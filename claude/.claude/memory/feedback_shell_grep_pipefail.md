---
name: "Shell failure propagation under set -Eeuo pipefail: what crashes and what is swallowed"
description: "Failure shapes under set -Eeuo pipefail: grep as a mid-pipeline filter crashes the script, while a process substitution or the left operand of an && list swallows the failure and reports success; plus a filter whose exit status answers 'did I run' and not 'did I find something' (jq -e conflating absent-key with unparseable, jq -r letting a literal null through), and $? read after a command substitution in the same command, which reports the substitution's status and turns a gate sweep into a false pass"
metadata:
  type: feedback
---

In any shell script with `set -Eeuo pipefail`, `grep` used as a **filter** mid-pipeline (not as a test) crashes the script when it matches nothing.

```bash
# BUGGY: if grep matches nothing it returns 1, pipefail propagates,
# the assignment fails, and set -e kills the script BEFORE the
# `if [[ -z "$var" ]]` branch you wrote to handle the empty case.
var=$(some_cmd | grep -E 'pattern' | sort -V | tail -n1)
if [[ -z "$var" ]]; then
  # unreachable
fi
```

**Why:** `set -e` *does* propagate to assignments via command substitution in modern bash (verified: `bash -c 'set -e; x=$(false); echo y'` exits 1). Combined with `pipefail`, any failing pipeline element kills the parent. `grep` semantically returns 1 on "no match". This is fine when grep is a test, but fatal when grep is a filter.

**How to apply:** when reviewing or writing shell, scan every `set -Eeuo pipefail` script for pipelines where `grep`'s exit status is not the meaningful outcome. Two idiomatic fixes:

```bash
# Option 1: tolerate empty grep output (preferred when filtering)
var=$(some_cmd | { grep -E 'pattern' || true; } | sort -V | tail -n1)

# Option 2: catch the whole pipeline failure (preferred when caller has a fallback)
var=$(some_cmd | grep -E 'pattern' | sort -V | tail -n1 || true)
```

Same applies to `jq`, `awk` with explicit `exit 1`, or any filter that returns non-zero on "nothing to do."

## The mirror image: failures that are swallowed rather than fatal

A `< <(pipeline)` redirection does not crash the script, because a process substitution's exit status is silent. That silence is a safety property against the crash above and a defect anywhere the command's success is the point: the loop simply runs zero times and the script continues as if the work was done.

```bash
# BUGGY: jq's exit status is discarded. A malformed file updates nothing
# and the script still exits 0.
while IFS= read -r item; do ...; done < <(jq -r '.things | keys[]' "$f")

# FIX: command substitution DOES propagate the status.
if ! items=$(jq -r '.things | keys[]' "$f"); then
  echo "could not read ${f}" >&2
  FAILED=1
elif [ "$items" != "" ]; then
  while IFS= read -r item; do ...; done <<<"$items"
fi
```

**`&&` lists are asymmetric under `set -e`, and only the last operand is fatal.** Verified 2026-08-29:

```bash
bash -c 'set -euo pipefail; false && echo ran; echo AFTER'   # prints AFTER, exits 0
bash -c 'set -euo pipefail; true && false; echo AFTER'       # exits 1, AFTER unreachable
```

So in `cmd_a >"$tmp" && mv "$tmp" "$dst"`, a failure of `cmd_a` or of its redirection is exempt from errexit and execution falls through to whatever success message follows, while a failure of `mv` aborts. Writing the whole list as an `if` condition removes the asymmetry: both operands then reach the `else`, and the failure is accounted for explicitly rather than by abort.

When a script keeps a `FAILED` accumulator so one failure does not stop the run, every one of these swallowed paths is a hole in that accounting, not a crash to prevent.

**Inside a function, the asymmetry above is intact and the function *call* is what aborts.** A reviewer reading `f() { cmd && return 0; [[ test ]] && return 3; return 1; }` will claim the `[[ ]]` kills the shell and `return 1` is unreachable, which looks true from the outside and is false: measured on bash 5.2.21, a trace placed on the `return 1` line prints, the exempt `&&` list falls through exactly as at top level, and what exits 1 is the unguarded call `f` returning non-zero under errexit. The two diagnoses are observationally identical and prescribe opposite remedies: rewriting the list as `if [[ test ]]; then return 3; fi` is behaviour-identical (exit 1 and exit 3 unchanged on both paths), where the real exposure is the call site, and `f || st=$?` is what covers it. Before accepting a claim that a return path is unreachable under `set -e`, put an `echo` on that line and run it. Measured 2026-11-06 on `probe_set` in `css-toolchain-update` (`/audit:walkthrough`, finding REJECTED on this).

**A fix applied to one script of a pair does not travel to its sibling.** `claude-plugins-update` carried the corrected shape and the comment explaining it since the day before, in the same directory, while `claude-plugins-install` kept the bug: an unparseable `settings.json` printed two jq errors, restored nothing, and still ended on `Done.` with exit 0, defeating the script's only purpose. After fixing this shape anywhere, grep the sibling scripts for `< <(` before closing the task. Both are pinned by `_meta/tests/claude-plugins-update.bats` and `_meta/tests/claude-plugins-install.bats`.

## A third shape: a non-zero status that means two different things

`jq -e` returns 1 when the last output is `null` or `false` and 5 when the input does not parse. Used as a boolean guard, those collapse:

```bash
# BUGGY: an absent key (normal) and an unparseable file (broken) both skip
# the block, silently, and the script exits 0.
if [ -f "$f" ] && jq -e '.a.b' "$f" >/dev/null 2>&1; then
  ...
fi

# FIX: probe validity first, so only the absent-key case stays silent.
if [ -f "$f" ]; then
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "Could not read ${f}" >&2
    FAILED=1
  elif jq -e '.a.b' "$f" >/dev/null 2>&1; then
    ...
  fi
fi
```

Branch on the validity probe, never on the numeric code: `jq`'s manual documents 1, 2, 3 and 4, and no code for malformed input, so the 5 is an artefact of the installed build.

The mirror of this is a *zero* status that means "nothing there": `jq -r '.a.b'` prints the four characters `null` and exits 0 when the key is missing, so a downstream `[ "$v" != "" ]` guard passes and the word reaches whatever the value feeds. `jq -er` closes it by turning the null into exit 1, which an existing `|| v=""` fallback already handles. The general rule covers both directions: a filter's exit status answers "did I run", never "did I find something", so any guard that treats the two as the same question has a hole.

Both shapes and the tests that pinned them left the repository on 2026-10-08 with the Ouroboros uninstall, so no live example remains.

## A fourth shape: `$?` read after a command substitution in the same command

`$?` holds the status of the last command to finish, and a command substitution inside the very command that reads it counts. So a loop reporting a tool's exit code through `printf '%s exit=%s' "$(basename "$f")" "$?"` reports `basename`'s status, which is always 0, and every file passes. Measured 2026-11-07 on bash 5.2.21:

```bash
false; printf 'file=%s exit=%s\n' "$(basename /a/b)" "$?"            # file=b exit=0, wrong
false; rc=$?; printf 'file=%s exit=%s\n' "$(basename /a/b)" "$rc"    # file=b exit=1, right
```

Capture into a variable on its own line, immediately after the command, and read the variable. This bit a `panache format --check` sweep whose every line read `exit=0` while the real statuses were mixed, and that false pass was then written into a memory note as a measured fact about panache's cache, which it was not. The direction of the error is the dangerous one: a gate declared green that never ran. The same shape hides a non-zero status behind any `$(...)`, `"$(wc -l <"$f")"` included, so it is not specific to `basename`.

A sibling of it, from the same session: an env var whose value the tool rejects makes the whole invocation a usage error rather than a run with the flag off. `PANACHE_NO_CACHE=1` exits 2 with `invalid value '1' for '--no-cache' [possible values: true, false]`, so the boolean env vars of a clap-based CLI take `true` and `false`, never `1`. Combined with the `$?` shape above, a sweep can report success from a tool that never examined a single file.

When auditing a new shell script, run: `rg -n 'grep[^|]*\|' script | grep -Ev '\|\| (true|echo|\{)'` to surface candidates. The `-E` is load-bearing: in basic syntax `|` and `(` are literal and the filter removes nothing.
