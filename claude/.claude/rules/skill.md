---
paths:
  - "**/SKILL.md"
---

# Writing a skill

On-demand reference, loaded when a `SKILL.md` is touched. Moved out of `CLAUDE.md` on 2026-09-22.

- The `description:` field must specify **when** to invoke the skill, never **how** it works. Empirically, a description that summarizes the workflow ("Reviews code by first checking style, then logic") causes Claude to follow the description as a shortcut and skip the body. Keep the description to trigger language only ("Use when X" / "Trigger on Y"); put the workflow in the body.
