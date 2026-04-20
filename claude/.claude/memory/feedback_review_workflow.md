---
name: Preferred review workflow
description: When reviewing a package/project, use 3 background specialist agents + parallel-review foreground, then offer review-walkthrough
type: feedback
---

When the user asks for a comprehensive review of a project, use this workflow:

1. **Background agents** (3, non-overlapping): `/ouroboros:qa` (structure QA), `/critical-code-reviewer` (adversarial code review), `/cran-extrachecks` (CRAN readiness — for R packages)
2. **Foreground**: `/parallel-review` (scatter-gather with 2-3 agents by facet → consolidated report)
3. **Synthesize**: Deduplicate findings across all 6 agents into one numbered report sorted by severity (blocking → required → suggestions)
4. **Offer** `/review-walkthrough` to process findings one by one interactively

5. **Run tests** after the walkthrough completes and fixes have been applied, for any project that includes tests. Always. Do not ask — just run them. For R packages: run `devtools::document()` before `devtools::test()` to ensure NAMESPACE is up to date.

**Why:** User wants maximum coverage from multiple angles with a single consolidated output, not 6 separate reports to read. The walkthrough is opt-in, not auto-triggered. Tests must run after fixes to catch regressions immediately.

**How to apply:** Propose this workflow whenever the user asks for a "review", "audit", or "quality check" on a package or project. Adapt step 1 agents to the project type (e.g., drop CRAN checks for non-R projects). After walkthrough fixes, always run the project's test suite without asking.
