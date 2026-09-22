#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/write-journal.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  export WORK STUB_DIR RUNTIME

  mkdir -p "$STUB_DIR" "$RUNTIME"
  for cmd in cat jq realpath date; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  jq -nc --arg s "$1" --arg p "$2" '{session_id: $s, cwd: "/x", tool_input: {file_path: $p}}'
}

journal() {
  printf '%s' "$RUNTIME/claude-code-writes-$1.log"
}

@test "appends one timestamped line per write, keyed by session" {
  run_hook "$(payload abc-123 "$WORK/a.sh")"
  [ "$status" -eq 0 ]
  run_hook "$(payload abc-123 "$WORK/b.md")"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$(journal abc-123)")" -eq 2 ]
  run cut -f2 "$(journal abc-123)"
  [ "${lines[0]}" = "$WORK/a.sh" ]
  [ "${lines[1]}" = "$WORK/b.md" ]
}

@test "timestamp is an integer in nanoseconds" {
  run_hook "$(payload s1 "$WORK/a.sh")"
  run cut -f1 "$(journal s1)"
  [[ $output =~ ^[0-9]{19}$ ]]
}

@test "separate sessions write separate journals" {
  run_hook "$(payload s1 "$WORK/a.sh")"
  run_hook "$(payload s2 "$WORK/b.sh")"
  [ "$(cut -f2 "$(journal s1)")" = "$WORK/a.sh" ]
  [ "$(cut -f2 "$(journal s2)")" = "$WORK/b.sh" ]
}

@test "records the resolved path of a symlink" {
  mkdir -p "$WORK/real"
  : >"$WORK/real/f.md"
  ln -s "$WORK/real" "$WORK/link"
  run_hook "$(payload s1 "$WORK/link/f.md")"
  [ "$(cut -f2 "$(journal s1)")" = "$WORK/real/f.md" ]
}

@test "records a path whose file does not exist yet" {
  run_hook "$(payload s1 "$WORK/new/dir/f.md")"
  [ "$(cut -f2 "$(journal s1)")" = "$WORK/new/dir/f.md" ]
}

@test "falls back to /tmp when XDG_RUNTIME_DIR is unset" {
  local sid="bats-$$-$RANDOM"
  # shellcheck disable=SC2016
  run env -u XDG_RUNTIME_DIR PATH="$STUB_DIR" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$(payload "$sid" "$WORK/a.sh")" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "/tmp/claude-code-writes-$sid.log" ]
  rm -f "/tmp/claude-code-writes-$sid.log"
}

@test "journal is private to the user" {
  run_hook "$(payload s1 "$WORK/a.sh")"
  [ "$(stat -c %a "$(journal s1)")" = "600" ]
}

@test "ignores a session id carrying a path separator" {
  run_hook "$(payload '../evil' "$WORK/a.sh")"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
  [ ! -e "$WORK/evil.log" ]
}

@test "ignores a payload with no session id" {
  run_hook "$(jq -nc --arg p "$WORK/a.sh" '{tool_input: {file_path: $p}}')"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
}

@test "ignores a payload with no file path" {
  run_hook '{"session_id":"s1","tool_input":{}}'
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
}

@test "ignores a path containing a newline" {
  run_hook "$(payload s1 "$WORK/a"$'\n'"b.sh")"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
}

@test "ignores a path containing a tab" {
  run_hook "$(payload s1 "$WORK/a"$'\t'"b.sh")"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
}

@test "exits 0 on malformed JSON" {
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
}

@test "exits 0 silently when jq is missing" {
  rm -f "$STUB_DIR/jq"
  run_hook "$(payload s1 "$WORK/a.sh")"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$RUNTIME")" ]
}

@test "exits 0 when the runtime directory is not writable" {
  chmod 500 "$RUNTIME"
  run_hook "$(payload s1 "$WORK/a.sh")"
  chmod 700 "$RUNTIME"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
