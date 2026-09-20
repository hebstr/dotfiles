---
domain: biostat
author: heiss
topic: bayes
sources:
  - kind: blog
    url: https://www.andrewheiss.com/blog/2022/11/29/conditional-marginal-marginaleffects/
    published: 2022-11-29
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2022/09/26/guide-visualizing-types-posteriors/
    published: 2022-09-26
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2021/11/08/beta-regression-guide/
    published: 2021-11-08
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2022/05/09/hurdle-lognormal-gaussian-brms/
    published: 2022-05-09
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2021/12/01/multilevel-models-panel-data-guide/
    published: 2021-12-01
    captured: 2026-04-25
  - kind: blog
    url: https://www.andrewheiss.com/blog/2022/05/20/marginalia/
    published: 2022-05-20
    captured: 2026-04-25
---

# Biostat: Heiss patterns for Bayesian marginal effects (brms + marginaleffects + tidybayes)

Reference for Andrew Heiss's idioms on extracting and visualizing posteriors from `brms` models.
Source: <https://www.andrewheiss.com/blog/> (captured 2026-04-25).

This is a **delta** on top of the installed `r-skills:r-bayes` skill, which already covers DAGs, priors, multilevel formulas, lagged predictors, posterior extraction, and basic AME via `avg_slopes()` / `predictions()` / `datagrid()`. The Heiss material adds:

1. The conditional-vs-marginal distinction in multilevel Bayesian models
2. A taxonomy of three posterior types (link / expectation / prediction)
3. Three regimes of `re_formula` (NA / NULL / specified) and what each computes
4. Non-Gaussian families: Beta and Hurdle Lognormal, with formulas and interpretation
5. When to use `epred_draws()` vs `linpred_draws()` vs `predicted_draws()` (tidybayes)

## Two senses of "marginal", disambiguated first

The word "marginal" gets reused in two distinct ways and Heiss uses both. Treat them as separate concepts:

- **Marginal effect (AME sense)**: averaging a per-row effect across the rows of the dataset. Same as in frequentist `marginaleffects`. The opposite is *Marginal Effect at the Mean (MEM)* or *at representative values*. This is the focus of the older [marginalia post](https://www.andrewheiss.com/blog/2022/05/20/marginalia/).
- **Marginal effect (multilevel sense)**: *population-level*, with random offsets $b_{0_j}$ integrated out (vs. *conditional* = a single typical cluster with $b_{0_j} = 0$). This is the focus of [conditional-marginal-marginaleffects](https://www.andrewheiss.com/blog/2022/11/29/conditional-marginal-marginaleffects/).

Both senses can coexist on the same call (e.g. an *average* marginal effect at the *population* level).

## Conditional vs marginal in multilevel models

From [conditional-marginal-marginaleffects](https://www.andrewheiss.com/blog/2022/11/29/conditional-marginal-marginaleffects/) (2022-11-29):

- **Conditional effect**: "average or typical cluster; random offsets $b_{0_j}$ set to 0" → group-specific / cluster-specific / country-specific effect.
- **Marginal effect**: "global/population-level effect; clusters on average; random offsets incorporated" → population-level average effect.

Heiss's mnemonic: *"Conditional effect = average child"* vs *"Marginal effect = children on average"*.

## `re_formula`: three regimes

This is the operational knob. Same call signature, three radically different meanings:

```r
# Regime 1 — re_formula = NA: CONDITIONAL (typical cluster, b_0j = 0)
predictions(
  fit,
  newdata = datagrid(TX = c(0, 1)),
  by = "TX",
  re_formula = NA
)

# Regime 2 — re_formula = NULL on observed clusters: MARGINAL over observed groups only
predictions(
  fit,
  newdata = datagrid(TX = c(0, 1),
                     cluster = unique),
  by = "TX",
  re_formula = NULL
)

# Regime 3 — re_formula = NULL with hypothetical clusters: TRULY MARGINAL
# (matches analytical population-level formulas)
predictions(
  fit,
  newdata = datagrid(TX = c(0, 1),
                     cluster = c(-1:-100)),
  re_formula = NULL,
  allow_new_levels = TRUE,
  sample_new_levels = "gaussian",
  by = "TX"
)
```

The trick of Regime 3: synthesizing 100 fake cluster IDs (`c(-1:-100)`), allowing new levels, and sampling them from the estimated random-effects distribution. That is what reproduces the analytical population-level estimate. Averaging only over observed clusters (Regime 2) is *not* the same thing if the observed clusters are not a representative sample of the population.

Same idea applies to `comparisons()`:

```r
comparisons(
  fit,
  variables = "TX",
  re_formula = NA      # conditional
) %>%
  tidy()
```

## Three types of posterior: taxonomy

From [guide-visualizing-types-posteriors](https://www.andrewheiss.com/blog/2022/09/26/guide-visualizing-types-posteriors/) (2022-09-26):

| Function (brms / tidybayes) | Scale | What you get | Interval width |
|---|---|---|---|
| `posterior_linpred()` / `linpred_draws()` | **link** (logit, log) by default | μ alone, the linear predictor | narrowest |
| `posterior_epred()` / `epred_draws()` | **response** (probability, value) | E(y), the expectation of the predictive distribution | medium |
| `posterior_predict()` / `predicted_draws()` | **response** | full draws from the predictive distribution (parameter uncertainty + observation noise) | widest |

Key clarifications from the post:

- For Gaussian regression, `linpred` and `epred` are **identical** because $E(y) = \mu$.
- For logistic regression, they differ by **scale only** (logit vs probability): `epred = plogis(linpred)`.
- For **lognormal** models, `epred` uses a non-trivial formula: $\exp(\mu + \sigma^2 / 2)$, *not* a simple back-transform. This is one of the few places where you must use `epred`, not `linpred(..., transform = TRUE)`.

Auxiliary parameters are accessed with `dpar`:

```r
beta_linpred_phi <- model_beta |>
  linpred_draws(newdata = penguins_avg_flipper, dpar = "phi")

beta_linpred_phi_trans <- model_beta |>
  linpred_draws(newdata = penguins_avg_flipper, dpar = "phi", transform = TRUE)
```

Standard call shape with `tidybayes`:

```r
penguins |>
  data_grid(flipper_length_mm = seq_range(flipper_length_mm, n = 100)) |>
  add_epred_draws(model_normal, ndraws = 100)
```

## Beta regression: modeling proportions

From [beta-regression-guide](https://www.andrewheiss.com/blog/2021/11/08/beta-regression-guide/) (2021-11-08):

```r
model_beta_bayes <- brm(
  bf(prop_fem ~ quota,
     phi ~ quota),
  data = vdem_2015_fake0,
  family = Beta(),
  chains = 4, iter = 2000, warmup = 1000,
  cores = 4, seed = 1234,
  backend = "cmdstanr",
  file = "model_beta_bayes"
)
```

Interpretation:

- μ component on **logit scale** → use `plogis()` to back-transform.
- φ (precision) on **log scale**, modeled separately via `phi ~ ...` inside `bf()`.
- Variants: **zero-inflated beta** (mixture logistic + beta), **zero-one-inflated beta (ZOIB)** with α (P=0), γ (P=1), μ, φ.

Marginal effects:

```r
model_beta_bayes %>%
  avg_comparisons(variables = "quota")
```

```r
beta_bayes_pred <- model_beta_bayes %>%
  epred_draws(newdata = tibble(quota = c(FALSE, TRUE)))

beta_bayes_pred_diff <- beta_bayes_pred %>%
  compare_levels(variable = .epred, by = quota)
```

## Hurdle Lognormal: outcomes with structural zeros

From [hurdle-lognormal-gaussian-brms](https://www.andrewheiss.com/blog/2022/05/09/hurdle-lognormal-gaussian-brms/) (2022-05-09):

```r
model_gdp_hurdle_life <- brm(
  bf(gdpPercap ~ lifeExp,
     hu ~ lifeExp),
  data = gapminder,
  family = hurdle_lognormal(),
  chains = CHAINS, iter = ITER, warmup = WARMUP, seed = BAYES_SEED,
  silent = 2
)
```

Heiss's framing:

> "Define a mixture of models for two separate processes: (1) A model that predicts if the outcome is zero or not zero; (2) If the outcome is not zero, a model that predicts what the value of the outcome is."

Three components to interpret separately:

- **`hu`**: logistic regression on P(y = 0), logit scale; convert to percentage points with `regrid = "response"`.
- **`mu`**: lognormal on the magnitude of non-zeros, log scale → back-transform.
- **`epred`**: combined expectation, integrating both processes.

Targeting one component at a time with marginaleffects:

```r
model_gdp_hurdle_life |> comparisons(
  newdata = datagrid(lifeExp = seq(30, 80, 10)),
  dpar = "mu",
  transform_pre = "expdydx"
)

pred_gdp_hurdle_life <- model_gdp_hurdle_life |>
  predicted_draws(newdata = tibble(lifeExp = c(40, 70)))
```

`emmeans` equivalents:

```r
model_gdp_hurdle_life |>
  emtrends(~ lifeExp, var = "lifeExp", dpar = "mu",
           regrid = "response", tran = "log", type = "response",
           at = list(lifeExp = seq(30, 80, 10)))

model_gdp_hurdle_life |>
  emmeans(~ lifeExp, var = "lifeExp", dpar = "hu",
          regrid = "response",
          at = list(lifeExp = seq(30, 80, 10)))
```

## Country-year panel: multilevel formulas worth copying

From [multilevel-models-panel-data-guide](https://www.andrewheiss.com/blog/2021/12/01/multilevel-models-panel-data-guide/) (2021-12-01), useful reference patterns:

```r
bf(lifeExp ~ year + (1 | continent))
bf(lifeExp ~ year + (1 | country))
bf(lifeExp ~ year + (1 + year | country))
bf(lifeExp ~ year + (1 | year) + (1 + year | country))
bf(lifeExp ~ year + (1 + year | continent / country))
bf(lifeExp ~ gdpPercap_log_z + year + (1 + gdpPercap_log_z | country),
   decomp = "QR")
```

Group-specific predictions with `epred_draws(..., re_formula = NULL)` or `emmeans(..., re_formula = NULL)`.

## Decision flow

When you have a brms multilevel model and want to report an effect:

1. **Pick the sense of "marginal".** Cluster-typical (conditional) or population-level (marginal in the GLMM sense)?
2. **Pick the scale.** Link (`linpred_draws`, narrow intervals, native units) or response (`epred_draws`, back-transformed) or full predictive (`predicted_draws`, widest)?
3. **Set `re_formula` accordingly.** `NA` = conditional. `NULL` + observed clusters = marginal over observed. `NULL` + synthetic clusters with `allow_new_levels = TRUE, sample_new_levels = "gaussian"` = truly marginal.
4. **Choose the verb.** `predictions()` = predicted values. `comparisons()` / `avg_comparisons()` = differences in predictions. `slopes()` / `avg_slopes()` = derivatives.
5. **For multi-component families** (Beta, Hurdle, ZOIB), pass `dpar` to target a single component, or use `epred` to integrate them.

## Sources

- [Marginal and conditional effects for GLMMs with marginaleffects](https://www.andrewheiss.com/blog/2022/11/29/conditional-marginal-marginaleffects/) (2022-11-29): the `re_formula` post.
- [Visualizing the differences between Bayesian posterior predictions, linear predictions, and the expectation of posterior predictions](https://www.andrewheiss.com/blog/2022/09/26/guide-visualizing-types-posteriors/) (2022-09-26): the linpred / epred / predicted taxonomy.
- [A guide to modeling proportions with Bayesian beta and zero-inflated beta regression models](https://www.andrewheiss.com/blog/2021/11/08/beta-regression-guide/) (2021-11-08): Beta family + ZOIB.
- [A guide to modeling outcomes that have lots of zeros with Bayesian hurdle lognormal and hurdle Gaussian regression models](https://www.andrewheiss.com/blog/2022/05/09/hurdle-lognormal-gaussian-brms/) (2022-05-09): hurdle decomposition with `dpar`.
- [A guide to working with country-year panel data and Bayesian multilevel models](https://www.andrewheiss.com/blog/2021/12/01/multilevel-models-panel-data-guide/) (2021-12-01): multilevel formula patterns.
- [Marginalia](https://www.andrewheiss.com/blog/2022/05/20/marginalia/) (2022-05-20): AME vs MEM in the *frequentist* sense, cited here only to disambiguate the two meanings of "marginal".
