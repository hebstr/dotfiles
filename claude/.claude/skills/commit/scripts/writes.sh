#!/usr/bin/env bash
set -uo pipefail

restamp=0
named=()
if [[ ${1-} == --restamp ]]; then
  restamp=1
  shift
  named=("$@")
fi

stamp_value=$(date +%s%N)
session=${CLAUDE_CODE_SESSION_ID-}
runtime="${XDG_RUNTIME_DIR:-/tmp}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code"
stale_script="${BASH_SOURCE[0]%/*}/../../../hooks/commit-stale.sh"
failed=0

if [[ $session =~ ^[A-Za-z0-9_-]+$ ]]; then
  journal="$runtime/claude-code-writes-${session}.log"
  printf 'STAMP_FILE=%s\nSTAMP_VALUE=%s\n' "${journal%.log}.stamp" "$stamp_value"
elif ((restamp)); then
  printf 'writes.sh: no usable CLAUDE_CODE_SESSION_ID, so no stamp to rewrite\n' >&2
  exit 3
else
  journal=""
  printf 'writes.sh: no usable CLAUDE_CODE_SESSION_ID, so no journal and no stamp\n' >&2
  failed=3
fi

journaled=()
if [[ -n $journal && -r $journal ]]; then
  while IFS=$'\t' read -r _ path; do
    [[ -n $path ]] && journaled+=("$path")
  done <"$journal"
fi
paths=("${journaled[@]}")

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

if ((restamp == 0)); then
  sweep=yes
  marker=""
  today=$(date +%F)
  if [[ -n $top ]] && key=$(printf '%s' "$top" | sha256sum 2>/dev/null); then
    marker="$state_dir/verifier-sweep-${key:0:16}"
  fi
  if [[ -n $marker && -r $marker ]]; then
    IFS=$'\t' read -r last _ <"$marker" && [[ $last == "$today" ]] && sweep=no
  fi
  printf 'SWEEP=%s\n' "$sweep"
  if [[ -n $marker && $sweep == yes ]]; then
    if ! (
      umask 077
      mkdir -p "$state_dir" && printf '%s\t%s\n' "$today" "$top" >"$marker"
    ) 2>/dev/null; then
      printf 'writes.sh: could not post the sweep marker under %s, so the next pass of the day sweeps again\n' "$state_dir" >&2
    fi
  fi
fi

listed=()
((${#paths[@]} == 0)) || mapfile -t listed < <(printf '%s\n' "${paths[@]}" | LC_ALL=C sort -u)

sealing=()
((${#journaled[@]} == 0)) || mapfile -t sealing < <(printf '%s\n' "${journaled[@]}" | LC_ALL=C sort -u)
carry=()
if ((restamp)) && ((${#named[@]} > 0)); then
  sealing=("${named[@]}")
  carry=(--carry)
fi

if [[ -n $journal ]]; then
  if ! { ((${#sealing[@]} == 0)) || printf '%s\0' "${sealing[@]}"; } | "$BASH" "$stale_script" --seal "$session" "$stamp_value" "${carry[@]}"; then
    printf 'writes.sh: could not record the snapshot, so the stale check falls back to ctime\n' >&2
    ((restamp)) && exit 1
  elif ((restamp)); then
    if ! { printf '%s\n' "$stamp_value" >"${journal%.log}.stamp"; } 2>/dev/null; then
      printf 'writes.sh: could not write the stamp\n' >&2
      exit 1
    fi
  fi
fi

((restamp)) && exit "$failed"
((${#listed[@]} == 0)) || printf '%s\n' "${listed[@]}"
exit "$failed"
