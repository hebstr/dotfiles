---
name: Review severity for edstr (package-specific dismissals)
description: "Calibrate code review of the edstr R package: easy_format's `\">`-anchored HTML regex is correct (EDS <p> always attributed); supplements feedback_review_severity_personal"
metadata:
  type: feedback
---

Package-specific review dismissals for edstr, supplementing [[feedback_review_severity_personal]]. Scope: the R package at `~/Documents/packages/R-edstr` (clinical concept extraction over EDS clinical notes).

**Why:** recurring false positives on documented design boundaries a reviewer re-flags each pass.

**How to apply:**
- **`easy_format()`'s HTML-body regex `regex("\">(.+?)</p>", dotall = TRUE)` is correct as written** (`R/extract_helpers.R`, inside `.extract_format_text`). The `">` anchor requires an attribute quote before the closing `>` of the opening tag, i.e. it matches `<p class="...">content</p>` but NOT a bare `<p>content</p>`. This is intentional: EDS export `<p>` tags **always** carry an attribute (author-confirmed 2026-07-21). Do NOT flag "the regex ignores bare `<p>` tags / misses `<p>` without attributes" as a bug: bare `<p>` does not occur in the real EDS format, and any document that does produce empty formatted text is now surfaced by the `cli_warn` guard in `.extract_format_text`. The `dotall = TRUE` + non-greedy `(.+?)` were added 2026-07-21 so a single `<p>` whose content spans multiple lines is captured (the HTML is multi-line); greedy `.+` without dotall was the prior truncation bug and is fixed, so do not re-propose it either.
