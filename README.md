# dotfiles

Personal stow-managed dotfiles.

## Structure

```
bash/ bin/ claude/ gh/ git/ positron/ R/ Rstudio/ syncthing/   # stow packages
prek.toml                  # pre-commit hooks (shellcheck, shfmt, check-yaml)
_meta/
├── notes/       # internal docs
├── profiles/    # exportable Positron / VS Code profiles
├── templates/   # reusable config templates
└── tests/       # bats test suites for bin/ scripts
```

Packages follow stow conventions: each top-level dir maps its tree relative to `~`. For example `bash/.bashrc` → `~/.bashrc`, `Rstudio/.config/rstudio/rstudio-prefs.json` → `~/.config/rstudio/rstudio-prefs.json`.

## Bootstrap a new machine

```sh
sudo apt install -y stow
git clone https://github.com/hebstr/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -R -t ~ bash bin claude gh git positron R Rstudio syncthing
```
