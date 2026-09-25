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
  for cmd in realpath git stat rm sha256sum readlink; do
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

seal_only() {
  local value=$1
  shift
  # shellcheck disable=SC2016
  env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s\0" "${@:3}" | /bin/bash "$1" --seal s1 "$2"' _ "$SCRIPT" "$value" "$@"
}

seal() {
  seal_only "$@"
  stamp "$1"
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
  mapfile -t snapshot <"$RUNTIME/claude-code-writes-s1.123.seen"
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
  [ "$status" -eq 0 ]
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
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "keeps comparing content against the stamp's snapshot after a seal whose stamp was never written" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  value=$(date +%s%N)
  seal "$value" "$PROJECT/a.sh"
  seal_only "$((value + 1000))" "$PROJECT/a.sh"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--seal removes the snapshots of values that are neither sealed nor stamped" {
  commit_file proj/a.sh
  seal 100 "$PROJECT/a.sh"
  seal_only 200 "$PROJECT/a.sh"
  seal_only 300 "$PROJECT/a.sh"
  [ -e "$RUNTIME/claude-code-writes-s1.100.seen" ]
  [ ! -e "$RUNTIME/claude-code-writes-s1.200.seen" ]
  [ -e "$RUNTIME/claude-code-writes-s1.300.seen" ]
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

@test "prints a sealed file deleted since, and passes a path sealed absent that is still absent" {
  commit_file proj/a.sh
  commit_file proj/b.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  rm "$PROJECT/b.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh" "$PROJECT/b.sh"
  rm "$PROJECT/a.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "counts an absent path the snapshot does not hold when git status lists it, not when only the journal does" {
  commit_file proj/a.sh
  value=$(date +%s%N)
  seal "$value"
  rm "$PROJECT/a.sh"
  write_at "$((value + 1000))" "$PROJECT/tmp.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "counts a symlink whose target changed since the seal" {
  ln -s one "$PROJECT/link"
  seal "$(date +%s%N)" "$PROJECT/link"
  ln -sfn two "$PROJECT/link"
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/link" ]
}

@test "prints a sealed file it cannot read and exits non-zero" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  chmod 000 "$PROJECT/a.sh"
  run_stale
  [ "$status" -ne 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "--only leaves out tracking paths and prints each path once" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  printf 'x\n' >"$PROJECT/.claude/NOTE.md"
  seal "$(date +%s%N)"
  run_only "$PROJECT/.claude/NOTE.md" "$PROJECT/a.sh" "$PROJECT/a.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/a.sh" ]
}

@test "round-trips a path with spaces and glob characters through the snapshot" {
  commit_file 'proj/a b[1]*.sh'
  printf 'v2\n' >"$PROJECT/a b[1]*.sh"
  seal "$(date +%s%N)" "$PROJECT/a b[1]*.sh"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a b[1]*.sh"
  run_stale
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf 'v3\n' >"$PROJECT/a b[1]*.sh"
  run_stale
  [ "$output" = "$PROJECT/a b[1]*.sh" ]
}

@test "counts a path holding a tab, which the seal cannot record" {
  printf 'x\n' >"$PROJECT/t"$'\t'"ab.sh"
  seal "$(date +%s%N)" "$PROJECT/t"$'\t'"ab.sh"
  [ "$(wc -l <"$RUNTIME/claude-code-writes-s1.$(<"$RUNTIME/claude-code-writes-s1.stamp").seen")" -eq 1 ]
  run_stale
  [ "$status" -eq 0 ]
  [ "$output" = "$PROJECT/t"$'\t'"ab.sh" ]
}

@test "--seal exits 2 on a value that is not a number, writing nothing" {
  run seal_only 'not-a-number'
  [ "$status" -eq 2 ]
  shopt -s nullglob
  snapshots=("$RUNTIME"/*.seen)
  [ "${#snapshots[@]}" -eq 0 ]
}

@test "--seal exits non-zero when the snapshot cannot be written, and keeps the previous one" {
  commit_file proj/a.sh
  seal 100 "$PROJECT/a.sh"
  chmod 500 "$RUNTIME"
  run seal_only 200 "$PROJECT/a.sh"
  [ "$status" -ne 0 ]
  [ -e "$RUNTIME/claude-code-writes-s1.100.seen" ]
}

@test "rejects a session id carrying a path separator" {
  run_stale '../s1'
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}
