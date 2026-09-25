#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/commit-stale.sh"

setup() {
  mapfile -t git_env < <(git rev-parse --local-env-vars)
  unset "${git_env[@]}"
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  PROJECT="$WORK/proj"
  FAKE_HOME="$WORK/home"
  export WORK STUB_DIR RUNTIME PROJECT FAKE_HOME

  mkdir -p "$STUB_DIR" "$RUNTIME" "$PROJECT/.claude" "$FAKE_HOME/.claude/memory"
  git init -q "$WORK"
  printf '%s\n' .stubs/ runtime/ >>"$WORK/.git/info/exclude"
  for cmd in realpath git stat sha256sum readlink; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  chmod -R u+rw "$WORK" 2>/dev/null
  rm -rf "$WORK"
}

run_stale() {
  local session=${1:-s1} root=${2:-$PROJECT}
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash "$SCRIPT" "$session" "$root"
}

run_only() {
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s\0" "${@:3}" | /bin/bash "$1" --only s1 "$2"' _ "$SCRIPT" "$PROJECT" "$@"
}

write_at() {
  printf '%s\t%s\n' "$1" "$2" >>"$RUNTIME/claude-code-writes-s1.log"
}

stamp() {
  printf '%s\n' "$1" >"$RUNTIME/claude-code-writes-s1.stamp"
}

seal() {
  local value=$1
  shift
  # shellcheck disable=SC2016
  env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s\0" "${@:3}" | /bin/bash "$1" --seal s1 "$2"' _ "$SCRIPT" "$value" "$@"
  stamp "$value"
}

commit_file() {
  mkdir -p "$(dirname "$WORK/$1")"
  printf 'v1\n' >"$WORK/$1"
  git -C "$WORK" add -- "$1"
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
}

@test "prints nothing and exits 0 with no journal and a clean tree" {
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints a modified file newer than the stamp, one path per line" {
  commit_file proj/a.sh
  commit_file proj/b.sh
  stamp "$(date +%s%N)"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a.sh"
  printf 'v2\n' >"$PROJECT/b.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ $output == *"$PROJECT/a.sh"* ]]
  [[ $output == *"$PROJECT/b.sh"* ]]
}

@test "prints nothing when every change predates the stamp" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  write_at 100 "$PROJECT/a.sh"
  sleep 0.05
  stamp "$(date +%s%N)"
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints a journaled code write newer than the stamp" {
  mkdir -p "$PROJECT/src"
  printf 'x\n' >"$PROJECT/src/a.sh"
  git -C "$WORK" add -- proj/src/a.sh
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
  stamp 100
  write_at 200 "$PROJECT/src/a.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/src/a.sh" ]
}

@test "leaves out the project's .claude directory and the memory directory" {
  stamp 100
  write_at 200 "$PROJECT/.claude/PLAN.md"
  write_at 200 "$FAKE_HOME/.claude/memory/x.md"
  printf 'x\n' >"$PROJECT/.claude/NOTE.md"
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "treats a malformed stamp as absent and exits non-zero" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  stamp 'not-a-number'
  run_stale
  [ "$status" -ne 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "treats an unreadable stamp as absent and exits non-zero" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  stamp "$(date +%s%N)"
  chmod 000 "$RUNTIME/claude-code-writes-s1.stamp"
  run_stale
  [ "$status" -ne 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "exits non-zero on an unreadable journal" {
  write_at 200 "$PROJECT/a.sh"
  chmod 000 "$RUNTIME/claude-code-writes-s1.log"
  run_stale
  [ "$status" -ne 0 ]
}

@test "exits non-zero and keeps the journal paths when git status fails" {
  mkdir -p "$PROJECT/src"
  printf 'x\n' >"$PROJECT/src/a.sh"
  git -C "$WORK" add -- proj/src/a.sh
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
  write_at 200 "$PROJECT/src/a.sh"
  real_git=$(command -v git)
  rm "$STUB_DIR/git"
  # shellcheck disable=SC2016
  printf '#!/bin/bash\nfor a in "$@"; do [[ $a == status ]] && exit 128; done\nexec %q "$@"\n' "$real_git" >"$STUB_DIR/git"
  chmod +x "$STUB_DIR/git"
  run_stale
  [ "$status" -ne 0 ]
  [ "$output" = "$PROJECT/src/a.sh" ]
}

@test "--seal writes the stamp value as the snapshot header, then one digest per path" {
  commit_file proj/a.sh
  seal 123 "$PROJECT/a.sh"
  mapfile -t snapshot <"$RUNTIME/claude-code-writes-s1.seen"
  [ "${snapshot[0]}" = 123 ]
  [ "${#snapshot[@]}" -eq 2 ]
  [[ ${snapshot[1]} == f:*$'\t'"$PROJECT/a.sh" ]]
}

@test "passes a rewrite that keeps the sealed content although its ctime moved" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prints a file whose content differs from the sealed snapshot" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  printf 'v3\n' >"$PROJECT/a.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "prints a file the snapshot does not hold, even when its ctime predates the stamp" {
  printf 'x\n' >"$PROJECT/new.sh"
  sleep 0.05
  seal "$(date +%s%N)"
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/new.sh" ]
}

@test "counts a change of the executable bit" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  chmod +x "$PROJECT/a.sh"
  run_stale
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "passes a journaled write that restored the sealed content" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  value=$(date +%s%N)
  seal "$value" "$PROJECT/a.sh"
  write_at "$((value + 1000))" "$PROJECT/a.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "falls back to ctime when the snapshot belongs to another stamp" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal 100 "$PROJECT/a.sh"
  stamp "$(date +%s%N)"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a.sh"
  run_stale
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "--only checks the given paths alone" {
  commit_file proj/a.sh
  commit_file proj/b.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  printf 'v2\n' >"$PROJECT/b.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh" "$PROJECT/b.sh"
  printf 'v3\n' >"$PROJECT/a.sh"
  printf 'v3\n' >"$PROJECT/b.sh"
  run_only "$PROJECT/a.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "--only still reports an unreadable stamp" {
  commit_file proj/a.sh
  stamp 'not-a-number'
  run_only
  [ "$status" -ne 0 ]
}

@test "rejects a session id carrying a path separator" {
  run_stale '../s1'
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}
