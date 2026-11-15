---
name: relire
description: Assisted proofreading of a written document, section by section and point by point, invoked as `/relire <section>`.
disable-model-invocation: true
---

# Assisted proofreading of a section

Conduct the conversation in the user's language, whatever the language of this text.

## Unit and scope

The document is the one the invocation names; by default, the project's written document, which its `CLAUDE.md` designates.
The unit is the second-level section, or the subsection when the section runs past about thirty source lines.
The deepest heading the document has is the floor: below it the unit stays whole however long it is, and the survey states its bounds as it opens.
Never a single sentence, never the whole document.

A title passed as an argument that matches several sections of the document is resolved with the user before the survey, never by picking a level or the first match.

Before the survey, read the whole section from disk, plus what it depends on: the document upstream of it, the project plan, the design notes of the workstreams the section engages and that the plan's table names, and the downstream text when a move is under consideration.
Downstream text is read to learn where a moved statement would land and whether it would duplicate something there, never as validated text.

## Step 1: the survey

A reply that contains no edit.

A numbered list, one point per issue: where it is, what it is, what it costs the reader.
Ordered from substance to form: contradictions and statements nobody uses first, repetitions and punctuation after.
Each point is classified before it is presented: defect (a contradiction, a term used before it is introduced, an unsourced claim, a breach of a recorded decision) or preference.
Only defects are proposed for application; preferences take one line at the end of the survey and do not justify another pass.
The survey closes with a recommended order of treatment and with the substantive questions that need the user's answer before any edit.

A point whose fix depends on an unknown fact is a question, not a proposal.

Before any edit, take an inventory of the inline expressions of the computation engine that the section carries, from the working tree and never from the last commit, which lags as soon as a round goes uncommitted.

## Step 2: the edits

One point per reply, validated by the user before the next, with as few `Edit` calls as the point requires: usually one, two when it touches two sites.
A sentence of intent before the call, never a prose diff: the permission prompt shows the diff.

The user rewrites the file between rounds, often rephrasing what was just applied.
Reread the area on disk before every edit, never compose an `old_string` from memory, and do not re-propose what the user has just reworded their own way.

Moving a statement from one section to another is atomic: removal and arrival in the same reply, otherwise the argument disappears without landing.

## Criteria

The project's own criteria live in its `CLAUDE.md` and design notes: read them at invocation and do not copy them here, since duplication creates a second source of truth that drifts.

On top of them come the proofreading criteria that hold for any written document.

- What a section describes and what justifies it do not mix: a justifying sentence sitting in a descriptive section is moved, not deleted.
- A contradiction between two passages is a substantive defect even when each passage stands on its own: report it with both locations.
- A term used without having been introduced is a defect, including when it comes from a design note where it goes without saying.
- A clause that no measurement and no section uses is a leftover from an earlier state: propose removing it.
- A repetition whose second occurrence lives outside the unit cannot be settled from inside the unit: raise it as a question with both locations, and settle it in the round that reaches the second occurrence.
- A sentence that announces what the next one will say, a connective that sets up an opposition that does not exist, an anaphora that reaches back over a paragraph boundary, a term repeated within one paragraph.

## Verification

No fact is asserted without having been checked in the same round: a search of the repository, a reading of the relevant script or declaration file, a web search for an external fact.
A value the document publishes is read from the rendered output and never from the source, which holds the expression and not its result; when that output is missing or stale, the value is a question, not an assertion.
When verification is impossible, say so and ask the question rather than write a plausible wording.

## Step 3: closing the section

The project's prose linter must exit 0.
Compare the inline expressions of the computation engine with the inventory taken in Step 1, character for character: identical, except for a difference announced and justified in the round.
A count is not enough, since a rename at constant count passes it.
Rerun the render only if an expression, a script or a cross-reference moved; a prose-only pass does not call for it.

Run the consistency greps when a heading, an object or a path changed, and check that no cross-reference breaks.

A check that fails leaves the section open: its cause comes back as a Step 1 point, and the plan entry says so instead of announcing a closure.

Each section carries its closure criterion in the design note of its workstream: a finite number of conditions, each checkable by a command or a named reading, and a reopening clause.
Read it at the opening; if it is missing, propose one in the survey rather than surveying without end.
The section is closed when its conditions hold, and a new pass opens only on a new fact that the clause names (a source added, a result measured, an upstream change that contradicts the section, a decision by the user): a new reading is not one.
A condition that needs a human reader, legibility for a non-specialist for instance, is closed by that reading and not by one more pass.

The user stops wherever they want, and the list does not have to be exhausted.
Write the entry in the project plan in the same reply: the points applied, those still open, and any statement moved to another document, since otherwise the update of that document is lost.
Then re-verify each of its claims against the file and against commands: the counts, the titles, the objects cited by name.

## What the pass does not do

No verdict per sentence, no grid to fill in, no log per verdict: ceremony scales with the defects found, not with the length of the text.

No edit in the reply that proposes.

No survey of a section with no written content: say so, and propose writing the substance rather than judging a heading.

No writing to the user's personal working files, which are read and quoted but do not belong to the pass.
