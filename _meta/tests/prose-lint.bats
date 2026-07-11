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

@test "em dash inside single-line display math: exit 0" {
  local f
  f=$(_fixture math-oneline.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    '$$a — b$$' \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash inside multi-line display math block: exit 0" {
  local f
  f=$(_fixture math-block.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    '$$' \
    "x — y" \
    '$$' \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "prose-lint:ignore marker suppresses em dash flag: exit 0" {
  local f
  f=$(_fixture marker-em.md "This has an em dash — really. <!-- prose-lint:ignore -->")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: short line after blank: exit 0" {
  local f
  f=$(_fixture short-para.md "$(printf '%s\n' \
    "First paragraph." \
    "" \
    "Short.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: short bullet: exit 0" {
  local f
  f=$(_fixture bullet.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    "- short bullet" \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: short heading: exit 0" {
  local f
  f=$(_fixture heading.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    "# H1" \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash in table row: exit 0" {
  local f
  f=$(_fixture table-em.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    "| flag | meaning |" \
    "| --- | --- |" \
    "| /foo | does foo — really |" \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "em dash in markdown header: exit 0" {
  local f
  f=$(_fixture header-em.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    "### Section — Subtitle" \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "en dash in alphanumeric range: exit 0" {
  local f
  f=$(_fixture range-en.md "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    "- See pages 12–18 and version v2.1–v2.2 for details." \
    "" \
    "Outro paragraph here, also longer than sixty chars to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: YAML frontmatter fields: exit 0" {
  local f
  f=$(_fixture frontmatter.md "$(printf '%s\n' \
    "---" \
    "name: short-slug" \
    "description: A longer description that is well over sixty characters to avoid flagging." \
    "type: feedback" \
    "---" \
    "" \
    "Body content here that is longer than sixty characters to stay quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: Quarto fenced div markers: exit 0" {
  local f
  f=$(_fixture fenced-div.qmd "$(printf '%s\n' \
    "---" \
    "title: test" \
    "---" \
    "" \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "" \
    ":::: {.columns}" \
    "::: {.column width=\"50%\"}" \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    ":::" \
    "::: {.column width=\"50%\"}" \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    ":::" \
    "::::")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: Quarto fragment div between content lines: exit 0" {
  local f
  f=$(_fixture fragment-div.qmd "$(printf '%s\n' \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    "::: {.fragment}" \
    "Outro paragraph here, also longer than sixty chars to stay quiet." \
    ":::" \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "soft-wrap exception: nested Quarto divs (column + fragment): exit 0" {
  local f
  f=$(_fixture nested-div.qmd "$(printf '%s\n' \
    "::: {.column width=\"50%\"}" \
    "::: {.fragment}" \
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    ":::" \
    ":::")")
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
    "Intro paragraph here, longer than sixty chars to avoid soft-wrap flag." \
    '$$' \
    "x + y" \
    '$$' \
    "Closing prose with an em dash — must still be flagged after math.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "soft wrap: short line sandwiched: flag soft-wrap, exit 1" {
  local f
  f=$(_fixture wrap.md "$(printf '%s\n' \
    "First paragraph line longer than sixty chars to avoid flag itself." \
    "Short wrap" \
    "Third paragraph line longer than sixty chars to keep things quiet.")")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[soft-wrap]"* ]]
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

@test ".claude/memory file: skipped despite em dash, exit 0" {
  local dir f
  dir="${BATS_TEST_TMPDIR}/.claude/memory"
  mkdir -p "$dir"
  f="${dir}/mem.md"
  printf '%s' "This memory has an em dash — and stays unflagged." >"$f"
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
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

@test "working/backlog basenames: skipped despite em dash, exit 0" {
  local name f
  for name in PLAN.md DEFERRED.md CONTEXT.md MEMORY.md TODO.md; do
    f=$(_fixture "$name" "Has an em dash — and stays unflagged.")
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

@test "basename exclusion is case-sensitive: context.md still checked, exit 1" {
  local f
  f=$(_fixture context.md "Skill doc with an em dash — gets flagged.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

@test "unrelated basename: not excluded, em dash flagged, exit 1" {
  local f
  f=$(_fixture NOTES.md "Generic doc with an em dash — gets flagged.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[em-dash]"* ]]
}

# ─── smoke ──────────────────────────────────────────────────────────────────

@test "smoke: real README.md is clean" {
  run "$SCRIPT" "${BATS_TEST_DIRNAME}/../../README.md"
  [ "$status" -eq 0 ]
}
