#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/lua-toolchain-update

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/lua-toolchain-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs live in ${STUBS} (prepended to PATH). Behaviour is driven by exported
# env vars read at runtime, so a test overrides only what it needs.
#
#   GH_STYLUA_VERSION      tag returned by `gh api` for the StyLua repo
#   GH_LUALS_VERSION       tag returned by `gh api` for the lua-language-server repo
#   UNAME_ARCH             string returned by `uname -m`
#   STYLUA_CURRENT         version printed by the installed stylua stub; empty = "not installed"
#   LUALS_CURRENT          version printed by the installed lua-language-server stub; empty = "not installed"
#   STYLUA_ARCHIVE_MODE    full | no_binary | failing  (what `unzip` drops)
#   LUALS_ARCHIVE_MODE     full | no_binary | failing  (what `tar` drops)
#   CURL_EXIT              exit code of the curl stub
#
# The installed stylua / lua-language-server stubs are ALWAYS on PATH, so the
# real tools on the developer's PATH never leak into "not installed" tests.

_create_stubs() {
  cat >"${STUBS}/gh" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "api" ]; then
    case "$2" in
        *StyLua*) printf '%s\n' "${GH_STYLUA_VERSION}" ;;
        *lua-language-server*) printf '%s\n' "${GH_LUALS_VERSION}" ;;
    esac
fi
exit 0
EOF

  cat >"${STUBS}/curl" <<'EOF'
#!/usr/bin/env bash
out=""; next=0
for a in "$@"; do
    [ "$next" = 1 ] && { out="$a"; next=0; continue; }
    [ "$a" = "-o" ] && next=1
done
[ -n "$out" ] && : >"$out"
exit "${CURL_EXIT:-0}"
EOF

  cat >"${STUBS}/unzip" <<'EOF'
#!/usr/bin/env bash
dir=""; next=0
for a in "$@"; do
    [ "$next" = 1 ] && { dir="$a"; next=0; continue; }
    [ "$a" = "-d" ] && next=1
done
[ -z "$dir" ] && exit 0
case "${STYLUA_ARCHIVE_MODE:-full}" in
    full)
        printf '#!/usr/bin/env bash\necho "stylua %s"\n' "${GH_STYLUA_VERSION:-2.5.2}" >"$dir/stylua"
        chmod +x "$dir/stylua" ;;
    no_binary) : ;;
    failing)
        printf '#!/usr/bin/env bash\nexit 1\n' >"$dir/stylua"
        chmod +x "$dir/stylua" ;;
esac
exit 0
EOF

  cat >"${STUBS}/tar" <<'EOF'
#!/usr/bin/env bash
dir=""; next=0
for a in "$@"; do
    [ "$next" = 1 ] && { dir="$a"; next=0; continue; }
    [ "$a" = "-C" ] && next=1
done
[ -z "$dir" ] && exit 0
mkdir -p "$dir/bin"
case "${LUALS_ARCHIVE_MODE:-full}" in
    full)
        printf '#!/usr/bin/env bash\necho "%s-dev"\n' "${GH_LUALS_VERSION:-3.18.2}" >"$dir/bin/lua-language-server"
        chmod +x "$dir/bin/lua-language-server" ;;
    no_binary) : ;;
    failing)
        printf '#!/usr/bin/env bash\nexit 1\n' >"$dir/bin/lua-language-server"
        chmod +x "$dir/bin/lua-language-server" ;;
esac
exit 0
EOF

  cat >"${STUBS}/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${UNAME_ARCH:-x86_64}"
EOF

  # Installed-tool stubs: empty *_CURRENT prints no parseable version, which the
  # script reads as "not installed".
  cat >"${STUBS}/stylua" <<'EOF'
#!/usr/bin/env bash
echo "stylua ${STYLUA_CURRENT}"
EOF

  cat >"${STUBS}/lua-language-server" <<'EOF'
#!/usr/bin/env bash
echo "${LUALS_CURRENT}-dev"
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  export STUBS
  export HOME="${STUBS}/home"
  mkdir -p "${HOME}/.local/bin" "${HOME}/.local/share"

  export GH_STYLUA_VERSION=2.5.2
  export GH_LUALS_VERSION=3.18.2
  export UNAME_ARCH=x86_64
  export STYLUA_CURRENT=2.5.2
  export LUALS_CURRENT=3.18.2
  export STYLUA_ARCHIVE_MODE=full
  export LUALS_ARCHIVE_MODE=full

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
  [[ "$output" == *"lua-toolchain-update"* ]]
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
  run bash "${SCRIPT}" stylua
  [ "$status" -eq 2 ]
  [[ "$output" == *"unexpected argument 'stylua'"* ]]
}

# ─── dependency check ───────────────────────────────────────────────────────

@test "exits 1 when a required command is missing" {
  # Restricted PATH holds gh/curl/tar/uname stubs + symlinked bash/env,
  # but no unzip, so the preflight loop reports it.
  ln -s "$BASH" "${STUBS}/bash"
  ln -s "$(command -v env)" "${STUBS}/env"
  rm -f "${STUBS}/unzip"
  run env PATH="${STUBS}" "$BASH" "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'unzip'"* ]]
}

# ─── architecture detection ─────────────────────────────────────────────────

@test "exits 1 on unsupported architecture" {
  export UNAME_ARCH=s390x
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported architecture: s390x"* ]]
}

# ─── up-to-date behavior ────────────────────────────────────────────────────

@test "both tools up to date: skips both, exits 0" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stylua 2.5.2: already up to date"* ]]
  [[ "$output" == *"lua-language-server 3.18.2: already up to date"* ]]
}

@test "stylua out of date triggers install while luals is skipped" {
  export STYLUA_CURRENT=2.4.0
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lua-language-server 3.18.2: already up to date"* ]]
  [[ "$output" == *"✓ stylua 2.5.2"* ]]
  [ -x "${HOME}/.local/bin/stylua" ]
}

# ─── install paths (sandboxed via HOME override) ────────────────────────────

@test "installs stylua when not present, into ~/.local/bin" {
  export STYLUA_CURRENT=''
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ stylua 2.5.2"* ]]
  [ -x "${HOME}/.local/bin/stylua" ]
}

@test "installs lua-language-server runtime and launcher symlink" {
  export LUALS_CURRENT=''
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ lua-language-server 3.18.2"* ]]
  [ -x "${HOME}/.local/share/lua-language-server/bin/lua-language-server" ]
  [ -L "${HOME}/.local/bin/lua-language-server" ]
}

@test "--force reinstalls even when up to date" {
  run bash "${SCRIPT}" --force
  [ "$status" -eq 0 ]
  [[ "$output" != *"already up to date"* ]]
  [[ "$output" == *"✓ stylua 2.5.2"* ]]
}

# ─── failure propagation ────────────────────────────────────────────────────

@test "stylua version resolution failure is reported and exits 1" {
  export GH_STYLUA_VERSION=''
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to resolve latest StyLua version"* ]]
  [[ "$output" == *"failed for: stylua"* ]]
}

@test "exits 1 when the stylua binary is absent from the archive" {
  export STYLUA_CURRENT=''
  export STYLUA_ARCHIVE_MODE=no_binary
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"stylua binary missing from archive"* ]]
}

@test "exits 1 when the extracted stylua fails to execute" {
  export STYLUA_CURRENT=''
  export STYLUA_ARCHIVE_MODE=failing
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"extracted stylua fails to execute"* ]]
}

@test "exits 1 when lua-language-server is missing from the archive" {
  export LUALS_CURRENT=''
  export LUALS_ARCHIVE_MODE=no_binary
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bin/lua-language-server missing from archive"* ]]
}

@test "both tools failing reports both in the summary" {
  export GH_STYLUA_VERSION=''
  export GH_LUALS_VERSION=''
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed for:"* ]]
  [[ "$output" == *"stylua"* ]]
  [[ "$output" == *"lua-language-server"* ]]
}
