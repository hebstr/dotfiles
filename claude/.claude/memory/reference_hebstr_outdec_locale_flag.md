---
name: hebstr OutDec locale flag leaks into third-party numeric round-trips
description: hebstr uses global options(OutDec) as its EN/FR locale flag; it breaks any third-party package that does as.numeric(format(x)) (tidycmprsk::cuminc) or pastes a number into a machine-read string (gt::pct into a CSS unit). Workaround, not source-refactor.
metadata:
  type: reference
---

`hebstr::lang_fr()` sets `options(OutDec = ",")` globally, and hebstr reads `getOption("OutDec")` as its **package-wide EN/FR locale flag** (not merely a number format): `set_opts` in `opts.R` (the wording switch and the decimal marks), `easy_descr()`, `acro()` in `acro_helpers.R`, `gtsum_format()` (the `beta` and `adj_label` templates), `gt_heatmap()` (`dec_mark`, `sep_mark`) and the label and `decimal.mark` localisation in `easy_helpers.R`; `rg 'getOption\("OutDec"\)' R/` lists them all. So the comma OutDec is load-bearing by design; removing it breaks French wording across the package.

Consequence: the comma decimal mark leaks into any third-party package that formats a number to string then re-parses it with `as.numeric()`. `tidycmprsk::cuminc()` does exactly this in `cuminc_matrix_to_df` (event-time column names -> `as.numeric("29,47")` -> NA -> `missing value where TRUE/FALSE needed`). The next package doing a numeric round-trip will break the same way.

**Second victim, measured 2026-11-02 in eds-prise: a number pasted into a CSS unit.** `gt::pct()` is `paste0(x, "%")` on a numeric-mode argument, so a fractional column share comes out `"22,7456258411844%"` and gt aborts with `is not a valid CSS unit`, which broke `quarto render` on the one `tbl_decl()` caller whose width shares are not integers. The fix stays in the string rather than around the call: `paste0(sprintf("%.15g", share), "%")`, since `sprintf()` ignores `OutDec` where `as.character()` and `formatC()` both honour it, and `%.15g` reproduces the already published strings character for character. The rule to carry: under a French session, any number that becomes a machine-read string (CSS unit, URL, JSON, file name, SQL literal) goes through `sprintf()`, and a dot is never forced around a hebstr call, which would flip the package's own wording.

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
