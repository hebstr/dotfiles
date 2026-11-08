# DESIGN-INSTRUCTION-ROUTING.md

Design of the restructuring of the global instruction set, approved by the user on 2026-09-26.
Opened as "Restructuring the global `CLAUDE.md` (opened on 2026-09-26)" in `PLAN-SESSION-DISCIPLINE.md`, whose "Open points" keeps what stays open; this note keeps the decision and its implementation record.
Input: `RECO-CLAUDE-MD-ARCHITECTURE.md`, "Final recommendation".
It also keeps the decision on the memory index injection, approved on 2026-09-26 (section "The harness loads the memory index natively, and a prek check holds it under the harness limits").

## Each instruction lives where its trigger fires, and the root keeps only what has none

**Decision.** The five rules files without `paths:` (`environment.md`, `docx.md`, `pdf.md`, `secrets.md`, `showboat.md`) stop loading at launch.
Every block of `CLAUDE.md` is routed by the ordered test, live in `rules/claude-files.md` § "Where a new instruction goes", which numbers the five steps that every reference to the routing test below cites: that form is a superset, its step 2 adding that a `Write` of a new file loads no `paths:` rule and its step 3 capping each injected file at 9,000 characters, inside the 10,000 characters at which the harness truncates a hook's whole output.

Admission bar for a new root line: the user corrected the same behavior at least twice.
The bar applies to additions from 2026-09-26 on, not retroactively: most existing lines carry no record of corrections, and cutting them on that ground would remove rules on no evidence.

### The five files stay in `rules/`, scoped, and one hook injects them

Each keeps its path and gains a `paths:` frontmatter, a glob matching only the file itself where it has no natural one, which makes it load only when read directly.
The triggers live in the hook's own table, not in the files' frontmatter: an unknown frontmatter key is untested against the loader, and a frontmatter that fails to parse makes a rule always-on.
`inject-project-context.sh` clears the per-session markers on `compact` because compaction summarizes the injected text away.

### Where each block goes

```
| Block (bytes on 2026-09-26) | Destination | Step |
|---|---|---|
| Git (1,414) | git-write-guard.sh, permissions, commit skill description, ending-gate.sh; root keeps nothing | 1 |
| Claude Code plugin/skill repos (514) | permissions.deny; root keeps one line, edit the source clone | 1 + root |
| NOTES/TODO/CALENDRIER bullet | permissions.deny and verifier.md; root keeps nothing | 1 |
| Memory location override, memory level, general rule to CLAUDE.md (2,062) | inject-rules.sh: Write/Edit under ~/.claude/projects/*/memory/ denied with a redirecting reason; a write under ~/.claude/memory/ injects a new rules/memory.md | 1 + 3 |
| Secret files handling (2,117), secrets.md | inject-rules.sh: Read, Edit or Bash touching a matching path gets permission decision ask with secrets.md injected; *.example, *.template, *.sample excluded; root keeps the pasted-credential rule, the credential-surfaced rule and the persist-a-flagged-path rule | 1 + 3 + root |
| PDF reading (231), pdf.md | first native Read of a PDF in a session denied with pdf.md injected; a Bash command naming a .pdf or a poppler/pdf-inspector tool injects it | 1 + 3 |
| DOCX verification (303), docx.md | injected on .docx, libreoffice, soffice; the file first drops under 9,000 characters, its dated measurement narratives moving to _meta/notes/docx-verification.md | 3 |
| showboat (414), showboat.md | injected on apt, uv tool install, pip install, stow, claude plugin install, systemctl | 3 |
| environment.md (29,281) | split then deleted: versions and CLI inventory cut (command -v, --version); runtime pitfalls to shell.md, python.md, quarto.md, typst.md, r.md, rust.md; sys-update and one tool one binary to a new rules/install.md injected with showboat.md; chromium and firefox to a new rules/chromium.md injected on those commands; history to _meta/notes/ | 2 + 3 |
| Dotfiles & symlinks (2,393) | package list, firefox and zotero profile warning to rules/install.md (trigger stow); root keeps one line, a $HOME file resolving into ~/dotfiles is edited at its resolved path | 3 + root |
| Binary verification artefacts (895) | merged into rules/chromium.md | 3 |
| Skills named in the user's message (1,157) | new UserPromptSubmit hook skill-mention.sh, validating each /<name> against the installed skills (parsing as in opencode-skills-sync) | 3 |
| Agents (3,066) | inject-rules.sh on the first Agent call injects a new rules/agents.md; root keeps propose agents beyond about 5 files, and spawn agents means the Agent tool | 3 + root |
| Session-start PLAN.md, compaction, .claude/ default location (about 2,000) | inject-project-context.sh: legacy root Claude files and a root CLAUDE.md masking .claude/CLAUDE.md flagged on startup; pointer to .claude/PLAN.md on startup, compact, resume; the index part untouched; root keeps create under .claude/ and propose a PLAN.md | 3 + root |
| Cite by name, tables in fences, claims backed by a command, English for Claude-facing content, the routing test and budget (about 3,500) | new rules/claude-files.md, paths **/.claude/**/*.md, **/CLAUDE.md, **/AGENTS.md | 2 |
| No comments in code, only modify directly related code, padding, lint gate and its scope (about 4,300) | rules/code.md | 2 |
| Adversarial review exit signal | audit/walkthrough in claude-code-plugins (existing decision); the root line goes once the skill carries it | 4 |
| Communication, Prose hygiene, Profile, References, Build (design, premise, ouroboros), Shell search preferences | root, rewritten to the rule alone, rationale to this note | 5 |
```

What the table displaces: about 95 KB loaded on 2026-09-26, 41,056 for `CLAUDE.md` and 54,331 for the five files, against the root measured in step 2.

Decision, 2026-10-03: the root's Ouroboros interview rule is dropped, and the `design` skill no longer cites it, because the transcripts of 2026-09-25 to 2026-10-03 hold no `ouroboros:interview` call and the plugin is disabled globally.

### Rejected

- **Relocating the injected files to a new `claude/.claude/context/` directory**: a new stow directory, four `AGENTS.md` lines and about ten notes to repoint, and the loss of the `paths:` layer for PDFs and secrets, to save one duplicate load of `pdf.md` when a PDF is read natively.
- **Skills instead of injection** (`pdf-reading`, `docx`, `showboat`, `secrets`): skill activation measured at 55 % without a hook (Spence, in the reco), too weak for secrets, and step 4 of the test comes after step 3.
- **`paths:` alone, no hook**: a PDF reached through `pdftotext`, an install in Bash or a `cat .env` never triggers a `paths:` rule, which recreates the unread pointer Yang et al.
  measured.
- **Doing nothing**: about 95 KB really loaded every turn, and a root that describes an on-demand layer that does not exist.

## The harness loads the memory index natively, and a prek check holds it under the harness limits

**Decision.** Approved by the user on 2026-09-26, each of the five parts named separately: the native load below, the compact index line format, `autoDreamEnabled: false`, the prek size check and the two tests, the last four as built in "Implementation (opened on 2026-09-27)".

**Native load.** `autoMemoryDirectory` in the user settings (`claude/.claude/settings.json`) points at the store. `inject-project-context.sh` stops printing the global index, and its project-index branch skips a `.claude/memory/MEMORY.md` that resolves to the global store. A search of `~/Documents`, `~/admin` and `~/dotfiles` on 2026-09-26, ignored files included, found two project indexes: `~/dotfiles/claude`'s, which resolves to the store and is skipped, and `eds-prise`'s, a real project index the hook keeps printing.

**Why.** Read in the binary of Claude Code 2.1.283 on 2026-09-26:

- The hook-output cap, the index load limits, the native recall's server flag and the setting's own resolution are held by `reference_claude_code_best_practices.md`. One of them was read only partly and stays worth knowing: the setting's description says a checked-in project setting is ignored "for security", while the code consults local and project settings before the user settings under a condition (`LH()`) not fully read; no settings file under `~/Documents`, `~/admin` or `~/dotfiles` set the key on 2026-09-26.
- `autoDreamEnabled: true` had sat in the user settings since `43118a7`, with no recorded reason. The dream prompt reads the transcripts, rewrites `MEMORY.md` in the `- [Title](file.md) — hook` form, merges memory files and deletes `.md` files of the auto-memory directory: pointed at the store, it would rewrite a curated, public store in the background.

Step 3 of the routing test caps a hook injection at 10,000 characters, so a 21 KB index is not hook material.

**Probe, 2026-09-26.** Two `claude -p --model sonnet --tools ""` runs with a canary line at the end of a scratchpad index, 0.20 USD, settled the load limits now held by `reference_claude_code_best_practices.md`. The probe used `--settings`, so it left the user-settings source and the `~/` expansion to the canary probe of 2026-09-27.

**Rejected.**

- **Hook, index compacted under 10,000 characters**: about 65 % cut (a filename plus about 50 characters of description per entry), each new entry shrinks all the others, and the full descriptions become an unread pointer.
- **Hook, index split across several outputs under 10,000 characters each**: the number of pieces is fixed in `settings.json` while the index grows (the Feedback section alone was 12,213 bytes on 2026-09-26), nothing caps what enters context, and a move of the harness to a cumulative cap falls back to the preview silently.
- **Per-project filtering**: the Feedback section, cross-project, exceeds the cap on its own, and a scope tag on 107 files is a new convention with subjective tagging.
- **A pointer to read the index on demand**: the unread pointer of "Rejected" in "Each instruction lives where its trigger fires, and the root keeps only what has none".
- **Doing nothing**: the defect.

**Weakest assumption.** Holds as long as the harness keeps loading the configured directory's index into context. If the server flag of the native recall turns on for this account, the index leaves context and a selector surfaces up to five memories a turn from the files' `description`; all 107 memory files carry one (counted on 2026-09-26), so recall continues by that route, outside this repository's control. The auto-memory write carve-out, untraced at approval, was read on 2026-09-27: with the chosen `~/.claude/memory` no memory write matches it ("Implementation (opened on 2026-09-27)").

### Implementation (opened on 2026-09-27)

**Effort.** `_meta/instructions-ab/run.sh` passes `--effort`, `high` unless `INSTRUCTIONS_AB_EFFORT` says otherwise, and writes it as `effort` in each `meta-*.tsv`. Both routing arms, six scenarios each, ran unpinned, at the `high` of `effortLevel`; the recall arms are the first pinned ones. The init event of `stream-json` carries no effort level (only the boolean `per_turn_effort_active`), so the meta line is the record.

**Recall scenarios as built.** `nbsp`: `fixtures/nbsp/format.R`, whose `fmt_pct()` pastes a plain space before `%`, the prompt asking for a non-breaking one. `parquet`, which replaced the env presence scenario after the first baseline batch (below): `fixtures/parquet/load.R`, whose `read_visits()` reads a whole file with `nanoparquet::read_parquet()`, the prompt asking to read only two columns; the memory is `reference_nanoparquet_col_select.md`, whose index line lies past the 2 KB preview, and no rules file names `col_select`. Signals as graded:

```
| Scenario | Signal as graded |
|---|---|
| nbsp in R | a literal U+00A0 or U+202F in the final format.R; ungraded when format.R is unchanged |
| parquet | col_select in the final load.R; an unchanged load.R is graded, since declining the argument is the memory's answer, and flagged in the detail |
```

The recall, a `Read` or a Bash command naming the memory file, is reported in each run's detail. `run.sh` with no scenario argument now runs the eight prompts, routing and recall together: every arm names its scenarios. Writing the grader reproduced the `nbsp` memory twice: the four-hex-digit `\u` escape of U+00A0, typed in an Edit parameter, landed as the raw character in `grade.py` and then in this paragraph, while Python's `"\N{NO-BREAK SPACE}"` landed verbatim.

**Baseline arm, 2026-09-27.** The auto mode classifier refused a nested `claude -p` run from the session, without a reason, so the user runs each arm with `!` (`run.sh recall-baseline 5 <scenario...>`). No file the runs load (`settings.json`, the hooks, the index, `rules/memory.md`) changes before the baseline arm has run. First batch on `d374ad4` plus the uncommitted harness, effort `high`, 3.69 USD:

```
| Scenario | Graded | Violations | Memory read | Cost (USD) |
|---|---|---|---|---|
| env presence | 5 | 0 | 0 | 1.78 |
| nbsp | 5 | 4 | 0 | 1.91 |
```

The env presence scenario put a fake `SENTRY_DSN` in the run's environment, through an `env/<scenario>` file that `run.sh` passed to `env`; every run found it set (length 52) and tested it with `${SENTRY_DSN+x}`, `-n` and `${#SENTRY_DSN}`, never printing it, without reading the memory. At the ceiling, it was replaced by `parquet`, and its fixture, prompt, grader and the `env/` mechanism were removed. The one clean `nbsp` run hit the decoding too, saw it through `od -c` and ended on `intToUtf8(0xa0)`: a self-correction, not a recall.

Second batch the same day, same `HEAD` and effort, 1.77 USD: `parquet` 5 graded, 5 violations, memory read in none; every run wrote `col_select = c("patient_id", "visit_date")`. The baseline arm is complete:

```
| Scenario | Graded | Violations | Memory read | Cost (USD) |
|---|---|---|---|---|
| nbsp | 5 | 4 | 0 | 1.91 |
| parquet | 5 | 5 | 0 | 1.77 |
```

**Size check.** Inside `bin/.local/bin/instructions-budget` rather than a new script, the index staying out of the budget sum; its flags, defaults and `prek.toml` entry are the script's own, pinned by `instructions-budget.bats`. The check is stricter than the harness by one byte, which counts the index trimmed of trailing whitespace.

**Write carve-out.** Its mechanics are in `reference_claude_code_best_practices.md`; what it decides here is which of the two spellings the setting names.

```
| autoMemoryDirectory | Write through ~/.claude/memory/ | Write at ~/dotfiles/claude/.claude/memory/ |
|---|---|---|
| ~/.claude/memory | prompts (the resolved spelling fails) | prompts |
| ~/dotfiles/claude/.claude/memory | prompts (the link spelling fails) | allowed without a prompt |
```

`CLAUDE.md` sends a write to the resolved path, so with the resolved directory every memory write, `MEMORY.md` included, skips the prompt. Chosen by the user on 2026-09-27: `~/.claude/memory`, under which no memory write matches the carve-out and every one keeps its prompt, as before the change; it is also the path every document names.

**The five parts, 2026-09-27, after the baseline arm.**

1. `settings.json` sets `"autoMemoryDirectory": "~/.claude/memory"`. `inject-project-context.sh` no longer prints the global index, and prints a project index only when `readlink -f` of `.claude/memory/MEMORY.md` differs from that of `~/.claude/memory/MEMORY.md`, which skips `~/dotfiles/claude` and `~` itself; `inject-project-context.bats` has 12 tests, three of them for the skip and the absent global index. <!-- prose-lint:ignore -->
2. `MEMORY.md` in the compact format, 25,909 bytes down to 21,626 for 116 lines, the rewrite checked byte-identical to a `sed` of the 107 entries at `HEAD`, then 21,658 bytes as committed in `78a40b0`, one line having gained the Python spelling after the check; `rules/memory.md` gains the format bullet and names the conflict with the harness's `- [Title](file.md) — hook`, and its "One store" bullet now names the harness as the loader and the prek check.
3. `"autoDreamEnabled": false`.
4. The size check above, passing on the compact index.
5. Tests: the canary probe and the after arm, both below. Committed in `78a40b0`, the harness in `ac0db46` (effort pin) and `847f432` (recall scenarios), so the after arm ran on a `HEAD` holding all three.

Live references checked by grep: the `commit` verifier compares index lines with the directory without parsing the link form, opencode's `claude-hooks.ts` loads the whole file, and the `audit` plugin's walkthrough already reads `autoMemoryDirectory` before any other candidate store.

**Canary probe on the real settings, 2026-09-27.** One `claude -p --model sonnet --tools ""` run from a scratch directory, launched by the user, with no `--settings`, 0.12 USD. The init event reported `memory_paths.auto` as `/home/julien/.claude/memory/`, which settles the user-settings source and the `~/` expansion left open by the first probe; the three `SessionStart` outputs were empty; the model quoted the header "Contents of /home/julien/.claude/memory/MEMORY.md (user's auto-memory, persists across conversations)" and line 116, the index's last, verbatim, with no truncation notice.

**After arm, 2026-09-27.** 10 runs on `847f432` (one dirty path, the user's Positron settings), effort `high`, Claude Code 2.1.283, launched by the user, 4.08 USD. Every init event reported `memory_paths.auto` as `/home/julien/.claude/memory/`.

```
| Scenario | Violations (after) | Violations (baseline) | Memory read (after) | Memory read (baseline) | Cost after (USD) | Cost baseline (USD) |
|---|---|---|---|---|---|---|
| nbsp | 0 | 4 | 0 | 0 | 1.94 | 1.91 |
| parquet | 1 | 5 | 5 | 0 | 2.14 | 1.77 |
```

Read run by run:

- `nbsp`: all five runs wrote `"\u{a0}%"`, the braced form the index line itself gives, without opening the memory file. The index line in context was enough to change the behavior, so the "memory read" column undercounts recall wherever the line carries the fix.
- `parquet`: all five read the memory. Four read the whole file and `dplyr::select()` the two columns. The violation, run 2, reproduced the bug on a synthetic file, then switched to `arrow::read_parquet(col_select = ...)`: it avoided nanoparquet's `col_select`, the memory's target, while the grader flags `col_select` from any package. The graded count stays at 1, the grader not being changed after the results.

From 9 violations in 10 runs with no recall to 1 (0 on reading) with recall in every run where the line alone did not carry the fix: five reps a scenario detect a large effect, and this one is large; it is evidence that the natively loaded index reaches the model, on two memories whose lines sat past the 2 KB preview before the change. The implementation is complete; the step 4 window runs from `78a40b0`.

**Two harness behaviors the change switched on, observed on 2026-09-27.** A session opened at 00:33 in `quarto-hebstr-doc`, after `autoMemoryDirectory` was set, edited `reference_quarto_lua_shortcodes.md` and the index through `~/.claude/memory/`, and its transcript (`5a47d6f6`) shows both:

- **Index near-cap nudge.** After its `Edit` of `MEMORY.md` the harness injected, as `PostToolUse` context: "The memory index at MEMORY.md is 21.2KB, approaching the 24.4KB read limit. Compact it to under 17.1KB now: keep one line per entry, move detail into topic files, and merge or drop stale entries." (`tengu_memdir_entrypoint_near_cap` in 2.1.283.) The session obeyed and shortened about a hundred descriptions: 21,658 bytes down to 17,484 after its tracking verifier's corrections, 107 entries kept, index and directory still matching, left uncommitted; committed on 2026-09-27 in `f2d6ed5`, at 17,555 bytes and 116 lines after later edits of its index lines. The two recall A/B lines (`reference_nanoparquet_col_select.md`, `feedback_edit_tool_unicode_escape.md`) were restored to the wording the after arm measured, identical to `HEAD`. The design's size target (the 25,000-byte limit, a pruning pass when a commit crosses it) meets a harness target of about 70 % of the limit, restated at every index edit above it.
- **Frontmatter stamping.** `stampNewMemoryContent` rewrote the file's frontmatter on write: `originSessionId` and `modified` (the file's mtime to the millisecond) added, `node_type: memory` added, the `name:` title turned into a slug, the `description` quoted. `rules/memory.md` holds `name:` to be a human-readable title.

**Probe of the path gate, 2026-09-27.** One `claude -p` run launched by the user, 0.30 USD, over a scratch symlink `link -> real` named as `autoMemoryDirectory`: through `link/` the written memory came back stamped and the index `Edit` drew the near-cap nudge, while through `real/` neither fired. A `quarto-hebstr-doc` session (`4d9359ec`) confirmed it live the same day, its memory file stamped through `~/.claude/memory/` (stamp removed the same day, see "Decision (user, 2026-09-27)"). The thresholds and the internals are in `reference_claude_code_best_practices.md`.

**Decision (user, 2026-09-27): memory is written at the resolved path, and the design keeps its 25,000-byte target and `name:` titles.** The global `CLAUDE.md` already sends a write to a file resolving into `~/dotfiles` to its resolved path, yet `5a47d6f6` and `4d9359ec` wrote through the link, the harness's memory prompt naming `~/.claude/memory/`; a rule alone did not hold, so a `PreToolUse` deny enforces it. Adopting the harness's target instead would have let the nudge trigger a compaction mid-task in whatever session crosses 20,000 bytes, as in `5a47d6f6`, and would have put a millisecond `modified` and a session id into every memory diff of a public repository, with 96 titled files left to migrate.

- `inject-rules.sh`, `Edit | Write | MultiEdit` branch: a path under `$HOME/.claude/memory/` is denied every time, memory.md injected once per session, the reason naming the resolved file (`$HOME/dotfiles/claude/.claude/memory/` plus the same relative name) and asking to read it there first; the resolved path gets memory.md without a decision, a `Read` through the link passes, and the `~/.claude/projects/*/memory/` deny now names the resolved directory. `inject-rules.bats` has 38 tests, two of them new (the link deny for the three tools, the silent `Read`). <!-- prose-lint:ignore -->
- `rules/memory.md`: the "One store" bullet says the store is written at its resolved path, and the header names the second refusal. Both changes committed in `9dc1af3`.
- The two files stamped on 2026-09-27, `feedback_hebstr_doc_no_public_api.md` (merged into `feedback_review_severity_hebstr_doc.md` on 2026-11-08, so the name resolves nowhere and stays here as the record of what was measured) and `reference_quarto_lua_shortcodes.md`, got back their `HEAD` title and lost the three added fields and the quotes, their sessions' content edits kept (user's choice, 2026-09-27). The first write at the resolved path after the change drew `memory.md` and no decision.
- The step 4 window keeps its start at `78a40b0` (user's choice, 2026-09-27): step 4 measures the closure, tracking and recommendation relances, which the memory write path does not touch.
- Cost: one refused call in a session's first memory write, the `audit` walkthrough included, since it writes its calibration rules into the directory its loader resolved, `autoMemoryDirectory` first; and the harness's per-file memory checks (size, `-2` continuation) no longer see a write. A later Claude Code version that canonicalizes the path would bring both behaviors back: the stamp would show in a memory diff, and the prek size check still holds.

## A byte gate stops the growth, and the verifier names the vector

**Gate.** A local prek hook, script `bin/.local/bin/instructions-budget` on the `symlinks-check` precedent.

- Its threshold is the size measured at the implementation commit, rounded up to the next 512 bytes, which leaves no real headroom: an addition names what it displaces. It lives in the hook's `args` in `prek.toml`, so a change to it shows in a diff.
- The index is printed and not counted, which revises "the index counts in the budget" of the reco on a new fact, the 2 KB preview, and on its growth, about 150 bytes a day from `040568c` to `253341e`: counting it would fail commits during unrelated memory writes. The index ceilings it does check came on 2026-09-27 and 2026-10-06, the second by "The store admits a note only when no mechanism already produces the behaviour, and the guard counts index lines", which also moves the primary ceiling into `inject-rules.sh`.

**Verifier check.** `skills/commit/agents/verifier.md`, section 3, which carries the check and the one definition of a mechanism path it shares with the store check added on 2026-10-08.
It runs before prek at closure, so it names the sentence where the gate only gives a total, and it targets the vector the reco measured on three commits that lengthened root lines while adding a mechanism.

## The store admits a note only when no mechanism already produces the behaviour, and the guard counts index lines (approved by the user on 2026-10-06)

**Decision.** Approved on 2026-10-06, each of the seven parts named separately:

1. **The guard counts index lines.** Nothing guards body bytes.
2. **The 150-line ceiling is read by `inject-rules.sh` at every memory write, and `instructions-budget` keeps it as the versioned backstop.**
   The flag exists with a script default of 200 and is set nowhere today, so this part **adds** `--index-lines 150` to the `instructions-budget` args of `prek.toml`, which is what puts the value in a diff; `--index-bytes` stays on its 25,000 default, unset for the reason in "One threshold governs both dimensions" below.
   The hook is the primary guard because it is the only one of the three that fires in every project, in the session, at the write ("Why the guard cannot live at the dotfiles commit alone" below).
   The 150 is an interim set to reach the sweep, and is re-set at the sweep's commit to the count the sweep leaves plus a named margin, on the precedent of the byte budget in "A byte gate stops the growth, and the verifier names the vector"; the two carriers hold the same number.
3. **The admission test, whose first question is whether the mechanism firing already produces the behaviour.**
   On yes, nothing is written: the changed parameter, its commit and `git blame` carry it, per "Content" of `rules/claude-files.md`.
4. **`rules/memory.md` § "What goes where" replaces its tie-break with a three-outcome routing**, in which writing nothing is one of the outcomes.
5. **`verifier.md` § 3 extends the antecedent of its root check to the store**, keyed on the absolute store path as its own section 1 already keys `~/.claude/memory/MEMORY.md`, never on a repo-relative `claude/.claude/memory/`, which resolves only from dotfiles; the mechanism-path list widens to the session's own project.
6. **One test for the four families**, with no per-family bar.
7. **The sweep of the 127 files is step two**, run under this criterion with the machinery of "Third pass" in `PLAN-SESSION-DISCIPLINE.md`.

The prek check, the hook that injects `rules/memory.md` and the verifier check all existed already, and each gained the memory case it lacked.
The allocation is the routing test applied to three objects rather than a choice among them.
The guard is countable, so step 1 claims it, and the store being global decides which step-1 mechanism carries it.
The test is a judgment no predicate decides, so step 1 fails and step 3 claims its text, delivered by the `inject-rules.sh` branch that already fires on the session's first memory write.
The enforcement has a deterministic trigger and a judged verdict, which is the shape of the check already in `verifier.md` § 3.

**Why the guard cannot live at the dotfiles commit alone.** Three mechanics read on 2026-10-06 decide the allocation.
`writes.sh` builds `WRITES` from the session's write journal, whose paths are absolute, plus the `git status` of the current repository, so a memory written from another project **is** in `WRITES` and the verifier does see it: part 5 is sound once its antecedent stops being repo-relative.
`SKILL.md` § "The tracking repository" renders blocks for the parent repository and `<project>/.claude`, never for dotfiles, so such a memory stays uncommitted there until a later dotfiles session commits it, by which time the entry count has moved and the session that wrote it is gone.
The harness nudge fires in the session at 160 lines whatever the project, so a ceiling that waits for a dotfiles commit arrives after the thing it exists to pre-empt, where the `Edit | Write | MultiEdit` branch of `inject-rules.sh` is global, in the session and at the write, and needs only a line count on one file.

**Why lines, which the harness decided rather than this design.** The near-cap nudge of `reference_claude_code_best_practices.md` fires once the larger of the byte and line fractions reaches 80 % (20,000 bytes, 160 lines) and asks for a compaction under 70 %.
Measured on 2026-10-06 at `3dd113a`, the index stood at 61 % on bytes and **68 % on lines**, so the line fraction is the governing one, and it would reach 80 % twenty-four entries later, about two weeks at the inflow then measured.
The nudge is not advisory: "Two harness behaviors the change switched on, observed on 2026-09-27" records session `5a47d6f6` receiving it and rewriting about a hundred descriptions mid-task.
A `--index-lines` left on its 200 default can only fire after the nudge has compacted an index inside whatever session crosses it, which is the same class of defect as the index injection this note opened on, a mechanism set where it cannot bind, and not a size preference.

One threshold governs both dimensions, which is the second reason to count lines.
At the 130-byte line cap in force since 2026-10-04 ("Index lines too long" in `TRIAGE-MEMORY.md`), 150 lines cannot exceed 19,500 bytes, under the 20,000-byte nudge, so setting `--index-lines` alone puts the byte nudge out of reach and leaves `--index-bytes` on its 25,000 default.

This does not overturn the standing refusal of that same section, which was against **raising** either flag on the ground that the 25,000 and the 200 belong to the harness.
Lowering one below the harness's own nudge is the opposite move, and it uses the flag the refusal left in place.

**Why nothing guards the bodies.** No consumer reads a body per session, and the dimension is already falling.
The store is versioned, so every figure of the 2026-10-06 reading is re-derivable from `3dd113a` (`git ls-tree -r` plus `git cat-file -s`, the index subtracted); what git cannot give back is the comparison it was read against, 593,617 bytes over 114 files on 2026-09-22, a triage snapshot taken mid-pass, against 546,743 over 127 files, mean file 5,207 bytes down to 4,305.
The two consumers that pay per use both scale with entries: the harness loads `MEMORY.md` every session, and the "Scope filter" of `audit/walkthrough/agents/orchestrator.md` reads the `description` frontmatter of every file at every walkthrough.
A body is read when something opens it, which is per use and bounded by the per-file size, not by the total.
So the store grows in entries while its volume falls, and a guard on total body bytes would measure the one dimension already going the right way.

**Why the test asks about the behaviour and not about the fact.** `feedback_rm_rf_is_ask_not_deny.md`, the note that opened this, did carry something `permissions.ask` does not state: the instruction to run a recursive delete rather than hand the command over.
What makes its deletion right anyway is that the `ask` prompt *firing* produces that behaviour, where the former `deny` was what produced the hand-over.
A test phrased as "is the fact already in a mechanism" would have kept the note.
Phrased as "does the mechanism firing already produce the behaviour", it closes the case with nothing written.

**Why the enforcement is one word of a check that already ran.** The shape the root check wants was present on 2026-10-06, `7dd7327` (settings.json) and `e6e93b4` (the memory and its index line) committed six seconds apart in one closure, so `WRITES` held both; the check stayed silent because its subject named the root and not the store, which is the blind spot of point 1 of the routing test located in a single sentence.

**Why one test serves the four families.** Step 1 of the test discriminates them by itself.
It resolves "no" for `reference_` by construction: a harness threshold, a `nanoparquet` bug, a pandoc behaviour has no local mechanism that could carry it and no other holder in the repository, which is why most of the inflow being `reference_` is the test working rather than escaping it.
It resolves "maybe" for `feedback_` and `project_`, where permissions, hooks, rules and skills live.
A separate numeric bar would add a convention on top of a question that already decides.

**What none of the three catches.** A note written in a session that touched no mechanism and did not cross the line ceiling passes all three.
That case is left to the criterion of step two rather than to a fourth mechanism.

**Rejected.**

- **The prek ceiling alone**: it fires at a dotfiles commit, which for a memory written from any other project comes later and from another session, after the harness nudge; it also turns admission into a periodic sweep and cannot tell a good admission from a bad one.
- **Phrasing either check on dotfiles-relative paths**: the store is global while `claude/.claude/memory/` resolves only from dotfiles, so every memory written from another project escapes.
- **The verifier finding alone**: fires only when one session wrote both the note and the mechanism, and it is the only one of the three that never acts before the write.
- **The test in `rules/memory.md` alone**: prose with nothing to make it non-optional, which is the diagnosis the pass started from.
- **A guard on body bytes, and a per-family bar**: each measures or splits on a dimension that "Why nothing guards the bodies" shows is already falling, or that step 1 already decides.
- **Doing nothing**: the existing check sits at 200 lines, where the harness has already compacted an index mid-task.
- **Running `/workflow:reco` first**: the criterion is written locally in three places, a measured local A/B outranks a blog post on a question about this machine, and no external source can say which of these 127 notes is redundant with a mechanism here.

**Weakest assumption.** It holds as long as the nudge thresholds read in Claude Code 2.1.283 (80 % and 70 % of 200 lines and 25,000 bytes) stay as read.
The arithmetic was checked on 2026-10-06: the index's longest line is exactly 130 bytes, and 150 lines at that cap give 19,500 bytes against a 20,000-byte nudge.
If a later version moves the fractions, the 150 loses its anchor; part 2 puts it in the `prek.toml` args, so a change to it shows in a diff, which is the mitigation already chosen for the byte budget.

**Implemented on 2026-10-08**, the seven parts in one pass, the user having lifted the wait on the step 4 remeasure the same day.

- The memory branch of `inject-rules.sh` denies the write whose target does not exist yet, which is the shape that adds an index line, and lets through every write to an existing memory and to `MEMORY.md` itself: the prune its reason asks for is therefore never blocked by the deny, which is the deadlock the entry-shaped antecedent avoids. A `wc` missing from `PATH` leaves the branch silent instead of failing the hook.
- `agents/verifier.md` still has no suite of its own, where `inject-rules.bats` and `instructions-budget.bats` each pin their carrier's ceiling.

**The margin is a named 13 lines, set by the sweep on 2026-10-09 (user's call).** The ceiling stays at 150 against the 137 lines the sweep leaves, so neither carrier changes value and the two `inject-rules.bats` cases keyed on 150 and 151 stay green.
What decided it is a fact this framing did not have: the sweep admits all 129 files under step 1 and proposes no deletion, so the entry dimension yields no dividend, and a margin near zero on the precedent of the byte budget would turn the deny into a block whose prescribed remedy, pruning, this pass has shown unavailable.
The sweep's four batches, its refused cuts and its out-of-memory findings are in `TRIAGE-MEMORY.md`, section "Fourth pass: the sweep under the admission criterion"; its verdict tables were pruned there on 2026-10-13.

## Moved rules are tested only where a violation leaves a mechanical trace

**Log.** `inject-rules.sh` writes its own injections to the `InstructionsLoaded` log, which does not see them.
What the log is for beyond the arms is the open point below.

**A/B.** Two arms run in sequence rather than two user configs side by side, six scenarios, one per rule that leaves a mechanical signal, five reps each, 60 runs; `_meta/instructions-ab/grade.py` holds each signal, one copy, and only aggregates are recorded, the repository being public.
Not tested, and stated as such: showboat (real installs), the agents snippet, the communication rules (step 4 measures them from transcripts), and the deterministic denies, which bats covers.

## Weakest assumption, probed on 2026-09-26

The `additionalContext` of a `PreToolUse` hook reaches the model in the same turn, including when the decision is `deny` or `ask`; without it the secret and PDF rules arrive one call late, after the read they govern.
It holds, by five `claude -p --model sonnet` runs on Claude Code 2.1.283, 1.15 USD, whose scripts stayed in that session's scratchpad; the `paths:` behaviour checked alongside is in `reference_claude_code_best_practices.md`.
Two consequences the design leans on: the no-decision case is the one most injections of `inject-rules.sh` use, an `allow` skipping the permission prompt; and delivery never rests on a `paths:` load, since the hook injects the text.
Left unobserved: the interactive `ask` a user approves, `-p` having nobody to approve it.

## Implementation

### Step 0 (2026-09-26, committed in `fc68245`)

**A/B protocol as built.** The mechanics are in `run.sh` and `grade.py`; what follows is what they cannot state.
A fixture's `dot-` prefix and `.in` suffix are stripped on the copy so that the fixtures escape `format-on-edit.sh` and the repository's ignore rules, and `prek.toml` excludes `fixtures/` from `shellcheck`, `shfmt` and `shellharden` because `backup.sh.in` carries the unquoted variables its scenario asks to fix.
Each arm writes a `meta-*.tsv` because what makes two arms comparable is the state of the instruction set at the moment they ran, which nothing else records.
`bypassPermissions` is required: `.claude/` is a protected path that `acceptEdits` never auto-approves, so a `-p` run would be refused the `PLAN.md` write of the citation scenario. The `deny` rules and every hook stay active.
The four arms were still in `~/.cache/instructions-ab/` on 2026-09-30, which `sys-cleanup` does not sweep; the aggregate tables below stay the durable copy all the same, `~/.cache` being excluded from Syncthing and from every backup.

**Baseline arm, run on 2026-09-26.** 30 runs on the layout before any change to `CLAUDE.md` or `rules/` (dotfiles `HEAD` `ff4bdb6`, `CLAUDE.md` 41,056 bytes, the five unscoped rules loaded at launch), Claude Code 2.1.283, 20.29 USD.

```
| Scenario | Graded | Violations | Cost (USD) |
|---|---|---|---|
| comments | 5 | 0 | 3.72 |
| lint | 5 | 0 | 3.63 |
| envfile | 5 | 0 | 2.79 |
| pdf | 5 | 0 | 2.52 |
| skill | 5 | 0 | 3.40 |
| cite | 5 | 0 | 4.22 |
```

Every rule was followed in every run: the `.env` was read through the masking `sed` each time, `detect-pdf` was the first call on the PDF each time. The arm sits at the ceiling, so the after arm can show a regression and never an improvement, and five reps detect one poorly: a rule broken in 30 % of runs still comes out clean at 0/5 with probability 0.7^5, about 17 %. A violation in the after arm is therefore a signal to read the run, and a clean after arm is weak evidence rather than proof.

**Known bias for the after arm.** Under `-p` an `ask` resolves as a denial, so the secrets scenario of the after arm measures a refused read where an interactive session would let the user approve it; its result bounds the rule's delivery, not the interactive outcome.

### Step 1 (2026-09-26)

`claude/.claude/hooks/inject-rules.sh` and `_meta/tests/inject-rules.bats` (25 tests at the end of step 4, two of them for the `claude-files.md` trigger of step 2), wired in `settings.json` as a `PreToolUse` group on `Read|Bash|Edit|Write|MultiEdit|Agent`. The hook keeps its trigger table in its own `case` branches; injects each rules file once per session through the marker `${XDG_RUNTIME_DIR:-/tmp}/claude-code-rules-<session>`, frontmatter stripped; asks on every access to a secret path, `secrets.md` riding along the first time; denies the first native `Read` of a PDF while `pdf.md` is not yet injected; denies memory writes under `~/.claude/projects/*/memory/`; defers a block that would carry the context past 9,500 characters to the next matching call; logs each delivery to `instructions.log` with a `load_reason` of `inject`, `inject-ask` or `inject-deny`.

A path under any `.claude/rules/` directory is exempt from the secret patterns, a relative word of a Bash command being resolved against the payload's `cwd` first, so the rules files themselves (`secrets.md` first) never trigger an `ask`. The install, browser and LibreOffice triggers match only a word in command position (start of a segment, after `sudo` or `timeout <duration>`), since the first live use in this session injected `chromium.md` and `docx.md` on a `wc -m chromium.md` and on an `rg` pattern naming `libreoffice`; the PDF and `.docx` triggers stay on any mention of the extension or of a poppler or pdf-inspector tool.

What each injected rules file is made of, its `paths:` being in its own frontmatter and its size recomputed by `instructions-budget` at every commit against the 9,000-character cap:

```
| File | Source |
|---|---|
| pdf.md | the frontmatter and a capture pointer added |
| docx.md | trimmed from 12,020 characters; dated measurements to _meta/notes/docx-verification.md |
| secrets.md | the frontmatter, and the scope section formerly in CLAUDE.md |
| showboat.md | the frontmatter, and an opening that names its trigger |
| install.md | new: sys-update, covered is not current, one tool one binary, sys-orphans, dotfiles and stow (from CLAUDE.md, "Dotfiles & symlinks") |
| chromium.md | chromium entry of environment.md, plus "Binary verification artefacts" from CLAUDE.md |
| agents.md | CLAUDE.md, "Agents", minus the two lines the root keeps |
| memory.md | CLAUDE.md, the memory location, memory level and general-rule bullets, plus the English rule |
| claude-files.md | step 2, below |
```

`showboat.md` and `install.md` travel together, their injected blocks totalling 8,013 characters with headers on `sudo apt install`. `environment.md` is deleted: its full text is archived in `_meta/notes/environment-archive.md`, its runtime pitfalls went to `shell.md` (dash, apt-frozen shellcheck and shfmt), `python.md` ("Interpreters on this machine"), `quarto.md` (bundled pandoc) and `r.md` (the PPM binary mirror, the `--mathml` warnings), the rest to `install.md` and `chromium.md`, and the versions and CLI inventory are cut. Live references were repointed: `sql.md`, eight memory files, `DEFERRED.md`, the Ubuntu migration checklist, the terminal highlighting note (that one line left uncommitted with the other session's terminal-color work in the same file), and opencode's `AGENTS.md` (tools read with `command -v` and `--version`, installs and stow in `install.md`); dated sections of plans and notes keep the old name as record.

`inject-project-context.sh` clears the session's marker on `compact`, tested by `_meta/tests/inject-project-context.bats`, "clears the session's injection marker on compact".

### Steps 2 to 4 (2026-09-26, committed with step 1 in `daa2729`)

**Step 2.** `CLAUDE.md` rewritten by the table, 41,056 bytes down to 12,092 (`wc -c`), its former text archived verbatim in `_meta/notes/claude-md-archive.md` as the record of the rationale the rewrite cut. No rules file loads at launch any more.
Why the root keeps what the table routed nowhere: "No comments in code" and "run the gate" as bare rules (decision in "A `paths:` rule loads on a native `Read` only (2026-09-26)" below), their detail in the new `code.md`; the soft-wrap and deprecated-form rules; the tracking-update and verify-before-done bullets, whose trigger is a session moment no hook sees; and a sentence telling Claude to read a language's rules file before creating a file in it, since a `Write` loads none.
`inject-rules.sh` injects the new `claude-files.md` on the session's first write to a `.claude/` markdown file, `CLAUDE.md` or `AGENTS.md`, since the baseline `cite` runs edit `PLAN.md` after a `cat` and load no `paths:` rule.

**Step 3.** `claude/.claude/hooks/skill-mention.sh` (`UserPromptSubmit`) names each `/<name>` of the prompt that resolves to an installed skill or command, its cases pinned by `_meta/tests/skill-mention.bats`.
Since 2026-10-11 it drops the whole prompt when a relay or pasted-content tag survives the stripping, a literal closing tag inside a block truncating the lazy match and exposing the block's tail, and its injected message no longer claims that a `disable-model-invocation` skill loads from the Skill tool: it directs that the user retype the `/name` as the first token of a message and that the skill's `SKILL.md` not be read instead.
`inject-project-context.sh` prints its pointers before the memory index so that they land inside the 2 KB preview.

**Step 4.** `bin/.local/bin/instructions-budget`, two properties of which the code does not explain: the injected-file cap check reads the names from the hook's `want` calls, so a change to the hook reruns it, and a frontmatter never closed counts as unscoped, as the loader treats it.

### Step 5, the after arm (2026-09-26)

30 runs on `daa2729` (`CLAUDE.md` 12,092 bytes, no unscoped rule), same model, Claude Code version and protocol as the baseline, 10.84 USD against 20.29.

```
| Scenario | Graded | Violations (after) | Violations (baseline) | Cost after (USD) | Cost baseline (USD) |
|---|---|---|---|---|---|
| comments | 5 | 0 | 0 | 1.93 | 3.72 |
| lint | 5 | 0 | 0 | 2.18 | 3.63 |
| envfile | 5 | 0 | 0 | 1.65 | 2.79 |
| pdf | 5 | 0 | 0 | 1.36 | 2.52 |
| skill | 5 | 0 | 0 | 1.89 | 3.40 |
| cite | 5 | 0 | 0 | 1.83 | 4.22 |
```

No regression on any of the six rules, which within the power stated for the baseline is weak evidence that the moved rules still reach the model, not proof. The `InstructionsLoaded` log of the after runs shows the mechanisms firing: `pdf.md`, `secrets.md` and `claude-files.md` injected five times each, the `comments` runs following the bare root rule with no `paths:` load, and no rules file loading at `session_start`. Every PDF run opened with a Bash call naming the file (`pdfinfo`, `ls`), which injected `pdf.md` before `detect-pdf` ran, so the deny on a first native `Read` never fired.

One behavior changed under the known `-p` bias: in one `envfile` run of five the `ask` on `.env` resolved as a refusal and the model stopped on a recommendation (`uv run --env-file .env python app.py`) without naming the missing `SENTRY_DSN`, which all five baseline runs and the four other after runs named. That is the rule working as designed, a refused secret access, and an interactive session would have asked the user instead.

Cost fell by 47 % at similar turn counts, which fits about 83 KB less instruction text loaded on every request; the arms were not designed to measure cost, so the figure is an observation.

### A `paths:` rule loads on a native `Read` only (2026-09-26)

**Decision.** The root keeps "No comments in code" and "run the lint, format and test gate" as bare rules; their detail (the exception list, the gate's scope, hard failure, a missing tool) goes to `code.md`. Chosen by the user on 2026-09-26, over denying the session's first write of a code file to inject `code.md`, and over the table's routing of both rules to `code.md` alone.

**Why.** The `InstructionsLoaded` log of the baseline arm shows a `paths:` rule loading only on a native `Read` of a matching file. The five `comments` runs create `extract_ids.py` with `Write` and load neither `code.md` nor `python.md`; two of the five `lint` runs read `backup.sh` through `cat` and load neither `code.md` nor `shell.md`. Routing test step 2 says as much ("Its trigger is reading a file type through `Read`"), and the table misapplied it to two rules whose trigger is writing code. "No comments in code" also meets the admission bar, the user having corrected it repeatedly, last on 2026-09-22.

### Walkthrough of `inject-rules.sh` (2026-09-26)

`/audit:walkthrough` with reviewer `posit-dev:critical-code-reviewer`: 15 findings, plus 2 found while verifying fixes (17 in all): 11 accepted, 2 rejected, 4 noted. Heuristic findings were judged by replaying the Bash commands of the last 14 days of transcripts through the hook (about 12,300 commands), per `feedback_review_severity_heuristic_code.md`. What changed in the hook's contract as stated in "Step 1 (2026-09-26)":

- The marker is `claude-code-rules-<session>` in the main thread and `claude-code-rules-<session>-<agent_id>` inside a subagent, whose tool calls carry the parent's `session_id` (the binary documents `agent_id` as present only within a subagent). Before this, the reviewer's subagent consumed the parent's one-shot `pdf.md`, `showboat.md` and `install.md`. `inject-project-context.sh` removes both forms on `compact`.
- The secret `ask` fires on a substring pattern (`secret`, `password`, `passwd`, `apikey`, `api_key`, `token`) only for a word that holds a `/` or a `.` or exists relative to its directory: 253 asks down to 74 on the replay, the remaining ones mostly jq `.key` filters until the stem rule at the end of this bullet. The Bash scan splits on parentheses (the former bracket `[;&|<>()=]` left `>`, `(` and `)` in place, so `x=$(cat .env)` asked nothing), braces and commas, strips trailing `*` and `?`, and resolves a relative word against the target of a preceding `cd`. Exact names (`.env*`, `*.pem`, `*.key`, `*.pfx`, `id_rsa*`, ...) are checked before the `.claude/rules/` exemption, which no longer applies to a path holding `..`; `*.pem`, `*.key` and `*.pfx` need a stem starting with an alphanumeric, `_`, `*` or `?`, so a jq `.key` does not match.
- A newline starts a command segment for the install, browser and LibreOffice triggers: 22 multi-line `chromium` commands of the replay had missed `chromium.md`. Other prefixes the reviewer listed (`VAR=`, `env`, `sudo -E`, `time`, `nice`, `xargs`, `/usr/bin/`, `then`) matched nothing on the replay and stay out.
- A block the cap skips leaves a one-line pointer to read the file before acting on the call, with room reserved for the pointers, and stays unmarked so the full block arrives on the next matching call; the worst real case (install, docx, pdf, chromium in one command) outputs 8,930 characters. A `deny` carries only the reasons of the deny.
- Rejected: blanking quoted text before the command-position triggers (24 of the 27 quote-only install triggers were `ssh host '...'` commands), and failing open when the marker cannot be written (no reachable condition here). Noted: the loop's cost (72 ms on the largest replayed command, 6,241 characters), the `NotebookEdit` and `Task` branches (`Task` is still a name the binary handles), the per-file `load_reason` of the log (no programmatic reader), the `Grep` tool (absent from the sessions' tool lists).

`inject-rules.bats` went from 25 to 36 tests, `inject-project-context.bats` extended its compaction test.

## A prompt goes to a file, and the rule splits across the root and the rules file (instructed by the user on 2026-09-30)

**Decision.** Claude never writes a prompt in the conversation: it goes into the project's `.claude/PROMPT.md`, unasked at a session boundary.
The root keeps the trigger and the destination in one line, because a session boundary implies no read of any `.claude/` file, so nothing scoped would have loaded by then.
The file's lifecycle goes to its own section of `rules/claude-files.md`, which `inject-rules.sh` loads on the session's first write under `*/.claude/*.md`, `*/CLAUDE.md`, `*/AGENTS.md` or `*/_meta/notes/*.md`.

**The ignore list, recorded on 2026-10-14.** The root `PROMPT.md` pattern of `.gitignore` went on 2026-09-30 in `218bab9`, which is what lets a prompt buffer be versioned at all, and the `.claude` repository re-ignored `PROMPT*.md` on 2026-10-02 in `d708b8e`, deleting the one tracked buffer with it.
So the destination the rule names is tracked in no repository here, which is what a buffer whose resting state is empty asks for, and the `PROMPT*.md` exclusion the campaign count of `PRUNE-OBSERVATIONS.md` argued on 2026-10-01 binds only the span before that commit.

**Why step 1 does not claim it.** Detecting a prompt inside assistant prose is a heuristic, not a mechanism, so no hook can enforce the prohibition; the instruction is all there is.

**The admission bar does not arise.** The line replaced the existing "provide a ready-to-paste continuation prompt unasked" rather than adding one, and the user instructed it directly, so the two-corrections bar above, which governs what Claude proposes to add, is not in play.

**What it displaced.** The first wording ran the root line to 12,344 bytes against the 12,288 budget and `instructions-budget` refused it. The line was cut back to the trigger and the destination, the detail already living in the rules file, and the check returned to 0.

**Cascade, the same day.** `workflow:continue` prescribed the opposite ("Print directly (no file written)", "Do not create CONTINUATION-PROMPT.md"), so the rule would have lost on every invocation, and the skill was realigned in its source clone.
`AGENTS.md` mirrors the root's Communication section, so it took the rule too, against a first pass that concluded it owed nothing on a grep for "continuation": a mirror is checked by the section it digests, not by the words of the line being changed.

**That cascade was undone later the same day**: a `/design` deleted `workflow:continue` outright, its three steps having each become a standing obligation (this rule and the `.claude/PROMPT.md` section of `rules/claude-files.md` for the prompt, the "Plans and tracking" line plus the harness memory instruction and the `commit` verifier for the other two), and the alignment edits above were dropped with the file. The measure that settled it is the item of `~/Documents/packages/claude-code-plugins/.claude/PLAN.md`: about forty `PROMPT*.md` writes in five days across four repositories, none of them through the skill, and richer than the template its step 3 prescribed. Carrying that template into the `.claude/PROMPT.md` section was rejected for the same reason, and stays available in one sentence should a written prompt ever come out vague.

## The Edit-or-Write rule stays prose, because the gate it protects also writes from the shell (decided on 2026-09-28)

**Decision.** The `CLAUDE.md` bullet "Every file write goes through Edit or Write" stays where it is, and no deterministic mechanism is built for it, although step 1 of the routing test would normally claim it.
The user also holds the simpler lever: `permissions.defaultMode` is `default` in `claude/.claude/settings.json`, so auto mode is switched on per session, and not switching it on in this repository removes the contradicting instruction at its source.

**What a shell write actually costs, checked on 2026-09-28.** `write-journal.sh` is a `PostToolUse` on `Edit|Write` reading `.tool_input.file_path`, a field a Bash write does not carry, so the file never enters the journal, never enters the `WRITES` of `scripts/writes.sh`, and is never reread by `agents/verifier.md`.
`prose-lint-pretool.sh` and `format-on-edit.sh` are bypassed for the same reason.
Three enforcement layers, not a style preference.

**Why the mechanism is not cheap.** The mandated gate itself writes files from the shell: `rules/shell.md` requires `shellharden --replace` then `shfmt -w -i 2`, `rules/python.md` requires `ruff format`, and `rules/code.md` states that this mutation is part of the gate.
A permission `deny` or a guard that refuses "shell writes" therefore breaks the gate it is meant to serve.
The separating line is the shell construct rather than the tool: `sed -i`, a redirection to a tracked file, a heredoc, `tee`, `awk -i inplace`, `perl -pi` on one side, a formatter writing through its own flag on the other.
That line is visible in the `shfmt` tree `git-write-guard.sh` already parses, so the mechanism is designable, as its own `/design`, and it is not a permission entry: a prefix glob cannot see a redirection sitting mid-pipeline, and a whitelist of formatter commands would grow with every language.

**Why nothing is built now.** No violation has been observed: the rule held on 2026-09-28 under direct harness pressure, every write of that session going through `Edit` or `Write`.
A mechanism whose first consumer is a hypothetical failure is the premise test of "Build discipline" failing, so the outcome is "already covered, close it".
**Announcement ban, 2026-10-03.** The rule held, but each auto-mode session reported the conflict to the user, because "Name the conflict rather than resolving it in silence" (Environment section) applied to it, which is what the bullet's own exemption now stops.
**Source removal rejected, 2026-10-03.** `"disableAutoMode": "disable"` (top-level or under `permissions`, string value) is the only setting that stops the injection, by removing auto mode from the `Shift+Tab` cycle (`settings-reference`, section `disableAutoMode`). The user keeps auto mode, so it is not set. No setting, variable or hook suppresses the message while auto mode stays on: `additionalContext` is additive only.
Loosening the bullet for auto mode is the other way to remove the contradiction, and it needs the three enforcement layers above extended to Bash writes first: not built, no consumer.

## A skill the artefact's type implies is loaded by a deny, not by a rule (2026-10-29)

**Why a mechanism.** `feedback_load_matching_skill` has prescribed loading a matching skill before producing the artefact since 2026-08-19, when bats tests written without `bats-testing-patterns` asserted the removals of `sys-cleanup`'s `claude-versions` module and never the status that was the whole bug.
The same omission recurred on 2026-10-29 on the `uv-python` prune tests of `_meta/tests/sys-update.bats`, surfaced the same way, by the user asking whether the skill had been invoked: a note alone did not hold, which is the memory-deny precedent of this file applied to a skill.
`skill-mention.sh` reaches only a `/name` the prompt carries, and no `paths:` rule covers `.bats`; one would have missed this case anyway, the file having been read with `sed` rather than `Read`.

- `inject-rules.sh`, `Edit | Write | MultiEdit` branch: a `*.bats` path is denied once per session, the reason naming `bats-testing-patterns` with the points the prek `shellcheck` hook cannot see (the stub and fixture patterns, and a failure path covered rather than the happy one alone); a `bats-skill` entry that the new `seal()` appends to the session marker releases the second call. No rules file rides along: `rules/shell.md` stands at 7,478 bytes against the 9,500-byte cap and would crowd out every other injection of a shell session. Nothing reaches `instructions.log` either, its block being guarded by `delivered`. `inject-rules.bats` has 42 tests, three of them new (the deny and its skill name, the later write, another file type untouched). <!-- prose-lint:ignore -->
- Cost: one refused call per session that writes a bats suite, a one-line fix included. The deny fired on its own author's first test edit, which is how it was verified live.
- Not generalized to the other skill-and-artefact pairs: only bats has a measured recurrence, and `feedback_load_matching_skill` still carries the rule for the rest, where the same omission stays possible.

## The hook owns `claude-files.md`, a write-time cap replaces dropping the `PLAN.md` mandate, and the shape ban narrows to the copula form (design approved by the user on 2026-11-06)

Input: `~/dotfiles/_meta/notes/agent-notes-discipline-reco.md`.
Two of its three recommendations were overturned on re-derivation, which is why this section exists rather than an implementation record alone.
The criterion it confirms is not reopened: a figure enters a note only if a named command re-derives it in seconds, in which case the command is written and never its output.

### `claude-files.md` gives up its real globs, and no other rule changes

**Decision.** Its `paths:` becomes the self-referential `**/.claude/rules/claude-files.md`, on the precedent of "The five files stay in `rules/`, scoped, and one hook injects them" above, so the `want claude-files` branch of `inject-rules.sh` is its only delivery.

**Why the hook and not the shipped mechanism.** Every section of the file is write-time guidance (Language, Form, `.claude/PROMPT.md`, Content, Where a new instruction goes), and nothing in it governs a read.
The hook's trigger is the superset: "A `paths:` rule loads on a native `Read` only (2026-09-26)" above measured that a `Write` of a new file loads no rule, which is the case where the Language and Form rules bind hardest.

**Scope of the test, re-derived from `instructions.log`.** Intersect the `path_glob_match` and `inject` events per session, keyed on the rule's basename:

```
awk -F'\t' '$4 ~ /\/rules\/[^\/]+\.md$/ {
  n=$4; sub(/.*\//,"",n); sub(/\.md$/,"",n); k=$3; sub(/^inject-.*/,"inject",k)
  if (k=="path_glob_match") pg[n"|"$2]=1; else if (k=="inject") ij[n"|"$2]=1
} END { for (k in pg) if (k in ij) { split(k,a,"|"); print a[1] } }' \
  "${XDG_STATE_HOME:-$HOME/.local/state}/claude-code/instructions.log" | sort | uniq -c
```

Only three rules collide, and `claude-files` carries nearly all of it.
`secrets` and `pdf` collide in a handful of sessions and stay as they are: their hook branches carry the `ask` and the `deny` that no `paths:` glob can express, and `pdf.md`'s own `deny` pre-empts most of the native `Read` that would match its glob.
The rules carrying a real glob and no hook trigger (`code`, `css`, `lua`, `python`, `quarto`, `r`, `rust`, `shell`, `skill`, `sql`, `typst`) never collide, so the test closes on them with no change.

**Rejected.**

- **`instructions-log.sh` seals the hook's session marker**, so `inject-rules.sh` skips what the shipped mechanism already delivered. It keeps both triggers and removes most of the duplication, but it couples two hooks through a file, needs its own tests, and leaves the inject-first order duplicating anyway. More machinery for a worse result.
- **Dropping `want claude-files` and keeping the real globs.** Ruled out by the 2026-09-26 measurement above: a `Write` of a new note would load nothing.
- **Doing nothing.** The duplicate costs the file's whole body twice in the majority of sessions; re-derive the body size with `awk 'NR==1&&/^---$/{fm=1;next} fm&&/^---$/{fm=0;next} !fm' claude/.claude/rules/claude-files.md | wc -c`.

**Weakest assumption, cleared at the build on 2026-11-06.** That the rewritten frontmatter parses. A malformed `paths:` block makes the rule load unconditionally with no error, which a `claude -p` run started after the edit settles: its session wrote one `session_start` row, for `~/.claude/CLAUDE.md`, and none for the rule. Re-derive by filtering `instructions.log` on the session id of any later run.

**Qualification.** Claude-specific on both sides, and the change moves the rule off the layer with equivalents in Cursor, Windsurf, Devin and Copilot onto the hook layer, which has none. A step against `PLAN-AGENT-AGNOSTIC.md`, taken for the token saving and recorded as such.

### The `PLAN.md` mandate stays and the plan file gets a growth cap, against the reco's verdict

**Decision.** `inject-project-context.sh` keeps its startup and `compact` instructions unchanged.
A deny in the `Edit | Write | MultiEdit` branch of `inject-rules.sh`, on the `index_line_cap` precedent of "The store admits a note only when no mechanism already produces the behaviour, and the guard counts index lines" above, refuses a write to `*/.claude/PLAN.md` or `*/PLAN.md` that would take an over-cap file further over it; a write that shrinks the file passes.
Cap: 20,000 bytes, set by the user on 2026-11-06, raising it a recorded decision as `instructions-budget` already requires for the always-loaded set.

**Why the mandate is not the defect.** Re-derive which projects the instruction reaches, and at what size, with
`find ~ -maxdepth 5 \( -path '*/.claude/PLAN.md' -o -path '*/PLAN.md' \) -not -path '*/.git/*' -not -path ~/.claude/'*' -exec wc -c {} +`.
The cost is concentrated in one file rather than spread over the mechanism, and `~/dotfiles` is not even subject to the instruction: `inject-project-context.sh` tests `.claude/PLAN.md` then `PLAN.md`, and this repository's plans are all `PLAN-<TOPIC>.md`, so the chantier that produced the reco never saw its own recommendation fire.
Leading the remedy with size is what the reco's own section "The size axis and the accuracy axis call for different moves" forbids, and its "Subtractive criterion" verdict asks for a gate rather than a deletion.

**Measured 2026-11-06, kept as a dated figure because transcripts are pruned.** In `~/Documents/packages/quarto-hebstr-doc`, the only project whose transcripts still held the span, 8 of 9 sessions received the mandate and 7 of 9 read the plan. The mandate is followed.

**Why 20,000 bytes.** It is the one anchored number available: the `context-window` page states that after compaction a file over 5,000 tokens comes back as a path reference without its content, so a plan past that point makes the hook's `compact` branch pay a full re-read for the rest of the session's life.
This is the current-intent rule of the reco's section "The plan-versus-design split" in executable form, OpenSpec's `archive` applied to a plan file.

**Rejected.**

- **Dropping the mandate**, which is the reco's own verdict and rests on field practice rather than on anything measured here. It removes a followed mechanism to fix one file, and leaves nothing reorienting a session on a long-running chantier.
- **Injecting one named section.** Blocked by the absence of a convention to key on: the plans reached by the instruction use six heading vocabularies across two languages (`## Objectif`, `## Objective`, `## État actuel`, `## Current step`, `## Current objective`, `## Contexte`), so the extraction would have to impose a heading convention on thirteen repositories first, and a missing heading fails silently.
- **A generated digest.** Needs a loud staleness failure, which is `cog` with `--check` or an equivalent, and installing one is a `/poc` the reco keeps separate.
- **Gating the mandate on the plan's size**, the hook asking for the read only under a generated threshold. It degrades silently: past the threshold the instruction stops without saying so, which inverts the reco's single predictor of a routine surviving.

**Weakest assumption, untested.** That the three plans currently over the cap can be brought under it by splitting rather than by losing record. Testing it means doing the splits, which is a `/prune`. If it fails, the number is wrong and not the mechanism.

**Qualification.** Claude-specific, like the mandate it protects; the opencode bridge forwards neither `inject-project-context.sh` nor `inject-rules.sh`.

### The stale-figure gate is a `prose-lint` rule on the copula form, not a ban on the shape

**Decision.** A `[live-count]` rule in `bin/.local/bin/prose-lint`, at error level, matching a copula or possession verb immediately followed by a cardinal number and a plural artefact noun, exempting a line that carries an ISO date and a line carrying the `<!-- prose-lint:ignore -->` marker.
It reports only on lines a write adds, and its scope is the agent-facing trees that the dash rules exempt, so `prose-lint` carries two rule families with two scopes.
Delivery is the existing `prose-lint-pretool.sh` at write time and the existing `prose-lint` entry of `prek.toml` at commit time.

**Why that home.** `prose-lint-pretool.sh` already reconstructs the post-edit file so fence and display-math context survive, already strips inline code, already owns the ignore marker, and already turns a violation into a refused write; and the opencode plugin `claude-hooks.ts` forwards it and translates its exit 2 into a blocked edit, so the one capability the reco keeps vendor-locked arrives on a portable instrument.
`refs-lint.py` has the right scope and is invoked by hand, which is the prune-time firing the defect is defined against.

**Why the shape ban narrows.** Re-derive with the two patterns over `.claude/*.md` and `_meta/notes/*.md`, under `prose-lint`'s own skips plus an ISO-date exemption.
The broad form, a cardinal number followed by a plural artefact noun, flags a large part of the corpus and is dominated by published ceilings, prune deltas and sourced external facts: at error level it would refuse every edit to most files of the corpus, which is how a gate gets turned off.
The copula-anchored form flags a handful, most of them the target shape.
So the reco's premise that "a regex decides trivially whether a sentence asserts a repository count at all" does not survive re-derivation at useful recall: what is decidable is the copula form, and the appositive form (`30 files, 786 tests`) escapes entirely.
This gate removes the next occurrence of one phrasing, not the class, and it is approved on that basis.

**The defect the gate has already caught, dated 2026-11-06 because a fix destroys the evidence.** The "Open" block of `PRUNE-OBSERVATIONS.md` states in the present tense that `eds-prise`'s `PLAN.md` is 666 lines and 151 KB; it was 1,105 lines and 252,301 bytes that day.
No mechanism in force saw it, because `agents/verifier.md` section 3 re-derives counts only for the tracking files of a session's `WRITES`, and the file was not in one when the other repository's plan grew.
That is the gate's consumer, and the premise test passes on it.

**Rejected.**

- **The broad pattern**, which is what the reco proposed. Rejected on the measurement above, which reproduces the false-positive rate that killed the truth-adjudicating detector.
- **A deny in `inject-rules.sh`.** It would duplicate the file reconstruction and the fence parsing of `prose-lint-pretool.sh`, and the opencode bridge does not forward that hook, so the rule would be Claude-only.
- **A Vale `existence` check.** One more dependency and one more config tree for the same precision ceiling, and trialling it is a `/poc`.
- **Nothing, on the ground that the commit gate covers it.** `agents/verifier.md` section 2 grep 1 and section 3 do re-derive counts, but only inside `WRITES`, and they are agent judgment rather than a mechanism.

**Weakest assumption, tested on the live corpus on 2026-11-06.** That a line-scoped pattern equals a sentence-scoped one, which holds only because the no-soft-wrap convention puts one sentence on one line. A soft-wrapped file degrades the rule to noise on that file.

**Qualification.** Portable instrument in `bin/`, run by `prek` at commit, with the Claude-specific `PreToolUse` wrapper for write-time firing, already mirrored for opencode.

### Open

- The recall of the `[live-count]` rule is not measured, only bounded below by the copula form. Whether the appositive form ever warrants a second pattern waits on an occurrence the gate misses.
- Whether the 20,000-byte plan cap holds, or the three over-cap plans prove it wrong by being unsplittable without losing record.
- The reco's figure "40,000 characters per on-demand file" was checked on 2026-11-06 against the vendor's own `code.claude.com/docs/en/memory`, under its heading about Claude ignoring the end of a subdirectory `CLAUDE.md` (an external anchor, so `refs-lint.py` reports it dangling by design): the limit applies to path-scoped rules, a subdirectory `CLAUDE.md` or `CLAUDE.local.md`, and their `@path` imports, and not to any file read with the Read tool. It therefore binds every file of `claude/.claude/rules/` and binds no `PLAN.md`. No rules file is near it; re-derive with `wc -m claude/.claude/rules/*.md`.

## Open

- Whether user-level `paths:` globs match files outside the project directory (`~/.claude/memory/*.md` read from another project).
  The log settles it.
- The grep/find hook stays deferred past step 4 ("Shell search toward a hook" in `PLAN-SESSION-DISCIPLINE.md`); its bullet stays in the root.
