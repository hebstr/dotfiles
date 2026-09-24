---
name: design
description: Use when the user types `/design <suggestion>` to settle how to implement a suggestion before any code is written. Implementation design, not visual or UI design.
disable-model-invocation: true
---

# Designing an implementation suggestion

The invocation receives an implementation idea, more or less formed, and returns a settled decision.
The suggestion is the one the invocation carries; failing that, the one the conversation has just raised, and the restatement of step 1 exposes a wrong pick before it costs anything.
It writes no code and creates no file other than the note. It stops at the user's approval.

Conduct the conversation in the user's language, whatever the language of this text.
Two families of cases set the full design aside: three exits observed on entry, before step 1, and three shortened answers observed at steps 1, 2 and 3. Read "When the full design does not apply" before starting.

## 1. Restate

Restate the request in a few lines, in words other than its own: repeating its wording proves nothing, restating it exposes what was misunderstood.

Then name what the request leaves undetermined, and for each point, choose between two treatments.
An ambiguity is blocking when two readings lead to different work: there, ask the question and propose nothing before the answer.
Everything else proceeds under an explicit hypothesis, stated as such.
An unknown that a read or a read-only command settles is not a hypothesis: step 2 settles it, and the proposal gives the answer.

A request that leaves nothing undetermined exists; say so then, rather than inventing an ambiguity to fill the heading.

## 2. Read before proposing

The idiomaticity criterion only means something relative to a referent, and the referent is the repository, not general taste.

Before opening any approach: read the files the suggestion touches, and look for the precedent, that is, the way a comparable thing is already done here.
Check along the way whether the capability already exists, as an internal helper or as a function of a dependency already declared. Finding nothing on disk closes nothing: it establishes absence from the current dependencies, never from the ecosystem.

When the repository holds no precedent for this kind of artifact, the convention is probably established in a sibling project rather than absent: say so, name the candidate found or ask which one to take as a model, and do not invent one locally.

Also read, in full, the notes of the workstream concerned (its plan file `PLAN*.md`, its `.claude/DESIGN-*.md` or `_meta/notes/` notes) and the matching plan entry: a prior decision does not live in the scripts, and it is the one step 5 asks to record as overturned.

## 3. Open several approaches

Two to four, without the number acting as a quota: if only one holds, say so and say what rules out the others.

Two approaches are distinct when the responsibility lives in a different place. A name that changes, one more argument, a flag: that is a variant, and two variants of the same mechanism count as one approach.

"Do nothing" is an approach in its own right as soon as a mechanism already in place covers the need, and it wins by default when that is the case. A feature with no consumer is dead metadata.

Each approach carries three things and no more: the mechanism in two sentences, what it costs (a dependency, a coupling, a maintenance load, one more file the reader has to know), and what it rules out later.

## 4. Decide

One recommendation, never a list left open.

Idiomatic reads in this order: consistent with a precedent of this repository, failing that with the idiom of the stack, failing that with that of the dominant library of the domain.
Cite the precedent by its name, file plus object or file plus section, rather than asserting the property.

When the recommended approach is not the most robust, say what it trades for what.
Finally, name the most fragile hypothesis it rests on: "this holds as long as X; if X falls, Y".
When a side-effect-free test checks it (a read-only command, a trial in the scratchpad), run it before recommending and give its result; otherwise declare it untested. A probe with side effects, a launched process or a remote machine, is asked for first.

An approach that requires a new dependency is not chosen alone: it is proposed, costed at one more dependency, with the alternative without it beside it.

## 5. The note, or not

The note is written after the user's approval, never before.

Write a note when at least one of these three conditions holds: the decision constrains later sessions, it overturns a prior decision, or the rejected approaches would be proposed again by anyone who was not in this conversation.
Say in one line which one holds; otherwise the decision stays in the conversation, and say that too, with the reason, rather than passing over it.

Location: the workstream's note when one exists, `.claude/DESIGN-<TOPIC>.md` when nothing covers the subject.
The note is written in English.

What the note carries: the decision first, the reason, the rejected approaches with what rules out each, and the points left open named as open, none settled by default.
Section headings assert instead of labeling.
Code and prose are cited by name, never by line number, per the "Cite by name" rule of the global `CLAUDE.md`.
Dates are absolute.

## Stop

No code, no scaffolding, no pseudo-code, no file other than the note: the design produces none of these, before approval or after. The throwaway trial of step 4 stays in the scratchpad, which does not count as a project file.
Approval is explicit: neither silence nor agreement on a point of detail constitutes it.
The question that asks for it names the approach, and separates every decision the proposal bundles, so that an agreement covers only what it names.
Approval triggers writing the note when step 5 retains one, and closes the design there. Implementation requires a new instruction, and falls under the global baseline from then on.
The closing reply ends on the recommended next step, implement now or in a new conversation, and agreement to that step is the new instruction.

A refusal reopens step 4 on the approaches already opened. When they are all refused, step 3 reopens and the refusals become its material: what they rule out bounds the new approaches. Steps 1 and 2 are redone only if the request itself has changed.

## When the full design does not apply

The design arbitrates between several ways of implementing a suggestion. What does not call for that arbitration exits before step 1, and what barely calls for it receives a shortened answer.

### Exit before step 1

Three cases, observed on entry from the invocation, the conversation and a targeted grep of the subject in the project's `.claude/*.md` files and `_meta/notes/`:

- the decision already exists, in a note, a plan entry or earlier in the conversation: cite it by name and ask whether the invocation reopens it. A confirmed reopening starts the full design, and step 5 then retains the note on the ground of the overturned decision;
- no suggestion emerges, neither from the invocation nor from the conversation: ask which one to design, without constructing one;
- the request belongs to something other than an implementation decision, for example a bug to fix, a question of explanation, a recommendation that rests on external sources (`/workflow:reco`) or data analysis work: say why in one line, name what fits, and stop.

An exit signals and hands back without refusing: the user invoked the design deliberately, and their confirmation starts it as is.
A subject whose name no note carries escapes the grep; the prior decision is then discovered only at step 2, which treats it as material for the design.

### Shorten

Reduce the answer to one paragraph, a recommendation and a single risk, in three cases: the request is a fix or an edit the user scoped themselves; step 2 shows that the capability already exists and covers the need entirely, and the answer is then "already covered, close it", an outcome in its own right, whereas a partial coverage calls for the full design, where "do nothing" competes with the approaches that would do better; only one approach holds and its cost is negligible.

Say that the answer is shortened, and why.

## What comes before

`ouroboros:interview` first, on the criteria of the global baseline. Resistance can be observed at any step and suspends the design, which resumes on the answer: observed at step 1 it costs nothing, later the resumption restarts the steps the answer invalidates.
Then the decomposition into features ordered by dependencies, when the request covers several interlocking workstreams.
These two steps feed the design: running them after it forces redoing it.

## What comes after, and that this design does not do

The language's lint, format and test gate, the post-change consistency greps and the adversarial review proposal belong to the global baseline and apply to the implementation, once the decision is approved. Do not restate them here.
The plan entry recording the approved decision belongs to the same baseline: the "no file other than the note" criterion bounds the design, it does not suspend plan upkeep.

## What "done" means

For a full design:

- The restatement names at least one unknown of the request, or declares that it leaves none.
- The files the suggestion touches have been read, and the local precedent is named or its absence declared.
- Each approach carries its mechanism in two sentences, its cost and what it rules out later.
- The recommendation is unique and names the referent reached in the cascade: a repository precedent cited by name, failing that the stack idiom, failing that the dominant library.
- The most fragile hypothesis of the chosen approach is stated, and tested or declared untested.
- The decision to write a note or not is justified in one line.
- No file other than the note has been touched.

For a shortened answer: the reason for shortening is stated, and so are the recommendation and its single risk.

For an exit: the case is named, the existing decision is cited by name when it motivates the exit, and no step of the design has been started.
