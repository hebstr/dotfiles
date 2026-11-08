# DESIGN-COMMIT-GUARD.md

The commit guard: the write journal, the stamp and its content snapshot, the `Stop` gate, the `PreToolUse` guard on `Bash`, and the `commit` skill with its verifier and its scripts.
Split out of `PLAN-SESSION-DISCIPLINE.md` on 2026-10-15, where it was « Implémentation du noyau (étape 3, sous-étapes 1 à 4) ».
That plan keeps what opened the chantier and is not this mechanism: the baseline count, "Framing of step 3", the steps, and the step 4 remeasure whose window start the decisions below kept moving.

The artefacts: `claude/.claude/hooks/write-journal.sh`, `commit-gate.sh`, `commit-stale.sh`, `git-write-guard.sh` and `git-write-guard.jq`; `claude/.claude/skills/commit/` with `agents/verifier.md`, `scripts/writes.sh` and `scripts/transcripts.sh`; their suites in `_meta/tests/`; and the mirrors in `claude/.claude/settings.json`, `opencode.json` and `opencode/.config/opencode/AGENTS.md`.
Current behaviour is in those files and their suites.
What follows keeps the decisions, their rejected alternatives, the limits that still bind, and the fourteen walkthrough records.

Three live `DEFERRED.md` rows sit against it: the `git mv` or `git rm` performed during a session (2026-10-04), ownership evidence not reaching a memory file (2026-09-30), and `unsealed` not telling a live peer session from an ended one (2026-09-30).

## Verifier and stamp

The prompt `claude/.claude/skills/commit/agents/verifier.md` has been in English like the skill since their translation of 2026-09-24, and so has the report since the fidelity review of the same day (`.claude/DESIGN-CADRER.md`).
The content, the parameters and the mechanics of the stamp are in `verifier.md`, `SKILL.md` and the scripts; what follows keeps the rejected alternatives and the limits that still bind.

- **Decision (2026-09-22): the verifier writes the stamp, not a `SubagentStop` hook.** The official doc (`code.claude.com/docs/en/hooks.md`, section SubagentStop, read on 2026-09-22) gives `SubagentStop` `agent_id`, `agent_type`, `agent_transcript_path` and `last_assistant_message`.
  `agent_type` identifies the type (`general-purpose` here), not the verifier among the other agents of that type.
  Identifying it would take either a dedicated agent type, which the framing rules out, or reading its transcript, whose format is undocumented.
  `last_assistant_message` does not fit either: since 2.1.271, a subagent that hands its report back through `SubagentHandback` leaves only its closing text there.
- **Decision (2026-09-23): section 5 of the verifier closes every "to do" announcement of a live passage, whoever the actor.** The evidence comes from the project's transcripts rather than from a session summary, which keeps a fresh context intact: a review is a conversation event, not a write, and the verifier rereads only what the session wrote.
  Rejected ways: **doing nothing**, which covers only Claude with a write and the `/audit:` reviews, where the user's action outside the session is in scope; **closing at the source** (step 4c of `/audit:walkthrough`, a rule per actor), with no actor for an action outside the session; **verification at reading time** (`CLAUDE.md` and step 0.2 of `commit`), which rests on an instruction of the same kind as the one violated in the incident of 2026-09-23, given in the session's own context, and which closes only what is read; **closing by `/audit:walkthrough` itself**, outside this repository.
  Rereading the whole tracking is ruled out (434 KB for the dotfiles' `.claude/` alone, measured on 2026-09-23), hence the extraction of the live passages.
  Trade: closing follows the cadence of the `/commit` passes, not that of the readings.
  Superseded on 2026-09-30 by the section "Section 5 of the verifier runs once a day per repository, not once per pass": closing now follows the daily cadence, one pass per repository per day, and a pass abandoned after step 0.1.1 has spent the day's sweep.
  Framing assumptions, unchanged ("Framing assumptions" of `PLAN-SESSION-DISCIPLINE.md`): the absence of evidence closes nothing and is never flagged; an announcement is dated by the date written in its passage, the files of `.claude/` having no git history; each repository closes its own `.claude/` at its own `/commit`.
- **Limits of section 5, which still bind.** The retention (`cleanupPeriodDays` at 7) bounds the evidence to a week, so the absence of an invocation is worth nothing.
  An announcement in prose with no `/audit:` command escapes the `rg`: the `sys-cleanup` case of `PLAN-ORPHANS.md` carried both limits at once and would not have been flagged.
  The memory stays outside the section's scope.
  The transcript format is undocumented, but a drift in it produces no invocation, hence no finding, never a false block.
- **Weakest assumption**: a `/commit` runs in the repository between the action and the next reading that relies on it; if sessions open on a recommendation drawn from stale tracking before any `/commit`, the damage happens in that interval, and the lever then becomes verification at reading time, which this decision does not rule out.
  The frequency of sessions closed without a `/commit` is not measured.

## Section 5 of the verifier runs once a day per repository, not once per pass (design approved on 2026-09-30)

**Decision: the live-to-do sweep of `verifier.md` section 5 runs on the first pass of the day in a given repository and is skipped by the others; the sweep itself is unchanged.** `writes.sh` reads a dated marker, prints the flag and posts the marker; `SKILL.md` passes it in the agent prompt; section 5 of `verifier.md` opens on that condition. The user approved on 2026-09-30, and separately approved implementing it at once rather than deferring it past step 4.

**Why: a pass costs the same on a two-file commit as on a fifteen-file one, and the fixed part is the section whose yield has gone to zero.** Measured on 2026-09-30 over the retained transcripts (2026-09-23 to 2026-09-30), 133 passes with a duration, 88 with a `WRITES` list readable from the agent prompt. Chain: `commit_sessions.py`, then `verifier_cost.py`, `verifier_size.py`, `verifier_phase.py`, `verifier_yield.py` and `verifier_trace.py`, the last four written and archived that day (bullet "Measurement scripts" of `PLAN-SESSION-DISCIPLINE.md`). Every figure below re-derives from them while the transcripts last, which is until 2026-10-07.

Current regime, 2026-09-27 to 2026-09-30, `claude-opus-5` at effort `high`, n=36, median 576 s:

```
|W| <= 4     n=9    median 529 s   q1 448  q3 580
|W| 5-9      n=10   median 624 s   q1 496  q3 674
|W| >= 10    n=17   median 576 s   q1 448  q3 746
```

The previous regime, 2026-09-23 to 2026-09-26, n=52, still had a gradient over the same buckets: 162 s, 209 s, 285 s. The fixed part went from about 150 s to about 500 s and swamped the variable part. Model time is 81 % of wall (19 % tool execution) over 138 transcripts and 14.4 h in all.

Where that fixed part goes, bracketing the section 5 phase by its first characteristic command (`transcripts.sh`, the `next|blocker` heading sweep, `DEFERRED.md`, `git log --since`) over the 48 passes since 2026-09-27: median 150 s before it (33 % of wall), median 281 s from it to the stamp (57 %). The 57 % over-attributes, sections 1 to 4 interleaving after the sweep starts, and classifying by command shape alone gives 10 % as the floor; the full trace of the 2026-09-30 pass (582 s, 46 calls) puts the figure near 40 %.

What section 5 returned over the same window: of 129 reports read, 5 open on "no findings", and the reports whose `Findings` section carries a section-5 signature run 2/18, 16/28, 3/15, 9/27, 5/13, 0/12, 1/16 from 2026-09-23 to 2026-09-29, for 2, 37, 3, 10, 5, 0 and 1 marks. It cleared a stock on 2026-09-24, then the flow dried up: 6 marks over the last 41 reports (2026-09-27 to 2026-09-29), of which 1 over the last 28, against 37 on 2026-09-24 alone, so 0.15 marks per report against 1.32.

The closing pass of the session that wrote this section, on 2026-09-30, adds one point to the series: 525 s, 175k subagent tokens and 53 tool calls on a ten-path `WRITES` list, 7 of them outside `.claude/` and memory, against a median of 576 s for the `|W| >= 10` bucket as the table above stood.
Folding that pass in moves the corpus to 134 passes and 89 readable `WRITES` lists, and moves the `|W| >= 10` cell alone to 550 s over n=18, the other two cells unchanged: the table is the snapshot of that morning, the counts grow with every pass run afterwards, and the flatness the decision rests on holds either way (529 s against 550 s).

Two earlier records of the same series, kept because the aggregate above holds neither the within-session growth nor the state of section 5 on the day it was built, and because the 7-day retention makes both unreproducible after 2026-10-05. From 2026-09-28: one session ran three passes, 577 s, 657 s and 816 s, for 171k, 171k and 166k subagent tokens and 34, 34 and 33 tool calls, the third covering a single new 72-line script plus two tracking files. From 2026-09-23, when section 5 was built: 407 s, 48 tool calls and about 180k subagent tokens at the first pass, 321 s, 43 calls and about 155k at the second.

Precedent: `inject-rules.sh` already carries this pattern, its `marker` under `${XDG_RUNTIME_DIR:-/tmp}` and its `injected()` test delivering each rules file once per session, and its `log_dir` under `${XDG_STATE_HOME:-$HOME/.local/state}/claude-code` being where state that must survive a reboot goes, which a daily cadence needs. `writes.sh` computing the flag rather than the agent follows the "one rule, one computation, several callers" precedent of `commit-stale.sh`, set in the section "The shell of the `commit` skill moves into tested scripts".

**Rejected.**
- **Doing nothing and closing the point**: the only approach that moves no window, and it neither loses nor gains anything; about 6 h of agent time over the three days 2026-09-27 to 2026-09-29, a third of it on a section that returned 6 marks over those 41 reports.
- **Restricting section 5 to the passages changed since the previous stamp**: it contradicts the written premise of section 5, "the action that carries out a to-do item often writes nothing in the file that lists it", so it forecloses exactly what the section exists to catch.
- **Two agents, sections 1 to 4 in the foreground and section 5 separately or in the background**: two launches, two prompts and a stamp to arbitrate between them, where `SKILL.md` prescribes the foreground deliberately; the second agent rereads the same corpus, so the saving is on price and not on wall time unless it goes to the background.
- **Lowering the verifier's model or effort**, the original framing of decision 5 of "A session is refused only for content its commit takes unverified": its A/B needs a ground truth on verifier findings, which does not exist, and building one is the `ending-gate` bench pattern. The cadence lever needs no bench, changing when the sweep runs and not what it finds.

**Weakest assumption, tested.** That a section-5 item persists between two sweeps, so a skipped pass delays a finding instead of losing it.
Checked on 2026-09-30 against the four leftovers of the 2026-09-26 pass: all four are still in the tracking, four days and about 80 passes later. `PLAN-PYREFLY.md` still lists `/audit:blindspot claude/.claude/rules/environment.md` with no note although `rules/environment.md` was deleted in `daa2729`; `PLAN-LUA.md` carried "3.8.3" in four places until the prune pass of the same day repaired it; `DESIGN-BATS-HOOK.md` still carries "two green runs".
If it fails, it fails on an item created and carried out the same day whose passage is deleted before the next sweep. That deletion is itself a tracking write, which sections 1 and 3 see at the pass that carries it.

**Trade.** A same-day catch, against about 40 % of every pass after the first of the day.

**The window cost, priced before the call.** The change edits `writes.sh`, `SKILL.md` and `verifier.md`, all three in the frozen path list of the preflight of 2026-09-28, so no approach but "do nothing" avoids moving the step 4 window start. Precedent exists both ways: the shell-search point was deferred past step 4 on 2026-09-22 so as not to change the measured behaviour mid-window, while the start itself has moved about twenty times since 2026-09-24 and step 4 has never run. The user chose implementation now, on the recommendation that the pass cost is paid daily, about twelve passes a day in dotfiles, where the window move is paid once, and that "after step 4" has no date while the window keeps moving for other reasons.

**Open.**
- The two levers decision 5 named beside the sweep, model and effort, stay unmeasured and undecided: no bench of verifier findings exists, and nothing here builds one.
- Whether the daily cadence holds when a repository sees a single pass in a day, where every pass is the first of its day and nothing is saved, is not measured; the 2026-09-27 to 2026-09-30 distribution has 33 dotfiles passes over 4 days, 12, 8, 12 and 1, which is the full count and not the readable-`WRITES` subset the size buckets run on.

### Implementation (2026-09-30)

`claude/.claude/skills/commit/scripts/writes.sh`, its `SKILL.md` and `agents/verifier.md`, plus `_meta/tests/commit-writes.bats`: the scope the decision sets, and the sweep itself unchanged.
`writes.sh` prints `SWEEP=yes` or `SWEEP=no` after `STAMP_VALUE` and before the `WRITES` list, then posts the marker it just read.
`SKILL.md` passes `SWEEP` in the agent prompt beside `REPO`, `WRITES`, `STAMP_FILE` and `STAMP_VALUE`; section 5 of `verifier.md` opens on it and, on `no`, reports the single line `Section 5: skipped, SWEEP=no` under the `Greps`, so a skipped sweep tells itself apart from a sweep that found nothing, for `verifier_yield.py` as for the reader.

**The marker is keyed by the repository root alone**, the first of the two forms the section left open: `${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/verifier-sweep-<first 16 hex characters of the sha256 of the root>`, holding the date and the root, tab-separated.
`XDG_STATE_HOME` is per machine already, so a root-and-machine key would differ only if that state moved under `~/dotfiles`, which nothing proposes; the root is written beside the date to make the file readable while debugging, and only the date is read back.

Every degradation leaves the previous cadence rather than blocking: no git root gives no key, so `SWEEP=yes` and no marker; a marker that cannot be written gives a notice on stderr, `SWEEP=yes`, and a sweep again at the next pass of the day.
`--restamp` prints no flag and posts nothing, the flag being read once per pass, at step 0.1.1.
Known limit of posting at 0.1.1 rather than at the end of the pass, which the approved design sets: a pass abandoned after that call has spent the day's sweep, and the next one skips section 5 although nothing swept.

Gate: `shellharden --replace`, `shfmt -w -i 2` and `shellcheck` clean on `writes.sh`; `commit-writes.bats` 25/25, against 18 tests before, the 7 new ones covering the flag, the marker, its key and the two degradations; the whole `_meta/tests/` 1479/1479.
Committed in `463f3d3`, whose closing `/commit` was the first pass run under the new cadence: `SWEEP=yes`, marker posted, and `--restamp` printed no flag.

## The verifier's model is pinned and a failed seal is loud (approved on 2026-10-01)

**Decision: `SKILL.md` step 0.1.2 pins the verifier to `sonnet` in the call, and `--seal` stops reporting success when a path it was named did not reach the snapshot.** Approved by the user on 2026-10-01, implemented at once rather than deferred past step 4.

**Why the model pin, the ground the cadence section lacked.** That section rejected the model and effort lever for want of a ground truth for an A/B. The new fact is not a measurement but a constraint: the user declared the current cost unviable for a per-commit gate on 2026-09-30. The four days before 2026-09-27 are the observation an A/B would have produced, so none was built. The pin also removes a coupling the cost tables never named: without it the gate's cost is a function of the model and `effortLevel` the user happens to be running for their own work, so the same commit costs a different amount depending on an unrelated setting.

**Why the seal, and what one event it was.** `resealed[$real]=1` was set before `d=$(digest "$real") || continue`, so a digest failure both skipped the new entry and suppressed the carry of the old one, unsealing the path in silence, while `--restamp` printed a new stamp and exited 0 and `SKILL.md` reads that exit code as the signal. Two code sites, one cause.
The seal now records the path only after a successful digest, so a path it cannot read keeps its previous seal, and it exits 4 when any named path did not reach the snapshot. `writes.sh` already propagated a non-zero seal without writing the stamp; what it gained is a second notice, the existing one ("could not record the snapshot, so the stale check falls back to ctime") being false for this case, where the snapshot was written and one path is missing from it.

**One tested behaviour deliberately flipped.** A path holding a tab is a named path that cannot be recorded, so by the general form of the rule it now exits non-zero too, where the suite previously pinned a silent exit 0 on it. `commit-stale.bats` case "counts a path holding a tab, which the seal cannot record and reports as not recorded" carries both halves.

**`--only` now normalises with `realpath -ms`**, which is identity for its only caller (`git-write-guard.sh`'s `take()` pushes two already-absolute specs, the parent resolved with `-m` plus the raw basename, and the fully resolved path). It closes a fail-open of its own: a relative path missed the snapshot lookup, found no journal owner, and fell through `*) return 1`, so a sealed file that had since been modified was reported as nothing.

**Rejected: a runtime readback after sealing.** Recorded in the bullet "The seal keyed on the raw path string" of "Open points" with its two reasons (`excluded` makes it silent where the gate is silent, and its failure path is unreachable by construction), and replaced by a bats case pinning the same invariant.

Gate: `shellharden --replace`, `shfmt -w -i 2` and `shellcheck` clean on `commit-stale.sh` and `writes.sh`; the four suites 248/248 against 241 before, and the whole `_meta/tests/` 1519/1519.
Of the seven new cases, three were seen failing against the pre-fix script ("--seal --carry keeps the previous seal of a named path whose digest fails", "--seal exits non-zero when a named path was not recorded", "--only normalises a relative path, so a modified sealed file is still reported").
The other four were not: "--seal keeps the previous snapshot when a named path was not recorded" passes either way, the cleanup loop already keeping the snapshot the stamp names; the symlink case is a contract pin whose subject, the `-ms` normalisation, is identity on its absolute input, so it cannot distinguish the two scripts; and the two `commit-writes.bats` cases were derived rather than measured red, a probe against the pre-fix script having been refused twice at the permission dialog, their expectation resting on the recorded probe above (exit 0, snapshot holding `a.sh` alone).

Committed in `f459966`, which was the step 4 window start at the time.

**First pass under the pin, measured at this section's own closure.** 68 s of wall clock, 67 468 subagent tokens and 6 tool calls, on a six-path `WRITES` with `SWEEP=no`, reporting no findings.
Against the pass the bullet "The seal keyed on the raw path string" of "Open points" records for the previous regime, also `SWEEP=no`: 533 s, 166 808 tokens and 46 calls. About an eightfold drop in wall clock and a 2.5-fold one in tokens.
What that comparison does not establish: it is one pass against one pass, on different `WRITES` (six paths here against four tracking files there), and a pass that finds nothing makes fewer calls than one that finds six, so part of the gap is the finding count rather than the model. The flatness of cost against change size is the one thing already established (the cadence section's table), so the size difference is not what moved it.

**Open.** Whether the daily cadence saves anything in a repository that sees one pass a day stays unmeasured, as the cadence section left it. The pin's own effect on verifier quality is unmeasured by construction, no ground truth existing; what step 4 will see is a window whose every pass ran on `sonnet`, against a baseline that predates the verifier.

## Gate

The gate's computation lives in `commit-gate.sh` and its tests; what follows keeps the decisions named elsewhere, their rejected alternatives and the limits left open.
Since 2026-09-27, a message whose fenced blocks carry a commit line is judged on the paths those blocks take, through `git-write-guard.sh --verdict`; the journal and `git status` check is now only the fallback (section "A session is refused only for content its commit takes unverified").

- **Decision (2026-09-24, walkthrough of `commit-gate.sh`): environment assignments before `git` are part of the commit line.** `SKIP=<hook>` is the prek bypass, and it bypasses a prek hook, not the tracking verification: the blocks it ends are as stale as the others.
  Limit left open: a single-quoted value holding a space is not recognised (`FOO='a b' git commit`, where `FOO='a' git commit` is), the jq program living inside a single-quoted bash string; no occurrence measured.
  A commit chained after anything but `git` (`echo x; git commit`) stays outside the pattern, `cd` and `pushd` excepted since 2026-09-27.
- Measurements behind the pattern and the exclusions, not reproducible (retention): three `git -C ~/dotfiles commit` proposals escaped the gate before the walkthrough of 2026-09-23, while a commit in another repository stays in its scope; `cd <repo> && git commit` had no measured occurrence on 2026-09-23 and one on 2026-09-27; 237 of the 356 Write/Edit of 2026-09-22 aimed at `/tmp/`, hence the exclusion of paths outside a git tree; of 531 Edit/Write paths outside `.claude/` and `/tmp`, a single one was ignored by its repository (the `README.md` that `quarto-hebstr-slide` ignores on purpose), hence the exclusion through `git check-ignore`, an error of which leaves the path counted.
- Why tracking is defined by the root and not by the name: the `.claude/` of another directory stays code, since in the dotfiles `claude/.claude/hooks/` and `claude/.claude/skills/` are exactly what the gate must see; the git root is added to `CLAUDE_PROJECT_DIR` without replacing it, so that a nested subproject keeps its own `.claude/` exempt.
  Since 2026-09-27 that rule holds in the fallback only.
- Known limit: `last_assistant_message` is only the turn's final text (the hooks doc), so blocks followed by a tool call and then a closing sentence escape the gate.
  The section "3.
  Deliver" of `commit` ends on the blocks, which closes the prescribed case; reading `transcript_path` for the rest is ruled out, the format being undocumented.
- **Decision (2026-09-23): the gate unites the journal and `git status`.** Intended consequence, which still holds: in a fresh session, any modified tree forces a `/commit` pass before the first commit block, the stamp being specific to the session, and a missing journal no longer makes the gate exit 0.
  The other repositories stay covered by the journal alone.
  A deleted path counts as long as no stamp exists in the session, and no longer afterwards.
- **Decision (2026-09-23, walkthrough of `commit-gate.sh`): `ctime` instead of `mtime`.** `rename(2)` keeps the `mtime`: after an `mv` run through Bash once the stamp was written, the destination kept an earlier `mtime` and the deleted source no longer counted, so the gate let the rename through (measured).
  `stat -c %.9Z` cannot be backdated, where `touch -d` falsifies an `mtime`.
  A `chmod` after the stamp blocks too, which is intended since git tracks the executable bit.
  Rejected way: comparing the parent directory to catch pure deletions, which would block on any entry added or removed beside them.
  Since 2026-09-25, `ctime` is only the fallback: the decision "the stale check compares content, on the paths the commit takes" compares content whenever a snapshot matches the stamp.
- **Decision (2026-09-23, same walkthrough): no second block in the continuation.** The gate never reblocks in the continuation it triggers, even on a code path left stale, because a second block would relaunch the verifier (5 to 7 minutes) every time up to the ceiling of 8 consecutive blocks Claude Code imposes.
  Variant rejected for want of a consumer: reblocking if the stale set has changed, step 0.1.3 already reporting to the user the findings that bear on code.
- **Decision (2026-09-23, same walkthrough): `git --no-optional-locks status`.** The gate runs just before the user launches `git add` or `git commit`, so its `git status` does not take the optional index lock, as git's documentation (`GIT_OPTIONAL_LOCKS`) recommends for a background process.
  The skill's calls run in the foreground, where the flag has no effect.
- **Decision (2026-09-23, walkthrough of `ending-gate.sh`): the loop guard is specific to the gate.** `stop_hook_active` is a single field for every `Stop` hook, so the guard skipped the gate on every continuation `ending-gate.sh` triggered, which is exactly where the reason of the "close" family sends the model into `/commit`.
  The gate therefore writes its own marker when it blocks, consumes it on its own continuation and checks another hook's continuation normally.
  The loop stays bounded: one block from `ending-gate`, then at most one block from the gate, then the exit 0 that consumes the marker.
  Residual: if `ending-gate` blocks in turn in the gate's continuation, the next continuation is checked again, which can relaunch `/commit` once more on blocks still stale.
  `ending-gate.sh` keeps `stop_hook_active`: an offer unseen in the gate's continuation costs nothing lasting.

## The `commit` skill

- **Decision (2026-09-24): the commit header is short**, a rule of "3.
  Deliver" of the skill, mirrored in `opencode/.config/opencode/AGENTS.md`.
  Rejected: a feedback memory, which loads only when its description looks relevant, and a line in `CLAUDE.md`, since the skill is the only producer of the message in Claude Code.
  Deferred: a check in `commit-gate.sh` rejecting a `git commit -m` header over 72 characters, to build only if an overlong header recurs once the rule is in place.

- **Decision (2026-10-16): step 0.1.4 sends content written after the verifier's pass back through 0.1, instead of letting `--restamp` seal it.**
  The flag is for the paths an applied finding targets; used on tracking written after the pass, it satisfies the gate while skipping the check, which is how the `.claude/PROMPT.md` of 2026-10-01 cited a sha resolving in neither the repository its reader would use nor as the commit it described, caught only because the user asked a second time whether the file was up to date.
  A prohibition on naming such a path would not have reached it: `commit-stale.sh` filters the ignored paths and the `.claude` repository ignores the prompt buffer whatever its name (`HANDOFF*.md` since 2026-11-08, `PROMPT*.md` before it, and here under the `*` allowlist either way), so that file is printed in no stale list and taken by no commit block, hence crosses no gate.
  Written as a second pass over the new paths alone rather than a full re-verification: `writes.sh` with no flag reseals at current content, every path unchanged since the previous stamp having already been read, and `SWEEP` comes back `no` on the day's second pass, so section 5 of the verifier does not run again.
  The flag's own paragraph keeps the prohibition alone, the procedure living once in the paragraph that already handles every printed path no finding targets.
  Rejected on 2026-10-01 and still rejected: a checker for a sha that resolves nowhere.
  Of the 113 shas asserted across `.claude/*.md`, 16 resolve in neither local repository, 11 of them session or transcript ids (8 hex, against git's 7) and 5 legitimate commits of other repositories, so the rule fires 16 times with no true positive.
  The prose half of the incident is the seventh rule of `feedback_verify_before_claiming.md`.
  Not mirrored in `opencode/.config/opencode/AGENTS.md`, which has neither verifier nor stamp.

- **Decision (2026-10-16): every commit block of "3. Deliver" opens on `cd <project> && `, as section 5's nested block already did.**
  The Bash tool keeps a `cd` across calls and this skill changes directory before it delivers (the stale check of 0.1.4 runs `cd`-ed into the repository it reads), so an unprefixed block ran wherever the last probe left the shell.
  On 2026-10-15 the working directory had drifted to `~/dotfiles/.claude`, so the parent's `git add . && git commit` committed the `.claude` work under the parent's message and swept in `DESIGN-AGENT-SKILLS.md` and `DESIGN-POC.md`, two files another session had left dirty and that the proposal had explicitly excluded.
  Recovery took `git reset --soft HEAD~1`, a `git restore --staged` of the two foreign files and a recommit, all of it the user's to run, `reset` being outside the skill's four verbs.
  The mechanism did not fail: by "Authorship of a dirty file comes from the write journals", a dirty file no journal names reads as the user's own edit and never blocks.
  What each mechanism reads on each shape, measured on 2026-10-15 in a scratch parent repository holding a nested `.claude` one, both sealed, one parent file modified after the seal:

  ```
  | Parent block                                | cwd                   | Guard, PreToolUse            | Guard --verdict, which the gate calls              |
  |---------------------------------------------|-----------------------|------------------------------|----------------------------------------------------|
  | `git add . && git commit`                   | project root          | names the changed file       | names it alone; with the section 5 block, exits 1  |
  | `cd <project> && git add . && git commit`   | project root          | names the changed file       | same                                               |
  | `git add . && git commit`                   | drifted to `.claude`  | passes, nothing reported     | nothing reported, with or without that block       |
  | `cd <project> && git add . && git commit`   | drifted to `.claude`  | names the changed file       | exits 1 with that block, names the file without it |
  ```

  Reading of the table: the prefix costs nothing at the gate, whose `--verdict` already exits 1 on a response holding commits in two directories, which is every response section 5 renders a block in, falling back to the whole-`git status` check on `${CLAUDE_PROJECT_DIR:-cwd}`.
  What it buys is the guard's per-path check against the right repository once the shell has drifted, where the unprefixed form fails open at both mechanisms.
  The two-directory refusal never bites at execution, section 4 running one Bash call per block.
  That the drift is routine rather than incidental was recorded on 2026-10-16, when no transcript would hold it: in one session the working directory alternated between `~/dotfiles` and `~/dotfiles/.claude` about ten times, and all three commit blocks landed in the intended repository only because each carried an explicit `cd`.
  Prescribed on the bullet that governs every block rather than on the `git add .` one the note first named, since drift breaks an explicit pathspec identically (`git-write-guard.bats`, "resolves a pathspec from the directory a cd leads to").
  Nothing pinned the unprefixed form: no suite reads `SKILL.md` (`agent-skills-update.bats`, `skill-mention.bats` and `opencode-skills-sync.bats` name it, none of them the gate's or the guard's), while `git-write-guard.bats` pins the prefixed shape as read and allowed, by "checks the repository a cd leads to, not the directory of the session".
  Mirrored in `opencode/.config/opencode/AGENTS.md`, whose run bullet now admits `cd <project> &&` beside `cd <project>/.claude &&`.

## Any agent runs `git add` and `git commit` at closure, each call confirmed in its native permission dialog (design approved on 2026-09-25)

**Decision: one contract for every agent, one adapter per agent.** The contract: the agent displays the commit block, runs it exactly as displayed, one shell call per block, each call going through the agent's own permission dialog, which the model can neither skip nor forge; it stops at the first refusal or failure (a prek hook rewriting a file included) and reports it; every other git write verb is refused by configuration.
Adding an agent takes a native per-call confirmation on `git add` and `git commit` and a configurable refusal on the rest, nothing else.
This overturns the Git rule of `CLAUDE.md` ("Never run git write commands"), the skill intro ("It runs no git write command") and the `AGENTS.md` hard limit ("Never run a git command that writes") for `git add` and `git commit` only.
"Any agent, opencode included" is the user's requirement of 2026-09-25, added after a first, Claude Code only version of this design had been approved the same day.
Each adapter is now in place, in `claude/.claude/settings.json`, `opencode.json`, both `AGENTS.md` and the skill; two of the eight approved points are decisions rather than configuration, and stay here:

- **No `AskUserQuestion` step, in any agent** (developed under "Rejected" below).
- **opencode's "always" answer is accepted and documented, not blocked**: it approves `git commit *` for the rest of the session, a deliberate click of the user's, whereas blocking it would take code on an undocumented plugin event (`permission.replied`).
- Why opencode needs no hook: `"*": "ask"` already closes the rerouted forms, and without a verifier there is no stamp to check.
  The `commit` skill stays at `ask` there, its closing procedure still needing Claude Code's journal, session id and Agent tool.

**What opencode already does, read on 2026-09-25.** `permission.bash` opens on `"*": "ask"` and the last matching rule wins (opencode permissions docs), so `git add` and `git commit` already prompt there and only the `AGENTS.md` instruction forbids them, while the other write verbs sit at `ask`, not `deny`.
The installed v1.18.32 splits a command with tree-sitter and evaluates one pattern per command (`packages/opencode/src/tool/shell.ts` at tag `v1.18.32`), so `git status && git commit` prompts and `git -C . commit` falls to `"*": "ask"`.
"always" saves `BashArity.prefix(tokens).join(" ") + " *"`, which is `git commit *` since git has arity 2, "for the rest of the current OpenCode session" (docs).
Where Claude Code's `ask` rule outranks the allow a "don't ask again" would save, opencode lets that click silence the later commits of the session.

**Why the native dialog carries the confirmation.** Verified on 2026-09-25 in `code.claude.com/docs/en/permissions`: "Rules are evaluated in order: deny, then ask, then allow", so an `ask` rule beats the bare `Bash` allow and any allow rule a "don't ask again" would save.
An `ask` rule matches every subcommand, past any leading assignment, and "still prompts ... even in auto mode".
"Hook decisions don't bypass permission rules": a matching `ask` rule prompts even when a hook returns `"allow"`.
The model can neither skip nor forge the dialog.
`AskUserQuestion`, by contrast, is a tool the model chooses to call and blocks nothing unless a hook reads its answer.

**Why the guard exists.** The same page says a Bash rule "isn't a security boundary around the program": `git -C . push` and `bash -c '…'` escape it.
That hole is measured here: section "Gate" above records three `git -C ~/dotfiles commit` proposals in the transcripts, and with the bare `Bash` allow they would run with no prompt at all.
`commit-gate.sh` is a `Stop` hook that judges the displayed text at the end of the turn, so a commit executed mid-turn escapes it; the stale check in the guard closes that gap with the same computation (`commit-stale.sh`).

**Rejected.**
- `ask` rules alone: the measured `git -C` hole stays open with no prompt, and nothing checks mid-turn that the verifier ran.
- `AskUserQuestion` as the single confirmation, enforced by a `PostToolUse` hook recording the approved command and a `PreToolUse` hook allowing only that text: the `ask` rules must go, since a hook `"allow"` cannot silence them, so the whole guarantee would rest on our script and on undocumented behavior (the hooks reference never names `AskUserQuestion`, nor the shape of its `tool_response`).
A bug would open a silent execution.
- `AskUserQuestion` on top of the dialog: a double confirmation where only the second is guaranteed, and a Claude Code tool opencode does not have.
- A shared `git-commit-run` script as the only execution path in every agent, raw `git add` and `git commit` staying denied: it would centralize the checks, but the command run would differ from the blocks displayed, rendering the blocks in its form would blind `commit-gate.sh`, which detects `git commit` lines, and Claude Code's `git -C` hole would stay open.
- A git hook asking for confirmation on `/dev/tty`: an agent's shell has no terminal, so the question never reaches the user.

**Weakest assumptions.** In Claude Code, the `ask` rules cover the canonical form and the guard covers every other form Claude writes in practice; a form outside both lists (`git 'commit'`) would run unprompted, no occurrence is known, untested.
Since 2026-09-25 the guard refuses a quoted or variable subcommand (decision "every git write verb is gated" below).
In opencode, the evaluation stays per command: the V2 core on the `dev` branch (`packages/core/src/tool/bash.ts`) carries "TODO: Port tree-sitter bash / PowerShell parser-based approval reduction" and matches the whole command string, so an allow pattern on a read verb can cover a chained write.
The `*git add*` and `*git commit*` form of point 6 is the answer to that, at the cost of a prompt on a command that merely contains the text; source read, no live trial.
Whether either dialog renders the command with syntax highlighting is untested; the colored display comes from the ```` ```bash ```` blocks that "3.
Deliver" already requires.

**Left out, still open.** `git add -A`, which "3.
Deliver" forbids, is not refused by the guard: it was not part of the approved point 2, so the skill prescribes something the mechanism does not enforce.

**The prek mechanism behind the content snapshot, measured on 2026-09-25.** prek saves the unstaged changes to a patch before running its hooks and restores them afterwards ("Unstaged changes detected.
Temporarily saving them to ...", then "Restored unstaged changes from ..."), which rewrites every file left for the later commits and moves its `ctime` past the stamp.
A `ctime` check therefore refuses every sequence of two commits or more in a prek repository from its second commit on, and a commit made by anyone in the repository invalidates the verification of every file left out of it.
That is what the next decision answers, and what its weakest assumption rests on.

**Decision (2026-09-25, `/design` approved by the user): the stale check compares content, on the paths the commit takes.** This overturns "`ctime` instead of `mtime`" under "Gate" wherever a snapshot exists, and keeps it as the fallback.
Superseded on 2026-09-27 for the `cd` entry of its fallback list, for `git mv`, for the gate and for its trade, by "A session is refused only for content its commit takes unverified" below.
- `writes.sh` records, beside the stamp, a digest (`sha256sum` of the bytes plus the executable bit, the link target for a symlink, `-` for an absent path) of every path of `WRITES`, headed by `STAMP_VALUE`.
`commit-stale.sh` compares each candidate path's current digest with it when the header equals the stamp, and falls back to the `ctime` comparison otherwise.
A path missing from the snapshot counts as changed when it exists or `git status` lists it.
The restamp of step 0.1.4 of `commit` rewrites the stamp and the snapshot together.
- `git-write-guard.sh` alone restricts the check to the paths the commit takes: what is already staged, the paths the `git add` and `git rm` before it in the same command name (`.`, a directory, `-u`), `commit -a`, and the pathspecs of `commit`.
Anything it cannot resolve (a quoted path, a glob, a `:(magic)` pathspec, a `cd` in the command, `--pathspec-from-file`, an interactive mode, `git mv` in the same command) falls back to the whole `git status`, the conservative side.
- `commit-gate.sh` keeps the whole `git status`, now compared by content: it sees text, not the paths a block stages.
- Rejected: restricting the paths while keeping `ctime` (the files left for the next commit are exactly those prek rewrites); a prek `pre-commit` hook comparing the index with the snapshot (one entry per repository, none in a repository without prek, and a global `core.hooksPath` would disable prek).
- Weakest assumption: prek's restore gives back byte-identical content.
The case after `e839a00` (six unchanged files counted) supports it; a live trial in the scratchpad was refused at the dialog, since it ran `git commit`, so it is untested live.
If it fails, the commit is refused as before, never let through.
- Trade: a file another session creates still blocks a closing response that shows commit blocks, through `commit-gate.sh`; since "4.
Execute", such a response shows blocks only when some are left for the user.

**Decision (2026-09-25, same `/design`): every git write verb is gated.
Superseded for aliases (refused, no longer resolved), the indirection of its weakest assumption, `git update-ref` and the branch-creating forms of `git worktree add` by "Second walkthrough of `git-write-guard.sh`" (2026-09-27).** Each point approved by name:

1. `permissions.ask` gains `Bash(git rm*)` and `Bash(git mv*)`, since "3. Deliver" foresees `git rm --cached` inside a sequence.
   `permissions.deny` gains `git revert`, `git clean`, `git pull`, `git am` and the write forms of `git branch` that a prefix can express (`-m`, `-M`, `-c`, `-C`, `-f`, `-u`, `--move`, `--copy`, `--force`, `--delete`, `--set-upstream-to`, `--unset-upstream`).
   `opencode.json` mirrors both, `*git rm*` and `*git mv*` at `ask` last.
   **Superseded on 2026-10-30 for the two `ask` entries, by the user, deliberately:** `permissions.ask` now holds `Bash(git add*)` and `Bash(git commit*)` alone, so a canonical `git rm` or `git mv`, which `git-write-guard.sh` still lets through, runs with no dialog.
   `opencode.json` keeps `*git rm*` and `*git mv*` at `ask`, so the two harnesses diverge on this point; whether opencode follows is open.
2. `git-write-guard.sh` lets `add`, `commit`, `rm` and `mv` through in their canonical form only, refuses the denied verbs in every form, canonical included, refuses `git branch` unless it only lists (a bare branch name creates one, which no prefix rule can tell from a listing), checks aliases and shell strings against every gated verb (which closed the `sw` and `unstage` aliases of `git/.gitconfig`, until the second walkthrough made the guard refuse every alias instead), and refuses a quoted or variable subcommand (`git 'push'`, `git $x`), the form the weakest assumption above names.
3. "4. Execute" stops before a block holding a command other than `git add`, `git rm`, `git mv` or `git commit`; the Git section of `CLAUDE.md` and the `AGENTS.md` hard limit name the four verbs.
- Rejected: an allowlist of read-only subcommands in the guard (a dozen subcommands have a read and a write mode, `branch`, `tag`, `stash`, `config`, `remote`, `worktree`, `notes`, `reflog`, `symbolic-ref`, `submodule`, each a false refusal on reads run constantly); `deny` for `rm` and `mv` (it would cut the `git rm --cached` sequence "3. Deliver" foresees).
- Weakest assumption: an indirection the segment parser does not see (`g=git; $g push`, `$(printf git) push`) runs unprompted; no occurrence is known, untested.
Closed on 2026-09-27 by point 12 of "Second walkthrough of `git-write-guard.sh`": a gated verb after a program held in a variable or a substitution is refused.
- Open, not decided: the other write verbs, `git apply`, `git worktree add`, `git update-ref`, `git config` in write mode, `git remote add`, stay gated by nothing in Claude Code and by `"*": "ask"` in opencode.
Settled on 2026-09-27 for `git update-ref` and the branch-creating forms of `git worktree add` by finding 9 of "Second walkthrough of `git-write-guard.sh`"; `git apply`, `git config` in write mode and `git remote add` stay open.

**Implemented on 2026-09-25 in `4cfcd0b` and `1d81e36`**, since superseded in parts by "Second walkthrough of `commit-stale.sh`", "Second walkthrough of `git-write-guard.sh`" and "A session is refused only for content its commit takes unverified"; the current behaviour is in the scripts and their suites.
Never live-tested, and still not: the Claude Code dialog for `git rm` and `git mv`, and every opencode rule.

**Walkthrough of `git-write-guard.sh` (2026-09-25, reviewer `posit-dev:critical-code-reviewer`, 10 findings: 8 accepted, 2 noted), fixes committed in `cb79698`.
Superseded on 2026-09-27 by "Second walkthrough of `git-write-guard.sh`" for the quoted git and the `&` redirection among the residuals of its finding 4 (point 12 and finding 10 there) for the shell-string check (`mention`) of its finding 5 (finding 3 there) and for the alias expansion of its finding 6 (finding 1 there).**
- Finding 1, accepted: `git stage`, git's builtin synonym for `git add`, matched neither list nor any `ask` rule, so it staged with no dialog.
The guard now refuses it in every form (canonical, alias, shell string) with a message naming `git add`, rather than admitting a fifth verb: the four-verb contract of `CLAUDE.md`, `AGENTS.md`, `settings.json` and `opencode.json` stays as it is.
The shell-string check, the alias checks and the new refusal share the `gated` list.
Test: "denies git stage, the synonym of git add, in every form".
- Finding 2, accepted: `strip_quotes` knows neither comments nor heredoc bodies, so an apostrophe in either (`# don't`, a heredoc holding `don't`) opened a quote that ran to the end of the string and hid every later git call, the stale check included.
`strip_quotes` now fails when a quote is still open at the end, and the guard refuses the command, asking to drop the apostrophe or run the git part on its own.
Chosen over parsing comments and heredocs: an unquoted heredoc runs its `$(...)` and backticks, so skipping bodies would open another gap, and the commit skill's blocks carry no heredoc.
Residual, accepted: a stray apostrophe closed by a later one the parser misreads (`echo don\'t` after the heredoc) still balances and hides the text between; written by hand only, no accidental occurrence known.
Test: "denies a command whose quotes stay open after an apostrophe in a comment or a heredoc".
- Finding 3, accepted: the fallback ran `commit-stale.sh` against `${CLAUDE_PROJECT_DIR:-$cwd}` while the commit takes place in the payload's `cwd` or the target of a `cd`, so a Bash write or a prek restore in another repository went unseen, on exactly the `cd <repo> && git ...` form the reroute message recommends.
The guard now follows the `cd` and `pushd` targets it can resolve (none, `~`, `~/...`, an absolute or relative plain path) and passes the git toplevel of the directory the commit runs in as the root, in both modes, never that directory itself: a root drifted to `~/dotfiles/claude` would make `excluded` drop `claude/.claude/hooks/` as tracking, the trap of the decision "step 0.1.4 passes the git toplevel as root".
A commit after a `cd` it cannot resolve (quoted path, variable, option, `cd -`, `~user/...`) is refused; the `~user` case was found by the walkthrough's final evaluate, where it resolved to a nonexistent root and left the stale check on the journal alone.
Two residuals, both on the conservative side or written by hand only: a nested project's own `.claude/` now counts as code for the guard as it already does for step 0.1.4 (the gate still exempts it through `CLAUDE_PROJECT_DIR`), and a `cd` inside a subshell is read as persisting after it.
Tests: "checks the repository a cd leads to, not the directory of the session", "counts a .claude directory below the repository root as code after a cd into a subdirectory", "denies a commit after a cd whose target the guard cannot resolve".
- Finding 4, accepted in a closed form: `setsid`, `flock`, `find -exec`, `fdfind -x`, a redirection before git or before the subcommand, `\git`, `g""it` and `git pu\sh` ran a gated verb unprompted.
None of them occurs in the 9 643 Bash commands of `~/.claude/projects/` outside this walkthrough's own probes (measured 2026-09-25), so the fix avoids open lists that the next review would extend.
The wrapper list is gone: any segment where a word reading `git` once backslashes and quotes are removed follows another program is treated as git behind a wrapper, named after that program.
Redirections are skipped among the global options and reroute a confirmed verb, backslashes are removed from the program and the subcommand, and the early `*git*` exit tests the command with its quotes and backslashes removed.
The quote placeholder of `strip_quotes` is now the control character `\x1f` instead of `Q`, which a literal capital Q in a path or a subcommand collided with (a `cd` into a `mktemp` directory named with a Q read as unresolvable).
Residuals, none seen in use: a program name quoted whole (`'git' push`), command substitution in backticks (`` git `echo push` ``, the indirection class the weakest assumption already names), `git 2>&1 push` (the `&` splits the segment), and a false refusal on `echo git push`.
Tests: "denies a git write run through any program placed before git", "denies a git write whose program name or subcommand is escaped or redirected", "passes read commands that name git after another program or carry a redirection", "reads a capital Q in a cd target as a letter, not as a quote".
- Finding 5, accepted: the shell-string check matched `runner` and `mention` anywhere in the raw command, so a read pipeline into `xargs` that named a gated verb elsewhere (`rg -l 'git commit' ... | xargs wc -l`, `git branch -r | xargs ...`, `--grep=revert`) was refused, the reviewer's own probe included.
`xargs` leaves `runner`: its git call is plain words, which the wrapper rule of finding 4 already catches (`xargs git rm` is refused as git behind the wrapper `xargs`).
`runner` keeps `bash -c` and `eval`, whose git sits inside quotes, and `mention` must now follow the runner.
Residuals: a runner placed before an unrelated quoted mention (`bash -c 'x' && rg 'git commit'`) is still refused; and a git command fed as data to a shell that runs it, which the whole-command match used to refuse by the same accident that caused the false refusals, now passes, found by the final evaluate.
It belongs to the indirection class the weakest assumption of "every git write verb is gated" already names, next to a verb piped into a shell, which no version of the guard caught.
Tests: "passes read pipelines into xargs that name a gated verb outside a git call", "denies a git write that xargs runs".
- Finding 6, accepted: git looks an alias up case-insensitively and follows an alias whose expansion is another alias, while the guard looked the subcommand up as typed, once, in a table `git config --get-regexp` keys in lowercase, so `git SW main` reached `switch` through the user's `sw` alias unrefused.
The lookup now lowercases the subcommand and expands in a loop, refusing past ten hops (a cycle included).
A chain needs a `git config` write first, one of the verbs still open under "every git write verb is gated".
Test: "resolves aliases whatever their case and through chains".
- Finding 7, accepted: `branch_writes` let a dash-led value through to its `-*` write branch, so `git branch --sort -committerdate` was refused.
`--sort`, `--format` and `--points-at`, whose value is required, now always consume the next word; `--contains`, `--no-contains`, `--merged` and `--no-merged`, whose value is optional, keep the dash test.
Test: two forms added to "passes the branch listing forms".
- Finding 8, noted: a heredoc body is parsed as commands, so `git commit -F - <<'EOF'` whose body holds a line such as `git push stays with the user` is refused, and since finding 2 so is any heredoc with a stray apostrophe.
The refusal is on the safe side, the `commit` skill writes `git commit -m "<header>"` and no heredoc, and skipping bodies was rejected under finding 2 (an unquoted heredoc runs its substitutions).
- Finding 9, noted, a limit of the decision "the stale check compares content, on the paths the commit takes": `commit-stale.sh` digests the working tree while the commit takes the index.
A path staged with content the verifier never saw (a partial `git add -p`, or a staged version whose working copy was brought back to the sealed content) passes the check and is committed.
No fix: comparing the index blob would need a second snapshot of staged content, for a case with no known occurrence.
- Finding 10, accepted: the test gaps.
Findings 1 to 7 each gained a test, the `cd` test that passed on a clean tree whatever repository the fallback read is backed by "checks the repository a cd leads to, not the directory of the session", and "denies a commit when the stamp is unreadable" and "denies a commit when the session id is unusable" now assert their own message instead of the `could not` both share.
The cases are in `git-write-guard.bats`, which establishes its own count.

**Second walkthrough of `commit-stale.sh` (2026-09-25, reviewer `posit-dev:critical-code-reviewer`, 8 findings: 6 accepted, 2 noted), fixes committed in `5de47a6`.** First real run the same day: prek saved and restored the unstaged `.gitignore` around `5de47a6`, and the guard let the next commit, `d4e2232`, through.
- Finding 1, accepted: `--seal` wrote the single snapshot `claude-code-writes-<session>.seen` under the new value at step 0.1.1 of `commit`, while the stamp keeps the old value until the verifier writes the new one.
A `/commit` stopped in between (verifier interrupted or dead) left a header that never matched the stamp again, so every check fell back to `ctime` until a `/commit` completed: prek sequences refused again, and a deletion after the stamp let through.
The snapshot is now one file per value, `claude-code-writes-<session>.<value>.seen`, read by the stamp's value; a seal prunes, after a successful write only, the snapshots matching neither the new value nor the current stamp, so at most two survive per session.
The header check stays.
Tests: "keeps comparing content against the stamp's snapshot after a seal whose stamp was never written" and "--seal removes the snapshots of values that are neither sealed nor stamped", both seen failing first; `rm` joins the stubs of `commit-stale.bats`, `commit-writes.bats` and `git-write-guard.bats`.
- Finding 2, accepted: `--only` no longer calls `in_work_tree_unignored`, whose two git calls per path filtered nothing, since `git-write-guard.sh` passes `git status` entries only.
Measured on 500 paths in the scratchpad: 6.1 s before, 2.6 s after, the level of the list mode.
`--only` therefore counts every path it is given, an ignored one included: a caller passes `git status` paths.
- Finding 3, noted: the digest `o` of a directory ignores what is inside, so a nested repository (`?? nested/`) or a submodule (` M sub`) changed after the seal passes; the `ctime` fallback had the same blind spot.
No `.gitmodules` under `~/dotfiles` or `~/Documents` (depth 5) and no nested repository in the dotfiles, measured the same day; reopen on a real case.
A real case exists since 2026-09-30: `~/dotfiles/.claude` is a repository of its own, no remote, versioned locally (`project_claude_dir_local_only_repo`, `DESIGN-CLAUDE-REPO.md`). It does not realize the blind spot from the parent root, where the nested repository never appears in the `git status` listing the digest reads, the parent's `.gitignore` keeping `/.claude/`. It can realize it from inside: a commit whose root is `.claude` reads that repository's own `git status`, where a new untracked directory of notes appears as `dir/` and digests as `o`.
- Finding 4, noted, a candidate case for the weakest assumption of the decision "the stale check compares content, on the paths the commit takes": in a repository with a content-changing clean filter (`html-id` in `eds-prise` and `md-nesrine`, on `output/**/*.html`), prek may restore the cleaned bytes of an unstaged file rather than the originals, which would refuse the next commit of a sequence, the conservative side.
Not measured: the toy repository needs a `git add` and a commit, which the guard refuses; a `prek run` there with a staged file and an unstaged filtered one, run by the user, would settle it.
- Findings 5 to 7, accepted: the test gaps.
`commit-stale.bats` gains the sealed-branch cases (deleted file, path sealed absent, absent path listed or only journaled, symlink target, unreadable file, `--only` exclusion and duplicates, spaces and glob characters, a path holding a tab), the seal exits ("--seal exits 2 on a value that is not a number, writing nothing", "--seal exits non-zero when the snapshot cannot be written, and keeps the previous one"), and `$status` asserts in "counts a change of the executable bit" and "falls back to ctime when the snapshot belongs to another stamp".
Each case pinning a branch fails against a copy with that branch mutated.
`commit-writes.bats` gains "--restamp exits 1 and keeps the stamp when the snapshot cannot be written" and a teardown that restores permissions.
`commit-stale.bats` held 30 cases at that walkthrough and `commit-writes.bats` 18, both since grown; `commit-gate.bats` (45) passes unchanged and `git-write-guard.bats` (59) passes with only the `rm` stub added.
- Finding 8, accepted: seal mode reads its value from `${2-}` instead of the variable `root`.

## A session is refused only for content its commit takes unverified (design approved on 2026-09-27)

**Decision: the guard and the gate judge the same thing with the same computation, the paths the commit takes, compared by content with the session's snapshot; a file the commit does not take never blocks, whoever wrote it and in whichever repository.** The requirement is the user's, on 2026-09-27: simultaneous sessions never block each other, in different repositories and, by the user's choice the same day, in the same repository.
This overturns four parts of the decision "the stale check compares content, on the paths the commit takes": the `cd` and the `git mv` entries of its fallback list, its trade "a file another session creates still blocks a closing response that shows commit blocks, through `commit-gate.sh`", and its reason for keeping the whole `git status` in the gate ("it sees text, not the paths a block stages").
The user approved, each by name:

1. Guard: a `cd` or `pushd` no longer sets `fallback`, and `top` and `base` come from the directory the commit runs in (the resolved `dir`, which today feeds `commit_dir` alone); `git mv` is read through its paths instead of falling back.
   The other fallbacks keep the whole `git status` of the commit's repository (a quoted or variable path, a glob, a `:(magic)` pathspec, `--pathspec-from-file`, the interactive modes, `-A` and its long forms, a path that does not resolve), since the commit may take any path there.
2. Gate, approach A: `commit-gate.sh` extracts each fenced block of `last_assistant_message` holding a line its pattern matches and submits it to the guard's path computation, in a mode that returns the stale verdict alone, every other refusal of the guard staying silent there.
   With no fenced block, the gate keeps its current whole-`git status` check.
3. Refusal message: a path the commit takes that the session never sealed is named as possibly another session's, with the instruction to leave it out of the staging command, instead of the instruction to rerun the verifier, whose next seal would take it in and let the following commit carry that session's work.
4. Step 0.1.4 of `commit`: the stamp is rewritten when every counted path is a file an applied finding targets, whatever its kind (`rules/`, `_meta/notes/`, `README.md`), no longer only when it is a tracking file.
5. The duration of a verifier pass (model, effort, the section 5 sweep) goes to its own `/design` in a fresh conversation, on an A/B measurement: it trades detection quality, and the data does not separate the growth of the tracking from the `xhigh` effort set on 2026-09-26 in `d374ad4`.
   Done on 2026-09-30, section "Section 5 of the verifier runs once a day per repository, not once per pass": the sweep was decided on the cadence lever, and the model and effort levers were left undecided, the A/B this point asks for having no ground truth to run against.
   On 2026-09-27 the user set the `claude-opus-5-5` effort back to `high`, after a diagnosis of session cost over the transcripts of 2026-09-19 to 2026-09-27: from `d374ad4` on, thinking tokens per response (`usage.output_tokens_details.thinking_tokens`, one count per message id) went from about 250 to about 650 and agent time per user prompt from 3.6 to 10.7 min, in dotfiles and in other projects alike, while at `high` Opus 5.5 thought and wrote per response as much as Opus 5 did before 2026-09-22; committed in `bed4533`.
6. The step 4 window start moves to the commit carrying this implementation, as it did for `b29e216`, `00df6eb`, `df43109`, `1d81e36` and `5de47a6`, since the guard and the gate shape the commit proposals step 4 counts.

**Why: most refusals that cost a verifier pass named files the refused session never wrote, and one computation shared by both checks is the local precedent.** The transcript analysis of 2026-09-27 covers the 7-day retention window, `commit` invocations from 2026-09-20 and verifier passes from 2026-09-22, the verifier's first day: 95 sessions, 148 `commit` invocations, 131 verifier passes, 128 of them measured for 8.7 h in all, median 199 s, p90 435 s, 5 over 600 s, the daily median rising from 121 s to 611 s and the median tool calls per pass from 14 to 56.5, 83 % of a pass spent on model time.
Of 20 stale refusals, 7 named no file the refused session wrote through Edit or Write: 2 across repositories, the memory commits from `quarto-hebstr-doc` into `~/dotfiles` on 2026-09-27 at 01:18 and 08:41, and 5 within `~/dotfiles`; 5 more mixed its files with another session's.
A refusal sends the model back to a verifier pass: 14 passes directly followed a refusal, 80 min in all.
The largest gate block (session `9962b122`, 2026-09-26) named 10 files, all written by the concurrent session `29836738`.
In `5a47d6f6` (2026-09-27, 00:33 to 01:43) a memory commit cost a 646 s pass, a refusal on the Positron settings the session never touched, a second pass of 813 s, and was then abandoned.
Three more loops reran the verifier after a finding applied to a file the gate counts as code: `CONTRIBUTING.md` in `dca7142d`, `verifier.md` in `7a7ec02f`, and `rules/memory.md` in `b3a7e2d2`, which took 983 s then 710 s for one commit on 2026-09-27.
Precedent: `commit-stale.sh` is the executable "that the gate and step 0.1.4 both call" (section "The shell of the `commit` skill moves into tested scripts"), so that one rule has one computation and several callers, and the guard and the gate can no longer diverge.

**Rejected.**
- Gate B, the journal alone (a flag in `commit-stale.sh`): it reverses "the gate unites the journal and `git status`" for the gate, which would miss Bash writes, writes before a `/clear` and hand edits, and it would still block, and send to a pass, on the session's own code the blocks do not take.
- Gate C, attribution through the other sessions' journals under `${XDG_RUNTIME_DIR:-/tmp}`: the Positron settings named by both cross-repository refusals appear in no Edit or Write of any transcript after 2026-09-26 13:24 (the last one, in `9962b122`), so the incident of 2026-09-27 would stay blocked, and a journal written before a `/clear` reads as another session's.
- Removing the gate: it is the only check on blocks the user runs by hand.
On 2026-09-27 the command the guard refused at 08:41 ran through `!` at 08:46 (`e669269`).
- Guard, requiring `git -C` instead of resolving the `cd`: `-C` is the form the guard reroutes, because the permission dialog does not see it.
- Step 0.1.4, counting `_meta/notes/` and `rules/` as tracking: the gate must see `rules/`, and it would cover neither `CONTRIBUTING.md` nor `verifier.md`.

**Weakest assumption, tested.** Every commit block the gate must judge sits in a fenced block.
In the transcripts, 198 assistant texts out of 198 holding a line the gate's pattern matches had it inside a fence, 184 of them a `bash` fence (measured 2026-09-27).
If it fails, the gate falls back to its current check: a spurious block, never a missed one.
The 0.1.4 change rests on the main thread checking each finding before applying it (step 0.1.3), untested beyond the three loops measured.

**Trade.** The gate no longer reports the session's own unverified code that the displayed blocks do not commit; the guard sees that code at the commit that takes it.

**Open.**
- `WRITES` still holds another session's dirty files through the `git status` half of `writes.sh`, so the verifier reviews them: a cost, not a block.
No attribution holds, since a journal written before a `/clear` carries another session id.
- The verifier of a session opened in another repository applies findings in the `~/dotfiles` tracking (`5a47d6f6` edited five `.claude/` files on 2026-09-27 between 01:34 and 01:42).
`.claude/` is exempt from the stale check while its repository ignores it, so nothing blocks there, and a clashing Edit fails loudly. Since 2026-11-07 that exemption is conditional rather than absolute, `excluded()` reading `git check-ignore`, so the notes of a repository that tracks them (dotfiles) do reach the check: see `DESIGN-CLAUDE-REPO.md` § "The premise that chose the nested form fell, and one refusal did not (2026-11-07)".
- A path in another repository that the session wrote through Bash and its commit takes is in neither the journal nor the `git status` `writes.sh` reads, so it is refused on every attempt; the message of point 3 names it instead of looping.
No occurrence is known.

**Implemented on 2026-09-27 in `cda7428`, decisions 1 to 4**, the behaviour being in `git-write-guard.sh`, `commit-gate.sh`, `commit-stale.sh` and their suites.
Four points the code does not carry:
- The gate joins the matching fenced blocks in order into one command rather than calling the guard per block, because a `cd` persists across Bash calls: a block without its own `cd` runs where the previous one left the shell.
- Residual, found by the verifier on 2026-09-27 and still open: in a message holding both a fenced commit block and an unfenced commit line, only the fenced block is judged, so this section's weakest assumption ("a spurious block, never a missed one") holds only for messages with no fenced commit block.
- The exemption of a nested project's `.claude/` through `CLAUDE_PROJECT_DIR` survives in the fallback only; with fenced blocks the gate counts it as code, as the guard and step 0.1.4 already did.
- **Decision (user, 2026-09-27, after `cda7428`): the gate's pattern reaches a commit line that opens on `cd` or `pushd`.** A line that opens on prose stays unmatched, so prose quoting such a chain in inline code passes.
Replayed the same day: 199 assistant texts matched against 198 before, the one added being a memory commit of session `5a47d6f6`, no prose among the added matches; that text holds its line inside a `bash` fence, so the weakest assumption holds at 199 of 199 under the extended pattern.
A quoted target makes the guard's verdict refuse, so such a block falls back to the whole-status check.
Committed in `46a7ba5`.

**Second walkthrough of `git-write-guard.sh` (2026-09-27, reviewer `posit-dev:critical-code-reviewer`, 11 findings and one found during the walk, point 12: 12 accepted), committed in `7c01358`.** Closing checks: Ouroboros evaluate APPROVED (score 0.88, goal alignment 0.92; its Stage 1 ran no command, none being configured, and it could not run bats; it named two tests coupled to the installed git, "denies an alias over a deprecated command, which git lets it override" needing `whatchanged` in `git --list-cmds=deprecated` and the `git stage` tests needing `stage` among the builtins, to check on ju-TP2); drift 0.41 against a 0.3 threshold, from its goal component (0.82) alone, constraints and ontology at 0; the ten L2 generations verified against OpenRouter.
- Finding 1, accepted, **decision (user): the agent gets no git alias; a subcommand that is not a command git lists is refused.** The guard read aliases once, from the `git config` of the payload's `cwd`, so an alias it could not see at parse time ran a gated verb unprompted: `git -c alias.p=push p`, `--config-env`, `GIT_CONFIG_COUNT`/`KEY_n`/`VALUE_n` and `GIT_CONFIG_PARAMETERS`, `git config alias.p push && git p`, `cd <other repo> && git p`, `HOME=` or `GIT_CONFIG_GLOBAL=` before git, `-c alias.st=push st` overriding a saved alias, and every alias written with the subsection syntax (`[alias "p"] command = push`), whose name git 2.55 allows to hold any character and which the `alias.<name>` table never held, even saved in the config the guard reads.
git ignores an alias that hides a command except for a deprecated one (git-config(1)), and `git -c alias.whatchanged='!…' whatchanged` runs the alias.
The guard now loads `git --list-cmds=builtins,main,others` minus `git --list-cmds=deprecated` and refuses any other subcommand; the alias table, its expansion loop and its two refusals (ten hops, shell alias) are gone.
`--list-cmds` is marked internal and experimental in git(1): a failed or empty listing refuses every git subcommand, pinned by "denies every git subcommand when git cannot list its commands".
Rejected: the reviewer's narrow fix (refusing `-c alias.*` and `GIT_CONFIG*`), which leaves the other forms open; keeping saved aliases next to the command list, which leaves a redefinition of a saved name open; applying the rule to git at command position only, which reopens `timeout 30 git -c alias.p=push p`, `env git p`, `xargs git p` and git by path; a list of runner programs, which any unlisted runner bypasses; skipping words shaped like paths, since `alias.src/.command` makes `git src/` an alias.
Trade: an unquoted `git` read as another program's argument and followed by a word is refused, and the message tells the agent to quote it; `rg -c git src/` moves from "passes read commands that name git after another program or carry a redirection" to "denies an unquoted git that another program reads, when a non-command follows it", which also pins `rg -c 'git' src/` passing.
Replayed on the 3 797 transcript commands that mention git, the rule refuses 7, none of that kind: a nonexistent subcommand (`git numstat`), and alias calls that are all probes of this guard (`git SW`, `git a2`, `git zz` from the first walkthrough, three from this one).
Outside those probes the agent called no alias, and a command the user runs through `!` does not reach the hook (the refused commit of 2026-09-27 08:41 ran through `!`, above).
Tests: `git-write-guard.bats` 75 cases, the alias cases run red before the code, the subsection case measured passing on the previous guard, and two tests renamed, "resolves aliases whatever their case and through chains" to "denies an alias whatever its case and through chains" and "passes an alias that expands to a read command" to "denies an alias even when it expands to a read command"; `commit-gate.bats` 55 cases pass unchanged.
- Finding 2, accepted, with a narrower fix than the reviewer's: `strip_quotes` copied an unquoted backslash with the character after it, so a backslash-newline stayed in the string and the segment split cut the git call where bash joins the lines.
`git -c \` then `alias.p=push p` and `env \` then `git commit -m x` passed, and `git commit \` then `--amend` or `-n` escaped `check_commit_options`.
`strip_quotes` now drops an unquoted backslash-newline, except on a line where a `#` at the start of a word opened a comment: bash does not continue a comment (`echo a # b \` then `echo c` prints both lines, measured), and the segment loop reads only the first git of a segment, so the reviewer's global `${stripped//$'\\\n'/}` would have turned `git status # see \` then `git push` into one segment read as `status` (measured passing once joined).
An escaped `\\` before a newline is consumed as a pair and never joins.
The fix also ends the refusal finding 1 had put on a two-line `git \` then `commit`, whose subcommand came out empty.
Replay: 9 transcript commands carry a continuation and a git word, 1 refused before and after (a `git -c … commit`).
Tests, the first two run red before the code: "reads a git call across a line continuation", "passes a git command split over lines by a continuation", and "does not join the line after a comment or an escaped backslash", which pins the two exceptions; `git-write-guard.bats` 78 cases, `commit-gate.bats` 55.
- Finding 3, accepted, **decision (user): inside a shell string, only a git read that git lists by name runs.** The check was the `runner` regex followed by `mention`, a regex for a gated verb anywhere after git, both on the raw text.
`runner` missed a shell called by path (`/bin/bash -c`), long options (`--norc`) and option values (`-O extglob`), and `mention` missed a word split by quotes or a backslash (`g""it push`, `pu\sh`), a variable (`git $v`) and an alias (`git p`), so each of those ran a gated verb unprompted.
`runner` now takes an optional path and any option words before `-…c`, on the command with continuations joined; the text after the shell name (after `eval`) has `$` removed before a quote, then every `"`, `'` and `\`, and each `git` word in it, not only the first, is read past git's global options: a subcommand that is gated, not a command git lists, or holds a `$` is refused.
The scan starts at the shell name rather than after the matched `-…c`, because the option-word group is greedy and stopped at a `-c` inside the string (`bash -c 'git -c alias.q=push q'` passed until that change); scanning more text only adds git words.
Removing quotes mirrors bash's quote removal inside a word, so it can join or reveal words but not hide one; a `$'git'` or `$"git"` keeps its `$` otherwise, and bash runs it (`$'git' --version` answers).
The reviewer's fix (the two regex changes and `mention` on unquoted text) was rejected: it leaves the alias and the variable.
Replay on the transcripts: 2 shell-string refusals instead of 4, the two left being loops of guard probes; the two dropped were false positives (a string assigned to a variable, `git config --get … && git check-attr …`), and nothing is refused that the old check passed.
Cost: `bash -c 'git branch'` is refused even as a listing (none in the transcripts).
Residual, not closed: an interpreter that is not a shell (`python3 -c`, `perl -e`, `ssh <host> '…'`); their list is open, the limit finding 4 of the first walkthrough set, and of a script written to a file.
Tests, run red before the code: "denies a git write through any spelling of a shell string", "denies an alias, a variable or git options hiding a write inside a shell string", "passes git reads inside a shell string" (red on the assigned string); `git-write-guard.bats` 81 cases, `commit-gate.bats` 55.
- Finding 4, accepted: git takes a unique prefix of a long option as the option (gitcli(7), "Abbreviating long options"; `git status --shor` answers), which `check_commit_options` already applies to `--no-verify` and `--amend`, while `staging_specs` and `commit_specs` matched full spellings only.
`git add --al && git commit -m x` therefore checked the `git status` before the add, nothing staged, while the commit took the whole tree; and `git add --renormalize`, which implies `-u` (`git add -h`), was ignored even in full.
The permission dialog still showed; the stale check was lost.
A `long_prefix` helper now reads each `--name` (before `=`) as a prefix: in `staging_specs`, `--all`, `--no-ignore-removal`, `--patch`, `--interactive`, `--edit` and `--pathspec-from-file` set `fallback` and `--update` and `--renormalize` set `tracked`; in `commit_specs`, `--patch`, `--interactive` and `--pathspec-from-file` set `fallback` and `--all` sets `tracked`.
No minimum length per option beyond three characters: a prefix git accepts that starts a widening option is that option, and one that also starts another option is ambiguous and refused by git, so widening on it costs only a command git refuses anyway (the L1 check proposed per-option minimums; `--a`, its example, is ambiguous for both add and commit).
No transcript command outside probes carries an abbreviated long option on add or commit.
Test, run red before the code: "reads an abbreviated long option that widens what add or commit takes", with prefixes unique for the installed git (`--inter` and `--pathspec-f`, the report's examples, are ambiguous for add); `git-write-guard.bats` 82 cases, `commit-gate.bats` 55.
- Finding 5, accepted, **decision (user): before add, commit, rm or mv, `SKIP=` is the only assignment kept.** The segment loop skipped every leading `NAME=value`, so `GIT_DIR=`, `GIT_INDEX_FILE=` or `GIT_WORK_TREE=` sent the commit to another repository or index than the one the stale check read (`GIT_DIR=/tmp/elsewhere/.git git commit -m x` exited 0), the `-C` case as an environment prefix; and `GIT_CONFIG_COUNT`/`KEY_0`/`VALUE_0` or `GIT_CONFIG_PARAMETERS` carrying `core.hooksPath=/dev/null` turned the prek hooks off as `--no-verify` would, while the same setting through `git -c` was rerouted (both exited 0, measured).
The loop now records the last assignment other than `SKIP`, and a confirmed verb behind one is refused, the message naming `SKIP=` as the one kept; a read (`GIT_DIR=… git log`) is untouched.
Rejected: the reviewer's named list (`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_NAMESPACE`, `GIT_CONFIG*`), which leaves `GIT_OBJECT_DIRECTORY`, `GIT_COMMON_DIR` and a relocated global config (`HOME=`, `XDG_CONFIG_HOME=`) open; every `GIT_*` plus `HOME` and `XDG_CONFIG_HOME` (the L1 check's pick), which keeps a list for the rest.
Of the 13 187 Bash commands in the transcripts, the only assignment before a confirmed verb is `SKIP` (2), so the rule refuses none of them.
Tests: "denies an assignment other than SKIP before add, commit, rm or mv" run red before the code, "passes SKIP before a commit and any assignment before a git read" pinning what stays; `git-write-guard.bats` 84 cases, `commit-gate.bats` 55.
- Finding 6, accepted: the cd branch matched `cd`, `pushd` or `popd` as the first word only, so `builtin cd`, `command cd`, `builtin pushd`, `\cd` and `'cd'` left `dir` on the old directory and the stale check read the session's repository while the commit ran elsewhere; `pushd +1` resolved to a path that does not exist, and a `CDPATH=` or `HOME=` set in the command sent bash's `cd` (and a `~/` pathspec) somewhere the guard did not follow, where a directory that is not a repository makes `top` fail and the guard exit 0 (each measured exiting 0).
The guard now sets `dir=""`, which refuses a later commit with the plain-path message, when the command word reads empty once `\` and quotes are dropped, when any word of the segment reads `cd`, `pushd` or `popd` that way without the cd branch consuming it, when a cd target starts with `+`, and from the first word `CDPATH=…` or `HOME=…` to the end of the command, since both persist in the shell.
`builtin` and `command` are not modelled: `command -v cd /tmp` is a lookup, and a wrong model toward a directory outside any repository opens the check, where a refusal costs one rewrite.
Replay: the 5 transcript commands refused with the plain-path message all `cd "$VAR"` in scratch test scripts, refused before this change too.
Tests, the first run red before the code: "denies a commit after a directory change the guard cannot follow", "passes a commit after a command that only names git, HOME or a lookup"; `git-write-guard.bats` 86 cases, `commit-gate.bats` 55.
The L1 check left a probe directory `/tmp/cdpath_test`, which the `rm -rf` deny rule keeps it from removing; the user removed it on 2026-09-27.
- Finding 7, accepted, with a fix wider than the reviewer's: `take` resolved each pathspec with `realpath -m`, which follows the last component too, so a tracked symlink became its target and never matched its own `git status` entry; a link repointed after the verification passed unchecked (`git add link && git commit -m x` exited 0 in the bats harness).
`~/dotfiles` tracks two symlinks, `css/.local/bin/prettier` and `css/.local/bin/stylelint` (`git ls-files -s`, mode 120000).
The reviewer's fix, resolving the parent only, breaks three cases the L1 check named: a path at the root, a trailing slash (which falls back into full resolution) and a symlinked directory named as the pathspec (the `~/.claude` layout), which today's full resolution maps onto the physical entries under it.
`take` now normalizes the path lexically first (`realpath -m -s`, as git reads `.`, `..` and trailing slashes), then adds two specs: the physical parent followed by the last name, which is the link itself, and the full resolution, which covers a symlinked directory.
Taking both is the conservative side: at worst the target of a link is checked as well.
Tests: "checks a tracked symlink the commit takes, not its target" run red before the code (its `./link/` case added with it), and "checks the files under a symlinked directory named as a pathspec" pinning the case the reviewer's fix would break; `git-write-guard.bats` 91 cases, `commit-gate.bats` 55.
- Finding 8, accepted, **the guard now enforces the block shape the `commit` skill already prescribes** ("a block holding any command other than `git add`, `git rm`, `git mv` or `git commit`: stop the sequence before it").
The guard runs once before the command, so in `printf x > a.sh && git add a.sh && git commit -m x` it compared `a.sh` at its sealed content, then the command wrote and committed the new one (exit 0 in the bats harness, measured); afterwards the tree is clean and a Bash write is not in the Edit/Write journal, so the Stop gate sees nothing either (by construction, not measured with a real commit).
The calibration rule of `feedback_review_severity_shell_installers.md` asking for a measured case did not apply, the category being data integrity.
A command holding a `git commit` whose repository exists at check time is now refused when it also holds anything but `cd`/`pushd` segments and git add, rm, mv or commit calls (`SKIP=` allowed): another program, a git read, `git branch`, a bare `git`, or a `>` redirection anywhere; the message names what it found.
`git commit -h` or `--help` as the sole argument is not a commit (`-m -h` still is).
Residual, named by the L1 check: a repository the command itself creates (`git init`) is not checked, as before, having no verification to bypass.
Replay: the rule refuses 2 transcript commands, both probes of this walkthrough holding `git commit -h 2>&1`, whose `&` splits the segment (finding 10).
Tests: "denies a command that writes before the commit it holds" run red before the code, "passes a commit block of cd and git add, rm, mv and commit, or a commit into a repository the command creates"; finding 6's "passes a commit after a command that only names git, HOME or a lookup" becomes "does not read a lookup or a word HOME as a directory change", since such a command is now refused by this rule; `git-write-guard.bats` 93 cases, `commit-gate.bats` 55.
Residual found by the closing verifier on 2026-09-27 and measured the same day with `--verdict`: a segment made only of assignments sets nothing the rule reads, so a commit line preceded by an assignment-only segment exits 0 where the same line preceded by a no-op is refused; `PATH` being exported already, an assignment to it changes the program the commit line runs.
Closing it is the user's to decide.
A second residual, found by the walkthrough of `git-write-guard.bats` on 2026-09-27 and measured the same day: the rule runs after `top`, so that a repository the command creates passes, and a directory change the parser does not read as `cd` then skips it whenever the session's directory is not a repository: from `/tmp`, an escaped spelling of `cd` followed by a staged commit exits 0 where the plain spelling exits 2.
Closing it means reordering that trade-off, the user's to decide as well.
- Finding 9, accepted, **decision (user): a branch or HEAD moves only through a gated verb**, which settles for two verbs the item "Open, not decided" of "every git write verb is gated".
`git update-index --add f && git update-ref HEAD $(git commit-tree $(git write-tree) -p HEAD -m x)` made a commit with no dialog and no stale check, and `git fast-import` (which updates refs, git-fast-import(1)), `git symbolic-ref HEAD refs/heads/other` and `git worktree add` (which creates a branch) each exited 0 (measured); the L1 check added `git fetch <repo> <src>:<local ref>` (git-fetch(1)).
`update-ref` and `fast-import` join `left`, and `permissions.deny` in `settings.json`, `permission.bash` in `opencode.json` and the verb list of `AGENTS.md` gain them; `symbolic-ref` with two operands or `-d`, `worktree add` when it creates or resets a branch (`-b`, `-B`, `--orphan`, `--track`, `--guess-remote`, or no commit-ish without `--detach`, git-worktree(1)), and `fetch` with a colon refspec after the repository, `-u` (in a cluster too), `--update-head-ok` or `--refmap` are refused like the write forms of `git branch`, their read forms passing (`symbolic-ref HEAD`, `worktree list`, `fetch -q origin`, an SSH URL as the repository).
Inside a shell string or after an unreadable program name, those three are refused in every form.
Left open, and why: the index and object plumbing (`update-index`, `read-tree`, `write-tree`, `commit-tree`, `hash-object -w`) moves no branch, and a later canonical commit's stale check takes the staged entries; `notes` and `replace` write their own ref namespaces (the L1 check's assumption, not verified); `bundle unbundle` updates no ref (same).
Found by the closing verifier pass and still open, for the user to decide (folded into option B's scope on 2026-09-27 by the prompt Claude recommended and wrote to `PROMPT.md` at the user's request, see "Option B, decided"): `git replay` (which updates refs by default, git-replay(1)), `git filter-branch`, `git bisect start` (which moves HEAD), `git send-pack` (the plumbing under `git push`, git-send-pack(1)) and `git worktree add <path> <branch>` when the branch exists only on one remote (git-worktree(1) then acts as `--track -b`) each exit 0 at the guard (measured), so the decision holds for the commands this finding names, not yet for the whole class.
A first count read only the first 400 characters of each transcript command and missed some; over full commands, `update-ref` (3) and `fast-import` (2) appear only in this walkthrough's own `jq` check of the deny lists, `commit-tree` once in a probe string, and `worktree add` once for real, `git -C $Q worktree add -q --detach $D 1.1.5` in a `quarto-hebstr-doc` session, which the first version of the rule refused and the narrowed one passes (found in finding 10's replay).
`fetch` appears only as `-q [origin]`, `--tags` and `--dry-run`.
Tests: "denies plumbing that moves a branch or HEAD" run red before the code, "passes plumbing that reads, or touches only the index and objects" (the `--detach` worktree, a commit-ish worktree and redirections added with finding 10); `git-write-guard.bats` 95 cases, `commit-gate.bats` 55.
- Finding 10, accepted, severity raised: the report filed it as a suggestion, but `git 2>&1 push origin main`, `git >&2 push`, `git &>/dev/null push` and `git 2>&1 add a.sh` each exited 0 (measured), the `&` of the redirection splitting the segment before the subcommand, a bypass of the kind of findings 1 to 3.
Before the split, `>&`, `<&` and `&>` lose their `&` in both `stripped` and `plain` (`2>&1` reads `2>1`), so the word stays a redirection and no longer cuts the segment.
The replay of the 547 transcript commands naming git with such a redirection turned up a false positive older than this walkthrough, a redirection counted as a positional operand (`git branch -a --contains d657ff0 2>&1` read as creating a branch), which the new `symbolic-ref` rule of finding 9 shared (`git symbolic-ref --short HEAD 2>/dev/null`): `args` now drops redirection words, an operator alone taking its target with it, for every subcommand, which also replaces finding 8's special case for `git commit -h 2>&1`.
After both changes, the 20 refusals left in that set are the `stash` and `tag` verbs refused in every form since 2026-09-25, alias and other probes, and `git stage`.
Tests: five redirection cases added to "denies a git write whose program name or subcommand is escaped or redirected" and `git commit -h 2>&1` to "passes a commit block of cd and git add, rm, mv and commit, or a commit into a repository the command creates", both run red before the code; `git-write-guard.bats` 95 cases, `commit-gate.bats` 55.
- Finding 11, accepted with no further change: the test gaps it named are closed by the tests each finding above added, every refusal case run red before its code; `git-write-guard.bats` goes from 69 cases at `46a7ba5` to 95.
- Point 12, found during findings 3 and 6 outside the report, accepted, **decision (user): a targeted fix now (option A), the parser rebuilt on a real shell syntax tree later (option B, below).** A program name the parser could not read hid git: `"git" push origin main`, `'git' push`, `"git" commit --no-verify -m x`, `'git' add -A`, `$'git' push`, `$"git" push`, `g=git; $g push`, `"$g" push`, `$(echo git) push` and `` `echo git` push `` each exited 0, since `strip_quotes` turned a fully quoted word into one placeholder; and `$'\x67\x69\x74' push` never reached the parser, the fast path requiring the substring `git`.
`strip_quotes` now sets two globals, `stripped` as before and `plain`, which keeps quoted content with its blanks and separators masked, so words stay aligned; a `$` before a quote is dropped, an escape inside `$'…'` becomes the `hide` marker, a `$` in single quotes is masked and a backtick in double quotes reads as `$`.
Git detection reads `plain`: a quoted git is git at command position, elsewhere only when the word after git's global options is a gated verb, so `rg -c 'git' src/`, the remedy finding 1's message gives, still passes.
A program word holding `$` or `hide`, or a segment right after a `$(…)` or backtick substitution closes (the separators are paired on a stack, so `f() { rm …; }` does not count), is refused when the word after git's global options is gated or holds `hide`.
The fast path also admits `$'` and a `$` or backtick with a gated word; a command it newly admits that leaves a quote open exits 0 as before instead of being refused.
Inside a shell string, a `$'…'` escape other than `\t`, `\n`, `\r`, `\\`, `\'` or `\"` is refused.
`after_git_options` replaces three copies of the global-option loop.
Replay: the fast path newly admits 785 transcript commands and refuses none of them (23 before the stack and the quote-open exit, all false positives: 14 open quotes in commands without git, 8 `f() { rm …; }` bodies, one `IFS=$'\t'` inside `bash -c`); on the 3 860 commands mentioning git, 0 refusals as "cannot read" or "escaped or quoted", the plain-path count unchanged at 5, and 2 quote-open refusals (not counted before this point; the quote-open branch for a command naming git is unchanged).
The dynamic-name rule matched none of 13 207 commands in a simulation before it was written.
Tests, the refusals run red before the code: "reads a git whose name is quoted", "denies a gated verb after a program name held in a variable, a substitution or escapes", "passes a program held in a variable or a substitution when no gated verb follows", and an ANSI-C case in "denies a git write through any spelling of a shell string"; `git-write-guard.bats` 89 cases, `commit-gate.bats` 55.
Cross-model: L2 valid on the finding; an adversarial L1 on the fix reproduced three forms still exiting 0, all runtime word splitting the guard cannot read statically: a reassigned field separator, a brace expansion whose empty word is dropped, and a command substitution emitting the verb.
They stay open for option B: closing them means refusing an unquoted expansion or a brace expansion in command position, whose cost a regex over raw text cannot measure (it counts quoted patterns and arithmetic).
- **Option B, decided (user, 2026-09-27), a step of its own in a fresh conversation: rebuild the guard's command parsing on `shfmt --to-json`.** shfmt 3.8.0 is installed here and exports a typed bash syntax tree (`DblQuoted`, `SglQuoted` with `Dollar`, `ParamExp`, `CmdSubst`, nested statements), about 6 ms a parse against about 50 ms for a guard call (measured).
Why: findings 2, 3, 6 and 12 of this walkthrough are all gaps of the hand-written parser, each fix adding a case.
What it must cover: the program word resolved from its literal parts; a policy, measured on the transcripts through the new parser, for an unquoted expansion or a brace expansion in command position (the three residuals above); `bash -c` and `eval` strings parsed with the same parser instead of point 3's dequoting; heredoc bodies not read as commands (finding 8 of the first walkthrough); a `cd` scoped to its subshell, which the hand-written parser read as persisting after the subshell.
Added to its scope on 2026-09-27 by the prompt Claude recommended and wrote to `PROMPT.md` at the user's request, which runs it after the walkthrough of `git-write-guard.bats`: the verbs finding 9 leaves open (`git replay`, `git filter-branch`, `git bisect start`, `git send-pack`, a `worktree add` whose branch exists only on a remote) and the wording of finding 8's refusal message, which leaves out `pushd` and `SKIP=`.
Open: shfmt on ju-TP2 (not checked), the behaviour when shfmt is missing or fails to parse (fail closed is the default to weigh), and the 96 bats cases as the safety net of the rewrite.
- **Option B, scope decided (user, 2026-09-27, in the conversation opening its implementation).** Each point approved by name: (1) shfmt missing or failing to parse a command the fast path admits refuses it (fail closed), the missing case naming `sudo apt install shfmt`; (2) both residuals of finding 8 close with it, a statement made only of assignments counting as another command, and the rule "a command holding git commit runs only cd, pushd and git add, rm, mv or commit" running before the repository lookup, so a commit into a repository the command creates (`git init && … && git commit`) is refused, which changes the test "passes a commit block of cd and git add, rm, mv and commit, or a commit into a repository the command creates"; (3) `git bisect` joins `left` in every form, with `replay`, `filter-branch` and `send-pack`, and the deny mirrors (`settings.json`, `opencode.json`, `AGENTS.md`); (4) `git worktree add` with a commit-ish and no `--detach` passes only when `git rev-parse --verify --quiet <commit-ish>^{commit}` succeeds in the directory the guard tracks, an unknown directory refusing.
The policy for an unquoted expansion or a brace expansion in command position comes back to the user with the transcript replay's numbers.
Order: replay harness, core parser at 96 of 96, shell strings, heredocs and subshell `cd`, the expansion policy, the verbs, the message and residuals, gate and record.
Found while scoping: shfmt 3.8.0 at `/usr/bin/shfmt` here, about 5 ms a parse; ju-TP2 still unchecked (`command -v shfmt` there, for the user).
- **Option B, expansion policy decided (user, 2026-09-27, on the transcript numbers): a statement whose program word holds an unquoted expansion or a brace expansion (`$x`, `$(…)`, `{a,b}`, `$d/tool`) is refused in a command the fast path admits, and inside shell strings.** Measured over the 12 510 unique Bash commands of `~/.claude/projects/` (subagents included): 15 such program words, 9 in commands naming git, 8 of them guard probes, and one real read (`for src in "cat MEMORY.md" "git show …"; do $src | rg …`); no brace expansion.
Rejected: the whole-word form only (`$x` refused, `$d/tool` passed), since `IFS=/; x=git; $x/push` runs `git push`; parsing every command holding `$` or a backtick, for its cost on most Bash calls and its false refusals outside git.
- **Option B, implemented (2026-09-27), committed in `8f4f939`, the shfmt memory in `6004c14`.** `git-write-guard.sh` parses the command with `shfmt -ln bash --to-json` and flattens the tree with `git-write-guard.jq` beside it; the hand-written parser and its separator stack are gone, and the scope decisions and the expansion policy are applied as decided.
The shfmt divergence found while implementing is in `reference_shfmt_ast_divergences.md`.
Cost measured the same day, 400 git commands on battery, serial: median 56.2 to 67.5 ms (paired median +10 ms), p90 80.7 to 80.5 ms.
Residuals, none measured in use: a command that spells neither `git` nor a gated word (`$(printf '\x67\x69\x74') $(printf '\x70\x75\x73\x68')`) never reaches the parser, the fast path's price; an expansion as the program a wrapper runs (`env $x`, `timeout 5 $x`); interpreters other than a shell; a `cd` inside a function body, which only matters once the function is called, an extra program the block-shape rule already refuses.
- **Option B, decided after its commit (user, 2026-09-27).** (1) The step 4 window start moves to `8f4f939` (step 4 of "Steps" in `PLAN-SESSION-DISCIPLINE.md`). (2) The expansion policy keeps its nested form: a shell string built by a substitution, such as `sh -c "$(git config --get filter.<name>.clean)"`, stays refused in a command naming git, although the measurement shown when the policy was chosen did not count its 3 transcript commands; its content is known only when it runs, and running the filter from a command that does not name git passes. (3) `command -v shfmt` on ju-TP2 waits for the user's access to that machine.

**Third walkthrough of `git-write-guard.sh` (2026-09-27, the first after option B, reviewer `posit-dev:critical-code-reviewer`, 8 findings: 8 accepted), committed in `548bbb6`.** Closing checks: Ouroboros evaluate APPROVED (score 0.87, goal alignment 0.92; its Stage 1 ran no command, none being configured, and it could not run bats); drift 0.61 against a 0.3 threshold, from goal (0.83) and ontology (1.00, no `current_concepts` passed), constraints at 0; the two L2 generations verified against OpenRouter (0.014252 USD).
`git-write-guard.bats` goes from 104 to 112 cases and `commit-gate.bats` from 55 to 56, the whole `_meta/tests/` tree at 1 477, all passing; `shellcheck`, `shfmt -i 2` and `shellharden --check` clean; latency 62 ms a call, within the 56 to 67 ms band measured at option B.
Each new refusal was run red against the guard of `663aaf7` before its code, and each fix was replayed over the 16 671 unique Bash commands of `~/.claude/projects/`.
- Finding 1, accepted: the flattener's `.Cmd` dispatch tested `($pre | length) > 0` before the structural branches, so a `TimeClause` or `CoprocClause` wrapping anything but a `CallExpr` emitted `["K", "time"]` and then `nested`, which walks command substitutions only, and the wrapped body was never emitted.
`time (git push)`, `time { git push; }`, `time if true; then git push; fi`, `coproc (git push)`, `coproc C { git push; }` and `time (cd /tmp && git push origin main)` each exited 0 while `git push` exited 2, and `--verdict` stayed silent on the commit form, so the Stop gate passed too.
The structural chain moves verbatim into a `structural` def and the `$pre` marker now prepends it.
Test: "reads the body a time or coproc keyword wraps", `time (ls -la)` pinning what still passes.
- Finding 2, accepted, **decision (user): a shell that reads its script on stdin is parsed when the guard can read that script, and refused when it cannot.** `shell_source` recognised only `eval` and a `-c` flag, and the flattener mined a redirection's `.Word` and `.Hdoc` for substitutions alone, so `bash <<< 'git push'`, `bash -s <<< …`, a heredoc, `echo 'git push' | bash`, `printf … | sh` and `source /dev/stdin <<< …` each exited 0.
The flattener now emits `["H", flags, text]` for ops 61, 62 and 63 (the body of `<<`, `<<-`, `<<<`), flagged `d` when it is not purely literal; `read_call` carries the payload to its own command, and `shell_source`, when the program is a shell with no `-c` and no script operand, parses a readable body and refuses an unreadable one.
A script operand (`bash script.sh`, `printf … | bash hook.sh`) stays the recorded residual, `--version` and `--help` are exempt (6 corpus commands).
Replay of the 1 638 commands touching a shell, a heredoc or an expansion: +2 refusals, both a pipe feeding an interactive bash, 0 lost.
Tests: "reads the script a shell takes on stdin, and denies one it cannot read", ten deny forms and five pass forms.
- Finding 3, accepted: `symref_writes` matched `-d | --delete` exactly, while git takes a unique prefix of a long option and clusters short ones (`git symbolic-ref --sho` and `--sh` answer here, and `--n` raises git's own ambiguity error), so `--del`, `--dele`, `--d` and `-qd` deleted a symref unprompted.
The arms now read `long_prefix "$tok" --delete` and a `*d*` cluster, as `worktree_writes` and `fetch_writes` already did; `--no-delete` and the read forms still pass.
The 28 corpus commands naming `symbolic-ref` give 10 flips, all probes of this walkthrough.
- Finding 4, accepted, **decision (user): a command holds commits in one directory or it is refused.** `commit_dir=$dir` kept the last commit's directory and one `top`/`git status` pass followed, so with repo A stale and repo B clean, `cd A && git add a.sh && git commit -m x` was refused while the same command continued with `&& cd B && git add b.sh && git commit -m y` exited 0.
The remedy accumulating per toplevel was rejected over this one for the single status pass it keeps, the L1 check agreeing; the `commit` skill prescribes "each commit in its own fenced block" and "one Bash call per block", so the refused shape is one the workflow never produces, and the 38 corpus commands naming two commits are probes and searches.
Two commits in the same directory still pass, with both commits' paths checked.
The comparison is on `dir` rather than the toplevel, so two subdirectories of one repository are refused as well, the conservative side.
Tests: "denies a command holding commits in two directories, whose tracking check reads one repository", "passes two commits in the same directory, whose paths are all checked".
- Finding 5, accepted, **decision (user): four narrow forms join the refusals, not `git config` as a whole.** `string_verb` admitted every subcommand git lists outside `gated|mixed`, and the plain path admitted the same, so `git config core.hooksPath /dev/null` (which disarms the prek hooks for every later commit, `.git/hooks/pre-commit` being what runs here), `git apply -R`, `git checkout-index -f` and `git read-tree --reset -u` all exited 0, inside a shell string and outside.
`hooks_path_write`, `apply_writes`, `checkout_index_writes` and `read_tree_writes` refuse those four; the verbs join `mixed`, so their read forms pass and every form is refused inside a shell string.
A blanket refusal of `git config` writes was rejected: it costs about ten real corpus commands (`user.name`, `user.email` in scratch repositories, `--unset`) for no guarantee, where the four narrow forms cost none.
`git config core.hooksPath` with no value is a read and passes, as does `--unset`.
The message of `string_verb`, which claimed "only a git read git lists by name runs there", now describes the set it admits.
Mirrors updated: `settings.json`, `opencode.json` and `AGENTS.md`.
- Finding 6, accepted, **decision (user): `git add -f` is left to the user.** The candidate paths come from `git status`, which omits ignored paths, and `-f` set neither `tracked` nor `fallback`, so a sealed then modified `.gitignore`d file was committed at exit 0.
Setting `fallback` does not close it (the `picked` loop only iterates `entries`, which never held the path), and `--ignored=matching` collapses an ignored directory into one entry, leaving `git add -f ignored_dir/file` open, `traditional` costing 2 828 entries here against 41.
The refusal is scoped to `add`, so `git rm -f` and `git add -- -f` pass.
0 real occurrence in the corpus; the calibration rule asking for a measured case did not apply, the category being data integrity.
Test: "denies a forced add, whose ignored file git status leaves out of the tracking check".
- Finding 7, accepted: in `--verdict` mode the guard exited 0 both after judging a clean commit and when it judged no commit at all, and `commit-gate.sh` reads any exit 0 as `judged=1`, so a commit its regex matched and the parser missed made the Stop gate fail open instead of falling back to the whole-status check.
An `unjudged` helper exits 1 under `--verdict` at the fast path, the parse failure with no git, `((commits))` and the `rev-parse --show-toplevel` failure, so that exit 0 means a commit was judged.
Findings 1 and 2 were two live instances of the class.
Measured: `cd /tmp && git commit -m x` gives verdict 0 on the guard of `663aaf7` and 1 now.
Tests: "--verdict stays silent and exits 1 when it judged no commit, so the gate falls back", and in `commit-gate.bats` "falls back to the whole status check when the guard judges no commit in the blocks".
- Finding 8, accepted: `string_verb` looked up `known[$1]` before testing `$1`, so `bash -c 'git ""'` printed `known: bad array subscript` to stderr ahead of the refusal, inside the text the model reads back; the verdict itself was right.
`-z $1` now precedes the lookup, as the plain path already did.
Pinned inside "denies a quoted or variable subcommand".

**Walkthrough of `git-write-guard.bats` (2026-09-27, reviewer `posit-dev:critical-code-reviewer`, 9 findings: 5 accepted, 1 rejected, 3 noted), committed in `d5dcfab` (tests) and `9b8980b` (calibration rule).** Only the suite changed, the guard is untouched; `git-write-guard.bats` goes from 95 to 96 cases, all passing, `shellcheck` clean.
Ouroboros evaluate APPROVED (score 0.92, its Stage 1 ran no command).
No mutant was run by the walkthrough itself (the scratchpad copy was refused by the permissions), so each new case is tied to the branch it pins by reading, the reviewer's mutants being the only measurement.
- Finding 1, accepted: `take` falls back to the whole tree for five forms, a quote, `$`, a backslash, a leading `:` and a glob, and only the quoted one was tested.
"checks the whole tree when a pathspec cannot be resolved" now loops over `*.sh`, `:/`, `$f` and `a\.sh` as well, none of which `strip_quotes` marks as quoted.
- Finding 2, accepted: short `-u`, option clusters and `commit -p` were untested, only the abbreviated long forms.
"reads an abbreviated long option that widens what add or commit takes" gains `git add -u`, `-vu`, `-vA`, `git commit -p` and `-vp`; its name is kept, since finding 4 of the second walkthrough cites it.
- Finding 3, accepted: the refusal when `git status` fails was untested, and a lost `wait "$!"` would leave `entries` empty and pass the commit.
New test "denies a commit when git status fails", a git stub failing on `status` only, installed after `seal`.
- Finding 4, accepted: "denies a commit when a tracked file changed after the stamp" asserted `commit skill`, which both stale classes print; it now asserts the header "changed after the last tracking verification" before the path.
- Finding 5, accepted: the `--reason` value skip of `worktree_writes` was untested; `git worktree add --lock --reason why ../x` joins "denies plumbing that moves a branch or HEAD".
- Finding 6, rejected: the `git config alias.*` fixture lines change no result under the current guard, but they are what makes a return to alias resolution fail (`alias.st 'status -sb'`), which finding 1 of the second walkthrough ruled out; calibration rule added to `feedback_review_severity_bats_tests.md`.
- Finding 7, noted: fixture git calls read the real `~/.gitconfig`; none of its keys affects a fixture today (no `core.hooksPath`, `commit.gpgsign` or `init.templateDir`), and a future one could only fail loudly.
- Finding 8, noted: the guard's line `((i < n)) && [[ -z ${pw[i]//[\\$mark]/} ]] && dir=""` looks redundant with the loop after it, but it only refuses more; left for option B.
- Finding 9, noted: the second residual recorded under finding 8 of "Second walkthrough of `git-write-guard.sh`".

### Authorship of a dirty file comes from the write journals, and a pathspec commit is read as git reads it (2026-09-30)

**Decision: the seal records only what the session's own write journal names; a dirty path another session's journal names is refused as that session's work; a dirty path no journal names is the user's own edit and never blocks; and the staged set counts as taken only by a commit carrying no pathspec.**
The enclosing section, "A session is refused only for content its commit takes unverified", settled what the guard and the gate compare, the paths the commit takes, and never where the authorship of a dirty file comes from. Three bugs followed from that gap, two refusing a legitimate commit and one letting another session's work escape, all three hit on 2026-09-30 by `dotfiles-3a` and `dotfiles-78` within the same hour.

1. A2a, the staged set against a pathspec commit. `git help commit` states that with a pathspec git commits the matching files "without recording the changes already added to the index", so a peer's staged work cannot ride along; the guard counted it anyway and refused a commit naming two memory files over `README.md` and `_meta/notes/dotfiles-bootstrap.md`, staged by a peer. `commit_specs` now sets `committed_specs`, and the branch that picks every staged entry runs only when that flag is clear. Pinned by "passes a pathspec commit while another session's work sits staged" and "still denies a pathspec commit whose own file changed after the verification".
2. A2b, the all-or-nothing reseal. Step 0.1.4 leans on `writes.sh --restamp` to reseal when every counted path is a file an applied finding targets, and a single foreign path made resealing unsafe, since the new seal would take that session's work in. The flag now takes paths: the named ones are resealed and `commit-stale.sh --seal --carry` copies every other entry of the previous snapshot verbatim, so an untouched path keeps the digest it was sealed with and stays judged against it. With no path the flag still reseals the whole journal. Pinned by "--restamp given paths reseals those and carries the other seals unchanged".
   Corrected on 2026-09-30, the fix shipping with the pass that hit it: the carry loop ended on `[[ -n $p && -z ${resealed[$p]+set} ]] && printf`, so when the previous snapshot's **last** entry was one of the resealed paths the `&&` list yielded 1, and that status climbed through the loop, the `if`, the redirected group and the subshell to the `) 2>/dev/null || exit`. The reseal then aborted with exit 1, no message, and the stamp left pointing at the old value, so the session read as stale on the very files it had just resealed and the gate blocked its commit. An `if`/`fi` closes it. This is the `&&`-list shape of `feedback_shell_grep_pipefail`, and the cost of the silence is what makes it worth recording: the failure is indistinguishable from success for a session that does not read the exit code. Pinned by "--seal --carry succeeds when a resealed path is the last entry of the previous snapshot" and "--seal --carry keeps one entry per path when a resealed path was carried before".
3. A3, the seal admitting another session's work. `writes.sh` sealed the union of its journal with the whole `git status --porcelain`, and the porcelain carries no authorship, so `7d8a14d` took `claude/.claude/memory/MEMORY.md` and `claude/.claude/memory/project_claude_dir_local_only_repo.md`, live work of session `d35b65a9`, under a message describing that session's subject. `writes.sh` now seals its journal alone while still listing the porcelain for the verifier to read, and `commit-stale.sh` resolves an unsealed dirty path against every journal under `${XDG_RUNTIME_DIR:-/tmp}`: its own journal gives `changed`, another session's gives `unsealed`, no journal gives no finding at all. Pinned by "seals the journal's paths only, still listing what git status adds" and the three `--only` cases naming the user's edit, the peer's file and the session's own post-seal write.

**Why the journal and not the session list.** `ListAgents` returns the live peers by name and `SendMessage` reaches one, verified on 2026-09-30 (`dotfiles-3a [ec1d28] · interactive · idle · started 2h ago`), so telling a peer what was committed under its nose needs nothing built. Presence is the wrong signal for enforcement: knowing a session is alive says nothing about which files it holds, and a guard built on the session list would still have committed `MEMORY.md`. Per-path authorship is already on disk with no protocol, no lock and no message, one journal per session keyed by session id, eleven of them that evening, and the two files of A3 resolve to `d35b65a9` by a single `grep -l`.

This does not reopen "Gate C", rejected on 2026-09-27 for reading a pre-`/clear` journal as another session's. Gate C proposed the journals as an extra reason to block; the rule adopted here uses them mainly to stop blocking, since a dirty path in no journal is now silent where it used to be `unsealed`. Only the positively foreign case refuses.

**What the `unsealed` class now means.** Exactly what its refusal message always claimed, a file another session may be writing. Step 0.1.4 of `commit` was rewritten to match, and it now names the paths to reseal instead of resealing everything.

**Refined on 2026-10-10: ownership is consulted for a sealed path too, and a peer entry counts as foreign only when it post-dates the seal.** Until then `changed()` returned the digest comparison for every path the snapshot held and never called `read_owners`, so attribution ran only on paths the snapshot lacked. A path this session wrote, hence sealed, that a peer then modified came back `changed`, whose prescribed remedy is the `/commit` pass that reseals it at its current content and commits it: A3's failure by a route A3's fix left open, traced end to end in a sandbox. A second route reached the same verdict on an unsealed path, `owner[$path]=self` being unconditional while `peer` was set only on an unset key, so a path both journals named resolved to `self` whatever the glob order. `read_owners` now keeps the timestamp field it discarded (`read -r _ path`) and tells a peer entry post-dating the stamp, which outranks `self` and promotes a sealed path to `unsealed`, from one predating it, which keeps its former meaning on a path the snapshot lacks and leaves a sealed path `changed`. Rejected: letting `peer` outrank `self` unconditionally, which closes the same hole in two hunks and makes the first residual below worse, a file an ended session's journal names and this session then edits becoming permanently `unsealed`. The timestamp split costs no fixture change, the journal line carrying `date +%s%N` and the stamp being minted by the same clock. Pinned by "--only labels a sealed path another session wrote after the seal unsealed" and "--only labels a path both journals name unsealed when the other session's entry postdates the seal", both of which fail before the fix, and by "--only keeps a sealed path changed when the other session's entry predates the seal", which is what fails under the unconditional form and so pins the choice between the two. The same pass closed a second hole, against a requirement this note had already written down under "First red test: an unreadable stamp or journal must exit with an error, never with an empty list": `read_owners` was the one reader skipping a journal it could not read without touching `failed`, so a path a peer journal named came back silent at exit 0, which both consumers read as nothing to check and permit. It now sets `failed=1` for a journal that exists and cannot be read, after skipping the unexpanded glob, that order being what keeps a run with no journal at all at exit 0. Pinned by "--only exits non-zero when another session's journal is unreadable". Walkthrough of `commit-stale.sh` and its suite, 2026-10-10.

**Residuals, none of them closed here.**
- The Gate C hazard survives in one direction: a journal written before a `/clear`, or by a session that has since ended, still reads as a peer's, so a file the user later edits by hand can be refused on a dead session's evidence. The refusal is recoverable and names the path, where the A3 failure was silent, so the conservative side was taken deliberately. The refinement of 2026-10-10 does not narrow this, and the first draft of this sentence claimed it did: a sealed path consulted no ownership before that date, and `self` was already unconditional, so a dead session's journal refused nothing in either case, and there was nothing there to narrow. What the refinement adds is refusals, on a post-stamp peer entry alone. The hazard therefore stands in full, on a path this session never wrote, which is where a stale journal is the only evidence there is, and the alternative the refinement rejected would have widened it to paths this session wrote as well.
- A user hand edit is no longer sealed, so a second hand edit of the same file after the verifier ran is no longer detected as `changed`. The verifier still reads the file, since `writes.sh` keeps listing the porcelain.
- A path holding a tab or a newline can be recorded by neither the seal nor a journal, so it is classed `unsealed` on sight rather than attributed. Pinned by "counts a path holding a tab, which the seal cannot record".
- The rule voids the mechanical reason the `.claude` bulk import was left to the user. A note no live session's journal names now passes, so section 5 of `commit` and the opencode mirror were rewritten to say the first commit is the user's by policy, and `project_claude_dir_local_only_repo.md` with them. The three passages of `DESIGN-CLAUDE-REPO.md` that still stated the old measurement (160 of 161 counted `unsealed`, "the bulk import cannot be run by an agent at all") went with its prune pass of 2026-10-13, which states the voiding on the import bullet of "The decision (2026-09-30)": the correction is no longer owed anywhere.
- Two of the `.gitignore` edits of 2026-09-30 beyond the two secret globs stay unrecorded: `TODO.md` narrowed to `/TODO.md`, and `/DRAFT.md` added. The third, `PROMPT.md` dropped from the ignore list, was recorded on 2026-10-14 in the section "A prompt goes to a file" of `DESIGN-INSTRUCTION-ROUTING.md`, together with the `.claude` repository's own re-ignore of `PROMPT*.md` two days later, which leaves the buffer tracked nowhere.
- `excluded()` exempts the memory directory from the staleness check entirely, by the realpath of `~/.claude/memory`, which is `~/dotfiles/claude/.claude/memory` here. Measured on 2026-09-30 after the fix: with a peer journal naming both, `--only` reports `claude/.claude/rules/memory.md` as `unsealed` and stays silent on `claude/.claude/memory/MEMORY.md`. The two files of the A3 incident were therefore exempt for a second, independent reason, and ownership evidence does not reach them. Whether a memory file should be ownership-checked while staying exempt from staleness is open.

**Cost.** The five files implementing the guard, the gate and the seal go from 1,357 to 1,434 lines, and their four suites from 2,473 to 2,675, 241 cases passing on 2026-09-30, `shellcheck` clean, the guard's 28 `deny` sites unchanged. The last increment is the `commit-stale.sh` walkthrough of the same day, four cases and three behaviour fixes, measured after it. The three fixes are therefore additive, and the subtraction the complaint asks for is the redesign below, which the user has not ordered: ask git what a command will commit (`git diff --name-only HEAD -- <pathspec>` for the pathspec form, the staged set for the bare one) instead of re-deriving pathspec and index semantics in bash, which would kill A2a by construction and retire the `specs`, `tracked` and `fallback` machinery of `staging_specs`, `commit_specs`, `move_specs` and `take` along with whichever `deny` sites stop being reachable. Its cost is that the guard runs a git command per candidate pathspec inside a `PreToolUse` hook, and that the fallback list, which today names every form it cannot resolve, becomes git's own answer.

## The shell of the `commit` skill moves into tested scripts (framing approved on 2026-09-24)

**Decision: the three shell computations the skill and its verifier carry as text move into `claude/.claude/skills/commit/scripts/`, called by their path, tested in bats in `_meta/tests/`, and the list of step 0.1.4 comes out of the same function as `commit-gate.sh`.** The three computations are the building of `WRITES` and the minting of the stamp (0.1.1), the list of the paths later than the stamp (0.1.4), and the two `rg | jq` pipelines of the section "5.
Live to-do items already carried out" of `verifier.md`.
The `bats-tests` hook of `prek.toml` extends to `claude/.claude/skills/`; shellcheck and shfmt already cover a script with a shebang placed there.
Precedent followed: `skills/depouiller/scripts/squelette.py` and its `test_squelette.py` for the placement inside the skill, `_meta/tests/commit-gate.bats` for the shape of the tests (a stamp dated by `date +%s%N`, the `ctime` not being falsifiable).

**Why: this code escapes every barrier, and two of its defects can only be fixed by a single, tested computation.**
- The text of a `SKILL.md` or of a prompt is seen neither by shellcheck, nor by bats, nor by the review criterion of section 0.3 of `commit`, which excludes `SKILL.md` files.
- Step 0.1.4 fails on the permissive side: the `2>/dev/null` of the journal half hides a token or a journal path miscopied, the `git status` half prints an error, but the list comes back empty in both cases, the condition "each of these paths is a tracking file an applied finding targets" becomes vacuously true, and the rewritten stamp hides code from the gate.
First red test: an unreadable stamp or journal must exit with an error, never with an empty list.
- Step 0.1.4 duplicates the logic of `commit-gate.sh` without its tests, and the copy has already drifted once (0.1.4 read the journal alone when the gate already counted `git status`, from `6e91fc3` to `e145eae`, see "Rewriting the stamp at 0.1.4" under "Known limits of the journal").
Moreover it filters neither the exempted tracking paths nor the ignored files, so it does not compute the set the gate will read.
- Testing falls under `rules/code.md`: more than two branches in 0.1.4, a script reused from session to session.
The jsonl fixtures of section 5 cover the typed command, the `Skill` call and the skill called with no arguments, which printed `null`.
- Once extracted, each script falls under the 30-line review criterion of section 0.3: the adversarial review follows from the extraction, it is not a way of its own.

**What the measurement establishes (transcripts of 2026-09-23): the code runs almost always as written.** Over the transcripts dated 2026-09-23 in UTC, 28 of the 31 launches of 0.1.1 conform, the other three paraphrase the block, one of them losing the union; the verifier, bounding the window at `6e91fc3`, counts 29 to 30 of them, a single one losing the union.
No real launch of 0.1.4 kept an unsubstituted `<STAMP_VALUE>` token.
Section 5, which runs in the subagents, is not measured.

**Rejected.**
- **Doing nothing**: it leaves the leak of 0.1.4 and the drift with the gate in place, and it is precisely 0.1.4 that can disarm the tested net the gate is.
- **`` !`…` `` injection in `SKILL.md`** (doc `code.claude.com/docs/en/skills`, read on 2026-09-23): it runs once only, at load time, and only in `SKILL.md`, so it covers neither 0.1.4, which runs after the verifier, nor section 5, which lives in a separate file; outside auto mode, a command no `allow` rule and no `allowed-tools` covers makes the invocation of a skill the hooks make mandatory fail; the code would stay untested, for a fidelity gain measured at 3 launches out of 31.
- **The prompt's `! cmd` prefix**: it asks the user for an action at every closure, where `ending-gate.sh` requires the model to close on its own.
- **An adversarial review alone**: it finds the defects once without preventing the drift; it comes with the extraction anyway.

**Trade**: a little execution fidelity, which the injection would guarantee better for 0.1.1, against testability.

**Weakest assumption**: the main thread calls the script instead of rewriting it.
Measured at 28 out of 31 for a six-line block, not measured for a one-line call.
If it falls, the `` !`${CLAUDE_SKILL_DIR}/scripts/…` `` injection on top of the scripts becomes the remedy.

**Decided on 2026-09-24: the sharing goes through a separate executable, `claude/.claude/hooks/commit-stale.sh <session_id> <root>`, that the gate and step 0.1.4 both call.** It prints the stale paths, exits 0 when the computation is complete and non-zero when a source failed, printing what it could compute; the gate blocks on a non-empty output whatever that code, and 0.1.4 keeps the stamp on any non-zero code.
Reasons: no sourced function has any precedent in `claude/.claude/hooks/`, a list mode would mix a command of the skill into the hook that reads its payload on stdin, and `bats-tests` already covers `hooks/`.
Since the script reads the stamp file, which 0.1.4 has just checked equal to `STAMP_VALUE`, `<JOURNAL>` disappears and `<STAMP_VALUE>` leaves the list command of 0.1.4, staying for the stamp check, which makes recording `STAMP_VALUE` through a script pointless.
Order chosen: `commit-stale.sh` and its tests, the gate (net: `commit-gate.bats` unchanged), 0.1.4, `skills/commit/scripts/writes.sh` for 0.1.1, `skills/commit/scripts/transcripts.sh` for section 5 of `verifier.md`, then the `files` pattern of `bats-tests`.

**Implemented on 2026-09-24 in `0326423`**, the contracts of the three scripts being held by their bats suites.
Three points the code cannot carry, `rules/code.md` routing them here:
- The output of `commit-stale.sh` separates the paths with newlines, so a file name holding one is cut in two, a limit the journal's TSV format already carried.
- The `files` pattern of `bats-tests` targets `claude/\.claude/skills/[^/]+/scripts/`, narrower than the `claude/.claude/skills/` the decision announced: an edit of `SKILL.md` does not rerun the suite, since no bats test reads the text of a skill.
- `commit-stale.sh` does not have the executable bit, like the other hooks of this chantier, and the skill's two scripts do, like `skills/depouiller/scripts/squelette.py`; all of them are called by `bash <path>`.

**Walkthrough of `commit-stale.sh` (2026-09-24, reviewer `posit-dev:critical-code-reviewer`).**
- **Decision: step 0.1.4 passes the git toplevel as root, no longer `$PWD`.** The Bash tool keeps a `cd` across calls and leaves `CLAUDE_PROJECT_DIR` unset (both measured in that walkthrough), so a `$PWD` drifted to `~/dotfiles/claude` made `excluded` drop `claude/.claude/hooks/` and `claude/.claude/skills/` as tracking, which the gate, rooted at `CLAUDE_PROJECT_DIR`, counts: 0.1.4 could then see an empty list and rewrite the stamp.
The command is now `root=$(git rev-parse --show-toplevel) && bash ~/.claude/hooks/commit-stale.sh "$CLAUDE_CODE_SESSION_ID" "$root"`: outside a repository it exits non-zero, which keeps the stamp, and in a project opened on a subdirectory of its repository the residual gap runs the safe way, 0.1.4 counting more than the gate.
The session's primary working directory was rejected as the root because it follows `cd` too.
- `commit-stale.bats` gains "treats an unreadable stamp as absent and exits non-zero" (10 cases).
The unreadable and malformed stamps share one `failed=1` line today, so the case adds no code coverage; it pins the exit that 0.1.4 keeps the stamp on, and fails on its own against a copy whose stamp guard tests `-r` instead of `-e`, which the malformed-stamp case lets through.
- Noted, for the step 4 remeasure to look for: a journaled project file written after the stamp and then restored to its committed content still counts, since the journal loop keeps a path on `ts > stamp` alone, so the gate blocks on a file with no diff.
No case measured.
Filtering journal paths under the git toplevel through `git status` would fix it but give the journal two regimes, other repositories staying covered by the journal alone; decide on it only if the window shows such a block.
- Not acted on: the exit status of the filtering branches (ignored, out-of-tree, deleted, renamed paths) is asserted only through `commit-gate.bats`, which discards it.
None of those branches sets `failed`, and a regression that did would only keep the stamp, reported by 0.1.4's non-zero branch.

**Walkthrough of `commit-stale.sh` (2026-09-30, reviewer `posit-dev:critical-code-reviewer`).**
5 findings and one note: 3 accepted, 1 deferred to `DEFERRED.md` (the journal lifecycle), 2 noted.
- **Decision: the seal normalises with `realpath -ms`, not the `-m` of `write-journal.sh`.** The divergence is deliberate and is what the code cannot carry.
The list side keys the snapshot on `$top/${entry:3}`, whose last component git never resolves, and `digest()` has a symlink branch of its own, so `-m` sealed a tracked symlink under its target's path and left the symlink reported `changed`, which the test "counts a symlink whose target changed since the seal" caught.
`-ms` keeps that branch reachable. Residual: a path named through a symlinked directory (`~/.claude/hooks/x`) does not align with the journal's `-m` form, and the mismatch over-reports, so it degrades the safe way.
The gap it closed was that `--restamp` passes its named paths through untouched, so a relative one sealed nothing and the gate reblocked the file the reseal claimed to clear, at exit 0.
- Noted, for a later remeasure to look for: `--seal <n> --carry` with `n` equal to the value already in the stamp file drops every carried seal in silence, the group's redirection truncating the file the carry then reads.
Unreachable through the only caller, `writes.sh` minting `date +%s%N` in the same pass. What would wake it: a caller passing a value it did not mint itself, or a stamp at second resolution.
- Noted: no `printf` of the seal group is tested and the group's status comes from its trailing `if ((carry))`, so a partial write leaves a truncated snapshot at exit 0 and the stamp still moves.
All four truncation shapes were traced on the read side (missing header, missing row, cut digest, cut path) and each falls back to `changed` or `unsealed`, never to silence, so the direction is the guard.
- `commit-writes.bats` was the only one of the four suites whose stubs omitted `realpath`, so the seal's new call took its fallback there rather than the production path; `realpath` joins its stub list.

**Walkthrough of `writes.sh` (2026-09-24, reviewer `posit-dev:critical-code-reviewer`).**
- **Decision: outside any git repository, `writes.sh` exits 1 with `no git repository from <dir>` on stderr, still listing the journal.** The same `$PWD` drift as in 0.1.4: run from a directory outside any repository, the script skipped `git status` and exited 0, so an empty journal (a session after `/clear`, or Bash-only writes) gave 0.1.1 an empty list, read as "clean tree", and the verifier was skipped.
The gate's re-block does not rescue it, since the skill reruns `writes.sh` from the same directory and the gate's loop marker then lets the continuation through.
0.1.1's exit-1 branch now covers that case and sends the model back to the project root before rerunning, and the empty-list shortcut to 0.2 applies to exit code 0 only, since it came before the exit-code branches and would otherwise still catch an empty list that exits 1 (raised by the commit verifier of the same session).
Exit 3 keeps precedence when the session id is also missing.
Rejected: a `REPO=<top>` line for the skill to compare, since nothing reliable gives the project root to compare it with (the primary working directory follows `cd`, as the 0.1.4 decision found); passing the root as an argument through `root=$(git rev-parse --show-toplevel) && ...`, which drops the journal list of a session legitimately working outside any repository.
Drift into another repository stays uncovered, as in 0.1.4.
- `commit-writes.bats`: "lists journaled paths outside any git repository" becomes "exits 1 with a notice outside any git repository, still listing journaled paths", and "keeps exit 3 over the missing repository when both apply" is added (8 cases), both seen failing first.
- Rejected: dropping journal entries at or below the stored stamp, as `commit-stale.sh` does, to spare the verifier a re-check on a second `/commit` of the same session.
`verifier.md` defines `WRITES` as the paths written during the session, and its re-derivation of tracking claims against the current state needs the tracking files written before the stamp, whose claims a later write can falsify; the cost gain is unmeasured.
The two scripts filter differently on purpose: the gate asks what changed since the last check, the verifier checks everything the session asserted.
- Noted: when the session id is unusable and `git status` fails or no repository is found, the exit is 3 and 0.1.1's exit-3 branch does not say the list lacks `git status`, nor send the model back to the project root.
The stderr notice names the second failure, and the combination needs `CLAUDE_CODE_SESSION_ID` missing, which Claude Code sets in every Bash call; separate exit bits were not worth a new output contract.
Reopen only on a real exit 3.

**Walkthrough of `transcripts.sh` (2026-09-24, reviewer `posit-dev:critical-code-reviewer`).** 6 findings: 5 accepted, 1 noted.
Every accepted defect was a false negative, never a false positive, since section 5 never flags an item for lack of evidence.
- `invocations` also lists slash commands typed without arguments, which Claude Code records with no `<command-args>` tag: 52 typed-command records came out of the top-level `~/dotfiles` transcripts before, 96 after.
The capture is anchored on the start of the message (an optional `<command-message>` then `<command-name>`), so a tag quoted inside prose no longer counts, and the argument field is empty, never `null`.
- Both modes read subagent transcripts, `<proj>/<session>/subagents/*.jsonl`: 202 such files against 117 top-level ones, holding about 44% of the Bash calls.
- `bash` prints, from the first line holding `NAME`, up to 60 characters before its first occurrence and 140 after, instead of the first line cut at 160, which lacked the name for 16 of the 61 `writes.sh` commands, 41 of the 183 `sys-update` ones and 199 of the 855 `bats` ones, subagent transcripts included.
After the change, none lacks it.
The window is built with `split($n)` because jq 1.7's `index` counts bytes while its slices count characters.
Rejected: the reviewer's cut of the first matching line at 200 characters, which still lacked the name for 8 to 122 commands per name.
Left as is: `sort -u` merging lines identical within the window, which the verifier could not tell apart anyway.
`verifier.md` section 5 describes the new output.
- Dates are local days (`fromdate | strflocaltime`), no longer the UTC day that dated 10% of the records (22:00 to 24:00 UTC) a day early against local item dates.
The conversion is optional, so a record without a timestamp is skipped instead of aborting jq (0 such records in any project).
- The project directory is `${repo//[^a-zA-Z0-9]/-}`, the rule of `uC` in the Claude Code 2.1.281 binary (`e.replace(/[^a-zA-Z0-9]/g,"-")`); the same names result for all 23 current project directories.
- Noted: `rg -F "$name"` searches the JSON-encoded line, so a `NAME` holding `"` or `\` never matches; no script or command name carries either.
- `commit-transcripts.bats`: 15 cases (10 before), `TZ=Europe/Paris` pinned in `run_transcripts` and `REPO` carrying `_`.
Each new case except the two guards (quoted tag, missing timestamp) was seen failing against the HEAD script.

**Third walkthrough of `commit-gate.sh` (2026-09-24, reviewer `posit-dev:critical-code-reviewer`).** 3 findings: 1 accepted, 1 rejected, 1 noted.
- Accepted: environment assignments before `git`, decision under "Gate".
The new case of `commit-gate.bats` was seen failing against the HEAD script.
It lands inside the step 4 window, whose start moves to the commit carrying it, `b29e216` (step 4 of `PLAN-SESSION-DISCIPLINE.md`).
- Rejected: a readability check on `commit-stale.sh` so that a missing sibling fails loudly rather than exiting 0.
The trigger named, a migration that moves the gate without it, is caught at commit: with `commit-gate.sh` copied alone beside `commit-gate.bats`, 21 of the 44 cases fail, and the prek hook `bats-tests` runs `_meta/tests/` on any change under `claude/.claude/hooks/`.
- Noted: `: >"$blocked" 2>/dev/null` does not silence a failed marker write, since bash applies the redirections left to right and the failing one comes first.
The runtime directory is user-owned (`/run/user/1000`, `drwx------`), and if the write ever failed, the bash error in the block reason would be the only signal that the loop guard is lost, so the grouped form `write-journal.sh` uses would remove it for nothing.

**Fourth walkthrough of `commit-gate.sh` (2026-09-28, the first after the `--verdict` contract change of `548bbb6`, reviewer `posit-dev:critical-code-reviewer`).** 6 findings: 2 accepted, 1 rejected, 3 noted.
Closing checks: Ouroboros evaluate APPROVED (score 0.87, goal alignment 0.93, drift 0.07; its Stage 1 ran no command, none being configured); drift check skipped, under 4 fixes; no L2 verdict, the report's tiers holding none of Blocking, Required or Critical.
Its two fixes change `commit-gate.sh` and `commit-stale.sh`, so they land inside the step 4 window, whose start the user moved to the commit carrying them, `bf02a32` (step 4 of "Steps" in `PLAN-SESSION-DISCIPLINE.md`).
- Accepted: the fallback branch discarded the exit status of its `commit-stale.sh` child, so an infrastructure failure of the check made the gate exit 0 where the judged branch and the guard both block.
Measured on a throwaway repository: with `.git/index` overwritten, `commit-stale.sh` exits 1 printing nothing, `git-write-guard.sh --verdict` exits 1, and the gate passed; an unreadable journal on a clean tree gives the same shape.
The branch now carries an `unchecked` flag set by `wait "$!"`, reaches the message block on it alone, and prints a refusal worded like the guard's.
The gate cannot tell a `--verdict` `deny` from an `unjudged`, both exiting 1, so a guard refusal still reaches the fallback rather than blocking on its own message: left as is, the contract change belonging to the guard.
`commit-gate.bats` gains "blocks when the whole status check cannot read one of its sources", written after the fix rather than before it.
- Accepted: list mode dropped the class `changed()` computes, so the fallback labelled every hit `changed` and told the model to invoke the commit skill, where the judged path names an `unsealed` path as possibly another session's and tells it to leave that path out of the staging commands, "now and after any new verifier pass, whose seal would take them in".
Following the fallback's remedy is what seals a foreign file in, since `writes.sh` seals every `git status` entry of the repository whatever session wrote it.
Measured: the same file after the same seal prints `unsealed<TAB><path>` through `--only` and a bare path through list mode.
List mode now prints `<class><TAB><path>` like `--only`, which supersedes "List mode, which step 0.1.4 and the gate's fallback read, prints bare paths as before" in the implementation record of 2026-09-27 above; `commit-gate.sh` drops its `judged` split and parses one format, step 0.1.4 of `SKILL.md` documents the two fields, and 14 list-mode assertions of `commit-stale.bats` carry their class, each measured against the running code.
`commit-gate.bats` gains "the whole status check names a never sealed path as unsealed" (58 cases); `commit-stale.bats` stays at 31.
- Rejected: the trigger pattern missing a commit split by a backslash continuation.
The shape the finding named, `git commit \` then `-m`, matches, as do a continuation before `git` and one after `-m`; only a continuation between `git` and `commit` slips, and over the 489 retained transcript files it occurs twice, both of them the probe command of the walkthrough itself.
The guard reads all four, and `SKILL.md` renders the commit line whole.
Its calibration rule, missing from the store until the `commit-gate.bats` walkthrough's verifier found it on 2026-09-28, is a bullet of `feedback_review_severity_shell_installers.md` committed in `1124ce5`: it sets an evidence bar (a continuation between `git` and `commit` measured in a transcript that is not a walkthrough probe) rather than closing the category, the gate touching data integrity.
- Noted: the fence loop reads its input through an unchecked process substitution, like the fallback did.
The trigger `jq -e` of the same payload already exits non-zero on a malformed payload and on a non-string message (measured: exit 5 for a number, an object and unparsable input, 1 for `null`), and the gate exits 0 on it, so no input reaches the loop and fails there.
- Noted: three fence shapes push a matching block into the whole-status check (a fence indented four spaces, a three-backtick line inside a four-backtick fence, a closing fence carrying an info string).
All three are CommonMark, checked against pandoc 3.11: the first is an indented code block, the second does not close, the third does not close either.
Aligning the gate differently would diverge from the spec.
- Noted: a `cd` in a block the pattern does not match is dropped from the joined command, and the guard then resolves the commit against the Stop payload's `cwd`.
Unlike the fence shapes this is a miss rather than a spurious block, measured with two repositories: with the `cd` the guard reports the stale path of the target repository, without it the guard checks the payload's repository and the gate passes.
Reachability nil: of the 489 transcript files, 34 hold a bash block opening on a `cd` and one is a `cd`-only block, followed by no commit block, and `SKILL.md` puts the staging command and the commit line in every block.
No clean fix: joining every block hands the guard unrelated commands and trips its refusal of a command running something else alongside `git commit`.

**Walkthrough of `commit-gate.bats` (2026-09-28, reviewer `posit-dev:critical-code-reviewer`, the last of the four proposed at the `cda7428` closure).** 2 findings: 1 accepted, 1 noted.
Tests only: no script changed, so the step 4 window keeps its start at `bf02a32`; its fix is committed in `bd5732f`.
Closing checks: evaluate skipped, under 2 fixes; drift check skipped, under 4 fixes; no L2 verdict, the report's tiers holding none of Blocking, Required or Critical.
- Accepted: no case made two of the gate's three message blocks fire in the same run, so the suite could not tell the three independent `if` of the message block from a chain, nor a per-block count from `${#stale[@]}`.
Both combined states are reachable from the code: `commit-stale.sh` prints its accumulated list before exiting on `failed`, so `unchecked` coexists with a stale path, and its `changed()` labels one path `changed` and another `unsealed` in the same pass.
`commit-gate.bats` gains "names a changed path and a never sealed path in the same run" and "names a stale path in the same run as an unreadable source" (60 cases), each asserting its own block's count.
Both were run red against the two regressions they name, injected in turn into `commit-gate.sh` then reverted: the changed count written `${#stale[@]}` fails the first alone, the three `if` chained on `elif` fails the second alone, the 59 other cases passing under each.
- Noted: two cases hand-roll `run_gate()`'s `env` line to set `CLAUDE_PROJECT_DIR`, which `run_gate()` always unsets.
The reviewer counted three; the third is `seal()`, whose inner command differs.
The three lines carry the same `PATH`, `XDG_RUNTIME_DIR` and `HOME` today, so the drift they expose is hypothetical, and parameterizing the helper would put a conditional array on the execution path of all 60 cases.

**`bats-testing-patterns` pass on `commit-writes.bats` and `commit-transcripts.bats` (2026-09-24).** Tests only: no script changed, so the step 4 window keeps its start at `b29e216`.
Committed in `a6530e2`.
- `commit-transcripts.bats` gains 6 cases (21): "keeps every later occurrence of the name in the excerpt", "matches a name holding pattern metacharacters literally", "exits 0 with no output when no transcript line mentions a command", "exits non-zero when a matching transcript line is not valid JSON", "prints nothing when the transcript directory holds no transcript", "rejects a call without a repository"; "prints nothing and says so when the project has no transcript directory" now also asserts a single output line.
- `commit-writes.bats` gains 4 cases (12): "lists both sides of a staged rename as separate paths", "keeps a git status path holding a space or an accented letter verbatim", "skips a journal line that carries no path", "puts the stamp under /tmp when XDG_RUNTIME_DIR is unset".
- Mutation-tested on 10 mutants, one per new case, each targeting the line the case pins (`rc[0] <= 1`, the `rc[1]` check, the empty `files` guard, `rg -F`, `join($n)`, the `repo` usage guard; `--no-renames`, `-z`, the empty-path guard, the `/tmp` default): 10 killed, each by its own case alone, and the same harness passes on the unmodified scripts.
- Pinned rather than decided: `transcripts.sh` fails closed on a matching line jq cannot parse, so a truncated last line in a transcript still being written would fail the whole `invocations` or `bash` call.
No such failure has been observed; reopen only on one.

**Walkthrough of `commit-transcripts.bats` (2026-09-24, reviewer `posit-dev:critical-code-reviewer`).** 4 findings: 2 accepted, 1 rejected, 1 noted.
Tests only: no script changed, so the step 4 window keeps its start at `b29e216`.
The suite stays at 21 cases.
- Accepted: "leaves out a Bash command that does not name the script" never reached the `contains($n)` clause of `bash_filter`, since `rg -F` dropped its `rg other` record before jq.
It gains a Bash `tool_use` whose `description`, not its `command`, holds the name, the shape of 7 records in the real transcripts.
Without the clause that record makes jq fail on `null | split($n)`.
The mutant dropping the clause, which passed 21/21 before, now fails this case.
- Accepted: "lists a Bash command naming the script, cut to 60 characters before the name and 140 after" checked a glob and a total length, both blind to swapping the two bounds.
It now asserts the exact line, 56 `x` and ` && ` before the name, ` --all ` and 133 `x` after.
The swapped mutant and an off-by-one `.[-59:]` mutant both now fail it.
- Rejected: "deduplicates and sorts invocations across transcripts" checks only `lines[0]`.
The unchecked line comes out of the Skill-call path that "prints an empty argument field, never null, for a Skill call without arguments" already pins exactly, so an assertion on it catches no further regression.
Calibration rule added to `feedback_review_severity_bats_tests.md`.
- Noted: `run_transcripts` passes `RIPGREP_CONFIG_PATH` through.
It is unset on this machine, and a config truncating long lines would break the script the same way in real use, so the suite failing then is the right signal; `env -u` in the test would hide it.

**Walkthrough of `commit-writes.bats` (2026-09-25, reviewer `posit-dev:critical-code-reviewer`).** 5 findings: 4 accepted, 1 rejected.
Tests only: `writes.sh` unchanged, so the step 4 window keeps its start at `00df6eb`.
The suite goes from 12 to 14 cases.
- Accepted, confirmed by L1 and L2: `setup()` unsets the output of `git rev-parse --local-env-vars`.
Git exports `GIT_DIR` and `GIT_INDEX_FILE` to `pre-commit`, and prek's system hooks do not clear them (prek's `git.rs`: a hook operating on another repository "must clear Git's repository-local environment"), so absolute values would send the suite's `git init`/`add`/`commit` to the dotfiles repository.
With `GIT_INDEX_FILE` pointed at an outside file, the reviewer saw that file written and two cases fail; after the fix the file is not created and the suite passes.
The same two lines went into the other four suites that write with git (`commit-gate.bats`, `commit-stale.bats`, `agent-skills-update.bats`, `prek-metadata-only.bats`) the same day: 106/106 cases pass, with `GIT_INDEX_FILE` pointed at an outside file too, which stays uncreated.
`out-textconv.bats`, `clean-html-id.bats` and `st-add-folder.bats` name git without writing through it.
- Accepted, confirmed by L1 and L2: "prints the stamp file and a nanosecond stamp value first" asserts the stamp file does not exist, since step 4 of `SKILL.md` reads the stamp as proof the verifier ran.
The reviewer's mutant writing the stamp from `writes.sh` passed all 12 cases before.
- Accepted, confirmed by L1: the git-status-failure case, renamed "exits 1 and keeps the journal paths when git status fails", asserts exit 1 instead of non-zero, and "keeps exit 3 over a failed git status when both apply" pins the `((failed == 0))` guard of that branch, which "keeps exit 3 over the missing repository when both apply" never reached.
The failing stub moved into the helper `fail_git_status`.
The guard-removal mutant was not rerun against the new case.
- Accepted: "lists journal paths written before the stored stamp" pins that `writes.sh` does not filter the journal by the stamp as `commit-stale.sh` does, the choice the `shell_installers` calibration protects.
- Rejected, L1 and L2 both invalid: pinning `LC_ALL=en_US.UTF-8` in `run_writes`.
The workstation's `en_US.UTF-8` already sorts `a.sh` before `.claude/PLAN.md`, so the ordering case catches a dropped `LC_ALL=C` where the suite runs, and a named locale missing elsewhere would put a `setlocale` warning into `$output`.
Calibration rule added to `feedback_review_severity_bats_tests.md`.

**Open points, none settled by default.**
- The `` !` `` injection on top of the scripts, to settle only if the remeasure still shows paraphrases.
- Closed on 2026-09-24 (section "Walkthrough of `transcripts.sh`"): the project path encoding of section 5, formerly `${repo//[\/.]/-}` in `transcripts.sh` (ex-`sed 's#[/.]#-#g'`), is now `${repo//[^a-zA-Z0-9]/-}`, the rule read in Claude Code's own code.
Still not reproduced: names over 200 characters, which Claude Code truncates and suffixes with a hash; no project path comes near that length.

**Decided on 2026-09-24: the implementation comes before step 4** ("Steps" of `PLAN-SESSION-DISCIPLINE.md`). Why: it fixes a leak that can let code pass the gate unchecked, and it does not touch what step 4 remeasures (contested commit proposals, tracking relaunches), since the rework keeps the skill's behaviour.

## The `commit` skill moves to a separate plugin with its gate and its journal, once the mechanism is stable (framing approved on 2026-09-24)

**Decision: nothing moves now; the migration to `claude-code-plugins` is triggered when step 4 is closed, the review of the scripts of "The shell of the `commit` skill moves into tested scripts" having been done on 2026-09-24 on the current paths.
It takes the form of a separate `commit` plugin, with its own source directory.**

**Why: the goal is a skill as portable and packaged as the `audit` and `workflow` plugins, and for a skill that carries hooks only a plugin reaches it.** Grouping the files in the dotfiles would leave the hooks registered in the user's `settings.json`; only a plugin's `hooks/hooks.json` makes the whole thing a unit installable and activatable in one block.
The wait is about the rate of change: the mechanism changed on 2026-09-22, 23 and 24, and every retouch of a plugin goes through the source clone, a push and a cache refresh (`CLAUDE.md`, Environment, the bullet on the downstream copies under `~/.claude/plugins/`).

**The migrated unit is the skill, `write-journal.sh`, `commit-gate.sh` and `commit-stale.sh`.** The skill without the gate is the way "The skill alone, without a hook" rejected by the framing of step 3 ("Rejected ways" of `PLAN-SESSION-DISCIPLINE.md`).
`ending-gate.sh` and `reco-relance.sh` stay in the dotfiles: they carry Communication rules of `CLAUDE.md`.
The gate stands on its own, its loop guard holding for any other `Stop` hook (decision "the loop guard is specific to the gate" under "Gate", test "blocks a continuation another Stop hook triggered").
The "close" family of `ending-gate.sh` looks for ` /commit`: to realign if the plugin changes the skill's invocation name.

**Target.**
- The plugin's `hooks/hooks.json` declares the gate and the journal through `${CLAUDE_PLUGIN_ROOT}`; precedent of a plugin `hooks/hooks.json`: `ouroboros` and `r-skills` installed, of `${CLAUDE_PLUGIN_ROOT}` in its commands: `ouroboros` alone.
- `commit-stale.sh` stays beside the gate; `SKILL.md` calls it through `${CLAUDE_PLUGIN_ROOT}`, which the doc (`code.claude.com/docs/en/plugins-reference`, read on 2026-09-24) substitutes in the content of a plugin's skill and agent, but which is absent from the Bash tool's environment.
- `writes.sh` and `transcripts.sh` stay in `skills/commit/scripts/`, on the precedent of `audit/walkthrough/scripts/` and the `${CLAUDE_SKILL_DIR}` of `audit/walkthrough/agents/ouroboros-bridge.md`.
- The bats of `_meta/tests/` (`commit-gate.bats`, `commit-stale.bats`, `commit-writes.bats`, `commit-transcripts.bats`, `write-journal.bats`) move beside the scripts, like the `test_*.py` of the plugins repository, and the CI of `claude-code-plugins`, which runs the manifest validation, prek and pytest, without bats, gains a bats step.
- The dotfiles lose the `write-journal.sh` and `commit-gate.sh` entries of `claude/.claude/settings.json` and activate the plugin.

**Couplings to undo at the migration, inventory of 2026-09-24.**
- Hardcoded paths: `SKILL.md` calls `~/.claude/skills/commit/scripts/writes.sh` and `~/.claude/hooks/commit-stale.sh`, `verifier.md` calls both modes of `~/.claude/skills/commit/scripts/transcripts.sh`.
- The registration of the hooks in `claude/.claude/settings.json`.
- Conventions specific to the user, the real work of the migration: `~/.claude/memory/MEMORY.md` and `REPO/_meta/notes` in `verifier.md`; the Git section of `~/.claude/CLAUDE.md`, the "Secret files handling" scope of `CLAUDE.md`, `feedback_commit_sequence_add_all.md` and the reviewer `posit-dev:critical-code-reviewer` in `SKILL.md`; the undocumented variable `CLAUDE_CODE_SESSION_ID`.
- Remeasure before the migration: `rg -F '~/.claude/' claude/.claude/skills/commit` and the consumers of `commit-stale.sh` outside the skill and the gate.
- Added on 2026-09-25: the unit gains `git-write-guard.sh` and `_meta/tests/git-write-guard.bats`, a third commit-related `settings.json` entry (its `PreToolUse` on `Bash`), and a second consumer of `commit-stale.sh` outside the skill and the gate.
The `ask` rules on `git add` and `git commit` stay in the user's own `settings.json` (section "Any agent runs `git add` and `git commit` at closure, each call confirmed in its native permission dialog").
- Added on 2026-09-27: `commit-gate.sh` calls `git-write-guard.sh --verdict` by sibling path (`${BASH_SOURCE[0]%/*}`), as it calls `commit-stale.sh`, so the gate, the guard and `commit-stale.sh` move together (section "A session is refused only for content its commit takes unverified").

**Rejected.**
- **Folding `commit` into the `workflow` plugin**: a plugin is activated and deactivated only in one block (doc cited above), so whoever installs `workflow` for another skill would get a `Stop` gate and a journal; that is the reason `waza@waza` was refused in `DESIGN-AGENT-SKILLS.md`.
`commit`, invoked by the model, would also break the convention of skills reserved to the repository's user.
Lastly `audit` and `workflow` share `"source": "./"`, and a `hooks/hooks.json` at that root would be loaded by both.
- **Migrating now**: the retouch would go through a push and the cache during step 4, which remeasures a mechanism meant to stay stable.
- **Prefiguring the tree in the dotfiles**: it freezes a layout before the plugin's constraints have been checked, without advancing the generalisation of the conventions, and with no consumer before the migration.

**Weakest assumption**: the `~/.claude/...` paths gain no consumers between now and the migration (4 script calls and 2 `settings.json` entries on 2026-09-24).
If they do, the move grows and prefiguring becomes worth it again; the remeasure above says so.

**Open points, none settled by default.**
- Substitution of `${CLAUDE_PLUGIN_ROOT}` in `verifier.md`, which the skill reads through `Read` instead of loading it as a plugin agent: otherwise `SKILL.md` passes it the resolved paths.
- Declaring hooks in a marketplace entry with `strict: false`: the doc says nothing about it; the plugin's own source directory makes the question moot if it carries its own manifest.
- The form of the generalisation of the conventions specific to the user.

## Known limits of the journal

- **Writes outside Edit/Write.** The journal sees only the `Edit|Write` matcher: a file written in Bash (`sed -i`, a heredoc, a redirection) does not enter it.
  `reference_claude_code_best_practices.md` says so ("`PostToolUse` on `Edit|Write` misses files written via `Bash`").
  Since 2026-09-23, the gate and step 0.1 of the skill unite the journal and the `git status` of the project's repository (section "Gate"): such a file blocks the commit there and enters `WRITES`.
  The limit now holds only in a repository other than the project's, where the rule of `CLAUDE.md` (Communication, "Every file write goes through Edit or Write") that routes every write through Edit/Write is the only guard left; a possible way if it does not hold: a `Bash` matcher journaling the difference of `git status --porcelain`.
- **Rewriting the stamp at 0.1.4.** The check that decides whether to rewrite a fresh stamp after the verifier's corrections read the journal alone, where the gate also counts the paths of `git status` whose `mtime` is later than the stamp: a code file modified outside Edit/Write while the verifier was running would be hidden by that rewrite.
  Found by the verifier on 2026-09-23 and fixed the same day: the list of 0.1.4 now unites the paths journaled after `<STAMP_VALUE>` with those of `git status` whose `mtime` is later than it, like the gate (`ctime` since the walkthrough of 2026-09-23, see "Gate"); a deleted path does not appear in it, since the gate no longer counts one once a stamp is written.
  Since 2026-09-24, that list comes out of `commit-stale.sh`, the gate's own computation, which also filters the exempted tracking and the ignored files (see "The shell of the `commit` skill moves into tested scripts").
- **Writes earlier than the hook's registration.** Observed at the first pass: `write-journal.sh` and `write-journal.bats`, written before the hook was registered, were missing from the journal; they were added to `WRITES` by hand from `git status`.
  A case specific to the installation session.
- **Session id rotation.** `/clear` mints a new session id, measured on 2026-09-23 on 2.1.278: the transcript `e04bba45-…` closes at 23:42:31Z, the next one `6073595b-…` opens on `/clear` at 23:43:06Z, and `CLAUDE_CODE_SESSION_ID` is `6073595b-…` there.
  Since the journal is indexed by that id, the writes from before the rotation leave the journal that `commit-gate.sh` and the verifier read: before the union of 2026-09-23, the gate exited 0 on a missing journal and code edited before the `/clear` reached a commit unchecked.
  The union of the journal and `git status`, implemented the same day (section "Gate"), covers that case in the project's repository, `--resume` and the restart that empties `XDG_RUNTIME_DIR` included, without depending on the id.
  `--resume` has not been measured.
  **What the union does not cover: the attestation, measured on 2026-10-15.** A restart takes the stamp, the snapshots per value and every write journal away at once; the machine restarted at 12:00:22 between the verifier's pass and the commit, with the stamp minted at 11:48:48 and resealed at 11:51:46.
  The operator gets no error, only a false finding: `commit-stale.sh` returns the session's own modified files as `changed`, no snapshot holding their sealed content any more, and the gate would refuse the commit blocks.
  The remedy is to run step 0.1 again in full, which reseals at the current content and mints a new stamp: the verifier's findings still hold, only its attestation is gone.
  The sweep marker, for its part, lives under `${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/` and survives the restart, so `SWEEP` stayed at `no` on both sides.

## Open points

- **The seal keyed on the raw path string, so a reseal named in relative form unsealed the file: observed on 2026-09-30 in `eds-prise`, cause established, fixed in `c3473fd`.**
  A `/commit` pass whose verifier produced six findings was blocked after those findings were applied. `git-write-guard.sh` named four files "changed after the last tracking verification", all four of them files a `writes.sh --restamp` had just named. The snapshot on disk shows why: it holds the same file under two keys, `.claude/PLAN.md` and `/home/julien/Documents/des/eds/eds-prise/.claude/PLAN.md`, with different digests. `commit-stale.sh --seal` then keyed on the path exactly as handed to it (`resealed[$path]=1`, `printf '%s\t%s\n' "$d" "$path"`), while the check side resolves through `realpath -m`, so a relative argument wrote a key the guard never looks up and `--carry` treated it as a different file, leaving the guard to read the absolute key with its pre-correction digest.
  **What this cost:** naming a path on `--restamp` unsealed it instead of sealing it, `--restamp` exited 0 and printed a new stamp value, and the only symptom came several steps later as a refusal whose message sends the operator back through the verifier. The recovery path from a silent seal defect is the most expensive operation in the system, and it re-runs a verification that was never what failed. In this pass it also cost a second verifier launch, which the user stopped.
  **Timeline, by mtime.** The failing reseal wrote its snapshot at 23:03:05; `claude/.claude/hooks/commit-stale.sh` gained the `realpath -m` normalisation at 23:13:00, uncommitted in this tree and not by the session that hit the defect; every reproduction attempted after that stored the absolute key correctly. So a reading of the live file after 23:13 cannot see the defect, and the seal written at 23:03 is the only evidence left of it. That artefact does not survive: the snapshots live under `${XDG_RUNTIME_DIR}`, so the next reseal deletes it (`commit-stale.sh --seal` keeps only the new value and the current one) and a reboot takes the rest. The two keys quoted above are therefore the record, and no file will back them up.
  **The two code sites of the digest failure were closed on 2026-10-01** (section "The verifier's model is pinned and a failed seal is loud"), on the probe this bullet records: seal `a.sh` and `b.sh` under one value, make `b.sh` unreadable, then reseal naming `b.sh` with `--carry`, and the old snapshot held `a.sh` alone while the call exited 0.
  What that probe established and no other copy holds: the two symptoms were one event, a digest failure, seen once from the seal and once from the exit code, so the count of three defects was a count of code sites rather than of causes.
  **Still open, and deliberately not built:** nothing checks at runtime that the keys just sealed are the keys the check side will look up. Rejected on 2026-10-01 rather than deferred: `excluded` drops every `<root>/.claude/` path and the memory from the check side, so a runtime readback is silent exactly where the gate is, and with both sides normalising through `realpath -ms` its failure path is unreachable by construction, which is why no case can drive it red. The invariant is pinned in `commit-stale.bats` instead, by "the seal keys a path named through a symlinked directory as the symlink, so the resolved path the journal names stays reported", which fails if either side's normalisation is ever changed: the same guarantee checked once at commit rather than on every reseal.
  Residual that case pins: the seal keys with `realpath -ms` while `write-journal.sh` keeps `-m`, so a path named through a symlinked directory over-reports. Flipping the journal to `-ms` was rejected on 2026-10-01: `in_work_tree_unignored` would then read `~/.claude/hooks/x` as outside the work tree and drop it, turning a safe over-report into a fail-open.
  **A cost measurement of the regime before the model pin, taken in the same pass:** 532 737 ms of wall clock, 166 808 subagent tokens and 46 tool calls, on a `WRITES` of four tracking files with `SWEEP=no`, in a repository whose `PLAN.md` alone is 306 KB. The cadence lever was already spent on that pass, which is what left the model and effort pair as the only lever on cost (section "The verifier's model is pinned and a failed seal is loud").

- **`command -v shfmt` on ju-TP2, for the user, pending since 2026-09-27.** Syncthing carries the working tree there without waiting for a commit, so `git-write-guard.sh` may already run on that machine and refuse every git command Claude makes if shfmt is missing.
  Pending there too: a run of the two `git-write-guard.bats` tests coupled to the installed git ("denies an alias over a deprecated command, which git lets it override" and the `git stage` tests).
