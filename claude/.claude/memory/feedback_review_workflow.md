---
name: Preferred review workflow
description: When reviewing a package/project, launch 3 background specialists + 2-3 foreground agents by facet, synthesize, then offer /audit:walkthrough
type: feedback
---

When the user asks for a comprehensive review of a project, use this workflow:

1. **Background agents** (3, non-overlapping): `ouroboros:qa` (structure QA), `posit-dev:critical-code-reviewer` (adversarial code review), `r-lib:cran-extrachecks` (CRAN readiness, for R packages only)
2. **Foreground agents** (2-3, by facet): spawn parallel Agent calls with non-overlapping scopes (e.g. architecture, security, data layer): use the Agent tool directly, not a dedicated skill
3. **Synthesize**: Deduplicate findings across all agents into one numbered report sorted by severity (blocking → required → suggestions)
4. **Offer** `/audit:walkthrough` to process findings one by one interactively

5. **Run tests** after the walkthrough completes and fixes have been applied, for any project that includes tests. Always. Do not ask, just run them. For R packages: run `devtools::document()` before `devtools::test()` to ensure NAMESPACE is up to date.

**Why:** User wants maximum coverage from multiple angles with a single consolidated output, not separate reports to read. The walkthrough is opt-in, not auto-triggered. Tests must run after fixes to catch regressions immediately.

**How to apply:** Propose this workflow whenever the user asks for a "review", "audit", or "quality check" on a package or project. Adapt step 1 agents to the project type (e.g., drop CRAN checks for non-R projects). After walkthrough fixes, always run the project's test suite without asking.
