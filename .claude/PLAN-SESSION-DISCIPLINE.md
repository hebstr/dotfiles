# PLAN-SESSION-DISCIPLINE.md

Chantier note: the discipline of updating the tracking, the stability of recommendations, session closure.
Opened by `/cadrer` on 2026-09-22.
On 2026-10-15 the commit-guard core (write journal, stamp, gate, `PreToolUse` guard, the `commit` skill and its verifier) moved out into `.claude/DESIGN-COMMIT-GUARD.md`; what stays here is the measurement campaign, the two hooks that carry Communication rules (`ending-gate.sh`, `reco-relance.sh`, with `closure-check.sh`) and the pruning.

**Status (2026-10-08).
Steps 1 to 3 done. **Step 4 (the remeasure): its window stops being a condition, decided by the user on 2026-10-08 on a measurement.** The covered paths took 57 commits since 2026-09-24 and the longest silence observed on them is 1.97 days, where the comparable pass needs seven (`git log --since=2026-09-24` over the step 4 list, "Preflight of 2026-09-28"): the remeasure therefore demands a deliberate freeze of the harness rather than a wait, the harness being under constant development. It becomes opportunistic, to be run if a seven-day freeze presents itself, its scripts staying archived in `_meta/session-discipline/` and its counting replayable identically; it no longer freezes anything and a commit that moves the start has no effect any more. Last start observed before the lifting: `ff6aa2f` of 2026-10-08 at 21:59:10 +0200.
A file of `rules/` counts as a covered mechanism on the same footing as a hook, the list naming "the global `CLAUDE.md` and its `rules/`" and the precedent being `472b09d`, which moved the start for `rules/chromium.md`; an exemption is written explicitly, like that of `.gitignore` at `3788eff`.
What remains to be done lives in "Open points" and in the sections its bullets name, the only authoritative copy; the narrative of the substeps and their shas is in `git log`.**

## Objective

Remove the relances the user makes at almost every session ("tout est update ?", "vérifie le tracking avant de proposer un commit", "que recommandes-tu vraiment ?", "je peux clore ici ?") by making the corresponding discipline reliable without the user.

Three axes, set by the user:

1. Tracking verification precedes every commit proposal: a sweep of the repository and an update if needed, never a commit proposed without it.
2. Every recommendation is tested before being issued, during the session as at its end: it holds at the relance or it is revised beforehand.
   Adversarial review proposals (`/audit:walkthrough`, `/audit:blindspot`) obey the same discipline and stop being a systematic reflex.
3. A session always closes in this order: tracking recorded and up to date, then a recommendation on what comes next or the explicit indication to close, then, when that indication is to close, the certification of the closure and its branch, then the commit proposal, which marks the closure.
   The third element was added on 2026-11-08 by `.claude/DESIGN-HANDOFF.md`, which carries why it sits before the commit rather than after it.

Two further strands attach to it: a methodical cleanup of the conventions that have become useless or counterproductive, and the articulation with `/workflow:sync`, which the user runs themselves in a fresh conversation after each session.

## Success criteria

- The user no longer has to ask the verification or closure questions; measurable by the same count as the baseline below, replayed once the mechanism is in place.
- A recommendation asked again with no new information is maintained.
- The adversarial reviews proposed are the ones the user runs, and the post-session `/workflow:sync` no longer finds anything stale in the tracking files, or becomes useless.

## Framing assumptions

- Global scope: `~/.claude/CLAUDE.md`, `rules/`, memory, the skills and hooks of the dotfiles' `claude` package, plus the `~/Documents/packages/skills` repository where `workflow/sync` lives (`workflow/continue`, cited when the chantier opened, was deleted on 2026-09-30).
  The chantier therefore touches two repositories.
- "End of session" means every task of the session done, the session being closable, rather than the end of each task (made precise by the user on 2026-09-23, replacing "end of the current task or a signal from the user").
  Associated preference: short, targeted sessions rather than one session chaining everything; the continuation of a closed session therefore leaves in a fresh conversation.
  With no file modified, no commit proposal, but the closing recommendation is still owed.
- "Recommendation" covers the choices that commit to something, not trivial yes/no confirmations.
- Cleaning up the conventions is part of the chantier and gains from coming early: the size of `CLAUDE.md` is a suspect in the non-compliance.
  It rests on evidence (rules never triggered, rules violated continuously), not on taste.

## What reading the repository establishes

- **The rules exist and do not hold.** `CLAUDE.md` already carries "update all affected tracking files... Never wait for the user to ask", "A tracking-file write is not done when it lands, only when its claims are re-derived", and the objective reevaluation before any recommendation.
  Adding text changes nothing: the question is the mechanism that makes them hold.
- **The strong lever is executable.** `.claude/ANTI-SYCOPHANCY-PLAN.md`, section "0. Anchoring on executable truth": an instruction is the weakest lever.
  No hook carries the closure discipline at that point: the only `Stop` hook of `~/.claude/settings.json` moves an ouroboros artefact, removed on 2026-10-08 with the plugin, the two gates this plan delivered holding the place since.
- **Axis 1 collides with the "fresh context" axis.** Verifying inside the build conversation is the self-critique that this same note and `CLAUDE.md` (Build discipline, a review "always in a fresh conversation") declare bound to fail; this is why `/workflow:sync` in a fresh conversation works better.
- **Blind spot of `/workflow:sync`.** Its scope is "relative to uncommitted changes": when `.claude/` is gitignored, as here and in `md-nesrine`, stale tracking files are invisible to it.
  Two runs out of 35 stopped for that reason (sessions `d00bc83b`, `47cb13d4`).

## Measured baseline (transcripts, 2026-09-22)

Two subagents, lexical analysis of the transcripts `~/.claude/projects/*/*.jsonl`.
Actual window: 161 transcripts, messages from 2026-09-15 to 2026-09-22, so 8 days and not 90: `cleanupPeriodDays` is `7` in `~/.claude/settings.json`.
Scripts in the session scratchpad (`load.py`, `an.py`, `q2.py`, `q3.py`, `q3b.py`, `a2.py`, `a4.py`, `b2.py`), which does not survive the session.

### Tracking and closure

```
| Measure | Value |
|---|---|
| Sessions >= 5 turns with a tracking or closure relance | 64/79 (81 %) |
| of which tracking relance / closure relance | 58/79 / 34/79 |
| Tracking relances in total, closure relances in total | 100 / 40 |
| Tracking relance followed by an admission or a tracking edit | 80/100 (cautious bound 62) |
| Plain "oui" answer with no edit | 21/100 |
| Commit proposals (git commit -m) | 111, over 34 sessions |
| of which followed by a tracking relance | 34/111 (31 %), 14 contesting explicitly |
| /workflow:sync runs, of which at the opening of a fresh session | 35, 32 |
| syncs that corrected at least one file | 29/35, 134 files in all |
```

A notable finding: 81 of the 111 commit proposals followed a read or a write of tracking in the same turn, and they carry 31 of the 34 contestations.
Touching a tracking file is not verification.

### Recommendations and adversarial reviews

```
| Measure | Value |
|---|---|
| Classifiable "que recommandes-tu" relances | 45 |
| Maintained / qualified / reversed | 20 (44 %) / 12 (27 %) / 13 (29 %) |
| Sessions mentioning /audit:walkthrough or /audit:blindspot | 93/161 |
| (type, target) pairs proposed / run | ~70 / ~17 (~24 %) |
| blindspot on memory files proposed / run | 16 / 0 |
| walkthrough on code proposed / run | ~40 / ~14 |
| Proposals contested: maintained / modified / abandoned | 8 / 4 / 3 |
| Findings accepted in the audits run | ~125/222 (~56 %) |
```

Several reversals follow a verification made only at the relance (a test, a measurement): the first recommendation had been issued without it.
Untested assumption: the reevaluation rule of `CLAUDE.md` pushes toward revising at every relance, which looks like complaisance toward the relance rather than an instability of its own.
The reviews run on code pay off (walkthrough `llama-session` 7/10 including 2 Blocking, `win-config` 8/11); those on the updaters (`sys-update`, `rig-update`, `syncthing-update` 1/7) and on `CLAUDE.md` (blindspot 17/53) pay off little.
The defect is the targeting, not the value.

### Limits of the measurement

Lexical patterns (atypical wordings missed), reversals classified by a single reader on truncated excerpts, proposal/run matching by the target's basename, acceptance rates judged by the audit session itself, an 8-day window centred on tooling work.

## Sequence chosen (decision of 2026-09-22)

Decision: `/workflow:reco` then `/cadrer` on its report, with this measured baseline as input to both, because it serves at once as material for the convention cleanup and as the base for judging the effect of the mechanism.

Rejected:

- Chaining `/cadrer` with no research: the user wants the external state of the art, and it is the in-house convention that has to be called into question.
- Reco then cadrer with no measured base: deprives the cleanup of evidence and the chantier of a point of comparison.

Question for `/workflow:reco`:

> A CLI coding agent (Claude Code, September 2026), a single user, markdown tracking files (PLAN, DEFERRED, design notes, memory).
> Which mechanisms reliably enforce, with no relance from the user:
> (a) updating and verifying the tracking before a session closes;
> (b) the stability and the correct calibration of the agent's recommendations (confidence score, verification in a fresh context, jury of judges, and how to tell a genuine revision from complaisance toward the relance);
> (c) targeted rather than systematic adversarial review proposals;
> (d) a standardised session closure: a recommendation or "close", then the commit.
>
> Compare the written instructions with the executable mechanisms (Stop and PreToolUse hooks, verifier subagents, closure skills).
> Say what degrades as the instruction file grows, and how to prune it.
> Include the work of Matt Pocock and his circle if it does not come up on its own.

## Steps

1. `/workflow:reco` in a fresh conversation, on the question above, with this note as context.
   Done on 2026-09-22: `.claude/RECO-SESSION-DISCIPLINE.md`.
2. `/cadrer` in a fresh conversation on the reco report.
   Done on 2026-09-22: section "Framing of step 3".
3. Implementation following the framing, convention cleanup included, in the order of that section's decomposition.
   Done on 2026-09-22: substeps 0 to 6, see "Framing of step 3".
4. Remeasure with the same count, over a comparable window.
   Framed sessions match both `/cadrer` and `/design`, the skill having been renamed on 2026-09-24 (`.claude/DESIGN-CADRER.md`, "The skill becomes `design`, rewritten in English").
   The window opened on 2026-09-24 and its start then moved about twenty times, once per change to a mechanism the measure covers, until it stopped gating on 2026-10-08, as the status block at the top of this file records; the chain of shas is `git log`'s and the sha-by-sha chronicle went with the pass of 2026-10-15.
   What still binds out of it: which paths count, and the precedent both ways, the shell-search point deferred past the window on 2026-09-22 against a start moved about twenty times since 2026-09-24.
   The paths are the hooks `commit-gate.sh`, `ending-gate.sh`, `git-write-guard.sh` with `git-write-guard.jq`, `commit-stale.sh`, `closure-check.sh`, `reco-relance.sh`, `write-journal.sh`, `inject-rules.sh` and `inject-project-context.sh`; the `commit` skill with `agents/verifier.md` and `scripts/`; the global `CLAUDE.md` and its `rules/`; `settings.json`; and the `opencode` `AGENTS.md` mirror.
   Step 4 also measures the recall of `closure-check.sh` the way it measures that of `reco-relance.sh`, its regex having been fitted on the same transcripts it was replayed on.
   The `reco-relance.sh` half of that was done out of window on 2026-09-28 (section "The recommendation reminder fires on a question mark, not on a wording"), so only the `closure-check.sh` half remains for step 4.
   **Preflight of 2026-09-28, 13:26 local: the window has not run, and step 4 is deferred.** `bf02a32` is of the same morning, 09:04:07 +0200, so the window was 4 h 22 min old.
   Counted before any analysis, as the user required: 159 transcripts under `~/.claude/projects/*/*.jsonl`, messages from 2026-09-21T08:01:48Z to 2026-09-28T11:30:54Z, 7 d 3 h of amplitude, 82 sessions of 5 turns or more, against 161 transcripts over 8 days and 79 eligible sessions at the baseline.
   Only 2 sessions had started after the window start, one of them the measuring session, 11 turns between them and 1 reaching 5 turns; 3 sessions had any activity inside it.
   Comparing that to a denominator of 79 would compare unequal durations, which the user ruled out.
   Correction to the framing of that preflight: the first pass's scripts do exist, archived verbatim in `_meta/session-discipline/` (bullet "Measurement scripts"), so nothing had to be rewritten from the tables and no definition could drift.
   `load.py` then `an.py`, rerun on a copy outside the repository, printed 159 sessions and 82 eligible over 2026-09-21 to 2026-09-28.
   The two lexical patterns behind "sessions with a tracking or closure relance" are the regexes named `A` and `B` at the top of `an.py`, unchanged since 2026-09-22.
   That rerun read 62 of those 82 sessions as carrying a relance (76 %, against 64/79 and 81 %), but its span lies almost entirely before the window start, so it measures the construction period and is not the remeasure.
   Three constraints on the pass whenever it runs, none of them dated: `cleanupPeriodDays` at 7 slides the retained set, so a pass taken seven days after the freeze starts has every retained transcript inside the window and an amplitude matching the baseline's 8 calendar dates; the cutoff must then apply to the message timestamp rather than to the date, a date cutoff being unable to split the freeze's own day, which changes the filter of `an.py` alone and no lexical definition; and no mechanism in the path list above may change until it runs.
   The untested hypothesis of the baseline, that the reevaluation rule of `CLAUDE.md` pushes toward revising at every relance, stays open: it needs relances inside the window.

## Framing of step 3 (approved on 2026-09-22)

Decision: the closure discipline goes through an executable commit gate (a write journal, a `Stop` hook of type `command`, a verifier in a fresh subagent launched by `/commit`), and `/commit` becomes invocable by the model.
Reason: the written instructions already exist and fail (31 % of commit proposals contested), and only an executable mechanism changes that rate.

### The review threshold is still to be recalibrated

The threshold of 30 lines added plus deleted that section 0.3 of `commit` applies to executable code is an initial setting, to be recalibrated at step 4.

### Rejected ways

- **The skill alone, without a hook**: one more instruction, where the baseline shows that instructions fail.
- **A `Stop` hook of type `prompt` or `agent`**: one model call per turn, and the `agent` type is experimental.
- **Doing nothing more, `/workflow:sync` run by hand**: that is the relance the first success criterion removes, and the blind spot of `.claude/` stays.
- **A stamp written by a `PostToolUse` on `Agent`**: it would fire when the subagent is launched, which runs in the background, and not when it ends.
- **A review-scope script in the manner of `review-scope.py`**: one more file for a single `numstat` command.
- **The `ce-pov` skill, a confidence score, a jury**: no defined consumer for the first, bad calibration for the second, disproportion for the third.

### Weakest assumption

The mechanism holds as long as a verifier in a fresh context, fed the journal's list, catches what the user catches today (the 34 contestations).
If it does not, the gate becomes a ceremony, and the lever is then its prompt, not the gate.

## Core implementation (step 3, substeps 1 to 4)

Moved out on 2026-10-15 into `.claude/DESIGN-COMMIT-GUARD.md`, which carries the write journal, the stamp and its snapshot, the gate, the `PreToolUse` guard on `Bash` and the `commit` skill with its verifier and its scripts: the decisions, their rejected ways, the limits that still bind and the fourteen walkthroughs.

## Recommendations (substep 5)

The rule lives in two bullets of `claude/.claude/CLAUDE.md`, Communication, "When presenting a choice, end with your own recommendation" and "When the user asks again about a recommendation already given and brings no new fact, keep it", the opencode mirror included under `project_opencode_agents_md_mirror.md`.

### Hook

- The behaviour in force is the one set by "The recommendation reminder fires on a question mark, not on a wording"; `reco-relance.sh` and `_meta/tests/reco-relance.bats` are its record, and the platform facts it exploits are in `reference_claude_code_best_practices.md`.
- Firing measurement of the old regex, on 2026-09-22 over the available transcripts (`~/.claude/projects/*/*.jsonl`, a 7-day window): 54 firings over 494 typed prompts, almost all on "que recommandes tu ?" with no hyphen, the user's dominant form; that is the base step 4 compares against.

### Detection routes rejected, and not revisited by the reassessment of 2026-09-28

The decision of 2026-09-22 ("the detection stays a regex") was reversed on 2026-09-28 by "The recommendation reminder fires on a question mark, not on a wording", which made the whole wording regex disappear.
These routes would be proposed again without this list:

- **A `UserPromptSubmit` hook of type `prompt`**: impossible.
  On that event, `ok: false` blocks the prompt and ends the turn, and a `prompt` hook cannot set an `additionalContext` (`hooks.md` doc, section "Response schema", read on 2026-09-22).
- **A `command` hook that calls a model itself** (`claude -p --model haiku`, or the `llama-server` of `ju-TP2`): 1 to 3 s of waiting and a network dependency on every prompt, with a 30 s ceiling past which the context is lost.
  That is the reason that already ruled out the `Stop` hook of type `prompt`.
- **Firing on state** (injecting after any response that carried a recommendation, by reading `transcript_path`): the transcript format is undocumented, and it is lexical detection on the model's output instead of the user's prompt, which moves the problem rather than solving it.
- **Injecting on every prompt**: about 100 tokens a turn, a reminder that wears out by repetition, and a duplicate of `CLAUDE.md`, already in context.
- **Patterns in a data file**: easier to maintain, with no effect on robustness.

### What the hook targets, and what it does not (2026-09-22)

The relance comes from the user, and the hook only fires after it.
It therefore serves the second success criterion (a recommendation asked again with no new information is maintained), not the first (the user no longer has to ask again).
Two other levers bear on the frequency of relances:

- the verification before the first issuing, which is only an instruction of `CLAUDE.md`: no mechanism enforces it at the moment the recommendation is issued;
- the recommendation on what comes next, rendered as a matter of course by step 0.2 of `/commit`.
  A good share of the "que recommandes tu ?" measured are asks for what comes next ("que recommandes tu de faire ?", "... pour les points restants ?") rather than challenges to a recommendation already given.

Step 4 therefore separates two measurements: the frequency of "que recommandes tu ?" (the effect of the closure) and, among the genuine relances, the share of recommendations maintained against those reversed (the effect of the hook and of the rule), telling asks for what comes next from challenges.

### Limits

- The reminder stays an instruction, placed where it serves: its effect can only be judged at the step 4 remeasure (share of relances "maintained" against "reversed", 44 % and 29 % at the baseline).
- What is still missed is a relance with no question mark, named under "Weakest assumption, tested on the bench" of "Implementation (2026-09-28)".
- A subagent's incoming messages go through `UserPromptSubmit`, observed on 2026-09-22 on the `/commit` verifier's report, which quoted the wording; that these envelopes reach `prompt` as the transcript shows them stays inferred, never measured on the payload (`reference_claude_code_best_practices.md`).

## Pruning (substep 6)

Incident of the pass on the index, to know before any index pruning: removing the end of two lines by Edit also took their newlines, which merged three entries.
Only the `comm` check of the index against the directory caught it; the entries were restored.
That check is therefore the guard of any pass that touches `MEMORY.md`.

### Third pass: a verdict on the evidence for each memory file (framing approved on 2026-09-22)

**Decision.** Every file of `~/.claude/memory/` gets one row of a verdict table (keep, delete, merge into, prune the body, correct a stale fact), with the evidence that grounds it: for a deletion, the text that covers the content, cited by name.
Four read-only subagents sort by family (`feedback_`, `reference_`, `project_`, `feedback_review_severity_*`).
Every destructive verdict is rechecked in the main context before acting.
The user validates the table batch by batch, then each Edit.

**Why.** The two previous passes rested on the report of a single subagent, which the second had to correct (`rv-install` declared deleted when it had been renamed).
No file has yet been read in full against `CLAUDE.md`, `rules/` and the skills.
As of 2026-09-22 the store holds 114 files for 593,617 bytes, 15 of them above 8 KB, and 41 have neither an inbound `[[...]]` link nor a reference from `CLAUDE.md`, `rules/`, `skills/`, `hooks/`, the `.claude/` notes, `opencode/` or `claude-code-plugins`.
That last figure does not show those files are useless: what reaches them is an index line the model opens on, and the `description` under it, the native selector over that field being gated off on this account.

**The `review_severity` family forms a batch of its own.** Its 19 files (231,176 bytes as of 2026-09-22) are read by the "Scope filter" of `audit/walkthrough/agents/orchestrator.md` on each one's `description`, not by the index.
A merge is admitted there only between files aimed at the same project.

**Weakest assumption.** "Covered by a rule, therefore deletable" holds as long as the rule loads in the same contexts as the memory.
A `rules/*.md` with `paths:` loads only when a matching file is edited, whereas the index line is always injected.
A memory that serves a decision taken outside an edit (a Bash command) then gets the verdict "keep a short index line", not "delete".

**Rejected.**

- A sequential review in conversation, one file at a time: 114 round trips, all the content read in the main context, and a merge only shows once both its files have been read.
- Sticking to the open leftovers (pruning the bodies of `feedback_audit_walkthrough.md`, `reference_claude_code_best_practices.md`, `reference_tool_update_routines.md`, `feedback_r_environment.md`, and the form of the index): leaves the hundred other files unread in full.
  Those leftovers go into the table.
- A guard against reaccumulation (a redundancy check in the `commit` verifier): no measurement of how fast duplicates reappear; belongs to the framing of the index injection ("Open points").

**Table.** The sort of 2026-09-22 produced more than 110 verdict rows, pruned on 2026-10-13 because the commits carry them: what is left of it lives in `.claude/TRIAGE-MEMORY.md`, with the four questions to the user and the findings outside memory, and the index-line ceiling is held there in "Index lines too long".

**Open.** The validation grain within a batch, not settled.

## A proposal ends on a recommendation, and closure is invoked without waiting (framing approved on 2026-09-23)

**Decision.** Rewritten rules, plus a `Stop` hook of type `command` distinct from `commit-gate.sh`, `ending-gate.sh`, which reads `last_assistant_message` and blocks on two families: an action proposal with no position (the "offer" family), a delegation of the closure to the user (the "close" family).
The rewritten rules live in `CLAUDE.md` (Communication and Git), in the `description` of `skills/commit/SKILL.md` and in the `AGENTS.md` mirror under `project_opencode_agents_md_mirror.md`; the wordings, the exemption for quotations and the reason for the block are in the script and `_meta/tests/ending-gate.bats`.

**Why.** Two corrections from the user on 2026-09-23.
In the first, an offer "Je peux l'écrire si tu veux" is followed, after the relance "que recommandes tu ?", by a contrary recommendation, grounded in a rereading of `CLAUDE.md` that should have preceded the offer.
In the second, "Lance /commit quand tu veux le bloc" leaves the closure to the user.
Both rules already existed and do not hold.
Measurement of 2026-09-23 over 174 transcripts (`~/.claude/projects/*/*.jsonl`, 7 days) and 1,855 final responses:
- 191 responses contain "si tu veux", "quand tu veux" or "lance /commit", 89 of them in the last paragraph, hence the check of the whole message;
- 11 responses contain "lance /commit", 10 of them on their last line;
- the `commit-gate.sh` gate only sees `git commit` and lets these delegations through.

**The moment to close is the end of the session, not the end of each task** (see "Framing assumptions").
The verifier therefore runs only at session closure, and not at each task, which rules out its cost as an objection.
It still goes through again when a write counted as code, `_meta/notes/` included, follows the stamp: 2 to 3 passes a session on 2026-09-22 and 2026-09-23, from the `Agent` calls on `verifier.md` in the transcripts.

**Rejected.**
- Rules alone: the lever that "What reading the repository establishes" judges insufficient, and the counts above confirm it.
- A hook that invokes the closure from the state of the repository (a modified tree, nothing pending): "every task is done" is a judgement, not a mechanical fact, and the hook would fire at the end of each task.
- Extending `reco-relance.sh`: it fires at `UserPromptSubmit`, so after the relance, too late.
- Doing nothing: both rules exist and fail.

**Weakest assumption.** The mechanism holds as long as proposals with no position go through a finite list of wordings.
Measured on 2026-09-29 and disproved: precision 0.299 and recall 0.212 for the offer family, verdict under "Open" of "Implementation (2026-09-28)".
The hook forces an explicit recommendation, but cannot check that the verification it depends on preceded its first issuing: that part stays an instruction.

**Open.** Step 4 compares these two behaviours from 2026-09-23, the date of the change.

### Implementation of response endings (2026-09-23)

The wordings of the two families, the exemptions and the reason returned on stderr are in `claude/.claude/hooks/ending-gate.sh` and `_meta/tests/ending-gate.bats`.

What the script does not explain by itself:
- The exemption for quotations does not treat the straight apostrophe as a delimiter, because of French elision: "je l'applique si tu veux" must block.
- The reason asks for the response to be followed up, not rewritten (walkthrough of 2026-09-23): the hook acts after the display, and "rewrite" pushed the continuation to repeat the whole response.
- The exception for a slash command inside a code span rests on the measurement of 2026-09-23 over 1,652 final responses (7 days, not reproducible): 14 of the 15 "lance /commit" were written `` lance `/commit` ``, so exempting every span would have emptied the closure family.
- `si tu préfères`, 46 of those responses, is left off the list: on the samples read it almost always follows a recommendation, test "passes an alternative offered after a recommendation".

Known limits:
- The continuation one gate triggers is reviewed by the other in one direction only: since the walkthrough of 2026-09-23 ("Gate", decision "the loop guard is specific to the gate"), `commit-gate.sh` reviews the continuation of `ending-gate.sh`, but an offer in the continuation of `commit-gate.sh` is not seen.
- Noted at the walkthrough of 2026-09-23, with no fix, for want of an occurrence over the 181 transcripts of `~/.claude/projects/` (36,306 lines of assistant text): an orphan backtick or straight quote masking an offer on its line (a single offer line out of 241 carries an odd delimiter, and the gate blocks it anyway), a non-breaking space inside a wording, a newline between the verb and `/commit`, verbs off the list (`invoquer /commit`), `~~~` blocks (none in the responses) and `/commit-*` (no skill of that name).
To reopen on a real incident or at the step 4 replay.

## A defect in a file the session wrote is a verifier finding, and "is everything up to date?" is answered from a check (design approved on 2026-09-26)

**Decision.** Two levers, approved separately by the user on 2026-09-26 and implemented the same day, each now carried by its own files: **A, verifier side**, the rule that a defect settled in a file of `WRITES` is a `Findings` entry however minor, plus two checks of section 3, in `skills/commit/agents/verifier.md`, with the relay of every remaining `Out of scope` entry in steps 0.1.3 and 0.2 of `skills/commit/SKILL.md`; **C, question side**, `claude/.claude/hooks/closure-check.sh` and `_meta/tests/closure-check.bats`, a `UserPromptSubmit` hook on the "tout est update ?"
and "je peux clore ici ?"
forms.

**Why.** Incident of 2026-09-26, `/audit:walkthrough bash/.profile` then `/commit` in this repository.
The first verifier pass listed under "Out of scope" that the `MEMORY.md` index line of `feedback_review_severity_bash_dotfiles.md`, extended in the session, was "not false, just narrower"; step 0.1.3 applied findings only, the entry was dropped unsaid, and step 0.2 declared the session closable.
Asked "tout est update ?", Claude answered "oui, sauf un détail" before checking, then edited; a second verifier pass found that the memory's own addition had made "both fixed that day" read as the wrong date.
The written rule already existed ("Never state a verifiable fact without checking it first").
The question is stereotyped, which is what makes a regex sufficient: over the retained transcripts (7 days, counted 2026-09-26) 45 to 56 user prompts depending on the pattern, 16 of them exactly "tout est update ?", 4 "tout le tracking est update ?".

**Rejected.**

- **B, `ending-gate.sh` blocking a closure phrase while an open-items file written by the verifier is non-empty**: the model would empty that file itself, so the gate becomes a ceremony it satisfies, the failure "Weakest assumption" of "Framing of step 3" names.
- **D, one more rule in `CLAUDE.md` alone**: the rule exists and failed on 2026-09-26, as "What reading the repository establishes" predicts for written rules.

**Weakest assumption, untested.** A holds as long as the verifier, under the new wording, actually files as findings what it filed as "Out of scope"; if it does not, the remaining lever is the relay of step 0.1.3, which is a written rule.
Testing it would mean replaying the verifier on the pre-incident state, already committed (`88968bb`, `653317d`).
C's regex was checked against the measured forms only.

### Implementation (2026-09-26)

- **What grounds the wrapper strip of `closure-check.sh`**, measured on 2026-09-26 over the 178 transcripts of `~/.claude/projects/*/*.jsonl` and not reproducible: without stripping `<agent-message>`, `<cross-session-message>` and `<task-notification>`, the regex fired 141 times, 8 of them false positives, 7 being 6 subagent hand-backs and 1 task notification quoting the user's forms, the eighth the opening prompt of the implementing session, which quotes the question; with the strip, 134 times, that opening prompt the only false positive left.
  That these wrappers reach the hook's `prompt` as they appear in the transcript is inferred from the 2026-09-22 observation under "Limits" of "Recommendations (substep 5)", never measured on the payload.
- **First observation on A's weakest assumption, before the window.** The two verifier passes of the implementing session, run under the new wording, filed as `Findings` a missing pointer ranked "lower severity" and a families bullet narrower than the script ("not false, just narrower"), and the first of them caught a contradiction the new wording had created in section 5 of `verifier.md`.
  Two passes on the session that wrote the rule settle nothing; step 4 judges, and a second observation from another session, 2026-10-17, sits under the "Closure discipline" bullet of "Open points".

## Restructuring the global `CLAUDE.md` (opened on 2026-09-26)

Reco, design and implementation all done on 2026-09-26: the research is in `.claude/RECO-CLAUDE-MD-ARCHITECTURE.md`, the decision and its implementation record in `.claude/DESIGN-INSTRUCTION-ROUTING.md`, and what stays open in the bullet "Restructuring the global `CLAUDE.md`" of "Open points".

**Not to redo.** `RECO-SESSION-DISCIPLINE.md` already covers file size against adherence, pruning, Matt Pocock (150 to 200 instructions, "Stale Documentation Poisons Context", a root file reduced to essentials with linked files loaded on demand, a 25-line repository `CLAUDE.md`), HumanLayer and the official documentation.
`RECO-CLAUDE-MD-ARCHITECTURE.md` covers the architecture that report left open, and Pocock's work since.
`~/dotfiles/_meta/notes/agent-notes-discipline-reco.md`, third of the series, delivered 2026-11-06, covers the whole agent-facing corpus rather than the root file: the startup payload and its mechanism caps, the stale-figure defect, what the field puts at write time, the tooling, and a verdict on each convention in force under its section "Verdicts on the conventions in force". It sits in `_meta/notes/` and not beside the two above because that is the only one of the two repositories carrying a remote.
The `/design` it feeds ran on 2026-11-06 and is approved: `.claude/DESIGN-INSTRUCTION-ROUTING.md` § "The hook owns `claude-files.md`, a write-time cap replaces dropping the `PLAN.md` mandate, and the shape ban narrows to the copula form".
Two of the reco's three recommendations were overturned there on re-derivation, so its "Verdicts on the conventions in force" stays the record of what was recommended and that section the record of what was decided.

## The recommendation reminder fires on a question mark, not on a wording (design approved on 2026-09-28)

**Decision.** `reco-relance.sh` stops matching wordings and decides on one structural property of the prompt: after the formal blocks are stripped, a question mark remains.
Seven parts, approved together by the user on 2026-09-28; the script and its suite carry the mechanism, `feedback_no_literal_matching_on_natural_language.md` the conformance criterion (fewer patterns to maintain than before), and what the method gives up is under "Open" of "Implementation (2026-09-28)".

**Why a question mark carries the trigger.** Replayed on the frozen `recall_bench.json`, with the corrected split of the open point (11 `typo`, 18 `anchor`, 31 harness rows, 11 `commande` rows):

```
| rule                 | fires | typo  | anchor | harness | commande |
|---|---|---|---|---|---|
| a question mark      | 63/63 | 11/11 |  12/18 |    2/31 |     0/11 |
| that, and len < 200  | 59/63 |  9/11 |  11/18 |    0/31 |     0/11 |
| that, and len < 120  | 53/63 |  8/11 |  10/18 |    0/31 |     0/11 |
| len < 120 alone      | 53/63 |  8/11 |  14/18 |    1/31 |     8/11 |
```

The two harness rows a bare question mark catches are `<command-message>workflow:reco</command-message>` wrappers whose question mark sits in the `<command-args>` that follows, so the harness column reaches 0/31 only when a prompt holding a `NOISE` marker is dropped whole, never under a strip of the tag pair.

Replayed on the same frozen bench once implemented, on 2026-09-28: 62/63 `fires`, 11/11 `typo`, 12/18 `anchor`, 0/31 harness, 0/11 `commande`.
The `fires` row lost is a ninth `<command-message>` prompt, a `/cadrer` invocation whose question mark sits in its `<command-args>`; the eight counted above miss it because the old hook fired on it, which put it in the `fires` bucket rather than in `noise`.
Dropping it whole is by design, so 63/63 `fires` and 0/31 harness cannot both hold, and 62/63 is what the approved rule scores.
The 11 `commande` rows carry no question mark at all, so they need nothing lexical to be skipped, and `NOT_A_LEMMA` has no successor in the hook.
The 12 `anchor` rows retained are the genuine asks ("quelle approche recommandes tu ?", "recommandes tu de commit avant la revue adverse ou bien après ?"); of the 6 skipped, 4 are not asks ("ok je valide la voie A...", "non je voulais dire la relance reco").

Volume, measured on 2026-09-28 against the live base and **not reproducible**, the retention sliding it: 1,069 typed prompts under 600 characters, 930 after the formal strip, 328 holding a question mark, 35 %, for about 33,000 tokens a week and never a block.

**Rejected.**

- **Two stages, a state marker plus a structural test** (the user's own lead of 2026-09-28, instructed and dropped on the evidence): recognising that a response carried a recommendation is a fresh list of natural-language wordings, inside the hook whose list this design is meant to shrink, so it adds patterns instead of removing them.
  The marker would also discriminate almost nothing, `ending-gate.sh` having required since 2026-09-23 that every response end on an explicit recommendation.
  And it is unjudgeable on the frozen bench, whose rows hold `session`, `bucket`, `token`, `lemma`, `distance` and `prompt`, no assistant message and no turn order.
- **Deleting `reco-relance.sh`** and leaving the two `CLAUDE.md` bullets alone, as opencode already runs: it gives up a just-in-time placement whose effect has never been measured, which is symmetric with keeping it for the same reason, and step 4 was built to measure it.
- **A tolerant lexical stage** (edit distance on the lemma, anchor dropped): retired by the user on 2026-09-28 as more literal matching and one more script; `agrep` and `tre-agrep` are not installed either.
- **A length cap beside the question mark**: every threshold tested loses `fires` and `typo` rows, and the precision it would buy is not measurable on a bench that holds only the prompts the lemma pass matched.

### Implementation (2026-09-28)

`claude/.claude/hooks/reco-relance.sh` and `_meta/tests/reco-relance.bats` only, the scope the decision sets; `closure-check.sh` and `ending-gate.sh` untouched.

**Weakest assumption, tested on the bench.** That the user types a question mark when asking again.
All 63 `fires` rows and all 11 `typo` rows carry one, and the two genuine asks the method misses are exactly the two that do not ("commenr recommande tu de procédéer", "c'ets à toi de me dire s'il est temps de clore ou non.
je rappele que tu dois terminer en propose une reco").
If that habit changes, the recall collapses with no net but the permanent rule of `CLAUDE.md`.

**Open.**

- `closure-check.sh` keeps its regex: a question mark does not tell "je peux clore ici ?"
  from any other question, and its reminder (reread the verifier's "Out of scope", reread the tracking files) is too expensive to carry on 35 % of prompts.
  A formal successor was named and not instructed: fire on a question mark **and** the existence, in this session, of a verifier report whose "Out of scope" has had no answer, which is a written file rather than a wording.

- The "offer without a position" half of `ending-gate.sh` keeps its list for want of a labelled bench: nothing had frozen final assistant messages, and they expire under `cleanupPeriodDays: 7` like the prompts did.
  Freezing that bench is the first step of any redesign of it, and it has to happen before the retention takes the messages.
  Done on 2026-09-29, before any redesign: `ending_bench.py` writes `ending_bench.json` beside it (bullet "Measurement scripts"), 1,503 stop points over 151 transcripts scanned, 142 of them contributing one, spanning 2026-09-21T20:12Z to that morning, 2.45 MB, kept out of the repository by the `*.json` rule of `3788eff` since it quotes assistant messages.
  Of those two figures only the 142 re-derives from the file: the scanned count is not recorded in its `meta`, and the retention had already taken the set down to 147 transcripts by that afternoon, so 151 stands as a record of the run rather than as a reproducible number.
  Replaying today's hook over them: 1,419 silent, 69 `offer`, 7 `close`, 8 both, the phrases led by "si tu veux" (44), "veux-tu que je" (13) and "lance /commit" (11).
  The bench carried no judgement on which messages genuinely end on an offer without a position; that labelling followed the same day, over a stratified sample of 400 rows whose design and constants are in the docstrings of `ending_sample.py` and `ending_merge.py`.
  The ninth shard, which relabels the first through a second labeller, answers the single-reader limit every earlier pass recorded and none had sized: raw agreement 0.96, Cohen's kappa 0.898 over 50 rows, 0.92 on the closure flag, the two disagreements both `offer` against `position`.
  **Verdict on the "offer" half: precision 0.299 (23 of its 77 offer-family firings are genuine), recall 0.212 (CI 0.150 to 0.295), about 85 missed offers in the silent population against 23 caught.** It fires wrongly seven times out of ten and catches one true offer in five.
  Per phrase, true against false: "dis-moi si" 0/10 and "tu veux que je" 0/3 carry no signal at all, "si tu veux" 11/33 carries the volume and most of the error, and only "quand tu veux" 6/3 and "veux-tu que je" 6/7 are above chance.
  That table counts offer-family phrases alone: a first version of `ending_merge.py` iterated every phrase of a firing row, which put the close-family "lance /commit" in it at 6/2, double-counted with the offer phrase each of those 8 rows also carries, and the script now skips a phrase matching `/commit`.
  The `close` half inverts: precision 0.867 (13 of 15) but recall 0.063, about 193 missed handoffs, so it is accurate and nearly blind.
  Caveat carried by the numbers: 19 of the 42 `offer` labels are marked low confidence.
  The two measured disagreements are a response ending on "j'attends ton feu vert pour passer au bilan" and one ending on "C'est anodin, je le laisse à ton choix.", both read `offer` by the first labeller and `position` by the second.

  **A boundary the labellers named in prose, decided by the user on 2026-09-29: a response that applies a fix, reports its verification and verdict, then asks for the next review point is `position`.** The 21 rows of that shape in the sample are listed by id in `ADJUDICATED_POSITION` of `ending_merge.py`, by id rather than by a pattern over their prose, and each keeps its `label_as_read` so the override stays visible and reversible.
  The reason: `CLAUDE.md` requires that in an adversarial review the user calls the stop, not the audited model, so asking for the next point after applying and verifying executes a rule rather than dodging a decision; labelling it an offer would make the gate fire against a behaviour the instructions demand.
  The labellers had almost reached that reading on their own, 19 of the 21 rows already `position`, with 7 of the 21 at low confidence (5 of those 19, plus the two overridden rows), and on the 4 rows both labellers saw they agreed at high confidence, so the shape was a source of hesitation rather than of divergence.
  The decision overrides two rows only, 930 (`none`) and 1138 (`offer`), and moves the recall from 0.204 to 0.212, the precision not at all, one of the 21 firing the hook and by the `close` family.
  Priced before the call, the opposite ruling would have cost far more: treating all 21 as offers puts the estimated misses at 175 and the recall at 0.116.
  All of it is readable from `ending_labelled.json` without a transcript, which is what the bench exists for.

- Whether the reminder placed on a question earns its tokens stays unmeasured, as it was for the wording trigger; step 4 judges.

**Walkthrough of `reco-relance.bats` (2026-09-28, reviewer `posit-dev:critical-code-reviewer`).** 7 findings: 3 accepted, 1 rejected, 3 noted.
The script was not touched: every change is in the suite, committed in `c9b3bcf`, the two calibration rules below in `1aa7339`.

Accepted.
The suite could not tell stdout from stderr, `run` merging the two, so the three injection assertions read a stream Claude Code does not: a mutant sending the whole payload to stderr left them green (16/17, the one failure being the malformed-JSON test, for the unrelated reason that the jq parse error then leaked).
Fixed by `run --separate-stderr`, `[ -z "$stderr" ]` in both `assert_injects` and `assert_silent`, and `bats_require_minimum_version 1.5.0`, which follows `clean-html-id.bats` and `out-textconv.bats`, the only two suites here using that flag.
No fixture held two wrappers of one kind, which is where a greedy quantifier diverges from a lazy one: three fixtures added, the two `pasted_content` ones killing `[\\s\\S]*?` to `[\\s\\S]*` and `gsub` to `sub`, the `agent-message` one killing a greedy mutant restricted to the wrapper strip, which no `pasted_content` fixture reaches since the two `gsub` are independent.

Rejected: "`| strings` is untested".
Dropping it makes jq abort on a non-string prompt, and the script's `2>/dev/null` plus its trailing `exit 0` turn that abort back into exactly the silence the two tests named for that case assert, so the mutant is observationally equivalent through the hook's contract.
Measured the same day against the hardened suite: a jq compile error fails the injection tests, and a broken strip regex fails a silence test, so real breakage is already caught and the proposed canary would only copy the jq program into the test file.

Noted, three.
The missing-jq test pins the contract and not the guard, bash applying the command's own redirections before printing "command not found"; the guard stays, becoming load-bearing again the moment the `2>/dev/null` goes (measured).
The unanchored `noise` regex does silence a prose mention of a marker, "Pourquoi le Stop hook feedback: reste-t-il vide ?"
among them, but that shape has 0 occurrences over the 897 typed prompts of the available transcripts, 339 of them carrying a question mark, so it is noted under the heuristic-code rule and reopens on a real incident rather than on a fixture.
Two mutants survive the suite, dropping `\\b` from the wrapper alternation and moving the noise `select` after the two `gsub`; the second is arguably the better design, restricting the silencing to markers outside quoted material, which is the precision limit the previous item names.

Gate: `shfmt -d -i 2` and `shellcheck` clean, `bats _meta/tests/reco-relance.bats` 20/20, the whole `_meta/tests/` 1484/1484.
Cross-model L1 (Agent sonnet) ran on the five Important+ findings with no divergence; L2 never fired, this reviewer's tiers holding none of Blocking, Required or Critical.
Ouroboros evaluate APPROVED at 0.90.
Two rules went to `feedback_review_severity_bats_tests`: a surviving mutant that is observationally equivalent through the artifact's contract is not a test defect, and a proposed remedy is measured for discriminating power before it is applied, the "add a positive counterpart" remedy of this walkthrough having killed nothing until it was substituted.

## Open points

- **A `handoff` skill closing every session, suggested by the user on 2026-11-08 and designed the same day: `.claude/DESIGN-HANDOFF.md`.** That note carries the nine approved decisions, its six rejected approaches, the measurements of 2026-11-08 that only the consumed `.claude/HANDOFF.md` buffer held, what stays open, and the record of the four artifacts built the same day under its section "Implementation of 2026-11-08".
  Step 4 must account for the change, which adds a step to axis 3 above, rewrites what a session does after its last commit, and replaces the injected text of `closure-check.sh` without touching its trigger, so the recall measurement that step still owes is unaffected.

- **Both adversarial reviews the user accepted on 2026-10-11 ran that day.** The `write-journal.sh` pass returned zero finding, so no behaviour changed and the pass on its suite was never owed; its four measured-clean shapes are recorded in `feedback_review_severity_shell_installers.md` and in `26506fb`, and `DESIGN-COMMIT-GUARD.md` no longer carries the item, its open point having been dropped on 2026-10-16 once that evidence was derived. What the `skill-mention.sh` pass settled the same day is in `DESIGN-INSTRUCTION-ROUTING.md`, section "Step 3": the relay-tag guard and the rewritten injected message. The calibration that governed it, `feedback_review_severity_heuristic_code.md` with `feedback_no_literal_matching_on_natural_language.md`, held: of nine findings two were accepted, one rejected on the hooks doc and six noted for want of any producer on the real corpus.

- **The fourth memory pass, opened by the user on 2026-10-06: framed the same day, its seven parts implemented on 2026-10-08.** The decision, its measurements, its seven rejected approaches, its weakest assumption and the implementation record are in `.claude/DESIGN-INSTRUCTION-ROUTING.md`, section "The store admits a note only when no mechanism already produces the behaviour, and the guard counts index lines"; that section also records what the framing corrected, the governing index fraction being lines rather than bytes.
  **Step two, the sweep, ran on 2026-10-09 and closes the item.** Its four batches, its refused cuts, its closing measurements and the ceiling's margin are in `.claude/TRIAGE-MEMORY.md`, section "Fourth pass: the sweep under the admission criterion", which also carries the later narrowings of that margin.
  **What binds from here:** only the unparsing frontmatters, which the sweep left out of scope.
  One task for that pass, found on 2026-10-06 while measuring the descriptions: frontmatters that no longer parse, all on the unquoted `: ` in a value that "Body prunes of the third pass" of `TRIAGE-MEMORY.md` records quoting out of sixteen files on 2026-09-22, so the fix does not hold and the quoting is worth a mechanism rather than a pass.
  Eight at that date and at the closure of 2026-10-08 (`feedback_concision`, `feedback_fr_to_en_translation`, `project_transcription_local_cpu`, `reference_better_bibtex_export_control`, `reference_flextable_grouped_rows`, `reference_git_html_id_filter`, `reference_gtsummary_notes_and_labels`, `reference_r_list_key_lookup`), twelve on 2026-10-16, re-derived by `yaml.safe_load` over the frontmatter of the store's 133 `.md` (`MEMORY.md`, the 134th, carrying none by design): the four added since are `feedback_bats_comment_carve_out`, `project_qmd_format_hook`, `reference_llama_server_gpu_serving` and `reference_plugin_skill_env_vars`, each on the same unquoted `: ` in its `description`.
  That growth is the measurement the "mechanism rather than a pass" reading was missing: four new carriers in the eight days a prose fix was the only guard.
  **Settled on 2026-11-06: the cost is nil today, on two conditions that are neither permanent nor ours.** The selector over the files' `description` exists in the binary but is gated off on this account, so selection is the model opening a file off the `MEMORY.md` index; and the frontmatter's writer never fires, keying on the literal configured path while writes land at the resolved store. `TRIAGE-MEMORY.md` § "A non-parsing frontmatter costs nothing while the native recall stays off" carries the evidence, the commands that re-derive it, and what the flag turning on would cost. What stays open is therefore a decision rather than a measurement: whether to stop the carrier count growing while that is free, a `yaml.safe_load` at the commit gate being the cheap form.

- **Verifier cost on a small commit, opened on 2026-09-26, designed and implemented on 2026-09-30, and what stays open of it moved to `DESIGN-COMMIT-GUARD.md`** with the two seal residuals of 2026-09-30 and 2026-10-01 and the `shfmt` check owed on ju-TP2.

- **Leftovers of the `/commit` of 2026-09-26, three still open.** Retarget or drop is the user's call on the two live passages that still name the deleted `rules/environment.md`, `PLAN-PYREFLY.md` "Adversarial review" and `PLAN-ORPHANS.md` "Blockers"; `PLAN-TOOL-UPDATERS.md` step 7, the third, was retargeted to `claude/.claude/rules/install.md` on 2026-10-14, and `PLAN-LUA.md`, a fourth carrier the first list missed, now points at `_meta/notes/environment-archive.md`.
  `PLAN-UPDATER-HYGIENE.md` still owes the adversarial-review status of `quarto-update` and the current code of `rig-update` and `gh-update`; its `bash/.profile`, `sys-cleanup` and `duckdb-update` halves are closed.

- **Restructuring the global `CLAUDE.md`, opened and done on 2026-09-26.** Still open from its design note (`.claude/DESIGN-INSTRUCTION-ROUTING.md`, "Open"): whether user-level `paths:` globs match a file outside the project directory.
  The three changes approved on 2026-11-06 were built the same day: the self-referential `paths:` on `rules/claude-files.md`, the plan growth cap in `inject-rules.sh`, and the `[live-count]` rule in `prose-lint`, which took the inverse scope of the dash rules and now reports on the lines a write adds. Their rejected approaches and what stays open on them are in that note's section "The hook owns `claude-files.md`, a write-time cap replaces dropping the `PLAN.md` mandate, and the shape ban narrows to the copula form": the count rule's recall is bounded below by the copula form and not measured, and whether the 20,000-byte cap holds waits on the plans over it being split without losing record.

- **The tracking rule carries its subtractive half, designed and implemented on 2026-09-30.** The criterion of the two pruning passes went into the "Plans and tracking" bullet of the global `CLAUDE.md` (one clause) and the "Content" section of `rules/claude-files.md` (four bullets); the decision, its three rejected approaches and its open points are in `.claude/PRUNE-OBSERVATIONS.md`, section "The criterion is now a rule, the root carrying one clause and the scoped file the whole test".
  That file also holds what pruning a tracking file takes, as the motif list its thirty-six per-pass records were lifted into on 2026-10-14; the name-check bullet of `rules/claude-files.md` is the one pointer a session is actually shown, and it names the installed `bin/.local/bin/refs-lint.py`.
  Still open there: the weakest assumption, that a criterion in prose produces deletions at all, is untested.
  Step 4 must account for the rule, which changes what a session writes to and removes from a tracking file.

- **Closure discipline, design approved and implemented on 2026-09-26.** Section "A defect in a file the session wrote is a verifier finding, and "is everything up to date?" is answered from a check", subsection "Implementation (2026-09-26)".
  **Second observation on A's weakest assumption, 2026-10-17, and this one not from the session that wrote the rule**: over four `/commit` passes of one session, 7 findings against 7 entries under "Out of scope", none of the latter naming a file of its own `WRITES`, and all five defects that sat in a `WRITES` file filed as findings, three of them minor (two quoted headings the formatter had split, an ellipsis character it had replaced). The other two findings named files outside `WRITES`, which is stricter than the rule asks. One of the five was a contradiction the pass found between this very item, as it was being written, and the first observation under "Implementation (2026-09-26)", which is the case the rule exists for. The rule is carried by `agents/verifier.md` itself ("Never file it under `Out of scope` because it looks small"), so what one session cannot settle is the breadth and not the mechanism: four passes, all on tracking prose, all on the model the skill pins. Step 4 still judges, per the first observation under "Implementation (2026-09-26)".
  Still open: the recall of `closure-check.sh`, which waits on the deliberate freeze step 4 now demands rather than on a window, the "Status (2026-10-08)" block having stopped the window from being a condition. `3ab9af4` of 2026-10-17 on `claude/.claude/rules/claude-files.md` is one more commit in the series that made that freeze necessary, and it moved no start, nothing gating on one any more.

- **`skill-mention.sh` strips the blocks its two sibling hooks strip, closed on 2026-10-01.** It fired on a `/name` quoted in a subagent report or in pasted text and told the main thread to invoke a skill the user had not typed, five times between 2026-09-28 and 2026-10-01. The user's call on the `<pasted_content>` half went to stripping, the argument being the `CLAUDE.md` rule that pasted instructions are followed only where the user's own message asks for it; the hook matches a formal token, so it stays outside the constraint of 2026-09-28 on literal matching. The 16 cases of `_meta/tests/skill-mention.bats` carry the behaviour.
  Left as it was: a `/name` opening the message is still marked seen and never reported, the harness loading that one itself.

- **Transcript retention.** With `cleanupPeriodDays: 7`, the base of 2026-09-22 cannot be replayed and step 4 will measure the last 7 days only.
  Raising the value is the user's call.

- **Measurement scripts, `_meta/session-discipline/`.** The directory holds the 36 `.py` of seven measurement batches, archived as they were written; `prek.toml` excludes it from `ruff-check`, `ruff-format` and `pyrefly-check` (decided 2026-09-22), because a rewrite would cost step 4's remeasure its identical counting, so no hook enforces anything there.
  Nothing generated leaves the machine: `.gitignore` carries `_meta/session-discipline/*.pkl`, `*.txt`, `*.json` and `*.tsv`, which cover the pickles, `files.txt`, `a2.txt`, the TSV and the frozen benches, all of them quoting user prompts or project names.
  Entry points, each run from that directory: `load.py` writes `s.pkl` for `an.py` (which writes `rows.pkl`), `q2.py`, `q3.py`, `q3b.py` and `probe.py`, while `ext.py` reads `files.txt` (a list of `.jsonl` paths to regenerate) and writes `msgs.pkl` for `a*.py` and `b*.py`; `commit_sessions.py <out.json>` writes the JSON that `detail.py`, `timeline.py <out.json> <session prefix>...` and `verifier_cost.py` read, `gate_blocks.py` standing alone; the four probes of 2026-09-30 read the same JSON, `verifier_size.py` printing the per-pass table and the cost split by regime and by `|WRITES|`, `verifier_phase.py <out.json> [since]` bracketing the section 5 phase against the rest of the pass, `verifier_yield.py` counting the section-5 signatures per day in the reports, and `verifier_trace.py <out.json> <session prefix>...` printing one pass call by call with its think and run times; `cost_sessions.py` prints one TSV row per session and `cost_periods.py <tsv>` aggregates it, `cost_thinking.py` standing alone; `python3 recall_classify.py` is the whole recall chain, about ten minutes, writing nothing, and `recall_bench.py` freezes `recall_bench.json`; `bench_probe.py`, `bench_probe2.py` and `volume_probe.py` replay the candidate trigger rules over that bench; `python3 ending_bench.py`, about twenty seconds, writes `ending_bench.json`, then `ending_sample.py`, the labelling pass, and `ending_merge.py` write `ending_labelled.json`.
  Traps: `cost_sessions.py` and `cost_thinking.py` hard-code UTC+2 as local time, and `cost_periods.py` carries its period bounds in the code (09-22 15:32 and 09-26 16:37 local), a comparison of the `high` effort needing a third at 09-27 17:38; `verifier_cost.py` skips without a word a pass whose subagent transcript is gone; `gate_blocks.py` skips the `instructions-ab` projects, and the analysing session is hard-coded as `SELF` to exclude it; the `stop_blocks` column is always 0, the field it reads marking no Stop block; `bench_probe2.py` ends on a `KeyError: 'other'` in its trailing-question block, after printing everything the design used; `verifier_size.py` reads `|WRITES|` out of the agent prompt, which it finds for 88 of the 133 passes only, the prompt having carried both a `WRITES:` and a `WRITES=` heading and some parent transcripts being gone, so its size buckets run on a subset while its per-day table runs on all; `verifier_phase.py` brackets rather than measures, everything after the first section-5 command counting toward that phase although sections 1 to 4 interleave with it; `recall_load.py` is a second loader on purpose, sharing no pickle chain with `load.py`, the names differing so both can sit here.
  Three definitions recorded here because `rules/code.md` routes a WHY out of the code.
  `recall_classify.py`: `NOT_A_LEMMA` drops `commande`, `commandes`, `commander` and `commandez`, which sit two edits from `recommande` but are a different word, so "donne la commande" is not counted as a recommendation ask; and the classifier has a fourth bucket, `other`, beside noise, typo and anchor.
  `ending_bench.py`: a *stop point* is an assistant text entry, outside a sidechain, followed by a real user prompt, by a `Stop hook feedback` entry or by the end of the transcript, the third case existing because the hook exits 2, so a definition keyed on the next prompt alone would miss exactly the firing messages; `.last_assistant_message` is reconstructed from the entry's text blocks rather than captured, the script's weakest assumption, which 23 of the 24 rows holding a real `Ending gate:` feedback confirm, the 24th being a message that predates `bcd7527` by six minutes.
  `ending_sample.py`: shard 99 duplicates shard 00 on purpose, so that a second labeller's pass yields the agreement figure.
  Still open, found while archiving: the sentence of `rules/python.md` counting "three Python files of its own". The `_meta/` tree listing neither `session-discipline/` nor `instructions-ab/` was fixed on 2026-09-30, when `README.md` was deleted and its "Structure" moved to `_meta/notes/dotfiles-bootstrap.md`.

- **Shell search toward a hook.** Classed H at the pruning: `grep` still leads 634 Bash segments against 4,192 for `rg` over 7 days, which makes it a rule violated continuously.
  A `PreToolUse` on `Bash` flagging `grep` or `find` at the head of a segment is to be framed: the false positive of `| grep` on a short output is likely.
  The bullet stays in `CLAUDE.md` until then.
  Decided on 2026-09-22: the framing waits for the end of step 4, so as not to change the measured behaviour inside the window.

- **The adversarial-review stop signal, toward the skill.** Its place is `audit/walkthrough` in the `skills` repository, outside the scope of step 3; the bullet stays in `CLAUDE.md`.

- **Memory index injection, closed on 2026-09-27.** Pending from its implementation (`78a40b0`, `847f432`), in a fresh conversation: `/audit:walkthrough _meta/instructions-ab/grade.py --reviewer posit-dev:critical-code-reviewer`.
  The `_meta/tests/inject-project-context.bats` half ran on 2026-10-12 (`fbcc7de`), leaving the `grade.py` one.
  Also left open on 2026-09-27: the two harness behaviours the change switched on, the index near-cap nudge and frontmatter stamping (described in `.claude/DESIGN-INSTRUCTION-ROUTING.md`), whose settling may touch `settings.json` or `rules/memory.md`; the window cost that qualifier carried is spent since the step 4 lifting of 2026-10-08 above.

- **The migration of the `commit` skill into a separate plugin waits on step 4 being closed**, which is the one thing this plan still owes it; the decision, its three open points and the shell's own are in `DESIGN-COMMIT-GUARD.md`, sections "The `commit` skill moves to a separate plugin with its gate and its journal, once the mechanism is stable" and "The shell of the `commit` skill moves into tested scripts".

- **Revision of the `cadrer` skill, implemented on 2026-09-24 (`07f3329`), the skill renamed `design` the same day.** Step 4 must account for two of its corrections, recorded in `.claude/DESIGN-CADRER.md`: B3 (test the weakest assumption before recommending) and B4 (a validation question that names the path, a closure ending on the recommended next step), which touches response endings, so a session going through `/cadrer` or `/design` after 2026-09-24 is not comparable with an earlier one on those behaviours.

- **Stale announcements across the tracking, implemented on 2026-09-23.** Step 4 must account for it: section 5 of `verifier.md` was extended inside the window, so stale announcements only compare from that date; the shell-search point deferred past step 4 is the opposite case, a behaviour nothing had yet modified in the window.
