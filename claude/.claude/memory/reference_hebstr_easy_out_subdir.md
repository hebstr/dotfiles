---
name: hebstr easy_out writes per-output folders in kebab-case
description: Breaking changes to hebstr::easy_out() at sha 97e8829 — per-output subfolder, kebab-case names, easy_out_map() removed, filename now required for unnamed objects — and what a project must do to catch up
metadata:
  type: reference
---

`hebstr` sha `97e8829` (pulled 2026-08-31 by an unrelated `rv add`, since the dependency tracks branch `main`) changes `easy_out()` in four ways that hit every project on the stack.

**Per-output folder, kebab-case names.** `easy_out(fig_surv_strata)` now writes `output/fig-surv-strata/fig-surv-strata.svg` where it wrote `output/fig_surv_strata.svg`. The new `subdir` argument defaults to `TRUE`; pass a string to name the folder, or `FALSE` for the old flat layout. File names are kebab-case either way. The folder is derived before `suffix`, so variants of one output share it.

**The break is silent.** Files written flat by earlier runs stay where they are, nothing errors, and a hard-coded `knitr::include_graphics("output/fig_flowchart.svg")` keeps resolving — to an artefact no run refreshes. Catching up means deleting the old contents of the output directory and repointing hard-coded paths. In a repo that tracks its artefacts, that is a git operation the user owns.

**`easy_out_map()` is removed**, folded into `easy_out()`: hand it a named list and it writes the elements one by one. `easy_out_map(plots, filename = "fig")` becomes `easy_out(plots, filename = "fig")`. A call to the removed function aborts the whole render, so this is the one to grep for first after a sync.

**`filename` is now required when the object is not passed by name**, because the default deparsed the expression and named the folder after it. `easy_out(get_xlsx(checklist))` used to write `get-xlsx-checklist/`. A bare symbol still works.

**One limitation lifted**: the class guard now accepts `htmlwidget`, `flextable` and `hebstr_dict` alongside ggplot, ggmatrix, gt, gtsummary, wbWorkbook and grid grobs. Project docs asserting that `easy_out()` refuses a `reactable` are stale.

Related: [[reference_hebstr_theme_bar_facets]], [[reference_hebstr_outdec_locale_flag]], [[project_hebstr_add_note_migration]].
