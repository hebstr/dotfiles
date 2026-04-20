---
name: CLAUDE.md configuration preferences
description: User's validated preferences for CLAUDE.md structure — what belongs in global vs project scope, what to avoid
type: feedback
---

Global CLAUDE.md (~/.claude/CLAUDE.md) should contain only personal defaults (profile, style, guardrails, tools). Build/test/lint commands belong in project-level CLAUDE.md files.

**Why:** Reviewed 2026-03-27 — build commands are project-specific and would be noise in global config. Data safety rules (patient data, joins, approximations) ARE appropriate in global because they're personal guardrails across all projects.

**How to apply:** When suggesting CLAUDE.md changes, put project-specific content (commands, git conventions, file structure) in project CLAUDE.md. Don't suggest fragmenting into .claude/rules/ until the file exceeds ~100 lines. Don't suggest hooks for pattern-matching patient data — organizational guardrails are the right approach there. All Claude-related project files (CLAUDE.md, reviews, settings) go in `.claude/`, not at the project root — keeps the root clean.
