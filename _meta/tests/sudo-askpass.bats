#!/usr/bin/env bats
# Tests for bin/.local/bin/sudo-askpass

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/sudo-askpass"

# ─── stub factory ───────────────────────────────────────────────────────────
# The script is run with PATH=${STUBS}, so zenity resolves to the stub here
# and never opens a real dialog. Omitting the stub is how "zenity not
# installed" is simulated.

setup() {
  STUBS="$(mktemp -d)"
  export STUBS
  ln -s "$BASH" "${STUBS}/bash"
}

teardown() {
  rm -rf "$STUBS"
}

_stub_zenity() {
  cat >"${STUBS}/zenity" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/zenity.log"
printf 'hunter2\n'
EOF
  chmod +x "${STUBS}/zenity"
}

_run() {
  run env PATH="$STUBS" "$@" "$BASH" "$SCRIPT" "[sudo] password for julien:"
}

# ─── happy path ─────────────────────────────────────────────────────────────

@test "prints the password zenity returns, on stdout alone" {
  _stub_zenity
  _run DISPLAY=:0
  [ "$status" -eq 0 ]
  [ "$output" = "hunter2" ]
}

@test "passes the prompt sudo gave as the dialog title" {
  _stub_zenity
  _run DISPLAY=:0
  [ "$status" -eq 0 ]
  grep -q -- '--title=\[sudo\] password for julien:' "${STUBS}/zenity.log"
}

@test "asks zenity for a modal password dialog with a timeout" {
  _stub_zenity
  _run DISPLAY=:0
  [ "$status" -eq 0 ]
  grep -q -- '--password' "${STUBS}/zenity.log"
  grep -q -- '--modal' "${STUBS}/zenity.log"
  grep -q -- '--timeout=120' "${STUBS}/zenity.log"
}

@test "accepts a wayland display as well as an X one" {
  _stub_zenity
  run env -u DISPLAY PATH="$STUBS" WAYLAND_DISPLAY=wayland-0 \
    "$BASH" "$SCRIPT" "prompt"
  [ "$status" -eq 0 ]
  [ "$output" = "hunter2" ]
}

# ─── failure paths ──────────────────────────────────────────────────────────

@test "refuses without a display instead of hanging" {
  _stub_zenity
  run env -u DISPLAY -u WAYLAND_DISPLAY PATH="$STUBS" "$BASH" "$SCRIPT" "prompt"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no graphical display"* ]]
  [ ! -f "${STUBS}/zenity.log" ]
}

@test "refuses when zenity is absent" {
  _run DISPLAY=:0
  [ "$status" -eq 1 ]
  [[ "$output" == *"zenity not installed"* ]]
}

@test "propagates a cancelled dialog as a failure and prints no password" {
  _stub_zenity
  cat >"${STUBS}/zenity" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${STUBS}/zenity"
  _run DISPLAY=:0
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "propagates a timed-out dialog as a failure" {
  _stub_zenity
  cat >"${STUBS}/zenity" <<'EOF'
#!/usr/bin/env bash
exit 5
EOF
  chmod +x "${STUBS}/zenity"
  _run DISPLAY=:0
  [ "$status" -eq 5 ]
  [ -z "$output" ]
}

@test "writes the password to no file of its own" {
  _stub_zenity
  _run DISPLAY=:0
  [ "$status" -eq 0 ]
  run ! grep -rl 'hunter2' "$STUBS" --exclude=zenity
}
