---
name: hebstr add_note() migration — one call site left (ipl-sca)
description: add_note() became gtsummary-only and must be piped BEFORE tbl_format() (hebstr, 2026-07-17); umb-coco is migrated, one call site remains in ipl-sca, and quarto-stat was never one
metadata:
  type: project
---

On 2026-07-17 `add_note()` changed in hebstr (`~/Documents/packages/R-hebstr`; the commit is in `origin/main` as of 2026-07-28, which is what makes the ipl-sca break below reachable on its next sync): it takes a **`gtsummary`** table and must be piped **before** `tbl_format()`, where it previously took a `gt_tbl` after it. It attaches the footnote with `gtsummary::modify_footnote_body()` instead of `gt::tab_footnote()`, and aborts on any non-gtsummary input. Canonical entry is in the repo's `NEWS.md`, under Breaking changes.

**Why:** `tbl_format()` returns a `flextable` under `options(hebstr.docx = TRUE)` and a `gt_tbl` otherwise, so a `gt` verb applied downstream fails on the Word branch. Giving `add_note()` a flextable branch was tried and rejected on evidence: `flextable::footnote()` restarts its own symbol counter and emits a second "1" colliding with the symbols `tbl_format()` already wrote, and gt/gtsummary number footnotes in table **reading order** rather than call order, which a post-render append cannot reproduce without reimplementing gtsummary's numbering. Declared upstream on the gtsummary object, a single call site serves both output formats and gtsummary does the numbering. Do not re-propose the flextable-branch design.

**How to apply.** State re-verified on 2026-07-28, and the backlog is down to one call site:

- `~/Documents/services/umb-coco` — **migrated**. All 15 `add_note()` calls sit above `tbl_format()` (`scripts/tbl_{baseline,tumor,tox_global,treatment,coxph,event,nutrition}.R`); `index.qmd` was never a call site, it names `tbl_format()` in prose. The project consumes hebstr from a local path (`rv.lock`: `source = { path = ".../R-hebstr" }`, `force_source = true`), so it tracks the source clone directly rather than a SHA.
- `~/Documents/services/ipl-sca` — **the one remaining site**: `scripts/tbl_pop.R:23-27` pipes `gt_format(width = 750) |> add_note(...)`, the old post-format order. Grepping that project for `tbl_format` finds nothing: `gt_format()` is the former name, kept as a deprecating forwarder, so the site is easy to miss. It pins a SHA in `rv.lock` (`2c8dbff`, predating the change), so it breaks on its next sync, not silently.
- `~/Documents/sandbox/quarto-stat` — **not a call site**. `quarto_exemples/quarto_2.qmd:196` lists `add_note()` inside a markdown table of hebstr functions.

The migration is mechanical: move each `add_note(...)` above `tbl_format(...)` in the pipe, arguments unchanged (`vars`, `levels`, `rows`, `pvalue_mv` all map over as-is). Verify by rendering: footnote text identical, symbols renumbered in reading order — which may legitimately differ from the previous output when notes were declared out of table order, so a changed symbol is not a regression. md-nesrine is already migrated (8 scripts, 2026-07-17); see [[project_md_nesrine_render_pitfalls]] for that project's docx state.
