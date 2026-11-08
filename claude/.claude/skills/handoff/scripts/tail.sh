#!/usr/bin/env bash
set -uo pipefail

session=${CLAUDE_CODE_SESSION_ID-}
runtime="${XDG_RUNTIME_DIR:-/tmp}"
tmpdir="${TMPDIR:-/tmp}"

if [[ ! $session =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'tail.sh: no usable CLAUDE_CODE_SESSION_ID, so no journal to read\n' >&2
  exit 3
fi

journal="$runtime/claude-code-writes-${session}.log"
stamp_file="${journal%.log}.stamp"

if [[ ! -r $journal ]]; then
  printf 'tail.sh: no readable write journal at %s\n' "$journal" >&2
  exit 1
fi

stamp=0
if [[ -r $stamp_file ]]; then
  read -r stamp <"$stamp_file"
  if [[ ! $stamp =~ ^[0-9]+$ ]]; then
    printf 'tail.sh: the stamp at %s is not a timestamp, so the scope cannot be computed\n' "$stamp_file" >&2
    exit 1
  fi
else
  printf 'tail.sh: no stamp file at %s, so the whole journal is the scope\n' "$stamp_file" >&2
fi

paths=()
malformed=0
while IFS=$'\t' read -r ts path; do
  if [[ -z $path || ! $ts =~ ^[0-9]+$ ]]; then
    malformed=$((malformed + 1))
    continue
  fi
  case $path in "$tmpdir"/* | /tmp/*) continue ;; esac
  ((ts > stamp)) && paths+=("$path")
done <"$journal"

((${#paths[@]} == 0)) || printf '%s\n' "${paths[@]}" | LC_ALL=C sort -u

if ((malformed > 0)); then
  printf 'tail.sh: %d journal line(s) carry no timestamp and were skipped, so the scope is incomplete\n' "$malformed" >&2
  exit 1
fi

exit 0
