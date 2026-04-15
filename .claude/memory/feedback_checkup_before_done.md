---
name: Checkup before marking done
description: Run a quality audit on task output before marking any step done — verify the result is actually usable by the next step, not just structurally complete
type: feedback
---

Never mark a task step as "done" without verifying the output is **usable by the next step**, not just structurally present.

**Why:** During a multi-step pipeline, a step was marked done because all output entries had the required fields. But the content was shallow — key values missing from 97% of entries, distribution bias undetected. The user had to ask "est-ce fonctionnel ?" to trigger the audit. That cost a round-trip and a backtrack.

**How to apply:**
1. After completing the work, **before updating any plan or tracking file**, run a checkup and present the results to the user.
2. The checkup must answer: "if the next step consumed this output right now, what would break or be degraded?"
3. Check **content quality**, not just field presence — are values plausible, are distributions sensible, does the output actually reflect the input data?
4. If issues are found: document them, add fix sub-steps to the plan, do NOT mark the step done.
5. Only mark done after the checkup passes or the user explicitly accepts the known limitations.

This applies to any multi-step task in any project.
