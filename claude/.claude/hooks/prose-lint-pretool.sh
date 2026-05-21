#!/usr/bin/env bash
set -eu

command -v prose-lint >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE=$(jq -r '.tool_input.file_path // empty' <<<"$INPUT")
[ -z "$FILE" ] && exit 0

case "$FILE" in
*.md | *.qmd | *.Rmd) ;;
*) exit 0 ;;
esac

CONTENT=$(jq -r '.tool_input.new_string // .tool_input.content // empty' <<<"$INPUT")
[ -z "$CONTENT" ] && exit 0

EXT="${FILE##*.}"
TMP=$(mktemp --suffix=".$EXT")
trap 'rm -f "$TMP"' EXIT
printf '%s' "$CONTENT" >"$TMP"

if OUTPUT=$(prose-lint "$TMP" 2>&1); then
  exit 0
fi

printf 'prose-lint blocked write to %s:\n%s\n' "$FILE" "${OUTPUT//$TMP/$FILE}" >&2
exit 2
