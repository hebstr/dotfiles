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

@test "reports a uv tool whose interpreter is gone once, with a uv repair, not its entry points" {
  local tool="${FAKE_HOME}/.local/share/uv/tools/mytool"
  _make_venv "$tool" "/nonexistent/python3.13"
  : >"${tool}/uv-receipt.toml"
  printf '#!%s/bin/python\nimport mytool\n' "$tool" >"${tool}/bin/mytool"
  ln -s "${tool}/bin/mytool" "${ROOT}/bin/mytool"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"venvs whose interpreter is gone (1)"* ]]
  [[ "$output" == *"fix: uv tool install --force mytool, re-adding any extras or --with listed in ${tool}/uv-receipt.toml"* ]]
  [[ "$output" != *"uv tool upgrade"* ]]
  [[ "$output" != *"scripts whose interpreter is gone"* ]]
  [[ "$output" != *"rm -r -- ${tool}"* ]]
  _run --count
  [ "$output" = "1" ]
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

@test "skips the argument of env -u and -C when finding the interpreter" {
  printf '#!/usr/bin/env -u PYTHONPATH bash\necho ok\n' >"${ROOT}/bin/live-unset"
  printf '#!/usr/bin/env -C /tmp sys-orphans-missing-interpreter\n' >"${ROOT}/bin/dead-chdir"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"scripts whose interpreter is gone (1)"* ]]
  [[ "$output" == *"fix: rm -- ${ROOT}/bin/dead-chdir"* ]]
  [[ "$output" != *"live-unset"* ]]
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

@test "warns when a check aborts partway, and keeps the other classes" {
  local kernels="${FAKE_HOME}/.local/share/jupyter/kernels"
  mkdir -p "${kernels}/locked"
  printf '{"argv": ["/nonexistent/python"]}\n' >"${kernels}/locked/kernel.json"
  chmod 000 "${kernels}/locked/kernel.json"
  mkdir -p "${FAKE_HOME}/R/x86_64-pc-linux-gnu-library/4.4"
  _run
  chmod 600 "${kernels}/locked/kernel.json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Jupyter kernelspecs whose interpreter is gone: check failed, results may be incomplete"* ]]
  [[ "$output" == *"R user libraries for an R version not installed (1)"* ]]
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

@test "spares an orphaned plugin version a live session still holds, not one held by a reused or dead pid" {
  local cache="${FAKE_HOME}/.claude/plugins/cache" stat start dead
  local -a fields
  stat=$(<"/proc/$$/stat")
  read -r -a fields <<<"${stat##*) }"
  start=${fields[19]}
  dead=$(($(</proc/sys/kernel/pid_max) + 1))
  mkdir -p "${cache}/market/plugin/0.1.0/.in_use" "${cache}/market/plugin/0.2.0/.in_use" "${cache}/market/plugin/0.3.0/.in_use"
  echo 1788000000000 >"${cache}/market/plugin/0.1.0/.orphaned_at"
  echo 1788000000000 >"${cache}/market/plugin/0.2.0/.orphaned_at"
  echo 1788000000000 >"${cache}/market/plugin/0.3.0/.orphaned_at"
  printf '{"pid":%s,"procStart":"%s"}' "$$" "$start" >"${cache}/market/plugin/0.1.0/.in_use/$$"
  printf '{"pid":%s,"procStart":"%s"}' "$$" "$((start + 1))" >"${cache}/market/plugin/0.2.0/.in_use/$$"
  printf '{"pid":%s,"procStart":"1"}' "$dead" >"${cache}/market/plugin/0.3.0/.in_use/${dead}"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Claude Code plugin versions marked orphaned (2)"* ]]
  [[ "$output" == *"fix: rm -r -- ${cache}/market/plugin/0.2.0"* ]]
  [[ "$output" == *"fix: rm -r -- ${cache}/market/plugin/0.3.0"* ]]
  [[ "$output" != *"${cache}/market/plugin/0.1.0"* ]]
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

@test "skips an editor whose global or profile registry does not parse, with a warning" {
  local ext="${FAKE_HOME}/.positron/extensions" profile="${FAKE_HOME}/.config/Positron/User/profiles/p1"
  mkdir -p "${ext}/a.global-1.0.0" "${ext}/b.profile-2.0.0" "$profile"
  printf '[{"relativeLocation":"a.global-1.0.0"}' >"${ext}/extensions.json"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"cannot parse ${ext}/extensions.json"* ]]
  [[ "$output" != *"rm -r --"* ]]
  printf '[{"relativeLocation":"a.global-1.0.0"}]\n' >"${ext}/extensions.json"
  : >"${profile}/extensions.json"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"cannot parse ${profile}/extensions.json"* ]]
  [[ "$output" != *"rm -r --"* ]]
}

@test "accepts an empty global registry when a profile registry references the extensions" {
  local ext="${FAKE_HOME}/.positron/extensions" profile="${FAKE_HOME}/.config/Positron/User/profiles/p1"
  mkdir -p "${ext}/b.profile-2.0.0" "${ext}/c.orphan-3.0.0" "$profile"
  printf '[]\n' >"${ext}/extensions.json"
  printf '[{"relativeLocation":"b.profile-2.0.0"}]\n' >"${profile}/extensions.json"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix: rm -r -- ${ext}/c.orphan-3.0.0"* ]]
  [[ "$output" != *"b.profile-2.0.0"* ]]
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

@test "does not size a package finding from a same-named file in the current directory" {
  local info="${ROOT}/dpkg-info"
  printf '%s\n' /. "${ROOT}/nope/bin/ghost" >"${info}/ghost.list"
  head -c 20000 /dev/zero >"${ROOT}/ghost"
  cd "$ROOT"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix: sudo dpkg --purge ghost"* ]]
  [[ ! "$output" =~ [0-9.]+[KMG][[:space:]]+ghost ]]
}

@test "keeps reporting when a finding holds an unreadable subdirectory" {
  _make_venv "${FAKE_HOME}/proj/.venv" "/nonexistent/python3.13"
  mkdir -p "${FAKE_HOME}/proj/.venv/locked"
  chmod 000 "${FAKE_HOME}/proj/.venv/locked"
  _run
  chmod 700 "${FAKE_HOME}/proj/.venv/locked"
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix: rm -r -- ${FAKE_HOME}/proj/.venv"* ]]
  [[ "$output" == *"1 orphans found"* ]]
}

# ─── dangling links ─────────────────────────────────────────────────────────

@test "reports a dangling alternatives master and fixes only its dead candidate" {
  ln -s /nonexistent/jdk/bin/javac "${ROOT}/alternatives/javac"
  ln -s /nonexistent/jdk/man/javac.1 "${ROOT}/alternatives/javac.1"
  printf 'auto\n/usr/bin/javac\njavac.1\n/usr/share/man/man1/javac.1.gz\n\n/nonexistent/jdk/bin/javac\n2000\n/nonexistent/jdk/man/javac.1\n%s\n1000\n\n\n' \
    "$BASH" >"${ROOT}/alt-admin/javac"
  ln -s "$BASH" "${ROOT}/alternatives/live"
  : >"${ROOT}/alt-admin/live"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"dangling alternatives (1)"* ]]
  [[ "$output" == *"fix: sudo update-alternatives --remove javac /nonexistent/jdk/bin/javac"* ]]
  [[ "$output" != *"--remove-all"* ]]
  [[ "$output" != *"javac.1"* ]]
  [[ "$output" != *"--remove live"* ]]
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
