#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/claude-plugins-update

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/claude-plugins-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs are written into ${STUBS} and the test runs with PATH=${STUBS}, so a
# command that is not stubbed or symlinked here is genuinely "not found" from
# the script's point of view.

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  # rm first: a test may shadow one of the real binaries symlinked in setup(),
  # and a redirection onto a symlink writes through to its target.
  rm -f "${STUBS}/${name}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

_write_installed() {
  mkdir -p "${FAKE_HOME}/.claude/plugins"
  cat >"${FAKE_HOME}/.claude/plugins/installed_plugins.json"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  export STUBS FAKE_HOME
  # jq is the one real binary the script drives directly, and it is real
  # because several tests assert how *its* exit status propagates, so a stub
  # would test the stub instead.
  ln -s "$(command -v jq)" "${STUBS}/jq"
  ln -s "$BASH" "${STUBS}/bash"
  _stub_command claude
}

# The script parses no arguments, so this forwards none.
_run() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" "$BASH" "$SCRIPT"
}

teardown() {
  rm -rf "$STUBS" "$FAKE_HOME"
}

# ─── dependency guards ──────────────────────────────────────────────────────

@test "missing jq: exits 1 with message" {
  rm "${STUBS}/jq"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}

@test "missing claude: exits 1 with message" {
  rm "${STUBS}/claude"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude is required"* ]]
}

# ─── marketplace update ─────────────────────────────────────────────────────

@test "no installed_plugins.json: exits 0 with message" {
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No installed_plugins.json found"* ]]
}

@test "marketplace update failure does not abort, but exits non-zero" {
  _stub_command claude 'case "$1 $2" in "plugin marketplace") exit 1 ;; esac; exit 0'
  _write_installed <<'EOF'
{"plugins": {"foo@mkt": {}}}
EOF
  _run
  [ "$status" -ne 0 ]
  # the plugin loop still ran despite the marketplace failure
  [[ "$output" == *"foo@mkt"* ]]
}

# ─── plugin loop ────────────────────────────────────────────────────────────

@test "every plugin updated: exits 0, each name echoed" {
  _write_installed <<'EOF'
{"plugins": {"alpha@mkt": {}, "beta@mkt": {}}}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha@mkt"* ]]
  [[ "$output" == *"beta@mkt"* ]]
}

@test "one plugin update fails: exits non-zero, marks that plugin failed" {
  _stub_command claude 'case "$3" in alpha@mkt) exit 1 ;; esac; [ "$2" = update ] && echo "UPDATED:$3"; exit 0'
  _write_installed <<'EOF'
{"plugins": {"alpha@mkt": {}, "beta@mkt": {}}}
EOF
  _run
  [ "$status" -ne 0 ]
  [[ "$output" == *"[failed]"* ]]
  [[ "$output" == *"UPDATED:beta@mkt"* ]]
}

# ─── plugin list read failure ───────────────────────────────────────────────

@test "malformed installed_plugins.json: exits non-zero, does not claim success" {
  _write_installed <<'EOF'
{"plugins": {"alpha@mkt":
EOF
  _stub_command opencode
  _stub_command opencode-skills-sync 'echo SYNC-RAN'
  _run
  [ "$status" -ne 0 ]
  [[ "$output" == *"SYNC-RAN"* ]]
}

@test "installed_plugins.json without a .plugins key: exits non-zero" {
  _write_installed <<'EOF'
{"somethingElse": {}}
EOF
  _run
  [ "$status" -ne 0 ]
}

@test "empty .plugins object is not a failure: exits 0" {
  _write_installed <<'EOF'
{"plugins": {}}
EOF
  _run
  [ "$status" -eq 0 ]
}

# ─── plugin update stdin isolation ──────────────────────────────────────────

@test "plugin update does not inherit the loop's plugin list on stdin" {
  _write_installed <<'EOF'
{"plugins": {"alpha@mkt": {}, "beta@mkt": {}, "gamma@mkt": {}}}
EOF
  _stub_command claude 'case "$2" in update) IFS= read -r leaked && echo "LEAKED:${leaked}" ;; esac; exit 0'
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"LEAKED:"* ]]
  [[ "$output" == *"alpha@mkt"* ]]
  [[ "$output" == *"beta@mkt"* ]]
  [[ "$output" == *"gamma@mkt"* ]]
}

# ─── opencode skill links follow the updated install paths ──────────────────

@test "opencode installed: resyncs its plugin skill links" {
  _write_installed <<'EOF2'
{"plugins": {}}
EOF2
  _stub_command opencode
  _stub_command opencode-skills-sync 'echo SYNC-RAN'
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"SYNC-RAN"* ]]
}

@test "opencode skill resync failure: exits non-zero" {
  _write_installed <<'EOF2'
{"plugins": {}}
EOF2
  _stub_command opencode
  _stub_command opencode-skills-sync 'exit 1'
  _run
  [ "$status" -ne 0 ]
}

@test "opencode absent: leaves the skill links alone" {
  _write_installed <<'EOF2'
{"plugins": {}}
EOF2
  _stub_command opencode-skills-sync 'echo SYNC-RAN'
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"SYNC-RAN"* ]]
}
