#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

# Pins tail.sh of the handoff skill: which journal entries reach the scope, and
# which failure exits with no list rather than with an empty one. Two traps drive
# the harness:
#   1. the script reads the journal and never the filesystem, so every path in a
#      fixture is a literal string and no file is created for it;
#   2. those literal paths stay outside /tmp, which the script filters, while the
#      journal itself lives under BATS_TEST_TMPDIR, which it never inspects;
#   3. tab is an IFS whitespace character, so a line opening on a tab collapses to
#      one field instead of yielding an empty timestamp: the two malformed shapes
#      a truncated write can leave are spelled out rather than built from an empty
#      first field, which never reaches the loop as one.

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/handoff/scripts/tail.sh"

setup() {
  RUNTIME="$BATS_TEST_TMPDIR/runtime"
  JOURNAL="$RUNTIME/claude-code-writes-s1.log"
  STAMP="$RUNTIME/claude-code-writes-s1.stamp"
  export RUNTIME JOURNAL STAMP
  mkdir -p "$RUNTIME"
}

journal_line() {
  printf '%s\t%s\n' "$1" "$2" >>"$JOURNAL"
}

stamp_at() {
  printf '%s\n' "$1" >"$STAMP"
}

tail_env() {
  env XDG_RUNTIME_DIR="$RUNTIME" TMPDIR="${2:-/scratch/tmp}" \
    CLAUDE_CODE_SESSION_ID="${1-s1}" /bin/bash "$SCRIPT"
}

@test "prints the paths later than the stamp and drops the earlier ones" {
  stamp_at 1762000000000000000
  journal_line 1761999999999999999 /repo/before.md
  journal_line 1762000000000000001 /repo/after.md
  run -0 --separate-stderr tail_env
  [ "$output" = "/repo/after.md" ]
}

@test "a path whose timestamp equals the stamp stays out of the scope" {
  stamp_at 1762000000000000000
  journal_line 1762000000000000000 /repo/sealed.md
  run -0 --separate-stderr tail_env
  [ -z "$output" ]
}

@test "drops a path under /tmp and under TMPDIR, keeping the others" {
  stamp_at 1762000000000000000
  journal_line 1762000000000000001 /tmp/claude-1000/scratchpad/probe.md
  journal_line 1762000000000000002 /scratch/tmp/other.md
  journal_line 1762000000000000003 /repo/kept.md
  run -0 --separate-stderr tail_env s1 /scratch/tmp
  [ "$output" = "/repo/kept.md" ]
}

@test "keeps a path belonging to another repository" {
  stamp_at 1762000000000000000
  journal_line 1762000000000000001 /elsewhere/project/.claude/PLAN.md
  run -0 --separate-stderr tail_env
  [ "$output" = "/elsewhere/project/.claude/PLAN.md" ]
}

@test "prints each path once, sorted" {
  stamp_at 1762000000000000000
  journal_line 1762000000000000001 /repo/b.md
  journal_line 1762000000000000002 /repo/a.md
  journal_line 1762000000000000003 /repo/b.md
  run -0 --separate-stderr tail_env
  [ "${lines[0]}" = "/repo/a.md" ]
  [ "${lines[1]}" = "/repo/b.md" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "no stamp file takes the whole journal as the scope and says so" {
  journal_line 1762000000000000001 /repo/a.md
  journal_line 1762000000000000002 /repo/b.md
  run -0 --separate-stderr tail_env
  [ "${#lines[@]}" -eq 2 ]
  [[ $stderr == *"no stamp"* ]]
}

@test "an unreadable journal exits non-zero and prints no path" {
  stamp_at 1762000000000000000
  journal_line 1762000000000000001 /repo/a.md
  chmod 000 "$JOURNAL"
  run ! --separate-stderr tail_env
  [ -z "$output" ]
  [[ $stderr == *"journal"* ]]
}

@test "a missing journal exits non-zero and prints no path" {
  run ! --separate-stderr tail_env
  [ -z "$output" ]
  [[ $stderr == *"journal"* ]]
}

@test "an empty stamp file exits non-zero and prints no path" {
  : >"$STAMP"
  journal_line 1762000000000000001 /repo/a.md
  run ! --separate-stderr tail_env
  [ -z "$output" ]
  [[ $stderr == *"stamp"* ]]
}

@test "a stamp left as an unsubstituted token exits non-zero and prints no path" {
  stamp_at '<STAMP_VALUE>'
  journal_line 1762000000000000001 /repo/a.md
  run ! --separate-stderr tail_env
  [ -z "$output" ]
  [[ $stderr == *"stamp"* ]]
}

@test "no usable CLAUDE_CODE_SESSION_ID exits 3 and prints no path" {
  run -3 --separate-stderr tail_env ""
  [ -z "$output" ]
  [[ $stderr == *"CLAUDE_CODE_SESSION_ID"* ]]
}

@test "a journal line whose timestamp is not numeric is counted, the valid paths still printed" {
  stamp_at 1762000000000000000
  journal_line '<STAMP_VALUE>' /repo/orphan.md
  journal_line 1762000000000000001 /repo/a.md
  run ! --separate-stderr tail_env
  [ "$output" = "/repo/a.md" ]
  [[ $stderr == *"1 journal"* ]]
}

@test "a journal line holding a single field is counted, not skipped in silence" {
  stamp_at 1762000000000000000
  printf '%s\n' /repo/truncated.md >>"$JOURNAL"
  journal_line 1762000000000000001 /repo/a.md
  run ! --separate-stderr tail_env
  [ "$output" = "/repo/a.md" ]
  [[ $stderr == *"1 journal"* ]]
}
