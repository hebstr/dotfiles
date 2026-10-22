---
name: reference_duckdb_storage_version_split
description: The duckdb CLI at v2.0.0 writes a storage format the R client 1.5.6 cannot open; the compat setting needs a `v` prefix
metadata:
  type: reference
---

The CLI (`~/.local/bin/duckdb`, kept current by `duckdb-update`) is at `v2.0.0`, while the R client is at `1.5.6` and CRAN published no newer one (checked 2026-10-22, `Date/Publication: 2026-09-29`).
A database the `v2.0.0` CLI creates is unreadable by both the `1.5.6` CLI ("The database file was created with a newer version of DuckDB") and the R client, which fails inside `rapi_startup` with an `IO` error naming no version, so the cause does not read off the message.
An existing 1.x file stays readable after the `v2.0.0` CLI writes to it and checkpoints: the format is not upgraded in place, so no existing database breaks by being opened.

`SET storage_compatibility_version='v1.5.6'` before the `ATTACH` makes the new CLI write a file both the old CLI and the R client read.
The `v` prefix is mandatory: `'1.5.6'` raises `Invalid Input Error`, and the error lists every accepted version.

PyPI ships `duckdb` 2.0.0, so a fresh `uv` environment takes the new engine while R stays on the old one: on a file both read, the writer decides, and only the compat setting keeps them agreeing.

The split is temporary by the user's decision of 2026-10-23: they upgrade the R client once a 2.x reaches the CRAN, and the compat setting is the bridge until then.
`curl -fsSL https://cran.r-project.org/web/packages/duckdb/DESCRIPTION | rg '^Version'` retires this note when it answers 2.x (still `1.5.6` on 2026-10-23).

Related: [[reference_dbplyr_in_vs_semi_join]], [[reference_dbplyr_null_semantics]].
