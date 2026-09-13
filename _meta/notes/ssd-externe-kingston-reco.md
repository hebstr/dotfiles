# SSD externe Kingston A400 : stockage et sauvegarde système

Note de recherche issue de `/workflow:reco` (2026-09-13).
Partitionnement et formatage réalisés le 2026-09-13 (voir « Réalisé »). Reste à configurer Timeshift et Déjà Dup.

## État constaté au 2026-09-13

- Disque : Kingston A400 `SA400S37120G`, 111,8 Go, branché en USB, vu comme `/dev/sda` ce jour-là.
- Une seule partition `sda2`, ext4 de 1 Go, pleine à 100 %, montée sur `/media/julien/37b7a34c-58a0-49e4-8ea2-68be43f3ca63`. Le reste du disque n'est pas alloué.
- Contenu : `archive/` (911 Mo : `pro-biostats`, `pro-epidémio`, `pro-misc`), effacé par le formatage.
- Disque interne : 115 Go utilisés, dont 67 Go dans `/home/julien`. Hors `/home`, la racine mesure environ 47 Go (`du` sans `sudo`, donc sous-estimé : les snaps ne sont pas lisibles).
- Paquets : `timeshift` 24.01.1 et `exfatprogs` 1.2.2 disponibles mais non installés, `deja-dup` 45.2 installé.

## Décision

Table GPT, deux partitions :

```
| # | Système de fichiers | Taille | Type sgdisk | Rôle |
|---|---|---|---|---|
| 1 | exFAT | ~40 Go | 0700 (Microsoft basic data) | Stockage lisible sous Linux, Windows et macOS |
| 2 | ext4 | reste, ~72 Go | 8300 (Linux filesystem) | Instantanés Timeshift en mode rsync, `/home` exclu |
```

`/home` (67 Go) se sauvegarde ailleurs, avec Déjà Dup vers un autre support.

## Réalisé le 2026-09-13

Étapes 1 à 6 de la procédure faites, sauf l'installation de `timeshift` (seul `exfatprogs` installé). `archive/` avait déjà été copié sur le disque interne.
État vérifié avec `lsblk` :

```
| Partition | Taille | FS | Label | Type GPT | UUID |
|---|---|---|---|---|---|
| sda1 | 40G | exfat | DATA | ebd0a0a2-b9e5-4433-87c0-68b6b72699c7 | EEEF-F20C |
| sda2 | 71,8G | ext4 | TIMESHIFT | 0fc63daf-8483-4772-8e79-3d69d8477de4 | 04d2a2ce-4736-4d16-bd35-c26b0cdc27e6 |
```

La partition `DATA` a été montée (`/media/julien/DATA`) et un fichier test s'y est écrit, puis le SSD a été démonté et mis hors tension (`udisksctl power-off`).
Trace reproductible de ces étapes : `ssd-externe-kingston-format.md`.

Reste à faire : étapes 8 et 9 (Timeshift, Déjà Dup).

## Pourquoi

- Une image disque complète (Clonezilla) ne tient pas : 115 Go de données pour 112 Go de SSD.
- Timeshift refuse les partitions Windows (NTFS, FAT, exFAT) : ses instantanés reposent sur des liens physiques. D'où ext4.
- Timeshift exclut `/home` par défaut et ne protège pas les données utilisateur (« Timeshift is NOT a backup tool and is not meant to protect user data », README).
- exFAT plutôt que NTFS : macOS lit NTFS mais n'y écrit pas.
- Windows n'affiche que les partitions de type « basic data », d'où le type `0700` sur la partition exFAT. GPT est pris en charge sur les disques amovibles depuis Windows Vista.
- Taille de la partition Timeshift : le premier instantané copie tout le système (40 Go ou plus ici), les suivants ne stockent que les changements. Les forums rapportent 40 à 80 Go pour 7 à 9 instantanés. Une répartition 60/50 était trop juste.

## Points de vigilance

- Ce qui est rangé uniquement sur la partition exFAT n'a aucune sauvegarde.
- exFAT n'a pas de journal : toujours éjecter avant de débrancher.
- Le A400 n'a pas de cache DRAM : le premier instantané sera lent.
- Les instantanés programmés échouent si le SSD n'est pas branché (« Snapshot device not available »). Déclencher à la main, avant chaque grosse mise à jour, et n'en garder que 3 à 5.
- Timeshift repère la partition par son UUID, qui change au formatage : la resélectionner dans Timeshift.
- Snaps et Flatpaks gonflent les instantanés. Ce que Timeshift exclut par défaut sur `/snap` et `/var/lib/snapd` n'est pas vérifié.
- TRIM est souvent désactivé derrière un adaptateur USB. Inutile pour effacer le disque : `wipefs` puis `sgdisk -Z` suffisent.
- Si le disque interne meurt, Timeshift ne suffit pas seul : démarrer sur une clé Ubuntu, réinstaller, puis restaurer l'instantané.

## Procédure

Le nom `/dev/sda` peut changer d'un branchement à l'autre : le vérifier à l'étape 3 avant toute commande destructive.

```bash
# 1. Mettre archive/ à l'abri
cp -a /media/julien/37b7a34c-58a0-49e4-8ea2-68be43f3ca63/archive ~/archive-ssd-kingston

# 2. Démonter la partition
udisksctl unmount -b /dev/sda2

# 3. Vérifier que sda est bien le Kingston 111,8G en usb
lsblk -o NAME,SIZE,MODEL,TRAN

# 4. Effacer les signatures et la table de partitions
sudo wipefs -a /dev/sda2 && sudo wipefs -a /dev/sda && sudo sgdisk -Z /dev/sda

# 5. Créer la table GPT et les deux partitions
sudo sgdisk -o -n 1:0:+40G -t 1:0700 -c 1:DATA -n 2:0:0 -t 2:8300 -c 2:TIMESHIFT /dev/sda
sudo partprobe /dev/sda

# 6. Installer les outils et formater
sudo apt install exfatprogs timeshift
sudo mkfs.exfat -L DATA /dev/sda1
sudo mkfs.ext4 -L TIMESHIFT /dev/sda2

# 7. Contrôler
lsblk -f /dev/sda
```

8. Timeshift : mode RSYNC, partition `TIMESHIFT`, `/home` laissé exclu, premier instantané à la main.
9. Déjà Dup pour `/home`, vers un autre support que ce SSD.

## Sources

Vérifiées par requête HTTP le 2026-09-13.

- Timeshift, README : <https://github.com/linuxmint/timeshift>
- Clonezilla : <https://clonezilla.org/>
- Microsoft, Windows and GPT FAQ : <https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-and-gpt-faq>
- GPT fdisk, codes de type : <https://www.rodsbooks.com/gdisk/walkthrough.html>
- Apple, formats compatibles : <https://support.apple.com/en-us/101830>
- Linux Mint forums, Timeshift et exFAT : <https://forums.linuxmint.com/viewtopic.php?t=401340>
- Linux Mint forums, tailles des instantanés : <https://forums.linuxmint.com/viewtopic.php?t=296847>
- Gentoo wiki, TRIM par USB : <https://wiki.gentoo.org/wiki/Discard_over_USB>
