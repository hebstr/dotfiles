---
name: reference_duckdb_storage_version_split
description: duckdb storage is one-way readable across versions and the compat setting needs a `v` prefix; the R-client-behind-CLI split closed on 2026-10-23
metadata:
  type: reference
---

A database written by a newer duckdb is unreadable by an older client: the CLI says "The database file was created with a newer version of DuckDB", and the R client fails inside `rapi_startup` with an `IO` error naming no version, so the cause does not read off the message.
The converse is safe: an existing older file stays readable after a newer client writes to it and checkpoints, the format not being upgraded in place.
Re-measured 2026-10-28 between R clients, 2.0.0 writing and 1.5.6 failing to open.

`SET storage_compatibility_version='v1.5.6'` before the `ATTACH` makes a newer CLI write a file an older client reads.
The `v` prefix is mandatory: `'1.5.6'` raises `Invalid Input Error`, and the error lists every accepted version.

The split that motivated this note is closed: the CLI (`~/.local/bin/duckdb`, kept current by `duckdb-update`), PyPI and now the CRAN all ship 2.0.0, published 2026-10-23, so the compat setting is no longer the bridge it was while the R client sat at 1.5.6.
What the monoculture costs is a one-way door: a project whose lockfile moves to duckdb 2.0.0 cannot move back once a cache has been written under it.
That door is what forced a fix rather than a rollback in `eds-prise`, `.claude/DESIGN-COLLECT.md`, section « La collecte du 2026-10-28 », where duckdb 2.0.0 also broke `tbl(con, I("name"))` by letting `dbExistsTable()` raise where it used to return `FALSE`.

Related: [[reference_dbplyr_in_vs_semi_join]], [[reference_dbplyr_null_semantics]].
