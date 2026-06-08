#!/usr/bin/env bash

if [ -f DESCRIPTION ]; then
  echo "R package: $(grep '^Package:' DESCRIPTION | cut -d' ' -f2) v$(grep '^Version:' DESCRIPTION | cut -d' ' -f2)"
elif [ -f rv.lock ] || [ -f rproject.toml ]; then
  echo "R project (rv-managed). Use 'rv add <pkg>' for installs (keeps the lockfile authoritative); never pak::pak() against the project library. Lockfile is rv.lock."
fi

if [ -f _quarto.yml ]; then
  FORMAT=$(grep -E '^\s*format:' _quarto.yml | head -1 | sed 's/.*format:\s*//')
  TYPE=$(grep -E '^\s*type:' _quarto.yml | head -1 | sed 's/.*type:\s*//')
  echo "Quarto project${TYPE:+ (type: $TYPE)}${FORMAT:+, format: $FORMAT}."
  if [ "$(ls -A _extensions/ 2>/dev/null)" ]; then
    echo "Quarto extensions: $(ls _extensions/)"
  fi
  if grep -qi 'typst' _quarto.yml; then
    echo "Typst output format. Use Typst syntax, not LaTeX."
  fi
fi

if [ -f pyproject.toml ] && { [ -f uv.lock ] || grep -q '\[tool\.uv\]' pyproject.toml 2>/dev/null; }; then
  PROJ_NAME=$(grep -E '^name\s*=' pyproject.toml | head -1 | cut -d'"' -f2)
  PY_VER=$(grep -E 'requires-python' pyproject.toml | grep -o '"[^"]*"' | tr -d '"')
  echo "uv project${PROJ_NAME:+: $PROJ_NAME}${PY_VER:+ (Python $PY_VER)}."
elif [ -f uv.lock ]; then
  echo "uv environment detected."
fi

if [ -f "$HOME/.claude/memory/MEMORY.md" ]; then
  echo "=== Global memory index (~/.claude/memory/) — read a file's body on demand when its description is relevant ==="
  cat "$HOME/.claude/memory/MEMORY.md"
fi

if [ -f .claude/memory/MEMORY.md ]; then
  echo "=== Project memory index (.claude/memory/) — read a file's body on demand when relevant ==="
  cat .claude/memory/MEMORY.md
fi
