#!/usr/bin/env bash
set -euo pipefail

command -v notify-send >/dev/null 2>&1 || exit 0

payload=$(cat)

if command -v jq >/dev/null 2>&1; then
  message=$(printf '%s' "$payload" | jq -r '.message // "Claude Code needs your attention"')
  cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""')
  transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // ""')
else
  message="Claude Code needs your attention"
  cwd=""
  transcript=""
fi

project="${cwd##*/}"
[[ -z $project ]] && project="Claude Code"

conv=""
if [[ -n $transcript && -r $transcript ]] && command -v jq >/dev/null 2>&1; then
  raw=$(jq -r '
    select(.type == "user")
    | .message.content
    | select(type == "string")
  ' "$transcript" 2>/dev/null | head -n 1 | tr -d '\n')
  if ((${#raw} > 50)); then
    conv="${raw:0:49}…"
  else
    conv="$raw"
  fi
fi

if [[ -n $conv ]]; then
  title="${project} — ${conv}"
else
  title="Claude Code — ${project}"
fi

urgency=normal
shopt -s nocasematch
if [[ $message == *permission* || $message == *waiting* ]]; then
  urgency=critical
fi
shopt -u nocasematch

notify-send \
  --app-name="Claude Code" \
  --urgency="$urgency" \
  --category=im.received \
  "$title" \
  "$message" 2>/dev/null || true
