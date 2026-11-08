---
name: handoff
description: 'Use at the end of a session, as soon as section 0.2 of the commit skill concludes that nothing remains to pursue and the session can be closed, and before that skill delivers its commit blocks. Also use when the user asks whether everything is up to date or whether the session can be closed, when `closure-check.sh` asks for it, and when the session is over without having committed anything.'
---

# Certifying that the session can be closed

Conduct the conversation in the user's language, whatever the language of this text.

This skill establishes that the session can be closed, then records that closure in one of two branches: nothing written when the work is finished, or a brief in `.claude/HANDOFF.md` when the next step needs a conversation this one cannot be.
What it certifies is the content no verifier pass has read: the writes that followed the last pass of the `commit` verifier, which reach no other mechanism.

It runs no git command and writes no commit block.
Called from section 0.2 of `commit`, it hands back to that skill's section 0.3 once section 5 below has reported; invoked on its own, it ends on that report.
The design is `~/dotfiles/.claude/DESIGN-HANDOFF.md`.

Order: the branch of section 2, then the brief of section 3, then the scope of section 1, then the pass of section 4.
The brief is an input to the reread rather than its successor, two defects of 2026-11-08 having lived in a brief written after everything else.

## 1. The delta no pass has read

The write journal's entries post-dating the stamp are the scope, with no filter but the temporary directories:

```bash
bash ~/.claude/skills/handoff/scripts/tail.sh
```

Each line printed is one path, sorted and deduplicated.
Exit 0 with no line means the journal holds nothing after the stamp, which is the empty scope section 4 acts on, and it is the only shape that may be read that way.
Exit 3 says `CLAUDE_CODE_SESSION_ID` is unusable; exit 1 says the journal is unreadable, or the stamp is not a timestamp, or a journal line is malformed.
On exit 3, and on the first two shapes of exit 1, nothing is printed, so a failure never reads as an empty scope.
A malformed line is the third shape: the valid paths are still printed and stderr names how many lines were skipped, so the scope is that list plus whatever those lines held.
The cases are pinned by `_meta/tests/handoff-tail.bats`.

The temporary directories are the one thing dropped, the session scratchpad living there and holding no tracking file.
A path in another repository stays in: a note of `~/dotfiles` written from a project session is exactly the kind of write no other mechanism reaches.

No stamp file means no verifier pass ran in this session, and the whole journal is then the scope, which the script says on stderr and is the shape a session that commits nothing takes.
On any non-zero exit, say which failure it was, then take as the scope the files you know the session wrote after the last pass, naming that the list is yours rather than the journal's.

Do not use `commit-stale.sh` for this list.
Its `excluded()` drops the `.claude/` paths each project ignores and the memory store, and its journal branch drops them again through `in_work_tree_unignored`, which is 117 of the 150 post-pass paths measured on 2026-11-08: the paths this pass exists to read are exactly the ones it filters.

A write made through Bash or by hand is in no journal.
`CLAUDE.md` forbids shell writes, so this bites only on a file the user edited themselves, which `git status` shows for anything not ignored.

## 2. The branch

Branch 2, a brief, holds on one of three reasons and on nothing else:

1. the next step is gated on a `/name` only the user can type (`/design`, `/prune`, `/poc`, `/workflow:sync`, an `/audit:` pass, any skill carrying `disable-model-invocation`);
2. it belongs to another working directory or another repository;
3. it needs a context this conversation has burned, a review of this session's own work included.

Otherwise branch 1, and nothing is written.
An unfinished workstream is not a reason by itself: its plan carries the next step, and a brief that repeats it duplicates the note.

State the branch and the reason in one line before acting on it.

## 3. The brief, branch 2 only

The file is the project's `.claude/HANDOFF.md`, whose lifecycle is in `rules/claude-files.md`, section "`.claude/HANDOFF.md`": it is overwritten whole, carries one prompt, and is never run or proposed for running by you.
Content already there means a previous brief was never consumed: say so and ask before overwriting.

Seven things a brief carries, because the reader has none of this session's context:

1. **The opening line**, which is the `/name` when the brief routes to a gated skill, the rest of the file being its argument; otherwise an imperative title naming the task.
2. **The current state with the evidence that establishes it**: a sha, a dated measurement, a count. Never what you remember.
3. **What the reader must not do**, named: the skill not to invoke, the command that has no CLI route, the pass that would stop at its first step.
4. **The ground truth of each step**, given as the command that produces it.
5. **The bounds and the traps**, each dated and each measured.
6. **What is owed elsewhere and must not be folded in**, with where it is filed.
7. **Where the record goes**: the note that takes the outcome, and the ceiling or the gate that governs writing to it.

The seven points were derived from `eds-prise/.claude/HANDOFF-COMMENTS.md` of 2026-11-08, which satisfied all seven; its buffer was consumed the same day, so there is no example left to read and `DESIGN-HANDOFF.md` holds the derivation.

## 4. The reread

An empty scope means the verifier's own pass already covered every write of the session, which is the case when nothing was written after it: launch no pass, and say so in section 5.
That is the normal shape of a session whose last act was the pass itself, and it is not a clean bill for anything the pass did not read.

Otherwise, mint a new stamp and seal the session's writes under it, the seal being a `sha256` per path rather than their content:

```bash
bash ~/.claude/skills/commit/scripts/writes.sh
```

Copy `STAMP_FILE`, `STAMP_VALUE` and `SWEEP` as printed, and ignore the path list it prints: the scope is the list of section 1, not this one.
Then read `agents/verifier.md` of the `commit` skill and launch a `general-purpose` agent in the foreground, pinned on `sonnet`, whose prompt is that file followed by `REPO`, `WRITES` holding the paths of section 1 alone, `SWEEP`, `STAMP_FILE` and `STAMP_VALUE`.
A fresh context is the whole point: give it no summary of the session and no opinion on what is up to date.
`SWEEP` comes back `no` when a pass already swept this repository today, so section 5 of the verifier does not run again.

**One pass.** Apply its findings with Edit, one at a time, each checked first, a finding the check disproves being dropped and named as dropped.
A finding that calls for a change to code rather than to tracking goes to the user.
Then reseal the paths an applied finding targets, as absolute paths:

```bash
bash ~/.claude/skills/commit/scripts/writes.sh --restamp <path>...
```

The writes those fixes produced are not reread a third time: name them, and say they reach the commit certified by no pass.
Never name in `--restamp` a path no applied finding targets.

## 5. What the pass reports

Three lines, which are the proof the certification exists for:

- the paths reread, and that the list came from the journal's tail;
- what the pass found, each finding with what was done about it, and the paths resealed;
- the branch, with the brief's path when there is one.

Then the closure: an explicit statement that nothing remains to pursue, allowed only when every `Out of scope` entry of this pass and of the pass of `commit` step 0.1.3 has an answer.
Called from `commit`, hand back to its section 0.3 at that point, so that the fixes ride in the blocks of section 0.4 and the commit still marks the closure.
Invoked on its own, end there: a brief is the user's to send, and you neither run it nor propose running it.
