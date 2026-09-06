---
name: hebstr gt table width is hard pixels
description: hebstr's tbl_format/theme_gt width becomes a fixed px table.width that the gt container can only scroll; the theme-level fix, why pct() and NULL are both refused, and how to measure a table's natural width
metadata:
  type: reference
---

`theme_gt(width = )` passes its argument straight to `gt::tab_options(table.width = )` as hard pixels, and `gt` wraps the table in a `width:100%; overflow-x:auto` container. Whenever the body column is narrower than the declared width, the table is truncated behind a horizontal scrollbar rather than shrinking. One rule in the theme fixes it for every `gtsummary` table at once:

```
table.gt_table {
  max-width: 100%;
}
```

No `!important`: `max-width` and `width` are different properties, so the cap beats `gt`'s id-scoped `width` rule regardless of specificity. The declared px then behaves as a preferred width, kept wherever it fits, compressed below. Verified in eds-prise on 2026-09-03, five tables, four viewport widths.

Neither obvious alternative works. `tbl_format(width = gt::pct(100))` aborts: its `.check_size()` demands a scalar numeric. `width = NULL` is accepted, but `easy_out()` reads the declared px back out of the gt options to size its `webshot`, and absent one it rewrites `table.width = px(700)` on the exported copy, so every artifact under `output/` is forced to 700 px. See [[reference_hebstr_easy_out_subdir]].

Two measurement notes. Under `hebstr-doc`'s default grid the body column equals the viewport minus 541 px, capped at 1002 px (`body-width: 1000px`), so a 950 px table overflows below a 1491 px window and a wide-screen render never reproduces the report. And a table's natural width is the `max-content` of `thead` + `tbody` with `tfoot` removed: the footnote sits in one `tfoot` cell that never wraps, which inflates the whole table's `max-content` past 2 000 px and makes `fit-content` useless.
