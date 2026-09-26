---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/.bashrc"
  - "**/.bash_profile"
  - "**/.bash_aliases"
  - "**/.profile"
  - "**/.bash_logout"
  - "**/.blerc"
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

On this machine `/bin/sh` is dash, POSIX only: a `#!/bin/sh` script gets no bash idiom.
Ubuntu 24.04 freezes the apt `shellcheck` and `shfmt` behind the versions the prek hooks pin, so the commit gate runs newer tools than the terminal: read a hook failure on a file the local CLI passes as that gap before suspecting the file.

## Mandatory pipeline after every create/edit

After writing or editing any shell script, run the full pipeline in one shot before marking the task done. Order matters: shellharden fixes quoting, shfmt formats, shellcheck validates.

```sh
shellharden --replace script.sh && shfmt -w -i 2 script.sh && shellcheck script.sh
```

Running only one or two tools is not sufficient, all three are complementary. If a Bats test exists, run `bats <test-file>` after the format+lint gate.

SC2030/SC2031 in bats files (`export` in `setup()`) are documented false positives: note them and continue.

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
- **Bats files** are associated with `shellscript` (`files.associations`, `*.bats`), so Bash IDE serves them: it passes `--filename` to shfmt, whose `auto` dialect then parses `@test`. Do not install `jetmartin.bats`: it declares its own `bats` language id, and Bash IDE activates on `onLanguage:shellscript` only, so the LSP, shellcheck diagnostics and formatting would all stop on `.bats`.
- **shell-format** (`foxundermoon.shell-format`): for Dockerfile/dotenv/.gitignore/hosts/.properties/jvmoptions only. Do **not** use for shellscript: it tries to download its own shfmt and fails silently ("cannot format Shell Script-files").
- Optional: `jeff-hykin.better-shellscript-syntax`, `rogalmic.bash-debug`. No extension for shellharden, run manually or via prek.

Active configuration is checked in at `positron/.config/Positron/User/profiles/*/settings.json` (search `bashIde`). The `[shellscript]` block is the source of truth; do not duplicate it here.

## Pre-commit hook (prek)

The repo-root `~/dotfiles/prek.toml` is authoritative for the pinned hook revisions and the full hook set; do not copy its `rev` values here (they drift). The relevant behavior: the `shfmt` hook runs `-w -i 2` (matching the local pipeline) and the `shellcheck` hook runs with defaults. The `bash/` package is covered like any other: its dotfiles carry no shebang, so each opens on a `# shellcheck shell=` directive naming its dialect (`sh` for `.profile`, which login shells other than bash also read), without which shellcheck reports SC2148. prek types only `.bashrc` as `shell` from its name: `.profile`, `.bash_logout` and `.blerc` (the ble.sh init file, bash) come out as plain `text` (`prek util identify`), so `prek.toml` carries a second `shellcheck`, `shfmt` and `shellharden` entry with `types = ["text"]` and `files = '^bash/\.(profile|bash_logout|blerc)$'`, a `files` override on the `shell`-typed entry being ANDed with that type and still skipping them.

All three tools of the pipeline are enforced at commit: a local `shellharden` hook runs `--check`, which is report-only, so its fixing stays in the local pipeline above and no commit rewrites a shell file through it (`shfmt -w` still does, as the paragraph above says). It excludes `\.bats$` by choice, not by necessity: shellharden parses `@test` and transforms every `.bats` of this repo without error, and would restyle 22 of the 42 (`"${STUBS}"` to `"$STUBS"`, `[ -z "$x" ]` to `[ "$x" = "" ]`, measured 2026-09-22). The tests stay unnormalized because nothing replays that rewrite on them: `format-on-edit.sh` dispatches on `*.sh | *.bash`, so the per-edit cost that justified normalizing the scripts does not arise. Its exit 2 under `--check` means "would change", for a `.bats` as for any file. Since `--check` prints nothing either, the hook's `name` carries the fix command, which is what a failing run shows.

The `_meta/profiles/prek.toml` scaffold carries the same three for other projects: `shellcheck` and `shfmt` from their pinned upstream repos, and the local `shellharden` hook in the same `--check` form. Its local block already depends on this machine's inventory (`prose-lint`, `panache`), so the `shellharden` entry adds no assumption. The `metadata-only` entry does add one: `prek-metadata-only` fails closed without the `out-textconv` diff driver (`git` stow package) and a `diff=out-textconv` attribute on every type it matches (`_meta/profiles/gitattributes`).

Hook matching is by content, not by extension: `prek` types a file `shell` from its shebang, so the extensionless scripts under `bin/.local/bin/` are covered by all three. The `format-on-edit` hook is the asymmetric one, dispatching on `*.sh | *.bash`, so those same scripts reach no gate at edit time and are caught at commit instead. Do not widen either the hook's globs or this file's `paths:` to close that gap; the commit hooks already enforce it mechanically.

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
