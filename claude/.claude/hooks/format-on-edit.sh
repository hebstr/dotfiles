#!/usr/bin/env bash
FILE=$(jq -r '.tool_input.file_path')
REAL=$(realpath "$FILE" 2>/dev/null || printf '%s' "$FILE")

[[ "$REAL" == "$PWD"/* ]] || exit 0

case "$FILE" in
*.R | *.r) air format "$FILE" && jarl check "$FILE" 2>&1 | tail -30 ;;
*.py | *.ipynb) ruff check --fix "$FILE" && ruff format "$FILE" 2>&1 | tail -30 ;;
*.sh | *.bash) shellharden --replace "$FILE" && shfmt -w -i 2 "$FILE" && shellcheck "$FILE" 2>&1 | tail -30 ;;
*.md | *.qmd)
  case "$REAL" in
  */memory/* | */PLAN.md | */DEFERRED.md | *-context.md | */CLAUDE.md | */rules/*.md) ;;
  *) command -v panache >/dev/null 2>&1 && panache format "$FILE" ;;
  esac
  # The stowed dotfiles config is curated user-facing prose (keep prose-lint);
  # any other .claude/ tree is a project's transient Claude notes (exempt).
  case "$REAL" in
  */dotfiles/claude/.claude/*) prose-lint "$FILE" 2>&1 | tail -30 ;;
  */.claude/* | *-context.md) ;;
  *) prose-lint "$FILE" 2>&1 | tail -30 ;;
  esac
  ;;
esac
