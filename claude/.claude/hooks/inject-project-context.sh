#!/bin/bash

# Section 1: Project type + git status
if git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Git branch: $(git branch --show-current)"
  CHANGES=$(git status --porcelain | wc -l)
  [ "$CHANGES" -gt 0 ] && echo "Uncommitted changes: $CHANGES files"
fi

if [ -f DESCRIPTION ]; then
  echo "R package: $(grep '^Package:' DESCRIPTION | cut -d' ' -f2) v$(grep '^Version:' DESCRIPTION | cut -d' ' -f2)"
fi

# Section 2: R environment (renv or rv)
if [ -f renv.lock ]; then
  R_VER=$(grep -A1 '"R"' renv.lock | grep -o '"Version": "[^"]*"' | head -1 | cut -d'"' -f4)
  PKG_COUNT=$(grep -c '"Package"' renv.lock)
  echo "renv active (R $R_VER, $PKG_COUNT packages locked). Use pak::pkg_install(), not install.packages()."
elif [ -f rv.lock ] || [ -f rproject.toml ]; then
  echo "rv environment detected. Packages managed via rv, not install.packages()."
fi

# Section 3: Quarto config
if [ -f _quarto.yml ]; then
  FORMAT=$(grep -E '^\s*format:' _quarto.yml | head -1 | sed 's/.*format:\s*//')
  TYPE=$(grep -E '^\s*type:' _quarto.yml | head -1 | sed 's/.*type:\s*//')
  echo "Quarto project${TYPE:+ (type: $TYPE)}${FORMAT:+, format: $FORMAT}."
  if ls _extensions/ &>/dev/null; then
    echo "Quarto extensions: $(ls _extensions/)"
  fi
  if echo "$FORMAT" | grep -qi 'typst'; then
    echo "Typst output format. Use Typst syntax, not LaTeX."
  fi
fi

# Section 4: uv (Python)
if [ -f pyproject.toml ] && grep -q '\[tool\.uv\]' pyproject.toml 2>/dev/null; then
  PROJ_NAME=$(grep -E '^name\s*=' pyproject.toml | head -1 | cut -d'"' -f2)
  PY_VER=$(grep -E 'requires-python' pyproject.toml | grep -o '"[^"]*"' | tr -d '"')
  echo "uv project${PROJ_NAME:+: $PROJ_NAME}${PY_VER:+ (Python $PY_VER)}. Use uv add/uv run, not pip install."
elif [ -f uv.lock ]; then
  echo "uv environment detected. Use uv add/uv run, not pip install."
fi
