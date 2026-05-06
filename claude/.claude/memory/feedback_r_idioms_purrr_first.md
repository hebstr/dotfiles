---
name: R idioms — purrr first for list-building
description: For repeated R calls to simplify into a list, lead with purrr (set_names + map), not base R setNames + vectorized call
type: feedback
---

When simplifying repeated R calls into a named list (e.g. multiple `Sys.getenv()`, `readLines()`, or similar), lead with the purrr-idiomatic pipeline: `set_names()` + `map()`. Base R (`setNames()` + vectorized call in a `{}` block) is a fallback only when explicitly asked, or when there is a concrete performance reason.

**Why:** User's conventions are explicitly tidyverse-idiomatic. Proposing base R first and correcting to purrr only when asked wastes a turn.

**How to apply:** For any "simplify these repeated calls into a list" pattern in R, sketch the purrr pipeline first. Example:

```r
c("ID", "GROUP", "TEXT") |>
  purrr::set_names(tolower) |>
  purrr::map(\(x) Sys.getenv(paste0("COL_", x)))
```

Reach for base R only if the user asks for it, or if there is a measurable performance bottleneck that purrr cannot address.
