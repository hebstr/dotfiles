#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/llama-update

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/llama-update"

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

# A fake build: llama-server reports its build number, llama-cli lists a CUDA
# device unless the build was made without one.
_make_build_dir() {
  local dir="$1" num="$2" cuda="${3:-yes}"
  mkdir -p "$dir"
  cat >"${dir}/llama-server" <<EOF
#!/usr/bin/env bash
echo "version: 0.4.1-dev (build ${num}, commit abc1234)"
EOF
  if [ "$cuda" = yes ]; then
    printf '#!/usr/bin/env bash\necho "Available devices:"\necho "  CUDA0: FAKE GPU (12288 MiB)"\n' >"${dir}/llama-cli"
  else
    printf '#!/usr/bin/env bash\necho "Available devices:"\n' >"${dir}/llama-cli"
  fi
  chmod +x "${dir}/llama-server" "${dir}/llama-cli"
}

# Release archives shaped like upstream's: binaries under llama-<tag>/, the
# CUDA runtime as loose files.
_make_release() {
  local tag="$1" cuda="${2:-yes}" ver="${3:-12.8}" work
  work="$(mktemp -d)"
  _make_build_dir "${work}/main/llama-${tag}" "${tag#b}" "$cuda"
  mkdir -p "${work}/rt"
  touch "${work}/rt/libcudart.so.12"
  tar -czf "${FIXTURES}/llama-${tag}-bin-ubuntu-cuda-${ver}-x64.tar.gz" -C "${work}/main" .
  tar -czf "${FIXTURES}/cudart-llama-${tag}-bin-ubuntu-cuda-${ver}-x64.tar.gz" -C "${work}/rt" .
  rm -rf "$work"
}

_install_curl_stub() {
  _stub_command curl '
printf "%s\n" "$*" >>"${CURL_LOG}"
out= url= head=
while [ $# -gt 0 ]; do
  case "$1" in
  -o) out="$2"; shift ;;
  -*I*) head=1 ;;
  http*) url="$1" ;;
  esac
  shift
done
case "$url" in
*/latest/download/nightly-tag.txt)
  [ -n "${NIGHTLY_FAILS:-}" ] && exit 22
  printf "%s\n" "${FAKE_NIGHTLY:-b200}"
  exit 0
  ;;
esac
src="${FIXTURES}/${url##*/}"
if [ -n "$head" ]; then
  [ -n "${HEAD_FAILS:-}" ] && exit "$HEAD_FAILS"
  [ -e "$src" ] || exit 22
  exit 0
fi
[ -n "${DOWNLOAD_FAILS:-}" ] && exit 22
[ -e "$src" ] || exit 22
cp "$src" "$out"'
}

# Each page file holds "<tag> <1|0>" lines, 1 when the build ships both CUDA
# archives, newest first as the releases API returns them. A "<page>.json"
# file holds a raw API page instead and goes through the script's own --jq
# filter, run by the real jq.
_install_gh_stub() {
  _stub_command gh '
page=1 filter=
while [ $# -gt 0 ]; do
  case "$1" in
  --jq) filter="$2"; shift ;;
  *page=*) page="${1##*page=}" ;;
  esac
  shift
done
[ -n "${GH_FAILS:-}" ] && exit 1
if [ -e "${GH_PAGES}/${page}.json" ]; then
  jq -r "$filter" "${GH_PAGES}/${page}.json"
elif [ -e "${GH_PAGES}/${page}" ]; then
  cat "${GH_PAGES}/${page}"
fi
exit 0'
}

# One API page where b302 ships both 12.8 archives, b301 ships 12.4 ones only,
# b300 only the main 12.8 archive, and a v* release sits among the builds.
_gh_json_page_mixed() {
  cat >"${GH_PAGES}/1.json" <<'EOF'
[
  {"tag_name": "b302", "assets": [
    {"name": "llama-b302-bin-ubuntu-cuda-12.8-x64.tar.gz"},
    {"name": "cudart-llama-b302-bin-ubuntu-cuda-12.8-x64.tar.gz"}]},
  {"tag_name": "b301", "assets": [
    {"name": "llama-b301-bin-ubuntu-cuda-12.4-x64.tar.gz"},
    {"name": "cudart-llama-b301-bin-ubuntu-cuda-12.4-x64.tar.gz"}]},
  {"tag_name": "b300", "assets": [
    {"name": "llama-b300-bin-ubuntu-cuda-12.8-x64.tar.gz"}]},
  {"tag_name": "v0.4.1", "assets": []},
  {"tag_name": "b299", "assets": []}
]
EOF
}

_gh_page() {
  printf "%s\n" "${@:2}" >"${GH_PAGES}/$1"
}

setup() {
  STUBS="$(mktemp -d)"
  ROOT="$(mktemp -d)"
  FIXTURES="$(mktemp -d)"
  CURL_LOG="$(mktemp -u)"
  GH_PAGES="$(mktemp -d)"
  export STUBS ROOT FIXTURES CURL_LOG GH_PAGES
  OPT="${ROOT}/opt"
  BIN="${ROOT}/bin"
  STAGE_DIR="${ROOT}/stage"
  for cmd in cat sed tr grep sort mkdir mktemp rm cp mv ln readlink dirname find tar gzip touch jq; do
    [ -e "/usr/bin/${cmd}" ] && ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _stub_command uname 'echo x86_64'
  _stub_command pgrep 'exit 1'
  _install_curl_stub
  _install_gh_stub
}

teardown() {
  rm -rf "$STUBS" "$ROOT" "$FIXTURES" "$CURL_LOG" "$GH_PAGES"
}

_run() {
  run env PATH="$STUBS" HOME="$ROOT" FIXTURES="$FIXTURES" CURL_LOG="$CURL_LOG" \
    GH_PAGES="$GH_PAGES" GH_FAILS="${GH_FAILS:-}" HEAD_FAILS="${HEAD_FAILS:-}" \
    FAKE_NIGHTLY="${FAKE_NIGHTLY:-}" NIGHTLY_FAILS="${NIGHTLY_FAILS:-}" \
    DOWNLOAD_FAILS="${DOWNLOAD_FAILS:-}" ${LLAMA_CUDA:+"LLAMA_CUDA=$LLAMA_CUDA"} \
    LLAMA_OPT_ROOT="$OPT" LLAMA_BIN_DIR="$BIN" LLAMA_STAGE="$STAGE_DIR" \
    LLAMA_RELEASES="https://example.test/releases" \
    "$BASH" "$SCRIPT" "$@"
}

# An install already in the llama-update layout, active on the given tag.
_installed() {
  local tag
  mkdir -p "$OPT"
  for tag in "$@"; do
    _make_build_dir "${OPT}/llama.cpp-${tag}" "${tag#b}"
  done
  ln -sfn "llama.cpp-${!#}" "${OPT}/llama.cpp"
}

_active() { readlink "${OPT}/llama.cpp"; }

# ─── argument handling ──────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: llama-update"* ]]
  [[ "$output" == *"--list"* ]]
}

@test "an unknown argument exits 1 and names it" {
  _run --frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument: --frobnicate"* ]]
}

@test "a malformed tag is refused before anything is downloaded or moved" {
  _make_build_dir "${OPT}/llama.cpp" 11065
  _run v0.4.1
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a build tag: v0.4.1"* ]]
  [ ! -e "$CURL_LOG" ]
  [ ! -L "${OPT}/llama.cpp" ]
}

@test "a second tag is refused" {
  _run b100 b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"only one tag is accepted"* ]]
}

@test "a malformed LLAMA_CUDA is refused before anything is downloaded" {
  LLAMA_CUDA=12 _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"LLAMA_CUDA must read like 12.8, got '12'"* ]]
  [ ! -e "$CURL_LOG" ]
}

@test "a machine other than x86_64 is refused" {
  _stub_command uname 'echo aarch64'
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"this machine is aarch64"* ]]
}

@test "a missing tar is named before anything is downloaded" {
  rm "${STUBS}/tar"
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"tar is required"* ]]
  [ ! -e "$CURL_LOG" ]
}

# ─── fresh install ──────────────────────────────────────────────────────────

@test "an explicit tag installs the build and links it" {
  _make_release b200
  _run b200
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b200" ]
  [ -x "${OPT}/llama.cpp-b200/llama-server" ]
  [ -e "${OPT}/llama.cpp-b200/libcudart.so.12" ]
  [ "$(readlink "${BIN}/llama-server")" = "${OPT}/llama.cpp/llama-server" ]
}

@test "the staged downloads are removed once the build is in place" {
  _make_release b200
  _run b200
  [ "$status" -eq 0 ]
  [ ! -e "$STAGE_DIR" ]
}

@test "without a tag the build named by nightly-tag.txt is installed" {
  _make_release b300
  _gh_page 1 "b302 1" "b300 1" "b299 1"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Latest stable build: b300"* ]]
  [ "$(_active)" = "llama.cpp-b300" ]
}

@test "a stable build without CUDA archives gives way to the first later one that has them" {
  _make_release b302
  _gh_page 1 "b305 1" "b302 1" "b301 0" "b300 0" "b299 1"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"b300 ships no CUDA 12.8 x64 archives, taking b302"* ]]
  [ "$(_active)" = "llama.cpp-b302" ]
}

@test "the release scan pages until it passes below the stable build" {
  _make_release b302
  _gh_page 1 "b310 0" "b305 0"
  _gh_page 2 "b302 1" "b300 0" "b298 1"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b302" ]
}

@test "a qualifying build on a later page beats a newer one on the first" {
  _make_release b302
  _gh_page 1 "b310 1" "b305 1"
  _gh_page 2 "b302 1" "b300 0" "b298 1"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b302" ]
}

@test "the release scan stops after ten pages" {
  local p
  for p in 1 2 3 4 5 6 7 8 9 10; do
    _gh_page "$p" "b$((400 - p)) 0"
  done
  _gh_page 11 "b320 1"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"no build at or after b300"* ]]
}

@test "the release filter requires both archives for the configured CUDA version" {
  _make_release b302
  _gh_json_page_mixed
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"b300 ships no CUDA 12.8 x64 archives, taking b302"* ]]
  [ "$(_active)" = "llama.cpp-b302" ]
}

@test "LLAMA_CUDA selects the archives both in the release filter and the download" {
  _make_release b301 yes 12.4
  _gh_json_page_mixed
  LLAMA_CUDA=12.4 FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b301" ]
  grep -q "download/b301/llama-b301-bin-ubuntu-cuda-12.4-x64.tar.gz" "$CURL_LOG"
  run ! grep -q "cuda-12.8" "$CURL_LOG"
}

@test "no CUDA build at or after the stable one fails loudly and changes nothing" {
  _installed b100
  _gh_page 1 "b301 0" "b300 0" "b299 1"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"no build at or after b300 ships the CUDA 12.8 x64 archives"* ]]
  [ "$(_active)" = "llama.cpp-b100" ]
}

@test "without a tag a default older than the active build leaves it in place" {
  _installed b400
  _make_release b302
  _gh_page 1 "b405 1" "b302 1" "b300 0"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"active b400 is newer than the default b302"* ]]
  [ "$(_active)" = "llama.cpp-b400" ]
  run ! grep -q -- "-C -" "$CURL_LOG"
}

@test "without a tag a default equal to the active build is a no-op" {
  _installed b302
  _gh_page 1 "b302 1" "b300 0"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on b302"* ]]
}

@test "an explicit older tag still downgrades" {
  _installed b400
  _make_release b200
  _run b200
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b200" ]
  [ -d "${OPT}/llama.cpp-b400" ]
}

@test "without gh the default build cannot be resolved" {
  rm "${STUBS}/gh"
  FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required to resolve the default build"* ]]
}

@test "a failing release listing asks for an explicit tag" {
  GH_FAILS=1 FAKE_NIGHTLY=b300 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not list the releases through gh"* ]]
}

@test "an explicit tag without CUDA archives fails before any download" {
  _installed b100
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"build b200 publishes no llama-b200-bin-ubuntu-cuda-12.8-x64.tar.gz"* ]]
  run ! grep -q -- "-C -" "$CURL_LOG"
  [ "$(_active)" = "llama.cpp-b100" ]
}

@test "an unreachable host is not reported as a missing archive" {
  _make_release b200
  HEAD_FAILS=6 _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not reach"* ]]
  [[ "$output" != *"publishes no"* ]]
}

@test "a nightly-tag.txt that names no build fails loudly and changes nothing" {
  _installed b100
  FAKE_NIGHTLY=v0.4.1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"names 'v0.4.1'"* ]]
  [ "$(_active)" = "llama.cpp-b100" ]
}

@test "an unreachable nightly-tag.txt asks for an explicit tag" {
  NIGHTLY_FAILS=1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"pass a tag"* ]]
}

# ─── failures leave the active build alone ──────────────────────────────────

@test "a build that lists no CUDA device is not switched to" {
  _installed b100
  _make_release b200 no
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"lists no CUDA0 device"* ]]
  [ "$(_active)" = "llama.cpp-b100" ]
  [ ! -e "${OPT}/llama.cpp-b200" ]
  run ! compgen -G "${OPT}/.llama.cpp-*"
}

@test "an archive holding no llama-server fails and keeps the active build" {
  local work
  _installed b100
  work="$(mktemp -d)"
  mkdir -p "${work}/main/llama-b200" "${work}/rt"
  touch "${work}/main/llama-b200/README.md" "${work}/rt/libcudart.so.12"
  tar -czf "${FIXTURES}/llama-b200-bin-ubuntu-cuda-12.8-x64.tar.gz" -C "${work}/main" .
  tar -czf "${FIXTURES}/cudart-llama-b200-bin-ubuntu-cuda-12.8-x64.tar.gz" -C "${work}/rt" .
  rm -rf "$work"
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"no llama-server in llama-b200-bin-ubuntu-cuda-12.8-x64.tar.gz"* ]]
  [ "$(_active)" = "llama.cpp-b100" ]
  [ ! -e "${OPT}/llama.cpp-b200" ]
  run ! compgen -G "${STAGE_DIR}/extract.*"
}

@test "a partial tree left by an interrupted run is replaced, not merged" {
  _make_release b200
  mkdir -p "${OPT}/.llama.cpp-b200.partial"
  touch "${OPT}/.llama.cpp-b200.partial/stale"
  _run b200
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b200" ]
  [ ! -e "${OPT}/llama.cpp-b200/stale" ]
  [ ! -e "${OPT}/.llama.cpp-b200.partial" ]
}

@test "a failed download keeps the active build and says it resumes" {
  _installed b100
  _make_release b200
  DOWNLOAD_FAILS=1 _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"rerun to resume"* ]]
  [ "$(_active)" = "llama.cpp-b100" ]
}

@test "downloads are requested with resume and retries" {
  _make_release b200
  _run b200
  [ "$status" -eq 0 ]
  grep -q -- "-C - --retry 5" "$CURL_LOG"
  grep -q "download/b200/cudart-llama-b200-bin-ubuntu-cuda-12.8-x64.tar.gz" "$CURL_LOG"
}

# ─── migration from the plain directory ─────────────────────────────────────

@test "a plain install directory is moved under its build tag" {
  _make_build_dir "${OPT}/llama.cpp" 11065
  _make_release b200
  _run b200
  [ "$status" -eq 0 ]
  [[ "$output" == *"Moving the existing install to ${OPT}/llama.cpp-b11065"* ]]
  [ -x "${OPT}/llama.cpp-b11065/llama-server" ]
  [ "$(_active)" = "llama.cpp-b200" ]
}

@test "migration onto the build already installed downloads nothing" {
  _make_build_dir "${OPT}/llama.cpp" 11065
  _run b11065
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on b11065"* ]]
  [ "$(_active)" = "llama.cpp-b11065" ]
  [ ! -e "$CURL_LOG" ]
}

@test "a plain directory whose build cannot be read is left in place" {
  mkdir -p "${OPT}/llama.cpp"
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"move it aside by hand"* ]]
  [ -d "${OPT}/llama.cpp" ]
  [ ! -L "${OPT}/llama.cpp" ]
}

@test "a plain directory whose tagged name is taken is left in place" {
  _make_build_dir "${OPT}/llama.cpp" 11065
  _make_build_dir "${OPT}/llama.cpp-b11065" 11065
  _run b200
  [ "$status" -eq 1 ]
  [[ "$output" == *"llama.cpp-b11065 already exists beside the directory"* ]]
  [ -d "${OPT}/llama.cpp" ]
  [ ! -L "${OPT}/llama.cpp" ]
}

# ─── rollback, retention, idempotence ───────────────────────────────────────

@test "a tag already on disk is switched to without downloading" {
  _installed b100 b200
  _run b100
  [ "$status" -eq 0 ]
  [[ "$output" == *"without downloading"* ]]
  [ "$(_active)" = "llama.cpp-b100" ]
  [ ! -e "$CURL_LOG" ]
}

@test "a build on disk that lists no CUDA device is not switched to" {
  _installed b200
  _make_build_dir "${OPT}/llama.cpp-b100" 100 no
  _run b100
  [ "$status" -eq 1 ]
  [[ "$output" == *"build b100 lists no CUDA0 device"* ]]
  [ "$(_active)" = "llama.cpp-b200" ]
  [ -d "${OPT}/llama.cpp-b100" ]
}

@test "only the active build and the previous one are kept" {
  _installed b100 b200
  _make_release b300
  _run b300
  [ "$status" -eq 0 ]
  [ "$(_active)" = "llama.cpp-b300" ]
  [ -d "${OPT}/llama.cpp-b200" ]
  [ ! -e "${OPT}/llama.cpp-b100" ]
  [[ "$output" == *"previous b200 kept for rollback"* ]]
}

@test "the active tag is a no-op that only repairs the bin link" {
  _installed b100
  _run b100
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already on b100"* ]]
  [ "$(readlink "${BIN}/llama-server")" = "${OPT}/llama.cpp/llama-server" ]
}

@test "a bin link pointing elsewhere is repointed at the active build" {
  _installed b100
  mkdir -p "$BIN"
  ln -s /nowhere/llama-server "${BIN}/llama-server"
  _run b100
  [ "$status" -eq 0 ]
  [ "$(readlink "${BIN}/llama-server")" = "${OPT}/llama.cpp/llama-server" ]
}

@test "a running llama-server is told it keeps its build until restarted" {
  _installed b100
  _make_release b200
  _stub_command pgrep 'exit 0'
  _run b200
  [ "$status" -eq 0 ]
  [[ "$output" == *"keeps its build until it is restarted"* ]]
}

@test "a regular file at the bin link is left alone" {
  _installed b100
  mkdir -p "$BIN"
  echo keep >"${BIN}/llama-server"
  _run b100
  [ "$status" -eq 0 ]
  [[ "$output" == *"is not a symlink: leaving it alone"* ]]
  [ "$(cat "${BIN}/llama-server")" = keep ]
}

# ─── listing ────────────────────────────────────────────────────────────────

@test "--list marks the active build and orders by build number" {
  _installed b9999 b10000
  _run --list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "  b9999" ]
  [ "${lines[1]}" = "* b10000" ]
}

@test "--list reports a plain directory without moving it" {
  _make_build_dir "${OPT}/llama.cpp" 11065
  _run --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"migrated on the next update"* ]]
  [ ! -L "${OPT}/llama.cpp" ]
}
