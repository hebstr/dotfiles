---
name: Do not recommend renv
description: renv is being phased out entirely — rv is the replacement for all project types
type: feedback
---

Do not recommend `renv` in any context. The user is migrating away from renv; `rv` is the package management tool for all R projects going forward.

**Why:** renv is being phased out in favor of rv. For R packages specifically, DESCRIPTION is the canonical dependency declaration. For analysis projects and pipelines, rv replaces renv.

**How to apply:** Never suggest adding renv.lock or using renv functions. If a project still has renv.lock (legacy), do not flag its absence elsewhere as a gap, and do not suggest extending its use.
