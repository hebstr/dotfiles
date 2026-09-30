#!/usr/bin/env bash
set -uo pipefail

mode=list
case ${1-} in
--only | --seal)
  mode=${1#--}
  shift
  ;;
esac

session=${1-}
root=${2-}

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] || exit 2

runtime="${XDG_RUNTIME_DIR:-/tmp}"
journal="$runtime/claude-code-writes-${session}.log"
stamp_file="$runtime/claude-code-writes-${session}.stamp"
snapshot_prefix="$runtime/claude-code-writes-${session}."
failed=0

digest() {
  local out
  if [[ -L $1 ]]; then
    out=$(readlink -- "$1" 2>/dev/null) || return 1
    printf 'l:%s' "$out"
  elif [[ -f $1 ]]; then
    out=$({ sha256sum <"$1"; } 2>/dev/null) || return 1
    if [[ -x $1 ]]; then
      printf 'f:%s:x' "${out%% *}"
    else
      printf 'f:%s:-' "${out%% *}"
    fi
  elif [[ -e $1 ]]; then
    printf 'o'
  else
    printf '%s' -
  fi
}

if [[ $mode == seal ]]; then
  sealed_value=${2-}
  carry=0
  [[ ${3-} == --carry ]] && carry=1
  [[ $sealed_value =~ ^[0-9]+$ ]] || exit 2
  (
    umask 077
    {
      declare -A resealed=()
      printf '%s\n' "$sealed_value"
      while IFS= read -r -d '' path; do
        [[ -n $path && $path != *[$'\t\n']* ]] || continue
        resealed[$path]=1
        d=$(digest "$path") || continue
        [[ $d != *[$'\t\n']* ]] || continue
        printf '%s\t%s\n' "$d" "$path"
      done
      if ((carry)); then
        previous=""
        [[ -r $stamp_file ]] && { read -r previous <"$stamp_file" || true; }
        if [[ $previous =~ ^[0-9]+$ && -r "${snapshot_prefix}${previous}.seen" ]]; then
          {
            IFS= read -r header || header=""
            if [[ $header == "$previous" ]]; then
              while IFS=$'\t' read -r d p; do
                if [[ -n $p && -z ${resealed[$p]+set} ]]; then
                  printf '%s\t%s\n' "$d" "$p"
                fi
              done
            fi
          } <"${snapshot_prefix}${previous}.seen"
        fi
      fi
    } >"${snapshot_prefix}${sealed_value}.seen"
  ) 2>/dev/null || exit
  current=""
  [[ -r $stamp_file ]] && { read -r current <"$stamp_file" || true; }
  for old in "$snapshot_prefix"*.seen; do
    [[ $old == "${snapshot_prefix}${sealed_value}.seen" || $old == "${snapshot_prefix}${current}.seen" ]] && continue
    rm -f -- "$old"
  done
  exit 0
fi

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

sealed=0
declare -A sealed_digest=()
snapshot="${snapshot_prefix}${stamp}.seen"
if ((stamp > 0)) && [[ -r $snapshot ]]; then
  {
    IFS= read -r header || header=""
    if [[ $header == "$stamp" ]]; then
      sealed=1
      while IFS=$'\t' read -r d p; do
        [[ -n $p ]] && sealed_digest[$p]=$d
      done
    fi
  } <"$snapshot"
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

declare -A owner=()
owners_read=0

read_owners() {
  local file id path
  ((owners_read)) && return 0
  owners_read=1
  for file in "$runtime"/claude-code-writes-*.log; do
    [[ -r $file ]] || continue
    id=${file##*/claude-code-writes-}
    id=${id%.log}
    while IFS=$'\t' read -r _ path; do
      [[ -n $path ]] || continue
      if [[ $id == "$session" ]]; then
        owner[$path]=self
      else
        [[ -n ${owner[$path]+set} ]] || owner[$path]=peer
      fi
    done <"$file"
  done
}

changed() {
  local now ctime
  class=changed
  if ((sealed)); then
    if ! now=$(digest "$1"); then
      failed=1
      return 0
    fi
    if [[ -n ${sealed_digest[$1]+set} ]]; then
      [[ $now != "${sealed_digest[$1]}" ]]
    else
      if [[ $1 == *[$'\t\n']* ]]; then
        class=unsealed
        return 0
      fi
      read_owners
      case ${owner[$1]-} in
      self) class=changed ;;
      peer) class=unsealed ;;
      *) return 1 ;;
      esac
      [[ $now != - || $2 == listed ]]
    fi
    return
  fi
  [[ $2 == journal ]] && return 0
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

if [[ $mode == only ]]; then
  while IFS= read -r -d '' path; do
    [[ -n $path ]] || continue
    excluded "$path" && continue
    [[ -n ${seen[$path]:-} ]] && continue
    seen[$path]=1
    changed "$path" listed || continue
    stale+=("$class"$'\t'"$path")
  done
else
  if [[ -r $journal ]]; then
    while IFS=$'\t' read -r ts path; do
      [[ $ts =~ ^[0-9]+$ && -n $path ]] || continue
      ((ts > stamp)) || continue
      excluded "$path" && continue
      [[ -n ${seen[$path]:-} ]] && continue
      if ! in_work_tree_unignored "$path"; then
        seen[$path]=1
        continue
      fi
      changed "$path" journal || continue
      seen[$path]=1
      stale+=("$class"$'\t'"$path")
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
      changed "$path" listed || continue
      seen[$path]=1
      stale+=("$class"$'\t'"$path")
    done
  fi
fi

((${#stale[@]} == 0)) || printf '%s\n' "${stale[@]}"
exit "$failed"
