#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/anki-update

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/anki-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# All stubs are created once in setup(). Behaviour is driven by exported env
# vars that the stubs read at runtime, so individual tests only need to
# override the relevant variable before calling `run`.
#
# Variables and their defaults:
#   CURL_API_RESPONSE       JSON array returned for the GitHub releases API call
#   CURL_CHECKSUMS_CONTENT  content written to the downloaded checksums file
#   SHA256SUM_HASH          first field printed by the sha256sum stub
#   TAR_STUB_MODE           full | no_install
#   ANKI_MARKER             path used by the script instead of the system default

_create_stubs() {
  # curl ─ API call writes to stdout; downloads write to the -o file
  cat >"${STUBS}/curl" <<'EOF'
#!/usr/bin/env bash
output_file=""
next_o=0
for arg in "$@"; do
    [ "$next_o" = 1 ] && { output_file="$arg"; next_o=0; continue; }
    [ "$arg" = "-o" ] && next_o=1
done
if [[ "$*" == *"api.github.com"* ]]; then
    printf '%s\n' "${CURL_API_RESPONSE}"
elif [ -n "$output_file" ]; then
    case "$output_file" in
        *checksums*) printf '%s\n' "${CURL_CHECKSUMS_CONTENT}" > "$output_file" ;;
        *)           touch "$output_file" ;;
    esac
fi
exit 0
EOF

  # sudo ─ -v succeeds (initial auth); -n exits 1 so the keepalive loop
  # terminates immediately; other invocations exec the full argument list
  # without shifting, so `sudo apt-get install ...` runs the apt-get stub
  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  exec "$@" ;;
esac
EOF

  # sleep ─ returns immediately so the keepalive loop does not orphan a
  # 60-second process that would hold the bats stdout pipe open
  cat >"${STUBS}/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  # apt-get ─ no-op; prerequisites are assumed available
  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  # sha256sum ─ prints a hash line; awk in the script extracts the first field
  cat >"${STUBS}/sha256sum" <<'EOF'
#!/usr/bin/env bash
printf '%s  fake\n' "${SHA256SUM_HASH:-aabbccdd}"
EOF

  # tar ─ populates the staging dir per TAR_STUB_MODE instead of extracting
  cat >"${STUBS}/tar" <<'EOF'
#!/usr/bin/env bash
target_dir=""
next_c=0
for arg in "$@"; do
    [ "$next_c" = 1 ] && { target_dir="$arg"; next_c=0; continue; }
    [ "$arg" = "-C" ] && next_c=1
done
[ -z "$target_dir" ] && exit 0
mkdir -p "$target_dir"
case "${TAR_STUB_MODE:-full}" in
    full)
        mkdir -p "$target_dir/anki-25.02"
        printf '#!/usr/bin/env bash\nexit 0\n' > "$target_dir/anki-25.02/install.sh"
        chmod +x "$target_dir/anki-25.02/install.sh"
        ;;
    no_install)
        mkdir -p "$target_dir/anki-25.02"
        ;;
esac
exit 0
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_MARKER="$(mktemp)"
  export STUBS FAKE_MARKER

  export CURL_API_RESPONSE='[{"tag_name":"25.02","assets":[{"name":"linux.tar.zst"}]}]'
  export CURL_CHECKSUMS_CONTENT='aabbccdd  anki-launcher-25.02-linux.tar.zst'
  export SHA256SUM_HASH=aabbccdd
  export TAR_STUB_MODE=full
  export ANKI_MARKER="${FAKE_MARKER}"

  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}"
  rm -f "${FAKE_MARKER}"
}

# ─── dependency checks ───────────────────────────────────────────────────────

@test "exits 1 and reports error when jq is not available" {
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}

@test "exits 1 and reports error when curl is not available" {
  cat >"${STUBS}/jq" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${STUBS}/jq"
  rm "${STUBS}/curl"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl is required"* ]]
}

# ─── version resolution ─────────────────────────────────────────────────────

@test "exits 1 when GitHub API returns an empty tag_name" {
  export CURL_API_RESPONSE='[{"tag_name":"","assets":[{"name":"x"}]}]'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "exits 1 when GitHub API returns no releases with assets" {
  export CURL_API_RESPONSE='[]'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "prints the version resolved from the GitHub API" {
  printf '25.02\n' >"${FAKE_MARKER}"
  run bash "${SCRIPT}"
  [[ "$output" == *"Latest Anki launcher: 25.02"* ]]
}

# ─── up-to-date check ───────────────────────────────────────────────────────

@test "exits 0 and reports nothing-to-do when already on latest version" {
  printf '25.02\n' >"${FAKE_MARKER}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
}

@test "proceeds with install when marker file is absent" {
  rm "${FAKE_MARKER}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"nothing to do"* ]]
}

# ─── prerequisite installation ──────────────────────────────────────────────

@test "installs system prerequisites via apt-get before downloading" {
  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
printf 'apt-get %s\n' "$*"
EOF
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"apt-get"* ]]
  [[ "$output" == *"zstd"* ]]
}

# ─── checksum verification ──────────────────────────────────────────────────

@test "exits 1 when the tarball entry is absent from the checksums file" {
  export CURL_CHECKSUMS_CONTENT='aabbccdd  some-other-package.tar.gz'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum line missing"* ]]
}

@test "exits 1 when the sha256sum hash does not match the checksums file" {
  export SHA256SUM_HASH=deadbeef
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum mismatch"* ]]
}

# ─── install.sh discovery ───────────────────────────────────────────────────

@test "exits 1 when install.sh is absent from the extracted archive" {
  export TAR_STUB_MODE=no_install
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"install.sh missing"* ]]
}

# ─── successful install ─────────────────────────────────────────────────────

@test "exits 0 on a successful install" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
}

@test "writes the new version to the marker file on success" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(cat "${FAKE_MARKER}")" = "25.02" ]
}

@test "prints the installed version on success" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed Anki launcher: 25.02"* ]]
}

@test "prints previous version when upgrading from a known version" {
  printf '24.04\n' >"${FAKE_MARKER}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous launcher version: 24.04"* ]]
}

@test "omits previous version line when marker file was absent" {
  rm "${FAKE_MARKER}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Previous launcher version"* ]]
}
