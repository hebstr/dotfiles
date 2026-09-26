#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/inject-rules.sh"

setup() {
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RULES="$WORK/rules"
  RUNTIME="$WORK/runtime"
  STATE="$WORK/state"
  export WORK STUB_DIR RULES RUNTIME STATE

  mkdir -p "$STUB_DIR" "$RULES" "$RUNTIME" "$STATE"
  for cmd in cat jq awk grep date mkdir; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
  for name in pdf docx secrets showboat install chromium agents memory claude-files; do
    printf -- '---\npaths:\n  - "**/*.%s-probe"\n---\n\nBODY-%s\n' "$name" "$name" >"$RULES/$name.md"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_hook() {
  local payload=$1
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" HOME="$WORK" CLAUDE_RULES_DIR="$RULES" \
    XDG_RUNTIME_DIR="$RUNTIME" XDG_STATE_HOME="$STATE" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

read_call() {
  jq -nc --arg t "$1" --arg f "$2" '{session_id: "s1", tool_name: $t, tool_input: {file_path: $f}}'
}

bash_call() {
  jq -nc --arg c "$1" '{session_id: "s1", tool_name: "Bash", tool_input: {command: $c}}'
}

field() {
  printf '%s' "$output" | jq -r ".hookSpecificOutput.$1 // \"\""
}

@test "stays silent on an unrelated call" {
  run_hook "$(bash_call 'ls -la')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "denies the first native Read of a PDF and injects pdf.md" {
  run_hook "$(read_call Read "$WORK/a.pdf")"
  [ "$status" -eq 0 ]
  [ "$(field permissionDecision)" = deny ]
  [[ $(field permissionDecisionReason) == *detect-pdf* ]]
  [[ $(field additionalContext) == *BODY-pdf* ]]
}

@test "lets a later native Read of a PDF through once pdf.md is injected" {
  run_hook "$(read_call Read "$WORK/a.pdf")"
  run_hook "$(read_call Read "$WORK/b.PDF")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "injects pdf.md without a decision on a poppler command" {
  run_hook "$(bash_call 'pdftotext -layout report.pdf -')"
  [ -z "$(field permissionDecision)" ]
  [[ $(field additionalContext) == *BODY-pdf* ]]
  run_hook "$(read_call Read "$WORK/report.pdf")"
  [ -z "$output" ]
}

@test "strips the frontmatter from the injected text" {
  run_hook "$(bash_call 'detect-pdf x.pdf --analyze --json')"
  [[ $(field additionalContext) != *paths:* ]]
  [[ $(field additionalContext) == *'rules/pdf.md, injected by inject-rules.sh'* ]]
}

@test "asks on a Read of a secret file, every time, with secrets.md injected once" {
  run_hook "$(read_call Read "$WORK/project/.env")"
  [ "$(field permissionDecision)" = ask ]
  [[ $(field additionalContext) == *BODY-secrets* ]]
  run_hook "$(read_call Read "$WORK/project/.env")"
  [ "$(field permissionDecision)" = ask ]
  [ -z "$(field additionalContext)" ]
}

@test "asks on a Bash command naming a secret file" {
  run_hook "$(bash_call "sed -E 's/=.*\$/=***/' .env")"
  [ "$(field permissionDecision)" = ask ]
  [[ $(field permissionDecisionReason) == *.env* ]]
}

@test "matches each secret pattern" {
  for p in .env.local .envrc .secrets .pgpass .netrc credentials.toml server.pem tls.key cert.pfx id_rsa.pub id_ed25519 conf/my-secret.yml db_password.txt api_key.json gh-token.txt; do
    rm -f "$RUNTIME"/claude-code-rules-*
    run_hook "$(read_call Read "$WORK/$p")"
    [ "$(field permissionDecision)" = ask ] || {
      echo "not matched: $p"
      return 1
    }
  done
}

@test "leaves template variants, source files named token and the rules themselves alone" {
  for p in .env.example config.template creds.sample src/tokenizer.py notes/token.md; do
    run_hook "$(read_call Read "$WORK/$p")"
    [ -z "$output" ] || {
      echo "matched: $p"
      return 1
    }
  done
  run_hook "$(read_call Read "$RULES/secrets.md")"
  [ -z "$output" ]
  run_hook "$(bash_call 'rg -n patterns claude/.claude/rules/secrets.md ~/.claude/rules/secrets.md')"
  [ -z "$output" ]
}

@test "denies a memory write under the harness path and injects memory.md" {
  run_hook "$(read_call Write "$WORK/.claude/projects/-x/memory/feedback_a.md")"
  [ "$(field permissionDecision)" = deny ]
  [[ $(field permissionDecisionReason) == *'~/.claude/memory/'* ]]
  [[ $(field additionalContext) == *BODY-memory* ]]
}

@test "injects memory.md without a decision on a write to the canonical store" {
  run_hook "$(read_call Edit "$WORK/.claude/memory/MEMORY.md")"
  [ -z "$(field permissionDecision)" ]
  [[ $(field additionalContext) == *BODY-memory* ]]
}

@test "injects claude-files.md on a write to a file meant for Claude" {
  for p in project/.claude/PLAN.md project/.claude/notes/DESIGN-X.md project/CLAUDE.md opencode/AGENTS.md; do
    rm -f "$RUNTIME"/claude-code-rules-*
    run_hook "$(read_call Edit "$WORK/$p")"
    [[ $(field additionalContext) == *BODY-claude-files* ]] || {
      echo "missed: $p"
      return 1
    }
  done
  rm -f "$RUNTIME"/claude-code-rules-*
  run_hook "$(read_call Edit "$WORK/project/README.md")"
  [ -z "$output" ]
}

@test "injects memory.md and claude-files.md together on a memory write" {
  run_hook "$(read_call Write "$WORK/.claude/memory/feedback_x.md")"
  [[ $(field additionalContext) == *BODY-memory*BODY-claude-files* ]]
}

@test "injects agents.md on the first Agent call only" {
  run_hook "$(jq -nc '{session_id: "s1", tool_name: "Agent", tool_input: {prompt: "x"}}')"
  [[ $(field additionalContext) == *BODY-agents* ]]
  run_hook "$(jq -nc '{session_id: "s1", tool_name: "Agent", tool_input: {prompt: "y"}}')"
  [ -z "$output" ]
}

@test "injects showboat.md and install.md on an install command" {
  for c in 'sudo apt install jq' 'uv tool install ruff' 'pip install x' 'cd ~/dotfiles && stow -n claude' 'claude plugin install foo' 'systemctl --user restart x'; do
    rm -f "$RUNTIME"/claude-code-rules-*
    run_hook "$(bash_call "$c")"
    [[ $(field additionalContext) == *BODY-showboat*BODY-install* ]] || {
      echo "missed: $c"
      return 1
    }
  done
}

@test "does not take a word containing stow or apt for the command" {
  run_hook "$(bash_call 'stow-rprofile && echo apt')"
  [ -z "$output" ]
}

@test "injects docx.md on libreoffice and on a .docx read" {
  run_hook "$(bash_call 'libreoffice --headless --convert-to pdf a.odt')"
  [[ $(field additionalContext) == *BODY-docx* ]]
  rm -f "$RUNTIME"/claude-code-rules-*
  run_hook "$(read_call Read "$WORK/r.docx")"
  [[ $(field additionalContext) == *BODY-docx* ]]
}

@test "injects chromium.md on a chromium command" {
  # shellcheck disable=SC2016
  run_hook "$(bash_call 'P=$(mktemp -d); timeout 60 chromium --headless=new --screenshot a.html')"
  [[ $(field additionalContext) == *BODY-chromium* ]]
}

@test "does not take a file or a search pattern naming a tool for the command" {
  run_hook "$(bash_call 'wc -m chromium.md && rg -n "libreoffice|firefox" notes.txt')"
  [ -z "$output" ]
}

@test "resolves a bare file name against the cwd before exempting the rules" {
  run_hook "$(jq -nc --arg d "$WORK/x/.claude/rules" '{session_id: "s1", cwd: $d, tool_name: "Bash", tool_input: {command: "wc -m secrets.md"}}')"
  [ -z "$output" ]
  run_hook "$(jq -nc --arg d "$WORK/project" '{session_id: "s1", cwd: $d, tool_name: "Bash", tool_input: {command: "wc -m secrets.md"}}')"
  [ "$(field permissionDecision)" = ask ]
}

@test "defers a block that would push the context past the cap" {
  awk 'BEGIN { for (i = 0; i < 9400; i++) printf "x"; print "" }' >"$RULES/secrets.md"
  run_hook "$(read_call Read "$WORK/secret-report.pdf")"
  [ "$(field permissionDecision)" = deny ]
  [[ $(field additionalContext) == *'rules/secrets.md'*xxxx* ]]
  [[ $(field additionalContext) != *BODY-pdf* ]]
  run_hook "$(read_call Read "$WORK/secret-report.pdf")"
  [ "$(field permissionDecision)" = deny ]
  [[ $(field additionalContext) == *BODY-pdf* ]]
}

@test "skips a rules file that does not exist" {
  rm "$RULES/chromium.md"
  run_hook "$(bash_call 'chromium --version')"
  [ -z "$output" ]
}

@test "keeps one marker per session" {
  run_hook "$(bash_call 'pdfinfo a.pdf')"
  run_hook "$(jq -nc '{session_id: "s2", tool_name: "Bash", tool_input: {command: "pdfinfo a.pdf"}}')"
  [[ $(field additionalContext) == *BODY-pdf* ]]
}

@test "logs each injection with its decision" {
  run_hook "$(read_call Read "$WORK/a.pdf")"
  run awk -F'\t' '{print $2 "|" $3 "|" $4}' "$STATE/claude-code/instructions.log"
  [ "$output" = "s1|inject-deny|$RULES/pdf.md" ]
}

@test "exits 0 on malformed input or an unsafe session id" {
  run_hook "not json"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook "$(jq -nc '{session_id: "a/b", tool_name: "Read", tool_input: {file_path: "/x.pdf"}}')"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
