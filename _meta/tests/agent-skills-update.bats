#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for bin/.local/bin/agent-skills-update

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/agent-skills-update"

# ─── stub factory ───────────────────────────────────────────────────────────
# The script runs with PATH=${STUBS}: npx is a stub that logs its argv, while
# jq and git are real, since the checks under test read a real lock file and
# a real working tree.

_stub_command() {
  local name="$1" body="${2:-exit 0}"
  rm -f "${STUBS}/${name}"
  cat >"${STUBS}/${name}" <<EOF
#!/usr/bin/env bash
${body}
EOF
  chmod +x "${STUBS}/${name}"
}

# A dotfiles-like tree: REPO/agents/.agents stowed as FAKE_HOME/.agents.
_make_layout() {
  mkdir -p "${REPO}/agents/.agents/skills" "${FAKE_HOME}/.claude/skills"
  ln -s "${REPO}/agents/.agents" "${FAKE_HOME}/.agents"
}

_init_git() {
  git -C "$REPO" init -q
}

_commit_all() {
  git -C "$REPO" add -A
  git -C "$REPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m init
}

# Installs a skill the way the skills CLI does in symlink mode.
_add_skill() {
  local name="$1"
  mkdir -p "${REPO}/agents/.agents/skills/${name}"
  printf -- '---\nname: %s\n---\n' "$name" >"${REPO}/agents/.agents/skills/${name}/SKILL.md"
  ln -s "../../.agents/skills/${name}" "${FAKE_HOME}/.claude/skills/${name}"
}

# Writes a lock listing the given names, each sourced from owner/<name> at
# skills/<name>, and the matching upstream listing the gh stub serves, so a
# skill is current unless a test rewrites its listing.
_write_lock() {
  local entries="" name
  for name in "$@"; do
    entries+="${entries:+,}\"${name}\": {\"source\": \"owner/${name}\", \"sourceType\": \"github\", \"skillPath\": \"skills/${name}/SKILL.md\", \"skillFolderHash\": \"h-${name}\"}"
    _write_upstream "$name" "h-${name}"
  done
  printf '{"version": 3, "skills": {%s}}\n' "$entries" >"${REPO}/agents/.agents/.skill-lock.json"
}

# Serves the GitHub contents listing of owner/<name>/skills with one folder.
_write_upstream() {
  local name="$1" sha="$2" folder="${3:-$1}"
  mkdir -p "${GH_FIXTURES}/repos/owner/${name}/contents"
  printf '[{"path": "skills/%s", "type": "dir", "sha": "%s"}]\n' "$folder" "$sha" \
    >"${GH_FIXTURES}/repos/owner/${name}/contents/skills.json"
}

# ─── setup / teardown ───────────────────────────────────────────────────────

setup() {
  STUBS="$(mktemp -d)"
  FAKE_HOME="$(mktemp -d)"
  REPO="$(mktemp -d)"
  NPX_LOG="${STUBS}/npx.log"
  GH_FIXTURES="$(mktemp -d)"
  export STUBS FAKE_HOME REPO NPX_LOG GH_FIXTURES
  for cmd in jq git readlink; do
    ln -s "$(command -v "$cmd")" "${STUBS}/${cmd}"
  done
  ln -s "$BASH" "${STUBS}/bash"
  _stub_command npx 'printf "%s\n" "$*" >>"$NPX_LOG"; exit "${NPX_EXIT:-0}"'
  # Serves "gh api <endpoint>" from ${GH_FIXTURES}/<endpoint>.json, 404 otherwise.
  _stub_command gh '[ "$1" = api ] || exit 2
f="${GH_FIXTURES}/$2.json"
[ -f "$f" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
cat "$f"'
  ln -s "$(command -v cat)" "${STUBS}/cat"
  _make_layout
}

_run() {
  run env PATH="$STUBS" HOME="$FAKE_HOME" NPX_LOG="$NPX_LOG" NPX_EXIT="${NPX_EXIT:-0}" \
    GH_FIXTURES="$GH_FIXTURES" "$BASH" "$SCRIPT"
}

teardown() {
  rm -rf "$STUBS" "$FAKE_HOME" "$REPO" "$GH_FIXTURES"
}

# ─── dependency guards ──────────────────────────────────────────────────────

@test "missing npx: exits 1 with message" {
  rm "${STUBS}/npx"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"npx is required"* ]]
}

@test "missing jq: exits 1 with message" {
  rm "${STUBS}/jq"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required"* ]]
}

@test "missing gh: exits 1 with message" {
  rm "${STUBS}/gh"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh is required"* ]]
}

@test "missing git: exits 1 with message" {
  rm "${STUBS}/git"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"git is required"* ]]
}

# ─── skip conditions ────────────────────────────────────────────────────────

@test "no lock file: exits 0 without calling npx" {
  _init_git
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"nothing to update"* ]]
  [ ! -f "$NPX_LOG" ]
}

@test "skills dir outside a git working tree: skips without calling npx" {
  _add_skill alpha
  _write_lock alpha
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipped:"*"not inside a git working tree"* ]]
  [ ! -f "$NPX_LOG" ]
}

# ─── update ─────────────────────────────────────────────────────────────────

@test "healthy layout: runs a global non-interactive update and exits 0" {
  _init_git
  _add_skill alpha
  _add_skill beta
  _write_lock alpha beta
  _commit_all
  _run
  [ "$status" -eq 0 ]
  [ "$(cat "$NPX_LOG")" = "-y skills update -g -y" ]
  [[ "$output" != *"repair:"* ]]
  [[ "$output" != *"Changes to review"* ]]
}

@test "npx failure: layout is still checked, exits 1" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  _commit_all
  NPX_EXIT=1 _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"skills update failed"* ]]
  [[ "$output" == *"Checking installed layout"* ]]
}

@test "unreadable lock: exits 1 with message" {
  _init_git
  printf 'not json\n' >"${REPO}/agents/.agents/.skill-lock.json"
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read the skill list"* ]]
}

@test "empty lock: exits 0 with nothing to check" {
  _init_git
  _write_lock
  _commit_all
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"repair:"* ]]
}

# ─── layout check ───────────────────────────────────────────────────────────

@test "skill copied into ~/.claude/skills instead of linked: exits 1 with repair" {
  _init_git
  _add_skill alpha
  rm "${FAKE_HOME}/.claude/skills/alpha"
  mkdir "${FAKE_HOME}/.claude/skills/alpha"
  _write_lock alpha
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha: ${FAKE_HOME}/.claude/skills/alpha is not a symlink"* ]]
  [[ "$output" == *"repair: npx -y skills remove alpha -g -y && npx -y skills add owner/alpha -g -s alpha -a claude-code cline -y"* ]]
}

@test "link missing from ~/.claude/skills: exits 1" {
  _init_git
  _add_skill alpha
  rm "${FAKE_HOME}/.claude/skills/alpha"
  _write_lock alpha
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha:"*"is not a symlink"* ]]
}

@test "link resolving elsewhere: exits 1" {
  _init_git
  _add_skill alpha
  mkdir "${FAKE_HOME}/elsewhere"
  rm "${FAKE_HOME}/.claude/skills/alpha"
  ln -s "${FAKE_HOME}/elsewhere" "${FAKE_HOME}/.claude/skills/alpha"
  _write_lock alpha
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha:"*"does not resolve to"* ]]
}

@test "lock entry without a skill directory: exits 1" {
  _init_git
  _write_lock ghost
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"ghost: missing from ${FAKE_HOME}/.agents/skills"* ]]
}

@test "only the broken skill is reported among several" {
  _init_git
  _add_skill alpha
  _add_skill beta
  rm "${FAKE_HOME}/.claude/skills/beta"
  _write_lock alpha beta
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"beta:"* ]]
  [[ "$output" != *"alpha:"* ]]
}

@test "skills outside the lock are not checked" {
  _init_git
  _add_skill alpha
  mkdir "${FAKE_HOME}/.claude/skills/local-copy"
  _write_lock alpha
  _commit_all
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"local-copy"* ]]
}

# ─── freshness check ────────────────────────────────────────────────────────
# The skills CLI can skip a skill and still exit 0 ("All global skills are up
# to date"), as it did on 2026-09-18 when tw93/Waza duplicated its skill
# folders, so currency is checked against upstream rather than trusted.

@test "skill left behind upstream by a zero-exit update: exits 1" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  _write_upstream alpha h-newer
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha: not current with owner/alpha (skills/alpha)"* ]]
}

@test "skill folder gone upstream: exits 1" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  _write_upstream alpha h-other renamed
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha: skills/alpha no longer exists in owner/alpha"* ]]
}

@test "upstream unreachable: exits 1" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  rm -r "${GH_FIXTURES}/repos/owner/alpha"
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha: could not query owner/alpha"* ]]
}

@test "a pinned ref is queried at that ref, not the default branch" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  jq '.skills.alpha.ref = "v1"' "${REPO}/agents/.agents/.skill-lock.json" >"${REPO}/lock.tmp"
  mv "${REPO}/lock.tmp" "${REPO}/agents/.agents/.skill-lock.json"
  _write_upstream alpha h-newer
  printf '[{"path": "skills/alpha", "type": "dir", "sha": "h-alpha"}]\n' \
    >"${GH_FIXTURES}/repos/owner/alpha/contents/skills?ref=v1.json"
  _commit_all
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"not current"* ]]
}

@test "a non-GitHub source is noted, not failed" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  jq '.skills.alpha.sourceType = "local"' "${REPO}/agents/.agents/.skill-lock.json" >"${REPO}/lock.tmp"
  mv "${REPO}/lock.tmp" "${REPO}/agents/.agents/.skill-lock.json"
  _commit_all
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"alpha: currency not checkable (source type 'local'"* ]]
}

@test "only the stale skill is reported among several" {
  _init_git
  _add_skill alpha
  _add_skill beta
  _write_lock alpha beta
  _write_upstream beta h-newer
  _commit_all
  _run
  [ "$status" -eq 1 ]
  [[ "$output" == *"beta: not current"* ]]
  [[ "$output" != *"alpha: not current"* ]]
}

# ─── review output ──────────────────────────────────────────────────────────

@test "files rewritten by the update are listed for review" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  _commit_all
  _stub_command npx 'printf "changed\n" >>"$HOME/.agents/skills/alpha/SKILL.md"'
  _run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Changes to review"* ]]
  [[ "$output" == *"skills/alpha/SKILL.md"* ]]
}

@test "changes outside the agents package are not listed" {
  _init_git
  _add_skill alpha
  _write_lock alpha
  printf 'x\n' >"${REPO}/outside.txt"
  _commit_all
  printf 'y\n' >>"${REPO}/outside.txt"
  _run
  [ "$status" -eq 0 ]
  [[ "$output" != *"Changes to review"* ]]
}
