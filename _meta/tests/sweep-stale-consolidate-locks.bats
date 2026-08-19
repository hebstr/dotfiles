#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/sweep-stale-consolidate-locks.sh"

setup() {
  TMPHOME=$(mktemp -d)
  PROJECT="-home-user-proj"
  MEMDIR="$TMPHOME/.claude/projects/$PROJECT/memory"
  LOCK="$MEMDIR/.consolidate-lock"
  export TMPHOME PROJECT MEMDIR LOCK
  mkdir -p "$MEMDIR"
  LIVE_PID=""
  STUBS=""
}

teardown() {
  if [ -n "$LIVE_PID" ]; then
    kill "$LIVE_PID" 2>/dev/null || true
  fi
  rm -rf "$TMPHOME"
  if [ -n "$STUBS" ]; then
    rm -rf "$STUBS"
  fi
}

make_lock() {
  printf '%s' "$1" >"$LOCK"
}

spawn_live() {
  sleep 300 &
  LIVE_PID=$!
}

run_hook() {
  run env HOME="$TMPHOME" /bin/bash "$SCRIPT"
}

# The PID-reuse guard reads two timestamps through stat; a stat that always
# fails is the only way to reach the branch that keeps the lock when neither
# can be read.
stub_failing_stat() {
  STUBS=$(mktemp -d)
  printf '%s\n' '#!/usr/bin/env bash' 'exit 1' >"$STUBS/stat"
  chmod +x "$STUBS/stat"
}

run_hook_stubbed() {
  run env HOME="$TMPHOME" PATH="$STUBS:$PATH" /bin/bash "$SCRIPT"
}

log_contents() {
  cat "$TMPHOME/.claude/logs/dream-sweeper.log" 2>/dev/null
}

@test "exits 0 and creates the log dir" {
  run_hook
  [ "$status" -eq 0 ]
  [ -d "$TMPHOME/.claude/logs" ]
}

@test "removes a lock held by a dead PID" {
  dead_pid=$(bash -c 'echo $$')
  make_lock "$dead_pid"
  run_hook
  [ "$status" -eq 0 ]
  [ ! -e "$LOCK" ]
  [[ "$(log_contents)" == *stale* ]]
}

@test "removes a lock with empty content" {
  make_lock ""
  run_hook
  [ "$status" -eq 0 ]
  [ ! -e "$LOCK" ]
}

@test "removes a lock with non-numeric content" {
  make_lock "garbage"
  run_hook
  [ "$status" -eq 0 ]
  [ ! -e "$LOCK" ]
}

@test "keeps a lock held by a live PID that started before the lock" {
  spawn_live
  make_lock "$LIVE_PID"
  run_hook
  [ "$status" -eq 0 ]
  [ -e "$LOCK" ]
}

@test "removes a lock whose live PID is a recycled one (process started after the lock)" {
  spawn_live
  make_lock "$LIVE_PID"
  touch -d '1 hour ago' "$LOCK"
  run_hook
  [ "$status" -eq 0 ]
  [ ! -e "$LOCK" ]
  [[ "$(log_contents)" == *recycled* ]]
}

@test "keeps a live lock when neither timestamp can be read" {
  stub_failing_stat
  spawn_live
  make_lock "$LIVE_PID"
  touch -d '1 hour ago' "$LOCK"
  run_hook_stubbed
  [ "$status" -eq 0 ]
  [ -e "$LOCK" ]
  [[ "$(log_contents)" != *"$PROJECT"* ]]
}
