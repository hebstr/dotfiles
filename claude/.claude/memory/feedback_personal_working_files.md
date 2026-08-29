---
name: Personal working files are the user's to write, not Claude's
description: Rationale and edge cases behind the CLAUDE.md write-gate on NOTES.md, TODO.md and CALENDRIER.md (reading is free; the rule itself lives in Plan & memory discipline)
metadata:
  type: feedback
---

The rule is in `~/.claude/CLAUDE.md`, section "Plan & memory discipline": `NOTES.md`, `TODO.md` and `CALENDRIER.md` are read and grepped like any other file, and never written to. This note carries only what the bullet has no room for.

**Why:** they hold the user's own thinking, in the user's own shorthand, at whatever stage of half-formed it happens to be. That makes them a first-class source, often the only place a clinical premise or a project constraint is written down at all, and it makes them the user's alone to maintain. Rewriting a scratchpad destroys the shorthand its author reads by, and an item marked done by Claude asserts a status the user never claimed.

**How to apply, beyond the CLAUDE.md bullet:**
- Reading them uninvited is expected, not a transgression. What stays gated is the follow-through: use their content for the task at hand, do not turn a half-formed line into an unsolicited suggestion or into a domain question the user never raised.
- Editing is the whole gate, and nothing licenses an exception: not a typo, not a broken link, not a stale count. Surface it and let the user apply it.
- A `NOTES.md:<n>` citation in another note now resolves by opening the target, but their line numbers stay volatile by design, so cite by section title or quoted fragment rather than by line ([[feedback_line_number_cross_refs]]).
- History: this was a read-gate from 2026-07-28, opened after a `/workflow:sync` run in `eds-avc` read both files off the injected uncommitted-file list and raised a domain question sourced entirely from `NOTES.md`. Narrowed to a write-gate on 2026-08-25, on the user's correction: the failure was the unsolicited suggestion, not the read, and sealing the files off cost access to content the work depends on.

Related: [[reference_todo_sync]], [[feedback_explicit_invocation_gate]], [[feedback_checkup_scope]], [[feedback_line_number_cross_refs]].
