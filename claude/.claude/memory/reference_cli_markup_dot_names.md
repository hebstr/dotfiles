---
name: reference_cli_markup_dot_names
description: A dot-prefixed R object inside a cli message is read as inline markup, not as an expression
metadata:
  type: reference
---

`cli_abort()`, `cli_warn()` and `cli_inform()` read `{.name}` as inline markup (a class such as `{.path}` or `{.code}`), so interpolating an object whose name starts with a dot aborts on `Invalid cli literal: {.code {{...}}} starts with a dot` instead of printing the message. This collides head-on with the house convention of `rules/r.md`, where everything internal to a script or a setup is dot-prefixed (`.annot_reader`, `.surv`, `.model`), so the collision is the default case rather than an edge one.

Interpolate a call rather than the bare name: `{nrow(.annot_non_resolu)}` and `{length(.annot_reader)}` both resolve, because the literal no longer starts with a dot. That also supplies the quantity a following `{?s}` reads for pluralisation, so holding the rows rather than the count in the object is usually the better shape.

Second trap in the same strings: `cli_abort()` calls `cli:::glue_cmd(.trim = FALSE)`, so glue's `\\` end-of-line continuation keeps the next line's indentation and sends a run of spaces into the message. Write a long message on one line, or split it across elements of the `c()` vector.

Measured 2026-11-11 in `eds-prise` on `annot/annot_output-merge.R`, where the guard fired and its own message was what raised. Related: [[reference_r_list_key_lookup]].
