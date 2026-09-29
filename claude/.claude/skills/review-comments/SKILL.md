---
name: review-comments
description: Use when the user types `/review-comments <docx>` to work through, point by point, the comments a reviewer left on a `.docx`.
disable-model-invocation: true
---

# Working through a reviewer's comments on a Word file

Conduct the conversation in the user's language, whatever the language of this text.

The invocation receives a `.docx` a third party has commented, and returns a register where every comment carries a decision from the user.
What is written into the register follows the language of the project's notes, and the labels the script writes stay as they are, since the tally is counted on them.

## Unit and scope

The unit is the comment, question or remark alike, with its replies filed under it.
Tracked changes, highlights and anything to do with presentation are out of scope unless the user asks otherwise; cite them when they shed light on a comment, never as points of their own.

The authored source is not edited during the pass: the register takes the decisions, and carrying them back into the source comes afterwards, outside the pass.

With no docx, or when the script reports it unreadable, ask for one.
The register is created at the path the user gives. With no path, ask for one, and also ask for the authored source the docx was rendered from, if there is one.
An existing register is never overwritten: the script refuses, and `--force` is passed only on an explicit instruction, after saying that it renumbers and wipes the decisions already recorded. A further review of the same document opens a register at another path. A directory git ignores has no safety net.

## Stage 1, the skeleton

The script sets out the list, passing no judgement:

```
uv run --script ~/.claude/skills/review-comments/scripts/skeleton.py <docx> -o <register> [--source <source>]
```

It transcribes every comment word for word from `word/comments.xml`, files replies under their root through `word/commentsExtended.xml`, restores the anchored extract to its original text, deletions put back and insertions ignored, and derives the section from the document's outline levels.
Never copy a comment out by hand: `officer::docx_comments()` and `pandoc --track-changes=all` both return a reply as a standalone comment, and a hand-copied transcription drifts with nothing to signal it.

The script's summary gives the count of comments, of points, of replies, of points with no anchor, of points anchored outside the document body and its notes (header, footer) and, with `--source`, of extracts not found or ambiguous.
It also flags a file with no `word/commentsExtended.xml`, where replies cannot be filed and each one counts as a point: tell the user before the triage.
Every extract not found or ambiguous is settled by reading the source, in the entry's `**Localisation**` line, whose parenthesised status left by the script is replaced by the result: a short extract is completed with the sentence containing it, an extract that cannot be found is placed by its section and says so.

Then record the linked comments, by number, in the register's section for them, and present them to the user: a link bears on what the user will set aside.

The numbering is fixed at this stage and never moves again.

## Stage 2, the triage

The user reads the register and names in the conversation the entries not worth a turn.
Each one takes, in place, `**Décision** : écartée au tri, AAAA-MM-JJ.` dated to the session, and its reformulation and proposal lines keep their « à établir ».

Never delete an entry and never renumber: the links, the cross-references between points and the tally all hold by the numbers, and a comment set aside may call for a reply later.

## Stage 3, the review

One point per turn, in order, the entries set aside passed over in silence.

The turn presents the transcribed comment, then three things.

1. **Reformulation et contexte.** Restate what the reviewer is asking for without reusing their wording, and give what supports or contradicts it. Read before asserting: the section the comment points at, the passages tied to it, the project's design notes, and the reference cited when the comment calls it into question, in the PDF itself as `rules/pdf.md` prescribes.
2. **Proposition.** A reply to the reviewer, written in their tone: short and informal if theirs is, and matching their form of address (in French, tutoiement for tutoiement). It states what will be done, not how.
3. **The decision question**: approve the proposal, as it stands or amended, skip the point, or defer it.

When a comment admits two readings that lead to different replies, set both out, one proposal per reading, and ask the user which reading holds.

The entry is written only once the decision is made, in the same response as the next turn or on its own: reformulation, proposal and decision, including for a skipped point, whose substance stays useful.
Decision vocabulary, carried by the entry's `**Décision** :` line: « proposition validée », whether the proposal was kept as it stood or amended, « sauté en revue », noting what the user will handle themselves when they say so, « reporté », with the place the task is recorded in.

A deferral that calls for work of its own, a reference search for instance, is recorded as a specification in the design note of the chantier it belongs to, the one the project's `CLAUDE.md` or its plan's table names: what is already covered and verified, the questions to investigate, the bounds.

## Verification

- A reference number the reviewer cites is read off the bibliography of the reviewed output, never off the source: the numbering order is the output's.
- The author of a change, highlights included, is read from the XML, `w:rPrChange`, `w:ins` or `w:del` and their `w:author` attribute, never inferred from an absence in the source.
- A number the comment calls into question is checked against the reference, and the check is stated in the reformulation.
- What the reviewed output does not show is checked too: an element present in the source but missing from the docx often explains a comment.

## Writing traps

The machine's Markdown formatter breaks a « » quotation after sentence-final punctuation and leaves a lone « » » at the head of a line: write the quoted extract with no final period, question mark or colon.
After every write, `rg '^»' <register>` must return zero.

Re-read the entry's region from disk before every `Edit`: the formatter rewrites the file between turns.

## Closing

The user stops wherever they want, and the list does not have to be exhausted.

The tally is counted on the register rather than from memory, with `rg` over the decision lines, on the wording they carry: « proposition validée », « sauté en revue », « reporté », « écartée au tri », and what is still « à prendre ».
The machine's prose linter is run over the register.
The tally goes into the tracking files the project's `CLAUDE.md` names, along with the open points: decisions still to carry into the source, deferrals recorded, points skipped.

## What the pass does not do

No editing of the authored source.
No handling of tracked changes unless asked for.
No entry deleted and none renumbered.
No proposal written before reading what it commits to, and no proposals drafted ahead for several points.
No entry written before its decision.

## What "done" means

- The skeleton comes from the script, its summary is reported to the user, and the extracts not found or ambiguous are settled.
- The linked comments are recorded before the triage.
- Every entry carries a decision or stays explicitly « à prendre » because the user stopped.
- No entry is deleted, and the numbering is the one from stage 1.
- `rg '^»'` returns zero and the prose linter passes.
- The tally is counted on the file and recorded in the project's tracking files.

## Maintaining the script

Any change to `scripts/skeleton.py` re-runs its tests, which build their own docx files and depend on no binary file:

```
uv run --no-project --with pytest pytest ~/.claude/skills/review-comments/scripts/test_skeleton.py
```

A defect observed on a real docx is reproduced there first with a minimal docx, before the fix.
