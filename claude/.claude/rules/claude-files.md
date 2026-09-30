---
paths:
  - "**/.claude/**/*.md"
  - "**/CLAUDE.md"
  - "**/AGENTS.md"
---

# Files written for Claude

Loaded when Claude reads a file meant for Claude or another agent (`CLAUDE.md`, `AGENTS.md`, rules, skills, memory, and the `.claude/` notes: plans, design notes, handoffs, `DEFERRED.md`), and injected by `inject-rules.sh` on the session's first write to one.

## Language

- Everything meant for Claude or agents is written in English, French only when the user explicitly asks for it: memory files, skills with their agents and prompts, rules files, `CLAUDE.md`, and the `.claude/` notes. The conversation itself still mirrors the user's language.
- Existing French content of that kind moves to English at its next substantial rewrite, skills one per conversation; the deferred list is in `~/dotfiles/.claude/DESIGN-CADRER.md`.

## Form

- In a `.claude/` markdown file, every table and every display equation goes inside a ``` fence: fenced content is the only thing a `panache` reformat leaves byte-identical, and these files are read by Claude rather than rendered. Never do this in a rendered document (`.qmd`, README, docs), where the table is the point. Rationale in `rules/quarto.md`.
- Cite by name, never by line number: code by its symbol (a function, a branch named by its guard), a test by its `test_that()`, `def test_` or `@test` title, prose by its section heading or a verbatim quote. A line number rots silently on any insertion above it, while a name either resolves under `rg -F` or fails loudly.
- A drifted line reference is never renumbered: in live text, convert it to a name in the same edit; in a dated or superseded section, leave it as record. A shift in line numbers alone is therefore never staleness for a sync or audit pass. Carve-out: a project `CLAUDE.md` that deliberately keeps `file:line` pointers in a named section owns their upkeep, and no new ones are added elsewhere. Detail and incidents in `feedback_line_number_cross_refs.md`.

## Content

- A tracking-file write states only what a command just confirmed (grep, count, `git log`, `git status`), never what recall suggests. The commit verifier re-derives these claims, and the ones the user's own action invalidates (a commit, a rename, a manual edit) are rechecked once they act.
- `NOTES.md`, `TODO.md` and `CALENDRIER.md` are the user's personal scratchpads: read them freely, never write to them, keep them out of every tracking update, and surface to the user a change they need.
- A tracking update deletes as well as records: an executed decision goes, unless it records a rejected alternative or a constraint that still binds future work. A step taken, a parameter changed, a verification passed belong to the commit message and to `git blame`.
- What the criterion protects, and a pass leaves alone: walkthrough blocks, the internal `Rejected` and `Voies écartées` lists, fragile hypotheses, unclosed residuals, a WHY the code cannot carry (`CLAUDE.md` forbids comments in code and routes it to the tracking note), a measurement no better copy holds, and everything a pending measurement step must still compare.
- A section that describes an artefact the repository carries goes: a script's exit codes, its flags and its cases are established better by its suite, which "Cite by name" above already prescribes citing by title. A verified fact with no other holder moves to a memory recalled by its description, rather than staying in a plan only the verifier reads.
- After each cut, and not at the end of the pass, check the names: `rg -F` the title of what was cut and the names inside it across the repository's `.claude/`, its notes and its test files. A rename and a rewrite break a reference exactly as a deletion does. Incidents and the sweep script are in `~/dotfiles/.claude/PRUNE-OBSERVATIONS.md`.

## Where a new instruction goes

Every new instruction is routed by this test, applied in order (`~/dotfiles/.claude/DESIGN-INSTRUCTION-ROUTING.md`):

1. A deterministic mechanism can enforce it (a permission, a `PreToolUse` deny or ask, a `Stop` gate, a linter): it moves there, and `CLAUDE.md` keeps nothing, not even a sentence naming the hook; the hook's own message carries the instruction.
2. Its trigger is reading a file type through `Read`: a `paths:` rule. A `Write` of a new file loads no `paths:` rule.
3. Its trigger is a command, a tool, a path, a phrase or a session moment: a hook that injects the rule at that moment (`PreToolUse`, `UserPromptSubmit`, `SessionStart`), each injected file at or under 9,000 characters.
4. It is a multi-step procedure: a skill.
5. What remains stays in `CLAUDE.md` only if it applies in every session and is not derivable from the machine or the repository; its rationale goes to a note.

A new line in the global `CLAUDE.md` needs the user to have corrected the same behavior at least twice. The always-loaded set, `CLAUDE.md` plus every rules file without `paths:`, has a byte budget: an addition names what it displaces, and raising the budget is a recorded decision.
