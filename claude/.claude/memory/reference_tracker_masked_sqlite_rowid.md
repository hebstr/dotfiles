---
name: reference-tracker-masked-sqlite-rowid
description: GNOME Tracker is masked on this machine since 2026-11-10; unmasking it restarts a CPU-burning log flood
metadata:
  type: reference
---

GNOME Tracker's four user units (`tracker-miner-fs-3`, `tracker-miner-fs-control-3`, `tracker-writeback-3`, `tracker-xdg-portal-3`) are masked on ju-TP since 2026-11-10, and the index at `~/.cache/tracker3` was deleted. Never unmask them without first checking that `tracker` has moved past 3.7.1 in the archive.

Ubuntu's `libsqlite3-0` 3.45.1-1ubuntu2.9 (installed 2026-11-08) backports from SQLite 3.45.3 the fix to the `SQLITE_ALLOW_ROWID_IN_VIEW` build option. Tracker 3.7.1 uses a bare `ROWID` inside a view, so every cleanup query fails with `ambiguous column name: ROWID`. Any file that vanishes between discovery and extraction then leaves a stale record Tracker can never purge, and it retries forever: 80% of a core continuously, 4M journal lines per hour, `/var/log/syslog` at 30.5 GB in two days, TCPU at 74 °C. The agents' own atomic writes (`<file>.tmp.<pid>.<hex>`, which the `*.tmp` entry of `ignored-files` does not match) are the main trigger, so this machine's workflow feeds the loop continuously.

The upstream fix is GNOME/tracker MR 665, not backported to noble; the apt candidate was still the unpatched `3.7.1-1build1`. No Launchpad bug was found for the regression.

Three guard rails were installed in the same pass and are independent of Tracker: `/etc/systemd/journald.conf.d/50-limits.conf` (`SystemMaxUse=200M`, aligned on the `JOURNAL_SIZE` that `sys-cleanup`'s `clean_journal()` already vacuums to, plus `RateLimitIntervalSec=30s` and `RateLimitBurst=2000`), `maxsize 200M` with `rotate 7` in `/etc/logrotate.d/rsyslog`, and `/etc/systemd/journald.conf.d/syslog.conf` carrying `ForwardToSyslog=no`. That last filename is load-bearing: it masks Ubuntu's `/usr/lib/systemd/journald.conf.d/syslog.conf`, and since `journald.conf(5)` sorts drop-ins by filename across every directory with the last winning, any numeric prefix would sort ahead of `syslog.conf` and be overridden. `/var/log/syslog` still receives the kernel stream through `module(load="imklog")`, which bypasses journald.

A rsyslog-side `SysSock.RateLimit.*` was measured useless here: systemd socket activation hands rsyslogd its socket, and imuxsock ignores `SysSock.*` in that case. Covering any of this in `sys-cleanup` was weighed and rejected: the journal is already a module there, `/var/log` outside the journal came to about 78 MB, and a user-invoked reclaim cannot bound 907 KiB/s.

Full trace, including what was rejected: `~/dotfiles/_meta/notes/tracker-rowid-loop-remediation.md`.
