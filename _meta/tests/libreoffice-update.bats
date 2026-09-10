#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# SC2030/SC2031: bats runs each @test in its own subshell; "modification lost" warnings
# for `export` inside @test blocks don't apply — next test starts fresh by design.

# Tests for libreoffice-update
# Mocks: curl, gpg, tar, dpkg, dpkg-query, libreoffice, sudo, apt-get, uname — no real
# network, no real installs. The /opt tree and the unversioned launcher path are
# redirected into the temp dir through LO_OPT_ROOT / LO_BIN_LINK.
#
# Every run that must not reach the branch-change prompt takes `</dev/null`: an
# unexpected `read` inherits the suite's stdin and blocks forever instead of
# failing, which costs a CI job its whole time budget and names no test. On EOF
# the read fails, `set -e` exits, and the assertion reports the culprit.

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
  mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/usr-local-bin"

  export LO_OPT_ROOT="$TMPDIR_TEST/opt"
  export LO_BIN_LINK="$TMPDIR_TEST/usr-local-bin/libreoffice"

  # Default: TDF key is already in the keyring — tests that exercise the
  # import branch remove this flag in their own body.
  : >"$TMPDIR_TEST/.gpg_has_key"

  _make_uname_stub x86_64
  _make_curl_stub
  _make_gpg_stub
  _make_tar_stub
  _make_dpkg_stub 0
  _make_dpkg_query_stub
  _set_installed "$FAKE_OLD_SAME_BRANCH"
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
# Stateful mock — keyring state lives in $TMPDIR_TEST/.gpg_has_key (created by
# setup() by default; tests that want to exercise the import branch rm it).
#
# Behavior controlled by env vars set per test:
#   GPG_RECV_RC    (default 0) — exit code of `gpg --keyserver ... --recv-keys`
#                                When 0 AND GPG_RECV_LIES != 1, the call also
#                                creates the keyring flag (= key imported).
#   GPG_RECV_LIES  (default 0) — when 1, recv-keys exits 0 but does NOT create
#                                the keyring flag. Simulates keys.openpgp.org
#                                stripping UIDs from keys whose owner has not
#                                verified their email there: gpg reports success
#                                but the key is silently dropped.
#   GPG_VERIFY_OK  (default 1) — when 1, prints GOODSIG+VALIDSIG for --verify;
#                                when 0, prints BADSIG and exits 1.
_make_gpg_stub() {
  cat >"$TMPDIR_TEST/bin/gpg" <<'EOF'
#!/usr/bin/env bash
KEYRING_FLAG="$TMPDIR_TEST/.gpg_has_key"
case "$1" in
  --list-keys)
    [ -e "$KEYRING_FLAG" ] && exit 0 || exit 1
    ;;
  --keyserver)
    rc="${GPG_RECV_RC:-0}"
    if [ "$rc" -eq 0 ] && [ "${GPG_RECV_LIES:-0}" != "1" ]; then
      : >"$KEYRING_FLAG"
    fi
    exit "$rc"
    ;;
  --batch)
    status_fd=1
    prev=""
    for arg in "$@"; do
      [ "$prev" = "--status-fd" ] && status_fd="$arg"
      prev="$arg"
    done
    # Real gpg --verify fails with "No public key" when the signing key isn't
    # in the keyring. Mirror that here so tests catch the bug end-to-end, not
    # just the post-import sanity check.
    if [ ! -e "$KEYRING_FLAG" ]; then
      printf '[GNUPG:] ERRSIG F434A1EFAFEEAEA3 1 10 00 0 9\n' >&"$status_fd"
      printf '[GNUPG:] NO_PUBKEY F434A1EFAFEEAEA3\n' >&"$status_fd"
      exit 2
    fi
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
# Models TDF's two-name quirk: tarballs are named by marketing version
# (e.g. LibreOffice_26.2.3_Linux_x86-64_deb.tar.gz) but extract to a
# directory using the build version (e.g. LibreOffice_26.2.3.2_Linux_x86-64_deb/).
# The inner-dir name is derived by inserting TAR_BUILD_SUFFIX before `_Linux_`.
#
# Supports:
#   tar -tzf <tarball>            → prints the inner dir (one line per entry)
#   tar -xzf <tarball> -C <dir>   → creates <dir>/<inner>/DEBS/dummy.deb
#
# Env vars:
#   TAR_BUILD_SUFFIX  (default ".2") — string inserted before `_Linux_` to form
#                                       the inner-dir name. Set to "" to model
#                                       a tarball whose inner-dir matches the
#                                       filename exactly.
_make_tar_stub() {
  cat >"$TMPDIR_TEST/bin/tar" <<'EOF'
#!/usr/bin/env bash
mode=""
target_dir="" tarball="" prev=""
for arg in "$@"; do
  case "$arg" in
    -tzf | -tz) mode=list ;;
    -xzf | -xz) mode=extract ;;
  esac
  case "$prev" in
    -C) target_dir="$arg" ;;
    -tzf | -xzf | -tz | -xz) tarball="$arg" ;;
  esac
  prev="$arg"
done

base=$(basename "$tarball" .tar.gz)
inner="${base/_Linux_/${TAR_BUILD_SUFFIX-.2}_Linux_}"

case "$mode" in
  list)
    printf '%s/\n' "$inner"
    printf '%s/DEBS/\n' "$inner"
    printf '%s/DEBS/dummy.deb\n' "$inner"
    ;;
  extract)
    mkdir -p "$target_dir/$inner/DEBS"
    : >"$target_dir/$inner/DEBS/dummy.deb"
    ;;
esac
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

# _add_branch VERSION_TRIPLE_OR_QUAD
# Models one TDF /opt tree: $LO_OPT_ROOT/libreoffice<branch>/program/soffice plus
# the branch-namespaced dpkg rows the dpkg-query stub answers from. The extra
# packages beyond -core are what the purge path enumerates.
_add_branch() {
  local ver="$1" branch pkg
  branch=$(awk -F. '{print $1"."$2}' <<<"$ver")
  mkdir -p "$LO_OPT_ROOT/libreoffice${branch}/program"
  cat >"$LO_OPT_ROOT/libreoffice${branch}/program/soffice" <<EOF
#!/usr/bin/env bash
printf 'LibreOffice %s abcdef0123456789\n' "${ver}"
EOF
  chmod +x "$LO_OPT_ROOT/libreoffice${branch}/program/soffice"
  for pkg in "libobasis${branch}-core" "libobasis${branch}-calc" \
    "libreoffice${branch}" "libreoffice${branch}-debian-menus"; do
    printf '%s %s-1\n' "$pkg" "$ver" >>"$TMPDIR_TEST/.lo_versions"
  done
}

# _set_installed [VERSION]
# Resets the fake /opt tree to hold exactly the given branch (none if omitted).
_set_installed() {
  rm -rf "$LO_OPT_ROOT"
  : >"$TMPDIR_TEST/.lo_versions"
  mkdir -p "$LO_OPT_ROOT"
  [ "${1:-}" != "" ] && _add_branch "$1"
  return 0
}

# _make_dpkg_query_stub
# Answers both call shapes the script uses, from $TMPDIR_TEST/.lo_versions:
#   -f='${Version}' <exact-pkg>                → the version, no trailing newline
#   -f='${binary:Package}\t${db:Status-Status}\n' <glob>...  → one row per match
# Package arguments are matched as shell globs, and no match exits 1, both the
# way the real tool behaves.
_make_dpkg_query_stub() {
  cat >"$TMPDIR_TEST/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
fmt=""
pats=()
for arg in "$@"; do
  case "$arg" in
    -W | --show) ;;
    -f=*) fmt="${arg#-f=}" ;;
    *) pats+=("$arg") ;;
  esac
done

db="$TMPDIR_TEST/.lo_versions"
[ -e "$db" ] || exit 1

found=0
while read -r name ver; do
  for p in "${pats[@]}"; do
    # Unquoted RHS: glob match, as dpkg-query does on package arguments.
    if [[ "$name" == $p ]]; then
      found=1
      case "$fmt" in
        *Version*) printf '%s' "$ver" ;;
        *) printf '%s\t%s\n' "$name" installed ;;
      esac
      break
    fi
  done
done <"$db"
exit $((!found))
EOF
  chmod +x "$TMPDIR_TEST/bin/dpkg-query"
}

# _make_libreoffice_stub VERSION_TRIPLE_OR_QUAD
# The unversioned launcher, used only for the closing `libreoffice --version`
# echo and for the no-/opt-tree fallback.
# Empty string → stub exits 1, simulating libreoffice not installed.
_make_libreoffice_stub() {
  local ver="$1"
  if [ "$ver" = "" ]; then
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
# Records every invocation in $TMPDIR_TEST/.apt_calls so purge tests can assert
# which packages were handed to it.
_make_apt_get_stub() {
  local rc="${1:-0}"
  cat >"$TMPDIR_TEST/bin/apt-get" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"\${TMPDIR_TEST}/.apt_calls"
exit ${rc}
EOF
  chmod +x "$TMPDIR_TEST/bin/apt-get"
}

# _apt_calls — every recorded apt-get invocation, empty when there was none.
_apt_calls() {
  cat "$TMPDIR_TEST/.apt_calls" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Missing dependencies
# ---------------------------------------------------------------------------

@test "exits 1 when curl is missing" {
  # setup() already provides stubs for tar/gpg/dpkg etc — just remove curl
  rm -f "$TMPDIR_TEST/bin/curl"
  for cmd in sed awk grep sort; do
    [ -e "$TMPDIR_TEST/bin/$cmd" ] || ln -sf "$(command -v "$cmd")" "$TMPDIR_TEST/bin/$cmd"
  done
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"curl is required"* ]]
}

# dpkg-query carries the version lookup and the purge enumeration, so its
# absence has to stop the script rather than silently degrade detection to the
# unversioned launcher.
@test "exits 1 when dpkg-query is missing" {
  rm -f "$TMPDIR_TEST/bin/dpkg-query"
  for cmd in sed awk grep sort; do
    [ -e "$TMPDIR_TEST/bin/$cmd" ] || ln -sf "$(command -v "$cmd")" "$TMPDIR_TEST/bin/$cmd"
  done
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"dpkg-query is required"* ]]
}

# ---------------------------------------------------------------------------
# Architecture detection
# ---------------------------------------------------------------------------

@test "exits 1 for unsupported architecture" {
  _make_uname_stub aarch64
  run "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported architecture: aarch64"* ]]
}

# ---------------------------------------------------------------------------
# Version resolution
# ---------------------------------------------------------------------------

@test "exits 1 when TDF listing has no version directories" {
  export TDF_LISTING="<html><body>no versions here</body></html>"
  run "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to resolve latest LibreOffice version"* ]]
}

# ---------------------------------------------------------------------------
# Up-to-date check
# ---------------------------------------------------------------------------

@test "exits 0 with message when already on latest" {
  _set_installed "26.2.3.0"
  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" != *"Downloading"* ]]
}

# Regression test for the stale-launcher bug: TDF debs ship only branch-versioned
# launchers, so the unversioned one keeps pointing at the old branch after an
# upgrade. Reading the current version through it reported 26.2 with 26.8 already
# installed, and the script re-offered the branch change on every run.
@test "reads the newest installed branch, not the unversioned launcher" {
  _set_installed "26.2.3.0"
  _add_branch "$FAKE_OLD_OTHER_BRANCH"
  ln -sfn "$LO_OPT_ROOT/libreoffice25.8/program/soffice" "$LO_BIN_LINK"
  _make_libreoffice_stub "$FAKE_OLD_OTHER_BRANCH"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" != *"Branch change detected"* ]]
}

@test "repoints a lagging unversioned launcher at the newest branch" {
  _set_installed "26.2.3.0"
  _add_branch "$FAKE_OLD_OTHER_BRANCH"
  ln -sfn "$LO_OPT_ROOT/libreoffice25.8/program/soffice" "$LO_BIN_LINK"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pointing ${LO_BIN_LINK} at LibreOffice 26.2"* ]]
  [ "$(readlink -f "$LO_BIN_LINK")" = "$LO_OPT_ROOT/libreoffice26.2/program/soffice" ]
}

@test "leaves an already-current launcher untouched" {
  _set_installed "26.2.3.0"
  ln -sfn "$LO_OPT_ROOT/libreoffice26.2/program/soffice" "$LO_BIN_LINK"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *"Pointing"* ]]
}

@test "refuses to replace a regular file sitting at the launcher path" {
  _set_installed "26.2.3.0"
  printf '#!/bin/sh\n' >"$LO_BIN_LINK"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"is not a symlink: leaving it alone"* ]]
  [ ! -L "$LO_BIN_LINK" ]
}

# dpkg-query is the fast path; a tree whose libobasis package cannot be queried
# still has to yield a version, otherwise the script falls back to the
# unversioned launcher and the bug above returns.
@test "falls back to the branch soffice when dpkg-query knows nothing" {
  _set_installed "26.2.3.0"
  : >"$TMPDIR_TEST/.lo_versions"
  _make_libreoffice_stub "$FAKE_OLD_OTHER_BRANCH"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

@test "falls back to the unversioned launcher when no /opt tree exists" {
  _set_installed
  _make_libreoffice_stub "26.2.3.0"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
}

# ---------------------------------------------------------------------------
# Purge of superseded branches
# ---------------------------------------------------------------------------

@test "purges a superseded branch left behind by an earlier upgrade" {
  _set_installed "26.2.3.0"
  _add_branch "$FAKE_OLD_OTHER_BRANCH"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on ${FAKE_LATEST}"* ]]
  [[ "$output" == *"Purging superseded LibreOffice 25.8 (4 packages)"* ]]
  [[ "$(_apt_calls)" == *"purge -y libobasis25.8-core"* ]]
  [ ! -d "$LO_OPT_ROOT/libreoffice25.8" ]
}

@test "purge never touches the branch being kept" {
  _set_installed "26.2.3.0"
  _add_branch "$FAKE_OLD_OTHER_BRANCH"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$(_apt_calls)" != *"26.2"* ]]
  [ -d "$LO_OPT_ROOT/libreoffice26.2" ]
}

@test "purges the old branch after a branch change" {
  _set_installed "$FAKE_OLD_OTHER_BRANCH"

  run "$SCRIPT" <<<"yes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"then purges 25.8 once the new install succeeds"* ]]
  [[ "$output" == *"Purging superseded LibreOffice 25.8"* ]]
  [ ! -d "$LO_OPT_ROOT/libreoffice25.8" ]
}

@test "keeps the old tree when its purge fails" {
  _set_installed "26.2.3.0"
  _add_branch "$FAKE_OLD_OTHER_BRANCH"
  _make_apt_get_stub 1

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Purge of LibreOffice 25.8 failed"* ]]
  [ -d "$LO_OPT_ROOT/libreoffice25.8" ]
}

@test "no purge when the newest branch is the only one installed" {
  _set_installed "26.2.3.0"

  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *"Purging"* ]]
  [ "$(_apt_calls)" = "" ]
}

# A downgrade purges the branch it falls back from, like any other branch
# change: it happens only after the prompt has named that branch and been
# accepted, so the purge is never a surprise.
# The purge runs after the install, so a failed install keeps the only working
# LibreOffice on the machine. The fixture has to be a branch change: a
# same-branch run purges nothing whatever the ordering, so it cannot tell a
# correct script from one that purges first.
@test "purges nothing when the install fails" {
  _set_installed "$FAKE_OLD_OTHER_BRANCH"
  _make_dpkg_stub 1
  _make_apt_get_stub 1

  run "$SCRIPT" <<<"yes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Dependency fix failed"* ]]
  [[ "$output" != *"Purging"* ]]
  [[ "$(_apt_calls)" != *"purge"* ]]
  [ -d "$LO_OPT_ROOT/libreoffice25.8" ]
}

@test "purges the branch a downgrade falls back from" {
  _set_installed "26.2.3.0"
  _add_branch "27.2.0.1"

  run "$SCRIPT" <<<"yes"
  [ "$status" -eq 0 ]
  [[ "$output" == *"then purges 27.2 once the new install succeeds"* ]]
  [[ "$output" == *"Purging superseded LibreOffice 27.2"* ]]
  [ ! -d "$LO_OPT_ROOT/libreoffice27.2" ]
}

# ---------------------------------------------------------------------------
# Branch-change prompt
# ---------------------------------------------------------------------------

@test "aborts when branch-change prompt is declined" {
  _set_installed "$FAKE_OLD_OTHER_BRANCH"
  run "$SCRIPT" <<<"no"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch change detected"* ]]
  [[ "$output" == *"Aborted."* ]]
  [[ "$output" != *"Downloading"* ]]
}

@test "proceeds when branch-change prompt is accepted" {
  _set_installed "$FAKE_OLD_OTHER_BRANCH"
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
  rm -f "$TMPDIR_TEST/.gpg_has_key"
  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing TDF signing key ${TDF_FPR}"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

@test "exits 1 when GPG key import fails on all keyservers" {
  rm -f "$TMPDIR_TEST/.gpg_has_key"
  export GPG_RECV_RC=1
  run "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to import TDF signing key"* ]]
}

# Regression test for the keys.openpgp.org UID-stripping bug:
# the keyserver returns exit 0 (success) but silently drops the key because
# the owner hasn't verified their email there ("new key but contains no user
# ID - skipped"). Without a post-import sanity check, the script would
# proceed and fail later at --verify with a confusing "No public key" error.
@test "exits 1 when recv-keys lies (openpgp.org UID-stripping case)" {
  rm -f "$TMPDIR_TEST/.gpg_has_key"
  export GPG_RECV_LIES=1
  run "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"TDF signing key not present in keyring after import"* ]]
}

@test "exits 1 when GPG signature verification fails" {
  export GPG_VERIFY_OK=0
  run "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"GPG verification failed"* ]]
}

# ---------------------------------------------------------------------------
# Installation paths
# ---------------------------------------------------------------------------

# Regression test for TDF's two-name quirk: tarballs named ..._26.2.3_... but
# extracting to ..._26.2.3.X_..._deb/. An earlier version of the script
# reconstructed the inner-dir path from ${VER} and failed with "Missing or
# empty DEBS directory" when X != "" (which is the actual TDF convention).
@test "handles tarballs whose inner dir uses build version not filename version" {
  export TAR_BUILD_SUFFIX=".5"
  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing LibreOffice ${FAKE_LATEST} core .deb packages"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

@test "handles tarballs whose inner dir matches filename exactly" {
  export TAR_BUILD_SUFFIX=""
  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed version:"* ]]
}

@test "exits 0 on happy path with installed-version and rollback hint" {
  run "$SCRIPT" </dev/null
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
  run "$SCRIPT" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"dpkg install failed"* ]]
  [[ "$output" == *"Installed version:"* ]]
}

@test "exits 1 when dpkg fails and apt-get cannot recover" {
  _make_dpkg_stub 1
  _make_apt_get_stub 1
  run "$SCRIPT" </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"Dependency fix failed"* ]]
  [[ "$output" == *"To roll back, reinstall the previous"* ]]
}
