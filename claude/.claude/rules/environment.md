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
| Typst  | 0.14    | PDF typesetting, via Quarto and standalone (`/snap/bin/typst`); tooling/gate in `rules/typst.md` |
| Rust   | 1.96    | Learning (systems/CLI programming); managed via `rustup` |

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
| prose-lint  | Mechanical anti-AI-slop checks for `.md`/`.qmd` (em/en dashes, soft wraps); local script (`~/.local/bin/prose-lint`) |
| cargo       | Rust build system / package manager (toolchain via `rustup`) |
| cargo clippy | Rust linter (binary `cargo-clippy`, run via `cargo clippy`; no standalone `clippy` command) |
| rustfmt     | Rust formatter (`cargo fmt`)                 |
| bacon       | Rust background checker (`cargo install bacon`) |
| typst       | Typst compiler (`/snap/bin/typst`); `typst compile`/`watch`. Gate in `rules/typst.md` |
| typstyle    | Typst formatter (`~/.cargo/bin/typstyle`; `--check`/`-i`)  |
| tinymist    | Typst language server, bundled in the Positron extension `myriad-dreamin.tinymist` (editor-only, not a PATH CLI) |
