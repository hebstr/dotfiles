---
name: pak metadata cache accumulation and how to read the current snapshot
description: pak writes one pkgs-<hash>.rds metadata snapshot per configuration (repos, R version, platform) under ~/.cache/R/pkgcache/_metadata and never removes superseded ones; pak::meta_summary()[["current_db"]] names the live one; meta_clean() prompts unless force = TRUE; R_PKG_CACHE_DIR redirects the cache; a rebuild from empty took 94 s
metadata:
  type: reference
---

Measured 2026-09-13 with pak 0.11.1.

- `~/.cache/R/pkgcache/_metadata` held 17 `pkgs-<hash>.rds` snapshots (70 to 135 MiB each, 1430 MiB) plus 26 raw `PACKAGES.gz` repo dirs (21 MiB). A new snapshot appears whenever the configuration hash changes, 29 files in 13 days here, and none is ever deleted. `pak::cache_clean()` does not touch this directory.
- `pak::meta_summary()` returns `cachepath`, `current_db`, `raw_files`, `db_files`, `size`; `current_db` is the snapshot of the calling session's configuration. Read it as `[["current_db"]]` inside a single-quoted `Rscript -e` so shellcheck does not flag the `$` (SC2016).
- `pak::meta_clean(force = FALSE)` asks "Do you want to delete all package metadata (Y/n)" through `get_confirmation2`; only `force = TRUE` runs unattended, and it deletes the whole DB.
- `R_PKG_CACHE_DIR` is honoured (a scratch cache filled there), although `rg -a` does not find the string in pak's compressed install.
- Rebuild cost from an empty cache: `pak::meta_update()` took 94 s and wrote 77 MiB, recreating the same current snapshot. Deleting only superseded snapshots avoids that cost for the default R; a session under another R version rebuilds its own.

The daily prune built on this is in `clean_r_cache` of `~/dotfiles/bin/.local/bin/sys-cleanup`; rationale in `~/dotfiles/.claude/PLAN-ORPHANS.md` step 5. See [[feedback_verify_native_gc_semantics]].
