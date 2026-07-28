---
name: Personal working files are not to be read
description: Rationale and edge cases behind the CLAUDE.md read-gate on NOTES.md and TODO.md (the rule itself lives in Plan & memory discipline)
metadata:
  type: feedback
---

The rule is in `~/.claude/CLAUDE.md`, section "Plan & memory discipline": never read, grep, or edit `NOTES.md` / `TODO.md` without an explicit instruction naming the file. This note carries only what the bullet has no room for.

**Why:** they hold the user's own thinking, in the user's own shorthand, at whatever stage of half-formed it happens to be. They are a scratchpad, not an interface. Reading them uninvited turns private notes into input for suggestions the user never asked for, and their line numbers and phrasing are volatile by design, so anything built on them is stale on arrival.

**How to apply, beyond the CLAUDE.md bullet:**
- None of these license a read: the file is tracked by git, sits at the repo root, appears in `git status`, or is described in a project `CLAUDE.md` architecture block. The `eds-avc` project file marks both with "NE PAS LIRE sauf demande explicite" for exactly this reason.
- Editing is a stricter gate than reading, not the same one: a request to read does not extend to a fix, even an obviously correct one.
- Established 2026-07-28, after a `/workflow:sync` run in `eds-avc` read both files because they appeared in the injected uncommitted-file list, and raised a domain question (an LLM count) sourced entirely from `NOTES.md`.

Related: [[reference_todo_sync]], [[feedback_explicit_invocation_gate]], [[feedback_checkup_scope]].
