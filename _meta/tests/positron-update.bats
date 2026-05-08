#!/usr/bin/env bats

# Tests for positron-update
# Mocks: curl, dpkg, dpkg-query, positron, sha256sum, sudo — no real network calls, no real installs

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/positron-update"

FAKE_LATEST="2024.09.1-607"
FAKE_OLD_VER="Positron 2024.08.0 build 500"
FAKE_HASH="deadbeef1234abcd5678deadbeef1234abcd5678deadbeef1234abcd5678abcd"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
  export PATH="$TMPDIR_TEST/bin:$PATH"
  mkdir -p "$TMPDIR_TEST/bin"

  _make_curl_stub amd64
  _make_dpkg_stub amd64

  cat >"$TMPDIR_TEST/bin/dpkg-query" <<'STUB'
#!/usr/bin/env bash
printf '2024.08.0-500\n'
STUB
  chmod +x "$TMPDIR_TEST/bin/dpkg-query"

  _make_positron_stub "$FAKE_OLD_VER"
  _make_sha256sum_stub "$FAKE_HASH"

  cat >"$TMPDIR_TEST/bin/sudo" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-v" ]]; then exit 0; fi
exec "$@"
STUB
  chmod +x "$TMPDIR_TEST/bin/sudo"

  cat >"$TMPDIR_TEST/bin/apt-get" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$TMPDIR_TEST/bin/apt-get"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# _make_curl_stub ARCH
# Stubs curl to:
#   - Return GitHub API JSON when called without -o
#   - Write checksums JSON keyed by the correct deb filename for ARCH when URL contains "checksums"
#   - Touch an empty file for deb download calls
_make_curl_stub() {
  local arch="${1:-amd64}"
  local deb_arch
  case "$arch" in
  amd64) deb_arch="x64" ;;
  arm64) deb_arch="arm64" ;;
  *) deb_arch="x64" ;;
  esac
  cat >"$TMPDIR_TEST/bin/curl" <<EOF
#!/usr/bin/env bash
outfile="" url="" prev=""
for arg in "\$@"; do
  [[ "\$prev" == "-o" ]] && outfile="\$arg"
  [[ "\$arg" == https://* ]] && url="\$arg"
  prev="\$arg"
done
if [[ -z "\$outfile" ]]; then
  printf '{"tag_name":"${FAKE_LATEST}"}\n'
elif [[ "\$url" == *"checksums"* ]]; then
  printf '{"Positron-${FAKE_LATEST}-${deb_arch}.deb":"${FAKE_HASH}"}\n' >"\$outfile"
else
  touch "\$outfile"
fi
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"
}

# _make_dpkg_stub ARCH [INSTALL_EXIT_CODE]
_make_dpkg_stub() {
  local arch="${1:-amd64}" rc="${2:-0}"
  cat >"$TMPDIR_TEST/bin/dpkg" <<EOF
#!/usr/bin/env bash
case "\$1" in
  --print-architecture) printf '%s\n' "${arch}" ;;
  -i) exit ${rc} ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$TMPDIR_TEST/bin/dpkg"
}

# _make_positron_stub VERSION_STRING
# Empty string → stub exits 1, simulating positron not installed.
_make_positron_stub() {
  local ver="$1"
  if [[ -z "$ver" ]]; then
    printf '#!/usr/bin/env bash\nexit 1\n' >"$TMPDIR_TEST/bin/positron"
  else
    cat >"$TMPDIR_TEST/bin/positron" <<EOF
#!/usr/bin/env bash
printf '%s\n' "${ver}"
EOF
  fi
  chmod +x "$TMPDIR_TEST/bin/positron"
}

# _make_sha256sum_stub HASH
_make_sha256sum_stub() {
  local hash="$1"
  cat >"$TMPDIR_TEST/bin/sha256sum" <<EOF
#!/usr/bin/env bash
printf '%s  %s\n' "${hash}" "\$1"
EOF
  chmod +x "$TMPDIR_TEST/bin/sha256sum"
}

# ---------------------------------------------------------------------------
# Missing dependencies
# ---------------------------------------------------------------------------

@test "exits 1 when jq is missing" {
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}

# ---------------------------------------------------------------------------
# Architecture detection
# ---------------------------------------------------------------------------

@test "exits 1 for unsupported architecture" {
  _make_dpkg_stub "ppc64le"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture: ppc64le"* ]]
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

@test "exits 1 when GitHub API returns null version" {
  cat >"$TMPDIR_TEST/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '{"tag_name":null}\n'
STUB
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve latest Positron version"* ]]
}

@test "exits 1 when GitHub API returns empty version" {
  cat >"$TMPDIR_TEST/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '{"tag_name":""}\n'
STUB
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve latest Positron version"* ]]
}

# ---------------------------------------------------------------------------
# Up-to-date check
# ---------------------------------------------------------------------------

@test "exits 0 with message when already on latest version" {
  _make_positron_stub "Positron 2024.09.1 build 607"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" != *"Downloading"* ]]
}

@test "proceeds to download when positron is not installed" {
  local call_log="$TMPDIR_TEST/.positron_calls"
  cat >"$TMPDIR_TEST/bin/positron" <<EOF
#!/usr/bin/env bash
n=\$(( \$(cat "$call_log" 2>/dev/null || printf 0) + 1 ))
printf '%s\n' "\$n" >"$call_log"
if [ "\$n" -eq 1 ]; then exit 1; fi
printf 'Positron 2024.09.1 build 607\n'
EOF
  chmod +x "$TMPDIR_TEST/bin/positron"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloading Positron"* ]]
  [[ "$output" != *"Already on"* ]]
}

# ---------------------------------------------------------------------------
# Architecture → filename mapping
# ---------------------------------------------------------------------------

@test "downloads x64 deb for amd64 architecture" {
  # The checksums JSON is keyed by the x64 filename; wrong ARCH mapping would cause
  # a checksum-missing failure, so a clean exit 0 implicitly verifies the mapping.
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed version:"* ]]
}

@test "downloads arm64 deb for arm64 architecture" {
  _make_curl_stub arm64
  _make_dpkg_stub arm64
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed version:"* ]]
}

# ---------------------------------------------------------------------------
# Checksum verification
# ---------------------------------------------------------------------------

@test "exits 1 when checksum entry is missing from JSON" {
  cat >"$TMPDIR_TEST/bin/curl" <<EOF
#!/usr/bin/env bash
outfile="" url="" prev=""
for arg in "\$@"; do
  [[ "\$prev" == "-o" ]] && outfile="\$arg"
  [[ "\$arg" == https://* ]] && url="\$arg"
  prev="\$arg"
done
if [[ -z "\$outfile" ]]; then
  printf '{"tag_name":"${FAKE_LATEST}"}\n'
elif [[ "\$url" == *"checksums"* ]]; then
  printf '{}\n' >"\$outfile"
else
  touch "\$outfile"
fi
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum entry missing"* ]]
}

@test "exits 1 on checksum mismatch" {
  _make_sha256sum_stub "0000000000000000000000000000000000000000000000000000000000000000"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum mismatch"* ]]
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------

@test "exits 0 and shows installed version and rollback hint on success" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing via dpkg"* ]]
  [[ "$output" == *"Installed version:"* ]]
  [[ "$output" == *"Previous version was: 2024.08.0-500"* ]]
  [[ "$output" == *"To roll back:"* ]]
  [[ "$output" == *"positron=2024.08.0-500"* ]]
}

@test "exits 0 when dpkg fails but apt-get recovers dependencies" {
  _make_dpkg_stub amd64 1
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dpkg install failed"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

@test "exits 1 when dpkg fails and apt-get cannot fix dependencies" {
  _make_dpkg_stub amd64 1
  cat >"$TMPDIR_TEST/bin/apt-get" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
  chmod +x "$TMPDIR_TEST/bin/apt-get"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Dependency fix failed"* ]]
}
