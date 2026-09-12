#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/rv-update
#
# The script is flat (no functions to source), so every test runs it as a
# subprocess against a stub PATH. PATH is *replaced*, not prepended: the real
# rv lives in ~/.local/bin and would otherwise answer the absence tests.

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/rv-update"
FAKE_CURRENT="0.22.2"
FAKE_LATEST="0.23.0"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs are created once in setup() and driven by exported env vars read at
# runtime, so a test only overrides the variable it cares about.
#
#   RV_VERSION        version printed by `rv --version` (empty ⇒ the stub fails)
#   GH_TAG            tag returned by `gh api --jq '.tag_name // empty'`
#   GH_EXIT           exit code of the gh stub
#   CURL_EXIT         exit code of the curl stub
#   INSTALLER_MODE    success | noop | remove | fail
#   INSTALLED_VERSION version printed by the rv the installer drops in
#
# Side effects land in $STATE: curl-args, gh-args, installer-ran, installer-path.

_create_stubs() {
  cat >"${STUBS}/rv" <<'EOF'
#!/usr/bin/env bash
[ -n "${RV_VERSION:-}" ] || exit 1
printf 'rv %s\n' "${RV_VERSION}"
EOF

  cat >"${STATE}/rv-installed" <<'EOF'
#!/usr/bin/env bash
printf 'rv %s\n' "${INSTALLED_VERSION}"
EOF

  cat >"${STUBS}/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/gh-args"
[ "${GH_EXIT:-0}" -eq 0 ] || exit "${GH_EXIT}"
printf '%s\n' "${GH_TAG}"
EOF

  # curl ─ writes the installer to the -o target instead of fetching it
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
[ -n "$output_file" ] || exit 0
cat >"$output_file" <<'INSTALLER'
#!/usr/bin/env bash
printf '%s\n' "$0" >>"${STATE}/installer-path"
printf 'installer ran\n' >>"${STATE}/installer-ran"
case "${INSTALLER_MODE:-success}" in
    success) cp "${STATE}/rv-installed" "${STUBS}/rv"; chmod +x "${STUBS}/rv" ;;
    noop)    : ;;
    remove)  rm -f "${STUBS}/rv" ;;
    fail)    printf 'installer failed\n' >&2; exit 1 ;;
esac
INSTALLER
EOF

  chmod +x "${STUBS}"/*
}

# A PATH holding only the stubs and the system binaries the script actually
# needs, so an absence test cannot be answered by /usr/bin.
_sandbox_path() {
  local sysbin="${TEST_TMP}/sysbin" cmd
  mkdir -p "${sysbin}"
  for cmd in bash mktemp awk sed cat cp rm chmod; do
    ln -sf "$(command -v "${cmd}")" "${sysbin}/${cmd}"
  done
  printf '%s' "${STUBS}:${sysbin}"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  TEST_TMP="$(mktemp -d)"
  STUBS="${TEST_TMP}/bin"
  STATE="${TEST_TMP}/state"
  mkdir -p "${STUBS}" "${STATE}"
  export TEST_TMP STUBS STATE

  export RV_VERSION="${FAKE_CURRENT}"
  export GH_TAG="v${FAKE_CURRENT}"
  export GH_EXIT=0
  export CURL_EXIT=0
  export INSTALLER_MODE=success
  export INSTALLED_VERSION="${FAKE_LATEST}"

  _create_stubs
  export PATH="${STUBS}:/usr/bin:/bin"
}

teardown() {
  rm -rf "${TEST_TMP}"
}

# ─── dependency check ───────────────────────────────────────────────────────

# gh resolves the release tag through its own embedded jq engine, so the
# script must run on a machine that has no jq at all.
@test "runs with no jq anywhere on PATH" {
  run env PATH="$(_sandbox_path)" "$BASH" "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"jq is required"* ]]
  [[ "$output" == *"is up to date."* ]]
}

# PATH is narrowed to the stub directory alone so the system gh in /usr/bin
# cannot satisfy the check; $BASH bypasses that PATH for the shebang.

@test "exits 1 when gh is absent" {
  rm -f "${STUBS}/gh"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required"* ]]
}

@test "reports the missing dependency before touching the network" {
  rm -f "${STUBS}/gh"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ ! -f "${STATE}/curl-args" ]
}

# ─── bootstrap (rv absent) ──────────────────────────────────────────────────

@test "bootstraps through the official installer when rv is absent" {
  rm -f "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rv not found on PATH"* ]]
  [ -f "${STATE}/installer-ran" ]
}

@test "reports the installed version after a bootstrap" {
  rm -f "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rv ${FAKE_LATEST} installed."* ]]
}

@test "skips the release lookup entirely when rv is absent" {
  rm -f "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ ! -f "${STATE}/gh-args" ]
}

@test "exits 1 when the bootstrap leaves rv off PATH" {
  rm -f "${STUBS}/rv"
  export INSTALLER_MODE=noop
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"rv installed, but not yet visible on PATH"* ]]
  [[ "$output" == *"Start a new shell"* ]]
}

# ─── release lookup ─────────────────────────────────────────────────────────

@test "skips the update when the API returns no tag" {
  export GH_TAG=""
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping update check (failed to query GitHub API)"* ]]
  [ ! -f "${STATE}/installer-ran" ]
}

@test "skips the update when gh itself fails" {
  export GH_EXIT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping update check"* ]]
  [ ! -f "${STATE}/installer-ran" ]
}

@test "queries the latest release of A2-ai/rv" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/gh-args")" == *"repos/A2-ai/rv/releases/latest"* ]]
}

# ─── up-to-date check ───────────────────────────────────────────────────────

@test "reports up to date and runs no installer when versions match" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rv ${FAKE_CURRENT} is up to date."* ]]
  [ ! -f "${STATE}/installer-ran" ]
}

@test "strips the leading v from the release tag before comparing" {
  export GH_TAG="v${FAKE_CURRENT}"
  export RV_VERSION="${FAKE_CURRENT}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is up to date."* ]]
}

@test "handles a tag published without the v prefix" {
  export GH_TAG="${FAKE_CURRENT}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"is up to date."* ]]
}

# ─── upgrade (rv outdated) ──────────────────────────────────────────────────

@test "upgrades when the installed version is behind" {
  export GH_TAG="v${FAKE_LATEST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rv ${FAKE_CURRENT} installed: upgrading to ${FAKE_LATEST}"* ]]
  [ -f "${STATE}/installer-ran" ]
  [[ "$output" == *"rv ${FAKE_LATEST} installed."* ]]
}

# An rv that is on PATH but cannot report a version aborts the script through
# `set -o pipefail`, before the lookup and with no message of its own.
@test "aborts silently when the installed rv cannot report its version" {
  export GH_TAG="v${FAKE_LATEST}"
  printf '#!/usr/bin/env bash\nexit 1\n' >"${STUBS}/rv"
  chmod +x "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -f "${STATE}/installer-ran" ]
}

@test "exits 1 when the upgrade leaves rv off PATH" {
  export GH_TAG="v${FAKE_LATEST}"
  export INSTALLER_MODE=remove
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"rv upgraded, but not yet visible on PATH"* ]]
  [[ "$output" == *"Start a new shell"* ]]
}

@test "aborts when the installer itself fails" {
  export GH_TAG="v${FAKE_LATEST}"
  export INSTALLER_MODE=fail
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [[ "$output" != *"installed."* ]]
}

# ─── installer download ─────────────────────────────────────────────────────

@test "fetches the installer from the A2-ai repository" {
  rm -f "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/curl-args")" == *"https://raw.githubusercontent.com/A2-ai/rv/refs/heads/main/scripts/install.sh"* ]]
}

@test "bounds the installer download with timeouts and retries" {
  rm -f "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  args="$(cat "${STATE}/curl-args")"
  [[ "$args" == *"--connect-timeout 10"* ]]
  [[ "$args" == *"--max-time 120"* ]]
  [[ "$args" == *"--retry 2"* ]]
}

@test "aborts without running an installer when the download fails" {
  rm -f "${STUBS}/rv"
  export CURL_EXIT=22
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  [ ! -f "${STATE}/installer-ran" ]
  [[ "$output" != *"installed."* ]]
}

@test "removes the downloaded installer once it has run" {
  rm -f "${STUBS}/rv"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  script_path="$(cat "${STATE}/installer-path")"
  [ -n "$script_path" ]
  [ ! -e "$script_path" ]
}
