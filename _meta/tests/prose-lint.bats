#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/prose-lint

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/prose-lint"

_fixture() {
  local name=$1 content=$2
  local path="${BATS_TEST_TMPDIR}/${name}"
  printf '%s' "$content" >"$path"
  printf '%s' "$path"
}

# ─── exit 0: clean inputs ───────────────────────────────────────────────────

@test "empty file: exit 0" {
  local f
  f=$(_fixture clean.md "")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "em dash inside inline backtick: exit 0" {
  local f
  f=$(_fixture meta.md "Use \`—\` for ranges? No.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash inside fenced code block: exit 0" {
  local f
  f=$(_fixture fenced.md "$(printf '%s\n' \
    "Some prose." \
    '```' \
    "code with — em dash" \
    '```' \
    "more prose.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash inside shorter fence nested in a longer one: exit 0" {
  local f
  f=$(_fixture nested-fence.md "$(printf '%s\n' \
    "Some prose." \
    '````markdown' \
    '```r' \
    "x <- 'a — b'" \
    '```' \
    '````' \
    "more prose.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash inside fence indented under a list item: exit 0" {
  local f
  f=$(_fixture indented-fence.md "$(printf '%s\n' \
    "- item" \
    "" \
    '  ```bash' \
    '  echo "a — b"' \
    '  ```' \
    "" \
    "more prose.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash inside single-line display math: exit 0" {
  local f
  f=$(_fixture math-oneline.md "$(printf '%s\n' \
    "Intro paragraph for context." \
    "" \
    '$$a — b$$' \
    "" \
    "Outro paragraph for context.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash inside multi-line display math block: exit 0" {
  local f
  f=$(_fixture math-block.md "$(printf '%s\n' \
    "Intro paragraph for context." \
    "" \
    '$$' \
    "x — y" \
    '$$' \
    "" \
    "Outro paragraph for context.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "prose-lint:ignore marker suppresses em dash flag: exit 0" {
  local f
  f=$(_fixture marker-em.md "This has an em dash — really. <!-- prose-lint:ignore -->")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash in table row: exit 0" {
  local f
  f=$(_fixture table-em.md "$(printf '%s\n' \
    "Intro paragraph for context." \
    "" \
    "| flag | meaning |" \
    "| --- | --- |" \
    "| /foo | does foo — really |" \
    "" \
    "Outro paragraph for context.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash in markdown header: exit 0" {
  local f
  f=$(_fixture header-em.md "$(printf '%s\n' \
    "Intro paragraph for context." \
    "" \
    "### Section — Subtitle" \
    "" \
    "Outro paragraph for context.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "en dash in alphanumeric range: exit 0" {
  local f
  f=$(_fixture range-en.md "$(printf '%s\n' \
    "Intro paragraph for context." \
    "" \
    "- See pages 12–18 and version v2.1–v2.2 for details." \
    "" \
    "Outro paragraph for context.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

# ─── exit 1: violations ─────────────────────────────────────────────────────

@test "em dash in prose: flag em-dash, exit 1" {
  local f
  f=$(_fixture em.md "This is — bad prose.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "en dash outside code: flag en-dash, exit 1" {
  local f
  f=$(_fixture en.md "Steps – with en dash.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[en-dash]"* ]]
}

@test "em dash in inline single-dollar math: flagged as prose, exit 1" {
  local f
  f=$(_fixture math-dollar.md "Inline math like \$a — b\$ stays flagged as prose.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "em dash after closed display math block: flagged, exit 1" {
  local f
  f=$(_fixture math-resume.md "$(printf '%s\n' \
    "Intro paragraph for context." \
    '$$' \
    "x + y" \
    '$$' \
    "Closing prose with an em dash — must still be flagged after math.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "em dash after longer fence holding an unpaired shorter one: flagged, exit 1" {
  local f
  f=$(_fixture nested-fence-resume.md "$(printf '%s\n' \
    "Some prose." \
    '````markdown' \
    '```' \
    "code" \
    '````' \
    "Closing prose with an em dash — must still be flagged.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "em dash after math block closed at end of a content line: flagged, exit 1" {
  local f
  f=$(_fixture math-inline-close.md "$(printf '%s\n' \
    '$$' \
    "a = b" \
    'c = d $$' \
    "" \
    "Closing prose with an em dash — must still be flagged after math.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "multi-file: 1 clean + 1 violation: exit 1, only violation reported" {
  local clean dirty
  clean=$(_fixture clean.md "")
  dirty=$(_fixture dirty.md "Bad — prose.")
  run "$SCRIPT" "$clean" "$dirty"
  [ "$status" -eq 1 ]
  [[ "$output" == *"dirty.md"* ]]
  [[ "$output" != *"clean.md"* ]]
}

# ─── exit 2: CLI errors ─────────────────────────────────────────────────────

@test "no args: exit 2 with usage" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

@test "non-existent file: exit 2" {
  run "$SCRIPT" "${BATS_TEST_TMPDIR}/does-not-exist.md"
  [ "$status" -eq 2 ]
}

@test "unreadable file: exit 2, not a silent pass" {
  local f
  f=$(_fixture unreadable.md "Bad — prose.")
  chmod 000 "$f"
  run "$SCRIPT" "$f"
  chmod 644 "$f"
  [ "$status" -eq 2 ]
}

@test "non-md file: exit 0, skip with stderr message" {
  local f
  f=$(_fixture not-md.txt "Bad — prose, but .txt is skipped.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test ".qmd file: accepted (not skipped), exit 0" {
  local f
  f=$(_fixture clean.qmd "")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" != *"skipping"* ]]
}

@test ".claude/memory file: em dash unflagged, exit 0" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude/memory"
  mkdir -p "$dir"
  f="${dir}/mem.md"
  printf '%s' "This memory has an em dash — and stays unflagged." >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[em-dash]"* ]]
}

@test ".claude non-memory file: still checked, em dash flagged, exit 1" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/CLAUDE.md"
  printf '%s' "This rule has an em dash — and gets flagged." >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "working/backlog basenames: em dash unflagged, exit 0" {
  local name f
  for name in PLAN.md DEFERRED.md CONTEXT.md MEMORY.md TODO.md CALENDRIER.md; do
    f=$(_fixture "$name" "Has an em dash — and stays unflagged.")
    run "$SCRIPT" "$f"
    [ "$status" -eq 0 ] || {
      echo "expected exit 0 for $name, got $status" >&2
      return 1
    }
    [[ "$output" != *"[em-dash]"* ]] || {
      echo "expected no em-dash flag for $name" >&2
      return 1
    }
  done
}

@test "the user's scratchpads are in no rule's scope: skipped whole, exit 0" {
  local name f
  for name in TODO.md CALENDRIER.md; do
    f=$(_fixture "$name" "The repository has 42 tests and an em dash — too.")
    run "$SCRIPT" "$f"
    [ "$status" -eq 0 ] || {
      echo "expected exit 0 for $name, got $status" >&2
      return 1
    }
    [[ "$output" == *"skipping"* ]] || {
      echo "expected skip message for $name" >&2
      return 1
    }
  done
}

# ─── [live-count] ───────────────────────────────────────────────────────────

@test "live count in a .claude note: flagged, exit 1" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  printf '%s' "The suite has 42 tests." >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[live-count]"* ]]
}

@test "live count in every other agent-facing shape: flagged, exit 1" {
  local rel f
  for rel in .claude/memory/mem.md _meta/notes/x-reco.md CLAUDE.md AGENTS.md \
    PLAN.md DEFERRED.md CONTEXT.md MEMORY.md; do
    mkdir -p "${BATS_TEST_TMPDIR}/$(dirname "$rel")"
    f="${BATS_TEST_TMPDIR}/${rel}"
    printf '%s' "The corpus carries 1,105 lines." >"$f"
    run "$SCRIPT" "$f"
    [ "$status" -eq 1 ] || {
      echo "expected exit 1 for $rel, got $status" >&2
      return 1
    }
    [[ "$output" == *"[live-count]"* ]] || {
      echo "expected a live-count flag for $rel" >&2
      return 1
    }
  done
}

@test "live count in user-facing prose: not in scope, exit 0" {
  local f
  f=$(_fixture README.md "The repository has 42 tests.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "an ISO date on the line exempts the count: exit 0" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  printf '%s' "Measured 2026-11-06: the suite has 42 tests." >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "the ignore marker exempts the count: exit 0" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  printf '%s' "The suite has 42 tests. <!-- prose-lint:ignore -->" >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "shapes outside the pattern: exit 0" {
  local dir f line
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  for line in "The suite had 42 tests." \
    "The suite was 42 tests." \
    "The suite has 42 patients." \
    "The suite has about 42 tests." \
    "The suite is at 42 tests." \
    "The suite has forty-two tests." \
    "30 files, 786 tests." \
    "The suite has 42 \`tests\`."; do
    printf '%s' "$line" >"$f"
    run "$SCRIPT" "$f"
    [ "$status" -eq 0 ] || {
      echo "expected exit 0 on: $line" >&2
      return 1
    }
  done
}

@test "a count in a fenced block or in display math: exit 0" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  printf '%s\n' '```' 'The suite has 42 tests.' '```' '$$' 'x has 42 lines' '$$' >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "a count in a table row or a header: flagged, exit 1" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  printf '%s\n' '| the suite has 42 tests | x |' >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[live-count]"* ]]
  printf '%s\n' '## The suite has 42 tests' >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
}

@test "a thousands separator in the number: flagged, exit 1" {
  local dir f sep
  dir="${BATS_TEST_TMPDIR}/.claude"
  mkdir -p "$dir"
  f="${dir}/DESIGN-X.md"
  for sep in "251,906" "251.906" "251 906" $'251\302\240906'; do
    printf '%s' "The plan is $sep bytes." >"$f"
    run "$SCRIPT" "$f"
    [ "$status" -eq 1 ] || {
      echo "expected exit 1 on separator: $sep" >&2
      return 1
    }
  done
}

@test "basename exclusion is case-sensitive: context.md still checked, exit 1" {
  local f
  f=$(_fixture context.md "Skill doc with an em dash — gets flagged.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "unrelated basename: not excluded, em dash flagged, exit 1" {
  local f
  f=$(_fixture GUIDE.md "Generic doc with an em dash — gets flagged.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

# ─── smoke ──────────────────────────────────────────────────────────────────

@test "smoke: real _meta/notes/dotfiles-bootstrap.md is clean" {
  run "$SCRIPT" "${BATS_TEST_DIRNAME}/../notes/dotfiles-bootstrap.md"
  [ "$status" -eq 0 ]
}
