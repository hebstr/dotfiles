---
name: reference_fs_path_null_collapse
description: "fs::path() returns character(0) as soon as one argument is NULL, so a whole path silently vanishes and every wrapper over it returns nothing; fs::path_join() drops the NULL instead"
metadata:
  type: reference
---

`fs::path()` recycles its arguments, so a single `NULL` or zero-length argument makes the whole call return `character(0)` instead of the path built from the others.
Measured 2026-10-18: `fs::path("collect", "data", NULL)` is `character(0)`, and so is `fs::path("collect", "data", character(0))`.

Nothing raises. The empty result flows into an outer `fs::path(dirname, filename, ext = ext)`, which is `character(0)` too, then into `read_parquet()` or `write_parquet()`, which fail far from the cause or write nowhere.

This is a live shape in the hebstr-stack analysis projects, where a `safe_path(root, dir, split = .split)` helper builds `fs::path(root, dir, split)` and `.split` is `NULL` whenever the project is not partitioned by month.
It had silently disabled `safe_path()` and every wrapper over it in `crpv-ciclo`, where a `rootname` fallback covered the file name but never the directory, so the defect sat unnoticed as long as no caller ran.

Two fixes, both measured: `fs::path_join(c(root, dir, split))`, where `c()` drops the `NULL` before the join, and `fs::path(root, dir, "")`, which also yields `collect/data` with no trailing slash.
Prefer `path_join()`, which says what it does.

The general form is [[feedback_verify_before_claiming]] applied to paths: a helper returning a zero-length vector looks like a helper that had nothing to print, so check `length()` rather than the printed output when a path helper seems idle.
