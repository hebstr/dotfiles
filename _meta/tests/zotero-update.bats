#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/zotero-update"

# ─── stub factory ───────────────────────────────────────────────────────────

_create_stubs() {
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

  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "${STUBS}/sudo.log"
case "\$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  "\$@" ;;
esac
EOF

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

  cat >"${STUBS}/apt-get" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/apt.log"
case "\$1" in
    update)  exit "\${APT_EXIT_UPDATE:-0}" ;;
    install) exit "\${APT_EXIT_INSTALL:-0}" ;;
    *)       exit 0 ;;
esac
EOF

  cat >"${STUBS}/dpkg-query" <<'EOF'
#!/usr/bin/env bash
printf '10.0.3\n'
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  APTROOT="$(mktemp -d)"
  export STUBS APTROOT

  mkdir -p "${APTROOT}/keyrings" "${APTROOT}/sources.list.d"

  export KEY_URL="https://example.test/zotero-archive-keyring.gpg"
  export KEYRING="${APTROOT}/keyrings/zotero-archive-keyring.gpg"
  export SOURCES_LIST="${APTROOT}/sources.list.d/zotero.list"
  export REPO_URL="https://example.test/apt-package-archive"

  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}" "${APTROOT}"
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 and reports error when curl is not available" {
  rm "${STUBS}/curl"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl is required"* ]]
}

# ─── sudo credential cache ──────────────────────────────────────────────────

@test "invokes sudo -v before any file operation" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(head -n1 "${STUBS}/sudo.log")" = "-v" ]
}

# ─── keyring refresh (fetched every run, installed when it differs) ─────────

@test "installs the keyring when the file is absent" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Zotero GPG key"* ]]
  grep -q 'FAKE-GPG-KEY' "${KEYRING}"
}

@test "replaces a keyring whose content differs from upstream" {
  printf 'EXPIRED-KEY\n' >"${KEYRING}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Zotero GPG key"* ]]
  grep -q 'FAKE-GPG-KEY' "${KEYRING}"
}

@test "leaves a keyring identical to upstream untouched" {
  printf 'FAKE-GPG-KEY\n' >"${KEYRING}"
  printf 'deb existing\n' >"${SOURCES_LIST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installing Zotero GPG key"* ]]
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
  grep -q '^install -y zotero$' "${STUBS}/apt.log"
  [ -z "$(ls -A "$TMPDIR")" ]
}

@test "passes KEY_URL to curl when fetching the key" {
  export KEY_URL="https://override.test/key.gpg"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -q 'https://override.test/key.gpg' "${STUBS}/curl.log"
}

@test "fetches the key on every run, even when the keyring exists" {
  printf 'FAKE-GPG-KEY\n' >"${KEYRING}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STUBS}/curl.log" ]
}

# ─── sources.list install (absent → install, present → skip) ────────────────

@test "writes the flat-repository sources.list entry when absent" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Adding the zotero-deb repository"* ]]
  grep -qxF "deb [signed-by=${KEYRING} by-hash=force] ${REPO_URL} ./" "${SOURCES_LIST}"
}

@test "skips the sources.list write when the file already has content" {
  printf 'deb http://existing/ ./\n' >"${SOURCES_LIST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Adding the zotero-deb repository"* ]]
  grep -qx 'deb http://existing/ ./' "${SOURCES_LIST}"
}

# ─── apt-get invocations ────────────────────────────────────────────────────

@test "refreshes only the Zotero source, failing on any error" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qxF "update -o Dir::Etc::SourceList=${SOURCES_LIST} -o Dir::Etc::SourceParts=- --no-list-cleanup --error-on=any" "${STUBS}/apt.log"
}

@test "invokes apt-get install -y zotero" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  grep -qx 'install -y zotero' "${STUBS}/apt.log"
}

@test "non-zero apt-get update aborts before the install step" {
  export APT_EXIT_UPDATE=1
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  run ! grep -qx 'install -y zotero' "${STUBS}/apt.log"
}

@test "non-zero apt-get install propagates as script failure" {
  export APT_EXIT_INSTALL=2
  run bash "${SCRIPT}"
  [ "$status" -ne 0 ]
  grep -qx 'install -y zotero' "${STUBS}/apt.log"
}

# ─── final version print ────────────────────────────────────────────────────

@test "prints the installed package version at the end" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "${lines[-1]}" == "zotero 10.0.3" ]]
}

# ─── idempotent path: all sentinels present ─────────────────────────────────

@test "fully provisioned host: skips both writes but still runs apt" {
  printf 'FAKE-GPG-KEY\n' >"${KEYRING}"
  printf 'deb existing\n' >"${SOURCES_LIST}"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installing Zotero GPG key"* ]]
  [[ "$output" != *"Adding the zotero-deb repository"* ]]
  grep -q '^update ' "${STUBS}/apt.log"
  grep -qx 'install -y zotero' "${STUBS}/apt.log"
}
