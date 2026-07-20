---
paths:
  - "**/*.lua"
---

# Lua toolchain

## Scope: Pandoc / Quarto filter Lua

This file governs Lua written for Pandoc and Quarto: filters, shortcodes, and the small modules they call, as found under `_extensions/*/` in a Quarto extension repo.
It does not govern Neovim Lua, Roblox Lua, or any other dialect; the type checking below is wired specifically to the Pandoc and Quarto APIs and is meaningless outside them.
A filter edit does not end at this gate: the filter only runs inside a `quarto render`, so after the Lua gate passes, the consuming document (`example.qmd` or the project) must still render clean under `rules/quarto.md`.
Editing a `.qmd` itself never triggers this gate; that path is `rules/quarto.md` alone.

## CLI tools

| Tool | Role |
|---|---|
| `stylua` | Formatter (`~/.local/bin/stylua`, prebuilt binary from the `JohnnyMorganz/StyLua` releases). Reads project `stylua.toml`. `--check` validates (exit 1 if unformatted), no flag rewrites in place |
| `lua-language-server` | LSP and type checker (`~/.local/bin/lua-language-server` → `~/.local/share/lua-language-server/`). `--check <workspace-root>` runs a headless type and diagnostics pass. No separate linter CLI exists; LuaLS is both |

There is no fixer stage before the formatter for Lua: StyLua is the only mutation, and `lua-language-server --check` is report-only.
This makes the gate shorter than shell's or Python's, closer to `rules/typst.md`.

## Per-project prerequisite: `.luarc.json` + vendored stubs

`lua-language-server --check` is useless against Pandoc or Quarto code without the API type stubs, and it is workspace-scoped: it reads a `.luarc.json` at the workspace root and resolves every relative path against that root.
A project of filters therefore needs, committed at its root:

- `stylua.toml` pinning `indent_type = "Spaces"` and `indent_width = 2` (see Formatter settings below).
- `.luarc.json` (manually managed, no `Generator` key, so Quarto does not overwrite it) pointing `Lua.workspace.library` and `Lua.runtime.plugin` at a vendored copy of the stubs by relative path.
- `.luals/` holding that vendored copy: `.luals/types/` (the `pandoc/` and `quarto/` LuaCATS stubs) and `.luals/plugin.lua` (the runtime plugin that types filter-callback parameters). Source them from `/opt/quarto/share/lua-types/` and `/opt/quarto/share/lua-plugin/plugin.lua`; both are MIT, so committing them is fine. Record the source and a re-sync command in the file so it can be refreshed when Quarto updates.
- `Lua.workspace.ignoreDir` listing `.luals` (do not diagnose the stubs themselves) and any third-party extension vendored inside this one (for example `_extensions/<name>/_extensions`, which holds installed dependencies that are not this project's code).

Put `.luarc.json` and `.luals/` at the repo root, outside `_extensions/`, so `quarto add` does not ship the dev tooling to consumers.
Un-gitignore `.luarc.json`: Quarto's editor extension generates one with absolute paths and adds it to `.gitignore`; the committed relative-path version replaces it and must be tracked.

The absolute-path `.luarc.json` that Quarto generates is machine-specific and gitignored, so it gives CI and collaborators nothing.
The vendored relative-path setup is the one that works for the author, CI, and a collaborator at once.

## Mandatory pipeline after every create/edit of a `.lua`

Run the gate when the edit meets the non-trivial threshold in `CLAUDE.md` (new file, new function, logic change beyond ~10 lines or adding a branch); skip for one-line typo fixes.

```sh
stylua <file>.lua                                        # format in place
stylua --check <file>.lua                                # confirm formatted (exit 1 if not)
lua-language-server --check <workspace-root> --checklevel Warning
```

The linter's argument is the workspace root (the directory holding `.luarc.json`), not the edited file.
Point it at a single file or a subdirectory and it finds no `.luarc.json`, loads no stubs, and reports false `undefined global pandoc` on every AST call.
It checks the whole project minus `ignoreDir`, prints results to stdout, and exits 1 when any problem remains (verified on LuaLS 3.18; there is no `check.json` to locate).
`--checklevel Warning` is the floor: `Information` and `Hint` add `unused-local` and similar noise that buries the real diagnostics.
Keep the log files out of the repo with `--logpath` to a temp directory; they are not needed to read the result.

A hard failure is `lua-language-server --check` reporting a problem, or `stylua --check` still reporting after the in-place run.
On a hard failure, fix and re-run from the top at most once; if the second pass still fails, surface the residual to the user.
For a no-mutation CI gate, run `stylua --check` plus the `lua-language-server --check`, neither of which writes to tracked files.

## Useful flags

**stylua**

| Flag | Effect |
|---|---|
| `-c, --check` | Check mode: exit 1 if any file is unformatted, print diffs, write nothing (the gate's validating step) |
| `-f, --config-path <path>` | Use an explicit `stylua.toml`; default searches the current directory |
| `--output-format <fmt>` | Diff format in check mode: `Standard`, `Unified`, `Json`, `Summary` (`Json` for CI parsing) |
| `--verify` | Re-check the output AST against the input to catch a correctness change introduced by formatting |

**lua-language-server**

| Flag | Effect |
|---|---|
| `--check <dir>` | Run the headless diagnostics pass on the workspace root (the gate's lint step) |
| `--checklevel <level>` | Minimum level reported: `Error`, `Warning`, `Information`, `Hint` (default `Warning`, the floor the gate uses) |
| `--configpath <path>` | Load a specific config, relative to the workspace; suppresses any editor-provided config |
| `--check_format <fmt>` | `pretty` (stdout, default) or `json` (written under `--logpath`); the default is why no `check.json` appears |
| `--logpath <path>` | Directory for the diagnostics log; point it at a temp dir to keep logs out of the repo |

## What the type checker catches, and one thing it does not

LuaLS with the Quarto stubs catches undefined globals, `need-check-nil`, type mismatches on assignment, wrong argument and return arity, and misspelled fields on `@class`-typed values (an AST node like a misspelled `doc.blockss`, since the plugin types the filter-callback parameter).

It does not catch a misspelled function on the `pandoc.*` or `quarto.*` module tables (`pandoc.system.list_directoy` for `list_directory`), because the upstream stubs declare those modules as open tables rather than classes.
This is a stub-authoring limit, not a config one; do not patch the vendored stubs to close it.
The Quarto stubs also lag the bundled pandoc (they are pinned to an older commit), so an occasional false diagnostic on a newer API is expected; note it rather than disabling the check.

## Formatter settings

StyLua reads `stylua.toml` from the project root, and the CLI, the pre-commit hook, and the editor extension all read that same file.
So the three agree by construction, unlike typstyle or shfmt where the width is passed separately in each place and can drift.
The one requirement is that the editor is not configured to override the project config or to use LuaLS's own built-in formatter (see Editor tooling).
The pinned values are `indent_type = "Spaces"` and `indent_width = 2`; changing them means editing only `stylua.toml`.

## Pre-commit hook (prek)

Add StyLua's official hook to the `_meta/profiles/prek.toml` scaffold, scoped to `\.lua$`:
use the `stylua-github` id from the `JohnnyMorganz/StyLua` repo, which downloads the release binary and so needs no Rust toolchain on the target (matching the multi-user deploy model of the other hooks).
It formats in place and reads the project `stylua.toml`, so it needs no width or indent arguments, matching the mutating convention of `ruff-format` and `shfmt -w`.
Do not copy the hook `rev` into this file (it drifts; the scaffold is the source of truth).
Do not add the hook to the dotfiles repo's own root `prek.toml`: that repo contains no `.lua` files, following the precedent set for typstyle.

There is no prek hook for `lua-language-server --check`: it needs the per-project `.luarc.json` and vendored stubs to mean anything, so it stays a local and CI gate step, not a commit hook.

## Editor tooling

Positron uses Open VSX; install two extensions, since no single one covers both diagnostics and formatting the way tinymist does for Typst:

- `sumneko.lua` (the LuaLS server, diagnostics and completion; bundles its own server binary).
- `JohnnyMorganz.stylua` (the formatter; drives the same `stylua` binary and `stylua.toml`).

LuaLS ships its own formatter, which would fight StyLua.
In the active Positron profile, set the `[lua]` `editor.defaultFormatter` to `JohnnyMorganz.stylua`, leave LuaLS's `Lua.format.enable` off, and add `formatOnSave`.
The LuaLS extension reads the project `.luarc.json`, so completion and diagnostics in-editor match the `--check` gate exactly.

## References

- Quarto Lua development and `.luarc.json`: https://quarto.org/docs/extensions/lua.html
- Quarto Lua API: https://quarto.org/docs/extensions/lua-api.html
- Pandoc Lua filters manual: https://pandoc.org/lua-filters.html
- StyLua: https://github.com/JohnnyMorganz/StyLua
- lua-language-server wiki: https://luals.github.io/wiki/
