---
paths:
  - "**/*.R"
  - "**/*.r"
---

# R toolchain

## CLI tools

| Tool | Role |
|---|---|
| `air` | Formatter (config: `air.toml`) |
| `jarl` | Linter (static analysis) |

## Mandatory pipeline after every create/edit

```sh
air format script.R && jarl check script.R
```

Both are required: `air` formats only, `jarl` lints only. If the project has tests, run them after the format+lint gate: `testthat::test_file('tests/testthat/test-foo.R')`.

Run the `air` on the PATH, which is `/usr/local/bin/air`, kept current by `sys-update devtools`. The Positron extension ships its own copy under `~/.positron/extensions/posit.air-vscode-*/bundled/bin/air` and, left at its default `air.executableStrategy: "bundled"`, prepends it to the integrated terminal's PATH: the gate would then format with a binary the editor updates and `devtools-update` never sees. The setting is at `"environment"` so both resolve to the same file, with the bundle as fallback. Two formatters drifting apart show up as reformatting churn in diffs, never as an error, so check `command -v air` rather than trusting a clean run.

## Code style conventions

- Use the native pipe `|>`
- Use the lambda shorthand `\()` instead of `function()`; inside purrr map/walk, prefer tilde formula `~ .x` for simple expressions
- Use `here::here()` for paths, never absolute paths
- Outside an `rv`-managed project, install packages with `pak::pak()`, never `install.packages()`. Inside an `rv` project (presence of `rv.lock` or `rproject.toml`), use `rv add <pkg>` to keep the lockfile authoritative; never call `pak::pak()` against the project library
- Never use `renv`; `rv` replaces it for all project types; `DESCRIPTION` is canonical for packages
- For list-building from repeated calls, lead with purrr (`set_names()` + `map()`); base R only if asked or for a concrete performance reason
- Before recommending `@importFrom pkg fn` or `pkg::fn`, verify the function is exported: `Rscript -e "'fn_name' %in% getNamespaceExports('pkg')"` (returns `TRUE`/`FALSE`; more robust than `pkg::fn`, which can trigger package load side effects). This presupposes `pkg` is installed: an error like `there is no package called 'pkg'` means not installed, not "not exported". For a package under local development (not yet installed), use `devtools::load_all()` then `'fn_name' %in% getNamespaceExports('pkg')` instead

## Preserving analysis code

This code exists for a data science/biostatistics purpose. When editing it for infrastructure, code-quality, or refactoring reasons, do not alter its analysis semantics:

- Joins: always use explicit keys; check for NA on join keys after every join
- Domain-specific regex or business rules: do not "fix" or tighten without explicit domain validation
- LLM inference parameters (temperature, top_p, seed): do not change without documented justification (breaks reproducibility of existing results)
- Calculated approximations (e.g. age from date diff / 365.25): flag but do not auto-correct, often intentional for consistency with institutional conventions

## Analysis project conventions (hebstr stack)

Scope: R analysis projects on the `hebstr` stack, recognised by `hebstr` in `rproject.toml` together with a `scripts/_setup.R` sourced by the report `.qmd` and one `tbl_*` / `fig_*` script per output.
`~/Documents/services/md-nesrine/` is the reference implementation.
Read it before writing a kind of output the current project has no precedent for; these conventions are established elsewhere and are not to be reinvented locally.

**Placement**

- One script per output under `scripts/`, named `tbl_<name>.R` or `fig_<name>.R`, ending in `easy_out()` or `easy_out_map()`. `auto_exec()` sweeps them, and a leading underscore excludes a script from that sweep
- `scripts/_setup.R` holds the recoding and every object shared by more than one output script. A frame consumed by a single output belongs in that output's script
- Shared helpers live in the directory swept by `auto_exec()` from `.Rprofile` (`config/`, or `lib/`). A helper used by one script is defined in that script
- An output script selects and renders. When its frame is shared it does not read files, join, recode, or derive variables

**Data management**

- Categorical variables are coded as integers, their modalities declared in `easy_label(value = list(...))`, which converts them through `labelled::to_factor()`. Hand-written `factor(levels =, labels =)` duplicates the modality order between declaration and use
- `easy_label(variable = list(...))` carries every variable label, then `discard(~ is.null(var_label(.x)))` drops the unlabelled columns. Labelling is the selection mechanism, so intermediates disappear without an explicit `select(-...)`
- `easy_cut()` derives `{var}_cat` and leaves the continuous variable beside it
- `nanoparquet::read_parquet()` returns a `data.frame`, so `as_tibble()` at the read
- Dot-prefix what is internal to a setup or a script (`.surv`, `.model`); leave the deliverables bare (`df`, `tbl_*`, `fig_*`)

**gtsummary pipeline**

```
data |>
  select(...) |>
  use_vars() |>
  tbl_summary(by =, statistic = opts$vars$stat, digits = opts$digits, missing = "ifany", missing_text = opts$labs$row_missing) |>
  add_stat_label(label = opts$vars$label) |>
  gtsum_format() |>
  tbl_format(width =)
```

`select()` chooses the variables, which makes `include =` redundant.
`use_vars()` scans every column it is handed and stores the parametric/non-parametric split that `opts$vars$stat` resolves against, so a column left in the frame but absent from the table aborts `tbl_summary()` on a name it cannot select: restrict the frame first.
`gtsum_format()` calls `add_overall()` itself, so calling it beforehand collides on `stat_0`.

## Useful flags

**air format**

| Flag | Effect |
|---|---|
| `--check` | Dry-run, exits non-zero if file would change |

**jarl check**

| Flag | Effect |
|---|---|
| `--fix` | Auto-fix safe issues |
| `--unsafe-fixes` | Include fixes that may alter intent |
| `--allow-dirty` | Apply fixes even with uncommitted changes |
| `--select RULE,GROUP` | Run specific rules or groups only |

## Syntax check without executing

R has no `--noexec` mode. Use `parse()` via Rscript to check syntax only:

```sh
Rscript -e "parse('script.R')"
```

## Pre-commit hook (prek)

The `_meta/profiles/prek.toml` scaffold carries one live family of R hooks, scoped to `\.(R|r)$`: `air-format` (`posit-dev/air-pre-commit`) and `jarl-check` (`etiennebacher/jarl-pre-commit`), the mutating-plus-reporting pair matching the local pipeline.

A second family, `lorenzwalthert/precommit` (`no-browser-statement`, `no-debug-statement`, `deps-in-desc`), sits commented out in the scaffold alongside its rationale.
Those hooks run in an renv-sandboxed environment whose lockfile does not build under R 4.6: `v0.4.3` pins digest 0.6.36, which uses the removed `Calloc`/`Free` macros, and the main branch pulls V8 and so needs `libnode.so.109`, absent on nodesource setups.
The value forgone is small: the first two are greps for stray debug calls, and `deps-in-desc` duplicates `R CMD check`.
`roxygenize` stays excluded on its own merits even if that family is re-enabled: it runs `pkgload::load_all()` on the package, so the hook's isolated environment must provide every `Import`, which is slow and fails on packages with system dependencies (`magick`, `rsvg`, `svglite`, `systemfonts`, ...).
Regenerate `man/` via `devtools::document()` locally or in CI instead.

The live pair needs no R at all: `air-format` and `jarl-check` are both `language: python` upstream, shipping their binary from PyPI, so a machine that only runs them commits without an R install.
That changes if the `lorenzwalthert/precommit` family is ever re-enabled: those are `language: r`, and prek runs them through the system `Rscript` (it does not manage R toolchains) and rejects any `language_version`, so R then has to be present on every machine and CI runner that commits.
Do not copy the hook `rev` values into a project config: they drift, and the scaffold is the source of truth.
The dotfiles repo's own root `prek.toml` carries no R hooks: that repo has no `.R` package, only an empty `.Rprofile`, following the precedent set for typstyle and StyLua.

## References

- air: https://github.com/posit-dev/air
- jarl: https://github.com/etiennebacher/jarl
- precommit hooks: https://lorenzwalthert.github.io/precommit/articles/available-hooks.html
- prek R language support: https://prek.j178.dev/languages/
