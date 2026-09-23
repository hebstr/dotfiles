#!/usr/bin/env bash
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

offer="\\bsi tu veux\\b|\\bquand tu veux\\b|\\bdis[- ]moi si\\b|\\b(tu veux|veux-tu) que je\\b|\\bif you want\\b|\\blet me know if\\b|\\bwant me to\\b"
close="\\b(lance[rsz]?|run|tape[rsz]?) +/commit\\b"

hits=$(jq -r --arg offer "$offer" --arg close "$close" '
  select((.stop_hook_active // false | tostring) == "false")
  | .last_assistant_message
  | strings
  | gsub("```[\\s\\S]*?```"; "")
  | gsub("(?<t>`+)(?<c>[^\\n]*?)\\k<t>"; if (.c | test("^/[A-Za-z0-9:_-]+$")) then .c else "" end)
  | gsub("\"[^\"\\n]*\"|«[^»\\n]*»|“[^”\\n]*”"; "")
  | ([match($offer; "gi").string | ascii_downcase] | unique | map("offer\t" + .) | .[]),
    ([match($close; "gi").string | ascii_downcase] | unique | map("close\t" + .) | .[])
' 2>/dev/null) || exit 0

[[ -n $hits ]] || exit 0

offers=()
closes=()
while IFS=$'\t' read -r family phrase; do
  case $family in
  offer) offers+=("\"$phrase\"") ;;
  close) closes+=("\"$phrase\"") ;;
  esac
done <<<"$hits"

{
  if ((${#offers[@]} > 0)); then
    printf 'Ending gate: the response offers an action without taking a position (%s). ' "${offers[*]}"
    printf 'That response is already displayed: follow it with an explicit recommendation, do it or do not, with the reason in one line. '
    printf 'An action the discipline already requires, such as a tracking update, is done, not offered.\n'
  fi
  if ((${#closes[@]} > 0)); then
    printf 'Ending gate: the response hands the session closure to the user (%s). ' "${closes[*]}"
    printf 'If every task of the session is done, invoke the commit skill yourself now; otherwise name the next task and recommend it.\n'
  fi
} >&2
exit 2
