#!/usr/bin/env bash

LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/dream-sweeper.log"

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

shopt -s nullglob
for lock in "$HOME"/.claude/projects/*/memory/.consolidate-lock; do
  pid=$(tr -d '[:space:]' <"$lock" 2>/dev/null)
  reason="stale"
  if [ "$pid" != "" ] && kill -0 "$pid" 2>/dev/null; then
    # PID-reuse guard: a live PID whose process started after the lock was
    # written is a recycled PID, not the original holder. /proc/<pid> mtime is
    # the process start time; keep the lock only when the holder predates it
    # (or when either timestamp can't be read, to avoid dropping a live lock).
    proc_start=$(stat -c %Y "/proc/$pid" 2>/dev/null)
    lock_mtime=$(stat -c %Y "$lock" 2>/dev/null)
    if [ "$proc_start" = "" ] || [ "$lock_mtime" = "" ] || [ "$proc_start" -le "$lock_mtime" ]; then
      continue
    fi
    reason="recycled"
  fi
  project=$(basename "$(dirname "$(dirname "$lock")")")
  locked_since=$(stat -c '%y' "$lock" 2>/dev/null | cut -d. -f1)
  rm -f "$lock" 2>/dev/null &&
    printf '%s removed %s (pid=%s, %s, locked since %s)\n' \
      "$(date -Iseconds)" "$project" "${pid:-empty}" "$reason" "${locked_since:-unknown}" \
      >>"$LOG_FILE"
done

exit 0
