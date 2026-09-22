#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false | tostring' 2>/dev/null) || exit 0
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0

[[ $active == false ]] || exit 0
[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

printf '%s' "$payload" | jq -e '(.last_assistant_message // "") | contains("git commit -m")' >/dev/null 2>&1 || exit 0

runtime="${XDG_RUNTIME_DIR:-/tmp}"
journal="$runtime/claude-code-writes-${session}.log"
stamp_file="$runtime/claude-code-writes-${session}.stamp"
[[ -r $journal ]] || exit 0

stamp=0
if [[ -r $stamp_file ]]; then
  read -r stamp <"$stamp_file" || true
  [[ $stamp =~ ^[0-9]+$ ]] || stamp=0
fi

root="${CLAUDE_PROJECT_DIR:-$cwd}"
[[ -n $root ]] && root=$(realpath -m -- "$root" 2>/dev/null || printf '%s' "$root")
memory=$(realpath -m -- "$HOME/.claude/memory" 2>/dev/null || printf '%s' "$HOME/.claude/memory")

declare -A seen=()
stale=()
while IFS=$'\t' read -r ts path; do
  [[ $ts =~ ^[0-9]+$ && -n $path ]] || continue
  ((ts > stamp)) || continue
  [[ -n $root && $path == "$root/.claude/"* ]] && continue
  [[ $path == "$memory/"* ]] && continue
  [[ -n ${seen[$path]:-} ]] && continue
  seen[$path]=1
  stale+=("$path")
done <"$journal"

((${#stale[@]} > 0)) || exit 0

{
  printf 'Commit gate: the commit blocks just shown are stale. '
  printf '%d file(s) outside the tracking files were written after the last tracking verification:\n' "${#stale[@]}"
  for p in "${stale[@]:0:10}"; do
    printf '  %s\n' "$p"
  done
  ((${#stale[@]} > 10)) && printf '  ... and %d more\n' "$((${#stale[@]} - 10))"
  printf 'Invoke the /commit skill now: it runs the tracking verifier, then renders the commit blocks again. '
  printf 'Tell the user that the blocks already displayed are stale and must not be run.\n'
} >&2
exit 2
