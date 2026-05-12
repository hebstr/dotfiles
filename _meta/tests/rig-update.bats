#!/usr/bin/env bats

# Tests for rig-update
# Mocks: gh, curl, rig, apt-get, sudo — no real network calls, no real installs

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/rig-update"
FAKE_LATEST="0.9.0"
FAKE_OUTDATED="0.7.0"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
  export PATH="$TMPDIR_TEST/bin:$PATH"
  mkdir -p "$TMPDIR_TEST/bin"

  export RIG_GPG_KEY_DEST="$TMPDIR_TEST/rig.gpg"
  export RIG_APT_SOURCE_FILE="$TMPDIR_TEST/rig.list"

  cat >"$TMPDIR_TEST/bin/curl" <<'STUB'
#!/usr/bin/env bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift; touch "$1" ;;
  esac
  shift
done
STUB
  chmod +x "$TMPDIR_TEST/bin/curl"

  cat >"$TMPDIR_TEST/bin/gh" <<STUB
#!/usr/bin/env bash
if [[ "\$1" == "api" ]]; then
  printf '%s\n' "${FAKE_LATEST}"
  exit 0
fi
exit 0
STUB
  chmod +x "$TMPDIR_TEST/bin/gh"

  cat >"$TMPDIR_TEST/bin/apt-get" <<'STUB'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*"
STUB
  chmod +x "$TMPDIR_TEST/bin/apt-get"

  cat >"$TMPDIR_TEST/bin/sudo" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-v" ]]; then exit 0; fi
exec "$@"
STUB
  chmod +x "$TMPDIR_TEST/bin/sudo"

  make_rig_stub "$FAKE_OUTDATED"

  if ! command -v jq >/dev/null 2>&1; then
    cat >"$TMPDIR_TEST/bin/jq" <<'STUB'
#!/usr/bin/env bash
input=$(cat)
tag=$(printf '%s\n' "$input" | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
printf '%s\n' "${tag#v}"
STUB
    chmod +x "$TMPDIR_TEST/bin/jq"
  fi

  # shellcheck source=/dev/null
  source "$SCRIPT"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

make_rig_stub() {
  local version="$1"
  cat >"$TMPDIR_TEST/bin/rig" <<EOF
#!/usr/bin/env bash
echo "RIG -- The R Installation Manager $version"
EOF
  chmod +x "$TMPDIR_TEST/bin/rig"
}

# ---------------------------------------------------------------------------
# fetch_latest_version
# ---------------------------------------------------------------------------

@test "fetch_latest_version: returns version from GitHub API" {
  run fetch_latest_version
  [ "$status" -eq 0 ]
  [ "$output" = "$FAKE_LATEST" ]
}

@test "fetch_latest_version: exits 1 when API returns null" {
  cat >"$TMPDIR_TEST/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf 'null\n'
STUB
  chmod +x "$TMPDIR_TEST/bin/gh"
  run fetch_latest_version
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

# ---------------------------------------------------------------------------
# get_current_version
# ---------------------------------------------------------------------------

@test "get_current_version: returns version when rig is installed" {
  run get_current_version
  [ "$status" -eq 0 ]
  [ "$output" = "$FAKE_OUTDATED" ]
}

@test "get_current_version: returns unknown when rig is absent" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$TMPDIR_TEST/bin/rig"
  chmod +x "$TMPDIR_TEST/bin/rig"
  run get_current_version
  [ "$status" -eq 0 ]
  [ "$output" = "unknown" ]
}

# ---------------------------------------------------------------------------
# setup_apt_repo
# ---------------------------------------------------------------------------

@test "setup_apt_repo: skips everything if both files already present" {
  touch "$RIG_GPG_KEY_DEST"
  touch "$RIG_APT_SOURCE_FILE"
  run setup_apt_repo
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "setup_apt_repo: downloads GPG key when absent" {
  touch "$RIG_APT_SOURCE_FILE"
  run setup_apt_repo
  [ "$status" -eq 0 ]
  [ -f "$RIG_GPG_KEY_DEST" ]
}

@test "setup_apt_repo: creates APT source file with correct content" {
  touch "$RIG_GPG_KEY_DEST"
  run setup_apt_repo
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_APT_SOURCE_FILE")" = "deb http://rig.r-pkg.org/deb rig main" ]
}

# ---------------------------------------------------------------------------
# do_upgrade
# ---------------------------------------------------------------------------

@test "do_upgrade: runs apt-get update and installs r-rig" {
  run do_upgrade
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get update"* ]]
  [[ "$output" == *"r-rig"* ]]
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

@test "main: skips when already on latest version" {
  make_rig_stub "$FAKE_LATEST"
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" != *"apt-get"* ]]
}

@test "main: upgrades when rig is outdated" {
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get update"* ]]
  [[ "$output" == *"r-rig"* ]]
  [[ "$output" == *"Previous version was: ${FAKE_OUTDATED}"* ]]
}

@test "main: prints latest and current versions" {
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest rig release: ${FAKE_LATEST}"* ]]
  [[ "$output" == *"Current version:    ${FAKE_OUTDATED}"* ]]
}

@test "main: configures APT repo when files are missing" {
  run main
  [ "$status" -eq 0 ]
  [ -f "$RIG_GPG_KEY_DEST" ]
  [ -f "$RIG_APT_SOURCE_FILE" ]
}

# ---------------------------------------------------------------------------
# dependencies
# ---------------------------------------------------------------------------

@test "exits 1 when jq is missing" {
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"
  rm -f "$TMPDIR_TEST/bin/jq"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}
