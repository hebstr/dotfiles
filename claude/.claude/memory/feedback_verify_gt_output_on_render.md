---
name: "gtsummary and gt: the rendered image is the oracle, never the object's styling tables"
description: A gt/gtsummary formatting defect (indentation, header wrapping, an empty column) is invisible in `table_styling` and hard to read in the HTML; render the artifact and look at it, because a helper that rewrites the table body can flatten a structure the styling table still describes correctly
metadata:
  type: reference
---

After any formatting change to a gtsummary table, look at the rendered artifact. Reading the object's `table_styling$*` frames, or grepping the emitted HTML, does not establish what the reader will see.

## Why

Measured 2026-09-01 in `eds-prise`, on `scripts/tbl_code_descr.R`.

**A structure can be described correctly and rendered flat.** `hebstr::gtsum_format()` ends on `.fmt_indent()`, which sets an indent on every row whose `row_type` is `"level"`. A `tbl_hierarchical()` table has *only* rows of that type, so concept and code rows came out at the same level, destroying the hierarchy that was the whole point of the table. `x$table_styling$indent` still listed entries with `n_spaces` 0 and 4 and looked exactly like the working version: the styling frame accumulates entries, and which one wins is decided at render.

**The HTML is a dead end for this.** gt expresses indentation through classes defined once in a stylesheet block, so counting `gt_indent_*` occurrences returns 1 per class whatever the body does, and searching for inline `padding-left` finds only cell padding. Three turns went into that archaeology and produced nothing; one look at the PNG settled it immediately.

**Two other defects only the image showed.** A header number breaking across two lines (`N = 93 908` cut after `93`) once a fourth column narrowed its column, and a `by` level with no observation keeping its column with an `N = 0` header and cells reading `0 (NA)` that `tbl_format()`'s `zero_replace` does not clean.

Same shape as [[feedback_verify_quarto_theming]] for CSS: the source compiles, the object looks right, and the output is wrong. Same shape as the closing rule of [[reference_dbplyr_null_semantics]]: verify on the written artifact, never on the code that produces it.

## How to apply

- **Trigger**: any change to a gtsummary chain that touches headers, spanners, indentation, column selection, or footnotes, and any use of a formatting helper written for a different table class.
- Run the script so it writes its artifact, then read the PNG. On the hebstr stack `easy_out()` already writes both HTML and PNG next to each other.
- The HTML is still useful for what is textual and exact: header labels, footnote text, the presence of a spanner, a table width. Use it for string checks, never for layout.
- `as_tibble(x, col_labels = FALSE)` on the gtsummary object is a good check of values and row order. It says nothing about indentation, spanners, or header composition, all of which live in styling applied later.
- When a formatting helper from the local stack is applied to a gtsummary class it was not written for, expect it to touch the body as well as the header, and check the body specifically. Here the fix was `gtsum_format(indent = 0)` followed by `modify_indent()` on the code rows alone.
