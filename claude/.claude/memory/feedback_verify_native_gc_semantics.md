---
name: Verify what a native GC command removes before calling a cache covered
description: Before declaring a cache "covered" by a package manager's own cleanup command, read its help text and test it on a scratch copy; several such commands remove far less than their name suggests (uv cache prune, pak::cache_clean, flatpak uninstall --unused, prek cache gc)
metadata:
  type: feedback
---

A cleanup command's name is not its contract. Before writing "already covered, nothing to build" about a cache, read the command's `--help` and run it against a scratch copy of the cache (an env var such as `UV_CACHE_DIR`, `R_PKG_CACHE_DIR` or `FLATPAK_USER_DIR` usually redirects it), then measure what is left.

Measured 2026-09-13 on this machine, all while `sys-cleanup` ran the command daily:

- `uv cache prune` removes dangling entries only; archive entries no venv links survive it (11 GiB of 14 GiB in `~/.cache/uv`).
- `prek cache gc` left its own embedded uv cache with 48 unlinked archive entries (247 MiB): the same gap one level down.
- `pak::cache_clean()` leaves `_metadata`, where one `pkgs-<hash>.rds` per configuration piles up (16 superseded snapshots, 1.36 GiB).
- `flatpak uninstall --unused` keeps any runtime an installed app names in `sdk=`, even though the app only needs `runtime=` (1.7 GiB SDK).
- `flatpak repair --user` is prune-only on a healthy repo, but its man page also removes refs and re-installs from the network on a corrupted one, so it is a repair, not a cleanup.

**Why:** `PLAN-UPDATER-HYGIENE.md` recorded "caches: `sys-cleanup` already owns them through `uv cache prune` ... Nothing to build" on 2026-08-19 without checking what prune removes, and that unverified line hid 11 GiB for a month. It is the reasoning-from-absence failure of [[feedback_verify_before_claiming]] applied to a tool's name.

**How to apply:** treat "the tool has a GC command" as a hypothesis. The check is cheap: help text, one run on a scratch copy, a before/after count of whatever the cache holds (entries, link counts, snapshots). Record the measured semantics next to the decision so the next audit does not repeat the assumption. Design and measurements for the machine's cleanup in `~/dotfiles/.claude/PLAN-ORPHANS.md`; uv specifics in [[reference_uv_cache_internals]], pak specifics in [[reference_pak_metadata_cache]].
