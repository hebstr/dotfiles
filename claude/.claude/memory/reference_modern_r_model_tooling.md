---
name: Modern R tooling for model evaluation, comparison, and effect interpretation
description: Current-practice R packages (easystats, broom, yardstick, marginaleffects) for evaluating/comparing models and interpreting effects; reference for tool selection, surface when tool choice is in play or on user request
metadata:
  type: reference
---

Current-practice R packages for model evaluation, comparison, and effect interpretation. This is reference knowledge about **tool selection**, in the same logic as the rest of the user's stack (idiomatic tidyverse, always the current recommended form): the user (biostatistician) values staying up to date on tooling. It is NOT about interpreting the user's data, which is the user's domain and which Claude has no access to anyway.

How to use this memory: surface these when the choice of tool is in play or when the user asks. Do not impose them spontaneously on analysis code, and when a script shows a formula by hand on purpose (e.g. pedagogical), that is the user's call. The user adopted these readily when directed (easystats and marginaleffects both came up and were accepted in a sandbox session).

The set: easystats `performance` and `parameters`, broom, yardstick (tidymodels), marginaleffects; their function surfaces are in the package docs.

**marginaleffects version note:** in marginaleffects >= 0.32 the string `hypothesis = "pairwise"` is rejected (use the formula `~pairwise`), and the package nudges from `"b1=b2"` toward `"b1 - b2 = 0"`.

**Methodological caveat (tooling currency, not data interpretation):** pseudo-R2 is not meaningful across a non-Gaussian GLM (Gamma/Poisson); AIC/BIC are the trustworthy comparison currency. easystats docs concede this.

See [[user_profile]].
