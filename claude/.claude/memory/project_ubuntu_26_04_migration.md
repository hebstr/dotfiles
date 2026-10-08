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

**How to apply:** if the subject returns, read the note rather than rerun the research. A daily cloud routine already watches the trigger (`trig_019wLpTCwdTRi8kKNBwaQLnw`, created 2026-09-09): do not create a second one. **The flag has fired: `Dist: resolute` reads `Supported: 1` on 2026-10-09, for 26.04.1 LTS.** What gates the migration from here is the buffer alone, two to three months, which puts it at December 2026 at the earliest as the decision already says. Manual re-check: `curl -s https://changelogs.ubuntu.com/meta-release-lts | rg -A4 '^Dist: resolute'`. On migration day, two files move from `noble` to `resolute`: `~/dotfiles/_meta/profiles/Rprofile.site` and `~/dotfiles/claude/.claude/rules/r.md`.
