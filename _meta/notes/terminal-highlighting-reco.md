# Terminal syntax highlighting: command line and file contents

Research note from `/workflow:reco` (2026-09-25).
Scope: bash 5.2 on Ubuntu 24.04, in GNOME Terminal and in the Positron integrated terminal, covering both the command line while typing and file contents printed to the terminal.
No system action taken: neither ble.sh nor bat is installed, and `bash/.bashrc` is unchanged.
Implementation design settled by `/design` on 2026-09-25, in the section "Design: how the decision lands in this repository" below; it drops `MANPAGER` from the decision.

## State of the machine at research time

- `bash/.bashrc` carries the stock Ubuntu `PS1` block, a venv-aware `PS1` rewrite built on `__base_ps1`, `dircolors` and `lesspipe`; no line editor, no pager colorizer.
- `delta` already colors git diffs.
- Positron's profile `settings.json` does not set `terminal.integrated.shellIntegration.enabled`, so VS Code shell integration is injected (default).
- `apt-cache policy bat`: candidate `0.24.0-1build1`, not installed.

## Decision

- Command line: ble.sh, nightly build, installed under `~/.local/share/blesh`.
- File contents: bat from apt, `BAT_THEME=ansi`, no `cat` alias. `MANPAGER` was part of this decision and is withdrawn (2026-09-25): see "`MANPAGER` stays unset because bat 0.24 cannot color man pages on the terminal palette" below.
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

## Design: how the decision lands in this repository

Decided by `/design` on 2026-09-25, approved by the user the same day, implemented the same day; the installs are traced in `_meta/notes/terminal-highlighting-setup.md`.
The `bash` stow package is also stowed on `ju-TP2` (WSL), per the `stow` command of `_meta/notes/wsl-init-tuto.md`, so every addition to `bash/.bashrc` must be inert where neither ble.sh nor bat is installed.

### ble.sh updates through an inline `blesh` module of `sys-update`

The wrapper `update_blesh` records `skipped (blesh not installed)`, the wording of the app-gated modules such as `update_zotero`, unless `~/.local/share/blesh/ble.sh` exists, then runs `run_or_dry bash ~/.local/share/blesh/ble.sh --update`; the module needs no sudo.
This follows `update_claude` (`claude update`) and the decision recorded in `rules/environment.md` that the `npm` module stays an inline one-liner, a tool that updates itself having no bespoke distribution shape to wrap.
`_meta/tests/sys-update.bats` hardcodes the module lists, so it takes the new module in the same change.

The mechanism was checked on 2026-09-25 by installing the nightly into a scratch directory: the installed copy carries `_ble_base_repository=release:nightly-20260908+d81fd54`, so `--update` takes the `ble-update/.download-nightly-build` path of `ble.pp` (download the tarball, compare its hash with the previous download, `cp -Rf` over the install) and exited 0.
Two limits of that path, read in `ble.pp` and accepted:

- there is no rollback: the copy overwrites in place and `nightly` is a single rolling release tag, so an earlier build cannot be fetched again; the presence guard below is the kill switch instead;
- when the download fails after five retries, `ble-update/.impl` maps its status 7 to 0, so the module reports `OK` without having updated anything.

Rejected:

- **A dedicated `blesh-update` script that also installs**, on the `rv-update` model: a script and a bats file to automate a two-command first install, which `uv-python` and `uv-tools` already leave manual.
- **No module, `ble-update` by hand**, on the `llama-update` model: the argument there is a silent break on another machine, while a broken ble.sh shows at the next shell on the machine that runs `sys-update`; without a module the nightly simply falls behind.

### ble.sh loads right after the interactive check and attaches on the last line

A new section `### LINE EDITOR` follows `### INTERACTIVE CHECK` and sources `~/.local/share/blesh/ble.sh --attach=none` behind a file-presence test; `[[ ! ${BLE_VERSION-} ]] || ble-attach` is the last line of the file, after the `~/.secrets` source.
This is the layout of the ble.sh README; its `[[ $- == *i* ]]` prefix is redundant here, since the preceding section already returns in a non-interactive shell.

`__fix_venv_prompt` only assigns `PS1` and prints nothing, so `bleopt prompt_command_changes_layout` is not needed for it.
`PROMPT_COMMAND` puts `__fix_venv_prompt; history -a` ahead of any hook already set, under a `case` guard that keeps a re-sourced `.bashrc` from repeating it (walkthrough of 2026-09-26). GNOME Terminal starts login shells here (`login-shell=true`), so `/etc/profile.d/vte-2.91.sh` has already set `__vte_prompt_command`, which now survives: it prints only the OSC 0 title and OSC 7 working-directory sequences, and how ble.sh handles those two escapes in a real terminal is not yet observed.
No `~/.blerc` is created until a setting needs one.
Positron needs no setting: `ble.pp` detects `VSCODE_INJECTION` while VS Code's integration script sources `~/.bashrc` and switches to attaching at the prompt, which was read in the source and not observed.

### The presence guard is the only trial switch

Installing ble.sh turns it on in both terminals, and moving `~/.local/share/blesh` aside turns it off, with no commit either way.
The guard is required anyway for `ju-TP2`, so the trial costs nothing extra.
Rejected: an opt-in environment variable set in the GNOME Terminal profile and in Positron's `terminal.integrated.env.linux`, two settings to add and later remove for no gain over the guard.

### bat is used through an alias and the `ansi` theme

bat comes from apt, which the `apt` module of `sys-update` keeps current.
`alias bat=batcat` joins `### ALIASES`, after the precedent `alias fd=fdfind`, and `export BAT_THEME=ansi` joins `### PAGER`.
Measured on 2026-09-25 with the noble `.deb` extracted to a scratch directory: `ansi` colors a bash script with the terminal palette.

### `MANPAGER` stays unset because bat 0.24 cannot color man pages on the terminal palette

Measured on 2026-09-25 with bat 0.24.0 and man-db 2.12:

- `batcat -plman`, the form this note first recorded from the current README, passes man's own SGR sequences through untouched in 0.24, which has no `--strip-ansi`: it adds no color;
- `sh -c 'col -bx | batcat -l man -p'` with `MANROFFOPT=-c`, the form the v0.24.0 README documents, colors only the `(1)` of the title line under `ansi`, `base16` and `base16-256`, and drops man's bold and underline;
- only the 24-bit themes (Monokai) color the headings, and they ignore the terminal palette, which is the reason `ansi` was chosen.

Rejected: that documented form with a 24-bit theme for man alone, which contradicts the `ansi` rationale.
Left undecided, as a separate idea outside this decision: coloring man pages through `less` itself on the terminal palette (`LESS='-R --use-color -Dd… -Du…'` with `MANROFFOPT=-c`); less 590 accepts the options, but `LESS` applies to every program that pages through less.

### Tests and trace

No bats test covers `bash/.bashrc`, for want of any precedent: the file gets the shell gate of `rules/shell.md`.
The installs are traced in `_meta/notes/terminal-highlighting-setup.md` per `rules/showboat.md`: `apt install bat` goes in a note under a tilde fence, since it needs sudo, and the ble.sh install is an `exec` block.

### Open points

- The weakest assumption: ble.sh coexists with Positron's shell integration and emulates the three `bind 'set …'` lines of `### READLINE` without breaking the venv prompt. Probed on 2026-09-25 with ble.sh `0.4.0-nightly+d81fd54` in a pseudo-terminal (`script -qfec`), once as `bash -i` and once as Positron launches it (`VSCODE_INJECTION=1 bash --init-file` on `/usr/share/positron/…/shellIntegration-bash.sh`): ble.sh attaches in both with no error; the `(…)` venv prefix appears when `VIRTUAL_ENV` is set and leaves when it is unset; under the Positron path every command emits the `633;A`/`B`/`C`/`D` markers and its `633;E` command line, the first recorded command being ble.sh's own `ble/base/attach-from-PROMPT_COMMAND`. `bind -v` reports the three settings, and ble.sh's completion reads `completion-ignore-case` and `mark-symlinked-directories` (`lib/core-complete.sh`) but never `show-all-if-ambiguous`, so its own menu completion replaces that setting. A pseudo-terminal is not a real terminal: the trial in GNOME Terminal and in Positron still settles it.
- Left open on 2026-09-25, when the session paused: bat 0.24.0-1build1 is installed and traced; the manual trial has only confirmed command-line highlighting in one terminal, from a screenshot that does not name it; the venv prefix, `completion-ignore-case`, `mark-symlinked-directories`, Positron's command decorations and bat's colors in both terminals remain to check. Since the walkthrough of 2026-09-26, the GNOME Terminal trial also checks how ble.sh handles the OSC 0 and OSC 7 output of `__vte_prompt_command`, which now survives in `PROMPT_COMMAND`.
- Whether GNOME Terminal and Positron render the same colors, per "Matching colors across the two terminals" above.
- Mapping `.qmd` to bat's Markdown syntax, untested.
