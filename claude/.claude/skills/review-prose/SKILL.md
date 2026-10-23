---
name: review-prose
description: Use when the user types `/review-prose <docx>` to carry the direct text edits a reviewer made on a rendered `.docx` back into the authored source.
disable-model-invocation: true
---

# Carrying a reviewer's text edits back into the authored source

Conduct the conversation in the user's language, whatever the language of this text.

The invocation receives a `.docx` a third party has edited with track changes on, and returns the authored source with those edits applied.
The edited source is the whole deliverable: nothing else is created, and `git diff` on the source is the record of the pass.

This is the sibling of `/review-comments`, which works through the comments a reviewer left and states that "The authored source is not edited during the pass".
That invariant is inverted here, and the two passes stay separate: comments belong to `/review-comments`, direct text edits to this one.

## Unit and scope

The unit is the reviewer's intent, never the word-level site: four verbs that one paragraph moves to the past tense are one intent.
One `Edit` per intent, in document order, split into two calls only when two sites inside the same paragraph are two distinct intents.

Tracked insertions and deletions of text are in scope.
Comments are out of scope and go to `/review-comments`; cite one when it explains an edit, never as a point of its own.
Formatting-only revisions are out of reach for the reason given in stage 1.

With no docx, ask for one.
The authored source is the one the docx was rendered from, named by the project's `CLAUDE.md` or by the user; with no source, ask for it rather than editing the nearest candidate.
The reader facts this pass stands on live in `rules/docx.md`, which is injected on any `.docx` touch: read them there instead of restating them.
What goes into the project's tracking files at closing follows the language of the project's notes.

## Stage 1, the opening count

The pass opens by counting the tracked runs and their authors off the XML, and reports both before the first edit, so the route's blind spots are known before anything is applied.

```
unzip -p <docx> word/document.xml | rg -o '<w:(ins|del|rPrChange) ' | sort | uniq -c
unzip -p <docx> word/document.xml | rg -o 'w:author="[^"]+"' | sort | uniq -c
```

Each counted revision element carries one `w:author`, so the two tallies sum to the same number when insertions, deletions and formatting changes are all there is.
A larger author tally names a revision kind the first command does not count, a moved range or a table-cell revision for instance: say which, rather than reporting a clean count.
Revision dates read off `w:date` the same way.

Three facts are stated at the opening rather than left to imply completeness.

- **The route is blind to formatting-only revisions by construction.** A `w:rPrChange` produces zero diff lines, so the count is the only place it is ever seen.
- **An untracked overwrite is invisible for the same structural reason.** Accepting and rejecting agree on any text no revision mark covers, so a reviewer who typed over a sentence with tracking off leaves nothing for stage 2 to find.
- **The weakest assumption is that the reviewer turned track changes on.** Zero tracked runs means the pass has only the fallback below.

When the author tally shows more than one reviewer, say so and ask the user how to treat them.
The text diff of stage 2 cannot attribute at all, the per-run `w:author` read is the only channel, and no filtering rule is prescribed.

## Stage 2, the two conversions and the diff

Two conversions of the one reviewed file are the whole input, and both go into the scratchpad.

```
pandoc --track-changes=reject -t markdown --wrap=none <docx> -o rej.md
pandoc --track-changes=accept -t markdown --wrap=none <docx> -o acc.md
diff rej.md acc.md
```

No render is needed and nothing has to be sorted: the only differences are the reviewer's.
`diff` must report zero added and zero removed lines, which is what makes line-pair alignment safe.
An added or a removed line means an inserted or deleted paragraph broke the pairing: report it and handle that paragraph on its own text rather than by its line pair.

The word-level sites inside the changed paragraphs come from one more call:

```
git diff --no-index --word-diff=plain --unified=0 rej.md acc.md
```

Grouping those sites into intents is the judgement this pass contributes, and no tool produces the number: on the artifact the method comes from, 16 sites in 8 paragraphs were 11 intents.
Present the grouping to the user before the first edit.

## Stage 3, the edits

One intent per response, validated by the user before the next.
One sentence of intention before the call, never a prose diff: the permission dialog shows the diff.
Re-read the region from disk before every `Edit` and never compose an `old_string` from memory: the user rewrites the file between turns, often taking up in their own way what was just applied.

The anchor is a search, not the rendered string.

- A citation key comes out of both conversions as a superscripted number, `^1.^` where the source carries `@lucas2022`, and an inline computation renders its value.
- Pick a distinctive substring of the rejected paragraph outside those spans and locate it with `rg -F -n '<span>' <source>`, which returns the hit count and the line in one call.
- One hit is the condition for editing. Several hits: extend the span. Zero hits: the span crosses something the render rewrote, so pick another.
- `review-comments/scripts/skeleton.py` carries a locator behind `--source`, its `locate()` function, and it is not reused: it returns a found, ambiguous or not-found string with no line number, and choosing a span that survives the render is beyond it either way.

A caption edit lands in chunk YAML rather than in prose.
A table caption reaches the diff as a row of the pipe table, while its target in the source is a `#| tbl-cap:` option; `#| fig-cap:` takes the same treatment.
Chunk YAML is therefore searched alongside prose.

Two residue classes are surfaced, never fixed silently, and handling them is what makes the pass worth more than a mechanical application.

- **A reviewer edit that is itself wrong** is applied in its corrected form, with the reviewer's intent kept and the correction stated to the user. A reviewer's `ne peut pas s'expliquée seulement` was applied as `s'expliquer`, keeping the restriction they had added.
- **A reviewer edit left half done** is applied exactly as left and flagged as the user's arbitrage, never harmonised. Four verbs of one paragraph moved to the past while `comptent` stayed in the present, which is a question for the user and not a fifth edit.

## When the diff is empty

One fallback is documented and its steps are not: diffing the reviewed docx against a later render of the same document.
It converges on the same edits and imports every edit the user made between the two renders as noise, a reformatted bibliography, renumbered tables, bumped dependency versions and a rewritten section, all to be sorted by hand.
It has been improvised once and never run as a procedure.
Report the empty diff with that cost and let the user decide, rather than opening it silently.

## Verification

- The anchor's hit count is 1 before the `Edit`, read off `rg -F -n` in the same turn and never assumed from the paragraph looking distinctive.
- A value the source computes is never edited to match the rendered text: the source carries the expression, the docx its result. An edit landing on such a span is reported to the user instead of applied.
- The author of a change is read from the XML, as `rules/docx.md` prescribes, never inferred from an absence in the source.
- An intent counts as applied once its region has been re-read from disk after the `Edit`.
- The applied set is checked intent by intent against the word diff at closing, counted on `git diff` of the source rather than from memory.

## Closing

The user stops wherever they want, and the list does not have to be exhausted.

The record is `git diff` on the source, and no register is written: an applied edit owes nothing to anyone and is readable there.
Four things go into the tracking files the project's `CLAUDE.md` names, in the same response: the edits applied, the reviewer errors corrected, the half-done edits left as open arbitrages for the user, and the intents not reached.
Then re-check each of those claims against the file and the commands.

## What the pass does not do

No comment handled, and no reply drafted to one.
No register file, no inventory script, no file created at all beyond the two scratchpad conversions.
No formatting-only revision applied, the route being blind to it.
No reviewer edit harmonised, and no correction made silently.
No render, and no diff against a later render unless the user chooses that fallback.
No edit in the response that proposes it.
No writing into the user's personal working files.

## What "done" means

- The opening count is reported with its three blind spots, and a second author is raised with the user.
- `diff` shows zero added and zero removed lines, or the broken pairing is reported.
- The site-to-intent grouping was presented before the first edit.
- Every intent is either applied or explicitly left to the user, in document order, one per validated response.
- Every edit was anchored on a span whose `rg -F` hit count was 1, and its region re-read after the call.
- The corrected reviewer errors and the open arbitrages are stated to the user and written into the project's tracking files.
