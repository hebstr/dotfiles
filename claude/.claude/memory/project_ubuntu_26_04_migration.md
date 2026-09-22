---
name: Ubuntu 24.04 to 26.04 migration deferred
description: Decision 2026-09-09 to stay on 24.04 until December 2026 at the earliest, gated on the Supported flag of Canonical's meta-release; full research already done, do not redo it
metadata:
  type: project
---

On 2026-09-09 a full `/workflow:reco` research covered moving this machine (Ubuntu 24.04.5, noble) to 26.04 LTS "Resolute Raccoon".
Decision: no migration before December 2026, target window December 2026 to February 2027.
Research, repository checks and the day-of checklist: `~/dotfiles/_meta/notes/ubuntu-26-04-migration-reco.md`.

**Why:** the data science stack has served `resolute` since May 2026; the risk sits in the OS core (rust-coreutils by default with documented silent breakage on `sort` and `dd`, `sudo-rs`, Wayland only, cgroup v1 removed). 24.04 is supported until May 2029, so waiting costs nothing.

**How to apply:** if the subject returns, read the note rather than rerun the research. A daily cloud routine already watches the trigger (`trig_019wLpTCwdTRi8kKNBwaQLnw`, created 2026-09-09, silent while the flag is 0): do not create a second one. Manual check: `curl -s https://changelogs.ubuntu.com/meta-release-lts | grep -A4 '^Dist: resolute'` must show `Supported: 1` (still `Supported: 0` on 2026-09-22), then allow two to three months of buffer. On migration day, two files move from `noble` to `resolute`: `~/dotfiles/_meta/profiles/Rprofile.site` and `~/dotfiles/claude/.claude/rules/environment.md`.
