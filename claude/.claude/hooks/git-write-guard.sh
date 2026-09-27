#!/usr/bin/env bash
set -uo pipefail

verdict=0
[[ ${1-} == --verdict ]] && verdict=1

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0

[[ ${cmd//[\"\'\\]/} == *git* ]] || exit 0

confirmed='add|commit|rm|mv'
left='push|reset|checkout|switch|restore|stash|merge|rebase|tag|cherry-pick|revert|clean|pull|am'
gated="$confirmed|stage|$left|branch"
mark=$'\x1f'

deny() {
  ((verdict)) && exit 1
  printf 'git write guard: %s\n' "$@" >&2
  exit 2
}

reroute() {
  deny "this command runs git $1 through $2, which the permission dialog does not see." \
    "Write it as a plain \`git $1 ...\` at the start of a command, from the repository (\`cd <repo> && git $1 ...\`), so that the user confirms it. Do not look for another form."
}

leave() {
  deny "$1 is a git write the user runs: leave it to the user, and do not look for another form."
}

strip_quotes() {
  local s=$1 out="" q="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    if [[ -n $q ]]; then
      if [[ $q == '"' && $c == "\\" ]]; then
        ((i++))
      elif [[ $c == "$q" ]]; then
        q=""
      fi
      continue
    fi
    case $c in
    \' | \")
      q=$c
      out+=$mark
      ;;
    \\)
      out+=${s:i:2}
      ((i++))
      ;;
    *) out+=$c ;;
    esac
  done
  printf '%s' "$out"
  [[ -z $q ]]
}

declare -A alias_of=()
while read -r key value; do
  alias_of[${key#alias.}]=$value
done < <(git -C "${cwd:-.}" config --get-regexp '^alias\.' 2>/dev/null)

runner='(^|[^[:alnum:]_./-])((bash|sh|zsh|dash|ksh)[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*-[[:alnum:]]*c|eval)([[:space:]]|$)'
mention="(^|[^[:alnum:]_./-])git[^[:alnum:]_-]([^;&|"$'\n'"]*[^[:alnum:]_-])?($gated)([^[:alnum:]_-]|\$)"
if [[ $cmd =~ $runner && ${cmd#*"${BASH_REMATCH[0]}"} =~ $mention ]]; then
  deny "this command runs a git write through a shell string (bash -c, eval), which the permission rules do not see." \
    "Write git add, commit, rm or mv as a plain command so that the user confirms it; leave every other git write to the user. Do not look for another form."
fi

check_commit_options() {
  local tok name letters k
  for tok in "$@"; do
    case $tok in
    --*)
      name=${tok%%=*}
      if ((${#name} >= 6)) && [[ --no-verify == "$name"* ]]; then
        deny "--no-verify skips the prek hooks: run the commit without it, or leave it to the user."
      fi
      if ((${#name} >= 4)) && [[ --amend == "$name"* ]]; then
        deny "--amend rewrites the last commit: leave it to the user."
      fi
      ;;
    -?*)
      letters=${tok#-}
      for ((k = 0; k < ${#letters}; k++)); do
        case ${letters:k:1} in
        n) deny "-n is --no-verify, which skips the prek hooks: run the commit without it, or leave it to the user." ;;
        [mFCctuS]) break ;;
        esac
      done
      ;;
    esac
  done
}

branch_writes() {
  local tok value listing=0 positional=0 skip=0
  for tok in "$@"; do
    if ((skip)); then
      value=$((skip == 2))
      skip=0
      ((value)) || [[ $tok != -* ]] && continue
    fi
    if [[ $tok =~ ^-[arvilq]+$ ]]; then
      [[ $tok == *l* ]] && listing=1
      continue
    fi
    case $tok in
    --list) listing=1 ;;
    --contains | --no-contains | --merged | --no-merged) skip=1 ;;
    --points-at | --sort | --format) skip=2 ;;
    --all | --remotes | --verbose | --quiet | --show-current | --ignore-case | --omit-empty | --no-color | --no-column | --no-abbrev) ;;
    --contains=* | --no-contains=* | --merged=* | --no-merged=* | --points-at=* | --sort=* | --format=* | --color | --color=* | --column | --column=* | --abbrev=*) ;;
    -*) return 0 ;;
    *) positional=1 ;;
    esac
  done
  ((positional && !listing))
}

tracked=0
fallback=0
specs=()

take() {
  local abs
  if [[ -z $dir || $1 == *"$mark"* || $1 == *'$'* || $1 == *\\* || $1 == :* || $1 == *[\*\?\[]* ]]; then
    fallback=1
    return
  fi
  case $1 in
  /*) abs=$1 ;;
  [~]) abs=$HOME ;;
  [~]/*) abs=$HOME/${1:2} ;;
  [~]*)
    fallback=1
    return
    ;;
  *) abs=$dir/$1 ;;
  esac
  abs=$(realpath -m -- "$abs" 2>/dev/null) || {
    fallback=1
    return
  }
  specs+=("$abs")
}

staging_specs() {
  local tok letters dashdash=0
  for tok in "$@"; do
    if ((dashdash)); then
      take "$tok"
      continue
    fi
    case $tok in
    --) dashdash=1 ;;
    -u | --update) tracked=1 ;;
    -A | --all | --no-ignore-removal | -p | --patch | -i | --interactive | -e | --edit | --pathspec-from-file*) fallback=1 ;;
    --*) ;;
    -?*)
      letters=${tok#-}
      [[ $letters == *[Apie]* ]] && fallback=1
      [[ $letters == *u* ]] && tracked=1
      ;;
    *) take "$tok" ;;
    esac
  done
}

move_specs() {
  local tok dashdash=0 paths=()
  for tok in "$@"; do
    if ((!dashdash)); then
      case $tok in
      --)
        dashdash=1
        continue
        ;;
      -?*) continue ;;
      esac
    fi
    paths+=("$tok")
  done
  ((${#paths[@]} > 1)) || return 0
  for tok in "${paths[@]:0:${#paths[@]}-1}"; do
    take "$tok"
  done
}

commit_specs() {
  local tok letters k dashdash=0 skip=0
  for tok in "$@"; do
    if ((skip)); then
      skip=0
      continue
    fi
    if ((dashdash)); then
      take "$tok"
      continue
    fi
    case $tok in
    --) dashdash=1 ;;
    -a | --all) tracked=1 ;;
    -p | --patch | --interactive | --pathspec-from-file*) fallback=1 ;;
    --message | --file | --reuse-message | --reedit-message | --template | --author | --date | --fixup | --squash | --cleanup | --trailer) skip=1 ;;
    --*) ;;
    -?*)
      letters=${tok#-}
      for ((k = 0; k < ${#letters}; k++)); do
        case ${letters:k:1} in
        a) tracked=1 ;;
        p) fallback=1 ;;
        [mFCct])
          ((k == ${#letters} - 1)) && skip=1
          break
          ;;
        esac
      done
      ;;
    *) take "$tok" ;;
    esac
  done
}

commits=0
dir=${cwd:-.}
commit_dir=$dir
stripped=$(strip_quotes "$cmd") ||
  deny "this command leaves a quote open to the guard's parser (an apostrophe in a comment or a heredoc), which hides everything after it." \
    "Drop the apostrophe, or run the git part as a command of its own."
segments=${stripped//[;&|()\`]/$'\n'}
while IFS= read -r segment; do
  read -ra w <<<"$segment"
  n=${#w[@]}
  i=0
  while ((i < n)) && [[ ${w[i]} =~ ^[A-Za-z_][A-Za-z0-9_]*= || ${w[i]} =~ ^(\{|!|if|then|else|elif|do|while|until)$ ]]; do
    ((i++))
  done
  if ((i < n)) && [[ ${w[i]} == cd || ${w[i]} == pushd || ${w[i]} == popd ]]; then
    target=${w[i + 1]-}
    if [[ ${w[i]} == popd || ${w[i]} == pushd && -z $target ]]; then
      dir=""
      continue
    fi
    case $target in
    '' | [~]) dir=$HOME ;;
    *"$mark"* | *'$'* | *\\* | -*) dir="" ;;
    [~]/*) dir=$HOME/${target:2} ;;
    [~]*) dir="" ;;
    /*) dir=$target ;;
    *) [[ -n $dir ]] && dir=$dir/$target ;;
    esac
    continue
  fi
  j=$i
  while ((j < n)); do
    bare=${w[j]//[\\$mark]/}
    [[ $bare == git || $bare == */git ]] && break
    ((j++))
  done
  ((j < n)) || continue
  wrapper=""
  ((j > i)) && wrapper=${w[i]}
  i=$j
  program=$bare
  escaped=0
  [[ $program != "${w[i]}" ]] && escaped=1
  ((i++))
  options=0
  redirected=0
  while ((i < n)); do
    if [[ ${w[i]} =~ ^[0-9]*[\<\>] ]]; then
      redirected=1
      [[ ${w[i]} =~ ^[0-9]*[\<\>]+$ ]] && ((i++))
      ((i++))
      continue
    fi
    case ${w[i]} in
    -C | -c | --git-dir | --work-tree | --namespace | --exec-path | --super-prefix | --config-env | --attr-source)
      options=1
      ((i += 2))
      ;;
    -*)
      options=1
      ((i++))
      ;;
    *) break ;;
    esac
  done
  sub=${w[i]-}
  args=("${w[@]:i+1}")
  [[ -n $sub ]] || continue
  if [[ $sub == *"$mark"* || $sub == *'$'* ]]; then
    deny "the git subcommand is quoted or held in a variable, which hides it from the permission rules: write it plainly."
  fi
  [[ $sub == *\\* ]] && escaped=1
  sub=${sub//\\/}

  via=""
  [[ -n $wrapper ]] && via="the wrapper $wrapper"
  [[ $program != git ]] && via="git called by path ($program)"
  ((escaped)) && via="an escaped or quoted git or subcommand"
  ((redirected)) && via="a redirection before the subcommand"
  ((options)) && via="git global options before the subcommand"

  depth=0
  while [[ ! $sub =~ ^($gated)$ && -n ${alias_of[${sub,,}]+set} ]]; do
    ((depth++ < 10)) ||
      deny "the alias git $sub expands through too many aliases to be read: write the git command plainly."
    expansion=${alias_of[${sub,,}]}
    if [[ $expansion == '!'* ]]; then
      if [[ $expansion =~ (^|[^[:alnum:]_-])($gated)([^[:alnum:]_-]|$) ]]; then
        deny "the alias git $sub runs a git write through a shell, which the permission dialog does not see." \
          "Write git add, commit, rm or mv as a plain command so that the user confirms it; leave every other git write to the user. Do not look for another form."
      fi
      continue 2
    fi
    read -ra expanded <<<"$expansion"
    via="the alias git $sub"
    sub=${expanded[0]-}
    args=("${expanded[@]:1}" "${args[@]}")
  done

  if [[ $sub == stage ]]; then
    deny "git stage is git add under another name, which the permission rules do not see: write it as git add."
  fi
  if [[ $sub =~ ^($left)$ ]]; then
    leave "git $sub"
  fi
  if [[ $sub == branch ]]; then
    branch_writes "${args[@]}" && leave "git branch with a branch name or a write option (create, rename, copy, delete, upstream)"
    continue
  fi
  [[ $sub =~ ^($confirmed)$ ]] || continue
  [[ -n $via ]] && reroute "$sub" "$via"
  case $sub in
  add | rm) staging_specs "${args[@]}" ;;
  mv) move_specs "${args[@]}" ;;
  commit)
    [[ -n $dir ]] ||
      deny "this command changes directory before the commit to a place the guard cannot resolve (a quoted or escaped path, a variable, an option, cd -, popd)." \
        "Write the cd target as a plain path, so that the tracking check reads the repository the commit takes place in."
    commit_dir=$dir
    check_commit_options "${args[@]}"
    commit_specs "${args[@]}"
    commits=1
    ;;
  esac
done <<<"$segments"

((commits)) || exit 0

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] ||
  deny "could not check the tracking verification: the session id is unusable. Leave the commit to the user."

top=$(git -C "$commit_dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
entries=()
mapfile -d '' -t entries < <(git --no-optional-locks -C "$top" status --porcelain=v1 -z --no-renames --untracked-files=all 2>/dev/null)
wait "$!" ||
  deny "could not check the tracking verification: git status failed in $top. Invoke the commit skill again; if it persists, leave the commit to the user."

picked=()
for entry in "${entries[@]}"; do
  code=${entry:0:2}
  path="$top/${entry:3}"
  if ((fallback)) || [[ ${code:0:1} != [\ ?!] ]]; then
    picked+=("$path")
    continue
  fi
  if ((tracked)) && [[ $code != '??' && $code != '!!' && ${code:1:1} != ' ' ]]; then
    picked+=("$path")
    continue
  fi
  for spec in "${specs[@]}"; do
    if [[ $path == "$spec" || $path == "$spec/"* ]]; then
      picked+=("$path")
      break
    fi
  done
done

stale_script="${BASH_SOURCE[0]%/*}/commit-stale.sh"
stale=()
mapfile -t stale < <({ ((${#picked[@]} == 0)) || printf '%s\0' "${picked[@]}"; } | "$BASH" "$stale_script" --only "$session" "$top" 2>/dev/null)
wait "$!" ||
  deny "could not check the tracking verification: a source of commit-stale.sh was unreadable. Invoke the commit skill again; if it persists, leave the commit to the user."

if ((verdict)); then
  ((${#stale[@]} == 0)) || printf '%s\n' "${stale[@]}"
  exit 0
fi

((${#stale[@]} > 0)) || exit 0

changed=()
unsealed=()
for line in "${stale[@]}"; do
  if [[ ${line%%$'\t'*} == unsealed ]]; then
    unsealed+=("${line#*$'\t'}")
  else
    changed+=("${line#*$'\t'}")
  fi
done

list() {
  local p
  for p in "${@:1:10}"; do
    printf '  %s\n' "$p"
  done
  (($# <= 10)) || printf '  ... and %d more\n' "$(($# - 10))"
}

{
  if ((${#changed[@]} > 0)); then
    printf 'git write guard: %d file(s) this commit takes changed after the last tracking verification:\n' "${#changed[@]}"
    list "${changed[@]}"
    printf 'Invoke the commit skill now: it runs the tracking verifier and renders the blocks again. Do not retry this commit.\n'
  fi
  if ((${#unsealed[@]} > 0)); then
    printf 'git write guard: %d file(s) this commit takes were never sealed by the last tracking verification, so another session may be writing them:\n' "${#unsealed[@]}"
    list "${unsealed[@]}"
    printf "Leave them out of the staging command, now and after any new verifier pass, whose seal would take them in and let a later commit carry that session's work; if one is already staged, leave the commit to the user. Only if this session wrote them through Edit or Write after its last verification, invoke the commit skill instead.\n"
  fi
} >&2
exit 2
