---
name: flextable grouped row spans
description: Row grouping in flextable: why as_grouped_data() plus flextable() plus merge_h() never spans the group row, what as_flextable(hide_grouplabel = TRUE) builds instead, how it reaches Word, and the gt counterpart with what both engines drop and how their row striping diverges
metadata:
  type: reference
---

`flextable::as_grouped_data(x, groups = "g")` inserts one row per group where `g` carries the label and every other column is `NA`, and sets `attr(, "columns")` to the non-group columns.

**`flextable(dat)` then `merge_h(part = "body")` does not produce a group row.** `merge_h` merges runs of identical adjacent cells, so on a group row it merges the `NA` cells beside the label and leaves the label alone in the group column: measured on a 5-column frame under flextable 0.10.0, the span matrix reads `1 4 0 0 0`, a span of 4 over columns 2 to 5 with the label in a narrow column 1.

**`as_flextable(dat, hide_grouplabel = TRUE)` is the construction that spans.** Reading `flextable:::as_flextable.grouped_data`: it builds the flextable on `col_keys` without the group column, `compose()`s the label into column 1 of each group row, then `merge_h_range(j1 = 1, j2 = <last>)` and left-aligns it. `hide_grouplabel = FALSE`, the default, prefixes the label with `"<group name>: "`. Under `layout = "fixed"` with per-column widths it reaches Word as one `w:tbl` whose group rows each carry a `w:gridSpan` equal to the column count, over a `w:tblGrid` of distinct `w:gridCol`.

The `gt` counterpart is `gt(groupname_col = )`, which lifts the column out of the body into a row group and leaves the remaining columns to `cols_width()`. Both engines therefore drop the group column's own header, so a published label on the grouping variable is lost by construction and the group rows are the only place its values appear. Neither engine makes those rows bold by default: `gt` separates them with its 2 px `row_group` borders, where a themed `flextable` gives them nothing but the body striping.

**The two engines also stripe different row sets.** A `flextable` built from grouped data counts the group rows as ordinary body rows, so the alternation runs over the whole layout; `gt`'s `row.striping` counts the data rows alone and skips the group headings, so each group's first row flips with the parity of the groups above it and the two forms diverge. Matching them means turning `row.striping.include_table_body` off and painting the alternation explicitly, through `cells_body()` for the data rows and `cells_row_groups()` for the headings.

Measured 2026-10-04 in eds-prise, on the widget-conversion pilot whose width budget is in [[reference_hebstr_gt_table_width]].
