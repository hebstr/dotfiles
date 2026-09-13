---
name: Pitfalls of the Bash tool shell on this machine
description: Traps met in Claude's own Bash tool session: find resolves to bfs (names starting with '-' become options), pkill -f matches the tool's own command line and kills the shell, rg -h is help not no-filename, sudo cannot prompt and the '!' prompt prefix has no TTY, bundled rm -rf commands get declined
metadata:
  type: reference
---

Observed 2026-09-13; each one cost a failed or misleading command before it was understood.

- **`find` is bfs in the tool shell.** `command -v find` prints `find` (a shell-snapshot function or alias) and errors come back as `bfs: error: ... Unknown argument`. bfs parses a path starting with `-` as an option, so a relative path like `-dyKJnGvV-0ec8I8/` breaks silently into misclassification. Use `/usr/bin/find`, or pass paths as `./name` or absolute. Scripts run outside the tool shell resolve `/usr/bin/find` (GNU) and are unaffected.
- **`pkill -f <pattern>` kills the tool's own shell.** The Bash tool runs the whole command string through `bash -c`, so the pattern also matches that shell's command line; the call dies with exit 144 mid-script. The `[r]egex` trick does not help because the literal string appears in the command text. Kill by process name (`pgrep -x chrome`) or by a captured PID. The same self-match makes `pgrep -f positron` report a running editor that is not there: check `ps -eo comm=` instead.
- **`rg -h` prints ripgrep's help.** For "no filename", use `--no-filename`; the misuse returns help text that looks like empty results.
- **sudo cannot run from the session.** `sudo -n true` fails (password required), and the `! <command>` prompt prefix has no terminal either: `sudo: a terminal is required to read the password`. A `sudo -v` in another terminal does not carry over: sudoers caches credentials per terminal under `timestamp_type=tty`, and with no terminal it falls back to the parent process (`man sudoers`, sudo 1.9.15p5), which differs for every tool call. Hand sudo commands to the user for their own terminal, grouped, and verify the effect afterwards from the session.
- **Keep destructive commands separate.** A long command that bundles `rm -rf` of several paths with a test run was declined at the permission prompt as a whole, discarding the test. Put each deletion in its own call, scoped to exactly the paths meant.

See also [[feedback_shell_grep_pipefail]] for failure propagation inside scripts.
