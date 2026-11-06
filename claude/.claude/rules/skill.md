---
paths:
  - "**/SKILL.md"
---

# Writing a skill

On-demand reference, loaded when a `SKILL.md` is touched. Moved out of `CLAUDE.md` on 2026-09-22.

- **Quote the `description:` value when it holds a `: ` anywhere.** An unquoted plain scalar carrying a colon followed by a space parses as a nested mapping, so the frontmatter stops being a mapping at all. Claude Code's own loader tolerates the form, which is why the defect stays invisible in a session: a stricter parser rejects the file and its tool drops the skill. Measured 2026-11-06 on `commit/SKILL.md`, where "Also use to close a session: invoke it yourself" made `sys-update agent-skills` skip it with `Nested mappings are not allowed in compact mappings`, while the same text parsed in `yaml.safe_load` once single-quoted. No gate covers it: prek's `check yaml` hook takes `.yaml` and `.yml` only and reports "no files to check" on a `SKILL.md`.
- The `description:` field must specify **when** to invoke the skill, never **how** it works. Empirically, a description that summarizes the workflow ("Reviews code by first checking style, then logic") causes Claude to follow the description as a shortcut and skip the body. Keep the description to trigger language only ("Use when X" / "Trigger on Y"); put the workflow in the body.
