#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2016
# Tests for opencode/.config/opencode/plugins/claude-hooks.ts

bats_require_minimum_version 1.5.0

PLUGIN="${BATS_TEST_DIRNAME}/../../opencode/.config/opencode/plugins/claude-hooks.ts"

setup() {
  command -v node >/dev/null || skip "node is required"
  export HOME="${BATS_TEST_TMPDIR}/home"
  HOOKS="${HOME}/.claude/hooks"
  PROJECT="${BATS_TEST_TMPDIR}/project"
  mkdir -p "$HOOKS" "$PROJECT"
  _hook prose-lint-pretool.sh 'exit 0'
  _hook format-on-edit.sh 'exit 0'
  cat >"${BATS_TEST_TMPDIR}/driver.mjs" <<'EOF'
const [plugin, phase, tool, argsJson, directory] = process.argv.slice(2)
const { ClaudeHooks } = await import(plugin)
const hooks = await ClaudeHooks({ directory })
const args = JSON.parse(argsJson)
try {
  if (phase === "system") {
    // opencode reads back its own array after the hook, so only in-place changes count.
    const system = [args.system]
    await hooks["experimental.chat.system.transform"]({ sessionID: "s" }, { system })
    process.stdout.write(JSON.stringify(system))
  } else if (phase === "before") {
    await hooks["tool.execute.before"]({ tool, sessionID: "s", callID: "c" }, { args })
    console.log("ALLOWED")
  } else {
    const output = { title: "t", output: "TOOL-OUTPUT", metadata: {} }
    await hooks["tool.execute.after"]({ tool, sessionID: "s", callID: "c", args }, output)
    console.log(output.output)
  }
} catch (e) {
  console.log(`THROWN: ${e.message}`)
}
EOF
}

# Writes a stub hook that saves its stdin and working directory, then runs $2.
_hook() {
  cat >"${HOOKS}/$1" <<EOF
#!/usr/bin/env bash
cat >"${BATS_TEST_TMPDIR}/$1.stdin"
pwd >"${BATS_TEST_TMPDIR}/$1.cwd"
$2
EOF
}

_drive() {
  run node "${BATS_TEST_TMPDIR}/driver.mjs" "$PLUGIN" "$1" "$2" "$3" "$PROJECT"
}

@test "before: a write reaches prose-lint-pretool.sh as a Claude Code payload" {
  _drive before write '{"filePath": "/abs/doc.md", "content": "text"}'
  [ "$status" -eq 0 ]
  [ "$output" = "ALLOWED" ]
  run jq -c '.tool_input' "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin"
  [ "$output" = '{"file_path":"/abs/doc.md","content":"text"}' ]
}

@test "before: an edit maps oldString, newString and replaceAll" {
  _drive before edit '{"filePath": "/abs/doc.md", "oldString": "a", "newString": "b", "replaceAll": true}'
  [ "$output" = "ALLOWED" ]
  run jq -c '.tool_input' "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin"
  [ "$output" = '{"file_path":"/abs/doc.md","old_string":"a","new_string":"b","replace_all":true}' ]
}

@test "before: an edit creating a missing file reaches the hook as a write" {
  _drive before edit "{\"filePath\": \"${PROJECT}/new.md\", \"oldString\": \"\", \"newString\": \"body\"}"
  [ "$output" = "ALLOWED" ]
  run jq -c '.tool_input' "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin"
  [ "$output" = "{\"file_path\":\"${PROJECT}/new.md\",\"content\":\"body\"}" ]
}

@test "before: an empty oldString on an existing file keeps the edit shape" {
  printf 'old\n' >"${PROJECT}/doc.md"
  _drive before edit "{\"filePath\": \"${PROJECT}/doc.md\", \"oldString\": \"\", \"newString\": \"body\"}"
  run jq -c '.tool_input' "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin"
  [ "$output" = "{\"file_path\":\"${PROJECT}/doc.md\",\"old_string\":\"\",\"new_string\":\"body\"}" ]
}

@test "before: a prose edit whose oldString is not verbatim in the file is refused" {
  printf 'one  two\n' >"${PROJECT}/doc.md"
  _drive before edit "{\"filePath\": \"${PROJECT}/doc.md\", \"oldString\": \"one two\", \"newString\": \"x\"}"
  [[ "$output" == "THROWN: oldString does not occur verbatim"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin" ]
}

@test "before: a prose edit with a verbatim oldString reaches the hook" {
  printf 'one  two\n' >"${PROJECT}/doc.md"
  _drive before edit "{\"filePath\": \"${PROJECT}/doc.md\", \"oldString\": \"one  two\", \"newString\": \"x\"}"
  [ "$output" = "ALLOWED" ]
}

@test "before: the verbatim oldString check covers .qmd files" {
  printf 'one  two\n' >"${PROJECT}/doc.qmd"
  _drive before edit "{\"filePath\": \"${PROJECT}/doc.qmd\", \"oldString\": \"one two\", \"newString\": \"x\"}"
  [[ "$output" == "THROWN: oldString does not occur verbatim"* ]]
}

@test "before: a non-prose edit is not held to a verbatim oldString" {
  printf 'one  two\n' >"${PROJECT}/x.R"
  _drive before edit "{\"filePath\": \"${PROJECT}/x.R\", \"oldString\": \"one two\", \"newString\": \"x\"}"
  [ "$output" = "ALLOWED" ]
}

@test "before: a relative path is resolved against the project directory" {
  _drive before write '{"filePath": "docs/doc.md", "content": "x"}'
  run jq -r '.tool_input.file_path' "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin"
  [ "$output" = "${PROJECT}/docs/doc.md" ]
}

@test "before: the hook runs in the project directory" {
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$(cat "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.cwd")" = "$PROJECT" ]
}

@test "before: exit 2 blocks the edit with the hook's stderr" {
  _hook prose-lint-pretool.sh 'echo "em dash on line 3" >&2; exit 2'
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$output" = "THROWN: em dash on line 3" ]
}

@test "before: exit 2 without stderr still blocks, with a default message" {
  _hook prose-lint-pretool.sh 'exit 2'
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$output" = "THROWN: prose-lint-pretool.sh blocked this edit" ]
}

@test "before: any other failure stays advisory" {
  _hook prose-lint-pretool.sh 'echo boom >&2; exit 1'
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$output" = "ALLOWED" ]
}

@test "before: a missing hook script does not block" {
  rm "${HOOKS}/prose-lint-pretool.sh"
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$output" = "ALLOWED" ]
}

@test "before: a hook that exits without reading stdin does not crash" {
  printf '#!/usr/bin/env bash\nexit 0\n' >"${HOOKS}/prose-lint-pretool.sh"
  _drive before write "{\"filePath\": \"/abs/doc.md\", \"content\": \"$(head -c 100000 /dev/zero | tr '\0' x)\"}"
  [ "$status" -eq 0 ]
  [ "$output" = "ALLOWED" ]
}

@test "before: a hook whose child keeps the pipes open is killed at the timeout" {
  _hook prose-lint-pretool.sh 'sleep 30 & exit 0'
  export CLAUDE_HOOKS_TIMEOUT_MS=500
  local start=$SECONDS
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$output" = "ALLOWED" ]
  [ $((SECONDS - start)) -lt 10 ]
}

@test "before: tools other than edit and write run no hook" {
  _drive before bash '{"command": "ls"}'
  [ "$output" = "ALLOWED" ]
  [ ! -e "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin" ]
}

@test "guard: a write under ~/.claude is refused before any hook runs" {
  mkdir -p "${HOME}/.claude"
  _drive before write "{\"filePath\": \"${HOME}/.claude/probe.md\", \"content\": \"x\"}"
  [[ "$output" == "THROWN: "*"must not modify"* ]]
  [ ! -e "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin" ]
}

@test "guard: a write creating ~/.claude itself is refused" {
  _drive before write "{\"filePath\": \"${HOME}/.claude/rules/new.md\", \"content\": \"x\"}"
  [[ "$output" == "THROWN: "*"must not modify"* ]]
}

@test "guard: an edit under ~/dotfiles/claude/.claude is refused" {
  mkdir -p "${HOME}/dotfiles/claude/.claude"
  _drive before edit "{\"filePath\": \"${HOME}/dotfiles/claude/.claude/CLAUDE.md\", \"oldString\": \"a\", \"newString\": \"b\"}"
  [[ "$output" == "THROWN: "*"must not modify"* ]]
}

@test "guard: a relative path climbing into ~/.claude is refused" {
  mkdir -p "${HOME}/.claude"
  _drive before write "{\"filePath\": \"../home/.claude/x.md\", \"content\": \"x\"}"
  [[ "$output" == "THROWN: "*"must not modify"* ]]
}

@test "guard: a symlink resolving under the profile is refused" {
  mkdir -p "${HOME}/dotfiles/claude/.claude/rules"
  ln -s "${HOME}/dotfiles/claude/.claude/rules" "${PROJECT}/rules"
  _drive before write "{\"filePath\": \"${PROJECT}/rules/new.md\", \"content\": \"x\"}"
  [[ "$output" == "THROWN: "*"must not modify"* ]]
}

@test "guard: a project's own .claude directory stays writable" {
  mkdir -p "${HOME}/.claude" "${PROJECT}/.claude"
  _drive before write "{\"filePath\": \"${PROJECT}/.claude/PLAN.md\", \"content\": \"x\"}"
  [ "$output" = "ALLOWED" ]
}

@test "guard: a sibling whose name only starts like the profile stays writable" {
  mkdir -p "${HOME}/.claude" "${HOME}/.claude-notes"
  _drive before write "{\"filePath\": \"${HOME}/.claude-notes/a.md\", \"content\": \"x\"}"
  [ "$output" = "ALLOWED" ]
}

# Builds a system prompt the way opencode joins it: header, one block per
# instruction file ("Instructions from: <path>\n<content>"), then the skills text.
_system_with() {
  local parts=("HEADER") f content
  for f in "$@"; do
    content=$(
      cat "$f"
      printf x
    )
    parts+=("Instructions from: ${f}"$'\n'"${content%x}")
  done
  parts+=("Skills provide specialized instructions.")
  local IFS=$'\n'
  jq -n --arg s "${parts[*]}" '{system: $s}'
}

_profile_files() {
  mkdir -p "${HOME}/.claude/memory" "${PROJECT}/.claude"
  printf 'GLOBAL RULES\nline two\n' >"${HOME}/.claude/CLAUDE.md"
  printf 'GLOBAL MEMORY\n' >"${HOME}/.claude/memory/MEMORY.md"
  printf 'PROJECT RULES\n' >"${PROJECT}/.claude/CLAUDE.md"
}

@test "system: the global profile blocks are removed, the rest kept in order" {
  _profile_files
  _drive system - "$(_system_with "${HOME}/.claude/CLAUDE.md" "${PROJECT}/.claude/CLAUDE.md" "${HOME}/.claude/memory/MEMORY.md")"
  [ "$status" -eq 0 ]
  run jq -r '.[0]' <<<"$output"
  [[ "$output" != *"GLOBAL"* ]]
  [[ "$output" == "HEADER"$'\n'"Instructions from: ${PROJECT}/.claude/CLAUDE.md"$'\n'"PROJECT RULES"$'\n\n'"Skills provide specialized instructions." ]]
}

@test "system: the profile's dotfiles source is removed too" {
  mkdir -p "${HOME}/dotfiles/claude/.claude/memory"
  printf 'GLOBAL RULES\n' >"${HOME}/dotfiles/claude/.claude/CLAUDE.md"
  printf 'GLOBAL MEMORY\n' >"${HOME}/dotfiles/claude/.claude/memory/MEMORY.md"
  _drive system - "$(_system_with "${HOME}/dotfiles/claude/.claude/CLAUDE.md" "${HOME}/dotfiles/claude/.claude/memory/MEMORY.md")"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0]' <<<"$output")" = "HEADER"$'\n'"Skills provide specialized instructions." ]
}

@test "system: a prompt without the profile passes unchanged" {
  _profile_files
  input=$(_system_with "${PROJECT}/.claude/CLAUDE.md")
  _drive system - "$input"
  [ "$(jq -r '.[0]' <<<"$output")" = "$(jq -r '.system' <<<"$input")" ]
}

@test "system: a block whose content no longer matches the file is kept" {
  _profile_files
  input=$(_system_with "${HOME}/.claude/CLAUDE.md")
  printf 'GLOBAL RULES EDITED\n' >"${HOME}/.claude/CLAUDE.md"
  _drive system - "$input"
  [ "$(jq -r '.[0]' <<<"$output")" = "$(jq -r '.system' <<<"$input")" ]
}

@test "system: a missing profile file changes nothing" {
  mkdir -p "${PROJECT}/.claude"
  printf 'PROJECT RULES\n' >"${PROJECT}/.claude/CLAUDE.md"
  input=$(_system_with "${PROJECT}/.claude/CLAUDE.md")
  _drive system - "$input"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[0]' <<<"$output")" = "$(jq -r '.system' <<<"$input")" ]
}

@test "after: format-on-edit.sh runs in the project directory with the payload" {
  _drive after edit '{"filePath": "/abs/x.R", "oldString": "a", "newString": "b"}'
  [ "$status" -eq 0 ]
  [ "$(cat "${BATS_TEST_TMPDIR}/format-on-edit.sh.cwd")" = "$PROJECT" ]
  run jq -r '.tool_input.file_path' "${BATS_TEST_TMPDIR}/format-on-edit.sh.stdin"
  [ "$output" = "/abs/x.R" ]
}

@test "after: a silent hook leaves the tool output untouched" {
  _drive after write '{"filePath": "/abs/x.R", "content": "x"}'
  [ "$output" = "TOOL-OUTPUT" ]
}

@test "after: the hook's report is appended to the tool output" {
  _hook format-on-edit.sh 'echo "jarl: 1 violation"'
  _drive after write '{"filePath": "/abs/x.R", "content": "x"}'
  [ "${lines[0]}" = "TOOL-OUTPUT" ]
  [[ "$output" == *"format-on-edit.sh:"*"jarl: 1 violation"* ]]
}

@test "after: a failing hook reports its stderr without throwing" {
  _hook format-on-edit.sh 'echo "air: parse error" >&2; exit 1'
  _drive after write '{"filePath": "/abs/x.R", "content": "x"}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "TOOL-OUTPUT" ]
  [[ "$output" == *"format-on-edit.sh:"*"air: parse error"* ]]
  [[ "$output" != *"THROWN"* ]]
}

@test "after: tools other than edit and write run no hook" {
  _drive after read '{"filePath": "/abs/x.R"}'
  [ "$output" = "TOOL-OUTPUT" ]
  [ ! -e "${BATS_TEST_TMPDIR}/format-on-edit.sh.stdin" ]
}
