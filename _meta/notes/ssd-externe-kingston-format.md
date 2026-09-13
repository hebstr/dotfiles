# SSD externe Kingston A400 : partitionnement et formatage

*2026-09-13T15:41:03Z by Showboat 0.6.1*
<!-- showboat-id: cad5173c-5376-492b-9299-5bac22669a2b -->

Kingston A400 `SA400S37120G` (111,8 Go, USB) reformaté le 2026-09-13 en table GPT à deux partitions : exFAT de 40 Go pour le stockage partagé Linux/Windows/macOS, ext4 sur le reste pour les instantanés Timeshift. Choix et sources dans `ssd-externe-kingston-reco.md`.

Un seul bloc est exécutable : le contrôle des prérequis, que `showboat verify` rejoue sans risque. Les étapes disque exigent `sudo` et le SSD branché ; elles sont consignées dans des blocs délimités par des tildes, avec la sortie observée ce jour-là, à relancer à la main. Ne jamais les délimiter par des backticks : showboat 0.6.1 traite tout bloc en backticks comme exécutable, même sans langage et même dans une note, et `verify` le lance (mesuré le 2026-09-13, où `verify` a tenté les `sudo` destructifs, refusés faute de mot de passe). Seuls les blocs en tildes et les blocs indentés sont ignorés. Le nom `/dev/sda` n'est pas stable d'un branchement à l'autre : toujours le reconfirmer avant l'étape destructive.

Prérequis : outils de partitionnement et de formatage. `sgdisk` et `partprobe` viennent des paquets `gdisk` et `parted`, `mkfs.exfat` de `exfatprogs`, installé pour l'occasion (`sudo apt install -y exfatprogs`).

```bash
for t in sgdisk wipefs partprobe udisksctl mkfs.exfat mkfs.ext4 lsblk; do command -v "$t"; done; dpkg-query -W -f="\${Package} \${Status}\n" exfatprogs
```

```output
/usr/sbin/sgdisk
/usr/sbin/wipefs
/usr/sbin/partprobe
/usr/bin/udisksctl
/usr/sbin/mkfs.exfat
/usr/sbin/mkfs.ext4
/usr/bin/lsblk
exfatprogs install ok installed
```

Étape 1, identifier le disque et démonter l'ancienne partition (ext4 de 1 Go, contenu `archive/` copié au préalable sur le disque interne).

~~~text
$ udisksctl unmount -b /dev/sda2
Unmounted /dev/sda2.
$ lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,TRAN /dev/sda
NAME     SIZE TYPE FSTYPE LABEL MOUNTPOINTS MODEL                 TRAN
sda    111,8G disk                          KINGSTON SA400S37120G usb
└─sda2     1G part ext4
~~~

Étape 2, destructive : effacer les signatures, détruire les tables GPT et MBR, créer la table GPT et les deux partitions. Type `0700` (Microsoft basic data) sur la partition exFAT, sans quoi Windows ne lui attribue pas de lettre ; type `8300` (Linux filesystem) sur la partition ext4.

~~~text
$ sudo wipefs -a /dev/sda2 && sudo wipefs -a /dev/sda && sudo sgdisk -Z /dev/sda && sudo sgdisk -o -n 1:0:+40G -t 1:0700 -c 1:DATA -n 2:0:0 -t 2:8300 -c 2:TIMESHIFT /dev/sda && sudo partprobe /dev/sda
~~~

Étape 3, destructive : formater.

~~~text
$ sudo mkfs.exfat -L DATA /dev/sda1 && sudo mkfs.ext4 -L TIMESHIFT /dev/sda2
~~~

Étape 4, contrôle : table, types, labels et systèmes de fichiers.

~~~text
$ lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,PARTTYPE,PTTYPE,UUID,MOUNTPOINTS /dev/sda
NAME     SIZE FSTYPE LABEL     PARTLABEL PARTTYPE                             PTTYPE UUID                                 MOUNTPOINTS
sda    111,8G                                                                 gpt
├─sda1    40G exfat  DATA      DATA      ebd0a0a2-b9e5-4433-87c0-68b6b72699c7 gpt    EEEF-F20C
└─sda2  71,8G ext4   TIMESHIFT TIMESHIFT 0fc63daf-8483-4772-8e79-3d69d8477de4 gpt    04d2a2ce-4736-4d16-bd35-c26b0cdc27e6
~~~

Étape 5, contrôle d'écriture sur la partition de stockage, puis éjection. exFAT n'a pas de journal : toujours éjecter avant de débrancher.

~~~text
$ udisksctl mount -b /dev/sda1
Mounted /dev/sda1 at /media/julien/DATA
$ touch /media/julien/DATA/.write-test && rm /media/julien/DATA/.write-test && df -h /media/julien/DATA
Sys. de fichiers Taille Utilisé Dispo Uti% Monté sur
/dev/sda1           40G    384K   40G   1% /media/julien/DATA
$ udisksctl unmount -b /dev/sda1 && udisksctl power-off -b /dev/sda
Unmounted /dev/sda1.
~~~

La partition `TIMESHIFT` reste vide jusqu'à la configuration de Timeshift (étapes 8 et 9 de la note de reco).

