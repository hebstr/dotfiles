---
name: continuation prompts on session boundary
description: When recommending to continue work in a new conversation, proactively provide a ready-to-paste continuation prompt
type: feedback
---

When a task should continue in a new conversation (context too large, different working directory, or natural breakpoint), proactively generate a ready-to-paste continuation prompt — do not wait for the user to ask for one.

**Why:** The user confirmed this behavior as valuable (2026-04-01). A well-crafted continuation prompt preserves context across session boundaries without requiring the user to re-explain the task. It saves time and reduces information loss.

**How to apply:** When recommending "new conversation", always include a fenced code block with the continuation prompt. The prompt should reference: (1) specific file paths for context, (2) what was already done, (3) what remains to do, (4) any constraints or known issues. Keep it self-contained — the next session has no memory of the current one.
