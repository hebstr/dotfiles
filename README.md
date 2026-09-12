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
└── tests/       # bats test suites for bin/ scripts, claude/ hooks and the git diff driver
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
`pyrefly` (the Python gate's type checker, also run by this repo's own commit hook), `sqlfluff[rs]` (the SQL gate), `showboat`, `ouroboros-ai`, `huggingface-hub` and `yt-dlp` each need a manual `uv tool install` on a fresh machine.
The uv-managed Python interpreters behave the same way: `sys-update uv-python` moves them to the latest patch of each installed branch, so a fresh machine needs `uv python install` first.
Tracked in `.claude/DEFERRED.md`.

Hooks are run via [`prek`](https://github.com/j178/prek) (`prek install`, `prek run -a`).

## Git content filter and diff driver

The `git` package ships a `clean` filter named `html-id` and a `textconv` diff driver named `out-textconv`, so `stow git` is the whole setup and a fresh machine needs no extra step.
The filter renumbers the random ids `gt` puts on its tables and `reactable` on its widgets, `gt1` and `htmlwidget-wdg1` upward in order of appearance, so a re-rendered HTML output diffs on content alone.
The driver renders a `.docx`, `.xlsx`, `.pptx` or `.png` as stable text for `git diff`, hiding the metadata every render regenerates; it reads only and never rewrites a stored byte (`_meta/notes/git-out-textconv.md`).

A driver is inert until a repository asks for it, and that half stays versioned with each project: one attribute line per pattern in its own `.gitattributes`, of which `_meta/profiles/gitattributes` is the template.
Declaring the filter in a global attributes file instead would apply it to every repository on the machine, third-party clones included, where it would rewrite ids on `git add` with no warning.

`git check-attr filter diff -- <file>` and `git config --get filter.html-id.clean` settle whether a diff is real.
