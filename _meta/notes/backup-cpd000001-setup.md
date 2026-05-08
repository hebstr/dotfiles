# Backup cpd000001 → WS-CAR

## Contexte

Sauvegarde incrémentielle de `/home/edjulien/` sur `cpd000001` vers un partage réseau Windows `WS-CAR-EDSN1M01`.

La connexion SSH ne fonctionne que dans le sens WS-CAR → cpd000001 (pare-feu réseau).
Le script tourne donc sur WS-CAR (Git Bash / MINGW64) et tire les données via rclone SFTP.

## Architecture

```
cpd000001:/home/edjulien/
    ↓ rclone sync (SFTP)
WS-CAR:/s/julien.elicesdiez/backup/edjulien/
```

## Installation de rclone sur WS-CAR

Depuis Git Bash :

```bash
curl -O https://downloads.rclone.org/rclone-current-windows-amd64.zip
unzip rclone-current-windows-amd64.zip
mkdir -p ~/bin
cp rclone-v*/rclone.exe ~/bin/
echo 'export PATH="$HOME/bin:$PATH"' > ~/.bashrc
source ~/.bashrc
rclone --version
```

## Configuration du remote rclone

```bash
rclone config
```

Paramètres saisis :

| Champ | Valeur |
|-------|--------|
| name | `cpd000001` |
| type | `sftp` |
| host | `cpd000001` |
| user | `edjulien` |
| auth | mot de passe |

Vérification :

```bash
rclone lsd cpd000001:/home/edjulien/
```

## Déploiement du script et des exclusions

Depuis Git Bash sur WS-CAR :

```bash
mkdir -p ~/bin ~/.config/backup

scp edjulien@cpd000001:~/dotfiles/_meta/backup/.local/bin/backup-cpd000001 \
    ~/bin/backup-cpd000001
chmod +x ~/bin/backup-cpd000001

scp edjulien@cpd000001:~/dotfiles/_meta/backup/.config/backup/excludes.txt \
    ~/.config/backup/excludes.txt
```

## Utilisation

Test à blanc :

```bash
rclone sync cpd000001:/home/edjulien/ /s/julien.elicesdiez/backup/edjulien/ \
    --filter-from ~/.config/backup/excludes.txt \
    --delete-excluded \
    --progress \
    --dry-run
```

Backup réel :

```bash
backup-cpd000001
```

## Comportement du sync

| Cas | Comportement |
|-----|-------------|
| Fichier nouveau sur source | Copié vers destination |
| Fichier modifié sur source | Mis à jour sur destination |
| Fichier supprimé sur source | Supprimé de la destination |
| Fichier correspondant à une exclusion | Supprimé de la destination (`--delete-excluded`) |

## Automatisation

Planificateur de tâches Windows (Task Scheduler) — lancer `bash.exe ~/bin/backup-cpd000001` quotidiennement.
Les fichiers `.service` et `.timer` du paquet sont des références Linux non utilisés sur WS-CAR.

## Fichiers du paquet dotfiles

```
_meta/backup/
├── .local/bin/backup-cpd000001       script principal
├── .config/backup/excludes.txt       liste des exclusions rclone
├── .config/systemd/user/
│   ├── backup-cpd000001.service      (référence Linux, non utilisé sur WS-CAR)
│   └── backup-cpd000001.timer        (référence Linux, non utilisé sur WS-CAR)
```
