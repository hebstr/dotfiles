---
name: Review severity for eds-prise
description: "Calibration for code reviews of eds-prise, both subsystems (the R analysis pipeline under scripts/ and collect/, and the Streamlit annotation app under annot/): deliberate conventions not to re-flag, measurement traps, and the false-positive shapes of eight passes (2026-08-10 to 2026-09-02)"
metadata:
  type: feedback
---

`~/Documents/des/eds/eds-prise` is a personal epidemiological analysis project (PRISE, shoulder pathology care pathways, CHU de Lille EDS): `setup.R`, `scripts/_common.R` (shared preparation), one script per output, `collect/`, and the `annot/` Streamlit app. Not a package, not production.
Domain context lives in the project's own store (`~/Documents/des/eds/eds-prise/.claude/memory/project_prise.md`, `project_codes.md`); the general personal-project calibration in [[feedback_review_severity_personal]].
Its former technical document `technique.qmd` has been archived to `.claude/archive/technique.qmd` since 2026-09-08 (project `CLAUDE.md`, "Commentaires et documentation technique"): read it there, but cite code and guards, not its callouts.

## The reviewer's diagnosis is sound, its remedy and its evidence are not

Across eight passes (`critical-code-reviewer` on `scripts/` twice, the `annot/` app, `_common.R`, `annot/lib/password.py`, `annot/lib/note.py`, `code_douleur_rx()`; `review-testing` on `annot/tests`), the diagnoses held and a third to a half of the remedies needed rewriting after measurement; two proposed fixes would have introduced a new defect. Take the diagnosis seriously and run the remedy before applying it.

- **A cited count on the wrong frame kills the tier, not the diagnosis.** Twice on `pat_cp`: counts taken from the full `pat` parquet (1 632 367 rows) or an intermediate frame (`df_pat_cp`) were 0 on the frames the scripts consume. Re-measure on those (`.df_pop`, `.pop_cs_pat`). Rejecting the evidence and fixing the underlying defect are compatible outcomes (`.dept_from_cp` now tests the length before padding).
- **A severity resting on a mismatched comparator** (71.6 % vs 89.1 %, where the larger figure counted delays the sentence excludes; the honest contrast was one point): recompute the reviewer's own comparison.
- **"Nothing guards X" is measured by enumerating the guards, and this reviewer names the wrong covering guard.** The set of codes is caught by `n_code$declare == n_code$observe` and `!anyNA(df_code_tbl$key)`; a concept whose regex matches nothing is caught by `setequal(names(.key_libelle), names(n_code_key))` in `CODE LIBELLE`, not by the declare/observe count (a code absent from the nomenclature measured 49 == 49). Check a guard's date before citing a blind spot.
- **Remedy shapes to refuse:** a symmetric `between()` where only one bound is at risk (it would have deleted 17 real observations); harmonising two siblings that differ on purpose (hierarchical CIM-10 sorted alphabetically, CCAM by frequency); a literal no-op fix; a remedy that duplicates a study definition into a second language (the inclusion regexes live in R config, so Python makes the loss visible rather than reproducing it); an exact exception traded for a misleading message; an unmeasured micro-optimisation ("free", "no intermediate allocation": 1.501 s against 1.468 s, noise).
- **A remedy can fail the claim of its own finding, or break a fix applied earlier in the same walkthrough.** Run it on the case the finding names, and re-read later remedies against earlier fixes.
- **A mechanism asserted from an older version's behaviour.** Streamlit 1.60 accepts additive `st.set_page_config` calls; check the installed source before a "must be first" claim.
- **Cross-check the review against the design note's stated motivations.** `.claude/DESIGN-ANNOT-UI.md` named a concern the reviewer never mentioned; covering a target is not covering the concern that motivated it. Its threat model (internal CHU machine, two annotators, disposable passwords) closes auth findings on hashing and `st.login()` OIDC.
- **`review-testing` is reliable on `annot/tests`** (11 of 11 accepted, remedies applied as written), where `critical-code-reviewer` is not on analysis code. Clean small modules under tests are also where the latter is reliable.

## Deliberate conventions, do not re-flag

- **`stopifnot()` blocks are tripwires.** A guard asserting what the surrounding filter does not establish is the design; making it "true by construction" trades a loud abort for a silent exclusion. Deleting conditions true by construction today is refused too: in a repo with no test suite they are the regression net. Exception: a guard whose two sides derive from the same object is an identity, not a guard (`str_detect(str_flatten(code, "|"), fixed(code))` can only fail on `NA`), and it costs something when its label claims coverage.
- **In a pairing of two tables truncated at different depths, only the downstream event is bounded to the analysis period, the anchor date left free**; a population definition bounds explicitly (`.pat_cs_per`, `n_cs$an`). Not an inconsistency. The object that first carried the pattern, `.cs_geste_per`, was removed in `1b4f1b4` (2026-09-06).
- **Naming:** dot-prefixed objects are internal, bare `df_*` are deliverables, and an internal one is exposed at the third consumer. `.pat_*` is a vector of patient ids, `.X_pat` a frame with one row per patient; renaming the near-anagram pairs creates the inconsistency it claims to fix. `n_*` frames built with `lst()` are read by inline citations in `index.qmd`: an `NA` no citation reaches is not a defect.
- **Annotation output columns are `note_<variable>_<annotator>`**, so the stray-column guard reads `endswith(suffix)` on purpose (`note_motif_admin2` belongs to `admin2`); do not re-propose `suffix in col`.
- **Estimate columns never hold `None` at save time**: the save button is gated by `value_note=bool(complete(pending).iat[0])`, which is what keeps the bare `!= EMPTY` comparisons in `max_index` correct. Do not "fix" those without noticing the guard.
- **Do not propose tests on states the app cannot produce** (a zero-row frame: the output derives from the input and the save frame is one row). Check which states the app reaches.
- **Read `.claude/DEFERRED.md` before reviewing `annot/`**, and re-derive a deferred item's stated cost: one deferral priced the design change rather than the defect fix.

## Measurement traps, Claude's own included

- **Frames past `easy_label()` are factors**: `pat_dept == 3` returns zero silently. Measure on the pre-label frame.
- **Row order out of `collect()` is not stable between runs**: compare with `arrange()` on a unique key; a frame out of `keep_labelled()` has lost `id_pat`, so compare the pre-label frame.
- **`.claude/` is gitignored**: see [[feedback_rg_misses_gitignored_trackers]]; scope `--no-ignore` to `.claude/`, or `_book/` and `_freeze/` bury the answer.
- **`%in%` returns `FALSE` on `NA`**, never `NA`: a `sum(..., na.rm = TRUE)` over `!(NA %in% x)` counts the missing values.
- **`$` partially matches on a list, `[[` does not**: `list(imagerie = "x")$imag` returns `"x"`, so a removed YAML key with a same-prefix sibling returns the sibling's value. Every `_variables.yml` read uses `[[`; `with()` is exact and aborts loudly.
- **`stopifnot(x == "literal")` passes when `x` is `NULL`** (`logical(0)`): use `identical()`.
- **`str_flatten()` on a nested list inlines its deparse** (`A|list("B1", "B2")|C`, a valid regex matching nothing): `unlist()` first.
- **`stack()` keeps the level of a zero-length element while dropping its rows**: assert the observation, not the taxonomy.
- **`nanoparquet::write_parquet(metadata = )` wants a named character vector** (0.5.1), and the read-back carries an `ARROW:schema` entry to drop. The code-pattern metadata lives in `code_douleur.parquet` itself, since two files written side by side had drifted six days apart.
- **Streamlit:** `st.sidebar.foo()` inside `with st.sidebar.container()` ignores the `with` stack (write bare `st.foo()`); `st.cache_data` hashes argument values only, never file content; `AppTest` rewrites the output parquet on load, so back it up and verify the restore by content; an empty `ElementList` is falsy, never `None`; `Series.equals` compares index labels and dtype as well as values.
- **A smoke gate can prove writes do not happen without proving they do**: include the states that exercise the write ("output absent", "declared note column dropped"), and observe session state (`doc_index`) rather than re-reading an untouched file.
- **A `case_when` default is a branch**: give it a case.
- **`hmac.compare_digest(b"", b"")` is `True`**: the one-liner `users.get(username, "")` authenticates an unknown user with an empty password.

## Open by design

A single invalid code among several in one motif keeps its key, matches the others and narrows the branch silently. Holding it would need an expected count per concept, a second source of truth; recorded, not built.

See [[project_md_nesrine_render_pitfalls]] for the `stats::filter` masking that blocks any non-render entry point into this pipeline.
