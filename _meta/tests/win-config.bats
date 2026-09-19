#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/win-config

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/win-config"

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

# wslpath -w is the identity here, so the reg.exe stub receives a path it can
# open directly; the test exercises the script's logic, not path conversion.
_install_interop_stubs() {
  _stub_command powershell.exe '
printf "C:\\\\FakeLocal\r\n"'

  _stub_command wslpath '
case "$1" in
-u)
  value="${2//\\//}"
  case "${value,,}" in
  c:/fakelocal*) printf "%s\n" "${LOCAL_DIR}${value:12}" ;;
  *) exit 1 ;;
  esac
  ;;
-w) printf "%s\n" "$2" ;;
esac'

  _stub_command reg.exe '
case "$1" in
export)
  body="${REG_BODY:-\"Enabled\"=dword:00000000}"
  [ -n "${EXPORT_FAILS:-}" ] && exit 1
  {
    printf "\xff\xfe"
    printf "Windows Registry Editor Version 5.00\r\n\r\n[%s]\r\n%s\r\n" "$2" "$body" |
      iconv -f UTF-8 -t UTF-16LE
  } >"$3"
  ;;
import)
  cp "$2" "${IMPORT_LOG}"
  ;;
esac
exit 0'
}

setup() {
  STUBS="$(mktemp -d)"
  LOCAL_DIR="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  FAKE_TMP="$(mktemp -d)"
  IMPORT_LOG="$(mktemp -u)"
  mkdir -p "${LOCAL_DIR}/Temp"
  export STUBS LOCAL_DIR FAKE_HOME FAKE_TMP IMPORT_LOG
  for cmd in cat awk sed tr diff iconv mktemp date rm mkdir cp; do
    [ -e "/usr/bin/${cmd}" ] && ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _install_interop_stubs
}

teardown() {
  rm -rf "$STUBS" "$LOCAL_DIR" "$FAKE_HOME" "$FAKE_TMP" "$IMPORT_LOG"
}

_run() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" TMPDIR="$FAKE_TMP" WSL_DISTRO_NAME=Ubuntu-test \
    LOCAL_DIR="$LOCAL_DIR" IMPORT_LOG="$IMPORT_LOG" \
    REG_BODY="${REG_BODY:-}" EXPORT_FAILS="${EXPORT_FAILS:-}" \
    "$BASH" "$SCRIPT" "$@"
}

_profile_dir() {
  printf '%s' "${FAKE_HOME}/dotfiles/_meta/profiles/windows"
}

# ─── argument handling ──────────────────────────────────────────────────────

@test "no argument prints usage and exits 0" {
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dump"* ]]
  [[ "$output" == *"explorer-advanced"* ]]
}

@test "an unknown command exits 1" {
  _run frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command"* ]]
}

@test "an unknown domain exits 1 and lists the known ones" {
  _run dump not-a-domain
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown domain"* ]]
  [[ "$output" == *"mouse"* ]]
}

@test "outside WSL the script refuses to run" {
  run env -u WSL_DISTRO_NAME PATH="$STUBS" HOME="$FAKE_HOME" "$BASH" "$SCRIPT" dump
  [ "$status" -eq 1 ]
  [[ "$output" == *"not running under WSL"* ]]
}

# ─── dump ───────────────────────────────────────────────────────────────────

@test "dump with no domain writes one file per domain" {
  _run dump
  [ "$status" -eq 0 ]
  [ "$(find "$(_profile_dir)" -maxdepth 1 -name '*.reg' | wc -l)" -eq 9 ]
  [ -f "$(_profile_dir)/mouse.reg" ]
}

@test "dump writes UTF-8 without CR and keeps the registry header" {
  _run dump advertising
  [ "$status" -eq 0 ]
  run file "$(_profile_dir)/advertising.reg"
  [[ "$output" != *"UTF-16"* ]]
  run grep -c $'\r' "$(_profile_dir)/advertising.reg"
  [ "$output" = "0" ]
  run head -1 "$(_profile_dir)/advertising.reg"
  [[ "$output" == "Windows Registry Editor Version 5.00" ]]
}

@test "dump leaves no transfer directory behind on the Windows side" {
  _run dump
  [ "$status" -eq 0 ]
  [ "$(find "${LOCAL_DIR}/Temp" -mindepth 1 | wc -l)" -eq 0 ]
}

@test "diff and restore leave no transfer directory behind" {
  _run dump advertising
  _run diff advertising
  _run restore advertising
  [ "$status" -eq 0 ]
  [ "$(find "${LOCAL_DIR}/Temp" -mindepth 1 | wc -l)" -eq 0 ]
}

@test "a failing export leaves no half-written profile behind" {
  EXPORT_FAILS=1 _run dump advertising
  [ "$status" -eq 1 ]
  [[ "$output" == *"export failed"* ]]
  [ ! -e "$(_profile_dir)/advertising.reg" ]
}

@test "the content-delivery filter drops the rotating subscription keys" {
  REG_BODY='"A"=dword:00000001

[HKCU\Subscriptions\314559]
"Payload"="junk"' _run dump content-delivery
  [ "$status" -eq 0 ]
  run grep -c Subscriptions "$(_profile_dir)/content-delivery.reg"
  [ "$output" = "0" ]
  run grep -c '"A"=dword' "$(_profile_dir)/content-delivery.reg"
  [ "$output" = "1" ]
}

# ─── diff ───────────────────────────────────────────────────────────────────

@test "diff exits 0 when the live state matches the profile" {
  _run dump advertising
  _run diff advertising
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "diff exits 1 and shows the drift" {
  _run dump advertising
  REG_BODY='"Enabled"=dword:00000001' _run diff advertising
  [ "$status" -eq 1 ]
  [[ "$output" == *"live:advertising"* ]]
  [[ "$output" == *"dword:00000001"* ]]
}

@test "diff without a profile exits 1 and names the missing file" {
  _run diff advertising
  [ "$status" -eq 1 ]
  [[ "$output" == *"No dump file"* ]]
}

# ─── restore ────────────────────────────────────────────────────────────────

@test "restore backs the live state up before importing" {
  _run dump advertising
  _run restore advertising
  [ "$status" -eq 0 ]
  [[ "$output" == *"backed up advertising to ${FAKE_TMP}/win-config-backup-advertising-"* ]]
  [[ "$output" == *"restored advertising"* ]]
  [ "$(find "$FAKE_TMP" -name 'win-config-backup-advertising-*' | wc -l)" -eq 1 ]
}

@test "restore stages UTF-16LE with a BOM and CRLF endings" {
  _run dump advertising
  _run restore advertising
  [ "$status" -eq 0 ]
  run file -b "$IMPORT_LOG"
  [[ "$output" == *"Windows Registry"* ]]
  run bash -c "head -c 2 '$IMPORT_LOG' | od -An -tx1 | tr -d ' \n'"
  [ "$output" = "fffe" ]
  run bash -c "iconv -f UTF-16LE -t UTF-8 <'$IMPORT_LOG' | grep -c \$'\r'"
  [ "$output" -gt 0 ]
}

@test "restore without a profile exits 1 and imports nothing" {
  _run restore advertising
  [ "$status" -eq 1 ]
  [[ "$output" == *"No dump file"* ]]
  [ ! -e "$IMPORT_LOG" ]
}
