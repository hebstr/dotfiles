#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/notify.sh"

setup() {
  TMPDIR_TEST=$(mktemp -d)
  STUB_DIR="$TMPDIR_TEST/stubs"
  CAPTURE="$TMPDIR_TEST/notify-args"
  TRANSCRIPT="$TMPDIR_TEST/transcript.jsonl"
  export TMPDIR_TEST STUB_DIR CAPTURE TRANSCRIPT

  mkdir -p "$STUB_DIR"
  for cmd in cat jq head tr sed; do
    real=$(command -v "$cmd")
    ln -sf "$real" "$STUB_DIR/$cmd"
  done

  make_notify_stub 0
}

make_gdbus_stub() {
  local output="$1"
  cat >"$STUB_DIR/gdbus" <<STUB
#!/bin/bash
printf '%s\n' "$output"
STUB
  chmod +x "$STUB_DIR/gdbus"
}

make_gdbus_stub_failing() {
  cat >"$STUB_DIR/gdbus" <<'STUB'
#!/bin/bash
exit 1
STUB
  chmod +x "$STUB_DIR/gdbus"
}

teardown() {
  if [[ -f $TRANSCRIPT ]]; then
    chmod 644 "$TRANSCRIPT" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_TEST"
}

make_notify_stub() {
  local exit_code="${1:-0}"
  local print_id="${2:-42}"
  cat >"$STUB_DIR/notify-send" <<STUB
#!/bin/bash
: > "$CAPTURE"
for arg in "\$@"; do
  printf '%s\n' "\$arg" >> "$CAPTURE"
done
printf '%s\n' "$print_id"
exit $exit_code
STUB
  chmod +x "$STUB_DIR/notify-send"
}

remove_notify_stub() {
  rm -f "$STUB_DIR/notify-send"
}

remove_jq_stub() {
  rm -f "$STUB_DIR/jq"
}

write_transcript() {
  : >"$TRANSCRIPT"
  for line in "$@"; do
    printf '%s\n' "$line" >>"$TRANSCRIPT"
  done
}

run_hook() {
  local payload="$1"
  # shellcheck disable=SC2016 # intentional: $1/$2 expand inside the inner shell
  run env PATH="$STUB_DIR" CAPTURE="$CAPTURE" XDG_RUNTIME_DIR="$TMPDIR_TEST" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

build_payload() {
  jq -nc \
    --arg msg "$1" \
    --arg cwd "$2" \
    --arg tp "$3" \
    '{message:$msg, cwd:$cwd, transcript_path:$tp}'
}

capture_app_name() { sed -n '1p' "$CAPTURE"; }
capture_urgency() { sed -n '2p' "$CAPTURE"; }
capture_category() { sed -n '3p' "$CAPTURE"; }
capture_print_id() { sed -n '4p' "$CAPTURE"; }
capture_title() { sed -n '5p' "$CAPTURE"; }
capture_message() { sed -n '6p' "$CAPTURE"; }
capture_replace_id() { grep -m1 -E '^--replace-id=' "$CAPTURE" || true; }

# ---------------------------------------------------------------------------
# Guard: notify-send absent
# ---------------------------------------------------------------------------

@test "exits 0 silently when notify-send is missing" {
  remove_notify_stub
  run_hook '{"message":"hi"}'
  [ "$status" -eq 0 ]
  [ ! -f "$CAPTURE" ]
}

# ---------------------------------------------------------------------------
# Fallback: jq absent
# ---------------------------------------------------------------------------

@test "uses default title and message when jq is missing" {
  remove_jq_stub
  run_hook '{"message":"some message","cwd":"/home/user/proj"}'
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — Claude Code" ]
  [ "$(capture_message)" = "Claude Code needs your attention" ]
}

@test "urgency is normal when jq is missing (no payload inspection)" {
  remove_jq_stub
  run_hook '{"message":"permission required"}'
  [ "$status" -eq 0 ]
  [ "$(capture_urgency)" = "--urgency=normal" ]
}

# ---------------------------------------------------------------------------
# Title formatting
# ---------------------------------------------------------------------------

@test "title is 'Claude Code — <project>' when transcript is absent" {
  payload=$(build_payload "do this" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — proj" ]
}

@test "title falls back to 'Claude Code' when cwd is empty" {
  payload=$(build_payload "do this" "" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — Claude Code" ]
}

@test "title falls back to 'Claude Code' when cwd is /" {
  payload=$(build_payload "do this" "/" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — Claude Code" ]
}

@test "project name is basename of cwd" {
  payload=$(build_payload "do this" "/a/b/c/my-project" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — my-project" ]
}

# ---------------------------------------------------------------------------
# Message defaults
# ---------------------------------------------------------------------------

@test "message defaults when payload lacks a message field" {
  run_hook '{"cwd":"/home/user/proj"}'
  [ "$status" -eq 0 ]
  [ "$(capture_message)" = "Claude Code needs your attention" ]
}

@test "message is taken from payload when present" {
  payload=$(build_payload "build complete" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_message)" = "build complete" ]
}

# ---------------------------------------------------------------------------
# Transcript-derived conversation snippet
# ---------------------------------------------------------------------------

@test "title includes short user message from transcript" {
  write_transcript '{"type":"user","message":{"content":"hello world"}}'
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "proj — hello world" ]
}

@test "title truncates user message longer than 50 chars" {
  long=$(printf 'a%.0s' {1..80})
  write_transcript "{\"type\":\"user\",\"message\":{\"content\":\"$long\"}}"
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  expected="proj — $(printf 'a%.0s' {1..49})…"
  [ "$(capture_title)" = "$expected" ]
}

@test "title keeps user message of exactly 50 chars untruncated" {
  msg=$(printf 'a%.0s' {1..50})
  write_transcript "{\"type\":\"user\",\"message\":{\"content\":\"$msg\"}}"
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "proj — $msg" ]
}

@test "title uses first user message when multiple exist" {
  write_transcript \
    '{"type":"user","message":{"content":"first"}}' \
    '{"type":"assistant","message":{"content":"reply"}}' \
    '{"type":"user","message":{"content":"second"}}'
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "proj — first" ]
}

@test "skips user messages whose content is not a string" {
  write_transcript \
    '{"type":"user","message":{"content":[{"type":"text","text":"tool result"}]}}' \
    '{"type":"user","message":{"content":"the real prompt"}}'
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "proj — the real prompt" ]
}

@test "falls back to project-only title when transcript file is unreadable" {
  write_transcript '{"type":"user","message":{"content":"hi"}}'
  chmod 000 "$TRANSCRIPT"
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — proj" ]
}

@test "falls back to project-only title when transcript file is missing" {
  payload=$(build_payload "needs you" "/home/user/proj" "/nonexistent/transcript.jsonl")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — proj" ]
}

@test "falls back to project-only title when transcript has no user message" {
  write_transcript '{"type":"assistant","message":{"content":"hello back"}}'
  payload=$(build_payload "needs you" "/home/user/proj" "$TRANSCRIPT")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_title)" = "Claude Code — proj" ]
}

# ---------------------------------------------------------------------------
# Urgency
# ---------------------------------------------------------------------------

@test "urgency is normal for an ordinary message" {
  payload=$(build_payload "build complete" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_urgency)" = "--urgency=normal" ]
}

@test "urgency is critical when message mentions permission" {
  payload=$(build_payload "permission required for tool" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_urgency)" = "--urgency=critical" ]
}

@test "urgency match for permission is case-insensitive" {
  payload=$(build_payload "PERMISSION required" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_urgency)" = "--urgency=critical" ]
}

@test "urgency is critical when message mentions waiting" {
  payload=$(build_payload "Claude is waiting on your input" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_urgency)" = "--urgency=critical" ]
}

# ---------------------------------------------------------------------------
# Fixed flags
# ---------------------------------------------------------------------------

@test "passes Claude Code as app-name and im.received as category" {
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_app_name)" = "--app-name=Claude Code" ]
  [ "$(capture_category)" = "--category=im.received" ]
}

# ---------------------------------------------------------------------------
# Failure tolerance
# ---------------------------------------------------------------------------

@test "exits 0 even when notify-send fails" {
  make_notify_stub 1
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Idle gate (skip notification when user is actively at the keyboard)
# ---------------------------------------------------------------------------

@test "emits notification when gdbus is absent" {
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$CAPTURE" ]
}

@test "skips notification when user idle time is below threshold" {
  make_gdbus_stub "(uint64 5000,)"
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ ! -f "$CAPTURE" ]
}

@test "emits notification when user idle time is at threshold" {
  make_gdbus_stub "(uint64 10000,)"
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$CAPTURE" ]
}

@test "emits notification when user idle time is well above threshold" {
  make_gdbus_stub "(uint64 60000,)"
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$CAPTURE" ]
}

@test "parses idle value from gdbus output, not the digits in 'uint64'" {
  make_gdbus_stub "(uint64 60000,)"
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$CAPTURE" ]
}

@test "emits notification when gdbus output is malformed" {
  make_gdbus_stub "unexpected output"
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$CAPTURE" ]
}

@test "emits notification when gdbus fails" {
  make_gdbus_stub_failing
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -f "$CAPTURE" ]
}

# ---------------------------------------------------------------------------
# Replace previous notification instead of stacking
# ---------------------------------------------------------------------------

@test "passes --print-id on every invocation" {
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_print_id)" = "--print-id" ]
}

@test "first invocation does not pass --replace-id" {
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$(capture_replace_id)" ]
}

@test "second invocation in same project passes --replace-id of previous id" {
  make_notify_stub 0 7
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ "$(capture_replace_id)" = "--replace-id=7" ]
}

@test "second invocation in a different project does not reuse previous id" {
  make_notify_stub 0 7
  payload_a=$(build_payload "hi" "/home/user/projA" "")
  run_hook "$payload_a"
  [ "$status" -eq 0 ]
  payload_b=$(build_payload "hi" "/home/user/projB" "")
  run_hook "$payload_b"
  [ "$status" -eq 0 ]
  [ -z "$(capture_replace_id)" ]
}

@test "ignores stale state file with non-numeric content" {
  printf 'garbage\n' >"$TMPDIR_TEST/claude-code-notify-_home_user_proj.id"
  payload=$(build_payload "hi" "/home/user/proj" "")
  run_hook "$payload"
  [ "$status" -eq 0 ]
  [ -z "$(capture_replace_id)" ]
}
