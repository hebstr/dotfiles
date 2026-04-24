# dotfiles

Personal stow-managed dotfiles, synced across machines via syncthing.

## Structure

```
bash/ bin/ claude/ gh/ git/ positron/ R/ Rstudio/ syncthing/   # stow packages
_meta/
├── notes/       # internal docs (syncthing setup, etc.)
└── templates/   # reusable config templates (air.toml, prek.toml)
```

Packages follow stow conventions: each top-level dir maps its tree relative to `~`. For example `bash/.bashrc` → `~/.bashrc`, `Rstudio/.config/rstudio/rstudio-prefs.json` → `~/.config/rstudio/rstudio-prefs.json`.

The `bin/` package contains personal CLI utilities symlinked to `~/.local/bin/`:

- `positron-update`, `quarto-update` — interactive installers that fetch the latest release, verify checksum, and install (deb / tarball)
- `st-add-folder` — Syncthing helper

`_meta/` and dotted dirs are never stowed — the `dot` function explicitly excludes them.

## Bootstrap a new machine

```sh
sudo apt install -y stow git
git clone https://github.com/hebstr/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -R -t ~ bash bin claude gh git positron R Rstudio syncthing
```

After `bash/.bashrc` is loaded in a new shell, the `dot` function is available for everything else.

## Daily usage

```sh
dot <pkg>        # install a single package
dot -R <pkg>     # restow (cleans stale symlinks)
dot -D <pkg>     # uninstall
dot .            # install every package except _meta and .*
dot -R .         # restow everything
dot -D .         # uninstall everything
dot -n -v .      # dry-run everything
```

The function lives in `bash/.bashrc`. It expands `.` to the list of stow-worthy top-level dirs (excluding `_*` and `.*`) and passes every other argument straight to stow.

## Adding a new package

1. Create the package dir mirroring the target tree: `mkdir -p newpkg/.config/newpkg`
2. Move or create config files inside
3. `dot newpkg` to install

No list to maintain — the `dot` function picks it up automatically on next `dot .`.
