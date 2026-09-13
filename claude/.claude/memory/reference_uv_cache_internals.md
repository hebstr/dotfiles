---
name: uv cache internals that matter for cleanup
description: uv cache prune keeps unlinked archive entries; live archive entries mix hardlinked and copied files so only whole-entry deletion is safe; long-lived uvx/uv run processes (MCP servers) hold the cache lock for a session's life; deleting an entry costs a download; entry dir mtime is extraction time; prek and the Anki launcher embed their own uv caches
metadata:
  type: reference
---

Measured 2026-09-13 with uv 0.12.13, on the real `~/.cache/uv` and on a scratch cache through `UV_CACHE_DIR`.

- **`uv cache prune` removes dangling entries only.** After an uninstall it reports "No unused entries found" and keeps the archive entry nothing links. `--force` only skips the in-use check.
- **Live entries are mixed.** 242 of 783 `archive-v0` entries held both hardlinked and link-count-1 files, because uv copies instead of links the files it rewrites in a venv. A file-level `find -links 1 -delete` would strip live entries; delete an entry only when none of its files has a link count above 1. Cached `uvx` environments also live in `archive-v0` (top-level `pyvenv.cfg`) and are left to prune.
- **Deleting an entry costs a download, never a broken cache.** Prune leaves its `wheels-v6/.../*.http` pointer dangling, and the next install downloads again and recreates the entry; with `--offline` that install fails.
- **The cache lock is effectively always held.** Every uv process holds a shared `flock` on `<cache>/.lock` for its lifetime, and MCP servers started through `uvx ...` or `uv run ...` live as long as a Claude Code session (4 holders via `lsof`). A cleanup gated on an exclusive lock never runs. The race the lock guards, an entry extracted and not yet linked, is covered by an age floor instead: a fresh entry's directory mtime is its extraction time.
- **Other uv caches exist.** prek keeps one at `~/.cache/prek/cache/uv` (48 unlinked entries, 247 MiB, surviving `prek cache gc`; swept since 2026-09-13 by `clean_prek` after gc); the Anki launcher at `~/.local/share/AnkiProgramFiles/cache` (all linked, not swept). Search for `archive-v0` directories rather than assuming one cache.
- rv (0.22.2), by contrast, hardlinks every file of a package into a project library, so its cache entries are never mixed and a file-level link-count sweep is safe there.

The daily sweep built on this is `sweep_uv_archive` in `~/dotfiles/bin/.local/bin/sys-cleanup` (`UV_ARCHIVE_MIN_AGE_MIN=1440`), called by `clean_uv` before `uv cache prune` and by `clean_prek` after `prek cache gc`; rationale in `~/dotfiles/.claude/PLAN-ORPHANS.md` step 3 and its follow-up decision. See [[feedback_verify_native_gc_semantics]].
