#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/opencode-skills-sync

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/opencode-skills-sync"

setup() {
  export HOME="${BATS_TEST_TMPDIR}/home"
  export XDG_DATA_HOME="${HOME}/.local/share"
  FARM="${XDG_DATA_HOME}/opencode-claude-skills"
  CACHE="${HOME}/.claude/plugins/cache"
  mkdir -p "${HOME}/.claude/plugins"
  printf '{"version": 2, "plugins": {}}\n' >"${HOME}/.claude/plugins/installed_plugins.json"
  printf '{"enabledPlugins": {}}\n' >"${HOME}/.claude/settings.json"
}

# Registers plugin $1 of marketplace $2 as installed at $3, enabled unless $4 is false.
_install() {
  local key="$1@$2" path="$3" on="${4:-true}" f
  f="${HOME}/.claude/plugins/installed_plugins.json"
  jq --arg k "$key" --arg p "$path" '.plugins[$k] = [{"scope": "user", "installPath": $p}]' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
  f="${HOME}/.claude/settings.json"
  jq --arg k "$key" --argjson v "$on" '.enabledPlugins[$k] = $v' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
}

_skill() {
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: d\n---\n' "$(basename "$1")" >"$1/SKILL.md"
}

# A shared repository whose marketplace manifest assigns skills to two plugins.
_shared_repo() {
  local root="$1"
  _skill "${root}/one/alpha"
  _skill "${root}/one/beta"
  _skill "${root}/two/gamma"
  _skill "${root}/shared"
  mkdir -p "${root}/.claude-plugin"
  cat >"${root}/.claude-plugin/marketplace.json" <<'EOF'
{"plugins": [
  {"name": "one", "source": "./", "skills": ["./one/alpha", "./shared"]},
  {"name": "two", "source": "./", "skills": ["./two/gamma"]}
]}
EOF
}

@test "links exactly the skills a marketplace entry lists" {
  _shared_repo "${CACHE}/m/one/h1"
  _install one m "${CACHE}/m/one/h1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${FARM}/one/alpha/SKILL.md" ]
  [ -f "${FARM}/one/shared/SKILL.md" ]
  [ ! -e "${FARM}/one/beta" ]
  [ ! -e "${FARM}/two" ]
  [ "$(readlink "${FARM}/one/alpha")" = "${CACHE}/m/one/h1/one/alpha" ]
}

@test "splits a shared repository between the plugins it hosts" {
  _shared_repo "${CACHE}/m/one/h1"
  _shared_repo "${CACHE}/m/two/h1"
  _install one m "${CACHE}/m/one/h1"
  _install two m "${CACHE}/m/two/h1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${FARM}/one/alpha/SKILL.md" ]
  [ -f "${FARM}/one/shared/SKILL.md" ]
  [ ! -e "${FARM}/one/gamma" ]
  [ -f "${FARM}/two/gamma/SKILL.md" ]
  [ ! -e "${FARM}/two/alpha" ]
  [ ! -e "${FARM}/two/shared" ]
  [[ "$output" == *"Linked 3 plugin skill(s)"* ]]
}

@test "accepts a single skill path given as a string" {
  _skill "${CACHE}/m/p/1/x/only"
  _skill "${CACHE}/m/p/1/skills/ignored"
  mkdir -p "${CACHE}/m/p/1/.claude-plugin"
  printf '{"plugins": [{"name": "p", "skills": "./x/only"}]}\n' >"${CACHE}/m/p/1/.claude-plugin/marketplace.json"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${FARM}/p/only/SKILL.md" ]
  [ ! -e "${FARM}/p/ignored" ]
}

@test "ignores an enabled plugin that is not installed" {
  jq '.enabledPlugins["ghost@m"] = true' "${HOME}/.claude/settings.json" >"${HOME}/s.tmp"
  mv "${HOME}/s.tmp" "${HOME}/.claude/settings.json"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "${FARM}/ghost" ]
}

@test "skips disabled plugins and plugins absent from enabledPlugins" {
  _skill "${CACHE}/m/off/1/skills/s1"
  _install off m "${CACHE}/m/off/1" false
  _skill "${CACHE}/m/gone/1/skills/s2"
  _install gone m "${CACHE}/m/gone/1"
  jq 'del(.enabledPlugins["gone@m"])' "${HOME}/.claude/settings.json" >"${HOME}/s.tmp"
  mv "${HOME}/s.tmp" "${HOME}/.claude/settings.json"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "${FARM}/off" ]
  [ ! -e "${FARM}/gone" ]
  [[ "$output" == *"Linked 0 plugin skill(s)"* ]]
}

@test "falls back to the skills directory without a marketplace entry" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _skill "${CACHE}/m/p/1/skills/s2"
  mkdir -p "${CACHE}/m/p/1/skills/not-a-skill"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${FARM}/p/s1/SKILL.md" ]
  [ -f "${FARM}/p/s2/SKILL.md" ]
  [ ! -e "${FARM}/p/not-a-skill" ]
}

@test "falls back when the marketplace manifest has no skills for the plugin" {
  _skill "${CACHE}/m/p/1/skills/s1"
  mkdir -p "${CACHE}/m/p/1/.claude-plugin"
  printf '{"plugins": [{"name": "p", "source": "./"}]}\n' >"${CACHE}/m/p/1/.claude-plugin/marketplace.json"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${FARM}/p/s1/SKILL.md" ]
}

@test "adds the skill paths plugin.json declares, without duplicates" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _skill "${CACHE}/m/p/1/extra/s2"
  mkdir -p "${CACHE}/m/p/1/.claude-plugin"
  printf '{"name": "p", "skills": ["./extra/", "./skills"]}\n' >"${CACHE}/m/p/1/.claude-plugin/plugin.json"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "${FARM}/p/s1/SKILL.md" ]
  [ -f "${FARM}/p/s2/SKILL.md" ]
  [[ "$output" == *"p@m: 2 skill(s)"* ]]
}

@test "accepts a plugin that ships no skill" {
  mkdir -p "${CACHE}/m/lsp/1"
  _install lsp m "${CACHE}/m/lsp/1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "${FARM}/lsp" ]
}

@test "succeeds with no plugin installed" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -d "$FARM" ]
  [[ "$output" == *"Linked 0 plugin skill(s)"* ]]
}

@test "a rerun drops the links of a plugin disabled since" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ -e "${FARM}/p/s1" ]
  _install p m "${CACHE}/m/p/1" false
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "${FARM}/p" ]
}

@test "a rerun follows a plugin to its new install path" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  _skill "${CACHE}/m/p/2/skills/s1"
  _install p m "${CACHE}/m/p/2"
  rm -rf "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "${FARM}/p/s1")" = "${CACHE}/m/p/2/skills/s1" ]
}

@test "fails when installed_plugins.json is missing" {
  rm "${HOME}/.claude/plugins/installed_plugins.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"installed_plugins.json not found"* ]]
}

@test "fails when settings.json is missing" {
  rm "${HOME}/.claude/settings.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"settings.json not found"* ]]
}

@test "fails on an unexpected installed_plugins.json shape and keeps the last farm" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  printf '{"version": 3, "installs": []}\n' >"${HOME}/.claude/plugins/installed_plugins.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unexpected shape"* ]]
  [ -f "${FARM}/p/s1/SKILL.md" ]
}

@test "fails on an installed_plugins.json that is not valid JSON" {
  printf '{"plugins": \n' >"${HOME}/.claude/plugins/installed_plugins.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unexpected shape"* ]]
}

@test "fails on an unreadable marketplace manifest and keeps the last farm" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  mkdir -p "${CACHE}/m/p/1/.claude-plugin"
  printf '{"plugins": [\n' >"${CACHE}/m/p/1/.claude-plugin/marketplace.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot read"*"marketplace.json"* ]]
  [ -f "${FARM}/p/s1/SKILL.md" ]
  run bash -c "ls -A '${XDG_DATA_HOME}'"
  [ "$output" = "opencode-claude-skills" ]
}

@test "fails on an unreadable plugin.json" {
  _skill "${CACHE}/m/p/1/skills/s1"
  mkdir -p "${CACHE}/m/p/1/.claude-plugin"
  printf '{"skills": \n' >"${CACHE}/m/p/1/.claude-plugin/plugin.json"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot read"*"plugin.json"* ]]
}

@test "fails on a plugin entry without installPath" {
  printf '{"plugins": {"p@m": [{"scope": "user"}]}}\n' >"${HOME}/.claude/plugins/installed_plugins.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no installPath for p@m"* ]]
}

@test "fails on an unexpected settings.json shape" {
  printf '{"permissions": {}}\n' >"${HOME}/.claude/settings.json"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unexpected shape"* ]]
}

@test "fails when an enabled plugin's install path is gone and keeps the last farm" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  _install p m "${CACHE}/m/p/9"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"install path"*"is missing"* ]]
  [ "$(readlink "${FARM}/p/s1")" = "${CACHE}/m/p/1/skills/s1" ]
}

@test "fails when a listed skill has no SKILL.md" {
  _shared_repo "${CACHE}/m/one/h1"
  rm "${CACHE}/m/one/h1/one/alpha/SKILL.md"
  _install one m "${CACHE}/m/one/h1"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no SKILL.md"* ]]
}

@test "fails when two skills of one plugin share a directory name" {
  _shared_repo "${CACHE}/m/one/h1"
  _skill "${CACHE}/m/one/h1/other/alpha"
  jq '.plugins[0].skills += ["./other/alpha"]' "${CACHE}/m/one/h1/.claude-plugin/marketplace.json" >"${HOME}/m.tmp"
  mv "${HOME}/m.tmp" "${CACHE}/m/one/h1/.claude-plugin/marketplace.json"
  _install one m "${CACHE}/m/one/h1"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha collides with ${CACHE}/m/one/h1/one/alpha"* ]]
}

@test "fails when two marketplaces ship the same skill under one plugin name" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _skill "${CACHE}/n/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  _install p n "${CACHE}/n/p/1"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"p@n: s1 collides with ${CACHE}/m/p/1/skills/s1"* ]]
}

@test "leaves no staging directory behind" {
  _skill "${CACHE}/m/p/1/skills/s1"
  _install p m "${CACHE}/m/p/1"
  run "$SCRIPT"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  run bash -c "ls -A '${XDG_DATA_HOME}'"
  [ "$output" = "opencode-claude-skills" ]
}

@test "leaves no staging directory behind after a failure" {
  _install p m "${CACHE}/m/p/missing"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  run bash -c "ls -A '${XDG_DATA_HOME}'"
  [ "$output" = "" ]
}
