---
name: Review severity for personal packages
description: Calibrate code review severity down for personal/internal packages — skip defensive patterns appropriate for public CRAN libs
type: feedback
---

For personal utility packages (not public CRAN libraries), calibrate review severity accordingly. Do not suggest overly defensive patterns that are appropriate for public-facing code.

**Why:** Reviews of hebstr and edstr both had 60-70% of findings rejected as disproportionate. Patterns flagged as bugs were valid R idioms or acceptable shortcuts for internal tooling.

**How to apply:**
- Do not suggest input validation on internal function arguments when downstream errors are already clear
- Do not suggest tryCatch wrapping when a fallback path already exists
- Do not flag variable name shadowing when R's scoping rules resolve it unambiguously
- Do not flag missing namespace prefixes for functions already in NAMESPACE imports
- Do not flag testthat test isolation as "missing mutualisation" — self-sufficient tests are the recommended testthat 3 pattern
- Project-level memory files may contain package-specific examples of dismissed findings — check those before reviewing
