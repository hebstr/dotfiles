#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/commit-gate.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  PROJECT="$WORK/proj"
  FAKE_HOME="$WORK/home"
  OUTSIDE=$(realpath "$(mktemp -d)")
  export WORK STUB_DIR RUNTIME PROJECT FAKE_HOME OUTSIDE

  mkdir -p "$STUB_DIR" "$RUNTIME" "$PROJECT/.claude" "$FAKE_HOME/.claude/memory"
  git init -q "$WORK"
  printf '%s\n' .stubs/ runtime/ >>"$WORK/.git/info/exclude"
  for cmd in cat jq realpath git stat; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK" "$OUTSIDE"
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

commit_file() {
  mkdir -p "$(dirname "$WORK/$1")"
  printf 'v1\n' >"$WORK/$1"
  git -C "$WORK" add -- "$1"
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
}

@test "blocks on a modified tracked file when the session has no journal" {
  commit_file proj/src/a.sh
  printf 'v2\n' >"$PROJECT/src/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/a.sh"* ]]
}

@test "blocks on an untracked file when the session has no journal" {
  mkdir -p "$PROJECT/src"
  printf 'x\n' >"$PROJECT/src/new.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/new.sh"* ]]
}

@test "passes when a modified file predates the stamp" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  touch -d @1000 "$PROJECT/a.sh"
  stamp 2000000000000
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "blocks when a modified file is newer than the stamp" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  touch -d @3000 "$PROJECT/a.sh"
  stamp 2000000000000
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/a.sh"* ]]
}

@test "ignores modified files under .claude and the memory directory" {
  printf 'x\n' >"$PROJECT/.claude/PLAN.md"
  printf 'x\n' >"$FAKE_HOME/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores a git-ignored file" {
  printf 'x\n' >"$PROJECT/build.log"
  printf '%s\n' '*.log' >>"$WORK/.git/info/exclude"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "blocks on a deleted tracked file without a stamp and passes with one" {
  commit_file proj/gone.sh
  rm "$PROJECT/gone.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/gone.sh"* ]]
  stamp 150
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "lists a path seen in both the journal and git status once" {
  mkdir -p "$PROJECT/src"
  printf 'x\n' >"$PROJECT/src/a.sh"
  write_at 200 "$PROJECT/src/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [ "$(grep -c "$PROJECT/src/a.sh" <<<"$output")" -eq 1 ]
  [[ $output == *"1 file(s)"* ]]
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

@test "reads a stamp written without a trailing newline" {
  write_at 100 "$PROJECT/a.sh"
  printf '%s' 150 >"$RUNTIME/claude-code-writes-s1.stamp"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
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
  printf '%s\n' home/.claude/memory >>"$WORK/.git/info/exclude"
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

@test "ignores writes under the git root's .claude when the project dir is a subdirectory" {
  git init -q "$PROJECT"
  mkdir -p "$PROJECT/sub/.claude"
  write_at 200 "$PROJECT/.claude/PLAN.md"
  write_at 201 "$PROJECT/sub/.claude/PLAN.md"
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT/sub" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$(payload "$(commit_message)" false "$PROJECT/sub")" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "ignores writes outside any git work tree" {
  write_at 200 "$OUTSIDE/probe.sh"
  write_at 201 "$OUTSIDE/gone/deeper/x.py"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "lists a repository write but not an out-of-repository one" {
  write_at 200 "$OUTSIDE/probe.sh"
  write_at 201 "$PROJECT/src/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/a.sh"* ]]
  [[ $output != *"$OUTSIDE/probe.sh"* ]]
  [[ $output == *"1 file(s)"* ]]
}

@test "still lists a write in another repository than the project's" {
  git init -q "$OUTSIDE"
  write_at 200 "$OUTSIDE/other.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$OUTSIDE/other.sh"* ]]
}

@test "passes when the message only mentions git commit -m in prose" {
  write_at 200 "$PROJECT/a.sh"
  # shellcheck disable=SC2016
  run_gate "$(payload 'La porte lit `git commit -m` dans le texte final.')"
  [ "$status" -eq 0 ]
}

@test "blocks a git commit -am line" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload "$(printf '%s\n' '```bash' '  git commit -am "fix: y"' '```')")"
  [ "$status" -eq 2 ]
}

@test "blocks a commit chained after its staging command" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload "$(printf '%s\n' '```bash' 'git add a.sh && git commit -m "fix: y"' '```')")"
  [ "$status" -eq 2 ]
}

@test "passes when prose quotes a chained commit" {
  write_at 200 "$PROJECT/a.sh"
  # shellcheck disable=SC2016
  run_gate "$(payload 'Une ligne `git add … && git commit -m` passait inaperçue.')"
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
