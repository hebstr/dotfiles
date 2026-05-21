# dotfiles

Personal stow-managed dotfiles.

## Structure

```
bash/ bin/ claude/ gh/ git/ positron/ R/ Rstudio/ syncthing/   # config stow packages
prek.toml                  # pre-commit hooks
_meta/
├── backup/      # backup script + systemd timer/service + excludes
├── notes/       # internal docs
├── profiles/    # exportable Positron / VS Code profiles
├── templates/   # reusable config templates
└── tests/       # bats test suites for bin/ scripts
```

Packages follow stow conventions: each top-level dir maps its tree relative to `~` (`bash/.bashrc` → `~/.bashrc`, `bin/.local/bin/` → `~/.local/bin/`).

## Bootstrap

```sh
sudo apt install -y stow
git clone https://github.com/hebstr/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -R -t ~ bash bin claude gh git positron R Rstudio syncthing
```

Hooks are run via [`prek`](https://github.com/j178/prek) (`prek install`, `prek run -a`).
