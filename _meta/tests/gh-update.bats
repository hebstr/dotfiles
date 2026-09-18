#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

# Tests for gh-update
# Mocks: curl, uname, gh, apt-get, sudo — no real network calls, no real installs

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/gh-update"
FAKE_LATEST="2.102.0"
FAKE_OUTDATED="2.100.0"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
  export PATH="$TMPDIR_TEST/bin:$PATH"
  mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/tmp"
  export TMPDIR="$TMPDIR_TEST/tmp"

  export GH_GPG_KEY_DEST="$TMPDIR_TEST/githubcli-archive-keyring.gpg"
  export GH_APT_SOURCE_FILE="$TMPDIR_TEST/github-cli.list"

  export FAKE_LATEST
  export CURL_API_BODY="{\"tag_name\": \"v${FAKE_LATEST}\"}"
  export CURL_FAIL_ON=""
  export CHECKSUM_MODE=good
  cat >"$TMPDIR_TEST/bin/curl" <<'STUB'
#!/usr/bin/env bash
out="" url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift; out="$1" ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
printf '%s\n' "$url" >>"$TMPDIR_TEST/curl-log"
[[ -n "$CURL_FAIL_ON" && "$url" == *"$CURL_FAIL_ON"* ]] && exit 22
case "$url" in
  */releases/latest)
    printf '%s\n' "$CURL_API_BODY"
    ;;
  *.deb)
    printf 'deb payload\n' >"$out"
    ;;
  *_checksums.txt)
    name="${url##*/}"
    ver="${name#gh_}"
    ver="${ver%_checksums.txt}"
    {
      for arch in amd64 arm64; do
        deb="gh_${ver}_linux_${arch}.deb"
        if [[ "$CHECKSUM_MODE" == good ]]; then
          sum=$(printf 'deb payload\n' | sha256sum | cut -d' ' -f1)
        else
          sum=$(printf 'tampered\n' | sha256sum | cut -d' ' -f1)
        fi
        [[ "$CHECKSUM_MODE" == missing ]] && continue
        printf '%s  %s\n' "$sum" "$deb"
      done
      printf '%s  gh_%s_linux_386.deb\n' "$(printf x | sha256sum | cut -d' ' -f1)" "$ver"
    } >"$out"
    ;;
esac
exit 0
STUB
  chmod +x "$TMPDIR_TEST/bin/curl"

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

  make_gh_stub "$FAKE_OUTDATED"

  # shellcheck source=/dev/null
  source "$SCRIPT"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

make_gh_stub() {
  local version="$1"
  cat >"$TMPDIR_TEST/bin/gh" <<EOF
#!/usr/bin/env bash
echo "gh version $version (2026-09-01)"
echo "https://github.com/cli/cli/releases/tag/v$version"
EOF
  chmod +x "$TMPDIR_TEST/bin/gh"
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

@test "fetch_latest_version: returns the version from the GitHub API through curl" {
  run fetch_latest_version
  [ "$status" -eq 0 ]
  [ "$output" = "$FAKE_LATEST" ]
  [ "$(cat "$TMPDIR_TEST/curl-log")" = "https://api.github.com/repos/cli/cli/releases/latest" ]
}

@test "fetch_latest_version: exits 1 when the API has no tag" {
  export CURL_API_BODY='{"message": "API rate limit exceeded"}'
  run fetch_latest_version
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "fetch_latest_version: exits 1 when the API call fails" {
  export CURL_FAIL_ON=api.github.com
  run fetch_latest_version
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

# ---------------------------------------------------------------------------
# get_current_version
# ---------------------------------------------------------------------------

@test "get_current_version: returns the version when gh is installed" {
  run get_current_version
  [ "$status" -eq 0 ]
  [ "$output" = "$FAKE_OUTDATED" ]
}

@test "get_current_version: returns unknown when gh is broken" {
  printf '#!/usr/bin/env bash\nexit 1\n' >"$TMPDIR_TEST/bin/gh"
  chmod +x "$TMPDIR_TEST/bin/gh"
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

@test "remove_apt_repo: removes the source and then the key" {
  printf 'deb https://cli.github.com/packages stable main\n' >"$GH_APT_SOURCE_FILE"
  printf 'key' >"$GH_GPG_KEY_DEST"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [ ! -e "$GH_APT_SOURCE_FILE" ]
  [ ! -e "$GH_GPG_KEY_DEST" ]
  [ "$(cat "$TMPDIR_TEST/sudo-log")" = "$(printf 'rm -f %s\nrm -f %s' "$GH_APT_SOURCE_FILE" "$GH_GPG_KEY_DEST")" ]
}

@test "remove_apt_repo: removes a key left without its source" {
  printf 'key' >"$GH_GPG_KEY_DEST"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [ ! -e "$GH_GPG_KEY_DEST" ]
}

@test "remove_apt_repo: keeps the key when the source cannot be removed" {
  printf 'deb https://cli.github.com/packages stable main\n' >"$GH_APT_SOURCE_FILE"
  printf 'key' >"$GH_GPG_KEY_DEST"
  make_failing_sudo_rm_stub "$GH_APT_SOURCE_FILE"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not remove $GH_APT_SOURCE_FILE"* ]]
  [ -e "$GH_APT_SOURCE_FILE" ]
  [ -e "$GH_GPG_KEY_DEST" ]
}

@test "remove_apt_repo: warns and returns 0 when the key cannot be removed" {
  printf 'key' >"$GH_GPG_KEY_DEST"
  make_failing_sudo_rm_stub "$GH_GPG_KEY_DEST"
  run remove_apt_repo
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not remove $GH_GPG_KEY_DEST"* ]]
}

# ---------------------------------------------------------------------------
# do_upgrade
# ---------------------------------------------------------------------------

@test "do_upgrade: fetches the deb and the checksums from the release" {
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 0 ]
  local base="https://github.com/cli/cli/releases/download/v${FAKE_LATEST}"
  [ "$(cat "$TMPDIR_TEST/curl-log")" = "$(printf '%s\n%s' \
    "${base}/gh_${FAKE_LATEST}_linux_amd64.deb" "${base}/gh_${FAKE_LATEST}_checksums.txt")" ]
}

@test "do_upgrade: installs the verified deb through apt-get by path" {
  run do_upgrade "$FAKE_LATEST" arm64
  [ "$status" -eq 0 ]
  [[ "$(cat "$TMPDIR_TEST/sudo-log")" == "apt-get install -y /"*"/gh_${FAKE_LATEST}_linux_arm64.deb" ]]
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

@test "do_upgrade: exits 1 without installing on a checksum mismatch" {
  export CHECKSUM_MODE=bad
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum"* ]]
  [ ! -f "$TMPDIR_TEST/sudo-log" ]
}

@test "do_upgrade: exits 1 without installing when the deb has no checksum" {
  export CHECKSUM_MODE=missing
  run do_upgrade "$FAKE_LATEST" amd64
  [ "$status" -eq 1 ]
  [[ "$output" == *"No checksum"* ]]
  [ ! -f "$TMPDIR_TEST/sudo-log" ]
}

@test "do_upgrade: a failed download aborts before the install" {
  export CURL_FAIL_ON=.deb
  # The real script, not `run do_upgrade`: bats disables errexit inside `run`.
  run "$SCRIPT"
  [ "$status" -eq 22 ]
  [ ! -f "$TMPDIR_TEST/sudo-log" ]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "do_upgrade: a failed checksums download aborts before the install" {
  export CURL_FAIL_ON=_checksums.txt
  run "$SCRIPT"
  [ "$status" -eq 22 ]
  [ ! -f "$TMPDIR_TEST/sudo-log" ]
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

@test "main: skips when already on the latest version" {
  make_gh_stub "$FAKE_LATEST"
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" != *"apt-get"* ]]
  [ "$(wc -l <"$TMPDIR_TEST/curl-log")" -eq 1 ]
}

@test "main: removes the retired apt repo even when gh is already current" {
  make_gh_stub "$FAKE_LATEST"
  printf 'deb https://cli.github.com/packages stable main\n' >"$GH_APT_SOURCE_FILE"
  printf 'key' >"$GH_GPG_KEY_DEST"
  run main
  [ "$status" -eq 0 ]
  [ ! -e "$GH_APT_SOURCE_FILE" ]
  [ ! -e "$GH_GPG_KEY_DEST" ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "main: does not check the architecture when gh is already current" {
  make_gh_stub "$FAKE_LATEST"
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
  [ "$(wc -l <"$TMPDIR_TEST/curl-log")" -eq 1 ]
}

@test "main: upgrades when gh is outdated" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get install -y"*"gh_${FAKE_LATEST}_linux_amd64.deb"* ]]
  [[ "$output" == *"Previous version was: ${FAKE_OUTDATED}"* ]]
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "main: installs gh when it is absent" {
  # A stub rather than a removal: /usr/bin/gh on the PATH would answer instead.
  printf '#!/usr/bin/env bash\nexit 127\n' >"$TMPDIR_TEST/bin/gh"
  # The install stub puts gh in place, as the real package would.
  cat >"$TMPDIR_TEST/bin/apt-get" <<EOF
#!/usr/bin/env bash
printf 'apt-get %s\n' "\$*"
printf '#!/usr/bin/env bash\necho "gh version ${FAKE_LATEST} (2026-09-15)"\n' >"$TMPDIR_TEST/bin/gh"
chmod +x "$TMPDIR_TEST/bin/gh"
EOF
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Current version:   unknown"* ]]
  [[ "$output" == *"apt-get install -y"* ]]
  [[ "$output" == *"gh version ${FAKE_LATEST}"* ]]
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
  [[ "$output" == *"Latest gh release: ${FAKE_LATEST}"* ]]
  [[ "$output" == *"Current version:   ${FAKE_OUTDATED}"* ]]
}

# ---------------------------------------------------------------------------
# dependencies
# ---------------------------------------------------------------------------

@test "exits 1 when curl is missing" {
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"
  ln -sf "$(command -v jq)" "$TMPDIR_TEST/bin/jq"
  rm -f "$TMPDIR_TEST/bin/curl"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl is required"* ]]
}

@test "exits 1 when jq is missing" {
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}
