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
| Python | 3.13 / 3.14 | NLP pipeline (langchain + llama.cpp). Two uv-managed interpreters, and which one applies depends on the layer: 3.14 is uv's default (`uv python find`) and runs every uv tool, while most project venvs are pinned to 3.13 by their `.python-version` (11 against 3 as of 2026-09-17, plugin cache copies excluded); of the nine `.venv` actually built, five run 3.13 and four run 3.14, one of which declares no `.python-version` and follows the uv default. Standalone PEP 723 scripts follow the uv default and declare `requires-python = ">=3.14"`: the template in `rules/python.md` and both such scripts in the dotfiles, `git/.config/git/out-textconv.py` and the `depouiller` skill's `scripts/squelette.py` (aligned 2026-09-14). Read the project's own pin rather than this table, and expect a new project to land on 3.14. Both are exposed in `~/.local/bin`, as `python3.13` and `python3.14`, and there is no bare `python` on the PATH at all, so every interpreter is addressed by its versioned name or through `uv run`. System `python3` is 3.12 (Ubuntu default) and carries no usable Jupyter stack: see `_meta/notes/jupyter-vestiges-cleanup.md` |
| Quarto | 1.10    | Docs generation (HTML via `quarto render`) |
| Pandoc | 3.11    | Markup conversion; Lua filters. Installed from the upstream `.deb` (Ubuntu 24.04 ships 3.1.3 and never advances). Quarto uses its own bundled copy, `quarto pandoc`, on a version of its own (1.10.18 bundles 3.10, against 3.11 in `/usr/bin` since 2026-08-28): for anything running inside a Quarto render, query that one, not `/usr/bin/pandoc`. 3.11 introduced `--math-method=METHOD[:URL]` and deprecated the per-engine flags (`--mathml`, `--mathjax`, `--katex`, `--webtex`), which now warn on every call: R tooling still emitting the old form (pkgdown 2.2.1, rmarkdown 2.32) floods a build with `[WARNING] Deprecated: --mathml`, which is cosmetic and leaves the output unchanged |
| Typst  | 0.15    | PDF typesetting, via Quarto and standalone (`/snap/bin/typst`); tooling/gate in `rules/typst.md` |
| Rust   | 1.97    | Learning (systems/CLI programming); managed via `rustup` |

## Package management

**R**

| Tool | Notes |
|------|-------|
| pak  | Default package installer (`pak::pak()`) outside `rv`-managed projects |
| rv   | Lockfile: `rv.lock`, config: `rproject.toml`. Inside an rv project, use `rv add <pkg>` (not pak) to keep the lockfile authoritative |

- CRAN mirror: `https://packagemanager.posit.co/cran/__linux__/noble/latest` (PPM, Linux noble binaries).
  Carried by `_meta/profiles/Rprofile.site`, symlinked into each `/opt/R/<version>/lib/R/etc/` by `stow-rprofile`, which `rig-update` re-runs whenever an install is missing it.
  The P3M entry rig writes in `etc/repositories` only feeds `setRepositories()`: without that symlink `repos` stays `@CRAN@`, pak falls back to `cran.rstudio.com` and every package builds from source.
  The `__linux__/<distro>` segment is what serves binaries, not the domain: `https://packagemanager.posit.co/cran/latest` returns `x-package-type: source` under the same R user agent.
  That second URL is what Positron's `positron.r.defaultRepositories: "posit-ppm"` sets, so the setting is no substitute for the symlink, and it defers to R startup scripts anyway.

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
The `positron`, `anki` and `libreoffice` modules also skip unless the application itself is on the PATH, since their updaters install it when absent and `stow bin` puts them on machines that must not get it (WSL); a first install calls the `<app>-update` script directly.
Prefer the module over an ad-hoc install or upgrade, so the maintained path stays authoritative.

Coverage is transitive where a package manager already tracks the tool: apt packages (shellcheck, shfmt) via `apt`, snaps (typst) via `snap`, cargo binaries (typstyle, shellharden, panache, bacon, pdf-inspector, filter-repo-rs, ggsql-cli) via `cargo`, cargo-dist installers (ruff, air, jarl, uv, prek) via `devtools`, uv tools via `uv-tools`, uv-managed Python interpreters via `uv-python`.
Transitive is not the same as current, and the apt pair is where the two part company: Ubuntu 24.04 holds shellcheck at 0.9.0-1 and shfmt at 3.8.0 as both installed and candidate, so `sys-update apt` will never advance them past that, against 0.11.0 and 3.13.1 upstream. The prek hooks pin those upstream versions, which puts the commit gate ahead of the local CLI rather than behind it: a file the terminal validates can fail at commit, never the reverse. Measured 2026-09-12 and inert so far, 0 finding from either shellcheck on the 30 shell scripts and the 26 bats files of the dotfiles repo, 0 diff from either shfmt, the two checks 0.11.0 adds being optional and off by default. Read a hook failure on a clean file as this gap before suspecting the file.

The `cargo` module passes `GGSQL_SKIP_GENERATE=1`, without which `cargo install ggsql-cli` cannot build on this machine: `tree-sitter-ggsql`'s build script regenerates the parser from `grammar.js` by default and so demands a `tree-sitter-cli` that is not installed, even though the published crate already ships the generated `src/parser.c`. The default is inverted for a crates.io release rather than specific to this machine, it is unchanged on upstream `HEAD`, and nothing is filed about it, so treat the variable as load-bearing until `posit-dev/ggsql` changes the default. It hits `cargo install ggsql-jupyter` the same way, which upstream does document.
Tools with a bespoke distribution shape each have a dedicated `<tool>-update` script wired as its own module (quarto, pandoc, lua-toolchain = stylua + lua-language-server, css-toolchain = stylelint + prettier + stylelint-config-standard-scss, duckdb, positron, rig, gh, rv, ...); `sys-update --list` is the authority for the full set.
The `npm` module only updates globally installed packages, so it does not cover the pinned CSS gate toolchain: that one is the `css-toolchain` module's job. Node and the npm binary itself come from the NodeSource apt repository (`nodejs`), so the `apt` module updates them, and the `npm` module stays an inline one-liner with no `npm-update` script, having no bespoke distribution shape to handle (decided 2026-09-14). That split holds only under the user prefix `~/.npm-global` (`npm config set prefix`, a machine-local `~/.npmrc` never stowed): with the default `/usr` prefix, `npm update -g` targets the deb-owned `npm` and fails with `EACCES`, measured on `ju-TP2` until 2026-09-19.
`uv-python` and `uv-tools` are two modules because `uv tool upgrade --all` updates the packages inside each tool venv and never the interpreter underneath, which left 3.14.0 running eleven months and seven patch releases behind its branch until `uv python upgrade` was wired in on 2026-09-12. The upgrade reaches most existing environments on its own: uv points a venv at a minor-version symlink (`cpython-3.14-linux-x86_64-gnu`) and repoints it, so those venvs follow the new patch without being recreated. A venv created against an explicit patch is not redirected, which upstream documents and which is not a rare case here: when the symlinks moved to 3.14.7 and 3.13.15 on 2026-09-12, eight venvs stayed behind on a hardcoded path, the `ouroboros-ai` and `yt-dlp` tools plus six project environments. So never read a green `uv-python` as proof that every interpreter moved: `<venv>/bin/python --version` is the only answer. Rebuilding such a venv against the minor request (`uv tool upgrade --all --python 3.14`, or a project's next `uv sync`) makes it follow from then on, and superseded patch directories cannot be removed until it does. Neither module installs anything absent, so a fresh machine still needs its `uv python install` and `uv tool install` by hand.

Positron extensions (Bash IDE, sumneko.lua, JohnnyMorganz.stylua, tinymist, SomewhatStationery.some-sass, esbenp.prettier-vscode, sqlfluff.vscode-sqlfluff) update in-editor; they are not CLIs and not covered by `sys-update`.

### One tool, one binary

Several extensions bundle a copy of a CLI that `sys-update` also maintains, and some push their copy onto the integrated terminal's PATH. The gate then runs a binary the editor updates and no module tracks, and since both copies work, the split shows up only as diagnostics or formatting that differ between the editor and the terminal. Each such extension is pinned to the managed binary instead:

| Tool | Extension setting | Resolves to | Kept current by |
|---|---|---|---|
| pyrefly | `pyrefly.lspPath` | `~/.local/bin/pyrefly` | `uv-tools` |
| air | `air.executableStrategy: "environment"` | `/usr/local/bin/air` | `devtools` |
| panache | `panache.executableStrategy: "environment"` | `~/.cargo/bin/panache` | `cargo` |

`rules/python.md` and `rules/r.md` carry the per-tool detail and the way back if a Positron upgrade ever outpaces the CLI.

The same split can come from two installs rather than an extension: `uv` sat in both `~/.local/bin` and `/usr/local/bin`, with the PATH picking the copy `devtools-update` neither version-checks nor updates. Removed 2026-07-27, `/usr/local/bin/uv` kept, alongside air, ruff, jarl and prek. That removal orphaned the `uvx` sitting beside it, which resolves `uv` as a sibling rather than through the PATH and so failed outright while masking the working `/usr/local/bin/uvx`; removed 2026-07-28. Deleting one binary of a pair means checking what else shipped in that directory. When a tool looks stale despite a green `sys-update`, run `command -v` on it before anything else.

Staleness has two independent causes, and a script needs both halves to be immune: its version check must read the install target rather than a PATH lookup, and the PATH must resolve that same target. Audited 2026-09-10 across the 13 per-tool updaters (`sys-update` itself being the orchestrator): only `devtools-update` (`"${prefix}/${tool}" --version`), `css-toolchain-update` (the manifest inside its gate directory) and `libreoffice-update` (`detect_installed` scans the `/opt/libreoffice*` trees, falling back to the PATH only when none answers) satisfy the first half, while `duckdb`, `pandoc`, `positron`, `rig`, `rv` and `lua-toolchain` address the tool through the PATH, `anki-update` keeps its own marker, `syncthing-update` leaves the version to apt and `claude-plugins-update` reads the pin it wrote into `mcp.json`. No script verifies the second half except `libreoffice-update`, whose `sync_bin_link` maintains the unversioned launcher because its install target is a versioned `/opt` path. `quarto-update` has covered both halves since 2026-09-13: it reads `"${PREFIX}/bin/quarto" --version`, since Positron's integrated terminal puts its bundled quarto first, and its own `sync_bin_link` creates or repoints `/usr/local/bin/quarto`, leaving a regular file there alone. The six converged when measured, so nothing is broken today, and the `uv` case above is the second half failing on a script whose first half was correct. `gh-update`, added 2026-09-18 after that audit, joins the PATH group: it reads `gh --version`.

## CLI tools available

| Tool    | Role                                      |
|---------|-------------------------------------------|
| git     | Version control                           |
| gh      | GitHub CLI (PRs, issues, releases)        |
| ripgrep | Fast code search (`rg`)                   |
| uv      | Python package/project manager            |
| ruff    | Python linter/formatter (via uv)          |
| pyrefly | Python type checker (`uv tool install pyrefly`); the checker Positron bootstraps. Gate and config caveat in `rules/python.md` |
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
| sys-orphans | Read-only detector of dangling references left by removed software (`~/.local/bin/sys-orphans`, `bin` stow package): venvs and scripts whose interpreter is gone, dead Jupyter kernelspecs, Claude Code plugin versions marked `.orphaned_at`, editor extension folders no registry (global or profile) references, dpkg packages whose non-doc files are all gone, dangling alternatives masters and systemd unit links, `~/.claude.json` projects whose folder is gone, R user libraries for an uninstalled R. Prints each finding with its fix command and removes nothing; `--count` prints the total, which `sys-cleanup` reads to end its run with a one-line hint. Complements `sys-cleanup`, which only reclaims caches with a mechanical criterion. Design in `~/dotfiles/.claude/PLAN-ORPHANS.md` |
| out-textconv.py | Renders an OOXML package or a PNG as stable text, as a git `textconv` driver, so `git diff` on a rendered `.docx`/`.xlsx`/`.pptx`/`.png` shows content changes alone and hides the metadata every write regenerates; local script shipped beside its config in the `git` stow package and called by path, not on the PATH (`~/.config/git/out-textconv.py`), with a `.py` extension so that `pyrefly check` and the editor treat it as Python. Declared as `[diff "out-textconv"]` in `~/dotfiles/git/.gitconfig`, consumed by a `diff=out-textconv` attribute in the project's `.gitattributes`. Reads only, never rewrites a stored byte, unlike the `html-id` clean filter beside it. Note: `_meta/notes/git-out-textconv.md` |
| prek-metadata-only | prek hook `metadata-only` (`~/.local/bin/prek-metadata-only`, `bin` stow package) built on `out-textconv`: fails the commit when a staged, modified `.docx`/`.pptx`/`.xlsx`/`.png` has an empty patch through that driver, meaning only write metadata moved, and ends its message on `prek-metadata-only --restore`, a mode that recomputes the set when run and restores each file from HEAD, only unstaging one whose working copy holds a newer render. Added files pass; fails closed when the driver is unconfigured or a staged, modified matched file's `diff` attribute is not `out-textconv`, so a project adopting the hook maps each type in `.gitattributes` or narrows the hook's `files`. Declared as a local `language = "system"` hook with `require_serial = true` in `_meta/profiles/prek.toml`, without which prek splits the files into per-CPU batches and repeats the message once per batch |
| panache     | Markdown/Quarto/Rmd formatter + LSP + linter (`~/.cargo/bin/panache`); delegates chunk formatting to `air` (the `ruff` half never fires) and chunk linting to `jarl`/`ruff`. Details in `rules/quarto.md` |
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
| sqlfluff    | SQL fixer + linter (`~/.local/bin/sqlfluff`, `uv tool install "sqlfluff[rs]"`); the whole gate on its own, `fix` then `lint`. Needs a project config naming a dialect (`.sqlfluff`, or `[tool.sqlfluff]` in `pyproject.toml`) or it exits 2. Gate in `rules/sql.md` |
| detect-pdf  | PDF classification, text vs scanned, plus per-page OCR / table / column routing (`cargo install pdf-inspector`). Always the first step on a PDF; routing in `rules/pdf.md` |
| pdf2md      | PDF to Markdown with multi-column reading order (same crate). Unsafe on slide decks: see the measured defects in `rules/pdf.md` |
| pdftotext   | Raw PDF text extraction (poppler-utils); `-layout` keeps the spatial arrangement, plain mode is the default for `rg` searches |
| pdfinfo     | PDF metadata: page count, `Creator`, `Producer` (poppler-utils). The `Producer` field is what decides the slide-deck branch in `rules/pdf.md` |
| pdftoppm    | PDF page to PNG (poppler-utils); the way to hand a scanned page to the native `Read` tool |
| chromium    | Headless browser (`/snap/bin/chromium`, snap, kept current by `sys-update snap`). The way to read computed styles of a rendered page (`--headless=new --dump-dom` over a probe calling `getComputedStyle`) and to capture it (`--screenshot`), which settles a CSS specificity dispute that a screenshot cannot. Snap confinement puts two directories out of reach, and one that looks out of reach is not. It cannot touch the session scratchpad under `/tmp`, where `--screenshot` fails with a misleading `Failed to write file ... No such file or directory`, so every capture and every probe goes in the project instead. It blocks dot-directories directly under `$HOME`. A project's own `.claude/` is fine, however, read and written alike, measured 2026-09-20 on `~/Documents/packages/quarto-hebstr-slide/.claude/screenshots/`: that is where captures belong, per the binary-artefact rule in `CLAUDE.md`, and writing them under `~/snap/` to move them afterwards is a detour born of this entry's earlier, over-general wording. Every headless launch takes its own throwaway profile, `P=$(mktemp -d ~/snap/chromium/common/claude-profile.XXXXXX); trap 'rm -rf "$P"' EXIT` then `--user-data-dir="$P"`, in the same shell call that ends the browser: without `--user-data-dir`, a run killed before it exits (a timeout, a CDP session torn down) leaves a `scoped_dir*` profile of up to ~146 MiB under `~/snap/chromium/common/chromium-headless/`, which piled up to 1141 dirs and 26.8 GiB between 2026-08-18 and 2026-09-13, while a fixed shared profile makes a concurrent launch abort with exit 21 on its `SingletonLock` (both measured 2026-09-13, `.claude/PLAN-ORPHANS.md` in the dotfiles). It is the only browser reachable from here: Firefox is installed but cannot start under the agent's sandbox, which denies the namespace it needs (`unshare(CLONE_NEWPID): EPERM`), and then misreports the failure as "Firefox is already running" whatever profile or `-no-remote` flag is passed. Chromium ships no hyphenation dictionary either (it fetches them through the component updater), so `hyphens: auto` measures identical to `hyphens: none` here even on words that hyphenate unambiguously: read that as "not measurable locally", never as "the property is inert" |
| libreoffice | Office suite, used headless only, as the sole engine on this machine that renders a `.docx` (`/usr/local/bin/libreoffice`, a symlink into a versioned `/opt/libreoffice<branch>/` tree installed from the TDF debs by the `libreoffice` module. The debs are branch-namespaced, so dpkg never treats a new branch as an upgrade and creates only branch-versioned launchers: `libreoffice-update` repoints the unversioned symlink itself and purges the superseded branch, leaving one tree. The `soffice` every online recipe names is that tree's binary and is not on the PATH). `--headless --convert-to pdf` feeds `pdftoppm` and then the native `Read` tool, which is how a Word output becomes visible here. Its divergence from Word falls on justification and line breaking, so the render shows gross breakage and settles nothing finer, and it accepts OOXML that Word refuses to open outright, so a clean conversion is no validity check either; routing and measured defects in `rules/docx.md` |
