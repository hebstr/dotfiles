# dotfiles

Personal stow-managed dotfiles.

## Structure

```
bash/ bin/ claude/ css/ gh/ git/ obsidian/ panache/ positron/ R/ Rstudio/ syncthing/   # config stow packages
prek.toml                  # pre-commit hooks
_meta/
├── backup/      # backup script + systemd timer/service + excludes
├── notes/       # internal docs
├── profiles/    # exportable app profiles + reusable config templates
└── tests/       # bats test suites for bin/ scripts and claude/ hooks
```

Packages follow stow conventions: each top-level dir maps its tree relative to `~` (`bash/.bashrc` → `~/.bashrc`, `bin/.local/bin/` → `~/.local/bin/`).

## Bootstrap

```sh
sudo apt install -y stow
git clone https://github.com/hebstr/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -R -t ~ bash bin claude css gh git obsidian panache positron R Rstudio syncthing
npm --prefix css/.local/share/css-gate ci
```

The `npm ci` step is required, not optional: the `css` package ships pinned `package.json` + `package-lock.json` but its `node_modules/` is gitignored, so `~/.local/bin/{stylelint,prettier}` dangle until it runs, and `symlinks-check` fails.
Thereafter `sys-update css-toolchain` keeps that toolchain current.

The uv tools have no equivalent step, and the bootstrap above does not install them: `sys-update uv-tools` upgrades what is already present and installs nothing.
`pyrefly` (the Python gate's type checker), `sqlfluff[rs]` (the SQL gate), `showboat`, `ouroboros-ai`, `huggingface-hub`, `youtube-transcript-api` and `yt-dlp` each need a manual `uv tool install` on a fresh machine.
Tracked in `.claude/DEFERRED.md`.

Hooks are run via [`prek`](https://github.com/j178/prek) (`prek install`, `prek run -a`).
