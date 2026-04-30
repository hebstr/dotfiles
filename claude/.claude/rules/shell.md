---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/.bashrc"
  - "**/.bash_profile"
  - "**/.bash_aliases"
---

# Shell scripting toolchain

## CLI tools

| Tool | Role | Installation |
|---|---|---|
| `shellcheck` | Linter (static analysis, `SC*` warnings) | `sudo apt install shellcheck` |
| `shellharden` | Auto-fix variable quoting | `cargo install shellharden` (not available via apt on Ubuntu 24.04) |
| `shfmt` | Formatter (indentation, spacing) | `sudo apt install shfmt` |

Orthogonal roles:
- **shellcheck** reports — does not fix
- **shellharden** automatically fixes quoting (based on shellcheck rules)
- **shfmt** formats (cosmetic only, no semantic correction)

## Typical pipeline

Order matters — shellharden modifies structure, shfmt formats, shellcheck validates:

```sh
shellharden --replace script.sh   # auto-fix quoting
shfmt -w script.sh                # format in place
shellcheck script.sh              # final audit
```

## Useful shfmt flags

| Flag | Effect |
|---|---|
| `-w` | write in place |
| `-i 2` | 2-space indentation |
| `-ci` | indent `case` branches |
| `-sr` | space after redirections (`> file`) |
| `-bn` | `&&` / `\|` at start of line |

Combined example:
```sh
shfmt -w -i 2 -ci -sr script.sh
```

## VS Code / Positron extensions

**Install:**
1. **Bash IDE** (`mads-hartmann.bash-ide-vscode`) — full LSP (completion, hover, go-to-def) + integrates shellcheck and shfmt automatically. Used as formatter for `shellscript`.
2. **shell-format** (`foxundermoon.shell-format`) — used only for **other** formats: Dockerfile, dotenv, .gitignore/.dockerignore, /etc/hosts, .properties, jvmoptions, bats. Do not use for shellscript: it tries to download its own shfmt and sometimes fails silently (Positron message: "cannot format Shell Script-files").

**Nice-to-have:**
- **Better Shellscript Syntax** (`jeff-hykin.better-shellscript-syntax`) — more precise highlighting
- **Bash Debug** (`rogalmic.bash-debug`) — step-by-step debugger (scripts > 100 lines)

No extension for shellharden — run manually or via pre-commit.

## `settings.json` config

shfmt flags are not passed on the command line: Bash IDE exposes each option individually (`caseIndent` = `-ci`, `spaceRedirects` = `-sr`, etc.). The `-i N` indentation setting goes through `editor.tabSize` in the `[shellscript]` block.

```json
{
  "bashIde.shellcheckPath": "shellcheck",
  "bashIde.shfmt.path": "/usr/bin/shfmt",
  "bashIde.enableSourceErrorDiagnostics": true,
  "bashIde.shfmt.caseIndent": true,
  "bashIde.shfmt.spaceRedirects": true,
  "[shellscript]": {
    "editor.tabSize": 2,
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "mads-hartmann.bash-ide-vscode"
  }
}
```

`enableSourceErrorDiagnostics` enables cross-file diagnostics via `source`/`.` (resolves sourced files to propagate errors).

Other flags exposed by Bash IDE: `binaryNextLine` (`-bn`), `simplifyCode` (`-s`), `funcNextLine`, `languageDialect` (bash/posix/mksh/bats).

### Other formats (Dockerfile, dotenv, ignore, etc.)

`foxundermoon.shell-format` is registered by default as formatter for Dockerfile/dotenv/.gitignore/hosts/.properties/jvmoptions/bats, but `Format Document` does not trigger automatically without a `[language]` block. Only add a block when needed:

- **format-on-save desired** -> `formatOnSave: true` + `defaultFormatter` (e.g. Dockerfile where formatting is beneficial)
- **just pin the formatter choice** (useful when multiple extension candidates, e.g. Dockerfile with `ms-azuretools.vscode-docker`) -> `defaultFormatter` only
- **nothing** -> `Format Document With...` remains available on demand

Formats where auto-format should be avoided: dotenv (order sometimes significant), .gitignore, /etc/hosts (rarely edited, structural comments).

Example for Dockerfile:

```json
"[dockerfile]": {
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "foxundermoon.shell-format"
}
```

## Pre-commit hook

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.13.1
    hooks:
      - id: shfmt
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.10.0.1
    hooks:
      - id: shellcheck
```

## Check a script without executing it

```sh
sh -n script.sh          # POSIX syntax check
bash -n script.sh        # bash syntax check
shellcheck script.sh     # full lint
```

## References

- ShellCheck: https://github.com/koalaman/shellcheck — `SC*` codes documented at https://www.shellcheck.net
- shellharden: https://github.com/anordal/shellharden
- shfmt (`mvdan/sh` project): https://github.com/mvdan/sh
- bash-language-server: https://github.com/bash-lsp/bash-language-server
