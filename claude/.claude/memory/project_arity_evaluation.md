---
name: Arity evaluated and rejected as air + jarl replacement
description: Arity 0.23.0 tested 2026-09-10 against air 0.11.0 + jarl 0.6.0 and not adopted; two blockers that configuration cannot reach; full measurements in ~/dotfiles/_meta/notes/arity-trial.md, do not redo them
metadata:
  type: project
---

Arity (jolars/arity), a Rust formatter + linter + LSP for R, was evaluated on 2026-09-10 as a single-binary replacement for `air` 0.11.0 and `jarl` 0.6.0, and not adopted. The binary sits in `~/.local/bin/arity`, outside the gate, kept for watching the project; `rm ~/.local/bin/arity && rm -rf ~/.cache/arity` reverts it.

Two blockers, neither reachable by configuration:

- **The formatter recompacts hand-written line breaks.** Arity has no equivalent of air's `persistent-line-breaks`, and the absence is a design decision pinned by the repo's own test fixture `crates/arity-formatter/tests/fixtures/formatter/call_user_line_breaks/input.R`, whose first line reads `# Unlike air, Arity doesn't cater to user line breaks`. It follows from tenet 1, "the formatter is the sole layout authority". Measured across the fourteen projects carrying an `air.toml`, each at its own declared line width: air reports one file, arity would rewrite roughly nine in ten.
- **`arity lint --fix` strips rlang's `!!`.** The `comparison-negation` rule reads `!!var < inf` as the double negation R's grammar actually parses, and its fix is classed *safe*, so it applies without `--unsafe-fixes`. The corpus carries 341 `!!` lines across 110 files. Contrast: jarl refuses to apply any fix outside a version-controlled tree.

Two further findings, reproduced on v0.23.0, undocumented and unreported upstream as of that date: `undefined-symbol` flags the native pipe placeholder (`x <- 1:3 |> sum(x = _)` evaluates to 6 in R and is flagged), and the same rule fires on every verb name in a hebstr-stack analysis project because the session is attached by `.Rprofile` and `setup.R` rather than by a `library()` call inside the linted file. Arity's data-masking model itself works: it does not flag masked columns. No config key declares a package attached elsewhere.

Revisit trigger: an upstream `persistent-line-breaks` equivalent, or a `comparison-negation` carve-out for rlang injection. Neither is on the published roadmap; arity has no milestones and no open issues, its planning living in an unpublished `TODO.md`, and `versionary.jsonc` sets `bump-minor-pre-major`, so breaking changes land in minor bumps. Sole author, 1073 of its commits against bots for the rest.

**Why:** The evaluation cost a full session of measurement against the real corpus, and the two blockers are structural rather than version-bound, so re-testing on the next release would repeat the same work for the same answer.
**How to apply:** Keep `air format` then `jarl check` as the R gate ([[feedback_r_environment]]). Do not propose arity as a drop-in replacement. `arity lint --select` restricted to the `packaging` and `documentation` families remains a live option for `R-hebstr` and `R-edstr` roxygen and DESCRIPTION checks, ground jarl does not cover; it never invokes the formatter. Full trace, replayable with `showboat verify`, in `~/dotfiles/_meta/notes/arity-trial.md`.
