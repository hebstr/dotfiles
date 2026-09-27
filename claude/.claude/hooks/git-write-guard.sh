#!/usr/bin/env bash
set -uo pipefail

verdict=0
[[ ${1-} == --verdict ]] && verdict=1

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0

confirmed='add|commit|rm|mv'
left='push|reset|checkout|switch|restore|stash|merge|rebase|tag|cherry-pick|revert|clean|pull|am|update-ref|fast-import'
gated="$confirmed|stage|$left|branch"
mixed='symbolic-ref|worktree|fetch'
gated_word="(^|[^[:alnum:]_-])($gated)([^[:alnum:]_-]|\$)"
ansi_escape='[$]'\''[^'\'']*[\\][^tnr'\''"\\]'
mark=$'\x1f'
hide=$'\x1e'

[[ ${cmd//[\"\'\\]/} == *git* || $cmd == *\$\'* || ($cmd == *[\$\`]* && $cmd =~ $gated_word) ]] || exit 0

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

keep() {
  if [[ $1 == [[:space:]\;\&\|\(\)\`] ]]; then
    plain+=$mark
  else
    plain+=$1
  fi
}

strip_quotes() {
  local s=$1 q="" c i comment=0 ansi=0
  stripped=""
  plain=""
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    if [[ -n $q ]]; then
      if [[ $c == "$q" ]]; then
        q=""
      elif ((ansi)) && [[ $c == "\\" ]]; then
        plain+=$hide
        ((i++))
      elif [[ $q == '"' && $c == "\\" ]]; then
        ((i++))
        keep "${s:i:1}"
      elif [[ $q == "'" && $c == '$' ]]; then
        plain+=$mark
      elif [[ $q == '"' && $c == '`' ]]; then
        plain+='$'
      else
        keep "$c"
      fi
      continue
    fi
    case $c in
    \' | \")
      q=$c
      ansi=0
      stripped+=$mark
      plain+=$mark
      ;;
    '$')
      if [[ ${s:i+1:1} == [\'\"] ]]; then
        ((i++))
        q=${s:i:1}
        ansi=0
        [[ $q == "'" ]] && ansi=1
        stripped+=$mark
        plain+=$mark
      else
        stripped+=$c
        plain+=$c
      fi
      ;;
    \\)
      if [[ ${s:i+1:1} == $'\n' ]]; then
        if ((comment)); then
          stripped+=${s:i:2}
          plain+=${s:i:2}
        fi
        comment=0
      else
        stripped+=${s:i:2}
        plain+=${s:i:2}
      fi
      ((i++))
      ;;
    '#')
      ((i == 0)) || [[ ${s:i-1:1} == [[:space:]\;\&\|\(\)] ]] && comment=1
      stripped+=$c
      plain+=$c
      ;;
    $'\n')
      comment=0
      stripped+=$c
      plain+=$c
      ;;
    *)
      stripped+=$c
      plain+=$c
      ;;
    esac
  done
  [[ -z $q ]]
}

declare -A known=()
if listed=$(git --list-cmds=builtins,main,others 2>/dev/null) &&
  deprecated=$(git --list-cmds=deprecated 2>/dev/null); then
  while read -r name; do
    [[ -n $name ]] && known[$name]=1
  done <<<"$listed"
  while read -r name; do
    [[ -n $name ]] && unset 'known[$name]'
  done <<<"$deprecated"
fi

after_git_options() {
  local -n words=$1
  local m
  for ((m = $2; m < ${#words[@]}; m++)); do
    case ${words[m]} in
    -C | -c | --git-dir | --work-tree | --namespace | --exec-path | --super-prefix | --config-env | --attr-source) ((m++)) ;;
    -*) ;;
    *) break ;;
    esac
  done
  printf '%s' "${words[m]-}"
}

runner='(^|[^[:alnum:]_./-])(([^[:space:];&|]*/)?(bash|sh|zsh|dash|ksh)[[:blank:]]+([^[:space:];&|]+[[:blank:]]+)*-[[:alnum:]]*c|eval)([[:space:]]|$)'
joined=${cmd//$'\\\n'/}
if [[ $joined =~ $runner ]]; then
  inner=${joined#*"${BASH_REMATCH[3]}${BASH_REMATCH[4]:-eval}"}
  [[ $inner =~ $ansi_escape ]] &&
    deny "this command runs a shell string written with \$'...' escapes, which the guard cannot read and the permission rules do not see." \
      "Write git add, commit, rm or mv as a plain command so that the user confirms it; leave every other git write to the user. Do not look for another form."
  inner=${inner//\$\'/\'}
  inner=${inner//\$\"/\"}
  inner=${inner//[\"\'\\]/}
  while IFS= read -r segment; do
    read -ra w <<<"$segment"
    for ((k = 0; k < ${#w[@]}; k++)); do
      [[ ${w[k]} == git || ${w[k]} == */git ]] || continue
      sub=$(after_git_options w $((k + 1)))
      [[ -n $sub ]] || continue
      if [[ $sub == *'$'* || $sub =~ ^($gated|$mixed)$ || -z ${known[$sub]+set} ]]; then
        deny "this command runs git $sub through a shell string (bash -c, eval), which the permission rules do not see: only a git read git lists by name runs there." \
          "Write git add, commit, rm or mv as a plain command so that the user confirms it; leave every other git write to the user. Do not look for another form."
      fi
    done
  done <<<"${inner//[;&|()\`]/$'\n'}"
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

symref_writes() {
  local tok positional=0 skip=0
  for tok in "$@"; do
    if ((skip)); then
      skip=0
      continue
    fi
    case $tok in
    -d | --delete) return 0 ;;
    -m) skip=1 ;;
    -*) ;;
    *) positional=$((positional + 1)) ;;
    esac
  done
  ((positional >= 2))
}

worktree_writes() {
  local tok detach=0 positional=0 skip=0
  [[ ${1-} == add ]] || return 1
  shift
  for tok in "$@"; do
    if ((skip)); then
      skip=0
      continue
    fi
    case $tok in
    --*)
      long_prefix "$tok" --track --guess-remote --orphan && return 0
      long_prefix "$tok" --detach && detach=1
      [[ $tok == --reason ]] && skip=1
      ;;
    -?*)
      [[ $tok == *[bB]* ]] && return 0
      [[ $tok == *d* ]] && detach=1
      ;;
    *) positional=$((positional + 1)) ;;
    esac
  done
  ((!detach && positional < 2))
}

fetch_writes() {
  local tok seen=0
  for tok in "$@"; do
    case $tok in
    --*) long_prefix "$tok" --update-head-ok --refmap && return 0 ;;
    -?*) [[ $tok == *u* ]] && return 0 ;;
    *)
      ((seen)) && [[ $tok == *:* ]] && return 0
      seen=1
      ;;
    esac
  done
  return 1
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
  local abs parent
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
  if ! abs=$(realpath -m -s -- "$abs" 2>/dev/null) || ! parent=$(realpath -m -- "${abs%/*}/" 2>/dev/null); then
    fallback=1
    return
  fi
  specs+=("${parent%/}/${abs##*/}")
  abs=$(realpath -m -- "$abs" 2>/dev/null) || {
    fallback=1
    return
  }
  specs+=("$abs")
}

long_prefix() {
  local name=${1%%=*} opt
  shift
  ((${#name} >= 3)) || return 1
  for opt in "$@"; do
    [[ $opt == "$name"* ]] && return 0
  done
  return 1
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
    -u) tracked=1 ;;
    -A | -p | -i | -e) fallback=1 ;;
    --*)
      if long_prefix "$tok" --all --no-ignore-removal --patch --interactive --edit --pathspec-from-file; then
        fallback=1
      elif long_prefix "$tok" --update --renormalize; then
        tracked=1
      fi
      ;;
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
    -a) tracked=1 ;;
    -p) fallback=1 ;;
    --message | --file | --reuse-message | --reedit-message | --template | --author | --date | --fixup | --squash | --cleanup | --trailer) skip=1 ;;
    --*)
      if long_prefix "$tok" --patch --interactive --pathspec-from-file; then
        fallback=1
      elif long_prefix "$tok" --all; then
        tracked=1
      fi
      ;;
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
moved=0
other=""
dir=${cwd:-.}
commit_dir=$dir
if ! strip_quotes "$cmd"; then
  [[ ${cmd//[\"\'\\]/} == *git* ]] || exit 0
  deny "this command leaves a quote open to the guard's parser (an apostrophe in a comment or a heredoc), which hides everything after it." \
    "Drop the apostrophe, or run the git part as a command of its own."
fi
stripped=${stripped//">&"/">"}
stripped=${stripped//"<&"/"<"}
stripped=${stripped//"&>"/">"}
plain=${plain//">&"/">"}
plain=${plain//"<&"/"<"}
plain=${plain//"&>"/">"}
segments=${stripped//[;&|()\`]/$'\n'}
seps=""
opened=""
ticks=0
for ((p = 0; p < ${#stripped}; p++)); do
  c=${stripped:p:1}
  case $c in
  '(')
    if ((p > 0)) && [[ ${stripped:p-1:1} == '$' ]]; then
      opened+='s'
    else
      opened+='p'
    fi
    seps+=$c
    ;;
  ')')
    if [[ ${opened: -1} == s ]]; then
      seps+=S
    else
      seps+=$c
    fi
    opened=${opened%?}
    ;;
  '`')
    ticks=$((ticks + 1))
    if ((ticks % 2 == 0)); then
      seps+=B
    else
      seps+=$c
    fi
    ;;
  ';' | '&' | '|' | $'\n') seps+=$c ;;
  esac
done
mapfile -t plains <<<"${plain//[;&|()\`]/$'\n'}"
idx=-1
while IFS= read -r segment; do
  idx=$((idx + 1))
  read -ra w <<<"$segment"
  read -ra pw <<<"${plains[idx]-}"
  n=${#w[@]}
  i=0
  assigned=""
  while ((i < n)) && [[ ${w[i]} =~ ^[A-Za-z_][A-Za-z0-9_]*= || ${w[i]} =~ ^(\{|!|if|then|else|elif|do|while|until)$ ]]; do
    [[ ${w[i]} == *=* && ${w[i]%%=*} != SKIP ]] && assigned=${w[i]%%=*}
    ((i++))
  done
  for word in "${w[@]}"; do
    [[ $word =~ ^(CDPATH|HOME)= ]] && moved=1
    [[ -z $other && $word == *'>'* ]] && other="a redirection"
  done
  if ((i < n)) && [[ ${w[i]} == cd || ${w[i]} == pushd || ${w[i]} == popd ]]; then
    target=${w[i + 1]-}
    if [[ ${w[i]} == popd || ${w[i]} == pushd && -z $target ]]; then
      dir=""
      continue
    fi
    case $target in
    '' | [~]) dir=$HOME ;;
    *"$mark"* | *'$'* | *\\* | -* | +*) dir="" ;;
    [~]/*) dir=$HOME/${target:2} ;;
    [~]*) dir="" ;;
    /*) dir=$target ;;
    *) [[ -n $dir ]] && dir=$dir/$target ;;
    esac
    ((moved)) && dir=""
    continue
  fi
  ((moved)) && dir=""
  ((i < n)) && [[ -z ${pw[i]//[\\$mark]/} ]] && dir=""
  for ((k = i; k < n; k++)); do
    [[ ${pw[k]//[\\$mark]/} =~ ^(cd|pushd|popd)$ ]] && dir=""
  done
  from=-1
  if ((idx > 0)) && [[ ${seps:idx-1:1} == [SB] ]]; then
    from=$i
  elif ((i < n)) && [[ ${pw[i]-} == *[\$$hide]* ]]; then
    from=$((i + 1))
  fi
  if ((from >= 0)); then
    verb=$(after_git_options pw "$from")
    if [[ ${verb//[\\$mark]/} =~ ^($gated|$mixed)$ || $verb == *"$hide"* ]]; then
      deny "this command runs ${verb//[$mark$hide]/} through a program name the guard cannot read (a variable, a substitution or \$'...' escapes), which the permission rules do not see." \
        "Write git add, commit, rm or mv as a plain command so that the user confirms it; leave every other git write to the user. Do not look for another form."
    fi
  fi
  j=$i
  while ((j < n)); do
    bare=${pw[j]-}
    bare=${bare//[\\$mark]/}
    if [[ $bare == git || $bare == */git ]]; then
      [[ ${w[j]} != *"$mark"* ]] || ((j == i)) && break
      next=$(after_git_options pw $((j + 1)))
      [[ ${next//[\\$mark]/} =~ ^($gated)$ ]] && break
    fi
    ((j++))
  done
  if ((j == n)); then
    [[ -z $other && i -lt n ]] && other=${pw[i]//[$mark$hide]/}
    continue
  fi
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
  args=()
  skip=0
  for tok in "${w[@]:i+1}"; do
    if ((skip)); then
      skip=0
    elif [[ $tok =~ ^[0-9]*[\<\>]+$ ]]; then
      skip=1
    elif [[ ! $tok =~ ^[0-9]*[\<\>] ]]; then
      args+=("$tok")
    fi
  done
  if [[ -z $sub ]]; then
    [[ -n $other ]] || other=git
    continue
  fi
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

  ((${#known[@]} > 0)) ||
    deny "could not read the list of git commands (git --list-cmds), so the subcommand cannot be checked: leave this git command to the user."
  [[ -n $sub && -n ${known[$sub]+set} ]] ||
    deny "git $sub is not a command git lists (an alias, or a deprecated command an alias can override), which hides what it runs from the permission rules: write the git command plainly." \
      "If git is only an argument of another program here, quote it ('git')."

  if [[ $sub == stage ]]; then
    deny "git stage is git add under another name, which the permission rules do not see: write it as git add."
  fi
  if [[ $sub =~ ^($left)$ ]]; then
    leave "git $sub"
  fi
  if [[ $sub == branch ]]; then
    branch_writes "${args[@]}" && leave "git branch with a branch name or a write option (create, rename, copy, delete, upstream)"
    [[ -n $other ]] || other="git branch"
    continue
  fi
  if [[ $sub == symbolic-ref ]] && symref_writes "${args[@]}"; then
    leave "git symbolic-ref with a ref to point at, or -d"
  fi
  if [[ $sub == worktree ]] && worktree_writes "${args[@]}"; then
    leave "git worktree add creating or resetting a branch (-b, -B, --orphan, --track, or no commit-ish without --detach)"
  fi
  if [[ $sub == fetch ]] && fetch_writes "${args[@]}"; then
    leave "git fetch into a local ref (a refspec with a colon, -u, --refmap)"
  fi
  if [[ ! $sub =~ ^($confirmed)$ ]]; then
    [[ -n $other ]] || other="git $sub"
    continue
  fi
  [[ -n $via ]] && reroute "$sub" "$via"
  [[ -n $assigned ]] &&
    deny "$assigned before git $sub can change the repository, the index or the configuration git uses, which the guard's checks do not follow: write it as a plain \`git $sub ...\`, SKIP= being the only assignment kept."
  case $sub in
  add | rm) staging_specs "${args[@]}" ;;
  mv) move_specs "${args[@]}" ;;
  commit)
    ((${#args[@]} == 1)) && [[ ${args[0]} == -h || ${args[0]} == --help ]] && continue
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
[[ -z $other ]] ||
  deny "this command runs $other alongside git commit: a write it makes lands after the tracking check, so the commit could take content the verification never saw." \
    "A command holding git commit runs only cd and git add, rm, mv or commit: run the rest as a command of its own."
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
