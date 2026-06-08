---
name: R environment and tooling preferences
description: Confirmed R environment idioms (rv not renv, system2 over system, rv sync at startup)
metadata:
  type: feedback
---

Package management uses `rv` (not renv). Lockfile is `rv.lock`. Do not suggest `install.packages()` or renv commands.

`rv sync` is called automatically at R session startup via `.Rprofile` (`system2("rv", "sync")` placed in the SETUP INIT block).

`system2("cmd", "args")` is preferred over `system("cmd args")` for CLI calls from R: cleaner argument separation, better cross-platform behavior, return value is the exit code.

**Why:** User asked to add `rv sync` to `.Rprofile` and asked a follow-up about `system2` vs `system`; confirmed the distinction matters to them.
**How to apply:** When suggesting CLI execution from R, default to `system2`. When discussing package management, always use rv idioms. See [[user_profile]].
