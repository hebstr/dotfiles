#!/usr/bin/env bash
set -uo pipefail

stamp_value=$(date +%s%N)
session=${CLAUDE_CODE_SESSION_ID-}
runtime="${XDG_RUNTIME_DIR:-/tmp}"
failed=0

if [[ $session =~ ^[A-Za-z0-9_-]+$ ]]; then
  journal="$runtime/claude-code-writes-${session}.log"
  printf 'STAMP_FILE=%s\nSTAMP_VALUE=%s\n' "${journal%.log}.stamp" "$stamp_value"
else
  journal=""
  printf 'writes.sh: no usable CLAUDE_CODE_SESSION_ID, so no journal and no stamp\n' >&2
  failed=3
fi

paths=()
if [[ -n $journal && -r $journal ]]; then
  while IFS=$'\t' read -r _ path; do
    [[ -n $path ]] && paths+=("$path")
  done <"$journal"
fi

if top=$(git rev-parse --show-toplevel 2>/dev/null); then
  entries=()
  mapfile -d '' -t entries < <(git -C "$top" status --porcelain=v1 -z --no-renames --untracked-files=all 2>/dev/null)
  if ! wait "$!"; then
    printf 'writes.sh: git status failed in %s\n' "$top" >&2
    ((failed == 0)) && failed=1
  fi
  for entry in "${entries[@]}"; do
    paths+=("$top/${entry:3}")
  done
else
  printf 'writes.sh: no git repository from %s, so no git status\n' "$PWD" >&2
  ((failed == 0)) && failed=1
fi

((${#paths[@]} == 0)) || printf '%s\n' "${paths[@]}" | LC_ALL=C sort -u
exit "$failed"
