---
name: Modern R tooling for model evaluation, comparison, and effect interpretation
description: Current-practice R packages (easystats, broom, yardstick, marginaleffects) for evaluating/comparing models and interpreting effects; reference for tool selection, surface when tool choice is in play or on user request
metadata:
  type: reference
---

Current-practice R packages for model evaluation, comparison, and effect interpretation. This is reference knowledge about **tool selection**, in the same logic as the rest of the user's stack (idiomatic tidyverse, always the current recommended form): the user (biostatistician) values staying up to date on tooling. It is NOT about interpreting the user's data, which is the user's domain and which Claude has no access to anyway.

How to use this memory: surface these when the choice of tool is in play or when the user asks. Do not impose them spontaneously on analysis code, and when a script shows a formula by hand on purpose (e.g. pedagogical), that is the user's call. The user adopted these readily when directed (easystats and marginaleffects both came up and were accepted in a sandbox session).

**Packages and what they cover:**
- **easystats `performance`** (in-sample fit comparison / diagnostics of lm/glm, incl. non-Gaussian families): `compare_performance()` ranks multiple models (different classes OK) on AIC/BIC/RMSE/R2/Sigma + weights in one call; `model_performance()` for a single model; `check_model()` for diagnostics (GLM-appropriate only on recent versions). RMSE/R2 are in-sample.
- **easystats `parameters`**: `model_parameters()` is the broom `tidy()` alternative with CI/p-values/dof built in and `exponentiate` for log/logit links (exponentiates CIs too).
- **broom**: `tidy/glance/augment` for single-model tidying (idiomatic in tidyverse pipelines); no cross-model comparison function, that gap is what `compare_performance()` fills.
- **yardstick** (tidymodels): predictive evaluation on a data frame of predictions (truth/estimate columns), ideally on held-out/resampled data (rsample). Not for in-sample GLM fit comparison.
- **marginaleffects**: puts every quantity on the response scale, so coefficients that are not directly comparable (lm additive grams vs Gamma-log multiplicative) become comparable. Core surface: `avg_slopes()` (AME, dy/dx), `avg_predictions()`, `avg_comparisons()`; `plot_predictions()`/`plot_slopes()` for fitted curves and varying slopes; `hypothesis = ~pairwise` or positional `"b1 - b2 = 0"` for delta-method tests; `datagrid()` for grids. For interactions, `avg_slopes(..., by = group)` reads off per-group slopes directly instead of decoding interaction terms; `hypothesis = ~pairwise` tests whether the group slopes differ. Version note: in marginaleffects >= 0.32 the string `"pairwise"` is rejected (use the formula `~pairwise`), and the package nudges from `"b1=b2"` toward `"b1 - b2 = 0"`. Andrew Heiss is the reference popularizer the user knows.

**Methodological caveat (tooling currency, not data interpretation):** pseudo-R2 is not meaningful across a non-Gaussian GLM (Gamma/Poisson); AIC/BIC are the trustworthy comparison currency. easystats docs concede this.

See [[user_profile]].
