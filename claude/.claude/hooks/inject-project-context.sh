#!/usr/bin/env bash

if command -v jq >/dev/null 2>&1; then
  payload=$(cat)
  IFS=$'\t' read -r source session < <(printf '%s' "$payload" | jq -r '[.source // "-", .session_id // "-"] | @tsv' 2>/dev/null)
  if [[ $source == compact && $session =~ ^[A-Za-z0-9_-]+$ ]]; then
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/claude-code-rules-${session}" "${XDG_RUNTIME_DIR:-/tmp}/claude-code-rules-${session}"-*
  fi
fi

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

if [ -f .claude/PLAN.md ]; then
  plan=.claude/PLAN.md
elif [ -f PLAN.md ]; then
  plan=PLAN.md
else
  plan=""
fi
if [ "$plan" != "" ]; then
  case ${source:-startup} in
  compact) echo "Context was just compacted: re-read $plan and restate its current objective, current step and blockers before continuing." ;;
  *) echo "This project has $plan: read it and state its current objective, current step and blockers before any other work, without asking what to read." ;;
  esac
fi

if [ "${source:-startup}" != compact ]; then
  legacy=()
  for f in CLAUDE.md PLAN.md MEMORY.md DEFERRED.md; do
    [ -f "$f" ] && legacy+=("$f")
  done
  if [ ${#legacy[@]} -gt 0 ]; then
    echo "Legacy root-level Claude file(s): ${legacy[*]}. Read them in place; on your first edit of one, propose moving it to .claude/, and never create a new Claude file at the root."
  fi
  if [ -f CLAUDE.md ] && [ -f .claude/CLAUDE.md ]; then
    echo "./CLAUDE.md and ./.claude/CLAUDE.md both exist, and the root copy masks the other: propose relocating into .claude/ now, never keep both."
  fi
fi

if [ -f "$HOME/.claude/memory/MEMORY.md" ]; then
  echo "=== Global memory index (~/.claude/memory/) — read a file's body on demand when its description is relevant ==="
  cat "$HOME/.claude/memory/MEMORY.md"
fi

if [ -f .claude/memory/MEMORY.md ]; then
  echo "=== Project memory index (.claude/memory/) — read a file's body on demand when relevant ==="
  cat .claude/memory/MEMORY.md
fi
