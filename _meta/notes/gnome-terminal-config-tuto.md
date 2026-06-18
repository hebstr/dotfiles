# gnome-terminal-config : tutoriel

*2026-05-15T14:24:41Z by Showboat 0.6.1*
<!-- showboat-id: c0c1e57f-97d6-4f3b-a7ad-4f5ebb282871 -->

## Contexte

Script utilitaire pour sauvegarder, restaurer, et comparer la configuration de gnome-terminal (profil par défaut, couleurs, font, raccourcis clavier, scrollback, etc.) entre machines.

Stocke un dump `dconf` complet de `/org/gnome/terminal/` dans `~/dotfiles/_meta/profiles/gnome-terminal.dconf`, versionné avec le reste des dotfiles.

Cas d'usage typiques :

- bootstrap d'une nouvelle machine (cloner dotfiles → stow bin → `gnome-terminal-config restore`)
- snapshot avant modification risquée (test d'un thème, refonte des keybindings)
- vérifier qu'aucune dérive n'a eu lieu entre la config locale et celle versionnée

## Interface

Trois sous-commandes :

```bash
gnome-terminal-config --help
```

```output
Usage: gnome-terminal-config <command>

Commands:
  dump        Export current gnome-terminal config to dotfiles
  restore     Apply the saved config (backs up current state first)
  diff        Show what restore would change
```

## 1. Capturer la config actuelle : `dump`

Exporte tout l'arbre dconf `/org/gnome/terminal/` vers `~/dotfiles/_meta/profiles/gnome-terminal.dconf`. À relancer chaque fois qu'un réglage à conserver est modifié (puis commit).

```bash
gnome-terminal-config dump
```

```output
Dumped to /home/julien/dotfiles/_meta/profiles/gnome-terminal.dconf (24 lines)
```

Vérification : le fichier de dump contient bien le profil par défaut, les couleurs, la font, et les raccourcis (extrait des 15 premières lignes) :

```bash
head -15 ~/dotfiles/_meta/profiles/gnome-terminal.dconf
```

```output
[legacy]
shortcuts-enabled=true
theme-variant='dark'

[legacy/keybindings]
copy='<Primary><Shift>c'
paste='<Primary><Shift>v'
reset='<Primary><Shift>k'
reset-and-clear='disabled'
select-all='<Primary><Shift>a'

[legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9]
background-color='#181818'
cell-height-scale=1.2
cursor-shape='ibeam'
```

## 2. Vérifier la dérive : `diff`

Affiche un diff unifié entre l'état dconf courant et le dump versionné. Exit 0 si identique, diff non vide sinon. Utile avant un `dump` (pour voir ce qu'on s'apprête à figer) ou avant un `restore` (pour voir ce qu'on s'apprête à écraser).

```bash
gnome-terminal-config diff && echo '(aucune dérive)'
```

```output
(aucune dérive)
```

## 3. Restaurer sur une nouvelle machine : `restore`

Workflow type sur une machine vierge :

```bash
git clone <dotfiles-repo> ~/dotfiles
cd ~/dotfiles && stow bin
gnome-terminal-config restore
```

`restore` :

1. dump l'état dconf actuel dans `/tmp/gnome-terminal-backup-<timestamp>.dconf` (filet de sécurité)
2. charge `~/dotfiles/_meta/profiles/gnome-terminal.dconf` via `dconf load /org/gnome/terminal/`
3. les changements sont visibles dans un **nouvel onglet** gnome-terminal (les onglets existants gardent leur état hérité)

Si le dump versionné est cassé ou indésirable, restaurer depuis le backup :

```bash
dconf load /org/gnome/terminal/ < /tmp/gnome-terminal-backup-<timestamp>.dconf
```

> Pas d'exécution dans ce tutoriel : `restore` modifie l'état dconf de la session. Le tester ici écraserait la config réelle (même si idempotent quand le dump matche déjà l'état courant).

## Tests

Tests unitaires bats avec `dconf` stubbé, dans `_meta/tests/gnome-terminal-config.bats` :

```bash
bats ~/dotfiles/_meta/tests/gnome-terminal-config.bats
```

Couvre : usage/help, commande inconnue, `dump` (chemin, création du répertoire, invocation dconf), `restore` (absence de dump, backup /tmp, invocation dconf load), `diff` (absence de dump, match).

