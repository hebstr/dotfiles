# Versioning `.claude/`

The tracking notes of a project are versioned in a nested git repository that never leaves ju-TP, and the `commit` skill is what produces its commits.
`~/dotfiles` left that form on 2026-11-07 and is now the one exception, its notes tracked by the parent repository: the section "The premise that chose the nested form fell, and one refusal did not" holds what changed, and the dated sections below stay as the record of the decision they describe.

## The decision (2026-09-30)

The subtractive criterion of `rules/claude-files.md` ("Content") sends a step taken, a parameter changed and a verification passed to the commit message and to `git blame`, and no `.claude/` had either, so the criterion deleted instead of moving.
`~/dotfiles/.claude/.git`, initialized on 2026-09-30 with no remote, becomes that destination, its import landing the same day as `42fb9ab`:

- the form stays the nested repository ignored by the parent, whose `.gitignore` already carries `/.claude/`;
- the history stays local to ju-TP, decided by the user on 2026-09-30, so no remote and no exception to `.stignore`, whose `.git` entry has no leading slash and therefore excludes the history at any depth;
- the initial import is the user's, run in their own terminal, once, and by policy rather than by a check: the measurement of 2026-09-30 that made it unrunnable by an agent was voided the same evening by the journal-authorship rule, which reclassifies a dirty file no write journal names as the user's own edit, so nothing refuses an import any more;
- the other `.claude/` under `~` get a repository at the user's first visit to each project, on their request (decided 2026-09-30), with no script and no batch initialization, so the window where a cut would have no destination is theirs to close. The adoptions, the count of the ones still without one and the commands that re-derive both are in `project_claude_dir_local_only_repo`.

Rejected with that last point, and not to be re-proposed: a clause in the "Content" section of `rules/claude-files.md` warning that the criterion's destination exists only where `.claude/` has a first commit, with `git -C .claude log --oneline -1` as the check.
It answers a situation the user's plan prevents.
The routing test sends nothing to the global `CLAUDE.md` either: a deterministic mechanism already enforces the commit (section 5 of the `commit` skill, and the guard), the always-loaded set sits against its byte budget, and a new root line needs the same behaviour corrected twice.

## Why the nested form, the three others being answers to a question the user closed

Each of the three exists to make the history leave the working tree or reach another machine, and replication was refused:

- `git init --separate-git-dir` moves the history out of the synchronized tree under a name `.stignore` does not exclude. Without replication it buys a `.git` pointer file and one more path to know about.
- A bare repository with `GIT_DIR` and `GIT_WORK_TREE` leaves no `.git` in the tree and needs a wrapper, which the four scripts resolving `git rev-parse --show-toplevel` would each have to learn.
- A submodule or a subtree makes `.claude` a path the parent tracks, therefore pushed to `github.com/hebstr/dotfiles`, which the user refused.

The first clause of this section fell on 2026-11-04: see "The premise that chose the nested form fell, and one refusal did not (2026-11-07)".

## Why the skill produces the commits, a hook being the wrong holder

The destination the criterion names is the commit message, so what writes that message decides whether the discipline works at all.

- A hook or a cron committing on its own writes no message worth reading, and puts a git write outside the contract that `git-write-guard.sh` and the `ask` rules of `settings.json` enforce, where every git write is confirmed by the user.
- The user committing by hand costs nothing to build, and makes the destination exist only when they think of it, while the criterion fires in every session. `PRUNE-OBSERVATIONS.md` records that over-firing has a backstop and under-firing has none.
- Narrowing the rule instead, so it stops naming a destination that does not exist, is the alternative that builds nothing. It reinstates the inflation the rule of 2026-09-30 was written against.

## `commit-stale.sh` is not corrected, its interference being what checks a `.claude` commit

The `excluded()` of `commit-stale.sh` compares `$root/.claude/` and `$top/.claude/`, which become `.claude/.claude/` when the root is `.claude` itself, so the exemption evaporates.
That is the behaviour to keep, and `DEFERRED.md` no longer carries the row that called it a defect: the evaporating exemption is what makes every file of a `.claude` commit pass the staleness check, file by file, and correcting it would exempt all of them and let any commit through, the bulk import included.
Both sides are pinned in `_meta/tests/commit-stale.bats`, by "checks the files of a .claude commit when .claude itself is the root" against "leaves out the project's .claude directory and the memory directory" and "leaves out the repository's own .claude directory when the root is a subdirectory of it".

## What the paired blocks give up, and it is not the check

Delivered in the same response as the parent's block, the `.claude` block escapes the `Stop` gate: `git-write-guard.sh --verdict` refuses the pair, so `commit-gate.sh` falls back to the repository-wide `commit-stale.sh` on the parent root, which excludes `.claude/`.
Nothing is unchecked when it runs: at `PreToolUse` each command is judged on its own, and exactly.
What is lost is the early warning, not the enforcement.

## What the repository leaves out, and why the capture rule still holds

`screenshots/` is 95 PNG and nothing else, `pdf-tables-eval/` is 16 PDF for 17 MB **and** 6 markdown files that are the evaluation's results, which is why the ignore rule is `*.pdf` and not that directory.
Ignoring `screenshots/` is what keeps "a capture is never versioned" of `rules/chromium.md` ("Where verification captures go") literally true in both repositories.

## The gate the repository carries (2026-09-30)

Two corrections of 2026-11-07, this section keeping its wording as the record of what it decided. `~/dotfiles/.claude/prek.toml` no longer exists, deleted with the nested repository, so what follows is the prescription an adopting project applies rather than a file this tree carries. And the `panache-format` paragraph below was overtaken the day after its measurement: `f63bd64` (2026-10-17, "keep panache out of the tracking notes") put `^\.claude/` in the parent's own `exclude`, so the exclusion is the parent's and no longer rests on the nested file carrying no such hook.

`.claude/prek.toml` holds three hooks, installed on 2026-09-30, the day the repository took its first commits: `end-of-file-fixer` and `check-merge-conflict` from `pre-commit/pre-commit-hooks`, `gitleaks` from its own repository, both revs already pinned in the parent's `prek.toml` so only two upstreams need keeping in step. That same file travels byte for byte to an adopting repository, decided on 2026-10-04 at the user's request, so an adoption adds no upstream to keep in step.
`gitleaks` is what makes the set worth having: the parent ignores `.claude/`, so 855 KB of notes had never been scanned at commit time, and a hand run on 2026-09-30 found nothing, which makes it a forward guard rather than a backlog.
Four candidates were measured and refused on their backlog, and that measurement is the refusal's whole ground. `prose-lint` fails 0 of the 25 it lints, `DEFERRED.md` being exempt by basename, the `PreToolUse` hook having kept them clean. `trailing-whitespace` finds none. `check-added-large-files` sits at 500 KB against a 206 KB maximum and would never fire. `refs-lint.py` exits 1 on 5 of the 26 with false positives verified one by one, and its second pass returns no verdict by construction, so it stays hand-run per `rules/claude-files.md`.
`panache-format` is excluded by policy, every `.claude/` tree being Claude-facing.
That exclusion is the nested `prek.toml` carrying no such hook, and it is not a property of the path: the parent's own `panache-format` exclude does not reach `.claude/`, so `prek run --files .claude/<note>` from the dotfiles root does reflow a note, measured 2026-10-16 (`project_qmd_format_hook`).
Re-measured on `R-hebstr/.claude` before installing there, the four came back with the same empty backlog; `eds-prise/.claude` on 2026-10-04 is the one exception recorded, with **2 trailing-space hits**, both the `metadata: ` line of a memory frontmatter. They do not reopen the refusal of 2026-09-30 on their own, sitting in YAML where the space changes no parse, so the hook would buy a cosmetic rewrite of two files. Whether that is worth a fourth hook is the user's call and nothing here depends on it.

## The premise that chose the nested form fell, and one refusal did not (2026-11-07)

The section "Why the nested form" rejects its three alternatives on one premise, that each "exists to make the history leave the working tree or reach another machine, and replication was refused".
Replication now has a consumer: `cpd000001` runs opencode since 2026-11-04, has no network path from ju-TP, and reaches the public dotfiles repository alone (`_meta/notes/opencode-cpd-setup.md`), so the tracking notes have a reader on another machine.
What did not fall is the other refusal of that section, pushing `.claude/` to `github.com/hebstr/dotfiles`, which is public (`gh api repos/hebstr/dotfiles`, `"private": false`).
That refusal alone now decides the form, and it is the user's to lift.

**Ruled on 2026-11-07: the past history is archived as a bundle and not imported into the parent, the notes being tracked there from the next commit on.**
The user stopped the import on its length, twice, against a session that had come to recommend it: the filter, the aside move, the fetch, the merge and the copy-back are five steps and one unmeasurable one for a gain of `git blame` in place.
The import analysis below stays as the rejected alternative, with its measurements, so that reopening it costs a reading rather than a rerun.

Carried out the same day. The user took the bundle (`~/archive/pro-dotfiles/claude-notes-2026-11-07.bundle`, 1.6 MB on disk, `git bundle verify` reporting a complete history) and removed `.claude/.git`; the session then took five mechanisms, each verified rather than assumed:

- the parent's `.gitignore` lost `/.claude/`, and `.claude/.gitignore` gained `DESIGN-SSH.md` and `DESIGN-GPU-REMOTE.md`, which `git status --ignored` returns as `!!` beside `PROMPT.md` and `settings.local.json` while `git check-ignore .claude/DESIGN-CPD.md` exits 1;
- `.prekignore` gained `.claude/` and lost it again the same day, the premise having failed under measurement: prek 0.5.10 does not discover `.claude/prek.toml` as a sub-project, tracked or not. `prek list` prints every hook under the single `.:` project and no `end-of-file-fixer` in either state, which is the hook only that file declares. The `_meta/profiles/` entry of `.prekignore` may be obsolete for the same reason and was left alone;
- `.claude/prek.toml` is deleted here rather than tracked, nothing being able to run it. The session first kept it as the one copy a push would back up, and dropped that on the user's question: the prescription has two sources already, this note's "The gate the repository carries" naming the three hooks and their two upstreams, and the parent's own `prek.toml` pinning both at the same revisions (`v6.0.0` and `v8.30.1`, compared file to file), so the bytes are reconstructible without a file nothing runs. The census behind the abandoned argument stays useful: 55 `.claude/` directories under `$HOME`, 12 holding a nested repository, 14 holding that gate file, all 14 byte-identical at sha `adc04fd7c538`, and the 12 living copies sit under `~/Documents`, which Syncthing replicates to three machines. An adoption therefore copies from any of them. `collab-comments/.claude` holds the same file with no repository either, so its copy is dead too, which predates this change;
- of its three hooks the parent already carried `check-merge-conflict` and `gitleaks`, and `end-of-file-fixer` was the one the move would have dropped, so `prek.toml` gained it scoped to `files = '^\.claude/'`. Repo-wide would have been wrong: 8 tracked text files lack a final newline and 5 of them are rewritten by their own tools (Positron profiles, `graph.json`, Handy's settings store, `.skill-lock.json`, `rstudio-prefs.json`), so the hook would fight them at every commit. Scoped, its backlog is 0, measured on the 34 notes themselves (none lacks a final newline) rather than through `prek run end-of-file-fixer --all-files`, which answers "no files to check" while `.claude/` is still untracked and therefore proves nothing about them;
- `excluded()` of `commit-stale.sh` no longer exempts a `.claude/` path outright: it exempts one the repository ignores, through `git -C <base> check-ignore`, so the exemption follows the convention instead of the path. Measured on the two shapes: `~/admin/pro-cv`, which held the only nested `.claude/.git` left under `$HOME` that day, answers exit 0 and keeps the exemption, dotfiles answers exit 1 and is checked. `_meta/tests/commit-stale.bats` carries the ignore rule in the two tests that rely on the exemption plus one new test for the tracked case, 55 tests green, and the shell gate passes on both files. `_meta/tests/commit-gate.bats` needed the same treatment, which is what pre-running the whole suite caught before the commit hook would have: the gate calls `commit-stale.sh`, so five of its tests rested on the old blanket exemption too, and they now declare the ignore rule through the same `ignore_claude` helper, with one new test pinning the blocking case. The whole suite is 1849 green;
- section 5 of the `commit` skill is skipped for dotfiles, where `git -C .claude rev-parse --git-dir` now resolves to the parent's own `.git` and would read as a project without a tracking repository. The discriminator written there is `git -C <project>/.claude rev-parse --show-toplevel`, verified to answer the project root on dotfiles and `<project>/.claude` on `pro-cv`;
- the lead sentence of this note names the exception, while the dated sections keep their original wording as record, per the "drifted reference" rule of `rules/claude-files.md`.

What this costs from now on, stated once: the notes and every tracking commit message are public, and the two excluded notes are versioned nowhere, their history living only in that bundle.

Open, found by the commit verifier the same day and left to the user: that exclusion protects less than it looks. `_meta/notes/ssh-lan-server.md`, `ssh-lan-wsl.md`, `ssh-lan-mdns.md` and `wsl-init-tuto.md` are tracked and already public, and they carry two of the host names and one of the addresses. What the two excluded notes still keep out is the remaining address, the second private range and the SSH and GPU reasoning around them. It predates this change and is no regression, so nothing was scrubbed: deciding whether those four notes should be redacted, or whether the exclusion of the two is then pointless, is the user's.
Measured the same day, so that nothing below is re-derived:

- Any resolvable `.git` entry at `.claude/` makes the path a gitlink to the parent, and the parent's ignore rule is not what hides the content. On a fixture holding the notes and their history, `git add .claude` stages `160000` under `warning: adding embedded git repository`, while `git add .claude/<note>` exits 0 and stages nothing at all. Tested with `.git` as a directory and as a `git clone --separate-git-dir` pointer file to a live repository: both give the gitlink, so moving the git directory out of the tree buys nothing while its pointer stays. With no `.git` entry, the same `git add .claude` indexes the 37 files.
- The parent honours `.claude/.gitignore`, so the convention's four exclusions need no restating in the parent's own file: on that fixture `PROMPT.md` and `settings.local.json` come back `!!`.
- The parent's gate takes the notes as they stand: `prose-lint` over the 31 notes and the 6 of `pdf-tables-eval/` exits 0 with no output, `panache-format` already excludes `^\.claude/`, and the largest note is 164K against the 500K of `check-added-large-files`. `.claude/prek.toml` would be discovered as a sub-project, which `.prekignore` is the mechanism against, as its `_meta/profiles/` entry already is.
- What a push would publish beyond the notes themselves: `DESIGN-SSH.md` and `DESIGN-GPU-REMOTE.md` carry the LAN topology, private ranges holding no credential, and every future tracking commit message, which the subtractive criterion fills with what a pass cut. Excluding those two notes through `.claude/.gitignore` costs their future versioning and nothing else, their history staying in whatever the nested repository becomes.
- The 266 past commits are not importable as they stand: `git log --diff-filter=D --name-only` lists 16 deleted `pdf-tables-eval/*.md` totalling 1.27 MB, which are full-text Markdown conversions of published articles rather than table excerpts, the `vaswaniAttentionAllYou2023.md` blob alone running to 42 KB and carrying Google's own notice limiting reproduction permission to tables and figures. A git history does not publish in part: a push carries every blob it ever held.
- Scanned over `git rev-list --all` on 2026-11-07, which bounds what a filtered import would still carry: the twelve author e-mail addresses found are third parties' personal data and sit in those same files only; so do every digit run of eleven characters or more, three of them traced individually to an ISSN, a phone number and a table figure, with no credential and no patient identifier anywhere. The LAN topology is the one thing outside them, in all 266 commits. A filter removing `pdf-tables-eval/`, `DESIGN-SSH.md` and `DESIGN-GPU-REMOTE.md` therefore makes the history publishable, and the only price left is those two notes having a history nowhere but the backup bundle. One correction to that scan, so it is not repeated: the hospital markers it first reported in ten notes were `IPP` matching inside "skipping", "flipping" and "stripping", and the notes hold no patient data. `filter-repo-rs --detect-secrets` over the same reachable history reports 0, which is the tool-side confirmation of the manual greps.
- The filter is one pass of `filter-repo-rs`, the tool the user already runs (1.0.5 in `~/.cargo/bin`, kept current by `sys-update cargo` per `_meta/notes/environment-archive.md`), so no tool has to be installed and `git-filter-repo` is not the reference here. Measured on a clone on 2026-11-07: `--path pdf-tables-eval --path DESIGN-SSH.md --path DESIGN-GPU-REMOTE.md --invert-paths --to-subdirectory-filter .claude` keeps all 266 commits, puts every surviving path under `.claude/`, and leaves the three removed paths in no commit of `--all` with no `pdf-tables-eval` blob reachable. It writes `.git/filter-repo/commit-map`, 266 lines, in which all 20 cited hashes resolve, so re-anchoring those citations is mechanical rather than archaeology. `--backup --backup-path <file>` folds the archive bundle into the same command, taken before the rewrite. Run it on a clone and never in place: `--to-subdirectory-filter .claude` applied inside `~/dotfiles/.claude` would relocate the worktree to `.claude/.claude/`.
- The import step itself is unmeasured and stays so: `git-write-guard.sh` leaves `git merge` to the user, so nothing here establishes how `git merge --allow-unrelated-histories` behaves. What is known independently is that git refuses a merge that would overwrite untracked files, so the notes are moved aside before it and the files the filtered history does not carry are copied back after, rather than relying on the merge to tolerate them.
- The archive form is a bundle rather than a moved git directory, measured the same day: `git bundle create … --all` from `.claude` writes **1.8 MB** where the loose objects occupy 16 MB, `git bundle verify` reports a complete history, and `git clone` on that file returns the 266 commits at `151f58e`. `~/archive` is a send-only Syncthing folder shared with ju-TP2-ubuntu, ju-GO and ju-DG, where `~/.local/share` is in no folder, so a bundle placed there replicates to three machines and closes the one-disk point of the section below. The bundle is taken before any filter, which is what keeps the two excluded notes' history.
- Two mechanisms would need the dotfiles exception, neither of them optional: `excluded()` of `commit-stale.sh` filters `$root/.claude/*`, so notes committed from the parent root leave the staleness gate, and section 5 of the `commit` skill prescribes a block inside a nested repository that would no longer exist here while it still exists in the other projects.

A hand copy of the notes onto cpd was accepted as the quick form on 2026-11-07, before this question reopened. Its cost is that the copy never updates, and that opencode loads neither `.claude/CLAUDE.md` nor `.claude/memory/MEMORY.md` from `dotfiles/.claude`, both absent there, while those two paths are its whole `instructions` list (line 38 of the tracked `opencode.json`): a pasted tree is read only when a prompt names it.

### The confidentiality read before the push (2026-11-08)

Four parallel agents read the 28 tracked paths plus the 6 `pdf-tables-eval/*.md` of `4cfa875`, 34 files and 6,282 lines, each applying an eight-category taxonomy to its own group so no file was read twice.
Do not rerun it.

Two measurements of this section are wrong and are corrected here, which `git log --all -S` over every reachable commit established where a grep of the two tips had missed it.
The author e-mail addresses did not sit in the deleted article conversions only: three were quoted as examples in this note, and the LAN values were too, so the note reporting the scan carried what the scan found.

Five passages were ruled unpublishable and are redacted inside the commits that introduced them, never in a commit on top: the warehouse schema with the study table name, the three e-mail addresses, the three LAN values, the named reviewer's graded work, and the whole-table reproductions of the deleted corpus.
Two findings are already public and no remedy reaches them.
The warehouse schema pair shipped in a memory since deleted, reachable from `2520b65`, an ancestor of `origin/main`.
The `cpd` machine identity, its account names, its hardware and its free-port census ship in the tracked `_meta/cpd/cpd-recon-*.log` and in four `_meta/notes/` files.
Removing either means rewriting published history on a public remote, weighed and refused: the exposure predates the push, and a force-push breaks the one replication channel `cpd` depends on.

`.claude/.gitignore` became deny-by-default the same day, `*` followed by 21 exceptions, superseding the two named exclusions recorded above.
Seven tracked notes are left out deliberately, four because the read found a passage in them and three because no opencode session on `cpd` could act on their subject.
The form was chosen over a longer exclusion list because a note written next month is then private until someone lists it, where allow-by-default made every future note public and owed a fresh read each time.
The cost is that an unlisted note stops reaching `cpd`, which for these seven is nothing.

Two mechanical facts govern the push, neither optional.
A `.gitignore` entry untracks nothing, so the seven need `git rm --cached` inside `4cfa875`.
And no `.claude` path exists in `origin/main`, so every blob sits in `4cfa875` except `DESIGN-CPD.md`, which entered at `0c701d1`.

Open, with the condition a command can check: `git log --all -S` finds the three e-mail addresses, the three LAN values, the study table name and the reviewer's name in no commit, and `git ls-tree -r 4cfa875 .claude` lists neither `pdf-tables-eval/` nor the seven unlisted notes.
The warehouse schema pair stays findable at `2520b65` by the decision above.
Also open: the archive bundle's filename sits in five tracked files that all reach the push, so redacting it in one is void and the five are one decision.

## Open

The weakest assumption, untested before a real closure: that a commit message written at closure carries what the criterion deleted.
A message reading "update tracking" loses the deletion exactly as today, which is why section 5 of the skill prescribes naming what was cut.

The history exists in exactly one place: `.stignore` excludes `.git` at any depth, so Syncthing replicates the notes and not their history, and no backup covers it either.
A reinstall or a lost disk therefore keeps the notes and loses their history, and `git clean -xdff` in the parent destroys it outright, which is why `git-write-guard.sh` leaves `git clean` to the user.
That is the price of the replication the user refused, not an oversight.
