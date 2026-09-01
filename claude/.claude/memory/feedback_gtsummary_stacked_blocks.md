---
name: "gtsummary stacked blocks: an ordinary label row per block, never tbl_stack group headers"
description: On the hebstr stack, a gtsummary table made of several blocks (one per stratum, plus a total) opens each block with an ordinary label row and indents the block's rows under it, via add_variable_group_header() before tbl_stack(); the group_header argument of tbl_stack() and the .header of tbl_strata() render full-width gt group rows outside the striping, which the user rejects
metadata:
  type: feedback
---

When a gtsummary table is built from several stacked blocks, one per stratum with a total block, each block opens with an ordinary label row carrying the block's name, and the block's rows are indented four spaces under it, exactly the layout of a categorical variable and its levels. Striping runs over every row. Produce that with `add_variable_group_header(x, header = <name>, variables = everything())` on each block, then `tbl_stack()` with no `group_header`.

**Why:** validated by the user on 2026-09-02 in `eds-prise`, on `scripts/tbl_branche_imag.R`, after two forms were rejected in a row. `tbl_stack(group_header = )` and `tbl_strata(.header = )` both emit gt row-group rows: full width, shaded, outside the alternating stripe, with a look no other table of the project has. The user's words: "strip row normal avec indentation des concept". The `add_variable_group_header()` header row carries no statistic, which is exactly right for a stratum name and is the same trait that made it unfit for a table whose upper level must carry a count (the code tables of `eds-prise` use `tbl_hierarchical()` for that reason).

**How to apply:**

- **Trigger:** any `tbl_stack()` or `tbl_strata()` on the hebstr stack, in every project, whenever the blocks need a name in the body of the table.
- Build each block from its own frame (`split()` on the stratum, plus the whole frame for the total, order and name of the total decided by the user), apply `add_variable_group_header()` to each, then `tbl_stack()` the list. Neither `group_header` nor `.header`.
- The header templates take no Markdown bold: `tbl_format()` renders the asterisks verbatim in a group row. Keep the names bare.
- `tbl_strata()`'s `.quiet` is deprecated since gtsummary 2.0.0 and ignored; do not pass it.
- Check the rendered PNG, not the object, as [[feedback_verify_gt_output_on_render]] requires: the group-row form and the label-row form look identical in `table_body` and differ only at render.
