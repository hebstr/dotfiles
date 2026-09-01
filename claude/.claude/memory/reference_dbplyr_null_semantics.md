---
name: dbplyr aggregates follow SQL NULL semantics, not R's
description: "A dplyr pipeline against a database backend silently changes the meaning of NA: sum()/mean() skip NULLs instead of propagating them, so sum(if_else(col == v, 1L, 0L)) undercounts a mixed group and returns NULL for an all-NULL one; comparisons to NULL are never TRUE; wrap the aggregate in coalesce() and verify on the written artifact, never on the code"
metadata:
  type: reference
---

The same `summarise()` gives different answers in R and against a database backend, with no warning and no error. Two divergences do the damage.

**Aggregates skip NULLs.** R's `sum()` propagates `NA` unless given `na.rm = TRUE`; SQL's `SUM` ignores NULLs by default, and returns `NULL` only when *every* input is NULL. So `sum(if_else(col == "x", 1L, 0L))` over a group where `col` is sometimes NULL silently undercounts, and over a group where `col` is always NULL returns `NULL` where 0 was meant. The two failure modes look nothing alike and only the second is visible.

**Comparisons to NULL are never true.** `col == "x"` yields NULL, not FALSE, so a row with a NULL never lands in either branch of an `if_else`. That is what feeds the aggregate above.

**How to apply:** wrap the aggregate, `coalesce(sum(...), 0L)`, or test the predicate explicitly with `!is.na(col) & col == "x"` when a NULL must count as FALSE. When the derivation matters, verify on the written artifact rather than by reading the pipeline: query the parquet for the count of NULLs in the derived column and compare it to the count of groups whose input is entirely NULL. If the two match, the mechanism above is confirmed.

**Why:** measured 2026-08-31 in `eds-prise`. `collect/prise_collect-cache.R` builds per-patient stay counters with `sum(if_else(SEJ_TYPE == "EXT", 1L, 0L))` through dbplyr onto DuckDB. `SEJ_TYPE` is NULL on 151 765 of 15.8 M stays, and the written patient parquet carried NULL counters for exactly 10 101 patients of 1 632 367, a figure that matched the count of patients with no typed stay at all, which is what identified the mechanism. Reading the R alone suggested every patient with any untyped stay would be NA, which is what R semantics would have given and is 60 117 patients, six times more.

Do not "fix" such a pipeline blind when it runs somewhere you cannot execute it: see [[feedback_review_severity_eds_prise]] for that project's constraint, where the collect scripts only run on the hospital network.
