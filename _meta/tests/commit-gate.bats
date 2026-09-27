#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/commit-gate.sh"

setup() {
  mapfile -t git_env < <(git rev-parse --local-env-vars)
  unset "${git_env[@]}"
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  PROJECT="$WORK/proj"
  FAKE_HOME="$WORK/home"
  OUTSIDE=$(realpath "$(mktemp -d)")
  export WORK STUB_DIR RUNTIME PROJECT FAKE_HOME OUTSIDE

  mkdir -p "$STUB_DIR" "$RUNTIME" "$PROJECT/.claude" "$FAKE_HOME/.claude/memory"
  git init -q "$WORK"
  printf '%s\n' .stubs/ runtime/ >>"$WORK/.git/info/exclude"
  for cmd in cat jq realpath git stat rm sha256sum readlink shfmt; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK" "$OUTSIDE"
}

run_gate() {
  local payload=$1
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

payload() {
  local message=$1 active=${2:-false} cwd=${3:-$PROJECT}
  jq -nc --arg m "$message" --argjson a "$active" --arg c "$cwd" \
    '{session_id: "s1", cwd: $c, stop_hook_active: $a, last_assistant_message: $m}'
}

commit_message() {
  printf '%s\n' 'Voici le commit :' '```bash' 'git add .' 'git commit -m "feat(x): y"' '```'
}

unfenced_message() {
  printf '%s\n' 'Voici le commit :' 'git add .' 'git commit -m "feat(x): y"'
}

block_message() {
  printf '%s\n' '```bash' "$@" '```'
}

write_at() {
  printf '%s\t%s\n' "$1" "$2" >>"$RUNTIME/claude-code-writes-s1.log"
}

stamp() {
  printf '%s\n' "$1" >"$RUNTIME/claude-code-writes-s1.stamp"
}

seal() {
  local value=$1
  shift
  # shellcheck disable=SC2016
  env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s\0" "${@:3}" | /bin/bash "$1" --seal s1 "$2"' _ "${SCRIPT%/*}/commit-stale.sh" "$value" "$@"
  stamp "$value"
}

commit_file() {
  mkdir -p "$(dirname "$WORK/$1")"
  printf 'v1\n' >"$WORK/$1"
  git -C "$WORK" add -- "$1"
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
}

staged_change() {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  git -C "$WORK" add proj/a.sh
}

@test "blocks on a modified tracked file when the session has no journal" {
  commit_file proj/src/a.sh
  printf 'v2\n' >"$PROJECT/src/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/a.sh"* ]]
}

@test "blocks on an untracked file when the session has no journal" {
  mkdir -p "$PROJECT/src"
  printf 'x\n' >"$PROJECT/src/new.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/new.sh"* ]]
}

@test "passes when a modified file predates the stamp" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  sleep 0.05
  stamp "$(date +%s%N)"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "blocks when a modified file is newer than the stamp" {
  commit_file proj/a.sh
  stamp "$(date +%s%N)"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/a.sh"* ]]
}

@test "passes when a rewrite after the stamp keeps the sealed content" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  sleep 0.05
  printf 'v2\n' >"$PROJECT/a.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "blocks on a file renamed after the stamp" {
  commit_file proj/a.sh
  stamp "$(date +%s%N)"
  sleep 0.05
  mv "$PROJECT/a.sh" "$PROJECT/b.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/b.sh"* ]]
}

@test "passes blocks whose paths kept their sealed content while another session changes a file they do not take" {
  commit_file proj/a.sh
  commit_file proj/b.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  printf 'v2\n' >"$PROJECT/b.sh"
  printf 'x\n' >"$PROJECT/c.md"
  run_gate "$(payload "$(block_message 'git add a.sh && git commit -m "fix: y"')")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes a memory commit into another repository while foreign files change in both repositories" {
  commit_file claude/.claude/hooks/inject-rules.sh
  mkdir -p "$WORK/claude/.claude/memory"
  rm -rf "$FAKE_HOME/.claude/memory"
  ln -s "$WORK/claude/.claude/memory" "$FAKE_HOME/.claude/memory"
  printf '%s\n' home/ >>"$WORK/.git/info/exclude"
  git init -q "$OUTSIDE"
  printf 'x\n' >"$OUTSIDE/filetree.lua"
  printf 'x\n' >"$WORK/claude/.claude/memory/feedback_x.md"
  seal "$(date +%s%N)" "$OUTSIDE/filetree.lua" "$WORK/claude/.claude/memory/feedback_x.md"
  printf 'v2\n' >"$WORK/claude/.claude/hooks/inject-rules.sh"
  printf 'x\n' >"$OUTSIDE/other-session.lua"
  run_gate "$(payload "$(block_message "cd $WORK" 'git add claude/.claude/memory/feedback_x.md && git commit -m "docs(claude): x"')" false "$OUTSIDE")"
  [ "$status" -eq 0 ]
}

@test "blocks a block that changes directory into another repository and takes a file changed there after the verification" {
  git init -q "$OUTSIDE"
  printf 'v1\n' >"$OUTSIDE/a.sh"
  seal "$(date +%s%N)" "$OUTSIDE/a.sh"
  printf 'v2\n' >"$OUTSIDE/a.sh"
  run_gate "$(payload "$(block_message "cd $OUTSIDE" 'git add a.sh && git commit -m "fix: y"')")"
  [ "$status" -eq 2 ]
  [[ $output == *"$OUTSIDE/a.sh"* ]]
  [[ $output == *"/commit"* ]]
  [[ $output == *"stale"* ]]
}

@test "blocks a block whose commit line opens on cd, when the commit takes a file changed after the verification" {
  git init -q "$OUTSIDE"
  printf 'v1\n' >"$OUTSIDE/a.sh"
  seal "$(date +%s%N)" "$OUTSIDE/a.sh"
  printf 'v2\n' >"$OUTSIDE/a.sh"
  run_gate "$(payload "$(block_message "cd $OUTSIDE && git add a.sh && git commit -m \"fix: y\"")")"
  [ "$status" -eq 2 ]
  [[ $output == *"$OUTSIDE/a.sh"* ]]
}

@test "blocks a commit line that opens on cd or pushd, in each form" {
  staged_change
  for line in "cd $PROJECT && git commit -m x" "pushd $PROJECT && git commit -m x" "cd $PROJECT; git commit -m x" "cd \"$PROJECT\" && git commit -m x" "cd '$PROJECT' && git commit -m x" "cd $WORK && cd proj && git add a.sh && git commit -m x"; do
    run_gate "$(payload "$(block_message "$line")")"
    [ "$status" -eq 2 ]
    [[ $output == *"$PROJECT/a.sh"* ]]
  done
}

@test "passes a one-line memory commit into another repository while foreign files change in both repositories" {
  commit_file claude/.claude/hooks/inject-rules.sh
  mkdir -p "$WORK/claude/.claude/memory"
  rm -rf "$FAKE_HOME/.claude/memory"
  ln -s "$WORK/claude/.claude/memory" "$FAKE_HOME/.claude/memory"
  printf '%s\n' home/ >>"$WORK/.git/info/exclude"
  git init -q "$OUTSIDE"
  printf 'x\n' >"$OUTSIDE/filetree.lua"
  printf 'x\n' >"$WORK/claude/.claude/memory/feedback_x.md"
  seal "$(date +%s%N)" "$OUTSIDE/filetree.lua" "$WORK/claude/.claude/memory/feedback_x.md"
  printf 'v2\n' >"$WORK/claude/.claude/hooks/inject-rules.sh"
  printf 'x\n' >"$OUTSIDE/other-session.lua"
  run_gate "$(payload "$(block_message "cd $WORK && git add claude/.claude/memory/feedback_x.md && git commit -m \"docs(claude): x\"")" false "$OUTSIDE")"
  [ "$status" -eq 0 ]
  printf 'v3\n' >"$WORK/claude/.claude/memory/feedback_x.md"
  printf 'x\n' >"$WORK/a.sh"
  run_gate "$(payload "$(block_message "cd $WORK && git add claude/.claude/memory/feedback_x.md a.sh && git commit -m \"docs(claude): x\"")" false "$OUTSIDE")"
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/a.sh"* ]]
}

@test "carries a cd from one commit block to the next, as the shell does across Bash calls" {
  git init -q "$OUTSIDE"
  printf 'v1\n' >"$OUTSIDE/a.sh"
  printf 'v1\n' >"$OUTSIDE/b.sh"
  seal "$(date +%s%N)" "$OUTSIDE/a.sh" "$OUTSIDE/b.sh"
  printf 'v2\n' >"$OUTSIDE/b.sh"
  message=$(printf '%s\n' "$(block_message "cd $OUTSIDE" 'git add a.sh && git commit -m "fix: a"')" 'Puis :' "$(block_message 'git add b.sh && git commit -m "fix: b"')")
  run_gate "$(payload "$message")"
  [ "$status" -eq 2 ]
  [[ $output == *"$OUTSIDE/b.sh"* ]]
}

@test "names a path the blocks take that the verification never sealed as possibly another session's" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  seal "$(date +%s%N)" "$PROJECT/a.sh"
  printf 'x\n' >"$PROJECT/other.md"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"never sealed"*"$PROJECT/other.md"* ]]
  [[ $output == *"another session"* ]]
  [[ $output == *"out of the staging commands"* ]]
  [[ $output == *"must not be run"* ]]
  [[ $output != *"$PROJECT/a.sh"* ]]
}

@test "leaves the repository's .claude directory and the memory directory out of the paths the blocks take" {
  mkdir -p "$WORK/.claude"
  printf 'x\n' >"$WORK/.claude/PLAN.md"
  printf 'x\n' >"$FAKE_HOME/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(commit_message)" false "$WORK")"
  [ "$status" -eq 0 ]
}

@test "falls back to the whole status check when no fenced block holds the commit" {
  write_at 200 "$PROJECT/a.sh"
  message=$(printf '%s\n' "$(block_message 'git status --short')" 'git add .' 'git commit -m "feat(x): y"')
  run_gate "$(payload "$message")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/a.sh"* ]]
}

@test "falls back to the whole status check when the guard judges no commit in the blocks" {
  write_at 200 "$PROJECT/a.sh"
  message=$(block_message 'cd /tmp && git commit -m "feat(x): y"')
  run_gate "$(payload "$message")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/a.sh"* ]]
}

@test "ignores modified files under .claude and the memory directory" {
  printf 'x\n' >"$PROJECT/.claude/PLAN.md"
  printf 'x\n' >"$FAKE_HOME/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores a git-ignored file" {
  printf 'x\n' >"$PROJECT/build.log"
  printf '%s\n' '*.log' >>"$WORK/.git/info/exclude"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores a journaled write to a git-ignored file" {
  printf '%s\n' '*.log' >>"$WORK/.git/info/exclude"
  write_at 200 "$PROJECT/build.log"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "blocks on a deleted tracked file without a stamp and passes with one" {
  commit_file proj/gone.sh
  rm "$PROJECT/gone.sh"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/gone.sh"* ]]
  stamp 150
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "lists a path seen in both the journal and git status once" {
  mkdir -p "$PROJECT/src"
  printf 'x\n' >"$PROJECT/src/a.sh"
  write_at 200 "$PROJECT/src/a.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [ "$(grep -c "$PROJECT/src/a.sh" <<<"$output")" -eq 1 ]
  [[ $output == *"1 file(s)"* ]]
}

@test "blocks a commit proposal after a code write with no stamp" {
  write_at 100 "$PROJECT/src/a.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/a.sh"* ]]
  [[ $output == *"/commit"* ]]
  [[ $output == *"stale"* ]]
}

@test "blocks when a code write is newer than the stamp" {
  stamp 150
  write_at 100 "$PROJECT/old.sh"
  write_at 200 "$PROJECT/new.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/new.sh"* ]]
  [[ $output != *"$PROJECT/old.sh"* ]]
}

@test "passes when every code write predates the stamp" {
  write_at 100 "$PROJECT/a.sh"
  stamp 150
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "reads a stamp written without a trailing newline" {
  write_at 100 "$PROJECT/a.sh"
  printf '%s' 150 >"$RUNTIME/claude-code-writes-s1.stamp"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "passes when the stamp equals the last write" {
  write_at 150 "$PROJECT/a.sh"
  stamp 150
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores writes under the project's .claude directory" {
  write_at 200 "$PROJECT/.claude/PLAN.md"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "ignores writes under the resolved memory directory" {
  write_at 200 "$FAKE_HOME/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "resolves a symlinked memory directory before comparing" {
  rm -rf "$FAKE_HOME/.claude/memory"
  mkdir -p "$WORK/dotfiles/claude/.claude/memory"
  ln -s "$WORK/dotfiles/claude/.claude/memory" "$FAKE_HOME/.claude/memory"
  printf '%s\n' home/.claude/memory >>"$WORK/.git/info/exclude"
  write_at 200 "$WORK/dotfiles/claude/.claude/memory/feedback_x.md"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "a .claude directory that is not the project's own still counts as code" {
  write_at 200 "$WORK/dotfiles/claude/.claude/hooks/x.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"claude/.claude/hooks/x.sh"* ]]
}

@test "a sibling directory sharing the .claude prefix is not excluded" {
  write_at 200 "$PROJECT/.claude-old/x.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
}

@test "prefers CLAUDE_PROJECT_DIR over cwd as the project root" {
  mkdir -p "$PROJECT/sub"
  write_at 200 "$PROJECT/.claude/PLAN.md"
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$(payload "$(unfenced_message)" false "$PROJECT/sub")" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "ignores writes under the git root's .claude when the project dir is a subdirectory" {
  git init -q "$PROJECT"
  mkdir -p "$PROJECT/sub/.claude"
  write_at 200 "$PROJECT/.claude/PLAN.md"
  write_at 201 "$PROJECT/sub/.claude/PLAN.md"
  # shellcheck disable=SC2016
  run env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" CLAUDE_PROJECT_DIR="$PROJECT/sub" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$(payload "$(unfenced_message)" false "$PROJECT/sub")" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "ignores writes outside any git work tree" {
  write_at 200 "$OUTSIDE/probe.sh"
  write_at 201 "$OUTSIDE/gone/deeper/x.py"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "lists a repository write but not an out-of-repository one" {
  write_at 200 "$OUTSIDE/probe.sh"
  write_at 201 "$PROJECT/src/a.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$PROJECT/src/a.sh"* ]]
  [[ $output != *"$OUTSIDE/probe.sh"* ]]
  [[ $output == *"1 file(s)"* ]]
}

@test "still lists a write in another repository than the project's" {
  git init -q "$OUTSIDE"
  write_at 200 "$OUTSIDE/other.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"$OUTSIDE/other.sh"* ]]
}

@test "passes when the message only mentions git commit -m in prose" {
  write_at 200 "$PROJECT/a.sh"
  # shellcheck disable=SC2016
  run_gate "$(payload 'La porte lit `git commit -m` dans le texte final.')"
  [ "$status" -eq 0 ]
}

@test "blocks a git commit -am line" {
  commit_file proj/a.sh
  printf 'v2\n' >"$PROJECT/a.sh"
  run_gate "$(payload "$(block_message '  git commit -am "fix: y"')")"
  [ "$status" -eq 2 ]
}

@test "blocks a commit chained after its staging command" {
  staged_change
  run_gate "$(payload "$(block_message 'git add a.sh && git commit -m "fix: y"')")"
  [ "$status" -eq 2 ]
}

@test "blocks a commit line carrying git global options" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload "$(block_message 'git -C ~/dotfiles add a.sh && git -C ~/dotfiles commit -m "fix: y"')")"
  [ "$status" -eq 2 ]
  run_gate "$(payload "$(block_message 'git -c user.name=t commit -m "fix: y"')")"
  [ "$status" -eq 2 ]
}

@test "blocks a commit line carrying an environment prefix" {
  staged_change
  run_gate "$(payload "$(block_message 'SKIP=metadata-only git commit -m "v5.4.1"')")"
  [ "$status" -eq 2 ]
  run_gate "$(payload "$(block_message 'git add a.sh && SKIP=a,b git commit -m "fix: y"')")"
  [ "$status" -eq 2 ]
  run_gate "$(payload "$(block_message 'GIT_AUTHOR_NAME="J D" GIT_AUTHOR_EMAIL=j@d git commit -m "fix: y"')")"
  [ "$status" -eq 2 ]
}

@test "passes when prose quotes a chained commit" {
  write_at 200 "$PROJECT/a.sh"
  # shellcheck disable=SC2016
  run_gate "$(payload 'Une ligne `git add … && git commit -m` passait inaperçue.')"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run_gate "$(payload 'Lance ensuite `cd ~/dotfiles && git commit -m x` toi-même.')"
  [ "$status" -eq 0 ]
  run_gate "$(payload "$(printf '%s\n' 'Le motif lit :' 'cd, puis git commit')")"
  [ "$status" -eq 0 ]
}

@test "passes when the message proposes no commit" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload 'Le script est prêt.')"
  [ "$status" -eq 0 ]
}

@test "passes its own continuation and consumes its marker" {
  staged_change
  : >"$RUNTIME/claude-code-commit-gate-s1.blocked"
  run_gate "$(payload "$(commit_message)" true)"
  [ "$status" -eq 0 ]
  [ ! -e "$RUNTIME/claude-code-commit-gate-s1.blocked" ]
}

@test "blocks a continuation another Stop hook triggered" {
  staged_change
  run_gate "$(payload "$(commit_message)" true)"
  [ "$status" -eq 2 ]
  [ -e "$RUNTIME/claude-code-commit-gate-s1.blocked" ]
}

@test "writes its marker when it blocks" {
  staged_change
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 2 ]
  [ -e "$RUNTIME/claude-code-commit-gate-s1.blocked" ]
}

@test "clears a leftover marker on a stop that is not a continuation" {
  : >"$RUNTIME/claude-code-commit-gate-s1.blocked"
  run_gate "$(payload 'Le script est prêt.')"
  [ "$status" -eq 0 ]
  [ ! -e "$RUNTIME/claude-code-commit-gate-s1.blocked" ]
}

@test "passes with no journal and a clean tree" {
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
}

@test "treats a malformed stamp as absent" {
  write_at 100 "$PROJECT/a.sh"
  stamp garbage
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
}

@test "skips malformed journal lines" {
  printf 'garbage line\n\t%s\n' "$PROJECT/b.sh" >"$RUNTIME/claude-code-writes-s1.log"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 0 ]
}

@test "lists a path written twice only once" {
  write_at 100 "$PROJECT/a.sh"
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [ "$(grep -c "$PROJECT/a.sh" <<<"$output")" -eq 1 ]
  [[ $output == *"1 file(s)"* ]]
}

@test "caps the listed paths at ten and counts the rest" {
  for i in $(seq 1 12); do
    write_at "$((100 + i))" "$PROJECT/f$i.sh"
  done
  run_gate "$(payload "$(unfenced_message)")"
  [ "$status" -eq 2 ]
  [[ $output == *"12 file(s)"* ]]
  [[ $output == *"and 2 more"* ]]
  [[ $output != *"$PROJECT/f11.sh"* ]]
}

@test "ignores a session id carrying a path separator" {
  write_at 200 "$PROJECT/a.sh"
  run_gate "$(jq -nc --arg m "$(commit_message)" '{session_id: "../s1", cwd: "/x", stop_hook_active: false, last_assistant_message: $m}')"
  [ "$status" -eq 0 ]
}

@test "exits 0 on malformed JSON" {
  run_gate 'not json'
  [ "$status" -eq 0 ]
}

@test "exits 0 silently when jq is missing" {
  write_at 200 "$PROJECT/a.sh"
  rm -f "$STUB_DIR/jq"
  run_gate "$(payload "$(commit_message)")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
