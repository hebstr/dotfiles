---
name: R environment and tooling preferences
description: Confirmed R environment idioms (rv not renv, system2 over system, how an rv project activates at startup)
metadata:
  type: feedback
---

Package management uses `rv` (not renv). Lockfile is `rv.lock`. Do not suggest `install.packages()` or renv commands.

An rv project's `.Rprofile` activates the library with `source("rv/scripts/activate.R")`; a sync at startup is the optional `.rv$sync()` line after it, active in eds-epimad and umb-coco and commented out in eds-avc, eds-prise and crpv-ciclo (checked 2026-09-22). No `.Rprofile` under `~/Documents` calls `system2("rv", "sync")`.

`system2("cmd", "args")` is preferred over `system("cmd args")` for CLI calls from R: cleaner argument separation, better cross-platform behavior, return value is the exit code.

**Why:** User asked to add `rv sync` to `.Rprofile` and asked a follow-up about `system2` vs `system`; confirmed the distinction matters to them.
**How to apply:** When suggesting CLI execution from R, default to `system2`. When discussing package management, always use rv idioms. See [[user_profile]].
