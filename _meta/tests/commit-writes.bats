#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/commit/scripts/writes.sh"

setup() {
  mapfile -t git_env < <(git rev-parse --local-env-vars)
  unset "${git_env[@]}"
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  STATE="$WORK/state"
  export WORK STUB_DIR RUNTIME STATE

  mkdir -p "$STUB_DIR" "$RUNTIME" "$STATE" "$WORK/.claude"
  git init -q "$WORK"
  printf '%s\n' .stubs/ runtime/ state/ .claude/ >>"$WORK/.git/info/exclude"
  for cmd in git date sort rm mkdir sha256sum readlink; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  chmod -R u+rw "$WORK" 2>/dev/null
  rm -rf "$WORK"
}

run_writes() {
  local session=${1-s1} dir=${2:-$WORK}
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" XDG_STATE_HOME="$STATE" CLAUDE_CODE_SESSION_ID="$session" \
    /bin/bash -c 'cd "$1" && /bin/bash "$2"' _ "$dir" "$SCRIPT"
}

run_restamp() {
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" XDG_STATE_HOME="$STATE" CLAUDE_CODE_SESSION_ID=s1 \
    /bin/bash -c 'cd "$1" && /bin/bash "$2" --restamp' _ "$WORK" "$SCRIPT"
}

marker_for() {
  local key
  key=$(printf '%s' "$1" | sha256sum)
  printf '%s/claude-code/verifier-sweep-%s' "$STATE" "${key:0:16}"
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

@test "prints the stamp file, a nanosecond stamp value and the sweep flag first" {
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "STAMP_FILE=$RUNTIME/claude-code-writes-s1.stamp" ]
  [[ ${lines[1]} =~ ^STAMP_VALUE=[0-9]{19}$ ]]
  [ "${lines[2]}" = "SWEEP=yes" ]
  [ "${#lines[@]}" -eq 3 ]
  [ ! -e "$RUNTIME/claude-code-writes-s1.stamp" ]
}

@test "records a digest of every listed path under the stamp value" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  write_at 100 "$WORK/.claude/PLAN.md"
  run_writes
  [ "$status" -eq 0 ]
  value=${lines[1]#STAMP_VALUE=}
  mapfile -t snapshot <"$RUNTIME/claude-code-writes-s1.$value.seen"
  [ "${snapshot[0]}" = "$value" ]
  [ "${#snapshot[@]}" -eq 3 ]
  [[ ${snapshot[1]} == -$'\t'"$WORK/.claude/PLAN.md" ]]
  [[ ${snapshot[2]} == f:*$'\t'"$WORK/a.sh" ]]
  [ ! -e "$RUNTIME/claude-code-writes-s1.stamp" ]
}

@test "--restamp writes a fresh stamp and the snapshot headed by it, and lists nothing" {
  printf '100\n' >"$RUNTIME/claude-code-writes-s1.stamp"
  printf 'x\n' >"$WORK/new.sh"
  run_restamp
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  value=${lines[1]#STAMP_VALUE=}
  [[ $value =~ ^[0-9]{19}$ ]]
  [ "$(<"$RUNTIME/claude-code-writes-s1.stamp")" = "$value" ]
  mapfile -t snapshot <"$RUNTIME/claude-code-writes-s1.$value.seen"
  [ "${snapshot[0]}" = "$value" ]
  [[ ${snapshot[1]} == f:*$'\t'"$WORK/new.sh" ]]
}

@test "--restamp exits 1 and keeps the stamp when the snapshot cannot be written" {
  printf '100\n' >"$RUNTIME/claude-code-writes-s1.stamp"
  chmod 500 "$RUNTIME"
  run_restamp
  [ "$status" -eq 1 ]
  [[ $output == *"could not record the snapshot"* ]]
  [ "$(<"$RUNTIME/claude-code-writes-s1.stamp")" = 100 ]
}

@test "--restamp writes nothing without a session id" {
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" XDG_STATE_HOME="$STATE" CLAUDE_CODE_SESSION_ID= \
    /bin/bash -c 'cd "$1" && /bin/bash "$2" --restamp' _ "$WORK" "$SCRIPT"
  [ "$status" -eq 3 ]
  [ ! -e "$RUNTIME/claude-code-writes-.stamp" ]
}

@test "unions the journal and git status, sorted, each path once" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  printf 'x\n' >"$WORK/new.sh"
  write_at 100 "$WORK/a.sh"
  write_at 200 "$WORK/.claude/PLAN.md"
  run_writes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 6 ]
  [ "${lines[3]}" = "$WORK/.claude/PLAN.md" ]
  [ "${lines[4]}" = "$WORK/a.sh" ]
  [ "${lines[5]}" = "$WORK/new.sh" ]
}

@test "lists journal paths written before the stored stamp" {
  printf '300\n' >"$RUNTIME/claude-code-writes-s1.stamp"
  write_at 100 "$WORK/.claude/PLAN.md"
  write_at 200 "$WORK/a.sh"
  run_writes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[3]}" = "$WORK/.claude/PLAN.md" ]
  [ "${lines[4]}" = "$WORK/a.sh" ]
}

@test "resolves git status paths against the repository root from a subdirectory" {
  mkdir -p "$WORK/sub"
  printf 'x\n' >"$WORK/sub/new.sh"
  run_writes s1 "$WORK/sub"
  [ "$status" -eq 0 ]
  [ "${lines[3]}" = "$WORK/sub/new.sh" ]
}

@test "lists both sides of a staged rename as separate paths" {
  commit_file a.sh
  git -C "$WORK" mv a.sh b.sh
  run_writes
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[3]}" = "$WORK/a.sh" ]
  [ "${lines[4]}" = "$WORK/b.sh" ]
}

@test "keeps a git status path holding a space or an accented letter verbatim" {
  printf 'x\n' >"$WORK/my é.sh"
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[3]}" = "$WORK/my é.sh" ]
}

@test "skips a journal line that carries no path" {
  printf '100\n\n' >>"$RUNTIME/claude-code-writes-s1.log"
  write_at 200 "$WORK/a.sh"
  run_writes
  [ "$status" -eq 0 ]
  [[ $output != *$'\n\n'* ]]
  [ "${lines[3]}" = "$WORK/a.sh" ]
}

@test "puts the stamp under /tmp when XDG_RUNTIME_DIR is unset" {
  session="bats-writes-$$"
  # shellcheck disable=SC2016
  run env -u XDG_RUNTIME_DIR PATH="$STUB_DIR" XDG_STATE_HOME="$STATE" CLAUDE_CODE_SESSION_ID="$session" \
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

@test "posts a marker holding today's date and the repository root on the first pass" {
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "SWEEP=yes" ]
  marker=$(marker_for "$WORK")
  [ "$(<"$marker")" = "$(date +%F)"$'\t'"$WORK" ]
}

@test "prints SWEEP=no on a second pass of the same day" {
  run_writes
  [ "${lines[2]}" = "SWEEP=yes" ]
  run_writes s2
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "SWEEP=no" ]
}

@test "prints SWEEP=yes again and refreshes the marker when it carries an earlier date" {
  marker=$(marker_for "$WORK")
  mkdir -p "${marker%/*}"
  printf '%s\t%s\n' 2000-01-01 "$WORK" >"$marker"
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "SWEEP=yes" ]
  [ "$(<"$marker")" = "$(date +%F)"$'\t'"$WORK" ]
}

@test "keys the marker by repository root, so another repository sweeps the same day" {
  run_writes
  [ "${lines[2]}" = "SWEEP=yes" ]
  other=$(realpath "$(mktemp -d)")
  git init -q "$other"
  run_writes s1 "$other"
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "SWEEP=yes" ]
  [ "$(<"$(marker_for "$other")")" = "$(date +%F)"$'\t'"$other" ]
  rm -rf "$other"
}

@test "prints SWEEP=yes and posts no marker outside any git repository" {
  outside=$(realpath "$(mktemp -d)")
  run_writes s1 "$outside"
  rm -rf "$outside"
  [ "$status" -eq 1 ]
  [[ $output == *"SWEEP=yes"* ]]
  [ ! -d "$STATE/claude-code" ]
}

@test "--restamp prints no sweep flag and posts no marker" {
  run_restamp
  [ "$status" -eq 0 ]
  [[ $output != *SWEEP* ]]
  [ ! -e "$(marker_for "$WORK")" ]
}

@test "warns and keeps SWEEP=yes when the marker cannot be posted" {
  mkdir -p "$STATE/claude-code"
  chmod 500 "$STATE/claude-code"
  run_writes
  [ "$status" -eq 0 ]
  [ "${lines[2]}" = "SWEEP=yes" ]
  [[ $output == *"could not post the sweep marker"* ]]
  [ ! -e "$(marker_for "$WORK")" ]
}
