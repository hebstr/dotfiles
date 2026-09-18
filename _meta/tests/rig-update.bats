#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

# Tests for rig-update
# Mocks: gh, uname, rig, apt-get, sudo — no real network calls, no real installs

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
  mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/tmp"
  export TMPDIR="$TMPDIR_TEST/tmp"

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

  export FAKE_LATEST
  export GH_DOWNLOAD_MODE=one
  export GH_DOWNLOAD_RC=0
  cat >"$TMPDIR_TEST/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  api)
    printf '%s\n' "$FAKE_LATEST"
    ;;
  release)
    printf '%s\n' "$*" >>"$TMPDIR_TEST/gh-download-args"
    ((GH_DOWNLOAD_RC == 0)) || exit "$GH_DOWNLOAD_RC"
    dir="" pattern=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -D) shift; dir="$1" ;;
        -p) shift; pattern="$1" ;;
      esac
      shift
    done
    case "$GH_DOWNLOAD_MODE" in
      one) : >"$dir/${pattern//\*/1}" ;;
      two) : >"$dir/${pattern//\*/1}"; : >"$dir/${pattern//\*/2}" ;;
    esac
    ;;
esac
exit 0
STUB
  chmod +x "$TMPDIR_TEST/bin/gh"

  export UNAME_ARCH=x86_64
  cat >"$TMPDIR_TEST/bin/uname" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$UNAME_ARCH"
STUB
  chmod +x "$TMPDIR_TEST/bin/uname"

  export APT_RC=0
  cat >"$TMPDIR_TEST/bin/apt-get" <<'STUB'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*"
exit "$APT_RC"
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

make_failing_sudo_rm_stub() {
  local target="$1"
  cat >"$TMPDIR_TEST/bin/sudo" <<STUB
#!/usr/bin/env bash
[[ "\$1" == rm && "\$*" == *"$target"* ]] && exit 1
exec "\$@"
STUB
  chmod +x "$TMPDIR_TEST/bin/sudo"
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
# deb_arch
# ---------------------------------------------------------------------------

@test "deb_arch: maps x86_64 to amd64" {
  run deb_arch
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]
}

@test "deb_arch: maps aarch64 to arm64" {
  export UNAME_ARCH=aarch64
  run deb_arch
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

@test "deb_arch: exits 1 on an unsupported architecture" {
  export UNAME_ARCH=riscv64
  run deb_arch
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture: riscv64"* ]]
}

# ---------------------------------------------------------------------------
# remove_apt_repo
# ---------------------------------------------------------------------------

@test "remove_apt_repo: no sudo and no output when neither file exists" {
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -f "$TMPDIR_TEST/sudo-log" ]
}

@test "remove_apt_repo: removes the source and the key" {
  printf 'deb http://rig.r-pkg.org/deb rig main\n' >"$RIG_APT_SOURCE_FILE"
  printf 'key' >"$RIG_GPG_KEY_DEST"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [ ! -e "$RIG_APT_SOURCE_FILE" ]
  [ ! -e "$RIG_GPG_KEY_DEST" ]
  [[ "$output" == *"$RIG_APT_SOURCE_FILE"* ]]
  [[ "$output" == *"$RIG_GPG_KEY_DEST"* ]]
  [ "$(cat "$TMPDIR_TEST/sudo-log")" = "$(printf 'rm -f %s\nrm -f %s' "$RIG_APT_SOURCE_FILE" "$RIG_GPG_KEY_DEST")" ]
}

@test "remove_apt_repo: removes a key left without its source" {
  printf 'key' >"$RIG_GPG_KEY_DEST"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [ ! -e "$RIG_GPG_KEY_DEST" ]
}

@test "remove_apt_repo: keeps the key when the source cannot be removed" {
  printf 'deb http://rig.r-pkg.org/deb rig main\n' >"$RIG_APT_SOURCE_FILE"
  printf 'key' >"$RIG_GPG_KEY_DEST"
  make_failing_sudo_rm_stub "$RIG_APT_SOURCE_FILE"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not remove $RIG_APT_SOURCE_FILE"* ]]
  [ -e "$RIG_APT_SOURCE_FILE" ]
  [ -e "$RIG_GPG_KEY_DEST" ]
}

@test "remove_apt_repo: warns and returns 0 when the key cannot be removed" {
  printf 'key' >"$RIG_GPG_KEY_DEST"
  make_failing_sudo_rm_stub "$RIG_GPG_KEY_DEST"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not remove $RIG_GPG_KEY_DEST"* ]]
}

# ---------------------------------------------------------------------------
# do_upgrade
# ---------------------------------------------------------------------------

@test "do_upgrade: downloads the release deb for the architecture" {
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 0 ]
  local args
  args=$(cat "$TMPDIR_TEST/gh-download-args")
  [[ "$args" == "release download v${FAKE_LATEST} "* ]]
  [[ "$args" == *"-R r-lib/rig"* ]]
  [[ "$args" == *"-p r-rig_${FAKE_LATEST}-*_amd64.deb"* ]]
}

@test "do_upgrade: installs the downloaded deb through apt-get by path" {
  run do_upgrade "$FAKE_LATEST" arm64
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get install -y /"*"/r-rig_${FAKE_LATEST}-1_arm64.deb"* ]]
  [[ "$(cat "$TMPDIR_TEST/sudo-log")" == "apt-get install -y "*"r-rig_${FAKE_LATEST}-1_arm64.deb" ]]
}

@test "do_upgrade: never refreshes an apt index" {
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 0 ]
  [[ "$output" != *"apt-get update"* ]]
}

@test "do_upgrade: removes its temporary directory" {
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "do_upgrade: exits 1 without installing when no deb was downloaded" {
  export GH_DOWNLOAD_MODE=none
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 1 ]
  [[ "$output" == *"found 0"* ]]
  [[ "$output" != *"apt-get install"* ]]
}

@test "do_upgrade: exits 1 without installing when several debs match" {
  export GH_DOWNLOAD_MODE=two
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 1 ]
  [[ "$output" == *"found 2"* ]]
  [[ "$output" != *"apt-get install"* ]]
}

@test "do_upgrade: a failed download aborts before the install" {
  export GH_DOWNLOAD_RC=1
  # The real script, not `run do_upgrade`: bats disables errexit inside `run`.
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" != *"apt-get install"* ]]
  [ -z "$(ls -A "$TMPDIR")" ]
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
  [ ! -f "$TMPDIR_TEST/gh-download-args" ]
}

@test "main: relinks Rprofile.site even when rig is already current" {
  make_rig_stub "$FAKE_LATEST"
  make_r_dir 4.6.1
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile ran"* ]]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "main: removes the retired apt repo even when rig is already current" {
  make_rig_stub "$FAKE_LATEST"
  printf 'deb http://rig.r-pkg.org/deb rig main\n' >"$RIG_APT_SOURCE_FILE"
  printf 'key' >"$RIG_GPG_KEY_DEST"
  run main
  [ "$status" -eq 0 ]
  [ ! -e "$RIG_APT_SOURCE_FILE" ]
  [ ! -e "$RIG_GPG_KEY_DEST" ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "main: does not check the architecture when rig is already current" {
  make_rig_stub "$FAKE_LATEST"
  export UNAME_ARCH=riscv64
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "main: fails before downloading on an unsupported architecture" {
  export UNAME_ARCH=riscv64
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture"* ]]
  [ ! -f "$TMPDIR_TEST/gh-download-args" ]
}

@test "main: upgrades even when stow-rprofile fails" {
  make_r_dir 4.6.1
  make_failing_stow_stub
  # The real script, not `run main`: bats disables errexit inside `run`, so a
  # sourced function cannot reproduce a `set -e` abort.
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stow-rprofile failed"* ]]
  [[ "$output" == *"apt-get install -y"* ]]
  [[ "$output" == *"Previous version was: ${FAKE_OUTDATED}"* ]]
}

@test "main: upgrades when rig is outdated" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get install -y"*"r-rig_${FAKE_LATEST}-1_amd64.deb"* ]]
  [[ "$output" == *"Previous version was: ${FAKE_OUTDATED}"* ]]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "main: upgrades with the arm64 deb on aarch64" {
  export UNAME_ARCH=aarch64
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"r-rig_${FAKE_LATEST}-1_arm64.deb"* ]]
}

@test "main: a failed install exits with apt's status" {
  export APT_RC=100
  run "$SCRIPT"
  [ "$status" -eq 100 ]
  [[ "$output" != *"Previous version was"* ]]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "main: prints latest and current versions" {
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest rig release: ${FAKE_LATEST}"* ]]
  [[ "$output" == *"Current version:    ${FAKE_OUTDATED}"* ]]
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
