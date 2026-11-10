# Tracker 3.7.1 spinning on SQLite's ROWID bug: neutralisation and guard rails

*2026-11-10T11:05:46Z by Showboat 0.6.1*
<!-- showboat-id: 6601b1a8-4201-4605-b00e-f7cd1d16b7d6 -->

## Context

Machine hot and fans at full speed with no task running, 2026-11-10 around 11:30. `tracker-miner-fs-3` had burned 64 min of CPU over 80 min of uptime and was emitting 4,089,340 log lines per hour, which had grown `/var/log/syslog` to 30.5 GB (previous rotations: ~15 MB) at 907 KiB/s. TCPU at 74 °C.

Beyond the thermal symptom, the disk was the real deadline: logrotate ran weekly, and at 907 KiB/s the 313 GB free would have been gone in about four days, before the next rotation.

## Root cause

`libsqlite3-0` 3.45.1-1ubuntu2.9, installed 2026-11-08 at 02:13:48, backports from SQLite 3.45.3 the fix to the `SQLITE_ALLOW_ROWID_IN_VIEW` build option (LP #2087772). Tracker 3.7.1 references a bare `ROWID` inside a view, which SQLite now treats as ambiguous, so every cleanup query fails with `ambiguous column name: ROWID`. First syslog trace: 2026-11-08 at 10:32:34, the first session after the upgrade.

The loop: Tracker discovers a file, the file disappears before extraction, the purge `DELETE` fails on the bug, the stale record survives, Tracker retries. Forever. The triggers are the agents' atomic writes, shaped `<file>.tmp.<pid>.<hex>` (the pattern appears in the `claude` binary), which the `*.tmp` glob of `ignored-files` does not match. None of those files still existed on disk; 1691 failures were recorded.

No fix in noble: the apt candidate stays `tracker 3.7.1-1build1`, unpatched. The upstream fix is GNOME/tracker MR 665, and no Launchpad bug was found for the regression. Route chosen by the user: neutralise Tracker, since searching happens through rg and fdfind anyway.

## Unit neutralisation

Both D-Bus services `org.freedesktop.Tracker3.Miner.Files` and `.Control` declare `SystemdService=`, so masking the systemd unit also blocks D-Bus activation. The two `org.gnome.Nautilus.Tracker3.*` services point at `/app/libexec/`, a Flatpak path absent from this machine, so they are inert. `tracker-extract-3` is not a unit: the miner spawns it, so it falls with the miner.

```bash
systemctl --user mask tracker-miner-fs-3.service tracker-miner-fs-control-3.service tracker-writeback-3.service tracker-xdg-portal-3.service
systemctl --user list-unit-files --no-pager | grep -i tracker
```

```output
tracker-miner-fs-3.service                                        masked    enabled
tracker-miner-fs-control-3.service                                masked    enabled
tracker-writeback-3.service                                       masked    enabled
tracker-xdg-portal-3.service                                      masked    enabled
```

Masking does not touch an instance already running, and one mattered here: after the first `systemctl --user stop`, D-Bus had re-activated the miner at 11:44:11, before the 11:48:24 mask (cgroup `background.slice/tracker-miner-fs-3.service`, so through systemd), and it had already burned 3 min 31 s of CPU in 4 min 26 s. The sequence below is what actually clears a live instance.

```bash
systemctl --user unmask tracker-miner-fs-3.service >/dev/null 2>&1
systemctl --user stop tracker-miner-fs-3.service
systemctl --user mask tracker-miner-fs-3.service >/dev/null 2>&1
systemctl --user list-unit-files --no-pager | grep tracker-miner-fs-3
ps -eo args | grep -c "^/usr/libexec/tracker" || true
```

```output
tracker-miner-fs-3.service                                        masked    enabled
0
```

## Stale index

Removed, since it held the corrupted records and the masked miner will never read it again. Not replayable (destructive).

~~~text
$ du -sh ~/.cache/tracker3 && rm -rf ~/.cache/tracker3
310M	/home/julien/.cache/tracker3
~~~

## Guard rails

Three levers were on the table. The rsyslog rate limit was dropped on measurement: `rsyslog.service` declares `Requires=syslog.socket`, that socket is active, and `rsyslogd`'s listening socket is `/run/systemd/journal/syslog`, handed over by systemd socket activation. The imuxsock documentation states that under systemd many `SysSock.*` parameters are ignored, which would leave `SysSock.RateLimit.*` inert here. `SysSock.RateLimit.Severity` is also documented inconsistently between the reference page and the code. The edit would further have landed in `/etc/rsyslog.conf`, a dpkg conffile, so a prompt on every rsyslog upgrade, for no effect.

The effective cap sits upstream, in journald, `ForwardToSyslog` having been on at the time: everything reaching rsyslog had already passed journald's rate limit.

Three files installed, directives checked against the man pages on the machine (logrotate 3.21.0, systemd 255):

- `/etc/systemd/journald.conf.d/50-limits.conf`: `RateLimitIntervalSec=30s` and `RateLimitBurst=2000`, i.e. 66 messages/s per service sustained, which drops a runaway from 4M to ~240k lines per hour. Plus `SystemMaxUse=200M`, set first to `1G` against a journal sitting at 4.0 GB, then aligned on the `JOURNAL_SIZE="200M"` that `clean_journal()` of `bin/.local/bin/sys-cleanup` already vacuums to. The always-on cap now does the work that module did intermittently, so its reported reclaim stops being the ceiling being pulled down and becomes a flood signal.
- `/etc/logrotate.d/rsyslog`: `maxsize 200M` added, `rotate 4` raised to `rotate 7`. The weekly cadence is kept, but since the logrotate timer fires daily, a file past 200 MB is rotated the next day at the latest.
- `/etc/systemd/journald.conf.d/syslog.conf`: `ForwardToSyslog=no`. The filename is load-bearing, since it masks Ubuntu's own `/usr/lib/systemd/journald.conf.d/syslog.conf`, which forces `yes` against the compiled default of `no`. `journald.conf(5)` sorts drop-ins by filename across every directory and the last one wins, so any numeric prefix (`50-`, `99-`) sorts ahead of `syslog.conf` in ASCII and would be overridden; only an identical name, or one past `s`, reaches the end of the cascade.

Dropping the forward halves the write amplification of userspace logs, which were stored twice on the NVMe. It does not kill `/var/log/syslog`: `module(load="imklog")` in `/etc/rsyslog.conf` reads the kernel ring buffer directly, so kernel messages keep landing there and in `kern.log` (measured right after the change: 819 bytes of `wlp0s20f3` reassociation). That stream is small, `kern.log` holding 3.9 MB over a rotation period.

Nothing on this machine consumed the file: no hit for `/var/log/syslog` across `~/dotfiles`, and neither `fail2ban`, `logcheck` nor `logwatch` is installed, `dpkg -l` returning only `rsyslog` itself.

Covering any of this in `sys-cleanup` was weighed and rejected, 2026-11-10. The journal is already a module there, and more aggressive than the cap was; everything in `/var/log` outside the journal came to about 78 MB (1.1 GB total against 1022 MB of journal), which no module is worth; and a user-invoked reclaim is the wrong instrument against 907 KiB/s, which fills the disk in days. An always-on cap is what bounds that.

## Privileged application

Not replayable. `sudo -A` does work from Claude Code's Bash tool (X reachable, `XAUTHORITY=/run/user/1000/gdm/Xauthority`, zenity dialog shown), but the sudo timestamp does not survive from one tool call to the next, so every `sudo` opens its own dialog. Hence the single `sudo -A bash -c`. Detail in `sudo-askpass-setup.md`.

~~~text
$ sudo -A bash -c 'set -Eeuo pipefail
install -d -m 755 /etc/systemd/journald.conf.d
install -m 644 -o root -g root "$1/50-limits.conf" /etc/systemd/journald.conf.d/50-limits.conf
install -m 644 -o root -g root "$1/rsyslog.logrotate" /etc/logrotate.d/rsyslog
systemctl restart systemd-journald
journalctl --vacuum-size=1G 2>&1 | tail -n 3
truncate -s 0 /var/log/syslog' _ <staging dir>

Vacuuming done, freed 0B of archived journals from /run/log/journal.
Vacuuming done, freed 0B of archived journals from /var/log/journal/beb894a32ee54c05b46a72aef0cc8270.
Vacuuming done, freed 0B of archived journals from /var/log/journal.
~~~

The explicit vacuum frees nothing because restarting journald had already applied the cap, then `1G`, and brought the journal from 4.0 GB down to 1021.6 MB. `truncate` rather than `rm`, to keep rsyslog's file descriptor valid. Measured at the time: 31 GB reclaimed, `/` from 132 GB used to 101 GB.

The second elevation, installing `syslog.conf` and the 200M alignment, was refused to the agent by the auto-mode classifier under `Logging/Audit Tampering`: disabling the forward and truncating a log file in one elevation reads as covering tracks from the outside. The refusal was not worked around by splitting the command, and the user ran it themselves. Any later pass touching logging reduction on this machine should expect the same refusal and hand the command over rather than reshape it.

Journal after that restart: 181.2 MB, inside the 200M cap.

## Final verification

```bash
echo "--- tracker units ---"
systemctl --user list-unit-files --no-pager | grep tracker
echo "--- tracker processes ---"
ps -eo args | grep -c "^/usr/libexec/tracker" || true
echo "--- effective journald ---"
systemd-analyze cat-config systemd/journald.conf | grep -Ev "^\s*#|^$"
echo "--- effective logrotate ---"
st=$(mktemp); logrotate --debug --state "$st" /etc/logrotate.d/rsyslog 2>&1 | grep -E "rotations|rotated earlier"; rm -f "$st"
echo "--- sizes ---"
stat -c "%s bytes  %n" /var/log/syslog
journalctl --disk-usage
echo "--- temperatures (mC) ---"
for z in 0 6 9; do printf "%s: %s\n" "$(cat /sys/class/thermal/thermal_zone$z/type)" "$(cat /sys/class/thermal/thermal_zone$z/temp)"; done
echo "--- load ---"
cat /proc/loadavg
```

```output
--- tracker units ---
tracker-miner-fs-3.service                                        masked    enabled
tracker-miner-fs-control-3.service                                masked    enabled
tracker-writeback-3.service                                       masked    enabled
tracker-xdg-portal-3.service                                      masked    enabled
--- tracker processes ---
0
--- effective journald ---
[Journal]
[Journal]
SystemMaxUse=200M
RateLimitIntervalSec=30s
RateLimitBurst=2000
[Journal]
ForwardToSyslog=no
--- effective logrotate ---
 weekly (7 rotations)
empty log files are not rotated, log files >= 209715200 are rotated earlier, old logs are removed
--- sizes ---
819 bytes  /var/log/syslog
Archived and active journals take up 181.2M in the file system.
--- temperatures (mC) ---
acpitz: 34000
TCPU: 34050
x86_pkg_temp: 36000
--- load ---
0.55 0.36 0.26 2/873 25859
```
