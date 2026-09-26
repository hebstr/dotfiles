---
name: Tool update routines (devtools-update vs cargo install-update vs uv tool upgrade vs uv python upgrade)
description: Four disjoint update mechanisms on the user's machine; do not conflate them when adding/auditing a tool
metadata:
  type: reference
---

The user has four separate update routines, three for tools and one for the interpreter the uv tools run on. Match the routine to how the thing is installed; never add a tool to the wrong one.

The per-routine inventories, the `GGSQL_SKIP_GENERATE=1` the `cargo` module needs (run `cargo install-update -a` by hand the same way, never bare), and why `uv-python` is a module apart from `uv-tools` are in `~/dotfiles/claude/.claude/rules/install.md` § "One entry point: `sys-update`" and § "Covered is not current", the fuller record in `~/dotfiles/_meta/notes/environment-archive.md` § "Keeping the toolchain current". What that section does not say:

- **`devtools-update`** handles cargo-dist binaries only, via each repo's `<tool>-installer.sh` on GitHub `releases/latest`, installed system-wide to `/usr/local/bin`. Eligibility is mechanical: the repo must publish `<tool>-installer.sh`, and adding a tool that has none produces a 404 URL.
- **`cargo install-update`** updates every crate registered in `~/.cargo/.crates.toml`, which is what `cargo install` writes; a binary dropped into `~/.cargo/bin` by any other means carries no entry and is invisible to it (none left since `arf` was removed on 2026-09-25).
- **`uv tool upgrade --all`** updates everything installed with `uv tool install` (binary in `~/.local/bin`). A tool being Rust-written says nothing here: pyrefly is Rust and belongs to this routine, not the two above. `huggingface-hub` belongs to it on `ju-TP2`, where the models live. It only updates; nothing in the repo installs a uv tool on a fresh machine (backlog item in `~/dotfiles/.claude/DEFERRED.md`).

Decision rule when a new tool appears, in order. Is it `uv tool install`-ed (present in `uv tool list`, binary in `~/.local/bin`)? → `uv tool upgrade --all`, add nothing. Otherwise, for a Rust tool: does its repo ship `<tool>-installer.sh`? Yes and you want it system-wide → `devtools-update`. No, or it is `cargo install`-ed into `~/.cargo/bin` → it is already covered by `cargo install-update`, add nothing.

An editor extension bundling its own copy of one of these binaries: see `rules/install.md` § "One tool, one binary".

Worked examples (2026-06-09):
- **typstyle**: cargo-installed, no cargo-dist installer → belongs to `cargo install-update`, NOT devtools-update. (I initially proposed adding it to devtools-update; that was wrong.)
- **tinymist**: ships a cargo-dist installer (eligible by mechanism) but its server binary is bundled in the Positron extension `myriad-dreamin.tinymist` (`serverPath` defaults to bundled), so a system-wide install would be a dead consumer. Do not add.
- **prek**: was installed by BOTH routines (cargo copy shadowed the `/usr/local/bin` one in PATH). Resolved by `cargo uninstall prek`, keeping the devtools-update entry so prek aligns with its cargo-dist peers. Pick one routine per tool.
- **panache**: cargo-installed into `~/.cargo/bin` (`panache 3.0.0` in `.crates.toml`, confirmed crates.io registry source) → already covered by `cargo install-update`, NOT eligible for devtools-update. Same category as typstyle.

Related: [[feedback_verify_after_install]], [[feedback_review_severity_shell_installers]].
