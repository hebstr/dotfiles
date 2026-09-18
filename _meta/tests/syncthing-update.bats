#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/syncthing-update

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/syncthing-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# The script writes to /etc/apt paths via `sudo install`. Tests redirect
# those paths to a sandboxed ${APTROOT} via env overrides on the script
# (KEYRING, SOURCES_LIST, PREFS_FILE). Stubs replace external commands so
# no real network / apt / sudo calls occur.

_create_stubs() {
  # curl ─ logs args, writes a fake key body to -o (stdout without it);
  # ${CURL_RC} simulates a failed fetch
  cat >"${STUBS}/curl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/curl.log"
[ "\${CURL_RC:-0}" -eq 0 ] || exit "\${CURL_RC}"
out=/dev/stdout
while [ \$# -gt 0 ]; do
    [ "\$1" = -o ] && { out="\$2"; shift; }
    shift
done
printf 'FAKE-GPG-KEY\n' > "\$out"
EOF

  # sudo ─ -v / -n behave like a cached credential; otherwise exec the rest
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "${STUBS}/sudo.log"
case "\$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  "\$@" ;;
esac
EOF

  # install ─ supports the forms the script uses:
  #   install -d -m MODE DIR
  #   install -m MODE -o USER -g GROUP SRC DEST   (SRC: temp key file or /dev/stdin)
  cat >"${STUBS}/install" <<'EOF'
#!/usr/bin/env bash
mode_d=0
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        -d) mode_d=1; shift ;;
        -m|-o|-g) shift 2 ;;
        *) positional+=("$1"); shift ;;
    esac
done
if [ "$mode_d" = 1 ]; then
    for d in "${positional[@]}"; do
        mkdir -p "$d" 2>/dev/null || true
    done
    exit 0
fi
src="${positional[0]}"
dest="${positional[1]}"
if [ "$src" = "/dev/stdin" ]; then
    cat > "$dest"
else
    cp "$src" "$dest"
fi
EOF

  # apt-get ─ logs args; per-test ${APT_EXIT_<verb>} overrides exit codes
  cat >"${STUBS}/apt-get" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/apt.log"
case "\$1" in
    update)  exit "\${APT_EXIT_UPDATE:-0}" ;;
    install) exit "\${APT_EXIT_INSTALL:-0}" ;;
    *)       exit 0 ;;
esac
EOF

  # syncthing ─ prints a fake version string for the final --version call
  cat >"${STUBS}/syncthing" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && printf 'syncthing v1.27.0 fake\n'
exit 0
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  APTROOT="$(mktemp -d)"
  export STUBS APTROOT

  mkdir -p "${APTROOT}/keyrings" \
    "${APTROOT}/sources.list.d" \
    "${APTROOT}/preferences.d"

  export KEY_URL="https://example.test/release-key.gpg"
  export KEYRING="${APTROOT}/keyrings/syncthing-archive-keyring.gpg"
  export SOURCES_LIST="${APTROOT}/sources.list.d/syncthing.list"
  export PREFS_FILE="${APTROOT}/preferences.d/syncthing.pref"
  export CHANNEL="stable-v2"

  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}" "${APTROOT}"
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 and reports error when curl is not available" {
  # Restrict PATH to STUBS only, then remove the curl stub so the
  # `command -v curl` check fails. $BASH is an absolute path so the
  # interpreter itself remains reachable.
  rm "${STUBS}/curl"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl is required"* ]]
}

# ─── sudo credential cache ──────────────────────────────────────────────────

@test "invokes sudo -v before any file operation" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STUBS}/sudo.log" ]
  [ "$(head -n1 "${STUBS}/sudo.log")" = "-v" ]
}

# ─── keyring refresh (fetched every run, installed when it differs) ─────────

@test "installs the keyring when the file is absent" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Syncthing GPG key"* ]]
  [ -s "${KEYRING}" ]
  grep -q 'FAKE-GPG-KEY' "${KEYRING}"
}

@test "replaces a keyring whose content differs from upstream" {
  printf 'EXPIRED-KEY\n' >"${KEYRING}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Syncthing GPG key"* ]]
  grep -q 'FAKE-GPG-KEY' "${KEYRING}"
}

@test "leaves a keyring identical to upstream untouched" {
  printf 'FAKE-GPG-KEY\n' >"${KEYRING}"
  printf 'deb existing\n' >"${SOURCES_LIST}"
  printf 'Pin: existing\n' >"${PREFS_FILE}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installing Syncthing GPG key"* ]]
  run ! grep -qx install "${STUBS}/sudo.log"
}

@test "a failed key fetch warns, keeps the keyring and still updates" {
  printf 'EXPIRED-KEY\n' >"${KEYRING}"
  export CURL_RC=22
  export TMPDIR="${APTROOT}/tmp"
  mkdir -p "$TMPDIR"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Could not fetch"* ]]
  grep -q '^EXPIRED-KEY$' "${KEYRING}"
  grep -q '^install -y syncthing$' "${STUBS}/apt.log"
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "passes KEY_URL to curl when fetching the key" {
  export KEY_URL="https://override.test/key.gpg"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STUBS}/curl.log" ]
  grep -q 'https://override.test/key.gpg' "${STUBS}/curl.log"
}

@test "fetches the key on every run, even when the keyring exists" {
  printf 'FAKE-GPG-KEY\n' >"${KEYRING}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STUBS}/curl.log" ]
}

# ─── sources.list install (absent → install, present → skip) ────────────────

@test "writes the sources.list entry when absent" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Adding apt.syncthing.net"* ]]
  [ -s "${SOURCES_LIST}" ]
  grep -q 'deb \[signed-by=' "${SOURCES_LIST}"
  grep -q 'apt.syncthing.net' "${SOURCES_LIST}"
  grep -q 'syncthing stable-v2' "${SOURCES_LIST}"
}

@test "embeds the resolved KEYRING path in the sources.list entry" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qF "signed-by=${KEYRING}" "${SOURCES_LIST}"
}

@test "honors a CHANNEL override in the sources.list content" {
  export CHANNEL="release"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -q 'syncthing release$' "${SOURCES_LIST}"
}

@test "skips the sources.list write when the file already has content" {
  printf 'deb http://existing/ stable main\n' >"${SOURCES_LIST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Adding apt.syncthing.net"* ]]
  grep -q '^deb http://existing/ stable main$' "${SOURCES_LIST}"
}

# ─── preferences pin (absent → install, present → skip) ─────────────────────

@test "writes the apt preferences pin when absent" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pinning apt.syncthing.net"* ]]
  [ -s "${PREFS_FILE}" ]
  grep -q '^Package: \*$' "${PREFS_FILE}"
  grep -q '^Pin: origin apt.syncthing.net$' "${PREFS_FILE}"
  grep -q '^Pin-Priority: 990$' "${PREFS_FILE}"
}

@test "skips the preferences write when the file already has content" {
  printf 'Package: *\nPin: origin other\nPin-Priority: 100\n' >"${PREFS_FILE}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Pinning apt.syncthing.net"* ]]
  grep -q '^Pin: origin other$' "${PREFS_FILE}"
}

# ─── apt-get invocations ────────────────────────────────────────────────────

@test "refreshes only the Syncthing source, failing on any error" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qxF "update -o Dir::Etc::SourceList=${SOURCES_LIST} -o Dir::Etc::SourceParts=- --no-list-cleanup --error-on=any" "${STUBS}/apt.log"
}

@test "invokes apt-get install -y syncthing" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -q '^install -y syncthing$' "${STUBS}/apt.log"
}

@test "non-zero apt-get update aborts before the install step" {
  export APT_EXIT_UPDATE=1
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  run ! grep -q '^install -y syncthing$' "${STUBS}/apt.log"
}

@test "non-zero apt-get install propagates as script failure" {
  export APT_EXIT_INSTALL=2
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  grep -q '^install -y syncthing$' "${STUBS}/apt.log"
}

# ─── final version print ────────────────────────────────────────────────────

@test "prints syncthing --version at the end" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"syncthing v1.27.0 fake"* ]]
}

# ─── idempotent path: all sentinels present ─────────────────────────────────

@test "fully provisioned host: skips all three writes but still runs apt" {
  printf 'FAKE-GPG-KEY\n' >"${KEYRING}"
  printf 'deb existing\n' >"${SOURCES_LIST}"
  printf 'Pin: existing\n' >"${PREFS_FILE}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installing Syncthing GPG key"* ]]
  [[ "$output" != *"Adding apt.syncthing.net"* ]]
  [[ "$output" != *"Pinning apt.syncthing.net"* ]]
  grep -q '^update ' "${STUBS}/apt.log"
  grep -q '^install -y syncthing$' "${STUBS}/apt.log"
}
