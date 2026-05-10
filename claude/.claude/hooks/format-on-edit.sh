#!/usr/bin/env bash
FILE=$(jq -r '.tool_input.file_path')
REAL=$(realpath "$FILE" 2>/dev/null || printf '%s' "$FILE")

[[ "$REAL" == "$PWD"/* ]] || exit 0

case "$FILE" in
*.R | *.r) air format "$FILE" && jarl check "$FILE" 2>&1 | tail -30 ;;
*.py | *.ipynb) ruff format "$FILE" && ruff check --fix "$FILE" 2>&1 | tail -30 ;;
*.sh | *.bash) shellharden --replace "$FILE" && shfmt -w -i 2 -ci -sr "$FILE" && shellcheck "$FILE" 2>&1 | tail -30 ;;
esac
