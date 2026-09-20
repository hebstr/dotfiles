---
domain: biostat
author: sjoberg
topic: gtsummary
sources:
  - kind: repo
    repo: ddsjoberg/gtsummary
    url: https://github.com/ddsjoberg/gtsummary
    ref: v2.5.0
    captured: 2026-04-25
    files:
      - DESCRIPTION
      - NEWS.md
  - kind: blog
    url: https://www.danieldsjoberg.com/gtsummary/
    captured: 2026-04-25
  - kind: blog
    url: https://larmarange.github.io/broom.helpers/
    captured: 2026-04-25
  - kind: blog
    url: https://larmarange.github.io/labelled/
    captured: 2026-04-25
  - kind: blog
    url: https://larmarange.github.io/ggstats/
    captured: 2026-04-25
  - kind: blog
    url: https://larmarange.github.io/guide-R/
    captured: 2026-04-25
---

# Biostat: gtsummary patterns for clinical summary tables (Sjoberg + Larmarange)

Reference for **gtsummary** v2.5.0 (released 2025-12-05, last commit 2026-03-16), focused on clinical reporting patterns.
Sources: [danieldsjoberg.com/gtsummary](https://www.danieldsjoberg.com/gtsummary/) and [larmarange.github.io](https://larmarange.github.io/) (captured 2026-04-25).

This is a **delta** on top of installed R skills (`r-skills:tidyverse-patterns`, `r-lib:*`, `quarto:quarto-authoring`). Those cover dplyr, broom, ggplot, package dev, Quarto basics. They do NOT cover:

1. Auto-typed Table 1 with stratification + automatic test selection
2. Journal-house themes (JAMA, Lancet, NEJM, qjecon)
3. Variable-type selectors (`all_continuous`, `all_categorical`, `all_dichotomous`)
4. Clinical table constructors (`tbl_survfit`, `tbl_uvregression`, `tbl_svysummary`, `tbl_hierarchical`, `tbl_cross`, `tbl_strata`)
5. Inline reporting via `inline_text()` per-table-class S3 methods
6. Backend-agnostic rendering (gt / flextable / kableExtra / huxtable from one object)
7. The `broom.helpers` escape hatch behind `tbl_regression()`
8. Label-driven workflow via `labelled::var_label()`
9. Survey-weighted reporting end-to-end (Larmarange-authored surface)

## Table 1: `tbl_summary()` core idiom

From <https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html>:

```r
trial |>
  tbl_summary(
    include = c(age, grade, response),
    by = trt,
    missing = "no"
  ) |>
  add_n() |>
  add_p() |>
  modify_header(label = "**Variable**") |>
  bold_labels()
```

The shipped `trial` dataset is a 200-patient simulated chemotherapy RCT (`age, marker, stage, grade, response, death, ttdeath, trt`) designed for clinical demos.

Per-type controls:

```r
tbl_summary(
  by = trt,
  statistic = list(
    all_continuous()  ~ "{mean} ({sd})",
    all_categorical() ~ "{n} / {N} ({p}%)"
  ),
  digits  = all_continuous() ~ 2,
  type    = all_continuous() ~ "continuous2",
  label   = list(grade = "Tumor Grade"),
  missing = "no"
)
```

| Argument | Effect |
|---|---|
| `by =` | Stratify columns (e.g. by treatment arm) |
| `add_p()` | Auto-pick test by variable type (Wilcoxon / Fisher / chi² / Kruskal) |
| `add_overall()` | "Total" column |
| `add_n()` | Per-row N |
| `missing = "no"` / `missing_text = "(Missing)"` | Suppress or relabel missingness row |
| `type = ... ~ "continuous2"` | Multi-line continuous summary (NEJM-style) |

**Variable-type selectors** are gtsummary-specific: they target the table's metadata, not raw data. They are `all_continuous()`, `all_categorical()`, `all_dichotomous()`, `all_stat_cols()`.

## Regression tables: `tbl_regression()`

From <https://www.danieldsjoberg.com/gtsummary/articles/tbl_regression.html>:

```r
m1 <- glm(response ~ age + stage, trial, family = binomial)
tbl_regression(m1, exponentiate = TRUE)         # OR with 95% CI
```

Univariable screen across many predictors:

```r
trial |>
  tbl_uvregression(
    method      = glm,
    y           = response,
    include     = c(age, grade),
    method.args = list(family = binomial),
    exponentiate = TRUE
  ) |>
  add_global_p() |>
  add_nevent()
```

| Function | Purpose |
|---|---|
| `tbl_regression()` | Tidy one fitted model into a publication table |
| `tbl_uvregression()` | One row per univariable model (screening) |
| `add_global_p()` | Type-3 / LRT omnibus p-value for multi-level factors |
| `add_nevent()` | Outcome events (essential for survival/binary) |
| `add_vif()` | VIF column for collinearity check |
| `add_q()` | FDR adjustment |
| `add_significance_stars()` | Stars (used by `qjecon` theme) |
| `add_glance_table()` / `add_glance_source_note()` | Append model fit stats |
| `combine_terms()` | Pool multiple terms into one row (e.g., spline basis) |

Custom tidiers (slot into `tidy_fun =`): `tidy_robust`, `tidy_bootstrap`, `tidy_standardize`, `pool_and_tidy_mice`, `tidy_gam`.

Custom p-value formatter:

```r
tbl_regression(
  m1,
  pvalue_fun  = label_style_pvalue(digits = 2),
  exponentiate = TRUE
)
```

## Journal themes: what they actually change

From <https://www.danieldsjoberg.com/gtsummary/reference/theme_gtsummary.html>:

```r
theme_gtsummary_journal(journal = "jama")
theme_gtsummary_compact()        # stack additional theme on top
reset_gtsummary_theme()

with_gtsummary_theme(theme_gtsummary_journal("lancet"), { ... })   # scoped
```

| Journal | Effect |
|---|---|
| `"jama"` | Round large p to 2 decimals; CI separator `"ll to ul"`; tbl_summary: no `%` sign, em-dash IQR, runs `add_stat_label()`; tbl_regression: coef and CI in same column |
| `"lancet"` | Mid-point as decimal separator; round large p to 2 decimals; CI `"ll to ul"`; tbl_summary: no `%`, em-dash IQR |
| `"nejm"` | Round large p to 2 decimals; CI `"ll to ul"`; tbl_summary: no `%`, em-dash IQR |
| `"qjecon"` | tbl_summary: percentages to 1 decimal; tbl_regression: significance stars, hides CI and p |

Other themes: `theme_gtsummary_compact()`, `theme_gtsummary_mean_sd()`, `theme_gtsummary_eda()`, `theme_gtsummary_continuous2()`, `theme_gtsummary_language()` (16 languages incl. fr, de, es, ja, ko, zh-Hans, zh-Hant), `theme_gtsummary_printer()` (default backend).

## Combining tables: merge, stack, strata

From <https://www.danieldsjoberg.com/gtsummary/articles/gallery.html>:

Side-by-side baseline + two regression outcomes:

```r
tbl_merge(
  list(gt_t1, gt_r1, gt_r2),
  tab_spanner = c(NA_character_, "**Tumor Response**", "**Time to Death**")
)
```

Stratified table within strata (subgroup forests):

```r
trial |>
  tbl_strata(
    strata = grade,
    ~ .x |> tbl_summary(by = trt, missing = "no")
  )
```

Cox univariable with events per level:

```r
tbl_uvregression(
  method  = survival::coxph,
  y       = survival::Surv(ttdeath, death),
  include = c(stage, grade)
) |>
  add_nevent(location = "level")
```

Robust SE for clustered data:

```r
tbl_regression(
  lmod, exponentiate = TRUE,
  tidy_fun = \(x, ...) tidy_robust(x, vcov = cov, ...)
)
```

## Inline reporting in Quarto / Rmd: `inline_text()`

From <https://www.danieldsjoberg.com/gtsummary/articles/inline_text.html>:

Default tbl_regression pattern:

```
"{estimate} ({conf.level*100}% CI {conf.low}, {conf.high}; {p.value})"
```

Available fields: `{estimate}`, `{conf.low}`, `{conf.high}`, `{p.value}`, `{conf.level}`, `{N}`.

```markdown
The age-adjusted odds were `r inline_text(tbl_m1, variable = age)`.
```
→ "1.02 (95% CI 1.00, 1.04; p=0.091)"

Cell-level pull from a `tbl_summary`:

```markdown
`r inline_text(tab1, variable = stage, level = "T1", column = "Drug B")`
```
→ "25 (25%)"

Custom pattern:

```r
inline_text(tbl_m1, variable = age,
            pattern = "(OR {estimate}; 95% CI {conf.low}, {conf.high}; {p.value})")
```

`inline_text` has dedicated S3 methods for `tbl_summary`, `tbl_svysummary`, `tbl_regression`, `tbl_uvregression`, `tbl_survfit`, `tbl_cross` and `tbl_continuous`, replacing fragile manual `sprintf` of estimates/CIs in narrative text.

Adjacent tool for prose-from-model (different mechanism, complementary): [`easystats::report()`](https://easystats.github.io/report/) by Dominique Makowski et al., which auto-generates English narrative from a model object. Use `inline_text()` for in-line fragments inside hand-written prose; use `report()` when you want a full sentence or paragraph generated from a model.

## Output backends: same object, four targets

gtsummary delegates rendering, never owns it:

| Converter | Target |
|---|---|
| `as_gt()` | gt (HTML default) |
| `as_flex_table()` | flextable (Word, PowerPoint via officer) |
| `as_kable()` / `as_kable_extra()` | kable / kableExtra (PDF/LaTeX) |
| `as_hux_table()` / `as_hux_xlsx()` | huxtable / xlsx export |
| `as_tibble()` / `as.data.frame()` | raw tibble |

Critical when journals require Word submission but websites need HTML: one table object, no re-authoring.

## Other clinical constructors

From <https://www.danieldsjoberg.com/gtsummary/reference/index.html>:

- `tbl_cross()`: 2-way cross-tab with chi²/Fisher
- `tbl_continuous()`: one continuous variable summarized across factors
- `tbl_survfit()`: KM estimates at fixed times + log-rank `add_p()`
- `tbl_svysummary()`: survey-weighted (complex designs, NHANES-style)
- `tbl_hierarchical()` / `tbl_hierarchical_count()`: AE-style nested events (MedDRA)
- `tbl_likert()`: ordinal scale summaries
- `tbl_strata2()` / `tbl_strata_nested_stack()`: strata facets
- `tbl_split_by_rows()` / `tbl_split_by_columns()`: paginate large tables
- `tbl_ard_*()`: build from CDISC ARD (Analysis Results Datasets, regulated submissions). Notable: `tbl_ard_strata()` / `tbl_ard_strata2()` (v2.5.0, #1852), strata facets driven by ARD inputs.

Style helpers (numeric formatters, exposed for reuse): `style_pvalue`, `style_percent`, `style_sigfig`, `style_ratio`, `style_number` and their `label_style_*` higher-order versions for `pvalue_fun =` arguments.

Modifiers: `modify_header`, `modify_spanning_header`, `modify_caption`, `modify_footnote_body`, `modify_footnote_header`, `modify_abbreviation`, `modify_source_note`, `modify_column_hide`/`_unhide`, `modify_column_alignment`, `modify_fmt_fun`, `modify_indent`, `modify_missing_symbol`, `modify_table_body`, `bold_labels`, `bold_levels`, `bold_p`, `italicize_labels`, `italicize_levels`, `sort_p`, `filter_p`.

## Pharma / ARD axis: the regulatory-submissions pivot

Since ~2024 gtsummary is being re-architected on top of an **ARD (Analysis Results Dataset)** backend, a CDISC standard for storing analytical results in a structured, traceable form for regulatory submissions. The `tbl_ard_*()` family in gtsummary is the consumer side; the producer side lives in two foundational packages maintained by the `insightsengineering` org (Roche-led pharmaverse stack):

- [`cards`](https://github.com/insightsengineering/cards): "CDISC Analysis Results Data". The foundational ARD container. Defines the data structure that statistical results flow through.
- [`cardx`](https://github.com/insightsengineering/cardx): "Supplements ARD Functions Found in `cards`". Adds higher-level builders. **Co-maintained by Emily de la Rua** (`edelarua`), the **#2 contributor on gtsummary itself** (243 commits, vs. Sjoberg's 2012). She is the operational driver of this axis on the gtsummary side.

Companion packages (same org, pharma-reporting stack):

- [`crane`](https://github.com/insightsengineering/crane): "Supplements the gtsummary Package for Pharmaceutical Reporting". Originally created by Sjoberg, now maintained by Joe Zhu (Roche). Adds gtsummary builders specific to pharma reporting that don't fit upstream.
- [`tern`](https://github.com/insightsengineering/tern): "Table, Listings, and Graphs (TLG) library for common outputs used in clinical trials". Top contributor besides Sjoberg/de la Rua: Davide Garolini (`Melkiades`, Roche, ~143 commits).

Outside the insightsengineering org but in the same regulatory orbit:

- [`tfrmt`](https://github.com/GSK-Biostatistics/tfrmt): "R package for formatting tables". A **display-metadata DSL** for CDISC TFLs (Tables, Figures, Listings) that consumes ARD inputs and emits regulatory-grade outputs. Authored by Christina Fillmore (`christina.e.fillmore@gsk.com`, ORCID 0000-0003-0595-2302) at GSK Biostatistics.

Stack picture: a clinical analysis flows `model → cards/cardx (ARD) → tfrmt or crane/tern → gt/flextable/officer` for the final submission artifact. This is the direction Sjoberg himself is steering toward (PHUSE/CDISC workshops 2025). If you work on regulatory submissions, start at the ARD layer; if you work on academic publications, the classic `tbl_summary`/`tbl_regression` path is fine.

## Larmarange angle: the broom.helpers + labelled stack

Joseph Larmarange (IRD) is the second-most active gtsummary contributor and maintains three packages gtsummary depends on directly: `broom.helpers`, `labelled`, `ggstats`. Patterns below are not in the official Sjoberg docs but unlock customizations gtsummary alone doesn't expose.

### `broom.helpers`: the engine behind `tbl_regression()`

From <https://larmarange.github.io/broom.helpers/articles/tidy.html>:

```r
model_poly |>
  tidy_plus_plus(
    exponentiate    = TRUE,
    add_header_rows = TRUE,
    variable_labels = c(age = "Age in years")
  )
```

Composed steps: `tidy_and_attach()` → `tidy_identify_variables()` → `tidy_add_reference_rows()` → `tidy_add_estimate_to_reference_rows()` (fills OR=1 / HR=1) → `tidy_add_header_rows()` → `tidy_add_variable_labels()` / `tidy_add_term_labels()` → `tidy_add_n()` → `tidy_remove_intercept()`.

**Escape hatch**: `...` in `tbl_regression()` flows to `tidy_plus_plus()` (PR #1387). When gtsummary doesn't expose the tidier option, pass it through.

### `labelled`: labels picked up automatically

From <https://larmarange.github.io/labelled/articles/intro_labelled.html>:

`tbl_summary()` and `tbl_regression()` automatically read `var_label()` for row headers and `val_labels()` (when converted via `to_factor()`) for category levels, so **no `label =` argument is needed if labels are set upstream on the data frame**.

```r
df <- data.frame(age = c(1, 2, 3), opinion = c(1, 2, 1))
var_label(df$age)     <- "Age in years"
var_label(df$opinion) <- "Overall satisfaction"
val_labels(df$opinion) <- c("Dissatisfied" = 1, "Satisfied" = 2)
```

Pipe-friendly entry point (his guide-R idiom):

```r
d <- d |>
  set_variable_labels(
    sport        = "Pratique un sport ?",
    sexe         = "Sexe",
    groupe_ages  = "Groupe d'âges"
  )
```

Source: <https://larmarange.github.io/guide-R/analyses/regression-logistique-binaire.html>

### French / multi-language locale

```r
theme_gtsummary_language(
  language     = "fr",
  decimal.mark = ",",
  big.mark     = " "
)
```

Source: <https://larmarange.github.io/analyse-R/gtsummary.html> (frozen 2022 but most complete French intro).

### Survey-weighted reporting, largely his contribution surface

`tbl_svysummary()` (PR #547), srvyr compatibility (PR #887), CIs (PR #1402), design-effect reporting (PR #1487).

```r
mod_quasi2 |>
  tbl_regression(exponentiate = TRUE) |>
  add_global_p(keep = TRUE) |>
  add_vif()
```

Source: <https://larmarange.github.io/guide-R/donnees_ponderees/regression-logistique-binaire-ponderee.html>

### Visual counterpart: `ggstats::ggcoef_model()`

Forest-plot equivalent of `tbl_regression()`, same model object, same broom.helpers backend, no re-tidying:

```r
mod1 <- lm(Fertility ~ ., data = swiss)
ggstats::ggcoef_model(mod1)
```

Also: `ggcoef_table()`, `ggcoef_compare()`, `gglikert()`, `stat_cross()`. Source: <https://larmarange.github.io/ggstats/>.

## Decision flow: picking the right table verb

1. **Baseline characteristics by arm** → `tbl_summary(by = trt)` + `add_p()` + `add_overall()`.
2. **One regression model** → `tbl_regression(fit, exponentiate = TRUE)` + `add_global_p()` for factors.
3. **Many univariable models** → `tbl_uvregression(method = ..., y = ...)`.
4. **Survival** → `tbl_survfit()` for KM, `tbl_uvregression(method = coxph, y = Surv(...))` for hazards.
5. **Survey/weighted design** → `tbl_svysummary()` then `svyglm() |> tbl_regression()`.
6. **Subgroup analyses** → `tbl_strata(strata = ..., ~ .x |> tbl_summary(...))`.
7. **Multi-model side-by-side** → build separately, combine with `tbl_merge()` + `tab_spanner`.
8. **Multiple imputation** → `tbl_regression(..., tidy_fun = pool_and_tidy_mice)`.
9. **Need a tidier option not exposed** → drop to `broom.helpers::tidy_plus_plus()` directly, or pass through `...`.
10. **Output format**: HTML → `as_gt()` (default); Word → `as_flex_table()`; LaTeX → `as_kable_extra()`; xlsx → `as_hux_xlsx()`.

## Sources

### Sjoberg / official docs

- [gtsummary site](https://www.danieldsjoberg.com/gtsummary/): landing
- [tbl_summary article](https://www.danieldsjoberg.com/gtsummary/articles/tbl_summary.html)
- [tbl_regression article](https://www.danieldsjoberg.com/gtsummary/articles/tbl_regression.html)
- [Themes article](https://www.danieldsjoberg.com/gtsummary/articles/themes.html) and [theme reference](https://www.danieldsjoberg.com/gtsummary/reference/theme_gtsummary.html)
- [Gallery](https://www.danieldsjoberg.com/gtsummary/articles/gallery.html)
- [inline_text article](https://www.danieldsjoberg.com/gtsummary/articles/inline_text.html)
- [Function index](https://www.danieldsjoberg.com/gtsummary/reference/index.html)
- [Repo `ddsjoberg/gtsummary`](https://github.com/ddsjoberg/gtsummary): v2.5.0 (2025-12-05), commit `952b665` (2026-03-16)

### Larmarange ecosystem

- [`broom.helpers` site](https://larmarange.github.io/broom.helpers/) and [tidy article](https://larmarange.github.io/broom.helpers/articles/tidy.html)
- [`labelled` site](https://larmarange.github.io/labelled/) and [intro](https://larmarange.github.io/labelled/articles/intro_labelled.html)
- [`ggstats` site](https://larmarange.github.io/ggstats/)
- [guide-R (active French reference)](https://larmarange.github.io/guide-R/): gtsummary embedded in regression chapters and weighted-data section
- [analyse-R gtsummary chapter (frozen 2022, most complete French intro)](https://larmarange.github.io/analyse-R/gtsummary.html)
- [Larmarange's PRs on gtsummary](https://github.com/ddsjoberg/gtsummary/pulls?q=is%3Apr+author%3Alarmarange)

### Pharma / ARD ecosystem

- [`cards`](https://github.com/insightsengineering/cards): foundational ARD container (insightsengineering org, Roche-led)
- [`cardx`](https://github.com/insightsengineering/cardx): supplements, co-maintained by Emily de la Rua (`edelarua`), #2 contributor on gtsummary itself (243 commits)
- [`crane`](https://github.com/insightsengineering/crane): gtsummary supplements for pharma reporting; created by Sjoberg, maintained by Joe Zhu (Roche)
- [`tern`](https://github.com/insightsengineering/tern): clinical trial Tables/Listings/Graphs (NEST stack); top non-Sjoberg contributor: Davide Garolini (`Melkiades`, Roche)
- [`tfrmt`](https://github.com/GSK-Biostatistics/tfrmt): display-metadata DSL for CDISC TFLs from ARD; Christina Fillmore (GSK Biostatistics)
- [gtsummary contributors graph](https://github.com/ddsjoberg/gtsummary/graphs/contributors): for contributor ranks cited above

### Adjacent prose-from-model

- [`easystats::report()`](https://easystats.github.io/report/) by Dominique Makowski et al.: auto-generates English narrative from a model object; complement to `inline_text()`
