#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/todo-sync

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/todo-sync"

setup() {
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$HOME"
}

_write() {
  local rel=$1 content=$2
  mkdir -p "$HOME/$(dirname "$rel")"
  printf '%s' "$content" >"$HOME/$rel"
}

_p() {
  printf '%s\n' "$@"
}

# ─── empty scan ─────────────────────────────────────────────────────────────

@test "no TODO.md anywhere: header table only, no data rows" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| Prio | Projet | Item | Statut |"* ]]
  [[ "$output" != *"| P0 |"* ]]
  [[ "$output" != *"| P1 |"* ]]
  [[ "$output" != *"| P2 |"* ]]
}

# ─── basic parsing ──────────────────────────────────────────────────────────

@test "single P0 item: appears in table" {
  _write proj/TODO.md "$(_p '## P0' '- [ ] do thing')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| P0 | ~/proj | do thing |  |"* ]]
}

@test "checked item is skipped" {
  _write proj/TODO.md "$(_p '## P0' '- [x] done item' '- [ ] open item')"
  run "$SCRIPT"
  [[ "$output" == *"| open item |"* ]]
  [[ "$output" != *"done item"* ]]
}

@test "items outside P0/P1/P2 are skipped" {
  _write proj/TODO.md "$(_p '## Notes' '- [ ] skip me' '## P0' '- [ ] keep me')"
  run "$SCRIPT"
  [[ "$output" == *"keep me"* ]]
  [[ "$output" != *"skip me"* ]]
}

@test "section after tier resets tier" {
  _write proj/TODO.md "$(_p \
    '## P0' '- [ ] before' \
    '## Done' '- [ ] orphan' \
    '## P1' '- [ ] after')"
  run "$SCRIPT"
  [[ "$output" == *"before"* ]]
  [[ "$output" == *"after"* ]]
  [[ "$output" != *"orphan"* ]]
}

@test "all three tiers collected" {
  _write proj/TODO.md "$(_p \
    '## P0' '- [ ] p0a' \
    '## P1' '- [ ] p1a' \
    '## P2' '- [ ] p2a')"
  run "$SCRIPT"
  [[ "$output" == *"| P0 | ~/proj | p0a |"* ]]
  [[ "$output" == *"| P1 | ~/proj | p1a |"* ]]
  [[ "$output" == *"| P2 | ~/proj | p2a |"* ]]
}

@test "near-miss headings (## P10, ## P0a) are not tiers" {
  _write proj/TODO.md "$(_p \
    '## P0a' '- [ ] noise1' \
    '## P10' '- [ ] noise2' \
    '## P0' '- [ ] real')"
  run "$SCRIPT"
  [[ "$output" == *"real"* ]]
  [[ "$output" != *"noise1"* ]]
  [[ "$output" != *"noise2"* ]]
}

# ─── annotation / statut ────────────────────────────────────────────────────

@test "annotation 'X : Y': statut is X" {
  _write proj/TODO.md "$(_p '## P0' '- [ ] task body *(en cours : depuis hier)*')"
  run "$SCRIPT"
  [[ "$output" == *"| task body | en cours |"* ]]
}

@test "annotation without ' : ' split: full annotation is statut" {
  _write proj/TODO.md "$(_p '## P0' '- [ ] task body *(bloque)*')"
  run "$SCRIPT"
  [[ "$output" == *"| task body | bloque |"* ]]
}

@test "no annotation: empty statut column" {
  _write proj/TODO.md "$(_p '## P0' '- [ ] plain task')"
  run "$SCRIPT"
  [[ "$output" == *"| plain task |  |"* ]]
}

# ─── project naming ────────────────────────────────────────────────────────

@test "one-level path: project is ~/dirname" {
  _write alpha/TODO.md "$(_p '## P0' '- [ ] a')"
  run "$SCRIPT"
  [[ "$output" == *"| P0 | ~/alpha | a |"* ]]
}

@test "two-level path: project keeps both segments" {
  _write alpha/beta/TODO.md "$(_p '## P0' '- [ ] b')"
  run "$SCRIPT"
  [[ "$output" == *"| P0 | alpha/beta | b |"* ]]
}

@test "deep path: project keeps only last two segments" {
  _write alpha/beta/gamma/TODO.md "$(_p '## P0' '- [ ] c')"
  run "$SCRIPT"
  [[ "$output" == *"| P0 | beta/gamma | c |"* ]]
}

@test "notes file: project label is '~/notes'" {
  _write notes/TODO.md "$(_p '## P0' '- [ ] notes item')"
  run "$SCRIPT"
  [[ "$output" == *"| P0 | ~/notes | notes item |"* ]]
}

@test "admin file: project label is '~/admin'" {
  _write admin/TODO.md "$(_p '## P0' '- [ ] admin item')"
  run "$SCRIPT"
  [[ "$output" == *"| P0 | ~/admin | admin item |"* ]]
}

@test "admin items sort before all other projects" {
  _write admin/TODO.md "$(_p '## P0' '- [ ] admin p0')"
  _write alpha/TODO.md "$(_p '## P0' '- [ ] alpha p0')"
  run "$SCRIPT"
  local l_admin l_alpha
  l_admin=$(printf '%s\n' "$output" | grep -n 'admin p0' | head -1 | cut -d: -f1)
  l_alpha=$(printf '%s\n' "$output" | grep -n 'alpha p0' | head -1 | cut -d: -f1)
  [ "$l_admin" -lt "$l_alpha" ]
}

@test "delimiter between admin todos and project todos" {
  _write admin/TODO.md "$(_p '## P0' '- [ ] admin item')"
  _write proj/TODO.md "$(_p '## P0' '- [ ] proj item')"
  run "$SCRIPT"
  [[ "$output" == *"admin item"*"---"*"proj item"* ]]
}

@test "notes items sort after all other projects" {
  _write notes/TODO.md "$(_p '## P0' '- [ ] notes p0')"
  _write zeta/TODO.md "$(_p '## P2' '- [ ] zeta p2')"
  run "$SCRIPT"
  local l_notes l_zeta
  l_notes=$(printf '%s\n' "$output" | grep -n 'notes p0' | head -1 | cut -d: -f1)
  l_zeta=$(printf '%s\n' "$output" | grep -n 'zeta p2' | head -1 | cut -d: -f1)
  [ "$l_zeta" -lt "$l_notes" ]
}

@test "delimiter between project todos and notes todos" {
  _write notes/TODO.md "$(_p '## P0' '- [ ] notes item')"
  _write proj/TODO.md "$(_p '## P0' '- [ ] proj item')"
  run "$SCRIPT"
  [[ "$output" == *"proj item"*"---"*"notes item"* ]]
}

@test "delimiter between todos and empty/non-conformant section" {
  _write proj/TODO.md "$(_p '## P0' '- [ ] proj item')"
  mkdir -p "$HOME/empty-proj"
  : >"$HOME/empty-proj/TODO.md"
  run "$SCRIPT"
  [[ "$output" == *"proj item"*"---"*"## VIDE"* ]]
}

# ─── empty / non-conformant files ──────────────────────────────────────────

@test "empty file: listed under 'VIDE'" {
  mkdir -p "$HOME/empty-proj"
  : >"$HOME/empty-proj/TODO.md"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## VIDE"* ]]
  [[ "$output" == *"empty-proj"* ]]
}

@test "file without P0/P1/P2 section: listed under 'À FORMATER'" {
  _write no-tier/TODO.md "$(_p '## Notes' '- [ ] just a note')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## À FORMATER"* ]]
  [[ "$output" == *"no-tier"* ]]
}

@test "file with P0/P1/P2 section but all items checked: not flagged non-conformant" {
  _write done-proj/TODO.md "$(_p '## P0' '- [x] finished')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"done-proj"* ]]
}

# ─── exclusions ────────────────────────────────────────────────────────────

@test "excluded paths: node_modules, .venv, venv, site-packages, vendor, *library*" {
  for excl in node_modules .venv venv site-packages vendor mylibrary; do
    _write "proj/$excl/inner/TODO.md" "$(_p '## P0' '- [ ] hidden')"
  done
  _write real/TODO.md "$(_p '## P0' '- [ ] visible')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"visible"* ]]
  [[ "$output" != *"hidden"* ]]
}

# ─── escaping ──────────────────────────────────────────────────────────────

@test "pipe character in item: escaped as backslash-pipe" {
  _write proj/TODO.md "$(_p '## P0' '- [ ] a | b')"
  run "$SCRIPT"
  [[ "$output" == *'a \| b'* ]]
}

# ─── tab normalization ────────────────────────────────────────────────────

@test "tab in item body: normalized to space, no column shift" {
  _write proj/TODO.md "$(_p '## P0' $'- [ ] before\tafter')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"| P0 | ~/proj | before after |  |"* ]]
}

@test "tab in status annotation: normalized to space" {
  _write proj/TODO.md "$(_p '## P0' $'- [ ] task *(en\tcours : detail)*')"
  run "$SCRIPT"
  [[ "$output" == *"| task | en cours |"* ]]
}

# ─── sort order ────────────────────────────────────────────────────────────

@test "sort: tier asc, then project asc, then file order within section" {
  _write zeta/TODO.md "$(_p '## P1' '- [ ] z-p1')"
  _write alpha/TODO.md "$(_p \
    '## P0' '- [ ] a-p0-1' '- [ ] a-p0-2' \
    '## P1' '- [ ] a-p1')"
  run "$SCRIPT"
  local l_a01 l_a02 l_a1 l_z1
  l_a01=$(printf '%s\n' "$output" | grep -n 'a-p0-1' | head -1 | cut -d: -f1)
  l_a02=$(printf '%s\n' "$output" | grep -n 'a-p0-2' | head -1 | cut -d: -f1)
  l_a1=$(printf '%s\n' "$output" | grep -n 'a-p1' | head -1 | cut -d: -f1)
  l_z1=$(printf '%s\n' "$output" | grep -n 'z-p1' | head -1 | cut -d: -f1)
  [ "$l_a01" -lt "$l_a02" ]
  [ "$l_a02" -lt "$l_a1" ]
  [ "$l_a1" -lt "$l_z1" ]
}

# ─── CLI prerequisites ─────────────────────────────────────────────────────

@test "fdfind missing on PATH: exit 1 with error message" {
  local empty_bin="${BATS_TEST_TMPDIR}/empty_bin"
  mkdir -p "$empty_bin"
  ln -s "$(command -v bash)" "$empty_bin/bash"
  run env -i PATH="$empty_bin" HOME="$HOME" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fdfind is required"* ]]
}
