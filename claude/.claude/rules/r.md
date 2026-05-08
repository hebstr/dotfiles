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

Both are required — `air` formats only, `jarl` lints only.

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
