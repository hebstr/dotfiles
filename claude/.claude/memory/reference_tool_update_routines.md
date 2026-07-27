---
name: Tool update routines (devtools-update vs cargo install-update vs uv tools)
description: Three disjoint update mechanisms on the user's machine; do not conflate them when adding/auditing a tool
metadata:
  type: reference
---

The user has three separate tool-update routines. Match the routine to how the tool is installed; never add a tool to the wrong one.

- **`devtools-update`** (`~/dotfiles/bin/.local/bin/devtools-update`): handles **cargo-dist binaries only**, via each repo's `<tool>-installer.sh` on GitHub `releases/latest`, piped through `sudo env <VAR>=<prefix> sh`, installed **system-wide to `/usr/local/bin`**. Eligibility is mechanical: the repo must publish `<tool>-installer.sh`. Current set: air, jarl, uv, ruff, prek. Adding a tool that has no cargo-dist installer produces a 404 URL.
- **`cargo install-update`** (the `cargo-update` crate, binary `cargo-install-update`): updates everything in `~/.cargo/bin` from crates.io. Covers: cargo-update, bacon, filter-repo-rs, ggsql-cli, shellharden, typstyle, panache. `sys-update`'s `cargo` module runs `cargo install-update -a` (or run it directly to update just these).
- **`uv tool upgrade --all`**: updates everything installed with `uv tool install`, which lands in `~/.local/bin`. Covers: pyrefly, showboat, ouroboros-ai, huggingface-hub, youtube-transcript-api, yt-dlp. `sys-update`'s `uv-tools` module runs it. A tool being Rust-written says nothing here: pyrefly is Rust and belongs to this routine, not the two above. This routine only *updates*; nothing in the repo installs a uv tool on a fresh machine (backlog item in `.claude/DEFERRED.md`, scope = all six).

Decision rule when a new tool appears, in order. Is it `uv tool install`-ed (present in `uv tool list`, binary in `~/.local/bin`)? → `uv tool upgrade --all`, add nothing. Otherwise, for a Rust tool: does its repo ship `<tool>-installer.sh`? Yes and you want it system-wide → `devtools-update`. No, or it is `cargo install`-ed into `~/.cargo/bin` → it is already covered by `cargo install-update`, add nothing.

Orthogonal to all three: when an editor extension bundles its own copy of one of these binaries, the maintained copy and the running copy can differ. `rules/environment.md` ("One tool, one binary") holds the current mountings (pyrefly, air, panache) and the `command -v` reflex.

Worked examples (2026-06-09):
- **typstyle**: cargo-installed, no cargo-dist installer → belongs to `cargo install-update`, NOT devtools-update. (I initially proposed adding it to devtools-update; that was wrong.)
- **tinymist**: ships a cargo-dist installer (eligible by mechanism) but its server binary is bundled in the Positron extension `myriad-dreamin.tinymist` (`serverPath` defaults to bundled), so a system-wide install would be a dead consumer. Do not add.
- **prek**: was installed by BOTH routines (cargo copy shadowed the `/usr/local/bin` one in PATH). Resolved by `cargo uninstall prek`, keeping the devtools-update entry so prek aligns with its cargo-dist peers. Pick one routine per tool.
- **panache**: cargo-installed into `~/.cargo/bin` (`panache 3.0.0` in `.crates.toml`, confirmed crates.io registry source) → already covered by `cargo install-update`, NOT eligible for devtools-update. Same category as typstyle. Note its Positron extension `jolars.panache` uses `panache.executableStrategy: environment`, so this `~/.cargo/bin` binary IS the live consumer (not the extension-bundled `server/panache`).

Related: [[feedback_verify_after_install]], [[project_rv_install_deployment]].
