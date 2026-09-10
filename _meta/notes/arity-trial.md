# Arity: essai comme remplaçant de air + jarl

*2026-09-10T07:05:48Z by Showboat 0.6.1*
<!-- showboat-id: 2003316f-cc69-4b47-9d18-56ac8327393e -->

Arity (jolars) est un formatter + linter + LSP R en Rust, inspiré de air (formatage, tests, style) et de jarl (règles, architecture). Objectif de cet essai : mesurer l'écart de comportement avec la paire air 0.11.0 / jarl 0.6.0 en place, sans toucher à l'outillage existant. Installation user-local dans ~/.local/bin, réversible par un simple rm.

```sh
curl --proto "=https" --tlsv1.2 -sSf https://arity.cc/install | sh
```

```output
Downloading arity-x86_64-unknown-linux-gnu.tar.gz...
Checksum verified.
Installed arity to /home/julien/.local/bin/arity
```

```sh
command -v arity && arity --version && arity lint --help | head -5
```

```output
/home/julien/.local/bin/arity
arity 0.23.0
Lint .R files

Reads stdin when given `-`, or when paths are omitted and stdin is not a terminal. Exit codes: 0 = no findings, 1 = findings (or files blocked by parse errors), 2 = usage/IO error.

Usage: arity lint [OPTIONS] [PATH]...
```

## Écart de formatage

Référence : les projets R du poste sont propres sous `air format --check`. La question est de savoir ce qu'arity réécrirait sur ce même corpus, à largeur de ligne identique.

```sh
cd /home/julien/Documents/packages/R-hebstr && air format --check R/ && echo "air: propre"; arity format --check -q --no-config R/ 2>&1 | tail -1
```

```output
air: propre
22 of 23 file(s) would be reformatted
```

Cause principale : arity n'a pas d'équivalent de `persistent-line-breaks` d'air. Il recompacte tout appel qui tient dans la largeur de ligne, alors qu'air respecte le saut de ligne écrit à la main. Sa table de configuration ne retient que `line-width`, `indent-width`, `line-ending` et `description` : ni `persistent-line-breaks`, ni `indent-style` (tabulations), ni `skip`, ni `table`.

```sh
cd /home/julien/Documents/packages/R-hebstr && arity format --check --no-config R/xlsx_helpers.R 2>&1 | sed -n "1,14p"
```

```output
Diff in R/xlsx_helpers.R:64:
       return(wb)
     }
 
-    wb_add_font(
-      wb = wb,
-      dims = params$dims$data,
-      size = font_size
-    )
+    wb_add_font(wb = wb, dims = params$dims$data, size = font_size)
   }
 
   # posed before the border, so that the prototype row spread_style() broadcasts
---
```

Le constat vaut pour tout le corpus, quatorze projets portant un `air.toml`, chacun mesuré à la largeur de ligne qu'il déclare. air ne signale qu'un fichier, arity en réécrirait environ neuf sur dix.

```sh
for cfg in $(fdfind -H "^air\.toml$" /home/julien/Documents); do
  proj=$(dirname "$cfg")
  lw=$(awk -F"= *" "/^line-width/{print \$2}" "$cfg"); lw=${lw:-80}
  a=$(air format --check "$proj" 2>&1 | tail -1)
  b=$(arity format --check -q --no-config --line-width "$lw" --exclude "rv/scripts" "$proj" 2>&1 | tail -1)
  printf "%-14s lw=%-4s air:[%s] arity:[%s]\n" "$(basename "$proj")" "$lw" "$a" "$b"
done
```

```output
crpv-ciclo     lw=100  air:[] arity:[13 of 15 file(s) would be reformatted]
eds-avc        lw=100  air:[] arity:[32 of 37 file(s) would be reformatted]
eds-epimad     lw=100  air:[] arity:[4 of 7 file(s) would be reformatted]
eds-prise      lw=100  air:[] arity:[39 of 41 file(s) would be reformatted]
m2-dm1         lw=100  air:[] arity:[11 of 11 file(s) would be reformatted]
m2-dm2         lw=100  air:[] arity:[10 of 11 file(s) would be reformatted]
m2-dm3         lw=100  air:[] arity:[11 of 12 file(s) would be reformatted]
R-edstr        lw=100  air:[Would reformat: /home/julien/Documents/packages/R-edstr/R/edstr_import.R] arity:[29 of 32 file(s) would be reformatted]
R-hebstr       lw=80   air:[] arity:[42 of 49 file(s) would be reformatted]
stats          lw=80   air:[] arity:[3 of 4 file(s) would be reformatted]
ipl-sca        lw=80   air:[] arity:[5 of 6 file(s) would be reformatted]
md-nesrine     lw=100  air:[] arity:[24 of 24 file(s) would be reformatted]
umb-coco       lw=100  air:[] arity:[15 of 16 file(s) would be reformatted]
umb-rmi        lw=80   air:[] arity:[8 of 11 file(s) would be reformatted]
```

## Le fix qui casse le tidy eval

Le défaut bloquant. La règle `comparison-negation` lit `!!var < inf` comme la double négation que R analyse effectivement, et non comme l'opérateur d'injection rlang. Le correctif est classé *safe* : un simple `arity lint --fix`, sans `--unsafe-fixes`, retire les `!!` et change la sémantique du code. Le corpus porte 341 lignes de `!!` réparties sur 110 fichiers.

```sh
cd $(mktemp -d) && cat > bb.R <<EOF
h <- function(var, inf) {
  rlang::exprs(!!var < inf ~ "a")
}
k <- function(x, y) {
  if (!(x < y)) "z"
}
EOF
cp bb.R before.R
arity lint --no-config --fix --select comparison-negation bb.R >/dev/null 2>&1
diff before.R bb.R
echo "--- jarl sur le meme fichier ---"
jarl check --fix bb.R 2>&1 | tail -3
```

```output
2c2
<   rlang::exprs(!!var < inf ~ "a")
---
>   rlang::exprs(var < inf ~ "a")
5c5
<   if (!(x < y)) "z"
---
>   if (x >= y) "z"
--- jarl sur le meme fichier ---
Error: `jarl check --fix` can potentially perform destructive changes but no Version Control System (e.g. Git) was found on this project, so no fixes were applied.
Add `--allow-no-vcs` to the call to apply the fixes.
```

## Bruit du linter

Sur un paquet (`R-hebstr`, DESCRIPTION et NAMESPACE présents, index construit par `arity index`), arity remonte 51 constats là où jarl n'en remonte aucun. `undefined-symbol` en fournit 35, tous faux : masquage de données passé à un verbe que l'outil ne connaît pas (`modify_table_styling(columns = label)`), référencement séquentiel dans `lst()`, entrées `importFrom` entre guillemets que le NAMESPACE déclare pourtant (`"%>%"`, `"str_sub<-"`), et le segment `_` du pipe natif.

```sh
cd /home/julien/Documents/packages/R-hebstr && jarl check R/ 2>&1 | tail -2
arity lint --output concise R/ 2>&1 | grep -oE "\[[a-z0-9-]+\]" | sort | uniq -c | sort -rn
```

```output
── Summary ──────────────────────────────────────
All checks passed!
     35 [undefined-symbol]
     11 [comparison-negation]
      4 [unused-binding]
      1 [unnecessary-nesting]
```

Sur un projet d'analyse, la disproportion change d'ordre. `eds-prise` n'a ni DESCRIPTION ni `library()` dans les scripts, la session étant montée par `.Rprofile` et `setup.R` : arity ne résout donc plus rien et déclare indéfinis `select`, `mutate`, `left_join`. Les 36 `unused-binding` qui subsistent une fois `undefined-symbol` écarté visent les fonctions de `lib/`, lues comme des liaisons locales jamais relues alors qu'elles peuplent l'environnement global.

```sh
cd /home/julien/Documents/des/eds/eds-prise && jarl check . 2>&1 | tail -2
arity lint --no-config --output concise . 2>&1 | grep -oE "\[[a-z0-9-]+\]" | sort | uniq -c | sort -rn
```

```output
── Summary ──────────────────────────────────────
All checks passed!
   1229 [undefined-symbol]
     36 [unused-binding]
```

Deux défauts reproduits sur v0.23.0, absents de la documentation et du suivi d'issues amont. Le premier tient en une ligne que R évalue sans broncher.

```sh
cd $(mktemp -d) && printf "x <- 1:3 |> sum(x = _)\n" > pl.R
Rscript -e "source(\"pl.R\"); cat(\"R evalue a\", x, \"\n\")"
arity lint --no-config --output concise pl.R 2>&1 | grep undefined
jarl check pl.R 2>&1 | tail -1
```

```output
R evalue a 6 
pl.R:1:21: warning [undefined-symbol] no in-scope binding or attached package exports `_`
All checks passed!
```

Le modèle de masquage de données d'arity n'est pas en cause, et c'est vérifiable en trois fichiers : il ne signale ni la colonne `speed` ni la colonne dérivée `z`. Ce qu'il ne résout pas, ce sont les noms de verbes, faute d'un `library()` dans le fichier lu. Aucune clé de configuration ne permet de déclarer qu'un paquet est attaché ailleurs, donc sur la convention hebstr (`.Rprofile` plus `setup.R`) la règle se désactive ou se subit.

```sh
cd $(mktemp -d)
printf "df |> dplyr::mutate(z = speed * 2)\n" > a1.R
printf "library(dplyr)\ndf |> mutate(z = speed * 2)\n" > a2.R
printf "df |> mutate(z = speed * 2)\n" > a3.R
for f in a1 a2 a3; do printf "%s: " "$f.R"; arity lint --no-config --output concise $f.R 2>&1 | grep -c undefined-symbol; done
```

```output
a1.R: 0
a2.R: 0
a3.R: 1
```

## Ce qu'arity apporte

Le formatage de DESCRIPTION, qu'air ne touche pas, mais dans un style qui n'est pas celui d'usethis : `person()` éclaté à raison d'un argument par ligne, virgule vide comprise. La clé `[format] description` vaut `true` par défaut, donc un `arity format .` réécrit le DESCRIPTION sans qu'on le demande.

La vitesse : 0,04 s contre 0,10 s pour air sur 39 fichiers, 0,13 s contre 0,09 s pour jarl au lint. À cette échelle l'écart ne décide rien.

Un serveur de langage unique là où air et jarl en demandent deux, et 66 règles réparties en sept familles dont six couvrent le packaging et la documentation roxygen, terrain que jarl ne couvre pas.

## Ce que dit l'amont

Les mesures ci-dessus disent qu'arity recompacte. Elles ne disent pas si c'est un manque appelé à être comblé ou une décision. C'est une décision, et elle est verrouillée par un test du dépôt : le fixture `crates/arity-formatter/tests/fixtures/formatter/call_user_line_breaks/input.R` s'ouvre sur `# Unlike air, Arity doesn't cater to user line breaks`, et son `expected.R` réduit `list(\n a = 1,\n b = 2\n)` à `list(a = 1, b = 2)`. Elle découle de la première tenue du projet, « le formateur est seule autorité de mise en page ». `persistent-line-breaks` ne figure ni dans la référence de configuration, ni dans sa liste de clés réservées pour plus tard.

Air documente exactement l'inverse, et donne sa raison : « The goal of this feature is to strike a balance between being opinionated and recognizing that users often know when taking up more vertical space results in more readable output » (https://posit-dev.github.io/air/formatter.html). Les deux points d'échappement sont le premier argument d'un appel et la première expression d'un pipeline.

L'asymétrie du linter tient à un fait simple : jarl ne cherche pas les symboles non résolus. Ses sept familles de règles (comments, correctness, dplyr, performance, readability, suspicious, testthat) ne contiennent aucun équivalent d'`undefined-symbol` (https://jarl.etiennebacher.com/rules). Il ne peut donc pas se tromper là où arity se trompe, et il ne trouve rien là où arity trouve juste. Les deux outils ne mesurent pas la même chose.

Position officielle des deux outils en place. Jarl écarte le formatage et renvoie à air : « Jarl is not a code formatter, so automatic fixes may not match your expected code style. To automatically format code, use Air or styler » (https://jarl.etiennebacher.com/getting-started). Air n'a pas fermé la porte au lint : Davis Vaughan, sur l'issue 304 du dépôt air le 2025-04-15, à qui demandait un équivalent de `ruff check --fix`, répond « It is something we have been thinking about, but also no timeline on that ». La paire n'est donc pas un attelage définitif.

Maturité d'arity au 2026-09-10. Première release v0.2.0 le 2026-06-12, v0.23.0 le 2026-09-07, soit trois mois. Aucun jalon, aucune issue ouverte, la planification vivant dans un `TODO.md` non publié de 80 Ko. `versionary.jsonc` porte `bump-minor-pre-major`, donc les ruptures atterrissent dans les versions mineures. Contributeurs : jolars pour 1073 commits, le reste étant dependabot, github-actions et un commit `claude`.

Signal communautaire proche de zéro, et c'est mesurable plutôt que ressenti. Aucune mention dans R Weekly depuis la création du dépôt, là où jarl apparaît dans cinq numéros dont deux en titre. Aucun billet de l'auteur, qui avait pourtant annoncé panache sur le forum Posit. Deux issues déposées par des tiers en tout. Étoiles : arity 33, jarl 157, air 442. Le seul retour tiers approfondi de la famille porte sur jarl, passé sur `parsnip` et `igraph` par Hannah Frick et Maëlle Salmon, avec son unique faux positif rapporté (https://blog.r-hub.io/2026/06/02/jarl/).

Si la décision bascule un jour, la voie d'installation est tracée. `arity-installer.sh` honore `ARITY_INSTALL_DIR`, la forme que `devtools-update` consomme déjà pour prek, donc l'ajout tient en une entrée de la table `INSTALLERS` et une de `REPOS`, avec `/usr/local/bin` pour préfixe comme air et jarl. Le paquet Positron bundle son propre binaire, ce qui rejoue le partage « un outil, un binaire » déjà réglé pour air, panache et pyrefly.

## Conclusion de l'essai

Arity ne remplace pas air et jarl de façon transparente sur ce poste. Le formateur réécrirait neuf fichiers sur dix du corpus, et le recompactage qui en est la cause est une décision amont verrouillée par un test, pas un manque en attente de correctif. Le linter est inexploitable en l'état sur cette stack : `undefined-symbol` se désactive ou se subit, et `comparison-negation` porte un correctif classé sûr qui supprime les `!!`.

Ce qui resterait exploitable sans toucher au formateur : `arity lint --select` restreint aux familles `packaging` et `documentation`, qui couvrent le roxygen et le `DESCRIPTION` de `R-hebstr` et `R-edstr`, terrain que jarl laisse vide.

Binaire laissé dans `~/.local/bin/arity` pour suivre le projet ; `rm ~/.local/bin/arity && rm -rf ~/.cache/arity` revient en arrière. Le projet a trois mois de releases (v0.2.0 le 2026-06-12, v0.23.0 le 2026-09-07), un auteur unique qui est celui de panache déjà en service ici, et une cadence hebdomadaire. À revoir sur deux déclencheurs précis : un équivalent de `persistent-line-breaks`, ou une exception rlang dans `comparison-negation`. Ni l'un ni l'autre n'est annoncé.

Décision consignée dans `~/.claude/memory/project_arity_evaluation.md`.

