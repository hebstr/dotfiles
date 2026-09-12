# dotfiles

Personal stow-managed dotfiles.

## Structure

```
air/ bash/ bin/ claude/ css/ firefox/ gh/ git/ obsidian/ panache/ positron/ R/ Rstudio/ syncthing/   # config stow packages
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
stow -R -t ~ air bash bin claude css gh git obsidian panache positron R Rstudio syncthing
stow -R --no-folding -t ~ firefox
npm --prefix css/.local/share/css-gate ci
```

`firefox` is stowed on its own line and with `--no-folding` deliberately.
It carries a single `user.js` under a randomly generated profile directory (`z24d9fn6.default-release`), and stow folds an arborescence whose target directory does not exist, which on a fresh machine would symlink `~/.mozilla` itself into the repo and put the whole Firefox profile (`places.sqlite`, `cookies.sqlite`, the cache) under version control.
`--no-folding` creates real directories and links the leaf file only.
That profile name is specific to one machine: elsewhere, rename the directory inside the package to match the local profile, otherwise the link lands where Firefox never reads and the setting vanishes with no error.

The `npm ci` step is required, not optional: the `css` package ships pinned `package.json` + `package-lock.json` but its `node_modules/` is gitignored, so `~/.local/bin/{stylelint,prettier}` dangle until it runs, and `symlinks-check` fails.
Thereafter `sys-update css-toolchain` keeps that toolchain current.

The uv tools have no equivalent step, and the bootstrap above does not install them: `sys-update uv-tools` upgrades what is already present and installs nothing.
`pyrefly` (the Python gate's type checker), `sqlfluff[rs]` (the SQL gate), `showboat`, `ouroboros-ai`, `huggingface-hub` and `yt-dlp` each need a manual `uv tool install` on a fresh machine.
The uv-managed Python interpreters behave the same way: `sys-update uv-python` moves them to the latest patch of each installed branch, so a fresh machine needs `uv python install` first.
Tracked in `.claude/DEFERRED.md`.

Hooks are run via [`prek`](https://github.com/j178/prek) (`prek install`, `prek run -a`).
