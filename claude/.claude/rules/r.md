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
- Before writing a helper, ask the installed packages whether one already exists (CLAUDE.md, Coding preferences). Two commands, both against the installed artifact rather than recall: `Rscript -e 'grep("<keyword>", getNamespaceExports("<pkg>"), value = TRUE)'` for the current export surface, and `grep -n "<keyword>" $(Rscript -e 'cat(system.file("NEWS.md", package = "<pkg>"))')` for what shipped after training, a package's own `NEWS.md` being installed alongside it. `apropos("<pattern>")` after `library()` searches the whole search path when the owning package is unknown. Measured miss: a kebab-case helper hand-rolled in `hebstr` while stringr 1.6.0 (packaged 2025-11-03) exports `str_to_kebab()`, next to `str_to_snake()` and `str_to_camel()`; the NEWS grep names both the function and its release.
- Nothing on disk means "absent from the installed packages", not "absent from R" (CLAUDE.md, Coding preferences). Escalate to a function-level index, never to a bare web search: `https://search.r-project.org/?P=<query>` is the official R engine and indexes both the help pages and the `NEWS` of CRAN packages, and `https://rdrr.io/` covers CRAN, Bioconductor, R-Forge and GitHub. Verified on the incident above: querying `str_to_kebab` on `search.r-project.org` returns the stringr NEWS entry outright, so that one request would have caught it even with stringr absent from the library. A hit in a package that is not already a dependency is proposed to the user with its cost, never installed to save a few lines.
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

Scope: R analysis projects on the `hebstr` stack, recognised by `hebstr` in `rproject.toml` together with a `setup.R` at the project root sourced by the report `.qmd` and one `tbl_*` / `fig_*` script per output.
`~/Documents/services/md-nesrine/` is the reference implementation.
Read it before writing a kind of output the current project has no precedent for; these conventions are established elsewhere and are not to be reinvented locally.

**Placement**

- One script per output under `scripts/`, named `tbl_<name>.R` or `fig_<name>.R`, ending in `easy_out()`. `auto_exec()` sweeps them, and a leading underscore excludes a script from that sweep. Both filters are regular expressions matched on the filename: `exclude` carries that underscore convention as its `"^_"` default, and `include` restricts a sweep to one family, `auto_exec(include = "^tbl")` reaching the tables alone. `exclude` applies after `include`, so a script matching both is still skipped
- `setup.R` at the project root holds the recoding and every object shared by more than one output script, and the report `.qmd` sources it before calling `auto_exec()`. A frame consumed by a single output belongs in that output's script. A project large enough to split it keeps the session setup in `setup.R` and moves the shared preparation to an underscore-prefixed script under `scripts/`, which the sweep skips
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

**Table notes are placed by scope, never all in `note_global`.** `tbl_format(note_global = )` carries only what holds of the whole table: the population, what the columns are, a caveat on reading them. A statement that holds of one row belongs on that row, attached with `hebstr::add_note(vars = )`, which renders it as a symbol-keyed footnote instead of a sentence the reader has to re-attach. The shape that scales, one entry per note carrying the variables it targets:

```
.note_var <- lst(
  index = lst(vars = c("pat_age", "pat_dept"), note = "Lus au premier séjour qualifiant."),
  nature = lst(vars = "pat_cas", note = "...")
)

<chain> |>
  reduce(.note_var, \(tbl, x) add_note(tbl, vars = x$vars, note = x$note), .init = _) |>
  tbl_format(note_global = .note_global, width = )
```

Guard all three failure modes, none of which raises on its own: the count of global notes, the length of each variable note, and the targets against the described variables. `str_glue()` returns a zero-length string when an interpolated object is missing and `c()` then drops it, so a note vanishes from a published table without an error; and a note aimed at a variable the table does not carry is equally silent.

Verified behaviours, measured rather than assumed. `add_note()` works on `tbl_summary`, on `tbl_merge` and on `tbl_stack`; on a stack the note lands on the matching row of every block. One call naming several variables renders as a single symbol repeated on each row. Its position relative to `gtsum_format()` is indifferent, that function's closing `modify_footnote()` resetting the header footnote and leaving body notes intact; only being upstream of `tbl_format()` is required. Declaration order is indifferent too, gtsummary numbering symbols in table reading order.

Two limits. A note that qualifies a *column* has no `add_note()` form, which targets rows, so it stays in `note_global`. And a `gt::gt()` table takes its notes through `gt::tab_source_note()` (`gt_notes()` in the hebstr helpers), which appends unanchored text: the same scoping principle applies but the anchored form is `gt::tab_footnote(locations = )`.

**gtsummary is the default for every table; `gt::gt()` is the fallback, taken only when gtsummary cannot express the table.**
A table of pre-computed counts is not automatically a `gt` case: reshape the aggregate back into observations first, one row per unit with the indicator columns, and let `tbl_summary()` do the counting. That is what earns the percentages and puts the denominator in the header.
Reach for `gt::gt()` plus `theme_gt()` only once that reshaping fails or distorts the table.

**Two nested levels counted on the same units are `tbl_hierarchical()`, not indicator columns.** When each row of a long frame carries a parent and a child (a concept and its code, a system organ class and its preferred term) and the count wanted at both levels is a distinct-unit count, the reshaping above is the wrong first move: it builds one indicator column per level of both variables and leaves the ordering and the indentation to be derived by hand. `tbl_hierarchical(data, variables = c(parent, child), id = <unit>, denominator = <one row per unit>)` gives the two levels, the distinct-unit counts and the indentation from the mechanism, and `sort_hierarchical()` sorts both levels by descending count in one call. It is `[Experimental]` in gtsummary 2.5.1, so pin the version and re-check the output shape after any upgrade. Four properties decided by the mechanism rather than by an argument: declared factor levels are ignored for row order, so any other ordering needs `modify_table_body()`; a level absent from the data loses its row; an empty `by` level keeps its column with an `N = 0` header and `0 (NA)` cells, so drop it with `droplevels()`; and `add_stat_label()` has no method for the class, so the stat label is pasted onto the parent rows with `modify_table_body()`, using the `", "` that `add_stat_label()` itself applies.

`gtsum_format()` does work on a `tbl_hierarchical`, which is what keeps the project's header (spanner, `Total` with its `N`, each level with its `n` and share). It assumes one row per observed unit, so it needs four adaptations: rewrite the `stat_0` header, whose `N` is taken as the row count of the long frame; pass `indent = 0` and re-indent the child rows, since its `.fmt_indent()` indents every `"level"` row and a hierarchical table has only those; set a variable label on the `by` column, which the spanner reads; and paste the stat label back, its closing `modify_footnote(everything() ~ NA)` having removed the footnote that carried it. It calls `add_overall()` itself, so it must precede `sort_hierarchical()`, and that overall column is only correct when the `by` variable partitions the units.

Two consequences of the gtsummary route, both worth knowing before choosing it:

- Columns counting different units (documents, patients, a filtered subset) need one `tbl_summary()` per unit, merged by `tbl_merge(tab_spanner = )`. The chain then stops at `tbl_format()`: `gtsum_format()` selects `stat_0`, which a merged table does not have, carrying `stat_0_1`, `stat_0_2` and so on.
- Number formatting follows the gtsummary locale rather than the explicit `sep_mark` / `dec_mark` a hand-built `gt` table sets, so a French document needs `lang_fr()` active for thousands separators and decimal marks to come out right.

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
