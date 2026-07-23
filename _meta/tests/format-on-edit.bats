#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

SCRIPT="${FORMAT_ON_EDIT_HOOK:-$BATS_TEST_DIRNAME/../../claude/.claude/hooks/format-on-edit.sh}"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  CAPTURE_DIR="$WORK/.capture"
  export WORK STUB_DIR CAPTURE_DIR

  mkdir -p "$STUB_DIR" "$CAPTURE_DIR"
  for cmd in jq realpath tail; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
  make_stub panache
  make_stub prose-lint
  make_stub air
  make_stub jarl
}

teardown() {
  rm -rf "$WORK"
}

make_stub() {
  local name=$1
  cat >"$STUB_DIR/$name" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$CAPTURE_DIR/$name"
exit 0
STUB
  chmod +x "$STUB_DIR/$name"
}

remove_stub() {
  rm -f "$STUB_DIR/$1"
}

fixture() {
  local rel=$1
  mkdir -p "$WORK/$(dirname "$rel")"
  printf '# t\n' >"$WORK/$rel"
  printf '%s' "$WORK/$rel"
}

run_hook() {
  local path=$1 cwd=${2:-$WORK} payload
  payload=$(jq -nc --arg p "$path" '{tool_input: {file_path: $p}}')
  # shellcheck disable=SC2016 # intentional: $1/$2/$3 expand inside the inner shell
  run env PATH="$STUB_DIR" \
    /bin/bash -c 'cd "$3" || exit 99; printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT" "$cwd"
}

run_hook_raw() {
  local payload=$1 cwd=${2:-$WORK}
  # shellcheck disable=SC2016 # intentional: $1/$2/$3 expand inside the inner shell
  run env PATH="$STUB_DIR" \
    /bin/bash -c 'cd "$3" || exit 99; printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT" "$cwd"
}

assert_ran() {
  [ -s "$CAPTURE_DIR/$1" ] || {
    echo "expected $1 to run; capture dir: $(ls -A "$CAPTURE_DIR" 2>/dev/null)" >&2
    return 1
  }
}

assert_not_ran() {
  [ ! -e "$CAPTURE_DIR/$1" ] || {
    echo "expected $1 not to run; it was called with: $(cat "$CAPTURE_DIR/$1")" >&2
    return 1
  }
}

@test "skips everything when the file resolves outside PWD" {
  mkdir -p "$WORK/inside"
  f=$(fixture "outside/notes.md")

  run_hook "$f" "$WORK/inside"

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "formats and lints a plain .md" {
  f=$(fixture "notes.md")

  run_hook "$f"

  assert_ran panache
  assert_ran prose-lint
  [[ $(cat "$CAPTURE_DIR/panache") == "format --force-exclude $f" ]]
}

@test "formats and lints a plain .qmd" {
  f=$(fixture "report.qmd")

  run_hook "$f"

  assert_ran panache
  assert_ran prose-lint
  [[ $(cat "$CAPTURE_DIR/panache") == *--force-exclude* ]]
}

@test "skips both tools inside _snaps" {
  f=$(fixture "tests/testthat/_snaps/render.md")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "skips panache but still calls prose-lint on a memory file" {
  f=$(fixture "memory/note.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "skips panache but still calls prose-lint on PLAN.md" {
  f=$(fixture "PLAN.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "skips panache but still calls prose-lint on DEFERRED.md" {
  f=$(fixture "DEFERRED.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "skips panache but still calls prose-lint on any CLAUDE.md" {
  f=$(fixture "sub/CLAUDE.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "skips panache but still calls prose-lint on any rules file" {
  f=$(fixture "sub/rules/quarto.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "skips both tools on a -context.md note" {
  f=$(fixture "sweep-context.md")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "skips panache on a .md generated beside a .qmd" {
  fixture "vignette.qmd" >/dev/null
  f=$(fixture "vignette.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "skips panache on a .md generated beside a .Rmd" {
  fixture "readme.Rmd" >/dev/null
  f=$(fixture "readme.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "lints the stowed dotfiles config but leaves its layout alone" {
  f=$(fixture "dotfiles/claude/.claude/rules/shell.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "exempts a project .claude tree from prose-lint" {
  f=$(fixture "projet/.claude/PLAN.md")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "formats a project .claude note whose basename is not the exact skip glob" {
  f=$(fixture "projet/.claude/PLAN-LUA.md")

  run_hook "$f"

  assert_ran panache
  assert_not_ran prose-lint
}

@test "still runs prose-lint when panache is not installed" {
  remove_stub panache
  f=$(fixture "notes.md")

  run_hook "$f"

  assert_not_ran panache
  assert_ran prose-lint
}

@test "leaves non-markdown extensions to the other dispatch arms" {
  f=$(fixture "script.R")

  run_hook "$f"

  assert_ran air
  assert_ran jarl
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "no-ops on a payload carrying no file_path" {
  # realpath resolves the literal "null" against PWD, so the line-5 guard passes:
  # what rejects the payload is the extension dispatch, not the containment check.
  run_hook_raw '{"tool_input": {}}'

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}
