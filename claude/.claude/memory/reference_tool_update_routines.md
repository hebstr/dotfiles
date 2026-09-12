---
name: Tool update routines (devtools-update vs cargo install-update vs uv tool upgrade vs uv python upgrade)
description: Four disjoint update mechanisms on the user's machine; do not conflate them when adding/auditing a tool
metadata:
  type: reference
---

The user has four separate update routines, three for tools and one for the interpreter the uv tools run on. Match the routine to how the thing is installed; never add a tool to the wrong one.

- **`devtools-update`** (`~/dotfiles/bin/.local/bin/devtools-update`): handles **cargo-dist binaries only**, via each repo's `<tool>-installer.sh` on GitHub `releases/latest`, piped through `sudo env <VAR>=<prefix> sh`, installed **system-wide to `/usr/local/bin`**. Eligibility is mechanical: the repo must publish `<tool>-installer.sh`. Current set: air, jarl, uv, ruff, prek. Adding a tool that has no cargo-dist installer produces a 404 URL.
- **`cargo install-update`** (the `cargo-update` crate, binary `cargo-install-update`): updates every crate registered in `~/.cargo/.crates.toml` from crates.io, which is what `cargo install` writes there; a binary dropped into `~/.cargo/bin` by any other means (`arf`, currently) carries no entry and is invisible to it. Covers: cargo-update, bacon, filter-repo-rs, ggsql-cli, shellharden, typstyle, panache. `sys-update`'s `cargo` module runs `env GGSQL_SKIP_GENERATE=1 cargo install-update -a`, and that variable is load-bearing rather than decorative: without it `tree-sitter-ggsql`'s build script regenerates the parser from `grammar.js` and demands a `tree-sitter-cli` that is not installed, so the whole `-a` run fails on `ggsql-cli`. Run it by hand the same way, never bare.
- **`uv tool upgrade --all`**: updates everything installed with `uv tool install`, which lands in `~/.local/bin`. Covers: pyrefly, sqlfluff, showboat, ouroboros-ai, huggingface-hub, yt-dlp. `sys-update`'s `uv-tools` module runs it. A tool being Rust-written says nothing here: pyrefly is Rust and belongs to this routine, not the two above. This routine only *updates*; nothing in the repo installs a uv tool on a fresh machine (backlog item in `.claude/DEFERRED.md`, scope = the six tools plus the uv-managed interpreters).
  This routine stops at the package layer: `uv tool upgrade` refreshes what lives inside each tool venv and never the interpreter underneath. That interpreter is `sys-update`'s separate `uv-python` module (`uv python upgrade`), which moves each installed branch to its latest patch and likewise installs nothing absent. The two are wired as distinct modules for that reason, `uv-python` ordered first so the tool venvs follow the new patch; `rules/environment.md` holds the caveat that a venv created against an explicit patch is not redirected, so a green `uv-python` is no proof that every interpreter moved.

Decision rule when a new tool appears, in order. Is it `uv tool install`-ed (present in `uv tool list`, binary in `~/.local/bin`)? → `uv tool upgrade --all`, add nothing. Otherwise, for a Rust tool: does its repo ship `<tool>-installer.sh`? Yes and you want it system-wide → `devtools-update`. No, or it is `cargo install`-ed into `~/.cargo/bin` → it is already covered by `cargo install-update`, add nothing.

Orthogonal to the three tool routines: when an editor extension bundles its own copy of one of these binaries, the maintained copy and the running copy can differ. `rules/environment.md` ("One tool, one binary") holds the current mountings (pyrefly, air, panache) and the `command -v` reflex.

Worked examples (2026-06-09):
- **typstyle**: cargo-installed, no cargo-dist installer → belongs to `cargo install-update`, NOT devtools-update. (I initially proposed adding it to devtools-update; that was wrong.)
- **tinymist**: ships a cargo-dist installer (eligible by mechanism) but its server binary is bundled in the Positron extension `myriad-dreamin.tinymist` (`serverPath` defaults to bundled), so a system-wide install would be a dead consumer. Do not add.
- **prek**: was installed by BOTH routines (cargo copy shadowed the `/usr/local/bin` one in PATH). Resolved by `cargo uninstall prek`, keeping the devtools-update entry so prek aligns with its cargo-dist peers. Pick one routine per tool.
- **panache**: cargo-installed into `~/.cargo/bin` (`panache 3.0.0` in `.crates.toml`, confirmed crates.io registry source) → already covered by `cargo install-update`, NOT eligible for devtools-update. Same category as typstyle. Note its Positron extension `jolars.panache` uses `panache.executableStrategy: environment`, so this `~/.cargo/bin` binary IS the live consumer (not the extension-bundled `server/panache`).

Related: [[feedback_verify_after_install]], [[project_rv_install_deployment]].
