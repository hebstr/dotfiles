---
name: Errors are never cosmetic — always investigate
description: Any error message (hook, tool, CI, linter) must be investigated before proceeding. Never dismiss, minimize, or label an error as cosmetic.
type: feedback
---

An error is NEVER cosmetic. Any message containing "error", non-zero exit code, REJECTED status, or unexpected result must be investigated before proceeding. Do not dismiss, minimize, wave away, or label an error as "cosmetic" or "not critical".

**Why:** (1) The user had to explicitly ask me to explore an Ouroboros evaluate REJECTED result that I waved away as "probably just missing tooling." (2) I labeled PreToolUse:Write hook errors as "cosmetic" without investigating — turns out it was a real hook (doc-blocker from r-skills plugin) with an overly broad matcher. Both times the user had to push me to investigate. Dismissing errors without inspection erodes trust.

**How to apply:** When any error appears: (1) identify the source (which hook, tool, command, CI step), (2) reproduce or read logs to find the root cause, (3) report the actual cause with evidence, (4) only then assess severity. This applies to hook errors, Ouroboros evaluate, CI pipelines, pre-commit hooks, linters, and any other automated check. Even if the operation "succeeded despite the error", the error itself needs explanation.
