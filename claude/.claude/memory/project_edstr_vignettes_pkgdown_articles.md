---
name: edstr vignettes — plain-html, CRAN + pkgdown (hebstr-doc theme reverted)
description: Decision (2026-07-22, revised same day) — edstr vignettes use plain quarto html (pkgdown's own theme), shipped to CRAN again; the hebstr-doc standalone theme was tried and rolled back because it renders dirty inside pkgdown
metadata:
  type: project
---

Decision (2026-07-22): edstr's six vignettes render with the plain quarto `html` format (`vignettes/_quarto.yml`: `format: html` + `toc: true`, `echo: true`, `eval: false`). They ship to CRAN as normal vignettes AND are served as pkgdown articles, where pkgdown applies its own configured Bootstrap theme (`_pkgdown.yml`: primary `#0099FF`, Fira Code, Luciole via `pkgdown/extra.scss`, light-switch).

**Reverted experiment (same day):** the vignettes were briefly switched to the `hebstr-doc-html` standalone theme (`quarto add hebstr/quarto-hebstr-doc`, from [[project_hebstr_doc_adaptive_figures]]) and dropped from CRAN. Rolled back because it rendered dirty: `hebstr-doc-html` is a *standalone* full-page theme (`embed-resources`, its own compiled Bootstrap, full-page grid with 450px margins, low-contrast body color tuned for its own background). pkgdown extracts the vignette body plus Quarto's embedded `<style>` blocks and injects them into its own Bootstrap page, so the two themes fight → light-gray unreadable body text, wrong fonts. A standalone Quarto theme cannot cleanly live inside a pkgdown article; there is no contrast tweak that fixes it. Plain-html render is ~27 KB with zero Luciole/hebstr refs vs 2.2 MB themed.

**Cleanup left for the user:** `rm -rf vignettes/_extensions` (the untracked 2.1 MB hebstr theme extension; `rm` was denied to Claude twice — user manages deletions). The `include-code-files` extension was already dropped (no vignette used it).

**Reusable mechanism knowledge (kept for reference; NOT the current state):** to drop vignettes from a CRAN build, the lever is removing the `VignetteBuilder` field in DESCRIPTION, not `.Rbuildignore`. `R CMD build` builds vignettes into `inst/doc/` *before* applying `.Rbuildignore`, so `^vignettes$` alone excludes the source dir but the built HTML still ships (verified empirically). Removing `VignetteBuilder: quarto` stops the build entirely; combined with `^vignettes$` the tarball dropped to ~0.04 MB. pkgdown builds `vignettes/*.qmd` as site articles regardless of `.Rbuildignore`. This was the size-mitigation for the 3.1 MB themed vignettes; with the theme gone the size blocker is void, so `VignetteBuilder: quarto` is restored and `^vignettes$` removed from `.Rbuildignore`.

Keep the `%\VignetteIndexEntry` / `%\VignetteEngine{quarto::html}` front matter. Stale quarto freeze (`vignettes/.quarto`) once caused mixed themed/lean output; clear it before a verification render. Regenerating the pkgdown site (`pkgdown::build_site()`) is the user's git-controlled op.
