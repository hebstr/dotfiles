---
name: hebstr gt table width is hard pixels
description: hebstr's tbl_format/theme_gt width becomes a fixed px table.width that the gt container can only scroll; the theme-level fix, why pct() and NULL are both refused, the 700 px fallback whose 770 px capture silently clips a wider table's exported PNG and so the Word deliverable, how the same overflow fails differently on a native flextable, Word honouring the declared grid and LibreOffice rescaling it, and how to measure a table's natural width
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

**That fallback clips the PNG, and only the PNG.** `easy_out()` captures at `vwidth = width * 1.1`, so a table whose `gt::cols_width()` declares more than the 770 px the fallback gives loses its rightmost columns in the export with no error raised, the HTML staying correct; a Word render, where `out_qmd()` dispatches a `gt` to `knitr::include_graphics()` of that PNG, is therefore the deliverable that loses them. Measured in eds-prise on 2026-10-03 on a `gt` whose columns summed `500 + 40 × n`: complete at six columns, clipped from seven. A table whose column widths are derived rather than fixed must pass the same sum to `theme_gt(width = )`; `gt::tab_options(table.width = )` normalises a bare integer to `"<n>px"`, so no `gt::px()` wrapper is needed.

**The same overflow on a native `flextable` fails in Word and passes in LibreOffice.** A table given per-column widths through `flextable::width()` under `layout = "fixed"` reaches Word as a `w:tblGrid` of distinct `w:gridCol` values, and it keeps flextable's own default `w:jc w:val="center"`, which `theme_ft()` does not touch. Word honours that grid literally, so a grid wider than the section's text column hangs off **both** sides and the label column's text starts off the left edge of the page: the fills, the spanner and the grid all render, the labels are simply not there. LibreOffice instead scales the grid down to the text column keeping the ratio, so a LibreOffice render reports a pass on exactly this. Measured 2026-10-04 in `R-hebstr/dev/out.qmd` on the same `500 + 40 × n` calendar at fifteen time columns, 16500 twips against a 9360-twip column: 288 px of visible label column predicted, 290 measured, against a correct render once the grid fit. The budget is `docx_page_width()` on the template, 6.3 in (604 px) for `hebstr-doc`, and the fix is a width per renderer rather than one value, the `gt` keeping its HTML pixels. See [[project_word_render_control]] for the route that showed it.

Two measurement notes. Under `hebstr-doc`'s default grid the body column equals the viewport minus 541 px, capped at 1002 px (`body-width: 1000px`), so a 950 px table overflows below a 1491 px window and a wide-screen render never reproduces the report. And a table's natural width is the `max-content` of `thead` + `tbody` with `tfoot` removed: the footnote sits in one `tfoot` cell that never wraps, which inflates the whole table's `max-content` past 2 000 px and makes `fit-content` useless.
