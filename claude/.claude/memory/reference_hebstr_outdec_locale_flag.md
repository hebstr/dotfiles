---
name: hebstr OutDec locale flag leaks into third-party numeric round-trips
description: hebstr uses global options(OutDec) as its EN/FR locale flag; it breaks any third-party package that does as.numeric(format(x)) (e.g. tidycmprsk::cuminc). Workaround, not source-refactor.
metadata:
  type: reference
---

`hebstr::lang_fr()` sets `options(OutDec = ",")` globally, and hebstr reads `getOption("OutDec")` as its **package-wide EN/FR locale flag** (not merely a number format): `set_opts` (opts.R:242 wording switch + 191/195 decimal marks), `easy_descr.R:136`, `acro_helpers.R:159`, `gtsum_format.R:329`, `gt_heatmap.R:137-138`, `easy_helpers.R:114/629`. So the comma OutDec is load-bearing by design; removing it breaks French wording across the package.

Consequence: the comma decimal mark leaks into any third-party package that formats a number to string then re-parses it with `as.numeric()`. `tidycmprsk::cuminc()` does exactly this in `cuminc_matrix_to_df` (event-time column names -> `as.numeric("29,47")` -> NA -> `missing value where TRUE/FALSE needed`). The next package doing a numeric round-trip will break the same way.

**Workaround (proportionate, in use):** force a dot decimal mark only around the fit; gtsummary display keeps the session comma because gtsummary formats via its theme `decimal.mark`, not OutDec.
```r
cuminc_num <- \(formula, data) {
  op <- options(OutDec = ".")
  on.exit(options(op))
  tidycmprsk::cuminc(formula, data = data)
}
```
Verified: `label_style_percent`/`style_number` stay `,` under a French gtsummary theme even with `OutDec="."`, so tables/figures are unaffected.

**Decision (2026-07-10):** keep the confined workaround; do NOT refactor hebstr's locale mechanism (private `.hebstr$lang` flag + explicit theme decimal.mark across 7 files + tests + rv reinstall). Cross-project blast radius, disproportionate to trigger from one tidycmprsk interaction. Do not re-propose the refactor unless hebstr's locale design is being reworked for its own sake. hebstr dev clone: `~/Documents/packages/R-hebstr/`.

Related: [[feedback_review_severity_hebstr]], [[reference_r_check_separable_model_tests]].
