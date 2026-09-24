#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false | tostring' 2>/dev/null) || exit 0
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

runtime="${XDG_RUNTIME_DIR:-/tmp}"
blocked="$runtime/claude-code-commit-gate-${session}.blocked"

if [[ $active == false ]]; then
  rm -f -- "$blocked"
elif [[ -e $blocked ]]; then
  rm -f -- "$blocked"
  exit 0
fi

printf '%s' "$payload" | jq -e '(.last_assistant_message // "") | test("(^|\n)[ \t]*(([A-Za-z_][A-Za-z0-9_]*=(\"[^\"\n]*\"|[^ \t\n\"])*[ \t]+)*git [^\n]*[;&|][ \t]*)?([A-Za-z_][A-Za-z0-9_]*=(\"[^\"\n]*\"|[^ \t\n\"])*[ \t]+)*git([ \t]+-[Cc][ \t]+[^ \t\n]+)*[ \t]+commit\\b")' >/dev/null 2>&1 || exit 0

stale=()
mapfile -t stale < <("$BASH" "${BASH_SOURCE[0]%/*}/commit-stale.sh" "$session" "${CLAUDE_PROJECT_DIR:-$cwd}" 2>/dev/null)

((${#stale[@]} > 0)) || exit 0

: >"$blocked" 2>/dev/null

{
  printf 'Commit gate: the commit blocks just shown are stale. '
  printf '%d file(s) outside the tracking files were changed after the last tracking verification:\n' "${#stale[@]}"
  for p in "${stale[@]:0:10}"; do
    printf '  %s\n' "$p"
  done
  ((${#stale[@]} > 10)) && printf '  ... and %d more\n' "$((${#stale[@]} - 10))"
  printf 'Invoke the /commit skill now: it runs the tracking verifier, then renders the commit blocks again. '
  printf 'Tell the user that the blocks already displayed are stale and must not be run.\n'
} >&2
exit 2
