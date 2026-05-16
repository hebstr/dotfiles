---
name: feedback_prose-lint-write
description: When to invoke /write to fix prose-lint violations (judgment-required vs mechanical)
type: feedback
---

Invoke `/write` to fix prose-lint violations only when the replacement requires judgment (e.g. choosing between colon, comma, parentheses, or restructure for an em-dash). Do not invoke it as a reflex on every prose-lint output.

**Why:** mechanical violations with a single obvious fix (an isolated soft-wrap, an em-dash that can only be a colon) don't need the reference. Violations where context determines the replacement benefit from the reference grounding that `/write` loads.

**How to apply:** before invoking `/write` on a prose-lint finding, ask whether the replacement choice is unambiguous. If yes, fix directly. If no, invoke `/write` to load the reference.
