---
name: Review severity for quarto-hebstr-doc (Quarto extension)
description: "Calibrate code review of the quarto-hebstr-doc Quarto extension (filetree.lua): dismissed idiom/perf/duplication findings; supplements feedback_review_severity_personal"
metadata:
  type: feedback
---

Package-specific review dismissals for the `quarto-hebstr-doc` Quarto extension at `~/Documents/packages/quarto-hebstr-doc`, supplementing [[feedback_review_severity_personal]]. Distinct from [[feedback_review_severity_hebstr]] (the R package). See also [[reference_quarto_lua_shortcodes]] and [[reference_lua_gate_quarto_filters]].

**Why:** the 2026-07-20 `/audit:walkthrough` of `filters/filetree.lua` produced recurring idiom/perf/duplication findings that a future reviewer will re-flag; each was assessed and dismissed on the merits.

**How to apply (do NOT re-flag these):**
- **The 7-line `kw` helper duplicated between `filetree.lua` and `add-code-files.lua` is deliberate, not a refactor target.** Each shortcode is an autonomous entry point (CLAUDE.md calls them "autonomous"); factoring `kw` out costs a shared module plus a `package.path` derived from `PANDOC_SCRIPT_FILE` in each consumer, reopening the install-depth hazard CLAUDE.md already documents twice (filetree icons, Typst `code.tmTheme`). ~20 lines of indirection + a new failure mode to save 7 stable lines. Rejected (C5); the copies must stay byte-identical, so keep `kw` aligned across both.
- **The hardcoded `/` path separator is a deliberate single internal convention, not a `pandoc.path.join` omission.** `relpath` is the annotation-key AND display string; the sidecar is authored with `/` cross-platform, so `pandoc.path.join` (which emits `\` on Windows) would break key matching. `/` also works for filesystem access on all three OSes. Splitting the convention only for the FS-path joins would leave `relpath` on `/` two lines away, more confusing than uniform `/`. NOTED, no change (A8).
- **No `list_directory` cache.** Measured 7 redundant listings of 66 on a depth-3 walk (each of 7 dirs listed twice: once to type via `classify`, once to read). Once-per-render, depth-bounded, OS dentry-cached; a cache is dead metadata by the premise test. NOTED (A6).
- **The `warn` guard (`quarto and quarto.log...` + stderr fallback) vs the unguarded `quarto.doc.is_format` is intentional asymmetry.** `warn` is standalone-safe for helper testing; `is_format` has no non-quarto behavior and a nil-`quarto` crash there is already a clear error. The `project_dir = quarto and quarto.project...` guard is semantic (project legitimately absent in single-file render), a third distinct case, not part of the asymmetry. NOTED (A9).
- **Terse helper names (`kw`, `esc`, `opt`) are conventional Lua-filter idiom, not a naming defect.** `esc` = HTML escape, `opt` = option getter, `kw` = kwarg getter (and must stay aligned with `add-code-files.lua`). NOTED (C12).
- **`depth=0`/negative clamping to `depth=1` is coherent, not a silent-coercion bug.** `scan`'s `depth > 1` guard sends 0 and 1 down the same `has_visible_entry` branch; the render does not lie. Rejected (C3 sub-claim). Note: the sibling coercions in C3 (`depth="abc"`, non-canonical `hidden` spellings, unknown kwargs, positional args) WERE worth cheap `warn()`s and were fixed, on the "a call site that misses the documented form should be named, not absorbed" principle.
