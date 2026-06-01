---
name: Shell pipelines: grep as filter under set -Eeuo pipefail
description: Latent crash pattern when grep is used as a filter (not a test) inside a captured pipeline; how to spot it and fix it
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

Same applies to `jq`, `awk` with explicit `exit 1`, or any filter that returns non-zero on "nothing to do." A `< <(pipeline)` redirection is *usually* safe (process substitution exit status is silent), but for consistency in the same function, fix both forms together.

**Encountered:**
- `bin/.local/bin/sys-cleanup` `clean_claude_versions` (twice), 2026-05-10
- `bin/.local/bin/devtools-update` `get_latest_version`, 2026-05-10

When auditing a new shell script, run: `rg -n 'grep[^|]*\|' script | grep -v '|| (true|echo|{)'` to surface candidates.
