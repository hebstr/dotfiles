---
name: "Lua lint/format/test gate for Quarto filters (rules/lua.md)"
description: How the Lua gate is wired for Pandoc/Quarto extension filters — the workspace-root LuaLS check, the vendored .luarc.json/.luals setup, the shortcode test harness, and why the gate does not overlap adversarial-audit findings
metadata:
  type: reference
---

`rules/lua.md` exists and auto-loads on `**/*.lua`. The gate is `stylua` (format) then `lua-language-server --check` (report-only type/diagnostics); no fixer stage before the formatter. Built 2026-07-20; first consumer is `~/Documents/packages/quarto-hebstr-doc`. Tools installed at `~/.local/bin/{stylua,lua-language-server}` (trace: `~/dotfiles/_meta/notes/lua-toolchain.md`).

**`lua-language-server --check` targets the workspace ROOT, not a file.** Its argument must be the directory holding `.luarc.json`; it resolves the relative library path against that root and checks the whole project. Point it at a single file or a subdir and it finds no config, loads no stubs, and reports false `undefined global pandoc` on every AST call. On LuaLS 3.18 it prints to stdout and exits 1 on any problem (no `check.json` to locate). Use `--checklevel Warning` (lower levels add `unused-local` noise).

**Per-project prerequisite** (committed at repo root, outside `_extensions/` so `quarto add` does not ship it): a manually-managed `.luarc.json` (drop the `Generator` key or Quarto rewrites it) with repo-relative paths into a vendored `.luals/` (stubs from `/opt/quarto/share/lua-types/`, plugin from `/opt/quarto/share/lua-plugin/plugin.lua`, both MIT); `stylua.toml` (`indent_type="Spaces"`, `indent_width=2`); and `Lua.workspace.ignoreDir` listing `.luals`, any vendored third-party extension, and `tests/luaunit.lua`. Un-gitignore `.luarc.json` (Quarto's auto-generated one uses absolute paths and is gitignored, useless for CI/collaborators). `fdfind` will not find the gitignored one without `-I`.

**Testing Quarto filters:** they are shortcodes (`return { name = function(args, kwargs, meta) end }`), not Pandoc document filters, so `pandoc.utils.run_lua_filter` does not invoke them. Load the file with `dofile` (globals `quarto`/`PANDOC_SCRIPT_FILE` set beforehand, since the file captures them at load time) and call the handler directly; `args`/`kwargs` are built as Inlines. Harness uses vendored `luaunit.lua`, run with `quarto pandoc lua tests/run.lua` from the repo root, against Quarto's bundled pandoc (the version the extension runs on). See [[reference_quarto_lua_shortcodes]] for the shortcode semantics the tests must respect.

**`undefined-field` fires only on `@class`-typed values** (AST nodes via the plugin, e.g. a bad `doc.blockss`), not on misspelled functions of the `pandoc.*`/`quarto.*` module tables (declared as open tables upstream). Do not patch the vendored stubs to close this.

**The gate does not retroactively catch adversarial-audit findings.** Measured on the two hebstr-doc filters: 0 of 29 `/audit:blindspot` findings are gate-detectable (they are logic/design/security/API/naming, not undefined-symbol/type/nil/arity/format). A type-checker and formatter catch a class orthogonal to what an audit finds; they are complementary. The gate's justification is forward-looking (cheap continuous catching on future edits) plus format consistency, not overlap with the audit. Do not enable `stylua --check`/`lua-language-server --check` in CI until the filters are cleaned up, or CI is red from day one on known-unfixed issues.
