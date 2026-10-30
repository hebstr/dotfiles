#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/sys-update

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/sys-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs are written into ${STUBS} and the test sets PATH=${STUBS}, so only
# the commands explicitly stubbed are visible to the script. This is how
# "command not installed" cases are simulated: omit the stub.
#
# Default setup() installs a sudo stub and links cat, paste and bash;
# per-test helpers add
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
  # Use $BASH (absolute path) so the script's interpreter never depends on
  # the restricted PATH that env applies.
  run env PATH="$STUBS" HOME="${STUBS}/home" "$BASH" "$SCRIPT" "$@"
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
  for m in apt snap flatpak npm rustup cargo claude blesh devtools uv-python uv-tools \
    rv rig gh duckdb lua-toolchain css-toolchain claude-plugins agent-skills quarto positron anki libreoffice zotero syncthing; do
    [[ "$output" == *"$m"* ]] || {
      printf 'missing module: %s\n' "$m" >&2
      return 1
    }
  done
}

# ─── --list ─────────────────────────────────────────────────────────────────

@test "--list shows MODULE/SUDO header and module rows" {
  _run --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODULE"* ]]
  [[ "$output" == *"SUDO"* ]]
  [[ "$output" == *"apt"* ]]
  [[ "$output" == *"anki"* ]]
}

@test "--list marks the sudo column per module" {
  _run --list
  [ "$status" -eq 0 ]
  echo "$output" | grep -E '^apt[[:space:]]+yes$'
  echo "$output" | grep -E '^snap[[:space:]]+yes$'
  echo "$output" | grep -E '^libreoffice[[:space:]]+yes$'
  echo "$output" | grep -E '^zotero[[:space:]]+yes$'
  echo "$output" | grep -E '^syncthing[[:space:]]+yes$'
  echo "$output" | grep -E '^npm[[:space:]]+no$'
  echo "$output" | grep -E '^quarto[[:space:]]+yes$'
  echo "$output" | grep -E '^positron[[:space:]]+yes$'
  echo "$output" | grep -E '^anki[[:space:]]+yes$'
  echo "$output" | grep -E '^rig[[:space:]]+yes$'
  echo "$output" | grep -E '^gh[[:space:]]+yes$'
  echo "$output" | grep -E '^devtools[[:space:]]+yes$'
  echo "$output" | grep -E '^duckdb[[:space:]]+no$'
  echo "$output" | grep -E '^lua-toolchain[[:space:]]+no$'
  echo "$output" | grep -E '^agent-skills[[:space:]]+no$'
  echo "$output" | grep -E '^blesh[[:space:]]+no$'
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
  # apt-get is not stubbed: if --dry-run executed it, the module would be
  # recorded as FAIL and the script would exit 1.
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

@test "uv-tools module skips when uv is absent" {
  _run --dry-run uv-tools
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv-tools"*"skipped (not found)"* ]]
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
  [[ "$output" == *"[dry-run] env GGSQL_SKIP_GENERATE=1 cargo install-update -a"* ]]
}

@test "cargo module exports GGSQL_SKIP_GENERATE to the cargo process" {
  ln -s "/usr/bin/env" "${STUBS}/env"
  _stub_command cargo-install-update
  cat >"${STUBS}/cargo" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\${GGSQL_SKIP_GENERATE:-unset}" "\$*" >> "${STUBS}/cargo.log"
EOF
  chmod +x "${STUBS}/cargo"
  _run cargo
  [ "$status" -eq 0 ]
  grep -q '^1 install-update -a$' "${STUBS}/cargo.log"
}

@test "uv-python module upgrades the interpreters, not the tool packages" {
  _stub_command uv
  _run --dry-run uv-python
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] uv python upgrade"* ]]
  [[ "$output" != *"tool upgrade"* ]]
}

@test "uv-python module skips when uv is absent" {
  _run --dry-run uv-python
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv-python"*"skipped (not found)"* ]]
}

@test "uv-python runs before uv-tools so the tool venvs follow the new patch" {
  _stub_command uv
  _run --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ uv-python"* ]]
  [[ "$output" == *"→ uv-tools"* ]]
  python_pos="${output%%→ uv-python*}"
  tools_pos="${output%%→ uv-tools*}"
  [ "${#python_pos}" -lt "${#tools_pos}" ]
}

# The prune reads the install directory `uv python dir` prints, so the stub
# answers that one subcommand with a fixture directory and logs every argv.
# Its optional argument is the exit code `python uninstall` answers with, so a
# test can drive the prune's failure path.
# Fixtures are built with real directories and real symlinks: the script
# decides what to keep with `-ef`, which only a true symlink satisfies.
_stub_uv_python_dir() {
  local uninstall_code="${1:-0}"
  PYDIR="${STUBS}/pythons"
  mkdir -p "$PYDIR"
  cat >"${STUBS}/uv" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${STUBS}/uv.log"
if [ "\$1 \$2" = "python dir" ]; then
  printf '%s\n' "${PYDIR}"
fi
if [ "\$1 \$2" = "python uninstall" ]; then
  exit ${uninstall_code}
fi
exit 0
EOF
  chmod +x "${STUBS}/uv"
}

@test "uv-python prunes the patch its minor line no longer links to" {
  _stub_uv_python_dir
  mkdir -p "${PYDIR}/cpython-3.14.9-linux-x86_64-gnu" "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" "${PYDIR}/cpython-3.14-linux-x86_64-gnu"
  _run uv-python
  [ "$status" -eq 0 ]
  grep -q '^python uninstall cpython-3.14.9-linux-x86_64-gnu$' "${STUBS}/uv.log"
  [[ "$output" == *"uv-python"*"OK (1 stale pruned)"* ]]
}

@test "uv-python leaves a minor line uv never linked alone" {
  _stub_uv_python_dir
  mkdir -p "${PYDIR}/cpython-3.13.5-linux-x86_64-gnu"
  _run uv-python
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv-python"*"OK"* ]]
  [[ "$output" != *"stale pruned"* ]]
  run ! grep -q 'uninstall' "${STUBS}/uv.log"
}

@test "uv-python prunes every minor line in one uninstall call" {
  _stub_uv_python_dir
  mkdir -p "${PYDIR}/cpython-3.13.5-linux-x86_64-gnu" "${PYDIR}/cpython-3.13.7-linux-x86_64-gnu" \
    "${PYDIR}/cpython-3.14.9-linux-x86_64-gnu" "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.13.7-linux-x86_64-gnu" "${PYDIR}/cpython-3.13-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" "${PYDIR}/cpython-3.14-linux-x86_64-gnu"
  _run uv-python
  [ "$status" -eq 0 ]
  grep -q '^python uninstall cpython-3.13.5-linux-x86_64-gnu cpython-3.14.9-linux-x86_64-gnu$' "${STUBS}/uv.log"
  [[ "$output" == *"uv-python"*"OK (2 stale pruned)"* ]]
}

@test "uv-python keeps a free-threaded patch out of the default line's prune" {
  _stub_uv_python_dir
  mkdir -p "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" \
    "${PYDIR}/cpython-3.14.9+freethreaded-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" "${PYDIR}/cpython-3.14-linux-x86_64-gnu"
  _run uv-python
  [ "$status" -eq 0 ]
  run ! grep -q 'uninstall' "${STUBS}/uv.log"
}

@test "uv-python reports plain OK when the only patch is the linked one" {
  _stub_uv_python_dir
  mkdir -p "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" "${PYDIR}/cpython-3.14-linux-x86_64-gnu"
  _run uv-python
  [ "$status" -eq 0 ]
  [[ "$output" != *"stale pruned"* ]]
  run ! grep -q 'uninstall' "${STUBS}/uv.log"
}

@test "uv-python reports FAIL when the prune's uninstall fails" {
  _stub_uv_python_dir 1
  mkdir -p "${PYDIR}/cpython-3.14.9-linux-x86_64-gnu" "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" "${PYDIR}/cpython-3.14-linux-x86_64-gnu"
  _run uv-python
  [ "$status" -ne 0 ]
  [[ "$output" == *"uv-python"*"FAIL"* ]]
  [[ "$output" != *"stale pruned"* ]]
}

@test "uv-python prune survives an install directory that does not exist" {
  _stub_uv_python_dir
  rm -rf "$PYDIR"
  _run uv-python
  [ "$status" -eq 0 ]
  [[ "$output" == *"uv-python"*"OK"* ]]
  run ! grep -q 'uninstall' "${STUBS}/uv.log"
}

@test "--dry-run uv-python reports the prune in the conditional and uninstalls nothing" {
  _stub_uv_python_dir
  mkdir -p "${PYDIR}/cpython-3.14.9-linux-x86_64-gnu" "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu"
  ln -s "${PYDIR}/cpython-3.14.10-linux-x86_64-gnu" "${PYDIR}/cpython-3.14-linux-x86_64-gnu"
  _run --dry-run uv-python
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] uv python uninstall cpython-3.14.9-linux-x86_64-gnu"* ]]
  [[ "$output" == *"uv-python"*"OK (1 stale would be pruned)"* ]]
  [[ "$output" != *"stale pruned)"* ]]
  run ! grep -q 'python uninstall' "${STUBS}/uv.log"
}

@test "blesh module skips when ble.sh is not installed" {
  _run blesh
  [ "$status" -eq 0 ]
  [[ "$output" == *"blesh"*"skipped (blesh not installed)"* ]]
}

@test "blesh module runs the installed ble.sh with --update" {
  mkdir -p "${STUBS}/home/.local/share/blesh"
  cat >"${STUBS}/home/.local/share/blesh/ble.sh" <<EOF
printf '%s\n' "\$*" >> "${STUBS}/blesh.log"
EOF
  _run blesh
  [ "$status" -eq 0 ]
  [ "$(cat "${STUBS}/blesh.log")" = "--update" ]
  summary="${output#*MODULE*STATUS}"
  [[ "$summary" == *"blesh"*"OK"* ]]
}

@test "claude-plugins module dispatches to claude-plugins-update" {
  _stub_command claude-plugins-update
  _run --dry-run claude-plugins
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] claude-plugins-update"* ]]
}

@test "agent-skills module dispatches to agent-skills-update" {
  _stub_command agent-skills-update
  _run --dry-run agent-skills
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] agent-skills-update"* ]]
}

@test "libreoffice module dispatches to libreoffice-update" {
  _stub_command libreoffice
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

@test "zotero module dispatches to zotero-update" {
  _stub_command zotero
  _stub_command zotero-update
  _run --dry-run zotero
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] zotero-update"* ]]
}

@test "zotero module skips when zotero-update is absent" {
  _run --dry-run zotero
  [ "$status" -eq 0 ]
  [[ "$output" == *"zotero"*"skipped (not found)"* ]]
}

# ─── application modules update, never install ──────────────────────────────
# positron, anki, libreoffice and zotero ship updaters that install the application
# when it is absent; sys-update must only run them where the app already is.

_stub_logging_updater() {
  cat >"${STUBS}/$1-update" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$1-update" >> "${STUBS}/updater.log"
EOF
  chmod +x "${STUBS}/$1-update"
}

@test "positron module skips when positron is not installed" {
  _stub_logging_updater positron
  _run positron
  [ "$status" -eq 0 ]
  [[ "$output" == *"positron"*"skipped (positron not installed)"* ]]
  [ ! -f "${STUBS}/updater.log" ]
}

@test "anki module skips when anki is not installed" {
  _stub_logging_updater anki
  _run anki
  [ "$status" -eq 0 ]
  [[ "$output" == *"anki"*"skipped (anki not installed)"* ]]
  [ ! -f "${STUBS}/updater.log" ]
}

@test "libreoffice module skips when libreoffice is not installed" {
  _stub_logging_updater libreoffice
  _run libreoffice
  [ "$status" -eq 0 ]
  [[ "$output" == *"libreoffice"*"skipped (libreoffice not installed)"* ]]
  [ ! -f "${STUBS}/updater.log" ]
}

@test "zotero module skips when zotero is not installed" {
  _stub_logging_updater zotero
  _run zotero
  [ "$status" -eq 0 ]
  [[ "$output" == *"zotero"*"skipped (zotero not installed)"* ]]
  [ ! -f "${STUBS}/updater.log" ]
}

@test "application modules run their updater when the application is installed" {
  for app in positron anki libreoffice zotero; do
    _stub_command "$app"
    _stub_logging_updater "$app"
  done
  _run positron anki libreoffice zotero
  [ "$status" -eq 0 ]
  [ "$(cat "${STUBS}/updater.log")" = "$(printf '%s\n' positron-update anki-update libreoffice-update zotero-update)" ]
}

@test "no module argument never installs absent applications" {
  for app in positron anki libreoffice zotero; do
    _stub_logging_updater "$app"
  done
  _run --dry-run
  [ "$status" -eq 0 ]
  for app in positron anki libreoffice zotero; do
    [[ "$output" != *"[dry-run] ${app}-update"* ]]
    [[ "$output" == *"${app}"*"skipped (${app} not installed)"* ]]
  done
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

@test "gh module dispatches to gh-update" {
  _stub_command gh-update
  _run --dry-run gh
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run] gh-update"* ]]
}

@test "gh module skips when gh-update is absent" {
  _run --dry-run gh
  [ "$status" -eq 0 ]
  [[ "$output" == *"gh"*"skipped (not found)"* ]]
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
  [[ "$output" == *"→ npm"* ]]
  [[ "$output" == *"→ rustup"* ]]
  npm_pos="${output%%→ npm*}"
  rustup_pos="${output%%→ rustup*}"
  [ "${#npm_pos}" -lt "${#rustup_pos}" ]
}

@test "no module argument selects all modules" {
  _run --dry-run
  [ "$status" -eq 0 ]
  for m in apt snap flatpak npm rustup cargo claude blesh devtools uv-python uv-tools \
    rv rig gh duckdb lua-toolchain css-toolchain claude-plugins agent-skills quarto positron anki libreoffice zotero syncthing; do
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
  grep -q '^update -q --error-on=any$' "${STUBS}/apt.log"
  grep -q '^full-upgrade -y$' "${STUBS}/apt.log"
}

@test "failed index refresh still runs full-upgrade and reports apt as FAIL" {
  cat >"${STUBS}/apt-get" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/apt.log"
[[ "\$1" == update && "\$*" == *--error-on=any* ]] && exit 100
exit 0
EOF
  chmod +x "${STUBS}/apt-get"
  _run apt
  [ "$status" -eq 1 ]
  grep -q '^full-upgrade -y$' "${STUBS}/apt.log"
  summary="${output#*MODULE*STATUS}"
  [[ "$summary" == *"apt"*"FAIL (index refresh)"* ]]
  [[ "$summary" != *"OK"* ]]
  [ "$(grep -c '^apt ' <<<"$summary")" -eq 1 ]
}

@test "module exit propagates: failing apt-get makes the script exit non-zero" {
  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${STUBS}/apt-get"
  _run apt
  [ "$status" -ne 0 ]
}

# A child that traps SIGINT and exits normally hides the Ctrl-C from bash's
# wait-and-cooperative-exit; setsid gives the run its own process group so
# `kill -INT 0` reaches sys-update without reaching bats.
@test "Ctrl-C aborts the run even when the module's child traps SIGINT" {
  cat >"${STUBS}/apt-get" <<'EOF'
#!/usr/bin/env bash
trap 'exit 130' INT
kill -INT 0
exit 0
EOF
  chmod +x "${STUBS}/apt-get"
  _stub_command snap
  _stub_command npm "touch '${STUBS}/npm.ran'"
  run setsid env PATH="$STUBS" "$BASH" "$SCRIPT" snap apt npm
  [ "$status" -eq 130 ]
  [ ! -e "${STUBS}/npm.ran" ]
  summary="${output#*MODULE*STATUS}"
  [[ "$summary" == *"snap"*"OK"* ]]
}

# ─── summary table ──────────────────────────────────────────────────────────

@test "summary table is printed with MODULE/STATUS header" {
  _run --dry-run apt
  [ "$status" -eq 0 ]
  [[ "$output" == *"MODULE"*"STATUS"* ]]
}

@test "summary lists each selected module" {
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
