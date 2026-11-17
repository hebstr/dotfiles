#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

# Pins board.R of the diagram skill: which invocations it refuses before any
# render, and what a real run leaves in the output folder. Three traps drive
# the harness:
#   1. the refusals fire before hebstr is loaded, so those tests need neither
#      Node nor a browser and run everywhere; the ones that refuse for another
#      reason than the folder pass an output path outside /tmp, the one folder
#      the script refuses, and none of the refusals may leave a folder behind;
#   2. the real run goes through easy_out(), whose PNG capture launches the snap
#      Chromium, which cannot read /tmp: its output folder is made under $HOME
#      and removed in teardown, while the candidate files, which only R reads,
#      stay in BATS_TEST_TMPDIR;
#   3. the user library of this machine can hold a hebstr older than the
#      diagram feature, while a project's rv library holds the real one: the
#      real-run tests run from DIAGRAM_BOARD_PROJECT when it is set and skip
#      when the hebstr they reach cannot render a diagram.

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/skills/diagram/scripts/board.R"

setup() {
  OUT="$BATS_TEST_DIRNAME/diagram-board-refused"
  A="$BATS_TEST_TMPDIR/a.mmd"
  B="$BATS_TEST_TMPDIR/b.mmd"
  printf 'flowchart TD\n  A["Alpha"] --> B["Beta"]\n' >"$A"
  printf 'flowchart TD\n  C["Gamma"] --> D["Delta"]\n' >"$B"
  export OUT A B
}

teardown() {
  rm -rf "${REAL_OUT-}"
}

board() {
  Rscript "$SCRIPT" "$@"
}

real_run_ready() {
  command -v node >/dev/null || skip "node is not installed"
  [ "$(node --version | sed 's/^v\([0-9]*\).*/\1/')" -ge 20 ] || skip "node is older than 20"
  cd "${DIAGRAM_BOARD_PROJECT:-.}" || return 1
  Rscript -e 'quit(status = !(requireNamespace("hebstr", quietly = TRUE) && exists(".dark_surface", envir = asNamespace("hebstr")) && "easy_diagram" %in% getNamespaceExports("hebstr")))' ||
    skip "no hebstr with diagram support from here: set DIAGRAM_BOARD_PROJECT to a project root whose library has one"
  command -v chromium >/dev/null || skip "chromium is not installed"
}

@test "no --out: usage, exit 2" {
  run -2 board "$A"
  [[ "$output" == *"usage: board.R"* ]]
}

@test "no candidate: exit 2" {
  run -2 board --out "$OUT"
  [[ "$output" == *"no candidate file"* ]]
  [ ! -e "$OUT" ]
}

@test "an unknown option: exit 2" {
  run -2 board --out "$OUT" --bogus "$A"
  [[ "$output" == *"unknown option --bogus"* ]]
}

@test "an option without its value: exit 2" {
  run -2 board "$A" --out
  [[ "$output" == *"--out needs a value"* ]]
}

@test "an output folder under /tmp: exit 3, nothing written" {
  run -3 board --out /tmp/diagram-board-refused/deep/er "$A"
  [[ "$output" == *"is under /tmp"* ]]
  [ ! -e /tmp/diagram-board-refused ]
}

@test "a relative output folder resolving under /tmp: exit 3" {
  cd "$BATS_TEST_TMPDIR"
  run -3 board --out board "$A"
  [[ "$output" == *"is under /tmp"* ]]
  [ ! -e "$BATS_TEST_TMPDIR/board" ]
}

@test "a missing candidate: exit 2, named" {
  run -2 board --out "$OUT" "$A" "$BATS_TEST_TMPDIR/nope.mmd"
  [[ "$output" == *"candidate not found: $BATS_TEST_TMPDIR/nope.mmd"* ]]
  [ ! -e "$OUT" ]
}

@test "a missing setup file: exit 2" {
  run -2 board --out "$OUT" --setup "$BATS_TEST_TMPDIR/nope.R" "$A"
  [[ "$output" == *"setup file not found"* ]]
}

@test "two candidates with one stem: exit 2" {
  mkdir "$BATS_TEST_TMPDIR/other"
  cp "$B" "$BATS_TEST_TMPDIR/other/a.mmd"
  run -2 board --out "$OUT" "$A" "$BATS_TEST_TMPDIR/other/a.mmd"
  [[ "$output" == *"two candidates share the name a"* ]]
  [ ! -e "$OUT" ]
}

@test "a real run writes one light and one dark SVG per candidate and a board naming both" {
  real_run_ready
  REAL_OUT=$(mktemp -d "$HOME/diagram-board-test.XXXXXX")
  run -0 board --out "$REAL_OUT" "$A" "$B"
  [ "${lines[-1]}" = "$REAL_OUT/board.html" ]
  for stem in a b; do
    [ -s "$REAL_OUT/$stem/$stem-light.svg" ]
    [ -s "$REAL_OUT/$stem/$stem-dark.svg" ]
    grep -q "<img src=\"$stem/$stem-light.svg\">" "$REAL_OUT/board.html"
    grep -q "<img src=\"$stem/$stem-dark.svg\">" "$REAL_OUT/board.html"
  done
}

@test "the dark column carries the dark surface hebstr uses" {
  real_run_ready
  REAL_OUT=$(mktemp -d "$HOME/diagram-board-test.XXXXXX")
  surface=$(Rscript -e 'cat(get(".dark_surface", envir = asNamespace("hebstr")))')
  run -0 board --out "$REAL_OUT" "$A"
  grep -q "td.dark { background: $surface; }" "$REAL_OUT/board.html"
}

@test "a setup file is sourced before the render" {
  real_run_ready
  REAL_OUT=$(mktemp -d "$HOME/diagram-board-test.XXXXXX")
  printf 'writeLines("setup-ran", file.path("%s", "marker"))\n' "$REAL_OUT" >"$BATS_TEST_TMPDIR/setup.R"
  run -0 board --out "$REAL_OUT" --setup "$BATS_TEST_TMPDIR/setup.R" "$A"
  [ "$(cat "$REAL_OUT/marker")" = "setup-ran" ]
}
