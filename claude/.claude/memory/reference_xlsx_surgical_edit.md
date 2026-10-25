---
name: reference_xlsx_surgical_edit
description: Changing text in a hand-styled .xlsx without flattening its formatting, by editing sharedStrings.xml inside the archive instead of rewriting the workbook
metadata:
  type: reference
---

An `.xlsx` the user styles by hand is never rewritten with `openxlsx`, `writexl` or `openpyxl` to change a string: those rebuild the file and drop the fills, fonts and column widths the user set. Edit the archive member instead.

Cell text lives in `xl/sharedStrings.xml` as `<si>` entries, which `xl/worksheets/sheetN.xml` references by index from a `<c t="s"><v>IDX</v></c>`. The procedure:

1. Map the target strings to their cells before touching anything: parse both members, list the `si` indices whose text matches, and print every cell that references one. A shared string referenced by several cells would change all of them, which is the only way this goes wrong silently.
2. Replace inside that one member, then rewrite the zip copying every `ZipInfo` with its own `compress_type`, so the other members stay byte-identical. Assert that afterwards.
3. Read the file back (`readxl`, `openpyxl`) and check the row and column counts plus the changed cells.

Measured on the editorial workbook of eds-prise, `docs/snds/dict-snds-source.xlsx` since the rename of 2026-10-21 and `snds/prise_snds-source.xlsx` when the measurement was taken, 2026-10-07, replacing four hard hyphens of `CIM-10` with `U+2011`: ten of the eleven members came back byte-identical and the styling survived.

**Appending a whole sheet is the measured exception and needs no surgery.** `openxlsx2::wb_load() |> wb_add_worksheet() |> wb_add_data() |> wb_save()` on that same workbook, 2026-10-25 with openxlsx2 1.30, re-serialised all ten existing members yet changed nothing that shows: the 4 fonts, the 23 `xf`, the fills and the number format compare equal element by element, the 69 cells of the styled sheet keep their reference, style index, type and value, and `pane`, `sheetView`, `dimension` and the four `col` widths are untouched, the one difference being a `sheetFormatPr` open tag turned self-closing. So the rule above bites on changing a string or a cell inside an existing sheet, where `wb_add_data()` would reset that cell's own style, and not on adding a sheet beside it. Two things the new sheet does not inherit and that a column of empty cells makes invisible in the XML: it gets no `col` width and no frozen pane until `wb_set_col_widths()` and `wb_freeze_pane()` set them, and `wb_add_data()` writes every `NA` as the Excel error literal `#N/A` unless it is passed `na.strings = NULL`, so a column meant to be filled by hand arrives full of error cells. Both were caught by converting the workbook to PDF and reading the page, never by reading the sheet XML.

Keep the file under git before editing, which is the real safety net. See [[project_word_render_control]] for reading the result on the real Word, and [[reference_table_column_width_layout]] for why a token broken across lines matters in a Word table.
