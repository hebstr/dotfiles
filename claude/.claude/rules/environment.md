# Environment reference

On-demand reference for the machine's installed toolchain. Load when a runtime version or tool-availability check is decision-relevant.

## System

- OS: Ubuntu 24.04 LTS, x86_64

## Runtimes

| Tool   | Version | Usage |
|--------|---------|-------|
| R      | 4.6.0   | Data processing, statistical analysis |
| Python | 3.13.9  | NLP pipeline (langchain + ollama), data manipulation |
| Quarto | 1.9.37  | Book generation (HTML via `quarto render`) |
| Typst  | 0.14.2  | PDF typesetting (via Quarto) |

## Package management

**R**

| Tool | Notes |
|------|-------|
| pak  | Default package installer (`pak::pak()`) |
| rv   | Lockfile: `rv.lock`, config: `rproject.toml` |

- CRAN mirror: `https://packagemanager.posit.co/cran/__linux__/noble/latest` (PPM, Linux noble binaries)

**Python**

| Tool | Notes |
|------|-------|
| uv   | Lockfile: `uv.lock`, config: `pyproject.toml` |

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
