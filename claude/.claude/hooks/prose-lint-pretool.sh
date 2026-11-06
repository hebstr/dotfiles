#!/usr/bin/env bash
set -eu

command -v prose-lint >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# opencode's plugins/claude-hooks.ts builds this payload too: keep the keys read here in step with it.
INPUT=$(cat)
FILE=$(jq -r '.tool_input.file_path // empty' <<<"$INPUT")
[ "$FILE" = "" ] && exit 0

case "$FILE" in
*.md | *.qmd | *.Rmd) ;;
*) exit 0 ;;
esac

REAL=$(realpath -m "$FILE")

# The dash rules reach the stowed global config and ordinary prose; every other
# .claude/ tree keeps its exemption. [live-count] is scoped by prose-lint
# itself and reported wherever it fires, which is why no branch exits here.
DASH=1
case "$REAL" in
*/dotfiles/claude/.claude/*) ;;
*/.claude/* | *-context.md) DASH=0 ;;
esac

# Mirror the real path under a temp root so prose-lint's path/basename scopes
# (.claude/memory/, PLAN.md, etc.) apply exactly as they would on the real file.
TMPROOT=$(mktemp -d)
trap 'rm -rf "$TMPROOT"' EXIT
TMP="$TMPROOT/${REAL#/}"
mkdir -p "$(dirname "$TMP")"

# Reconstruct the full post-edit file. prose-lint skips fenced code blocks and
# display-math blocks, so it must see the whole file with those intact; linting
# the bare Edit fragment (new_string) misreads such lines as prose. Write
# carries full content; Edit carries old_string/new_string applied against the
# current on-disk file. The line numbers the write adds come back on stdout:
# [live-count] fires on pre-existing text all over the corpus, so reporting it
# whole-file would refuse every edit to a file already carrying one.
ADDED=$(
  HOOK_INPUT="$INPUT" python3 - "$FILE" "$TMP" <<'PY'
import difflib, json, os, sys

ti = json.loads(os.environ["HOOK_INPUT"]).get("tool_input", {})
try:
    before = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read()
except OSError:
    before = None
if ti.get("content") is not None:
    after = ti["content"]
else:
    old, new = ti.get("old_string"), ti.get("new_string")
    if old is None or new is None or before is None:
        raise SystemExit(3)
    after = before.replace(old, new) if ti.get("replace_all") else before.replace(old, new, 1)
with open(sys.argv[2], "w", encoding="utf-8", errors="surrogateescape") as fh:
    fh.write(after)
added = []
for tag, _, _, j1, j2 in difflib.SequenceMatcher(
    None, (before or "").splitlines(), after.splitlines(), autojunk=False
).get_opcodes():
    if tag in ("insert", "replace"):
        added.extend(range(j1 + 1, j2 + 1))
print(" ".join(str(n) for n in added))
PY
) || exit 0

[ -s "$TMP" ] || exit 0

if OUTPUT=$(prose-lint "$TMP" 2>&1); then
  exit 0
fi

OUTPUT=$(printf '%s\n' "$OUTPUT" | awk -v tmp="$TMP" -v dash="$DASH" -v added="$ADDED" '
  BEGIN { n = split(added, a, " "); for (i = 1; i <= n; i++) add[a[i]] = 1 }
  index($0, tmp ":") == 1 {
    live = ($0 ~ /\[live-count\]/)
    if (live && !((substr($0, length(tmp) + 2) + 0) in add)) next
    if (!live && !dash) next
    kept = 1
    print
    next
  }
  /violation\(s\) found/ { next }
  /^[ \t]*$/ { next }
  { other = other $0 "\n" }
  END { if (!kept) printf "%s", other }
')

[ "$OUTPUT" = "" ] && exit 0

printf 'prose-lint blocked write to %s:\n%s\n' "$FILE" "${OUTPUT//$TMP/$FILE}" >&2
exit 2
