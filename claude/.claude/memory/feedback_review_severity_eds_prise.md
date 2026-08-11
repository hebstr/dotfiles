---
name: Review severity for eds-prise
description: Calibration for code reviews of eds-prise, both subsystems (the R analysis pipeline under scripts/, and the Streamlit annotation app under annot/): the conventions that are deliberate and must not be re-flagged, and the false-positive shapes reviewers produced on 2026-08-10 and 2026-08-11
metadata:
  type: feedback
---

`~/Documents/des/eds/eds-prise` is a personal epidemiological analysis project (PRISE, shoulder pathology care pathways, CHU de Lille EDS). Quarto working document plus `scripts/_setup.R` and one script per output. Not a package, not production. Measured on a 14-finding `critical-code-reviewer` pass walked on 2026-08-10: 12 accepted, 1 noted, 1 rejected. Of the 12 accepted, **7 were applied as the reviewer wrote them and 5 needed the fix rewritten after measurement**. Two of its proposed fixes would have introduced a new defect (deleting 17 real observations at one site, breaking a figure's accounting at another) and a third would have destroyed a deliberate ordering, so the finding rate is better than the remedy rate: take the diagnosis seriously and measure the remedy before applying it.

## Conventions that are deliberate, do not re-flag

- **`stopifnot()` blocks are tripwires, not redundant assertions.** A guard asserting a property the surrounding filter does not establish is the design, not a gap. Proposing to "make the guard true by construction" trades a loud, investigable abort for a silent exclusion, which this project consistently refuses. Same reading settled the `!anyNA(df_pop)` guard and the annual-series guard of `fig_tte_douleur.R`.
- **In a pairing between two tables truncated at different depths, only the downstream event is bounded to the analysis period; the anchor date is left free.** Stated twice with its rationale, `fig_tte_douleur.R` above `df_dlr_cs` and `_setup.R` above `.cs_geste_per`, which cross-reference each other. Where the intent is instead a population definition, the project does bound explicitly (`.pat_cs_per`, `n_cs$an`). The two patterns are not an inconsistency.
- Dot-prefixed objects are internal to their setup or script; bare `df_*` are the deliverables. Exposing an internal one is done when a **third** consumer appears, not the second (the `.sej_etude` → `df_sej_etude` and `df_index` episodes in `.claude/DEFERRED.md`).
- `n_*` objects built with `lst()` are internal summary frames read by explicit inline citations in `index.qmd`, never rendered as tables. An `NA` in a cell no citation reaches is not a defect, and is often the honest value.

## Two traps that produced wrong measurements, mine included

- **Frames that passed through `easy_label()` are factors.** `.df_pop` and `.df_porte` are post-conversion, so comparing `pat_dept == 3` returns zero silently. Measure on the pre-label frame (`.porte_pat`) or on the raw column. The trap is documented in a comment in `_setup.R` and I fell into it anyway; check which side of `easy_label()` a frame sits on before counting.
- **Row order out of `collect()` is not stable between runs.** Sourcing `_setup.R` twice gives `df_sej_pat`, `df_index`, `df_pop`, `df_porte` in different row order. Content is identical and every published aggregate is stable, since everything downstream aggregates or joins by key. Always compare with `arrange()` on a unique key before concluding a change had an effect; a bare `all.equal()` reports a difference that is not one. `df_pop` has no unique key (`keep_labelled()` drops `id_pat`), so compare `.df_pop`.

## False-positive shapes seen in the 2026-08-10 pass

- **Severity justified by a mismatched comparator.** A Blocking rested on 71.6 % vs 89.1 %, where the larger figure counted negative delays the sentence itself excludes. The honest contrast was 71.6 % vs 70.6 %, one point. Recompute the reviewer's own comparison before accepting its tier.
- **An intermediate frame reported as the study frame.** "8 missing postcodes of 53 479" belonged to `df_pat_cp`, not to the 7 337-patient study population, where the count is 0. Check which frame a cited count comes from.
- **A symmetric bound proposed where only one side is at risk.** Adding `between()` on an anchor date would have deleted 17 real observations and changed a published count, to guard a failure mode that exists only on the lower bound. Measure both sides of a proposed `between()` before applying it.
- **Harmonising two siblings that differ on purpose.** Alphabetical ordering of CIM-10 codes groups the hierarchical M75 family; CCAM codes are not hierarchical and sort by frequency. The fix was to name the variable instead of selecting it positionally, not to harmonise.
- A proposed fix that is a literal no-op (`if (any(x)) median(x[...]) else NA_real_` where the else branch returns the same `NA`). Run the proposed fix before accepting the finding it claims to fix.

## The annot/ Streamlit app is the project's second subsystem

`annot/prise_annot_output.py` plus `annot/lib/` and `annot/prise_annot_run.sh`, launched by that script, fed by parquet written from `annot/prise_annot_input.R`. Its output parquet is shared, one column pair per annotator (`note_estimate_<user>`, `note_comment_<user>`), and `AUTH` / `DOWNLOAD` are hardcoded constants the author flips by hand. The 2026-08-11 pass: 10 findings, 7 accepted, 2 noted, 1 rejected.

- **Read `.claude/DEFERRED.md` before reviewing this subsystem.** Finding 4 of the 2026-08-11 pass (unlocked module-level parquet write firing on every rerun) was already logged there on 2026-08-02 and consciously deferred as "correctif jugé trop coûteux pour le gain". The costing was wrong: it priced the *design* change (move creation to first save, thread `df_output` into `navigation()`) rather than the *defect* fix (gate the existing write on `rebuilt or added`, take the same `FileLock`), which needs none of it. A deferred item's stated cost is an estimate made under time pressure, not a measurement; re-derive it before honouring the deferral.
- **`st.sidebar.foo()` inside `with st.sidebar.container(...)` ignores the `with` stack.** `DeltaGenerator._active_dg` consults it only when `self == self._main_dg`; the source comment says so outright. Content must be written with bare `st.foo()` to land inside the container. Silent: the container is emitted empty and any CSS keyed on `.st-key-<key>` never applies.
- **`st.cache_data` hashes argument values only**, never file mtime or content. Any remedy of the shape "key this reader on its path so it notices a regenerated file" is a no-op when the path is a module-level constant, which it always is here. Reaching content changes needs mtime or a hash as the argument, or a server restart.
- **`AppTest` rewrites the output parquet**, because loading the app writes it. Back it up and restore it before and after every headless run, and verify the restore by content (row count plus non-empty note cells), not by `git status` alone.
- **Cross-check the reviewer's output against the design doc's own stated review motivations.** `.claude/DESIGN-ANNOT-UI.md` listed the `code.py` escaping asymmetry (`libelle` escaped, `code` not) as the reason to review that module; `critical-code-reviewer` reviewed the module, reported other things about it, and never mentioned the asymmetry. A reviewer covering a target is not evidence it covered the concern that motivated the target. Read the design doc's justification before accepting a review as complete.
- Estimate columns can never hold `None` despite `st.radio(index=None)` returning it: `value_note=state[VAR_ESTIMATE] not in [EMPTY, None]` disables the save button first. That guard is what makes the bare `!= EMPTY` comparisons in `max_index` and `n_noted` correct. Do not "fix" those comparisons without noticing the guard lives elsewhere.

## Three more remedy-level false positives, 2026-08-11

The pattern holds across both subsystems and is the thing to watch: the diagnoses were sound, two of the ten remedies were not, and one of my own rewrites introduced a fresh defect.

- **A remedy that duplicates a study definition into a second language.** "Add the three missing columns to the Oracle `SEJ_QUERY`" required reproducing two joins plus the project's CIM-10/CCAM inclusion regexes, held in R config, inside Python. That creates a second source of truth for the study's inclusion criteria. The right remedy was to make the loss visible (warn on the computed set difference), not to reproduce the upstream.
- **A remedy that trades an exact exception for a misleading message.** "Show the invalid-credentials error when `secrets.toml` is missing" would print "Identifiant ou mot de passe incorrect" when the real fault is an absent credential store; `load_secrets` already raises a custom message naming the exact path. Rejected. Consistent with the project's tripwire preference, and a reminder that a crash carrying the right message can be the correct behaviour.
- **My own first remedy conflated two states.** Guarding the destructive rebuild on "any note cell is non-empty" bricked startup on the legitimate "comment written, estimate not yet posted" state. Enumerate the intermediate states of a workflow before gating its entry point; here the routing needed four cases, not two.

Cross-provider L2 consensus (Ouroboros `ouroboros_evaluate`, 3 models) ran on four findings of that pass and returned 3/3 APPROVED every time, always agreeing with the intra-family L1 agent and with direct measurement. On a claim already settled by executing it, L2 ratifies rather than tests; spend it where the finding carries unmeasured judgment instead.

See [[feedback_review_severity_personal]] for the general personal-project calibration, [[project_prise]] and [[project_codes]] in the project's own `.claude/memory/` for domain context, and [[project_md_nesrine_render_pitfalls]] for the `stats::filter` masking that blocks any non-render entry point into this pipeline.
