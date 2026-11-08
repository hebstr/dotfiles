#!/usr/bin/env bash
set -uo pipefail

session=${CLAUDE_CODE_SESSION_ID-}
runtime="${XDG_RUNTIME_DIR:-/tmp}"
tmpdir="${TMPDIR:-/tmp}"
while [[ $tmpdir == */ && $tmpdir != / ]]; do tmpdir=${tmpdir%/}; done

if [[ ! $session =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'tail.sh: no usable CLAUDE_CODE_SESSION_ID, so no journal to read\n' >&2
  exit 3
fi

journal="$runtime/claude-code-writes-${session}.log"
stamp_file="${journal%.log}.stamp"

if [[ ! -e $journal ]]; then
  printf 'tail.sh: no write journal at %s, so no write of this session was journaled\n' "$journal" >&2
  exit 0
fi

if [[ ! -r $journal ]]; then
  printf 'tail.sh: the write journal at %s is unreadable, so the scope cannot be computed\n' "$journal" >&2
  exit 1
fi

stamp=0
if [[ -e $stamp_file ]]; then
  if [[ ! -r $stamp_file ]]; then
    printf 'tail.sh: the stamp at %s is unreadable, so the scope cannot be computed\n' "$stamp_file" >&2
    exit 1
  fi
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
  ((10#$ts > 10#$stamp)) && paths+=("$path")
done <"$journal"

[[ -z $ts$path ]] || malformed=$((malformed + 1))

((${#paths[@]} == 0)) || printf '%s\n' "${paths[@]}" | LC_ALL=C sort -u

if ((malformed > 0)); then
  printf 'tail.sh: %d journal line(s) carry no timestamp and were skipped, so the scope is incomplete\n' "$malformed" >&2
  exit 1
fi

exit 0
