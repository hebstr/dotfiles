---
name: Review severity for French statistical reports
description: "Calibrate review severity for French-language statistical reports (Quarto .qmd): do not flag established untranslated English statistical terms, and verify claims against executed code before filing them"
metadata:
  type: feedback
---

In the user's French statistical reports (`md-nesrine` and sibling `hebstr` service projects), the review patterns below are wasted effort.

**Do not flag untranslated English statistical terms as register inconsistencies.** `hazard ratio`, `odds ratio`, `at baseline` are established usage in French medical writing and have no equivalent in circulation. A French gloss appearing elsewhere in the same document (e.g. `rapport du nombre moyen de cures` for `IRR`) is not an inconsistency: each term follows the vocabulary of its own table, which is the stronger consistency constraint. Check the rendered table footnotes before concluding a register mismatch exists.

**Do not file a claim about what a statistical method does without executing the code first.** Two of the fifteen findings in the 2026-08-25 walkthrough were false positives built on inference about library defaults rather than on a run. `car::Anova` on a quasi family scales the deviance by the estimated dispersion, so its `LR Chisq` column is dispersion-corrected; asserting the opposite from a p-value gap cost a full point of the walkthrough. Likewise a variable set difference between two models was read as an under-declaration when `x_mv_exclude = NULL` showed no revision had occurred.

**Do not infer hebstr's behaviour from its documentation; read the function.** Three of the four findings rejected in the 2026-08-26 walkthrough were this same error. The parametric/non-parametric split behind `opts$vars$stat` is a declarative name filter, not a normality test: `easy_descr()` builds `\b(?:{parametric})\b` from `opts$parametric`, whose default is `nullfile()`, so with no `set_opts(parametric = ...)` every continuous variable is non-parametric and renders `médiane (IQR)`, deterministically. And the `DM` column is emitted only where missing values exist, per group: its absence from a table means zero missing, never an undeclared count (verify by checking that the category counts sum to the header N).

**A sentence must carry what the caption, the heading and the table do not.** Announcing sentences before descriptive tables are worth adding only where the denominator differs from the analysed population or a restriction applies; elsewhere the user calls them obvious and removes them, along with verbless fragments that merely restate the caption. The same rule settles the prose/table split: fixed-horizon survival rates live in the table, and the prose carries the median with its CI and the hazard ratio, which the table lacks. SAMPL asks that those rates be *indicated*, not indicated in prose, so a table satisfies it. Do not file such duplication as a missing item.

**Why:** the user is the biostatistician; analysis code is theirs to write and defend. A review finding that is wrong on the statistics costs more than one that is missing, because it forces them to re-derive a result they already know.

**How to apply:**
- Before filing any finding about a test, family, or estimator, run it and read the output. `Rscript` sourcing `setup.R` plus the relevant `scripts/*.R` takes a couple of minutes and settles the question.
- Check the project's own `.claude/` notes (`MODEL_GLM.md`, `NOTE-RAPPORT-STAT.md`, `CONTINUE.md`) before filing: documented decisions and known-open questions live there, and several findings are already tracked.
- A Methods section states the plan a priori. Naming which variable dropped out of a model after seeing the data belongs in Results or a table footnote, never in Methods. See [[project_md_nesrine_render_pitfalls]] for the project's other constraints.
