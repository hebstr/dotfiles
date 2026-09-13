#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/sys-orphans

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/sys-orphans"

# ─── setup / teardown ───────────────────────────────────────────────────────
# HOME points at an empty temp dir and every system location the script reads
# is redirected into ROOT, so each test starts with no finding at all and adds
# only the fixtures it asserts on.

setup() {
  FAKE_HOME="$(mktemp -d)"
  ROOT="$(mktemp -d)"
  mkdir -p "${ROOT}/dpkg-info" "${ROOT}/alternatives" "${ROOT}/alt-admin" \
    "${ROOT}/systemd-system" "${ROOT}/bin" "${ROOT}/opt-R"
  export FAKE_HOME ROOT
}

teardown() {
  rm -rf "$FAKE_HOME" "$ROOT"
}

_run() {
  run env HOME="$FAKE_HOME" \
    SYS_ORPHANS_DPKG_INFO="${ROOT}/dpkg-info" \
    SYS_ORPHANS_ALTERNATIVES="${ROOT}/alternatives" \
    SYS_ORPHANS_ALT_ADMIN="${ROOT}/alt-admin" \
    SYS_ORPHANS_SYSTEMD_DIRS="${ROOT}/systemd-system:${FAKE_HOME}/.config/systemd/user" \
    SYS_ORPHANS_BIN_DIRS="${ROOT}/bin" \
    SYS_ORPHANS_R_ROOT="${ROOT}/opt-R" \
    "$BASH" "$SCRIPT" "$@"
}

_make_venv() {
  local dir="$1" interpreter="$2"
  mkdir -p "${dir}/bin"
  printf 'home = %s\n' "${interpreter%/*}" >"${dir}/pyvenv.cfg"
  ln -s "$interpreter" "${dir}/bin/python"
}

# ─── CLI ────────────────────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"sys-orphans"* ]]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--count"* ]]
}

@test "exits 2 on an unknown option" {
  _run --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option: --nope"* ]]
}

@test "reports no orphans on a clean machine and --count prints 0" {
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphans detected"* ]]
  _run --count
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "--count prints only the total across classes" {
  _make_venv "${FAKE_HOME}/proj/.venv" "/nonexistent/python3.13"
  printf '#!/nonexistent/python3\n' >"${ROOT}/bin/dead-tool"
  _run --count
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

# ─── venvs ──────────────────────────────────────────────────────────────────

@test "reports a venv whose interpreter is gone, with its fix" {
  _make_venv "${FAKE_HOME}/proj/.venv" "/nonexistent/python3.13"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"venvs whose interpreter is gone (1)"* ]]
  [[ "$output" == *"${FAKE_HOME}/proj/.venv"* ]]
  [[ "$output" == *"fix: rm -r -- ${FAKE_HOME}/proj/.venv"* ]]
}

@test "does not report a venv whose interpreter exists" {
  _make_venv "${FAKE_HOME}/proj/.venv" "$BASH"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphans detected"* ]]
}

@test "ignores venvs under ~/.cache and ~/snap" {
  _make_venv "${FAKE_HOME}/.cache/uv/archive-v0/x" "/nonexistent/python3.13"
  _make_venv "${FAKE_HOME}/snap/app/common/.venv" "/nonexistent/python3.13"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphans detected"* ]]
}

# ─── scripts with a dead shebang ────────────────────────────────────────────

@test "reports scripts whose absolute or env interpreter is gone, not live or binary ones" {
  printf '#!/nonexistent/python3\nprint(1)\n' >"${ROOT}/bin/dead-abs"
  printf '#!/usr/bin/env sys-orphans-missing-interpreter\n' >"${ROOT}/bin/dead-env"
  printf '#!/usr/bin/env bash\necho ok\n' >"${ROOT}/bin/live-env"
  printf '#!/bin/sh\necho ok\n' >"${ROOT}/bin/live-abs"
  printf '\177ELF\002\001\001' >"${ROOT}/bin/binary"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts whose interpreter is gone (2)"* ]]
  [[ "$output" == *"fix: rm -- ${ROOT}/bin/dead-abs"* ]]
  [[ "$output" == *"fix: rm -- ${ROOT}/bin/dead-env"* ]]
  [[ "$output" != *"live-env"* ]]
  [[ "$output" != *"live-abs"* ]]
  [[ "$output" != *"/binary"* ]]
}

# ─── Jupyter kernelspecs ────────────────────────────────────────────────────

@test "reports a kernelspec whose interpreter is gone, not one that resolves" {
  local kernels="${FAKE_HOME}/.local/share/jupyter/kernels"
  mkdir -p "${kernels}/dead" "${kernels}/live"
  printf '{\n "argv": ["/nonexistent/envs/py13/bin/python", "-m", "ipykernel"]\n}\n' >"${kernels}/dead/kernel.json"
  printf '{\n "argv": ["bash", "-c", "true"]\n}\n' >"${kernels}/live/kernel.json"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Jupyter kernelspecs whose interpreter is gone (1)"* ]]
  [[ "$output" == *"fix: rm -r -- ${kernels}/dead"* ]]
  [[ "$output" != *"${kernels}/live"* ]]
}

# ─── Claude Code plugin cache ───────────────────────────────────────────────

@test "reports plugin versions Claude Code marked orphaned, not the others" {
  local cache="${FAKE_HOME}/.claude/plugins/cache"
  mkdir -p "${cache}/market/plugin/0.1.0" "${cache}/market/plugin/0.2.0"
  echo 1788000000000 >"${cache}/market/plugin/0.1.0/.orphaned_at"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Claude Code plugin versions marked orphaned (1)"* ]]
  [[ "$output" == *"fix: rm -r -- ${cache}/market/plugin/0.1.0"* ]]
  [[ "$output" != *"${cache}/market/plugin/0.2.0"* ]]
}

# ─── editor extensions ──────────────────────────────────────────────────────

@test "reports an extension folder no registry references, sparing profile-only and obsolete ones" {
  local ext="${FAKE_HOME}/.positron/extensions" profile="${FAKE_HOME}/.config/Positron/User/profiles/p1"
  mkdir -p "${ext}/a.global-1.0.0" "${ext}/b.profile-2.0.0" "${ext}/c.orphan-3.0.0" "${ext}/d.obsolete-4.0.0" "$profile"
  printf '[{"identifier":{"id":"a.global"},"relativeLocation":"a.global-1.0.0","location":{"path":"%s"}}]\n' \
    "${ext}/a.global-1.0.0" >"${ext}/extensions.json"
  printf '[{"identifier":{"id":"b.profile"},"relativeLocation":"b.profile-2.0.0","location":{"path":"%s"}}]\n' \
    "${ext}/b.profile-2.0.0" >"${profile}/extensions.json"
  printf '{"d.obsolete-4.0.0":true}\n' >"${ext}/.obsolete"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"editor extensions referenced by no registry (1)"* ]]
  [[ "$output" == *"fix: rm -r -- ${ext}/c.orphan-3.0.0"* ]]
  [[ "$output" != *"a.global-1.0.0"* ]]
  [[ "$output" != *"b.profile-2.0.0"* ]]
  [[ "$output" != *"d.obsolete-4.0.0"* ]]
}

@test "checks VS Code extensions against its own registries" {
  local ext="${FAKE_HOME}/.vscode/extensions"
  mkdir -p "${ext}/x.live-1.0.0" "${ext}/x.live-0.9.0"
  printf '[{"identifier":{"id":"x.live"},"relativeLocation":"x.live-1.0.0","location":{"path":"%s"}}]\n' \
    "${ext}/x.live-1.0.0" >"${ext}/extensions.json"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix: rm -r -- ${ext}/x.live-0.9.0"* ]]
  [[ "$output" != *"rm -r -- ${ext}/x.live-1.0.0"* ]]
}

@test "skips an editor whose global registry is absent" {
  mkdir -p "${FAKE_HOME}/.positron/extensions/lonely-1.0.0"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphans detected"* ]]
}

# ─── dpkg ───────────────────────────────────────────────────────────────────

@test "reports a package whose non-doc files are all gone, not metapackages or live ones" {
  local info="${ROOT}/dpkg-info" live_file="${ROOT}/live-file"
  mkdir -p "${ROOT}/usr/share/doc/ghost"
  echo copyright >"${ROOT}/usr/share/doc/ghost/copyright"
  echo x >"$live_file"
  printf '%s\n' /. "${ROOT}/nope/bin/java" "${ROOT}/nope/lib/libjvm.so" \
    "/usr/share/doc/ghost/copyright" >"${info}/ghost.list"
  printf '%s\n' /. /usr /usr/share /usr/share/doc >"${info}/meta:amd64.list"
  printf '%s\n' /. "$live_file" "${ROOT}/nope/other" >"${info}/alive.list"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed packages whose files are all gone (1)"* ]]
  [[ "$output" == *"fix: sudo dpkg --purge ghost"* ]]
  [[ "$output" != *"dpkg --purge meta"* ]]
  [[ "$output" != *"dpkg --purge alive"* ]]
}

# ─── dangling links ─────────────────────────────────────────────────────────

@test "reports a dangling alternatives master and leaves its slaves to it" {
  ln -s /nonexistent/jdk/bin/javac "${ROOT}/alternatives/javac"
  ln -s /nonexistent/jdk/man/javac.1 "${ROOT}/alternatives/javac.1"
  : >"${ROOT}/alt-admin/javac"
  ln -s "$BASH" "${ROOT}/alternatives/live"
  : >"${ROOT}/alt-admin/live"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dangling alternatives (1)"* ]]
  [[ "$output" == *"fix: sudo update-alternatives --remove-all javac"* ]]
  [[ "$output" != *"javac.1"* ]]
  [[ "$output" != *"--remove-all live"* ]]
}

@test "reports dangling systemd unit links with a fix matching their owner" {
  mkdir -p "${ROOT}/systemd-system/multi-user.target.wants" "${FAKE_HOME}/.config/systemd/user/default.target.wants"
  ln -s /nonexistent/gone.service "${ROOT}/systemd-system/multi-user.target.wants/gone.service"
  ln -s /nonexistent/mine.service "${FAKE_HOME}/.config/systemd/user/default.target.wants/mine.service"
  ln -s "$BASH" "${ROOT}/systemd-system/multi-user.target.wants/live.service"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dangling systemd unit links (2)"* ]]
  [[ "$output" == *"fix: sudo rm -- ${ROOT}/systemd-system/multi-user.target.wants/gone.service"* ]]
  [[ "$output" == *"fix: rm -- ${FAKE_HOME}/.config/systemd/user/default.target.wants/mine.service"* ]]
  [[ "$output" != *"live.service"* ]]
}

# ─── Claude Code project entries ────────────────────────────────────────────

@test "reports ~/.claude.json projects whose folder is gone" {
  mkdir -p "${FAKE_HOME}/alive-project"
  printf '{"projects":{"%s":{},"%s":{}}}\n' "${FAKE_HOME}/gone-project" "${FAKE_HOME}/alive-project" \
    >"${FAKE_HOME}/.claude.json"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Claude Code projects whose folder is gone (1)"* ]]
  [[ "$output" == *"${FAKE_HOME}/gone-project"* ]]
  [[ "$output" != *"${FAKE_HOME}/alive-project"* ]]
}

# ─── R user libraries ───────────────────────────────────────────────────────

@test "reports an R user library whose R version is not installed" {
  local lib="${FAKE_HOME}/R/x86_64-pc-linux-gnu-library"
  mkdir -p "${lib}/4.4" "${lib}/4.6" "${ROOT}/opt-R/4.6.1"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"R user libraries for an R version not installed (1)"* ]]
  [[ "$output" == *"fix: rm -r -- ${lib}/4.4"* ]]
  [[ "$output" != *"${lib}/4.6"* ]]
}
