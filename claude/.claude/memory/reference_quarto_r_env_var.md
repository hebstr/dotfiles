---
name: QUARTO_R overrides PATH and defeats rv version pins
description: Quarto resolves R through the exported QUARTO_R, not PATH, so an rv project pinned to another r_version silently enters safe mode and the render fails on "knitr is not available" rather than on the version mismatch
metadata:
  type: reference
---

`QUARTO_R` is exported in the shell profile (measured at `/opt/R/4.6.0/bin` on 2026-08-29) and **Quarto honours it over `PATH`**.
Prefixing `PATH` with another R's `bin` therefore changes nothing: `command -v Rscript` resolves to the other version while Quarto still runs the one `QUARTO_R` names.

The failure mode this creates on an `rv` project is misleading.
When `rproject.toml` pins `r_version = "4.5"` and `QUARTO_R` points at 4.6, `rv` refuses to activate the project library, enters safe mode, and creates an empty temporary library (`/tmp/Rtmp*/__rv_R_mismatch`).
The render then dies on `there is no package called 'rmarkdown'` and `The knitr package is not available in this R installation`, which reads as a missing-dependency problem.
The version mismatch is stated only in a `WARNING` line above it, easy to scroll past.
Installing knitr would be the wrong fix.

For a one-off render against the pinned version, override the variable for that command alone, which touches no global state:

```bash
QUARTO_R=/opt/R/4.5.3/bin quarto render doc.qmd
```

`rig default <version>` is not a substitute: it repoints `/usr/local/bin/R` and leaves `QUARTO_R` as it was, so Quarto keeps using the old one.
`rig list` shows which versions are installed.

The durable question this leaves open, unresolved as of 2026-08-29: an exported `QUARTO_R` makes every `rv` pin inoperative under Quarto, silently degrading instead of failing on the version. Either the variable goes and Quarto follows `PATH`, or each pinned project needs the per-command override above.

Related: [[project_rv_install_deployment]]
