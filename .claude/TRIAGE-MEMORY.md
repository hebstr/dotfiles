# TRIAGE-MEMORY.md

Eight memory passes applied, each under its own heading below, from the triage of 2026-09-22 over the 114 files of `~/.claude/memory/`, framed in `PLAN-SESSION-DISCIPLINE.md` § "Third pass", to the merge of 2026-11-08. The first three were the triage, the sweep of 2026-10-09 under the admission criterion and the harness's legacy stores on 2026-10-13; the ceiling re-set of 2026-10-23 sits between the fifth and the sixth and is not a pass.
The canonical store is versioned in `dotfiles`, its file count re-derived with `git ls-files claude/.claude/memory` rather than read here, so what the first two passes removed is read back in its history, `ee86678`, `1517137`, `653dc17` and `1464c2c` for 2026-09-22: that is what allows pruning their verdict tables. The fifth pass's legacy stores were not versioned, and the pre-pass tarball sat in a dead session scratchpad, so its "Superseded" and "Obsolete" tables are the only state of what the 31 deleted files held.
Four headings are cited from outside the note, so renaming one repoints its citers in the same edit, the map re-derived 2026-11-06: "A non-parsing frontmatter costs nothing while the native recall stays off" (the memory-pass bullet of `PLAN-SESSION-DISCIPLINE.md` § "Open points", and `rules/memory.md` § "One store" for the file rather than the heading), "Index lines too long" (`rules/memory.md` § "One store", `DESIGN-INSTRUCTION-ROUTING.md`, and the memory-triage status paragraph of `PLAN-SESSION-DISCIPLINE.md`), "Body prunes of the third pass" (the open-task bullet of `PLAN-SESSION-DISCIPLINE.md`) and "Fourth pass: the sweep under the admission criterion" (`DESIGN-INSTRUCTION-ROUTING.md`, `PLAN-SESSION-DISCIPLINE.md` and `PRUNE-OBSERVATIONS.md`).

## Deletions: ten files go

Applied on 2026-09-22 on the user's validation: the ten files, their coverage evidence and the repointed links are in `ee86678`.
The two merges came before the deletion: the third-party scope became a bullet of `feedback_prose-lint-write.md` § "Scope", the threat model the "Threat model on the multi-user servers" paragraph of `feedback_review_severity_shell_installers.md`, each time without the "likely HPC" and without the advice to pin the installer's URL, advice that `rv-update` contradicts: neither is to be reintroduced.
The check as it then stood excluded the files git ignores, which `feedback_rg_misses_gitignored_trackers` now holds.
The R-hebstr CI item, the one live remainder of `project_review_workflow_backlog.md`, was carried over nowhere.

## Fact corrections

Applied on 2026-09-22, every fact re-verified against the evidence before the Edit: thirty corrections, in `ee86678` and `1517137` and in the memories themselves, several of which the fourth pass took up again (`feedback_r_environment` in particular, whose `.rv$sync()` state was wrong on both sides).
Two decisions outlive the table:

- `..._shell_installers` keeps its hooks section, which does not move to `..._claude_config`: both files are selected on the same hooks path, and another session was writing there the same day. Its `set -euo pipefail` exclusion is narrowed to the context injectors.
- `..._hebstr` keeps its two dead citations named (`PLAN-cran-globalenv.md`, `PROMPT-CONTINUE.md`), with the mention that they no longer exist, in order to keep the source of the author's decision. This is the decision on which the fourth pass refuses a cut, § "Batch 3".

## Body prunes of the third pass

Four large files rewritten on 2026-09-22, each validated on its own diff, from 77, 35, 32 and 22 KB to about 15, 6, 9 and 3 KB, then a batch of medium and small ones validated on the overall diff; the cuts, the sizes and the pre-rewrite checks are in `653dc17` and `1464c2c`.
What is left of it and does not re-derive from the diff:

- Sixteen frontmatters were invalid YAML (a `: ` in an unquoted value, five of them written by this pass): all quoted on 2026-09-22, `yaml.safe_load` then passing on the 104 files. The fix did not hold, eight frontmatters refusing it again at the sweep of 2026-10-09, the same eight before and after: the quoting is worth a mechanism rather than a pass.
- The dash typology is unified in `feedback_prose-lint-write` (question 1), and `feedback_no_bulk_regex_for_contextual_skills` points at it.
- The operator traps taken out of `..._edscrib` are deleted and not carried over (question 4). The Ouroboros sections that went into `feedback_ouroboros_tools`, such as the conflict between an artifact drawn from the real content and prose that passes, died with that file, deleted on 2026-10-08 with the plugin.
- The "personal scripts" rule moved into `..._shell_installers` without `~/scripts/`, which does not exist.

## Index lines too long

**Cap in force since 2026-10-04: 130 bytes per whole line, including the `- <file>.md: ` prefix.**
That is where the harness's two caps meet (200 lines at 130 bytes make about 26,000 against a 25,000-byte cap): below it, lines stay unused; above it, the byte cap bites with half the lines still free.
It replaces the 200-character threshold on the description alone, set on 2026-09-22, which the lines' drift carried to 98 % of the byte cap.

Each line is derived from the target file's frontmatter `description`, never from the index line in place, which is the thing that drifts.
The frontmatter keeps the long form for whoever opens the file: shortening the index removes a duplicate, not a piece of information. What reads that long form today is a reader rather than a selector, the native recall being gated off on this account, which "A non-parsing frontmatter costs nothing while the native recall stays off" below settles with what would change if the flag turned on.
Two standing refusals: do not merge the `feedback_review_severity_*` entries as a family, whose recall is by target and where a merged file would load every calibration at every review (19 when this was written, 21 on 2026-11-08, and the count is not what grounds the refusal); do not raise `--index-bytes` or `--index-lines` of `instructions-budget`, which change only what the check reports, the 25,000 and the 200 belonging to the harness.

Pass of 2026-10-04: the 124 lines rewritten, the index from 24,470 to 14,839 bytes over 133 lines, without touching a memory file or a frontmatter.

## Questions to the user

The four closed on 2026-09-22, each pointing at its current holder.

1. A dash in a table cell that holds a sentence is prose; only a label cell (`| /flag — what it does |`) stays typographic. Held by `feedback_prose-lint-write`.
2. `pro-ordo` is a local unversioned sandbox: the filled-in parameters are not an established fact, `ordo.qmd` stays as it is, and `project_ordo_typst_template` holds the fact. The project's `.claude/DESIGN.md` still says `mssante` instead of `email`, outside the store, left as it is.
3. The multi-user context holds: the "Threat model on the multi-user servers" paragraph of `feedback_review_severity_shell_installers.md` is kept as it is.
4. The operator content taken out of `..._edscrib` is deleted, not carried over.

## Outside memory, noted in passing

- `claude-code-plugins/.claude/DEFERRED.md` said on 2026-10-13, of the per-bucket rates of the blindspot pass of 2026-09-20, that they « restent dans `feedback_audit_walkthrough.md`, qui les porte seul ».
  That memory keeps only one (11 of 11, 2026-09-20) and makes it a rule never to cite a bucket's rate without saying what the judge was seeing, so the pointer is false, in another repository: left to the user, noted again on 2026-10-13.
- The scope filter of `orchestrator.md` reads the description of the 19 `review_severity` files at every walkthrough, whatever the target: that is the ground of the refusal to merge them above, and § "Batch 3" measures it.

# Fourth pass: the sweep under the admission criterion (2026-10-09)

Step two of the pass framed in `DESIGN-INSTRUCTION-ROUTING.md` § "The store admits a note only when no mechanism already produces the behaviour, and the guard counts index lines", run with the machinery of "Third pass" in `PLAN-SESSION-DISCIPLINE.md`: four read-only subagents on `sonnet`, one per family, every file read in full.

**Step 1 of the admission test admitted all 129 files, so the sweep proposed no deletion**, and the store left it one entry down only because of the single approved merge.
Pruning a body never changes the dimension the ceiling counts, so a ceiling re-set can draw on no pruning dividend.
This is a fact the framing of 2026-10-06 did not have, and it bears on the margin: the deny message tells a session to prune before adding, and this pass establishes that the entry dimension has nothing to give.

## Batch 1: facts verified false today

Applied on 2026-10-09, 20 corrections over 17 files, 22 lines replaced, `refs-lint.py` clean on each: every corrected text is in the memory it belongs to and in that day's commit.
Two of the twenty left something the correction itself does not carry.
A memory that pins a tool version dates its measurement instead (the arity verdict, since merged into `project_closed_tool_evaluations`, read air 0.11.0 against the 0.12.0 installed, `jarl` and `arity` unchanged), and `..._hebstr`'s "decision D, permet des profils" was never located, so it stays unverified rather than corrected.

## Batch 2: body prunes outside the severity family

**Applied on 2026-10-09**, 27 of the 29 files, each row having named the passage and the holder that establishes it better, per `rules/claude-files.md` § "Content"; the cut text and its holder are in that day's commit.

Three memories were kept against their own citers: `skills/commit/SKILL.md` cites `feedback_commit_sequence_add_all`, `rules/claude-files.md` § Form cites `feedback_line_number_cross_refs` and `rules/code.md` cites `feedback_verify_before_claiming`, each for a detail the memory alone holds, so a pointer in a citer constrains the cited memory exactly as a quoted title does.
Four passages stayed for having no holder at all: the prek stash trap of `reference_git_html_id_filter`, still absent from `_meta/notes/git-html-id-filter.md` on 2026-10-13; the Lit, SglQuoted, heredoc and brace facts of `reference_shfmt_ast_divergences`, the WHY `git-write-guard.jq` cannot carry; the 30-run measurement and the self-matching-glob fact of `reference_claude_code_best_practices`; the `pyvenv.cfg` against `readlink -f` tip of `reference_tool_update_routines`.
One cut was a contradiction rather than a duplicate: `feedback_browser_layout_probe` had Firefox hanging until timeout where `rules/chromium.md` gives `unshare(CLONE_NEWPID): EPERM` misreported as "already running", and the memory now defers to the rule.

Two cuts refused.

- **The md-nesrine re-assert workaround of `project_md_nesrine_render_pitfalls` pitfall 1.** It is resolved at the root in md-nesrine alone, and the same note establishes that the pitfall still bites the siblings: 10 of the 15 `.Rprofile` under `~/Documents` still call `conflicts_prefer` on 2026-10-09.
  Cutting the remedy would leave the diagnosis without a remedy for them.
- **The V8 and `libnode.so.109` paragraph of `reference_gt_reactable_css_theming`.** It is phrased conditionally ("on a machine whose V8 build wants a missing `libnode.so.109`"), so it is a correct conditional fact rather than a stale claim about this machine, and it costs two lines.

One conflict with a verification recorded on 2026-09-22, settled on the current state: the `git check-ignore` half of `feedback_commit_sequence_add_all` was kept then for want of a holder, and `skills/commit/SKILL.md` § "1. Read the actual state" carries it now, so the cut went through.

## Batch 3: the severity family, its own batch

The scope filter, established from `orchestrator.md` § "Load target project memories": at every walkthrough the `name` and `description` of each of the 19 are read, and the body only if the description names the target's project, names an artifact kind present in the target, or names neither.
Calibration is injected into the reviewer prompt only for `code`-category reviewers; for a `skill-tool` reviewer the loaded block acts through Step 2b of the walkthrough skill alone.
No step-1 deletion was found: the walkthrough runs from its own cwd, so the reviewer never auto-loads the target project's `CLAUDE.md`, which is why the hebstr, edstr and eds-\* calibrations are not covered by those projects' own rules.

**Applied on 2026-10-09**, 17 of the 19 files, the family going from 159,906 to 151,849 bytes, `refs-lint.py` clean on each: what went was the per-walkthrough tallies, the retired items, the dated "Why" paragraphs and the finding ids, each in that day's commit.
`..._md_nesrine` and `..._profiles_scaffolds` were kept as they are, the second having only a "12 findings, 5 rejected" count not worth a pass.
What stayed for having no holder, and what a later pass meets again: the measured mutants of `..._bats_tests` (`STUB_LOCKED`, the `reco-relance` `strings`, the `GATE_DIR` inversion), item 6's 24 of 27 install triggers found only inside quotes in `..._claude_config`, the probe numbers of patterns 13, 15 and 16 of `..._claude_rules`, the guard-preservation lines of `..._eds_avc` on a project that forbids comments in code, the measurement traps and the gt `tab_style` measurement of `..._eds_prise`, the "Standing rejections", "What to keep flagging" and "Facts established" blocks of `..._edscrib`, the policy and the CRAN, `Suggests` and CI rules of `..._edstr`, and the `car::Anova` quasi-family and `nullfile()` facts of `..._stat_reports_fr`.

**Four cuts the sorting agent proposed and this pass refused, with the ground.**

- **Every "(`<script>` walkthrough, `<date>`)" provenance tag of `..._shell_installers`**, about twenty of them.
  They are the only trace of which pass established each dismissal, which is what lets a later reviewer judge whether the dismissal still applies, and `rules/claude-files.md` § "Content" protects walkthrough blocks.
  Cutting them is the largest single saving in the family and also the one with no holder.
- **Compressing the `commit-stale.sh` seal and carry pair of `..._shell_installers` to one line.** The second bullet carries a measurement no copy holds: all four truncation shapes traced on the read side, each falling back to `changed` or `unsealed` rather than to silence, so the direction of the degradation is itself the guard.
- **The "Method that settled points on this target" bullets of `..._edscrib`**, called generic repeats of the probe-discipline memories.
  They are not: the `filelock` floor sweep, the vendored Streamlit bundle decode, MS-OI29500 18.3.1.13, the `unresolved` guard and `load_frames`, the `{user}` placeholder walk are all specific to this target.
- **The generic "Lessons beyond the patterns" bullets of `..._skill_audits`**, called walkthrough procedure held by `feedback_audit_walkthrough`.
  That file does not hold them.
  Only the "run the walkthrough's final evaluate" bullet was cut, as moot: the Step 3 evaluate went with Ouroboros on 2026-10-08.

**One cut refused on a standing decision.** `..._hebstr` item 1's pointer to `PLAN-cran-globalenv.md` and `PROMPT-CONTINUE.md` stays: "Fact corrections" above records the user's decision of 2026-09-22 to keep both dead citations named, with the mention that they no longer exist, in order to keep the source of the author's decision.

Numbered patterns retired in `..._claude_config` (item 3) and `..._claude_rules` (items 6 and 14) were compressed to one line each rather than deleted, their numbers kept: deleting them renumbers the list and silently breaks every reference to a later pattern, which is the hazard `refs-lint.py` reports as an enumeration reference.

## Batch 4: index lines and frontmatter descriptions

Ten index lines and frontmatter descriptions rewritten downstream of batches 1 to 3, `MEMORY.md` and the frontmatters holding the applied text.
Three things the applied text does not carry.
The five severity descriptions that state a count or an enumeration of the body are the ones the scope filter reads at every walkthrough, so they drift whenever the body is pruned, which is what batches 2 and 3 forced here.
`..._stat_reports_fr` names `md-nesrine` because an R-only md-nesrine target would otherwise skip the file.
One line measured 131 bytes at the write against the 130-byte cap and was re-shortened, so the cap is checked on the composed line rather than on the description.

## Merges

- **Applied: `reference_hebstr_gt_table_width` into `reference_table_column_width_layout`**, about 9.6 KB, one trigger (a gt or flextable table's width across HTML, PNG and Word) and the only change the sweep made to the entry count.
- **Applied 2026-10-19, the ceiling having bound: `..._md_nesrine` into `..._stat_reports_fr`.** The only pair of the 19 aimed at one project, so the standing same-project rule admits it.
  It was held back as available and not recommended, the gain being one index line against a recall aimed at md-nesrine loading the merged file where 1.9 KB loaded before.
  What made it the move rather than a sweep: the index reached 151 lines against the ceiling of 150 when a memory note was added that day, and batch 4 had already made `stat_reports_fr`'s description name md-nesrine, so the second cost the hold-back named was paid before the merge.
  The two journal rules, the hash measurement and the `[[feedback_review_severity_personal]]` link were carried over byte-identical; the index went back to 150 lines, at the ceiling of that day.
  The next note added, on 2026-10-22, took the ceiling re-set recorded at the end of this file rather than that sweep, which stays owed.
- Refused on their triggers: the two dbplyr notes, the two pkgdown notes, the three Quarto notes (crossref, include, outside-render-list), the Zotero cluster, and `reference_flextable_grouped_rows` against the width pair.
  Each pair's symptoms would not be recalled by one description.

## Keep an index line, do not delete

The weakest assumption of "Third pass" bites on two files.

- `feedback_r_environment`: `rules/r.md` carries "Never use `renv`; `rv` replaces it" under `paths: **/*.R`, so a package-management discussion or an `rv add` from Bash escapes it.
- `project_shellharden_dotfiles_normalized`: `format-on-edit.sh` runs `shellharden --replace` on every `*.sh` edit, but the extensionless `bash/` dotfiles miss that case, and the "do not raise it as a finding" half serves review judgment, which fires on no edit.

## Out of memory, found by this pass

- **Withdrawn on 2026-10-09, and not to be re-flagged:** the `Supported: 0` of `_meta/notes/ubuntu-26-04-migration-reco.md`, filed as stale by the sorting agent and again by the commit verifier.
  It sits inside `## État au 2026-09-09`, a dated snapshot that "Form" of `rules/claude-files.md` protects as record, and the note's one live mention, criterion 1 of `## Décision`, states the condition to meet (`Supported: 1`) rather than the current state, so it is not false either; the live fact that the flag has fired is carried by `project_ubuntu_26_04_migration`.
- `rules/quarto.md` § "What panache damages" says "verified against panache 3.0.2"; the installed version is 3.14.0 and two of its defects re-reproduced today, so the facts hold and the version label is stale.
- `_meta/notes/pandoc-upgrade.md` documents a system pandoc installed by `.deb`; that package is purged and `rules/r.md` records the single-pandoc decision.
- `_meta/notes/git-html-id-filter.md` lacks the prek stash trap that only the memory holds.
- `audit/walkthrough/agents/ouroboros-bridge.md` is absent from the three current cache snapshots and present in three stale ones, which is the stacking `reference_claude_code_marketplace_mechanics` warns about.
- `claude/.claude/settings.json` keeps `litrev@litrev` at `false` while `~/.claude/plugins/cache/litrev/` still holds a snapshot.
- The merge's six dangling pointers in `eds-prise/.claude/` were the pass's one open debt and are **closed**: measured 2026-10-13, no file there names `reference_hebstr_gt_table_width` any more and `reference_table_column_width_layout` is cited once in `DESIGN-TABLES-HTML.md`, four times in `DESIGN-DOCX.md` and once in `DESIGN-CALENDRIER.md`, repaired by that project's own session as the handover asked.

## Not settled by this pass

Claims the sweep could not verify, left as they stand rather than ruled on: the ju-TP2 Windows state (the host does not resolve here), Zotero and BBT behaviours measured on 10.0.3 and 9.0.64 against 10.0.6 and 9.0.68 installed, the SNDS documentation site, the Opus `cyber` classifier cut, Quarto render-time behaviours measured on 1.10.18 against 1.10.19 installed, the Streamlit DOM and Styler facts measured on 1.60.0 against 1.63.0 installed, the harness internals read in 2.1.283 against 2.1.295 installed, the upstream readings of gortex and arity, and the cross-model consensus counts of past review sessions, which no artifact holds.
`reference_nanoparquet_col_select` did not reproduce on two synthetic files at 0.5.1, which refutes nothing: the real file shape may be load-bearing.

## What the pass left, measured 2026-10-09 at closure

129 files to 128, the one fewer being the merge and no note deleted on the criterion; 557,814 body bytes to 535,245; the index 138 lines and 15,441 bytes to 137 and 15,306; the severity family 159,906 bytes to 151,849 over its 19 files; and the same eight frontmatters `yaml.safe_load` refuses, before and after.

**The ceiling needs no edit**, 150 against the 137 the pass left being a margin of 13, since narrowed to 12 by the fifth pass and to 11 by the memory added on 2026-10-13, `instructions-budget` reading 139 index lines for 130 files.
**Four sites hard-code that number, not two**, contrary to the framing of this pass's prompt: `index_line_cap` in `inject-rules.sh`, the `--index-lines` arg in `prek.toml`, and two `inject-rules.bats` cases, "denies a new memory file once the index is over the line ceiling" and "leaves the prune path open over the ceiling, and passes at it", which carry an over-the-ceiling fixture and an at-the-ceiling one between them (161 and 160 since the re-set of 2026-10-23). A re-set touches all four.

# Fifth pass: the legacy harness stores (2026-10-13)

Steps 1 and 2 of the `DEFERRED.md` row dated 2026-06-02, both run that day, the row deleted with them: this section is what remains of it, and it is the single holder of lot C.
Scope: the 46 non-index memory files under the 13 `~/.claude/projects/*/memory/` directories, each read in full and judged against the canonical store, the rules files, the skills and the live code; the 13 `MEMORY.md` indexes and the stub at `~/.claude/projects/-home-julien/MEMORY.md` were outside the count.
Lots A and B were applied on the user's validation the same day, below, and lot C is the one part still open.

## What the whole lot rests on

**Ten of the thirteen project keys no longer resolve to any directory.** `~/Documents/pro/` does not exist: the tree is `~/Documents/{des,m2,packages,sandbox,services}`, so the eight keys under `-home-julien-Documents-pro-` can never be a session cwd again, and `~/.claude/plugins/marketplaces/litrev` and `~/.claude/skills/bookmarks-manager` are both gone.
Only `~/.claude`, `~/.claude/skills/ref` and `~/dotfiles` still resolve, and every project these stores describe moved, most restructured with the move.

**A migration lands as an append into an already-indexed file**, which is what kept the whole lot inside a 12-line index budget: the operative ceiling is `index_line_cap` in `inject-rules.sh` rather than the harness's 200, and its deny fires only on the creation of a file the index does not list, so editing an existing memory is unaffected and no verdict proposed a new memory file.

## Superseded, 15 files

The carrier is named per file because these stores were unversioned and nothing else records what the fifteen held.

```
| file | store | carrier |
|---|---|---|
| feedback_always_update_memory | litrev-mkt | `CLAUDE.md` § "Plans and tracking", its two bullets |
| feedback_checkup_before_done | litrev-mkt | `CLAUDE.md`'s "Before marking a step done", same four probes |
| feedback_litrev_extraction_patterns | litrev-mkt | 8 of its 11 patterns encoded in the litrev agents and skills; three residuals migrated |
| feedback_s2_api_key_detection | litrev-mkt | `litrev-search/SKILL.md` Step 0, verbatim, plus a second STOP at the S2 call |
| project_mcp_path_resolution | litrev-mkt | `claude-code-litrev/.claude/BUGS_FROM_PRISE.md` B2, open, with its three fix options |
| project_roadmap_sources | litrev-mkt | `claude-code-litrev/.claude/PLAN.md`, its tracking-file list |
| project_search_api_limitations | litrev-mkt | `litrev-search/references/database_strategies.md`, mechanism and figures |
| feedback_ref_invocation_form | skills-ref | `ref/SKILL.md` § Invocation |
| feedback_ref_naming_convention | skills-ref | `ref/SKILL.md` and `catalog.md`, both § "Naming convention" |
| feedback_ref_skill_yaml_header | skills-ref | the `sources:` schema of `ref/update.md`, required by `catalog.md` step 2 |
| feedback_ref_skill_scope | skills-ref | `catalog.md` § "Out of scope (covered elsewhere, do not add)" and its step 5 |
| feedback_verify_github_handles | skills-ref | `feedback_verify_before_claiming` rules 5 and 7, plus `CLAUDE.md`'s URL bullet |
| user_profile | eds-avc | the canonical `user_profile` and `CLAUDE.md` § Profile |
| mcp-config-conventions | cc-litrev | `claude-code-litrev/README.md` for conventions 1 and 2; convention 3 is below |
| feedback_code_text_english | R-edstr | `rules/code.md` § "Comments and code text" and `CLAUDE.md` § Communication |
```

Three carrier claims are judgements a later reader can reopen, so they stay stated.
`feedback_always_update_memory` lost its MCP-tool-count checklist as instance-specific, its number being wrong too (12 against the 16 `@mcp.tool` of `server.py`), and its compaction clause is harness-owned now.
`feedback_verify_github_handles` lost its named-handle incident as an example rather than a rule.
`user_profile` was the only name collision of the 46, and every divergence of the legacy copy was stale: `rig` with R 4.5.3/4.6.0 against the rv idioms of `feedback_r_environment`, `langchain + ollama` against the llama-server and Qwen3.6 stack of `pred/avc_pred_output.sh`.
Two memories were themselves wrong where the carrier is right: the mitigation of `project_mcp_path_resolution` is `LITREV_REVIEW_DIR` (`review_dir()` in `lib/http.py`) and not the absolute paths it asked callers for, and `mcp-config-conventions` was stale on distribution and broke the store's `<category>_<slug>.md` naming.

## Obsolete, 16 files

Nothing carries the content and nothing should: the fact stopped being true, or its subject is gone.

```
| file | store | why |
|---|---|---|
| feedback_review_severity | ~/.claude | all four carve-outs lost their subject; the scope is held by `feedback_review_severity_claude_config` |
| project_custom_commands | ~/.claude | the empty `~/.claude/commands/` it waited on exists nowhere; skills answered the need |
| feedback_no_git_writes | litrev-mkt | reversed by the `commit` skill and `git-write-guard.sh` |
| feedback_pipeline_audit_method | litrev-mkt | two of the three review skills it sequences are gone; its A1-A4 split offered to the repo |
| project_example4_triage | litrev-mkt | `workspace/example-4` gone, its six bugs resolved, its reference artifacts absent |
| project_mcp_s2_env | litrev-mkt | a "fixed 2026-04-02" record whose fix is in the code and in `litrev-search/SKILL.md` |
| project_overview | litrev-mkt | every count and phase drifted; `.claude/PLAN.md` and `README.md` carry the live version |
| project_plugin_conversion | litrev-mkt | the plugin moved again; its one live item, the memory migration P5, is this pass |
| project_skill_review_pass | litrev-mkt | a status record closed 2026-03-31; its F24-F27 pointer is `PLAN.md` steps 8 and 9 |
| feedback_review_severity | bookmarks | the skill is gone from `~/.claude/skills/` and from the dotfiles tree |
| feedback_r_skills | eds-avc | `/r-skills:code-review` does not exist; the gate plus `feedback_load_matching_skill` generalise it |
| project_fixtures | eds-avc | `collect/fixtures/` and its injection target are gone; its one live fact is in `.Rprofile` |
| project_quarto_book | eds-avc | `_quarto.yml` is the live state; `.claude/DEFERRED.md` note 4 carries the reactivation debt |
| project_streamlit_merge | eds-avc | finished: the app is a 6-line shim onto `edscrib` and its open question is answered |
| rprofile_config | eds-avc | every stated fact moved or reversed |
| feedback_review_severity | m2-dm3 | the bootstrap installer it calibrates has no target left in `~/Documents/m2/m2-dm3` |
```

Two of the sixteen are a reversal rather than a disappearance, which is what a later reader would reopen.
The `~/.claude` calibration advised preferring a model alias where `settings.json` now pins `"model": "claude-opus-5"`.
`rprofile_config` warned about a Positron trap that `_meta/profiles/Rprofile.site` defuses by setting `repos` itself, against the central claim of the file, and its env-var half moved to `_variables.yml`.

## Unmigrated, 15 files

Nothing else carried these and the fact was still worth keeping.
Eight of the fifteen were migrated the same day into the store, a rules file or a skill file, each as an append into an already-indexed file, so that lot cost no index line; `project_targets` and the transcribe calibration were closed by the user's decision, below.
**The five rows left are lot C, which this file alone holds**: four destined for `eds-avc/.claude/` and one for `claude-code-litrev/.claude/`, each subject to be re-verified against the code at the Edit.

```
| file | store | what is left, and where it goes |
|---|---|---|
| project_mcpb_packaging | litrev-mkt | `mcpb` and `build-mcpb` appear nowhere in the repo; its only packaging row is `PLAN.md` P6 (PyPI, blocked on naming). A backlog item, so a row in `claude-code-litrev/.claude/DEFERRED.md`, not a memory |
| feedback_quarto_authoring | eds-avc | the skill-first half is superseded by `rules/quarto.md` ("Do not reconstruct Quarto feature syntax from memory") plus `feedback_load_matching_skill`. The residual is the project convention that a callout always carries a title, which `eds-avc/.claude/CLAUDE.md` does not state (grep for `callout` empty) and which `reference_technical_doc_pattern` prescribes only for the hebstr-doc technical-doc pattern. Goes to `eds-avc/.claude/CLAUDE.md` § Conventions |
| project_doc_scripts_issues | eds-avc | all three calls are still there and still undefined: `mkdir(` and two `diffr(` in `docs/scripts/_resultats_pred_prompt.R`, `ggcascade(` in `_resultats_pop.R`; hebstr's 77 exports include neither `mkdir` nor `ggcascade` and `cascade` matches nothing in the package; `auto_exec` is commented out in both `docs/chapters/_setup.qmd` and `docs/scripts/_setup.R`, so the latency holds. `.claude/DEFERRED.md` note 4 covers the same reactivation breakage but names a different blocker (two missing prompt directories) and not these three. Goes into that note 4 |
| project_oracle_zigzag | eds-avc | the topology is intact, split across `avc_collect_eds.R` and `avc_collect_cache.R`, and `name_tbl("DOC")` still yields the study's document table. The project's `CLAUDE.md` carries "Oracle CHU-only" and "DuckDB is the local analytical store" but no size or latency justification, and the push back to Oracle carries no written WHY anywhere. Migrate the rationale and the two standing refusals into `eds-avc/.claude/CLAUDE.md`, correcting the warehouse table name and dropping the absent `avc_query_parquet.R` |
| project_quarto_prerender | eds-avc | no `pre-render:` in `_quarto.yml` (grep count 0) and the wish is in no tracking file. The sibling `eds-prise` has `pre-render: prerender.R`, so the pattern now exists next door, un-ported. A row in `eds-avc/.claude/DEFERRED.md` citing that precedent |
```

Two rows were closed by the user rather than migrated, and neither is to be reopened.
`project_targets`: the migration was abandoned on 2026-10-13, nothing of the dossier surviving (`targets` absent from the default library and from `rv.lock`, no `_targets.R`, the `targets.md` design notes gone), so reopening it means redesigning it; the standing refusal landed as a bullet of `feedback_review_severity_eds_avc`.
The transcribe calibration was deleted on the recommendation that a review calibration is worth nothing when the review will not happen: the project is alive at `~/Documents/sandbox/transcribe` and all three of its rules keep their subject, but the dotfiles `transcribe` driver retired the prototype, so migrating it would have cost an index line for a review nobody will run.

## Applied on the user's validation, 2026-10-13

**41 files deleted and 8 migrated**, the migrations being appends into seven memories, a line each in `rules/r.md` and `rules/code.md` and a step in `ref/catalog.md` § "Adding a note", with three descriptions widened and one index line reworded; the index stayed at 138 lines, so the 12-line margin stands.
Every migrated subject was re-checked on disk at the Edit, and fourteen legacy items were dropped for having lost theirs, each named in the append that replaced it so a later reader does not re-derive it.
The legacy stores were unversioned and the pre-pass tarball of all 59 files sat in that session's scratchpad, since gone, which is why the two tables above are the only account left of the 31 deleted files.

**Five non-index files remain under the harness path, all of lot C**, in two directories, four under the eds-avc key and one under the litrev marketplace key.
The other 11 directories were emptied by the deletions and removed the same day on the user's instruction, each under a guard refusing any directory whose contents were not exactly `MEMORY.md`, which is what kept the two lot C stores.
**Only the `memory/` subdirectory went, never the project key above it**, which is the harness's own and holds the transcripts: all 17 keys are still there, as is the stub at `~/.claude/projects/-home-julien/MEMORY.md`, outside any `memory/` subdirectory and outside this triage from the start.
Reading one of these paths takes a `./` prefix, the leading dash of the keys making `find` and a bare glob read them as options.
When lot C closes, its two `memory/` directories go the same way, and nothing else is owed under that path.

**One residual left deliberately unwritten.** Convention 3 of `mcp-config-conventions`, that editing a plugin's `mcpServers` block needs a Claude Code restart, was not measurable in that session and is not written anywhere.
This paragraph is its only record.
Re-measure before asserting it, against the opposite finding for hooks in [[reference_claude_code_best_practices]].

## Step 2, applied the same day

Three edits removed the harness path from the guard: the `rules/memory.md` bullet that named it, the `"$HOME"/.claude/projects/*/memory/*` case of the `Edit | Write | MultiEdit` branch of `inject-rules.sh`, and the one `inject-rules.bats` case keyed on it.
A `Write` under the harness path now answers no decision and falls through to the `claude-files.md` injection, which is the intended end state, while a `Write` under `~/.claude/memory/` still answers `deny`: both were checked by calling the hook on a crafted payload rather than by reading it.

**Lot C is handed over through two prompt buffers, written the same day at the closure of this session.** `~/Documents/des/eds/eds-avc/.claude/PROMPT.md` carries its four items with their dated measurements, the destination of each, what is already settled and must not be reopened (the `targets` abandonment and the six facts deleted as obsolete), and the instruction to re-verify against the code before writing.
`~/Documents/packages/claude-code-litrev/.claude/PROMPT.md` carries its three, the `.mcpb` row plus the two guards that rule 8 of `feedback_litrev_pipeline_patterns` names, and two stale pointers found in that repository in passing (phase 9b of `litrev/SKILL.md` writing memory to a path that has never existed, and row F33 naming an absent `bibliography.py`).
Both were absent before being written, so no unconsumed prompt was overwritten, both are ignored by git in their own repository, and a prompt buffer is not a record, which is why this paragraph is the record.

**Four live-looking references were left alone on the criterion of `rules/claude-files.md` § Content**, which protects a record: the `### Where each block goes` routing table, the scoping paragraph of "The harness loads the memory index natively", `### Implementation (opened on 2026-09-27)` and `### Step 1 (2026-09-26)`, all four in `.claude/DESIGN-INSTRUCTION-ROUTING.md`, each an approved design or a dated implementation record.
Two of them carry a test count that was already stale before this pass, and a dated section keeps it.

# Ceiling re-set from 150 to 160 (2026-10-23)

The index reached 151 lines when `reference_duckdb_storage_version_split.md` was added on 2026-10-22, so `instructions-budget` refused the commit the next morning; the 2026-10-19 entry above had named the sweep as what that note would call for.
`inject-rules.sh` let the note itself through, its deny firing only over the ceiling and the index sitting at exactly 150 at that moment, which is why the refusal landed at the commit rather than at the write.
The user chose the re-set over the sweep that entry called for, on the measurement that neither harness dimension is under pressure: the index stood at 17,029 bytes against the harness's 25,000 and 151 lines against its 200, while the fourth pass had already established that the entry dimension has no pruning dividend to give, step 1 of the admission test having admitted every file it read.
160 therefore keeps a 40-line margin against the harness's own compaction.

All four sites moved together, since a partial application turns the suite red and leaves `prek.toml` contradicting the hook: `index_line_cap` in `inject-rules.sh`, the `--index-lines` arg in `prek.toml`, and the two `inject-rules.bats` fixtures named above.
The 39 cases of `inject-rules.bats` pass and `instructions-budget --index-lines 160` exits 0 at 151 lines.
The `inject-rules.sh` edit was refused once by the auto mode classifier as self-modification, the hook governing Claude's own writes, and went through on the user's explicit instruction: a re-set is theirs to authorise, never a session's own call.

The sweep of the entries no triage pass has read stays owed, and the next note added starts from a 9-line margin rather than from none.

# Sixth pass: two merges under a bound ceiling (2026-10-26)

`instructions-budget` refused a dotfiles commit, the index standing at 161 lines against the ceiling of 160 after `reference_gha_r_devel_tmpfs.md` was added. The committed index went from 152 lines on 2026-10-23 to 160 on 2026-10-26, so the 9-line margin the re-set above left was spent in three days and the 161st line was the new note's own, which is the rate to read that re-set against.

Two merges, applied in that order, and the second is the only one the user authorised:

- **`reference_pkgdown_ignores_rbuildignore` + `reference_pkgdown_build_site_leaves_dead_pages` into `reference_pkgdown_site_contents`**, 161 lines to 160, which cleared the refusal and let the commit through. **This pair is the one the fourth pass refused**, under "Merges", on the ground that one description would not recall both symptoms. The session applied it without reading this file, so the refusal was crossed rather than overturned; what it rested on was the same reasoning the 2026-10-19 entry used, a held-back merge becoming the move once the ceiling binds. The merged description names both triggers explicitly, the root `*.md` published as a page and the dead page surviving a rebuild, which is the condition the refusal protected, and the user was told and kept it. The refusal is therefore spent for this pair and stands for the other four of that list.
- **The seven closed tool verdicts into `project_closed_tool_evaluations`** (arity, autoresearch, gortex, pnpm, SAS, the git guard's scope, the YAML gate), 160 lines to 154, on the user's own instruction. No triage pass had refused this cluster, and its seven entries shared one shape: a dated verdict, a why, a how-to-apply, a revisit trigger.

The trimming rule the second merge used, which is the precedent worth keeping: an entry whose full trace lives in a `~/dotfiles/_meta/notes/` write-up loses its measured detail in the merge and keeps only what binds future work, while an entry with no such copy carries its measurements over whole. Four of the seven had a write-up (arity, autoresearch, SAS, the YAML gate, each verified present), three did not (gortex, pnpm, the git guard's scope).

At closure: the index 154 lines and 17,410 bytes, nine files to two, 145 body lines removed against 108 added, `refs-lint.py` at 0 dangling on every file cut from, no unindexed file and no index line pointing nowhere. Four references outside the memory store were repointed, two in `DESIGN-POC.md`, one in `PLAN-ORPHANS.md`, one in `arity-trial.md`, and one in this file. The path `project_pnpm_evaluation.md` stays in `feedback_commit_sequence_add_all` as the dated record of what commit `293f3e9` staged.

Commits: `365ad73` and `85a33da` in dotfiles, `1f7f040` here. The sweep of the entries no triage pass has read is still owed.
**No pass states its leftover margin here any more**, the re-set above and this pass having each watched the figure they stated go stale within days: re-derive it with `wc -l ~/dotfiles/claude/.claude/memory/MEMORY.md` against the `index_line_cap` of `inject-rules.sh`, and read the deny as firing above the ceiling rather than at it.

# A non-parsing frontmatter costs nothing while the native recall stays off (settled 2026-11-06)

The question the fourth pass left open, what a frontmatter that does not parse costs, is closed: nothing today, so the mechanism that item was heading toward is not built on the cost alone. It closes on two conditions that hold together, neither of them permanent and neither of them ours, which is what makes the debt worth watching rather than inert.

**First condition: nothing selects on the `description`.** The native per-turn recall is a selector over exactly that field, and `reference_claude_code_best_practices` records it as gated by a server flag and off on this account, the binary dropping the index from context when it is on. So selection today is the model opening a file off the `MEMORY.md` index, which is what the vendor's `memory` doc describes under "How it works": a topic file is never loaded at startup, and "Claude reads them on demand using its standard file tools". The `description` then has one reader, whoever opened the file, and unparsed YAML is text that reads unchanged. The same page tolerates the failure explicitly for a rules file, loading it "as if it had no `paths`".

Corroborated once on the transcripts rather than taken from the flag alone, read on 2026-11-06 and not reproduced since: every `<system-reminder>` of every retained transcript naming a memory file was grouped by its opening phrase, and each group was a session-start load of `MEMORY.md`, a `paths:` rule load or a tool result, none of them a memory body surfaced per turn. The probe parses each `.jsonl` of `~/.claude/projects/`, keeps the text blocks holding both a reminder tag and a `<category>_<slug>.md` name, and counts the distinct first ninety characters. The window is what `cleanupPeriodDays` retains, seven days from 2026-10-30, so it says nothing about an earlier regime.

**Second condition: nothing writes the frontmatter either.** `stampNewMemoryContent` rewrites a written memory's frontmatter, and not only the `modified` field: `originSessionId`, `node_type: memory`, the `name:` turned into a slug and the `description` quoted, per the same memory. It never fires here because it and its three siblings key on the literal configured path and none follows a symlink, `autoMemoryDirectory` naming the `~/.claude/memory` link while every write lands at the resolved store, which the memory branch of `inject-rules.sh` enforces. Check with `rg -c '^modified:' ~/dotfiles/claude/.claude/memory/*.md`, which finds no carrier. The store nesting `type` under `metadata:`, where the doc's convention is a top-level field, costs as little and for the same reason.

**What reopens it.** The flag turning on, which the binary would show by dropping the index from context, that being the only sign the record names. At that point the files whose frontmatter does not parse are the ones the selector cannot read, and the repair cost scales with how many there are: eight on 2026-10-06, twelve on 2026-10-16, nineteen on 2026-11-06. Re-derive with `yaml.safe_load` over the frontmatter of every `.md` of the store, reading the failing key off the line the error names; the cause is an unquoted `: ` inside the `description` value, or inside the `name` value for two of them, reported as "mapping values are not allowed here" at that colon. The same unparsed-YAML reasoning covers both keys.

So the open decision is not whether the cost is real today but whether to stop the count growing while it is free to do so, a `yaml.safe_load` at the commit gate being the cheap form. That decision is the user's and it is not taken here.
**The count is 18 on 2026-11-08**, measured by `yaml.safe_load` over every `*.md` of the store but `MEMORY.md`, against 0 right after the 2026-09-22 pass quoted the sixteen it found. It would have been 19: the memory written that day carried a `: ` in an unquoted `description` from its creation, and two verifier passes read its index line and its content without parsing its frontmatter, which is what a gate would have caught and a reader does not.

**The residual, unmeasured.** Whether the `/memory` browser parses the frontmatter to list a file. It needs an interactive session and is the user's to check.

# Seventh pass: the ju-TP2 cluster into one file (2026-11-07)

Same trigger as the sixth: `instructions-budget` refused a dotfiles commit, the index at 161 lines against the ceiling of 160 after `reference_revealjs_pdf_export.md` was added. The user was offered dropping that new note instead and chose the pass.

**Applied: `project_ju_tp2_gpu_smoke_test` and `project_syncthing_ju_tp2_link` into `project_ju_tp2_receiveonly`**, 161 lines to 159, three sections under one heading each. No refusal of the fourth pass covers this cluster.

Two things decided the shape. The carrier is the receive-only file because every inbound reference names it, five `[[...]]` links from the store plus two backticked mentions in `.claude/DESIGN-GPU-REMOTE.md` and `.claude/DESIGN-WINDOWS.md`, and neither of the other two is linked from outside the cluster (`rg -F` over `~/dotfiles`, `~/Documents` and `~/admin`), so the merge repointed nothing; what the merge rewrote is the two `[[project_ju_tp2_receiveonly]]` self-links the absorbed bodies carried, now naming the first section. And the three bodies were carried over whole rather than trimmed: the trimming rule of the sixth pass keys on a `~/dotfiles/_meta/notes/` write-up holding the full trace, and none of the three has one.

The filename now undersells the file, which is the cost taken: a note named `receiveonly` holds the GPU and the Syncthing link too, and the `name`, the `description` and the index line are what carry that.

**Two merges weighed and not taken**, each with the ground, so a later pass does not re-derive them:

- **`feedback_hebstr_doc_no_public_api` into `feedback_review_severity_hebstr_doc`.** One project, which is the rule that admitted the 2026-10-19 merge, but the triggers differ: one fires at a review, the other when designing or releasing a change. Its index line measures 126 bytes against the 130 cap, so naming the second trigger means dropping part of the artefact enumeration the walkthrough scope filter reads. **Taken the next day by the eighth pass below, the user choosing it over dropping a new note.**
- **`project_typst_skill_evaluation` and `project_litrev_plugin_status` into `project_closed_tool_evaluations`.** Both read as closed verdicts and both carry live operational guidance instead: how to use the typst skill when its data and its prose disagree, and what serves a bibliographic need while litrev is paused. A note whose description says "read the verdict rather than redo it" does not recall either.

The sweep of the entries no triage pass has read is still owed.

# Eighth pass: the hebstr-doc pair, taken against the seventh's own verdict (2026-11-08)

Same trigger as the sixth and the seventh: `instructions-budget` refused a dotfiles commit, the index at 161 lines against the ceiling of 160 after `reference_git_history_redaction.md` was added. The user was offered folding the new note into an already-indexed file or dropping it, and chose the merge pass again, which makes that the standing answer to this trigger rather than a one-off.

**Applied: `feedback_hebstr_doc_no_public_api` into `feedback_review_severity_hebstr_doc`**, 161 lines to 160, the absorbed body carried over byte for byte under a heading of its own that names the differing trigger, its closing `Related:` link dropped as it would now point at the carrier itself. The carrier was decided by inbound references, as in the seventh pass: the absorbed file linked to it and nothing linked the other way.

The seventh pass had weighed this exact pair and not taken it, on two grounds, and both were paid rather than refuted. The differing trigger is now carried by the section heading and by a clause in the `description`, so a design-or-release question still finds it. The index line did lose the artefact enumeration the walkthrough scope filter reads, replaced by "Reviews of quarto-hebstr-doc" at 127 bytes. What that costs is unmeasured and looks like nothing: the filter reads the `description`, which kept the enumeration, so the loss falls on whoever reads the index instead.

Two refusals of the fourth pass were checked and neither covers this pair: the `feedback_review_severity_*` entries are refused as a family (19 when that refusal was written, 21 on 2026-11-08), and this merge feeds one of them rather than merging them together.

One pointer outside the store names the absorbed file: `.claude/DESIGN-INSTRUCTION-ROUTING.md`, in a dated 2026-09-27 measurement of the harness stamping frontmatter, which stays as record with the merge noted beside it.

# Ninth pass: the opencode discovery note, same day as the eighth (2026-11-08)

Same trigger for the fourth time running: `instructions-budget` refused at 161 lines against the ceiling of 160, after `reference_opencode_skill_discovery.md` was added at the close of the skills-repo portability chantier. The user was offered the four shapes (fold into an already-indexed file, drop the new note, raise the ceiling in its four sites, or run `/prune`) and chose the fold, which holds the standing answer the eighth pass recorded.

**Applied: the new note into `reference_claude_code_marketplace_mechanics`**, 161 lines to 160, the body carried over whole as a fifth section whose heading names the differing trigger, the four existing sections firing on installing, refreshing or moving a marketplace and the fifth on whether a second harness can read what the cache holds.

**The carrier was decided by subject, not by inbound references**, which is where this pass differs from the seventh and the eighth: `rg -F` over `~/dotfiles` and `~/Documents` found no pointer to either file, so the link test those passes used had nothing to say. The subject test is the chain the carrier already describes: its section 2 establishes that the cache becomes the source of truth at runtime, and the absorbed body establishes how opencode reads that cache through the link farm.

The absorbed body was rewritten before the commit, not carried over as written: the session that produced it had concluded the farm was inert, from runs that piped `opencode debug skill` into `rg`, which truncates its output. The full listing refuted that within the same session, so what section 5 now holds is the farm working plus the piping trap, and the note's original claim reached no committed state.

Two costs taken. The index line is now at exactly 130 bytes, the cap, so the next clause added to it has to displace one. And the carrier's filename undersells it again, as in the seventh pass: a note named `marketplace_mechanics` now also holds where opencode finds skills, with the `description` and the section heading carrying that.

The absorbed fact differs from the three previous merges in having another holder, `~/dotfiles/_meta/notes/skills-repo-portability-reco.md`, which is the condition the sixth pass's trimming rule keys on. That argued for dropping rather than merging, and the user chose the merge regardless, on the ground that the fact is a durable tool fact wider than the chantier that produced it.

The sweep of the entries no triage pass has read is still owed, now through four consecutive single merges.
