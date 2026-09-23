#!/usr/bin/env bash
set -uo pipefail

session=${1-}
root=${2-}

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 2

runtime="${XDG_RUNTIME_DIR:-/tmp}"
journal="$runtime/claude-code-writes-${session}.log"
stamp_file="$runtime/claude-code-writes-${session}.stamp"
failed=0

stamp=0
if [[ -e $stamp_file ]]; then
  value=""
  [[ -r $stamp_file ]] && { read -r value <"$stamp_file" || true; }
  if [[ $value =~ ^[0-9]+$ ]]; then
    stamp=$value
  else
    failed=1
  fi
fi

[[ -n $root ]] && root=$(realpath -m -- "$root" 2>/dev/null || printf '%s' "$root")
top=""
[[ -n $root ]] && top=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null) || top=""
memory=$(realpath -m -- "$HOME/.claude/memory" 2>/dev/null || printf '%s' "$HOME/.claude/memory")

in_work_tree_unignored() {
  local dir=${1%/*}
  while [[ -n $dir && ! -d $dir ]]; do
    dir=${dir%/*}
  done
  [[ $(git -C "${dir:-/}" rev-parse --is-inside-work-tree 2>/dev/null) == true ]] || return 1
  ! git -C "${dir:-/}" check-ignore -q -- "$1" 2>/dev/null
}

excluded() {
  [[ -n $root && $1 == "$root/.claude/"* ]] && return 0
  [[ -n $top && $1 == "$top/.claude/"* ]] && return 0
  [[ $1 == "$memory/"* ]]
}

changed_since_stamp() {
  local ctime
  if [[ -e $1 || -L $1 ]]; then
    ctime=$(stat -c '%.9Z' -- "$1" 2>/dev/null) || return 1
    ctime=${ctime/./}
    [[ $ctime =~ ^[0-9]+$ ]] || return 1
    ((10#$ctime > stamp))
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
    in_work_tree_unignored "$path" || continue
    stale+=("$path")
  done <"$journal"
elif [[ -e $journal ]]; then
  failed=1
fi

if [[ -n $top ]]; then
  entries=()
  mapfile -d '' -t entries < <(git --no-optional-locks -C "$top" status --porcelain=v1 -z --no-renames --untracked-files=all 2>/dev/null)
  wait "$!" || failed=1
  for entry in "${entries[@]}"; do
    path="$top/${entry:3}"
    excluded "$path" && continue
    [[ -n ${seen[$path]:-} ]] && continue
    changed_since_stamp "$path" || continue
    seen[$path]=1
    stale+=("$path")
  done
fi

((${#stale[@]} == 0)) || printf '%s\n' "${stale[@]}"
exit "$failed"
