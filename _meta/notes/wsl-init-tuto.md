# Initialisation WSL Ubuntu : tutoriel

## Contexte

Procédure pour transformer une distribution Ubuntu vierge sous WSL 2 en poste de travail équivalent à la machine principale.
Les dotfiles arrivent par Syncthing en réception seule (« Receive Only »), pas par `git clone`.

Deux instances Syncthing cohabitent sur la machine, chacune sur le système de fichiers qu'elle lit nativement :

- **Syncthing Windows** : dossiers situés sur `C:`.
- **Syncthing WSL** : `dotfiles` et tout dossier vivant dans `/home/<user>`.

Hors périmètre : Positron, Anki, LibreOffice, Firefox et Syncthing Windows, qui tournent côté Windows.

L'ordre compte : chaque étape fournit ce que la suivante suppose présent.

## 0. Côté Windows (PowerShell)

```powershell
wsl --update
wsl --list --online
wsl --install <nom>
wsl --list --verbose
```

- Choisir une LTS dans la liste (`Ubuntu-24.04` ou plus récente) : une version non-LTS en fin de vie voit ses dépôts déplacés et tout `apt install` renvoie 404.
- `wsl --list --verbose` doit afficher `VERSION 2`.
- Au premier lancement, Ubuntu demande de créer un utilisateur : c'est ce nom qui sert de `<user>` plus bas.

Optionnel, pour que les autres appareils joignent Syncthing WSL en direct plutôt que par relais (en mode NAT par défaut, la VM n'est pas joignable depuis le réseau local) : créer `C:\Users\<user_windows>\.wslconfig`.

```ini
[wsl2]
networkingMode=mirrored
```

Le mode `mirrored` exige Windows 11 22H2 ou plus.
Appliquer avec `wsl --shutdown`.

## 1. Rafraîchir apt, avant toute autre commande

```bash
sudo apt update
sudo apt full-upgrade -y
```

**`apt update` est obligatoire avant le premier `apt install`.**
L'image WSL est livrée avec un index de paquets figé à sa date de fabrication : sans rafraîchissement, apt réclame des versions que les miroirs ont supprimées et échoue en `404 Not Found`, dès `build-essential`.

Lire la sortie de `apt update`, pas seulement le code de retour : une ligne `Err:` ou `W:` signale un index resté périmé.
Si elle mentionne `Release file ... is not valid yet`, l'horloge de WSL a dérivé (fréquent après une veille de Windows) : `wsl --shutdown` côté PowerShell, puis relancer.

## 2. Configurer la distribution (`/etc/wsl.conf`)

```bash
sudoedit /etc/wsl.conf
```

```ini
[boot]
systemd=true

[user]
default=<user>
```

- `systemd=true` rend `systemctl --user` disponible, nécessaire pour Syncthing en service. La section `[boot]` n'existe que sous Windows 11.
- `[user] default` évite d'ouvrir la session en root.

Appliquer depuis PowerShell :

```powershell
wsl --shutdown
```

Attendre quelques secondes (la documentation parle de 8 secondes pour que la VM s'arrête), rouvrir Ubuntu, puis vérifier :

```bash
systemctl is-system-running
```

`running` ou `degraded` indiquent tous deux que systemd tourne.

Fuseau horaire : rien à faire, `[time] useWindowsTimezone` vaut `true` par défaut et WSL suit le fuseau de Windows.

Langue, optionnel :

```bash
sudo locale-gen fr_FR.UTF-8
sudo update-locale LANG=fr_FR.UTF-8
```

## 3. Paquets de base

```bash
sudo apt install -y \
  build-essential ca-certificates curl wget gnupg unzip git \
  stow ripgrep fd-find jq shellcheck shfmt bats \
  libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev \
  libharfbuzz-dev libfribidi-dev libfreetype-dev libpng-dev libtiff-dev libjpeg-dev
```

Noms vérifiés sur Ubuntu 24.04 le 2026-09-13.

- Ligne 1 : compilation, téléchargement, git.
- Ligne 2 : outils que les dotfiles et les scripts de `bin` supposent présents. `fd-find` installe le binaire `fdfind`.
- Lignes 3 et 4 : bibliothèques système des paquets R qui compilent encore malgré les binaires P3M (`curl`, `xml2`, `systemfonts`, `ragg`, `textshaping`).

Ubuntu 24.04 fige `shellcheck` en 0.9.0 et `shfmt` en 3.8.0, derrière les versions épinglées par les hooks prek (voir `rules/environment.md`).

## 4. Syncthing : deux instances

### Répartition des dossiers

| Dossier | Instance | Chemin |
|---|---|---|
| sur `C:` | Syncthing Windows | `C:\...` |
| `dotfiles` et dossiers Linux | Syncthing WSL | `/home/<user>/...` |

Pourquoi ne pas tout confier à une seule instance :

- **Syncthing Windows vers `\\wsl.localhost\<distro>\home\<user>\...`** : Syncthing sous Windows ne recrée pas les liens symboliques (les deux de `css/.local/bin` seraient perdus) ni le bit d'exécution (34 fichiers exécutables dans `dotfiles`, dont tout `bin`), et la détection des modifications à travers ce partage est peu fiable. Comportement connu de Syncthing sous Windows, non revérifié dans sa documentation.
- **Syncthing WSL vers `/mnt/c/...`** : une modification faite par une application Windows n'émet aucun événement côté WSL, donc Syncthing ne la voit qu'au rescan périodique ; les accès de WSL 2 au disque Windows sont lents ; sans l'option de montage `metadata`, les droits Linux n'existent pas ; NTFS ignore la casse. Limitations connues de WSL 2, non revérifiées dans la documentation.

Autres chemins à éviter : `/mnt/wsl/...` est un tmpfs partagé entre distributions, pas le home.

### Migrer un dossier de Syncthing Windows vers Syncthing WSL

Si `dotfiles` était déjà tiré par Syncthing Windows dans `\\wsl.localhost\...` :

1. Dans Syncthing Windows, retirer le dossier (Edit > Remove). Les fichiers restent sur le disque.
2. Ajouter le dossier dans Syncthing WSL avec le même Folder ID et le même chemin vu de Linux (`/home/<user>/dotfiles`), en « Receive Only ».
3. Vérifier les droits d'exécution une fois le scan terminé : `ls -l ~/dotfiles/bin/.local/bin`. Des fichiers écrits par l'instance Windows peuvent être restés sans bit `x` ; si « Revert Local Changes » dans Syncthing WSL ne les réaligne pas, `chmod +x` à la main (non testé).

### Versions

Syncthing v2 sur toutes les machines, v2.1.5 au 2026-09-13.
Les notes de la v2.0.0 ne disent pas si v1 et v2 synchronisent ensemble ; aligner la version majeure évite la question.

- **WSL** : dépôt officiel apt.syncthing.net, canal `stable-v2`. Le paquet d'Ubuntu 24.04 est une 1.27.
- **Windows** : Syncthing Windows Setup, l'un des deux intégrateurs listés sur la page de téléchargement officielle (l'autre étant SyncTrayzor v2). Remplacer une instance v1 ou l'ancien SyncTrayzor d'origine.

### Installer Syncthing WSL

`syncthing-update` configure exactement ce dépôt, mais il n'arrive qu'avec `stow bin`, donc après la synchro : première installation à la main.

```bash
sudo mkdir -p /etc/apt/keyrings
sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable-v2" | sudo tee /etc/apt/sources.list.d/syncthing.list
printf "Package: *\nPin: origin apt.syncthing.net\nPin-Priority: 990\n" | sudo tee /etc/apt/preferences.d/syncthing.pref
sudo apt-get update
sudo apt-get install -y syncthing
syncthing --version
```

Le pin donne la priorité à apt.syncthing.net sur le paquet d'Ubuntu.

```bash
syncthing generate
systemctl --user enable --now syncthing
syncthing device-id
```

Les deux instances réclament les mêmes ports (8384 pour l'interface, 22000 pour la synchro, 21027 pour la découverte locale), et WSL les partage avec Windows : par renvoi de `localhost` en mode NAT, par le même réseau en mode `mirrored`.
Au premier démarrage, Syncthing cherche de lui-même des ports libres (option `--no-port-probing` pour l'en empêcher), mais il faut fixer des ports distincts pour savoir à quelle instance le navigateur parle :

```bash
syncthing cli config gui raw-address set 127.0.0.1:8385
syncthing cli config options raw-listen-addresses 0 set tcp://0.0.0.0:22001
syncthing cli config options raw-listen-addresses add quic://0.0.0.0:22001
systemctl --user restart syncthing
```

Syntaxe vérifiée sur Syncthing 2.1.5. Si une version ultérieure la change, faire le même réglage dans l'interface (Actions > Settings > GUI pour l'adresse, Connections > Sync Protocol Listen Addresses pour les ports).

Interface de Syncthing WSL depuis le navigateur Windows : <http://127.0.0.1:8385>.
Celle de Syncthing Windows reste sur <http://127.0.0.1:8384>.

Si, en mode `mirrored`, les appareils ne se trouvent pas sur le réseau local, désactiver la découverte locale de l'instance WSL ; la découverte globale et les relais suffisent :

```bash
syncthing cli config options local-ann-enabled set false
```

### Appairage

Syncthing WSL est un appareil distinct de Syncthing Windows, avec son propre Device ID : l'ajouter sur chaque machine distante qui partage `dotfiles` ou un dossier Linux, et l'inscrire dans la table de `syncthing-state.md`.

## 5. Liens stow

Paquets à lier sur WSL :

| Paquet | Sur WSL | Raison |
|---|---|---|
| `bash`, `git`, `R`, `air`, `ruff`, `panache`, `prek`, `gh`, `bin` | oui | configs portables |
| `claude` | oui, avec `--no-folding` | voir ci-dessous |
| `css` | après l'étape 7 | ses liens pointent vers `node_modules`, absent avant `npm ci` |
| `firefox` | non | lié au profil `z24d9fn6.default-release` de la machine principale |
| `positron` | non | lié au profil `-eb36ac2`, et Positron tourne côté Windows |
| `obsidian`, `Rstudio` | non | non utilisés dans WSL |
| `syncthing` | seulement si `~/.claude`, `~/Documents`, `~/admin` ou `~/archive` sont synchronisés | ne contient que des `.stignore` |

Test à blanc d'abord :

```bash
cd ~/dotfiles
stow -n -v --no-folding bash git R air ruff panache prek gh bin claude
```

`--no-folding` est indispensable ici.
Sans lui, un `~/.claude` absent devient un lien unique vers `~/dotfiles/claude/.claude`, et tout ce que Claude Code y écrit ensuite (sessions, projets, `.credentials.json`) atterrit dans le dossier synchronisé.

Une distribution neuve contient déjà `~/.bashrc`, `~/.profile` et `~/.bash_logout`, que stow refuse d'écraser (`existing target is neither a link nor a directory`).
Les déplacer, ne pas les supprimer :

```bash
mkdir -p ~/dotfiles-backup
mv ~/.bashrc ~/.profile ~/.bash_logout ~/dotfiles-backup/
```

Ne pas utiliser `--adopt`, qui copie le fichier local dans le paquet par-dessus la version synchronisée.

Quand le test à blanc est propre :

```bash
stow -v --no-folding bash git R air ruff panache prek gh bin claude
readlink -e ~/.bashrc
exec bash -l
```

`readlink` doit renvoyer `/home/<user>/dotfiles/bash/.bashrc`.
`~/.secrets`, sourcé par `.bashrc`, n'est ni versionné ni synchronisé : à recréer à la main.

## 6. GitHub CLI

Presque tous les scripts `*-update` interrogent l'API GitHub via `gh`.
La version d'Ubuntu est ancienne ; installer depuis le dépôt officiel :

```bash
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y
gh auth login
```

Le paquet `gh` des dotfiles ne porte que `config.yml` ; `hosts.yml`, qui contient le jeton, est exclu du dépôt, d'où le `gh auth login`.

## 7. Toolchain

`sys-update` met à jour et n'installe rien : chaque module est ignoré tant que son outil est absent.
Les outils se posent donc une première fois à la main, dans cet ordre.

### Binaires cargo-dist (uv, ruff, air, jarl, prek)

```bash
devtools-update --all
```

Requiert `curl`, `sudo` et `gh` ; installe dans `/usr/local/bin`.

### Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
exec bash -l
cargo install cargo-update
```

`cargo-update` fournit `cargo install-update`, sans lequel le module `cargo` de `sys-update` est ignoré.
Les binaires cargo (typstyle, shellharden, panache, bacon, pdf-inspector) s'installent ensuite chacun par `cargo install <crate>`.

### Node et gate CSS

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x -o nodesource_setup.sh
sudo -E bash nodesource_setup.sh
sudo apt install -y nodejs
npm --prefix ~/dotfiles/css/.local/share/css-gate ci
cd ~/dotfiles && stow -v --no-folding css
```

22.x est la LTS indiquée par la documentation NodeSource consultée le 2026-09-13 ; la machine principale tourne en 24.x depuis le même dépôt.
Remplacer le numéro par la LTS courante.
`npm ci` écrit dans `node_modules`, exclu du dépôt git mais pas de Syncthing : en réception seule, le dossier passe alors en « Local Additions ».

### Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude-plugins-install
```

`claude-plugins-install` requiert `claude` et `jq`.

### R, Quarto, Pandoc, DuckDB, Lua

Ces scripts installent l'outil quand il est absent (la version courante lue vaut `unknown`, différente de la dernière publiée) :

```bash
rig-update
rig add release
stow-rprofile
rv-update
quarto-update
pandoc-update
duckdb-update
lua-toolchain-update
```

- `rig add release` : syntaxe de mémoire, à confirmer par `rig add --help`.
- `stow-rprofile` lie `Rprofile.site` dans chaque `/opt/R/<version>/lib/R/etc/` ; sans lui, `repos` reste `@CRAN@` et chaque paquet compile depuis les sources.

### Couche uv

```bash
uv python install 3.13 3.14
uv tool install pyrefly
uv tool install "sqlfluff[rs]"
uv tool install showboat
uv tool install ouroboros-ai
uv tool install huggingface-hub
uv tool install yt-dlp
```

Liste reprise du `README.md` des dotfiles ; l'absence de manifeste versionné est suivie dans `.claude/DEFERRED.md`.

## 8. Entretien

Ne pas lancer `sys-update` sans argument sur WSL : les scripts `positron-update`, `anki-update` et `libreoffice-update` sont présents via `stow bin` et tenteraient d'installer ces applications dans la distribution.
Nommer les modules :

```bash
sys-update apt npm rustup cargo claude devtools uv-python uv-tools rv rig duckdb lua-toolchain css-toolchain claude-plugins quarto pandoc syncthing
```

`sys-update --dry-run <modules>` affiche les commandes sans les exécuter.

## Pièges connus

- **Réception seule et liens stow.** Un programme qui modifie un fichier lié (`~/.gitconfig`, `~/.claude/...`, `~/.config/gh/config.yml`) écrit dans `~/dotfiles`. Syncthing affiche « Local Changes » et propose « Revert Local Changes », qui efface ces modifications au profit de la version de la machine principale.
- **Pas de `.stignore` à la racine de `~/dotfiles`.** `.git`, `.ruff_cache` et `node_modules` de la machine principale sont transférés.
- **Arrêt de la VM.** WSL arrête la distribution quand plus aucun processus ne la retient, ce qui stoppe Syncthing WSL (Syncthing Windows n'est pas concerné). Comportement exact avec systemd actif non vérifié ; si la synchro des dotfiles ne se fait que terminal ouvert, c'est la piste.
- **Un dossier, une instance.** Un même dossier ne doit jamais être partagé par les deux instances de la machine : elles écriraient chacune de leur côté et produiraient des conflits en boucle.
- **Horloge.** Après une veille de Windows, l'heure de WSL peut dériver et casser `apt update` : `wsl --shutdown`.

## Sources

Consultées le 2026-09-13.

- WSL, configuration avancée (`wsl.conf`, `.wslconfig`) : <https://learn.microsoft.com/en-us/windows/wsl/wsl-config>
- WSL, commandes de base : <https://learn.microsoft.com/en-us/windows/wsl/basic-commands>
- GitHub CLI sur Linux : <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>
- rustup : <https://rustup.rs/>
- NodeSource : <https://github.com/nodesource/distributions/blob/master/DEV_README.md>
- Claude Code, installation : <https://code.claude.com/docs/en/setup>
- Syncthing, téléchargements : <https://syncthing.net/downloads/>
- Syncthing, dépôt apt : <https://apt.syncthing.net/>
- Syncthing v2.0.0, notes de version : <https://github.com/syncthing/syncthing/releases/tag/v2.0.0>
