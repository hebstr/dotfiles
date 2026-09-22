---
name: QUARTO_R overrides PATH and defeats rv version pins
description: Quarto resolves R through the exported QUARTO_R, not PATH, so an rv project pinned to another r_version silently enters safe mode and the render fails on "knitr is not available" rather than on the version mismatch
metadata:
  type: reference
---

`QUARTO_R` is set in the environment and **Quarto honours it over `PATH`**. No shell profile sets it (`rg QUARTO_R` finds nothing in `~/dotfiles`, `~/.profile` or `/etc/profile.d`, 2026-09-22); a session started from Positron's integrated terminal sees `QUARTO_R=/opt/R/current/bin`, where `/opt/R/current` resolves to the same R as `/usr/local/bin/R` (4.6.1 that day). On 2026-08-29 it read `/opt/R/4.6.0/bin`, a version since removed. Check `echo $QUARTO_R` in the shell that will render rather than assuming either value.
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

Whether `rig default <version>` moves Quarto depends on the value: with `QUARTO_R=/opt/R/current/bin` it follows whatever `/opt/R/current` resolves to, while a value naming a versioned directory (the 2026-08-29 case) stays put. Neither makes Quarto honour an `rv` pin.
`rig list` shows which versions are installed.

The durable question this leaves open, unresolved as of 2026-09-22: a set `QUARTO_R` makes every `rv` pin inoperative under Quarto, silently degrading instead of failing on the version. Either the variable goes and Quarto follows `PATH`, or each pinned project needs the per-command override above.

Related: [[feedback_review_severity_shell_installers]] (threat model on the multi-user servers)
