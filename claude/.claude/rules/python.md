---
paths:
  - "**/*.py"
  - "**/*.ipynb"
---

# Python toolchain

## Code style conventions

- Prefer polars over pandas unless the project already uses pandas
- Before recommending `from pkg import fn` or `pkg.fn`, verify the symbol exists and is importable: `python -c "from pkg import fn"` (exits non-zero if the name is absent or the import path is wrong). Inside a project, run it through the project env: `uv run python -c "from pkg import fn"`. This is the Python analog of the R `getNamespaceExports` export check in `rules/r.md`

## Preserving analysis code

This code exists for a data science/biostatistics purpose. When editing it for infrastructure, code-quality, or refactoring reasons, do not alter its analysis semantics:

- Joins: always use explicit keys; check for NA on join keys after every join
- Domain-specific regex or business rules: do not "fix" or tighten without explicit domain validation
- LLM inference parameters (temperature, top_p, seed): do not change without documented justification (breaks reproducibility of existing results)
- Calculated approximations (e.g. age from date diff / 365.25): flag but do not auto-correct, often intentional for consistency with institutional conventions

## CLI tools

| Tool | Role |
|---|---|
| `ruff format` | Formatter |
| `ruff check` | Linter (static analysis + auto-fix) |

Prefer `uv run ruff` inside a project (picks up `pyproject.toml`); use global `ruff` for standalone scripts.

## Mandatory pipeline after every create/edit

```sh
ruff check --fix script.py && ruff format script.py && ruff check script.py
```

Order matters: `ruff check --fix` first (auto-fix may leave whitespace), then `ruff format` cleans it, then a final `ruff check` confirms no residual violations. Per ruff docs. If the project has tests, run `pytest <test-file>` after the format+lint gate.

## Useful flags

**ruff format**

| Flag | Effect |
|---|---|
| `--check` | Dry-run, exits non-zero if file would change |
| `--diff` | Show diff without writing |

**ruff check**

| Flag | Effect |
|---|---|
| `--fix` | Auto-fix safe violations |
| `--unsafe-fixes` | Include fixes that may alter intent |
| `--select RULE` | Run specific rules only (e.g. `--select E,F`) |
| `--show-fixes` | List all applied fixes |

## Syntax check without executing

```sh
python -m py_compile script.py
```

## Streamlit

Streamlit apps follow the same `ruff` gate as any Python file; there is no Streamlit-specific linter, and the gate does not run the app. For a manual smoke check, `streamlit run app.py` launches the dev server, but it stays in the foreground serving until interrupted, so it is not exit-code-testable: run it optionally while iterating, never as part of the automated gate.

## Standalone scripts: PEP 723 inline metadata

For single-file Python tools under `~/dotfiles/bin/.local/bin/` or any reusable standalone script, declare deps inline and run via `uv run --script`:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = ["polars", "rich"]
# ///
```

Self-contained, no venv to manage, deps versioned in the file. Make the file executable (`chmod +x`) and uv resolves/installs deps on first run.

Scope: standalone scripts only. Package code stays in `pyproject.toml`; project analysis notebooks use the project's `uv` env.

## References

- ruff: https://docs.astral.sh/ruff
- uv: https://docs.astral.sh/uv
- PEP 723: https://peps.python.org/pep-0723/
