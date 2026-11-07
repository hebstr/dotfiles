# PRUNE-OBSERVATIONS.md

What pruning a tracking file actually takes, as the motifs of thirty-six passes, the per-pass records they were lifted from having gone on 2026-10-14.
The criterion and three of its motifs became a rule on 2026-09-30, in the global `CLAUDE.md` and in the "Content" section of `rules/claude-files.md`, recorded in the section "The criterion is now a rule, the root carrying one clause and the scoped file the whole test" below.
The procedure was routed to a skill on 2026-10-16, once the campaign had measured that the rule alone cuts nothing; the decision is the last section of this file, and the skill was built the same day at `claude/.claude/skills/prune/SKILL.md`.

Criterion in force, from recommendation 3 of the `/workflow:reco` of 2026-09-29 on tracking-file governance: **an executed decision is deleted, unless it records a rejected alternative or a constraint that still binds future work.**
Recommendation 4 gives its positive form: a durable record is reserved for the decision whose rejected alternative would be re-proposed without it.
Everything else (a step taken, a parameter changed, a verification passed) belongs to the commit message and to `git blame`.
That reco left no report anywhere in the repository, so both recommendations survive only as quoted just above, and their ordinals resolve nowhere.

## The corpus of the deep pass, and where it stands

Opened on 2026-09-30, once `.claude/` became a repository of its own (`DESIGN-CLAUDE-REPO.md`), which is what changed the price of a cut: a deletion is recoverable from `42fb9ab` on, where the three passes of 2026-09-29 had to be right the first time.
That recoverability changed hands on 2026-11-07 and every `42fb9ab`-based hash in this file with it: the nested repository is gone, the parent now tracks these notes, and `git cat-file -e 42fb9ab` fails here, so reaching any commit before the move means cloning `~/archive/pro-dotfiles/claude-notes-2026-11-07.bundle` first and running the command there. From the parent's own first commit of these notes on, `git log` in `~/dotfiles` prices a pass as that nested history used to.
**That recoverability is thinner than it reads, checked 2026-10-13:** `.stignore` excludes `.git` at any depth so Syncthing never replicates it, and the one backup script syncs `cpd000001`'s home rather than ju-TP's, so this history sits on exactly one disk.
Content a pass cuts and nothing else holds is therefore moved into the dotfiles repository proper, a memory or `_meta/notes/`, rather than left to `git show`; the fact is in `project_claude_dir_local_only_repo`.
The three earlier passes touched one file; of the twenty-seven others, twenty-one were passed and two have never had a pass of their own, the `Pass` column below being the one copy of where each stands and the `Next` column the verdict of the corpus-grain inventory of 2026-10-13, which read all of them.
Those counts run over the table's 30 rows less `PLAN-SESSION-DISCIPLINE.md`, `DESIGN-COMMIT-GUARD.md` and the `pdf-tables-eval/` directory row, and a pass of this file itself never counts as one of them.
Twenty-one plus two falls four short of twenty-seven because four rows are neither: this file, passed but never counted, and `CONTINUE-OPENCODE-CPD.md`, `PROMPT-PDF-TABLES-EVAL.md` and `PLAN-SQL.md`, all three deleted.
`DESIGN-COMMIT-GUARD.md` is the thirtieth row and counts in neither set: it was created on 2026-10-15 out of the plan's commit-guard half and has had no pass of its own, but it is not a never-passed row either, the content having come out of three.
`DEFERRED.md`, `DESIGN-POSITRON-THEME-FILTER.md`, `ANTI-SYCOPHANCY-PLAN.md`, `RECO-SESSION-DISCIPLINE.md` and `PLAN-PYREFLY.md` left the never-passed set on 2026-10-14, each on its first pass of its own.
**Recount the `—` rows rather than carrying this figure: a deletion moves it, and so does a note created since the last reading.** Four writings of this count have been wrong, every time because a figure was carried instead of recounted.
Line counts in the table are the reading taken when each row was last read for this, and they move with every session, so the figure is a starting order rather than a target.
Re-reading the whole column is its own pass; a pass updates the rows it touches.
**The drift is not entropy: it tracks which files are being worked.** The inventory of 2026-10-13 found the column out on ten of the twenty-three comparable rows, against eight on 2026-10-08, and the worst of it was the file the routing pass had cut by 46 lines and which had gained 135 since, where six of the nine passed rows had not moved by a line.
`DEFERRED.md` is the one negative drift the campaign has met, a file that shrinks as its rows get closed.
**The never-passed rows are exhausted as a source of targets**, and the two left are both keeps, so every target from here is a second pass of a row whose `Next` cell reads "little left".
`PLAN-PYREFLY.md`, the last never-passed row that was not a keep, was passed on 2026-10-14 and answered the question its row had carried: `rules/python.md` and `rules/install.md` did hold nearly all of it, and 87 % of the file went in one pass.
**A note written in the same lot as the rules file that carries its content is prunable to a frame from the day that lot lands**, which is the shape to look for rather than size: the inventory read ~70 lines and the pass gave 151.
`DESIGN-POSITRON-THEME-FILTER.md` is now the smallest row of the corpus outright at 4,331 bytes, under `DESIGN-BATS-HOOK.md`'s 6,188, which is a keep.
The four files above 40 KB other than it are still all spoken for, as the rows below state.
Share no longer picks the target, and an estimate now reads high where four passes running had met theirs: `RECO-CLAUDE-MD-ARCHITECTURE.md` was read at 47 %, the highest of any never-passed English row, and delivered 31 % of the lines; the four that followed gave 43 of the ~45 read, 48 of the ~45, 41 of the ~30 and 47 of the ~45; then `PLAN-LUA.md` gave 23 of ~35, `DESIGN-CADRER.md` 32 of ~50 and `DESIGN-WINDOWS.md` 8 of ~20, 66 %, 64 % and 40 %, all three on a second pass of a row.
**The five widest shortfalls, derived over the nineteen estimates the records and this head stated, seventeen of them in a record that has since gone and two only here, are `DESIGN-WINDOWS.md`'s 40 %, `ANTI-SYCOPHANCY-PLAN.md`'s 44 %, `RECO-SESSION-DISCIPLINE.md`'s 47 %, `PLAN-ORPHANS.md`'s 38 of ~70 and `DESIGN-SSH.md`'s 28 of ~45.** That withdraws the reading that made 66 %, 64 % and 40 % three of the four widest, and `PLAN-LUA.md`'s 66 % the widest when it was written: neither was derived over every estimate the records state.
**A first pass undershoots as well**, and the rule that read the other way is withdrawn: `DESIGN-POSITRON-THEME-FILTER.md` gave 9 of ~13, 69 %, `ANTI-SYCOPHANCY-PLAN.md` 11 of ~25, 44 %, the second widest shortfall of the campaign, and the 47 % read on `RECO-CLAUDE-MD-ARCHITECTURE.md` was 37 lines delivered against ~55, 67 %, a figure this paragraph had carried as a share of the file instead.
**And a pass overshoots**, which withdraws what was left of the rule: `PLAN-UPDATER-HYGIENE.md` gave 26 of ~15, 173 %, and `PLAN-PYREFLY.md` 151 of ~70, 216 %, the widest of the campaign.
The estimate carries no direction at all, and the one thing the inventory reliably under-reads is a note whose content sits in another file the same lot wrote, whether a rules file or the scripts and comments of its own artefacts, neither of which it opened.
What is left in this file is the motif list, the tool's catalogue and the reserve.
**Measured against the import on 2026-10-14, the campaign was net additive and this file was why.** By `git ls-tree -r` at `42fb9ab` against `5fdfe79`, notes only and `pdf-tables-eval/` excluded, the corpus went from 27 files, 5,145 lines and 760,057 bytes to 25 files, 5,459 lines and 875,728 bytes, up 15.2 % in bytes; the corpus **without this file** went from 737,879 bytes to 667,391, down 9.6 %, while this file went from 22,178 to 208,337, up 186,159, which is 2.64 times what the passes removed from everything else and 23.8 % of the corpus.
**So no further pass could reach the objective**, a pass adding about 27 lines of record here to remove 8 to 47 from a smaller row, and the decision below took the register instead of another row.
**What the thirty-six per-pass records were for was settled by the user on 2026-10-14: the motifs, and nothing else.** Lift and drop was taken over keeping the records while cutting their apparatus, and over keeping the file as it stood on the ground that the records were the deliverable.
Priced before the cut, the thirty-six `## Pass of` sections held 186,018 bytes, 89.3 % of the file, their 309 bullets carrying 298 bolded motif leads over 22,776 bytes of lead text, against 1,025 bytes before the first `##` and 21,294 in the two other `##` sections.
The second option had at most 37 KB of room in the 49,573 bytes of non-bullet record, the pass of 2026-10-14 having already taken the figures, the rankings and the tallies out of it, and reached no objective at all.
**The cut took this file from 208,337 bytes to 58,720 and the corpus to 726,531, 4.4 % below its 760,057 at the import, which is the objective met.** Both figures are `git ls-tree -r` at `d565466` rather than a reading of the working tree, which a concurrent session moves.
It is 2.1 times what the thirty-six passes removed from every other note put together, 70,488 bytes, and no other move on the table reached it.
What remained after it was the split `PLAN-SESSION-DISCIPLINE.md` owed, done on 2026-10-15, and the regrouping no pass has ever attempted, a `merged into|fusion|regroup` search over this file matching nothing at `9121341`, before this paragraph wrote the pattern into it and made the search match itself: the converse of the false negative this file already records, where quoting a dead name silences the check for it.
The two rows with no pass of their own are `DESIGN-CPD.md` at 16,932 bytes over 113 lines and `DESIGN-BATS-HOOK.md` at 6,188, both keeps.
**An inventory's estimate is read against what a pass may touch, never against the file.** `DESIGN-TRANSCRIPTION.md` was read at about 210 cuttable lines of 512 and gave 228 net, the memory that holds its decisions being a stronger holder than the inventory could see; `DESIGN-INSTRUCTION-ROUTING.md` went the other way, 90 net against about 120, because a third of the file was already protected by the arbitration of `TRIAGE-MEMORY.md`, and an inventory taken file by file cannot see a ruling held in another row.
`DESIGN-CLAUDE-REPO.md` gave 41 against ~30 for the symmetric reason, one memory holding the executed half of nearly every section, and the inventory read no memory at all.
The language order is unchanged and still points the other way: the three rows pruned on 2026-10-14 owed only their migration and all three took it on 2026-10-16, `PLAN-PYREFLY.md` and `ANTI-SYCOPHANCY-PLAN.md` in pass 1 and `RECO-SESSION-DISCIPLINE.md` in pass 2, and the row pruned on 2026-10-13 took pass 3 the same day, `PLAN-SESSION-DISCIPLINE.md` taking pass 4 on 2026-10-16, `DESIGN-COMMIT-GUARD.md` closing the campaign as its last French row in pass 5 the same day.
Those six are a campaign of their own from 2026-10-16, and `DESIGN-CADRER.md` § "The six French `.claude/` notes are finished as a campaign" holds its order, its register and the inbound citations a rename repoints: the figures this paragraph carried are there instead, recounted: `ANTI-SYCOPHANCY-PLAN.md`'s had drifted from 54 to 64, and `TRIAGE-MEMORY.md`'s 57 was the length of its French block where the register counts accented lines, a change of measure rather than a drift.
A migration is never one of the passes this file counts, and the `Next` column's "migrate its N French lines" verdicts are the inventory's reading of 2026-10-13 rather than live figures.
Taking a French row still means splitting the work, prune first and migrate second, under the re-authoring constraint of `DESIGN-CADRER.md`, and the pass says which it is doing.
`PLAN-PYREFLY.md` had been named as next on 2026-09-30 because its "Adversarial review" was then the last of the three passages targeting the deleted `rules/environment.md` still untreated, and half that reason was spent on 2026-10-01 in `a6e139a` when the obsolescence note was added outside any prune pass.
Its pass of 2026-10-14 closed neither half: the bullet stayed verbatim, the retarget being the user's call, so a tracked item survived the pass that was supposed to consume it.
**The corpus-grain inventory of 2026-10-13 read the twenty-six notes the corpus then held and the six of `pdf-tables-eval/`, and the `Next` column carries its verdict per row**, about 1,730 lines of 7,246 judged cuttable.
The same day's deletion of `PLAN-SQL.md` and cut of `DEFERRED.md` took the corpus to twenty-five notes and 7,149 lines.
Four verdicts are not prunes.
`PLAN-SESSION-DISCIPLINE.md` splits: its « Implémentation du noyau » is 724 lines, 52 % of the file, and is a commit-guard mechanism with its own eleven walkthrough blocks and three live `DEFERRED.md` rows rather than a part of the measurement campaign that opened the plan. <!-- prose-lint:ignore -->
**Run on 2026-10-15 as `DESIGN-COMMIT-GUARD.md`, the user's name, and the French carried over verbatim, the user's call too: the migration stays a pass of its own because the move leaves 197 accented lines in the plan against 128 in the new note, so translating one half would split the debt rather than close it.** The section measured 719 lines at the cut and not 724, and the walkthrough blocks fourteen and not eleven, both figures having been read from section titles rather than from the file.
`DESIGN-CPD.md` and `DESIGN-BATS-HOOK.md` are keeps, the first a chantier whose every step is still untested, the second 61 lines of rejected options, a dependency table nothing else holds and one unresolved residual.
`PLAN-SQL.md` was deleted the same day, below.
The three verdicts the inventory could not settle alone, and which the user owns, are the two French rows that would be re-authored rather than translated and the name a split would give the new note.
`DESIGN-POC.md` was called a row and not a candidate on 2026-10-08, on the ground that a chantier closed the same day leaves nothing executed to cut; its pass five days later gave 48 lines, so a note written beside its own artefact is prunable from the day the artefact exists.

```
| File                            | Lines | Pass | Next, by the inventory of 2026-10-13 |
|---------------------------------|-------|------|--------------------------------------|
| PLAN-SESSION-DISCIPLINE.md      |   495 | three passes, 2026-09-29 and 2026-09-30; 2026-10-15, the split, 242,057 B to 61,880 and 1,398 lines to 495, 835 moved out and 68 cut | migrate its 197 French lines; little left to prune: the baseline count step 4 still compares, "Framing of step 3", the rejected lists, the ending-gate bench with its verdict, the `reco-relance.bats` walkthrough and the open points are the reserve |
| DESIGN-COMMIT-GUARD.md          |   867 | created 2026-10-15 by that split, 164,538 B, its moved bullets trimmed by 8 lines; written to the same day, 845 lines to 867 and 128 French lines to 132, two records added | migrate its 132 French lines; nothing else to prune yet: the fourteen walkthrough blocks, the rejected lists, the irreproducible measurements and the five open points are the reserve |
| TRIAGE-MEMORY.md                |   281 | 2026-10-13, 81,861 B to 35,956 and 552 lines to 281 | migrate its 57 French lines |
| DESIGN-INSTRUCTION-ROUTING.md   |   430 | 2026-09-30, from 455, 75 lines cut against 29 added, 35 moved to memory; 2026-10-13, 74,035 B to 61,133 and 544 lines to 454; 2026-10-14, 61,133 B to 58,693 and 454 lines to 430 | little left: the same 158 lines are protected by the arbitration and the reserve, and the routing test now lives only in `rules/claude-files.md` |
| DESIGN-TRANSCRIPTION.md         |   284 | 2026-10-13, 71,915 B to 41,008 and 512 lines to 284 | done, 228 net against the ~210 read |
| PRUNE-OBSERVATIONS.md           |   331 | 2026-09-30, 60 lines cut against 49 added; 2026-10-13, 451 to 550 over four records, then 550 lines to 544 and 109,520 B down 5,765 at `a789310`, this record included; 2026-10-14, 219,997 B to 206,942 and 1,056 lines to 1,040, likewise, then 208,337 B to 58,720 and 1,042 lines to 323, the thirty-six records lifted into one motif list and dropped | the motif list is the content of the file, and the tool's catalogue, the four passages a citer freezes and the closing section are the reserve |
| PLAN-ORPHANS.md                 |   232 | 2026-09-30, 59.2 KB to 49.4 KB, 297 lines to 264; 2026-10-13, 52,095 B to 37,623 and 270 lines to 232 | little left: the scan tables, the per-step rationale and the walkthrough blocks are the reserve |
| DESIGN-OPENCODE-HARNESS.md      |   201 | 2026-09-30, 32.5 KB to 29.3 KB, 261 lines to 247; 2026-10-14, 29,618 B to 22,993 and 248 lines to 201 | little left: the rejected ways, the 9B's live measurements, the walkthrough block and the three open points are the reserve |
| DESIGN-GPU-REMOTE.md            |   186 | 2026-09-30, 46.1 KB to 37.5 KB, 244 lines to 215; 2026-10-14, 37,492 B to 31,036 and 215 lines to 186 | little left: the three rejected lists, the 2026-09-20 measurements, the step 9 ceiling table, the two fragile assumptions and the four open points are the reserve |
| PLAN-PYREFLY.md                 |    18 | 2026-10-14, 16,566 B to 2,085 and 169 lines to 18 | migrate its 7 accented lines; nothing left to prune: the preset rejection and the one open audit are all that stayed |
| PLAN-TOOL-UPDATERS.md           |   120 | 2026-09-30, 26.3 KB to 16.3 KB, 250 lines to 159; 2026-10-14, 16,396 B to 12,252 and 159 lines to 118 | little left: the `devtools-update` rejection with its table, the skeleton `DESIGN-GPU-REMOTE.md` defers to, the RETURN-trap learning, the three zotero rejected options with the snap measurement behind the first, and the pending step 7 are the reserve |
| DESIGN-AGENT-SKILLS.md          |   111 | 2026-10-13, 19,355 B to 13,479 and 154 lines to 111 | little left: the three rejected ways, the placement criterion `DESIGN-POC.md` freezes, and the first run's `OK` that no suite reproduces |
| RECO-SESSION-DISCIPLINE.md      |   115 | 2026-10-14, 18,257 B to 13,929 and 141 lines to 115 | migrate its 65 French lines; little left to prune: the two one-way research blocks, frozen by `PLAN-SESSION-DISCIPLINE.md` and by a memory, « My take », « Tradeoffs », the dated measurement table and the three open items of « Final recommendation » are the reserve |
| PLAN-LUA.md                     |   116 | 2026-09-30, 25.8 KB to 15.9 KB, 184 lines to 139; 2026-10-14, 15,930 B to 12,977 and 139 lines to 116 | little left: step 8's finding classification and its refutation, the three rejected tool lists, the two `.luarc.json` rejected options, the Locked decisions with their cost acceptance, the registry baseline and the quarto-cli mocks are the reserve |
| DESIGN-POC.md                   |    80 | 2026-10-13, 14,154 B to 7,897 and 128 lines to 80 | little left: the three rejected ways, the scope exclusions, the four-instance test and the two open points are the reserve |
| DESIGN-CADRER.md                |    88 | 2026-10-08, 23.0 KB to 14.1 KB, 161 lines to 118; 2026-10-14, 14,438 B to 10,790 and 120 lines to 88 | little left: the 25-invocation audit, the four corrections with the two counts step 4 still owes, the two rejected lists, the French deferred list and the five open points are the reserve |
| RECO-CLAUDE-MD-ARCHITECTURE.md  |    81 | 2026-10-13, 18,336 B to 12,893 and 118 lines to 81 | little left: the research grounding two of the design's rejected options, and six of the seven rows of the Pocock table, are the reserve |
| DESIGN-CPD.md                   |   113 | — | keep |
| DESIGN-TYPST-REVIEW.md          |    84 | — | created 2026-10-17, after the campaign closed; never read for a pass |
| ANTI-SYCOPHANCY-PLAN.md         |   100 | 2026-10-14, 11,288 B to 9,927 and 111 lines to 100 | migrate its 54 French lines; little left to prune: the blinding rejection, the out-of-scope leviers, the calibration and divergence sections and the one-way sources block are the reserve |
| DESIGN-WINDOWS.md               |   101 | 2026-10-01, 21.8 KB to 13.7 KB, 182 lines to 109; 2026-10-14, 13,985 B to 11,986 and 109 lines to 101 | little left: the three-parameter table with its exclusions, the five rejected and deferred paths, the `/mnt/c` and reclaimable measurements, the seven open points and the frozen point 3 are the reserve |
| DESIGN-CLAUDE-REPO.md           |    67 | 2026-10-13, 16,075 B to 8,341 and 108 lines to 67 | little left: the three rejected git forms, the three rejected holders, what the paired blocks give up, the four refused gate candidates and the one-disk price are the reserve |
| PLAN-UPDATER-HYGIENE.md         |    81 | 2026-10-01, 22.5 KB to 10.3 KB, 175 lines to 107; 2026-10-14, 10,580 B to 8,029 and 107 lines to 81 | little left: the four rejections, the npm and cache scope exclusions, the `NO_PUBKEY` measurement, the unaudited-code residual and the apt 2.8.3 open point are the reserve |
| DESIGN-SSH.md                   |    69 | 2026-10-13, 19,782 B to 12,577 and 97 lines to 69 | little left: the `ssh.socket` arbitration, the rejected ways and the keep-alive residual are the reserve |
| DESIGN-BATS-HOOK.md             |    61 | — | keep |
| DESIGN-POSITRON-THEME-FILTER.md |    40 | 2026-10-14, 6,255 B to 4,331 and 49 lines to 40 | little left: the `git status` size measurement, the restage and `required` rejections, the four accepted limits, the three ways ruled out and the escaping WHY are the reserve |
| DEFERRED.md                     |    41 | 2026-10-13, 49.6 KB to 40.3 KB, four rows out; 2026-10-14, 40,285 B to 33,474 and 41 lines to 41 | little left: every row is a live residual, and the cloudflared chantier, the chosen remedies and the triggers are the reserve |
| PLAN-SQL.md                     |    99 | 2026-10-13, deleted | — |
| PROMPT-PDF-TABLES-EVAL.md       |    27 | 2026-10-02, deleted | — |
| CONTINUE-OPENCODE-CPD.md        |     0 | 2026-09-30, deleted | — |
| pdf-tables-eval/ (deleted)      |     0 | 2026-09-30, 9262 lines cut, 6 files kept; 2026-10-15, the 16 PDF copies and the 95 page renders deleted, 38.6 MB, neither ever tracked; 2026-11-08, the 6 analysis files deleted whole, 1029 lines | — |
```

**A gitignored input is not the measurement, and what decides its fate is recoverability rather than the criterion.** The row above records what left `pdf-tables-eval/` on 2026-10-15, both halves recoverable, the PDFs from `~/Zotero/storage` by their key and the renders from the PDFs.
The campaign's figures never covered either, counting only lines `git ls-tree` could see.

Five rows were decisions rather than passes: two taken on 2026-09-30, one on 2026-10-02, one on 2026-10-13 and one on 2026-11-08.
`CONTINUE-OPENCODE-CPD.md` was an empty file, a handoff consumed and left behind, imported empty in `42fb9ab`: gone, an empty file being no placeholder.
`PROMPT-PDF-TABLES-EVAL.md` went the same way on 2026-10-02, for the opposite reason: it was a full buffer, and the evidence that it had been consumed on 2026-09-23 is that its own deliverables exist, `pdf-tables-eval/` beside `_meta/notes/pdf-inspector-reco.md` rewritten the same evening and `rules/pdf.md` revised on 2026-09-26.
A buffer whose chantier closed is never a pass candidate, which is why its 27 lines were never worth a criterion.
`PLAN-SQL.md` went on 2026-10-13, and it is the first note deleted whole rather than a buffer: `rules/sql.md` is a strict superset of it, down to the rejected tools and the verified facts, while `_meta/notes/sql-gate.md` holds the install trace and the header of `format-on-edit.bats` holds the `grep`-in-the-stub-`PATH` trap.
What died with it: an application-state table naming two files that no longer exist, a completeness list whose criteria were met and two of whose figures had drifted, and two adversarial reviews proposed on 2026-08-09 and never launched, dropped rather than rehomed since a proposal is made once.
Repointed in the same edit: `feedback_bats_comment_carve_out`, which named this file as the holder of the exit-2 rationale.
The only other citer was this file's own table.
`pdf-tables-eval/` kept its 959 lines of analysis (`COMPARAISON.md` and the four `detail-lot-*.md`) and its README, and lost the 9,262 lines of raw `pdf2md` output, sixteen per-article dumps: `_meta/notes/pdf-inspector-reco.md` and `rules/pdf.md` carry the conclusions, so the criterion's "a measurement no better copy holds" did not protect them.

**Those 1,029 lines went whole on 2026-11-08, on the user's decision that nothing would be done with them, and the row is the campaign's one deletion the criterion argued against.** Two readings of the same day had just established the opposite: that the four `detail-lot-*.md` were the only holder of each table's denominator derivation, of the per-lot counting conventions that define what a false cell is, and of the alternative counts under a different convention, none of which `COMPARAISON.md` carried; and that the directory cost no context at all, no hook or `paths:` rule loading it, `rules/pdf.md` citing only the decision note. The recommendation was therefore to keep, twice, and the user overrode it.
What the fold into `_meta/notes/pdf-inspector-reco.md` saved, as the "regroup or delete" the user offered: the sixteen-article selection table with producer, language and evaluated pages, which is the only thing that makes a reprise possible now that the PDF copies are gone; the counting conventions, with the one divergence between lots that qualifies the aggregate (55 cells of 415 on Schmidt); the per-form breakdown, which is what `rules/pdf.md` rule 6 rests on; the error-type distribution; and the limits.
What went: the cell-by-cell examples of the 38 tables, each denominator's derivation, and the `-layout` failure mode per table. A reprise can therefore compare aggregates and no longer tables.
**The lesson the register keeps is about the offer rather than the content: "regroup what matters or delete" is an instruction a note can absorb, and quantifying the loss before writing it is what made the fold defensible rather than a silent downgrade of every figure in `rules/pdf.md`.**

Outside the `.claude/` corpus, on the same day and by the same criterion, the user decided the repository needs no `README.md` and it was deleted: a personal configuration repository has no reader to land on it, and the reproducibility half it carried moved to `_meta/notes/dotfiles-bootstrap.md`, versioned where the `.claude/` copies of those rationales are not.
No thin README was kept: what remained was either already in `_meta/notes/wsl-init-tuto.md` or now in that note, and the one live `DEFERRED.md` row the README owned, its bootstrap not running on a fresh Ubuntu, is closed by the note pointing at that tutorial for the ordered sequence.
The consequence is external and accepted: `github.com/hebstr/dotfiles` answers 200 to an unauthenticated API call, so the repository is public and its landing page now shows no README at all.

What makes that cut reversible is git rather than reproducibility, checked the same day: pdf-inspector is at 1.25.2 against the 1.24.0 the eval ran on, so a rerun measures a different tool and git is the only way back to those bytes: `git show 6a43c6b:.claude/pdf-tables-eval/<file>` for the six analysis files, and `42fb9ab` for the raw output, no longer reachable from the parent repository and only through `~/archive/pro-dotfiles/claude-notes-2026-11-07.bundle`.
Section counts throughout are `##` headings, the convention every pass used.

## The motifs of the thirty-six passes

Lifted on 2026-10-14 from the thirty-six per-pass records, which went in the same edit.
Each motif is stated once, at the completest grain any record reached, and where a record met it again at a new grain the grain is the clause that follows.
No motif here is dated and none claims an occurrence count: a motif a later pass withdrew is absent rather than marked, the tallies stopped at the twenty-first occurrence and the fourteenth consecutive pass, and the three motifs the campaign turned into a rule are in `rules/claude-files.md` rather than restated.

### The artefact is the better copy

- **A passage that describes an artefact the repository carries goes, the artefact establishing it better than prose.** Met at every grain from a bullet to a whole section: a hook's families of wordings, its exemption order and its failure contract; a script's exit codes, flags, defaults and thresholds; a bats suite's case names; a config file's own enumeration, where the prose copy drifts first; a step table whose every row is one of the artefact's sections, its ordinals retargeting to headings rather than to ranks; a line-for-line copy of one artefact section; a skill's own prose; a prompt that greps French strings; a TypeScript plugin whose own comments and 34-case suite pin almost every behavioural sentence a design note would write about it; a grader script holding every signal a measurement table states.
- **A script's own comments are part of the artefact**, and the suite covers every step they do not, so a pair of scripts that comment their own reasons empties the design prose around them, and a test harness's header comment holds the harness design.
- **An artefact's own `--help` empties an argument-surface section.**
- **A deleted artefact's record contracts to the one sentence its live citers rest on**, and its row in a rejected list stays; where nothing cites it, a section describing a deleted artefact goes whole, which is the motif's strongest form.
- **A list of what a file contains goes, a list of what it excludes stays.**
- **An artefact cannot state why it is not two artefacts**, and a gate claim is verified by running the hook rather than by reading the config's `types`.
- **A test inventory ages faster than any other artefact description**, and the behavioural half of a walkthrough finding belongs to the test title while its reason stays.
- **A claim that an artefact does not state something is a claim to re-verify, like a superlative**, and a cut is the right repair wherever the artefact already settles it.
- **An external quote is re-fetchable at its URL**, which is what the motif comes to on a reco; a documentation quote goes once the setup it grounded exists, and so does one grounding the accepted option.
- **A cache is not a better copy.**
- **The artefact that empties a design note need not be the script**: a committed blob showing a one-time migration cost paid, a versioned inventory against a gitignored note, a guard's refusal message quoted as a precedent, a count over a moving tree once a memory holds the command.
- **The file's own table is the artefact**, so a record's headline figures and its share ranking go, and a record that proves the motif by listing the artefact's contents commits the very duplication the motif names.
- **A motif applied section by section misses the copy that was written last**, so on a file whose steps end on the same sentences it applies as a sweep rather than as a judgement per step.

### Holders, and what a passage is kept for want of

- **A memory found through its index line is a holder an inventory read file by file cannot see**, and it is routinely the more complete copy: of a correction paragraph, of a translation's post-mortem, of a note's whole narrative where the memory's own creation is what cut it.
- **A rules file with a `paths:` front matter is the strongest holder there is**, emptying three steps at once and the same row twice, and a live rules file holds the test a note is named for in a superset form.
- **The holder of a row's narrative is usually a memory or a note written after it**, and a row that re-measures itself every month accumulates what its holder already states better.
- **A holder is read to the end, never credited.** Three of the four holders one note credited had drifted and the fourth had moved to a stronger file; of three passages claiming nothing else in the repository held them, two were false; and reading the holders section by section is what shows how far a standing caveat goes.
- **A verified fact with no other holder is moved, not kept**, and the check is one command: to a memory found through its index line, which beats a plan only the verifier reads, or to the file whose subject it is, written in that file's language.
- **A fact whose subject is not the note's subject stays put while its natural holder is frozen**, and a weaker copy elsewhere changes the wording rather than the verdict.
- **The holder improves between two passes of a row**, so a passage kept for want of one is re-priced rather than re-kept.
- **A pass that consolidates measurements into a note inverts the duplicated class for the next pass of that pair.** Where the first cut the note's measurements out of the always-loaded file and left the instructions there, the second finds the note holding a second copy of those instructions, so what cuts is the invariant and what stays is the measurement, the exact opposite of the sort the first applied. The direction is re-derived per pair rather than carried, and a grep proving a note holds the measurement still says nothing about which of the two holds the invariant.
- **A memory can lose what a pass credited it with, so a homing move is not permanent**, and a memory that holds a cut passage can be the thing that dated it worse.
- **A copied chain goes, one copy holding authority**, met on one fact at three dates and on a status block of 63 lines naming a sha per sub-step; three copies of one finding collapse to the copy nearest its cause, and three checks of one conclusion to the one no URL re-serves.
- **A rule stated four times keeps its completest copy, where a measurement keeps its latest.**
- **A system log is a holder, and outlives the line citing it.** So are a versioned store, which emptied three tables of about 300 lines; a versioned sibling, which held a reproduction half without anything having to move; a trace note naming itself by the citer's own ordinals, whose findings read as the file's own; a stow package's bootstrap note; and the sibling of a precedent filter, where what survives in the note is the asymmetry.
  Between two notes holding the same content, the deciding question was which disk it sat on.
- **A measurement window freezes writing, not reading**, so a mechanism inside it still reads as a holder; when the window stops freezing a tree it deletes passages rather than unblocking moves.
- **A WHY the text itself routes to a memory file is safe to cut, and the citation is the proof.**

### What the reserve protects, and where it inverts

- **A WHY the code cannot carry stays, even inside an executed section**, which is what keeps a reduction modest; a one-clause WHY nothing else holds survives the bullet it lived in.
- **The reserve's "a WHY the code cannot carry" inverts wherever the artefact does carry it**, a script comment and two function bodies being holders in their own right.
- **The reserve's "a measurement no better copy holds" is unconditional**, and it protected a whole section a brief expected to be a pass's mechanical half.
- **A rejected alternative does not stay a reserve once the mechanism that applies it makes it structural**, decided no three times, each verified before the cut rather than after.
- **A verified fact absent from every memory stays, however executed the decision it justifies.**
- **A fragile hypothesis the world has since measured stops being a reserve item**, keeping its statement and gaining its verdict while losing the lever it announced.
- **A decision not to build is reserve only while the plan holds its best copy**, and a never-launched review proposal goes where the one the user owns stays verbatim.
- **A scope exclusion is spent once the deliverable's own rules file carries it**, and a closed plan's binds nothing.
- **A survey whose conclusion was replaced by a construction stops constraining anything.**
- **A reversed decision keeps its rejected ways and loses its own statement**, each way being one that would be re-proposed without it, and its acknowledged weak point goes where the successor measured what that point called unmeasurable.
- **A refutation narrative is cut to the clause that stops the claim being re-raised**; a rejected finding stays where a superseded wording goes.
- **The research is the reserve, and an executed recommendation does not release it**, while a source goes whole when every one of its quotes has a stronger holder, and a checklist can stay whole although some of its bullets have holders.
- **A "keep" clause inside an applied verdict row is reserve only where it says nothing holds the passage.**
- **A protected section loses a bullet when the rule states its constraint in its own words**, and the reserve's walkthrough clause does not protect a bullet a memory holds better.
- **A reserve block's applied commands are still applied**, and a spent consumer cannot always be deleted because the reserve quotes it.
- **The one item of a section nobody executed stays**, where the executed ones around it go.

### The executed shapes a pass takes whole

- **A status block duplicating the steps below goes, and is read to the end first**: one hid a unique record, its decision, its two rejected alternatives and its measurement, which no numbered step held, and reading a duplicate block to the end is what separates the copy from the original.
- **A bullet whose head carries an executed state word and whose body ends on a sha goes whole.**
- **A block whose own header says it is superseded, by a section that survives, goes**, one line naming what superseded it replacing the whole record.
- **An approved list of parts goes once each part is either in the code or in a memory**, except the items that are decisions rather than settings: refusing a mechanism, accepting a behaviour rather than blocking it.
- **An objective section, a success-criteria block and an executed implementation order each go whole**, and so does a verification narrative ending in a committed artefact; a paragraph that names its own two holders goes with them.
- **A design-time decision list or protocol is the duplicate when the arbitration protects its as-built record**, and a design-time table superseded by an as-built one goes.
- **A section of open questions all answered goes**, the answers folding into the line that already held them; where they were resolved against real releases it is a dated to-do list whose answers are the implementation.
- **An "Open points" section is where executed verifications go to hide**, and a bullet headed "Closed <date>" is the criterion's target wearing a label; one of them hid a retraction rather than a verification.
- **An open point keeps its question and loses its inventory**, and a section whose decision cannot be re-proposed folds into `Open` as its residual.
- **An open item can be closed by the world rather than by a decision**, and checking cost one command.
- **A residual named in a plan is checked against the code before it is carried forward**, one verification having overturned a residual rather than a measurement.
- **An arbitration's reason can expire while its conclusion holds.**
- **A section whose heading announces a decision and whose body states a constraint is retitled rather than halved**, and a dated heading that makes a claim holds its own decision line.
- **A probe narrative reduces to what it established once the fact has moved**, and a step whose record lives in a trace note to its criterion and the pointer.
- **A decision list and its closing check are one list written twice**, a propagation record rots from both ends, and a section whose body never arrived goes.
- **A section listed as an implementation record can be a pending plan**: scoping by section title over-counts, and reading the section is what settles it; a heading's own participle can say the opposite of its content, « complété le <date> » meaning supplemented by a second review and read as completed, which put a corpus register, a brief and a campaign's pass order on 134 lines of open findings. The remedy is retitling the heading in the same pass, since nothing else stops the next reader repeating it.
- **A reco's recommendation section is the ladder its design climbed**, and what survives is the paragraph the design cites as its input and the confidence verdict.
- **A completeness list whose criterion was voided rather than met goes with the criterion**, and an inventory of what was updated in the pass goes with it.
- **A doctrine quoted in quotation marks can be a paraphrase of its source**, which reads exactly like a cut.
- **Reading a section closely protects more than an estimate predicts.**

### Measurements, figures and superlatives

- **A measurement goes when a better copy exists, reproducible or not**, the test being whether a better copy exists rather than whether the measurement can be rerun, and a published copy counts.
- **An irreproducible measurement attached to a closed point is moved, not kept in place**; attached to a point still open, it stays.
- **A measured cost stays when it prices the design and no other copy exists**, however long since implemented.
- **A decayed measurement is dated, not cut, and the decay is the finding.**
- **A measurement table reduces to its distribution once its consumers hold the figures they cite**, and in a dated section it keeps its drifted rows while the lines reading it go.
- **A design-time estimate superseded by an as-built measurement goes**, and a superseded value goes with the estimate that carried it.
- **A red-then-green count is not a verification passed**: what a test proves is a finding, where the suite totals are not.
- **A fact whose measuring command has changed meaning is repaired, not cut**, and so is a comparison whose two terms are both false, which an earlier pass of this campaign had created.
- **A count dropped as drift-prone was worth re-deriving instead.**
- **A superlative is a count restated, and it rots in silence as every later pass lands**, three having drifted into falsehood unseen: `refs-lint.py` resolves a name and never a claim.
- **The rule a memory quotes from here is that a count restated is a count to redo.** The sites met: a map inherited rather than re-taken, a margin carried rather than re-measured, a figure lifted from the very paragraph being rewritten, since rewriting it feels like deriving it; a superlative derived over a handover's sample of recent figures instead of over the column; a language reading carried past the cut that moved it; a head's count of its own evidence one short of what the page held.
- **A figure or a name written from recall reaches the record and the handover alike**, and it is the verifier rather than a reread that catches it.
- **Rewriting an inventory into a rule is where an unverified claim enters.**
- **A claim about an artefact written without reading the artefact is the same defect at its source.**
- **A list of carriers is one grep's snapshot, not an inventory**, one pass having found a fourth carrier of a deleted rules file that a list of three had missed.
- **A window start read from `git log` alone is a floor, never the date.**
- **A pass priced from the wrong repository reads as zero**, `.claude/` being a repository of its own.
- **Bytes are the honest measure wherever lines are long**, a line count having understated one cut by half, the two shares diverging by a factor of three to five.
- **A price figure is a record's own datum; its ranking is a count restated.**
- **Repeated readings of one quantity reduce to the latest, the inflections and the standing rules.**
- **An occurrence tally counts occurrences met, not bullets on a page**, and it is not resumable without recounting every record it ran over.
- **An estimate carries no direction**: a pass undershoots, overshoots and meets its reading, and what an inventory reliably under-reads is a note whose content sits in another file the same lot wrote.
- **A split is priced on the pair and not on the file it empties.** The split of 2026-10-15 took `PLAN-SESSION-DISCIPLINE.md` from 1,398 lines to 495, which reads as 65 % and is 835 lines moved; the pair fell 1,398 to 1,340 and 242,057 bytes to 226,418, so the corpus gained a note and lost 58 lines, the 68 cut less the heads and pointers the split had to write.
  A move is not a cut, and a per-file reading of one says the opposite of the corpus reading.
- **A section counted by its title over-reads it, and so does a block count.** The inventory sized « Implémentation du noyau » at 724 lines against 719 and its walkthrough blocks at eleven against fourteen, both read from the outline rather than from the file, which is the same defect as scoping by section title.

### The citers

- **The citation map is the first check, and it decides the scope.**
- **A map is re-taken per hit and never inherited**, a brief and a handover of the same session having been wrong on which section a citer freezes, and a map counted by file hides hits a per-hit map shows.
- **A per-hit map is what says which hit may not be touched**, and it answers the homing question too.
- **A recorded citation map is never a holder**, being the one thing the campaign's own motif forbids reusing.
- **A citer freezing a section does not freeze each of its rows**, and one claiming N kinds of content freezes the shape rather than the text.
- **A citer that defers to a section for a shape freezes the whole shape**, and the section keeps exactly what the citer defers to it.
- **A citer can be right about where a passage belongs and wrong about where it is.**
- **A citer that names a correction as owed is a cut instruction, not a freeze.**
- **A verbatim citer can license the cut of the sentence it quotes, and the tense is what decides**; a citer's present tense froze a measurement whose own subject had moved.
- **A citer that says the target "records this standard" freezes the standard even when the citer is the better copy.**
- **A citer's quotation marks can hold a paraphrase**, and a citer can name a form rather than a title.
- **A citer falsified by a cut is repaired in the citer**, and a cut can repair a dead file name rather than keep it as record, where a pending command keeps its own.
- **A protected passage's antecedent is protected with it.**
- **An ordinal cited from outside freezes a list's numbering**, so executed steps collapse to one line each rather than disappearing: the remedy is keeping the ordinal, never repairing citations afterwards, and the note that carries such a list says so in its own head so a later pass does not renumber.
- **A stale ordinal is repaired in the citer**, an ordinal grep over the citers is read rather than counted, and a freeze list can grow on re-derivation or on a second surface rather than a second citer.
- **An owed record is a reason not to cut, and checking cost one grep.**
- **A passage can cite a `DEFERRED.md` row that no longer exists**, and a cross-reference to a conditional step that has since run is executed.
- **A cut can remove someone else's citation**, and cutting a list orphans what its readers still name inside the same file.
- **The file that owns a ruling owns the evidence for it**, even when the importing file holds a finer copy.
- **Obeying "Cite by name" can create a pass's only dangling hit.**
- **Where every dated section title is quoted by a citer, a pass removes no heading at all.**

### What a cut breaks, and what the cut writes

- **A reference to an internal enumeration is invisible to a check on names**: what a cut breaks is a reference to a part of what it cut, never to its name, and a dangling one is always a reference into a block the same pass cut.
- **Rename, deletion and rewrite are the same operation as far as references are concerned**, a verbatim quote broken by a rewrite and a block renamed rather than cut each breaking a citation.
- **A reference broken by a deletion is inlined, repointed or left as record**, and which of the three is the arbitration.
- **A cut orphans a deixis, a determiner, a bare flag, a bare cardinal, a title, a count or a figure's home**, each visible only in the prose the cut left behind.
- **Cutting a numbered list to some of its sub-bullets orphans all of them**, and cutting a headline orphans the bullet that criticised it.
- **A cut takes the definition of a term the surviving frame still uses.**
- **Two references to a cut heading can resolve against each other, so nothing ever dangles.**
- **The replacement sentence is where a pass overclaims**, a compression widening a claim past the facts, a rewrite carrying a dead conditional forward, a frame claiming every "step N" of a file named one test.
- **Every defect a pass makes is in the prose the pass wrote, and the reread is what catches it**, which has paid in every pass since the motif was recorded, while the tool stays silent on all of it.
- **What a cut leaves behind is re-homed in the same pass, not only checked**, and restoring collateral is not the repair: checking the artefact is.
- **One cut unlocks another**, the last consumer of a passage kept for one purpose going with the cut that spends it.
- **Cutting an executed section also removes the stale references it carried.**
- **A quotation with no cue word before it is invisible to a check on names**, so every double-quoted span of 12 to 120 characters is swept on its own with `rg -F`; on a file made of quoted prose the sweep is read by sorting the misses, never by counting them, and three citations that had never resolved came out of one such sweep.
- **That sweep passes its span with `-e`, or every span opening on a dash reads as an `rg` flag and comes back a miss.** On 2026-10-15 it reported 16 phantom misses on one file, all of them `--seal` and `--only` bats titles that were in the suites; the tell is that the misses share a prefix.
  A sweep whose misses cluster on one shape is a bug in the sweep before it is a finding.
- **A reference can fail to resolve on capitalisation alone.**

### `refs-lint.py`

- **A 0 on dangling says the names it tested resolve, never that a claim is sound**: it resolves a name and never a figure, a sha or a superlative, and no count carries forward, each falling as a file shrinks.
- **The tool tests outward references only**, so a file whose references leave the corpus is its blind spot, and the enumeration pass is blind on the file that most needs it.
- **Its `CORPUS` is `("*.md", "*.bats", "*.sh", "*.py", "*.lua")`, so a `.qmd` and a `.yml` are never read**: citing a rendered document's section heading or a declaration key reads as dangling unless some `.md` of the project happens to name it too. Measured 2026-11-02 on eds-prise, where « Sources de données » resolved through the design notes that cite it while « Variable de confusion », which no note names, did not. The remedy is to describe the section instead of quoting it.
- **A backticked name living in another repository reads as dangling, and stays**; a record of a false positive is a holder, so the reference that causes it stays too.
- **A second holder anywhere in the corpus silences the check for a name**, so a before-and-after is taken on the file in place and never on a copy.
- **The catalogue of what it gets wrong is in § "The check after each cut"**, and it is read in one glance rather than counted.

### How a pass runs, and what a record costs

- **Cut by block, not by clause**: ten edits for 600 bytes is where a pass stops.
- **One short line beats amending a third file.**
- **A status block gets shorter and more accurate in the same edit by being stated in the negative.**
- **A verbatim citation dictates the wording of a block the pass rewrites from scratch.**
- **A trade can be voided by the pass's own earlier cut**, and one verification can split two ways in the same pass.
- **A dated defect list reduces to one line an item.**
- **A faux ami moves rather than goes, and the move was four words.**
- **A motif recorded inside a file does not bind the records written after it**, nineteen of them having opened on the very figures a motif recorded a day or two earlier had withdrawn: nothing reads a record at writing time, so what a pass measures there is the motif's half-life.
- **A record's price is read from its own commit**, never from the difference between two readings, which credits it with every commit that fell in between; comparing two passes means measuring both the same way.
- **A reading series is pruned twice, and the second pass follows it out of the section it lived in.**
- **A handover's claim is withdrawn rather than acted on wherever the pass cannot verify it.**
- **A byte ceiling on the target's write hook dictates the order of the pass**, every edit having to be net-negative until the file is under it: a frame repair that costs bytes, an orphaned cardinal being the usual one, is refused when it is made beside the cut that orphaned it, so the deletions all land first and the prose the pass wrote is repaired last, after the ceiling is met. Met on `quarto-hebstr-doc/.claude/PLAN.md`, 118,590 bytes against a 20,000-byte ceiling: a "Trois voies écartées" left facing two routes had to wait for four further cuts before it could be written as two.

## The check after each cut

Both regrets are the same defect, and attention does not fix it.
A mechanical sweep does, and since 2026-09-30 it is `bin/.local/bin/refs-lint.py`: it reports the named references of a target that resolve nowhere, then lists every reference to an internal enumeration, which a cut breaks without breaking any name.
Run it after every cut, not at the end: without it, two references out of three cuts went through unnoticed, and once it was in place it caught two more within the second, both renames rather than deletions.

Its false positives are stable, few, and of five kinds, so a run is read in one glance: a name that resolves in a test title or in the `opencode` `AGENTS.md` mirror, a Claude Code doc section cited with its URL, a fragment of prose in quotes, a name quoted precisely because it is dead, which is most of this file's own hits but not its alone, and a quoted title under twelve characters, which falls outside the span window so the text from its closing quote to the next opening one is tested instead, fixed by ordering two titles so the long one comes first.
`DESIGN-CADRER.md` reports one of the dead-name kind for the same reason, the project-section pointer its correction B1 replaced with a global rule, and that hit predates any prune pass there.
Writing that name out here, to document the case, silenced the check for it: the hit vanished from `DESIGN-CADRER.md` the moment this paragraph quoted it, and came back when the quotation was replaced by this description.
Second occurrence of the false negative below, caused by the very attempt to record the false positive.
**It has a false negative too, found on 2026-10-01:** the tool resolves a name found anywhere in the project, so quoting a dead name in a second file silences the check for it.
The four of the kind above went from reported to clean when a `.claude/PROMPT.md` written that day listed them verbatim as examples, and came back when it stopped.
Never quote a dangling name outside the file that owns it, and read a sudden drop to zero as a second holder rather than as a repair.
**Third occurrence, 2026-10-13, and a trap for the before-and-after:** a session checking whether its own cuts had added hits copied the `HEAD` version of this file beside the live one and linted the copy, which reported 0 against the live file's 4.
The copy was the second holder, so each file silenced the other on every name both carry.
A before-and-after is taken on the file in place, never on a copy sitting in the same corpus, and when that is awkward the cheaper answer is to grep each reported name yourself with the owner excluded, which is what settled it here.
**Fourth occurrence, 2026-11-02, and it is the variant "Never quote a dangling name outside the file that owns it" did not cover:** a second quotation of the dangling name *inside the owning file itself* silences the check too: the first clause of the `check()` predicate is `text.count(name) < 2` over the target file, and it fails before the corpus clause beside it is ever reached, so a note that documents its own dead reference loses the hit on it without any second holder.
The dead-name kind of false positive is why the tool gates nothing and stays hand-run: on the file that records deletions, every record reads as a dangling reference, which is what all of this file's own hits are.
No count carries forward, each falling as a file shrinks.

## What the pass of `PLAN-SESSION-DISCIPLINE.md` did not establish

- **The measured motive is not what the scope suggested.** Section 5 of `verifier.md` reads live passages only, its `rg` matching `^#{1,4} .*(next|blocker|étape|step|…)` and `^\*\*(statut|status)`, and its own rule declares a section recording an event an archive.
  The dated sections are therefore invisible to it except through four ancestor headings carrying "étape".
  The gain lands on sections 1 to 4, which read the whole file whenever it is in `WRITES`, and on the status block, which section 5 read at every pass in every session.
- **The 1,540-line target was not reachable under the criterion.** The reserve protects the 14 walkthrough blocks (about 381 lines), the internal "Rejected" and "Voies écartées" lists, the fragile hypotheses, the unclosed residuals, and everything step 4 must still compare.
  Since the split of 2026-10-15 those 14 blocks are `DESIGN-COMMIT-GUARD.md`'s reserve, not the plan's, and the plan's reserve is the clause after them.

## The criterion is now a rule, the root carrying one clause and the scoped file the whole test (decided 2026-09-30)

**Decision.** The `/design` held until the pruning was over ran on 2026-09-30, its approved form is split by the routing test of `rules/claude-files.md`, and `0eb3760` carries it.
The "Plans and tracking" bullet of the global `CLAUDE.md` gains "deleting is half of updating, by the criterion of `rules/claude-files.md`", paid for by dropping its four examples of a decision accepted in conversation.
The "Content" section of `rules/claude-files.md` gains four bullets: the criterion at the top of this file, the reserve it protects, the artefact motif together with the homing of a fact that has no other holder, and the name check after each cut.
Measured after the edits and the verifier's corrections: `CLAUDE.md` at 12,104 bytes against the `instructions-budget` threshold of 12,288, and `claude-files.md` at 5,043 characters against the 9,000-character injection cap.
No figure from the passes went into the rule, and the motif list above is where what each pass removed has gone.
The root clause is a deliberate exemption from the section 3 check of `skills/commit/agents/verifier.md`, which fires on a root passage naming a mechanism written in the same session: the "keeps nothing, not even a sentence naming the hook" clause of the routing test belongs to its step 1, a deterministic mechanism, while a `paths:` rule is step 2, and the "+ root" rows are the precedent.
A later pass that refiles it should read this paragraph first.

**Why the split rather than one file.** The precedent is the five rows of "Where each block goes" in `.claude/DESIGN-INSTRUCTION-ROUTING.md` whose Step ends in "+ root": the detail goes to the rule its trigger loads, the root keeps one line.
The root bullet is what fires the behaviour and is read every turn, so leaving its sign positive would state half the rule, while `claude-files.md` loads on a `Read` of a Claude file and is injected by `inject-rules.sh` on the session's first write to one, which is when a cut is decided.

**Rejected.**

- **Everything in `claude-files.md`, the root untouched.** The root would keep prescribing an addition alone, and the injection reaches the model at the `PreToolUse` of an Edit it has already composed.
- **A check in the verifier**, symmetric to section 5 of `skills/commit/agents/verifier.md`.
  One pass already costs 577 to 816 s and has its own `/design` pending on that cost; the criterion is arbitrated rather than mechanical, so a blank-context subagent would file noise on a plan of that size; and the verifier reports without ever cutting.
- **A `prune` skill holding the motifs, the two files keeping a pointer.** A skill is invoked rather than triggered, so the everyday case of a session closing a step stays uncovered, and the condition set that day was that the skill comes after, and only if the work delivers, which the campaign met on 2026-10-16.
  What this entry does not close is the procedure, approved on 2026-10-16 in the last section of this file: the motifs stay here and the criterion stays in the two always-loaded files, and the skill carries the order of the pass alone.
  The prune-pass handovers had turned this entry into a blanket prohibition no pass had read against it, traced on 2026-10-14 to `24b1391` of 2026-10-01, a handover's compression of this bullet copied forward by every buffer after it.

**Open.** The mechanical form exists since 2026-09-30, the deep pass having given it the consumer it lacked: `bin/.local/bin/refs-lint.py`, which `rules/claude-files.md` now names in place of the `rg -F` by hand, pinned by `_meta/tests/refs-lint.bats`.
The gate half of that plan is dead and is not to be re-proposed: the nested repository runs no hook, and the tool reports a false positive on every deletion this very file records.
The weakest assumption of the approved form, untested: that a criterion in prose produces deletions at all, every pass this file records having run under explicit instruction with the user arbitrating.
Over-firing has a backstop (the verifier flags a false claim, and the step 4 window measures tracking behaviour); under-firing has none, since the additive half is the habit.
The destination the rule names now has one: `DESIGN-CLAUDE-REPO.md` versions `.claude/` in a nested repository local to ju-TP, and section 5 of the `commit` skill writes the message.
That is no remedy for the inflation, which comes from the additive habit: git changes the cost of a deletion and its countability, not the habit.
Counting a deletion became possible on 2026-09-30, when the user imported the notes as `42fb9ab`: from that commit on, `git -C .claude log --numstat` prices every pass, and the assumption above stops being unmeasurable.

**First reading of that count, taken 2026-10-01 over `42fb9ab..24b1391`, 29 commits:** 497 lines added against 548 deleted, net 51 removed, excluding the `pdf-tables-eval/` row, which was one decision rather than a pass, and `PROMPT.md`.
So the criterion does produce deletions against the additive habit, by a margin thin enough that a single writing session reverses it: `PLAN-SESSION-DISCIPLINE.md` grew by more than the whole corpus shrank over that same span.
The assumption is answered "marginally yes" rather than confirmed.
The span is named by its end sha and not by `HEAD`: a count bounded by `HEAD` excludes the commit that records it and is falsified by the next one.
A rerun states its own end sha and the two exclusions.

**Fifth reading, over `42fb9ab..9fa1c02`, 43 commits: net 11 *added* under the narrow pathspec, and net 72 removed with `':(exclude)PROMPT*.md'` added.**
**That exclusion is what the reading settled, and the argument covers every buffer rather than the bare name.** `PROMPT.md` is excluded because a buffer's resting state is empty, so its lines leave on consumption and were never a record; a second buffer named after its chantier is not durable content either.
Excluding only the bare name makes writing the handover destroy the figure the handover exists to carry: 83 lines of that reading's swing were one such file.
Keeping the narrow pathspec is the alternative, and it means reading a figure that counts a buffer as a note.
A pass is priced by its own commit rather than by the difference between two readings, which credits it with every commit that fell in between.
A record's own figure tends to leave out the `Pass` column and the table the same commit writes, so comparing two passes means measuring both the same way.

**Sixth reading, over `42fb9ab..d65e70d`, the head before the `DESIGN-CADRER.md` pass: 1,497 added against 962 deleted, net 535 *added*.**
The campaign flipped to net growth here and stayed there, by a margin no longer thin, so a figure carried from the fifth reading reports a state that ended on 2026-10-01.
Per file over that span the passed rows were down 346 lines and twelve rows up 881, **this file accounting for 194 of them**: the subtractive half works where it runs, one file per conversation, and the additive half runs in every session, so the second-largest grower of the campaign was the record of the campaign.
That is the record eating most of the gain, at the grain of the whole corpus rather than of one pass.
**The commit count in every reading is pathspec-filtered**, 82 under the two exclusions against 88 bare at that sha, so a rerun that prints `git rev-list --count` without the pathspec reports a different count for the same span and reads as a drift that never happened.

**Thirty-sixth reading, over `42fb9ab..d565466`, the commit that lifted the records: 4,132 added against 4,495 deleted, net 363 *removed*, over 156 commits filtered and 162 bare**, predicted from the pass's own diff before it landed and verified at it to the line.
At `3f4fb5d` it read 4,135 against 4,498, net 363 *removed* still, over 157 commits filtered and 163 bare, and a reading bounded by anything but a sha is falsified by the next commit of its own session, which is what happened to this sentence twice before it named one.
The thirty-fifth read 352 at `9121341` and the closing commit `5fdfe79` took it to 354, 3,933 against 3,579, over 155 commits filtered and 161 bare, which is where this reading starts; the series had landed on its own prediction twenty-one consecutive times and had not been under 400 since the fifth until the thirty-third.
**This is the first reading net *removed* since the fifth**, which the sixth's "flipped to net growth here and stayed there" had held against ever since: the prediction is verified rather than carried, and a rerun that finds the pass split over two commits restates the two commit counts.
Every reading between the sixth and the thirty-fourth is gone, as the second, third, fourth and seventh to tenth went on 2026-10-13, each having been a dated figure whose only consumer was the next reading; the ordinals of the survivors are not renumbered, so the gaps in the series are deliberate.
Three rules outlive those figures.
A reading that says where it will land has to count the commit that lands it, which is what the twelfth missed by one line.
A pass that rewrites lines without removing any is invisible to a count that prices lines, as the `DEFERRED.md` pass of 2026-10-14 was.
And so is a homing move out of the corpus, as the `DESIGN-WINDOWS.md` pass's was into `claude/.claude/rules/shell.md`.
What the series established beyond the readings kept: **the campaign count prices the corpus and not the method**, since the growth between any two readings is written by ordinary sessions rather than by passes, which is why a pass is read by its own commit; and the two deep passes of 2026-10-13 were the first time the subtractive half outran a day of ordinary sessions, taking the count from 1,017 net added at the seventh reading to 582 at the ninth.

Nothing else is pending here, and the reserve of `PLAN-SESSION-DISCIPLINE.md` and of `DESIGN-COMMIT-GUARD.md` is what remains of it.
Its line counts are in the section "What the pass of `PLAN-SESSION-DISCIPLINE.md` did not establish" above, one copy holding them, and they grow with every session that writes to either file.

## The procedure becomes a user-level `prune` skill while the criterion stays a rule (decided 2026-10-16)

**Decision.** The pass gets a skill, built the same day at `claude/.claude/skills/prune/SKILL.md` and stowed as a single directory link, invoked as `/prune`.
The criterion stays in the global `CLAUDE.md` and in the "Content" section of `rules/claude-files.md`, and the motif list stays in this file: the skill carries the order of the pass and nothing else.
Eight items, approved separately by the user on 2026-10-16.

1. **Scope: a project's `.claude/` notes and the decision notes of `_meta/notes/`**, which is the `paths:` glob set of `rules/claude-files.md`.
   The memory store is out: it answers the admission test and the index-line ceiling of `rules/memory.md` rather than this criterion, it has a mechanical backstop the notes do not have in the `inject-rules.sh` deny, and "Fourth pass: the sweep under the admission criterion" of `TRIAGE-MEMORY.md` established that a body prune cannot move the dimension the ceiling counts.
   The always-loaded set is out too, governed by `instructions-budget` and by the routing test.
   The homing move stays in scope and is left to the baseline, as `DESIGN-POC.md` § "The skill writes the note and leaves the memory to the baseline" does.
2. **Placement: user level**, ruled by `DESIGN-AGENT-SKILLS.md` § "Where a skill the user writes goes is decided by its coupling to this machine" rather than assumed.
   Its load-bearing steps read this machine's corpus: `refs-lint.py`, a dotfiles artefact pinned by `_meta/tests/refs-lint.bats` and present on no other machine, the motif list above, and `~/.claude/memory/` as the homing destination.
   A marketplace `workflow:prune` would have to ship or discover the tool and could defer to no motif list at all.
3. **The inventory is a deliverable of its own, validated before any cut**, and what it delivers is a target order with the per-hit citation map, never a promised share.
   The motifs forbid the promise: an estimate carries no direction, an inventory read file by file cannot see a holder in a memory or a sibling row, and reading a section closely protects more than an estimate predicts.
4. **No per-pass record.** Priced in this file: the record was the campaign's second-largest grower, at one reading 2.64 times what the passes had removed from every other note, and the reading that closed the register found a further pass adding about 27 lines of record here to remove 8 to 47 from a smaller row.
   A pass writes its commit message.
   The one exception is a motif the list above does not already hold, appended here.
   Outside dotfiles a pass creates no per-project corpus, and a new motif comes to this file, the single central corpus.
   **Narrowed on 2026-10-16, before the first run, on a fact the eight items did not have:** `R-hebstr/.claude/PRUNE-OBSERVATIONS.md` already exists, opened 2026-10-04 with a `Pass` column, an order diverging from the dotfiles precedent on purpose and three-class per-pass records.
   An existing project register is a holder rather than an invention, so it governs the record's shape there, and the price measured above bounds this 208 KB file rather than a register of a hundred lines.
   Where no register exists, `git log` answers whether a note has been passed and the pass adds no file.
5. **The frontier.** Unattended: a passage whose artefact the repository carries, a status block duplicating the steps below, a bullet whose head carries an executed state word and whose body ends on a sha, an objective or success-criteria block, a section whose own header says it is superseded, a dangling pointer.
   Handed to the user: everything the reserve protects, which of inlining, repointing or leaving as record repairs a broken reference, a French row owing a prune then a migration, the name a split note takes, and a never-launched review proposal.
   Written by the pass as its own step: the reread, every defect a pass makes being in the prose the pass wrote.
6. **The two restructuring guards are cited, not restated.** `feedback_note_restructure_guards` holds both probes of 2026-10-14 with their measurements, and the step names the action: a non-empty replacement, a structure count after the edit, and a snapshot with a survivor comparison on a whole-file rewrite.
7. **Stop rule**, in the shape `feedback_review_severity_heuristic_code` gives one: the pass stops when the next candidate is reserve or costs more edits than lines, the floor being the motif's ten edits for 600 bytes.
   It stops without a second opinion, and "nothing left to cut here" is a verdict rather than a failure.
8. **The mechanical half stays deferred.** Folding the per-hit citation map, the quoted-span sweep, the structure count and the survivor comparison into `refs-lint.py` or a sibling was costed and deferred: the sweep is two lines of prescription in the skill, and nothing would consume a second tool except the pass itself.

**Why the rule alone was not enough, and the reading that settles it.**
The `Open` paragraph above named the approved form's weakest assumption as untested, that a criterion in prose produces deletions at all.
It is measurable from `42fb9ab` on, and the thirty-seventh reading answers no.
Over `42fb9ab..47876d6`, 2026-09-30 to 2026-10-15, `*.md` under the two exclusions: 5,053 added against 5,466 deleted, net 413 *removed*, over 161 commits filtered and 168 bare.
Classified by commit over the same span and pathspec: 27 whose subject names a prune, net 1,855 removed; 90 net-positive, 1,473 added; 32 net-zero; and twelve other net-negative commits totalling 31 removed, of which the largest at 11 lines is `109d7fe`, the commit that opened the campaign, five are `DEFERRED.md` row closures the plan-upkeep rule already mandates, and the remaining six are a `panache` repair and five one-line corrections.
**So the criterion in prose, net of the campaign's own commits and of row closures, produced ten lines in sixteen days, against 1,855 from the invoked passes.**
Under-firing is measured rather than suspected, and the invoked procedure is the mechanism that cuts rather than a workaround for a weak rule.
Classifying by commit subject is a proxy for which session was a pass, and it was read rather than counted: the 39 net-negative subjects were listed in full before the split was taken.

That does not contradict the `Rejected` entry above.
"The everyday case of a session closing a step stays uncovered" holds, and it is what the rule must keep; it is no reason to withhold the order of the pass from the one mechanism that fires.

**Rejected.**

- **Do nothing, the rule plus `refs-lint.py`.** The reading above: the mechanical half ships, the criterion fires every session, and together they cut ten lines unprompted.
  The procedure was also rebuilt from scratch by every pass, the three-phase order having been invented on the one project repository on 2026-10-13.
- **A skill plus a harness trigger proposing a pass at a threshold.** The only approach that attacks under-firing instead of waiting for the user, and it fails on its own terms: the threshold is the figure this file says does not pick the target, share no longer picking it, and an addition to the always-loaded set has to name what it displaces.
  It is the dead gate half re-entering by another door.
- **A growth ratchet on the staged file**, refusing further growth of a note already over a watch threshold, which would mechanise "a tracking update deletes as well as records".
  Rejected 2026-10-31 on the premise test, with the backlog row of 2026-09-30 that had carried it since, no mechanism capping growth being true and deciding nothing.
  **Thirty-eighth reading, over `47876d6..119680a`, 2026-10-16 to 2026-10-30, `*.md` under the two exclusions: 1,515 added against 1,036 deleted, net 479 *added*, over 63 commits filtered and 63 bare.**
  So the direction after the campaign is additive, which is the sixth reading's finding and not the thirty-sixth's, at about 32 lines a day spread over 29 notes, under one line per note per day.
  The distribution is flat over the fortnight: 6 notes over 40 KB against 7 on 2026-10-13, 9 over 30 against 8, 11 over 20 against 12, and one alone over 100 KB, `DESIGN-COMMIT-GUARD.md` at 167,435 B against 164,538 at `47876d6`, so 2,897 B over the fortnight.
  The drift a ratchet would catch is therefore that one, where the case it would matter in is the one the invoked pass demonstrably takes, `PLAN-SESSION-DISCIPLINE.md` going from 236 KB to 62 KB.
  Its watch threshold is also the figure this file says does not pick the target, which is the ground the harness-trigger entry above fell on.
  Cross-model L1 agreed on the day's figures; it was briefed on an unfiltered net 431 over a `--since` bound, which this reading restates under the pathspec and the sha bounds the series requires.
- **A tool and no skill**, the mechanical sweeps in code and the arbitration left to the user.
  It covers one step of six while every deciding step stays arbitrated.
  Kept as item 8 rather than refused.

**Weakest assumption, untested.** That a procedure derived from thirty-six dotfiles passes transfers to another repository.
Two instances bear on it and they differ in kind, which is why the clause "with no corpus and no table" was dropped from this sentence on 2026-10-16.
The pass of 2026-10-13/14 on `claude-code-plugins` ran against no register at all, produced the three-phase order the skill takes, and reached 54 % over its notes and 78 % on its `PLAN.md`.
`R-hebstr` has run its own campaign since 2026-10-04, four prune-labelled commits of eleven and pass 1 done, against a register that sets its own order: that is the instance item 4 was narrowed for, and the one the first `/prune` runs against.
The consumer base recounted on 2026-10-16 under `fdfind -u`, a bare run under-reading it because most of these directories are gitignored: 23 `.claude/` directories under `~` holding at least one note, counting `.md` less `PROMPT*.md` as the campaign's own pathspec does, four of them at twelve or above, dotfiles 26, `eds-prise` 23, `R-hebstr` 19 and `md-nesrine` 12.
Only dotfiles had moved since the reading of 2026-10-14, by one note, and again on 2026-10-17 to 27 with `DESIGN-TYPST-REVIEW.md`, the three other rows recounted unchanged the same day; `R-hebstr` then went to 20 hours later, its own pass 3 having extracted `XLSX-STYLE.md` out of § Pièges, so a count of this base decays from the consumers' own passes and not only from dotfiles. All of it under `fdfind -u -e md --max-depth 1`, the depth limit being load-bearing: a bare run counts a note repository's subdirectories and over-reads `eds-prise` at 26 and `md-nesrine` at 14.
The first figures written into this paragraph counted the buffers in and so read every row high against a reading that excluded them, which is this file's own rule that comparing two readings means measuring both the same way.
If the assumption fails it fails as the inventory step having nothing to read, and the repair is a scope clause rather than a redesign.

**Open.**

- The first pass goes to `R-hebstr`, as its own campaign's pass 2 on `DEFERRED.md`, settled 2026-10-16.
  What stays open after it is the order of the two other project rows, `eds-prise` at 23 notes and already 36 prune-labelled commits deep, and `md-nesrine` at 12, whose precondition fell the same day: its `.claude/` was imported as its own repository at `bec2712` with the three-hook prek gate at `7e81be8`, so no project row is blocked on recoverability any more.
- Whether a project's `PLAN.md` is one target or a split like `PLAN-SESSION-DISCIPLINE.md` was.
  `eds-prise`'s measured 1,105 lines and 251,906 bytes on 2026-11-06, and it is the first one the campaign will meet.
- Whether the record exception of item 4 ever fires again.
  The motif list is at the completest grain thirty-six passes reached, so the marginal motif of a dotfiles pass is near zero; on another repository it is unmeasured.
