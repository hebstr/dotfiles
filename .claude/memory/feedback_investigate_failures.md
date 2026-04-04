---
name: Investigate tool failures instead of dismissing them
description: When an external tool (Ouroboros, CI, linter) returns a failure, investigate the root cause before concluding it's irrelevant
type: feedback
---

When an external tool returns a failure or unexpected result (REJECTED, exit code != 0, error status), always investigate the root cause — run the underlying commands, check what's installed, reproduce the failure. Do not dismiss it with assumptions like "probably just missing tooling" without verifying.

**Why:** The user had to explicitly ask me to explore an Ouroboros evaluate REJECTED result that I waved away as "linting/coverage tool failures unrelated to the changes." The diagnosis was correct (mypy and pytest-cov not installed), but I should have reached that conclusion through investigation, not assumption. Dismissing failures without inspection erodes trust.

**How to apply:** When any tool reports a failure: (1) identify what commands it likely ran, (2) reproduce them locally, (3) report the actual root cause with evidence. Only then assess whether it's a real problem or a false negative. This applies to Ouroboros evaluate, CI pipelines, pre-commit hooks, and any other automated check.
