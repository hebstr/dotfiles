---
name: Benchmarks on this laptop carry a power state
description: This machine runs ~2x slower on battery than on AC, uniformly across CPU-bound work; check the power state before comparing any two timings, and never claim a perf gain from unpaired runs
metadata:
  type: feedback
---

Measured 2026-07-25 on the edstr extraction pipeline (7883 real clinical documents, 13 always-on stage timers plus sub-stage timers): the **same code, same input, same idle machine, ran ~2x slower on battery than on AC**, uniformly across every stage including pure-CPU ones.

| | battery | AC | ratio |
|---|---:|---:|---:|
| whole pipeline | ~77 s | ~38.5 s | 2.0 |
| per stage | | | 1.87 - 2.16 |

On battery the governor is `powersave` and cores sit at 0.7-1.5 GHz; the platform profile stays `balanced` either way, so nothing in the desktop UI signals the change.

**Why this matters:** I first attributed exactly this factor to machine contention around an OOM kill that happened nearby in time. That was wrong, and it was wrong in a way that looked convincing (uniform across CPU-bound stages, a plausible culprit in recent history). Only re-running under a verified power state exposed it.

**Run-to-run variance inside one regime is ~8%** on the same workload, so a before/after under ~10% is noise on a single pair of runs.

**Why:** a perf claim compares two numbers. If they come from different power regimes the comparison is meaningless, and the error is invisible: both runs look internally consistent, and the 2x is large enough to manufacture or erase any realistic optimisation.

**How to apply:**

- Before quoting or comparing any timing, check the regime: `cat /sys/class/power_supply/AC/online` (1 = AC, 0 = battery), plus `cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`.
- Record the regime alongside every measurement written to a note or a design doc. A bare number in a perf record is a trap for whoever reads it next.
- Claim gains as **shares or ratios**, not wall-clock deltas: shares are regime-invariant (verified stage by stage on the same workload), seconds are not.
- Require **paired runs in a fixed regime**, ideally back to back, before calling any optimisation a win. Do not accept a single before/after pair separated by hours.
- Applies to test-suite wall times too, not just profiling: any "~N s" in project documentation inherits the same ambiguity.

Related: [[feedback_verify_before_claiming]].
