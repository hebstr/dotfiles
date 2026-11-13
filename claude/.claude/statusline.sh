#!/bin/bash
# Claude Code statusline: Context % | 5h: % (reset) | 7d: % (reset)
exec 2>/dev/null

CACHE_DIR="$HOME/.cache/claude-statusline"
CACHE_FILE="$CACHE_DIR/last.json"
CACHE_MAX_AGE=21600

input=$(cat)

jq_fields='
def as_pct: if type == "number" then (round | tostring) else "" end;
def as_epoch:
  if type == "number" then (floor | tostring)
  elif type == "string" then (try (fromdateiso8601 | tostring) catch "")
  else "" end;
[
  (.context_window.used_percentage | as_pct),
  (.rate_limits.five_hour.used_percentage | as_pct),
  (.rate_limits.five_hour.resets_at | as_epoch),
  (.rate_limits.seven_day.used_percentage | as_pct),
  (.rate_limits.seven_day.resets_at | as_epoch)
] | .[]'

unless_reset() {
  local pct="$1" ts="$2"
  case "$ts" in
  '' | *[!0-9]*) printf '%s' "$pct" && return ;;
  esac
  if [ "$ts" -le "$(date +%s)" ]; then
    return
  fi
  printf '%s' "$pct"
}

cache_file_mtime() {
  local path="$1"
  local ts=""
  ts=$(stat -c %Y "$path" 2>/dev/null || true)
  printf '%s\n' "${ts:-0}"
}

# --- Payload ---
fields=()
if [ "$input" != "" ]; then
  mapfile -t fields < <(printf '%s' "$input" | jq -r "$jq_fields" 2>/dev/null)
fi

ctx_pct="${fields[0]:-0}"
five_pct="${fields[1]:-}"
five_reset="${fields[2]:-}"
seven_pct="${fields[3]:-}"
seven_reset="${fields[4]:-}"

live_limits=""
if [ "$five_pct" != "" ] || [ "$seven_pct" != "" ]; then
  live_limits=1
fi

# --- Cache ---
if [ "$live_limits" = "" ] && [ -f "$CACHE_FILE" ]; then
  cache_mtime=$(cache_file_mtime "$CACHE_FILE")
  cache_age=$(($(date +%s) - cache_mtime))
  if [ "$cache_age" -lt "$CACHE_MAX_AGE" ]; then
    cached=()
    mapfile -t cached < <(jq -r "$jq_fields" "$CACHE_FILE" 2>/dev/null)
    five_pct=$(unless_reset "${cached[1]:-}" "${cached[2]:-}")
    five_reset="${cached[2]:-}"
    seven_pct=$(unless_reset "${cached[3]:-}" "${cached[4]:-}")
    seven_reset="${cached[4]:-}"
  fi
fi

if [ "$live_limits" = 1 ]; then
  mkdir -p "$CACHE_DIR"
  # shellcheck disable=SC2015
  printf '%s' "$input" | jq '{rate_limits: .rate_limits}' \
    >"${CACHE_FILE}.tmp" 2>/dev/null &&
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE" 2>/dev/null ||
    rm -f "${CACHE_FILE}.tmp"
fi

# --- Colors ---
RESET="\033[0m"
DIM="\033[2m"
GREEN="\033[38;2;13;188;121m"
YELLOW="\033[38;2;229;229;16m"
RED="\033[38;2;205;49;49m"
BLUE="\033[38;2;59;142;234m"
MAGENTA="\033[38;2;214;112;214m"

# Format seconds remaining as "4h23m" or "1d21h"
format_reset() {
  local ts="$1"
  local now diff
  case "$ts" in
  '' | *[!0-9]*) return ;;
  esac
  now=$(date +%s)
  diff=$((ts - now))
  [ "$diff" -le 0 ] && return
  local mins=$((diff / 60))
  local hours=$((mins / 60))
  local days=$((hours / 24))
  if [ "$days" -ge 1 ]; then
    printf "%dd%dh" "$days" $((hours % 24))
  elif [ "$hours" -ge 1 ]; then
    printf "%dh%dm" "$hours" $((mins % 60))
  else
    printf "%dm" "$mins"
  fi
}

# Context %
if [ "$ctx_pct" -ge 85 ] 2>/dev/null; then
  ctx_color="$RED"
elif [ "$ctx_pct" -ge 70 ] 2>/dev/null; then
  ctx_color="$YELLOW"
else
  ctx_color="$GREEN"
fi
context_part="${DIM}Context${RESET} ${ctx_color}${ctx_pct}%${RESET}"

# Usage color
usage_color() {
  local pct="$1"
  if [ "$pct" -ge 90 ] 2>/dev/null; then
    printf "%s" "$RED"
  elif [ "$pct" -ge 70 ] 2>/dev/null; then
    printf "%s" "$MAGENTA"
  else
    printf "%s" "$BLUE"
  fi
}

# 5h part
if [ "$five_pct" != "" ]; then
  color=$(usage_color "$five_pct")
  reset_str=$(format_reset "$five_reset")
  if [ "$reset_str" != "" ]; then
    five_part="${DIM}5h:${RESET} ${color}${five_pct}%${RESET} ${DIM}(${reset_str})${RESET}"
  else
    five_part="${DIM}5h:${RESET} ${color}${five_pct}%${RESET}"
  fi
else
  five_part="${DIM}5h: --${RESET}"
fi

# 7d part
if [ "$seven_pct" != "" ]; then
  color=$(usage_color "$seven_pct")
  reset_str=$(format_reset "$seven_reset")
  if [ "$reset_str" != "" ]; then
    seven_part="${DIM}7d:${RESET} ${color}${seven_pct}%${RESET} ${DIM}(${reset_str})${RESET}"
  else
    seven_part="${DIM}7d:${RESET} ${color}${seven_pct}%${RESET}"
  fi
else
  seven_part="${DIM}7d: --${RESET}"
fi

printf "%b | %b | %b\n" "$context_part" "$five_part" "$seven_part"
