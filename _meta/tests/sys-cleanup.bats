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
  # chromium-headless and claude-versions (readlink), usage() (cat, paste). Symlinking real binaries into ${STUBS} keeps the
  # restricted PATH semantics: anything we don't list here is "not found".
  for cmd in cat paste du awk find grep sort tail rm readlink; do
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
  for m in trash uv rv prek npm r-cache claude-versions flatpak \
    claude-cli chromium-headless positron-pycache workspace-storage \
    jedi apt journal snap; do
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
  [[ "$output" == *"snap"* ]]
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
  echo "$output" | grep -E '^npm[[:space:]]+no$'
  echo "$output" | grep -E '^flatpak[[:space:]]+no$'
  echo "$output" | grep -E '^chromium-headless[[:space:]]+no$'
  echo "$output" | grep -E '^positron-pycache[[:space:]]+no$'
  echo "$output" | grep -E '^workspace-storage[[:space:]]+no$'
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
  [[ "$output" == *"OK (3 rc purged)"* ]]
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
  [[ "$output" == *"OK (0 rc purged)"* ]]
}

# autoremove drops old kernels under /usr and /boot, outside the apt archives;
# /usr, /var and /boot usually share one partition, which must count once.
@test "apt FREED measures the filesystems apt writes to, each partition once" {
  _stub_command dpkg 'exit 0'
  _stub_command apt-get 'exit 0'
  cat >"${STUBS}/df" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${STUBS}/df.args"
n=\$(cat "${STUBS}/df.count" 2>/dev/null || echo 0)
echo \$((n + 1)) >"${STUBS}/df.count"
used=\$((10737418240 - n * 314572800))
printf 'Filesystem Used\n'
printf '/dev/sda1 %s\n' "\$used" "\$used" "\$used"
EOF
  chmod +x "${STUBS}/df"
  _run apt
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^apt +300 MiB +OK \(0 rc purged\)$'
  [[ "$(<"${STUBS}/df.args")" == *" /usr /var /boot"* ]]
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

# An archive entry is reclaimable when none of its files is hardlinked into a
# venv. Entries younger than 24 h may be mid-install (extracted, not yet
# linked), and entries holding pyvenv.cfg are cached uvx environments, which
# `uv cache prune` owns.

_uv_logging_stub() {
  _stub_command uv "printf '%s\n' \"\$*\" >> \"${STUBS}/uv.log\""
}

_make_archive_entry() {
  local entry="${FAKE_HOME}/.cache/uv/archive-v0/$1" age="${2:-2 days ago}"
  mkdir -p "${entry}/pkg"
  echo code >"${entry}/pkg/__init__.py"
  echo meta >"${entry}/RECORD"
  touch -d "$age" "$entry"
  printf '%s' "$entry"
}

@test "--dry-run uv prints rm for an old archive entry with no linked file and keeps it" {
  _uv_logging_stub
  local entry
  entry="$(_make_archive_entry unusedEntry01)"
  _run --dry-run uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${entry}"* ]]
  [ -d "$entry" ]
}

@test "non-dry-run uv removes an old unlinked archive entry, then prunes" {
  _uv_logging_stub
  local entry
  entry="$(_make_archive_entry unusedEntry01)"
  _run uv
  [ "$status" -eq 0 ]
  [ ! -e "$entry" ]
  grep -q '^cache prune --force$' "${STUBS}/uv.log"
}

@test "uv keeps an archive entry with one file hardlinked into a venv" {
  _uv_logging_stub
  local entry
  entry="$(_make_archive_entry liveEntry01)"
  mkdir -p "${FAKE_HOME}/venv/lib"
  ln "${entry}/pkg/__init__.py" "${FAKE_HOME}/venv/lib/__init__.py"
  touch -d "2 days ago" "$entry"
  _run uv
  [ "$status" -eq 0 ]
  [ -f "${entry}/pkg/__init__.py" ]
  [ -f "${entry}/RECORD" ]
}

@test "uv keeps an unlinked archive entry younger than 24 hours" {
  _uv_logging_stub
  local entry
  entry="$(_make_archive_entry freshEntry01 "1 hour ago")"
  _run uv
  [ "$status" -eq 0 ]
  [ -d "$entry" ]
}

@test "uv keeps an old unlinked archive entry holding pyvenv.cfg" {
  _uv_logging_stub
  local entry
  entry="$(_make_archive_entry cachedEnv01)"
  echo "home = /x" >"${entry}/pyvenv.cfg"
  touch -d "2 days ago" "$entry"
  _run uv
  [ "$status" -eq 0 ]
  [ -d "$entry" ]
}

@test "uv removes an archive entry whose name starts with a dash" {
  _uv_logging_stub
  local entry
  entry="$(_make_archive_entry -dashEntry01)"
  _run uv
  [ "$status" -eq 0 ]
  [ ! -e "$entry" ]
}

@test "uv leaves the archive untouched when uv is not on PATH" {
  local entry
  entry="$(_make_archive_entry unusedEntry01)"
  _run uv
  [ "$status" -eq 0 ]
  [ -d "$entry" ]
  [[ "$output" == *"uv"*"skipped (not found)"* ]]
}

# prek embeds its own uv cache at ~/.cache/prek/cache/uv, which `prek cache gc`
# does not sweep; the module applies the same archive criterion after gc, so
# entries gc frees are reclaimed in the same run.

_make_prek_archive_entry() {
  local entry="${FAKE_HOME}/.cache/prek/cache/uv/archive-v0/$1" age="${2:-2 days ago}"
  mkdir -p "${entry}/pkg"
  echo code >"${entry}/pkg/__init__.py"
  touch -d "$age" "$entry"
  printf '%s' "$entry"
}

@test "--dry-run prek prints rm for an old unlinked entry of prek's uv cache and keeps it" {
  _stub_command prek
  local entry
  entry="$(_make_prek_archive_entry unusedPrek01)"
  _run --dry-run prek
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] prek cache gc"* ]]
  [[ "$output" == *"[dry-run] rm -rf ${entry}"* ]]
  [ -d "$entry" ]
}

@test "non-dry-run prek removes old unlinked uv entries, keeps linked and young ones" {
  _stub_command prek
  local unused live young
  unused="$(_make_prek_archive_entry unusedPrek01)"
  live="$(_make_prek_archive_entry livePrek01)"
  mkdir -p "${FAKE_HOME}/.cache/prek/hooks/python-env"
  ln "${live}/pkg/__init__.py" "${FAKE_HOME}/.cache/prek/hooks/python-env/__init__.py"
  touch -d "2 days ago" "$live"
  young="$(_make_prek_archive_entry youngPrek01 "1 hour ago")"
  _run prek
  [ "$status" -eq 0 ]
  [ ! -e "$unused" ]
  [ -f "${live}/pkg/__init__.py" ]
  [ -d "$young" ]
}

@test "prek sweeps its uv cache after gc, reclaiming entries gc freed in the same run" {
  local entry hook="${FAKE_HOME}/.cache/prek/hooks/python-env"
  entry="$(_make_prek_archive_entry freedByGc01)"
  mkdir -p "$hook"
  ln "${entry}/pkg/__init__.py" "${hook}/__init__.py"
  touch -d "2 days ago" "$entry"
  _stub_command prek "[ \"\$1 \$2\" = 'cache gc' ] && rm -rf '${hook}'; exit 0"
  _run prek
  [ "$status" -eq 0 ]
  [ ! -e "$entry" ]
}

@test "prek leaves its uv cache untouched when prek is not on PATH" {
  local entry
  entry="$(_make_prek_archive_entry unusedPrek01)"
  _run prek
  [ "$status" -eq 0 ]
  [ -d "$entry" ]
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

@test "npm module is skipped when npm is not on PATH" {
  _run --dry-run npm
  [ "$status" -eq 0 ]
  [[ "$output" == *"npm"*"skipped (not found)"* ]]
}

@test "--dry-run npm prints npm cache verify and does not run it" {
  _stub_command npm "printf '%s\n' \"\$*\" >>\"${STUBS}/npm.calls\""
  _run --dry-run npm
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] npm cache verify"* ]]
  [ ! -e "${STUBS}/npm.calls" ]
}

@test "non-dry-run npm runs npm cache verify" {
  _stub_command npm "printf '%s\n' \"\$*\" >>\"${STUBS}/npm.calls\""
  _run npm
  [ "$status" -eq 0 ]
  [ "$(cat "${STUBS}/npm.calls")" = "cache verify" ]
}

@test "npm FREED reports what verify removed from ~/.npm/_cacache" {
  mkdir -p "${FAKE_HOME}/.npm/_cacache/content-v2"
  head -c 2097152 /dev/zero >"${FAKE_HOME}/.npm/_cacache/content-v2/garbage"
  head -c 1024 /dev/zero >"${FAKE_HOME}/.npm/_cacache/content-v2/kept"
  _stub_command npm "rm -f \"\${HOME}/.npm/_cacache/content-v2/garbage\""
  _run npm
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^npm[[:space:]]+2 MiB[[:space:]]+OK$'
  [ -f "${FAKE_HOME}/.npm/_cacache/content-v2/kept" ]
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

@test "claude-cli module is skipped when ~/.cache/claude-cli-nodejs is absent" {
  _run --dry-run claude-cli
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-cli"*"skipped (not found)"* ]]
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

@test "claude-versions module is skipped when no version entry matches the regex" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/notaversion"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped (no version entry)"* ]]
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

# Claude Code stores each version as an executable file, not a directory;
# both layouts are accepted so a change upstream cannot silently disable the
# module again.

@test "claude-versions keeps the latest version file and prints rm for older ones (dry-run)" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.1.227"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.1.234"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.1.235"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/2.1.227"* ]]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/2.1.234"* ]]
  [[ "$output" != *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/2.1.235"* ]]
  # The regression this guards: the module used to report a skip here.
  [[ "$output" != *"skipped"* ]]
}

@test "claude-versions reports OK with nothing to remove when a single version file is present" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.1.235"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" != *"[dry-run] rm -rf"* ]]
  [[ "$output" != *"skipped"* ]]
  [[ "$output" == *"claude-versions"*"OK"* ]]
}

@test "non-dry-run claude-versions removes older version files and keeps the latest" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.1.227"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.1.235"
  _run claude-versions
  [ "$status" -eq 0 ]
  [ ! -e "${FAKE_HOME}/.local/share/claude/versions/2.1.227" ]
  [ -f "${FAKE_HOME}/.local/share/claude/versions/2.1.235" ]
}

@test "claude-versions handles a mix of version files and version dirs" {
  mkdir -p "${FAKE_HOME}/.local/share/claude/versions/1.0.0"
  touch "${FAKE_HOME}/.local/share/claude/versions/2.0.0"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/1.0.0"* ]]
  [[ "$output" != *"[dry-run] rm -rf ${FAKE_HOME}/.local/share/claude/versions/2.0.0"* ]]
}

# After `claude install <older-version>` the launcher points below the highest
# entry; deleting its target would leave `claude` dangling.
@test "claude-versions keeps the version the launcher resolves to even when it is not the latest" {
  local versions="${FAKE_HOME}/.local/share/claude/versions"
  mkdir -p "$versions" "${FAKE_HOME}/.local/bin"
  touch "${versions}/2.1.100" "${versions}/2.1.200" "${versions}/2.1.270"
  ln -s "${versions}/2.1.200" "${FAKE_HOME}/.local/bin/claude"
  _run claude-versions
  [ "$status" -eq 0 ]
  [ ! -e "${versions}/2.1.100" ]
  [ -f "${versions}/2.1.200" ]
  [ -f "${versions}/2.1.270" ]
}

@test "claude-versions never treats a suffixed name as the latest version" {
  local versions="${FAKE_HOME}/.local/share/claude/versions"
  mkdir -p "$versions"
  touch "${versions}/2.1.200" "${versions}/2.1.270" "${versions}/2.1.271.tmp"
  _run --dry-run claude-versions
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${versions}/2.1.200"* ]]
  [[ "$output" != *"[dry-run] rm -rf ${versions}/2.1.270"* ]]
  [[ "$output" != *"[dry-run] rm -rf ${versions}/2.1.271.tmp"* ]]
}

# ─── chromium-headless ──────────────────────────────────────────────────────
# A headless chromium profile holds a SingletonLock symlink to
# "<hostname>-<pid>". A profile is reclaimable only when that pid is dead: a
# killed run leaves its lock behind, a running one keeps its pid alive, and a
# profile without a lock may belong to a browser still starting.

DEAD_PID=4194399

_chromium_common() {
  printf '%s' "${FAKE_HOME}/snap/chromium/common"
}

_make_profile() {
  local dir="$1" lock_target="${2:-}"
  mkdir -p "$dir"
  echo data >"${dir}/Preferences"
  [[ -n "$lock_target" ]] && ln -s "$lock_target" "${dir}/SingletonLock"
  return 0
}

@test "chromium-headless module is skipped when ~/snap/chromium/common is absent" {
  _run --dry-run chromium-headless
  [ "$status" -eq 0 ]
  [[ "$output" == *"chromium-headless"*"skipped (not found)"* ]]
}

@test "chromium-headless records OK with nothing to remove when the snap dir holds no profile" {
  mkdir -p "$(_chromium_common)/chromium-headless"
  _run --dry-run chromium-headless
  [ "$status" -eq 0 ]
  [[ "$output" != *"[dry-run] rm -rf"* ]]
  [[ "$output" == *"chromium-headless"*"OK"* ]]
}

@test "--dry-run chromium-headless prints rm for a scoped_dir whose lock pid is dead and keeps it" {
  local dir
  dir="$(_chromium_common)/chromium-headless/scoped_dirAbC123"
  _make_profile "$dir" "host-with-dash-${DEAD_PID}"
  _run --dry-run chromium-headless
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${dir}"* ]]
  [ -d "$dir" ]
}

@test "non-dry-run chromium-headless removes dead-lock scoped_dir and claude-profile dirs" {
  local scoped profile
  scoped="$(_chromium_common)/chromium-headless/scoped_dirAbC123"
  profile="$(_chromium_common)/claude-profile.XyZ789"
  _make_profile "$scoped" "host-${DEAD_PID}"
  _make_profile "$profile" "host-${DEAD_PID}"
  _run chromium-headless
  [ "$status" -eq 0 ]
  [ ! -e "$scoped" ]
  [ ! -e "$profile" ]
  [[ "$output" == *"chromium-headless"*"OK"* ]]
}

@test "chromium-headless keeps a profile whose lock pid is alive" {
  local dir
  dir="$(_chromium_common)/chromium-headless/scoped_dirLive01"
  _make_profile "$dir" "host-$$"
  _run chromium-headless
  [ "$status" -eq 0 ]
  [ -d "$dir" ]
  [[ "$output" != *"rm -rf ${dir}"* ]]
}

@test "chromium-headless keeps a profile that has no SingletonLock" {
  local dir
  dir="$(_chromium_common)/claude-profile.NoLock1"
  _make_profile "$dir"
  _run chromium-headless
  [ "$status" -eq 0 ]
  [ -d "$dir" ]
}

@test "chromium-headless never touches the browser profile or unrelated dirs" {
  local common
  common="$(_chromium_common)"
  _make_profile "${common}/chromium/Default" "host-${DEAD_PID}"
  _make_profile "${common}/chromium-headless/Default" "host-${DEAD_PID}"
  _make_profile "${common}/other-dir" "host-${DEAD_PID}"
  _run chromium-headless
  [ "$status" -eq 0 ]
  [ -d "${common}/chromium/Default" ]
  [ -d "${common}/chromium-headless/Default" ]
  [ -d "${common}/other-dir" ]
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

# ─── positron-pycache ───────────────────────────────────────────────────────
# Positron's Python runs with PYTHONPYCACHEPREFIX, which mirrors each source
# directory's absolute path under the prefix. A mirror dir is reclaimable when
# its source directory is gone; only the highest such level is removed.

_pycache_prefix() {
  printf '%s' "${FAKE_HOME}/.config/Positron/User/globalStorage/ms-python.python/pycache"
}

@test "positron-pycache module is skipped when the pycache prefix is absent" {
  _run --dry-run positron-pycache
  [ "$status" -eq 0 ]
  [[ "$output" == *"positron-pycache"*"skipped (not found)"* ]]
}

@test "--dry-run positron-pycache prints rm for the highest mirror of a gone source and keeps it" {
  local prefix
  prefix="$(_pycache_prefix)"
  mkdir -p "${prefix}${FAKE_HOME}/gone/sub"
  echo pyc >"${prefix}${FAKE_HOME}/gone/sub/mod.cpython-313.pyc"
  _run --dry-run positron-pycache
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${prefix}${FAKE_HOME}/gone"* ]]
  [[ "$output" != *"rm -rf ${prefix}${FAKE_HOME}/gone/sub"* ]]
  [ -d "${prefix}${FAKE_HOME}/gone/sub" ]
}

@test "non-dry-run positron-pycache removes mirrors of gone sources and keeps those of existing ones" {
  local prefix
  prefix="$(_pycache_prefix)"
  mkdir -p "${FAKE_HOME}/project/pkg"
  mkdir -p "${prefix}${FAKE_HOME}/project/pkg" "${prefix}${FAKE_HOME}/project/removed"
  echo pyc >"${prefix}${FAKE_HOME}/project/pkg/a.cpython-313.pyc"
  echo pyc >"${prefix}${FAKE_HOME}/project/removed/b.cpython-313.pyc"
  _run positron-pycache
  [ "$status" -eq 0 ]
  [ -f "${prefix}${FAKE_HOME}/project/pkg/a.cpython-313.pyc" ]
  [ ! -e "${prefix}${FAKE_HOME}/project/removed" ]
  [[ "$output" == *"positron-pycache"*"OK"* ]]
}

@test "positron-pycache keeps a mirror whose source path exists as a directory with spaces and accents" {
  local prefix
  prefix="$(_pycache_prefix)"
  mkdir -p "${FAKE_HOME}/Télé chargements/x"
  mkdir -p "${prefix}${FAKE_HOME}/Télé chargements/x"
  _run positron-pycache
  [ "$status" -eq 0 ]
  [ -d "${prefix}${FAKE_HOME}/Télé chargements/x" ]
}

# ─── workspace-storage ──────────────────────────────────────────────────────
# Each workspaceStorage entry names its folder in workspace.json as a
# percent-encoded file:// URI. An entry is reclaimable when that folder is
# gone; other URI schemes (vscode-remote) are never judged.

_make_workspace_entry() {
  local editor="$1" id="$2" uri="$3" dir
  dir="${FAKE_HOME}/.config/${editor}/User/workspaceStorage/${id}"
  mkdir -p "$dir"
  printf '{\n  "folder": "%s"\n}\n' "$uri" >"${dir}/workspace.json"
  echo state >"${dir}/state.vscdb"
  printf '%s' "$dir"
}

@test "workspace-storage module is skipped when no editor storage dir exists" {
  _run --dry-run workspace-storage
  [ "$status" -eq 0 ]
  [[ "$output" == *"workspace-storage"*"skipped (not found)"* ]]
}

@test "--dry-run workspace-storage prints rm for an entry whose folder is gone and keeps it" {
  local entry
  entry="$(_make_workspace_entry Positron aaa111 "file://${FAKE_HOME}/gone-project")"
  _run --dry-run workspace-storage
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -rf ${entry}"* ]]
  [ -d "$entry" ]
}

@test "non-dry-run workspace-storage removes gone-folder entries in Positron and Code, keeps live ones" {
  local gone_p gone_c live
  mkdir -p "${FAKE_HOME}/live-project"
  gone_p="$(_make_workspace_entry Positron aaa111 "file://${FAKE_HOME}/gone-project")"
  gone_c="$(_make_workspace_entry Code bbb222 "file://${FAKE_HOME}/gone-project")"
  live="$(_make_workspace_entry Positron ccc333 "file://${FAKE_HOME}/live-project")"
  _run workspace-storage
  [ "$status" -eq 0 ]
  [ ! -e "$gone_p" ]
  [ ! -e "$gone_c" ]
  [ -d "$live" ]
  [[ "$output" == *"workspace-storage"*"OK"* ]]
}

@test "workspace-storage decodes percent-encoded UTF-8 before testing the folder" {
  local entry
  mkdir -p "${FAKE_HOME}/Téléchargements/m2 dm1"
  entry="$(_make_workspace_entry Positron ddd444 "file://${FAKE_HOME}/T%C3%A9l%C3%A9chargements/m2%20dm1")"
  _run workspace-storage
  [ "$status" -eq 0 ]
  [ -d "$entry" ]
}

@test "workspace-storage keeps entries with a non-file URI or no folder key" {
  local remote other
  remote="$(_make_workspace_entry Positron eee555 "vscode-remote://ssh-remote%2Bhost/home/x/project")"
  other="${FAKE_HOME}/.config/Positron/User/workspaceStorage/fff666"
  mkdir -p "$other"
  echo '{ "workspace": "file:///nowhere/a.code-workspace" }' >"${other}/workspace.json"
  _run workspace-storage
  [ "$status" -eq 0 ]
  [ -d "$remote" ]
  [ -d "$other" ]
}

# ─── r-cache: superseded pak metadata snapshots ─────────────────────────────
# pak writes one pkgs-<hash>.rds per configuration and never removes the old
# ones. The snapshot to keep is the one pak::meta_summary() names as
# current_db; when that query yields nothing, no snapshot is touched.

_metadata_dir() {
  printf '%s' "${FAKE_HOME}/.cache/R/pkgcache/_metadata"
}

_make_metadata() {
  local meta
  meta="$(_metadata_dir)"
  mkdir -p "${meta}/CRAN-0f0c1c4a0b/src/contrib"
  echo raw >"${meta}/CRAN-0f0c1c4a0b/src/contrib/PACKAGES.gz"
  echo current >"${meta}/pkgs-3a56b2c8ed.rds"
  echo old1 >"${meta}/pkgs-02e08e016f.rds"
  echo old2 >"${meta}/pkgs-ebe31bacf2.rds"
}

_rscript_stub_current_db() {
  local current="$1"
  cat >"${STUBS}/Rscript" <<EOF
#!/usr/bin/env bash
case "\$*" in
    *meta_summary*) printf '%s' "${current}" ;;
esac
exit 0
EOF
  chmod +x "${STUBS}/Rscript"
}

@test "--dry-run r-cache prints rm for superseded pak snapshots only, and keeps them" {
  _make_metadata
  _rscript_stub_current_db "$(_metadata_dir)/pkgs-3a56b2c8ed.rds"
  _run --dry-run r-cache
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] rm -f $(_metadata_dir)/pkgs-02e08e016f.rds"* ]]
  [[ "$output" == *"[dry-run] rm -f $(_metadata_dir)/pkgs-ebe31bacf2.rds"* ]]
  [[ "$output" != *"pkgs-3a56b2c8ed.rds"* ]]
  [ -f "$(_metadata_dir)/pkgs-02e08e016f.rds" ]
}

@test "non-dry-run r-cache removes superseded snapshots, keeps the current one and raw repo files" {
  _make_metadata
  _rscript_stub_current_db "$(_metadata_dir)/pkgs-3a56b2c8ed.rds"
  _run r-cache
  [ "$status" -eq 0 ]
  [ ! -e "$(_metadata_dir)/pkgs-02e08e016f.rds" ]
  [ ! -e "$(_metadata_dir)/pkgs-ebe31bacf2.rds" ]
  [ -f "$(_metadata_dir)/pkgs-3a56b2c8ed.rds" ]
  [ -f "$(_metadata_dir)/CRAN-0f0c1c4a0b/src/contrib/PACKAGES.gz" ]
  [[ "$output" == *"r-cache"*"OK"* ]]
}

@test "r-cache removes no snapshot when pak names no current database" {
  _make_metadata
  _rscript_stub_current_db ""
  _run r-cache
  [ "$status" -eq 0 ]
  [ -f "$(_metadata_dir)/pkgs-02e08e016f.rds" ]
  [ -f "$(_metadata_dir)/pkgs-ebe31bacf2.rds" ]
  [ -f "$(_metadata_dir)/pkgs-3a56b2c8ed.rds" ]
}

@test "r-cache removes no snapshot when the named current database does not exist" {
  _make_metadata
  _rscript_stub_current_db "$(_metadata_dir)/pkgs-ffffffffff.rds"
  _run r-cache
  [ "$status" -eq 0 ]
  [ -f "$(_metadata_dir)/pkgs-02e08e016f.rds" ]
  [ -f "$(_metadata_dir)/pkgs-3a56b2c8ed.rds" ]
}

@test "r-cache removes no snapshot when the current database lives in another cache dir" {
  _make_metadata
  mkdir -p "${FAKE_HOME}/elsewhere"
  echo other >"${FAKE_HOME}/elsewhere/pkgs-3a56b2c8ed.rds"
  _rscript_stub_current_db "${FAKE_HOME}/elsewhere/pkgs-3a56b2c8ed.rds"
  _run r-cache
  [ "$status" -eq 0 ]
  [ -f "$(_metadata_dir)/pkgs-02e08e016f.rds" ]
  [ -f "$(_metadata_dir)/pkgs-3a56b2c8ed.rds" ]
}

@test "r-cache touches no snapshot when Rscript is not on PATH" {
  _make_metadata
  _run r-cache
  [ "$status" -eq 0 ]
  [ -f "$(_metadata_dir)/pkgs-02e08e016f.rds" ]
  [ -f "$(_metadata_dir)/pkgs-ebe31bacf2.rds" ]
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
  for m in trash uv rv prek npm r-cache claude-versions flatpak \
    claude-cli chromium-headless positron-pycache workspace-storage \
    jedi apt journal snap; do
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

# ─── orphan hint from sys-orphans ───────────────────────────────────────────
# The daily run ends with one line when sys-orphans counts findings, so dangling
# references surface without anyone remembering to run the detector.

@test "summary ends with an orphan hint when sys-orphans counts findings" {
  _stub_command sys-orphans 'echo 3'
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" == *"TOTAL"*"3 orphans found, run sys-orphans for details"* ]]
}

@test "no orphan hint when sys-orphans counts zero" {
  _stub_command sys-orphans 'echo 0'
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" != *"orphans found"* ]]
}

@test "no orphan hint when sys-orphans is not on PATH" {
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" != *"orphans found"* ]]
}

@test "no orphan hint when sys-orphans prints something other than a count" {
  _stub_command sys-orphans 'echo "boom"; exit 1'
  _run --dry-run trash
  [ "$status" -eq 0 ]
  [[ "$output" != *"orphans found"* ]]
}

@test "summary FREED column reports 0 B for skipped modules" {
  _run --dry-run uv
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv"*"0 B"*"skipped (not found)"* ]]
}
