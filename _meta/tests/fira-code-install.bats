#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/fira-code-install
#
# Every command with a system side effect is stubbed, Windows executables
# included, so no test touches apt, the Windows registry or the real user font
# directory; coreutils such as mktemp, cp and rm run for real. The
# Windows side resolves %LOCALAPPDATA% to ${WIN_ROOT} through the wslpath stub.

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/fira-code-install"
FONTS=(FiraCode-Bold FiraCode-Light FiraCode-Medium FiraCode-Regular FiraCode-Retina FiraCode-SemiBold)

# ─── stub factory ───────────────────────────────────────────────────────────
#
#   DPKG_STATUS      status printed by dpkg-query for fonts-firacode
#   REG_PRESENT      1 when `reg.exe query` finds the value
#   REG_MISSING      value name `reg.exe query` misses even when REG_PRESENT=1
#   SHA_EXIT         exit code of the sha256sum stub
#   WIN_LOCALAPPDATA value printed by powershell.exe
#   PS_EXIT          exit code of the powershell.exe stub
#   WSLPATH_EXIT     exit code of the wslpath stub
#
# Side effects land in $STATE: apt-args, curl-args, sha-input, unzip-args,
# reg-add, powershell-args.

_create_stubs() {
  cat >"${STUBS}/dpkg-query" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${DPKG_STATUS}"
EOF

  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF

  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/apt-args"
EOF

  cat >"${STUBS}/powershell.exe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/powershell-args"
[ "${PS_EXIT:-0}" -eq 0 ] || exit "${PS_EXIT}"
printf '%s\r\n' "${WIN_LOCALAPPDATA}"
EOF

  cat >"${STUBS}/wslpath" <<'EOF'
#!/usr/bin/env bash
[ "${WSLPATH_EXIT:-0}" -eq 0 ] || exit "${WSLPATH_EXIT}"
printf '%s\n' "${WIN_ROOT}"
EOF

  cat >"${STUBS}/reg.exe" <<'EOF'
#!/usr/bin/env bash
case "$1" in
query) [ "${REG_PRESENT:-0}" = 1 ] && [ "$4" != "${REG_MISSING:-}" ] ;;
add) printf '%s\n' "$*" >>"${STATE}/reg-add" ;;
esac
EOF

  cat >"${STUBS}/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/curl-args"
output_file=""
next_o=0
for arg in "$@"; do
    [ "$next_o" = 1 ] && { output_file="$arg"; next_o=0; continue; }
    [ "$arg" = "-o" ] && next_o=1
done
printf 'zip payload\n' >"$output_file"
EOF

  cat >"${STUBS}/sha256sum" <<'EOF'
#!/usr/bin/env bash
cat >>"${STATE}/sha-input"
exit "${SHA_EXIT:-0}"
EOF

  # unzip ─ materialises the static cuts under the -d directory
  cat >"${STUBS}/unzip" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STATE}/unzip-args"
dest=""
next_d=0
for arg in "$@"; do
    [ "$next_d" = 1 ] && { dest="$arg"; next_d=0; continue; }
    [ "$arg" = "-d" ] && next_d=1
done
mkdir -p "$dest"
for f in FiraCode-Bold FiraCode-Light FiraCode-Medium FiraCode-Regular FiraCode-Retina FiraCode-SemiBold; do
    printf 'ttf\n' >"${dest}/${f}.ttf"
done
EOF

  chmod +x "${STUBS}"/*
}

_populate_font_dir() {
  local f
  mkdir -p "${FONT_DIR}"
  for f in "${FONTS[@]}"; do
    printf 'ttf\n' >"${FONT_DIR}/${f}.ttf"
  done
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  TEST_TMP="$(mktemp -d)"
  STUBS="${TEST_TMP}/bin"
  STATE="${TEST_TMP}/state"
  mkdir -p "${STUBS}" "${STATE}" "${TEST_TMP}/tmp"
  export TEST_TMP STUBS STATE

  export TMPDIR="${TEST_TMP}/tmp"
  export WIN_ROOT="${TEST_TMP}/win/Local"
  export FONT_DIR="${WIN_ROOT}/Microsoft/Windows/Fonts"
  export WIN_LOCALAPPDATA='C:\Users\tester\AppData\Local'
  export WSL_DISTRO_NAME="Ubuntu-24.04"
  export DPKG_STATUS="installed"
  export REG_PRESENT=0
  export SHA_EXIT=0

  _create_stubs
  export PATH="${STUBS}:/usr/bin:/bin"
}

teardown() {
  rm -rf "${TEST_TMP}"
}

# ─── invocation ─────────────────────────────────────────────────────────────

@test "is executable" {
  [ -x "${SCRIPT}" ]
}

@test "rejects any argument with a usage message and installs nothing" {
  export DPKG_STATUS=""
  run bash "${SCRIPT}" --help
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage: fira-code-install (takes no arguments)"* ]]
  [ ! -f "${STATE}/apt-args" ]
  [ ! -f "${STATE}/powershell-args" ]
}

# ─── Linux side ─────────────────────────────────────────────────────────────

@test "skips apt when fonts-firacode is already installed" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Linux: fonts-firacode already installed."* ]]
  [ ! -f "${STATE}/apt-args" ]
}

@test "installs fonts-firacode through apt when absent" {
  export DPKG_STATUS=""
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(cat "${STATE}/apt-args")" = "install -y fonts-firacode" ]
}

@test "treats a deinstalled package as absent" {
  export DPKG_STATUS="config-files"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/apt-args" ]
}

# ─── WSL detection ──────────────────────────────────────────────────────────

@test "skips the Windows install outside WSL" {
  unset WSL_DISTRO_NAME
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Not running under WSL: Windows install skipped."* ]]
  [ ! -f "${STATE}/powershell-args" ]
}

@test "exits 1 naming interop when WSL has no powershell.exe" {
  rm -f "${STUBS}/powershell.exe"
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"WSL interop unavailable (powershell.exe not on PATH)"* ]]
  [[ "$output" != *"Not running under WSL"* ]]
  [ ! -f "${STATE}/curl-args" ]
}

@test "exits 1 when %LOCALAPPDATA% resolves to nothing" {
  export WIN_LOCALAPPDATA=""
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot resolve %LOCALAPPDATA%"* ]]
}

@test "exits 1 with a message when powershell.exe itself fails" {
  export PS_EXIT=5
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot resolve %LOCALAPPDATA%"* ]]
}

@test "exits 1 with a message when wslpath cannot convert the path" {
  export WSLPATH_EXIT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot convert C:\Users\tester\AppData\Local to a WSL path"* ]]
  [ ! -f "${STATE}/curl-args" ]
}

# ─── Windows idempotence ────────────────────────────────────────────────────

@test "downloads nothing when every font is copied and registered" {
  _populate_font_dir
  export REG_PRESENT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Windows: Fira Code already installed"* ]]
  [ ! -f "${STATE}/curl-args" ]
}

@test "reinstalls when the registry holds the values but a file is missing" {
  _populate_font_dir
  rm -f "${FONT_DIR}/FiraCode-Retina.ttf"
  export REG_PRESENT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${FONT_DIR}/FiraCode-Retina.ttf" ]
}

@test "reinstalls when a single registry value is missing" {
  _populate_font_dir
  export REG_PRESENT=1
  export REG_MISSING="FiraCode-Retina (TrueType)"
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/curl-args" ]
  [ "$(wc -l <"${STATE}/reg-add")" -eq 6 ]
}

@test "reinstalls when the files exist but the registry does not" {
  _populate_font_dir
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -f "${STATE}/curl-args" ]
}

# ─── Windows install ────────────────────────────────────────────────────────

@test "downloads the pinned 6.2 release archive" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/curl-args")" == *"https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"* ]]
}

@test "verifies the archive against the pinned digest" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/sha-input")" == "0949915ba8eb24d89fd93d10a7ff623f42830d7c5ffc3ecbf960e4ecad3e3e79  "* ]]
}

@test "aborts before writing to Windows on a checksum mismatch" {
  export SHA_EXIT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [[ "$output" == *"checksum mismatch"* ]]
  [ ! -d "${FONT_DIR}" ]
  [ ! -f "${STATE}/reg-add" ]
}

@test "extracts the static cuts only" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [[ "$(cat "${STATE}/unzip-args")" == *"ttf/*.ttf"* ]]
  [[ "$(cat "${STATE}/unzip-args")" != *"variable_ttf"* ]]
}

@test "copies the six static fonts into the per-user font directory" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  for f in "${FONTS[@]}"; do
    [ -f "${FONT_DIR}/${f}.ttf" ]
  done
  [ "$(find "${FONT_DIR}" -name '*.ttf' | wc -l)" -eq 6 ]
}

@test "registers each font under HKCU with its Windows path" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"${STATE}/reg-add")" -eq 6 ]
  grep -qF 'add HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts /v FiraCode-Regular (TrueType) /t REG_SZ /d C:\Users\tester\AppData\Local\Microsoft\Windows\Fonts\FiraCode-Regular.ttf /f' "${STATE}/reg-add"
}

@test "removes its temporary directory on success" {
  run bash "${SCRIPT}"
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "${TMPDIR}")" ]
}

@test "removes its temporary directory when it aborts" {
  export SHA_EXIT=1
  run bash "${SCRIPT}"
  [ "$status" -eq 1 ]
  [ -z "$(ls -A "${TMPDIR}")" ]
}
