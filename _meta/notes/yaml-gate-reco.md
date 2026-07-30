# Gate YAML : recherche préalable, rien d'installé

Note de recherche issue de `/workflow:reco` (2026-07-30), différée.
Aucun outil installé, aucun fichier de config écrit, aucun hook ajouté.
Elle existe pour que la décision n'ait pas à être reprise de zéro.

## État actuel

La seule couverture YAML est le hook `check-yaml` (parse PyYAML) présent dans `prek.toml` et `_meta/profiles/prek.toml`.
C'est un contrôle de validité syntaxique au commit, rien de plus.

Absents : `rules/yaml.md`, branche `*.yml|*.yaml` dans `claude/.claude/hooks/format-on-edit.sh`, entrée dans `rules/environment.md`, module `sys-update`, extension YAML dans les settings Positron.

## Surface à couvrir

Fichiers écrits à la main, hors `_extensions/` vendorisés et `node_modules/` :

  | Classe         | Fichiers                                                                                                         | Validation déjà en place                      |
  | -------------- | ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
  | Config Quarto  | `_quarto.yml`, `_metadata.yml`, `_variables.yml`, `_brand.yml`, `_extension.yml`, `_publish.yml`, `filetree.yml` | `quarto render`, imposé par `rules/quarto.md` |
  | pkgdown        | `_pkgdown.yml` (R-edstr, R-hebstr)                                                                               | `pkgdown::build_site()`                       |
  | GitHub Actions | 4 repos : R-edstr, claude-code-plugins, quarto-hebstr-doc, pingfanhu-website                                     | aucune                                        |
  | dotfiles       | `gh/.config/gh/config.yml`                                                                                       | aucune                                        |

Le volume est dominé par Quarto, mais c'est la classe déjà validée.
La classe sans aucune couverture est celle des workflows GitHub Actions.

## Recommandation retenue

Trois pièces, en réutilisant l'existant plutôt qu'en ajoutant une toolchain.

1. **Formateur : `prettier`**, pas `yamlfmt`.
   Déjà installé, épinglé dans `~/.local/share/css-gate/`, déjà suivi par le module `css-toolchain` de `sys-update`.
   Zéro nouvel outil à maintenir pour cette couche.
2. **Linter : `yamllint`**, via `uv tool install` (module `uv-tools`), en pass validante avec `--strict`.
3. **Workflows : `actionlint`**, en surcouche sur `.github/workflows/` uniquement.

Éditeur : extension `redhat.vscode-yaml` (Open VSX : `redhat/vscode-yaml`) pour la complétion et la validation par schéma SchemaStore.
Elle ne remplace pas le gate : le `yaml-language-server` n'a aucun mode batch, seulement les transports LSP `--stdio`, `--socket`, `--node-ipc`.

L'ordre suit la forme des autres gates : formateur, puis linter validant dont le code de sortie décide.

## Pourquoi prettier et pas yamlfmt

C'est le point qui a renversé l'intuition de départ, qui allait vers yamlfmt.

`yamlfmt` convertit les blocs scalaires `|` en chaînes échappées avec `\n` : [issue #185](https://github.com/google/yamlfmt/issues/185), **ouverte**, labellisée `yaml_v3_problem` (« A bug in the underlying yaml library.
These issues are vastly harder to fix »).
Or les blocs `run: |` sont exactement le contenu des quatre repos à workflows.
Le mainteneur (unique, et la note du README précise que le projet n'est pas officiellement supporté par Google) explique que yamlfmt ne parse rien lui-même et hérite de `gopkg.in/yaml.v3`, dont la modification est hors de portée.

Prettier laisse les blocs `|` et `>` intacts.
Son coût est ailleurs, et se règle en un réglage : il réécrit `'simple'` en `"double"` et ramène le padding des commentaires de fin de ligne à un espace.
Ce second point entre en conflit avec le défaut `comments.min-spaces-from-content: 2` de yamllint, d'où le réglage à 1 côté `.yamllint`.
Piège prettier à éviter : `proseWrap: always`, qui reflowe et corrompt les scalaires quotés.
Le défaut `preserve` est sûr.

`yq` est écarté sans hésitation : il avale les commentaires de tête, écrase les lignes vides et aplatit les `|-`.
Ce n'est pas un formateur, le mainteneur l'assume.

`Biome` est inutilisable et pas seulement « pas encore » : sur sa [matrice de support](https://biomejs.dev/internals/language-support/), YAML est en parsing et formatage « en cours », mais **linting « pas en cours »**.

## Config yamllint à prévoir

Les trois règles que tout le monde désactive, mesuré sur environ 8 200 fichiers `.yamllint` publics : `line-length` (6 944 occurrences), `truthy` (6 056), `document-start` (5 376).
`extends: relaxed` reste minoritaire (876) : la pratique est d'ajuster `default`, pas de tomber en relaxed.

Le faux positif à connaître est la clé `on:` des workflows GitHub, que yamllint traite en booléen sous la sémantique YAML 1.1 ([issue #430](https://github.com/adrienverge/yamllint/issues/430), fermée).
Trois correctifs, du plus étroit au plus large : `truthy: {check-keys: false}`, `truthy: {allowed-values: [..., 'on']}`, ou `# yamllint disable-line rule:truthy`.
La doc officielle ne mentionne jamais ce cas ; c'est un savoir transmis par la communauté.

Découverte de config : `.yamllint`, `.yamllint.yaml`, `.yamllint.yml`, puis `$YAMLLINT_CONFIG_FILE`, puis `~/.config/yamllint/config`.
Codes de sortie : 1 sur erreur ; 2 sur warning seul, et seulement avec `--strict`.

## Blocage à lever en premier

`/usr/local/bin/yamllint` **n'est pas** `adrienverge/yamllint`.
C'est un symlink vers `../lib/node_modules/yaml-lint/dist/cli.js`, soit le paquet npm `yaml-lint` 1.7.0, qui ne fait qu'un contrôle de parse et n'a aucune règle de style.

```
lrwxrwxrwx 1 root root 41 Jan 29  2025 /usr/local/bin/yamllint -> ../lib/node_modules/yaml-lint/dist/cli.js
$ yamllint --version
1.7.0
```

Le vrai yamllint n'est pas installé.
L'apt de noble propose 1.33.0-1 contre 1.38.0 upstream, donc `uv tool install yamllint` est le bon canal.
Il faudra retirer ou renommer le symlink npm avant, sinon le PATH continuera de résoudre le mauvais binaire.

Également absents de la machine : `yamlfmt`, `actionlint`, `go`, `yaml-language-server`.

## Validation par schéma : ce qui existe et ce qui n'existe pas

Catalogue SchemaStore téléchargé et inspecté directement (HTTP 200, 1402 schémas) :

- **Présents** : `GitHub Workflow`, `yamllint`, `.pre-commit-config`.
- **Absents** : zéro occurrence de `quarto` ou `pkgdown`, zéro schéma dont le `fileMatch` cible `_quarto`, `_brand`, `_extension` ou `_pkgdown`.

Conséquence : la validation par schéma n'est utile que sur `.github/workflows/`.
Ne pas chercher à en mettre sur les configs Quarto ; `rules/quarto.md` impose déjà un `quarto render` complet sur toute édition de `_quarto.yml`, plus strict que n'importe quel schéma générique.

Une exception : `_brand.yml` a un schéma JSON Schema draft 2020-12 valide, hors catalogue, chez Posit : [`posit-dev/brand-yml/schema/brand.schema.json`](https://github.com/posit-dev/brand-yml/blob/main/schema/brand.schema.json), racine `$ref: #/$defs/Brand`.
Il est généré depuis `quarto-cli` à un tag épinglé, donc il retarde sur les releases Quarto.
Utilisable via un modeline `# yaml-language-server: $schema=...` ou via `yaml.schemas`.

À noter : le fichier `json-schemas.json` livré par quarto-cli n'est pas du JSON Schema conforme (une cinquantaine de ses `$defs` enveloppent leur corps dans un mot-clé non standard `object:`, qu'un validateur conforme ignore, si bien que ces defs acceptent n'importe quoi).
L'outillage éditeur de Quarto est un worker tree-sitter maison livré dans le CLI, pas une pile LSP + JSON Schema.

## Points non revérifiés

Rapportés par les agents de recherche, non confirmés en direct.
À traiter comme plausibles, pas comme acquis.

- Quarto attraperait `toc: yes` avec un message explicite sur YAML 1.2, mais **pas** les clés inconnues sous `format: html:` : une faute de frappe passerait silencieusement en métadonnée pandoc.
  C'est la vraie lacune de validation si elle se confirme.
- `actionlint` aurait un deadlock possible de l'intégration shellcheck sur gros script `run:`, corrigé sur `main` et dans aucun binaire publié (dernière release v1.7.12 du 2026-03-30, dernier commit 2026-04-19).
- Reformater et même réordonner toutes les clés d'un `_quarto.yml` produirait un `index.html` identique au bit près sur Quarto 1.10.18.

## Compléments à garder en tête

- `check-yaml` accepte `--unsafe`, qui bascule sur un contrôle syntaxique seul et autorise les tags YAML personnalisés.
  Pertinent si un `_quarto.yml` ou `_metadata.yml` porte un tag `!expr`.
  Le hook actuel ne le passe pas.
- Ne pas pointer un linter YAML sur un `.qmd` : il parse au-delà du `---` fermant et casse sur la première puce markdown.
  yamllint refuse d'assumer ce cas en amont.
  Le front matter est déjà mieux couvert par `panache`, qui diagnostique en plus la divergence js-yaml (YAML 1.2, Quarto) contre libyaml (YAML 1.1, pandoc) sur les valeurs `yes` / `no`.
- `actionlint` s'apparie couramment à `zizmor` : correctness d'un côté, sécurité de l'autre.
  Hors périmètre pour l'instant.
- Bruit shellcheck d'actionlint : SC2086 n'est pas pré-désactivé, et les directives `# shellcheck disable=` inline ne sont pas honorées.
  Les échappatoires sont `SHELLCHECK_OPTS`, un `-ignore` regex, ou `-shellcheck=` vide.
- Hooks pre-commit officiels disponibles pour les trois outils, et `prek` lit les `.pre-commit-hooks.yaml` upstream sans adaptation.
- Le hook `yamlfmt`, s'il était retenu un jour, ne se configure que par un fichier `.yamlfmt` à la racine, avec `language: system` pour viser un binaire local et `pass_filenames: false` dès qu'une config est fournie.

## Suite proposée

Installer et cadrer yamllint d'abord, puis mesurer le volume de violations sur l'existant avant de figer la config.
Le nombre de `line-length` et de `truthy` remontés sur les `_quarto.yml` et les workflows déjà écrits décidera de la config mieux qu'un choix a priori.

Ensuite seulement : `rules/yaml.md` sur le modèle de `rules/css.md`, branche dans `format-on-edit.sh`, hooks dans `prek.toml` et `_meta/profiles/prek.toml`.
