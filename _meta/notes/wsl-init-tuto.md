# WSL Ubuntu : installation reproductible

Procédure complète pour transformer une distribution Ubuntu 24.04 vierge sous WSL 2 en poste de travail équivalent à la machine principale.
Synthèse de la note initiale, de l'installation de `ju-TP2` le 2026-09-13 et de la trace `wsl-r-binary-runtime-deps.md` (showboat, bibliothèques R et locale).
Les comportements de scripts cités ici ont été relus dans `bin/.local/bin` le 2026-09-13.

## Conventions

- `<user>` : utilisateur Linux créé au premier lancement.
- `<user_windows>` : utilisateur Windows.
- `<distro>` : nom de la distribution (`Ubuntu-24.04`).
- **PowerShell** : commande à lancer côté Windows. Sans mention, la commande se lance dans un terminal WSL.
- Toute commande contenant `sudo` ou une connexion interactive (`gh auth login`) se lance dans un vrai terminal, pas depuis un agent.
- Les dotfiles arrivent par Syncthing en réception seule (« Receive Only »), jamais par `git clone`. Git se pratique sur la machine principale.
- L'ordre est obligatoire : chaque section fournit ce que la suivante suppose présent.

Deux instances Syncthing cohabitent, chacune sur le système de fichiers qu'elle lit nativement :

| Instance | Dossiers | Interface | Synchro |
|---|---|---|---|
| Syncthing Windows | dossiers sur `C:` | `127.0.0.1:8384` | `22000` |
| Syncthing WSL | `dotfiles` et dossiers sous `/home/<user>` | `127.0.0.1:8385` | `22001` |

Un même dossier n'est jamais partagé par les deux instances de la machine.
Syncthing Windows vers `\\wsl.localhost\...` perd les liens symboliques et le bit d'exécution ; Syncthing WSL vers `/mnt/c/...` ne reçoit aucun événement de modification des applications Windows, et NTFS ignore la casse.

Hors périmètre : Positron, Anki, LibreOffice, Firefox et Syncthing Windows, qui tournent côté Windows.

Valeurs de référence sur `ju-TP2` :

| Élément | Valeur |
|---|---|
| Windows | 11 24H2 (build 26100), WSL 2.7.14.0 |
| Distribution | Ubuntu 24.04.5 LTS, systemd actif |
| Syncthing | 2.1.5 des deux côtés |
| R | 4.6.1 via `rig`, dépôt PPM `__linux__/noble` |

## 0. Windows

PowerShell :

```powershell
wsl --update
wsl --list --online
wsl --install <distro>
wsl --list --verbose
```

- Choisir une LTS : une version non-LTS en fin de vie renvoie des 404 sur `apt install`.
- `wsl --list --verbose` doit afficher `VERSION 2`.
- Le nom d'utilisateur créé au premier lancement est `<user>`.

Pour que les autres appareils joignent Syncthing WSL en direct plutôt que par relais, et obligatoire pour l'accès SSH par le réseau local (`.claude/DESIGN-SSH.md`, traces `_meta/notes/ssh-lan-mdns.md` et `ssh-lan-wsl.md`) : `C:\Users\<user_windows>\.wslconfig`.

```ini
[wsl2]
networkingMode=mirrored
```

Exige Windows 11 22H2 ou plus. Appliquer avec `wsl --shutdown`.

## 1. apt

```bash
sudo apt update
sudo apt full-upgrade -y
```

`apt update` est obligatoire avant le premier `apt install` : l'index livré avec l'image est périmé et produit des `404 Not Found`.
Lire la sortie, pas seulement le code de retour : une ligne `Err:` ou `W:` signale un index resté périmé.
`Release file ... is not valid yet` signale une horloge dérivée, fréquente après une veille de Windows : `wsl --shutdown` côté PowerShell, puis relancer.

## 2. Distribution

### wsl.conf

```bash
sudoedit /etc/wsl.conf
```

```ini
[boot]
systemd=true

[user]
default=<user>
```

PowerShell, puis attendre environ 8 secondes avant de rouvrir Ubuntu :

```powershell
wsl --shutdown
```

```bash
systemctl is-system-running
```

`running` ou `degraded` : systemd tourne.
Le fuseau horaire suit Windows par défaut (`[time] useWindowsTimezone = true`), rien à régler.

### Locales

```bash
sudo locale-gen en_US.UTF-8 fr_FR.UTF-8
locale -a | rg -i 'en_US|fr_FR'
```

`en_US.UTF-8` n'est pas optionnelle : le terminal intégré de Positron exporte `LANG=en_US.UTF-8` alors que le système reste en `C.UTF-8`, et R retombe en locale `C` si elle n'est pas générée.
Symptôme : `Setting LC_CTYPE failed, using "C"` au démarrage de R, `unable to translate '<U+00E9>...' to native encoding` à l'installation d'un paquet.

### Linger

```bash
sudo loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger
```

Attendu : `Linger=yes`.
Sans linger, le gestionnaire systemd utilisateur s'arrête peu après la fermeture de la dernière session et emporte Syncthing et toute unité utilisateur, dont un build lancé par `systemd-run --user`.
La VM elle-même peut encore s'arrêter après inactivité (`vmIdleTimeout`, 60 000 ms par défaut dans `.wslconfig`) : si Syncthing WSL ne tourne que terminal ouvert malgré linger, c'est la piste.

## 3. Paquets de base

```bash
sudo apt install -y \
  build-essential ca-certificates curl wget gnupg unzip git \
  stow ripgrep fd-find jq shellcheck shfmt bats git-delta \
  libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
  libharfbuzz-dev libfribidi-dev libfreetype-dev libpng-dev libtiff-dev libjpeg-dev
```

- Ligne 2 : outils supposés présents par les dotfiles et `bin`. `fd-find` installe le binaire `fdfind`.
- `git-delta` : requis avant `stow git`, car `.gitconfig` déclare `core.pager = delta` et `interactive.diffFilter = delta --color-only`. Sans lui, `git diff`, `git log -p` et `git add -p` échouent.
- Lignes 3 et 4 : en-têtes des paquets R qui compilent encore malgré les binaires PPM. Les bibliothèques d'exécution des binaires sont traitées à la section 9.
- Ubuntu 24.04 fige `shellcheck` en 0.9.0 et `shfmt` en 3.8.0, derrière les versions épinglées par les hooks prek.

## 4. Syncthing WSL

### Installation

`syncthing-update` configure exactement ce dépôt, mais n'arrive qu'avec `stow bin` : première installation à la main.

```bash
sudo mkdir -p /etc/apt/keyrings
sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list
printf "Package: *\nPin: origin apt.syncthing.net\nPin-Priority: 990\n" | sudo tee /etc/apt/preferences.d/syncthing.pref
sudo apt-get update
sudo apt-get install -y syncthing
syncthing --version
```

Le pin fait passer apt.syncthing.net avant le paquet 1.27 d'Ubuntu ; toutes les machines restent en v2.
Si le paquet d'Ubuntu a été installé avant ce dépôt, supprimer le lien d'unité qu'il laisse :

```bash
sudo rm -f /etc/systemd/system/sleep.target.wants/syncthing-resume.service
```

### Service et ports

```bash
syncthing generate
systemctl --user enable --now syncthing
syncthing cli config gui raw-address set 127.0.0.1:8385
syncthing cli config options raw-listen-addresses 0 set tcp://0.0.0.0:22001
syncthing cli config options raw-listen-addresses add quic://0.0.0.0:22001
syncthing cli config folders default delete
systemctl --user restart syncthing
syncthing device-id
```

- WSL partage ses ports avec Windows (renvoi de `localhost` en NAT, même réseau en `mirrored`) : sans ports distincts, le navigateur Windows n'atteint jamais l'interface WSL.
- `folders default delete` retire le dossier `~/Sync` créé par défaut.
- Après le premier `wsl --shutdown`, contrôler que `systemctl --user is-enabled syncthing` répond `enabled` : le 2026-09-19, l'unité était `disabled` sur `ju-TP2` et Syncthing n'est pas revenu au redémarrage.
- Syntaxe vérifiée sur Syncthing 2.1.5 ; sinon, même réglage dans l'interface (Settings > GUI, Connections > Sync Protocol Listen Addresses).
- Syncthing se lance **uniquement** par systemd. Taper `syncthing` seul démarre une seconde instance qui prend le verrou, et le service échoue en boucle (`Failed to acquire lock`).
- En mode `mirrored`, si les appareils ne se trouvent pas sur le réseau local : `syncthing cli config options local-ann-enabled set false`.

Contrôle :

```bash
systemctl --user is-active syncthing
for p in $(pgrep -x syncthing); do printf '%s ' "$p"; cut -d: -f3 "/proc/$p/cgroup"; done
```

Attendu : `active`, deux processus (parent et enfant) tous deux dans `.../app.slice/syncthing.service`.
Un processus hors de ce cgroup est une instance lancée à la main : `kill <pid>`, puis `systemctl --user reset-failed syncthing && systemctl --user start syncthing`.

Interface WSL depuis le navigateur Windows : <http://127.0.0.1:8385>.

### Appairage et dossier `dotfiles`

Syncthing ne transmet jamais un `.stignore`, et celui de `~/dotfiles` n'est pas dans le paquet `syncthing` (stow refuse de lier dans son propre répertoire).
Le créer **avant** d'accepter le dossier, sinon `.git` et `node_modules` arrivent avec le reste :

```bash
mkdir -p ~/dotfiles
cat > ~/dotfiles/.stignore <<'EOF'
// Secrets
.env

// Artefacts dev
.git
.venv
node_modules
(?d)__pycache__
(?d)*.pyc
(?d).ruff_cache
(?d).pytest_cache
settings.local.json

// Verrous bureautiques
(?d)~$*
(?d).~lock.*#

// OS
(?d).DS_Store
(?d)._*
(?d)(?i)thumbs.db
(?d)(?i)desktop.ini
(?d).directory
(?d).Trash-*

// Editeurs
(?d)*.swp
(?d)*.swo
(?d)*~
EOF
```

Contenu copié du `~/dotfiles/.stignore` de la machine principale le 2026-09-13 ; le comparer à la version courante avant usage.

1. Sur la machine principale : ajouter le Device ID de WSL, puis partager `dotfiles`.
2. Dans l'interface WSL : accepter `dotfiles` en **Receive Only**, chemin `/home/<user>/dotfiles`.
3. Inscrire l'appareil dans la table de `syncthing-state.md`.
4. Attendre la fin de la synchro, puis contrôler le bit d'exécution : `ls -l ~/dotfiles/bin/.local/bin`.

Les autres dossiers Linux s'acceptent à la section 5, une fois leurs `.stignore` liés par stow.

## 5. Stow

### Préparer

Une distribution neuve contient déjà `~/.bashrc`, `~/.profile` et `~/.bash_logout`, que stow refuse d'écraser.

```bash
mkdir -p ~/dotfiles-backup
mv ~/.bashrc ~/.profile ~/.bash_logout ~/dotfiles-backup/
```

Ne jamais utiliser `--adopt`, qui copie le fichier local dans le paquet par-dessus la version synchronisée.

### Paquets

| Paquet | Commande | Raison |
|---|---|---|
| `bash`, `git`, `R`, `air`, `ruff`, `panache`, `prek`, `gh`, `bin`, `claude`, `ssh` | `stow --no-folding` | un dossier absent deviendrait un lien vers le dépôt, et tout ce que les programmes y écrivent (jeton `gh`, sessions Claude Code, `.credentials.json`, clés `~/.ssh/id_*`) atterrirait dans `~/dotfiles` |
| `agents` | `stow` (replié) | `~/.agents` doit rester un lien unique pour que l'installateur de skills écrive dans le dépôt |
| `syncthing` | `stow --no-folding`, en excluant les dossiers non synchronisés | sinon stow crée des dossiers vides juste pour y poser un `.stignore` |
| `css` | `stow` (replié), section 7 | les liens de `~/.local/bin` passent par `~/.local/share/css-gate/node_modules` : replié, ce dossier suit ce que `npm ci` et `sys-update css-toolchain` installent dans le dépôt ; en `--no-folding`, chaque fichier serait lié un par un et ceux qu'ajoute une mise à jour ne le seraient pas |
| `positron`, `firefox`, `obsidian`, `Rstudio` | aucun | applications côté Windows, profils propres à la machine principale, ou non utilisés |

Test à blanc, puis application :

```bash
cd ~/dotfiles
stow -n -v --no-folding --ignore='\.ruff_cache' bash git R air ruff panache prek gh bin claude ssh
stow -n -v agents
stow -n -v --no-folding --ignore='Musique' --ignore='Téléchargements' syncthing

stow -v --no-folding --ignore='\.ruff_cache' bash git R air ruff panache prek gh bin claude ssh
stow -v agents
stow -v --no-folding --ignore='Musique' --ignore='Téléchargements' syncthing
exec bash -l
```

- `--ignore='\.ruff_cache'` : un cache ruff arrivé dans `bin/.local/bin` serait lié dans `~/.local/bin`.
- `--ignore` sur `syncthing` : adapter la liste aux dossiers que WSL ne synchronise pas (le paquet porte `.claude`, `Documents`, `admin`, `archive`, `notes`, `Musique`, `Téléchargements`).
- `~/.secrets`, sourcé par `.bashrc`, n'est ni versionné ni synchronisé : à recréer à la main.

Contrôle :

```bash
readlink -e ~/.bashrc ~/.gitconfig
symlinks-check && echo "aucun lien cassé"
for f in .claude Documents admin archive notes; do readlink -e ~/"$f"/.stignore; done
```

Attendu : chemins sous `~/dotfiles/`, aucune ligne `BROKEN:`, chaque `.stignore` résolu sous `~/dotfiles/syncthing/`.

### Autres dossiers

Dans l'interface WSL, accepter chaque dossier partagé en **Receive Only**, chemin `/home/<user>/<dossier>` (`~/.claude` pour `claude`).
Pour créer un dossier depuis WSL plutôt que l'accepter, `st-add-folder` vise par défaut l'interface Windows : toujours le préfixer, `ST_URL=http://127.0.0.1:8385 st-add-folder <chemin>`.

Contrôle des motifs chargés :

```bash
K=$(syncthing cli config gui apikey get); U=http://127.0.0.1:8385
for f in claude Documents admin archive dotfiles notes; do
  printf '%-10s ' "$f"
  curl -s -H "X-API-Key: $K" "$U/rest/db/ignores?folder=$f" | jq -c '{n: (.ignore // [] | length), error}' | tr -d '\n'
  curl -s -H "X-API-Key: $K" "$U/rest/db/status?folder=$f" | jq -c '{state, ignorePatterns, receiveOnlyChangedFiles}'
done
```

Attendu : `n` non nul, `ignorePatterns: true`.
Un changement de cible d'un lien `.stignore` n'est pas vu par le surveillant de fichiers : forcer un rescan complet, `curl -s -X POST -H "X-API-Key: $K" "$U/rest/db/scan"`.

Règles de syntaxe :

- `.git/` (barre finale) exclut le contenu, pas le dossier : des dossiers vides apparaissent. Écrire `.git`.
- `(?d)` autorise Syncthing à supprimer ces fichiers quand ils bloquent la suppression d'un dossier.
- Un dossier en pause renvoie un statut vide : l'indicateur disparaît alors que les motifs sont chargés.

## 6. GitHub CLI

Presque tous les scripts `*-update` interrogent l'API GitHub via `gh`.

```bash
gh-update
gh auth login
gh auth status
```

- `gh-update` installe le `.deb` de la release `cli/cli` après contrôle sha256 et passe par `curl` et `jq`, pas par `gh` : il sert aussi à la première installation. Pas de dépôt apt, dont la clé a expiré en place le 2026-09-05.
- Le jeton va dans `~/.config/gh/hosts.yml`, fichier réel grâce à `--no-folding`, donc hors du dossier synchronisé.
- `gh auth login` réécrit `~/.config/gh/config.yml` à travers le lien stow : Syncthing signale une modification locale sur `dotfiles`. Faire « Revert Local Changes ».
- Avec le protocole SSH, `gh auth login` génère `~/.ssh/id_ed25519` et l'ajoute au compte. Contrôle : `ssh -T git@github.com` (code de sortie 1 attendu).

## 7. Toolchain

`sys-update` met à jour et n'installe presque rien : première installation à la main, dans cet ordre.

### Binaires cargo-dist

```bash
devtools-update --all
```

Installe `uv`, `uvx`, `ruff`, `air`, `jarl`, `prek` dans `/usr/local/bin`. Requiert `gh`.

### Rust et crates

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
exec bash -l
cargo install cargo-update
```

- `--no-modify-path` : `~/.profile` et `~/.bashrc` sont des liens stow et sourcent déjà `~/.cargo/env`. Sans l'option, rustup écrirait dans `~/dotfiles`.
- `cargo-update` fournit `cargo install-update`, sans lequel le module `cargo` de `sys-update` est ignoré.

Crates, avec parallélisme et mémoire bornés :

```bash
for c in typstyle shellharden panache bacon pdf-inspector filter-repo-rs; do
  systemd-run --user --wait --collect -p MemoryMax=8G -p MemorySwapMax=0 \
    -p "Environment=PATH=$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin" \
    -p Environment=CARGO_BUILD_JOBS=4 "$HOME/.cargo/bin/cargo" install "$c"
done
systemd-run --user --wait --collect -p MemoryMax=8G -p MemorySwapMax=0 \
  -p "Environment=PATH=$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin" \
  -p Environment=CARGO_BUILD_JOBS=4 -p Environment=GGSQL_SKIP_GENERATE=1 \
  "$HOME/.cargo/bin/cargo" install ggsql-cli
```

- Par défaut, cargo lance un `rustc` par cœur. Dans la mémoire allouée à WSL (moitié de la RAM Windows par défaut), cela déclenche l'OOM killer, qui tue Syncthing, le gestionnaire utilisateur et la session. `CARGO_BUILD_JOBS=4` et `MemoryMax=8G` confinent le build ; baisser les deux si la machine a moins de 32 Go.
- `GGSQL_SKIP_GENERATE=1` : sans lui, `tree-sitter-ggsql` exige `tree-sitter-cli`.
- `systemd-run --user` : le build survit à la fermeture du terminal, avec linger.

Contrôle :

```bash
for b in typstyle shellharden panache bacon detect-pdf pdf2md filter-repo-rs ggsql; do printf '%-15s %s\n' "$b" "$(command -v "$b" || echo ABSENT)"; done
journalctl -k | rg 'Out of memory'
```

Attendu : aucun `ABSENT`, aucune ligne OOM.
`detect-pdf` et `pdf2md` sortent en 1 sans argument : message d'usage, pas une panne.

### Node et gate CSS

```bash
curl -fsSL https://deb.nodesource.com/setup_24.x -o /tmp/nodesource_setup.sh
sudo -E bash /tmp/nodesource_setup.sh
sudo apt install -y nodejs
npm config set prefix "$HOME/.npm-global"
npm --prefix ~/dotfiles/css/.local/share/css-gate ci
cd ~/dotfiles && stow -v css
stylelint --version && prettier --version
```

- 24.x est la version de la machine principale ; remplacer par la LTS courante.
- Le `.stignore` de `~/dotfiles` exclut `node_modules` : `npm ci` est nécessaire et ne crée pas de modification locale.
- Le préfixe utilisateur est obligatoire : sans lui, les globaux sont ceux de `/usr`, qui appartiennent au paquet `nodejs`, et `sys-update npm` échoue en `EACCES` dès que npm publie une version plus récente que celle du paquet. `npm config set` écrit `~/.npmrc` hors des dotfiles, jamais stowé puisque `npm login` y dépose ses jetons ; `bash/.profile` ajoute `~/.npm-global/bin` au `PATH`. Appliqué sur `ju-TP2` le 2026-09-19.

### Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude-plugins-install
```

Le `.stignore` de `~/.claude` exclut `plugins/marketplaces` et `plugins/installed_plugins.json` : les plugins ne viennent pas par Syncthing.
`claude-plugins-install` lit l'état voulu dans `~/.claude/settings.json` et requiert `claude` et `jq`.

### R

```bash
rig-update
sudo rig add release
stow-rprofile
rv-update
Rscript -e 'cat(getOption("repos"), "\n")'
```

Attendu : `https://packagemanager.posit.co/cran/__linux__/noble/latest`.
Sans `stow-rprofile`, `repos` reste `@CRAN@` et tout paquet compile depuis les sources.

### Quarto

```bash
quarto-update
env -i HOME="$HOME" TERM=dumb bash -lic 'command -v quarto; quarto --version'
```

Attendu : `/usr/local/bin/quarto`.
`quarto-update` installe dans `/opt/quarto` et crée le lien `/usr/local/bin/quarto` s'il manque ; il lit la version installée dans `/opt/quarto`, pas sur le PATH.
Le `quarto` de `~/.positron-server/.../quarto/bin`, visible dans le terminal intégré de Positron, est la copie embarquée par Positron, pas une installation.

### Pandoc, DuckDB, Lua

```bash
pandoc-update
duckdb-update
lua-toolchain-update
```

### Couche uv

```bash
uv python install 3.13 3.14
for t in showboat pyrefly "sqlfluff[rs]" ouroboros-ai huggingface-hub yt-dlp; do uv tool install "$t"; done
```

Liste reprise du `README.md` des dotfiles ; l'absence de manifeste versionné est suivie dans `.claude/DEFERRED.md`.

## 8. Positron (côté Windows)

- Positron Windows lit ses réglages dans `C:\Users\<user_windows>\AppData\Roaming\Positron\User\` (ou `...\User\profiles\<id>\`). Les liens créés depuis WSL n'y sont pas lus : le paquet `positron` ne se stow pas.
- Importer le profil de la machine principale depuis Positron, pas par copie de fichiers.
- Les réglages propres à WSL (chemins Linux) vont dans `~/.positron-server/data/Machine/settings.json`, prioritaire sur les réglages utilisateur en session distante. Exemple si le profil désigne une autre version de R :

```json
{
  "positron.r.customBinaries": ["/opt/R/4.6.1/bin/R"],
  "positron.r.interpreters.default": "/opt/R/4.6.1/bin/R"
}
```

- Polices référencées par le profil (Fira Code) : `fira-code-install` depuis WSL, qui installe `fonts-firacode` côté Linux et les polices par utilisateur côté Windows, avec leurs entrées de registre.
- Si Windows Terminal n'affiche pas Fira Code : les mainteneurs de Windows Terminal attribuent les polices par utilisateur invisibles à un bug du cache de polices de Windows, contourné en redémarrant le service `FontCache` ou en installant la police pour tous les utilisateurs.
- Profil Windows Terminal de la distribution (couleurs, curseur, Fira Code) : `_meta/profiles/wsl-terminal-ubuntu.json` est un fragment JSON, qui modifie le profil existant sans toucher au `settings.json` de Windows Terminal. Le copier depuis WSL, après `fira-code-install`, dans le dossier des fragments de l'utilisateur Windows :

```bash
fragments="$(wslpath -u "$(powershell.exe -NoProfile -NonInteractive -Command '$env:LOCALAPPDATA' | tr -d '\r')")/Microsoft/Windows Terminal/Fragments/dotfiles"
mkdir -p "$fragments"
cp ~/dotfiles/_meta/profiles/wsl-terminal-ubuntu.json "$fragments/"
```

- La clé `updates` désigne le profil par son GUID, qui ne se déduit pas du nom de la distribution : celui du fichier ne correspond pas au calcul documenté pour `Ubuntu-24.04`. Le relever dans le `settings.json` de Windows Terminal (entrée de la distribution sous `profiles.list`) et corriger le fragment s'il diffère.
- Le fragment est une copie : une modification dans `~/dotfiles` ne l'atteint qu'en relançant `cp`.

## 9. Premier projet R

PPM sert des binaires. Ils n'ont pas besoin des en-têtes `-dev` que liste `rv sysdeps`, mais des bibliothèques partagées à l'exécution, absentes d'une distribution neuve.
Symptôme typique au `rv sync` :

```text
unable to load shared object '.../fs/libs/fs.so':
  libuv.so.1: cannot open shared object file: No such file or directory
ERROR: lazy loading failed for package 'hebstr'
```

Le paquet nommé dans `lazy loading failed` n'est pas le coupable : c'est une de ses dépendances qui ne se charge pas.
Détection sur tout le cache rv, après un premier `rv sync` même en échec :

```bash
fdfind -t f -e so . ~/.cache/rv -x ldd {} 2>/dev/null | awk '/not found/ && !/libR\.so/ {print $1}' | sort -u
```

Correspondance relevée sur le projet de référence (`md-nesrine`) :

| Bibliothèque manquante | Paquet R | Paquet apt |
|---|---|---|
| `libuv.so.1` | `fs` | `libuv1t64` |
| `libMagick++-6.Q16.so.9`, `libMagickCore-6.Q16.so.7`, `libMagickWand-6.Q16.so.7` | `magick` | `libmagick++-6.q16-9t64` |

```bash
sudo apt install -y libuv1t64 libmagick++-6.q16-9t64
```

Pour une bibliothèque absente de ce tableau : `apt-file search <lib>.so` (après `sudo apt install apt-file && sudo apt-file update`).

Contrôle :

```bash
cd <projet> && rv sync; echo "exit=$?"
Rscript -e 'cat(Sys.getlocale("LC_CTYPE"), "\n")'
```

Attendu : `exit=0`, locale `en_US.UTF-8` depuis le terminal de Positron.
Un paquet installé pendant que la locale manquait garde des libellés en `<U+XXXX>` : le réinstaller.

Dépendances de rendu de `hebstr` (`easy_out()` capture les tableaux via webshot2 et chromote) :

```bash
sudo snap install chromium
```

Sur 24.04, le paquet apt `chromium` n'est qu'une transition vers le snap.
Authentification `googlesheets4` : interactive, dans une session Positron, avant le premier rendu.

## 10. Entretien

```bash
sys-update --dry-run
sys-update
sys-orphans
```

Sans argument, `sys-update` lance tous les modules.
Les modules `positron`, `anki`, `libreoffice` et `zotero` exigent que l'application soit déjà installée : dans WSL, ils sont ignorés (`skipped (<app> not installed)`), bien que `stow bin` y pose leurs scripts.
Le module `agent-skills` n'agit que là où git suit `~/dotfiles` : dans WSL, sans `.git`, il affiche `Skipped:` et le tableau le note `OK`, les skills arrivant par Syncthing depuis la machine principale.

`sys-orphans` ne supprime rien : il liste les reliquats et la commande de nettoyage de chacun.

Désinstallation, si un `sys-update` antérieur au 2026-09-14 a installé LibreOffice ou Anki dans WSL :

```bash
sudo apt purge -y 'libreoffice*' 'libobasis*'
sudo rm -rf /opt/libreoffice*
sudo rm -f /usr/local/bin/libreoffice
rm -rf ~/.config/libreoffice
sudo /usr/local/share/anki/uninstall.sh
zcat -f /var/log/apt/history.log* | rg -B3 '^Install:.*libxcb-xinerama0'
sudo apt purge -y libxcb-xinerama0 libxcb-cursor0 libnss3 zstd
sudo apt-mark auto libxcb-image0 libxcb-render-util0
sudo apt autoremove --purge -y
```

- Les paquets TDF forment deux familles, `libreoffice<branche>*` et `libobasis<branche>-*` : purger la seule première en laisse une trentaine.
- La ligne `zcat` confirme que `zstd` et `libnss3` viennent bien d'`anki-update` avant de les purger ; sinon, les retirer de la ligne suivante.

## 11. Vérification finale

```bash
env -i HOME="$HOME" TERM=dumb bash -lic 'for t in git gh delta uv ruff air jarl prek pyrefly sqlfluff showboat cargo panache typstyle ggsql node stylelint prettier R rig rv quarto pandoc duckdb stylua syncthing claude; do command -v "$t" >/dev/null || echo "ABSENT $t"; done'
locale -a | rg -i 'en_US|fr_FR'
loginctl show-user "$USER" -p Linger
systemctl --user is-active syncthing
cd ~/dotfiles
stow -n -v --no-folding --ignore='\.ruff_cache' bash git R air ruff panache prek gh bin claude ssh
stow -n -v agents css
stow -n -v --no-folding --ignore='Musique' --ignore='Téléchargements' syncthing
symlinks-check && echo "aucun lien cassé"
sys-orphans
```

Attendu : aucune ligne `ABSENT`, deux locales, `Linger=yes`, `active`, aucun conflit stow, aucun lien cassé, aucun orphelin.
Le shell `env -i` écarte le PATH hérité, notamment la copie de Quarto embarquée par Positron.

Pour garder une preuve de l'état obtenu, enregistrer ces contrôles en trace showboat **sur la machine WSL** (les commandes sont en lecture seule, donc rejouables par `showboat verify`) :

```bash
N=~/dotfiles/_meta/notes/wsl-<machine>-verify.md
showboat init "$N" "WSL <machine> : vérification finale"
showboat exec "$N" bash 'for t in git gh uv R quarto syncthing claude; do command -v "$t" >/dev/null || echo "ABSENT $t"; done; echo fin'
showboat exec "$N" bash 'loginctl show-user "$USER" -p Linger; systemctl --user is-active syncthing'
showboat exec "$N" bash 'symlinks-check && echo "aucun lien cassé"'
```

Le fichier atterrit dans `~/dotfiles`, en réception seule : il apparaîtra en « Local Additions » jusqu'à ce qu'il soit rapatrié sur la machine principale.

## 12. Accès SSH

SSH par clé dans les deux sens entre la machine principale (`ju-TP`) et WSL (`ju-TP2`), avec des noms résolus par mDNS (`<hôte>.local`).
Conception et alternatives écartées : `.claude/DESIGN-SSH.md`. Traces : `ssh-lan-server.md` (serveur de la machine principale), `ssh-lan-mdns.md` (noms), `ssh-lan-wsl.md` (serveur WSL et maintien).
Les étapes se suivent dans l'ordre et chacune dit sur quelle machine elle se lance. Chaque machine a sa propre clé `~/.ssh/id_ed25519_lan`, dont la ligne publique va dans `~/.ssh/authorized_keys` de l'autre. Aucune clé n'entre dans les dotfiles : le paquet `ssh` ne porte que `~/.ssh/config`.

La première clé ne peut passer que par mot de passe : l'étape 1 laisse donc le mot de passe actif sur la machine principale, l'étape 2 y dépose la clé de WSL avec `ssh-copy-id`, et l'étape 3 coupe le mot de passe. La seconde clé passe ensuite par le lien déjà établi, sans copie à la main.

### Prérequis

- `networkingMode=mirrored` (section 0) et `stow ssh`, qui pose `~/.ssh/config` avec les alias `ju-TP` et `ju-TP2` : section 5 dans WSL, bootstrap du `README.md` sur la machine principale.
- Les alias distinguent la casse : taper `ju-TP2`, jamais `ju-tp2` que les messages d'erreur affichent. `ssh ju-tp2` ignore tout le bloc `Host ju-TP2` (port 22, aucune clé dédiée).
- **Les noms d'hôte** : tout repose sur `ju-TP.local` et `ju-TP2.local`. Sur la machine principale, `hostnamectl hostname` doit répondre `ju-TP` (sinon `sudo hostnamectl set-hostname ju-TP`). WSL prend le nom de l'ordinateur Windows, qu'un Windows réinstallé nomme `DESKTOP-XXXX` : PowerShell administrateur, `Rename-Computer -NewName ju-TP2`, redémarrage, puis `hostname` dans WSL doit répondre `ju-TP2`. Autres noms : adapter `HostName` et `HostKeyAlias` dans `ssh/.ssh/config`.
- **L'utilisateur** : `ssh/.ssh/config` écrit `User julien` pour les deux alias ; un autre nom d'utilisateur Linux impose d'y changer cette ligne.

### Étape 1. Machine principale : serveur, mot de passe encore permis

```bash
sudo apt install -y openssh-server libnss-mdns avahi-daemon
sudo install -d -m 0755 /etc/systemd/system/ssh.socket.d
printf '%s\n' '[Socket]' 'IPAddressDeny=any' 'IPAddressAllow=10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 localhost' \
  | sudo tee /etc/systemd/system/ssh.socket.d/10-lan-only.conf
sudo systemctl daemon-reload && sudo systemctl restart ssh.socket
systemctl show ssh.socket -p IPAddressAllow
ss -ltn '( sport = :22 )'
install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
ssh-keygen -t ed25519 -N '' -C "$USER@$(hostname) lan $(date +%F)" -f ~/.ssh/id_ed25519_lan
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

- `libnss-mdns` et `avahi-daemon` sont présents sur une Ubuntu de bureau, absents d'une installation minimale : sans eux, la machine principale ne résout pas `ju-TP2.local`.
- `10-lan-only.conf` : filtre posé par systemd sur le socket ; un paquet venu d'une adresse publique est jeté avant que `sshd` ne démarre. `ufw` est inactif sur cette machine, ce filtre est la seule restriction réseau. Il n'existe que tant que `sshd` démarre par `ssh.socket` : ne jamais activer `ssh.service` à sa place.
- Attendu : cinq plages dans `IPAddressAllow` (dont `127.0.0.0/8` et `::1/128`), l'écoute sur `0.0.0.0:22` et `[::]:22`, puis l'empreinte de la clé d'hôte : **la noter**, elle sert à l'étape 2.
- La clé `lan` de la machine principale est créée ici et ne sert qu'à partir de l'étape 4 (dépôt), puis de l'étape 6 (connexion). `ssh-keygen` demande avant d'écraser une clé existante : répondre `n` garde l'ancienne.

### Étape 2. WSL : noms, clé, premier contact

```bash
sudo apt install -y libnss-mdns
rg '^hosts:' /etc/nsswitch.conf
getent hosts ju-TP.local
ssh-keygen -t ed25519 -N '' -C "$USER@$(hostname) lan $(date +%F)" -f ~/.ssh/id_ed25519_lan
ssh-keyscan -t ed25519 ju-TP.local 2>/dev/null | ssh-keygen -lf -
ssh-copy-id -i ~/.ssh/id_ed25519_lan.pub -o BatchMode=no ju-TP
ssh ju-TP hostname
```

- Attendu : `hosts: files mdns4_minimal [NOTFOUND=return] dns`, l'adresse de la machine principale, puis une empreinte **identique** à celle notée à l'étape 1. Si elle diffère, s'arrêter là.
- `ssh-copy-id` passe par l'alias, donc par `HostKeyAlias` : il enregistre la clé d'hôte sous `ju-tp`, demande le mot de passe Linux de la machine principale une seule fois (`-o BatchMode=no` lève le `BatchMode yes` de l'alias), et ajoute la clé à son `authorized_keys`.
- `ssh ju-TP hostname` doit répondre `ju-TP` sans rien demander.
- Clé dédiée, distincte de l'`id_ed25519` enregistrée sur GitHub par `gh auth login`, sans phrase de passe pour que `BatchMode` fonctionne sans agent. La date dans le commentaire distingue une clé régénérée de l'ancienne.
- Si `ssh-keygen` demande `Overwrite (y/n)?`, une clé existe déjà : répondre `n`. Répondre `y` la remplace et coupe l'accès vers la machine principale, qui n'autorise que l'ancienne.
- Si `ssh-copy-id` s'arrête sur `REMOTE HOST IDENTIFICATION HAS CHANGED` : la machine principale a été réinstallée ; après avoir comparé l'empreinte, `ssh-keygen -R ju-tp` puis relancer.

### Étape 3. Machine principale : clé uniquement

```bash
printf '%s\n' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitRootLogin no' "AllowUsers $USER" \
  | sudo tee /etc/ssh/sshd_config.d/10-key-only.conf
sudo install -d -m 0755 /run/sshd
sudo sshd -t && sudo systemctl try-reload-or-restart ssh.service && echo config-ok
ssh -o BatchMode=yes -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null localhost true
```

- Attendu : `config-ok`, puis `Permission denied (publickey)`. Une réponse `(publickey,password)` signale que `sshd` tourne encore avec l'ancienne configuration.
- `ssh.socket` est en `Accept=no` : la première connexion démarre `ssh.service`, qui reste ensuite en démon permanent et ne relit sa configuration que sur `reload`. `try-reload-or-restart` recharge s'il tourne et ne fait rien sinon. Toute modification ultérieure de `sshd_config.d` demande la même commande.
- Le préfixe `10-` fait passer ce fichier avant un éventuel `50-cloud-init.conf`, car `sshd` garde la première valeur lue.
- Depuis WSL, `ssh ju-TP hostname` doit toujours répondre.

### Étape 4. WSL : serveur sur le port 2222

```bash
sudo apt install -y openssh-server
printf '%s\n' 'Port 2222' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitRootLogin no' "AllowUsers $USER" \
  | sudo tee /etc/ssh/sshd_config.d/10-key-only.conf
sudo install -d -m 0755 /run/sshd
sudo sshd -t && sudo systemctl daemon-reload && sudo systemctl restart ssh.socket
ss -ltn '( sport = :2222 )'
install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
k=$(ssh ju-TP cat .ssh/id_ed25519_lan.pub) && { grep -qxF "$k" ~/.ssh/authorized_keys || printf '%s\n' "$k" >> ~/.ssh/authorized_keys; }
ssh-keygen -lf ~/.ssh/authorized_keys
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

- Port 2222 : en `mirrored`, WSL partage l'espace de ports de Windows.
- `sshd` démarre à la demande via `ssh.socket`, dont le générateur lit le port dans `sshd_config.d` : d'où `daemon-reload` avant le redémarrage du socket.
- `/run/sshd` n'existe qu'après une première connexion (`RuntimeDirectory=sshd` de `ssh.service`) ; sans lui, `sshd -t` échoue avec `Missing privilege separation directory`. Le créer à la main ne sert qu'au contrôle.
- La clé de la machine principale arrive par le lien de l'étape 2. Attendu : `ssh-keygen -lf ~/.ssh/authorized_keys` liste une ligne `<user>@ju-TP lan`, puis l'empreinte de la clé d'hôte de WSL : **la noter**, elle sert à l'étape 6.

### Étape 5. Windows : pare-feu Hyper-V et maintien de WSL

PowerShell **administrateur**. La politique entrante de WSL est `Block` : sans la règle, la connexion depuis la machine principale expire.

```powershell
if (-not (Get-NetFirewallHyperVRule -Name WSL-SSH-2222 -ErrorAction SilentlyContinue)) {
  New-NetFirewallHyperVRule -Name WSL-SSH-2222 -DisplayName WSL-SSH-2222 -Direction Inbound -Action Allow -Protocol TCP -LocalPorts 2222 -RemoteAddresses 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16 -VMCreatorId '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'
}
Get-NetFirewallHyperVRule -Name WSL-SSH-2222
```

Le `if` rend le bloc rejouable : une règle déjà présente (Windows conservé, WSL seul réinstallé) est gardée telle quelle.

Un reset du pare-feu Hyper-V supprime cette règle et coupe l'accès sans message.

Sans session ouverte, Windows arrête la VM, et `ju-TP2` devient injoignable. Tâche planifiée au démarrage, dans la même fenêtre ; remplacer `<distro>` par le nom que donne `wsl -l -q`, et `<user_windows>` par la partie après la barre oblique inverse de `whoami` lancé dans un PowerShell **ordinaire** : le compte qui ouvre la session et possède la distribution, pas celui qui a élevé la fenêtre administrateur (sur `ju-TP2`, `whoami` répond `ju-tp2\julien`) :

```powershell
$a = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\wsl.exe" -Argument '-d <distro> --exec sleep infinity'
$t = New-ScheduledTaskTrigger -AtStartup
$p = New-ScheduledTaskPrincipal -UserId <user_windows> -LogonType S4U -RunLevel Limited
$s = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName WSL-KeepAlive -Action $a -Trigger $t -Principal $p -Settings $s -Force
Start-ScheduledTask -TaskName WSL-KeepAlive
Get-ScheduledTaskInfo -TaskName WSL-KeepAlive
```

- S4U : la tâche tourne sous l'utilisateur sans stocker de mot de passe. `LastTaskResult` `267009` (`0x41301`) signifie « en cours ».
- Sur `ju-TP2` : `<distro>` vaut `Ubuntu-24.04`, `<user_windows>` vaut `julien`.
- Tout `wsl --shutdown` (sections 0, 1 et 2) arrête aussi `sleep infinity`, et la tâche ne repart qu'au démarrage suivant : relancer `Start-ScheduledTask -TaskName WSL-KeepAlive` après chaque `wsl --shutdown`.
- `vmIdleTimeout=-1` dans `.wslconfig` est signalé peu fiable, d'où la tâche.
- Ces commandes, et celle de la règle Hyper-V, sont reconstruites et non copiées de l'exécution ; leur résultat a été comparé paramètre par paramètre à la tâche et à la règle en place sur `ju-TP2` le 2026-09-19. Relire `Get-ScheduledTask -TaskName WSL-KeepAlive` après création.
- Depuis la machine principale, ces objets Windows se lisent par `ssh ju-TP2`, avec le chemin complet `/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe` : une session SSH non interactive n'a pas `powershell.exe` dans son `PATH`.
- Test réel : redémarrer Windows sans ouvrir de terminal WSL, puis `ssh ju-TP2 hostname` depuis la machine principale. Avec l'ouverture de session automatique, ce test ne distingue pas le déclencheur « au démarrage » de l'ouverture de session.

### Étape 6. Machine principale : vérification

```bash
ssh-keyscan -t ed25519 -p 2222 ju-TP2.local 2>/dev/null | ssh-keygen -lf -
ssh ju-TP2 hostname
ssh -o BatchMode=yes -o PubkeyAuthentication=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 ju-TP2.local true
```

Attendu, dans l'ordre : l'empreinte notée à l'étape 4 (sinon, s'arrêter avant la ligne suivante, qui l'enregistre), `ju-TP2`, puis `Permission denied (publickey)`.
Les options `StrictHostKeyChecking=no` et `UserKnownHostsFile=/dev/null` ne servent qu'au contrôle du refus : sans elles, `ju-TP2.local:2222` n'est pas connu sous ce nom, et `BatchMode` répond `Host key verification failed` avant même de tester le mot de passe.

Commande PowerShell administrateur lancée **depuis un agent** : passer par `-EncodedCommand`. Le 2026-09-19, un `Start-Process` sans guillemets a créé la règle Hyper-V ouverte à `Any` pendant environ deux minutes.

### Usages

Chaque exemple se lance **depuis** une machine **vers** l'autre : depuis la machine principale avec `ju-TP2`, depuis WSL avec `ju-TP`. Viser la machine sur laquelle on se trouve répond `Permission denied (publickey)`, puisque seule la clé de l'autre y est autorisée ; ce refus est normal.

**Commande à distance.** La commande entre guillemets s'exécute sur l'autre machine et sa sortie s'affiche localement ; sans commande, `ssh ju-TP2` ouvre un terminal distant, fermé par `exit`.

```bash
ssh ju-TP2 'df -h ~'
ssh ju-TP2 'bash -lc "sys-update --dry-run"'
```

Une commande non interactive ne lit pas `.profile`, donc `~/.local/bin` (les scripts des dotfiles) manque au `PATH` : `bash -lc "..."` ouvre un shell de connexion qui le charge. Les commandes système (`df`, `npm`, `systemctl`) s'en passent.

**Copie de fichiers hors Syncthing.** Pour ce qu'aucun dossier synchronisé ne porte, ou dans le sens WSL vers la machine principale, que les dossiers en réception seule ne remontent jamais :

```bash
scp ju-TP2:~/projet/rapport.pdf .
rsync -av ju-TP2:~/projet/sorties/ ~/projet/sorties/
```

`scp` copie un fichier ; `rsync` synchronise un dossier et ne transfère que ce qui a changé. Le préfixe `ju-TP2:` désigne l'autre machine. Ne jamais copier ainsi **dans** `~/dotfiles` ou `~/.claude` de WSL, en réception seule.

**Page web de l'autre machine dans le navigateur local** (transfert de port). Une interface qui n'écoute que sur `localhost` de l'autre machine, comme Syncthing (`8385` dans WSL), Streamlit (`8501`) ou `quarto preview`, devient accessible localement :

```bash
ssh -N -L 8385:127.0.0.1:8385 ju-TP2
```

Ouvrir ensuite `http://localhost:8385` sur la machine principale. Le tunnel dure tant que la commande tourne ; `Ctrl+C` le ferme. Si le port local est déjà pris (le Syncthing local écoute sur `8384`, pas `8385`), choisir un autre numéro à gauche : `-L 9385:127.0.0.1:8385`.

**Calcul long qui survit à la déconnexion.**

```bash
ssh ju-TP2 'systemd-run --user --unit=calcul Rscript ~/projet/modele.R'
ssh ju-TP2 'journalctl --user -u calcul -f'
```

Le calcul continue si la connexion se ferme ou si la machine principale se met en veille (linger, section 2). La seconde ligne suit sa sortie ; `Ctrl+C` arrête le suivi, pas le calcul.

**Dépôt git échangé sans GitHub**, pour un projet privé :

```bash
git clone ju-TP:~/projets/mon-projet
```

Les deux copies s'échangent ensuite les commits par `git pull` et `git push` vers cette adresse. Pousser vers une branche **extraite** sur l'autre machine est refusé par défaut : pousser une autre branche, puis la fusionner sur place.

Limites communes : les deux machines sur le même réseau et éveillées ; Windows en veille rend WSL injoignable.

### Reprise : une seule machine réinstallée

L'autre machine garde sa configuration, mais ses fichiers `authorized_keys` et `known_hosts` pointent encore vers l'ancienne. Les listes ci-dessous **remplacent** l'enchaînement des étapes 1 à 6 : suivre la liste, qui renvoie à une étape seulement quand celle-ci s'applique telle quelle. Les deux sens étant coupés, chaque ligne se tape au clavier de la machine qu'elle nomme.

Dans les commandes, `julien` est le nom d'utilisateur Linux : un autre nom le remplace aussi dans les motifs `sed`, sinon ils ne retirent rien et l'ancienne clé reste autorisée.

**WSL réinstallé**, la machine principale intacte :

0. Si Windows est conservé, PowerShell administrateur **avant** de réinstaller la distribution : `Disable-ScheduledTask -TaskName WSL-KeepAlive`. Sinon la tâche tente de relancer la distribution pendant sa suppression ou avant la création de l'utilisateur.
1. Machine principale : repasser temporairement en mot de passe, retirer l'ancienne clé de WSL et son ancienne clé d'hôte, et relire l'empreinte à comparer.
   ```bash
   sudo mv /etc/ssh/sshd_config.d/10-key-only.conf /etc/ssh/10-key-only.conf.off && sudo systemctl try-reload-or-restart ssh.service
   ssh-keygen -lf ~/.ssh/authorized_keys
   sed -i '/ julien@ju-TP2 lan/d' ~/.ssh/authorized_keys
   ssh-keygen -lf ~/.ssh/authorized_keys
   ssh-keygen -R ju-tp2
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```
   Le `sed` retire toute ligne de WSL : il passe **avant** le dépôt de la nouvelle clé, jamais après. Les deux `ssh-keygen -lf` montrent ce qui part. La dernière ligne donne l'empreinte que l'étape 2 demande de comparer : **la noter**.
2. WSL : étape 2 complète.
3. Machine principale : remettre la clé seule, puis lancer le contrôle de l'étape 3 (`ssh ... localhost true`, qui doit répondre `Permission denied (publickey)`).
   ```bash
   sudo mv /etc/ssh/10-key-only.conf.off /etc/ssh/sshd_config.d/10-key-only.conf && sudo systemctl try-reload-or-restart ssh.service
   ```
4. WSL : étape 4 complète ; sa dernière ligne donne l'empreinte de la nouvelle clé d'hôte, à noter.
5. Windows : étape 5, rejouable telle quelle (la règle existante est gardée, `-Force` remplace la tâche), puis `Enable-ScheduledTask -TaskName WSL-KeepAlive` si l'étape 0 l'a désactivée.
6. Machine principale : étape 6, avec l'empreinte notée au point 4.

**Machine principale réinstallée**, WSL intact :

1. Machine principale : étape 1 complète (sa dernière ligne donne l'empreinte à noter).
2. WSL, à son clavier (le sens machine principale → WSL est coupé) : retirer l'ancienne clé et l'ancienne clé d'hôte, puis relire l'empreinte de WSL pour l'étape 6.
   ```bash
   sed -i '/ julien@ju-TP lan/d' ~/.ssh/authorized_keys
   ssh-keygen -R ju-tp
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
   ```
3. WSL : étape 2, sans les lignes `apt install` et `ssh-keygen -t` (déjà faites : répondre `n` si `ssh-keygen` le demande).
4. Machine principale : étape 3 complète.
5. WSL : de l'étape 4, seulement la ligne `k=$(ssh ju-TP cat ...)` et le `ssh-keygen -lf ~/.ssh/authorized_keys` qui la suit.
6. Machine principale : étape 6, avec l'empreinte notée au point 2.

Ces deux procédures, comme l'enchaînement mot de passe puis `ssh-copy-id` puis clé seule des étapes 1 à 3, ont été reconstruites et relues le 2026-09-19 (source de `ssh-copy-id`, unités systemd), pas encore exécutées : l'installation réelle a posé la clé seule d'abord et copié la clé de WSL à la main (trace `ssh-lan-server.md`).

## Pièges

### Syncthing

| Symptôme | Cause | Correctif |
|---|---|---|
| `syncthing.service` en échec, `Failed to acquire lock` | instance lancée à la main hors systemd | `kill <pid>`, `systemctl --user reset-failed syncthing && systemctl --user start syncthing` |
| l'interface `8384` affiche l'instance Windows | ports par défaut partagés avec Windows | ports `8385` et `22001` (section 4) |
| `st-add-folder` agit sur Syncthing Windows | `ST_URL` vaut `http://127.0.0.1:8384` par défaut | `ST_URL=http://127.0.0.1:8385 st-add-folder ...` |
| indicateur « Reduced by ignore patterns » absent | dossier en pause, statut vide | reprendre le dossier |
| dossier sans exclusion malgré un `.stignore` | fichier vide, copie au lieu du lien stow, ou pas de rescan depuis le changement de cible | lien stow, `readlink -e`, puis `POST /rest/db/scan` |
| dossiers vides `.git`, `.venv`, `.quarto` reçus | motifs terminés par `/` | écrire `.git` sans barre finale |
| modifications locales sur `.git/index` | `git status` réécrit l'index dans un dossier en réception seule | exclure `.git` dans `~/dotfiles/.stignore` |
| `git log` figé sur WSL | `.git` exclu : les commits ne transitent pas | git sur la machine principale |
| modifications locales sur un fichier lié (`config.yml`, `.Rprofile`) | un programme écrit à travers le lien stow | « Revert Local Changes » |
| modifications locales dans `~/.claude/projects/*/*/tool-results` | sorties de hooks des sessions Claude Code | exclure les dossiers de session `projects/*/????????-????-????-????-????????????` dans le `.stignore` de `claude` ; ne pas annuler pendant une session |
| Syncthing s'arrête terminaux fermés | linger désactivé, ou VM arrêtée par `vmIdleTimeout` | `sudo loginctl enable-linger "$USER"` |

Annuler les modifications locales sans l'interface :

```bash
K=$(syncthing cli config gui apikey get)
curl -s -X POST -H "X-API-Key: $K" "http://127.0.0.1:8385/rest/db/revert?folder=<id>"
```

### SSH

Diagnostic commun : `ssh -v <alias> true` montre où la connexion s'arrête (résolution, connexion TCP, clé d'hôte, authentification).

| Symptôme | Cause | Correctif |
|---|---|---|
| `REMOTE HOST IDENTIFICATION HAS CHANGED` ou `Host key verification failed` | machine réinstallée ou `openssh-server` réinstallé : nouvelle clé d'hôte, que `accept-new` refuse par principe | lire l'empreinte sur la machine (`ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`), puis `ssh-keygen -R ju-tp2` ou `ssh-keygen -R ju-tp` (le nom de `HostKeyAlias`, en minuscules) et se reconnecter |
| `Permission denied (publickey)` avec l'alias | clé `id_ed25519_lan` absente ou régénérée, ou sa ligne absente du `authorized_keys` de l'autre machine | voir la ligne « clé perdue » ci-dessous |
| machine réinstallée | les deux sens sont coupés | « Reprise : une seule machine réinstallée », fin de la section 12 |
| clé `lan` perdue sur une machine, l'autre sens fonctionne | la clé privée n'existe plus ; l'ancienne ligne publique reste autorisée sur l'autre machine | dans cet ordre. 1) Sur l'autre machine, retirer l'ancienne ligne **avant** tout dépôt : `ssh-keygen -lf ~/.ssh/authorized_keys` pour la voir, puis `sed -i '/ julien@ju-TP2 lan/d' ~/.ssh/authorized_keys` (clé de WSL perdue) ou `sed -i '/ julien@ju-TP lan/d' ~/.ssh/authorized_keys` (clé de la machine principale perdue). 2) Sur la machine touchée, régénérer avec la commande `ssh-keygen` de l'étape 1 ou 2. 3) Déposer la nouvelle par le sens qui marche : clé de WSL perdue, sur la machine principale `ssh ju-TP2 cat .ssh/id_ed25519_lan.pub >> ~/.ssh/authorized_keys` ; clé de la machine principale perdue, sur WSL `ssh ju-TP cat .ssh/id_ed25519_lan.pub >> ~/.ssh/authorized_keys`. Si aucun sens ne marche, suivre la ligne « machine réinstallée » |
| `Could not resolve hostname ju-tp2.local` ou `ju-tp.local` | `libnss-mdns` ou `avahi-daemon` absent, nom d'hôte différent (Windows renommé ou réinstallé), WSL revenu en NAT, ou réseau qui ne relaie pas le multicast | `getent hosts <nom>.local` ; `hostname` sur la machine visée (Prérequis) ; `wslinfo --networking-mode` doit répondre `mirrored` ; sur un réseau qui isole ses clients, mDNS et SSH direct sont impossibles, aucun repli n'est en place (Tailscale est la piste écartée dans `DESIGN-SSH.md`) |
| `ssh ju-TP2` expire, nom résolu | Windows en veille ou en veille prolongée ; WSL arrêté : tâche `WSL-KeepAlive` arrêtée après un `wsl --shutdown`, absente ou désactivée ; ou règle Hyper-V supprimée par une réinitialisation du pare-feu (Hyper-V ou Windows) | PowerShell : `Get-ScheduledTaskInfo -TaskName WSL-KeepAlive` ; tâche présente mais pas en cours (`LastTaskResult` autre que `267009`) : `Start-ScheduledTask -TaskName WSL-KeepAlive` ; `Get-NetFirewallHyperVRule -Name WSL-SSH-2222` ; recréer ce qui manque (étape 5) |
| `ssh ju-TP` ou `ssh ju-TP2` expire après un changement de hotspot | adresses IPv4 hors des trois plages privées, le plus souvent `100.64.0.0/10` (partage de connexion d'opérateur) : le filtre de la machine principale et la règle Hyper-V les rejettent tous deux | `ip -4 -br addr` sur les deux machines : la plage est l'adresse suivie de son `/<longueur>`, par exemple `100.72.3.14/24` donne `100.72.3.0/24` ; ajouter `100.64.0.0/10` en entier évite de recommencer au changement suivant. Machine principale : ajouter la plage à la ligne `IPAddressAllow` de `/etc/systemd/system/ssh.socket.d/10-lan-only.conf` (`sudoedit`), puis `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket`. Windows, PowerShell administrateur : `Set-NetFirewallHyperVRule -Name WSL-SSH-2222 -RemoteAddresses 10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,<plage>`. WARP, sur la machine principale, n'exclut du tunnel que les plages privées (`_meta/notes/warp-state.md`) : la nouvelle plage doit y être ajoutée aussi, par l'interface WARP (réglages, exclusions), aucune commande n'étant consignée. L'IPv6 n'entre pas en jeu : les noms se résolvent en IPv4 seulement (`mdns4_minimal`) |
| `ssh ju-TP` accepté depuis n'importe quel réseau | `ssh.service` activé à la place de `ssh.socket` : le filtre ne s'applique plus | `sudo systemctl disable --now ssh.service && sudo systemctl enable --now ssh.socket` |
| WSL écoute sur 22 et non 2222 | générateur de `ssh.socket` pas relancé après la modification du port | `sudo systemctl daemon-reload && sudo systemctl restart ssh.socket` |
| `sshd -t` : `Missing privilege separation directory: /run/sshd` | dossier créé seulement à la première connexion | `sudo install -d -m 0755 /run/sshd`, sans conséquence sur la config |
| WSL injoignable après un redémarrage, tâche présente | la tâche n'a pas démarré avant l'ouverture de session (cas non mesuré : `ju-TP2` ouvre sa session automatiquement), ou WSL lui-même ne démarre pas | ouvrir une session Windows. PowerShell : `Get-ScheduledTaskInfo -TaskName WSL-KeepAlive` (`LastRunTime` à l'heure du démarrage ?), puis `wsl -l -v` (la distribution doit être `Running`) et `wsl -d <distro> -u root systemctl is-system-running` (`running` ou `degraded`). Une erreur de `wsl` elle-même relève de `wsl --update` ou de la section 0. Si la tâche ne part qu'à l'ouverture de session, lui ajouter ce déclencheur (utile seulement si quelqu'un se connecte) : `Set-ScheduledTask -TaskName WSL-KeepAlive -Trigger @((New-ScheduledTaskTrigger -AtStartup),(New-ScheduledTaskTrigger -AtLogOn))` |

### Stow et liens

| Symptôme | Cause | Correctif |
|---|---|---|
| `existing target is neither a link nor a directory` | fichier réel à la cible | le déplacer vers `~/dotfiles-backup`, jamais `--adopt` |
| jeton ou données écrits dans `~/dotfiles` | dossier replié en un lien unique | `stow -D <paquet> && stow --no-folding <paquet>` |
| restow replié qui recrée des liens fichier par fichier | `stow -D` laisse les dossiers vides, et stow ne replie pas un dossier existant | vérifier qu'il ne reste aucun fichier (`fdfind -H -t f -t l . ~/<dossier>`), puis `find ~/<dossier> -depth -type d -empty -delete` avant `stow <paquet>` |
| `~/.local/bin/.ruff_cache` | cache présent dans le paquet `bin` | `--ignore='\.ruff_cache'` |
| dossier vide créé dans `~` | `stow syncthing` sur un dossier non synchronisé | `--ignore='<dossier>'` |
| `git diff` échoue | `delta` absent | `sudo apt install git-delta` |
| réglages Positron ignorés | liens WSL non lus par Positron Windows | importer le profil dans Positron |

### Installation

| Symptôme | Cause | Correctif |
|---|---|---|
| session coupée, Syncthing redémarré pendant `cargo install` | OOM killer | `journalctl -k \| rg 'Out of memory'` ; `CARGO_BUILD_JOBS` et `MemoryMax` (section 7) |
| compilation perdue à la fermeture du terminal | processus rattaché à la session | `systemd-run --user` et linger |
| `mv: cannot stat '/opt/quarto'` | `quarto-update` antérieur au 2026-09-13, sans gestion de la première installation | attendre la synchro de `dotfiles`, relancer `quarto-update` |
| LibreOffice, Anki ou Positron installés dans WSL | `sys-update` antérieur au 2026-09-14 lancé sans module | désinstallation de la section 10 ; `sudo apt purge -y positron` pour Positron ; `sys-update` sans argument est sûr une fois `dotfiles` synchronisé |
| `libuv.so.1: cannot open shared object file` | bibliothèque d'exécution d'un binaire PPM absente | scan `ldd` de la section 9 |
| `Setting LC_CTYPE failed, using "C"` | `en_US.UTF-8` non générée | `sudo locale-gen en_US.UTF-8` |
| `rig add` demande un mot de passe | écrit dans `/opt/R` | `sudo rig add release` |
| `apt install` en 404 | index périmé ou version non-LTS en fin de vie | `sudo apt update` ; LTS |

### Vérifications

| Piège | Correctif |
|---|---|
| `rg <motif> <dossier>` ignore `.bashrc` et `.profile` | `rg --hidden` dans un paquet stow |
| `pgrep -f '<commande>'` trouve son propre shell | `ps -o pid,args -C <binaire>` |
| `quarto` trouvé dans le shell courant | shell neuf : `env -i HOME="$HOME" TERM=dumb bash -lic 'command -v quarto'` |

## Sources

Consultées le 2026-09-13.

- WSL, configuration (`wsl.conf`, `.wslconfig`, `vmIdleTimeout`) : <https://learn.microsoft.com/en-us/windows/wsl/wsl-config>
- WSL, commandes de base : <https://learn.microsoft.com/en-us/windows/wsl/basic-commands>
- Syncthing, dépôt apt : <https://apt.syncthing.net/>
- Syncthing, syntaxe des exclusions : <https://docs.syncthing.net/users/ignoring.html>
- Syncthing v2.0.0, notes de version : <https://github.com/syncthing/syncthing/releases/tag/v2.0.0>
- GitHub CLI sur Linux : <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>
- rustup : <https://rustup.rs/>
- NodeSource : <https://github.com/nodesource/distributions/blob/master/DEV_README.md>
- Claude Code, installation : <https://code.claude.com/docs/en/setup>
- `loginctl` (linger) : <https://www.freedesktop.org/software/systemd/man/latest/loginctl.html>
- Windows Terminal, fragments JSON (emplacement, clé `updates`, GUID des profils), consultée le 2026-09-14 : <https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions>
- Fira Code 6.2, archive sans empreinte publiée, consultée le 2026-09-14 : <https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip>
- Windows Terminal, polices par utilisateur (bug du cache de polices, contournements), consultées le 2026-09-14 : <https://github.com/microsoft/terminal/issues/3257>, <https://github.com/microsoft/terminal/issues/14231#issuecomment-1280827973>