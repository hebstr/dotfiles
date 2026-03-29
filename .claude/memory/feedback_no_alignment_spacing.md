---
name: No argument alignment spacing
description: Do not align argument = signs with extra spaces in R function calls
type: feedback
---

Never add extra spaces to align `=` signs across arguments in R function calls.
Write `data = x`, not `data    = x`.

**Why:** The user considers this artificial alignment noisy and unnecessary.
**How to apply:** When writing or editing R code (examples, README, vignettes, source), use exactly one space before and after `=` in function arguments — no padding for vertical alignment.
