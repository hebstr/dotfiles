---
name: Tool update routines (devtools-update vs cargo install-update vs uv tool upgrade vs uv python upgrade)
description: Four disjoint update mechanisms on the user's machine, and the separate `agent-skills` route a third-party agent skill takes instead of all four; do not conflate them when adding/auditing a tool, and how `uv python upgrade` reaches the uv tool venvs (read `pyvenv.cfg`, never `readlink -f`)
metadata:
  type: reference
---

The user has four separate update routines, three for tools and one for the interpreter the uv tools run on. Match the routine to how the thing is installed; never add a tool to the wrong one.

These four cover binaries only. A third-party *agent skill* installed from GitHub takes none of them: it goes through the `skills` CLI and the lock of the `agents` stow package, and updates through the `agent-skills` module of `sys-update`. The install form, the two-target rule that keeps the CLI in symlink mode, and the rejected alternatives are in `~/dotfiles/.claude/DESIGN-AGENT-SKILLS.md`. Read that note before proposing any other shape for a third-party skill: on 2026-10-16 its absence from this memory produced a recommendation to clone the repository by hand, which the note had already rejected.

The per-routine inventories, the `GGSQL_SKIP_GENERATE=1` the `cargo` module needs (run `cargo install-update -a` by hand the same way, never bare), and why `uv-python` is a module apart from `uv-tools` are in `~/dotfiles/claude/.claude/rules/install.md` § "One entry point: `sys-update`" and § "Covered is not current", the fuller record in `~/dotfiles/_meta/notes/environment-archive.md` § "Keeping the toolchain current". What that section does not say:

- **`devtools-update`** handles cargo-dist binaries only, via each repo's `<tool>-installer.sh` on GitHub `releases/latest`, installed system-wide to `/usr/local/bin`. Eligibility is mechanical: the repo must publish `<tool>-installer.sh`, and adding a tool that has none produces a 404 URL.
- **`cargo install-update`** updates every crate registered in `~/.cargo/.crates.toml`, which is what `cargo install` writes; a binary dropped into `~/.cargo/bin` by any other means carries no entry and is invisible to it (none left since `arf` was removed on 2026-09-25).
- **`uv tool upgrade --all`** updates everything installed with `uv tool install` (binary in `~/.local/bin`). A tool being Rust-written says nothing here: pyrefly is Rust and belongs to this routine, not the two above. `huggingface-hub` belongs to it on `ju-TP2`, where the models live. It only updates; nothing in the repo installs a uv tool on a fresh machine, which `rules/install.md` states as the design rather than as a gap. A versioned install manifest was rejected on 2026-10-12 and is not to be re-proposed without a new fact: see [[feedback_review_severity_shell_installers]].
- **`uv python upgrade`** reaches the tool venvs only because they are bound to the minor-version symlink rather than to a patch directory: measured 2026-09-20 on `ju-TP`, the seven tool venvs of that day all read `home = .../cpython-3.14-linux-x86_64-gnu/bin` in their `pyvenv.cfg`, so the upgrade redirected all seven. The set is five on 2026-10-09 (`ggsql-jupyter`, `pyrefly`, `showboat`, `sqlfluff`, `yt-dlp`), all still bound the same way. That is a per-venv property, not a guarantee: `rules/install.md` records that one built against an explicit patch stays behind, and that a green `uv-python` proves nothing about a given venv. Check a venv by reading its `pyvenv.cfg`, never with `readlink -f` on its `bin/python`, which resolves through to the patch directory either way and reports a pinned venv and a following one identically. Since 2026-10-29 the module also prunes the patches the upgrade superseded, which uv itself never removes: rule and its one failure mode in `rules/install.md` § "Covered is not current".

Decision rule when a new tool appears, in order. Is it `uv tool install`-ed (present in `uv tool list`, binary in `~/.local/bin`)? → `uv tool upgrade --all`, add nothing. Otherwise, for a Rust tool: does its repo ship `<tool>-installer.sh`? Yes and you want it system-wide → `devtools-update`. No, or it is `cargo install`-ed into `~/.cargo/bin` → it is already covered by `cargo install-update`, add nothing.

An editor extension bundling its own copy of one of these binaries: see `rules/install.md` § "One tool, one binary".

Worked examples (2026-06-09):
- **typstyle**: cargo-installed, no cargo-dist installer → belongs to `cargo install-update`, NOT devtools-update. (I initially proposed adding it to devtools-update; that was wrong.)
- **tinymist**: ships a cargo-dist installer (eligible by mechanism) but its server binary is bundled in the Positron extension `myriad-dreamin.tinymist` (`serverPath` defaults to bundled), so a system-wide install would be a dead consumer. Do not add.
- **prek**: was installed by BOTH routines (cargo copy shadowed the `/usr/local/bin` one in PATH). Resolved by `cargo uninstall prek`, keeping the devtools-update entry so prek aligns with its cargo-dist peers. Pick one routine per tool.
- **panache**: cargo-installed into `~/.cargo/bin` (`panache 3.14.0` in `.crates.toml` on 2026-10-09, confirmed crates.io registry source) → already covered by `cargo install-update`, NOT eligible for devtools-update. Same category as typstyle.

Related: [[feedback_verify_after_install]], [[feedback_review_severity_shell_installers]].
