---
paths:
  - "**/*.sql"
---

# SQL toolchain

## Scope

This file governs hand-authored `.sql` files, the dominant dialects here being `duckdb` (queries run through the `duckdb` CLI) and `postgres`.

It does not govern SQL embedded in another language: a string literal in an `.R` or `.py` file, a `sql` chunk in a `.qmd`.
No tool in this ecosystem extracts SQL from a host language, SQLFluff included: its `python` templater targets templating placeholders, not source extraction, and Quarto exposes no chunk-level hook to attach a linter to.
Embedded SQL therefore has no gate at all, and the way to bring a query under one is to move it into a `.sql` file.

It does not govern generated SQL either: dumps, migration files emitted by an ORM, or anything under a build directory.

## CLI tools

```
| Tool | Role |
|---|---|
| `sqlfluff` | Fixer and validating linter (`~/.local/bin/sqlfluff`, `uv tool install "sqlfluff[rs]"`). `fix` rewrites in place, `lint` validates. The `[rs]` extra pulls the Rust lexer and parser, opt-in until it becomes the default in 5.0 |
```

Updated by the `uv-tools` module of `sys-update` (`uv tool upgrade --all`), like ruff and pyrefly.
The bootstrap and the dialect smoke test are traced in `_meta/notes/sql-gate.md`.

Do not install from apt: Ubuntu 24.04 ships 2.3.5, two majors behind.

SQLFluff is the whole gate on its own, which is what sets SQL apart from the other languages here.
`fix` occupies both the fixer and the formatter slots (`shellharden` plus `shfmt`, or `ruff check --fix` plus `ruff format`), and `lint` is the validating pass that `shellcheck` and the second `ruff check` occupy elsewhere.
There is no type-checking counterpart, and no test stage.

`sqlfluff format` also exists, but it force-applies `fix` restricted to layout rules, so it is a subset of the first step rather than a stage of its own. Do not add it.

## Mandatory pipeline after every create/edit

```sh
sqlfluff fix FILE
sqlfluff lint FILE
```

Do not chain the two with `&&`: `fix` exits 1 when unfixable violations remain, which is expected churn rather than a hard failure, and `&&` would skip the validating pass that decides.

Exit codes, identical for both subcommands: `0` clean, `1` violations found or a file could not be parsed, `2` configuration error or internal error.
A `2` is never a code-quality signal, it means the run never happened.

The `format-on-edit` hook runs both steps on every `.sql` edit, but only when a config sits at the project root (a `.sqlfluff`, or a `pyproject.toml` carrying a `[tool.sqlfluff` section), precisely to avoid turning every edit in an unconfigured project into an exit 2.
A project keeping its config in a subdirectory gets no edit-time coverage, and neither does one configuring the dialect through `setup.cfg`, `tox.ini` or `pep8.ini`, which the guard does not probe; both need the sequence above run by hand.

## Config resolution

A project-root config naming a dialect is mandatory, not recommended: a `.sqlfluff`, or a `[tool.sqlfluff]` table in a `pyproject.toml` the project already has.
Without a dialect, SQLFluff refuses to run at all and exits 2, so an unconfigured project and a project violating its own rules are mechanically distinguishable.

```ini
[sqlfluff]
dialect = duckdb
```

Config files are searched in this order, later ones overriding earlier: `setup.cfg`, `tox.ini`, `pep8.ini`, `.sqlfluff`, `pyproject.toml`.
In `pyproject.toml` every section starts with `tool.sqlfluff` and subsections are delimited by a dot (`[tool.sqlfluff.indentation]`).
Prefer `.sqlfluff` in an R or Quarto project, `pyproject.toml` in a Python project that already has one.

`--dialect duckdb` on the command line covers a one-off check outside any project, stdin included.
Inside a configured project, stdin needs no flag: config resolves from the working directory, or from the path given to `--stdin-filename`.

A project mixing dialects needs one config per directory: the dialect is a config value, not a per-file attribute, and SQLFluff resolves config from the file's own directory upward.

## Dialect coverage and its limits

`duckdb` inherits from `postgres`, which inherits from `ansi`.
The grammar is hand-maintained and trails DuckDB releases by roughly a quarter, so friendly-SQL syntax lands in DuckDB before SQLFluff can parse it.

The smoke test in `_meta/notes/sql-gate.md` covers 19 DuckDB-specific constructs against 4.3.0. All parse except one:

- **`ATTACH` is unparsable**, in every form (with or without `DATABASE`, with or without an alias, with or without `IF NOT EXISTS`). The parser falls back to the inherited PostgreSQL statements and marks the whole section unparsable, which surfaces as a `PRS` violation and exit 1. A file that attaches a database cannot pass the gate as written; isolate the `ATTACH` outside the linted file, or add a `-- noqa: PRS` on the statement.

What does parse: `SELECT * EXCLUDE / REPLACE`, `GROUP BY ALL`, `FROM`-first, `read_parquet()`, list comprehensions, lambdas, struct and map literals, `UNION ALL BY NAME`, `QUALIFY`, underscore numerics, `SET VARIABLE`, `COLUMNS()`, named arguments, `PIVOT`, `ASOF JOIN`, `TRY_CAST`.

Two consequences for how `fix` is used:

- Read the diff `fix` produces on DuckDB files rather than trusting it blindly. Upstream has at least one case where `fix` rewrote valid DuckDB into broken SQL rather than merely reporting a false positive.
- A `PRS` violation on syntax that DuckDB itself accepts is an upstream grammar gap, not a defect in the query. File it upstream and move on; do not rewrite working SQL to satisfy the parser.

## Positron

`sqlfluff.vscode-sqlfluff` on Open VSX is the only montage available, and it is installed.
It shells out to the CLI rather than running a language server: SQLFluff ships none, and there is no `sqlfluff lsp` subcommand.
The editor therefore surfaces the same violations as the pipeline above, with no completion, no hover, and no go-to-definition.

Wiring in the Positron profile `settings.json`:

```
| Key | Value | Why |
|---|---|---|
| `[sql].editor.formatOnSave` | `true` | The global `editor.formatOnSave` is `false`; format on save is opt-in per language |
| `[sql].editor.defaultFormatter` | `sqlfluff.vscode-sqlfluff` | The extension registers a document formatting provider over `fix` |
| `sqlfluff.executablePath` | `/home/julien/.local/bin/sqlfluff` | Default is the bare name resolved through `PATH`; the absolute path pins the editor to the uv-managed binary the gate uses |
| `sqlfluff.linter.run` | `onSave` | Default is `onType`, which relints on every keystroke |
| `sqlfluff.dialect` | unset | A global dialect would mask the exit 2 that separates an unconfigured project from one violating its own rules |
```

The extension bundles no SQLFluff of its own, so it sits outside the "one tool, one binary" table in `rules/environment.md`; the `executablePath` pin buys determinism, not conflict resolution.

Editing a `.sql` in a project with no config therefore raises a visible config error in the editor, where the `format-on-edit` hook stays silent instead. Both behaviours point at the same fix: add the project config.

The extension formats through stdin (`sqlfluff fix -` with `--stdin-filename`). On a project with no dialect that call leaves stdout empty, writes the error to stderr and exits 2, so a save cannot replace the buffer with the error text.

There is no usable SQL language server for DuckDB. The one candidate, `sqruff lsp`, comes with the tool this gate rejects and carries open bugs on both formatting and config discovery.

For a project that is purely PostgreSQL, `postgres-language-server` (Supabase, ex-`postgres_lsp`, ex-`postgrestools`) is a real language server built on `libpg_query`, published as `supabase.postgrestools` on Open VSX.
Its parse diagnostics and formatting work without a database, while completion, type checking and the database linter need a live connection.
Keep it out of the gate: it rejects DuckDB syntax outright, and it only attaches inside a workspace holding a `postgres-language-server.jsonc`.

## Commit gate (prek)

Upstream publishes `sqlfluff-fix` (`sqlfluff fix --show-lint-violations --processes 0 --disable-progress-bar`) and `sqlfluff-lint` (`sqlfluff lint --processes 0 --disable-progress-bar`).

Both sit in `_meta/profiles/prek.toml`, pinned at `rev = "4.3.0"` (the upstream tags carry no `v` prefix). `types: [sql]` is declared upstream, so a project holding no SQL never triggers them.

The prerequisite is the exit-2 behavior above: seeded into a project that has `.sql` files but no config, the hooks fail every commit touching one, with a configuration error rather than a violation to act on. Prune them, or add the config, at the same time the template is seeded. `pyrefly-check` sits in the template on the same terms, active and waiting on a config table the project must declare, but its unconfigured failure mode is the opposite: it exits 0 and validates nothing, where these two block the commit outright.

Order matters and both are listed: `sqlfluff-fix` rewrites the staged files, `sqlfluff-lint` is the validating pass that decides.

The hooks run in prek's own isolated environment against the pinned rev, not against `~/.local/bin/sqlfluff`, so `sys-update` never moves them; the rev is the only thing that does.

## Adjacent tools, deliberately outside the gate

**squawk** lints PostgreSQL migration DDL for lock hazards (`CREATE INDEX` without `CONCURRENTLY`, volatile column defaults). Static analysis, no database connection, `.squawk.toml`, `pip install squawk-cli`.
It is orthogonal to this gate rather than a competitor: it never formats, and it says nothing about a `SELECT`.
Worth adding only to a project writing DDL against a PostgreSQL instance under real traffic, and even there its most cited rule now has an equivalent in SQLFluff (`CV13`).

## Rejected alternatives

```
| Tool | Why not |
|---|---|
| `sqruff` | The Rust reimplementation, and the only serious contender. It has no `--check` flag and no `format` command, so it cannot express the validating half of the gate; config discovery ignores `pyproject.toml`; its default templater and rule set are narrower than SQLFluff's, so a dropped-in `.sqlfluff` silently lints less. The maintainers track the gap themselves. The speed argument that justified it is also dissolving: SQLFluff is absorbing Rust in place, opt-in since 4.0.0 and default at 5.0 |
| `pg_format` (pgFormatter) | Formatter only, PostgreSQL-oriented, Perl. No `--check`, no documented exit-code contract, so it cannot be the validating step. Nothing to enforce even as a formatter-only stage that SQLFluff does not already do |
| `sql-formatter` | Whitespace-only by design, DuckDB supported. No exit-code contract, and it adds an npm dependency to a Python and Rust toolchain |
| `shandy-sqlfmt` | Formatter only, dialect-agnostic lexer (no `duckdb` or `postgres` switch), built for dbt |
| `sqls`, `sqlls` | Language servers with neither lint nor format, so they fit no stage of the gate. `sqls` is alive under a new org and centred on a live database connection; `sqlls` is unmaintained since 2024 |
| `dbt lint` | 40x to 250x faster than SQLFluff and deliberately SQLFluff-compatible (reads `.sqlfluff`, same rule codes, honours `noqa`), but Beta, dbt Fusion only, and it exists to solve a dbt-templating bottleneck this setup never hits |
```

## Watch item

DuckDB merged a first-party SQL formatter into `main` on 2026-03-31: `duckdb -format-file`, `-format` on stdin, `.auto_format on`, and a `duckdb_format_sql()` function with `keyword_case`, `inline_threshold` and `indent_size` options.
It is in no released version (absent from 1.5.5, the 1.5.x branch having diverged before the merge) and absent from the DuckDB docs.
When it ships it will be exact on the dialect where SQLFluff guesses, and the formatting half of the gate is worth reconsidering for DuckDB files at that point. The linting half has no DuckDB-native counterpart planned.

## References

- SQLFluff dialect list and inheritance: https://docs.sqlfluff.com/en/stable/reference/dialects.html
- SQLFluff exit codes and production use: https://docs.sqlfluff.com/en/stable/production/cli_use.html
- SQLFluff configuration file search order: https://docs.sqlfluff.com/en/stable/configuration/setting_configuration.html
- SQLFluff upstream pre-commit hooks: https://raw.githubusercontent.com/sqlfluff/sqlfluff/main/.pre-commit-hooks.yaml
- SQLFluff parallelism limit with the dbt templater: https://github.com/sqlfluff/sqlfluff/issues/7666
- sqruff parity gaps, tracked by its own maintainers: https://github.com/quarylabs/sqruff/issues/2498
- DuckDB CLI formatter, merged and unreleased: https://github.com/duckdb/duckdb/pull/21725
- Squawk CLI and config: https://squawkhq.com/docs/cli
- Postgres Language Server, database requirement: https://pg-language-server.com/latest/features/database_linting/
- `dbt lint` benchmark against SQLFluff: https://docs.getdbt.com/reference/commands/lint
