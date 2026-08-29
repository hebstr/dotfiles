---
name: "Shell failure propagation under set -Eeuo pipefail: what crashes and what is swallowed"
description: "Two opposite failure shapes under set -Eeuo pipefail: grep as a mid-pipeline filter crashes the script, while a process substitution or the left operand of an && list swallows the failure and reports success"
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

**Encountered:**
- `bin/.local/bin/sys-cleanup` `clean_claude_versions` (twice), 2026-05-10
- `bin/.local/bin/devtools-update` `get_latest_version`, 2026-05-10
- `bin/.local/bin/claude-plugins-update`, 2026-08-29, both swallowed shapes at once: the plugin loop read from `< <(jq -er ...)` and the `mcp.json` rewrite was a bare `jq ... >"$tmp" && mv ...`. Pinned by `_meta/tests/claude-plugins-update.bats`

When auditing a new shell script, run: `rg -n 'grep[^|]*\|' script | grep -v '|| (true|echo|{)'` to surface candidates.
