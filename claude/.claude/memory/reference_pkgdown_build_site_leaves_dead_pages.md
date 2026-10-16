---
name: pkgdown build_site() never removes a dead page
description: "pkgdown rebuilds: build_site() writes and overwrites but never deletes, so the reference page of a renamed or removed export survives every rebuild and only clean_site() drops it; the three `Deprecated: --mathml` warnings a build emits come from rmarkdown, not from the site, and nothing is to be chased there"
metadata:
  type: reference
---

`pkgdown::build_site()` writes and overwrites, it never removes: the reference page of a topic that no longer exists survives every rebuild, so a renamed or deleted export leaves a live page on the published site with nothing in the build log about it.

Measured on hebstr on 2026-09-15: `clean_site()` followed by `build_site()` dropped the pages of `add_code_file`, `easy_out_map` and `easy_view`, which repeated bare `build_site()` runs had kept. Run `clean_site()` first whenever a rebuild follows a rename or a removal, and check the published site rather than the log.

The same build emits three `[WARNING] Deprecated: --mathml`: `rmarkdown:::pandoc_math_args` (rmarkdown 2.32) still passes `--mathml` to pandoc 3.10. Upstream defect, no effect on the output, nothing to fix locally.

[[reference_pkgdown_ignores_rbuildignore]] [[reference_pkgdown_assets_extra_css]]
