#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/st-add-folder

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/st-add-folder"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs replace pgrep, syncthing and curl so no real Syncthing instance is
# contacted. curl logs its full argument list; a GET answers an empty folder
# list so the "already exists" check passes.

_create_stubs() {
  cat >"${STUBS}/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

  cat >"${STUBS}/syncthing" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "cli config gui apikey get") printf 'FAKE-KEY\n' ;;
  "cli config devices list") printf 'DEVICE-A\n' ;;
esac
exit 0
EOF

  cat >"${STUBS}/curl" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${STUBS}/curl.log"
case "\$*" in
  *"-X GET"*) printf '[]\n' ;;
esac
exit 0
EOF

  chmod +x "${STUBS}"/*
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  WORK="$(mktemp -d)"
  export STUBS WORK

  mkdir -p "${WORK}/folder" "${WORK}/templates"
  printf '.git/\n' >"${WORK}/templates/.stignore"

  unset ST_URL
  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "${STUBS}" "${WORK}"
}

# ─── ignore template ────────────────────────────────────────────────────────

@test "copies the ignore template when the folder has no .stignore" {
  run bash "${SCRIPT}" "${WORK}/folder" --ignore "${WORK}/templates/.stignore"
  [ "$status" -eq 0 ]
  [ -f "${WORK}/folder/.stignore" ]
  [ ! -L "${WORK}/folder/.stignore" ]
  [[ "$output" == *"Copied .stignore"* ]]
}

@test "succeeds when .stignore is already a link to the template" {
  ln -s "${WORK}/templates/.stignore" "${WORK}/folder/.stignore"
  run bash "${SCRIPT}" "${WORK}/folder" --ignore "${WORK}/templates/.stignore"
  [ "$status" -eq 0 ]
  [ -L "${WORK}/folder/.stignore" ]
  [[ "$output" == *"Shared with 1 device(s)"* ]]
}

@test "dry-run does not announce a copy when .stignore is already a link" {
  ln -s "${WORK}/templates/.stignore" "${WORK}/folder/.stignore"
  run bash "${SCRIPT}" "${WORK}/folder" --ignore "${WORK}/templates/.stignore" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" != *"Would copy"* ]]
  [[ "$output" == *"already points to"* ]]
}

# ─── API endpoint ───────────────────────────────────────────────────────────

@test "targets 127.0.0.1:8384 by default" {
  run bash "${SCRIPT}" "${WORK}/folder"
  [ "$status" -eq 0 ]
  grep -q 'http://127.0.0.1:8384/rest/config/folders' "${STUBS}/curl.log"
}

@test "targets ST_URL when set" {
  ST_URL="http://127.0.0.1:8385" run bash "${SCRIPT}" "${WORK}/folder"
  [ "$status" -eq 0 ]
  grep -q 'http://127.0.0.1:8385/rest/config/folders' "${STUBS}/curl.log"
  run ! grep -q '8384' "${STUBS}/curl.log"
}
