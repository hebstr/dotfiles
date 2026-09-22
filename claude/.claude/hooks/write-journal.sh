#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
file=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
[[ -n $file ]] || exit 0

real=$(realpath -m -- "$file" 2>/dev/null) || real=$file
[[ $real == *$'\n'* || $real == *$'\t'* ]] && exit 0
journal="${XDG_RUNTIME_DIR:-/tmp}/claude-code-writes-${session}.log"

umask 077
{ printf '%s\t%s\n' "$(date +%s%N)" "$real" >>"$journal"; } 2>/dev/null || true
exit 0
