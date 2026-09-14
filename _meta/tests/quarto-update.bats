#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/quarto-update

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/quarto-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# All stubs are created once in setup(). Behaviour is driven by exported env
# vars that the stubs read at runtime, so individual tests only need to
# override the relevant variable before calling `run`.
#
# Variables (defaults set in setup() or inside each stub):
#   GH_API_OUTPUT          string returned by gh api --jq for the releases/latest call
#   CURL_CHECKSUMS_CONTENT line(s) written to the checksums file
#   UNAME_ARCH             string returned by `uname -m`
#   QUARTO_CURRENT_VERSION version printed by the installed quarto under
#                          QUARTO_PREFIX (and by a decoy quarto on PATH)
#   SHA256SUM_EXIT_CODE    exit code from the sha256sum stub (0 or 1)
#   TAR_STUB_MODE          full | no_binary | not_executable | failing_binary
#   MV_FAIL_ON_SOURCE      substring: mv fails when its source path contains it
#   MV_FAIL_PARTIAL        1: that failing mv first leaves a partial destination
#
# The script reads two overridable paths, both pointed into a per-test ROOT:
#   QUARTO_PREFIX          install tree (default /opt/quarto), populated by
#                          _install_fake_prefix; remove it to simulate a first install
#   QUARTO_BIN_LINK        PATH link (default /usr/local/bin/quarto)

_create_stubs() {
  # gh ─ `gh api ... --jq ...` returns the resolved tag (post-jq output)
  cat >"${STUBS}/gh" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "api" ]; then
    printf '%s\n' "${GH_API_OUTPUT}"
fi
exit 0
EOF

  # curl ─ downloads write to -o <file>
  cat >"${STUBS}/curl" <<'EOF'
#!/usr/bin/env bash
output_file=""
next_o=0
for arg in "$@"; do
    [ "$next_o" = 1 ] && { output_file="$arg"; next_o=0; continue; }
    [ "$arg" = "-o" ] && next_o=1
done
if [ -n "$output_file" ]; then
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

  # quarto ─ decoy on PATH, standing in for Positron's bundled copy; the
  # script must never read the installed version from it
  cat >"${STUBS}/quarto" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${QUARTO_CURRENT_VERSION:-1.9.0}"
EOF

  # sudo ─ -v succeeds (initial auth); -n exits 1 (keepalive sees expired creds
  # and terminates the loop); chown is logged to SUDO_CHOWN_LOG, since it cannot
  # run unprivileged; other invocations run the command unprivileged
  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    chown) printf '%s\n' "$*" >>"${SUDO_CHOWN_LOG}"; exit 0 ;;
    *)  exec "$@" ;;
esac
EOF

  # mv ─ real mv, except it fails when the source matches MV_FAIL_ON_SOURCE;
  # with MV_FAIL_PARTIAL=1 it first leaves a partial destination, as an
  # interrupted cross-filesystem copy does
  cat >"${STUBS}/mv" <<'EOF'
#!/usr/bin/env bash
if [ -n "${MV_FAIL_ON_SOURCE:-}" ] && [[ "${1:-}" == *"${MV_FAIL_ON_SOURCE}"* ]]; then
    [ "${MV_FAIL_PARTIAL:-0}" = 1 ] && mkdir -p "${2}/bin"
    echo "mv stub: refusing to move $1" >&2
    exit 1
fi
exec /bin/mv "$@"
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

_install_fake_prefix() {
  mkdir -p "${QUARTO_PREFIX}/bin"
  cat >"${QUARTO_PREFIX}/bin/quarto" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${QUARTO_CURRENT_VERSION:-1.9.0}"
EOF
  chmod +x "${QUARTO_PREFIX}/bin/quarto"
}

setup() {
  STUBS="$(mktemp -d)"
  export STUBS
  ROOT="$(mktemp -d)"
  export ROOT

  export GH_API_OUTPUT='1.9.37'
  export CURL_CHECKSUMS_CONTENT='fakehash  quarto-1.9.37-linux-amd64.tar.gz'
  export UNAME_ARCH=x86_64
  export QUARTO_CURRENT_VERSION=1.9.0
  export SHA256SUM_EXIT_CODE=0
  export TAR_STUB_MODE=full
  export MV_FAIL_ON_SOURCE=
  export MV_FAIL_PARTIAL=0
  export SUDO_CHOWN_LOG="${ROOT}/sudo-chown.log"
  export QUARTO_PREFIX="${ROOT}/opt/quarto"
  export QUARTO_BIN_LINK="${ROOT}/usr-local-bin/quarto"
  mkdir -p "${ROOT}/usr-local-bin"

  _create_stubs
  _install_fake_prefix
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}" "${ROOT}"
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 and reports error when gh is not available" {
  # Restrict PATH to STUBS only, minus gh, so the guard cannot be satisfied
  # from /usr/bin; $BASH gives the current interpreter's absolute path,
  # bypassing the restricted PATH.
  rm -f "${STUBS}/gh"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required"* ]]
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
  export GH_API_OUTPUT=''
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "exits 1 when GitHub API returns a literal null tag" {
  export GH_API_OUTPUT='null'
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve"* ]]
}

@test "prints resolved version from GitHub API" {
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest Quarto release: 1.9.37"* ]]
}

# ─── up-to-date check ───────────────────────────────────────────────────────

@test "exits 0 and reports nothing-to-do when already on latest version" {
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
}

@test "first install with a broken tarball aborts without creating the prefix" {
  rm -rf "${QUARTO_PREFIX}"
  export TAR_STUB_MODE=no_binary
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing bin/quarto"* ]]
  [ ! -e "${QUARTO_PREFIX}" ]
}

@test "reads the current version from the prefix, not from another quarto on PATH" {
  rm -rf "${QUARTO_PREFIX}"
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"nothing to do"* ]]
  [ -x "${QUARTO_PREFIX}/bin/quarto" ]
}

# ─── install and swap ───────────────────────────────────────────────────────

@test "first install creates the prefix without a backup" {
  rm -rf "${QUARTO_PREFIX}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -x "${QUARTO_PREFIX}/bin/quarto" ]
  [ "$("${QUARTO_PREFIX}/bin/quarto")" = "1.9.37" ]
  [ "$(compgen -G "${QUARTO_PREFIX}.bak-*" || true)" = "" ]
  [[ "$output" != *"Backup kept"* ]]
}

@test "upgrade keeps a backup holding the previous install" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$("${QUARTO_PREFIX}/bin/quarto")" = "1.9.37" ]
  local backup
  backup=$(compgen -G "${QUARTO_PREFIX}.bak-1.9.0-*")
  [ "$("${backup}/bin/quarto")" = "1.9.0" ]
  [[ "$output" == *"Backup kept"* ]]
}

@test "installed tree is handed to root" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qxF "chown -R root:root ${QUARTO_PREFIX}" "${SUDO_CHOWN_LOG}"
}

@test "first install keeps a backup left by an earlier failed rollback" {
  rm -rf "${QUARTO_PREFIX}"
  mkdir -p "${QUARTO_PREFIX}.bak-1.8.0-20260101-000000"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -d "${QUARTO_PREFIX}.bak-1.8.0-20260101-000000" ]
}

@test "upgrade removes older backups" {
  mkdir -p "${QUARTO_PREFIX}.bak-1.8.0-20260101-000000"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ ! -d "${QUARTO_PREFIX}.bak-1.8.0-20260101-000000" ]
}

@test "failed swap restores the previous install" {
  export MV_FAIL_ON_SOURCE=quarto-new
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"restoring"* ]]
  [ "$("${QUARTO_PREFIX}/bin/quarto")" = "1.9.0" ]
  [ "$(compgen -G "${QUARTO_PREFIX}.bak-*" || true)" = "" ]
}

@test "swap failing after a partial copy still restores the previous install" {
  export MV_FAIL_ON_SOURCE=quarto-new
  export MV_FAIL_PARTIAL=1
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [[ "$output" == *"restoring"* ]]
  [ "$("${QUARTO_PREFIX}/bin/quarto")" = "1.9.0" ]
  [ "$(compgen -G "${QUARTO_PREFIX}.bak-*" || true)" = "" ]
}

@test "failed first install leaves no prefix and attempts no restore" {
  rm -rf "${QUARTO_PREFIX}"
  export MV_FAIL_ON_SOURCE=quarto-new
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [[ "$output" != *"restoring"* ]]
  [ ! -e "${QUARTO_PREFIX}" ]
}

# ─── PATH link ──────────────────────────────────────────────────────────────

@test "creates the PATH link when it is missing" {
  rm -rf "${QUARTO_PREFIX}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -L "${QUARTO_BIN_LINK}" ]
  [ "$(readlink -f "${QUARTO_BIN_LINK}")" = "$(readlink -f "${QUARTO_PREFIX}/bin/quarto")" ]
}

@test "creates the PATH link even when quarto is already current" {
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to do"* ]]
  [ -L "${QUARTO_BIN_LINK}" ]
  [ "$(readlink -f "${QUARTO_BIN_LINK}")" = "$(readlink -f "${QUARTO_PREFIX}/bin/quarto")" ]
}

@test "repoints a PATH link that targets another quarto" {
  mkdir -p "${ROOT}/other/bin"
  printf '#!/bin/sh\n' >"${ROOT}/other/bin/quarto"
  ln -s "${ROOT}/other/bin/quarto" "${QUARTO_BIN_LINK}"
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pointing ${QUARTO_BIN_LINK}"* ]]
  [ "$(readlink -f "${QUARTO_BIN_LINK}")" = "$(readlink -f "${QUARTO_PREFIX}/bin/quarto")" ]
}

@test "leaves a correct PATH link untouched" {
  ln -s "${QUARTO_PREFIX}/bin/quarto" "${QUARTO_BIN_LINK}"
  export QUARTO_CURRENT_VERSION=1.9.37
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Pointing"* ]]
}

@test "leaves a regular file at the PATH link alone" {
  printf '#!/bin/sh\n' >"${QUARTO_BIN_LINK}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ ! -L "${QUARTO_BIN_LINK}" ]
  [[ "$output" == *"not a symlink"* ]]
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
