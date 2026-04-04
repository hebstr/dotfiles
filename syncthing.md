# Syncthing folder setup

Run on a fresh machine after:

1. `sudo apt install syncthing`
2. `systemctl --user start syncthing`
3. Connect devices via <http://127.0.0.1:8384> (exchange Device IDs)
4. `st-add-folder` is in PATH (`~/.local/bin/st-add-folder`)

## Devices

| Name  | Device ID |
|-------|-----------|
| ju-TP | `C2N42ZX-ZXFDD6E-PGWCLMD-AKKP5B4-JYD6ZDH-FGO67QH-QOZQCXY-EKXDOAR` |
| ju-GO | `AQG7RA4-SIR6FKL-3KJNWCC-QJ3IXOM-PKKC76T-WF662ZF-H54RBUC-NDNODAI` |
| ju-DG | `MMHRAUD-UXFH6LN-RGSLXY5-FO7ZVMP-4VZC2XG-VEC4NYM-N4RZZ7S-3N2BJQQ` |
| ju-LG | `3VBW4EI-4RZFQGX-4SZGUMA-TG5WRZU-C62XF7K-LJVGU3W-ZMT6L7S-G5JQJQW` |

## Existing folders

```sh
st-add-folder ~/.claude --ignore ~/dotfiles/.stignore/claude --versioning 1
st-add-folder ~/Documents --id Documents
st-add-folder ~/Musique --id Musique
st-add-folder ~/Images --id images/photos
st-add-folder ~/Images --id images/screenshots
st-add-folder ~/Téléchargements/sync --id téléchargements
```
