#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/pandoc-update

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/pandoc-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs live in ${STUBS} (prepended to PATH), driven by exported env vars.
#
#   GH_PANDOC_VERSION      tag returned by `gh api`
#   PANDOC_CURRENT         version printed by the installed pandoc stub
#   UNAME_ARCH             string returned by `uname -m`
#   GH_DOWNLOAD_MODE       full | none  (whether `gh release download` drops a .deb)
#   PANDOC_LUA_EXIT        exit code of `pandoc lua -e ...` (0 = run_lua_filter present)
#   PANDOC_DATA_INSTALLED  0 | 1  (whether `dpkg -l pandoc-data` reports it installed)
#   APT_LOG                file the apt-get stub appends its argv to
#
# The pandoc stub is ALWAYS on PATH so the developer's real pandoc never leaks.

_create_stubs() {
  cat >"${STUBS}/gh" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    api) printf '%s\n' "${GH_PANDOC_VERSION}" ;;
    release)
        dir=""; next=0
        for a in "$@"; do
            [ "$next" = 1 ] && { dir="$a"; next=0; continue; }
            [ "$a" = "-D" ] && next=1
        done
        if [ -n "$dir" ] && [ "${GH_DOWNLOAD_MODE:-full}" = "full" ]; then
            : >"${dir}/pandoc-${GH_PANDOC_VERSION}-1-amd64.deb"
        fi
        ;;
esac
exit 0
EOF

  cat >"${STUBS}/pandoc" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    lua) exit "${PANDOC_LUA_EXIT:-0}" ;;
    *) printf 'pandoc %s\nFeatures: +server +lua\n' "${PANDOC_CURRENT}" ;;
esac
EOF

  cat >"${STUBS}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${UNAME_ARCH:-x86_64}"
EOF

  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  exec "$@" ;;
esac
EOF

  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${APT_LOG}"
exit "${APT_EXIT:-0}"
EOF

  cat >"${STUBS}/dpkg" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-l" ] && [ "${PANDOC_DATA_INSTALLED:-0}" = "1" ]; then
    echo "ii  pandoc-data  3.1.3-1  all  general markup converter - data files"
fi
exit 0
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  export STUBS
  export APT_LOG="${STUBS}/apt.log"

  export GH_PANDOC_VERSION=3.10
  export PANDOC_CURRENT=3.10
  export UNAME_ARCH=x86_64
  export GH_DOWNLOAD_MODE=full
  export PANDOC_LUA_EXIT=0
  export PANDOC_DATA_INSTALLED=0

  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}"
}

# ─── argument parsing ───────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  run bash "${SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"pandoc-update"* ]]
  [[ "$output" == *"USAGE"* ]]
}

@test "-h is an alias for --help" {
  run bash "${SCRIPT}" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "unknown option exits 2" {
  run bash "${SCRIPT}" --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option '--nope'"* ]]
}

@test "unexpected positional argument exits 2" {
  run bash "${SCRIPT}" pandoc
  [ "$status" -eq 2 ]
  [[ "$output" == *"unexpected argument 'pandoc'"* ]]
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 when a required command is missing" {
  # gh/apt-get/sudo present in STUBS; dpkg removed, so the preflight reports it.
  ln -s "$BASH" "${STUBS}/bash"
  ln -s "$(command -v env)" "${STUBS}/env"
  rm -f "${STUBS}/dpkg"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'dpkg'"* ]]
}

# ─── architecture detection ─────────────────────────────────────────────────

@test "exits 1 on unsupported architecture" {
  export UNAME_ARCH=s390x
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported architecture: s390x"* ]]
}

# ─── version resolution ─────────────────────────────────────────────────────

@test "exits 1 when GitHub API returns empty tag" {
  export GH_PANDOC_VERSION=''
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to resolve latest pandoc version"* ]]
}

# ─── up-to-date check (variable-length version strings) ─────────────────────

@test "skips when already on a two-component latest (3.10)" {
  export GH_PANDOC_VERSION=3.10
  export PANDOC_CURRENT=3.10
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on 3.10: nothing to do."* ]]
  [ ! -f "${APT_LOG}" ]
}

@test "skips when already on a three-component latest (3.1.3)" {
  export GH_PANDOC_VERSION=3.1.3
  export PANDOC_CURRENT=3.1.3
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on 3.1.3: nothing to do."* ]]
}

# ─── install path ───────────────────────────────────────────────────────────

@test "installs via apt-get when a newer release exists" {
  export PANDOC_CURRENT=3.1.3
  export GH_PANDOC_VERSION=3.10
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest pandoc release: 3.10"* ]]
  [ -f "${APT_LOG}" ]
  grep -q 'install -y' "${APT_LOG}"
  grep -q 'pandoc-3.10-1-amd64.deb' "${APT_LOG}"
}

@test "exits 1 when the downloaded .deb is missing" {
  export PANDOC_CURRENT=3.1.3
  export GH_PANDOC_VERSION=3.10
  export GH_DOWNLOAD_MODE=none
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"expected exactly one .deb"* ]]
}

@test "warns when the installed pandoc lacks run_lua_filter" {
  export PANDOC_CURRENT=3.1.3
  export GH_PANDOC_VERSION=3.10
  export PANDOC_LUA_EXIT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: installed pandoc lacks pandoc.utils.run_lua_filter"* ]]
}

@test "notes the pandoc-data reliquat when it is still installed" {
  export PANDOC_CURRENT=3.1.3
  export GH_PANDOC_VERSION=3.10
  export PANDOC_DATA_INSTALLED=1
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pandoc-data is still installed"* ]]
  [[ "$output" == *"apt-get remove pandoc-data"* ]]
}

@test "--force reinstalls even when already on latest" {
  run bash "${SCRIPT}" --force
  [ "$status" -eq 0 ]
  [[ "$output" != *"nothing to do"* ]]
  [ -f "${APT_LOG}" ]
}
