#!/usr/bin/env bats

# Tests for devtools-install
# Mocks: curl, jq, sudo — no real network calls, no real installs

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/devtools-install"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

setup() {
  export TMPDIR_TEST
  TMPDIR_TEST=$(mktemp -d)
  export PATH="$TMPDIR_TEST/bin:$PATH"
  mkdir -p "$TMPDIR_TEST/bin" "$TMPDIR_TEST/prefix"
  PREFIX="$TMPDIR_TEST/prefix"

  # Mock sudo: no-op
  cat >"$TMPDIR_TEST/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-v" ]]; then exit 0; fi
if [[ "$1" == "-n" && "$2" == "-v" ]]; then exit 0; fi
if [[ "$1" == "env" ]]; then
  shift
  while [[ "$1" == *=* ]]; do
    export "$1"
    shift
  done
fi
exec "$@"
EOF
  chmod +x "$TMPDIR_TEST/bin/sudo"

  # Default mock curl: returns a minimal GitHub API response for version 1.2.3
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo '{"tag_name":"v1.2.3"}'
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  # Real jq must be available (it's a declared dependency)
  # But mock it if not present
  if ! command -v jq >/dev/null 2>&1; then
    cat >"$TMPDIR_TEST/bin/jq" <<'EOF'
#!/usr/bin/env bash
# Minimal jq mock: handles only the tag_name extraction pattern
echo "1.2.3"
EOF
    chmod +x "$TMPDIR_TEST/bin/jq"
  fi
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

# Create a fake installed binary that reports a given version
make_fake_binary() {
  local name="$1" version="$2" prefix="$3"
  cat >"${prefix}/${name}" <<EOF
#!/usr/bin/env bash
echo "${name} ${version}"
EOF
  chmod +x "${prefix}/${name}"
}

# Make curl return a specific GitHub API version
mock_latest_version() {
  local version="$1"
  cat >"$TMPDIR_TEST/bin/curl" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *api.github.com* ]]; then
  echo '{"tag_name":"v${version}"}'
else
  # For installer curl calls: write a fake installer to stdout
  echo '#!/usr/bin/env sh'
  echo "mkdir -p \"\${FAKE_INSTALL_PREFIX:-/tmp}\""
  echo "echo 'fake installer ran'"
fi
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"
}

# Create a curl stub that handles both GitHub API calls and installer downloads.
# API calls (URL contains api.github.com) return JSON to stdout.
# Download calls (with -o FILE) copy a pre-baked fake installer to FILE.
# The fake installer creates an executable $tool binary in the install dir
# by reading the tool-specific env var set by the sudo stub.
# shellcheck disable=SC2016  # single quotes are intentional: generating literal shell code
make_curl_stub() {
  local tool="$1" version="$2"
  local installer="$TMPDIR_TEST/fake-installer-${tool}.sh"

  printf '%s\n' \
    '#!/usr/bin/env sh' \
    'set -e' \
    'd="${AIR_UNMANAGED_INSTALL:-${JARL_UNMANAGED_INSTALL:-${UV_UNMANAGED_INSTALL:-${RUFF_UNMANAGED_INSTALL:-${PREK_INSTALL_DIR:-}}}}}"' \
    'mkdir -p "$d"' \
    >"$installer"
  printf 'printf '"'"'#!/bin/sh\\necho %s %s\\n'"'"' > "$d/%s"\n' \
    "$tool" "$version" "$tool" >>"$installer"
  printf 'chmod +x "$d/%s"\n' "$tool" >>"$installer"
  chmod +x "$installer"

  {
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'outfile="" prev=""' \
      'for arg in "$@"; do' \
      '    [[ "$prev" == "-o" ]] && outfile="$arg"' \
      '    prev="$arg"' \
      'done'
    printf 'if [[ "$*" == *api.github.com* ]]; then\n'
    printf '    echo '"'"'{"tag_name":"v%s"}'"'"'\n' "$version"
    printf 'elif [[ -n "$outfile" ]]; then\n'
    printf '    cp "%s" "$outfile"\n' "$installer"
    printf 'fi\n'
  } >"$TMPDIR_TEST/bin/curl"
  chmod +x "$TMPDIR_TEST/bin/curl"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

@test "--help prints usage and exits 0" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"devtools-install"* ]]
  [[ "$output" == *"USAGE"* ]]
}

@test "-h is equivalent to --help" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "--list prints tool table and exits 0" {
  run "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"TOOL"* ]]
  [[ "$output" == *"uv"* ]]
  [[ "$output" == *"ruff"* ]]
  [[ "$output" == *"air"* ]]
}

@test "no arguments prints usage to stderr and exits 2" {
  run "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "unknown tool exits 2 with error message" {
  run "$SCRIPT" --prefix "$PREFIX" nonexistent
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown tool 'nonexistent'"* ]]
}

@test "unknown option exits 2 with error message" {
  run "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option '--bogus'"* ]]
}

@test "--prefix requires an argument" {
  run "$SCRIPT" --prefix
  [ "$status" -eq 2 ]
  [[ "$output" == *"--prefix requires an argument"* ]]
}

# ---------------------------------------------------------------------------
# Version check: already up to date
# ---------------------------------------------------------------------------

@test "skips install when installed version matches latest" {
  mock_latest_version "1.2.3"
  make_fake_binary "uv" "uv 1.2.3 (abc 2024)" "$PREFIX"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}

@test "skips install for multiple tools all up to date" {
  mock_latest_version "1.2.3"
  make_fake_binary "uv" "uv 1.2.3" "$PREFIX"
  make_fake_binary "ruff" "ruff 1.2.3" "$PREFIX"

  run "$SCRIPT" --prefix "$PREFIX" uv ruff
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}

# ---------------------------------------------------------------------------
# Version check: needs update
# ---------------------------------------------------------------------------

@test "installs when installed version is lower than latest" {
  make_curl_stub "uv" "2.0.0"
  make_fake_binary "uv" "uv 1.0.0" "$PREFIX"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"updating uv"* ]]
}

# ---------------------------------------------------------------------------
# Not installed
# ---------------------------------------------------------------------------

@test "installs when tool is not present in prefix" {
  make_curl_stub "uv" "1.5.0"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"installing uv"* ]]
}

# ---------------------------------------------------------------------------
# --force
# ---------------------------------------------------------------------------

@test "--force reinstalls even when version matches" {
  make_curl_stub "uv" "1.2.3"
  make_fake_binary "uv" "uv 1.2.3" "$PREFIX"

  run "$SCRIPT" --prefix "$PREFIX" --force uv
  [ "$status" -eq 0 ]
  [[ "$output" != *"already up to date"* ]]
}

# ---------------------------------------------------------------------------
# GitHub API failures
# ---------------------------------------------------------------------------

@test "exits 1 when GitHub API returns empty version" {
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo '{"tag_name":""}'
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to resolve latest version"* ]]
}

@test "exits 1 when GitHub API returns null version" {
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo '{}'
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to resolve latest version"* ]]
}

# ---------------------------------------------------------------------------
# Installer failure
# ---------------------------------------------------------------------------

@test "exits 1 when installer curl fails" {
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *api.github.com* ]]; then
  echo '{"tag_name":"v1.2.3"}'
else
  exit 1
fi
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to download 'uv'"* ]]
}

@test "exits 1 when installer runs but binary is missing" {
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *api.github.com* ]]; then
  echo '{"tag_name":"v1.2.3"}'
else
  echo '#!/usr/bin/env sh'
  echo 'echo installer ran but dropped nothing'
fi
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 1 ]
  [[ "$output" == *"installer ran but"*"is not executable"* ]]
}

# ---------------------------------------------------------------------------
# Multiple tools — partial failure
# ---------------------------------------------------------------------------

@test "reports all failed tools and exits 1" {
  cat >"$TMPDIR_TEST/bin/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *api.github.com* ]]; then
  echo '{"tag_name":"v1.2.3"}'
else
  exit 1
fi
EOF
  chmod +x "$TMPDIR_TEST/bin/curl"

  run "$SCRIPT" --prefix "$PREFIX" uv ruff
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed for:"* ]]
  [[ "$output" == *"uv"* ]]
  [[ "$output" == *"ruff"* ]]
}

# ---------------------------------------------------------------------------
# Missing dependencies
# ---------------------------------------------------------------------------

@test "exits 1 when jq is missing" {
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'jq'"* ]]
}

@test "exits 1 when curl is missing" {
  rm "$TMPDIR_TEST/bin/curl"
  ln -sf "$(command -v bash)" "$TMPDIR_TEST/bin/bash"
  ln -sf "$(command -v env)" "$TMPDIR_TEST/bin/env"

  run env PATH="$TMPDIR_TEST/bin" "$SCRIPT" --prefix "$PREFIX" uv
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'curl'"* ]]
}

# ---------------------------------------------------------------------------
# --all
# ---------------------------------------------------------------------------

@test "--all skips all tools when all are up to date" {
  mock_latest_version "1.2.3"
  for tool in air jarl uv ruff prek; do
    make_fake_binary "$tool" "$tool 1.2.3" "$PREFIX"
  done

  run "$SCRIPT" --prefix "$PREFIX" --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}

# ---------------------------------------------------------------------------
# Prefix validation
# ---------------------------------------------------------------------------

@test "exits 2 when prefix directory does not exist" {
  run "$SCRIPT" --prefix "/nonexistent/prefix/$$" uv
  [ "$status" -eq 2 ]
  [[ "$output" == *"prefix directory does not exist"* ]]
}

@test "--prefix=DIR form accepted" {
  mock_latest_version "1.2.3"
  make_fake_binary "uv" "uv 1.2.3" "$PREFIX"

  run "$SCRIPT" "--prefix=$PREFIX" uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
}
