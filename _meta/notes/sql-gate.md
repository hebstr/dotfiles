# SQL gate: bootstrap sqlfluff

*2026-08-07T16:57:24Z by Showboat 0.6.1*
<!-- showboat-id: 550f8053-88b8-4a38-b419-84ce75a12ada -->

Mise en place de l'outillage du gate SQL, à l'instar des gates shell/Python/R/Rust/Typst/Lua/CSS.

Choix retenus, issus de la recherche `/workflow:reco` :

- **Fixer + linter validant** : SQLFluff.
  Seul outil de l'écosystème qui exprime les deux extrémités du gate (`fix` puis `lint`) avec des codes de sortie contractuels (0 propre, 1 violations, 2 erreur de config), et qui porte `duckdb` et `postgres` comme dialectes de première classe.
- **Extra `[rs]`** : lexer et parser Rust, opt-in depuis la 4.0.0, défaut annoncé en 5.0.
- **Écartés** : sqruff (pas de `--check`, pas de commande `format`, découverte de config partielle, 8 `.pre-commit-config.yaml` dans la nature contre 938 pour SQLFluff), pg_format et sql-formatter (formateurs purs, aucun contrat de code de sortie, donc inaptes à l'étape validante), shandy-sqlfmt (formateur only, sans dialecte), sqls et sqlls (LSP sans lint ni format).
- **Hors gate, conditionnel** : squawk pour les migrations DDL Postgres, postgres-language-server pour un projet purement Postgres.
- **LSP** : aucun serveur first-party côté SQLFluff. L'extension Open VSX `sqlfluff.vscode-sqlfluff` appelle la CLI, c'est le seul montage disponible dans Positron.

L'apt d'Ubuntu 24.04 est bloqué en 2.3.5, deux majeures de retard : l'installation passe donc par uv, comme ruff et pyrefly.

```bash
apt-cache policy sqlfluff | head -3
uv tool install "sqlfluff[rs]"
sqlfluff --version
```

```output
sqlfluff:
  Installed: (none)
  Candidate: 2.3.5-1
Resolved 16 packages in 1.54s
Downloading sqlfluff (1.0MiB)
Downloading sqlfluffrs (4.6MiB)
 Downloaded sqlfluff
 Downloaded sqlfluffrs
Prepared 8 packages in 8.73s
Installed 16 packages in 43ms
 + chardet==7.5.1
 + click==8.4.2
 + colorama==0.4.6
 + diff-cover==10.4.2
 + jinja2==3.1.6
 + markupsafe==3.0.3
 + pathspec==1.1.1
 + platformdirs==4.11.0
 + pluggy==1.6.0
 + pygments==2.20.0
 + pyyaml==6.0.3
 + regex==2026.7.19
 + sqlfluff==4.3.0
 + sqlfluffrs==4.3.0
 + tblib==3.2.2
 + tqdm==4.70.0
Installed 1 executable: sqlfluff
sqlfluff, version 4.3.0
```

Le dialecte `duckdb` de SQLFluff hérite de PostgreSQL et suit la grammaire DuckDB avec un retard d'environ un trimestre sur les releases. Le tracker amont affiche 43 issues labellisées duckdb, toutes fermées, ce qui ne dit pas si la couverture est solide ou simplement peu exercée. Smoke test sur la syntaxe friendly réellement utilisée ici.

```bash
declare -A CASES=(
  [exclude]="select * exclude (b) from t;"
  [replace]="select * replace (b + 1 as b) from t;"
  [group_by_all]="select a, count(*) from t group by all;"
  [from_first]="from t select a;"
  [read_parquet]="select * from read_parquet('f.parquet');"
  [list_compr]="select [x * 2 for x in [1, 2, 3]] as l;"
  [lambda]="select list_transform(l, x -> x + 1) from t;"
  [struct_lit]="select {'a': 1, 'b': 2} as s;"
  [map_lit]="select map {'a': 1} as m;"
  [union_by_name]="select a from t union all by name select a from u;"
  [qualify]="select a, row_number() over (partition by a) as rn from t qualify rn = 1;"
  [underscore_num]="select 1_000 as n;"
  [set_variable]="set variable x = 42;"
  [columns_star]="select columns('^v') from t;"
  [named_arg]="select struct_pack(a := 1) as s;"
  [pivot]="pivot t on a using sum(b);"
  [attach]="attach 'f.duckdb' as f;"
  [asof]="select * from t asof join u on t.ts >= u.ts;"
  [try_cast]="select try_cast(a as integer) from t;"
)
for k in $(printf "%s\n" "${!CASES[@]}" | sort); do
  if printf "%s\n" "${CASES[$k]}" | sqlfluff parse --dialect duckdb - >/dev/null 2>&1; then
    printf "ok    %s\n" "$k"
  else
    printf "FAIL  %s\n" "$k"
  fi
done
```

```output
ok    asof
FAIL  attach
ok    columns_star
ok    exclude
ok    from_first
ok    group_by_all
ok    lambda
ok    list_compr
ok    map_lit
ok    named_arg
ok    pivot
ok    qualify
ok    read_parquet
ok    replace
ok    set_variable
ok    struct_lit
ok    try_cast
ok    underscore_num
ok    union_by_name
```

Un seul trou : `ATTACH`, non reconnu quelle que soit la forme (avec ou sans `DATABASE`, avec ou sans alias, avec ou sans `IF NOT EXISTS`). Le parseur retombe sur les statements PostgreSQL hérités et rend la section entière inanalysable.

```bash
for s in "attach 'f.duckdb' as f;" "attach database 'f.duckdb' as f;" "attach if not exists 'f.duckdb';"; do
  printf "%-40s => " "$s"
  printf "%s\n" "$s" | sqlfluff parse --dialect duckdb - >/dev/null 2>&1 && echo ok || echo FAIL
done
printf "%s\n" "attach 'f.duckdb' as f;" | sqlfluff lint --dialect duckdb - 2>&1 | tail -4
```

```output
attach 'f.duckdb' as f;                  => FAIL
attach database 'f.duckdb' as f;         => FAIL
attach if not exists 'f.duckdb';         => FAIL
L:   1 | P:   1 |  PRS | Line 1, Position 1: Found unparsable section: "attach
                       | 'f.duckdb' as f;"
WARNING: Parsing errors found and dialect is set to 'duckdb'. Have you configured your dialect correctly?
All Finished!
```

Le gate se réduit à deux étapes : `sqlfluff fix` joue le fixer et le formateur, `sqlfluff lint` joue le linter validant. `sqlfluff format` existe mais force un sous-ensemble de `fix` restreint aux règles de layout, donc redondant ici. Vérification des codes de sortie sur les deux chemins : violations toutes réparables, puis violation non réparable.

```bash
d=$(mktemp -d); cd "$d"
printf "[sqlfluff]\ndialect = duckdb\n" > .sqlfluff

printf "SELECT a,b FROM t WHERE x=1\n" > fixable.sql
sqlfluff fix fixable.sql >/dev/null 2>&1; echo "fix  exit=$?"
sqlfluff lint fixable.sql >/dev/null 2>&1; echo "lint exit=$?"
cat fixable.sql

printf "SELECT *\nFROM t\n" > residual.sql
sqlfluff fix residual.sql >/dev/null 2>&1; echo "fix  exit=$?"
sqlfluff lint residual.sql 2>&1 | sed -n "2,3p"
sqlfluff lint residual.sql >/dev/null 2>&1; echo "lint exit=$?"
cd /; rm -rf "$d"
```

```output
fix  exit=0
lint exit=0
SELECT
    a,
    b
FROM t
WHERE x = 1
fix  exit=1
L:   1 | P:   1 | AM04 | Query produces an unknown number of result columns.
                       | [ambiguous.column_count]
lint exit=1
```

Sans dialecte configuré, SQLFluff refuse de tourner et sort en 2, le code réservé aux erreurs de configuration. C'est ce qui rend le `.sqlfluff` par projet obligatoire plutôt que recommandé, et ce qui distingue mécaniquement un projet non configuré d'un projet qui viole ses propres règles.

```bash
d=$(mktemp -d); cd "$d"
printf "select 1\n" > q.sql
out=$(sqlfluff lint q.sql 2>&1); echo "exit=$?"
printf "%s\n" "$out" | sed -n 2p | cut -c1-96
cd /; rm -rf "$d"

uv tool list | grep -A1 "^sqlfluff"
command -v sqlfluff
```

```output
exit=2
User Error: No dialect was specified. You must configure a dialect or specify one on the command
sqlfluff v4.3.0
- sqlfluff
/home/julien/.local/bin/sqlfluff
```

Suites :

- La mise à jour passe par le module `uv-tools` de `sys-update` (`uv tool upgrade --all`), aucun module dédié à écrire.
- L'extension Positron `sqlfluff.vscode-sqlfluff` est sur Open VSX, elle appelle la CLI plutôt qu'un serveur de langage. Installée depuis l'éditeur, comme les autres extensions, et câblée dans le `settings.json` du profil.
- DuckDB a mergé son propre formateur SQL (PR duckdb/duckdb#21725, 2026-03-31) : `duckdb -format-file`, `-format` sur stdin, `.auto_format on`, et une fonction `duckdb_format_sql()`. Absent de la 1.5.5 installée, la branche ayant divergé avant le merge. Quand il sortira, il sera exact sur le dialecte là où SQLFluff devine, et vaudra une réévaluation de l'étape de formatage sur les fichiers DuckDB.

Le gate est documenté dans `rules/sql.md`.
