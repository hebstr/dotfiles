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

pattern='(^|\n)[ \t]*(([A-Za-z_][A-Za-z0-9_]*=("[^"\n]*"|[^ \t\n"])*[ \t]+)*git [^\n]*[;&|][ \t]*)?([A-Za-z_][A-Za-z0-9_]*=("[^"\n]*"|[^ \t\n"])*[ \t]+)*git([ \t]+-[Cc][ \t]+[^ \t\n]+)*[ \t]+commit\b'
printf '%s' "$payload" | jq -e --arg re "$pattern" '(.last_assistant_message // "") | test($re)' >/dev/null 2>&1 || exit 0

open='^ {0,3}(`{3,}|~{3,})'
close='^ {0,3}(`{3,}|~{3,})[[:space:]]*$'
blocks=()
fence=""
block=""
while IFS= read -r line || [[ -n $line ]]; do
  if [[ -z $fence ]]; then
    [[ $line =~ $open ]] || continue
    fence=${BASH_REMATCH[1]}
    block=""
  elif [[ $line =~ $close && ${BASH_REMATCH[1]:0:1} == "${fence:0:1}" && ${#BASH_REMATCH[1]} -ge ${#fence} ]]; then
    blocks+=("$block")
    fence=""
  else
    block+=$line$'\n'
  fi
done < <(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null)
[[ -z $fence ]] || blocks+=("$block")

command=""
((${#blocks[@]} == 0)) ||
  command=$(printf '%s\0' "${blocks[@]}" | jq -Rrs --arg re "$pattern" '[split("\u0000")[] | select(test($re))] | join("\n")' 2>/dev/null)

stale=()
judged=0
if [[ -n $command ]]; then
  mapfile -t stale < <(jq -nc --arg s "$session" --arg c "$cwd" --arg x "$command" '{session_id: $s, cwd: $c, tool_input: {command: $x}}' |
    "$BASH" "${BASH_SOURCE[0]%/*}/git-write-guard.sh" --verdict 2>/dev/null)
  wait "$!" && judged=1
fi
if ((!judged)); then
  stale=()
  mapfile -t stale < <("$BASH" "${BASH_SOURCE[0]%/*}/commit-stale.sh" "$session" "${CLAUDE_PROJECT_DIR:-$cwd}" 2>/dev/null)
fi

((${#stale[@]} > 0)) || exit 0

: >"$blocked" 2>/dev/null

changed=()
unsealed=()
if ((judged)); then
  for line in "${stale[@]}"; do
    if [[ ${line%%$'\t'*} == unsealed ]]; then
      unsealed+=("${line#*$'\t'}")
    else
      changed+=("${line#*$'\t'}")
    fi
  done
else
  changed=("${stale[@]}")
fi

list() {
  local p
  for p in "${@:1:10}"; do
    printf '  %s\n' "$p"
  done
  (($# <= 10)) || printf '  ... and %d more\n' "$(($# - 10))"
}

{
  if ((${#changed[@]} > 0)); then
    printf 'Commit gate: the commit blocks just shown are stale. '
    if ((judged)); then
      printf '%d file(s) they take changed after the last tracking verification:\n' "${#changed[@]}"
    else
      printf '%d file(s) outside the tracking files were changed after the last tracking verification:\n' "${#changed[@]}"
    fi
    list "${changed[@]}"
    printf 'Invoke the /commit skill now: it runs the tracking verifier, then renders the commit blocks again. '
    printf 'Tell the user that the blocks already displayed are stale and must not be run.\n'
  fi
  if ((${#unsealed[@]} > 0)); then
    printf 'Commit gate: %d file(s) the commit blocks just shown take were never sealed by the last tracking verification, so another session may be writing them:\n' "${#unsealed[@]}"
    list "${unsealed[@]}"
    printf "Tell the user that the blocks already displayed must not be run, then render them again with these paths left out of the staging commands, now and after any new verifier pass, whose seal would take them in and let a later commit carry that session's work. "
    printf 'Only if this session wrote them through Edit or Write after its last verification, invoke the /commit skill instead.\n'
  fi
} >&2
exit 2
