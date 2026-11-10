---
name: reference-tracker-masked-sqlite-rowid
description: GNOME Tracker is masked on this machine since 2026-11-10; unmasking it restarts a CPU-burning log flood
metadata:
  type: reference
---

GNOME Tracker's four user units (`tracker-miner-fs-3`, `tracker-miner-fs-control-3`, `tracker-writeback-3`, `tracker-xdg-portal-3`) are masked on ju-TP since 2026-11-10, and the index at `~/.cache/tracker3` was deleted. Never unmask them without first checking that `tracker` has moved past 3.7.1 in the archive.

Ubuntu's `libsqlite3-0` 3.45.1-1ubuntu2.9 (installed 2026-11-08) backports from SQLite 3.45.3 the fix to the `SQLITE_ALLOW_ROWID_IN_VIEW` build option. Tracker 3.7.1 uses a bare `ROWID` inside a view, so every cleanup query fails with `ambiguous column name: ROWID`. Any file that vanishes between discovery and extraction then leaves a stale record Tracker can never purge, and it retries forever: 80% of a core continuously, 4M journal lines per hour, `/var/log/syslog` at 30.5 GB in two days, TCPU at 74 °C. The agents' own atomic writes (`<file>.tmp.<pid>.<hex>`, which the `*.tmp` entry of `ignored-files` does not match) are the main trigger, so this machine's workflow feeds the loop continuously.

The upstream fix is GNOME/tracker MR 665, not backported to noble; the apt candidate was still the unpatched `3.7.1-1build1`. No Launchpad bug was found for the regression.

Two guard rails were installed in the same pass and are independent of Tracker: `/etc/systemd/journald.conf.d/50-limits.conf` (`SystemMaxUse=1G`, `RateLimitIntervalSec=30s`, `RateLimitBurst=2000`) and `maxsize 200M` plus `rotate 7` in `/etc/logrotate.d/rsyslog`. A rsyslog-side `SysSock.RateLimit.*` was measured useless here: systemd socket activation hands rsyslogd its socket, and imuxsock ignores `SysSock.*` in that case. `ForwardToSyslog=no` stays available as the stronger lever, deliberately not applied.

Full trace, including what was rejected: `~/dotfiles/_meta/notes/tracker-rowid-loop-remediation.md`.
