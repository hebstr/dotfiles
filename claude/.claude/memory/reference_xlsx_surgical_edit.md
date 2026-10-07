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

Measured on `snds/prise_snds-source.xlsx` of eds-prise, 2026-10-07, replacing four hard hyphens of `CIM-10` with `U+2011`: ten of the eleven members came back byte-identical and the styling survived.

Keep the file under git before editing, which is the real safety net. See [[project_word_render_control]] for reading the result on the real Word, and [[reference_table_column_width_layout]] for why a token broken across lines matters in a Word table.
