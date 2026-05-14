#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# SC2030/SC2031: bats runs each @test in its own subshell; "modification lost" warnings
# for `export` inside @test blocks don't apply — next test starts fresh by design.

# Tests for libreoffice-update
# Mocks: curl, gpg, tar, dpkg, libreoffice, sudo, apt-get, uname — no real network, no real installs

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/libreoffice-update"

FAKE_LATEST="26.2.3"
FAKE_OLD_SAME_BRANCH="26.2.0.3"
FAKE_OLD_SAME_TRIPLE="26.2.0"
FAKE_OLD_OTHER_BRANCH="25.8.7.1"
TDF_FPR="C2839ECAD9408FBE9531C3E9F434A1EFAFEEAEA3"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
  export PATH="$TMPDIR_TEST/bin:$PATH"
  mkdir -p "$TMPDIR_TEST/bin"

  _make_uname_stub x86_64
  _make_curl_stub
  _make_gpg_stub
  _make_tar_stub
  _make_dpkg_stub 0
  _make_libreoffice_stub "$FAKE_OLD_SAME_BRANCH"
  _make_sudo_stub
  _make_apt_get_stub 0
  _make_sleep_stub
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# _make_uname_stub ARCH
_make_uname_stub() {
  local arch="${1:-x86_64}"
  cat >"$TMPDIR_TEST/bin/uname" <<EOF
#!/usr/bin/env bash
[ "\${1:-}" = "-m" ] && printf '%s\n' "${arch}" && exit 0
exit 0
EOF
  chmod +x "$TMPDIR_TEST/bin/uname"
}

# _make_curl_stub
# - GET https://.../stable/  → directory listing with version hrefs (uses $TDF_LISTING if set)
# - GET ... -o <file>        → touches <file>
_make_curl_stub() {
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
outfile="" url="" prev=""
for arg in "$@"; do
  [ "$prev" = "-o" ] && outfile="$arg"
  [[ "$arg" == https://* ]] && url="$arg"
  prev="$arg"
done

if [ -n "$outfile" ]; then
  : >"$outfile"
  exit 0
fi

if [[ "$url" == */stable/ ]]; then
  if [ -n "${TDF_LISTING:-}" ]; then
    printf '%s\n' "$TDF_LISTING"
  else
    cat <<HTML
<a href="25.8.6/">25.8.6/</a>
<a href="25.8.7/">25.8.7/</a>
<a href="26.2.2/">26.2.2/</a>
<a href="26.2.3/">26.2.3/</a>
HTML
  fi
fi
exit 0
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"
}

# _make_gpg_stub
# Behavior controlled by env vars set per test:
#   GPG_LIST_RC   (default 0) — exit code of `gpg --list-keys <fpr>`
#   GPG_RECV_RC   (default 0) — exit code of `gpg --keyserver ... --recv-keys`
#   GPG_VERIFY_OK (default 1) — when 1, prints GOODSIG line for --verify; when 0, prints BADSIG
_make_gpg_stub() {
  cat >"$TMPDIR_TEST/bin/gpg" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --list-keys)
    exit "${GPG_LIST_RC:-0}"
    ;;
  --keyserver)
    exit "${GPG_RECV_RC:-0}"
    ;;
  --batch)
    status_fd=1
    prev=""
    for arg in "$@"; do
      [ "$prev" = "--status-fd" ] && status_fd="$arg"
      prev="$arg"
    done
    if [ "${GPG_VERIFY_OK:-1}" = "1" ]; then
      printf '[GNUPG:] GOODSIG F434A1EFAFEEAEA3 The Document Foundation\n' >&"$status_fd"
      printf '[GNUPG:] VALIDSIG C2839ECAD9408FBE9531C3E9F434A1EFAFEEAEA3 2024-01-01\n' >&"$status_fd"
      exit 0
    else
      printf '[GNUPG:] BADSIG F434A1EFAFEEAEA3\n' >&"$status_fd"
      exit 1
    fi
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "$TMPDIR_TEST/bin/gpg"
}

# _make_tar_stub
# Parses `tar -xzf <tarball> -C <dir>` and creates <dir>/<basename>/DEBS/dummy.deb
_make_tar_stub() {
  cat >"$TMPDIR_TEST/bin/tar" <<'EOF'
#!/usr/bin/env bash
target_dir="" tarball="" prev=""
for arg in "$@"; do
  case "$prev" in
    -C) target_dir="$arg" ;;
    *f) tarball="$arg" ;;
  esac
  prev="$arg"
done
base=$(basename "$tarball" .tar.gz)
mkdir -p "$target_dir/$base/DEBS"
: >"$target_dir/$base/DEBS/dummy.deb"
exit 0
EOF
  chmod +x "$TMPDIR_TEST/bin/tar"
}

# _make_dpkg_stub INSTALL_RC
_make_dpkg_stub() {
  local rc="${1:-0}"
  cat >"$TMPDIR_TEST/bin/dpkg" <<EOF
#!/usr/bin/env bash
case "\$1" in
  -i) exit ${rc} ;;
  *)  exit 0 ;;
esac
EOF
  chmod +x "$TMPDIR_TEST/bin/dpkg"
}

# _make_libreoffice_stub VERSION_TRIPLE_OR_QUAD
# Empty string → stub exits 1, simulating libreoffice not installed.
_make_libreoffice_stub() {
  local ver="$1"
  if [ -z "$ver" ]; then
    printf '#!/usr/bin/env bash\nexit 1\n' >"$TMPDIR_TEST/bin/libreoffice"
  else
    cat >"$TMPDIR_TEST/bin/libreoffice" <<EOF
#!/usr/bin/env bash
printf 'LibreOffice %s abcdef0123456789\n' "${ver}"
EOF
  fi
  chmod +x "$TMPDIR_TEST/bin/libreoffice"
}

_make_sudo_stub() {
  cat >"$TMPDIR_TEST/bin/sudo" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -v|-n) exit 0 ;;
esac
exec "$@"
EOF
  chmod +x "$TMPDIR_TEST/bin/sudo"
}

# _make_sleep_stub
# Replaces the 60s sleep inside the sudo keepalive so tests don't hang.
# Exits non-zero so the keepalive's `while true; do sleep 60; ...` terminates
# immediately under `set -e`.
_make_sleep_stub() {
  cat >"$TMPDIR_TEST/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$TMPDIR_TEST/bin/sleep"
}

# _make_apt_get_stub RC
_make_apt_get_stub() {
  local rc="${1:-0}"
  cat >"$TMPDIR_TEST/bin/apt-get" <<EOF
#!/usr/bin/env bash
exit ${rc}
EOF
  chmod +x "$TMPDIR_TEST/bin/apt-get"
}

# ---------------------------------------------------------------------------
# Missing dependencies
# ---------------------------------------------------------------------------

@test "exits 1 when curl is missing" {
  # setup() already provides stubs for tar/gpg/dpkg etc — just remove curl
  rm -f "$TMPDIR_TEST/bin/curl"
  for cmd in sed awk grep sort; do
    [ -e "$TMPDIR_TEST/bin/$cmd" ] || ln -sf "$(command -v $cmd)" "$TMPDIR_TEST/bin/$cmd"
  done
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl is required"* ]]
}

# ---------------------------------------------------------------------------
# Architecture detection
# ---------------------------------------------------------------------------

@test "exits 1 for unsupported architecture" {
  _make_uname_stub aarch64
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture: aarch64"* ]]
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

@test "exits 1 when TDF listing has no version directories" {
  export TDF_LISTING="<html><body>no versions here</body></html>"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve latest LibreOffice version"* ]]
}

# ---------------------------------------------------------------------------
# Up-to-date check
# ---------------------------------------------------------------------------

@test "exits 0 with message when already on latest" {
  _make_libreoffice_stub "26.2.3.0"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" != *"Downloading"* ]]
}

# ---------------------------------------------------------------------------
# Branch-change prompt
# ---------------------------------------------------------------------------

@test "aborts when branch-change prompt is declined" {
  _make_libreoffice_stub "$FAKE_OLD_OTHER_BRANCH"
  run "$SCRIPT" <<<"no"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch change detected"* ]]
  [[ "$output" == *"Aborted."* ]]
  [[ "$output" != *"Downloading"* ]]
}

@test "proceeds when branch-change prompt is accepted" {
  _make_libreoffice_stub "$FAKE_OLD_OTHER_BRANCH"
  run "$SCRIPT" <<<"yes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch change detected"* ]]
  [[ "$output" == *"Downloading"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

# ---------------------------------------------------------------------------
# GPG key handling
# ---------------------------------------------------------------------------

@test "auto-imports TDF GPG key when not in keyring" {
  export GPG_LIST_RC=1
  export GPG_RECV_RC=0
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing TDF signing key ${TDF_FPR}"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

@test "exits 1 when GPG key import fails on all keyservers" {
  export GPG_LIST_RC=1
  export GPG_RECV_RC=1
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to import TDF signing key"* ]]
}

@test "exits 1 when GPG signature verification fails" {
  export GPG_VERIFY_OK=0
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GPG verification failed"* ]]
}

# ---------------------------------------------------------------------------
# Installation paths
# ---------------------------------------------------------------------------

@test "exits 0 on happy path with installed-version and rollback hint" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloading LibreOffice_${FAKE_LATEST}_Linux_x86-64_deb.tar.gz"* ]]
  [[ "$output" == *"Verifying GPG signature"* ]]
  [[ "$output" == *"Installing LibreOffice ${FAKE_LATEST} core .deb packages"* ]]
  [[ "$output" == *"Installing fr langpack"* ]]
  [[ "$output" == *"Installed version:"* ]]
  [[ "$output" == *"Previous version was: ${FAKE_OLD_SAME_BRANCH}"* ]]
  [[ "$output" == *"To roll back: reinstall"* ]]
  [[ "$output" == *"LibreOffice_${FAKE_OLD_SAME_TRIPLE}_Linux_x86-64_deb.tar.gz"* ]]
}

@test "recovers when dpkg fails but apt-get -f succeeds" {
  _make_dpkg_stub 1
  _make_apt_get_stub 0
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dpkg install failed"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

@test "exits 1 when dpkg fails and apt-get cannot recover" {
  _make_dpkg_stub 1
  _make_apt_get_stub 1
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Dependency fix failed"* ]]
  [[ "$output" == *"To roll back, reinstall the previous"* ]]
}
