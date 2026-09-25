#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/git-write-guard.sh"
STALE="$BATS_TEST_DIRNAME/../../claude/.claude/hooks/commit-stale.sh"

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
  for cmd in cat jq realpath git stat sha256sum readlink; do
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

seal() {
  local value=$1
  shift
  # shellcheck disable=SC2016
  env PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s\0" "${@:3}" | /bin/bash "$1" --seal s1 "$2"' _ "$STALE" "$value" "$@"
  stamp "$value"
}

commit_file() {
  mkdir -p "$(dirname "$WORK/$1")"
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

@test "denies a git write run through any program placed before git" {
  for c in 'setsid git push' 'flock /tmp/l git push' 'find . -name x -exec git rm {} \;' 'fdfind -e orig -x git rm' '>/dev/null git push' '2>/dev/null git add a.sh'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
  done
}

@test "denies a git write whose program name or subcommand is escaped or redirected" {
  for c in '\git push' 'g""it push' 'git pu\sh' 'git a\dd a.sh' 'git 2>/dev/null push' 'git 2> /dev/null add a.sh'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
  done
}

@test "passes read commands that name git after another program or carry a redirection" {
  for c in 'command -v git' 'fdfind -e md -x wc -l' 'find . -name .git -prune' 'git 2>/dev/null status' 'rg -c git src/'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
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
  [[ $output == *"commit-stale.sh was unreadable"* ]]
}

@test "denies a commit when the session id is unusable" {
  payload=$(jq -nc --arg d "$WORK" '{session_id: "", cwd: $d, tool_input: {command: "git commit -m x"}}')
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "$2"' _ "$payload" "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ $output == *"session id is unusable"* ]]
}

@test "passes a commit whose staged file kept its content through a prek restore" {
  commit_file a.sh
  commit_file b.sh
  printf 'v2\n' >"$WORK/a.sh"
  printf 'v2\n' >"$WORK/b.sh"
  seal "$(date +%s%N)" "$WORK/a.sh" "$WORK/b.sh"
  sleep 0.05
  printf 'v2\n' >"$WORK/b.sh"
  run_guard 'git add b.sh && git commit -m "fix: x"'
  [ "$status" -eq 0 ]
}

@test "passes a commit that does not take a file created after the verification" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  sleep 0.05
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git add a.sh && git commit -m "fix: x"'
  [ "$status" -eq 0 ]
}

@test "denies a commit taking a file whose content changed after the verification" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'v3\n' >"$WORK/a.sh"
  run_guard 'git add a.sh && git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/a.sh"* ]]
}

@test "denies a commit taking a file staged after the verification with new content" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'v3\n' >"$WORK/a.sh"
  git -C "$WORK" add a.sh
  run_guard 'git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/a.sh"* ]]
}

@test "resolves a directory pathspec to the files under it" {
  commit_file sub/a.sh
  printf 'v2\n' >"$WORK/sub/a.sh"
  seal "$(date +%s%N)" "$WORK/sub/a.sh"
  printf 'v3\n' >"$WORK/sub/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git add sub && git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/sub/a.sh"* ]]
  [[ $output != *other.md* ]]
}

@test "checks the tracked files a commit -a takes, not the untracked ones" {
  commit_file a.sh
  commit_file b.sh
  printf 'v2\n' >"$WORK/a.sh"
  printf 'v2\n' >"$WORK/b.sh"
  seal "$(date +%s%N)" "$WORK/a.sh" "$WORK/b.sh"
  printf 'v3\n' >"$WORK/b.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git commit -am "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/b.sh"* ]]
  [[ $output != *other.md* ]]
}

@test "checks the whole tree when a pathspec cannot be resolved" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git add "a.sh" && git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/other.md"* ]]
}

@test "checks the repository a cd leads to, not the directory of the session" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  OTHER=$(realpath "$(mktemp -d)")
  git init -q "$OTHER"
  printf 'x\n' >"$OTHER/new.md"
  run_guard "cd $OTHER && git add -A && git commit -m x"
  rm -rf "$OTHER"
  [ "$status" -eq 2 ]
  [[ $output == *"$OTHER/new.md"* ]]
}

@test "counts a .claude directory below the repository root as code after a cd into a subdirectory" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  mkdir -p "$WORK/claude/.claude/hooks"
  printf 'x\n' >"$WORK/claude/.claude/hooks/h.sh"
  run_guard "cd $WORK/claude && git add -A && git commit -m x"
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/claude/.claude/hooks/h.sh"* ]]
}

@test "reads a capital Q in a cd target as a letter, not as a quote" {
  mkdir -p "$WORK/Qsub"
  run_guard "cd $WORK/Qsub && git commit -m x"
  [ "$status" -eq 0 ]
}

@test "denies a commit after a cd whose target the guard cannot resolve" {
  # shellcheck disable=SC2016
  run_guard 'cd "$repo" && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"plain path"* ]]
  run_guard 'cd - && git commit -m x'
  [ "$status" -eq 2 ]
  run_guard 'cd ~root/x && git commit -m x'
  [ "$status" -eq 2 ]
}

@test "passes the canonical git rm and git mv" {
  run_guard 'git rm --cached a.sh'
  [ "$status" -eq 0 ]
  run_guard 'git mv a.sh b.sh'
  [ "$status" -eq 0 ]
}

@test "denies git stage, the synonym of git add, in every form" {
  git -C "$WORK" config alias.st stage
  run_guard 'git stage a.sh'
  [ "$status" -eq 2 ]
  [[ $output == *"write it as git add"* ]]
  run_guard 'git st a.sh'
  [ "$status" -eq 2 ]
  run_guard "bash -c 'git stage a.sh'"
  [ "$status" -eq 2 ]
}

@test "denies git rm behind -C and git mv behind a wrapper" {
  run_guard 'git -C . rm --cached a.sh'
  [ "$status" -eq 2 ]
  [[ $output == *"global options"* ]]
  run_guard 'env git mv a.sh b.sh'
  [ "$status" -eq 2 ]
}

@test "denies each verb left to the user, in its canonical form" {
  for verb in push reset checkout switch restore stash merge rebase tag cherry-pick revert clean pull am; do
    run_guard "git $verb"
    [ "$status" -eq 2 ]
    [[ $output == *"leave it to the user"* ]]
  done
}

@test "denies a verb left to the user behind -C or inside bash -c" {
  run_guard 'git -C ~/dotfiles push'
  [ "$status" -eq 2 ]
  run_guard "bash -c 'git push origin main'"
  [ "$status" -eq 2 ]
  [[ $output == *"shell string"* ]]
}

@test "denies an alias that expands to a verb left to the user" {
  git -C "$WORK" config alias.sw switch
  git -C "$WORK" config alias.unstage 'restore --staged'
  run_guard 'git sw main'
  [ "$status" -eq 2 ]
  run_guard 'git unstage a.sh'
  [ "$status" -eq 2 ]
}

@test "resolves aliases whatever their case and through chains" {
  git -C "$WORK" config alias.sw switch
  git -C "$WORK" config alias.a2 sw
  git -C "$WORK" config alias.l1 l2
  git -C "$WORK" config alias.l2 l1
  run_guard 'git SW main'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
  run_guard 'git a2 main'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
  run_guard 'git l1'
  [ "$status" -eq 2 ]
  [[ $output == *"too many aliases"* ]]
}

@test "denies a quoted or variable subcommand" {
  run_guard "git 'push'"
  [ "$status" -eq 2 ]
  # shellcheck disable=SC2016
  run_guard 'git $verb origin'
  [ "$status" -eq 2 ]
}

@test "denies a command whose quotes stay open after an apostrophe in a comment or a heredoc" {
  run_guard $'git status # don\'t\ngit -C . push'
  [ "$status" -eq 2 ]
  [[ $output == *"quote open"* ]]
  run_guard $'cat > f <<\'EOF\'\ndon\'t\nEOF\ngit add a.sh && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"quote open"* ]]
}

@test "denies creating, renaming or deleting a branch" {
  for args in 'feature' 'feature HEAD~1' '-m old new' '-M new' '-c copy' '-f feature' '--delete feature' '-u origin/main'; do
    run_guard "git branch $args"
    [ "$status" -eq 2 ]
  done
}

@test "passes the branch listing forms" {
  for args in '' '-a' '-vv' '-av' '--show-current' '--list "feat*"' '-l feat' '--contains HEAD' '--merged main -a' '--sort=-committerdate' '--sort -committerdate' '--points-at HEAD -a'; do
    run_guard "git branch $args"
    [ "$status" -eq 0 ]
  done
}

@test "passes read pipelines into xargs that name a gated verb outside a git call" {
  for c in "rg -l 'git commit' claude/ | xargs wc -l" 'git branch -r | xargs -n1 basename' 'git log --grep=revert --format=%H | xargs -n1 git show --stat' "rg -n 'git push' src/ | bash -c 'cat'"; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "denies a git write that xargs runs" {
  run_guard 'git ls-files | xargs git rm'
  [ "$status" -eq 2 ]
  [[ $output == *"wrapper xargs"* ]]
  run_guard 'xargs -I{} git push {}'
  [ "$status" -eq 2 ]
}

@test "passes a read command that pipes into xargs rm" {
  run_guard 'git ls-files -z | xargs -0 rm'
  [ "$status" -eq 0 ]
}

@test "passes everything when jq is missing" {
  rm "$STUB_DIR/jq"
  run_guard 'git -C ~/dotfiles commit -m x'
  [ "$status" -eq 0 ]
}
