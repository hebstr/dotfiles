#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/duckdb-update
#
# The script is flat, so every test runs it as a subprocess. Two isolations
# matter: PATH is *replaced* (the real duckdb sits in ~/.local/bin and would
# answer the version probe) and HOME is redirected, since the install target is
# "${HOME}/.local/bin/duckdb" and must never be the live binary.

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/duckdb-update"
FAKE_CURRENT="v1.4.1"
FAKE_LATEST="v1.4.2"
FAKE_STAMP="20260912-101500"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs are created once in setup() and driven by exported env vars read at
# runtime, so a test only overrides the variable it cares about.
#
#   GH_TAG           tag returned by `gh api --jq '.tag_name // ""'`
#   GH_EXIT          exit code of the gh stub
#   UNAME_ARCH       string returned by `uname -m`
#   DUCKDB_VERSION   raw `duckdb --version` line of the installed binary
#   CURL_EXIT        exit code of the curl stub
#   GUNZIP_MODE      good | broken (whether the extracted binary runs)
#
# Side effects land in $STATE: curl-args, gh-args.

_create_stubs() {
  cat >"${STUBS}/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/gh-args"
[ "${GH_EXIT:-0}" -eq 0 ] || exit "${GH_EXIT}"
printf '%s\n' "${GH_TAG}"
EOF

  cat >"${STUBS}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${UNAME_ARCH:-x86_64}"
EOF

  # duckdb ─ the copy already on PATH, probed for the current version
  cat >"${STUBS}/duckdb" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${DUCKDB_VERSION}"
EOF

  # curl ─ writes a marker to the -o target instead of downloading
  cat >"${STUBS}/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/curl-args"
output_file=""
next_o=0
for arg in "$@"; do
    [ "$next_o" = 1 ] && { output_file="$arg"; next_o=0; continue; }
    [ "$arg" = "-o" ] && next_o=1
done
[ "${CURL_EXIT:-0}" -eq 0 ] || exit "${CURL_EXIT}"
[ -n "$output_file" ] && printf 'gzipped payload\n' >"$output_file"
exit 0
EOF

  # gunzip ─ emits the extracted binary on stdout, working or not
  cat >"${STUBS}/gunzip" <<'EOF'
#!/usr/bin/env bash
case "${GUNZIP_MODE:-good}" in
    good)
        cat <<'BIN'
#!/usr/bin/env bash
printf '%s\n' "${INSTALLED_VERSION}"
BIN
        ;;
    broken)
        cat <<'BIN'
#!/usr/bin/env bash
exit 1
BIN
        ;;
esac
EOF

  # date ─ frozen, so a backup file name is assertable
  cat >"${STUBS}/date" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FROZEN_STAMP}"
EOF

  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

  chmod +x "${STUBS}"/*
}

# rm refuses the install target for the unprivileged caller and obeys sudo,
# which is what a root-owned symlink in a user-writable directory looks like.
# Every other rm call (the cleanup trap) is delegated to the real binary.
_stub_failing_rm() {
  cat >"${STUBS}/rm" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
    if [ "$arg" = "${DEST}" ]; then
        [ "${SUDO_RM:-0}" = 1 ] || exit 1
        printf 'sudo rm ran\n'
        exec /usr/bin/rm "$@"
    fi
done
exec /usr/bin/rm "$@"
EOF
  chmod +x "${STUBS}/rm"

  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
SUDO_RM=1 exec "$@"
EOF
  chmod +x "${STUBS}/sudo"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  TEST_TMP="$(mktemp -d)"
  STUBS="${TEST_TMP}/bin"
  STATE="${TEST_TMP}/state"
  BIN_DIR="${TEST_TMP}/home/.local/bin"
  mkdir -p "${STUBS}" "${STATE}" "${BIN_DIR}" "${TEST_TMP}/tmp"
  export TEST_TMP STUBS STATE BIN_DIR

  export HOME="${TEST_TMP}/home"
  export TMPDIR="${TEST_TMP}/tmp"
  export DEST="${BIN_DIR}/duckdb"

  export GH_TAG="${FAKE_LATEST}"
  export GH_EXIT=0
  export UNAME_ARCH=x86_64
  export DUCKDB_VERSION="${FAKE_CURRENT} 1a2b3c4d5e"
  export INSTALLED_VERSION="${FAKE_LATEST} 9f8e7d6c5b"
  export CURL_EXIT=0
  export GUNZIP_MODE=good
  export FROZEN_STAMP="${FAKE_STAMP}"

  _create_stubs
  export PATH="${STUBS}:/usr/bin:/bin"
}

teardown() {
  # The stub PATH is dropped first: a test may have shadowed rm, and the stub
  # would delete the directory it lives in before bats is done with it.
  PATH="/usr/bin:/bin"
  rm -rf "${TEST_TMP}"
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 when gh is absent" {
  rm -f "${STUBS}/gh"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required"* ]]
}

# ─── version resolution ─────────────────────────────────────────────────────

@test "queries the latest release of duckdb/duckdb" {
  run bash "${SCRIPT}"
  [[ "$(cat "${STATE}/gh-args")" == *"repos/duckdb/duckdb/releases/latest"* ]]
}

@test "exits 1 when the API returns an empty tag" {
  export GH_TAG=""
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve latest DuckDB version"* ]]
}

@test "exits 1 when the API returns a null tag" {
  export GH_TAG="null"
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve latest DuckDB version"* ]]
}

@test "aborts when gh itself fails" {
  export GH_EXIT=1
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [ ! -f "${STATE}/curl-args" ]
}

@test "prints the resolved release" {
  run bash "${SCRIPT}"
  [[ "$output" == *"Latest DuckDB release: ${FAKE_LATEST}"* ]]
}

# ─── architecture detection ─────────────────────────────────────────────────

@test "exits 1 for an unsupported architecture" {
  export UNAME_ARCH=s390x
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture: s390x"* ]]
}

@test "downloads the amd64 artifact on x86_64" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/curl-args")" == *"duckdb_cli-linux-amd64.gz"* ]]
}

@test "downloads the arm64 artifact on aarch64" {
  export UNAME_ARCH=aarch64
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/curl-args")" == *"duckdb_cli-linux-arm64.gz"* ]]
}

# ─── up-to-date check ───────────────────────────────────────────────────────

@test "reports nothing to do and downloads nothing when already current" {
  export DUCKDB_VERSION="${FAKE_LATEST} 1a2b3c4d5e"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}: nothing to do."* ]]
  [ ! -f "${STATE}/curl-args" ]
}

@test "treats an absent duckdb as an unknown version and proceeds" {
  rm -f "${STUBS}/duckdb"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous version was: unknown"* ]]
  [ -x "${DEST}" ]
}

@test "treats unparsable version output as unknown" {
  export DUCKDB_VERSION="not a version string"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous version was: unknown"* ]]
}

# ─── download and verification ──────────────────────────────────────────────

@test "downloads from the release tree of the resolved tag" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/curl-args")" == *"https://github.com/duckdb/duckdb/releases/download/${FAKE_LATEST}/"* ]]
}

@test "aborts without installing when the download fails" {
  export CURL_EXIT=22
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [ ! -e "${DEST}" ]
}

@test "exits 1 when the extracted binary fails to execute" {
  export GUNZIP_MODE=broken
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Extracted binary fails to execute"* ]]
}

@test "leaves an existing install untouched when the extracted binary is broken" {
  export GUNZIP_MODE=broken
  printf 'old binary\n' >"${DEST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ "$(cat "${DEST}")" = "old binary" ]
}

@test "installs the extracted binary as executable" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -x "${DEST}" ]
  [[ "$output" == *"${FAKE_LATEST}"* ]]
}

@test "removes its temporary directory on exit" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "${TMPDIR}")" ]
}

@test "removes its temporary directory when it aborts" {
  export GUNZIP_MODE=broken
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ -z "$(ls -A "${TMPDIR}")" ]
}

# ─── replacing the previous install ─────────────────────────────────────────

@test "creates no backup when nothing is installed yet" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"backed up"* ]]
  [ "$(find "${BIN_DIR}" -name 'duckdb.bak-*' | wc -l)" -eq 0 ]
}

@test "backs up a previous binary under its version and timestamp" {
  printf 'old binary\n' >"${DEST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous binary backed up to"* ]]
  [ "$(cat "${DEST}.bak-${FAKE_CURRENT}-${FAKE_STAMP}")" = "old binary" ]
}

@test "prunes stale backups once a fresh one is taken" {
  printf 'old binary\n' >"${DEST}"
  touch "${DEST}.bak-v1.3.0-20260101-000000" "${DEST}.bak-v1.2.0-20250101-000000"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${DEST}.bak-${FAKE_CURRENT}-${FAKE_STAMP}" ]
  [ "$(find "${BIN_DIR}" -name 'duckdb.bak-*' | wc -l)" -eq 1 ]
}

# Pruning is tied to taking a backup, so an install over nothing leaves older
# backups in place.
@test "keeps stale backups when no fresh backup is taken" {
  touch "${DEST}.bak-v1.3.0-20260101-000000"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${DEST}.bak-v1.3.0-20260101-000000" ]
}

@test "removes a symlink left by the old installer instead of backing it up" {
  ln -s /opt/duckdb/duckdb "${DEST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removing symlink ${DEST} -> /opt/duckdb/duckdb"* ]]
  [ ! -L "${DEST}" ]
  [ -x "${DEST}" ]
  [ "$(find "${BIN_DIR}" -name 'duckdb.bak-*' | wc -l)" -eq 0 ]
}

@test "escalates to sudo when the symlink cannot be removed unprivileged" {
  ln -s /opt/duckdb/duckdb "${DEST}"
  _stub_failing_rm
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sudo rm ran"* ]]
  [ -x "${DEST}" ]
}

@test "exits 1 when even sudo cannot remove the symlink" {
  ln -s /opt/duckdb/duckdb "${DEST}"
  _stub_failing_rm
  printf '#!/usr/bin/env bash\nexit 1\n' >"${STUBS}/sudo"
  chmod +x "${STUBS}/sudo"
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot remove ${DEST}: manual intervention required"* ]]
}

# ─── final report ───────────────────────────────────────────────────────────

@test "prints the version it just installed" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed version:"* ]]
  [[ "$output" == *"${INSTALLED_VERSION}"* ]]
}

@test "prints the version it replaced" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous version was: ${FAKE_CURRENT}"* ]]
}
