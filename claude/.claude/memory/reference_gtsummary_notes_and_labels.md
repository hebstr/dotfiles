---
name: reference_gtsummary_notes_and_labels
description: gtsummary 2.5.1 table notes and labelling: where add_note() works and why its position is indifferent, the one call that must follow hebstr's gtsum_format(), and a local easy_label() coercing logicals so the labelling step comes last
metadata:
  type: reference
---

Measured in `eds-prise` on 2026-09-03 against suppositions that turned out false, on gtsummary 2.5.1 and gt 1.3.0 (`rv.lock`), so none of it needs re-deriving on that pair.

**`add_note()` works on `tbl_merge` and on `tbl_stack`**, not only on a plain `tbl_summary`.

**Its position relative to `gtsum_format()` is indifferent.** The final `modify_footnote(everything() ~ NA)` of that hebstr helper resets only the header note, so a note added before survives. Beware the version: whether `modify_footnote` reaches more than the header depends on where gtsummary is in its `modify_footnote` / `modify_footnote_header` split, so re-check on a gtsummary upgrade.

**Declaration order is indifferent too**: gtsummary numbers the symbols in the table's reading order, not in the order the notes were declared.

**`add_variable_group_header()` is the exception: it goes after `gtsum_format()`, never before.** The `add_overall()` that the helper's `.fmt_by` branch calls aborts on a table that already carries a group-header row. (Which call comes before `tbl_stack()` is a separate question, settled in [[feedback_gtsummary_stacked_blocks]].)

**A labelling helper that coerces logicals forces the join to come last.** `eds-prise`'s own `easy_label()`, in its `lib/label-helpers.R` and not in hebstr, opens on `modify_if(is.logical, as.numeric)`, so joining indicator columns before labelling turns them numeric and aborts the `map()` over the blocks. The labelling step is therefore the last link of the chain, and marginals are read on the unlabelled frame. Check any project's own labelling helper for the same coercion before reordering a chain.

Check the result on the rendered PNG rather than on `table_body` or the HTML, per [[feedback_verify_gt_output_on_render]].
