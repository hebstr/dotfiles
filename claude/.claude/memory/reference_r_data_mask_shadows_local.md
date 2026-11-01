---
name: reference_r_data_mask_shadows_local
description: A column created earlier in the same tibble()/mutate() call shadows a same-named local object in later expressions, so obj$field aborts on "$ operator is invalid for atomic vectors"
metadata:
  type: reference
---

A data-masked call builds its mask incrementally: every column defined above an expression is visible to it and **wins over the calling environment**. So a local object and a column sharing a name collide silently until a later expression tries to subset the object.

Measured on 2026-11-01 on dplyr and tibble under R 4.6:

```r
code <- list(x = 1)
tibble(a = 1, code = "ab", b = code$x)
#> Error: $ operator is invalid for atomic vectors
```

`mutate(d, code = "ab", b = code$x)` fails identically, verified in the same session; `summarise()` and `transmute()` share the mechanism.

Two escapes, both measured: rename the local so it never collides with a column name, or reach past the mask with the `.env` pronoun, `b = .env$code$x`, which returns the object.

The failure mode is what makes it worth knowing. The error names `$` and an atomic vector and points at the line that uses the object, never at the column that shadowed it, and it only fires when the object is subset afterwards: an object merely passed whole takes the column's value instead, with no error at all.

It bit `eds-prise` on 2026-11-01, a `.code_concept()` result held in a local `code` while the same `tibble()` call built a `code` column, which is why that local is named `resolu`.

Related: [[reference_r_list_key_lookup]] for the `$` partial-match and `logical(0)` traps on the same kind of parsed-config object.
