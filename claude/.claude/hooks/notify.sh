#!/usr/bin/env bash
set -euo pipefail

command -v notify-send >/dev/null 2>&1 || exit 0

if command -v gdbus >/dev/null 2>&1; then
  idle_raw=$(gdbus call --session \
    --dest org.gnome.Mutter.IdleMonitor \
    --object-path /org/gnome/Mutter/IdleMonitor/Core \
    --method org.gnome.Mutter.IdleMonitor.GetIdletime 2>/dev/null || true)
  idle_ms=$(printf '%s' "$idle_raw" | sed -nE 's/.*uint64 ([0-9]+).*/\1/p')
  if [[ -n ${idle_ms:-} && $idle_ms -lt 10000 ]]; then
    exit 0
  fi
fi

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
  raw=$({ jq -r '
    select(.type == "user")
    | .message.content
    | select(type == "string")
    | gsub("\n"; " ")
  ' "$transcript" 2>/dev/null || true; } | head -n 1 | tr -d '\n')
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

slot_key="${cwd//\//_}"
[[ -z $slot_key ]] && slot_key=default
state_file="${XDG_RUNTIME_DIR:-/tmp}/claude-code-notify-${slot_key}.id"
replace_args=()
if [[ -r $state_file ]]; then
  prev_id=$(cat "$state_file" 2>/dev/null || true)
  if [[ $prev_id =~ ^[0-9]+$ ]]; then
    replace_args=(--replace-id="$prev_id")
  fi
fi

new_id=$(notify-send \
  --app-name="Claude Code" \
  --urgency="$urgency" \
  --category=im.received \
  --print-id \
  "${replace_args[@]}" \
  "$title" \
  "$message" 2>/dev/null) || true

if [[ $new_id =~ ^[0-9]+$ ]]; then
  printf '%s\n' "$new_id" >"$state_file" 2>/dev/null || true
fi
