---
name: commit
description: Use before proposing any commit, whether the user asked for one or not, and before writing any `git commit`. Also use to close a session: invoke it yourself as soon as every task of the session is done, without sending the user to `/commit` or asking whether to run it. Also use when a Stop hook (`commit-gate.sh`, `ending-gate.sh`) asks for it.
---

# Proposing a commit

Conduct the conversation in the user's language, whatever the language of this text.

This skill closes out the work in progress, delivers a commit proposal based on the actual state of the repository, then runs it, each call confirmed by the user in the permission dialog.
`git add`, `git rm`, `git mv` and `git commit` are the only git write commands it runs (Git section of `~/.claude/CLAUDE.md`).
No `git commit` block is written outside this skill: the `Stop` hook `commit-gate.sh` blocks a response that contains one when code has been written since the verifier last ran.

## 0. Close out

In this order, skipping none.

### 0.1 Verifier

1. Read the session's write log and the repository's modified files, and record the stamp value **before** launching the agent:

   ```bash
   bash ~/.claude/skills/commit/scripts/writes.sh
   ```

   The script prints `STAMP_FILE` and `STAMP_VALUE`, then the `WRITES` list, which combines the write log with `git status`, because the log sees neither the writes of a session that preceded a `/clear` (the session id changes) nor those made through Bash or by hand.
   It also records the content of every listed file under that stamp value, which the gate and the `git-write-guard.sh` hook compare against: a file whose content is unchanged since then does not count as stale.
   Shell state does not persist from one Bash call to the next: the commands of the following steps take these two values copied exactly as printed, in place of `<STAMP_FILE>` and `<STAMP_VALUE>`.
   Empty list with exit code 0: no write in the session and a clean tree, go to 0.2.
   Exit code 3, with no `STAMP_` line (`CLAUDE_CODE_SESSION_ID` empty or unusable): say so, and still run the verifier on the listed files, without a stamp; the gate will block again the next time commit blocks are delivered outside the continuation it triggered, inside which the marker it wrote when blocking makes it exit 0, and that is the intended behavior.
   Exit code 1 (`git status` failed, or no git repository from the current directory): say so. If the working directory has drifted out of the project's repository (a `cd` persists across Bash calls), `cd` back to the project root and rerun the script. Otherwise run the verifier on the printed list, which then holds only the write log.
2. Read `agents/verifier.md` (next to this file) and launch a `general-purpose` agent **in the foreground**, whose prompt is that file followed by `REPO` (the git root), `WRITES` (the list above), `STAMP_FILE` and `STAMP_VALUE`.
   A fresh context is the whole point of this step: give it no summary of the session and no opinion on what is up to date.
3. Apply its findings with Edit, one at a time, after checking each one: a finding the check disproves is dropped, and named as dropped.
   A finding that calls for a change to code rather than to tracking is not yours to apply: report it to the user.
   Then relay every entry the report leaves under `Out of scope` to the user, one line each, with what is done about it: settled and applied now, recorded as open in the tracking file it concerns, left to the user and why, or nothing and why. No entry is dropped unsaid.
4. Check that the stamp was written (`cat '<STAMP_FILE>'` equals `<STAMP_VALUE>`). If it was not, write it yourself with the same value, and say so.
   If step 3 applied at least one finding, list the paths the gate would now count, computed by the very script the gate calls, against the stamp just checked:

   ```bash
   root=$(git rev-parse --show-toplevel) && bash ~/.claude/hooks/commit-stale.sh "$CLAUDE_CODE_SESSION_ID" "$root"
   ```

   Non-zero exit code: a source could not be read and the list is incomplete; leave the stamp as it is, and say so.
   Empty output, or every printed path is a tracking file targeted by an applied finding (the gate already ignores `.claude/` and memory, but counts `_meta/notes/`, for example): rewrite the stamp and the recorded content together (`bash ~/.claude/skills/commit/scripts/writes.sh --restamp`), otherwise the gate would treat the commit blocks delivered right after these corrections as stale. A non-zero exit code means the stamp was not rewritten: say so.
   If at least one path falls outside that case, leave the stamp as it is and name that path to the user: the gate does not block again within the continuation it triggered (the marker it wrote when blocking), and will only block the next time commit blocks are delivered outside it, which is intended.

This pass does not replace the check the session owes at every tracking write; it catches what that check let through.

### 0.2 Continue or close

A recommendation on what to do next, in one sentence with its reason in one line, or an explicit statement that nothing remains to pursue and the session can be closed.
That statement is allowed only when every `Out of scope` entry relayed in 0.1.3 received an answer; an entry left without one is something that remains to pursue.
When a tracking file (a PLAN, a workstream note) names the next step, base the recommendation on it.

### 0.3 Review

Run `git diff --numstat HEAD` for tracked files, and `git ls-files --others --exclude-standard` then `wc -l` for new files.
Propose `/audit:walkthrough <file> --reviewer posit-dev:critical-code-reviewer` only for a new or changed executable code file with at least 30 changed lines (additions plus deletions).
Executable code means code in a programming language (shell, Python, R, Rust, JS/TS, SQL, Lua, CSS/SCSS, Typst, Perl, bats), or an extensionless file that carries a shebang. Never memory, `CLAUDE.md`, `rules/`, a `SKILL.md` or a configuration file: the user runs those reviews when they want them.
Nor for a file that an `/audit:walkthrough` or an `/audit:blindspot` handled during the session: its fixes close the review cycle, and proposing another review restarts the loop.
New or rewritten prose meant for a reader (README, CHANGELOG, published documentation): propose `/workflow:write <file>`.
Neither: propose nothing, and say nothing about it.
Only the user can invoke these two skills: give the command, do not invoke it.

### 0.4 Blocks

Sections 1 to 4.

## 1. Read the actual state

- `git status --short`, which also shows untracked files.
- `git diff --stat` and `git diff --cached --stat`, then the diff itself, to characterize each change.
- `git log --format=%s -15`, for the types and scopes in use.

The proposal rests on what the diff shows, never on what you remember of the conversation: a change the user made by hand counts as much as an edit made in the session.
A file edited during the session that `git status` does not show goes through `git check-ignore`: if it is ignored, report it as such and keep it out of every staging command, since `git add` on an ignored path fails and breaks the rest of the sequence.
Nothing to commit: say so and stop.

## 2. Split

One commit per independent topic. Whatever cannot stand on its own goes in the same commit: a change and its test, a rename and its call sites, a CHANGELOG entry and what it describes.

Two topics that share a file cannot be split by path: propose a single commit, or name the file that needs `git add -p`.
Name each untracked file, with your advice on whether to include it; if you advise leaving even one out, do not use `git add .` for the commit that would sweep it in.
A file whose name falls within the scope of "Secret files handling" in `CLAUDE.md` stays out of every staging command you propose: report it. The list is kept up to date there; copying it here would make the two diverge at the next edit of either.
Report content that is already staged, since it will be included in the first commit.

## 3. Deliver

Every commit proposal, whether requested or not, carries its message:

- the header alone, with no body, in Conventional Commits format (`type(scope): subject`), the scope taken from the recent `git log` when the repository uses one;
- a short header: 72 characters at most, about 50 as the target, one clause naming what changed, with no "and" joining a second change and no "so that" or "because" justifying it; the detail belongs in the tracking note, not the message. The recent `git log` sets the type and scope only, never the length: many of its headers run past 72 and are no model;
- each commit in its own fenced block tagged `bash`, holding its staging command then the full line `git commit -m "<header>"`; never the header alone, never a command as inline code or in prose;
- several commits: the blocks in execution order, so that each one runs as written;
- every staged path comes from `git status`, never from what the session remembers editing;
- `git add .` from the root when the commit takes everything `git status` shows and no earlier command in the sequence modifies `.gitignore` or runs `git rm --cached`; otherwise explicit paths or `git add -u`, never `git add -A` (see `feedback_commit_sequence_add_all.md`).

Point out in one line what the diff visibly lacks, for example the CHANGELOG entry for a visible change when the repository keeps one, without adding it yourself.

When the commit gate blocked the previous response, start by saying that the blocks already shown are stale and must not be run, then deliver the new ones.

## 4. Execute

Right after the blocks, in the same response, run them, one Bash call per block, in execution order, each holding exactly the text of its block: the permission dialog shows that text, and the user's answer there is the only authorization. A "yes" in conversation is not one, and no call runs a command the blocks do not show.

- The first refused call ends the sequence: run nothing after it, and say which blocks remain.
- A failed call ends it too, a prek hook rewriting a file included: report the output and run nothing more. The rewritten file is newer than the tracking verification, so the next attempt starts from this skill again.
- A refusal from the `git-write-guard.sh` hook is not a failure to work around: it names the reason (a rerouted form, `--no-verify` or `--amend`, a git write left to the user, files changed since the verification). Follow what it says, never another form of the same command.
- A block the user must run themselves (a `git add -p`, named in section 2) is left to them: say so, and stop the sequence before it.
- So is a block holding any command other than `git add`, `git rm`, `git mv` or `git commit`: stop the sequence before it, and say which blocks remain.

## After

Once the sequence has run, or when the user says they ran it, check with `git log --oneline -<n>` and `git status --short` that it produced what was proposed.
