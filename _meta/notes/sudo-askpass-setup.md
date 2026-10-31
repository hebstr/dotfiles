# sudo askpass: authenticating sudo without a terminal

*2026-10-31T16:11:17Z by Showboat 0.6.1*
<!-- showboat-id: e73cb1e7-0b0e-4eed-bb16-ee5a139fb89a -->

Claude Code's `!` prefix, and any context without a controlling terminal, make `sudo` fail on `a terminal is required to read the password`: sudo reads the password from `/dev/tty`, which is not openable there. The `-A` option makes it delegate the prompt to an external program, whose path comes from `SUDO_ASKPASS` (which takes precedence) or from a `Path askpass` line in `/etc/sudo.conf`. The variable wins here: `/etc/sudo.conf` is owned by root, outside `$HOME`, therefore outside stow, while the variable stays entirely in the repository and travels to ju-TP2 through Syncthing.

Starting state: no helper configured, and both `Path askpass` lines of `/etc/sudo.conf` are commented out.

```bash
rg -c "^Path askpass" /etc/sudo.conf; echo "exit=$? (1 = no active line)"
```

```output
exit=1 (1 = no active line)
```

## Three pieces, all stowable

The helper goes into the `bin` package, the export into the `bash` package, and `sys-update` switches between the two forms of `sudo` depending on whether a controlling terminal exists.
The helper refuses without a display, which keeps a machine with no graphical server (WSL, ju-TP2) from waiting on a window that will never come.
That refusal surfaces as a failed `sudo -A -v`, and `sys-update` aborts on it under `set -Eeuo pipefail`: no fallback to `sudo -v` runs there.
`.profile` gates the export on `[ -x ]` and the helper is tracked at mode 100755, so `SUDO_ASKPASS` is non-empty on every machine the `bin` package is stowed on, display or none, and the switch takes `-A`.
What the abort costs is the message rather than the outcome, a bare `sudo -v` failing in a terminal-less context as well.
Gating the export on a display, rather than patching `sudo_prime`, is the lever the day a real fallback is wanted.

```bash
cat bin/.local/bin/sudo-askpass
```

```output
#!/usr/bin/env bash
# sudo-askpass: read a password in a graphical dialog and print it on stdout.
#
# Wired through SUDO_ASKPASS (bash/.profile) and used by `sudo -A` when no
# controlling terminal is available. Refuses without a display so a caller on
# a headless machine fails instead of hanging.

set -Eeuo pipefail

if [[ -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} ]]; then
  printf 'sudo-askpass: no graphical display\n' >&2
  exit 1
fi

if ! command -v zenity >/dev/null 2>&1; then
  printf 'sudo-askpass: zenity not installed\n' >&2
  exit 1
fi

zenity --password --modal --timeout=120 --title="${1:-Authentication required}"
```

```bash
sed -n "/### ENVIRONMENT/,/^fi$/p" bash/.profile; echo "---"; sed -n "/^sudo_prime()/,/^}/p" bin/.local/bin/sys-update
```

```output
### ENVIRONMENT -------------------------------------------------------------
if [ -x "$HOME/.local/bin/sudo-askpass" ]; then
  export SUDO_ASKPASS="$HOME/.local/bin/sudo-askpass"
fi
---
sudo_prime() {
  if [[ -n ${SUDO_ASKPASS:-} ]] && ! : 2>/dev/null </dev/tty; then
    sudo -A -v
  else
    sudo -v
  fi
}
```

The test is `: </dev/tty`, not `[ -t 0 ]`: opening `/dev/tty` is what sudo attempts, and it fails with `ENXIO` when the process has no controlling terminal. `[ -t 0 ]` is only a proxy, wrong as soon as stdin is redirected from a file inside a terminal, a case sudo handles perfectly well on its own. Keeping `-A` conditional matters: passed in an interactive terminal, it would replace the terminal prompt with a window, a pure regression.

Priming the credential cache covers the rest of the run: the `sudo apt-get` and `sudo snap refresh` calls inside the modules reuse the timestamp `sudo_prime` laid down, and each use refreshes it.

`--modal` is kept as a redundant hint, not as a requirement: under zenity 4.0.1 the password dialog carries `_NET_WM_STATE_MODAL` whether or not the flag is passed, and `WM_TRANSIENT_FOR` is absent either way, so the window has no parent to be modal against (measured 2026-10-31 with `xprop`, both forms, reproduced).
The bats case asserting the flag pins the call's shape, never a modality the dialog needs.

## Linking

```bash
cd ~/dotfiles && stow --no-folding bin && readlink -f ~/.local/bin/sudo-askpass
```

```output
/home/julien/dotfiles/bin/.local/bin/sudo-askpass
```

## Verification

Two bats suites cover the branches. `sudo-askpass.bats` covers the helper: the password on stdout alone, the prompt sudo hands over used as the dialog title, refusal without a display, refusal without zenity, cancellation and timeout propagated as failures. `sys-update.bats` covers the switch, under `setsid --wait`, which puts the script in a session with no controlling terminal and propagates its exit status, where a bare `setsid` would not.

```bash
cd ~/dotfiles && shellcheck bin/.local/bin/sudo-askpass bin/.local/bin/sys-update bash/.profile && echo "shellcheck: clean" && bats _meta/tests/sudo-askpass.bats _meta/tests/sys-update.bats 2>&1 | rg -c "^ok " | xargs -I{} echo "bats: {} tests passed"
```

```output
shellcheck: clean
bats: 71 tests passed
```

The real end-to-end run, not replayable (it invalidates the sudo cache and opens a window that waits for input), launched from a context with no controlling terminal:

~~~text
sudo -k
SUDO_ASKPASS="$HOME/.local/bin/sudo-askpass" sudo -A -v && echo "SMOKE OK"

SMOKE OK: credential cache primed without a TTY
~~~

The window opens with the prompt sudo passes as its title (`[sudo] password for julien:`), zenity writes the password on its standard output and sudo reads it from there. Nothing keeps a copy: no file, no log, no session transcript.

That last clause holds for this path and for no other: it is sudo reading the pipe that keeps the password out of everything.
Run the helper directly and whatever holds the other end of its stdout keeps the password instead, in cleartext.
A terminal keeps it in the scrollback, and an agent harness keeps it in its transcript: measured 2026-10-31, Claude Code's Bash tool hands the helper a pipe exactly as sudo does, then captures it into the session jsonl.
No guard inside the helper reaches that case, `[ -t 1 ]` being false under both sudo and the harness, which leaves never invoking it by hand as the whole of the remedy.
To check the dialog, run the `sudo -A -v` of this section rather than the helper.

## Scope

The `.profile` export only takes effect at the next login: processes already running, Positron and the Claude Code session among them, keep their environment. Until then, `sudo -A` in a terminal-less context needs `SUDO_ASKPASS` set by hand.

Out of scope, decided: `/etc/sudo.conf` (not stowable, and the variable covers it), `timestamp_timeout` (the 15-minute default is enough, and every `sudo` of the run refreshes it), and the `sudo` calls inside `sys-update`'s modules (covered by the primed cache).
