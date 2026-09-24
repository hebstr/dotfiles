#!/usr/bin/env bash
set -uo pipefail

usage() {
  printf 'usage: transcripts.sh invocations <repo> | transcripts.sh bash <repo> <name>\n' >&2
  exit 2
}

mode=${1-}
repo=${2-}
name=${3-}

[[ -n $repo ]] || usage
case $mode in
invocations) ;;
bash) [[ -n $name ]] || usage ;;
*) usage ;;
esac

proj="$HOME/.claude/projects/${repo//[^a-zA-Z0-9]/-}"
if [[ ! -d $proj ]]; then
  printf 'transcripts.sh: no transcript directory at %s\n' "$proj" >&2
  exit 0
fi

shopt -s nullglob
files=("$proj"/*.jsonl "$proj"/*/subagents/*.jsonl)
((${#files[@]} > 0)) || exit 0

# shellcheck disable=SC2016
invocations_filter='((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate | strflocaltime("%Y-%m-%d"))?) as $d | .message.content
  | (if type == "string" then [.] else [.[]? | select(.type == "text") | .text] end
      | .[]
      | capture("^\\s*(<command-message>[^<]*</command-message>\\s*)?<command-name>/(?<k>[^<]+)</command-name>(\\s*<command-args>(?<a>[^<]*))?")?
      | "\($d)\t\(.k)\t\(.a // "" | split("\n")[0] // "")"),
    (if type == "array" then
       .[] | select(.type == "tool_use" and .name == "Skill")
       | "\($d)\t\(.input.skill)\t\((.input.args // "" | split("\n")[0]) // "")"
     else empty end)'

# shellcheck disable=SC2016
bash_filter='((.timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdate | strflocaltime("%Y-%m-%d"))?) as $d | .message.content
  | if type == "array" then
      .[] | select(.type == "tool_use" and .name == "Bash" and (.input.command | contains($n)))
      | (.input.command | split("\n") | map(select(contains($n)))[0] | split($n)) as $p
      | "\($d)\t\(($p[0] | .[-60:]) + $n + ($p[1:] | join($n) | .[0:140]))"
    else empty end'

if [[ $mode == invocations ]]; then
  rg --no-filename -e '<command-name>/' -e '"name":"Skill"' -- "${files[@]}" |
    jq -r "$invocations_filter" |
    LC_ALL=C sort -u
else
  rg --no-filename -F -e "$name" -- "${files[@]}" |
    jq -r --arg n "$name" "$bash_filter" |
    LC_ALL=C sort -u
fi
rc=("${PIPESTATUS[@]}")

((rc[0] <= 1 && rc[1] == 0 && rc[2] == 0))
