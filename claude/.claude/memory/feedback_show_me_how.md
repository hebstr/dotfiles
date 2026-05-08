---
name: show me how = tutorial, not execution
description: When user says show me how to do X, produce a tutorial to follow, not execute X directly
type: feedback
---

"Show me how to do X" means: produce a step-by-step tutorial the user can execute themselves to learn. It does not mean: do it for them.

**Why:** User wants to understand the tool/process, not just get the result. Doing it directly skips the learning and modifies their environment without consent.

**How to apply:** When the phrasing is "show me how to", "how do I" — write a tutorial with commands they can run, not a sequence of tool calls that execute those commands. If the intent is ambiguous, ask first: "Do you want me to do it, or a tutorial you can follow yourself?"
