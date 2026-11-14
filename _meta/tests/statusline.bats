#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for claude/.claude/statusline.sh

bats_require_minimum_version 1.5.0

# Pins which payload value lands in which segment, and what a segment shows when its
# rate-limit window is missing. Three traps drive the harness:
#   1. $HOME is load-bearing. The script caches rate_limits under $HOME/.cache, so every
#      test redirects HOME into $WORK or a stale cache from the real home leaks in.
#   2. The output carries SGR escapes; _run strips them so assertions read the text.
#   3. resets_at is computed relative to the test run, never a fixed literal: a hardcoded
#      epoch would drift into the past and silently drop the countdown it asserts on.
# The five_hour key is absent, not null, in the payload the CLI emits when no 5h window
# exists; both shapes get a test because jq's `// null` cannot tell them apart.

SCRIPT="${STATUSLINE_SCRIPT:-$BATS_TEST_DIRNAME/../../claude/.claude/statusline.sh}"
CACHE_REL=".cache/claude-statusline/last.json"

setup() {
  WORK=$(mktemp -d)
  HOME="$WORK/home"
  export WORK HOME
  mkdir -p "$HOME"
}

teardown() {
  rm -rf "$WORK"
}

_run() {
  printf '%s' "$1" | bash "$SCRIPT" | sed 's/\x1b\[[0-9;]*m//g'
}

_run_raw() {
  printf '%s' "$1" | bash "$SCRIPT"
}

_in_hours() {
  printf '%s\n' "$(($(date +%s) + $1 * 3600 + 90))"
}

_payload() {
  printf '{"context_window":{"current_usage":{"input_tokens":30000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000,"used_percentage":15}%s}' \
    "${1:+,\"rate_limits\":$1}"
}

_seed_cache() {
  mkdir -p "$(dirname "$HOME/$CACHE_REL")"
  printf '%s' "$1" >"$HOME/$CACHE_REL"
}

@test "maps each window to its own percentage when both are present" {
  run _run "$(_payload "{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours 2)},\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Context 15%"* ]]
  [[ "$output" == *"5h: 4%"* ]]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "takes the context percentage the payload reports instead of recomputing it" {
  run _run '{"context_window":{"current_usage":{"input_tokens":139200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000,"used_percentage":70}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Context 70%"* ]]
}

@test "reports no context percentage when the payload carries none" {
  run _run '{"context_window":{"current_usage":{"input_tokens":139200,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000,"used_percentage":null}}'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Context 0%"* ]]
}

@test "keeps the seven-day percentage when the five-hour key is absent" {
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "leaks no epoch into the seven-day segment when the five-hour key is absent" {
  reset_at=$(_in_hours 50)
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$reset_at}}")"
  [ "$status" -eq 0 ]
  run ! grep -q "$reset_at" <<<"$output"
}

@test "keeps the seven-day percentage when the five-hour percentage is null" {
  run _run "$(_payload "{\"five_hour\":{\"used_percentage\":null,\"resets_at\":null},\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "reads a plain ISO 8601 resets_at as a countdown" {
  iso=$(date -u -d "@$(_in_hours 2)" +%Y-%m-%dT%H:%M:%SZ)
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":\"$iso\"}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 12% (2h1m)"* ]]
}

@test "keeps the percentage and shows no countdown for an ISO resets_at it cannot parse" {
  iso=$(date -u -d "@$(_in_hours 2)" +%Y-%m-%dT%H:%M:%S.123Z)
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":\"$iso\"}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 12%"* ]]
  run ! grep -q '(' <<<"$output"
}

@test "shows the five-hour window alone when the seven-day key is absent" {
  run _run "$(_payload "{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours 2)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: 4%"* ]]
  [[ "$output" == *"7d: --"* ]]
}

@test "counts down to each window's reset" {
  run _run "$(_payload "{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours 2)},\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(2h1m)"* ]]
  [[ "$output" == *"(2d2h)"* ]]
}

@test "shows a percentage without a countdown when resets_at is missing" {
  run _run "$(_payload '{"five_hour":{"used_percentage":4},"seven_day":{"used_percentage":12}}')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: 4%"* ]]
  [[ "$output" == *"7d: 12%"* ]]
  run ! grep -q '(' <<<"$output"
}

@test "drops a countdown whose reset has already passed" {
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours -3)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 12%"* ]]
  run ! grep -q '(' <<<"$output"
}

@test "shows both windows as unavailable when rate_limits is absent and no cache exists" {
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: --"* ]]
}

@test "serves both windows from a fresh cache when the live payload omits rate_limits" {
  _seed_cache "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours 2)},\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}}"
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: 4%"* ]]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "serves a cache that is still inside the retention window" {
  _seed_cache "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours 2)}}}"
  touch -d '5 hours ago' "$HOME/$CACHE_REL"
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: 4%"* ]]
}

@test "ignores a cache older than the retention window" {
  _seed_cache '{"rate_limits":{"five_hour":{"used_percentage":4},"seven_day":{"used_percentage":12}}}'
  touch -d '12 hours ago' "$HOME/$CACHE_REL"
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: --"* ]]
}

@test "ignores a cached window whose reset has already passed" {
  _seed_cache "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours -1)},\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}}"
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "keeps a cached window that reports no reset at all" {
  _seed_cache '{"rate_limits":{"seven_day":{"used_percentage":12}}}'
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "ignores a cache this run cannot parse" {
  _seed_cache 'not json at all'
  run _run "$(_payload "")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: --"* ]]
}

@test "prefers a live window over the cached one of the same name" {
  _seed_cache '{"rate_limits":{"five_hour":{"used_percentage":99},"seven_day":{"used_percentage":99}}}'
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 12%"* ]]
  run ! grep -q '7d: 99%' <<<"$output"
}

@test "does not resurrect a cached window the live payload stopped reporting" {
  _seed_cache "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":4,\"resets_at\":$(_in_hours 2)}}}"
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "persists a live window that arrives without its sibling" {
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  run jq -r '.rate_limits.seven_day.used_percentage' "$HOME/$CACHE_REL"
  [ "$status" -eq 0 ]
  [ "$output" = "12" ]
}

@test "leaves no temporary file beside the cache it writes" {
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  run ls "$HOME/.cache/claude-statusline"
  [ "$output" = "last.json" ]
}

@test "writes the cache through a temporary name no other render shares" {
  mkdir -p "$HOME/.cache/claude-statusline"
  printf 'sentinel' >"$HOME/$CACHE_REL.tmp"
  run _run "$(_payload "{\"seven_day\":{\"used_percentage\":12,\"resets_at\":$(_in_hours 50)}}")"
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/$CACHE_REL.tmp")" = "sentinel" ]
  run jq -r '.rate_limits.seven_day.used_percentage' "$HOME/$CACHE_REL"
  [ "$output" = "12" ]
}

@test "colours the context percentage green below 70, yellow from 70, red from 85" {
  run _run_raw '{"context_window":{"used_percentage":69}}'
  [[ "$output" == *$'\e[38;2;13;188;121m69%'* ]]
  run _run_raw '{"context_window":{"used_percentage":70}}'
  [[ "$output" == *$'\e[38;2;229;229;16m70%'* ]]
  run _run_raw '{"context_window":{"used_percentage":84}}'
  [[ "$output" == *$'\e[38;2;229;229;16m84%'* ]]
  run _run_raw '{"context_window":{"used_percentage":85}}'
  [[ "$output" == *$'\e[38;2;205;49;49m85%'* ]]
}

@test "colours a usage percentage blue below 70, magenta from 70, red from 90" {
  run _run_raw "$(_payload '{"seven_day":{"used_percentage":69}}')"
  [[ "$output" == *$'\e[38;2;59;142;234m69%'* ]]
  run _run_raw "$(_payload '{"seven_day":{"used_percentage":70}}')"
  [[ "$output" == *$'\e[38;2;214;112;214m70%'* ]]
  run _run_raw "$(_payload '{"seven_day":{"used_percentage":89}}')"
  [[ "$output" == *$'\e[38;2;214;112;214m89%'* ]]
  run _run_raw "$(_payload '{"seven_day":{"used_percentage":90}}')"
  [[ "$output" == *$'\e[38;2;205;49;49m90%'* ]]
}

@test "stays silent on stderr and exits zero when the cache directory cannot be created" {
  mkdir -p "$HOME/.cache"
  printf 'x' >"$HOME/.cache/claude-statusline"
  run --separate-stderr _run "$(_payload '{"seven_day":{"used_percentage":12}}')"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [[ "$output" == *"7d: 12%"* ]]
}

@test "ignores a spend_limit window it does not display" {
  run _run "$(_payload '{"seven_day":{"used_percentage":12},"spend_limit":{"used_percentage":80,"used_usd":4.2}}')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 12%"* ]]
  run ! grep -q '80' <<<"$output"
}

@test "rounds a fractional percentage instead of printing it raw" {
  run _run "$(_payload '{"seven_day":{"used_percentage":12.6}}')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"7d: 13%"* ]]
}

@test "reports an empty payload without emitting a stray percentage" {
  run _run ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Context 0%"* ]]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: --"* ]]
}

@test "reports a payload that is not json without emitting a stray percentage" {
  run _run 'garbage'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Context 0%"* ]]
  [[ "$output" == *"5h: --"* ]]
  [[ "$output" == *"7d: --"* ]]
}
