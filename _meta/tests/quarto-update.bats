#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/quarto-update

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/quarto-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# All stubs are created once in setup(). Behaviour is driven by exported env
# vars that the stubs read at runtime, so individual tests only need to
# override the relevant variable before calling `run`.
#
# Variables and their defaults:
#   CURL_API_RESPONSE      JSON body returned for the GitHub releases/latest call
#   CURL_CHECKSUMS_CONTENT line(s) written to the checksums file
#   UNAME_ARCH             string returned by `uname -m`
#   QUARTO_CURRENT_VERSION version string printed by `quarto --version`
#   SHA256SUM_EXIT_CODE    exit code from the sha256sum stub (0 or 1)
#   TAR_STUB_MODE          full | no_binary | not_executable | failing_binary

_create_stubs() {
  # curl ─ API call writes to stdout; downloads write to -o <file>
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

  # uname ─ ignores flags, always returns UNAME_ARCH
  cat >"${STUBS}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${UNAME_ARCH:-x86_64}"
EOF

  # quarto ─ simulates `quarto --version` output
  cat >"${STUBS}/quarto" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${QUARTO_CURRENT_VERSION:-1.9.0}"
EOF

  # sudo ─ -v succeeds (initial auth); -n exits 1 (keepalive sees expired creds
  # and terminates the loop); other invocations pass through unprivileged
  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  shift; exec "$@" ;;
esac
EOF

  # sleep ─ returns immediately so the keepalive loop does not orphan a
  # 60-second process that would hold the bats stdout pipe open
  cat >"${STUBS}/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  # sha256sum ─ discards stdin, exits with SHA256SUM_EXIT_CODE
  cat >"${STUBS}/sha256sum" <<'EOF'
#!/usr/bin/env bash
cat > /dev/null
exit "${SHA256SUM_EXIT_CODE:-0}"
EOF

  # tar ─ instead of extracting, populates the staging dir per TAR_STUB_MODE
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
        mkdir -p "$target_dir/bin"
        printf '#!/usr/bin/env bash\nprintf "1.9.37"\nexit 0\n' > "$target_dir/bin/quarto"
        chmod +x "$target_dir/bin/quarto"
        ;;
    no_binary)
        mkdir -p "$target_dir/bin"
        ;;
    not_executable)
        mkdir -p "$target_dir/bin"
        touch "$target_dir/bin/quarto"
        ;;
    failing_binary)
        mkdir -p "$target_dir/bin"
        printf '#!/usr/bin/env bash\nexit 1\n' > "$target_dir/bin/quarto"
        chmod +x "$target_dir/bin/quarto"
        ;;
esac
exit 0
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  export STUBS

  export CURL_API_RESPONSE='{"tag_name":"v1.9.37"}'
  export CURL_CHECKSUMS_CONTENT='fakehash  quarto-1.9.37-linux-amd64.tar.gz'
  export UNAME_ARCH=x86_64
  export QUARTO_CURRENT_VERSION=1.9.0
  export SHA256SUM_EXIT_CODE=0
  export TAR_STUB_MODE=full

  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}"
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 and reports error when jq is not available" {
  # Restrict PATH to STUBS only so jq is not found; $BASH gives the
  # current interpreter's absolute path, bypassing the restricted PATH.
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}

# ─── architecture detection ─────────────────────────────────────────────────

@test "exits 1 for unsupported CPU architecture" {
  export UNAME_ARCH=s390x
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture: s390x"* ]]
}

@test "proceeds past architecture check for x86_64" {
  export UNAME_ARCH=x86_64
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Unsupported architecture"* ]]
}

@test "proceeds past architecture check for aarch64" {
  export UNAME_ARCH=aarch64
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Unsupported architecture"* ]]
}

# ─── version resolution ─────────────────────────────────────────────────────

@test "exits 1 when GitHub API returns empty tag_name" {
  export CURL_API_RESPONSE='{"tag_name":""}'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "exits 1 when GitHub API returns no tag_name field" {
  export CURL_API_RESPONSE='{}'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "prints resolved version from GitHub API" {
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [[ "$output" == *"Latest Quarto release: 1.9.37"* ]]
}

# ─── up-to-date check ───────────────────────────────────────────────────────

@test "exits 0 and reports nothing-to-do when already on latest version" {
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
}

@test "proceeds with install when quarto is not installed" {
  printf '#!/usr/bin/env bash\nexit 127\n' >"${STUBS}/quarto"
  export TAR_STUB_MODE=no_binary
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" != *"nothing to do"* ]]
}

# ─── checksum verification ──────────────────────────────────────────────────

@test "exits 1 when tarball entry is absent from checksums file" {
  export CURL_CHECKSUMS_CONTENT='fakehash  some-other-package.tar.gz'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Checksum line missing"* ]]
}

@test "exits 1 when sha256sum verification fails" {
  export SHA256SUM_EXIT_CODE=1
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
}

# ─── staged binary validation ───────────────────────────────────────────────

@test "exits 1 when extracted tree is missing bin/quarto" {
  export TAR_STUB_MODE=no_binary
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing bin/quarto"* ]]
}

@test "exits 1 when extracted bin/quarto is not executable" {
  export TAR_STUB_MODE=not_executable
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing bin/quarto"* ]]
}

@test "exits 1 when staged quarto binary fails to run" {
  export TAR_STUB_MODE=failing_binary
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"fails to execute"* ]]
}
