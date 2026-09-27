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
left='push|reset|checkout|switch|restore|stash|merge|rebase|tag|cherry-pick|revert|clean|pull|am|update-ref|fast-import|replay|filter-branch|bisect|send-pack'
gated="$confirmed|stage|$left|branch"
mixed='symbolic-ref|worktree|fetch|config|apply|checkout-index|read-tree'
gated_word="(^|[^[:alnum:]_-])($gated)([^[:alnum:]_-]|\$)"
hide=$'\x1e'
jq_file="${BASH_SOURCE[0]%/*}/git-write-guard.jq"
plainly="Write git add, commit, rm or mv as a plain command so that the user confirms it; leave every other git write to the user. Do not look for another form."

unjudged() {
  ((verdict)) && exit 1
  exit 0
}

[[ ${cmd//[\"\'\\]/} == *git* || $cmd == *\$\'* || ($cmd == *[\$\`]* && $cmd =~ $gated_word) ]] || unjudged

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

command -v shfmt >/dev/null 2>&1 ||
  deny "shfmt is missing, so the guard cannot read this command: install it (sudo apt install shfmt), and leave the git command to the user until then."
[[ -r $jq_file ]] ||
  deny "could not read git-write-guard.jq beside the guard, so it cannot read this command: leave the git command to the user."

parse() {
  mapfile -d '' -t tok < <(printf '%s' "$1" | shfmt -ln bash --to-json 2>/dev/null | jq -j -f "$jq_file" 2>/dev/null)
  wait "$!" && [[ ${tok[0]-} != X ]]
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

read_call() {
  local k na
  hdoc=$pend_hdoc
  hdocf=$pend_hdocf
  hdocset=$pend_set
  pend_hdoc=""
  pend_hdocf=""
  pend_set=0
  na=${tok[t]}
  names=("${tok[@]:t+1:na}")
  t=$((t + 1 + na))
  nw=${tok[t]}
  t=$((t + 1))
  wf=()
  wv=()
  for ((k = 0; k < nw; k++)); do
    wf+=("${tok[t]}")
    wv+=("${tok[t + 1]}")
    t=$((t + 2))
  done
}

after_git_options() {
  local m
  gitc=()
  gitloc=0
  for ((m = $1; m < nw; m++)); do
    case ${wv[m]} in
    -C)
      gitc+=("${wf[m + 1]-}"$'\t'"${wv[m + 1]-}")
      ((m++))
      ;;
    --git-dir | --work-tree)
      gitloc=1
      ((m++))
      ;;
    -c | --namespace | --exec-path | --super-prefix | --config-env | --attr-source) ((m++)) ;;
    --git-dir=* | --work-tree=*) gitloc=1 ;;
    -*) ;;
    *) break ;;
    esac
  done
  ge=$m
}

read_stdin() {
  ((hdocset)) ||
    deny "this command runs a shell that reads its script on stdin, which the guard cannot read and the permission rules do not see." "$plainly"
  [[ $hdocf != *d* ]] ||
    deny "this command runs a shell whose script comes from an expansion the guard cannot read." "$plainly"
  src=$hdoc
  [[ $hdocf == *o* ]] && opaque=1
  return 0
}

shell_source() {
  local k=$1 m c=0
  src=""
  opaque=0
  if [[ ${wf[k]} != *[do]* && (${wv[k]} == source || ${wv[k]} == .) ]]; then
    [[ ${wv[k + 1]-} == /dev/stdin ]] || return 1
    read_stdin
    return 0
  fi
  if [[ ${wv[k]} == eval && ${wf[k]} != *[do]* ]]; then
    ((k + 1 < nw)) || return 1
    for ((m = k + 1; m < nw; m++)); do
      src+="${wv[m]} "
      [[ ${wf[m]} == *o* ]] && opaque=1
    done
    return 0
  fi
  [[ ${wf[k]} != *[do]* && ${wv[k]##*/} =~ ^(bash|sh|zsh|dash|ksh)$ ]] || return 1
  for ((m = k + 1; m < nw; m++)); do
    case ${wv[m]} in
    --)
      m=$((m + 1))
      break
      ;;
    -o | -O | +o | +O | --rcfile | --init-file) m=$((m + 1)) ;;
    --version | --help) return 1 ;;
    --* | +*) ;;
    -*) [[ ${wv[m]} == *c* ]] && c=1 ;;
    *) break ;;
    esac
  done
  if ((c)); then
    ((m < nw)) || return 1
    src=${wv[m]}
    [[ ${wf[m]} == *o* ]] && opaque=1
    return 0
  fi
  ((m < nw)) && return 1
  ((k == 0 || hdocset)) || return 1
  read_stdin
}

deny_escapes() {
  deny "this command runs a shell string written with \$'...' escapes, which the guard cannot read and the permission rules do not see." "$plainly"
}

deny_split() {
  deny "this command names git and runs a program word built by an unquoted expansion or a brace expansion (\$x, \$(...), {a,b}), which word splitting can turn into a git call the guard cannot see." \
    "Quote the expansion (\"\$x\") or write the program plainly. $plainly"
}

string_verb() {
  [[ $2 == *[do]* || $1 == *[\$$hide]* || $1 =~ ^($gated|$mixed)$ || -z $1 || -z ${known[$1]+set} ]] || return 0
  deny "this command runs git ${1//$hide/} through a shell string (bash -c, eval), which the permission rules do not see: only a subcommand git lists by name, outside the gated verbs, runs there." "$plainly"
}

check_string() {
  local depth=$2 t=0 ev k nw=0 src opaque ge
  local hdoc="" hdocf="" hdocset=0 pend_hdoc="" pend_hdocf="" pend_set=0
  local -a tok=() names=() wf=() wv=()
  ((depth <= 3)) ||
    deny "this command nests shell strings deeper than the guard reads." "$plainly"
  if ! parse "$1"; then
    [[ ${1//[\"\'\\]/} == *git* ]] &&
      deny "this command runs a shell string that shfmt cannot parse, which hides its git calls from the guard." "$plainly"
    return 0
  fi
  while ((t < ${#tok[@]})); do
    ev=${tok[t]}
    t=$((t + 1))
    case $ev in
    K)
      t=$((t + 1))
      continue
      ;;
    H)
      pend_hdocf=${tok[t]}
      pend_hdoc=${tok[t + 1]}
      pend_set=1
      t=$((t + 2))
      continue
      ;;
    C) read_call ;;
    *) continue ;;
    esac
    ((nw > 0)) || continue
    for ((k = 0; k < nw; k++)); do
      if shell_source "$k"; then
        ((opaque)) && deny_escapes
        check_string "$src" $((depth + 1))
      fi
    done
    if [[ ${wf[0]} == *[do]* || ${wv[0]} == *[\$$hide]* ]]; then
      after_git_options 1
      if [[ ${wv[ge]-} =~ ^($gated|$mixed)$ || ${wv[ge]-} == *"$hide"* ]]; then
        string_verb "${wv[ge]}" "${wf[ge]}"
      fi
    fi
    [[ ${wf[0]} == *[ub]* || (${wv[0]} == *'$'* && ${wf[0]} != *q*) ]] && deny_split
    for ((k = 0; k < nw; k++)); do
      [[ ${wf[k]} != *d* && (${wv[k]} == git || ${wv[k]} == */git) ]] || continue
      after_git_options $((k + 1))
      ((ge < nw)) || continue
      string_verb "${wv[ge]}" "${wf[ge]}"
    done
  done
}

check_commit_options() {
  local tok name letters k skip=0
  for tok in "$@"; do
    if ((skip)); then
      skip=0
      continue
    fi
    case $tok in
    --) break ;;
    --message | --file | --reuse-message | --reedit-message | --template | --author | --date | --fixup | --squash | --cleanup | --trailer) skip=1 ;;
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
        [mFCct])
          ((k == ${#letters} - 1)) && skip=1
          break
          ;;
        [uS]) break ;;
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
    -m) skip=1 ;;
    --*) long_prefix "$tok" --delete && return 0 ;;
    -?*) [[ ${tok#-} == *d* ]] && return 0 ;;
    *) positional=$((positional + 1)) ;;
    esac
  done
  ((positional >= 2))
}

worktree_writes() {
  local a tok detach=0 positional=0 skip=0 ish=-1
  wt_ish=-1
  [[ ${args[0]-} == add ]] || return 1
  for ((a = 1; a < ${#args[@]}; a++)); do
    tok=${args[a]}
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
    *)
      positional=$((positional + 1))
      ((positional == 2)) && ish=$a
      ;;
    esac
  done
  ((detach)) && return 1
  ((positional >= 2)) || return 0
  wt_ish=$ish
  return 1
}

local_commit() {
  local base=$dir entry value
  [[ -n $base && $2 != *[qedo]* ]] && ((!gitloc)) || return 1
  for entry in "${gitc[@]}"; do
    [[ ${entry%%$'\t'*} != *[qedo]* ]] || return 1
    value=${entry#*$'\t'}
    case $value in
    /*) base=$value ;;
    [~]) base=$HOME ;;
    [~]/*) base=$HOME/${value:2} ;;
    [~]*) return 1 ;;
    *) base=$base/$value ;;
    esac
  done
  git -C "$base" rev-parse --verify --quiet --end-of-options "$1^{commit}" >/dev/null 2>&1
}

hooks_path_write() {
  local tok reading=0 keyed=0
  for tok in "$@"; do
    case $tok in
    --get | --get-all | --get-regexp | --get-urlmatch | --list | --unset | --unset-all | --show-origin | --show-scope) reading=1 ;;
    --*) ;;
    -*) ;;
    *)
      ((keyed)) && ((!reading)) && return 0
      [[ ${tok,,} == core.hookspath ]] && keyed=1
      ;;
    esac
  done
  return 1
}

apply_writes() {
  local tok
  for tok in "$@"; do
    case $tok in
    --*) long_prefix "$tok" --reverse && return 0 ;;
    -?*) [[ ${tok#-} == *R* ]] && return 0 ;;
    esac
  done
  return 1
}

checkout_index_writes() {
  local tok
  for tok in "$@"; do
    case $tok in
    --*) long_prefix "$tok" --force && return 0 ;;
    -?*) [[ ${tok#-} == *f* ]] && return 0 ;;
    esac
  done
  return 1
}

read_tree_writes() {
  local tok
  for tok in "$@"; do
    case $tok in
    --*) ;;
    -?*) [[ ${tok#-} == *u* ]] && return 0 ;;
    esac
  done
  return 1
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
  if [[ -z $dir || $2 == *[qedogb]* || $1 == :* || $1 == *[\*\?\[]* ]]; then
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

forced_add() {
  deny "git add -f stages a file the ignore rules exclude, which git status leaves out, so the tracking check cannot see whether the verification ever read it." \
    "Stage it without -f, or leave the commit to the user."
}

staging_specs() {
  local a tok letters dashdash=0
  for ((a = 0; a < ${#args[@]}; a++)); do
    tok=${args[a]}
    if ((dashdash)); then
      take "$tok" "${aflags[a]}"
      continue
    fi
    case $tok in
    --) dashdash=1 ;;
    -u) tracked=1 ;;
    -A | -p | -i | -e) fallback=1 ;;
    --*)
      [[ $sub == add ]] && long_prefix "$tok" --force && forced_add
      if long_prefix "$tok" --all --no-ignore-removal --patch --interactive --edit --pathspec-from-file; then
        fallback=1
      elif long_prefix "$tok" --update --renormalize; then
        tracked=1
      fi
      ;;
    -?*)
      letters=${tok#-}
      [[ $sub == add && $letters == *f* ]] && forced_add
      [[ $letters == *[Apie]* ]] && fallback=1
      [[ $letters == *u* ]] && tracked=1
      ;;
    *) take "$tok" "${aflags[a]}" ;;
    esac
  done
}

move_specs() {
  local a dashdash=0 paths=()
  for ((a = 0; a < ${#args[@]}; a++)); do
    if ((!dashdash)); then
      case ${args[a]} in
      --)
        dashdash=1
        continue
        ;;
      -?*) continue ;;
      esac
    fi
    paths+=("$a")
  done
  ((${#paths[@]} > 1)) || return 0
  for a in "${paths[@]:0:${#paths[@]}-1}"; do
    take "${args[a]}" "${aflags[a]}"
  done
}

commit_specs() {
  local a tok letters k dashdash=0 skip=0
  for ((a = 0; a < ${#args[@]}; a++)); do
    tok=${args[a]}
    if ((skip)); then
      skip=0
      continue
    fi
    if ((dashdash)); then
      take "$tok" "${aflags[a]}"
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
    *) take "$tok" "${aflags[a]}" ;;
    esac
  done
}

commits=0
moved=0
other=""
dir=${cwd:-.}
commit_dir=$dir
stack=()
src=""
opaque=0
hdoc=""
hdocf=""
hdocset=0
pend_hdoc=""
pend_hdocf=""
pend_set=0
tok=()
names=()
wf=()
wv=()
nw=0
if ! parse "$cmd"; then
  [[ ${cmd//[\"\'\\]/} == *git* ]] || unjudged
  deny "shfmt cannot parse this command, or reads a comment ending in a backslash as joined to the next line where bash does not, so the guard cannot see its git calls." \
    "Fix its syntax or drop that backslash, or run the git part as a command of its own."
fi
t=0
while ((t < ${#tok[@]})); do
  ev=${tok[t]}
  t=$((t + 1))
  case $ev in
  S)
    stack+=("$dir")
    continue
    ;;
  E)
    if ((${#stack[@]} > 0)); then
      dir=${stack[-1]}
      unset 'stack[-1]'
    fi
    continue
    ;;
  R)
    [[ -n $other ]] || other="a redirection"
    continue
    ;;
  K)
    [[ -n $other ]] || other=${tok[t]}
    t=$((t + 1))
    continue
    ;;
  H)
    pend_hdocf=${tok[t]}
    pend_hdoc=${tok[t + 1]}
    pend_set=1
    t=$((t + 2))
    continue
    ;;
  esac
  read_call
  assigned=""
  for name in "${names[@]}"; do
    [[ $name == SKIP ]] || assigned=$name
    [[ $name == CDPATH || $name == HOME ]] && moved=1
  done
  for word in "${wv[@]}"; do
    [[ $word =~ ^(CDPATH|HOME)= ]] && moved=1
  done
  if ((nw == 0)); then
    ((${#names[@]} == 0)) || [[ -n $other ]] || other="the assignment ${names[-1]}="
    ((moved)) && dir=""
    continue
  fi
  for ((k = 0; k < nw; k++)); do
    if shell_source "$k"; then
      ((opaque)) && deny_escapes
      check_string "$src" 1
    fi
  done

  prog=${wv[0]}
  pf=${wf[0]}
  if [[ -z $pf && $prog =~ ^(cd|pushd|popd)$ ]]; then
    if [[ $prog == popd || ($prog == pushd && nw -lt 2) ]]; then
      dir=""
      continue
    fi
    target=${wv[1]-}
    if ((nw < 2)); then
      dir=$HOME
    elif [[ ${wf[1]} == *[qedogb]* ]]; then
      dir=""
    else
      case $target in
      [~]) dir=$HOME ;;
      -* | +*) dir="" ;;
      [~]/*) dir=$HOME/${target:2} ;;
      [~]*) dir="" ;;
      /*) dir=$target ;;
      *) [[ -n $dir ]] && dir=$dir/$target ;;
      esac
    fi
    ((moved)) && dir=""
    continue
  fi
  ((moved)) && dir=""
  [[ -z $prog ]] && dir=""
  for word in "${wv[@]}"; do
    [[ $word =~ ^(cd|pushd|popd)$ ]] && dir=""
  done

  if [[ $pf == *[do]* ]]; then
    after_git_options 1
    verb=${wv[ge]-}
    if [[ $verb =~ ^($gated|$mixed)$ || $verb == *"$hide"* ]]; then
      deny "this command runs ${verb//$hide/} through a program name the guard cannot read (a variable, a substitution or \$'...' escapes), which the permission rules do not see." "$plainly"
    fi
  fi
  [[ $pf == *[ub]* ]] && deny_split

  j=0
  while ((j < nw)); do
    if [[ ${wf[j]} != *[do]* && (${wv[j]} == git || ${wv[j]} == */git) ]]; then
      [[ ${wf[j]} != *q* ]] || ((j == 0)) && break
      after_git_options $((j + 1))
      [[ ${wv[ge]-} =~ ^($gated)$ ]] && break
    fi
    ((j++))
  done
  if ((j == nw)); then
    name=$prog
    [[ -z $name || $name == *"$hide"* ]] && name="a program whose name the guard cannot read"
    [[ -n $other ]] || other=$name
    continue
  fi
  wrapper=""
  ((j > 0)) && wrapper=$prog
  program=${wv[j]}
  escaped=0
  [[ ${wf[j]} == *[qe]* ]] && escaped=1
  after_git_options $((j + 1))
  options=0
  ((ge > j + 1)) && options=1
  redirected=0
  for ((k = j; k <= ge && k < nw; k++)); do
    [[ ${wf[k]} == *r* ]] && redirected=1
  done
  sub=${wv[ge]-}
  sf=${wf[ge]-}
  args=("${wv[@]:ge+1}")
  aflags=("${wf[@]:ge+1}")
  if ((ge >= nw)); then
    [[ -n $other ]] || other=git
    continue
  fi
  if [[ $sf == *[qdo]* ]]; then
    deny "the git subcommand is quoted or held in a variable, which hides it from the permission rules: write it plainly."
  fi
  [[ $sf == *e* ]] && escaped=1

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
  if [[ $sub == worktree ]]; then
    worktree_writes && leave "git worktree add creating or resetting a branch (-b, -B, --orphan, --track, or no commit-ish without --detach)"
    if ((wt_ish >= 0)) && ! local_commit "${args[wt_ish]}" "${aflags[wt_ish]}"; then
      leave "git worktree add with a commit-ish that is not a commit of the local repository (git then creates a branch tracking a remote one)"
    fi
  fi
  if [[ $sub == fetch ]] && fetch_writes "${args[@]}"; then
    leave "git fetch into a local ref (a refspec with a colon, -u, --refmap)"
  fi
  if [[ $sub == config ]] && hooks_path_write "${args[@]}"; then
    leave "git config core.hooksPath, which disarms the prek hooks for every later commit"
  fi
  if [[ $sub == apply ]] && apply_writes "${args[@]}"; then
    leave "git apply -R, which overwrites working tree files"
  fi
  if [[ $sub == checkout-index ]] && checkout_index_writes "${args[@]}"; then
    leave "git checkout-index -f, which overwrites working tree files"
  fi
  if [[ $sub == read-tree ]] && read_tree_writes "${args[@]}"; then
    leave "git read-tree -u, which overwrites working tree files"
  fi
  if [[ ! $sub =~ ^($confirmed)$ ]]; then
    [[ -n $other ]] || other="git $sub"
    continue
  fi
  [[ -n $via ]] && reroute "$sub" "$via"
  [[ -n $assigned ]] &&
    deny "$assigned before git $sub can change the repository, the index or the configuration git uses, which the guard's checks do not follow: write it as a plain \`git $sub ...\`, SKIP= being the only assignment kept."
  case $sub in
  add | rm) staging_specs ;;
  mv) move_specs ;;
  commit)
    ((${#args[@]} == 1)) && [[ ${args[0]} == -h || ${args[0]} == --help ]] && continue
    [[ -n $dir ]] ||
      deny "this command changes directory before the commit to a place the guard cannot resolve (a quoted or escaped path, a variable, an option, cd -, popd)." \
        "Write the cd target as a plain path, so that the tracking check reads the repository the commit takes place in."
    ((commits)) && [[ $dir != "$commit_dir" ]] &&
      deny "this command holds a commit in $commit_dir and another in $dir: the tracking check reads one repository, so the first commit's files would go unchecked." \
        "Run one commit per command, as the commit skill's blocks already do."
    commit_dir=$dir
    check_commit_options "${args[@]}"
    commit_specs
    commits=1
    ;;
  esac
done

((commits)) || unjudged

[[ -z $other ]] ||
  deny "this command runs $other alongside git commit: a write it makes lands after the tracking check, so the commit could take content the verification never saw." \
    "A command holding git commit runs only cd or pushd and git add, rm, mv or commit, a SKIP= prefix being the only assignment: run the rest as a command of its own."

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] ||
  deny "could not check the tracking verification: the session id is unusable. Leave the commit to the user."

top=$(git -C "$commit_dir" rev-parse --show-toplevel 2>/dev/null) || unjudged
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
