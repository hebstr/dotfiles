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
  if (phase === "before") {
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

@test "before: a relative path is resolved against the project directory" {
  _drive before write '{"filePath": "docs/doc.md", "content": "x"}'
  run jq -r '.tool_input.file_path' "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin"
  [ "$output" = "${PROJECT}/docs/doc.md" ]
}

@test "before: exit 2 blocks the edit with the hook's stderr" {
  _hook prose-lint-pretool.sh 'echo "em dash on line 3" >&2; exit 2'
  _drive before write '{"filePath": "/abs/doc.md", "content": "x"}'
  [ "$output" = "THROWN: em dash on line 3" ]
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

@test "before: tools other than edit and write run no hook" {
  _drive before bash '{"command": "ls"}'
  [ "$output" = "ALLOWED" ]
  [ ! -e "${BATS_TEST_TMPDIR}/prose-lint-pretool.sh.stdin" ]
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

@test "after: tools other than edit and write run no hook" {
  _drive after read '{"filePath": "/abs/x.R"}'
  [ "$output" = "TOOL-OUTPUT" ]
  [ ! -e "${BATS_TEST_TMPDIR}/format-on-edit.sh.stdin" ]
}
