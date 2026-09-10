# Migration Ubuntu 24.04 vers 26.04 : quand partir

Note de recherche issue de `/workflow:reco` (2026-09-09).
Aucune action système engagée : la machine reste sur 24.04.5.
Sources officielles et dépôts re-vérifiés en direct par requête HTTP à cette date.

## Décision

Ne pas migrer avant décembre 2026.
Fenêtre visée : décembre 2026 à février 2027, conditionnée à deux critères vérifiables plutôt qu'à une date.

1. `curl -s https://changelogs.ubuntu.com/meta-release-lts | grep -A4 '^Dist: resolute'` renvoie `Supported: 1`.
2. Deux à trois mois de tampon après ce basculement.

Le critère 1 est surveillé automatiquement par une routine cloud quotidienne (6h UTC), créée le 2026-09-09 : <https://claude.ai/code/routines/trig_019wLpTCwdTRi8kKNBwaQLnw>.
Elle reste silencieuse tant que le flag vaut 0 et déroule la reco complète le jour où il passe à 1.
Ne pas en créer une seconde.

Le critère 1 est la preuve que les backports rust-coreutils ont atterri.
Le critère 2 couvre le précédent 22.04 vers 24.04, chemin ouvert puis retiré en septembre 2024 à cause d'un bug du solveur apt dans `ubuntu-release-upgrader`.

## État au 2026-09-09

26.04 LTS « Resolute Raccoon » est sortie le 2026-04-23, la 26.04.1 le 2026-08-27.
Le chemin automatique depuis 24.04 est encore fermé :

```
Dist: resolute
Name: Resolute Raccoon
Version: 26.04.1 LTS
Supported: 0
```

`noble` et `jammy` portent `Supported: 1` dans le même fichier.
La machine a `Prompt=lts` dans `/etc/update-manager/release-upgrades`, donc `do-release-upgrade` sans `-d` ne propose rien.

L'annonce 26.04.1 explicite le délai : « Users of Ubuntu 24.04 LTS will be offered an automatic upgrade to 26.04.1 LTS via Update Manager a couple of weeks following this release after some planned backports to address regressions in a recent version of rust-coreutils. »

Contrainte de temps nulle par ailleurs : 24.04 est maintenue jusqu'au 2029-05-31 en standard, 2034-05 en ESM.
Le noyau installé est le GA 6.8, couvert sur toute cette période.

## Ce qui est déjà prêt

Contrairement à l'hypothèse de départ, la stack data science n'est pas le point de blocage.
Tout sert `resolute` depuis mai 2026 :

  | Composant | État `resolute` | Vérification |
  | --------- | --------------- | ------------ |
  | Posit Package Manager | binaires R 4.6, ~24 900 paquets | `PACKAGES.gz` en 200, en-tête `x-package-binary-tag: 4.6-resolute` |
  | CRAN apt | suite `resolute-cran40`, `r-base 4.6.0` | `Release` daté du jour |
  | r2u | supporté amd64 et arm64 | ChangeLog 2026-04-05 |
  | rig | « Ubuntu 20.04, 22.04, 24.04, 26.04 » | README |
  | Positron | Ubuntu 26 listé, fin de support 2031-04-30 | `docs.posit.co/platform-support.html` |
  | Quarto | `.deb` « Ubuntu 18+/Debian 10+ », pas de borne haute | page de téléchargement |

La FAQ Positron mentionne « RHEL 8, 9, and 10 and Ubuntu 22/24 », mais cette phrase porte sur les fonctions Remote SSH et Workbench, pas sur le desktop.
Ce n'est pas une contradiction avec la matrice de support.

Les 8 dépôts tiers épinglés sur `noble` dans `/etc/apt/sources.list.d/` ont tous leur équivalent `resolute` en ligne : CRAN, Docker, QGIS, et les PPAs apt-fast, git-core, mozillateam, keepassxc.
Les autres sources (`claude-desktop`, `github-cli`, `nodesource`, `rig`, `syncthing`, `protonvpn`, `vscode`) utilisent une suite `stable` indépendante du nom de code.

## Le risque réel : le cœur de l'OS

  | Composant | 24.04 | 26.04 |
  | --------- | ----- | ----- |
  | GCC | 14 | 15.2 |
  | glibc | 2.39 | 2.43 |
  | Python | 3.12 | 3.14 |
  | Rust (archive) | 1.75 | 1.93 |
  | Noyau | 6.8 | 7.x |
  | coreutils | GNU | rust-coreutils |

Plus : session GNOME en Wayland uniquement (X.org supprimé), cgroup v1 retiré, `sudo-rs` par défaut, APT 3 sans `apt-key`, dracut à la place d'initramfs-tools, dernière version à supporter la compatibilité SysV dans systemd.

rust-coreutils est le seul sujet avec de la casse documentée, pas de la spéculation :

- GBIF IPT, issue 3060 (2026-06) : `sort` cassé, contournement `apt install coreutils-from-gnu coreutils-from-uutils- --allow-remove-essential`.
- Fil Discourse d'utilisateurs revenus à GNU coreutils, dont un cas NFS reconnu comme bug réel.
- LWN (2026-04) : uutils 0.8.0 par défaut, 8 problèmes TOCTOU ouverts, remplacement complet visé pour 26.10.
- HN : `dd` masquant des erreurs de troncature, risque de corruption silencieuse dans des scripts de sauvegarde ou de migration.

`cp`, `mv` et `rm` restent GNU dans 26.04 à cause de bugs non résolus.
`sudo-rs` change l'invite en `[sudo: authenticate] <METHOD>:`, ce qui casse toute automatisation de type Expect, et perd `sudoreplay` et `sudoers.ldap`.

Le mode de panne est silencieux : un `sort` ou un `dd` qui diverge dans un pipeline ne lève pas d'erreur, il produit un résultat faux.
C'est le pire profil pour du traitement de données, et c'est ce qui justifie le tampon du critère 2.

## Absence de signal

Aucun retour d'expérience publié sur un poste R ou Python en 26.04, ni sur Quarto, ni sur `cargo`, `rustup`, `uv`, `pipx`, ni sur `stow`.
Personne n'a écrit dessus, ce qui ne vaut pas validation.

## Checklist du jour J

Préparation, recommandation Canonical : « The #1 cause of broken upgrades is deb packages from non-Ubuntu sources. It's 100% preventable. »
Désactiver tous les dépôts tiers et PPAs avant, les réactiver un par un après en lisant la sortie d'`apt upgrade`.
Les snaps ne cassent pas la mise à niveau, même si leur fonctionnement sous 26.04 n'est pas garanti.

- Sauvegarde complète avant de lancer quoi que ce soit.
- Bascule `noble` vers `resolute` dans `~/dotfiles`. Les occurrences se retrouvent par `rg -n --hidden 'noble' ~/dotfiles` (le `--hidden` est indispensable, sans quoi `claude/.claude/` est ignoré), et valaient au 2026-09-09 : `_meta/profiles/Rprofile.site` (URL PPM) et `claude/.claude/rules/environment.md` (même URL, dans la section Package management).
- Juste après la mise à niveau, avant tout pipeline : `sudo apt install coreutils-from-gnu`.
- Recréer les venvs Python adossés au `python3` système (3.12 vers 3.14). Les projets `uv` avec leur propre 3.13 ne sont pas concernés.
- Mettre à jour `rules/environment.md` pour les versions réelles constatées après coup (GCC, glibc, Python système, noyau).

Option de dé-risquage : `do-release-upgrade -d` dans une VM ou un conteneur clonant les dépôts tiers, pour obtenir la liste réelle des paquets retirés sans toucher au poste.

## Mise à niveau en place ou réinstallation propre

Point non tranché par les sources.
Le camp « en place » domine sur Discourse pour préserver la configuration.
Le camp « propre » est porté par les cas de systèmes chargés (un `usrmerge` en échec sur une chaîne 22.04 vers 26.04) et par les notes Kubuntu qui encouragent un `~/.config` neuf.
Les dotfiles stow rendent la réinstallation propre bien moins coûteuse que la moyenne, ce qui affaiblit l'argument principal du camp « en place ».
À trancher au moment de partir, pas maintenant.

## Sources

- <https://changelogs.ubuntu.com/meta-release-lts>
- <https://lists.ubuntu.com/archives/ubuntu-announce/2026-August/000326.html>
- <https://ubuntu.com/server/docs/how-to/software/upgrade-your-release/>
- <https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/>
- <https://ubuntu.com/about/release-cycle>
- <https://discourse.ubuntu.com/t/best-practice-for-a-successful-release-upgrade-to-26-04/80868>
- <https://ubuntu.com/server/docs/reference/other-tools/sudo-rs/>
- <https://packagemanager.posit.co/__docs__/admin/serving-binaries.html>
- <https://cloud.r-project.org/bin/linux/ubuntu/>
- <https://docs.posit.co/platform-support.html>
- <https://github.com/r-lib/rig>
- <https://github.com/gbif/ipt/issues/3060>
- <https://lwn.net/Articles/1069593/>
