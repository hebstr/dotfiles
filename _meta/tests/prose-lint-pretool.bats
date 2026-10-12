#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

# Pins prose-lint-pretool.sh: which path classes reach prose-lint, what text it is
# handed, and the exit code and message of a block. Four traps drive the harness:
#   1. realpath -m resolves the payload path before the skip matching, so fixtures
#      must sit at real paths; the stowed-config discriminant needs a directory
#      shaped .../dotfiles/claude/.claude/..., and a project tree any other .claude/.
#   2. prose-lint is reached through PATH, so every test runs on a PATH holding the
#      stub dir alone: dropping a symlink from it is how "not installed" is exercised.
#      bash is among those symlinks because the real prose-lint opens on a
#      #!/usr/bin/env bash shebang: /usr/bin/env runs by absolute path, then resolves
#      that interpreter against this PATH.
#   3. The hook lints a mirror of the file under a temp root, so the stub records both
#      its argument and the text it was handed. The mirrored path carries the real one
#      verbatim, which is what keeps prose-lint's own path and basename skips working;
#      the tests that pin that run the real tool rather than the stub.
#   4. The blocking message goes to stderr, hence --separate-stderr throughout.
# What prose-lint does to the text belongs to prose-lint.bats, not here.

SCRIPT="${PROSE_LINT_PRETOOL_HOOK:-$BATS_TEST_DIRNAME/../../claude/.claude/hooks/prose-lint-pretool.sh}"
REAL_PROSE_LINT="$BATS_TEST_DIRNAME/../../bin/.local/bin/prose-lint"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  CAPTURE_DIR="$WORK/.capture"
  export WORK STUB_DIR CAPTURE_DIR

  mkdir -p "$STUB_DIR" "$CAPTURE_DIR"
  for cmd in awk bash cat dirname env jq mkdir mktemp python3 realpath rm; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
  stub_prose_lint
}

teardown() {
  rm -rf "$WORK"
}

# Records the argument and the mirrored text, then rejects an em dash the way the real
# tool does, with the exit code asked for (1 is prose-lint's violation code, 2 its CLI
# error code, and the hook blocks on either).
stub_prose_lint() {
  local code=${1:-1}
  cat >"$STUB_DIR/prose-lint" <<STUB
#!/bin/bash
printf '%s\n' "\$*" >>"$CAPTURE_DIR/args"
cat "\$1" >>"$CAPTURE_DIR/content"
[[ \$(cat "\$1") == *—* ]] || exit 0
printf '%s:3: [em-dash] em dash in prose\n' "\$1"
exit $code
STUB
  chmod +x "$STUB_DIR/prose-lint"
}

use_real_prose_lint() {
  ln -sf "$(realpath "$REAL_PROSE_LINT")" "$STUB_DIR/prose-lint"
}

fixture() {
  local rel=$1 content=${2-clean prose.}
  mkdir -p "$WORK/$(dirname "$rel")"
  printf '%s' "$content" >"$WORK/$rel"
  printf '%s' "$WORK/$rel"
}

# Not written to disk: the Write arm of the reconstruction never reads the file.
unwritten() {
  local rel=$1
  mkdir -p "$WORK/$(dirname "$rel")"
  printf '%s' "$WORK/$rel"
}

write_payload() {
  jq -nc --arg p "$1" --arg c "$2" '{tool_input: {file_path: $p, content: $c}}'
}

edit_payload() {
  jq -nc --arg p "$1" --arg o "$2" --arg n "$3" \
    '{tool_input: {file_path: $p, old_string: $o, new_string: $n}}'
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016 # intentional: $1/$2 expand inside the inner shell
  run --separate-stderr env PATH="$STUB_DIR" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

# The default content carries an em dash, so a path that reaches prose-lint blocks.
run_write() {
  run_hook "$(write_payload "$1" "${2-A line with an em dash — in it.}")"
}

assert_linted() {
  [ -s "$CAPTURE_DIR/args" ] || {
    echo "expected prose-lint to run; capture dir: $(ls -A "$CAPTURE_DIR" 2>/dev/null)" >&2
    return 1
  }
}

assert_not_linted() {
  [ ! -e "$CAPTURE_DIR/args" ] || {
    echo "expected prose-lint not to run; it was called with: $(cat "$CAPTURE_DIR/args")" >&2
    return 1
  }
}

assert_passed() {
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

assert_blocked() {
  [ "$status" -eq 2 ]
  [[ $stderr == *"prose-lint blocked write to $1:"* ]]
  [ "$output" = "" ]
}

# ─── payload guards ─────────────────────────────────────────────────────────

@test "no-ops on a payload carrying no file_path" {
  run_hook '{"tool_input": {}}'

  assert_passed
  assert_not_linted
}

@test "no-ops on a Bash payload, which carries no file_path" {
  run_hook '{"tool_name": "Bash", "tool_input": {"command": "ls"}}'

  assert_passed
  assert_not_linted
}

@test "forwards the three prose extensions to prose-lint" {
  for rel in notes.md report.qmd vignette.Rmd; do
    rm -f "$CAPTURE_DIR/args"
    f=$(fixture "$rel")

    run_write "$f"

    assert_linted || {
      printf 'not linted: %s\n' "$rel" >&2
      return 1
    }
  done
}

@test "leaves every other extension alone" {
  for rel in script.R mod.py theme.scss notes.txt notes.markdown README; do
    f=$(fixture "$rel")

    run_write "$f"

    assert_passed || {
      printf 'non-zero exit on: %s\n' "$rel" >&2
      return 1
    }
    assert_not_linted || {
      printf 'leaked on: %s\n' "$rel" >&2
      return 1
    }
  done
}

@test "no-ops when prose-lint is not installed" {
  rm -f "$STUB_DIR/prose-lint"
  f=$(fixture "notes.md")

  run_write "$f"

  assert_passed
}

@test "no-ops when python3 is not installed" {
  rm -f "$STUB_DIR/python3"
  f=$(fixture "notes.md")

  run_write "$f"

  assert_passed
  assert_not_linted
}

# ─── the .claude/ skip ──────────────────────────────────────────────────────

@test "exempts a project .claude note" {
  f=$(fixture "projet/.claude/PLAN.md")

  run_write "$f"

  assert_passed
  assert_not_linted
}

@test "exempts a project .claude design note whatever its kind" {
  for rel in projet/.claude/DESIGN-LUA.md projet/.claude/DESIGN-OPENCODE-HARNESS.md; do
    f=$(fixture "$rel")

    run_write "$f"

    assert_passed || {
      printf 'non-zero exit on: %s\n' "$rel" >&2
      return 1
    }
    assert_not_linted || {
      printf 'leaked on: %s\n' "$rel" >&2
      return 1
    }
  done
}

@test "exempts a nested project .claude note" {
  f=$(fixture "projet/pkg/.claude/notes/design.md")

  run_write "$f"

  assert_passed
  assert_not_linted
}

# dotfiles carries two .claude trees: its own project notes at the root, exempt like
# any project's, and the stowed global config under claude/, which stays linted.
@test "exempts the dotfiles project .claude tree" {
  f=$(fixture "dotfiles/.claude/DEFERRED.md")

  run_write "$f"

  assert_passed
  assert_not_linted
}

@test "exempts a -context.md wherever it sits" {
  for rel in sweep-context.md projet/docs/audit-context.md; do
    f=$(fixture "$rel")

    run_write "$f"

    assert_passed || {
      printf 'non-zero exit on: %s\n' "$rel" >&2
      return 1
    }
    assert_not_linted || {
      printf 'leaked on: %s\n' "$rel" >&2
      return 1
    }
  done
}

@test "lints the stowed global config" {
  for rel in dotfiles/claude/.claude/CLAUDE.md dotfiles/claude/.claude/rules/shell.md; do
    rm -f "$CAPTURE_DIR/args"
    f=$(fixture "$rel")

    run_write "$f"

    [ "$status" -eq 2 ] || {
      printf 'expected exit 2 on: %s, got %s\n' "$rel" "$status" >&2
      return 1
    }
    assert_linted || {
      printf 'not linted: %s\n' "$rel" >&2
      return 1
    }
  done
}

# The fake home sits one level deeper than the real one, so the link target carries
# ../.. where ~/.claude/CLAUDE.md carries a single ../ for the same shape.
@test "resolves a stow symlink onto the stowed branch" {
  fixture "dotfiles/claude/.claude/CLAUDE.md" >/dev/null
  mkdir -p "$WORK/home/.claude"
  ln -s ../../dotfiles/claude/.claude/CLAUDE.md "$WORK/home/.claude/CLAUDE.md"
  f="$WORK/home/.claude/CLAUDE.md"

  run_write "$f"

  assert_linted
  assert_blocked "$f"
}

# The stowed branch sits before the exempting one, so a -context.md or a memory file
# inside the stowed config is linted: prose-lint's own skips decide those, not the hook.
@test "the stowed branch wins over the -context.md and memory exemptions" {
  for rel in dotfiles/claude/.claude/skills/sweep/sweep-context.md \
    dotfiles/claude/.claude/memory/note.md; do
    rm -f "$CAPTURE_DIR/args"
    f=$(fixture "$rel")

    run_write "$f"

    assert_linted || {
      printf 'not linted: %s\n' "$rel" >&2
      return 1
    }
  done
}

@test "lints ordinary prose outside any .claude tree" {
  f=$(fixture "projet/README.md")

  run_write "$f"

  assert_linted
  assert_blocked "$f"
}

# ─── the temp mirror ────────────────────────────────────────────────────────

@test "hands prose-lint a mirror that carries the real path" {
  f=$(fixture "projet/README.md")

  run_write "$f"

  assert_linted
  arg=$(cat "$CAPTURE_DIR/args")
  [[ $arg == */"${f#/}" ]]
  [ "$arg" != "$f" ]
}

@test "the mirror keeps prose-lint's memory skip reachable" {
  use_real_prose_lint
  f=$(fixture "dotfiles/claude/.claude/memory/note.md")

  run_write "$f"

  assert_passed
}

@test "the mirror keeps prose-lint's basename skip reachable" {
  use_real_prose_lint
  f=$(fixture "projet/docs/PLAN.md")

  run_write "$f"

  assert_passed
}

@test "the mirror keeps prose-lint's extension skip reachable for an .Rmd" {
  use_real_prose_lint
  f=$(fixture "vignette.Rmd")

  run_write "$f"

  assert_passed
}

@test "blocks real prose that the real prose-lint rejects" {
  use_real_prose_lint
  f=$(fixture "projet/README.md")

  run_write "$f"

  assert_blocked "$f"
  [[ $stderr == *"[em-dash]"* ]]
}

@test "passes real prose that the real prose-lint accepts" {
  use_real_prose_lint
  f=$(fixture "projet/README.md")

  run_write "$f" "A line with no rhetorical dash in it."

  assert_passed
}

# ─── payload reconstruction ─────────────────────────────────────────────────

@test "lints the Write content rather than the file on disk" {
  f=$(fixture "notes.md" "what sits on disk")

  run_write "$f" "what the payload carries"

  [ "$(cat "$CAPTURE_DIR/content")" = "what the payload carries" ]
}

@test "lints a Write of a file that does not exist yet" {
  f=$(unwritten "fresh.md")

  run_write "$f" "brand new prose."

  assert_linted
  [ "$(cat "$CAPTURE_DIR/content")" = "brand new prose." ]
}

@test "replays an Edit against the file on disk, first occurrence only" {
  f=$(fixture "notes.md" "x x x")

  run_hook "$(edit_payload "$f" x y)"

  assert_linted
  [ "$(cat "$CAPTURE_DIR/content")" = "y x x" ]
}

@test "replays every occurrence of an Edit carrying replace_all" {
  f=$(fixture "notes.md" "x x x")
  payload=$(jq -nc --arg p "$f" \
    '{tool_input: {file_path: $p, old_string: "x", new_string: "y", replace_all: true}}')

  run_hook "$payload"

  assert_linted
  [ "$(cat "$CAPTURE_DIR/content")" = "y y y" ]
}

@test "lints the file unchanged when an Edit old_string matches nothing" {
  f=$(fixture "notes.md" "clean prose on disk.")

  run_hook "$(edit_payload "$f" absent replacement)"

  assert_linted
  [ "$(cat "$CAPTURE_DIR/content")" = "clean prose on disk." ]
}

@test "no-ops on an Edit of a file that is not on disk" {
  f=$(unwritten "ghost.md")

  run_hook "$(edit_payload "$f" old new)"

  assert_passed
  assert_not_linted
}

@test "no-ops on an Edit payload missing new_string" {
  f=$(fixture "notes.md")
  payload=$(jq -nc --arg p "$f" '{tool_input: {file_path: $p, old_string: "old"}}')

  run_hook "$payload"

  assert_passed
  assert_not_linted
}

@test "no-ops on a Write carrying empty content" {
  f=$(fixture "notes.md")

  run_write "$f" ""

  assert_passed
  assert_not_linted
}

@test "no-ops when an Edit reconstructs to an empty file" {
  f=$(fixture "notes.md" "the whole body")

  run_hook "$(edit_payload "$f" "the whole body" "")"

  assert_passed
  assert_not_linted
}

# ─── the blocking contract ──────────────────────────────────────────────────

@test "names the real path in the blocking message, never the mirror" {
  f=$(fixture "projet/README.md")

  run_write "$f"

  assert_blocked "$f"
  # Anchored: the mirror's own path ends with the real one, so an unsubstituted
  # report would satisfy any unanchored match on it.
  grep -qxF -- "$f:3: [em-dash] em dash in prose" <<<"$stderr"
  [ "$(grep -cF -- "$f" <<<"$stderr")" -eq 2 ]
}

@test "blocks on any non-zero prose-lint verdict, not just its violation code" {
  stub_prose_lint 2
  f=$(fixture "projet/README.md")

  run_write "$f"

  assert_blocked "$f"
}

@test "removes the temp mirror on the way out of a block" {
  f=$(fixture "projet/README.md")

  run_write "$f"

  assert_blocked "$f"
  mirror=$(cat "$CAPTURE_DIR/args")
  [ ! -e "$mirror" ]
  [ ! -e "${mirror%%/"${f#/}"}" ]
}
