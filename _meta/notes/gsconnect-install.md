# Migration kdeconnect (apt) → GSConnect (GNOME extension)

*2026-05-14T17:40:44Z by Showboat 0.6.1*
<!-- showboat-id: 8babd495-6fdc-4aba-905d-842b128aa759 -->

## Contexte

Ubuntu 24.04 LTS (noble) gèle `kdeconnect` à 23.08.5, soit ~9 versions en retard sur l'upstream KDE Gear (26.04.x). KDE Connect n'est pas distribué via flathub/snap (intégration DBus/réseau incompatible avec le sandbox).

Bascule vers **GSConnect**, extension GNOME Shell qui réimplémente le protocole KDE Connect en GJS. Canal de distribution indépendant d'apt (extensions.gnome.org), même app Android côté téléphone.

Limite : pas de migration automatique de l'appairage — clés cryptographiques distinctes entre kdeconnect et gsconnect. Re-pairing requis.

## État initial

```bash
dpkg -l kdeconnect 2>/dev/null | awk "/^ii/ {print \$2, \$3}"; echo "---"; kdeconnect-cli --list-devices 2>&1; echo "---"; pgrep -af kdeconnectd | grep -v claude | head -2; echo "---"; gnome-shell --version; echo "---"; gnome-extensions list | grep -iE "gsconnect|kdeconnect" || echo "no gsconnect/kdeconnect extension"
```

```output
kdeconnect 23.08.5-0ubuntu5
---
- S89: eb8640e8_006a_4bb6_bb96_1e238c06c73f (paired and reachable)
1 device found
---
2443 /usr/lib/x86_64-linux-gnu/libexec/kdeconnectd
---
GNOME Shell 46.0
---
no gsconnect/kdeconnect extension
```

## Étape 1 — Installer Extension Manager (GUI flatpak)

GUI recommandée par la communauté GNOME pour gérer les extensions : install/uninstall/update sans naviguer sur extensions.gnome.org. Install user-scope, pas de sudo.

```bash
flatpak install --user --noninteractive flathub com.mattjakeman.ExtensionManager 2>&1 | tail -20
```

```output
error: No remote refs found for ‘flathub’
```

Le remote flathub était configuré uniquement au niveau system, donc `flatpak install --user` ne le voit pas. Ajout au scope user :

```bash
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; flatpak --user remotes
```

```output
flathub
```

```bash
flatpak --user list --app | grep -i extensionmanager
```

```output
Extension Manager	com.mattjakeman.ExtensionManager	0.6.5	stable
```

## Étape 2 — Installer GSConnect (action utilisateur)

```bash
flatpak run com.mattjakeman.ExtensionManager
```

1. Onglet **Browse**
2. Recherche `GSConnect`
3. **Install** → l'extension s'installe dans `~/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/`
4. L'extension s'active automatiquement ; toggle ON sinon dans l'onglet **Installed**
5. Une icône GSConnect apparaît dans le top panel (à côté de l'horloge / des indicateurs)

## Étape 3 — Re-pairing S89 (action utilisateur)

Côté téléphone, ouvrir l'app **KDE Connect** (Android). L'ancien appareil bureau (kdeconnect) reste listé tant que le daemon tourne — un nouveau périphérique correspondant à GSConnect apparaîtra à la découverte.

- Côté bureau : clic sur l'icône GSConnect → S89 listé en *Available* → **Request Pairing**
- Côté téléphone : notification d'appairage → **Accept**
- Vérifier : envoi d'un ping bureau → téléphone fonctionne

Optionnel : supprimer l'ancien périphérique bureau côté téléphone (mort une fois kdeconnect désinstallé).

## Étape 4 — Retrait du paquet apt (à exécuter par toi)

À faire **après** confirmation que GSConnect fonctionne (sinon perte de moyen de communication temporaire) :

```bash
sudo apt remove kdeconnect
sudo apt autoremove
```

Optionnel — nettoyage de la conf legacy :

```bash
rm -rf ~/.config/kdeconnect/
```

## Étape 5 — Post-state (à capturer après les étapes manuelles)

Une fois tout fini, re-roule la dernière exec ci-dessous (à ajouter par toi via `showboat exec` ou par moi à la prochaine session).

## État intermédiaire — GSConnect actif, kdeconnect encore présent

Re-pairing confirmé par l'utilisateur. Détail intéressant : l'ID device de S89 (`eb8640e8_006a_4bb6_bb96_1e238c06c73f`) est **identique** entre kdeconnect et GSConnect — l'ID est généré par le téléphone, partagé via le protocole, donc seul le matériel cryptographique côté bureau diffère. La conf est stockée par GSConnect dans dconf (`/org/gnome/shell/extensions/gsconnect/`), pas dans `~/.config/gsconnect/` (qui ne contient que cert + clé).

```bash
gnome-extensions list --enabled | grep -i gsconnect; echo "---"; pgrep -af gsconnect | grep -v claude | head -1; echo "---"; dconf read /org/gnome/shell/extensions/gsconnect/device/eb8640e8_006a_4bb6_bb96_1e238c06c73f/paired; dconf read /org/gnome/shell/extensions/gsconnect/device/eb8640e8_006a_4bb6_bb96_1e238c06c73f/name
```

```output
gsconnect@andyholmes.github.io
---
33009 gjs -m /home/julien/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js
---
true
'S89'
```

## État final

`sudo apt remove kdeconnect` + `sudo apt autoremove` exécutés ; conf user supprimée (`rm -rf ~/.config/kdeconnect/`).

Le statut dpkg passe à `rc` (binaires retirés, conf système `/etc/` conservée). Pour purger complètement : `sudo apt purge kdeconnect` — non critique.

```bash
echo "## kdeconnect package status"; dpkg -l kdeconnect 2>/dev/null | tail -1 || echo "absent"; echo; echo "## kdeconnect binaries"; ls /usr/lib/x86_64-linux-gnu/libexec/kdeconnectd 2>&1; which kdeconnect-cli 2>&1 || echo "absent"; echo; echo "## kdeconnectd processes"; pgrep -af kdeconnectd | grep -v claude || echo "no kdeconnectd running"; echo; echo "## kdeconnect user config"; ls ~/.config/kdeconnect/ 2>&1; echo; echo "## gsconnect"; gnome-extensions list --enabled | grep gsconnect; pgrep -af gsconnect | grep -v claude | head -1; dconf read /org/gnome/shell/extensions/gsconnect/device/eb8640e8_006a_4bb6_bb96_1e238c06c73f/paired
```

```output
## kdeconnect package status
rc  kdeconnect     23.08.5-0ubuntu5 amd64        connect smartphones to your desktop devices

## kdeconnect binaries
ls: cannot access '/usr/lib/x86_64-linux-gnu/libexec/kdeconnectd': No such file or directory
absent

## kdeconnectd processes
no kdeconnectd running

## kdeconnect user config
ls: cannot access '/home/julien/.config/kdeconnect/': No such file or directory

## gsconnect
gsconnect@andyholmes.github.io
33009 gjs -m /home/julien/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js
true
```

## Bilan

| | Avant | Après |
|---|---|---|
| Paquet apt `kdeconnect` | 23.08.5 (gelé sur noble) | retiré (`rc`) |
| Daemon | `kdeconnectd` (PID 2443) | `gsconnect` (PID 33009) |
| Canal de distribution | apt noble/universe | extensions.gnome.org (via Extension Manager) |
| Version effective | 23.08.5 (~9 versions en retard) | suit l'upstream GSConnect |
| Appairage S89 | OK | OK (même device ID, nouveau matériel crypto bureau) |
| Conf utilisateur | `~/.config/kdeconnect/` (fichiers) | dconf `/org/gnome/shell/extensions/gsconnect/` |

Pour vérifier la cohérence du trace plus tard : `showboat verify ~/dotfiles/_meta/notes/kdeconnect-to-gsconnect.md` re-roule tous les blocs exec et diff la sortie.

## Purge complète

`sudo apt purge kdeconnect` exécuté — plus aucune trace du paquet.

```bash
dpkg -l kdeconnect 2>&1 | tail -1
```

```output
dpkg-query: no packages found matching kdeconnect
```
