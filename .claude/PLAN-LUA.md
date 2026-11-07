# PLAN-LUA.md

Design note and implementation plan for a Lua lint/format/test gate, at parity with the existing R / Python / shell / Rust / Typst gates.

Authored in `~/dotfiles` because the deliverable is `rules/lua.md` plus the shared prek scaffold; the consumers are Quarto extension repos elsewhere on disk (first target: `~/Documents/packages/quarto-hebstr-doc`).

**Status (2026-07-20): complete, all 8 steps done.** The gate exists, auto-loads on `**/*.lua`, and is wired into CI, the prek scaffold and Positron. The one follow-up left is in Blockers and open questions.

Two ordinal surfaces are frozen by an external citer, so a later pass reduces an item without renumbering either list: the steps, `_meta/notes/lua-toolchain.md` citing "PLAN-LUA step 2", and the two load-bearing constraints under Verified facts, the « Fichiers de suivi mis à jour dans la foulée » paragraph of `_meta/notes/pandoc-upgrade.md` citing « la justification du point load-bearing n°1 ».

**prek deployed to `quarto-hebstr-doc` (2026-07-20).** The consumer repo took an adapted subset of the `_meta/profiles/prek.toml` scaffold and dropped the Python hooks, absent from that repo; its own `prek.toml` is the authority for the current set, which has moved since (typstyle out, stylelint and prettier in).
The one adaptation no config file explains: **`.styluaignore` is honored in traversal but not for explicit file paths**, which is exactly what prek passes, so the `stylua-github` hook carries `args = ["--respect-ignores"]`. Without it the ignore file governs CI (`stylua --check .`) and not the commit hook, and the two disagree on vendored Lua and on `tests/fixtures/**`; `.styluaignore` carries the reason per path, and the `air-format` and `jarl-check` excludes are the same fixtures case.

## Objective

Give Claude Code a reproducible, automatically-loaded gate for Lua so that filter and shortcode code written for Quarto extensions is validated before being reported as done, the same way `rules/shell.md` gates a `.sh` edit.

Triggering context: a `/audit:blindspot` pass on `quarto-hebstr-doc` returned 25 findings on two Lua filters (`add-code-files.lua`, `filetree.lua`) written with no linter, no formatter, no type checking, and no tests.

## Success criteria

All met, except the one the measurement refuted: ~~the gate catches a measurable share of the 25 findings~~, 0 of 29 at step 8, which holds the classification and what the refutation is worth.

## Verified facts

Measured on this machine on 2026-07-20, the `run_lua_filter` row re-measured on 2026-09-30; do not re-derive them. The stub, plugin and `.luarc.json` rows are gone, `rules/lua.md` carrying the paths and the wiring they established.

```
| Fact                                    | Value | How verified |
|-----------------------------------------|-------|--------------|
| `pandoc.utils.run_lua_filter`           | present in 3.10, and was already in the 3.8.3 Quarto bundled at design time | `quarto pandoc lua -e`, under each |
| `PANDOC_SCRIPT_FILE` under `pandoc lua` | `nil` | `quarto pandoc lua -e` |
```

Two load-bearing constraints, both easy to get wrong:

1. Tests run under `quarto pandoc lua`, because the filters ship inside a Quarto extension and only ever execute against the pandoc Quarto bundles. `quarto pandoc` and a bare `pandoc` resolve to the same binary today, which is a state of this machine rather than a property: they have diverged before, in both directions, so the command stays pinned to the one the extension runs against.
2. Neither `quarto pandoc lua` nor `quarto run` exposes the `quarto` global. Any filter calling `quarto.doc.is_format` (which `filetree.lua` does) needs that global stubbed by the test harness. This matches what quarto-cli does in its own `tests/unit-lua/`, where roughly 45 lines of hand-written mocks precede the first assertion.

## Locked decisions

Recorded 2026-07-20, closing the indent question and the `.luarc.json` distribution question; do not re-litigate.

- **Decision: StyLua indent is 2 spaces** (`indent_type = "Spaces"`, `indent_width = 2`), set in all three places (editor, gate, hook) from the start. Reason: matches Quarto's own Lua sources and reads compactly in short, already-nested filter code; avoids retrofitting the tabs default later.
- **Decision: ship `.luarc.json` with a repo-relative library path plus a vendored (sparse) copy of the MIT LuaCATS stubs.** Reason: the only option that satisfies author, CI, and collaborator at once, which is a stated success criterion. Cost accepted: ~44 vendored files under the repo. This makes step 2 a build task (vendor + wire relative path), not a three-way spike.

## Design decisions

### Linter: `lua-language-server --check`, not luacheck or selene

The usual Lua linters know nothing about the Pandoc or Quarto API, so with either one the first task would be hand-maintaining a list of globals that Quarto already publishes as typed stubs. LuaLS consumes those stubs directly and therefore catches a strictly larger class of defect, which `rules/lua.md` enumerates.

Upstream precedent: Neovim removed luacheck from its CI with the rationale that "Majority of checks are already covered by LuaLS and Stylua. Luacheck provides lots of false-positive results we need to disable with comments" (neovim/neovim#32536), and `lua-language-server --check` gates CI in `neovim/nvim-lspconfig`.

Rejected: luacheck (maintained but in upkeep mode; no pandoc `std` set exists), selene (maintained, richer custom-API format, but still requires hand-writing a std YAML for pandoc that nobody has published; a code search for one returns zero results).

### Formatter: StyLua

The only unambiguous consensus in the Lua ecosystem, with an official GitHub Action and official pre-commit hooks in-repo. The alternatives are dead (`lua-fmt` 2018, `LuaFormatter` 2023).

### Tests: luaunit under `quarto pandoc lua`, plus a golden-diff layer

Two layers, because they catch different things.

Unit layer: vendored `luaunit.lua` (single file, pure Lua, no luarocks), as Quarto itself vendors it in two places. busted is rejected: it needs luarocks and the `luasystem` C extension, and no repository was found combining it with Pandoc filters.

Integration layer: golden-diff on a fixture, the only convention either project has published, Pandoc's own filter collection mandating per filter a `Makefile` with a `test` target, a `sample.md` and an expected-output file diffed against the render, and `tarleb/lua-filter-template` packaging that with a re-baseline target.

Only the unit layer shipped. The golden-diff layer was dropped as redundant at step 5: the unit layer asserts on real AST for both branches of both filters, and `render.yml`'s `example.qmd` render is the end-to-end smoke. `perevir` (tarleb, Markdown files with `{#input}`/`{#expected}` blocks, `-a` to accept snapshots) stays in References if the integration layer is ever revived.

Community baseline for calibration: of 120 extensions sampled from the community registry, 9 have any `tests/` directory, 68 have no CI at all, and 0 have a linter or formatter config. Doing any of this puts the repo in the top decile, so prefer the smallest gate that fires over the most complete one.

### The `.luarc.json` distribution problem

What makes the vendoring of Locked decisions worth its cost, on top of the absolute paths and the `.gitignore` entry that `rules/lua.md` records: the glob Quarto's editor extension generates targets `_extensions/*/*.lua`, whereas `quarto-hebstr-doc` keeps its filters one level deeper, at `_extensions/hebstr-doc/filters/*.lua`.

Rejected: an absolute machine-specific path; resolving the Quarto share directory at gate time and passing `--configpath` to a generated temporary config.

## Steps

1. **Install and record the toolchain.** ✅ Done 2026-07-20. Trace at `_meta/notes/lua-toolchain.md`; the two rows now live in `_meta/notes/environment-archive.md`, `rules/environment.md` having been deleted in `daa2729`.

2. **Resolve the `.luarc.json` distribution question.** ✅ Done 2026-07-20 in `quarto-hebstr-doc`, as Locked decisions prescribes; `rules/lua.md` carries the resulting setup, down to the two placement constraints (the vendored `.luals/` at the repo root outside `_extensions/`, and `ignoreDir` covering it and any third-party extension vendored inside this one).

3. **Write `rules/lua.md`.** ✅ Done 2026-07-20, `paths: ["**/*.lua"]`, structured after `rules/typst.md`.

4. **Build the test harness in `quarto-hebstr-doc`.** ✅ Done 2026-07-20. The plan's assumption was wrong, and the correction is what constrains any later harness work: both files are Quarto **shortcodes** returning a handler table (`return { ["filetree"] = fn }`), not Pandoc document filters, and `pandoc.utils.run_lua_filter` applies AST-node handlers and never invokes a shortcode. The header of `tests/support.lua` holds the convention that replaced it, and the suite, run by `quarto pandoc lua tests/run.lua`, has grown well past this plan and is its own authority. Stubbing the `quarto` global was enough, no golden-diff fallback was needed.

5. **Wire tests into CI.** ✅ Done 2026-07-20. `render.yml` runs the Lua unit tests and the LuaLS type check; the StyLua step it also carried has since been dropped there, formatting being gated by the prek hook alone.

6. **Add the prek hook.** ✅ Done 2026-07-20, `stylua-github` in `_meta/profiles/prek.toml`.

7. **Configure Positron.** ✅ Done 2026-07-20 in the active `hebstr-positron` profile, per the Editor tooling section of `rules/lua.md`.

8. **Measure and close the loop.** ✅ Done 2026-07-20. Result below.

   **The pre-audit revision is unrecoverable.** `filetree.lua` was untracked when the `/audit:blindspot` of 2026-07-19 ran, and was committed the next day in `199ada2`, so the audited revision is in no history. The audit ran on the working tree, which the walkthrough had already partly fixed (10 of 29 findings `done`). The gate was therefore measured against the working tree of the day, each of the 29 findings classified by whether `stylua` or `lua-language-server --check` can mechanically detect it. The review file that held them, `REVIEW-filetree.md`, has since been deleted from the consumer repo's gitignored `.claude/`, so the classification below is now its own record.

   **Acceptance metric: 0 of 29 findings are gate-detectable.** The audit findings are logic (A1–A5, C2, C3, C4, C7, C10, C14, A6, E3), security (E1), dynamic-API and compat (C1 dynamic meta value type, C9 `pandoc.Null` shim, A8 hardcoded separator, A9 guard consistency), accessibility and UX (C6, E2), cross-file duplication (C5), naming and config style (C11, C12, C13), or rejected (A7, E4, E5, E6). None of these is an undefined symbol, an `@class` field typo, a nil-deref, a type-mismatch, an arity error, or a format deviation, which is the entire class the gate detects. The gate independently emits two `cast-local-type` warnings in `filetree.lua` (`err = tostring(err)`, `sidecar = nil`), both intentional narrowing, so noise rather than defects, and neither is in the finding set.

   **This refutes the success-criterion premise, and that is the useful result.** A type-checker and a formatter do not retroactively catch what an adversarial logic and design review catches; the two are complementary. The gate's real return is forward-looking and continuous: on every future filter edit it catches, for near-zero cost, the undefined globals, AST-field typos, arity and nil errors, and format drift that an expensive per-commit audit should not be spent on (all verified catchable during step 2). On these two already-reviewed filters it buys format consistency and a standing net, nothing more.

## Blockers and open questions

Resolved items removed, and the stubs-lag constraint is held elsewhere: `rules/lua.md` states it in its own words with the `undefined-field` limitation, the pin sits in the vendored `.luals/types/pandoc/README.md` and the re-sync command in `.luarc.json`, both in the consumer repo. What remains is the one open follow-up:

- **Adversarial pass on `rules/lua.md` still pending** (step 8 follow-up). No prior art to copy for the AI-assistance angle (`awesome-claude-code`, `anthropics/skills`, the Posit skills repo have zero Lua/Pandoc-filter content), so `rules/lua.md` was written from scratch: run `/audit:blindspot ~/dotfiles/claude/.claude/rules/lua.md` in a fresh conversation.

## References

The Quarto, Pandoc, StyLua and LuaLS entry points are in the References of `rules/lua.md`. What only this note cites:

- Pandoc filter collection, test conventions in `CONTRIBUTING.md`: https://github.com/pandoc/lua-filters
- Filter template with `test` / `generate` / `quarto-extension` targets: https://github.com/tarleb/lua-filter-template
- perevir: https://codeberg.org/tarleb/perevir
- Neovim's rationale for dropping luacheck: https://github.com/neovim/neovim/issues/32536
