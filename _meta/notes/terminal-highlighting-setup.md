# Terminal syntax highlighting: ble.sh and bat

*2026-09-25T12:31:02Z by Showboat 0.6.1*
<!-- showboat-id: 6717ce2e-2b11-4484-ba12-3643ac2b1bb2 -->

Installs the two tools chosen in `_meta/notes/terminal-highlighting-reco.md`, whose section "Design: how the decision lands in this repository" holds the why: ble.sh highlights the command line, bat highlights file contents. The `bash` stow package already carries what uses them (`### LINE EDITOR`, the final `ble-attach`, `alias bat=batcat`, `BAT_THEME=ansi` in `bash/.bashrc`), all behind presence tests, so the steps below are only the installs. `sys-update blesh` keeps ble.sh current and `sys-update apt` keeps bat current.

Install the ble.sh nightly under `~/.local/share/blesh`, the path both the `.bashrc` guard and the `blesh` module test. No Debian package exists and the last tag dates from 2023, so the nightly is the channel. The download goes to a throwaway directory and only the installed tree stays.

```bash
tmp=$(mktemp -d) && curl -fsSL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz | tar xJf - -C "$tmp" && bash "$tmp/ble-nightly/ble.sh" --install ~/.local/share >/dev/null && rm -rf "$tmp" && rg -o "_ble_base_repository=\S+" ~/.local/share/blesh/ble.sh
```

```output
_ble_base_repository=release:nightly-20260908+d81fd54
```

Run the `blesh` module once, which proves the installed copy updates itself. The nightly is a single rolling tag, so this overwrites in place with no rollback, and a failed download still reports `OK` (both accepted in the design note).

```bash
sys-update blesh 2>&1 | tail -4
```

```output
MODULE           STATUS
-----------------------------------
blesh            OK
-----------------------------------
```

Install bat from the noble archive, which `sys-update apt` keeps current. It needs sudo, so it sits in a tilde fence that `verify` never replays; run on 2026-09-25, with the line `/var/log/apt/history.log` recorded:

~~~bash
sudo apt install -y bat
~~~

~~~text
Install: bat:amd64 (0.24.0-1build1)
~~~

The executable is `batcat` on Ubuntu, reached as `bat` through the alias in `bash/.bashrc`.
