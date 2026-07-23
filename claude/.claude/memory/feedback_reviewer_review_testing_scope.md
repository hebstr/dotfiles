---
name: Scope override for posit-dev:review-testing
description: "review-testing scopes itself to test files changed on the current branch: on a clean tree it finds nothing, so pass an explicit scope override when reviewing an existing suite"
metadata:
  type: feedback
---

`posit-dev:review-testing` opens its workflow with "Find changed test files on the current branch (relative to the base branch)". On a clean working tree with no PR (reviewing an existing suite on `main`), that yields zero files and the reviewer can come back with "no changed test files found" instead of a review.

**Why:** the skill is written for the post-implementation case (review the tests that came with this feature). Reviewing a whole existing suite is a different, equally common ask, and nothing in the skill's own text handles it. `/audit:walkthrough`'s orchestrator passes `Review: <target>`, which competes with the skill's Step 1 rather than clearly overriding it.

**How to apply:**

- When launching it (as `/audit:walkthrough --reviewer posit-dev:review-testing`, or directly), add an explicit scope override to the prompt: state that the tree is clean and there is no diff, enumerate the test files in scope, and say that reporting "no changed test files" is a task failure.
- It chains to `r-lib:testing-r-packages` for R conventions, by its own instruction. If a first pass already used that same skill, both reviews share a grid and therefore share blind spots. When the goal is independence from a review already done on the testthat grid rather than depth on test design, prefer `posit-dev:critical-code-reviewer`.
- Both reviewers emit the same severity tiers (`Critical Issues (Blocking)` / `Required Changes` / `Suggestions`), so `/audit:walkthrough` parses either without adaptation. Reviewer choice is about lens, never about output compatibility.

Related: [[feedback_review_workflow]], [[feedback_review_severity_personal]].
