#!/usr/bin/env bash
set -eu

command -v prose-lint >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE=$(jq -r '.tool_input.file_path // empty' <<<"$INPUT")
[ "$FILE" = "" ] && exit 0

case "$FILE" in
*.md | *.qmd | *.Rmd) ;;
*) exit 0 ;;
esac

# Reconstruct the full post-edit file. prose-lint skips fenced code blocks, so
# it must see the whole file with fences intact; linting the bare Edit fragment
# (new_string) misreads code lines as prose. Write carries full content; Edit
# carries old_string/new_string applied against the current on-disk file.
CONTENT=$(
  HOOK_INPUT="$INPUT" python3 - "$FILE" <<'PY'
import json, os, sys

ti = json.loads(os.environ["HOOK_INPUT"]).get("tool_input", {})
if ti.get("content") is not None:
    sys.stdout.write(ti["content"])
    raise SystemExit(0)
old, new = ti.get("old_string"), ti.get("new_string")
if old is None or new is None:
    raise SystemExit(3)
try:
    text = open(sys.argv[1]).read()
except OSError:
    raise SystemExit(3)
text = text.replace(old, new) if ti.get("replace_all") else text.replace(old, new, 1)
sys.stdout.write(text)
PY
) || exit 0

[ "$CONTENT" = "" ] && exit 0

# Mirror the real path under a temp root so prose-lint's path/basename skips
# (.claude/memory/, PLAN.md, etc.) apply exactly as they would on the real file.
REAL=$(realpath -m "$FILE")
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT
TMP="$TMPROOT/${REAL#/}"
mkdir -p "$(dirname "$TMP")"
printf '%s' "$CONTENT" >"$TMP"

if OUTPUT=$(prose-lint "$TMP" 2>&1); then
  exit 0
fi

printf 'prose-lint blocked write to %s:\n%s\n' "$FILE" "${OUTPUT//$TMP/$FILE}" >&2
exit 2
