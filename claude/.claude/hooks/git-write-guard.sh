#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

payload=$(cat)
cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
session=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null) || exit 0

[[ $cmd == *git* ]] || exit 0

deny() {
  printf 'git write guard: %s\n' "$@" >&2
  exit 2
}

reroute() {
  deny "this command runs git $1 through $2, which the permission dialog does not see." \
    "Write it as a plain \`git $1 ...\` at the start of a command, from the repository (\`cd <repo> && git $1 ...\`), so that the user confirms it. Do not look for another form."
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
      out+=Q
      ;;
    \\)
      out+=${s:i:2}
      ((i++))
      ;;
    *) out+=$c ;;
    esac
  done
  printf '%s' "$out"
}

declare -A alias_of=()
while read -r key value; do
  alias_of[${key#alias.}]=$value
done < <(git -C "${cwd:-.}" config --get-regexp '^alias\.' 2>/dev/null)

alias_writes() {
  local expansion=${alias_of[$1]-}
  [[ -n $expansion ]] || return 1
  if [[ $expansion == '!'* ]]; then
    [[ $expansion =~ (^|[^[:alnum:]_-])(add|commit)([^[:alnum:]_-]|$) ]]
  else
    [[ ${expansion%% *} == add || ${expansion%% *} == commit ]]
  fi
}

runner='(^|[^[:alnum:]_./-])((bash|sh|zsh|dash|ksh)[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*-[[:alnum:]]*c|eval|xargs)([[:space:]]|$)'
mention='(^|[^[:alnum:]_./-])git[^[:alnum:]_-](.*[^[:alnum:]_-])?(add|commit)([^[:alnum:]_-]|$)'
if [[ $cmd =~ $runner && $cmd =~ $mention ]]; then
  reroute "add or commit" "a shell string (bash -c, eval, xargs)"
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

commits=0
stripped=$(strip_quotes "$cmd")
segments=${stripped//[;&|()\`]/$'\n'}
while IFS= read -r segment; do
  read -ra w <<<"$segment"
  n=${#w[@]}
  i=0
  while ((i < n)) && [[ ${w[i]} =~ ^[A-Za-z_][A-Za-z0-9_]*= || ${w[i]} =~ ^(\{|!|if|then|else|elif|do|while|until)$ ]]; do
    ((i++))
  done
  wrapper=""
  if ((i < n)) && [[ ${w[i]} =~ ^(env|command|builtin|exec|nohup|timeout|nice|ionice|time|stdbuf|sudo|doas|unbuffer|chronic)$ ]]; then
    wrapper=${w[i]}
    while ((i < n)) && [[ ${w[i]} != git && ${w[i]} != */git ]]; do
      ((i++))
    done
  fi
  ((i < n)) || continue
  program=${w[i]}
  [[ $program == git || $program == */git ]] || continue
  ((i++))
  options=0
  while ((i < n)); do
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
  if [[ $sub != add && $sub != commit ]]; then
    alias_writes "$sub" || continue
    reroute "add or commit" "the alias git $sub"
  fi
  [[ -n $wrapper ]] && reroute "$sub" "the wrapper $wrapper"
  [[ $program != git ]] && reroute "$sub" "git called by path ($program)"
  ((options)) && reroute "$sub" "git global options before the subcommand"
  if [[ $sub == commit ]]; then
    check_commit_options "${w[@]:i+1}"
    commits=1
  fi
done <<<"$segments"

((commits)) || exit 0

[[ $session =~ ^[A-Za-z0-9_-]+$ ]] ||
  deny "could not check the tracking verification: the session id is unusable. Leave the commit to the user."

stale=()
mapfile -t stale < <("$BASH" "${BASH_SOURCE[0]%/*}/commit-stale.sh" "$session" "${CLAUDE_PROJECT_DIR:-$cwd}" 2>/dev/null)
wait "$!" ||
  deny "could not check the tracking verification: a source of commit-stale.sh was unreadable. Invoke the commit skill again; if it persists, leave the commit to the user."

if ((${#stale[@]} > 0)); then
  {
    printf 'git write guard: %d file(s) outside the tracking files changed after the last tracking verification:\n' "${#stale[@]}"
    for p in "${stale[@]:0:10}"; do
      printf '  %s\n' "$p"
    done
    ((${#stale[@]} > 10)) && printf '  ... and %d more\n' "$((${#stale[@]} - 10))"
    printf 'Invoke the commit skill now: it runs the tracking verifier and renders the blocks again. Do not retry this commit.\n'
  } >&2
  exit 2
fi

exit 0
