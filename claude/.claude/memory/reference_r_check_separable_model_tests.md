---
name: R model-tidying tests fail under R CMD check when the model is separable
description: Tests that build a model then tidy it (gtsummary/broom.helpers) can pass devtools::test() but fail R CMD check when the fitted model is perfectly separable; de-separate the data and run check() not just test()
metadata:
  type: reference
---

An R package test that fits a model (`glm`, ...) then tidies it (`gtsummary::tbl_regression`, `broom.helpers::tidy_plus_plus`) can pass `devtools::test()` / `devtools::load_all()` yet **fail under `R CMD check`** with an opaque `broom.helpers` error (`Unable to tidy \`x\``).

Root cause: a **perfectly separable** model (a predictor deterministically predicts the response, e.g. `y = rep(c(0,1),30)` aligned 1:1 with `sex = rep(c("f","m"),30)`) makes `glm` diverge (fitted probabilities 0/1, huge coefficients). Tidying such a model is unstable and errors under the installed-package full-suite context of `R CMD check`, while passing in the dev/isolated contexts.

Why the gap: `devtools::test()` sets `NOT_CRAN=true` and runs against the source namespace; `R CMD check` runs the built+installed package, whole suite in one session, no `NOT_CRAN`. The failure only surfaces in that stricter context.

Guards:
- Design test model data to be **non-separable**: decouple the response from predictors (different periods, or a genuine noisy relationship). A well-conditioned fit shows finite, modest coefficients (`max(abs(coef)) ~ 1`, no "fitted probabilities 0 or 1" warning).
- After adding a model-tidying test, run `devtools::check()`, not only `devtools::test()`. A green `test()` does not imply a green `check()` for this class of test.

Concrete instance: hebstr `test-gtsum_format.R:142` (2026-07-05). Fixed by `y = rep(c(0,1,1,0,1,0),10)` (period 6) vs `sex` (period 2), `x = seq_len(60)`; removed the `suppressWarnings` on the now-clean `glm`.
