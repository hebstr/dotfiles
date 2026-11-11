---
name: hebstr easy_out writes per-output folders in kebab-case
description: Breaking changes to hebstr::easy_out() at sha 97e8829 — per-output subfolder, kebab-case names, easy_out_map() removed, filename now required for unnamed objects — what a project must do to catch up, and how easy_out() pairs with out_qmd() across the HTML and Word branches
metadata:
  type: reference
---

`hebstr` sha `97e8829` (pulled 2026-08-31 by an unrelated `rv add`, since the dependency tracks branch `main`) changes `easy_out()` in four ways that hit every project on the stack. The two sections on the Word branch and on `out_qmd()` are later behaviour of the same function, not part of that sha.

**Per-output folder, kebab-case names.** `easy_out(fig_surv_strata)` now writes `output/fig-surv-strata/fig-surv-strata.svg` where it wrote `output/fig_surv_strata.svg`. The new `subdir` argument defaults to `TRUE`; pass a string to name the folder, or `FALSE` for the old flat layout. File names are kebab-case either way. The folder is derived before `suffix`, so variants of one output share it.

**The break is silent.** Files written flat by earlier runs stay where they are, nothing errors, and a hard-coded `knitr::include_graphics("output/fig_flowchart.svg")` keeps resolving — to an artefact no run refreshes. Catching up means deleting the old contents of the output directory and repointing hard-coded paths. In a repo that tracks its artefacts, that is a git operation the user owns.

**`easy_out_map()` is removed**, folded into `easy_out()`: hand it a named list and it writes the elements one by one. `easy_out_map(plots, filename = "fig")` becomes `easy_out(plots, filename = "fig")`. A call to the removed function aborts the whole render, so this is the one to grep for first after a sync.

**`filename` is now required when the object is not passed by name**, because the default deparsed the expression and named the folder after it. `easy_out(get_xlsx(checklist))` used to write `get-xlsx-checklist/`. A bare symbol still works.

**Under a Word render `easy_out()` writes nothing**, `export` defaulting to `FALSE` when `options(hebstr.docx = TRUE)`: a table goes into the document instead of into a file of its own. `out_qmd()` publishes a table live on that branch, but a figure *always* through the file its script wrote, so a docx-only render on an emptied `output/` aborts on `knitr::include_graphics()`. A project whose figures must survive that render passes `export = TRUE` in each `fig_*.R` (measured 2026-11-03 on m2-dm3); a full `quarto render` hides the trap, the HTML pass having written the files first.

**`out_qmd()` derives its path from the deparsed argument**, so the binding name must equal the `easy_out()` `filename`: `out_qmd(fig_uv$demo)` reads `output/fig-uv/fig-uv-demo.svg`, which `easy_out(fig_uv)` on a named list produces, and which `easy_out(x, filename = "fig_uv", suffix = "demo")` produces too when the panels need different sizes. A list built under one name and written under another filename silently points at nothing.

**`png = TRUE` is inert on a gt or a gtsummary object**, measured 2026-11-11 on eds-prise: that branch of `easy_out()` writes the HTML with `gtsave()` and then the PNG with `webshot()` unconditionally, so a table always comes out in both formats, and the `png` argument governs the htmlwidget branch instead. Asking for the flag to get a PNG out of a table reads the argument list rather than the branch.

**`gt_format()` is soft-deprecated in favour of `tbl_format()`**, same function and same arguments, the alias warning once per session at the first call. Older projects on the stack (eds-avc) still call the deprecated name, so a pattern copied from them carries it in.

**One limitation lifted**: the class guard now accepts `htmlwidget`, `flextable` and `hebstr_dict` alongside ggplot, ggmatrix, gt, gtsummary, wbWorkbook and grid grobs. Project docs asserting that `easy_out()` refuses a `reactable` are stale.

Related: [[reference_hebstr_theme_bar_facets]], [[reference_hebstr_outdec_locale_flag]], [[project_hebstr_add_note_migration]].
