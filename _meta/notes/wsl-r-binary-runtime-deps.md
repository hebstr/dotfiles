# Paquets R binaires sous WSL : bibliothèques d'exécution et locale

*2026-09-13T20:22:09Z by Showboat 0.6.1*
<!-- showboat-id: 3da6fe27-10b4-4398-bf03-608b9f130641 -->

## Contexte

Initialisation d'une **machine secondaire** (`ju-TP2`) sous Windows, en suivant `~/dotfiles/_meta/notes/wsl-init-tuto.md`, pour y lancer un projet R existant (`~/Documents/services/md-nesrine`). Relevé le 2026-09-13 :

- Windows 10.0.26100.9445 (build 26100, Windows 11 24H2), WSL 2.7.14.0, noyau 6.18.33.2-microsoft-standard-WSL2
- Ubuntu 24.04.5 LTS, `systemd` actif
- R 4.6.1 installé par `rig`, `Rprofile.site` lié par `stow-rprofile` (dépôt PPM `__linux__/noble`, donc paquets **binaires**), `rv` 0.22.2
- Positron côté Windows, connecté à WSL par son serveur distant (`~/.positron-server`, 2026.09.1-2). La seule Quarto sur le PATH est celle qu'il embarque (1.10.18) : `/opt/quarto` est absent, `quarto-update` n'a pas encore tourné.

Place dans le tutoriel : après l'étape 7 (« Toolchain »), au premier `rv sync` d'un projet (étape 9, « Premier projet R »). Les étapes 2 et 3 ne suffisent pas pour ce cas, voir « Écarts » en fin de note.

## Symptôme

Le `rv sync` du projet, lancé depuis le terminal intégré de Positron, échoue sur `hebstr`. La cause n'est pas hebstr, qui n'a pas de code compilé : il meurt au *lazy loading*, parce qu'une de ses dépendances ne se charge pas.

~~~text
Error in dyn.load(file, DLLpath = DLLpath, ...) :
  unable to load shared object '.../__rv__staging/fs/libs/fs.so':
  libuv.so.1: cannot open shared object file: No such file or directory
ERROR: lazy loading failed for package 'hebstr'
~~~

Le même log montre un second défaut, sans effet bloquant :

~~~text
During startup - Warning messages:
1: Setting LC_CTYPE failed, using "C"
Warning in parse(...) :
  unable to translate 'M<U+00E9>diane (IQR)' to native encoding
~~~

## Cause 1 : bibliothèques d'exécution absentes

PPM sert des binaires. Ils n'ont pas besoin des en-têtes `-dev` que liste `rv sysdeps`, mais des bibliothèques partagées à l'exécution. Un `ldd` sur tous les `.so` de `~/.cache/rv` (hors `libR.so`, que R résout au chargement) trouve exactement deux manques :

- `fs` : `libuv.so.1`, paquet apt `libuv1t64`
- `magick` : `libMagick++-6.Q16.so.9`, `libMagickCore-6.Q16.so.7`, `libMagickWand-6.Q16.so.7`, paquet apt `libmagick++-6.q16-9t64`

## Cause 2 : locale demandée mais non générée

Le système est en `C.UTF-8` (`/etc/default/locale`), et le serveur Positron aussi. C'est le **terminal intégré de Positron** qui exporte `LANG=en_US.UTF-8`, alors que cette locale n'était pas générée (`locale -a` : `C`, `C.utf8`, `POSIX`). R retombe alors en `C`, non UTF-8. Chaîne de processus relevée :

~~~text
bash (terminal intégré Positron)   LANG=en_US.UTF-8
positron-server                    LANG=C.UTF-8
/init                              (illisible)
~~~

Aucun réglage `terminal.integrated.*` n'est défini, ni dans le profil Positron des dotfiles, ni dans `~/.positron-server/data/Machine/settings.json`. Le suspect est `terminal.integrated.detectLocale` à sa valeur par défaut, qui dérive `LANG` de la langue de l'interface. Hypothèse non vérifiée dans la documentation. Un shell WSL ouvert hors Positron, en `C.UTF-8`, n'aurait probablement pas eu ce défaut (non testé).

## Correctif

Nécessite `sudo`, donc noté ici et jamais rejoué par `verify`. Sortie non capturée.

~~~text
sudo apt install libuv1t64 libmagick++-6.q16-9t64
sudo locale-gen en_US.UTF-8 fr_FR.UTF-8
~~~

## Vérifications

Paquets installés et locales générées :

```bash
dpkg-query -W -f='${Package} ${db:Status-Status}\n' libuv1t64 libmagick++-6.q16-9t64; locale -a | rg -i 'en_US|fr_FR'; cat /etc/default/locale
```

```output
libmagick++-6.q16-9t64 installed
libuv1t64 installed
en_US.utf8
fr_FR.utf8
LANG=C.UTF-8
```

Bibliothèques partagées résolues pour les deux binaires (nombre de manques hors libR.so) :

```bash
L=/home/julien/Documents/services/md-nesrine/rv/library/4.6/x86_64/noble; for s in "$L"/fs/libs/fs.so "$L"/magick/libs/magick.so; do printf '%s: ' "$(basename "$s")"; ldd "$s" | awk '/not found/ && !/libR.so/ {n++} END {print n+0, "missing"}'; done
```

```output
fs.so: 0 missing
magick.so: 0 missing
```

Synchronisation du projet, qui doit sortir en 0 :

```bash
cd /home/julien/Documents/services/md-nesrine && rv sync >/dev/null 2>&1; echo "exit=$?"
```

```output
exit=0
```

Chargement des paquets, locale UTF-8, et absence de libellés hebstr compilés en <U+XXXX> (si hebstr avait été installé sous la locale C, il faudrait le réinstaller) :

```bash
cd /home/julien/Documents/services/md-nesrine && Rscript -e 'cat(Sys.getlocale("LC_CTYPE"), "\n"); for (p in c("fs","magick","hebstr","chromote")) cat(p, requireNamespace(p, quietly = TRUE), "\n"); ns <- asNamespace("hebstr"); txt <- unlist(lapply(ls(ns, all.names = TRUE), function(f) { o <- get(f, ns); if (is.function(o)) deparse(o) })); cat("escapes:", sum(grepl("<U\\+[0-9A-F]{4}>", txt)), "\n")' 2>&1
```

```output
en_US.UTF-8 
fs TRUE 
magick TRUE 
hebstr TRUE 
chromote TRUE 
escapes: 0 
```

## Reste à faire

Chromium, dont `hebstr::easy_out()` a besoin via webshot2/chromote pour capturer les tableaux au rendu (pas à l'installation). Non installé à la date de cette note. Sur 24.04, le paquet apt `chromium` n'est qu'une transition vers le snap :

~~~text
sudo snap install chromium
~~~

Avant le premier rendu du projet : une authentification `googlesheets4` interactive (pas de `~/.cache/gargle` sur la machine), à faire dans une session Positron et non pendant un rendu.

## Écarts avec wsl-init-tuto.md

- **Étape 2** : la locale y est « optionnelle » et seule `fr_FR.UTF-8` est générée. Le terminal intégré de Positron réclame `en_US.UTF-8`, qu'il faut donc générer aussi.
- **Étape 3** : elle couvre les en-têtes `-dev` des paquets R qui compilent, pas les bibliothèques d'exécution des binaires PPM. `libuv1t64` et `libmagick++-6.q16-9t64` manquent pour ce projet. La liste dépend des paquets du projet : le scan `ldd` ci-dessus la redonne sur n'importe quel projet.
- **Chromium** n'y figure pas, alors que hebstr en dépend au rendu.

Mise à jour du 2026-09-13 : les trois écarts ci-dessus (locale `en_US.UTF-8`, bibliothèques d'exécution des binaires PPM, Chromium) sont intégrés à `wsl-init-tuto.md`, sections 2 et 9. Cette trace reste la preuve du correctif.
