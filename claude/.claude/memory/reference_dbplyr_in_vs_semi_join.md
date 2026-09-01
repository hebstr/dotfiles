---
name: "dbplyr: filter with %in% over a large id vector never returns; semi_join instead"
description: "`filter(id %in% <100k R values>)` against a lazy duckdb table inlines every value into a SQL IN list and does not complete; keep both sides lazy and use semi_join so the join happens in the database"
metadata:
  type: reference
---

Filtering a lazy database table on membership in a large R vector inlines every value as a literal in a SQL `IN (...)` clause. At roughly 10^5 values the query stops completing in any useful time, with no error and no warning: the pipeline simply hangs.

Keep both sides lazy and let the database do the join:

```
sej_type <- df_init$sej |>
  semi_join(df_init$code, by = "id_sej") |>
  distinct(id_sej, sej_type) |>
  collect()
```

The `collect()` goes last, after the restriction, so only the reduced result crosses back into R.

**Why:** measured 2026-09-01 in `eds-prise`, deriving the stay type for the stays carrying a declared code. `filter(id_sej %in% .ids)` with 98 901 identifiers against a 15.8 M-row duckdb table was killed at 2 minutes, then again at 500 seconds. The `semi_join` form returned the 98 901 rows as part of a run whose whole cost was the ordinary session setup.

`df_init` in that project is a list of `tbl_duckdb_connection` objects built by `read_collect()`, so every element is lazy and joins between them stay in the database. The same holds for any dbplyr backend.

A second reason to prefer it: the `%in%` form silently changes cost with the size of the id vector, so a pipeline that is fast on a test subset can hang on the full data. The `semi_join` form has no such cliff.

Do not confuse this with [[reference_dbplyr_null_semantics]], which is about aggregates over NULLs in the same stack; that one changes results, this one changes only whether the query returns.
