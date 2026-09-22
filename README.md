# dotfiles

Personal stow-managed dotfiles.

## Structure

```
agents/ air/ bash/ bin/ claude/ css/ firefox/ gh/ git/ obsidian/ opencode/ panache/ positron/ prek/ R/ Rstudio/ ruff/ ssh/ syncthing/   # config stow packages
prek.toml                  # pre-commit hooks
_meta/
├── backup/      # backup script + systemd timer/service + excludes
├── notes/       # internal docs
├── profiles/    # exportable app profiles + reusable config templates
└── tests/       # bats test suites for bin/ scripts, claude/ hooks, the opencode plugin, the git diff driver and the html-id clean filter
```

Packages follow stow conventions: each top-level dir maps its tree relative to `~` (`bash/.bashrc` → `~/.bashrc`, `bin/.local/bin/` → `~/.local/bin/`).

## Bootstrap

```sh
sudo apt install -y stow
git clone https://github.com/hebstr/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow -R --no-folding --ignore='\.ruff_cache' -t ~ air bash bin claude firefox gh git obsidian opencode panache positron prek R Rstudio ruff ssh syncthing
stow -R -t ~ agents css
npm config set prefix "$HOME/.npm-global"
npm --prefix css/.local/share/css-gate ci
```

`--no-folding` is the default here, deliberately.
Stow folds an arborescence whose target directory does not exist into a single symlink to the repo, so on a fresh machine everything a program later writes there lands in `~/dotfiles` and in Syncthing: Claude Code sessions and `.credentials.json` under `~/.claude`, the `gh` token, editor state under `~/.config/Positron`, the whole notes vault through `~/notes`, SSH keys generated in `~/.ssh`, the Firefox profile (`places.sqlite`, `cookies.sqlite`, the cache) through `~/.mozilla`.
`--no-folding` creates real directories and links the leaf files only.
Two packages stay folded: `agents`, because `~/.agents` must remain a single link for the skills installer to write into the repo, and `css`, whose `~/.local/bin` links resolve through `~/.local/share/css-gate/node_modules`: folded, that directory follows whatever `npm ci` and `sys-update css-toolchain` install in the repo, where `--no-folding` would link each file one by one and miss those an update adds.
On a machine that does not sync every Syncthing folder, add `--ignore='<folder>'` for each missing one, or stow creates empty directories just to hold their `.stignore`.

Agent skills are split across two packages on purpose.
`agents/.agents/skills/` holds what the `skills` CLI installs from upstream and what its `.skill-lock.json` tracks, and nothing there is hand-edited: an update replaces a skill directory whole.
`claude/.claude/skills/` holds the skills written here, and Claude Code reads only that one, through a symlink per skill.
Stow such a skill with plain `stow claude`, never `--no-folding`, which would link each file and leave a symlinked `SKILL.md` instead of the symlinked skill directory Claude Code supports.

`firefox` carries a single `user.js` under a randomly generated profile directory (`z24d9fn6.default-release`).
That profile name is specific to one machine: elsewhere, rename the directory inside the package to match the local profile, otherwise the link lands where Firefox never reads and the setting vanishes with no error.

`ssh` holds `.ssh/config` only, never a key, and that file stays `644`: `ssh` rejects a config others can write, and tolerates a group-writable one only because Ubuntu's build accepts a private user group.
Setting up the servers and keys behind its aliases, on both machines, is section 12 of `_meta/notes/wsl-init-tuto.md`, with the recovery table under its "Pièges".

The `npm ci` step is required: the `css` package ships pinned `package.json` + `package-lock.json` but its `node_modules/` is gitignored, so `~/.local/bin/{stylelint,prettier}` dangle until it runs, and `symlinks-check` fails.
Thereafter `sys-update css-toolchain` keeps that toolchain current.

The npm prefix step is required too: without it the global prefix is `/usr`, whose `npm` and `corepack` belong to the NodeSource `nodejs` deb, and `sys-update npm` fails with `EACCES` as soon as npm publishes a release newer than the deb's.
With `~/.npm-global`, `npm update -g` only sees packages installed there, and apt keeps `npm` itself current.
`npm config set` writes a machine-local `~/.npmrc`, deliberately not a stow package since `npm login` stores tokens in that file; `bash/.profile` puts `~/.npm-global/bin` on the `PATH`.

The uv tools have no equivalent step, and the bootstrap above does not install them: `sys-update uv-tools` upgrades what is already present and installs nothing.
`pyrefly` (the Python gate's type checker, also run by this repo's own commit hook), `sqlfluff[rs]` (the SQL gate), `showboat`, `ouroboros-ai`, `ggsql-jupyter`, `yt-dlp` and, on a machine that serves local models, `huggingface-hub` each need a manual `uv tool install` on a fresh machine.
The uv-managed Python interpreters behave the same way: `sys-update uv-python` moves them to the latest patch of each installed branch, so a fresh machine needs `uv python install` first.
The gap is tracked in `.claude/DEFERRED.md`.

[`prek`](https://github.com/j178/prek) runs the hooks (`prek install`, `prek run -a`).

## Local coding agent

opencode runs on the main machine against a Qwen3.5 9B served by `llama-server` on the GPU machine, through an SSH forward, and reads the Claude Code profile through a harness (`opencode/.config/opencode/`: `opencode.json`, `AGENTS.md`, `plugins/claude-hooks.ts`), each project's `.claude/CLAUDE.md` and `.claude/memory/MEMORY.md` included.
On the GPU machine, install the CUDA build with `llama-update` and the `hf` CLI with `uv tool install huggingface-hub`; `llama-session` downloads the model the first time it runs.
On the main machine, beyond the `stow` line above:

```sh
npm install -g opencode-ai
opencode-skills-sync
```

The second command links the skills of the enabled Claude Code plugins where opencode looks for them.
`sys-update claude-plugins` reruns it after the updates it makes; a plugin changed any other way (Claude Code's own auto-update, `/plugin enable`, `disable` or `update`) needs a manual `opencode-skills-sync`, or opencode serves the old set until the next `sys-update`.
To work, run `llama-session` in one terminal and `opencode` in another.
`_meta/notes/opencode-harness-setup.md` holds the full procedure and the checks that `showboat verify` replays.

## Git content filter and diff driver

The `git` package ships a `clean` filter named `html-id` and a `textconv` diff driver named `out-textconv`, so `stow git` is the whole setup and a fresh machine needs no extra step.
Each program is a script in `git/.config/git/` (`clean-html-id`, `clean-positron-theme`, `out-textconv.py`) that `git/.gitconfig` calls by path, so a script added to the package reaches a machine only once `stow --no-folding git` is rerun there.
The filter renumbers the random ids `gt` puts on its tables and `reactable` on its widgets, `gt1` and `htmlwidget-wdg1` upward in order of appearance, so a re-rendered HTML output diffs on content alone.
The driver renders a `.docx`, `.xlsx`, `.pptx` or `.png` as stable text for `git diff`, hiding the metadata every render regenerates; it reads only and never rewrites a stored byte (`_meta/notes/git-out-textconv.md`).
A second `clean` filter, `positron-theme`, serves this repository alone: it stores `workbench.colorTheme` in the Positron profile settings as `Material Night Eighties` whatever theme is active, so switching themes never reaches a commit or `git diff`.
`git status` still lists the file after a switch to a theme name of another length, since git reads a size change as a modification without running the filter; staging the file clears it.

A driver is inert until a repository asks for it, and that half stays versioned with each project: one attribute line per pattern in its own `.gitattributes`, of which `_meta/profiles/gitattributes` is the template.
Declaring the filter in a global attributes file instead would apply it to every repository on the machine, third-party clones included, where it would rewrite ids on `git add` with no warning.

`git check-attr filter diff -- <file>` and `git config --get filter.html-id.clean` settle whether a diff is real.
