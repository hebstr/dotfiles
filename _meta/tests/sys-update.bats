#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/sys-update

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/sys-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs are written into ${STUBS} and the test sets PATH=${STUBS}, so only
# the commands explicitly stubbed are visible to the script. This is how
# "command not installed" cases are simulated: omit the stub.
#
# Default setup() installs sudo + sleep stubs only; per-test helpers add
# more stubs (apt-get, snap, npm, etc.) as needed.

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
  # the rest of the argv so e.g. `sudo apt-get update` runs the apt-get stub
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
  export STUBS
  _install_sudo_stub
  _stub_command sleep
  # Symlink the few coreutils the script itself needs (cat/paste used by
  # usage()). Bats's own PATH stays untouched; we restrict the script's
  # PATH only via _run (see below), so that absent-from-STUBS == "command
  # not installed" from the script's point of view.
  # cat/paste are needed by the script's usage(); bash is needed because
  # every stub script starts with `#!/usr/bin/env bash` and env resolves
  # bash against the (restricted) PATH the script runs under.
  ln -s "/usr/bin/cat" "${STUBS}/cat"
  ln -s "/usr/bin/paste" "${STUBS}/paste"
  ln -s "$BASH" "${STUBS}/bash"
}

# Invoke the script under a PATH that contains only ${STUBS}, so any tool
# we did not stub is genuinely "not found" from the script's perspective.
_run() {
  # Use $BASH (absolute path) because env resolves its program against the
  # new PATH — `bash` would not be found in ${STUBS} alone.
  run env PATH="$STUBS" "$BASH" "$SCRIPT" "$@"
}

teardown() {
  rm -rf "$STUBS"
}

# ─── help / usage ───────────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"sys-update"* ]]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "-h is an alias for --help" {
  _run -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "--help lists every available module" {
  _run --help
  [ "$status" -eq 0 ]
  for m in apt snap flatpak npm rustup cargo claude devtools uv-tools \
    rv rig duckdb lua-toolchain css-toolchain claude-plugins quarto pandoc positron anki libreoffice syncthing; do
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
  [[ "$output" == *"apt"* ]]
  [[ "$output" == *"anki"* ]]
}

@test "--list marks apt and snap as sudo modules" {
  _run --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^apt[[:space:]]+yes$'
  echo "$output" | grep -E '^snap[[:space:]]+yes$'
  echo "$output" | grep -E '^libreoffice[[:space:]]+yes$'
  echo "$output" | grep -E '^syncthing[[:space:]]+yes$'
  echo "$output" | grep -E '^npm[[:space:]]+no$'
  echo "$output" | grep -E '^quarto[[:space:]]+no$'
  echo "$output" | grep -E '^pandoc[[:space:]]+yes$'
  echo "$output" | grep -E '^lua-toolchain[[:space:]]+no$'
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
  _run --dry-run apt bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown module: bogus"* ]]
}

# ─── --dry-run prints commands without executing ────────────────────────────

@test "--dry-run apt prints the apt-get commands and does not run them" {
  # apt-get is intentionally NOT stubbed; if --dry-run actually executed,
  # the missing apt-get under set -e would crash. Test passing proves no exec.
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"sudo apt-get update"* ]]
  [[ "$output" == *"sudo apt-get full-upgrade"* ]]
}

@test "--dry-run does not invoke sudo -v even for sudo modules" {
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/sudo.log"
exit 0
EOF
  chmod +x "${STUBS}/sudo"
  _run --dry-run apt snap
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}

@test "--dry-run snap prints the snap refresh command" {
  _stub_command snap
  _run --dry-run snap
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo snap refresh"* ]]
}

# ─── module dispatch and skip behavior ──────────────────────────────────────

@test "non-sudo module records 'skipped (not found)' when its command is absent" {
  _run --dry-run npm
  [ "$status" -eq 0 ]
  [[ "$output" == *"npm"* ]]
  [[ "$output" == *"skipped (not found)"* ]]
}

@test "module with stubbed command records OK in dry-run mode" {
  _stub_command npm
  _run --dry-run npm
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] npm update -g"* ]]
  [[ "$output" == *"npm"*"OK"* ]]
}

@test "uv-tools module dispatches to the uv command" {
  _stub_command uv
  _run --dry-run uv-tools
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] uv tool upgrade --all"* ]]
}

@test "cargo module checks for cargo-install-update, not cargo" {
  _stub_command cargo
  _run --dry-run cargo
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped (cargo-update not found)"* ]]
}

@test "cargo module runs when cargo-install-update is on PATH" {
  _stub_command cargo-install-update
  _stub_command cargo
  _run --dry-run cargo
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] cargo install-update -a"* ]]
}

@test "claude-plugins module dispatches to claude-plugins-update" {
  _stub_command claude-plugins-update
  _run --dry-run claude-plugins
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] claude-plugins-update"* ]]
}

@test "libreoffice module dispatches to libreoffice-update" {
  _stub_command libreoffice-update
  _run --dry-run libreoffice
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] libreoffice-update"* ]]
}

@test "libreoffice module skips when libreoffice-update is absent" {
  _run --dry-run libreoffice
  [ "$status" -eq 0 ]
  [[ "$output" == *"libreoffice"*"skipped (not found)"* ]]
}

@test "quarto module dispatches to quarto-update, not quarto itself" {
  _stub_command quarto
  _run --dry-run quarto
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped (not found)"* ]]
}

@test "lua-toolchain module dispatches to lua-toolchain-update" {
  _stub_command lua-toolchain-update
  _run --dry-run lua-toolchain
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] lua-toolchain-update"* ]]
}

@test "css-toolchain module dispatches to css-toolchain-update" {
  _stub_command css-toolchain-update
  _run --dry-run css-toolchain
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] css-toolchain-update"* ]]
}

@test "pandoc module dispatches to pandoc-update" {
  _stub_command pandoc-update
  _run --dry-run pandoc
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] pandoc-update"* ]]
}

# ─── apt always runs (no command check) ─────────────────────────────────────

@test "apt module has no command-availability guard" {
  # apt is always considered available; in dry-run it always prints
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] sudo apt-get update"* ]]
  [[ "$output" != *"skipped"* ]]
}

# ─── multiple modules ───────────────────────────────────────────────────────

@test "multiple modules are processed in order" {
  _stub_command npm
  _stub_command rustup
  _run --dry-run npm rustup
  [ "$status" -eq 0 ]
  npm_pos="${output%%→ npm*}"
  rustup_pos="${output%%→ rustup*}"
  [ "${#npm_pos}" -lt "${#rustup_pos}" ]
}

@test "no module argument selects all modules" {
  _run --dry-run
  [ "$status" -eq 0 ]
  for m in apt snap flatpak npm rustup cargo claude devtools uv-tools \
    rv rig duckdb lua-toolchain css-toolchain claude-plugins quarto pandoc positron anki libreoffice syncthing; do
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
  _stub_command apt-get
  _run apt
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
  _stub_command npm
  _run npm
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}

# ─── execution path (non-dry-run) ───────────────────────────────────────────

@test "non-dry-run apt actually invokes apt-get update and full-upgrade" {
  cat >"${STUBS}/apt-get" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/apt.log"
exit 0
EOF
  chmod +x "${STUBS}/apt-get"
  _run apt
  [ "$status" -eq 0 ]
  grep -q '^update -q$' "${STUBS}/apt.log"
  grep -q '^full-upgrade -y$' "${STUBS}/apt.log"
}

@test "module exit propagates: failing apt-get aborts the script" {
  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${STUBS}/apt-get"
  _run apt
  [ "$status" -ne 0 ]
}

# ─── summary table ──────────────────────────────────────────────────────────

@test "summary table is printed with MODULE/STATUS header" {
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODULE"*"STATUS"* ]]
}

@test "summary lists each selected module exactly once" {
  _stub_command npm
  _run --dry-run apt npm
  [ "$status" -eq 0 ]
  summary="${output#*MODULE*STATUS}"
  [[ "$summary" == *"apt"* ]]
  [[ "$summary" == *"npm"* ]]
}

@test "skipped modules show their skip reason in the summary" {
  _run --dry-run npm flatpak
  [ "$status" -eq 0 ]
  summary="${output#*MODULE*STATUS}"
  [[ "$summary" == *"npm"*"skipped (not found)"* ]]
  [[ "$summary" == *"flatpak"*"skipped (not found)"* ]]
}
