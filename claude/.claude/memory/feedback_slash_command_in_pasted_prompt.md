---
name: feedback_slash_command_in_pasted_prompt
description: A `/name` heading a pasted prompt fires nothing, and the Skill tool refuses it; ask the user to type it
metadata:
  type: feedback
---

When the user's message opens on `/name`, treat it as the instruction it is, even when the harness wrapped the text in `<pasted_content>` so the command never fired.
A skill carrying `disable-model-invocation: true` is absent from the session's skill list **and** refuses the `Skill` tool, which answers "Ask the user to run /name themselves; do not replicate this skill's workflow by other means".
So the only route is to say so in the first reply, before doing the work the skill was meant to conduct.

**Why:** on 2026-10-19 a `/design` opened a pasted request in `eds-avc`; the command fired nothing, the skill was invisible, and the session ran the whole exploration and wrote the design note itself.
The skill then refused the tool call, so the entire pass had to be handed back through `.claude/PROMPT.md` for a fresh conversation.
The user's correction: "l'invocation design était bien écrite en début de prompt : tu n'avais aucune raison viable de ne pas l'invoquer."
A `/name` absent from the skill list is the signal that it is user-invocable only, never the signal that it does not exist.

**How to apply:** scan the first line of a pasted prompt for `/name` before planning anything.
Absent from the skill list, check `~/.claude/skills/<name>/SKILL.md` for `disable-model-invocation: true` rather than concluding the skill is missing.
Then say in one line that the command has to be typed, and name what is worth doing first: exploration whose facts the skill will need is useful, the artifact the skill produces is not.
The handoff goes to `.claude/PROMPT.md` opening on that `/name`, per `rules/claude-files.md`.

Related: [[reference_claude_code_best_practices]].
