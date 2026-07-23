#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

# Pins format-on-edit.sh's routing: which command each path class invokes and with
# which flags, never what that command does to the file. Two traps drive the harness:
#   1. $PWD is load-bearing. The hook's `[[ "$REAL" == "$PWD"/* ]] || exit 0` guard
#      gates everything, so run_hook sets the working directory per test.
#   2. realpath resolves the path before matching, so fixtures must be real files at
#      real paths; the stowed-config discriminant needs a dir shaped .../dotfiles/claude/.claude/... .
# The .py arm is grouped `{ ruff check --fix; ruff format; }`, not `check && format`, so
# `ruff format` runs even when check exits non-zero on unfixable violations; one test pins that.

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
  make_stub ruff
  make_stub shellharden
  make_stub shfmt
  make_stub shellcheck
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

@test "skips panache and prose-lint on a project .claude/memory file" {
  f=$(fixture "projet/.claude/memory/note.md")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "skips panache but lints a dotfiles .claude/memory file" {
  f=$(fixture "dotfiles/claude/.claude/memory/note.md")

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

@test "formats and lints an uppercase .R with the air/jarl arm" {
  f=$(fixture "script.R")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_ran air
  assert_ran jarl
  assert_not_ran panache
  assert_not_ran prose-lint
}

@test "formats and lints a lowercase .r with the air/jarl arm" {
  f=$(fixture "script.r")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_ran air
  assert_ran jarl
}

@test "formats and lints a .py with the ruff arm in order" {
  f=$(fixture "mod.py")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_ran ruff
  [[ $(cat "$CAPTURE_DIR/ruff") == *"check --fix $f"* ]]
  [[ $(cat "$CAPTURE_DIR/ruff") == *"format $f"* ]]
  assert_not_ran air
}

@test "formats and lints a .ipynb with the ruff arm" {
  f=$(fixture "nb.ipynb")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_ran ruff
}

@test "still formats a .py when ruff check exits non-zero on unfixable violations" {
  cat >"$STUB_DIR/ruff" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$CAPTURE_DIR/ruff"
[ "\$1" = check ] && exit 1
exit 0
STUB
  chmod +x "$STUB_DIR/ruff"
  f=$(fixture "mod.py")

  run_hook "$f"

  assert_ran ruff
  [[ $(cat "$CAPTURE_DIR/ruff") == *"format $f"* ]]
}

@test "formats and lints a .sh with the shellharden/shfmt/shellcheck arm" {
  f=$(fixture "tool.sh")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_ran shellharden
  assert_ran shfmt
  assert_ran shellcheck
  [[ $(cat "$CAPTURE_DIR/shfmt") == "-w -i 2 $f" ]]
}

@test "formats and lints a .bash with the shellharden/shfmt/shellcheck arm" {
  f=$(fixture "tool.bash")

  run_hook "$f"

  [ "$status" -eq 0 ]
  assert_ran shellharden
  assert_ran shfmt
  assert_ran shellcheck
}

@test "no-ops on a payload carrying no file_path" {
  # realpath resolves the literal "null" against PWD, so the line-5 guard passes:
  # what rejects the payload is the extension dispatch, not the containment check.
  run_hook_raw '{"tool_input": {}}'

  [ "$status" -eq 0 ]
  assert_not_ran panache
  assert_not_ran prose-lint
}
