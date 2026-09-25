#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/git-write-guard.sh"

setup() {
  mapfile -t git_env < <(git rev-parse --local-env-vars)
  unset "${git_env[@]}"
  WORK=$(realpath "$(mktemp -d)")
  STUB_DIR="$WORK/.stubs"
  RUNTIME="$WORK/runtime"
  FAKE_HOME="$WORK/home"
  export WORK STUB_DIR RUNTIME FAKE_HOME

  mkdir -p "$STUB_DIR" "$RUNTIME" "$FAKE_HOME/.claude/memory"
  git init -q "$WORK"
  printf '%s\n' .stubs/ runtime/ home/ >>"$WORK/.git/info/exclude"
  for cmd in cat jq realpath git stat; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

run_guard() {
  local command=$1 payload
  payload=$(jq -nc --arg c "$command" --arg d "$WORK" \
    '{session_id: "s1", cwd: $d, tool_name: "Bash", tool_input: {command: $c}}')
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
}

stamp() {
  printf '%s\n' "$1" >"$RUNTIME/claude-code-writes-s1.stamp"
}

commit_file() {
  printf 'v1\n' >"$WORK/$1"
  git -C "$WORK" add -- "$1"
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
}

@test "passes a command that does not mention git" {
  run_guard 'rg -n foo src/'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "passes the canonical add and commit on a clean tree" {
  run_guard 'git add a.sh && git commit -m "feat(x): y"'
  [ "$status" -eq 0 ]
}

@test "passes a commit carrying an environment prefix" {
  run_guard 'SKIP=metadata-only git commit -m "v5.4.1"'
  [ "$status" -eq 0 ]
}

@test "passes a commit reached through cd" {
  run_guard 'cd ~/dotfiles && git commit -m "fix(bin): x"'
  [ "$status" -eq 0 ]
}

@test "passes a read command carrying global options" {
  run_guard 'git -C ~/dotfiles log --grep commit --oneline'
  [ "$status" -eq 0 ]
}

@test "passes a search whose pattern quotes a commit line" {
  run_guard "rg -n 'git -C . commit -m' _meta/"
  [ "$status" -eq 0 ]
}

@test "passes a quoted message that mentions a forbidden option" {
  run_guard 'git commit -m "fix: handle -n and --amend in the parser"'
  [ "$status" -eq 0 ]
}

@test "passes a combined -am flag" {
  run_guard 'git commit -am "fix: x"'
  [ "$status" -eq 0 ]
}

@test "denies a commit behind -C" {
  run_guard 'git -C ~/dotfiles commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"global options"* ]]
}

@test "denies an add behind -C with a quoted path" {
  run_guard 'git -C "my repo" add .'
  [ "$status" -eq 2 ]
}

@test "denies a commit behind -c" {
  run_guard 'git -c core.hooksPath=/dev/null commit -m "fix: x"'
  [ "$status" -eq 2 ]
}

@test "denies git called by path" {
  run_guard '/usr/bin/git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"by path"* ]]
}

@test "denies a commit inside bash -c" {
  run_guard "bash -c 'git add . && git commit -m x'"
  [ "$status" -eq 2 ]
  [[ $output == *"shell string"* ]]
}

@test "denies an add inside eval" {
  run_guard 'eval "git add ."'
  [ "$status" -eq 2 ]
}

@test "denies a commit behind a wrapper" {
  run_guard 'env GIT_EDITOR=true git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"wrapper env"* ]]
}

@test "denies a commit in a subshell behind a wrapper" {
  run_guard 'echo start; (timeout 30 git commit -m x)'
  [ "$status" -eq 2 ]
}

@test "denies an alias that expands to commit" {
  git -C "$WORK" config alias.ci commit
  run_guard 'git ci -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"alias git ci"* ]]
}

@test "denies a shell alias that runs add" {
  git -C "$WORK" config alias.save '!git add -u'
  run_guard 'git save'
  [ "$status" -eq 2 ]
}

@test "passes an alias that expands to a read command" {
  git -C "$WORK" config alias.st 'status -sb'
  run_guard 'git st'
  [ "$status" -eq 0 ]
}

@test "denies --no-verify" {
  run_guard 'git commit --no-verify -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"--no-verify"* ]]
}

@test "denies an abbreviated --no-verify" {
  run_guard 'git commit --no-veri -m "fix: x"'
  [ "$status" -eq 2 ]
}

@test "denies -n inside a short option cluster" {
  run_guard 'git commit -nm "fix: x"'
  [ "$status" -eq 2 ]
}

@test "passes an n carried by the message of an attached -m" {
  run_guard 'git commit -mnote'
  [ "$status" -eq 0 ]
}

@test "denies --amend and its abbreviation" {
  run_guard 'git commit --amend --no-edit'
  [ "$status" -eq 2 ]
  run_guard 'git commit --am -m x'
  [ "$status" -eq 2 ]
}

@test "passes -n on git add, where it means a dry run" {
  run_guard 'git add -n .'
  [ "$status" -eq 0 ]
}

@test "denies a commit when a tracked file changed after the stamp" {
  commit_file a.sh
  stamp "$(date +%s%N)"
  sleep 0.05
  printf 'v2\n' >"$WORK/a.sh"
  run_guard 'git add a.sh && git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/a.sh"* ]]
  [[ $output == *"commit skill"* ]]
}

@test "passes an add alone when a tracked file changed after the stamp" {
  commit_file a.sh
  stamp "$(date +%s%N)"
  sleep 0.05
  printf 'v2\n' >"$WORK/a.sh"
  run_guard 'git add a.sh'
  [ "$status" -eq 0 ]
}

@test "passes a commit when every change predates the stamp" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  sleep 0.05
  stamp "$(date +%s%N)"
  run_guard 'git add a.sh && git commit -m "fix: x"'
  [ "$status" -eq 0 ]
}

@test "denies a commit when the stamp is unreadable" {
  commit_file a.sh
  stamp "not-a-number"
  run_guard 'git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"could not"* ]]
}

@test "denies a commit when the session id is unusable" {
  payload=$(jq -nc --arg d "$WORK" '{session_id: "", cwd: $d, tool_input: {command: "git commit -m x"}}')
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "passes everything when jq is missing" {
  rm "$STUB_DIR/jq"
  run_guard 'git -C ~/dotfiles commit -m x'
  [ "$status" -eq 0 ]
}
