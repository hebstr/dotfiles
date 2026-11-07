# DESIGN-BATS-HOOK.md

Design note for the `bats-tests` hook in the root `prek.toml`, decided 2026-09-18.

## The hook keeps running the whole suite, in parallel

Decision: the `bats-tests` hook keeps `pass_filenames = false` and a whole-suite `entry`, and moves from `bats _meta/tests/` to `bats --jobs "$(nproc)" _meta/tests/`.
Validated and implemented 2026-09-18: `prek run bats-tests --all-files` passes in 15,6 s.

The `entry` goes through `bash -c` so that `$(nproc)` is expanded without depending on whether prek hands the string to a shell (not verified).
When GNU `parallel` is not on the PATH, the same `entry` drops `--jobs` and runs the suite serially instead of failing, since `bats --jobs` requires it.
Both machines carry `/usr/bin/parallel` (WSL checked by the user 2026-09-18), so the fallback is a guard for a fresh install only.
Committed in `e2cecbb` (2026-09-18).

The original whole-suite choice was never documented (the hook arrived in commit `1bcbd47`, message `.`).
It is kept because scripts depend on one another in ways the file names do not show, so a change to one script can break another script's tests:

```
| Changed file | Suite that also exercises it |
|---|---|
| bin/.local/bin/prose-lint | format-on-edit.bats (format-on-edit.sh calls prose-lint), prose-lint-pretool.bats (its mirror tests run the real tool) |
| git/.config/git/out-textconv.py | metadata-only.bats |
| bin/.local/bin/claude-plugins-update, libreoffice-update | sys-update.bats |
```

## Parallelism removes most of the wait without losing coverage

Measured 2026-09-18 on this machine (12 cores): 30 files, 786 tests, 51 s serial and 18 s with `bats --jobs 12`, zero failures on that one parallel run.
The slowest single file is `sys-cleanup.bats` at 6,3 s, which bounds how far parallelism can go.

That single run was the weak part, and it held for three days. On 2026-09-21 the hook failed on `pandoc-update.bats`, on a different test at each attempt, always one of the four that drive the install path and always on `[ "$status" -eq 0 ]`.
The cause is `pandoc-update`'s `pandoc --version | head -1`, left without the `|| true` its siblings carry under `set -Eeuo pipefail`: `head` closes the pipe, the writer takes SIGPIPE, the pipeline returns 141 and `set -e` kills the script after a successful install.
The line and its tests date from `16952db` (2026-07-20), so the defect lived two months under a serial hook that could not express it: measured that day on the bare pipeline, 0 failures in 300 serial runs against 36 in 300 at twelve-way parallelism, and 32 in 400 through the whole script.
Parallelism is therefore a detector rather than a cost, and the real exposure was never the test suite: `pandoc --version` prints a dozen lines under a real install, and `pandoc-update` runs inside a `sys-update` that loads the machine.
Fixed in `97cc960`, with a regression test whose stub outlasts the pipe buffer so the race becomes deterministic. Twenty parallel passes of the whole suite, 918 tests each, clean afterwards.
Both the script and its suite then went on 2026-09-30 in `7ad74e7`, which replaced the system pandoc with quarto's bundled binary, so that fix and its regression test are history and cover nothing now.

A sweep for the same shape across the repository found no second defect, and the way it nearly found three is the part worth keeping.
Three constructs read as the same bug and none is: a substitution inside a command argument (`lua-toolchain-update`, `echo "… $(… | head -n1)"`) never propagates its status; `inject-project-context.sh` sets no `-e` at all; and `libreoffice-update`'s `detect_installed`, whose `soffice --version | awk '{print $2}' | head -n1` fallback behind the `dpkg-query` lookup runs unguarded while the top-level `CURRENT=$(libreoffice --version ...)` assignment of the same file carries `|| true`, survives a writer built to force SIGPIPE, five runs out of five.
That asymmetry inside one file is not an oversight: the `CURRENT=` assignment runs at the top level, where the failure is fatal and the guard is owed, and the fallback runs inside a function reached through `CURRENT=$(detect_installed)`, where it is not.

The method is the lesson, not the inventory. `set -e` fires on the failing construct as written, and a probe that lifts it out of its nesting answers a different question: the same pipeline measured fatal five times out of five at the top level and harmless five times out of five inside the function, and an earlier probe wrapping each case in `( … ) || echo` reported both safe, `set -e` being disabled in the left operand of a list.
Reproduce in place, or do not conclude.

## Running only the affected tests was rejected

The rejected option: a wrapper receives the staged paths (`pass_filenames = true`) and maps each one to its test file by name.
The mapping itself is mechanical, since every `.bats` file bears the name of the script it tests.
What sinks the option is the dependency table above, which would have to be maintained by hand: a missing entry lets a broken test pass silently, exactly on the change that affects another script.
It would save about 15 s per commit over the parallel run, which does not pay for that silent failure.

The variant that runs affected tests at commit time and the whole suite at `pre-push` closes the gap, but surfaces a regression at push, away from the commit that caused it.
Also rejected.

Leaving the hook unchanged (51 s per matching commit) was the third option; parallelism removes most of that cost at no loss of coverage.

## Open points

- Test isolation under parallelism rests on two green runs (2026-09-18), on the twenty parallel passes recorded above, and against them on one unexplained failure.
  On 2026-09-30 the hook failed once at commit time, exit 1 on a suite of 1,483 tests, and four runs afterwards came back green at 1,483: serial, `bats --jobs 12`, `prek run bats-tests --all-files`, and the retried commit, which produced `0638496`.
  It happened a second time on 2026-11-06, exit 1 at commit time on the 1,830 tests of the staged state, and every run after it came back green: four `prek run bats-tests` in that same state, three parallel runs of the whole suite, and every commit since.
  Neither failing test was ever identified, the output being truncated before the `not ok` line, on the terminal the first time and at the harness's own storage the second, so nothing establishes whether it was an isolation defect under parallelism or something outside the suite.
  The capture the first occurrence called for is in place since 2026-11-06: the `entry` adds `--report-formatter junit --output "${XDG_RUNTIME_DIR:-/tmp}/bats-report"`, whose `report.xml` names every case and its failures whatever happens to the hook's own output, and the hook's `name` carries that path so a failing run shows where to read it. A third occurrence is nameable.
  It happened a third time on 2026-11-07, exit 1 at commit time on the 1,849 tests of the staged state, and the capture delivered: `report.xml` held exactly one failure, `sys-orphans.bats` on "reports a uv tool whose interpreter is gone once, with a uv repair, not its entry points", where the hook's own output was truncated again before any `not ok` line. So the mechanism answers the question the first two occurrences left open, and the answer is one named test rather than a suite-wide isolation defect.
  Six runs after it came back green: three serial and two parallel runs of `sys-orphans.bats` alone, then the whole suite under the hook's exact invocation, `--jobs "$(nproc)" --report-formatter junit --output`. The test builds its fixtures under its own `FAKE_HOME` and `ROOT` and asserts on output text alone, so nothing in it shares a path with another suite, and what makes it fail under a full parallel load is still unestablished.
  The remedy stays unapplied, the rule below asking for reproducibility that six green runs deny. What changes is that a fourth occurrence on this same test would meet it, and the name is now on record to compare against.
  If a test turns reproducibly flaky, `--no-parallelize-within-files` keeps parallelism at file level only; applying it against a single unidentified failure would treat a symptom nothing has located.
