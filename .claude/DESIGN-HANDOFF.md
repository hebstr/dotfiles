# DESIGN-HANDOFF.md

Design note for the `handoff` skill, approved by the user on 2026-11-08.
It sits beside `.claude/PLAN-SESSION-DISCIPLINE.md`, whose axis 3, success criteria and framing assumptions are its premises, and it is the only holder of the measurements of 2026-11-08: they were taken for the brief that opened this design, `.claude/HANDOFF.md`, which is a buffer overwritten whole.
Scope: the dotfiles `claude` package (the hooks, the skills, `CLAUDE.md`, `rules/`) and `~/Documents/packages/skills`.

## The closure is certified before the commit blocks, by one skill named `handoff`

**Decision**, nine parts approved together.

1. One skill, `handoff`, in the dotfiles `claude` package, invocable by the model and by `/handoff`, called by section 0.2 of the `commit` skill when that section concludes that nothing remains to pursue, and executed before section 0.4.
   Branch 1 is its empty outcome, the way `commit` with nothing to commit is one.
   `close` is abandoned.
2. The reread's scope is the write journal's tail, the entries of `claude-code-writes-<session>.log` whose timestamp exceeds the stamp, deduplicated and unfiltered.
   It is not the output of `commit-stale.sh`.
3. The reread is a pass of the existing verifier (`skills/commit/agents/verifier.md`) in a fresh context, launched as step 0.1.2 launches it, with `WRITES` holding that tail alone.
   It is not a reread by the thread that wrote the files.
4. One pass only.
   The writes its findings produce are resealed by `writes.sh --restamp <path>...` and named to the user, never reread a third time.
5. The branch is decided and the brief written **before** the reread, which covers the brief.
6. Branch 2 holds when the next step is gated on a `/name` only the user can type, or belongs to another working directory, or needs a context this conversation has burned.
   Otherwise branch 1, an unfinished workstream whose plan carries the next step included.
7. The brief's content contract is the seven points below, carried by the skill.
   `rules/claude-files.md`, section "`.claude/HANDOFF.md`", keeps the buffer's lifecycle.
8. `ending-gate.sh` gains no clause.
9. `closure-check.sh` stays and is reduced to a router, its procedure moving into the skill.

**Why one skill rather than a step of `commit` or two skills.**
The branch decision is the valuable half and needs both branches' criteria side by side; splitting them puts the choice back in the caller, which is where it is lost today.
The precedent is cited by name: of the procedure skills of this package (`commit`, `design`, `poc`, `prune`, `relire`, `review-comments`, `review-prose`, `typst-review`), `commit/SKILL.md` is the only one the model may invoke, every other carrying `disable-model-invocation: true` or a "user-invocable ONLY" description, and its own `description` already carries "Also use to close a session".
A model-invoked closure skill is therefore the house form rather than an invention.
The reference skills of the same directory (`ref`, `zotero`, `bash-defensive-patterns`, `bats-testing-patterns`) are loadable by the model and are not procedures, so they are no precedent either way.
Folding the procedure into `commit` instead would load the brief contract at every one of a session's median 8 commits and would leave the 12 sessions in 105 that commit nothing with no entry point, where the user wants an explicit `/handoff`.

## Placing the skill before section 0.4 resolves the order of axis 3 without demoting the commit

Axis 3 of `PLAN-SESSION-DISCIPLINE.md` declares the order "tracking recorded and up to date, then a recommendation on what comes next or the explicit indication to close, then the commit proposal, which marks the closure".
The suggestion put the handoff after the commit, which would have made every reread finding a second corrective commit and taken the closure marker away from the commit.
Running `handoff` between section 0.2 and section 0.4 keeps both: the commit still marks the closure and still records the work, the certification precedes it, and a finding's fix rides in the same commit through the reseal that step 0.1.4 already prescribes.
The order gains a fourth element rather than reversing two.

A finding whose fix touches code rather than tracking is not the skill's to apply, by the rule of step 0.1.3; it goes to the user.

## The delta to reread is the journal's tail, because `commit-stale.sh` cannot see 117 of 150 post-pass paths

The suggestion named `commit-stale.sh` as the source of the delta.
Measured on 2026-11-08 over the transcripts of `~/.claude/projects`, that list misses most of the hole the skill exists to close.

```
| Measure (2026-11-08)                                          | Value          |
|---|---|
| Sessions carrying at least one `writes.sh` call               | 94             |
| Verifier passes per session: median / max                     | 2 / 11         |
| Files written after the last pass: median / mean / max        | 1 / 1.6 / 8    |
| Sessions with at least one post-pass write                    | 73/94          |
| with more than one / more than three / more than five         | 41 / 9 / 2     |
| Post-pass paths in all                                        | 150            |
| of which invisible to `excluded()` of `commit-stale.sh`       | 117            |
| that 117 split: ignored `.claude/` paths / the memory store    | 105 / 12       |
| Visible: outside any `.claude/` / unignored `.claude/`        | 24 / 9         |
```

`excluded()` of `commit-stale.sh` drops a `.claude/` path that the enclosing project ignores, and drops the memory store unconditionally; its journal branch drops the same paths again through `in_work_tree_unignored`.
Checked the same day from each parent root: the `.claude/` notes of `eds-prise` and of `quarto-hebstr-doc` are ignored, `~/dotfiles/.claude/HANDOFF.md` and `~/dotfiles/.claude/DEFERRED.md` are ignored, and only the notes `~/dotfiles/.claude/.gitignore` whitelists by name are visible.
So the paths where both defects of 2026-11-08 lived, an ignored `.claude/` note and the brief itself, are exactly the paths that list cannot print, which step 0.1.4 of `commit/SKILL.md` already states for `.claude/HANDOFF.md` without drawing the consequence for the scope.

Replay: count, per transcript and outside sidechains, the Bash calls whose command holds `writes.sh` without `--restamp`, then the distinct `file_path` of the `Edit` and `Write` calls that follow the last of them.

"Unfiltered" has one exception, found on the smoke test of 2026-11-08 rather than designed: a path under `/tmp` or `$TMPDIR` is dropped, because the session scratchpad is journaled like any other write and holds no tracking file.
`commit-stale.sh` drops it as a side effect of `in_work_tree_unignored`, which the journal's tail does not inherit.
A path in another repository stays in, that being the write a project session makes to a `~/dotfiles` note, which no other mechanism reaches.

The stamp is the tail's only input, which the audit of 2026-11-08 found to be a hole of its own: `writes.sh --restamp` mints a fresh `date +%s%N` and writes it to the stamp file, carrying the per-path seals over unchanged, so every write between the verifier's pass and that reseal which no applied finding named falls behind the stamp and leaves the tail.
The gate is unaffected, reading the per-path seals, and `tail.sh` reads only the stamp value.
The window is usually the fix edits of step 0.1.3 alone, and the second pass step 0.1.4 prescribes over it is triggered off `commit-stale.sh`, so the paths most exposed are the ones that list already filters: both mechanisms miss the same class.
L1 and L2 both returned `valid`. Section 1 of the skill now carries the instruction to add that window to the scope; keying the tail on the last verifier stamp instead, through a separate restamp marker, would touch `writes.sh` and is left to the user.

Two corrections to the suggestion's premises follow.
`writes.sh` records a `sha256` digest per path under the stamp, through `digest()` of `commit-stale.sh`, never the file's content: the snapshot establishes that a file moved and restores nothing to reread.
And no mechanism prints the journal's tail today, `commit-stale.sh --only` applying `excluded()` like the other modes, so the skill computes it; `((ts > stamp))` in bash is exact on the 19-digit values of `date +%s%N` and is the idiom the journal branch of `commit-stale.sh` already uses.

## The reread is a verifier pass, and the brief is one of its inputs

**A fresh context, not a self-reread.** The suggestion had the skill reread the delta itself.
"What reading the repository establishes" in `PLAN-SESSION-DISCIPLINE.md` rules that out: verifying inside the build conversation is the self-critique that both that note and `CLAUDE.md` declare bound to fail, and the verifier exists for that reason.
Reusing it verbatim also costs nothing to specify and comes back with `SWEEP=no`, so section 5 does not sweep twice in a day.
Cost, from the table above: one to eight files, median one.

**The brief precedes the pass.** Of the two defects of 2026-11-08, one was two wrong counts in the brief, written after everything else.
A reread placed before the branch cannot see them, which inverts the order the suggestion proposed.

**Failure handling is cited, not copied, corrected 2026-11-08 by the audit.** Section 4 said only to copy `STAMP_FILE`, `STAMP_VALUE` and `SWEEP` as printed, which has no referent at exit 3, where no `STAMP_` line is printed at all, and it dropped the stamp read-back of step 0.1.4.
It now cites steps 0.1.1 and 0.1.4 for the handling and states only the two facts that differ for this caller, a third copy being what the rule against restating a caller's own rules exists to prevent.
Two measurements decided the wording, both against `writes.sh`: it never exits 4, mapping seal status 4 to `exit 1` in restamp mode and ignoring it otherwise, and in restamp mode `((restamp)) && exit "$failed"` runs after the stamp has been rewritten, so a non-zero exit does not mean the stamp was not written.
Step 0.1.4 of `commit/SKILL.md` asserts both of those the other way round and is owed a correction of its own, outside this skill.
Section 4 also now refuses `--restamp` with no path, that form resealing the whole journal and so certifying the content section 1 handed to no pass.

**Stop rule.** The reread is clean when the pass reports no `Findings`, every entry of its `Out of scope` has an answer, which section 0.2 already requires, and no path of the tail was left unread.
Exactly one pass runs: applying a finding is itself a write, so an unbounded rule would regress.
The writes the fixes produce are resealed and named, as step 0.1.4 prescribes for a pass cut short.

## Branch 2 is the next step this conversation cannot take

The criterion is stated so it is not re-litigated per session.
Branch 2 holds on one of three mechanical reasons, and on nothing else:

1. the next step is gated on a `/name` only the user can type, which covers every procedure skill of this package but `commit`, and `workflow/sync`, `workflow/reco`, `workflow/write` and the `audit/` passes of `~/Documents/packages/skills`;
2. it belongs to another working directory or another repository;
3. it needs a context this conversation has burned, a review of the session's own work included, which `CLAUDE.md` already sends to a fresh conversation.

An unfinished workstream is not a reason by itself: the plan carries its next step, and a brief repeating it duplicates the note, against the rule of `rules/claude-files.md` that a prompt worth keeping goes to the note that owns it.

The audit of 2026-11-08 found reason 3 silent on the review `commit` section 0.3 proposes, which runs after the branch is decided, so a session changing enough code to earn a review could conclude branch 1 and learn of it one step later.
The ordering is not what is fixed: the branch question is whether a brief carries more than the bare `/name`, which this conversation can answer without 0.3's `numstat`, and restating that threshold in the skill would drift against its owner.
Section 2 now says a review of the session's own work is reason 3 when the fresh conversation needs the inputs, the measured bounds and the interdictions a command cannot carry.
Cross-model split: L2 `valid` on the ordering, L1 `invalid` on the ground that 0.3's command is self-contained while conceding the wording admits the reading. The remedy is the same either way; the counter-example is this audit's own brief, which routes to `/audit:walkthrough` and carries four external inputs and four interdictions.

Evidence, the four non-empty buffers on disk on 2026-11-08, which the three reasons cover exactly: `eds-prise/.claude/HANDOFF-SNDS.md` opens on `/design` and `HANDOFF-UNSLOP.md` on `/poc`, reason 1; `claude-code-litrev/.claude/PROMPT.md` states its own reason 2, its destination being a `DEFERRED.md` that a dotfiles session does not write; `eds-prise/.claude/HANDOFF.md`, a site-by-site classification of 121 citations, is reason 3.
The rate the branch criterion has to explain is 46 of 105 sessions writing a buffer against 93 of 105 committing, so both branches live inside committing sessions and "did we commit" cannot be the criterion.

## What a brief must carry

Seven points, derived from `eds-prise/.claude/HANDOFF-COMMENTS.md` of 2026-11-08, the only worked example, which satisfied all seven.
It was good because the writing session held the whole context, which is what the contract replaces.
That buffer was consumed the same day, measured at 0 bytes while this design ran, so the derivation below is all that is left of it and no session can reread the example.

1. **The opening line is the `/name`** when the brief routes to a gated skill, the rest of the file being its argument, per `rules/claude-files.md`; otherwise an imperative title naming the task.
2. **The current state with the evidence that establishes it**, a sha, a dated measurement, a count, never recall.
3. **What the reader must not do**, named: the skill not to invoke, the command that has no CLI route, the pass that would stop at its first step.
4. **The ground truth for each step**, as the command that produces it rather than as a description of it.
5. **The bounds and the traps**, each dated and each measured.
6. **What is owed elsewhere and must not be folded in**, with where it is filed.
7. **Where the record goes**: the note that takes the outcome, and the ceiling or the gate that governs writing to it.

The contract lives in the skill because the skill is the only writer of a brief.
`rules/claude-files.md` keeps the lifecycle it already holds, one file per project, empty as its resting state, overwritten whole, one prompt at a time.

## The trigger is section 0.2 of `commit`, not a git event and not a phrase

**A git event cannot carry it.** Measured on 2026-11-08 over 105 transcripts: 93 sessions commit, median 8 commits, maximum 63; 99 % of sessions continue with a user turn after the first commit and 73 % with more than two; 62 % still carry a user turn after the **last** commit, 28 % more than one, 20 % more than two.
A hook has no lookahead, so a trigger on a commit's passage fires at the first of a median eight, and even an oracle firing on the last would be wrong 62 % of the time.

**A phrase cannot carry it either**, and that is the user's own complaint: the locution is a manual step they want gone.
Two false positives of `closure-check.sh` were observed on 2026-11-08, on two consecutive messages that were *about* the locution rather than posing it.

**Section 0.2 is the only point where the end of the session is known**, since it already demands, at every invocation, either a recommendation on what comes next or an explicit statement that nothing remains.
That statement is the branch decision.
Its lever is an instruction, the weakest by the ruling of `ANTI-SYCOPHANCY-PLAN.md`, with one difference that is measured here: an instruction in the body of a skill the model is executing holds, 94 of 105 transcripts carrying at least one `writes.sh` call at a median of 2 passes, where the rules of `CLAUDE.md` that this chantier replaced held at 31 % contestation.

**Cost of making 0.2 the single decider.** `commit` is invoked mid-session, so 0.2 rules on "is the session over" about eight times a session and must route only on the "nothing remains" branch.
A wrong "closable" costs one reread of one to eight files and a brief nobody consumes, both visible.
A missing conclusion fires nothing, and the fallback is the user's question through `closure-check.sh`.

## `ending-gate.sh` gains nothing, and `closure-check.sh` becomes a router

The symmetric clause considered was a refusal of a response that asserts the session closable without `handoff` having been invoked.
Its deterministic half is a per-session marker under `$XDG_RUNTIME_DIR`, as `commit-gate.sh` and `write-journal.sh` already keep one.
Its other half, recognising that a response asserts closability, is a list of natural-language wordings over the model's own output, which is the family measured on 2026-09-29: precision 0.299 and recall 0.212 for "offer", precision 0.867 and recall 0.063 for "close".
A list in that family buys too little to pay for a gate, and `feedback_no_literal_matching_on_natural_language.md` rules against it.
The route that would be deterministic, firing when commit blocks are delivered with no handoff marker, is refuted by the same lookahead measurement: it would demand a handoff at the first of a median eight commits.

`closure-check.sh` stays, for the 90 % of sessions where the user still asks and as the net under the instruction lever.
Its injected reminder, which today carries the whole procedure, duplicates the skill once the skill exists and shrinks to a routing line sending the model to `handoff`.
That also makes the two false positives cheap: firing on a message about the locution then costs a reread, not a wrong answer.
Narrowing its regex further is not attempted: distinguishing a message about the locution from one posing it is the same natural-language problem as above.

## Rejected approaches

- **No new skill, `commit` 0.1.4 extended into an unconditional closing pass.** The brief contract would load at every mid-session commit, a median of eight a session, and the 12 sessions in 105 that commit nothing would lose any entry point, where the user asks for an explicit `/handoff`.
- **Two skills, `close` routing to `handoff`.** The branch criterion would live in two files and the decision would return to the caller, which is where it is lost today.
- **Doing nothing, keeping the locution and the hook.** The user stays the mechanism, and the 117 post-pass paths of 150 that no list prints stay unread by anything.
  The ritual's productivity makes the hole real: 194 relances over 95 sessions on 2026-11-08, 117 of them followed by a tracking edit, and 74 of the 95 sessions with at least one relance that produced one.
- **A `Stop` hook as the trigger, instead of section 0.2.** Refuted by the 62 % of sessions carrying a user turn after their last commit, and by the precision of the only detector a hook could use.
- **`commit-stale.sh` as the source of the reread's scope.** It filters 117 of the 150 post-pass paths, including both carriers of the defects of 2026-11-08.
- **A self-reread by the thread that wrote the files.** The chantier's own finding on axis 1, and the reason the verifier runs in a subagent.

## Measurements this note now holds

The figures of 2026-11-08 lived only in `.claude/HANDOFF.md`, a buffer overwritten whole, so they are recorded here.
They are **not comparable to the measured baseline** of 2026-09-22 in `PLAN-SESSION-DISCIPLINE.md` (34/79 sessions with a closure relance, 40 relances): different patterns, a different window, and no filter on session length.

```
| Measure (2026-11-08, 105 transcripts)                          | Value        |
|---|---|
| Sessions carrying a message matching the closing locution      | 95 (90 %)    |
| Closure relances in all                                        | 194          |
| of which followed by an edit to a tracking file                | 117 (60 %)   |
| Sessions with at least one relance that produced one           | 74/95 (78 %) |
| Sessions writing a `PROMPT*.md` or `HANDOFF*.md`               | 46 (44 %)    |
| Project `.claude/` directories holding a buffer                | 11           |
| Sessions with at least one commit                              | 93           |
| Commits per session: median / max                              | 8 / 63       |
| Sessions continuing after the first commit                     | 99 %         |
| with more than two further user turns                          | 73 %         |
| Sessions with a user turn after the last commit                | 62 %         |
| with more than one / more than two                             | 28 % / 20 %  |
```

The locution figure is the prevalence of the pattern under a reduced copy of the hook's own regex, replayed on the transcripts that regex was fitted on, so it does not answer step 4 of the plan: the recall of `closure-check.sh` needs a ground truth built independently of it.
"Followed by" is not "caused by" in the 60 %; the two defects of 2026-11-08 are what give that figure its mechanism.

## Open

- **The `Unknown skill` of 2026-11-08 was a missing link, not a scan window.** The reduced `closure-check.sh` fired on the user's locution as designed and asked for the skill, and both `handoff` and `claude:handoff` came back `Unknown skill` from the `Skill` tool, which was first attributed to the harness having scanned the skills directory before the file existed.
  The cause, found at 21:04 the same day: `~/.claude/skills/` is a real directory carrying one symlink per skill, as `rules/install.md` prescribes for the `claude` package, and `stow claude` had not been rerun after the skill directory was created, so the path the harness scans held no `handoff` at all and the next session's skill list missed it too.
  `stow -n -v claude` named that single link and nothing else; it was created at 21:06, and the `Skill` listing gained the skill inside that same session, with no restart, so a skill is invocable as soon as its link exists.
  The procedure of 2026-11-08 was then run by hand, in its own order, and reported an empty scope, so the first end-to-end test of the routing still belongs to a session that did not build the chain.
  What step 4 inherits is narrower than "a session cannot measure a mechanism it has just created": a new skill directory needs its `stow` pass before any session sees it.
- **The recall of `closure-check.sh`** stays owed to step 4 of `PLAN-SESSION-DISCIPLINE.md`, and the deliberate freeze it now demands.
  Reducing the hook to a router changes its injected text, not its trigger, so the measurement is unaffected.
- **Whether section 0.2 concludes at the right moment** is the weakest assumption and is untested: it can only be judged at the step 4 remeasure, which must account for this change as it accounts for the two corrections of `DESIGN-CADRER.md`.
- **A brief written outside the skill** reached the content contract through nothing, the contract living in the skill, and the condition this was acceptable under was already false: the `CLAUDE.md` bullet on prompts made the session a second writer, unasked at a context limit.
  Closed 2026-11-08 by the audit, with the user's ruling on the scope: that bullet now names the skill as the only writer and sends the model to invoke it at a session boundary as at closure.
  The always-loaded budget bounded the wording, the file sitting at 12250 bytes of 12288 before the change and at 12284 after, so the next addition to `CLAUDE.md` names what it displaces.
- **A `/clear` earlier in the session** moves the session id, so its writes sit in a journal the tail never opens. Step 0.1.1 of `commit` unions `git status` for that case and this pass does not, and the ignored `.claude/` paths escape that union anyway, so the residual is named in section 1 rather than closed. Added by the audit of 2026-11-08; a post-`/clear` context cannot enumerate what the earlier one wrote, so no mechanism is proposed.
- **A write made through Bash or by hand** is absent from the journal, so the reread's tail misses it.
  `CLAUDE.md` forbids shell writes, and `git status` catches the unignored ones, which leaves an ignored `.claude/` file written outside `Edit` and `Write` as the residual.
- **The `description` stays closure-shaped**, and deliberately since 2026-11-08: its clauses all name the end of a session, while branch-2 reasons 2 and 3 are not closure-shaped, so the audit asked for a session-boundary trigger clause.
  Declined under "Test the premise before building": the `CLAUDE.md` bullet closed at the same audit is always loaded and already sends the model to invoke the skill at a context limit or from another working directory, so the clause would duplicate an always-on mechanism. L1 agreed.
  The residual is a deliberate handover request that is neither of those triggers, "what do I need to resume this in a fresh conversation"; reopen on one that fired nothing.
- **The `handoff` name** is the user's, after Matt Pocock's; nothing in `~/Documents/packages/skills` or this package held that name before 2026-11-08.

## The journal's tail is a tested script, 2026-11-08

**Decision: the computation lives in `claude/.claude/skills/handoff/scripts/tail.sh` with `_meta/tests/handoff-tail.bats`, and section 1 of the skill calls it.**
The shell block the skill first carried was justified by "what `commit/SKILL.md` already inlines in its steps 0.1.1 and 0.1.4", and that precedent does not exist: both fences of that file are script invocations, the logic having already been extracted, and the only inline computation left there is the `rg | jq` of `agents/verifier.md`.
What governs is the approved decision "The shell of the `commit` skill moves into tested scripts" of `DESIGN-COMMIT-GUARD.md`, whose motive applies verbatim: the text of a `SKILL.md` is seen neither by shellcheck, nor by bats, nor by the review criterion of section 0.3 of `commit`.
Its first red test is the one that bit here: an unreadable stamp or journal must exit with an error, never with an empty list, and in this skill an empty list is what section 4 reads as "the pass already covered everything".
Run in the session of 2026-11-08, the block answered a bare `No such file or directory` with no path on stdout, which is indistinguishable from an empty scope.
Drift measured on the twin block: 28 of 31 launches of 0.1.1 conformed, three paraphrased, one losing the union.

**An absent journal is not a failure, corrected 2026-11-08 by the audit.** The script read `[[ ! -r $journal ]]` for both the absent and the unreadable file and exited 1 on each, where `write-journal.sh` creates the log only at its first append, so a session that wrote nothing, the ordinary standalone shape through `closure-check.sh`, was told to announce a failure and rebuild its scope from recall.
`writes.sh` reads the same state as "no journaled path" and continues at exit 0, so the two scripts of one chain disagreed.
The branches are now split: absent exits 0 with a note on stderr, present and unreadable exits 1, and the test that pinned the old contract was rewritten rather than supplemented, so that branch added no test of its own.
The two stderr assertions were tightened at the same time, both having matched on `journal` and so discriminated nothing.

**Two arithmetic and stamp corrections, 2026-11-08.** `((ts > stamp))` read a timestamp carrying a leading zero as octal, printing `value too great for base` and dropping that path at exit 0 without counting it; it is now `((10#$ts > 10#$stamp))`, the form `commit-stale.sh` already uses in `((10#$ctime > stamp))`, which reads `08` as the decimal 8 and so excludes the path on its stated timestamp rather than on an error.
The stamp took the same `-e` against `-r` split as the journal: an unreadable stamp was reported as a missing one and the whole journal became the scope at exit 0, while the skill inferred from that message that no verifier pass had run. It now exits 1 on its own message, so `No stamp file means no verifier pass ran` is true again.
Exit 1 therefore carries four shapes and three of them print nothing.
Rejected at the same pass: that the exit codes are unobservable because the tool merges the streams. Measured in the deciding form, a bare invocation exiting non-zero, the tool prints `Exit code <n>` ahead of the output and exit 0 is the absence of that line, so the contract is readable as written and the section records the measurement.

A parent-directory discriminator was considered, to tell "this session wrote nothing" from "the runtime location is wrong", and rejected: all three scripts resolve `${XDG_RUNTIME_DIR:-/tmp}`, and that fallback always exists, so the test is inert in every drift case.
What remains is a residual the skill now states rather than a guard: `write-journal.sh` exits 0 when `jq` is absent, swallows a failed append under `|| true`, and reaches only its registered tools, so an absent journal never proves nothing was written.
The strict form would be a positive marker, the hook touching the journal at session start, which changes `write-journal.sh` and is left to the user.

Not folded into `writes.sh` as a flag: the rule is not the gate's (section 1 declines `commit-stale.sh` and its `excluded()`), it has one caller, and `writes.sh` sits in the frozen path list of the step 4 preflight.

**What the suite found, and the script now holds.** Tab is an IFS whitespace character, so a journal line opening on a tab collapses to a single field: `IFS=$'\t' read -r ts path` yields the path in `ts` and an empty `path`, and the block's `[ -n "$p" ]` guard dropped it in silence.
The loop therefore counts an empty path as malformed rather than skipping it, and a malformed line prints the valid paths with a count on stderr instead of hiding them.
A truncated write leaves three shapes and not the two claimed here until the audit of 2026-11-08: `read` returns non-zero on a final line carrying no newline, so the loop body never ran for it and the path was dropped at exit 0 with nothing on stderr, which is the silent short list the script's first red test exists to forbid.
The residual test after the loop (`[[ -z $ts$path ]] || malformed=...`) is what counts it; at EOF after a terminated line `read` clears both variables, so a normal pass counts nothing (measured 2026-11-08).
Cross-model split on the finding: L1 `invalid` on the ground that no producer exists, `write-journal.sh` appending one terminated line per `printf`, L2 `valid` on the mechanism. Accepted on the direction of the degradation rather than on its frequency, the fix being two lines and one test.

## Three contract decisions of the audit, 2026-11-08

**The temporary filter names its variables and strips a trailing slash.** `case $path in "$tmpdir"/* | /tmp/*)` let a scratchpad path through when `$TMPDIR` ended in a slash, measured on a `TMPDIR` outside `/tmp`, so the script normalises it and section 1 names `$TMPDIR` and `/tmp` instead of "the temporary directories".
Two further shapes stay uncovered at zero occurrences, by the stop rule of `feedback_review_severity_heuristic_code`: a `$TMPDIR` carrying a glob metacharacter, and one prefixing real work, which would empty the scope. `TMPDIR` is unset on this machine, so the `/tmp` fallback covers every path today.

**A brief names no sha the commit about to run can rewrite.** Point 2 of the contract asks for a sha, a dated measurement or a count, and the brief is composed before the blocks of `commit` section 0.4, so "uncommitted" and a commit count are falsified by the very commit that follows, and a HEAD sha by any later rebase.
The brief that opened this audit carried both defects and the rebase of the same evening proved the second.
Nothing re-checks the brief after 0.4, so the contract now bounds what may be claimed rather than adding a step that does not exist.

**An unconsumed brief the user declines to overwrite goes to a topic-suffixed buffer.** The convention is the repository's own rather than a new one: measured 2026-11-08, `eds-prise/.claude/` carries `HANDOFF.md` plus four `HANDOFF-<topic>.md`, and `R-hebstr/.claude/` carries `PROMPT.md` and `PROMPT-GT.md`.
The same measurement confirms the four non-empty buffers this note already cites and `HANDOFF-COMMENTS.md` at 0 bytes.
It also contradicts `rules/claude-files.md`, which says one file per project holds the prompt; that line is owed a correction outside this skill.

## Implementation of 2026-11-08

Four artifacts, built the same day the design was approved:
`claude/.claude/skills/handoff/SKILL.md`, whose five sections are the decision's five procedural halves;
section 0.2 of `claude/.claude/skills/commit/SKILL.md`, which carries the routing and names itself the only point where the end of the session is known;
the `reminder` of `claude/.claude/hooks/closure-check.sh`, reduced from the whole procedure to a routing line, with the `assert_injects` substring of `_meta/tests/closure-check.bats` following it;
and the `!DESIGN-HANDOFF.md` line of `.claude/.gitignore`.

Two more the same evening, from the decision above: `claude/.claude/skills/handoff/scripts/tail.sh` and `_meta/tests/handoff-tail.bats`, the suite written red first (12 failing on the absent script) and green at 13 once the IFS shape was added.

Gate: `shellharden`, `shfmt -d -i 2` and `shellcheck` clean on the hook, `bats _meta/tests/closure-check.bats` 28/28, `_meta/tests/instructions-budget.bats` clean, and both touched frontmatters parse under `yaml.safe_load`.
The script passes the same three tools and `bats _meta/tests/handoff-tail.bats` 19/19, the audit of that evening having taken the suite from 13 to 19.
The opencode `skill` permission map in `opencode/.config/opencode/opencode.json` defaults to `"*": "allow"`, which is what an auto-invoked certification carrying no git write wants, so nothing was owed there on 2026-11-08.
The mirror was: the audit of that evening changed the prompt bullet of `CLAUDE.md`, and `AGENTS.md` carried the same rule in its skill-free form, so its line now names the skill as the only writer too, by the rule of [[project_opencode_agents_md_mirror]]. Found by the verifier, this note having claimed the change touched no rule of `CLAUDE.md`.
