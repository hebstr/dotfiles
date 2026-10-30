---
name: Personal working files are the user's to write, not Claude's
description: Rationale and edge cases behind the write-gate on NOTES.md, TODO.md and CALENDRIER.md (reading is free; the rule is stated in rules/claude-files.md and enforced by permissions.deny for NOTES.md and TODO.md alone)
metadata:
  type: feedback
---

The rule is stated in `rules/claude-files.md`, section "Content": `NOTES.md`, `TODO.md` and `CALENDRIER.md` are read and grepped like any other file, and never written to. `permissions.deny` in `settings.json` enforces it for `NOTES.md` and `TODO.md` alone: the user took `Edit(//**/CALENDRIER.md)` out of that list on 2026-10-30, so that one file rests on the rule rather than on a mechanism. This note carries only what the bullet has no room for.

**Why:** they hold the user's own thinking, in the user's own shorthand, at whatever stage of half-formed it happens to be. That makes them a first-class source, often the only place a clinical premise or a project constraint is written down at all, and it makes them the user's alone to maintain. Rewriting a scratchpad destroys the shorthand its author reads by, and an item marked done by Claude asserts a status the user never claimed.

**How to apply, beyond the `rules/claude-files.md` bullet:**
- Reading them uninvited is expected, not a transgression. What stays gated is the follow-through: use their content for the task at hand, do not turn a half-formed line into an unsolicited suggestion or into a domain question the user never raised.
- A `NOTES.md:<n>` citation in another note now resolves by opening the target, but their line numbers stay volatile by design, so cite by section title or quoted fragment rather than by line ([[feedback_line_number_cross_refs]]).

Related: [[reference_todo_sync]], [[feedback_review_severity_skill_audits]], [[feedback_line_number_cross_refs]].
