#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

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

  export OPT_R="$TMPDIR_TEST/opt/R"
  export RPROFILE_TEMPLATE="$TMPDIR_TEST/Rprofile.site"
  mkdir -p "$OPT_R"
  touch "$RPROFILE_TEMPLATE"

  cat >"$TMPDIR_TEST/bin/stow-rprofile" <<'STUB'
#!/usr/bin/env bash
printf 'stow-rprofile ran\n'
STUB
  chmod +x "$TMPDIR_TEST/bin/stow-rprofile"

  export CURL_BODY="upstream-key"
  export CURL_RC=0
  cat >"$TMPDIR_TEST/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TMPDIR_TEST/curl-args"
((CURL_RC == 0)) || exit "$CURL_RC"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift; printf '%s' "$CURL_BODY" >"$1" ;;
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
printf '%s\n' "$*" >>"$TMPDIR_TEST/sudo-log"
exec "$@"
STUB
  chmod +x "$TMPDIR_TEST/bin/sudo"

  make_rig_stub "$FAKE_OUTDATED"

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

make_r_dir() {
  mkdir -p "$OPT_R/$1/lib/R/etc"
}

make_failing_stow_stub() {
  cat >"$TMPDIR_TEST/bin/stow-rprofile" <<'STUB'
#!/usr/bin/env bash
echo "No R versions found." >&2
exit 1
STUB
  chmod +x "$TMPDIR_TEST/bin/stow-rprofile"
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

@test "setup_apt_repo: leaves an existing source file alone" {
  printf 'custom\n' >"$RIG_APT_SOURCE_FILE"
  run setup_apt_repo
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$RIG_APT_SOURCE_FILE")" = "custom" ]
}

@test "setup_apt_repo: creates APT source file with correct content" {
  run setup_apt_repo
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_APT_SOURCE_FILE")" = "deb http://rig.r-pkg.org/deb rig main" ]
}

# ---------------------------------------------------------------------------
# refresh_gpg_key
# ---------------------------------------------------------------------------

@test "refresh_gpg_key: installs the key when absent" {
  run refresh_gpg_key
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_GPG_KEY_DEST")" = "upstream-key" ]
}

@test "refresh_gpg_key: no sudo and no output when the key is unchanged" {
  printf '%s' "upstream-key" >"$RIG_GPG_KEY_DEST"
  run refresh_gpg_key
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$TMPDIR_TEST/sudo-log" ]
}

@test "refresh_gpg_key: replaces a key that changed upstream" {
  printf '%s' "expired-key" >"$RIG_GPG_KEY_DEST"
  export TMPDIR="$TMPDIR_TEST/tmp"
  mkdir -p "$TMPDIR"
  run refresh_gpg_key
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_GPG_KEY_DEST")" = "upstream-key" ]
  [[ "$output" == *"key changed"* ]]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "refresh_gpg_key: fetches from RIG_GPG_KEY_URL" {
  export RIG_GPG_KEY_URL="https://override.test/rig.gpg"
  run refresh_gpg_key
  [ "$status" -eq 0 ]
  [[ "$(cat "$TMPDIR_TEST/curl-args")" == *"https://override.test/rig.gpg"* ]]
}

@test "refresh_gpg_key: warns and returns 0 when the install fails" {
  printf '%s' "expired-key" >"$RIG_GPG_KEY_DEST"
  cat >"$TMPDIR_TEST/bin/sudo" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == install ]] && exit 1
exec "$@"
STUB
  chmod +x "$TMPDIR_TEST/bin/sudo"
  run refresh_gpg_key
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not install"* ]]
  [ "$(cat "$RIG_GPG_KEY_DEST")" = "expired-key" ]
}

@test "refresh_gpg_key: warns and keeps the installed key when the fetch fails" {
  printf '%s' "expired-key" >"$RIG_GPG_KEY_DEST"
  export CURL_RC=22
  export TMPDIR="$TMPDIR_TEST/tmp"
  mkdir -p "$TMPDIR"
  run refresh_gpg_key
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not fetch"* ]]
  [ "$(cat "$RIG_GPG_KEY_DEST")" = "expired-key" ]
  [ -z "$(ls -A "$TMPDIR")" ]
}

# ---------------------------------------------------------------------------
# do_upgrade
# ---------------------------------------------------------------------------

@test "do_upgrade: runs apt-get update and installs r-rig" {
  run do_upgrade
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get update"* ]]
  [[ "$output" == *"apt-get update -qq -o Dir::Etc::SourceList=${RIG_APT_SOURCE_FILE} -o Dir::Etc::SourceParts=- --no-list-cleanup --error-on=any"* ]]
  [[ "$output" == *"r-rig"* ]]
}

@test "do_upgrade: a failed index refresh aborts before the install" {
  cat >"$TMPDIR_TEST/bin/apt-get" <<'STUB'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*"
# Real apt exits 0 on NO_PUBKEY unless asked otherwise.
[[ "$1" == update && "$*" == *--error-on=any* ]] && exit 100
exit 0
STUB
  chmod +x "$TMPDIR_TEST/bin/apt-get"
  # The real script, not `run do_upgrade`: bats disables errexit inside `run`.
  run "$SCRIPT"
  [ "$status" -eq 100 ]
  [[ "$output" == *"apt-get update"* ]]
  [[ "$output" != *"install -y r-rig"* ]]
}

# ---------------------------------------------------------------------------
# sync_rprofile
# ---------------------------------------------------------------------------

@test "sync_rprofile: no-op when no R version is installed" {
  run sync_rprofile
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sync_rprofile: relinks when an R install has no Rprofile.site" {
  make_r_dir 4.6.1
  run sync_rprofile
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile ran"* ]]
}

@test "sync_rprofile: no-op when every install already points at the template" {
  make_r_dir 4.6.1
  ln -s "$RPROFILE_TEMPLATE" "$OPT_R/4.6.1/lib/R/etc/Rprofile.site"
  run sync_rprofile
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sync_rprofile: relinks when a symlink points somewhere else" {
  make_r_dir 4.6.1
  touch "$TMPDIR_TEST/other"
  ln -s "$TMPDIR_TEST/other" "$OPT_R/4.6.1/lib/R/etc/Rprofile.site"
  run sync_rprofile
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile ran"* ]]
}

@test "sync_rprofile: leaves a regular Rprofile.site alone" {
  make_r_dir 4.6.1
  printf 'options(digits = 3)\n' >"$OPT_R/4.6.1/lib/R/etc/Rprofile.site"
  run sync_rprofile
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a symlink"* ]]
  [[ "$output" != *"stow-rprofile ran"* ]]
}

@test "sync_rprofile: no-op when stow-rprofile is not installed" {
  make_r_dir 4.6.1
  rm -f "$TMPDIR_TEST/bin/stow-rprofile"
  # Replaced, not prepended: ~/.local/bin carries the real stow-rprofile, which
  # this test would otherwise run against the live /opt/R.
  PATH="$TMPDIR_TEST/bin:/usr/bin:/bin"
  run sync_rprofile
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sync_rprofile: no-op when the template is missing" {
  make_r_dir 4.6.1
  rm -f "$RPROFILE_TEMPLATE"
  run sync_rprofile
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sync_rprofile: warns and returns 0 when stow-rprofile fails" {
  make_r_dir 4.6.1
  make_failing_stow_stub
  run sync_rprofile
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile failed"* ]]
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

@test "main: relinks Rprofile.site even when rig is already current" {
  make_rig_stub "$FAKE_LATEST"
  make_r_dir 4.6.1
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile ran"* ]]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "main: refreshes the GPG key even when rig is already current" {
  make_rig_stub "$FAKE_LATEST"
  printf '%s' "expired-key" >"$RIG_GPG_KEY_DEST"
  run main
  [ "$status" -eq 0 ]
  [ "$(cat "$RIG_GPG_KEY_DEST")" = "upstream-key" ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "main: upgrades even when stow-rprofile fails" {
  make_r_dir 4.6.1
  make_failing_stow_stub
  # The real script, not `run main`: bats disables errexit inside `run`, so a
  # sourced function cannot reproduce a `set -e` abort.
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile failed"* ]]
  [[ "$output" == *"apt-get update"* ]]
  [[ "$output" == *"Previous version was: ${FAKE_OUTDATED}"* ]]
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

@test "exits 1 when gh is missing" {
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"
  rm -f "$TMPDIR_TEST/bin/gh"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required"* ]]
}
