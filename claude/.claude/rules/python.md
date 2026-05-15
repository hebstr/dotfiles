---
paths:
  - "**/*.py"
  - "**/*.ipynb"
---

# Python toolchain

## CLI tools

| Tool | Role |
|---|---|
| `ruff format` | Formatter |
| `ruff check` | Linter (static analysis + auto-fix) |

Prefer `uv run ruff` inside a project (picks up `pyproject.toml`); use global `ruff` for standalone scripts.

## Mandatory pipeline after every create/edit

```sh
ruff format script.py && ruff check --fix script.py
```

Both are required: `ruff format` formats only, `ruff check` lints and fixes.

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

## References

- ruff: https://docs.astral.sh/ruff
- uv: https://docs.astral.sh/uv
