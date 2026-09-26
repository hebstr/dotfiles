#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/instructions-budget"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  BASE="$WORK/claude/.claude"
  export WORK BASE

  mkdir -p "$BASE/rules" "$BASE/hooks" "$BASE/memory"
  head -c 1000 /dev/zero | tr '\0' 'a' >"$BASE/CLAUDE.md"
  printf -- '---\npaths:\n  - "**/*.py"\n---\n\nscoped\n' >"$BASE/rules/python.md"
  printf 'want pdf\nwant showboat install\n' >"$BASE/hooks/inject-rules.sh"
  printf -- '---\npaths:\n  - "**/*.pdf"\n---\n\npdf rules\n' >"$BASE/rules/pdf.md"
  printf '# Memory Index\n' >"$BASE/memory/MEMORY.md"
}

teardown() {
  rm -rf "$WORK"
}

@test "passes when CLAUDE.md alone fits the budget" {
  run "$SCRIPT" --budget 1024 --root "$WORK"
  [ "$status" -eq 0 ]
  [[ $output == *'memory index: 15 bytes, not counted'* ]]
}

@test "fails above the budget and names the totals" {
  run "$SCRIPT" --budget 999 --root "$WORK"
  [ "$status" -eq 1 ]
  [[ $output == *'always-loaded instructions: 1000 bytes, budget 999 (CLAUDE.md 1000, unscoped rules: none)'* ]]
  [[ $output == *'DESIGN-INSTRUCTION-ROUTING.md'* ]]
}

@test "counts a rules file without paths frontmatter" {
  printf 'no frontmatter\n' >"$BASE/rules/loose.md"
  run "$SCRIPT" --budget 1010 --root "$WORK"
  [ "$status" -eq 1 ]
  [[ $output == *'unscoped rules: loose.md 15'* ]]
}

@test "counts a frontmatter without paths, or one never closed" {
  printf -- '---\ndescription: x\n---\n\nbody\n' >"$BASE/rules/nopaths.md"
  printf -- '---\npaths:\n  - "x"\n' >"$BASE/rules/unclosed.md"
  run "$SCRIPT" --budget 1020 --root "$WORK"
  [ "$status" -eq 1 ]
  [[ $output == *nopaths.md* ]]
  [[ $output == *unclosed.md* ]]
}

@test "does not count a scoped rules file" {
  head -c 50000 /dev/zero | tr '\0' 'b' >>"$BASE/rules/python.md"
  run "$SCRIPT" --budget 1024 --root "$WORK"
  [ "$status" -eq 0 ]
}

@test "fails when a file the hook injects exceeds the cap" {
  head -c 200 /dev/zero | tr '\0' 'c' >>"$BASE/rules/pdf.md"
  run "$SCRIPT" --budget 1024 --cap 100 --root "$WORK"
  [ "$status" -eq 1 ]
  [[ $output == *'injected rules file rules/pdf.md'*'cap 100'* ]]
}

@test "counts characters, not bytes, against the cap" {
  printf -- '---\npaths:\n  - "x"\n---\n' >"$BASE/rules/install.md"
  for _ in $(seq 40); do printf 'é' >>"$BASE/rules/install.md"; done
  run env LC_ALL=C "$SCRIPT" --budget 1024 --cap 70 --root "$WORK"
  [ "$status" -eq 0 ]
}

@test "does not count the memory index" {
  head -c 50000 /dev/zero | tr '\0' 'd' >>"$BASE/memory/MEMORY.md"
  run "$SCRIPT" --budget 1024 --root "$WORK"
  [ "$status" -eq 0 ]
}

@test "rejects a missing or malformed budget" {
  run "$SCRIPT" --root "$WORK"
  [ "$status" -eq 2 ]
  run "$SCRIPT" --budget ten --root "$WORK"
  [ "$status" -eq 2 ]
}
