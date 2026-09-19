---
name: Review severity for the bash/ stow package
description: Calibration rules for code reviews of the interactive shell dotfiles in ~/dotfiles/bash/ (.bashrc, .profile, .bash_logout)
metadata:
  type: feedback
---

When reviewing `~/dotfiles/bash/`, do NOT raise the following finding patterns:

- Per-line `# shellcheck source=/dev/null` directives flagged as redundant with the file-level `disable=SC1091`: on a `~`-prefixed path (`~/.bash_aliases`, `~/.secrets`) they suppress SC1090 (non-constant source), which SC1091 does not cover. Removing them makes shellcheck fail (measured 2026-09-19). Only a directive on a `$HOME/...` path is genuinely redundant, and it is harmless.
- The `firefox` alias hardcoding `/home/julien/.mozilla/firefox/z24d9fn6.default-release`: it mirrors the `firefox` stow package, deliberately tied to one machine, and is inert on ju-TP2 (no Firefox installed, same username).
- `bind` calls in `.bashrc` said to print "line editing not enabled" without a TTY: not reproduced under bash 5.2 (`bash -ic 'true' </dev/null`, `echo exit | bash -i`), and there is no `~/.inputrc` to move them into.

**Why:** walkthrough of `bash/` on 2026-09-19 (posit-dev:critical-code-reviewer), 11 findings: 3 accepted, 4 rejected, 4 noted. The three rejections above were each disproved by one command.

**How to apply:** drop these before reporting. In-scope real concerns for this package: PATH ordering that differs between the dash and bash login paths, or that lets an unmanaged directory shadow managed binaries (both fixed that day in `.profile`), and behavior that breaks interactive shells. A claim about what happens on ju-TP2 (WSL) is checkable over `ssh ju-TP2` in one read-only command: measure there before filing it. See [[feedback_review_severity_shell_installers]] for the neighbouring `bin/` scripts.
