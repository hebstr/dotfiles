#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/commit-gate.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  PROJECT="$WORK/proj"
  FAKE_HOME="$WORK/home"
  export WORK STUB_DIR RUNTIME PROJECT FAKE_HOME

  mkdir -p "$STUB_DIR" "$RUNTIME" "$PROJECT/.claude" "$FAKE_HOME/.claude/memory"
  for cmd in cat jq realpath; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_gate() {
  local payload=$1
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  local message=$1 active=${2:-false} cwd=${3:-$PROJECT}
  jq -nc --arg m "$message" --argjson a "$active" --arg c "$cwd" \
    '{session_id: "s1", cwd: $c, stop_hook_active: $a, last_assistant_message: $m}'
}

commit_message() {
  printf '%s\n' 'Voici le commit :' '```bash' 'git add .' 'git commit -m "feat(x): y"' '```'
}

write_at() {
  printf '%s\t%s\n' "$1" "$2" >>"$RUNTIME/claude-code-writes-s1.log"
}

stamp() {
  printf '%s\n' "$1" >"$RUNTIME/claude-code-writes-s1.stamp"
}

@test "blocks a commit proposal after a code write with no stamp" {
  write_at 100 "$PROJECT/src/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/a.sh"* ]]
  [[ $output == *"/commit"* ]]
  [[ $output == *"stale"* ]]
}

@test "blocks when a code write is newer than the stamp" {
  stamp 150
  write_at 100 "$PROJECT/old.sh"
  write_at 200 "$PROJECT/new.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/new.sh"* ]]
  [[ $output != *"$PROJECT/old.sh"* ]]
}

@test "passes when every code write predates the stamp" {
  write_at 100 "$PROJECT/a.sh"
  stamp 150
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes when the stamp equals the last write" {
  write_at 150 "$PROJECT/a.sh"
  stamp 150
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores writes under the project's .claude directory" {
  write_at 200 "$PROJECT/.claude/PLAN.md"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores writes under the resolved memory directory" {
  write_at 200 "$FAKE_HOME/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "resolves a symlinked memory directory before comparing" {
  rm -rf "$FAKE_HOME/.claude/memory"
  mkdir -p "$WORK/dotfiles/claude/.claude/memory"
  ln -s "$WORK/dotfiles/claude/.claude/memory" "$FAKE_HOME/.claude/memory"
  write_at 200 "$WORK/dotfiles/claude/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "a .claude directory that is not the project's own still counts as code" {
  write_at 200 "$WORK/dotfiles/claude/.claude/hooks/x.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"claude/.claude/hooks/x.sh"* ]]
}

@test "a sibling directory sharing the .claude prefix is not excluded" {
  write_at 200 "$PROJECT/.claude-old/x.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
}

@test "prefers CLAUDE_PROJECT_DIR over cwd as the project root" {
  mkdir -p "$PROJECT/sub"
  write_at 200 "$PROJECT/.claude/PLAN.md"
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$(payload "$(commit_message)" false "$PROJECT/sub")" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes when the message proposes no commit" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload 'Le script est prêt.')"
  [ "$status" -eq 0 ]
}

@test "passes when stop_hook_active is true" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload "$(commit_message)" true)"
  [ "$status" -eq 0 ]
}

@test "passes when the session has no journal" {
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "treats a malformed stamp as absent" {
  write_at 100 "$PROJECT/a.sh"
  stamp garbage
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
}

@test "skips malformed journal lines" {
  printf 'garbage line\n\t%s\n' "$PROJECT/b.sh" >"$RUNTIME/claude-code-writes-s1.log"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "lists a path written twice only once" {
  write_at 100 "$PROJECT/a.sh"
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [ "$(grep -c "$PROJECT/a.sh" <<<"$output")" -eq 1 ]
  [[ $output == *"1 file(s)"* ]]
}

@test "caps the listed paths at ten and counts the rest" {
  for i in $(seq 1 12); do
    write_at "$((100 + i))" "$PROJECT/f$i.sh"
  done
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"12 file(s)"* ]]
  [[ $output == *"and 2 more"* ]]
  [[ $output != *"$PROJECT/f11.sh"* ]]
}

@test "ignores a session id carrying a path separator" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(jq -nc --arg m "$(commit_message)" '{session_id: "../s1", cwd: "/x", stop_hook_active: false, last_assistant_message: $m}')"
  [ "$status" -eq 0 ]
}

@test "exits 0 on malformed JSON" {
  run_gate 'not json'
  [ "$status" -eq 0 ]
}

@test "exits 0 silently when jq is missing" {
  write_at 200 "$PROJECT/a.sh"
  rm -f "$STUB_DIR/jq"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
