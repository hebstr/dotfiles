#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/sys-cleanup

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/sys-cleanup"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs are written into ${STUBS} and the test sets PATH=${STUBS}, so only
# the commands explicitly stubbed (or symlinked in setup) are visible to the
# script. This is how "command not installed" cases are simulated: omit the
# stub.

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

_install_sudo_stub() {
  # sudo -v succeeds (initial credential cache); other invocations exec
  # the rest of the argv so e.g. `sudo journalctl ...` runs the journalctl stub
  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  exec "$@" ;;
esac
EOF
  chmod +x "${STUBS}/sudo"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  export STUBS FAKE_HOME
  _install_sudo_stub
  # Coreutils used by the script itself: bytes_of (du, awk), format_bytes
  # (awk), claude-versions (find, grep, sort, tail), several modules (rm),
  # usage() (cat, paste). Symlinking real binaries into ${STUBS} keeps the
  # restricted PATH semantics: anything we don't list here is "not found".
  for cmd in cat paste du awk find grep sort tail rm; do
    ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
}

# Invoke the script under a PATH that contains only ${STUBS}, with HOME
# pointed at a clean temp dir so cache directories under $HOME default to
# "absent" unless the test explicitly creates them.
_run() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" "$BASH" "$SCRIPT" "$@"
}

teardown() {
  rm -rf "$STUBS" "$FAKE_HOME"
}

# ─── help / usage ───────────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"sys-cleanup"* ]]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--list"* ]]
}

@test "-h is an alias for --help" {
  _run -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "--help lists every available module" {
  _run --help
  [ "$status" -eq 0 ]
  for m in trash uv rv prek go r-cache claude-versions flatpak \
    claude-cli jedi apt journal snap r-renv; do
    [[ "$output" == *"$m"* ]] || {
      printf 'missing module: %s\n' "$m" >&2
      return 1
    }
  done
}

# ─── --list ─────────────────────────────────────────────────────────────────

@test "--list shows MODULE/SUDO header and one row per module" {
  _run --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODULE"* ]]
  [[ "$output" == *"SUDO"* ]]
  [[ "$output" == *"trash"* ]]
  [[ "$output" == *"r-renv"* ]]
}

@test "--list marks apt, journal, and snap as sudo modules" {
  _run --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^apt[[:space:]]+yes$'
  echo "$output" | grep -E '^journal[[:space:]]+yes$'
  echo "$output" | grep -E '^snap[[:space:]]+yes$'
}

@test "--list marks non-sudo modules as no" {
  _run --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^trash[[:space:]]+no$'
  echo "$output" | grep -E '^uv[[:space:]]+no$'
  echo "$output" | grep -E '^flatpak[[:space:]]+no$'
  echo "$output" | grep -E '^r-renv[[:space:]]+no$'
}

# ─── argument parsing errors ────────────────────────────────────────────────

@test "exits 2 on an unknown option" {
  _run --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option: --nope"* ]]
}

@test "exits 2 on an unknown module" {
  _run bogus-module
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown module: bogus-module"* ]]
}

@test "rejects an unknown module even when other valid modules are listed" {
  _run --dry-run trash bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown module: bogus"* ]]
}

@test "--dry-run can appear after a module name" {
  _run trash --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] gio trash --empty"* ]]
}

# ─── --dry-run prints commands without executing ────────────────────────────

@test "--dry-run does not invoke sudo -v even for sudo modules" {
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/sudo.log"
exit 0
EOF
  chmod +x "${STUBS}/sudo"
  _run --dry-run apt journal
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}

@test "--dry-run apt prints clean and autoremove and does not run them" {
  # apt-get is intentionally not stubbed; a real exec would crash under set -e.
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo apt-get clean -y"* ]]
  [[ "$output" == *"[dry-run] sudo apt-get autoremove --purge -y"* ]]
}

@test "--dry-run apt prints dpkg --purge for residual rc packages" {
  cat >"${STUBS}/dpkg" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -l)
        printf 'rc  pkg-one        1.0  amd64        old config\n'
        printf 'rc  pkg-two:i386   2.0  i386         old config\n'
        printf 'ii  alive-pkg      3.0  amd64        installed\n'
        ;;
esac
EOF
  chmod +x "${STUBS}/dpkg"
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo dpkg --purge pkg-one pkg-two:i386"* ]]
}

@test "--dry-run apt skips dpkg --purge when no rc packages remain" {
  cat >"${STUBS}/dpkg" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -l)
        printf 'ii  alive-pkg      3.0  amd64        installed\n'
        ;;
esac
EOF
  chmod +x "${STUBS}/dpkg"
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" != *"[dry-run] sudo dpkg --purge"* ]]
}

@test "apt summary reports the rc purge count" {
  cat >"${STUBS}/dpkg" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -l)
        printf 'rc  pkg-one    1.0  amd64  old\n'
        printf 'rc  pkg-two    2.0  amd64  old\n'
        printf 'rc  pkg-three  3.0  amd64  old\n'
        ;;
esac
EOF
  chmod +x "${STUBS}/dpkg"
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"(archives + 3 rc purged)"* ]]
}

@test "apt summary reports 0 rc purged when none are present" {
  cat >"${STUBS}/dpkg" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -l)
        printf 'ii  alive  1.0  amd64  installed\n'
        ;;
esac
EOF
  chmod +x "${STUBS}/dpkg"
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"(archives + 0 rc purged)"* ]]
}

@test "--dry-run journal prints the journalctl vacuum command" {
  _run --dry-run journal
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo journalctl --vacuum-size=200M"* ]]
}

@test "--dry-run snap lists disabled revisions for removal" {
  cat >"${STUBS}/snap" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
    "list --all")
        printf 'Name     Version  Rev  Tracking       Publisher  Notes\n'
        printf 'oldsnap  1.0      42   latest/stable  -          disabled\n'
        ;;
esac
EOF
  chmod +x "${STUBS}/snap"
  _run --dry-run snap
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] snap remove oldsnap --revision=42"* ]]
}

@test "--dry-run trash prints gio trash --empty" {
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] gio trash --empty"* ]]
}

# ─── module skip behavior: missing command ──────────────────────────────────

@test "uv module is skipped when uv is not on PATH" {
  _run --dry-run uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv"*"skipped (not found)"* ]]
}

@test "uv module runs in dry-run when uv is on PATH" {
  _stub_command uv
  _run --dry-run uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] uv cache prune --force"* ]]
}

@test "prek module is skipped when prek is not on PATH" {
  _run --dry-run prek
  [ "$status" -eq 0 ]
  [[ "$output" == *"prek"*"skipped (not found)"* ]]
}

@test "prek module runs in dry-run when prek is on PATH" {
  _stub_command prek
  _run --dry-run prek
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] prek cache gc"* ]]
}

@test "flatpak module is skipped when flatpak is not on PATH" {
  _run --dry-run flatpak
  [ "$status" -eq 0 ]
  [[ "$output" == *"flatpak"*"skipped (not found)"* ]]
}

@test "flatpak module runs in dry-run when flatpak is on PATH" {
  _stub_command flatpak
  _run --dry-run flatpak
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] flatpak uninstall --unused -y"* ]]
}

@test "snap module is skipped when snap is not on PATH" {
  _run --dry-run snap
  [ "$status" -eq 0 ]
  [[ "$output" == *"snap"*"skipped (not found)"* ]]
}

# ─── module skip behavior: missing directory ────────────────────────────────

@test "go module is skipped when ~/.cache/go-build is absent" {
  _run --dry-run go
  [ "$status" -eq 0 ]
  [[ "$output" == *"go"*"skipped (not found)"* ]]
}

@test "go module runs go clean -cache when go binary is on PATH" {
  mkdir -p "${FAKE_HOME}/.cache/go-build"
  _stub_command go
  _run --dry-run go
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] go clean -cache"* ]]
}

@test "go module falls back to rm -rf when go binary is missing but dir exists" {
  mkdir -p "${FAKE_HOME}/.cache/go-build"
  _run --dry-run go
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.cache/go-build"* ]]
}

@test "claude-cli module is skipped when ~/.cache/claude-cli-nodejs is absent" {
  _run --dry-run claude-cli
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-cli"*"skipped (not found)"* ]]
}

@test "r-renv module is skipped when ~/.cache/R/renv is absent" {
  _run --dry-run r-renv
  [ "$status" -eq 0 ]
  [[ "$output" == *"r-renv"*"skipped (not found)"* ]]
}

@test "rv module is skipped when ~/.cache/rv is absent" {
  _run --dry-run rv
  [ "$status" -eq 0 ]
  [[ "$output" == *"rv"*"skipped (not found)"* ]]
}

@test "rv module prints both find passes in dry-run when the cache exists" {
  mkdir -p "${FAKE_HOME}/.cache/rv"
  _run --dry-run rv
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] find ${FAKE_HOME}/.cache/rv -type f -links 1 -delete"* ]]
  [[ "$output" == *"[dry-run] find ${FAKE_HOME}/.cache/rv -mindepth 1 -type d -empty -delete"* ]]
}

@test "claude-versions module is skipped when versions dir is absent" {
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-versions"*"skipped (not found)"* ]]
}

@test "claude-versions module is skipped when no version dir matches the regex" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/notaversion"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped (no version dir)"* ]]
}

@test "claude-versions keeps the latest version and prints rm for older ones (dry-run)" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/1.0.0"
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/1.2.0"
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/2.0.0"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/1.0.0"* ]]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/1.2.0"* ]]
  [[ "$output" != *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/2.0.0"* ]]
}

@test "claude-versions ignores non-version dirs alongside valid ones" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/1.0.0"
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/2.0.0"
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/notaversion"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  # 1.0.0 is older than 2.0.0 → scheduled for removal
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/1.0.0"* ]]
  # 2.0.0 is the latest → kept
  [[ "$output" != *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/2.0.0"* ]]
  # notaversion does not match the regex → never touched
  [[ "$output" != *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/notaversion"* ]]
}

# ─── module dispatch: dash → underscore ─────────────────────────────────────

@test "r-cache module dispatches to clean_r_cache" {
  _run --dry-run r-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ r-cache"* ]]
  [[ "$output" == *"r-cache"*"OK"* ]]
}

@test "claude-cli module dispatches to clean_claude_cli" {
  mkdir -p "${FAKE_HOME}/.cache/claude-cli-nodejs"
  _run --dry-run claude-cli
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ claude-cli"* ]]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.cache/claude-cli-nodejs"* ]]
}

@test "claude-versions module dispatches to clean_claude_versions" {
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ claude-versions"* ]]
}

# ─── modules with no skip path always record OK ─────────────────────────────

@test "trash module records OK (no command-availability guard in dry-run)" {
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" == *"trash"*"OK"* ]]
  [[ "$output" != *"trash"*"skipped"* ]]
}

@test "r-cache records OK even when neither pak nor sass cache exists" {
  _run --dry-run r-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"r-cache"*"OK"* ]]
}

@test "jedi records OK with no caches present (no skip path)" {
  _run --dry-run jedi
  [ "$status" -eq 0 ]
  [[ "$output" == *"jedi"*"OK"* ]]
  [[ "$output" != *"jedi"*"skipped"* ]]
}

@test "jedi processes both positron-jedi and jedi cache directories" {
  mkdir -p "${FAKE_HOME}/.cache/positron-jedi"
  mkdir -p "${FAKE_HOME}/.cache/jedi"
  _run --dry-run jedi
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.cache/positron-jedi"* ]]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.cache/jedi"* ]]
}

@test "apt module has no command-availability guard" {
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo apt-get clean -y"* ]]
  [[ "$output" != *"apt"*"skipped"* ]]
}

@test "journal module has no command-availability guard" {
  _run --dry-run journal
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo journalctl --vacuum-size=200M"* ]]
  [[ "$output" != *"journal"*"skipped"* ]]
}

# ─── multiple modules ───────────────────────────────────────────────────────

@test "multiple modules are processed in order" {
  _run --dry-run trash r-cache
  [ "$status" -eq 0 ]
  trash_pos="${output%%→ trash*}"
  rcache_pos="${output%%→ r-cache*}"
  [ "${#trash_pos}" -lt "${#rcache_pos}" ]
}

@test "no module argument selects all modules" {
  _run --dry-run
  [ "$status" -eq 0 ]
  for m in trash uv rv prek go r-cache claude-versions flatpak \
    claude-cli jedi apt journal snap r-renv; do
    [[ "$output" == *"→ ${m}"* ]] || {
      printf 'missing arrow for: %s\n' "$m" >&2
      return 1
    }
  done
}

# ─── sudo invocation policy ─────────────────────────────────────────────────

@test "calls sudo -v when a sudo module is selected (non-dry-run)" {
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "${STUBS}/sudo.log"
case "\$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  exec "\$@" ;;
esac
EOF
  chmod +x "${STUBS}/sudo"
  _stub_command journalctl
  _run journal
  [ "$status" -eq 0 ]
  [ -f "${STUBS}/sudo.log" ]
  grep -q '^-v$' "${STUBS}/sudo.log"
}

@test "does not call sudo -v when only non-sudo modules are selected" {
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "${STUBS}/sudo.log"
exit 0
EOF
  chmod +x "${STUBS}/sudo"
  # uv is not stubbed → module records "skipped (not found)" → no commands
  # are executed and therefore sudo must not be invoked at all.
  _run uv
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}

@test "needs_sudo is satisfied by any single sudo module among many" {
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$1" >> "${STUBS}/sudo.log"
case "\$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)  exec "\$@" ;;
esac
EOF
  chmod +x "${STUBS}/sudo"
  _stub_command journalctl
  _run r-cache journal
  [ "$status" -eq 0 ]
  grep -q '^-v$' "${STUBS}/sudo.log"
}

# ─── --dry-run does not actually mutate the filesystem ──────────────────────

@test "--dry-run claude-cli does not delete the cache" {
  mkdir -p "${FAKE_HOME}/.cache/claude-cli-nodejs"
  echo "preserved" >"${FAKE_HOME}/.cache/claude-cli-nodejs/file.txt"
  _run --dry-run claude-cli
  [ "$status" -eq 0 ]
  [ -f "${FAKE_HOME}/.cache/claude-cli-nodejs/file.txt" ]
  [ "$(cat "${FAKE_HOME}/.cache/claude-cli-nodejs/file.txt")" = "preserved" ]
}

@test "--dry-run claude-versions does not delete older version dirs" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/1.0.0"
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/2.0.0"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [ -d "${FAKE_HOME}/.local/share/claude/versions/1.0.0" ]
  [ -d "${FAKE_HOME}/.local/share/claude/versions/2.0.0" ]
}

# ─── execution path (non-dry-run) ───────────────────────────────────────────

@test "non-dry-run claude-cli actually deletes the cache directory" {
  mkdir -p "${FAKE_HOME}/.cache/claude-cli-nodejs/sub"
  echo "x" >"${FAKE_HOME}/.cache/claude-cli-nodejs/sub/file"
  _run claude-cli
  [ "$status" -eq 0 ]
  [ ! -d "${FAKE_HOME}/.cache/claude-cli-nodejs" ]
}

@test "non-dry-run rv deletes link-count-1 files but preserves hardlinked ones" {
  mkdir -p "${FAKE_HOME}/.cache/rv/pkg"
  echo orphan >"${FAKE_HOME}/.cache/rv/pkg/orphan.tar"
  echo live >"${FAKE_HOME}/.cache/rv/pkg/live.tar"
  # A second hardlink (the live project library) lifts the link count above 1,
  # marking the cache entry as still in use.
  ln "${FAKE_HOME}/.cache/rv/pkg/live.tar" "${FAKE_HOME}/project-lib-hardlink"
  _run rv
  [ "$status" -eq 0 ]
  [ ! -f "${FAKE_HOME}/.cache/rv/pkg/orphan.tar" ]
  [ -f "${FAKE_HOME}/.cache/rv/pkg/live.tar" ]
}

@test "non-dry-run journal invokes journalctl with the configured vacuum size" {
  cat >"${STUBS}/journalctl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/journalctl.log"
exit 0
EOF
  chmod +x "${STUBS}/journalctl"
  _run journal
  [ "$status" -eq 0 ]
  grep -q '^--vacuum-size=200M$' "${STUBS}/journalctl.log"
}

@test "non-dry-run claude-versions removes older version dirs and keeps the latest" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/1.0.0"
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/2.0.0"
  _run claude-versions
  [ "$status" -eq 0 ]
  [ ! -d "${FAKE_HOME}/.local/share/claude/versions/1.0.0" ]
  [ -d "${FAKE_HOME}/.local/share/claude/versions/2.0.0" ]
}

# ─── summary table ──────────────────────────────────────────────────────────

@test "summary table prints MODULE/FREED/STATUS header" {
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODULE"*"FREED"*"STATUS"* ]]
}

@test "summary ends with a TOTAL line" {
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" == *"TOTAL"* ]]
}

@test "summary lists each selected module" {
  _run --dry-run trash r-cache
  [ "$status" -eq 0 ]
  summary="${output#*MODULE*FREED*STATUS}"
  [[ "$summary" == *"trash"* ]]
  [[ "$summary" == *"r-cache"* ]]
}

@test "skipped modules show their skip reason in the summary" {
  _run --dry-run uv flatpak
  [ "$status" -eq 0 ]
  summary="${output#*MODULE*FREED*STATUS}"
  [[ "$summary" == *"uv"*"skipped (not found)"* ]]
  [[ "$summary" == *"flatpak"*"skipped (not found)"* ]]
}

@test "summary FREED column reports 0 B for skipped modules" {
  _run --dry-run uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv"*"0 B"*"skipped (not found)"* ]]
}
