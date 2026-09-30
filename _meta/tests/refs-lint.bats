#!/usr/bin/env bats
# Tests for bin/.local/bin/refs-lint.py

bats_require_minimum_version 1.5.0

SCRIPT="${REFS_LINT:-$BATS_TEST_DIRNAME/../../bin/.local/bin/refs-lint.py}"

# ─── fixture factories ──────────────────────────────────────────────────────

_project() {
  local root="$BATS_TEST_TMPDIR/proj"
  mkdir -p "$root/.claude" "$root/_meta/notes"
  git -C "$root" init -q
  printf '%s' "$root"
}

_nested() {
  local root
  root=$(_project)
  git -C "$root/.claude" init -q
  printf '%s' "$root"
}

_note() {
  printf '%s\n' "$2" >"$1"
}

# ─── root discovery ─────────────────────────────────────────────────────────

@test "a target in a nested .claude repository takes the parent as its corpus root" {
  local root
  root=$(_nested)
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'
  _note "$root/_meta/notes/trace.md" 'A named section here'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 0 ]
  [[ $output == *"corpus"*"under $root"* ]]
  [[ $output == *"1 named references tested, 0 dangling"* ]]
}

@test "a target in an ordinary repository takes that repository as its corpus root" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'
  _note "$root/_meta/notes/trace.md" 'A named section here'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 0 ]
  [[ $output == *"under $root"* ]]
}

@test "--root overrides discovery" {
  local root
  root=$(_nested)
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'
  _note "$root/_meta/notes/trace.md" 'A named section here'

  run "$SCRIPT" --root "$root/.claude" "$root/.claude/note.md"
  [ "$status" -eq 1 ]
  [[ $output == *"1 dangling"* ]]
}

# ─── the named-reference pass ───────────────────────────────────────────────

@test "a name resolving nowhere is reported and exits 1" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 1 ]
  [[ $output == *"A named section here"* ]]
  [[ $output == *"1 named references tested, 1 dangling"* ]]
}

@test "a name appearing twice in the target itself is not reported" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'see "A named section here"

## A named section here'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 0 ]
  [[ $output == *"0 dangling"* ]]
}

@test "a name resolving in a .bats file of the corpus is not reported" {
  local root
  root=$(_project)
  mkdir -p "$root/_meta/tests"
  _note "$root/.claude/note.md" 'the test see "handles an empty payload"'
  _note "$root/_meta/tests/x.bats" '@test "handles an empty payload" {'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 0 ]
  [[ $output == *"0 dangling"* ]]
}

@test "a quoted span with no cue word before it is never tested" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'It prints "A named section here" on failure.'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 0 ]
  [[ $output == *"0 named references tested"* ]]
}

@test "a pruned directory is not part of the corpus" {
  local root
  root=$(_project)
  mkdir -p "$root/node_modules/pkg"
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'
  _note "$root/node_modules/pkg/README.md" 'A named section here'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 1 ]
}

@test "--corpus replaces the default globs" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'
  _note "$root/_meta/notes/trace.md" 'A named section here'

  run "$SCRIPT" --corpus '*.txt' "$root/.claude/note.md"
  [ "$status" -eq 1 ]
  [[ $output == *"1 dangling"* ]]
}

# ─── the enumeration pass ───────────────────────────────────────────────────

@test "an enumeration reference is listed without changing the exit code" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'The remedy is in part 5 of the block above.'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 0 ]
  [[ $output == *"ordinal part 5"* ]]
  [[ $output == *"1 enumeration references"* ]]
}

@test "an enumeration reference is listed beside a dangling name" {
  local root
  root=$(_project)
  _note "$root/.claude/note.md" 'As decided in see "A named section here", part 2.'

  run "$SCRIPT" "$root/.claude/note.md"
  [ "$status" -eq 1 ]
  [[ $output == *"1 dangling"* ]]
  [[ $output == *"ordinal part 2"* ]]
}

# ─── arguments ──────────────────────────────────────────────────────────────

@test "a target that is not a file exits 2" {
  run "$SCRIPT" "$BATS_TEST_TMPDIR/absent.md"
  [ "$status" -eq 2 ]
  [[ $output == *"not a file"* ]]
}

@test "several targets are each checked and one dangling name fails the run" {
  local root
  root=$(_project)
  _note "$root/.claude/clean.md" 'nothing named here'
  _note "$root/.claude/note.md" 'As decided in see "A named section here".'

  run "$SCRIPT" "$root/.claude/clean.md" "$root/.claude/note.md"
  [ "$status" -eq 1 ]
  [[ $output == *"clean.md: 0 named references tested"* ]]
  [[ $output == *"note.md: 1 named references tested, 1 dangling"* ]]
}
