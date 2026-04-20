---
name: No renv for R packages
description: Do not recommend renv for R packages — DESCRIPTION is the canonical dependency declaration
type: feedback
---

Do not recommend `renv` for R packages. DESCRIPTION is the canonical dependency declaration for packages — `renv.lock` is for analysis projects and deployment pipelines, not for packages that already declare deps via Imports/Suggests.

**Why:** renv is not standard practice for R packages. It creates confusion about the source of truth (DESCRIPTION vs renv.lock). This applies to all R packages, not just this project.

**How to apply:** When reviewing any R package, do not flag absence of renv.lock as a reproducibility gap. Only suggest renv for analysis projects, Shiny apps, or deployment pipelines.
