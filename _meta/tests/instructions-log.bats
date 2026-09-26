#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/instructions-log.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  STATE="$WORK/state"
  export WORK STUB_DIR STATE

  mkdir -p "$STUB_DIR"
  for cmd in cat jq date mkdir; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_STATE_HOME="$STATE" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  jq -nc --arg s "$1" --arg r "$2" --arg f "$3" --arg t "${4:-}" \
    '{session_id: $s, hook_event_name: "InstructionsLoaded", load_reason: $r, file_path: $f, memory_type: "User"}
     + (if $t == "" then {} else {trigger_file_path: $t} end)'
}

log_file() {
  printf '%s' "$STATE/claude-code/instructions.log"
}

@test "appends one tab-separated line per load" {
  run_hook "$(payload abc-123 session_start /home/u/.claude/CLAUDE.md)"
  [ "$status" -eq 0 ]
  run_hook "$(payload abc-123 path_glob_match /home/u/.claude/rules/pdf.md /x/a.pdf)"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$(log_file)")" -eq 2 ]
  run awk -F'\t' 'NR == 2 {print $2 "|" $3 "|" $4 "|" $5}' "$(log_file)"
  [ "$output" = "abc-123|path_glob_match|/home/u/.claude/rules/pdf.md|/x/a.pdf" ]
}

@test "leaves the trigger field empty on an eager load" {
  run_hook "$(payload abc-123 session_start /home/u/.claude/rules/docx.md)"
  run awk -F'\t' '{print NF "|" $5}' "$(log_file)"
  [ "$output" = "5|" ]
}

@test "stamps each line with a UTC timestamp" {
  run_hook "$(payload abc-123 session_start /f.md)"
  run cut -f1 "$(log_file)"
  [[ $output =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "skips a payload missing the load reason" {
  run_hook "$(jq -nc '{session_id: "abc", file_path: "/f.md"}')"
  [ "$status" -eq 0 ]
  [ ! -e "$(log_file)" ]
}

@test "skips a payload missing the session" {
  run_hook "$(jq -nc '{load_reason: "session_start", file_path: "/f.md"}')"
  [ "$status" -eq 0 ]
  [ ! -e "$(log_file)" ]
}

@test "skips a session id outside the safe alphabet" {
  run_hook "$(payload 'a/b' session_start /f.md)"
  [ "$status" -eq 0 ]
  [ ! -e "$(log_file)" ]
}

@test "escapes a tab in the path so the line keeps five fields" {
  run_hook "$(payload abc session_start $'/odd\tname.md')"
  run awk -F'\t' '{print NF}' "$(log_file)"
  [ "$output" = "5" ]
}

@test "exits 0 on malformed input" {
  run_hook "not json"
  [ "$status" -eq 0 ]
  [ ! -e "$(log_file)" ]
}

@test "exits 0 when the state directory cannot be created" {
  : >"$WORK/blocker"
  STATE="$WORK/blocker"
  run_hook "$(payload abc session_start /f.md)"
  [ "$status" -eq 0 ]
}

@test "creates the log readable by its owner only" {
  run_hook "$(payload abc session_start /f.md)"
  run stat -c '%a' "$(log_file)"
  [ "$output" = "600" ]
}
