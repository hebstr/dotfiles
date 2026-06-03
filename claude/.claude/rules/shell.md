---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/.bashrc"
  - "**/.bash_profile"
  - "**/.bash_aliases"
  - "**/.profile"
---

# Shell scripting toolchain

## CLI tools

| Tool | Role | Installation |
|---|---|---|
| `shellcheck` | Linter (static analysis, `SC*` warnings) | `sudo apt install shellcheck` |
| `shellharden` | Auto-fix variable quoting | `cargo install shellharden` (not available via apt on Ubuntu 24.04) |
| `shfmt` | Formatter (indentation, spacing) | `sudo apt install shfmt` |

Orthogonal roles:
- **shellcheck** reports; does not fix
- **shellharden** automatically fixes quoting (based on shellcheck rules)
- **shfmt** formats (cosmetic only, no semantic correction)

## Mandatory pipeline after every create/edit

After writing or editing any shell script, run the full pipeline in one shot before marking the task done. Order matters: shellharden fixes quoting, shfmt formats, shellcheck validates.

```sh
shellharden --replace script.sh && shfmt -w -i 2 script.sh && shellcheck script.sh
```

Running only one or two tools is not sufficient, all three are complementary. If a Bats test exists, run `bats <test-file>` after the format+lint gate.

The shfmt flags above match the prek hook in `prek.toml` (source of truth at commit gate). Running with extra flags locally (e.g. `-ci`, `-sr`) reformats files in ways the hook will revert.

## Useful shfmt flags

| Flag | Effect | Used in pipeline |
|---|---|---|
| `-w` | write in place | yes |
| `-i 2` | 2-space indentation | yes |
| `-ci` | indent `case` branches | no (prek does not set it) |
| `-sr` | space after redirections (`> file`) | no (prek does not set it) |
| `-bn` | `&&` / `\|` at start of line | no |

Note: Positron's Bash IDE is configured to match prek's `-w -i 2` (no case-indent, no space-after-redirect); if a formatting conflict ever appears, the checked-in settings file is authoritative (see below). On-save formatting and the commit hook agree. Do not add `-ci`/`-sr` to the local pipeline or the `format-on-edit` hook: they produce formatting the commit gate reverts.

## Positron extensions

- **Bash IDE** (`mads-hartmann.bash-ide-vscode`): LSP + integrates shellcheck/shfmt automatically. Default formatter for `shellscript`.
- **shell-format** (`foxundermoon.shell-format`): for Dockerfile/dotenv/.gitignore/hosts/.properties/jvmoptions/bats only. Do **not** use for shellscript: it tries to download its own shfmt and fails silently ("cannot format Shell Script-files").
- Optional: `jeff-hykin.better-shellscript-syntax`, `rogalmic.bash-debug`. No extension for shellharden, run manually or via prek.

Active configuration is checked in at `positron/.config/Positron/User/profiles/*/settings.json` (search `bashIde`). The `[shellscript]` block is the source of truth; do not duplicate it here.

## Pre-commit hook (prek)

The repo-root `~/dotfiles/prek.toml` is authoritative for the pinned hook revisions and the full hook set; do not copy its `rev` values here (they drift). The relevant behavior: the `shfmt` hook runs `-w -i 2` (matching the local pipeline) and the `shellcheck` hook runs with defaults, and both exclude `^bash/` (the `bash/` package holds hand-maintained dotfiles like `.bashrc`/`.profile`, not standalone scripts, so it is kept out of auto-format and lint; reusable scripts live in `bin/.local/bin/` and are covered).

## Check a script without executing it

```sh
sh -n script.sh          # POSIX syntax check
bash -n script.sh        # bash syntax check
shellcheck script.sh     # full lint
```

## References

- ShellCheck: https://github.com/koalaman/shellcheck (`SC*` codes documented at https://www.shellcheck.net)
- shellharden: https://github.com/anordal/shellharden
- shfmt (`mvdan/sh` project): https://github.com/mvdan/sh
- bash-language-server: https://github.com/bash-lsp/bash-language-server
