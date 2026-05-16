#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
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

@test "ritual opener inside inline backtick: exit 0" {
  local f
  f=$(_fixture quoted-ritual.md "Avoid \`Notably,\` in prose.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 0 ]
}

@test "prose-lint:ignore marker suppresses ritual opener flag: exit 0" {
  local f
  f=$(_fixture marker.md "Notably, this would flag. <!-- prose-lint:ignore -->")
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

@test "ritual opener EN (Notably): flag ritual, exit 1" {
  local f
  f=$(_fixture ritual-en.md "Notably, this triggers the rule.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[ritual]"* ]]
}

@test "ritual opener FR (Force est de constater): flag ritual, exit 1" {
  local f
  f=$(_fixture ritual-fr.md "Force est de constater que cela déclenche.")
  run "$SCRIPT" "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[ritual]"* ]]
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

# ─── smoke ──────────────────────────────────────────────────────────────────

@test "smoke: real CLAUDE.md is clean" {
  run "$SCRIPT" "${BATS_TEST_DIRNAME}/../../claude/.claude/CLAUDE.md"
  [ "$status" -eq 0 ]
}
