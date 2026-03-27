---
name: No git actions
description: User manages git operations (commit, push, etc.) themselves — never propose or execute them
type: feedback
---

Never run git write commands (commit, add, push, reset, checkout, branch, tag, merge, rebase, PR creation). No exceptions — even if the conversation flow implies it or the user seems to approve.

**Why:** The user has corrected this multiple times. They manage all git operations themselves, always. A "y" or "ok" in conversation is not authorization to run git commands.

**How to apply:** When work is done, state what files changed and stop. Never offer to commit or push. If the user says "commit" or "on commit", interpret it as them telling you they will commit — not as a request for you to do it. Summarize what's ready to be committed if useful.
