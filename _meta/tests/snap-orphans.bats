#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/snap-orphans

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/snap-orphans"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs go in ${STUBS} and the test runs the script under PATH=${STUBS}, so
# only commands explicitly stubbed (or symlinked) are visible.

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

_install_sudo_stub() {
  # sudo -v / -n behave plausibly. The script's only non-probe invocation
  # is `sudo -E -- script args...` (root re-exec), which is gated on
  # DRY_RUN=0. Tests stick to --dry-run for sudo modes, so this arm must
  # never fire. If it does, abort loudly rather than `exec`-ing argv
  # verbatim (which would fail cryptically with `exec: -E: invalid option`).
  cat >"${STUBS}/sudo" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    -v) exit 0 ;;
    -n) exit 1 ;;
    *)
        printf 'sudo stub: unexpected invocation: %s\n' "$*" >&2
        exit 99
        ;;
esac
EOF
  chmod +x "${STUBS}/sudo"
}

# Build a fake /snap/<name>/current/meta/snap.yaml from a yaml body. The
# script reads $SNAP_META_ROOT/<name>/current/meta/snap.yaml.
_fake_snap_meta() {
  local name="$1" body="$2"
  mkdir -p "${SNAP_META}/${name}/current/meta"
  printf '%s\n' "$body" >"${SNAP_META}/${name}/current/meta/snap.yaml"
}

# Stub `snap` with a deterministic output for `snap list` and
# `snap connections --all`. Other subcommands (remove, forget, set, saved)
# are logged to ${STUBS}/snap.log so tests can assert on side-effects.
_stub_snap() {
  local list="$1" conns="$2" saved="${3:-}"
  cat >"${STUBS}/snap" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "list ")
    cat <<LIST
${list}
LIST
    ;;
  "connections --all")
    cat <<CONN
${conns}
CONN
    ;;
  "saved ")
    cat <<SAV
${saved}
SAV
    ;;
  *)
    printf '%s\n' "\$*" >>"${STUBS}/snap.log"
    ;;
esac
EOF
  chmod +x "${STUBS}/snap"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  SNAP_META="$(mktemp -d)"
  export STUBS FAKE_HOME SNAP_META
  _install_sudo_stub
  for cmd in awk cat du grep readlink sort; do
    if [[ ! -x "/usr/bin/${cmd}" ]]; then
      printf 'setup: /usr/bin/%s missing\n' "$cmd" >&2
      return 1
    fi
    ln -s "/usr/bin/${cmd}" "${STUBS}/${cmd}"
  done
  ln -s "${BASH}" "${STUBS}/bash"
}

teardown() {
  rm -rf "${STUBS}" "${FAKE_HOME}" "${SNAP_META}"
}

# Run the script with a restricted PATH and a fake snap-meta root. The
# script must already exist; we always invoke through bash so set -e
# propagation matches a real shebang invocation.
_run() {
  run env PATH="${STUBS}" HOME="${FAKE_HOME}" SNAP_META_ROOT="${SNAP_META}" \
    "$BASH" "${SCRIPT}" "$@"
}

# ─── help / usage ───────────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  _stub_command snap 'exit 0'
  _run --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"snap-orphans"* ]]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--remove"* ]]
  [[ "$output" == *"--purge-snapshots"* ]]
  [[ "$output" == *"--retention"* ]]
}

@test "-h is an alias for --help" {
  _stub_command snap 'exit 0'
  _run -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "script runs via its own shebang (executable, #!/usr/bin/env bash)" {
  _stub_command snap 'exit 0'
  run env PATH="${STUBS}" HOME="${FAKE_HOME}" SNAP_META_ROOT="${SNAP_META}" \
    "${SCRIPT}" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# ─── argument parsing errors ────────────────────────────────────────────────

@test "exits 2 on an unknown option" {
  _stub_command snap 'exit 0'
  _run --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option: --nope"* ]]
}

@test "--retention requires a value (exits 2 when missing)" {
  _stub_command snap 'exit 0'
  _run --retention
  [ "$status" -eq 2 ]
  [[ "$output" == *"--retention requires a value"* ]]
}

# ─── dependency check ──────────────────────────────────────────────────────

@test "exits 1 when snap is not installed" {
  # No snap stub → command -v snap fails
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"snap not installed"* ]]
}

# ─── detect_orphans: type-based exclusions ─────────────────────────────────

@test "core/snapd/gadget/kernel types are never flagged (system snaps)" {
  # type=core/snapd/gadget/kernel short-circuit the orphan check entirely,
  # regardless of consumers. Only type=base goes through the base-usage check.
  # Include a real orphan (unused base) alongside so the test asserts the
  # exclusion is selective, not a global "detector returns empty" regression.
  _stub_snap \
    "Name      Version  Rev  Tracking       Publisher  Notes
core      16-2.61  100  latest/stable  canonical  core
snapd     2.61     200  latest/stable  canonical  snapd
pc        22.04    300  -              canonical  gadget
pc-kernel 5.15     400  -              canonical  kernel
core20    20240101 90   latest/stable  canonical  base" \
    ""
  _fake_snap_meta core "type: core"
  _fake_snap_meta snapd "type: snapd"
  _fake_snap_meta pc "type: gadget"
  _fake_snap_meta pc-kernel "type: kernel"
  _fake_snap_meta core20 "type: base"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orphan snaps"* ]]
  [[ "$output" == *"core20"* ]]
  [[ "$output" != *"core "* ]]
  [[ "$output" != *"snapd"* ]]
  [[ "$output" != *"pc "* ]]
  [[ "$output" != *"pc-kernel"* ]]
}

@test "type:base falls through to the base-usage check (not a system exclusion)" {
  # An unused base IS flagged. Differentiates type=base from type=core.
  _stub_snap \
    "Name    Version  Rev  Tracking       Publisher  Notes
core22  20240101 100  latest/stable  canonical  base" \
    ""
  _fake_snap_meta core22 "type: base"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"core22"* ]]
}

@test "base snap declared by another snap is NOT orphan" {
  _stub_snap \
    "Name    Version  Rev  Tracking       Publisher  Notes
core22  20240101 100  latest/stable  canonical  base
firefox 120      500  latest/stable  mozilla    -" \
    ""
  _fake_snap_meta core22 "type: base"
  _fake_snap_meta firefox "$(printf 'type: app\nbase: core22\n')"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphan snaps detected"* ]]
}

@test "base snap with no consumer IS reported orphan" {
  _stub_snap \
    "Name    Version  Rev  Tracking       Publisher  Notes
core20  20240101 90   latest/stable  canonical  base
firefox 120      500  latest/stable  mozilla    -" \
    ""
  _fake_snap_meta core20 "type: base"
  _fake_snap_meta firefox "$(printf 'type: app\nbase: core22\n')"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orphan snaps"* ]]
  [[ "$output" == *"core20"* ]]
  [[ "$output" != *"firefox"* ]]
}

@test "content provider with an external consumer is NOT orphan" {
  _stub_snap \
    "Name           Version Rev Tracking      Publisher Notes
gtk-common-theme 0.1   100 latest/stable canonical -
firefox        120     500 latest/stable mozilla   -" \
    "Interface  Plug                          Slot                       Notes
content    firefox:gtk-3-themes           gtk-common-theme:gtk-3-themes -"
  _fake_snap_meta gtk-common-theme "type: app"
  _fake_snap_meta firefox "type: app"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphan snaps detected"* ]]
}

@test "content provider with no external consumer IS orphan" {
  _stub_snap \
    "Name           Version Rev Tracking      Publisher Notes
gnome-42-2204  0.0     100 latest/stable canonical -" \
    "Interface  Plug                Slot                      Notes
content    -                   gnome-42-2204:gnome-42-2204 -"
  _fake_snap_meta gnome-42-2204 "type: app"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orphan snaps"* ]]
  [[ "$output" == *"gnome-42-2204"* ]]
}

@test "leaf app with no content slot is never flagged" {
  _stub_snap \
    "Name    Version Rev Tracking      Publisher Notes
firefox 120    500 latest/stable mozilla   -" \
    "Interface Plug         Slot      Notes
home      firefox:home -         -"
  _fake_snap_meta firefox "type: app"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No orphan snaps detected"* ]]
}

# ─── report mode (default) ─────────────────────────────────────────────────

@test "report mode prints table headers when orphans exist" {
  _stub_snap \
    "Name    Version Rev Tracking      Publisher Notes
core20  20240101 90 latest/stable canonical base" \
    ""
  _fake_snap_meta core20 "type: base"
  _run
  [ "$status" -eq 0 ]
  grep -Eq '^snap[[:space:]]+size$' <<<"$output"
  grep -Eq '^core20[[:space:]]+[0-9?]' <<<"$output"
  [[ "$output" == *"snap-orphans --remove"* ]]
}

@test "report mode prints orphan count" {
  _stub_snap \
    "Name    Version Rev Tracking      Publisher Notes
core18  20240101 80 latest/stable canonical base
core20  20240101 90 latest/stable canonical base" \
    ""
  _fake_snap_meta core18 "type: base"
  _fake_snap_meta core20 "type: base"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orphan snaps (2)"* ]]
}

# ─── --remove (dry-run) ────────────────────────────────────────────────────

@test "--remove --dry-run prints pass header without invoking snap remove" {
  _stub_snap \
    "Name   Version Rev Tracking      Publisher Notes
core20 20240101 90 latest/stable canonical base" \
    ""
  _fake_snap_meta core20 "type: base"
  _run --remove --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pass 1"* ]]
  [[ "$output" != *"Pass 2"* ]]
  [ "$(grep -c '=== Pass ' <<<"$output")" -eq 1 ]
  [[ "$output" == *"core20"* ]]
  [[ "$output" == *"DRY: snap remove core20"* ]]
  [[ "$output" == *"dry-run cannot iterate further"* ]]
  [ ! -f "${STUBS}/snap.log" ]
}

@test "--remove --dry-run with no orphans reports zero passes" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" ""
  _run --remove --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No more orphans"* ]]
}

# ─── --purge-snapshots (dry-run) ───────────────────────────────────────────

@test "--purge-snapshots --dry-run reports 'no snapshots saved' when empty" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" "" ""
  _run --purge-snapshots --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"no snapshots saved"* ]]
}

@test "--purge-snapshots keeps snapshots whose snap is still installed" {
  _stub_snap \
    "Name    Version Rev Tracking      Publisher Notes
firefox 120    500 latest/stable mozilla   -" \
    "" \
    "Set Snap    Age  Version Rev Size  Notes
1   firefox 1d   120     500 10MB  -"
  _run --purge-snapshots --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"keep    1 (firefox still installed)"* ]]
}

@test "--purge-snapshots forgets snapshots whose snap is gone" {
  _stub_snap \
    "Name Version Rev Tracking Publisher Notes" \
    "" \
    "Set Snap     Age  Version Rev Size  Notes
7   oldsnap  90d  1.0     42  5MB   -"
  _run --purge-snapshots --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"forget  7 (oldsnap)"* ]]
  [[ "$output" == *"DRY: snap forget 7"* ]]
}

# ─── --retention ───────────────────────────────────────────────────────────

@test "--retention alone sets MODE=none (no report) and configures retention" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" ""
  _run --retention no --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"snapshots.automatic.retention=no"* ]]
  [[ "$output" == *"DRY: snap set system snapshots.automatic.retention=no"* ]]
  [[ "$output" != *"Orphan snaps"* ]]
  [[ "$output" != *"No orphan snaps detected"* ]]
}

@test "--retention combined with --remove runs both" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" ""
  _run --remove --retention 31d --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No more orphans"* ]]
  [[ "$output" == *"DRY: snap set system snapshots.automatic.retention=31d"* ]]
}

# ─── root escalation policy (dry-run skips it) ─────────────────────────────

@test "--remove --dry-run does not exec sudo even though remove needs root" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" ""
  rm -f "${STUBS}/sudo"
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${STUBS}/sudo.log"
exit 0
EOF
  chmod +x "${STUBS}/sudo"
  _run --remove --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}

@test "--retention --dry-run does not exec sudo" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" ""
  rm -f "${STUBS}/sudo"
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${STUBS}/sudo.log"
exit 0
EOF
  chmod +x "${STUBS}/sudo"
  _run --retention no --dry-run
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}

@test "default report mode does not exec sudo (read-only)" {
  _stub_snap "Name Version Rev Tracking Publisher Notes" ""
  rm -f "${STUBS}/sudo"
  cat >"${STUBS}/sudo" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${STUBS}/sudo.log"
exit 0
EOF
  chmod +x "${STUBS}/sudo"
  _run
  [ "$status" -eq 0 ]
  [ ! -f "${STUBS}/sudo.log" ]
}
