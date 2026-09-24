#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/commit/scripts/writes.sh"

setup() {
  mapfile -t git_env < <(git rev-parse --local-env-vars)
  unset "${git_env[@]}"
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  export WORK STUB_DIR RUNTIME

  mkdir -p "$STUB_DIR" "$RUNTIME" "$WORK/.claude"
  git init -q "$WORK"
  printf '%s\n' .stubs/ runtime/ .claude/ >>"$WORK/.git/info/exclude"
  for cmd in git date sort; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_writes() {
  local session=${1-s1} dir=${2:-$WORK}
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" CLAUDE_CODE_SESSION_ID="$session" \
    /bin/bash -c 'cd "$1" && /bin/bash "$2"' _ "$dir" "$SCRIPT"
}

write_at() {
  printf '%s\t%s\n' "$1" "$2" >>"$RUNTIME/claude-code-writes-s1.log"
}

commit_file() {
  printf 'v1\n' >"$WORK/$1"
  git -C "$WORK" add -- "$1"
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
}

fail_git_status() {
  local real_git
  real_git=$(command -v git)
  rm "$STUB_DIR/git"
  # shellcheck disable=SC2016
  printf '#!/bin/bash\nfor a in "$@"; do [[ $a == status ]] && exit 128; done\nexec %q "$@"\n' "$real_git" >"$STUB_DIR/git"
  chmod +x "$STUB_DIR/git"
}

@test "prints the stamp file and a nanosecond stamp value first" {
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "STAMP_FILE=$RUNTIME/claude-code-writes-s1.stamp" ]
  [[ ${lines[1]} =~ ^STAMP_VALUE=[0-9]{19}$ ]]
  [ "${#lines[@]}" -eq 2 ]
  [ ! -e "$RUNTIME/claude-code-writes-s1.stamp" ]
}

@test "unions the journal and git status, sorted, each path once" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  printf 'x\n' >"$WORK/new.sh"
  write_at 100 "$WORK/a.sh"
  write_at 200 "$WORK/.claude/PLAN.md"
  run_writes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[2]}" = "$WORK/.claude/PLAN.md" ]
  [ "${lines[3]}" = "$WORK/a.sh" ]
  [ "${lines[4]}" = "$WORK/new.sh" ]
}

@test "lists journal paths written before the stored stamp" {
  printf '300\n' >"$RUNTIME/claude-code-writes-s1.stamp"
  write_at 100 "$WORK/.claude/PLAN.md"
  write_at 200 "$WORK/a.sh"
  run_writes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[2]}" = "$WORK/.claude/PLAN.md" ]
  [ "${lines[3]}" = "$WORK/a.sh" ]
}

@test "resolves git status paths against the repository root from a subdirectory" {
  mkdir -p "$WORK/sub"
  printf 'x\n' >"$WORK/sub/new.sh"
  run_writes s1 "$WORK/sub"
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "$WORK/sub/new.sh" ]
}

@test "lists both sides of a staged rename as separate paths" {
  commit_file a.sh
  git -C "$WORK" mv a.sh b.sh
  run_writes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 4 ]
  [ "${lines[2]}" = "$WORK/a.sh" ]
  [ "${lines[3]}" = "$WORK/b.sh" ]
}

@test "keeps a git status path holding a space or an accented letter verbatim" {
  printf 'x\n' >"$WORK/my é.sh"
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "$WORK/my é.sh" ]
}

@test "skips a journal line that carries no path" {
  printf '100\n\n' >>"$RUNTIME/claude-code-writes-s1.log"
  write_at 200 "$WORK/a.sh"
  run_writes
  [ "$status" -eq 0 ]
  [[ $output != *$'\n\n'* ]]
  [ "${lines[2]}" = "$WORK/a.sh" ]
}

@test "puts the stamp under /tmp when XDG_RUNTIME_DIR is unset" {
  session="bats-writes-$$"
  # shellcheck disable=SC2016
  run env -u XDG_RUNTIME_DIR PATH="$STUB_DIR" CLAUDE_CODE_SESSION_ID="$session" \
    /bin/bash -c 'cd "$1" && /bin/bash "$2"' _ "$WORK" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "STAMP_FILE=/tmp/claude-code-writes-${session}.stamp" ]
}

@test "exits 1 with a notice outside any git repository, still listing journaled paths" {
  outside=$(realpath "$(mktemp -d)")
  write_at 100 "/elsewhere/a.sh"
  run_writes s1 "$outside"
  rm -rf "$outside"
  [ "$status" -eq 1 ]
  [[ $output == *"no git repository"* ]]
  [ "${lines[-1]}" = "/elsewhere/a.sh" ]
}

@test "keeps exit 3 over the missing repository when both apply" {
  outside=$(realpath "$(mktemp -d)")
  run_writes '' "$outside"
  rm -rf "$outside"
  [ "$status" -eq 3 ]
  [[ $output == *"no git repository"* ]]
}

@test "prints no stamp and exits 3 without a session id, still listing git status" {
  printf 'x\n' >"$WORK/new.sh"
  run_writes ''
  [ "$status" -eq 3 ]
  [[ $output != *STAMP_* ]]
  [[ $output == *"$WORK/new.sh"* ]]
}

@test "treats a session id carrying a path separator as missing" {
  run_writes '../s1'
  [ "$status" -eq 3 ]
  [[ $output != *STAMP_* ]]
}

@test "exits 1 and keeps the journal paths when git status fails" {
  write_at 100 "$WORK/a.sh"
  fail_git_status
  run_writes
  [ "$status" -eq 1 ]
  [[ $output == *"git status failed"* ]]
  [ "${lines[-1]}" = "$WORK/a.sh" ]
}

@test "keeps exit 3 over a failed git status when both apply" {
  fail_git_status
  run_writes ''
  [ "$status" -eq 3 ]
  [[ $output == *"git status failed"* ]]
}
