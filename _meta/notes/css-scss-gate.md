# CSS/SCSS gate: bootstrap de la toolchain

*2026-07-26T08:44:10Z by Showboat 0.6.1*
<!-- showboat-id: 6803fc75-56fa-4934-820c-40d555f5c0ca -->

Mise en place de l'outillage du gate CSS/SCSS, à l'instar des gates shell/Python/R/Rust/Typst/Lua.

Choix retenus, issus de la recherche `/workflow:reco` :

- **Formateur** : Prettier.
  Support SCSS officiel et courant, et il préserve les marqueurs de région Quarto octet pour octet (vérifié plus bas).
- **Linter** : Stylelint + `stylelint-config-standard-scss`.
  Stylelint est explicitement linter-only depuis la v15 et délègue le formatage à un pretty printer.
- **Écartés** : Biome (SCSS en `⌛️` parsing/format et `🚫` lint, jalon v2.6), dprint+malva (aucun binaire standalone, exige dprint comme hôte), `stylelint-config-prettier-scss` (mort depuis 2023, désactive des règles supprimées en v15).
- **LSP** : extension Positron `SomewhatStationery.some-sass`, qui embarque `some-sass-language-server` (navigation `@use` inter-fichiers).
  Dans un fork VS Code, elle cohabite par défaut avec le serveur CSS intégré, montage supporté depuis some-sass#236.

Déploiement : nouveau paquet stow `css`, portant la toolchain épinglée sous `.local/share/css-gate/`.
Les versions sont figées dans `package.json` + lockfile suivis par git ; `node_modules/` est déjà couvert par le `.gitignore` du dépôt.

```bash
node --version; npm --version; quarto --version; quarto check 2>&1 | grep -i "dart sass"
```

```output
v24.18.0
11.16.0
1.10.18
      Dart Sass version 1.101.0: OK
```

Le compilateur Sass qui compte est celui embarqué par Quarto (1.101.0), pas un `sass` système : toute dépréciation Dart Sass est donc active et remontée au render.

```bash
GATE_DIR="$HOME/dotfiles/css/.local/share/css-gate"
mkdir -p "$GATE_DIR"
cat > "$GATE_DIR/package.json" <<'JSON'
{
  "name": "css-gate",
  "private": true,
  "description": "Pinned toolchain backing the CSS/SCSS lint/format gate (rules/css.md)",
  "type": "module",
  "devDependencies": {
    "prettier": "3.9.6",
    "stylelint": "17.14.1",
    "stylelint-config-standard-scss": "17.0.0"
  }
}
JSON
cat "$GATE_DIR/package.json"
```

```output
{
  "name": "css-gate",
  "private": true,
  "description": "Pinned toolchain backing the CSS/SCSS lint/format gate (rules/css.md)",
  "type": "module",
  "devDependencies": {
    "prettier": "3.9.6",
    "stylelint": "17.14.1",
    "stylelint-config-standard-scss": "17.0.0"
  }
}
```

```bash
cd "$HOME/dotfiles/css/.local/share/css-gate"
npm install --no-fund --no-audit 2>&1 | tail -3
./node_modules/.bin/stylelint --version
./node_modules/.bin/prettier --version
test -f package-lock.json && echo "lockfile: $(jq -r .lockfileVersion package-lock.json), $(jq -r ".packages | length" package-lock.json) paquets"
```

```output

added 127 packages in 6s
17.14.1
3.9.6
lockfile: 3, 128 paquets
```

## Contrainte de déploiement : où vit la config

Stylelint résout les `extends` depuis le répertoire du fichier de configuration, pas depuis l'installation du binaire.
Une config posée ailleurs que dans le paquet stow ne trouve donc pas `stylelint-config-standard-scss` et échoue sur `ConfigurationError: Could not find "stylelint-config-standard-scss"`.
La conséquence dicte le design retenu : la config partagée vit à côté de son propre `node_modules`, ce qui fait résoudre `extends` sans effort, et `--config <chemin fixe>` suffit à l'invocation.
Les blocs de démonstration ci-dessous passent en plus `--config-basedir` parce qu'ils écrivent leur config dans un répertoire temporaire ; le gate installé n'en a pas besoin.
Une config locale à un projet, elle, exigerait ce flag.

## Le piège Quarto

`stylelint-config-standard-scss` active `comment-whitespace-inside: "always"`, qui exige une espace après `/*` et avant `*/`.
Les marqueurs de région Quarto (`/*-- scss:defaults --*/`) n'en ont pas : le preset les signale, et `--fix` les réécrit en `/* -- scss:defaults -- */`.
Quarto ne reconnaît alors plus aucune frontière de couche et refuse le fichier.
Le preset officiel, appliqué tel quel, casse donc tous les thèmes Quarto.

```bash
set -Eeuo pipefail
GATE="$HOME/dotfiles/css/.local/share/css-gate"
SL=("$GATE/node_modules/.bin/stylelint" --config-basedir "$GATE")
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
cd "$D"

printf '%s\n' '/*-- scss:defaults --*/' '$primary: #ab12cd !default;' > theme.scss
printf '%s\n' '---' 'title: t' 'format:' '  html:' '    theme: [cosmo, theme.scss]' '---' 'x' > doc.qmd
printf '%s\n' 'export default { extends: ["stylelint-config-standard-scss"] };' > sl.config.mjs

echo '== 1. render de reference, marqueur intact'
quarto render doc.qmd --quiet
grep -q 'ab12cd' doc_files/libs/bootstrap/*.min.css &&
  echo 'la variable du theme est bien compilee dans le CSS Bootstrap'

echo
echo '== 2. le preset nu signale le marqueur'
"${SL[@]}" --config sl.config.mjs theme.scss || true

echo
echo '== 3. --fix reecrit le marqueur'
"${SL[@]}" --config sl.config.mjs --fix theme.scss || true
printf 'avant: /*-- scss:defaults --*/\napres: %s\n' "$(head -1 theme.scss)"

echo
echo '== 4. Quarto refuse desormais le fichier'
rm -rf doc_files doc.html
render_log=$(quarto render doc.qmd 2>&1) && rc=0 || rc=$?
printf 'quarto render exit: %s\n' "$rc"
printf '%s\n' "$render_log" | sed -n 's/.*\(ERROR: .*\)/\1/p' | head -1
```

```output
== 1. render de reference, marqueur intact
la variable du theme est bien compilee dans le CSS Bootstrap

== 2. le preset nu signale le marqueur

theme.scss
  1:3   ✖  Expected whitespace after "/*"   comment-whitespace-inside
  1:21  ✖  Expected whitespace before "*/"  comment-whitespace-inside

✖ 2 problems (2 errors, 0 warnings)
  2 errors potentially fixable with the "--fix" option.


== 3. --fix reecrit le marqueur
avant: /*-- scss:defaults --*/
apres: /* -- scss:defaults -- */

== 4. Quarto refuse desormais le fichier
quarto render exit: 1
ERROR: The file /tmp/tmp.niMIr2tsC9/theme.scss doesn't contain at least one layer boundary (/*-- scss:defaults --*/, /*-- scss:rules --*/, /*-- scss:mixins --*/, /*-- scss:functions --*/, or /*-- scss:uses --*/)
```

## Config durcie

Trois écarts au preset, aucun n'étant un goût stylistique :

- `comment-whitespace-inside: null` : sans elle, `--fix` casse les thèmes Quarto (démonstration ci-dessus).
- `selector-class-pattern` élargi au camelCase : Pandoc génère `.sourceCode` et `.numberSource`, non renommables.
  Le motif reste strict sur le reste, plutôt que de désactiver la règle.
- `at-rule-disallowed-list: ["import"]` : `@import` Sass est déprécié depuis Dart Sass 1.80.0 et supprimé en 3.0.0, et un render Quarto avale l'avertissement du compilateur, donc le gate est le seul signal.
  Le corpus en compte zéro, la règle est purement anti-régression.

Les fonctions couleur legacy n'ont pas besoin de règle dédiée : `scss/no-global-function-names`, actif dans le preset, remonte déjà `lighten`, `darken`, `transparentize`, `adjust-hue`, `map-get` et `nth` avec le remplacement exact.

Vérification sur un thème réel du dépôt `quarto-hebstr-doc` (745 lignes), en passant la chaîne complète du gate.

```bash
set -Eeuo pipefail
GATE="$HOME/dotfiles/css/.local/share/css-gate"

cat > "$GATE/stylelint.config.mjs" <<'CONFIG'
export default {
  extends: ["stylelint-config-standard-scss"],
  rules: {
    // Quarto region markers (/*-- scss:defaults --*/) carry no inner whitespace;
    // the rule's autofix rewrites them and Quarto then rejects the theme file
    "comment-whitespace-inside": null,
    // Pandoc emits camelCase classes (.sourceCode, .numberSource) that cannot be renamed
    "selector-class-pattern": "^[a-zA-Z][a-zA-Z0-9_-]*$",
    // Sass @import is deprecated since Dart Sass 1.80.0 and removed in 3.0.0; the
    // compiler warning is swallowed by a Quarto render, so the gate is the only signal
    "at-rule-disallowed-list": ["import"],
  },
};
CONFIG

SL=("$GATE/node_modules/.bin/stylelint" --config "$GATE/stylelint.config.mjs" --config-basedir "$GATE")
PR=("$GATE/node_modules/.bin/prettier")

D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
SRC="$HOME/Documents/packages/quarto-hebstr-doc/_extensions/hebstr-doc/theme-base.scss"
cp "$SRC" "$D/theme-base.scss"
cd "$D"

echo '== etat initial (745 lignes, theme Quarto reel)'
"${SL[@]}" theme-base.scss 2>&1 | grep problems || true

echo
echo '== chaine du gate: stylelint --fix, puis prettier --write, puis stylelint validant'
"${SL[@]}" --fix theme-base.scss >/dev/null 2>&1 || true
"${PR[@]}" --write --log-level warn theme-base.scss
"${SL[@]}" theme-base.scss 2>&1 | tail -8 || true

echo
echo '== les marqueurs de region ont survecu'
grep -n 'scss:\(defaults\|rules\)' theme-base.scss

echo
echo '== prettier est idempotent apres la chaine'
"${PR[@]}" --check theme-base.scss

echo
echo '== stylelint attrape toujours les vrais defauts (echantillon)'
"${SL[@]}" theme-base.scss 2>&1 | grep -E 'no-global-function-names|generic-family' | head -6 || true
```

```output
== etat initial (745 lignes, theme Quarto reel)
✖ 58 problems (58 errors, 0 warnings)

== chaine du gate: stylelint --fix, puis prettier --write, puis stylelint validant
  632:18  ✖  Missing generic font family       font-family-no-missing-generic-family-keyword
  673:10  ✖  Expected list.nth instead of nth  scss/no-global-function-names
  674:18  ✖  Expected list.nth instead of nth  scss/no-global-function-names
  675:17  ✖  Expected list.nth instead of nth  scss/no-global-function-names
  676:15  ✖  Expected list.nth instead of nth  scss/no-global-function-names

✖ 6 problems (6 errors, 0 warnings)


== les marqueurs de region ont survecu
1:/*-- scss:defaults --*/
22:/*-- scss:rules --*/

== prettier est idempotent apres la chaine
Checking formatting...
All matched files use Prettier code style!

== stylelint attrape toujours les vrais defauts (echantillon)
  199:18  ✖  Missing generic font family       font-family-no-missing-generic-family-keyword
  632:18  ✖  Missing generic font family       font-family-no-missing-generic-family-keyword
  673:10  ✖  Expected list.nth instead of nth  scss/no-global-function-names
  674:18  ✖  Expected list.nth instead of nth  scss/no-global-function-names
  675:17  ✖  Expected list.nth instead of nth  scss/no-global-function-names
  676:15  ✖  Expected list.nth instead of nth  scss/no-global-function-names
```

Reste 6 défauts réels après la chaîne : deux `font-family` sans famille générique de repli, et quatre appels `nth()` global au lieu de `list.nth()`, une dépréciation Dart Sass.
Ce sont des corrections manuelles à faire dans le thème, pas du bruit à neutraliser.

Pas de config Prettier dans le paquet : les valeurs par défaut conviennent, et une config qui ne ferait que les répéter n'aurait aucun consommateur.
Un `.prettierrc` local à un projet reste prioritaire, ce qui est le comportement voulu.

```bash
cd "$HOME/dotfiles"
stow css
printf "cible du symlink: %s\n" "$(readlink -f "$HOME/.local/share/css-gate")"
git check-ignore -q css/.local/share/css-gate/node_modules && echo "node_modules ignore par git: oui"
printf "fichiers suivis a ajouter:\n"; git status --porcelain --untracked-files=all css/ | grep -v node_modules
symlinks-check && echo "symlinks-check: aucun lien casse"
```

```output
cible du symlink: /home/julien/dotfiles/css/.local/share/css-gate
node_modules ignore par git: oui
fichiers suivis a ajouter:
?? css/.local/bin/prettier
?? css/.local/bin/stylelint
?? css/.local/share/css-gate/package-lock.json
?? css/.local/share/css-gate/package.json
?? css/.local/share/css-gate/stylelint.config.mjs
symlinks-check: aucun lien casse
```

## LSP dans Positron

L'extension `SomewhatStationery.some-sass` embarque `some-sass-language-server` : navigation `@use`/`@forward` inter-fichiers, rename de symboles à l'échelle du workspace, documentation SassDoc.
Elle est publiée sur OpenVSX, donc installable directement par le CLI Positron.
Aucune désinstallation du serveur CSS intégré n'est requise : depuis some-sass#236, l'extension se met en retrait des fonctionnalités déjà couvertes quand l'éditeur embarque `vscode-css-language-server`, ce qui est le cas d'un fork VS Code.

```bash
positron --install-extension SomewhatStationery.some-sass 2>&1 | tail -4
positron --list-extensions --show-versions 2>/dev/null | grep -i some-sass
```

```output
Installing extensions...
Installing extension 'somewhatstationery.some-sass'...
Extension 'somewhatstationery.some-sass' v4.3.9 was successfully installed.
somewhatstationery.some-sass@4.3.9
```

## État à la fin de ce bootstrap

En place :

- toolchain épinglée (`prettier` 3.9.6, `stylelint` 17.14.1, `stylelint-config-standard-scss` 17.0.0) sous le paquet stow `css`, lockfile suivi par git ;
- config Stylelint durcie pour Quarto, validée sur un thème réel : 58 signalements ramenés à 6 défauts authentiques ;
- serveur de langage SCSS actif dans Positron.

Reste à faire, hors périmètre showboat (édition de code et de documentation) :

- `bin/.local/bin/css-lint`, wrapper enchaînant `stylelint --fix`, `prettier --write`, `stylelint` validant, avec `--config-basedir` et préférence donnée à une config locale au projet si elle existe ;
- `claude/.claude/rules/css.md`, règle de gate par langage sur le modèle de `lua.md` et `typst.md` ;
- module `css-toolchain` dans `sys-update` (le module `npm` existant ne couvre que les paquets globaux, pas ce répertoire épinglé) ;
- ajout de `css` à la liste des paquets stow dans `~/.claude/CLAUDE.md` ;
- câblage dans le hook `format-on-edit` et dans `prek.toml`.

`showboat verify` rejoue l'ensemble sans échec.
Quatre blocs divergent, aucun par échec.
Trois pour des raisons d'idempotence, attendues à la relecture : `npm install` affiche `up to date` au lieu de `added 127 packages`, le chemin `mktemp` de la démonstration Quarto change à chaque exécution, et l'installation de l'extension Positron signale qu'elle est déjà présente.
Le quatrième est le bloc de validation sur le thème réel : son entrée a depuis été corrigée (`list.nth`, familles génériques) et reformatée, donc il rapporte désormais zéro problème au lieu de 58 ramenés à 6, et le marqueur `scss:rules` a glissé de la ligne 22 à la 29 avec l'ajout de la région `scss:uses`.
Ne pas le réenregistrer : la démonstration vaut par les 58 signalements sur l'état d'alors, qu'un rejeu sur un fichier propre ne montrerait plus.

## Câblage final

Le wrapper `css-lint` initialement prévu a été abandonné : une fois la config partagée voisine de `node_modules` et les deux binaires sur le PATH, il ne restait qu'un alias déguisé, là où les autres gates du dépôt sont des chaînes nues inlinées dans le hook.

Livré :

- `css/.local/bin/{stylelint,prettier}`, symlinks stow vers la toolchain épinglée, donc les deux outils sont sur le PATH ;
- arm `*.css | *.scss` dans `claude/.claude/hooks/format-on-edit.sh`, sur le modèle des arms R, Python et shell, couvert par cinq tests dans `_meta/tests/format-on-edit.bats` (dont l'ordre des passes, la poursuite du formatage quand `stylelint --fix` sort en 2, et l'exclusion du CSS généré) ;
- `claude/.claude/rules/css.md`, règle de gate auto-chargée sur `**/*.{css,scss}` ;
- `bin/.local/bin/css-toolchain-update`, câblé comme module `css-toolchain` de `sys-update` ;
- `css` ajouté à la liste des paquets stow de `CLAUDE.md`, `stylelint` et `prettier` à l'inventaire CLI de `rules/environment.md`.

Le `prek.toml` de `~/dotfiles` ne reçoit aucun hook CSS : le seul CSS que le dépôt suit est un thème Obsidian vendu (`obsidian/notes/.obsidian/themes/Minimal/theme.css`), jamais écrit à la main, que le hook devrait de toute façon exclure.
Le snippet à déposer dans les dépôts qui en portent (`quarto-hebstr-doc` et les autres extensions Quarto) est documenté dans `rules/css.md`.
Aucun hook upstream n'est utilisable : stylelint ne publie pas de `.pre-commit-hooks.yaml`, `pre-commit/mirrors-prettier` est archivé depuis avril 2024, et `awebdeveloper/pre-commit-stylelint` n'a pas bougé depuis juillet 2023.

## Déploiement du gate au commit

`quarto-hebstr-doc` est le premier dépôt câblé : `package.json` + `package-lock.json` + `stylelint.config.mjs` à la racine, `node_modules/` ajouté à son `.gitignore`, et deux hooks prek dont l'`entry` pointe sur `node_modules/.bin/` (chemin relatif que prek résout depuis la racine du dépôt, donc la version épinglée du dépôt et non celle du PATH).

Trois effets de bord qu'il a fallu corriger dans ce dépôt, et qui se reproduiront à chaque nouveau dépôt câblé :

- `.github/workflows/render.yml` lançait `prek --all-files` sans Node ni `npm ci` : la CI aurait échoué au premier push, les binaires visés par l'`entry` n'étant pas commités.
  Étape `actions/setup-node` + `npm ci` ajoutée avant le hook.
- `filetree.yml` alimente le shortcode `filetree` qui parcourt le dépôt sur disque à `depth: 2` : `node_modules/` serait apparu dans `example.qmd`.
  Ajouté aux `exclude`, et les deux nouveaux fichiers racine décrits.
- `CONTRIBUTING.md` énumérait le jeu de hooks sans CSS/SCSS et ne mentionnait pas le `npm ci` préalable.

`css-toolchain-update` est couvert par 28 tests dans `_meta/tests/css-toolchain-update.bats` : parsing d'arguments, préflight des trois dépendances, `package.json` absent, priorité de `CSS_GATE_DIR`, registre injoignable et versions dégénérées (`null`, chaîne vide), branche à jour, et branche périmée (épinglage `--save-exact`, invocation npm unique, `--check` sans install, paquet absent rapporté `none`, échec npm propagé).

La suite a été validée par mutation du script sur copies, via l'override `CSS_TOOLCHAIN_UPDATE` : perte de `--save-exact`, `--check` qui installe quand même, garde vide/null neutralisée, garde d'échec curl supprimée.
Chaque mutation ne fait tomber que les tests de son périmètre.
