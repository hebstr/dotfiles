#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/win-cleanup

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/win-cleanup"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs live in ${STUBS} and the test sets PATH=${STUBS}, so the script sees
# only what a test explicitly provides. Dropping a stub is how "interop
# unavailable" is simulated.

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

# %LOCALAPPDATA% resolves to C:\FakeLocal and the Steam install to C:\FakeSteam;
# the wslpath stub maps both onto temp directories the tests populate.
_install_interop_stubs() {
  _stub_command powershell.exe '
for arg in "$@"; do
  case "$arg" in
  *LOCALAPPDATA*) printf "lookup\n" >>"${LA_LOG}"; printf "C:\\\\FakeLocal\r\n"; exit 0 ;;
  *Clear-RecycleBin*) printf "recyclebin\n" >>"${PS_LOG}"; exit 0 ;;
  *Start-Process*) printf "elevate\n" >>"${PS_LOG}"; exit 0 ;;
  esac
done
exit 0'

  # The Windows volume is case-insensitive, so the stub matches case-insensitively
  # and keeps the caller casing in the remainder.
  _stub_command wslpath '
value="$2"
case "$1" in
-u)
  value="${value//\\//}"
  case "${value,,}" in
  c:/fakelocal*) printf "%s\n" "${LOCAL_DIR}${value:12}" ;;
  c:/fakesteam*) printf "%s\n" "${STEAM_DIR}${value:12}" ;;
  *) exit 1 ;;
  esac
  ;;
-w) printf "C:\\\\win%s\n" "$value" ;;
esac'

  _stub_command reg.exe '
printf "\r\nHKEY_CURRENT_USER\\Software\\Valve\\Steam\r\n    SteamPath    REG_SZ    c:/fakesteam\r\n\r\n"'

  _stub_command tasklist.exe '
printf "%s\n" "${RUNNING_IMAGES:-}"'
}

setup() {
  STUBS="$(mktemp -d)"
  LOCAL_DIR="$(mktemp -d)"
  STEAM_DIR="$(mktemp -d)"
  PS_LOG="$(mktemp -u)"
  LA_LOG="$(mktemp -u)"
  export STUBS LOCAL_DIR STEAM_DIR PS_LOG LA_LOG
  for cmd in cat paste du awk df find grep sed sort tr rm mktemp; do
    [ -e "/usr/bin/${cmd}" ] && ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _install_interop_stubs
}

teardown() {
  rm -rf "$STUBS" "$LOCAL_DIR" "$STEAM_DIR" "$PS_LOG" "$LA_LOG"
}

_run() {
  run env PATH="$STUBS" WSL_DISTRO_NAME=Ubuntu-test \
    LOCAL_DIR="$LOCAL_DIR" STEAM_DIR="$STEAM_DIR" PS_LOG="$PS_LOG" LA_LOG="$LA_LOG" \
    RUNNING_IMAGES="${RUNNING_IMAGES:-}" \
    "$BASH" "$SCRIPT" "$@"
}

# ─── argument handling ──────────────────────────────────────────────────────

@test "--help exits 0 and names the modules" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"nvidia-cache"* ]]
  [[ "$output" == *"component-store"* ]]
}

@test "--list marks the admin modules and only those" {
  _run --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"windows-temp         yes"* ]]
  [[ "$output" == *"component-store      yes"* ]]
  [[ "$output" == *"nvidia-cache         no"* ]]
}

@test "an unknown module exits 2" {
  _run not-a-module
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown module"* ]]
}

@test "an unknown option exits 2" {
  _run --frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

# ─── environment guards ─────────────────────────────────────────────────────

@test "outside WSL the script refuses to run" {
  run env -u WSL_DISTRO_NAME PATH="$STUBS" "$BASH" "$SCRIPT" nvidia-cache
  [ "$status" -eq 1 ]
  [[ "$output" == *"not running under WSL"* ]]
}

@test "a missing interop binary refuses to run and names it" {
  rm -f "${STUBS}/tasklist.exe"
  _run nvidia-cache
  [ "$status" -eq 1 ]
  [[ "$output" == *"tasklist.exe"* ]]
}

@test "--list works before the WSL guard, so it runs anywhere" {
  run env PATH="$STUBS" "$BASH" "$SCRIPT" --list
  [ "$status" -eq 0 ]
}

# ─── module behaviour ───────────────────────────────────────────────────────

@test "nvidia-cache empties DXCache and GLCache and reports the bytes" {
  mkdir -p "${LOCAL_DIR}/NVIDIA/DXCache" "${LOCAL_DIR}/NVIDIA/GLCache"
  head -c 4096 /dev/zero >"${LOCAL_DIR}/NVIDIA/DXCache/shader.bin"
  head -c 2048 /dev/zero >"${LOCAL_DIR}/NVIDIA/GLCache/gl.bin"
  _run nvidia-cache
  [ "$status" -eq 0 ]
  [ ! -e "${LOCAL_DIR}/NVIDIA/DXCache/shader.bin" ]
  [ ! -e "${LOCAL_DIR}/NVIDIA/GLCache/gl.bin" ]
  [ -d "${LOCAL_DIR}/NVIDIA/DXCache" ]
  [[ "$output" == *"KiB"* ]]
}

@test "%LOCALAPPDATA% is resolved once per run, not once per module" {
  _run nvidia-cache user-temp firefox-cache explorer-cache crashdumps windows-temp
  [ "$status" -eq 0 ]
  [ "$(grep -c lookup "$LA_LOG")" -eq 1 ]
}

@test "--dry-run removes nothing" {
  mkdir -p "${LOCAL_DIR}/NVIDIA/DXCache"
  head -c 4096 /dev/zero >"${LOCAL_DIR}/NVIDIA/DXCache/shader.bin"
  _run --dry-run nvidia-cache
  [ "$status" -eq 0 ]
  [ -e "${LOCAL_DIR}/NVIDIA/DXCache/shader.bin" ]
  [[ "$output" == *"[dry-run]"* ]]
}

@test "user-temp spares entries younger than the age floor" {
  mkdir -p "${LOCAL_DIR}/Temp"
  head -c 1024 /dev/zero >"${LOCAL_DIR}/Temp/fresh.tmp"
  head -c 1024 /dev/zero >"${LOCAL_DIR}/Temp/stale.tmp"
  touch -d '10 days ago' "${LOCAL_DIR}/Temp/stale.tmp"
  _run user-temp
  [ "$status" -eq 0 ]
  [ -e "${LOCAL_DIR}/Temp/fresh.tmp" ]
  [ ! -e "${LOCAL_DIR}/Temp/stale.tmp" ]
}

@test "steam-cache counts one library when registry and vdf disagree on case" {
  mkdir -p "${STEAM_DIR}/steamapps/shadercache/123"
  cat >"${STEAM_DIR}/steamapps/libraryfolders.vdf" <<'EOF'
"libraryfolders"
{
	"0"
	{
		"path"		"C:\\FakeSteam"
	}
}
EOF
  _run steam-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (1 library)"* ]]
  [ ! -e "${STEAM_DIR}/steamapps/shadercache/123" ]
}

@test "steam-cache skips while steam is running" {
  mkdir -p "${STEAM_DIR}/steamapps/shadercache/123"
  RUNNING_IMAGES="steam.exe" _run steam-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped (steam running)"* ]]
  [ -e "${STEAM_DIR}/steamapps/shadercache/123" ]
}

@test "firefox-cache skips while firefox is running" {
  mkdir -p "${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/cache2"
  head -c 1024 /dev/zero >"${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/cache2/entry"
  RUNNING_IMAGES="firefox.exe" _run firefox-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped (firefox running)"* ]]
  [ -e "${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/cache2/entry" ]
}

@test "firefox-cache empties cache2 and leaves the profile alone" {
  mkdir -p "${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/cache2"
  head -c 2048 /dev/zero >"${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/cache2/entry"
  head -c 512 /dev/zero >"${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/prefs.js"
  _run firefox-cache
  [ "$status" -eq 0 ]
  [ ! -e "${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/cache2/entry" ]
  [ -e "${LOCAL_DIR}/Mozilla/Firefox/Profiles/abc.default/prefs.js" ]
}

@test "explorer-cache removes the thumbnail databases and spares the rest" {
  mkdir -p "${LOCAL_DIR}/Microsoft/Windows/Explorer"
  head -c 1024 /dev/zero >"${LOCAL_DIR}/Microsoft/Windows/Explorer/thumbcache_32.db"
  head -c 1024 /dev/zero >"${LOCAL_DIR}/Microsoft/Windows/Explorer/iconcache_16.db"
  head -c 1024 /dev/zero >"${LOCAL_DIR}/Microsoft/Windows/Explorer/keepme.dat"
  _run explorer-cache
  [ "$status" -eq 0 ]
  [ ! -e "${LOCAL_DIR}/Microsoft/Windows/Explorer/thumbcache_32.db" ]
  [ ! -e "${LOCAL_DIR}/Microsoft/Windows/Explorer/iconcache_16.db" ]
  [ -e "${LOCAL_DIR}/Microsoft/Windows/Explorer/keepme.dat" ]
}

# ─── elevated batch ─────────────────────────────────────────────────────────

@test "--dry-run prints the elevated batch without elevating" {
  _run --dry-run windows-temp component-store
  [ "$status" -eq 0 ]
  [[ "$output" == *"elevated batch"* ]]
  [[ "$output" == *"Dism.exe"* ]]
  [[ "$output" == *'C:\Windows\Temp'* ]]
  [ ! -e "$PS_LOG" ]
}

@test "both admin modules elevate once, not once each" {
  _run windows-temp component-store
  [ "$status" -eq 0 ]
  [ "$(grep -c elevate "$PS_LOG")" -eq 1 ]
}

@test "a declined elevation marks the admin modules failed" {
  _stub_command powershell.exe '
for arg in "$@"; do
  case "$arg" in
  *LOCALAPPDATA*) printf "C:\\\\FakeLocal\r\n"; exit 0 ;;
  esac
done
exit 0'
  _run windows-temp
  [ "$status" -eq 0 ]
  [[ "$output" == *"failed (not elevated)"* ]]
}
