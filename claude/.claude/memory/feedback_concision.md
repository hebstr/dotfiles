---
name: feedback_concision
description: Cut research narrative from notes and replies: record what binds future work, never how the answer was reached
metadata:
  type: feedback
---

Corrected twice on 2026-09-30, in eds-prise: a five-bullet note entry for a negative result ("quel est l'intérêt d'écrire un pavé pour ça ?"), then the reply summarising it ("arrête de parler pour rien dire, chaque mot compte").

What a note keeps is what changes a future decision: a figure, a closed route, a constraint still binding. What it drops is the path to it, the sources consulted, the reasoning replayed, the reassurance that a check ran. Two lines beat five bullets carrying the same two facts.

A reply keeps the answer and the recommendation. A recap of what was just done, a restatement of the question, and a closing summary of the edit the user can read in the diff all go.

**Why:** the conversation already holds the narrative, so a note repeating it costs a reader on every future pass and dilutes the fact that mattered. And where a `.claude/` has its own repository, `~/dotfiles` and eds-prise so far, every surplus line is committed and reviewed rather than scratch.

**How to apply:** before writing a note entry, name the future decision it changes; if none, drop it. Prefer one bullet per fact with its measurement inline. See [[feedback_prose-lint-write]] for style scope and [[project_claude_dir_local_only_repo]] for the repo.
