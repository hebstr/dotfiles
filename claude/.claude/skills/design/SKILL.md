---
name: design
description: Use when the user types `/design <suggestion>` to settle how to implement a suggestion before any code is written. Implementation design, not visual or UI design.
disable-model-invocation: true
---

# Designing how to implement a suggestion

This skill takes an implementation idea, rough or fully formed, and turns it into a decision weighed against the alternatives.
The suggestion is the one passed with the invocation or, failing that, the one just raised in the conversation; restating it in step 1 exposes a wrong pick before it costs anything.
Write no code and create no file except the note. Stop at the user's approval.

Conduct the conversation in the user's language, whatever the language of this text.
Two kinds of case skip the full design: three exits, detected on entry before step 1, and three shortened answers, detected at steps 1, 2 and 3. Read "When the full design does not apply" before starting.

## 1. Restate the request

Restate the request in a few lines, in your own words: echoing its wording proves nothing, while rephrasing it exposes any misunderstanding.

Then name what the request leaves open, and sort each open point into one of two treatments.
An ambiguity is blocking when two readings would lead to different work: ask the question, and propose nothing until it is answered.
Everything else goes ahead on an explicit assumption, stated as one.
An open point that a file read or a read-only command can settle is not an assumption: settle it in step 2, and give the answer in the proposal.

A request can leave nothing open; when it does, say so rather than inventing an ambiguity to fill the section.

## 2. Read before proposing

"Idiomatic" only means something against a reference point, and the reference point is this repository, not general taste.

Before opening any approach, read the files the suggestion touches and look for precedent: how something comparable is already done here.
Check at the same time whether the capability already exists, as an internal helper or as a function of a dependency already declared. Finding nothing on disk settles nothing: it shows the capability is absent from the current dependencies, never from the ecosystem.

When the repository has no precedent for this kind of artifact, the convention most likely lives in a sibling project rather than nowhere: say so, name the candidate you found or ask which project to follow, and do not invent a local one.

Also read in full the notes of the workstream at hand (its `PLAN*.md` plan file, its `.claude/DESIGN-*.md` or `_meta/notes/` notes) and its plan entry: earlier decisions are not recorded in the scripts, and step 5 needs them to tell whether this decision overturns one.

## 3. Open several approaches

Offer two to four, without treating the number as a quota: if only one holds up, say so and say what disqualifies the others.

Two approaches are distinct when the responsibility sits in a different place. A different name, an extra argument, a flag: those are variants, and two variants of one mechanism count as a single approach.

"Do nothing" is a legitimate approach whenever an existing mechanism already covers the need, and in that case it wins by default. A feature with no consumer is dead metadata.

Each approach states three things and nothing more: its mechanism in two sentences, its cost (a dependency, a coupling, a maintenance burden, one more file the reader has to know about), and what it forecloses later.

## 4. Make the call

Give one recommendation, never an open-ended list.

Judge what is idiomatic in this order: consistent with a precedent in this repository; failing that, with the idiom of the stack; failing that, with the idiom of the dominant library in the domain.
Cite the precedent by name, as file plus object or file plus section, instead of merely claiming the property.

When the recommended approach is not the most robust one, say what it trades away and for what.
Finally, name the weakest assumption it rests on: "this holds as long as X; if X fails, Y".
When a test without side effects can check it (a read-only command, a trial in the scratchpad), run it before recommending and report the result; otherwise declare it untested. Ask before running a probe with side effects, such as starting a process or touching a remote machine.

Never pick an approach that adds a dependency on your own: propose it, costed as one more dependency, next to the alternative that avoids it.

## 5. Write a note, or not

Write the note only after the user approves, never before.

Write one when at least one of three conditions holds: the decision constrains later sessions, it overturns an earlier decision, or anyone who missed this conversation would propose the rejected approaches again.
Say in one line which condition holds; if none does, the decision stays in the conversation, and say that too, with the reason, instead of leaving it unsaid.

Location: the workstream's existing note when there is one, `.claude/DESIGN-<TOPIC>.md` when nothing covers the subject.
Write the note in English.

The note holds the decision first, then the reason, the rejected approaches each with what disqualified it, and the open points marked as open, none decided by default.
Section headings make a claim rather than label a topic.
Cite code and prose by name, never by line number, per the "Cite by name" rule of the global `CLAUDE.md`.
Use absolute dates.

## Stop

No code, no scaffolding, no pseudo-code, no file other than the note: the design produces none of these, before approval or after. The throwaway trial of step 4 stays in the scratchpad, which does not count as a project file.
Approval must be explicit: silence does not count, and neither does agreement on a detail.
The question that asks for it names the approach and lists separately each decision the proposal bundles, so that a yes covers only what it names.
Approval triggers the note when step 5 calls for one, and ends the design there. Implementation needs a fresh instruction, and from then on the global baseline governs it.
The closing reply ends on the recommended next step, implementing now or in a new conversation, and the user's agreement to that step is the fresh instruction.

A refusal sends you back to step 4 with the approaches already on the table. If all of them are refused, reopen step 3 and use the refusals as input: what they rule out bounds the new approaches. Redo steps 1 and 2 only if the request itself has changed.

## When the full design does not apply

The design weighs several ways of implementing a suggestion. A request that calls for no such weighing exits before step 1, and one that barely calls for it gets a shortened answer.

### Exit before step 1

Three cases, detected on entry from the invocation, the conversation and a targeted grep for the subject in the project's `.claude/*.md` files and `_meta/notes/`:

- the decision already exists, in a note, a plan entry or earlier in the conversation: cite it by name and ask whether the invocation reopens it. If the user confirms, run the full design, and step 5 then keeps the note because the decision overturns an earlier one;
- no suggestion can be drawn from the invocation or the conversation: ask which one to design, without making one up;
- the request is not about choosing between ways of implementing something, for example a bug to fix, a request for an explanation, a recommendation that depends on external sources (`/workflow:reco`) or data analysis work: say why in one line, name what fits better, and stop.

An exit flags the case and hands control back without refusing: the user invoked the design on purpose, and if they confirm, it runs as is.
A subject that no note names slips past the grep; an earlier decision then only surfaces in step 2, which treats it as input to the design.

### Shorten

Cut the answer down to one paragraph, a recommendation and its single risk, in three cases: the request is a fix or an edit the user has scoped themselves; step 2 shows the capability already exists and fully covers the need, in which case the answer is "already covered, close it", a legitimate outcome in itself (partial coverage calls for the full design instead, where "do nothing" competes with the approaches that would do better); only one approach holds up and it costs next to nothing.

Say that the answer is shortened, and why.

## What comes before

`ouroboros:interview` comes first, under the criteria of the global baseline. Those criteria can be met at any step; when they are, suspend the design and resume it on the answer: met at step 1 this costs nothing, met later it means rerunning the steps the answer invalidates.
Then, when the request spans several interlocking workstreams, the breakdown into features ordered by dependency.
Both feed the design: running them after it means redoing it.

## What comes after, and is not this skill's job

The language's lint, format and test gate, the post-change consistency greps and the adversarial review proposal belong to the global baseline and apply to the implementation, once the decision is approved. Do not restate them here.
The plan entry recording the approved decision belongs to the same baseline: the "no file other than the note" rule bounds the design, it does not suspend plan upkeep.

## What "done" means

For a full design:

- The restatement names at least one open point in the request, or states that it leaves none.
- The files the suggestion touches have been read, and the local precedent is named or its absence stated.
- Each approach gives its mechanism in two sentences, its cost and what it forecloses later.
- There is a single recommendation, and it names the reference point reached in the cascade: a repository precedent cited by name, failing that the stack idiom, failing that the dominant library.
- The weakest assumption of the chosen approach is stated, and either tested or declared untested.
- The choice to write a note or not is justified in one line.
- No file other than the note has been touched.

For a shortened answer: the reason for shortening is given, along with the recommendation and its single risk.

For an exit: the case is named, the existing decision is cited by name when it is the reason for the exit, and no design step has been started.
