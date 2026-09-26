---
paths:
  - "**/.claude/rules/install.md"
---

# Installing, updating and stowing tools

Injected by `inject-rules.sh`, with `showboat.md`, on an `apt`, `pip install`, `uv tool install`, `claude plugin install`, `stow` or `systemctl` command.
A version or the presence of a tool is read from the machine (`command -v`, `--version`), never from memory; the former inventory is archived in `~/dotfiles/_meta/notes/environment-archive.md`.

## One entry point: `sys-update`

- `sys-update` (in `bin/`) runs every updater as a module: `sys-update --list` is the authority for the set, `sys-update <module>` runs one, no argument runs all. Prefer the module over an ad-hoc install or upgrade, so the maintained path stays authoritative.
- A tool a package manager already tracks is covered through it: apt packages by `apt`, snaps (typst, chromium) by `snap`, cargo binaries by `cargo`, cargo-dist installers (ruff, air, jarl, uv, prek) by `devtools`, uv tools by `uv-tools`, uv interpreters by `uv-python`. A tool with a bespoke distribution has its own `<tool>-update` script wired as a module.
- The `positron`, `anki`, `libreoffice` and `zotero` modules skip unless the application is on the PATH, since their updaters install it when absent; a first install calls `<app>-update` directly. Neither `uv-python` nor `uv-tools` installs anything absent: a fresh machine needs its `uv python install` and `uv tool install` by hand.
- `llama-update` is deliberately not a module: upstream builds land almost daily and an unattended one can break the opencode chain. It runs on the GPU host.
- Positron extensions and Zotero plugins update inside their application, outside `sys-update`.

## Covered is not current

- `uv python upgrade` repoints the minor-version symlink, so a venv built against the minor request follows the new patch, and one built against an explicit patch stays behind. A green `uv-python` proves nothing about a given venv: `<venv>/bin/python --version` is the only answer. Rebuilding against the minor request (`uv tool upgrade --all --python 3.14`, or a project's next `uv sync`) makes it follow from then on.
- The `cargo` module passes `GGSQL_SKIP_GENERATE=1`: without it, `cargo install ggsql-cli` (and `ggsql-jupyter`) regenerates its parser and demands a `tree-sitter-cli` that is not installed. Keep it until upstream changes the default.
- Global npm packages live under the user prefix `~/.npm-global`, set in a machine-local `~/.npmrc` that is never stowed; with the default `/usr` prefix, `npm update -g` hits the deb-owned `npm` and fails with `EACCES`. The same `~/.npmrc` carries `allow-scripts=opencode-ai`: a package newly listed in npm's install-script advisory is reviewed and added there, on each machine. Node itself comes from the NodeSource apt repository.

## One tool, one binary

Several extensions bundle a copy of a CLI that `sys-update` maintains, and some put their copy first on the integrated terminal's PATH. The gate then runs a binary nothing updates, and the split shows only as the editor and the terminal disagreeing. Each is pinned to the managed binary:

```
| Tool | Extension setting | Resolves to | Kept current by |
|---|---|---|---|
| pyrefly | pyrefly.lspPath | ~/.local/bin/pyrefly | uv-tools |
| air | air.executableStrategy: "environment" | /usr/local/bin/air | devtools |
| panache | panache.executableStrategy: "environment" | ~/.cargo/bin/panache | cargo |
```

The same split can come from two installs of one tool. When a tool looks stale despite a green `sys-update`, run `command -v` on it before anything else. When deleting one binary of a pair, check what else shipped in its directory: a `uvx` resolves `uv` as its sibling, not through the PATH.
An updater is immune only when its version check reads its install target rather than a PATH lookup and the PATH resolves to that same target.

After removing software, `sys-orphans` (read-only) lists the references it left dangling, each with its fix command; `sys-cleanup` reclaims caches.

## Dotfiles and stow

- `~/dotfiles` holds stow packages (`agents`, `air`, `bin`, `bash`, `claude`, `css`, `firefox`, `gh`, `git`, `obsidian`, `opencode`, `panache`, `positron`, `prek`, `R`, `Rstudio`, `ruff`, `ssh`, `syncthing`, `zotero`). This is the package set, not the directory listing: `_meta/` holds profiles, tests and notes and is never stowed.
- Always create links with `stow`, never `ln -s`. Place the file inside its package in the target-relative layout (`~/dotfiles/bin/.local/bin/foo.sh`), then `cd ~/dotfiles && stow --no-folding <package>`; plain `stow` for `agents` and `css`, which stay folded, and for `claude`, whose skills must each be one directory link, once `~/.claude/skills` exists as a real directory (rationale in `README.md`).
- A stale symlink at the target is removed before stowing. A regular file at the target may hold edits not yet migrated into the package: surface it and confirm with the user, or move its content into the package, before removing it.
- `firefox` and `zotero` are tied to one machine: each carries only `user.js`, under a randomly generated profile directory (`z24d9fn6.default-release`, `pucr7b5d.default`), so a reinstalled or reset profile takes a new name and the link lands where the application never reads. Never stow either profile directory itself, which holds `places.sqlite`, `cookies.sqlite`, the cache and, for Zotero, `logins.json` and `key4.db`.
