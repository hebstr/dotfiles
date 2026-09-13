# Syncthing folder setup

Run on a fresh machine after:

1. `syncthing-update` (apt.syncthing.net, channel `stable-v2`; Ubuntu 24.04's own package is 1.27)
2. `systemctl --user enable --now syncthing`
3. Connect devices via <http://127.0.0.1:8384> (exchange Device IDs)
4. `st-add-folder` is in PATH (`~/.local/bin/st-add-folder`); on a WSL instance whose GUI listens elsewhere, export `ST_URL=http://127.0.0.1:8385` first

## Devices

  | Name           | Device ID                                                         |
  | -------------- | ----------------------------------------------------------------- |
  | ju-TP          | `C2N42ZX-ZXFDD6E-PGWCLMD-AKKP5B4-JYD6ZDH-FGO67QH-QOZQCXY-EKXDOAR` |
  | ju-TP2-ubuntu  | `MOFXAU5-INQSOQC-XZWJ7FD-SF52ZZX-ESHSLFK-NDNJLFR-WBJE6SR-P3ZW2AM` |
  | ju-TP2-windows | `XGY4J4R-BXKT6OO-ZBILGZ6-J2K5WI6-WAN4EOF-WM5A4NF-WYFTX4R-SOMZZAV` |
  | ju-GO          | `NAF4MBW-UYSO5BB-BRUW5UO-C7OWXRS-UBBVSUP-DTF24RN-7KZ2W3I-PCOCGQQ` |
  | ju-DG          | `56LDHWP-UGLKA3I-VKUSWJU-DFKK7PL-BTTXSRH-A2G5Q42-Y643IIW-RZW2BQV` |

## Existing folders

```sh
st-add-folder ~/.claude --ignore ~/dotfiles/syncthing/.claude/.stignore --versioning 1
st-add-folder ~/Documents --id Documents --ignore ~/dotfiles/syncthing/Documents/.stignore
st-add-folder ~/Musique --id Musique --ignore ~/dotfiles/syncthing/Musique/.stignore
st-add-folder ~/Images --id images/photos
st-add-folder ~/Images --id images/screenshots
st-add-folder ~/Téléchargements --id téléchargements --ignore ~/dotfiles/syncthing/Téléchargements/.stignore
st-add-folder ~/notes --id notes --ignore ~/dotfiles/syncthing/notes/.stignore
st-add-folder ~/dotfiles --id dotfiles --ignore ~/dotfiles/.stignore
st-add-folder ~/admin --ignore ~/dotfiles/syncthing/admin/.stignore
st-add-folder ~/archive --ignore ~/dotfiles/syncthing/archive/.stignore
```
