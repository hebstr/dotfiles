#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/claude-plugins-install

bats_require_minimum_version 1.5.0

SCRIPT="${CLAUDE_PLUGINS_INSTALL:-$BATS_TEST_DIRNAME/../../bin/.local/bin/claude-plugins-install}"

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

# The default claude stub records its argv, so tests assert on what the script
# invoked rather than on log prose. ${CLAUDE_LOG} reaches the stub through the
# environment, which is why the body stays single-quoted here.
_stub_claude() {
  local body=${1:-}
  [ "$body" != "" ] || body='printf "%s\n" "$*" >>"$CLAUDE_LOG"; exit 0'
  _stub_command claude "$body"
}

_write_settings() {
  mkdir -p "${FAKE_HOME}/.claude"
  cat >"${FAKE_HOME}/.claude/settings.json"
}

_write_registry() {
  mkdir -p "${FAKE_HOME}/.claude/plugins"
  cat >"${FAKE_HOME}/.claude/plugins/installed_plugins.json"
}

_registry() {
  printf '%s' "${FAKE_HOME}/.claude/plugins/installed_plugins.json"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  CLAUDE_LOG="${STUBS}/claude.log"
  export STUBS FAKE_HOME CLAUDE_LOG
  : >"$CLAUDE_LOG"
  # Real binaries the script drives directly. jq is deliberately real: what the
  # tests pin is how the script consumes *its* output and exit status, so a stub
  # would test the stub instead. Resolved through command -v rather than a
  # hardcoded /usr/bin so the harness survives a differently laid-out system.
  for cmd in jq mktemp date cp mv cat; do
    ln -s "$(command -v "$cmd")" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _stub_claude
}

# The script parses no arguments, so this forwards none.
_run() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" CLAUDE_LOG="$CLAUDE_LOG" "$BASH" "$SCRIPT"
}

teardown() {
  rm -rf "$STUBS" "$FAKE_HOME"
}

# ─── dependency and precondition guards ─────────────────────────────────────

@test "missing claude: exits 1 with message" {
  rm "${STUBS}/claude"
  _write_settings <<'EOF'
{}
EOF
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"claude CLI not found"* ]]
}

@test "missing jq: exits 1 with message" {
  rm "${STUBS}/jq"
  _write_settings <<'EOF'
{}
EOF
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}

@test "missing settings.json: exits 1 and names the path" {
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"settings.json not found"* ]]
}

@test "settings.json present but empty object: exits 0, invokes nothing" {
  _write_settings <<'EOF'
{}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Done."* ]]
  run ! grep -q . "$CLAUDE_LOG"
}

# ─── marketplaces ───────────────────────────────────────────────────────────

@test "marketplace with a .repo source: added by repo" {
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {"mkt": {"source": {"repo": "owner/repo"}}}}
EOF
  _run
  [ "$status" -eq 0 ]
  grep -qx 'plugin marketplace add owner/repo' "$CLAUDE_LOG"
}

@test "marketplace with only a .path source: added by path" {
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {"mkt": {"source": {"path": "/opt/local-mkt"}}}}
EOF
  _run
  [ "$status" -eq 0 ]
  grep -qx 'plugin marketplace add /opt/local-mkt' "$CLAUDE_LOG"
}

@test "marketplace with both .repo and .path: repo wins" {
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {"mkt": {"source": {"repo": "owner/repo", "path": "/opt/local-mkt"}}}}
EOF
  _run
  [ "$status" -eq 0 ]
  grep -qx 'plugin marketplace add owner/repo' "$CLAUDE_LOG"
  run ! grep -q '/opt/local-mkt' "$CLAUDE_LOG"
}

@test "marketplace source with neither .repo nor .path: skipped, run continues" {
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {"mkt": {"source": {"kind": "builtin"}}},
 "enabledPlugins": {"p@mkt": true}}
EOF
  _run
  [ "$status" -eq 0 ]
  grep -qx 'plugin install p@mkt' "$CLAUDE_LOG"
  run ! grep -q 'marketplace add' "$CLAUDE_LOG"
}

@test "failing marketplace add: warns, stays non-fatal, plugin loop still runs" {
  _stub_claude 'printf "%s\n" "$*" >>"$CLAUDE_LOG"; case "$2" in marketplace) exit 1 ;; esac; exit 0'
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {"mkt": {"source": {"repo": "owner/repo"}}},
 "enabledPlugins": {"p@mkt": true}}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"already present or failed: owner/repo"* ]]
  grep -qx 'plugin install p@mkt' "$CLAUDE_LOG"
}

# ─── plugins ────────────────────────────────────────────────────────────────

@test "enabledPlugins true: installed" {
  _write_settings <<'EOF'
{"enabledPlugins": {"alpha@mkt": true}}
EOF
  _run
  [ "$status" -eq 0 ]
  grep -qx 'plugin install alpha@mkt' "$CLAUDE_LOG"
}

@test "enabledPlugins false: not installed" {
  _write_settings <<'EOF'
{"enabledPlugins": {"alpha@mkt": true, "beta@mkt": false}}
EOF
  _run
  [ "$status" -eq 0 ]
  grep -qx 'plugin install alpha@mkt' "$CLAUDE_LOG"
  run ! grep -q 'beta@mkt' "$CLAUDE_LOG"
}

@test "failing plugin install: warns, stays non-fatal, later plugins still run" {
  _stub_claude 'printf "%s\n" "$*" >>"$CLAUDE_LOG"; case "$3" in alpha@mkt) exit 1 ;; esac; exit 0'
  _write_settings <<'EOF'
{"enabledPlugins": {"alpha@mkt": true, "beta@mkt": true}}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed or failed: alpha@mkt"* ]]
  grep -qx 'plugin install beta@mkt' "$CLAUDE_LOG"
}

# ─── a settings.json jq cannot read must not report success ─────────────────
# Feeding the loop from a process substitution discards jq's exit status, so a
# fresh-machine restore that installs nothing would still print "Done." and
# exit 0. Same trap, same fix as claude-plugins-update.

@test "unparsable settings.json: exits non-zero, claims no success, invokes nothing" {
  _write_settings <<'EOF'
{"enabledPlugins":
EOF
  _run
  [ "$status" -ne 0 ]
  [[ "$output" != *"Done."* ]]
  run ! grep -q . "$CLAUDE_LOG"
}

@test "marketplace source jq cannot index: exits non-zero, plugin loop still runs" {
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {"mkt": {"source": "owner/repo"}},
 "enabledPlugins": {"p@mkt": true}}
EOF
  _run
  [ "$status" -ne 0 ]
  [[ "$output" != *"Done."* ]]
  grep -qx 'plugin install p@mkt' "$CLAUDE_LOG"
}

# ─── the loops' lists must not reach the child on stdin ─────────────────────
# Without `</dev/null` on the child, `claude plugin install` inherits the loop's
# stdin and swallows the next line: on a@mkt/b@mkt/c@mkt the script installs
# a@mkt and c@mkt, and b@mkt silently never happens.

@test "plugin install does not inherit the loop's plugin list on stdin" {
  _stub_claude 'case "$2" in install) IFS= read -r leaked && printf "LEAKED:%s\n" "$leaked" ;; esac; printf "%s\n" "$*" >>"$CLAUDE_LOG"; exit 0'
  _write_settings <<'EOF'
{"enabledPlugins": {"a@mkt": true, "b@mkt": true, "c@mkt": true}}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"LEAKED:"* ]]
  grep -qx 'plugin install a@mkt' "$CLAUDE_LOG"
  grep -qx 'plugin install b@mkt' "$CLAUDE_LOG"
  grep -qx 'plugin install c@mkt' "$CLAUDE_LOG"
}

@test "marketplace add does not inherit the loop's marketplace list on stdin" {
  _stub_claude 'case "$2" in marketplace) IFS= read -r leaked && printf "LEAKED:%s\n" "$leaked" ;; esac; printf "%s\n" "$*" >>"$CLAUDE_LOG"; exit 0'
  _write_settings <<'EOF'
{"extraKnownMarketplaces": {
  "m1": {"source": {"repo": "o/one"}},
  "m2": {"source": {"repo": "o/two"}},
  "m3": {"source": {"repo": "o/three"}}}}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"LEAKED:"* ]]
  grep -qx 'plugin marketplace add o/one' "$CLAUDE_LOG"
  grep -qx 'plugin marketplace add o/two' "$CLAUDE_LOG"
  grep -qx 'plugin marketplace add o/three' "$CLAUDE_LOG"
}

# ─── autoUpdate patch on the registry ───────────────────────────────────────
# Registry fixtures mirror the live file: each .plugins value is an array of
# objects, which is what makes `map(. + {autoUpdate: true})` the right filter.

@test "registry present: autoUpdate added to every entry, array shape preserved" {
  _write_settings <<'EOF'
{}
EOF
  _write_registry <<'EOF'
{"plugins": {"alpha@mkt": [{"name": "alpha"}], "beta@mkt": [{"name": "beta"}]}}
EOF
  _run
  [ "$status" -eq 0 ]
  jq -e '.plugins["alpha@mkt"] | type == "array"' "$(_registry)" >/dev/null
  jq -e '.plugins["alpha@mkt"][0].autoUpdate == true' "$(_registry)" >/dev/null
  jq -e '.plugins["beta@mkt"][0].autoUpdate == true' "$(_registry)" >/dev/null
  jq -e '.plugins["alpha@mkt"][0].name == "alpha"' "$(_registry)" >/dev/null
}

@test "registry present: a timestamped backup holds the pre-patch content" {
  _write_settings <<'EOF'
{}
EOF
  _write_registry <<'EOF'
{"plugins": {"alpha@mkt": [{"name": "alpha"}]}}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"registry patched. backup:"* ]]
  local backup
  backup=$(echo "$FAKE_HOME"/.claude/plugins/installed_plugins.json.bak.*)
  [ -f "$backup" ]
  jq -e '.plugins["alpha@mkt"][0] | has("autoUpdate") | not' "$backup" >/dev/null
}

@test "already-patched registry: idempotent, autoUpdate stays true" {
  _write_settings <<'EOF'
{}
EOF
  _write_registry <<'EOF'
{"plugins": {"alpha@mkt": [{"name": "alpha", "autoUpdate": true}]}}
EOF
  _run
  [ "$status" -eq 0 ]
  jq -e '.plugins["alpha@mkt"][0].autoUpdate == true' "$(_registry)" >/dev/null
  jq -e '.plugins["alpha@mkt"] | length == 1' "$(_registry)" >/dev/null
}

@test "registry absent: warns and exits 0" {
  _write_settings <<'EOF'
{}
EOF
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping autoUpdate patch"* ]]
  [[ "$output" == *"Done."* ]]
}

@test "malformed registry: exits non-zero, leaves the file intact, no success line" {
  _write_settings <<'EOF'
{}
EOF
  _write_registry <<'EOF'
{"plugins":
EOF
  _run
  [ "$status" -ne 0 ]
  [[ "$output" != *"registry patched"* ]]
  [[ "$output" != *"Done."* ]]
  [ "$(cat "$(_registry)")" = '{"plugins":' ]
}
