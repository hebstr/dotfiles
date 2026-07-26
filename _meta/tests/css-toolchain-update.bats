#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/css-toolchain-update

SCRIPT="${CSS_TOOLCHAIN_UPDATE:-$BATS_TEST_DIRNAME/../../bin/.local/bin/css-toolchain-update}"

# ─── stub factory ───────────────────────────────────────────────────────────
# Stubs live in ${STUBS} (prepended to PATH). Behaviour is driven by exported
# env vars read at runtime, so a test overrides only what it needs.
#
#   LATEST_PRETTIER    version the registry reports for prettier
#   LATEST_STYLELINT   version the registry reports for stylelint
#   LATEST_CONFIG      version the registry reports for stylelint-config-standard-scss
#   CURL_EXIT          exit code of the curl stub (non-zero = registry unreachable)
#   VERSION_LITERAL    when set, every package resolves to this raw JSON value
#                      instead of a version string (`null`, `""`)
#   NPM_EXIT           exit code of the npm stub
#   NPM_LOG            file the npm stub appends its argv to
#   CURL_LOG           file the curl stub appends its argv to
#
#   PIN_PRETTIER       version pinned in package.json devDependencies
#   PIN_STYLELINT      idem
#   PIN_CONFIG         idem
#
# jq is used unstubbed: it reads real manifests written by the tests, and the
# script's own error paths are what these tests exercise, not jq's.
#
# Two distinct version axes, and conflating them is the bug these tests guard:
# the PIN in ${GATE_DIR}/package.json is the committed source of truth compared
# against the registry, while ${GATE_DIR}/node_modules/<pkg>/package.json is
# merely what the tree currently holds. A test writes each independently.

_create_stubs() {
  cat >"${STUBS}/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_LOG}"
[ "${CURL_EXIT:-0}" != 0 ] && exit "${CURL_EXIT}"
url="${*: -1}"
pkg="${url##*/registry.npmjs.org/}"
pkg="${pkg%/latest}"
if [ -n "${VERSION_LITERAL:-}" ]; then
    printf '{"version":%s}\n' "${VERSION_LITERAL}"
    exit 0
fi
case "$pkg" in
    prettier) v="${LATEST_PRETTIER}" ;;
    stylelint) v="${LATEST_STYLELINT}" ;;
    stylelint-config-standard-scss) v="${LATEST_CONFIG}" ;;
    *) v="0.0.0" ;;
esac
printf '{"version":"%s"}\n' "$v"
EOF

  # Mirrors what `npm install --save-exact` does to the tree, so the script's
  # closing "✓ pkg version" lines read back a real manifest. The target is
  # asserted rather than inherited: a script that stops aiming npm at the gate
  # directory would otherwise write node_modules into the caller's cwd, and
  # `**/node_modules/` being gitignored makes that pollution invisible.
  cat >"${STUBS}/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${NPM_LOG}"
[ "${NPM_EXIT:-0}" != 0 ] && exit "${NPM_EXIT}"
target="${PWD}"
prev=""
for a in "$@"; do
    case "$a" in
        --prefix=*) target="${a#--prefix=}" ;;
        *) [ "$prev" = "--prefix" ] && target="$a" ;;
    esac
    prev="$a"
done
if [ "$target" != "${CSS_GATE_DIR}" ]; then
    printf 'npm stub: refusing to write outside the gate dir (target=%s)\n' "$target" >&2
    exit 1
fi
for a in "$@"; do
    case "$a" in
        -*|install) continue ;;
        *@*)
            pkg="${a%@*}"; ver="${a##*@}"
            mkdir -p "${target}/node_modules/${pkg}"
            printf '{"version":"%s"}\n' "$ver" >"${target}/node_modules/${pkg}/package.json" ;;
    esac
done
exit 0
EOF

  chmod +x "${STUBS}/curl" "${STUBS}/npm"
}

_install_fixture() {
  local pkg="$1" version="$2"
  mkdir -p "${GATE_DIR}/node_modules/${pkg}"
  printf '{"version":"%s"}\n' "$version" >"${GATE_DIR}/node_modules/${pkg}/package.json"
}

_write_manifest() {
  cat >"${GATE_DIR}/package.json" <<EOF
{
  "name": "css-gate",
  "private": true,
  "devDependencies": {
    "prettier": "${PIN_PRETTIER}",
    "stylelint": "${PIN_STYLELINT}",
    "stylelint-config-standard-scss": "${PIN_CONFIG}"
  }
}
EOF
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  export STUBS
  export HOME="${STUBS}/home"
  export CSS_GATE_DIR="${HOME}/.local/share/css-gate"
  export GATE_DIR="$CSS_GATE_DIR"
  mkdir -p "$GATE_DIR"

  export NPM_LOG="${STUBS}/npm.log"
  export CURL_LOG="${STUBS}/curl.log"
  : >"$NPM_LOG"
  : >"$CURL_LOG"

  export LATEST_PRETTIER=3.9.6
  export LATEST_STYLELINT=17.14.1
  export LATEST_CONFIG=17.0.0

  export PIN_PRETTIER=3.9.6
  export PIN_STYLELINT=17.14.1
  export PIN_CONFIG=17.0.0

  _write_manifest
  _install_fixture prettier 3.9.6
  _install_fixture stylelint 17.14.1
  _install_fixture stylelint-config-standard-scss 17.0.0

  _create_stubs
  export PATH="${STUBS}:${PATH}"
}

teardown() {
  rm -rf "$STUBS"
}

# ─── manifest agreement ─────────────────────────────────────────────────────
# The script's PACKAGES array is what gets version-checked; the stow package's
# manifest is what gets installed. A package added to one and not the other is
# silently never updated, so the two are pinned against each other here.

@test "PACKAGES matches the devDependencies of the shipped gate manifest" {
  local manifest="${BATS_TEST_DIRNAME}/../../css/.local/share/css-gate/package.json"
  [ -f "$manifest" ]
  local declared expected
  declared=$(sed -n 's/^PACKAGES=(\(.*\))$/\1/p' "$SCRIPT" | tr ' ' '\n' | sort)
  expected=$(jq -r '.devDependencies | keys[]' "$manifest" | sort)
  if [ "$declared" != "$expected" ]; then
    printf 'PACKAGES:\n%s\nmanifest devDependencies:\n%s\n' "$declared" "$expected" >&2
    return 1
  fi
}

# ─── argument parsing ───────────────────────────────────────────────────────

@test "--help prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"css-toolchain-update"* ]]
  [[ "$output" == *"USAGE"* ]]
}

@test "-h is an alias for --help" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"USAGE"* ]]
}

@test "--help queries neither the registry nor npm" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [ ! -s "$CURL_LOG" ]
  [ ! -s "$NPM_LOG" ]
}

@test "unexpected argument exits 2 and prints usage" {
  run bash "$SCRIPT" stylelint
  [ "$status" -eq 2 ]
  [[ "$output" == *"unexpected argument 'stylelint'"* ]]
  [[ "$output" == *"USAGE"* ]]
}

@test "unknown option is rejected as an unexpected argument" {
  run bash "$SCRIPT" --nope
  [ "$status" -eq 2 ]
  [[ "$output" == *"unexpected argument '--nope'"* ]]
}

# ─── dependency preflight ───────────────────────────────────────────────────
# A restricted PATH holds only the stubs plus symlinked bash/env, so removing
# one entry is what the preflight loop reports.

_restricted_path_run() {
  local drop="$1"
  ln -sf "$BASH" "${STUBS}/bash"
  ln -sf "$(command -v env)" "${STUBS}/env"
  ln -sf "$(command -v jq)" "${STUBS}/jq"
  ln -sf "$(command -v mktemp)" "${STUBS}/mktemp"
  rm -f "${STUBS}/${drop}"
  run env PATH="$STUBS" "$BASH" "$SCRIPT"
}

@test "exits 1 when npm is missing" {
  _restricted_path_run npm
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'npm'"* ]]
}

@test "exits 1 when curl is missing" {
  _restricted_path_run curl
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'curl'"* ]]
}

@test "exits 1 when jq is missing" {
  _restricted_path_run jq
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing required command 'jq'"* ]]
}

@test "a missing dependency stops before any registry call" {
  _restricted_path_run npm
  [ "$status" -eq 1 ]
  [ ! -s "$CURL_LOG" ]
}

# ─── gate directory ─────────────────────────────────────────────────────────

@test "exits 1 when the gate package.json is absent" {
  rm -f "${GATE_DIR}/package.json"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no package.json in ${GATE_DIR}"* ]]
  [[ "$output" == *"css stow package is not deployed"* ]]
}

@test "reads the gate directory from CSS_GATE_DIR, not the hardcoded default" {
  local elsewhere="${STUBS}/elsewhere"
  mkdir -p "$elsewhere"
  export CSS_GATE_DIR="$elsewhere"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no package.json in ${elsewhere}"* ]]
}

# ─── version resolution failures ────────────────────────────────────────────

@test "exits 1 when the registry is unreachable" {
  export CURL_EXIT=22
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to resolve latest version of prettier"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "exits 1 when the registry reports a null version" {
  export VERSION_LITERAL=null
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty latest version for prettier"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "exits 1 when the registry reports an empty version" {
  export VERSION_LITERAL='""'
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty latest version for prettier"* ]]
  [ ! -s "$NPM_LOG" ]
}

# ─── up-to-date behavior ────────────────────────────────────────────────────

@test "all packages current: reports up to date and never calls npm" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"= prettier 3.9.6"* ]]
  [[ "$output" == *"= stylelint 17.14.1"* ]]
  [[ "$output" == *"= stylelint-config-standard-scss 17.0.0"* ]]
  [[ "$output" == *"already up to date"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "--check on a current tree reports up to date" {
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"already up to date"* ]]
  [ ! -s "$NPM_LOG" ]
}

# ─── outdated behavior ──────────────────────────────────────────────────────

@test "one outdated package is installed pinned, the others are left alone" {
  export LATEST_STYLELINT=17.15.0
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"↑ stylelint 17.14.1 → 17.15.0"* ]]
  [[ "$output" == *"= prettier 3.9.6"* ]]
  [ "$(wc -l <"$NPM_LOG")" -eq 1 ]
  [[ "$(cat "$NPM_LOG")" == *"--save-exact"* ]]
  [[ "$(cat "$NPM_LOG")" == *"--save-dev"* ]]
  [[ "$(cat "$NPM_LOG")" == *"stylelint@17.15.0"* ]]
  [[ "$(cat "$NPM_LOG")" != *"prettier@"* ]]
}

@test "several outdated packages go through a single npm invocation" {
  export LATEST_STYLELINT=17.15.0
  export LATEST_CONFIG=18.0.0
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(wc -l <"$NPM_LOG")" -eq 1 ]
  [[ "$(cat "$NPM_LOG")" == *"stylelint@17.15.0"* ]]
  [[ "$(cat "$NPM_LOG")" == *"stylelint-config-standard-scss@18.0.0"* ]]
}

@test "the install lands in the gate directory, not the caller's cwd" {
  export LATEST_STYLELINT=17.15.0
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run jq -r '.version' "${GATE_DIR}/node_modules/stylelint/package.json"
  [ "$output" = "17.15.0" ]
}

# prettier's tree version is seeded away from both its pin and its latest, so a
# report echoing either instead of reading the tree fails here.
@test "the closing report reads the tree, not the requested version" {
  export LATEST_STYLELINT=17.15.0
  _install_fixture prettier 3.9.5
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ stylelint 17.15.0"* ]]
  [[ "$output" == *"✓ prettier 3.9.5"* ]]
  [[ "$output" != *"✓ prettier 3.9.6"* ]]
  [[ "$output" == *"✓ stylelint-config-standard-scss 17.0.0"* ]]
  [[ "$output" == *"commit package.json and package-lock.json"* ]]
}

@test "--check reports available updates without installing" {
  export LATEST_STYLELINT=17.15.0
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"↑ stylelint 17.14.1 → 17.15.0"* ]]
  [[ "$output" == *"1 update(s) available, none installed"* ]]
  [ ! -s "$NPM_LOG" ]
}

# ─── pin vs installed tree ──────────────────────────────────────────────────
# The pin is the comparison basis. An absent or stale tree is a separate
# condition, restored with `npm ci`, and must never bump the committed pin.

@test "a fresh tree with no node_modules compares against the pin, not none" {
  rm -rf "${GATE_DIR}/node_modules"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"= prettier 3.9.6"* ]]
  [[ "$output" != *"= prettier none"* ]]
  [[ "$output" != *"↑ prettier none"* ]]
  [[ "$output" == *"already up to date"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "a fresh tree reports the drift and points at npm ci" {
  rm -rf "${GATE_DIR}/node_modules"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not match the pin"* ]]
  [[ "$output" == *"npm --prefix"* ]]
  [[ "$output" == *" ci'"* ]]
}

@test "a fresh tree with an outdated pin offers the pin as the basis, never none" {
  rm -rf "${GATE_DIR}/node_modules"
  export LATEST_PRETTIER=4.0.0
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"↑ prettier 3.9.6 → 4.0.0"* ]]
  [[ "$output" != *"↑ prettier none"* ]]
}

@test "the npm ci hint is suppressed when the install reifies the tree anyway" {
  rm -rf "${GATE_DIR}/node_modules"
  export LATEST_STYLELINT=17.15.0
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not match the pin"* ]]
  [[ "$output" == *"commit package.json"* ]]
}

@test "--check still reports drift alongside available updates" {
  rm -rf "${GATE_DIR}/node_modules"
  export LATEST_STYLELINT=17.15.0
  run bash "$SCRIPT" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not match the pin"* ]]
  [[ "$output" == *"1 update(s) available"* ]]
}

@test "a single package absent from the tree does not bump its pin" {
  rm -rf "${GATE_DIR}/node_modules/prettier"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"= prettier 3.9.6"* ]]
  [[ "$(cat "$NPM_LOG")" != *"prettier@"* ]]
}

@test "an installed version ahead of the pin is drift, not an update" {
  _install_fixture stylelint 17.15.0
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"= stylelint 17.14.1"* ]]
  [[ "$output" == *"does not match the pin"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "a corrupt tree manifest is reported as drift, not a jq crash" {
  printf '{"version":\n' >"${GATE_DIR}/node_modules/prettier/package.json"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"= prettier 3.9.6"* ]]
  [[ "$output" == *"does not match the pin"* ]]
  [[ "$output" == *"prettier (none)"* ]]
  [[ "$output" != *"parse error"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "a tree in sync with the pin reports no drift note" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not match the pin"* ]]
}

# jq's `// empty` collapses an absent key and an empty-string value onto the
# same empty `pinned`, so only the realistic shape is covered here.
@test "a package missing from devDependencies is a hard error" {
  jq 'del(.devDependencies.prettier)' "${GATE_DIR}/package.json" >"${GATE_DIR}/pruned.json"
  mv "${GATE_DIR}/pruned.json" "${GATE_DIR}/package.json"
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"prettier is not pinned in"* ]]
  [ ! -s "$NPM_LOG" ]
}

@test "a failing npm install propagates a non-zero exit" {
  export LATEST_STYLELINT=17.15.0
  export NPM_EXIT=1
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" != *"commit package.json"* ]]
}
