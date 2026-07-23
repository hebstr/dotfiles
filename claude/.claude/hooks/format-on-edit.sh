#!/usr/bin/env bash
FILE=$(jq -r '.tool_input.file_path')
REAL=$(realpath "$FILE" 2>/dev/null || printf '%s' "$FILE")

[[ "$REAL" == "$PWD"/* ]] || exit 0

case "$FILE" in
*.R | *.r) air format "$FILE" && jarl check "$FILE" 2>&1 | tail -30 ;;
*.py | *.ipynb) ruff check --fix "$FILE" && ruff format "$FILE" 2>&1 | tail -30 ;;
*.sh | *.bash) shellharden --replace "$FILE" && shfmt -w -i 2 "$FILE" && shellcheck "$FILE" 2>&1 | tail -30 ;;
*.md | *.qmd)
  # _snaps/ holds testthat snapshots: machine-written, compared verbatim, so any
  # reflow turns into a spurious diff on the next run.
  case "$REAL" in
  */_snaps/*) ;;
  */memory/* | */PLAN.md | */DEFERRED.md | *-context.md | */CLAUDE.md | */rules/*.md) ;;
  # A .md beside a same-named .Rmd/.qmd is knitr/Quarto output (github_document):
  # reflowing it desynchronises it from the source it is regenerated from.
  *.md) [[ -f "${REAL%.md}.Rmd" || -f "${REAL%.md}.qmd" ]] ||
    { command -v panache >/dev/null 2>&1 && panache format --force-exclude "$FILE"; } ;;
  *) command -v panache >/dev/null 2>&1 && panache format --force-exclude "$FILE" ;;
  esac
  # The stowed dotfiles config is curated user-facing prose (keep prose-lint);
  # any other .claude/ tree is a project's transient Claude notes (exempt).
  case "$REAL" in
  */_snaps/*) ;;
  */dotfiles/claude/.claude/*) prose-lint "$FILE" 2>&1 | tail -30 ;;
  */.claude/* | *-context.md) ;;
  *) prose-lint "$FILE" 2>&1 | tail -30 ;;
  esac
  ;;
esac
