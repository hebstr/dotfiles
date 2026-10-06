---
name: reference_table_column_width_layout
description: Declaring one percentage grid for gt and flextable; why engine sizing and pixel overrides diverge, and the Word indent that sets a column's minimum share
metadata:
  type: reference
---

Measured 2026-10-06 on gt 1.3.0, flextable 0.10.0 and chromium, in eds-prise.

**Declare one grid in percent and both renderers carry it.** `gt::cols_width()` accepts `gt::pct()` and emits `table-layout: fixed; width: 100%` with one `<col style="width:N%">` per column; what a memory records as refused is `tbl_format(width = gt::pct(100))`, whose `.check_size()` demands a scalar numeric, not `cols_width()`. For flextable, the share times `hebstr::docx_page_width()` gives the inches of a fixed grid. A percentage is the only declaration independent of the total, so it is what survives a table published at several widths: a report body column, a standalone export, a Word text column. Letting each engine size from content instead gives one table three different grids, which is a defect as soon as the same table is read in two formats.

**`hebstr::easy_out()` rewrites `table.width` only when the `gt` carries `"auto"`**, so a percentage declaration survives the export; `easy_out(width = )` still sets the total and the column percentages follow it. That also forecloses the PNG clipping of [[reference_hebstr_gt_table_width]], a table at 100 per cent of the capture viewport never exceeding it. A **partial** pixel override is the trap: it switches the table to fixed layout, where the undeclared columns keep their content width only while the table width stays auto, and fall to equal shares as soon as anything declares one, which the export path does.

**Word sets the minimum share, not the HTML.** Under a fixed grid a column must hold its widest unbreakable token plus its horizontal indent, and an indentation rule on the first column (`w:ind w:left="300" w:right="100"`, 20 pt) takes that out of its own width where other columns pay 10. Measure the token with `systemfonts::string_width(s, family = "Aptos", size = 9)` and divide by the text column in points: a share one point short breaks every code in mid-token, silently, and only a real-Word readback shows it.

**gt.** With no `cols_width()` the HTML carries neither `table-layout: fixed` nor a `<colgroup>`: the browser's automatic algorithm sizes each column from its content and the table never exceeds its container, shrinking into it instead. Passing any `cols_width()` switches the table to `table-layout: fixed`, but while the table width stays auto the undeclared columns keep exactly the pixels they had with nothing declared, so a partial override pins one column and leaves the rest content-sized. That property dies under `tab_options(table.width = pct(100))`, where the undeclared columns fall to equal shares.

**flextable.** The widths a new flextable is created with are a flat 0.75 inch per column, so a theme that declares neither a grid nor autofit sizes by nothing. `set_table_properties(layout = "autofit", width = 1)`, which `hebstr::theme_ft(width = 1)` reaches, writes `w:tblLayout type="autofit"` with `w:tblW type="pct" w:w="5000"` and **no `w:tblGrid` at all**: Word measures the content itself, indentation and cell margins included, and fills the text column. A per-column `flextable::width()` is then ignored, so there is no partial override on the Word side: covering one column means declaring the whole grid under `layout = "fixed"`. `layout = "autofit"` with no width writes `pct 0`, which sizes to content without filling.

**Before blaming the layout, measure the demand.** Set `table.style.width = "max-content"` in the page and read the columns back: if the total exceeds the container, no width assignment avoids wrapping and the engine is spreading the deficit in proportion to each column's demand. A hyphen is a break opportunity, so a short token like `CIM-10` splits across two lines in both engines when its column is minimised; a non-breaking hyphen fixes it for both where a width override would only reach the HTML.

See [[reference_hebstr_gt_table_width]] for the PNG clipping a wide declared `gt` walks into, and [[reference_flextable_grouped_rows]] for what each renderer does with row groups.
