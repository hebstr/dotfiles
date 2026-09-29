# Upgrade du pandoc systeme vers 3.10

*2026-07-20T14:19:04Z by Showboat 0.6.1*
<!-- showboat-id: ca73b0fb-f65e-4704-a1b4-c623d62eaed7 -->

Ubuntu 24.04 gèle pandoc à 3.1.3 : `apt-cache policy` donne candidate == installed, donc `apt upgrade` ne bouge pas.
La seule voie est le `.deb` publié par jgm/pandoc.

Motivation immédiate : le gate Lua de `.claude/PLAN-LUA.md`, qui dépend de `pandoc.utils.run_lua_filter`, absent de la 3.1.3.

État avant l'opération, mesuré le 2026-07-20 : `pandoc 3.1.3` (`Features: -server +lua`), paquets `pandoc` 3.1.3+ds-2 et `pandoc-data` 3.1.3-1, `apt-cache policy` candidate == installed == 3.1.3+ds-2.
Ces valeurs ne sont pas rejouables une fois l'upgrade fait ; les blocs exécutables ci-dessous le sont.

Contrôle de sûreté avant remplacement : aucun paquet installé ne dépend de `pandoc` (`quarto` embarque le sien), donc `dpkg -i` ne casse aucune dépendance.

```bash
apt-cache rdepends --installed pandoc
```

```output
pandoc
Reverse Depends:
```

Récupération et inspection du paquet amont.
Le champ à vérifier est `Replaces: pandoc-data` : sans `Conflicts`, dpkg reprend les fichiers de `pandoc-data` sans refuser l'installation.
Les dépendances se limitent à libc6, libgmp10 et zlib1g, donc pas de runtime Haskell à tirer.

```bash
cd "$(mktemp -d)"
gh release download 3.10 -R jgm/pandoc -p "pandoc-3.10-1-amd64.deb" --clobber
dpkg-deb -f pandoc-3.10-1-amd64.deb Package Version Depends Replaces
```

```output
Package: pandoc
Version: 3.10-1
Depends: libc6 (>= 2.13), libgmp10, zlib1g (>= 1:1.1.4)
Replaces: pandoc-data
```

Installation.
`sudo` est inutilisable depuis Claude Code (pas de TTY pour saisir le mot de passe, et `!` n'en alloue pas non plus) ; `pkexec` passe par le prompt graphique polkit et fonctionne.
Bloc non rejouable tel quel, il exige une interaction :

~~~sh
pkexec dpkg -i pandoc-3.10-1-amd64.deb
~~~

Sortie obtenue : `Dépaquetage de pandoc (3.10-1) sur (3.1.3+ds-2)` puis `Paramétrage de pandoc (3.10-1)`, exit 0.

Vérification.
Trois choses : la version, la présence de `run_lua_filter` (la raison de l'upgrade), et le gain collatéral `+server` que la 3.1.3 n'avait pas.

```bash
pandoc --version | head -2
pandoc lua -e "print(\"run_lua_filter: \" .. tostring(pandoc.utils.run_lua_filter ~= nil))"
```

```output
pandoc 3.10
Features: +server +lua
run_lua_filter: true
```

Reliquat : `pandoc-data` 3.1.3-1 reste installé et possède encore les données de la 3.1.3 sous `/usr/share/pandoc/data/`.
Le binaire amont embarque les siennes et n'installe rien à cet emplacement, donc ces fichiers sont morts.
L'intersection avec les fichiers du nouveau `pandoc` se limite à quatre répertoires parents (`/.`, `/usr`, `/usr/share`, `/usr/share/doc`), et la simulation de retrait ne touche que `pandoc-data`.

```bash
comm -12 <(dpkg -L pandoc-data | sort) <(dpkg -L pandoc | sort)
```

```output
/.
/usr
/usr/share
/usr/share/doc
```

Fichiers de suivi mis à jour dans la foulée : `rules/environment.md` (nouvelle ligne Pandoc dans le tableau Runtimes, avec la divergence assumée entre `/usr/bin/pandoc` et `quarto pandoc`), `.claude/PLAN-LUA.md` (deux lignes du tableau de faits devenues fausses, plus la justification du point load-bearing n°1, qui reposait sur l'absence de `run_lua_filter`), et `memory/reference_quarto_lua_shortcodes.md` (les chaînes d'erreur de `list_directory` ont été re-mesurées sur 3.10 : identiques à la 3.1.3, l'invariance est désormais notée).

Retrait du reliquat, `pkexec apt-get -y remove pandoc-data` (567 ko libérés, aucun autre paquet touché).
`/usr/share/pandoc/` disparaît entièrement : plus rien ne le peuple.
Le contrôle qui compte ensuite est que les fichiers de données restent servis depuis le binaire, `default.csl` en tête, sans quoi citeproc casserait.

```bash
dpkg -l | grep -c "^ii  pandoc "
ls /usr/share/pandoc 2>&1 || true
printf "# Titre\n\nUn *test*.\n" | pandoc -f markdown -t html
pandoc --print-default-data-file=default.csl | head -1
```

```output
1
ls: cannot access '/usr/share/pandoc': No such file or directory
<h1 id="titre">Titre</h1>
<p>Un <em>test</em>.</p>
<?xml version="1.0" encoding="utf-8"?>
```

## Clos le 2026-09-29 : le paquet est purgé

Les blocs ci-dessus ne sont plus rejouables, le paquet `pandoc` n'existant plus sur la machine.

Le motif de l'upgrade est mort avant le paquet. Le gate Lua avait besoin de `pandoc.utils.run_lua_filter`, absent de la 3.1.3 gelée par Ubuntu 24.04 ; la 3.10 que quarto embarque l'a, mesuré le 2026-09-29, et la CI de `quarto-hebstr-doc` appelle de toute façon `quarto pandoc lua tests/run.lua`, jamais le binaire système. La divergence assumée en juillet entre `/usr/bin/pandoc` et `quarto pandoc` n'achetait donc plus rien.

Elle a fini par coûter. pandoc 3.12, sorti et installé le 2026-09-29, remplace dans `makeDataURI` le prédicat d'échappement `isOk`, alphanumériques ASCII seulement, par `isUnescapedInURI` de `Network.URI`, qui vaut `isReserved c || isUnreserved c`. Le prédicat valide une URI entière, il n'échappe pas ce qu'on insère dedans : `#` est réservé, donc laissé littéral, et il ouvre le fragment. Toute CSS embarquée en data-URI est coupée à sa première couleur hexadécimale. Mesuré sur les widgets reactable d'eds-prise : 2 125 caractères sur 9 887 atteignent le navigateur, dix-sept règles sur quatre-vingt-dix-huit, et les captures PNG sortent illisibles sans qu'aucune commande n'échoue.

Ce que R en fait aggrave le cas : `rmarkdown:::find_pandoc` collecte `RSTUDIO_PANDOC`, le premier `pandoc` du PATH et `~/opt/pandoc`, puis garde **la version la plus haute**, pas la première source. Positron pose pourtant déjà `RSTUDIO_PANDOC` sur son quarto embarqué : le pandoc système gagnait par son seul numéro de version.

État final, et ce qui remplace ce qui part. `apt-get purge pandoc`, sans casse, `apt-cache rdepends --installed pandoc` étant vide et `dpkg -L pandoc` ne possédant que le binaire, sa page de man et son copyright. `quarto-update` pose désormais deux liens au lieu d'un, par une fonction `sync_link` partagée : `/usr/local/bin/quarto` et `/usr/local/bin/pandoc`, ce dernier vers `${PREFIX}/bin/tools/$(uname -m)/pandoc`. Le nom du répertoire d'architecture est vérifié sur x86_64 seulement, le cas aarch64 reste une hypothèse, et un test épingle le comportement si le binaire n'y est pas : le lien est sauté en silence, sortie 0. `pandoc-update` et `_meta/tests/pandoc-update.bats` sont supprimés, le module `pandoc` de `sys-update` aussi, avec ses quatre assertions dans `_meta/tests/sys-update.bats`.

Le lien n'est pas cosmétique. Sans pandoc sur le PATH, un shell que Positron n'a pas lancé n'a pas non plus `RSTUDIO_PANDOC` : mesuré, `find_pandoc` rend la version `0` et `pandoc_available()` rend `FALSE`, sur quoi `hebstr:::.self_contained()` écrit un widget non autoportant avec un simple avertissement.

Trois issues ont été écartées, chacune sur mesure. Un `find_pandoc(dir = )` par projet ne traite qu'un dépôt sur une pile qui en compte plusieurs. Le même appel depuis `Rprofile.site` par `setHook(packageEvent("rmarkdown", "onLoad"))` ne protégeait que la valeur d'un pandoc système tenu à jour indépendamment, valeur nulle une fois constaté qu'il n'y a aucun usage hors quarto. Un gel apt à la 3.10 fait échouer `pandoc-update` bruyamment, `man apt-get` disant que sous `-y` toute modification d'un paquet gelé fait abandonner apt, donc `sys-update` sortirait un module en échec à chaque passage, pour un paquet qui serait alors le doublon exact de la copie de quarto.
