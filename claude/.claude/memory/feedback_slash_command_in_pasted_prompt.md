---
name: feedback_slash_command_in_pasted_prompt
description: A `/name` heading a pasted prompt fires nothing, and the Skill tool refuses it; ask the user to type it. A skill named in conversation and absent from the session list is user-invocable only, never nonexistent
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

The same inference is wrong when the user only names a skill in conversation rather than invoking it.
On 2026-10-29, asked in `dotfiles` whether a `/design` was worth invoking, the session answered that no skill of that name was available, reading its own listing as the inventory; the user corrected it with "le skill `/design` existe".
The listing is the set of model-invocable skills, never the set of installed ones, so it cannot support a claim of absence.

**How to apply:** scan the first line of a pasted prompt for `/name` before planning anything, and treat any skill the user names, invoked or merely mentioned, as existing until a check says otherwise.
Absent from the skill list, the cheapest check is one `Skill` call on the bare name: its refusal names `disable-model-invocation` outright, where `~/.claude/skills/<name>/SKILL.md` has to be found first and misses a plugin-provided skill.
Then say in one line that the command has to be typed, and name what is worth doing first: exploration whose facts the skill will need is useful, the artifact the skill produces is not.
The handoff goes to `.claude/PROMPT.md` opening on that `/name`, per `rules/claude-files.md`.

Related: [[reference_claude_code_best_practices]].
