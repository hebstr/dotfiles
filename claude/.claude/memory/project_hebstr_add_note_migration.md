---
name: hebstr add_note() migration backlog (umb-coco, ipl-sca, quarto-stat)
description: Pending — add_note() became gtsummary-only and must be piped BEFORE tbl_format() (hebstr source, 2026-07-17); 16 call sites in umb-coco/ipl-sca/quarto-stat still use the old post-tbl_format order and will break the moment those projects rv sync hebstr past that commit
metadata:
  type: project
---

On 2026-07-17 `add_note()` changed in the hebstr source clone (`~/Documents/packages/R-hebstr`, unpushed as of that date): it takes a **`gtsummary`** table and must be piped **before** `tbl_format()`, where it previously took a `gt_tbl` after it. It attaches the footnote with `gtsummary::modify_footnote_body()` instead of `gt::tab_footnote()`, and aborts on any non-gtsummary input. Canonical entry is in the repo's `NEWS.md`, under Breaking changes.

**Why:** `tbl_format()` returns a `flextable` under `options(hebstr.docx = TRUE)` and a `gt_tbl` otherwise, so a `gt` verb applied downstream fails on the Word branch. Giving `add_note()` a flextable branch was tried and rejected on evidence: `flextable::footnote()` restarts its own symbol counter and emits a second "1" colliding with the symbols `tbl_format()` already wrote, and gt/gtsummary number footnotes in table **reading order** rather than call order, which a post-render append cannot reproduce without reimplementing gtsummary's numbering. Declared upstream on the gtsummary object, a single call site serves both output formats and gtsummary does the numbering. Do not re-propose the flextable-branch design.

**How to apply:** these projects still use the old order and will break on their next `rv sync` of hebstr. They pin it by SHA in `rv.lock`, so nothing breaks silently until someone syncs:

- `~/Documents/services/umb-coco` — 14 call sites: `scripts/tbl_{baseline,tumor,tox_global,treatment,coxph,event,nutrition}.R` and `index.qmd`
- `~/Documents/services/ipl-sca` — 1 call site: `scripts/tbl_pop.R`
- `~/Documents/sandbox/quarto-stat` — 1 call site: `quarto_exemples/quarto_2.qmd`

The migration is mechanical: move each `add_note(...)` above `tbl_format(...)` in the pipe, arguments unchanged (`vars`, `levels`, `rows`, `pvalue_mv` all map over as-is). Verify by rendering: footnote text identical, symbols renumbered in reading order — which may legitimately differ from the previous output when notes were declared out of table order, so a changed symbol is not a regression. md-nesrine is already migrated (8 scripts, 2026-07-17); see [[project_md_nesrine_render_pitfalls]] for that project's docx state.
