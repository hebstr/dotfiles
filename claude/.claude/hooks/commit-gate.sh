#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
active=$(printf '%s' "$payload" | jq -r '.stop_hook_active // false | tostring' 2>/dev/null) || exit 0
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0

[[ $active == false ]] || exit 0
[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 0

printf '%s' "$payload" | jq -e '(.last_assistant_message // "") | test("(^|\n)[ \t]*(git [^\n]*[;&|][ \t]*)?git commit\\b")' >/dev/null 2>&1 || exit 0

runtime="${XDG_RUNTIME_DIR:-/tmp}"
journal="$runtime/claude-code-writes-${session}.log"
stamp_file="$runtime/claude-code-writes-${session}.stamp"

stamp=0
if [[ -r $stamp_file ]]; then
  read -r stamp <"$stamp_file" || true
  [[ $stamp =~ ^[0-9]+$ ]] || stamp=0
fi

root="${CLAUDE_PROJECT_DIR:-$cwd}"
[[ -n $root ]] && root=$(realpath -m -- "$root" 2>/dev/null || printf '%s' "$root")
top=""
[[ -n $root ]] && top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || top=""
memory=$(realpath -m -- "$HOME/.claude/memory" 2>/dev/null || printf '%s' "$HOME/.claude/memory")

in_work_tree() {
  local dir=${1%/*}
  while [[ -n $dir && ! -d $dir ]]; do
    dir=${dir%/*}
  done
  [[ $(git -C "${dir:-/}" rev-parse --is-inside-work-tree 2>/dev/null) == true ]]
}

excluded() {
  [[ -n $root && $1 == "$root/.claude/"* ]] && return 0
  [[ -n $top && $1 == "$top/.claude/"* ]] && return 0
  [[ $1 == "$memory/"* ]]
}

changed_since_stamp() {
  local mtime
  if [[ -e $1 || -L $1 ]]; then
    mtime=$(stat -c '%.9Y' -- "$1" 2>/dev/null) || return 1
    mtime=${mtime/./}
    [[ $mtime =~ ^[0-9]+$ ]] || return 1
    ((10#$mtime > stamp))
  else
    ((stamp == 0))
  fi
}

declare -A seen=()
stale=()
if [[ -r $journal ]]; then
  while IFS=$'\t' read -r ts path; do
    [[ $ts =~ ^[0-9]+$ && -n $path ]] || continue
    ((ts > stamp)) || continue
    excluded "$path" && continue
    [[ -n ${seen[$path]:-} ]] && continue
    seen[$path]=1
    in_work_tree "$path" || continue
    stale+=("$path")
  done <"$journal"
fi

if [[ -n $top ]]; then
  while IFS= read -r -d '' entry; do
    path="$top/${entry:3}"
    excluded "$path" && continue
    [[ -n ${seen[$path]:-} ]] && continue
    changed_since_stamp "$path" || continue
    seen[$path]=1
    stale+=("$path")
  done < <(git -C "$top" status --porcelain=v1 -z --no-renames --untracked-files=all 2>/dev/null)
fi

((${#stale[@]} > 0)) || exit 0

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
