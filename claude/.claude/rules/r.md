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

## References

- air: https://github.com/posit-dev/air
- jarl: https://github.com/etiennebacher/jarl
