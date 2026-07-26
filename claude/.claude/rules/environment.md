# Environment reference

On-demand reference for the machine's installed toolchain. Load when a runtime version or tool-availability check is decision-relevant.

## System

- OS: Ubuntu 24.04 LTS, x86_64

## Runtimes

Versions are major.minor (stable enough to gate idiom/feature choices: native pipe, `match`, `_brand.yml`). For the exact patch, query the binary (`R --version`, `python --version`, `quarto --version`, `typst --version`); do not rely on this table for patch-level decisions.

| Tool   | Version | Usage |
|--------|---------|-------|
| bash   | 5.2     | Scripting; system shell. `/bin/sh` is dash (POSIX), so `#!/bin/sh` lacks bash idioms. Tooling/gate in `rules/shell.md` |
| R      | 4.6     | Data processing, statistical analysis |
| Python | 3.13    | NLP pipeline (langchain + llama.cpp). uv-managed (3.13.x, the authoring version); system `python3` is 3.12 (Ubuntu default) |
| Quarto | 1.9     | Docs generation (HTML via `quarto render`) |
| Pandoc | 3.10    | Markup conversion; Lua filters. Installed from the upstream `.deb` (Ubuntu 24.04 ships 3.1.3 and never advances). Quarto uses its own bundled copy, `quarto pandoc`, on a different version (1.9.38 bundles 3.8.3): for anything running inside a Quarto render, query that one, not `/usr/bin/pandoc` |
| Typst  | 0.15    | PDF typesetting, via Quarto and standalone (`/snap/bin/typst`); tooling/gate in `rules/typst.md` |
| Rust   | 1.97    | Learning (systems/CLI programming); managed via `rustup` |

## Package management

**R**

| Tool | Notes |
|------|-------|
| pak  | Default package installer (`pak::pak()`) outside `rv`-managed projects |
| rv   | Lockfile: `rv.lock`, config: `rproject.toml`. Inside an rv project, use `rv add <pkg>` (not pak) to keep the lockfile authoritative |

- CRAN mirror: `https://packagemanager.posit.co/cran/__linux__/noble/latest` (PPM, Linux noble binaries)

**Python**

| Tool | Notes |
|------|-------|
| uv   | Lockfile: `uv.lock`, config: `pyproject.toml` |

**Rust**

| Tool   | Notes |
|--------|-------|
| cargo  | Build system + package manager. Lockfile: `Cargo.lock`, config: `Cargo.toml`. `cargo add` is built in. Registry: crates.io |
| rustup | Toolchain manager (`rustup show`, `rustup component add`) |

## Keeping the toolchain current

`sys-update` (in `bin/`) is the single entry point and orchestrates every updater as a module: `sys-update --list` for the current set, `sys-update <module>` to run one, no arguments for all.
Prefer the module over an ad-hoc install or upgrade, so the maintained path stays authoritative.

Coverage is transitive where a package manager already tracks the tool: apt packages (shellcheck, shfmt) via `apt`, snaps (typst) via `snap`, cargo binaries (typstyle, shellharden, panache, bacon) via `cargo`, cargo-dist installers (ruff, air, jarl, uv, prek) via `devtools`, uv tools via `uv-tools`.
Tools with a bespoke distribution shape each have a dedicated `<tool>-update` script wired as its own module (quarto, pandoc, lua-toolchain = stylua + lua-language-server, css-toolchain = stylelint + prettier + stylelint-config-standard-scss, duckdb, positron, rig, rv, ...); `sys-update --list` is the authority for the full set.
The `npm` module only updates globally installed packages, so it does not cover the pinned CSS gate toolchain: that one is the `css-toolchain` module's job.

Positron extensions (Bash IDE, sumneko.lua, JohnnyMorganz.stylua, tinymist, SomewhatStationery.some-sass, esbenp.prettier-vscode) update in-editor; they are not CLIs and not covered by `sys-update`.

## CLI tools available

| Tool    | Role                                      |
|---------|-------------------------------------------|
| git     | Version control                           |
| gh      | GitHub CLI (PRs, issues, releases)        |
| ripgrep | Fast code search (`rg`)                   |
| uv      | Python package/project manager            |
| ruff    | Python linter/formatter (via uv)          |
| air     | R formatter                               |
| jarl    | R linter                                  |
| delta   | Structured diffs with line numbers        |
| fd      | File search by name (`fdfind`)            |
| jq      | JSON processor                            |
| duckdb  | SQL queries from shell (`~/.local/bin/duckdb`) |
| rig     | R version manager (`rig default <version>`)    |
| stow    | Symlink manager for dotfiles (`~/dotfiles`)    |
| showboat | Executable demo documents (`uv tool install showboat`) |
| shellcheck  | Shell linter (static analysis, `SC*` codes)  |
| shellharden | Auto-fix shell variable quoting              |
| shfmt       | Shell formatter (indentation, spacing)       |
| prek        | Pre-commit hooks runner (Rust, replaces pre-commit) |
| bats        | Bash TDD framework |
| prose-lint  | Mechanical anti-AI-slop checks for `.md`/`.qmd` (em/en dashes); local script (`~/.local/bin/prose-lint`) |
| panache     | Markdown/Quarto/Rmd formatter + LSP + linter (`~/.cargo/bin/panache`); delegates chunk formatting to `air`/`ruff` and chunk linting to `jarl`/`ruff`. Details in `rules/quarto.md` |
| cargo       | Rust build system / package manager (toolchain via `rustup`) |
| cargo clippy | Rust linter (binary `cargo-clippy`, run via `cargo clippy`; no standalone `clippy` command) |
| rustfmt     | Rust formatter (`cargo fmt`)                 |
| bacon       | Rust background checker (`cargo install bacon`) |
| typst       | Typst compiler (`/snap/bin/typst`); `typst compile`/`watch`. Gate in `rules/typst.md` |
| typstyle    | Typst formatter (`~/.cargo/bin/typstyle`; `--check`/`-i`)  |
| tinymist    | Typst language server, bundled in the Positron extension `myriad-dreamin.tinymist` (editor-only, not a PATH CLI) |
| stylua      | Lua formatter (`~/.local/bin/stylua`; `--check`/in-place). Project settings via `stylua.toml`. Gate in `rules/lua.md` |
| stylelint   | CSS/SCSS linter (`~/.local/bin/stylelint`, symlink into the pinned toolchain at `~/.local/share/css-gate/`). Needs `--config` on every call. Gate in `rules/css.md` |
| prettier    | CSS/SCSS formatter (`~/.local/bin/prettier`, same toolchain). Gate in `rules/css.md` |
| lua-language-server | Lua LSP + type checker (`~/.local/bin/lua-language-server` → `~/.local/share/lua-language-server/`); `--check <dir>` for CLI diagnostics against Quarto LuaCATS stubs. Gate in `rules/lua.md` |
