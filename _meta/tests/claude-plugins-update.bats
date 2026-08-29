#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/claude-plugins-update

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

_write_mcp() {
  mkdir -p "${FAKE_HOME}/.claude"
  cat >"${FAKE_HOME}/.claude/mcp.json"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  export STUBS FAKE_HOME
  # Real binaries the script drives directly. jq is deliberately real: the
  # bugs under test are about propagating *its* exit status, so a stub would
  # test the stub instead.
  for cmd in jq mktemp dirname grep rm mv cat; do
    ln -s "$(command -v "$cmd")" "${STUBS}/${cmd}"
  done
  REAL_JQ="$(command -v jq)"
  export REAL_JQ
  ln -s "$BASH" "${STUBS}/bash"
  _stub_command claude
  _stub_command curl
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
  _stub_command claude 'case "$3" in beta@mkt) exit 1 ;; esac; exit 0'
  _write_installed <<'EOF'
{"plugins": {"alpha@mkt": {}, "beta@mkt": {}}}
EOF
  _run
  [ "$status" -ne 0 ]
  [[ "$output" == *"[failed]"* ]]
}

# ─── bug 1: unchecked jq on the plugin list ─────────────────────────────────

@test "malformed installed_plugins.json: exits non-zero, does not claim success" {
  _write_installed <<'EOF'
{"plugins": {"alpha@mkt":
EOF
  _run
  [ "$status" -ne 0 ]
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

# ─── ouroboros MCP pin ──────────────────────────────────────────────────────

@test "mcp pin already current: exits 0, reports already at" {
  _write_installed <<'EOF'
{"plugins": {}}
EOF
  _write_mcp <<'EOF'
{"mcpServers": {"ouroboros": {"args": ["ouroboros-ai==2.0.0"]}}}
EOF
  _stub_command curl 'printf "{\"info\":{\"version\":\"2.0.0\"}}"'
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"already at 2.0.0"* ]]
}

@test "mcp pin outdated: rewrites mcp.json and exits 0" {
  _write_installed <<'EOF'
{"plugins": {}}
EOF
  _write_mcp <<'EOF'
{"mcpServers": {"ouroboros": {"args": ["ouroboros-ai==1.0.0"]}}}
EOF
  _stub_command curl 'printf "{\"info\":{\"version\":\"2.0.0\"}}"'
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"1.0.0 → 2.0.0"* ]]
  grep -q 'ouroboros-ai==2.0.0' "${FAKE_HOME}/.claude/mcp.json"
}

# ─── bug 2: unchecked mcp.json rewrite ──────────────────────────────────────

@test "mcp rewrite jq failure: exits non-zero, no success line, file intact" {
  _write_installed <<'EOF'
{"plugins": {}}
EOF
  _write_mcp <<'EOF'
{"mcpServers": {"ouroboros": {"args": ["ouroboros-ai==1.0.0"]}}}
EOF
  _stub_command curl 'printf "{\"info\":{\"version\":\"2.0.0\"}}"'
  # fail only the rewrite invocation (the one carrying --arg), so the earlier
  # probe and version parse still run against real jq
  _stub_command jq '[ "$1" = "--arg" ] && exit 1; exec "$REAL_JQ" "$@"'
  _run
  [ "$status" -ne 0 ]
  [[ "$output" != *"1.0.0 → 2.0.0 (restart"* ]]
  [[ "$output" == *"mcp.json"* ]]
  grep -q 'ouroboros-ai==1.0.0' "${FAKE_HOME}/.claude/mcp.json"
}

@test "mcp rewrite mv failure: exits non-zero and does not print the success line" {
  _write_installed <<'EOF'
{"plugins": {}}
EOF
  _write_mcp <<'EOF'
{"mcpServers": {"ouroboros": {"args": ["ouroboros-ai==1.0.0"]}}}
EOF
  _stub_command curl 'printf "{\"info\":{\"version\":\"2.0.0\"}}"'
  _stub_command mv 'exit 1'
  _run
  [ "$status" -ne 0 ]
  [[ "$output" != *"1.0.0 → 2.0.0 (restart"* ]]
  [[ "$output" == *"mcp.json"* ]]
  # the original pin is left intact rather than half-written
  grep -q 'ouroboros-ai==1.0.0' "${FAKE_HOME}/.claude/mcp.json"
}
