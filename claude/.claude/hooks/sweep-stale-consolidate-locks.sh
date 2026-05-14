#!/usr/bin/env bash

LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/dream-sweeper.log"

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

shopt -s nullglob
for lock in "$HOME"/.claude/projects/*/memory/.consolidate-lock; do
  pid=$(tr -d '[:space:]' <"$lock" 2>/dev/null)
  if [ "$pid" != "" ] && kill -0 "$pid" 2>/dev/null; then
    continue
  fi
  project=$(basename "$(dirname "$(dirname "$lock")")")
  locked_since=$(stat -c '%y' "$lock" 2>/dev/null | cut -d. -f1)
  rm -f "$lock" 2>/dev/null &&
    printf '%s removed %s (pid=%s, locked since %s)\n' \
      "$(date -Iseconds)" "$project" "${pid:-empty}" "${locked_since:-unknown}" \
      >>"$LOG_FILE"
done

exit 0
