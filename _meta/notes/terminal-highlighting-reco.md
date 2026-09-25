# Terminal syntax highlighting: command line and file contents

Research note from `/workflow:reco` (2026-09-25).
Scope: bash 5.2 on Ubuntu 24.04, in GNOME Terminal and in the Positron integrated terminal, covering both the command line while typing and file contents printed to the terminal.
No system action taken: neither ble.sh nor bat is installed, and `bash/.bashrc` is unchanged.
Implementation design is deferred to `/design` in a separate conversation.

## State of the machine at research time

- `bash/.bashrc` carries the stock Ubuntu `PS1` block, a venv-aware `PS1` rewrite built on `__base_ps1`, `dircolors` and `lesspipe`; no line editor, no pager colorizer.
- `delta` already colors git diffs.
- Positron's profile `settings.json` does not set `terminal.integrated.shellIntegration.enabled`, so VS Code shell integration is injected (default).
- `apt-cache policy bat`: candidate `0.24.0-1build1`, not installed.

## Decision

- Command line: ble.sh, nightly build, installed under `~/.local/share/blesh`.
- File contents: bat from apt, `BAT_THEME=ansi`, `MANPAGER="batcat -plman"`, no `cat` alias.
- Confidence: medium for ble.sh (little field evidence outside its own tracker, none on Positron), high for bat.

## Why ble.sh

GNU Readline has no syntax highlighting: it only colors completion listings (`colored-stats`, `colored-completion-prefix`) and the active region.
Highlighting in bash therefore requires replacing readline, and ble.sh is the only mature replacement (actively maintained, last push 2026-09-08).
Switching to fish or zsh would give highlighting natively but discards `.bashrc` and every existing hook; community sources do not push bash users to switch.

Official setup, from the README (https://github.com/akinomyoga/ble.sh, verified 2026-09-25):

```
curl -L https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf -
bash ble-nightly/ble.sh --install ~/.local/share

# top of .bashrc
[[ $- == *i* ]] && source -- /path/to/blesh/ble.sh --attach=none
# end of .bashrc
[[ ! ${BLE_VERSION-} ]] || ble-attach
```

The README recommends bash 4.0 or higher; 5.2 qualifies.
No Debian or Ubuntu package exists and the last tag is from 2023, so the nightly is the practical channel; `sys-update` does not cover it.

### Known risks

- ble.sh redefines `trap`, `readonly`, `bind`, `history`, `read` and `exit` as shell functions, and a `PROMPT_COMMAND` that prints text needs `bleopt prompt_command_changes_layout=1`.
- fzf needs ble.sh's own contrib integration; starship, atuin and bash-preexec are recurring sources of tickets.
- Startup cost reported by the maintainer: about 100 to 400 ms per shell, more on first run while the cache builds.
- ble.sh#732 (closed): keystroke lag of 50 to 190 ms after startup.
- ble.sh#612 (open): `ble/util/setexit` errors under VS Code or Cursor, tied to bash 5.3 POSIX mode; not the local version.

### Positron (VS Code shell integration)

VS Code documents disabling automatic injection with `terminal.integrated.shellIntegration.enabled` set to `false` (https://code.visualstudio.com/docs/terminal/shell-integration, verified 2026-09-25) and documents no conflict with custom line editors.
Its bash script sources `~/.bashrc` itself, then hooks through bash-preexec when loaded, otherwise through a chained `DEBUG` trap and a `PROMPT_COMMAND` wrapper.
ble.sh's source (`ble.pp`) detects `VSCODE_INJECTION` and switches to attaching at the prompt, so the recommended `.bashrc` layout is handled; this was read by a research subagent and not re-read in the main thread.
No Positron-specific report exists on either tracker; a real trial in both terminals is the only evidence that counts.

## Why bat

bat is the community consensus for file highlighting; pygmentize, source-highlight and highlight survive mainly as `lesspipe` back-ends, and glow covers Markdown only.
README (https://github.com/sharkdp/bat, verified 2026-09-25):

- "On some older Ubuntu/Debian releases, the executable is installed as `batcat` instead of `bat`".
- "`ansi` looks decent on any terminal": it uses the terminal's own palette, so the same setting renders correctly in GNOME Terminal and in Positron.
- `export MANPAGER="bat -plman"`; the README warns the Manpage syntax still needs work.

Automatic light/dark theme selection (`--theme-light`, `--theme-dark`) arrived in bat 0.25.0, after the 0.24.0 that noble ships; upstream is v0.26.1 (2025-12-02, `gh api`).
With `ansi` that feature is unnecessary, so the apt package, kept current by `sys-update apt`, is enough.
bat bundles R and Markdown syntaxes but no Quarto one; mapping `.qmd` to Markdown is untested.

`alias cat=bat` stays out: it loses `cat`'s `-v`, `-e` and `-t`, and adds a pager and decorations to copied text.

## Matching colors across the two terminals

The integrated terminal takes its ANSI colors from the editor theme, overridable through `workbench.colorCustomizations`, and `terminal.integrated.minimumContrastRatio` adjusts foreground luminance to a 4.5:1 contrast unless set to `1` (https://code.visualstudio.com/docs/terminal/appearance, verified 2026-09-25).
No practitioner guide covers the GNOME and Positron pairing; copying the GNOME palette into `workbench.colorCustomizations` and setting the ratio to `1` if colors look washed out is an inference, not a sourced practice.

## Open points for `/design`

- Update mechanism for ble.sh: a dedicated `sys-update` module on the `<tool>-update` pattern, or ble.sh's own updater run by hand.
- Placement in `bash/.bashrc` and interaction with the venv-aware `PS1` rewrite.
- A reversible trial mode (an environment guard, for example) before adoption in both terminals.
- Whether the change calls for a bats test, as the `bin/` scripts have.
- A showboat trace for the installs, per `rules/showboat.md`.
