# gnome-config : tutoriel

## Contexte

Orchestrateur de configuration GNOME via `dconf`, versionnée avec les dotfiles.
Il sauvegarde, restaure et compare l'état dconf de plusieurs domaines du bureau (interface, périphériques, raccourcis, extensions, terminal, indexation Tracker, etc.) entre machines.

Chaque domaine est un dump `dconf` stocké dans `~/dotfiles/_meta/profiles/gnome/<domaine>.dconf`.
La table `domaine -> chemin dconf` vit en tête du script (`bin/.local/bin/gnome-config`), source de vérité unique.

Cas d'usage :

- bootstrap d'une machine (cloner dotfiles, stow bin, `gnome-config restore`)
- snapshot avant une modification risquée (thème, refonte des raccourcis)
- vérifier qu'aucune dérive n'a eu lieu entre l'état local et la version commitée

## Interface

```bash
gnome-config --help
```

Trois sous-commandes, chacune sur tous les domaines par défaut ou sur un sous-ensemble passé en arguments :

```
gnome-config dump    [domaine...]   # exporte l'état dconf courant vers _meta/profiles/gnome/
gnome-config restore [domaine...]   # applique l'état sauvegardé (ajoute/écrase, n'efface jamais ; backup /tmp d'abord)
gnome-config diff    [domaine...]   # montre la dérive entre l'état live et sauvegardé (exit 1 si dérive)
```

Exemples : `gnome-config dump terminal`, `gnome-config diff`, `gnome-config restore shell terminal`.

## Domaines

`desktop-interface`, `input-sources`, `peripherals`, `privacy`, `screensaver`, `session`, `wm`, `mutter`, `nautilus`, `settings-daemon`, `shell`, `shell-extensions`, `terminal`, `tracker`.

## Domaines curés

Trois domaines ne se laissent pas dumper naïvement ; le script applique un filtre pour que `dump` reproduise l'état voulu et que `diff` reste propre :

- `shell` : seules les clés `enabled-extensions` et `favorite-apps` sont conservées (le reste de `/org/gnome/shell/` est de l'état jetable).
- `shell-extensions` : les blocs `gsconnect` sont retirés (état d'appairage device-spécifique : certificats, IP, IDs).
- `peripherals` : les blocs `tablets/*` sont retirés (spécifiques au matériel branché).

## Workflow de restauration

```bash
git clone <dotfiles-repo> ~/dotfiles
cd ~/dotfiles && stow bin
gnome-config restore
```

`restore` pour chaque domaine :

1. dump l'état dconf actuel dans `/tmp/gnome-config-backup-<domaine>-<timestamp>.dconf` (filet de sécurité)
2. charge le fichier versionné via `dconf load`

Pour annuler un restore, recharger le backup : `dconf load <chemin> < /tmp/gnome-config-backup-<domaine>-<timestamp>.dconf`.
Certains changements (extensions, thème) ne s'affichent qu'après un nouvel onglet de terminal ou un redémarrage du shell.

## Ce que ça reproduit (et pas)

Ces dumps reproduisent la *configuration*, pas l'*installation*. Sur la machine cible, il faut déjà :

- les applications référencées par `shell.dconf` `favorite-apps` (Positron, Obsidian, Zotero, Tidal, etc.)
- les extensions GNOME Shell listées dans `shell.dconf` `enabled-extensions` (activées, pas installées, par le seed)
- la police `Fira Code` (référencée par le profil de `terminal.dconf`)
- les thèmes `Yaru`/`Yaru-dark` (stock Ubuntu, référencés par `desktop-interface.dconf`)

`tracker.dconf` `index-recursive-directories` contient des chemins absolus propres à cet utilisateur ; à ajuster ailleurs.

## Tests

Tests bats avec `dconf` stubbé, dans `_meta/tests/gnome-config.bats` :

```bash
bats ~/dotfiles/_meta/tests/gnome-config.bats
```

Couvre : usage/help, commande et domaine inconnus, `dump` (fichier, chemin dconf, création du répertoire, tous domaines, curation de `shell`), `restore` (absence de dump, backup /tmp, `dconf load`), `diff` (absence de dump, match).
