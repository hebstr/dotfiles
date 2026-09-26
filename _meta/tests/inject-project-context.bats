#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/inject-project-context.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  RUNTIME="$WORK/runtime"
  PROJECT="$WORK/project"
  export WORK RUNTIME PROJECT

  mkdir -p "$RUNTIME" "$PROJECT" "$WORK/.claude/memory"
  printf '# Memory Index\n- [a.md](a.md): entry\n' >"$WORK/.claude/memory/MEMORY.md"
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016
  run env HOME="$WORK" XDG_RUNTIME_DIR="$RUNTIME" \
    /bin/bash -c 'cd "$3" && printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT" "$PROJECT"
}

@test "clears the session's injection marker on compact" {
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1-a1"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s2"
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s2-a1"
  run_hook '{"session_id": "s1", "source": "compact"}'
  [ "$status" -eq 0 ]
  [ ! -e "$RUNTIME/claude-code-rules-s1" ]
  [ ! -e "$RUNTIME/claude-code-rules-s1-a1" ]
  [ -e "$RUNTIME/claude-code-rules-s2" ]
  [ -e "$RUNTIME/claude-code-rules-s2-a1" ]
}

@test "keeps the marker on startup and resume" {
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-s1"
  run_hook '{"session_id": "s1", "source": "startup"}'
  run_hook '{"session_id": "s1", "source": "resume"}'
  [ -e "$RUNTIME/claude-code-rules-s1" ]
}

@test "ignores an unsafe session id" {
  printf 'pdf\n' >"$RUNTIME/claude-code-rules-x"
  run_hook '{"session_id": "../claude-code-rules-x", "source": "compact"}'
  [ -e "$RUNTIME/claude-code-rules-x" ]
}

@test "points at .claude/PLAN.md on startup and after compaction" {
  mkdir -p "$PROJECT/.claude"
  : >"$PROJECT/.claude/PLAN.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'This project has .claude/PLAN.md: read it'* ]]
  run_hook '{"session_id": "s1", "source": "compact"}'
  [[ $output == *'re-read .claude/PLAN.md'* ]]
}

@test "falls back to a root PLAN.md and flags it as legacy" {
  : >"$PROJECT/PLAN.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'This project has PLAN.md'* ]]
  [[ $output == *'Legacy root-level Claude file(s): PLAN.md.'* ]]
}

@test "says nothing about plans or legacy files in a bare project" {
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output != *PLAN* ]]
  [[ $output != *Legacy* ]]
}

@test "flags a root CLAUDE.md masking .claude/CLAUDE.md" {
  mkdir -p "$PROJECT/.claude"
  : >"$PROJECT/CLAUDE.md"
  : >"$PROJECT/.claude/CLAUDE.md"
  run_hook '{"session_id": "s1", "source": "resume"}'
  [[ $output == *'root copy masks the other'* ]]
}

@test "prints the pointer before the memory index" {
  mkdir -p "$PROJECT/.claude"
  : >"$PROJECT/.claude/PLAN.md"
  run_hook '{"session_id": "s1", "source": "startup"}'
  [[ $output == *'This project has'*'Global memory index'* ]]
}

@test "still prints the memory index whatever the payload" {
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [[ $output == *'Global memory index'* ]]
  [[ $output == *'[a.md](a.md)'* ]]
}
