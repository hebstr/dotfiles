---
name: reference_r_list_key_lookup
description: Reading a declared key out of an R list (a parsed YAML block, a config): `$` partial-matches silently and `==` yields logical(0) on an absent or emptied key, which stopifnot() accepts; use `[[` and identical()
metadata:
  type: reference
---

Two traps, both measured in `eds-prise` on 2026-09-02 while reading `_variables.yml`, both silent.

**`$` partial-matches on a list.** `lst$select_inclusion` resolves to `lst$select_inclusion_code` when only the longer name exists, so renaming a key by adding a longer sibling keeps the old read working, and removing a key from a block that holds a sibling with the same prefix returns the sibling's value instead of failing. Every read of a declared key therefore goes through `[[`, which matches exactly and returns `NULL` otherwise. Partial matching is the documented default of `$` on lists; only `options(warnPartialMatchDollar = TRUE)` makes it audible, and it is off by default.

**`==` yields `logical(0)` on an absent or emptied key**, and `stopifnot()` accepts a zero-length logical as a pass: a guard written `stopifnot(cfg[["code"]] == "M19")` passes when the key was deleted, which is the one case it exists to catch. Guards that pin a key to its literal use `identical()`, which returns `FALSE` on `NULL`.

The same pair bites any config read as a list: YAML through `yaml::read_yaml()` or `yaml12::read_yaml()`, TOML, JSON, and `options()`.

Related: [[reference_dbplyr_null_semantics]] for the SQL-side analogue, where `col == v` is never TRUE on NULL and conditional counts undercount.
