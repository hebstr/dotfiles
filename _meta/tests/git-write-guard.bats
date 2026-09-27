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
  for cmd in cat jq realpath git stat rm sha256sum readlink shfmt; do
    ln -sf "$(command -v "$cmd")" "$STUB_DIR/$cmd"
  done
}

teardown() {
  rm -rf "$WORK"
}

guard() {
  local command=$1 dir=$2 payload
  shift 2
  payload=$(jq -nc --arg c "$command" --arg d "$dir" \
    '{session_id: "s1", cwd: $d, tool_name: "Bash", tool_input: {command: $c}}')
  # shellcheck disable=SC2016
  run env -u CLAUDE_PROJECT_DIR PATH="$STUB_DIR" XDG_RUNTIME_DIR="$RUNTIME" HOME="$FAKE_HOME" \
    /bin/bash -c 'printf "%s" "$1" | /bin/bash "${@:2}"' _ "$payload" "$SCRIPT" "$@"
}

run_guard() {
  guard "$1" "${2:-$WORK}"
}

run_verdict() {
  guard "$1" "${2:-$WORK}" --verdict
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

@test "denies an assignment other than SKIP before add, commit, rm or mv" {
  local c
  for c in 'GIT_DIR=/tmp/x/.git git commit -m x' 'GIT_INDEX_FILE=/tmp/idx git commit -m x' 'GIT_WORK_TREE=/tmp/x git add .' 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git commit -m x' "GIT_CONFIG_PARAMETERS=\"'core.hooksPath=/dev/null'\" git commit -m x" 'HOME=/tmp/x git commit -m x' 'SKIP=metadata-only GIT_DIR=/tmp/x git commit -m x' 'LC_ALL=C git rm --cached a.sh' 'X=1 git mv a.sh b.sh'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"SKIP= being the only assignment kept"* ]]
  done
}

@test "passes SKIP before a commit and any assignment before a git read" {
  local c
  for c in 'SKIP="metadata-only,shellcheck" git commit -m x' 'GIT_DIR=/tmp/x/.git git log -1' 'LC_ALL=C git status'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
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

@test "denies a git write through any spelling of a shell string" {
  local c cases=(
    "/bin/bash -c 'git push origin main'"
    "/usr/bin/sh -c 'git push'"
    "bash --norc -c 'git push'"
    "bash -O extglob -c 'git push'"
    $'bash -c \'g""it push\''
    $'bash -c \'git pu""sh\''
    'bash -c "git pu\sh"'
    $'bash \\\n  -c \'git push\''
    $'bash -c "\\$\'git\' push"'
    "bash -c 'x=\$(git push)'"
    $'bash -c $\'\\x67it push\''
  )
  for c in "${cases[@]}"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"shell string"* ]]
  done
}

@test "denies an alias, a variable or git options hiding a write inside a shell string" {
  git -C "$WORK" config alias.p push
  # shellcheck disable=SC2016
  local c cases=(
    "bash -c 'git p origin main'"
    'v=push; bash -c "git $v origin main"'
    "bash -c 'git -c alias.q=push q'"
    "bash -c 'cd x && git -C . commit -m y'"
    "bash -c 'git \"\$0\" origin main' push"
    "bash -c 'g=git; \$g push'"
    "bash -c \"bash -c 'git push'\""
  )
  for c in "${cases[@]}"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"shell string"* ]]
  done
}

@test "passes git reads inside a shell string" {
  local c cases=(
    "bash -c 'git status'"
    "bash -c 'top=\$(git rev-parse --show-toplevel); echo \$top'"
    "sh -c 'git -C ~/dotfiles log --oneline -3'"
    "timeout 30 bash -c 'git diff --stat'"
    "bash -c 'echo hi' && git status"
    "bash -c 's=\"git push\"; printf %s \"\$s\"'"
    "bash -c 'rg -n \"git push\" src/'"
  )
  for c in "${cases[@]}"; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
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

@test "reads the script a shell takes on stdin, and denies one it cannot read" {
  local c
  # shellcheck disable=SC2016
  for c in "bash <<< 'git push'" "bash -s <<< 'git push'" "source /dev/stdin <<< 'git push'" ". /dev/stdin <<< 'git push'" "timeout 5 bash <<< 'git push'" $'bash <<EOF\ngit push\nEOF' $'bash <<\'EOF\'\ngit push\nEOF' "echo 'git push' | bash" "printf '%s' 'git push origin main' | sh" 'git status && bash <<< "$script"'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
  done
  for c in "bash <<< 'git status'" "printf '%s' \"\$payload\" | bash hook.sh" 'git diff | rg bash' 'git status && bash --version' $'cat <<EOF\ngit push in prose\nEOF'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "reads the body a time or coproc keyword wraps" {
  local c
  for c in 'time (git push)' 'time { git push; }' 'time if true; then git push; fi' 'coproc (git push)' 'coproc C { git push; }' 'time (cd /tmp && git push origin main)'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
  done
  run_guard 'time (ls -la)'
  [ "$status" -eq 0 ]
}

@test "denies a git write run through any program placed before git" {
  for c in 'setsid git push' 'flock /tmp/l git push' 'find . -name x -exec git rm {} \;' 'fdfind -e orig -x git rm' '>/dev/null git push' '2>/dev/null git add a.sh'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
  done
}

@test "reads a git whose name is quoted" {
  local c
  for c in '"git" push origin main' "'git' push origin main" '"g"it push' $'$\'git\' push' '$"git" push' "timeout 30 'git' push"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"leave it to the user"* ]]
  done
  for c in '"git" commit --no-verify -m x' "'git' add -A"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"escaped or quoted"* ]]
  done
  run_guard 'git ls-files | xargs "git" rm'
  [ "$status" -eq 2 ]
  [[ $output == *"escaped or quoted"* ]]
}

@test "denies a gated verb after a program name held in a variable, a substitution or escapes" {
  local c
  # shellcheck disable=SC2016
  for c in 'g=git; $g push origin main' '"$g" push origin main' '${g} commit -m x' '$(echo git) push origin main' '`echo git` push origin main' '$g -C . push' $'$\'\\x67it\' push' $'$\'\\x67\\x69\\x74\' $\'\\x70\\x75\\x73\\x68\'' $'g=$\'\\x67it\'; $g push' $'$(printf \'\\x67it\') push'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"cannot read"* ]]
  done
}

@test "denies a program word built by an unquoted or brace expansion in a command naming git" {
  local c
  # shellcheck disable=SC2016
  for c in "IFS=,; x='git,push'; \$x" '{git,} push origin main' "\$(printf 'git\\npush')" 'IFS=/; x=git; $x/push' 'for src in "git status" "git push"; do $src; done' "bash -c 'IFS=,; x=git,push; \$x'" 'x="git push"; bash -c "$x"' 'x="git push"; eval "$x"'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"word splitting"* ]]
  done
  # shellcheck disable=SC2016
  for c in 'x=git; "$x" status' '"$EDITOR" notes.md && git status' 'rg -c "\$x" src/ && git log -1'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "passes a program held in a variable or a substitution when no gated verb follows" {
  local c
  # shellcheck disable=SC2016
  for c in '"$EDITOR" notes.md' '$(command -v python3) -c "print(1)"' '"$SCRIPT" --dry-run' '"git" status' "'git' log -1" '"$PY" "$SCRIPT"' "echo '\$HOME' && git status" 'cleanup() { rm -f "$f"; }; trap cleanup EXIT; git status' 'x=`rm -v "$f"`; git status' $'# don\'t\nrm -f "$x"' "bash -c 'while IFS=\$'\"'\"'\\t'\"'\"' read -r a; do echo \"\$a\"; done' && git status"; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "denies a git write whose program name or subcommand is escaped or redirected" {
  for c in '\git push' 'g""it push' 'git pu\sh' 'git a\dd a.sh' 'git 2>/dev/null push' 'git 2> /dev/null add a.sh' 'git 2>&1 push origin main' 'git >&2 push' 'git &>/dev/null push' 'git 2>&1 add a.sh' 'git <&0 push'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
  done
}

@test "passes read commands that name git after another program or carry a redirection" {
  for c in 'command -v git' 'fdfind -e md -x wc -l' 'find . -name .git -prune' 'git 2>/dev/null status' 'rg -c git'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "denies an alias that expands to commit" {
  git -C "$WORK" config alias.ci commit
  run_guard 'git ci -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"git ci is not a command git lists"* ]]
}

@test "denies a shell alias that runs add" {
  git -C "$WORK" config alias.save '!git add -u'
  run_guard 'git save'
  [ "$status" -eq 2 ]
}

@test "denies an alias even when it expands to a read command" {
  git -C "$WORK" config alias.st 'status -sb'
  run_guard 'git st'
  [ "$status" -eq 2 ]
  [[ $output == *"not a command git lists"* ]]
}

@test "denies an alias saved with the subsection syntax" {
  git -C "$WORK" config alias.p.command push
  run_guard 'git p origin main'
  [ "$status" -eq 2 ]
  [[ $output == *"not a command git lists"* ]]
}

@test "denies an alias the command defines or redefines itself" {
  git -C "$WORK" config alias.st 'status -sb'
  # shellcheck disable=SC2016
  for c in 'git -c alias.p=push p origin main' 'git -c Alias.C=commit c -m x' "git -c 'alias.p=push' p" "git -c 'alias.src/.command=!git push' src/" 'git --config-env=alias.p=V p' 'git --config-env alias.p=V p' 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=push git p' "GIT_CONFIG_PARAMETERS=\"'alias.p=push'\" git p" 'git config alias.p push && git p origin main' 'HOME=/tmp/x git p' 'cd /tmp && git p' 'git -c alias.st=push st origin main'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"not a command git lists"* ]]
  done
}

@test "denies an alias over a deprecated command, which git lets it override" {
  run_guard "git -c alias.whatchanged='!git push' whatchanged"
  [ "$status" -eq 2 ]
  git -C "$WORK" config alias.pack-redundant '!git push'
  run_guard 'git pack-redundant'
  [ "$status" -eq 2 ]
}

@test "passes read commands carrying configuration options" {
  for c in 'git -c core.pager=less log' 'git -c color.ui=always status' 'git --config-env=color.ui=C diff' 'git help push'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "denies an unquoted git that another program reads, when a non-command follows it" {
  run_guard 'rg -c git src/'
  [ "$status" -eq 2 ]
  [[ $output == *"quote it"* ]]
  run_guard "rg -c 'git' src/"
  [ "$status" -eq 0 ]
}

@test "denies every git subcommand when git cannot list its commands" {
  local real
  real=$(command -v git)
  rm "$STUB_DIR/git"
  # shellcheck disable=SC2016
  for body in '[[ $1 == --list-cmds=* ]] && exit 1' '[[ $1 == --list-cmds=* ]] && exit 0' '[[ $1 == --list-cmds=deprecated ]] && exit 1'; do
    printf '#!/bin/bash\n%s\nexec %q "$@"\n' "$body" "$real" >"$STUB_DIR/git"
    chmod +x "$STUB_DIR/git"
    run_guard 'git status'
    [ "$status" -eq 2 ]
    [[ $output == *"could not read the list of git commands"* ]]
  done
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
  [[ $output == *"changed after the last tracking verification"*"$WORK/a.sh"* ]]
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

@test "denies a commit when git status fails" {
  commit_file a.sh
  seal "$(date +%s%N)" "$WORK/a.sh"
  local real
  real=$(command -v git)
  rm "$STUB_DIR/git"
  # shellcheck disable=SC2016
  printf '#!/bin/bash\nfor a; do [[ $a == status ]] && exit 128; done\nexec %q "$@"\n' "$real" >"$STUB_DIR/git"
  chmod +x "$STUB_DIR/git"
  run_guard 'git add a.sh && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"git status failed"* ]]
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

@test "reads an abbreviated long option that widens what add or commit takes" {
  commit_file a.sh
  commit_file b.sh
  printf 'v2\n' >"$WORK/a.sh"
  printf 'v2\n' >"$WORK/b.sh"
  seal "$(date +%s%N)" "$WORK/a.sh" "$WORK/b.sh"
  printf 'v3\n' >"$WORK/b.sh"
  printf 'x\n' >"$WORK/other.md"
  local c
  for c in 'git add -u && git commit -m x' 'git add -vu && git commit -m x' 'git add --upd && git commit -m x' 'git add --renormalize && git commit -m x' 'git add --renorm && git commit -m x'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"$WORK/b.sh"* ]]
    [[ $output != *other.md* ]]
  done
  for c in 'git add -vA && git commit -m x' 'git commit -p -m x' 'git commit -vp -m x' 'git add --al && git commit -m x' 'git add --no-ignore-r && git commit -m x' 'git add --patc && git commit -m x' 'git add --ed && git commit -m x' 'git add --pathspec-fr=list && git commit -m x' 'git commit --interac -m x' 'git commit --patc -m x'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"$WORK/other.md"* ]]
  done
}

@test "checks a tracked symlink the commit takes, not its target" {
  printf 'a\n' >"$WORK/a.sh"
  printf 'b\n' >"$WORK/b.sh"
  ln -s a.sh "$WORK/link"
  git -C "$WORK" add a.sh b.sh link
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
  seal "$(date +%s%N)" "$WORK/link"
  ln -sfn b.sh "$WORK/link"
  run_guard 'git add link && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/link"* ]]
  run_guard 'git add ./link/ && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/link"* ]]
}

@test "checks the files under a symlinked directory named as a pathspec" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'v3\n' >"$WORK/a.sh"
  ln -s "$WORK" "$FAKE_HOME/proj"
  local c
  for c in "git add $FAKE_HOME/proj && git commit -m x" "git add $FAKE_HOME/proj/ && git commit -m x"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"$WORK/a.sh"* ]]
  done
}

@test "denies a command that writes before the commit it holds" {
  commit_file a.sh
  seal "$(date +%s%N)" "$WORK/a.sh"
  local c
  # shellcheck disable=SC2016
  for c in 'printf x > a.sh && git add a.sh && git commit -m x' 'git add a.sh && sed -i s/v1/v2/ a.sh && git commit -m x' 'git add a.sh && git commit -m x > log' 'git status && git add a.sh && git commit -m x' 'cp b.sh a.sh; git commit -am x' 'printf x > a.sh; git commit -m -h -a' 'X=1; git commit -m x' 'PATH=/tmp/p:$PATH; git commit -m x' 'X=1 && git add a.sh && git commit -m x' 'git commit -m "$(printf x > a.sh)"' "cd $WORK/new && git init -q && printf x > f && git add f && git commit -m x"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"only cd or pushd and git add, rm, mv or commit"* ]]
  done
}

@test "denies a commit block holding another command even outside any repository" {
  OTHER=$(realpath "$(mktemp -d)")
  run_guard "\$'\\x63\\x64' $WORK; git add -A && git commit -m x" "$OTHER"
  rm -rf "$OTHER"
  [ "$status" -eq 2 ]
  [[ $output == *"only cd or pushd and git add, rm, mv or commit"* ]]
}

@test "passes a commit block of cd, pushd and git add, rm, mv and commit" {
  commit_file a.sh
  commit_file c.sh
  seal "$(date +%s%N)" "$WORK/a.sh"
  local c
  for c in "cd $WORK && git add a.sh && git commit -m x" "pushd $WORK && git add a.sh && git commit -m x" 'SKIP=metadata-only git commit -m x' 'git rm --cached c.sh && git commit -m x' 'git mv c.sh d.sh && git commit -m x' 'git add -h | head -3; git commit -h | head -3' 'git add -h 2>&1 | head -3; git commit -h 2>&1 | head -3'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "checks the whole tree when a pathspec cannot be resolved" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  local c
  # shellcheck disable=SC2016
  for c in 'git add "a.sh" && git commit -m "fix: x"' 'git add *.sh && git commit -m x' 'git add :/ && git commit -m x' 'git add $f && git commit -m x' 'git add a\.sh && git commit -m x'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"$WORK/other.md"* ]]
  done
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
  run_guard 'cd my\ dir && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"plain path"* ]]
}

@test "denies a command holding commits in two directories, whose tracking check reads one repository" {
  commit_file a.sh
  OTHER=$(realpath "$(mktemp -d)")
  git init -q "$OTHER"
  printf 'v1\n' >"$OTHER/b.sh"
  git -C "$OTHER" add -- b.sh
  git -C "$OTHER" -c user.name=t -c user.email=t@t commit -qm init
  seal "$(date +%s%N)" "$WORK/a.sh" "$OTHER/b.sh"
  printf 'v2\n' >"$WORK/a.sh"
  run_guard "cd $WORK && git add a.sh && git commit -m x && cd $OTHER && git add b.sh && git commit -m y"
  rm -rf "$OTHER"
  [ "$status" -eq 2 ]
  [[ $output == *"one commit per command"* ]]
}

@test "passes two commits in the same directory, whose paths are all checked" {
  commit_file a.sh
  commit_file b.sh
  seal "$(date +%s%N)" "$WORK/a.sh" "$WORK/b.sh"
  run_guard 'git add a.sh && git commit -m x && git add b.sh && git commit -m y'
  [ "$status" -eq 0 ]
  printf 'v2\n' >"$WORK/a.sh"
  run_guard 'git add a.sh && git commit -m x && git add b.sh && git commit -m y'
  [ "$status" -eq 2 ]
  [[ $output == *"a.sh"* ]]
}

@test "passes a memory commit into another repository while a file there changes that the commit does not take" {
  commit_file claude/.claude/hooks/inject-rules.sh
  mkdir -p "$WORK/claude/.claude/memory"
  rm -rf "$FAKE_HOME/.claude/memory"
  ln -s "$WORK/claude/.claude/memory" "$FAKE_HOME/.claude/memory"
  ln -s "$WORK" "$FAKE_HOME/dotfiles"
  OTHER=$(realpath "$(mktemp -d)")
  git init -q "$OTHER"
  printf 'x\n' >"$OTHER/filetree.lua"
  printf 'x\n' >"$WORK/claude/.claude/memory/feedback_x.md"
  seal "$(date +%s%N)" "$OTHER/filetree.lua" "$WORK/claude/.claude/memory/feedback_x.md"
  printf 'v2\n' >"$WORK/claude/.claude/hooks/inject-rules.sh"
  mkdir -p "$WORK/_meta/tests"
  printf 'x\n' >"$WORK/_meta/tests/inject-rules.bats"
  run_guard 'cd ~/dotfiles && git add claude/.claude/memory/feedback_x.md && git commit -m "docs(claude): x"' "$OTHER"
  rm -rf "$OTHER"
  [ "$status" -eq 0 ]
}

@test "resolves a pathspec from the directory a cd leads to" {
  commit_file sub/a.sh
  printf 'v2\n' >"$WORK/sub/a.sh"
  seal "$(date +%s%N)" "$WORK/sub/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard "cd $WORK/sub && git add a.sh && git commit -m x"
  [ "$status" -eq 0 ]
  printf 'v3\n' >"$WORK/sub/a.sh"
  run_guard "cd $WORK/sub && git add a.sh && git commit -m x"
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/sub/a.sh"* ]]
  [[ $output != *other.md* ]]
}

@test "reads git mv through its source paths" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git mv a.sh b.sh && git commit -m x'
  [ "$status" -eq 0 ]
  printf 'v3\n' >"$WORK/a.sh"
  run_guard 'git mv -f -- a.sh b.sh && git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"$WORK/a.sh"* ]]
  [[ $output != *other.md* ]]
}

@test "leaves out of a fallback the session's writes in another repository" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  value=$(date +%s%N)
  seal "$value" "$WORK/a.sh"
  OTHER=$(realpath "$(mktemp -d)")
  git init -q "$OTHER"
  printf 'x\n' >"$OTHER/code.sh"
  write_at "$((value + 1000))" "$OTHER/code.sh"
  run_guard 'git add -A && git commit -m x'
  rm -rf "$OTHER"
  [ "$status" -eq 0 ]
}

@test "denies a commit after popd, whose directory the guard does not track" {
  mkdir -p "$WORK/sub"
  run_guard "pushd $WORK/sub && popd && git commit -m x"
  [ "$status" -eq 2 ]
  [[ $output == *"plain path"* ]]
}

@test "denies a commit after a directory change the guard cannot follow" {
  local c
  for c in 'builtin cd /tmp && git commit -m x' 'command cd /tmp && git commit -m x' 'builtin pushd /tmp && git commit -m x' '\cd /tmp && git commit -m x' "'cd' /tmp && git commit -m x" 'pushd +1 && git commit -m x' 'CDPATH=/tmp; cd sub && git commit -m x' 'export CDPATH=/tmp; cd sub && git commit -m x' 'HOME=/tmp; cd && git commit -m x' 'HOME=/tmp cd && git commit -m x' 'HOME=/tmp; git add ~/a.sh && git commit -m x'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"plain path"* ]]
  done
}

@test "does not read a lookup or a word HOME as a directory change" {
  local c
  # shellcheck disable=SC2016
  for c in 'command -v git && git commit -m x' 'printf %s "$HOME" && git commit -m x'; do
    run_guard "$c"
    [[ $output != *"plain path"* ]]
  done
  run_guard "cd $WORK && git commit -m x"
  [ "$status" -eq 0 ]
}

@test "names a path the verification never sealed as possibly another session's, to leave out" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git add . && git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"never sealed"*"$WORK/other.md"* ]]
  [[ $output == *"another session"* ]]
  [[ $output == *"out of the staging command"* ]]
  [[ $output != *"$WORK/a.sh"* ]]
  [[ $output != *"runs the tracking verifier"* ]]
}

@test "separates the files changed since the verification from the files it never sealed" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'v3\n' >"$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_guard 'git add . && git commit -m "fix: x"'
  [ "$status" -eq 2 ]
  [[ $output == *"changed after the last tracking verification"*"$WORK/a.sh"*"runs the tracking verifier"* ]]
  [[ $output == *"never sealed"*"another session"*"$WORK/other.md"*"out of the staging command"* ]]
}

@test "--verdict prints the class and path of each stale file the commit takes, and exits 0" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'v3\n' >"$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_verdict 'git add . && git commit -m "fix: x"'
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'changed\t%s\nunsealed\t%s' "$WORK/a.sh" "$WORK/other.md")" ]
}

@test "--verdict prints nothing and exits 0 when the commit takes nothing stale" {
  commit_file a.sh
  printf 'v2\n' >"$WORK/a.sh"
  seal "$(date +%s%N)" "$WORK/a.sh"
  printf 'x\n' >"$WORK/other.md"
  run_verdict 'git add a.sh && git commit -m x'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--verdict stays silent and exits 1 when it judged no commit, so the gate falls back" {
  commit_file a.sh
  seal "$(date +%s%N)" "$WORK/a.sh"
  local c
  for c in 'git status' 'git add a.sh' 'rg -n commit src/'; do
    run_verdict "$c"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
  done
  run_verdict 'git commit -m x' /tmp
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "--verdict stays silent and exits 1 on every other refusal" {
  # shellcheck disable=SC2016
  for c in 'git -C . commit -m x' 'git commit --amend --no-edit' 'git add . && git push' 'cd "$x" && git commit -m x' $'git status # don\'t\ngit commit -m x' "bash -c 'git commit -m x'"; do
    run_verdict "$c"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
  done
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

@test "denies plumbing and history tools that move a ref or HEAD, in every form" {
  local c
  for c in 'git replay --onto main topic~2..topic' 'git replay --contained --onto main base..topic' 'git filter-branch -f --msg-filter cat HEAD' 'git bisect start' 'git bisect start HEAD HEAD~5' 'git bisect good' 'git bisect reset' 'git bisect log' 'git send-pack origin refs/heads/main'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"leave it to the user"* ]]
  done
}

@test "denies a worktree add whose commit-ish is no local commit, where git would track a remote branch" {
  commit_file a.sh
  git -C "$WORK" update-ref refs/remotes/origin/topic HEAD
  git -C "$WORK" branch local-only
  local c
  # shellcheck disable=SC2016
  for c in 'git worktree add ../x topic' 'git worktree add -q ../x topic' 'git worktree add ../x "$b"' 'git -C "my dir" worktree add ../x local-only' 'git --git-dir=.git worktree add ../x local-only'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"leave it to the user"* ]]
  done
  for c in 'git worktree add ../x local-only' 'git worktree add ../x origin/topic' 'git worktree add --detach ../x topic' 'git -C . worktree add ../x HEAD~0'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
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

@test "denies an alias whatever its case and through chains" {
  git -C "$WORK" config alias.sw switch
  git -C "$WORK" config alias.a2 sw
  git -C "$WORK" config alias.l1 l2
  git -C "$WORK" config alias.l2 l1
  for c in 'git SW main' 'git a2 main' 'git l1'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"not a command git lists"* ]]
  done
}

@test "denies a quoted or variable subcommand" {
  run_guard "git 'push'"
  [ "$status" -eq 2 ]
  # shellcheck disable=SC2016
  run_guard 'git $verb origin'
  [ "$status" -eq 2 ]
  run_guard "bash -c 'git \"\"'"
  [ "$status" -eq 2 ]
  [[ $output != *"bad array subscript"* ]]
}

@test "reads an apostrophe in a comment or a heredoc body as text, and a quoted heredoc body as no command" {
  run_guard $'git status # don\'t\ngit -C . push'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
  run_guard $'git commit -F - <<\'EOF\'\nfix: x\n\ngit push stays with the user, don\'t\nEOF'
  [ "$status" -eq 0 ]
  run_guard $'cat <<\'EOF\'\n$(git push)\nEOF'
  [ "$status" -eq 0 ]
}

@test "reads the substitutions of an unquoted heredoc body as commands" {
  run_guard $'cat <<EOF\n$(git push origin main)\nEOF'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
  run_guard $'cat <<EOF\n`git tag v1`\nEOF'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
}

@test "denies a command naming git that shfmt cannot parse, and passes one that does not name git" {
  run_guard $'git status; echo "unclosed'
  [ "$status" -eq 2 ]
  [[ $output == *"shfmt cannot parse"* ]]
  run_guard $'echo $\'x\' "unclosed'
  [ "$status" -eq 0 ]
}

@test "denies every git command when shfmt is missing" {
  rm "$STUB_DIR/shfmt"
  run_guard 'git status'
  [ "$status" -eq 2 ]
  [[ $output == *"shfmt is missing"* ]]
  run_guard 'rg -n foo src/'
  [ "$status" -eq 0 ]
}

@test "scopes a cd inside a subshell to that subshell" {
  commit_file a.sh
  seal "$(date +%s%N)" "$WORK/a.sh"
  OTHER=$(realpath "$(mktemp -d)")
  git init -q "$OTHER"
  printf 'x\n' >"$OTHER/new.md"
  local c
  for c in "(cd $OTHER); git add -A && git commit -m x" "{ (cd $OTHER); } && git add -A && git commit -m x"; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
  run_guard "cd $OTHER && git add -A && git commit -m x"
  rm -rf "$OTHER"
  [ "$status" -eq 2 ]
  [[ $output == *"$OTHER/new.md"* ]]
}

@test "reads a git call across a line continuation" {
  run_guard $'git \\\n  push origin main'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
  run_guard $'git -c \\\n  alias.p=push p origin main'
  [ "$status" -eq 2 ]
  [[ $output == *"not a command git lists"* ]]
  run_guard $'env \\\n  git commit -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"wrapper env"* ]]
  run_guard $'git commit \\\n  --amend --no-edit'
  [ "$status" -eq 2 ]
  [[ $output == *"--amend"* ]]
  run_guard $'git commit \\\n  -n -m x'
  [ "$status" -eq 2 ]
  [[ $output == *"--no-verify"* ]]
  run_guard $'git commit -m fix#1 \\\n  --amend'
  [ "$status" -eq 2 ]
  [[ $output == *"--amend"* ]]
}

@test "passes a git command split over lines by a continuation" {
  run_guard $'git \\\n  commit -m "fix: x"'
  [ "$status" -eq 0 ]
  run_guard $'git log \\\n  --oneline -5'
  [ "$status" -eq 0 ]
}

@test "does not join the line after a comment or an escaped backslash" {
  run_guard $'git status # see \\\ngit push'
  [ "$status" -eq 2 ]
  [[ $output == *"comment ending in a backslash"* ]]
  run_guard $'echo a\\\\\ngit push'
  [ "$status" -eq 2 ]
  [[ $output == *"leave it to the user"* ]]
}

@test "denies a forced add, whose ignored file git status leaves out of the tracking check" {
  printf 'secret.txt\n' >"$WORK/.gitignore"
  git -C "$WORK" add -- .gitignore
  git -C "$WORK" -c user.name=t -c user.email=t@t commit -qm init
  printf 'v1\n' >"$WORK/secret.txt"
  seal "$(date +%s%N)" "$WORK/secret.txt"
  printf 'v2\n' >"$WORK/secret.txt"
  local c
  for c in 'git add -f secret.txt && git commit -m x' 'git add --force secret.txt && git commit -m x' 'git add -vf secret.txt && git commit -m x' 'git add --for secret.txt && git commit -m x'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"without -f"* ]]
  done
  run_guard 'git rm -f a.sh && git commit -m x'
  [ "$status" -ne 2 ] || [[ $output != *"without -f"* ]]
}

@test "denies git commands that disarm the hooks or overwrite the working tree" {
  local c
  for c in 'git config core.hooksPath /dev/null' 'git config --global core.hooksPath /dev/null' 'git config --add core.HooksPath /dev/null' 'git apply -R p.diff' 'git apply --reverse p.diff' 'git checkout-index -f -a' 'git checkout-index --force -a' 'git read-tree --reset -u HEAD~1' 'git read-tree -um HEAD'; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"leave it to the user"* ]]
  done
  run_guard "bash -c 'git config core.hooksPath /dev/null'"
  [ "$status" -eq 2 ]
  [[ $output == *"shell string"* ]]
}

@test "passes the read and non-destructive forms of config, apply, read-tree and checkout-index" {
  local c
  for c in 'git config --get filter.t.clean' 'git config core.hooksPath' 'git config --get core.hooksPath' 'git config --unset core.hooksPath' 'git config user.name a' 'git config --list' 'git apply p.diff' 'git read-tree HEAD' 'git checkout-index -a'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
}

@test "denies plumbing that moves a branch or HEAD" {
  local c
  # shellcheck disable=SC2016
  for c in 'git update-index --add f && git update-ref HEAD $(git commit-tree $(git write-tree) -p HEAD -m x)' 'git update-ref refs/heads/main abc123' 'git update-ref -d refs/heads/old' "printf 'commit refs/heads/main\n' | git fast-import" 'git symbolic-ref HEAD refs/heads/other' 'git symbolic-ref -m why HEAD refs/heads/other' 'git symbolic-ref --delete refs/heads/alias' 'git symbolic-ref --del refs/heads/alias' 'git symbolic-ref --dele refs/heads/alias' 'git symbolic-ref -qd refs/heads/alias' 'git worktree add ../x' 'git worktree add --lock --reason why ../x' 'git worktree add -b topic ../x HEAD' 'git worktree add -B topic ../x' 'git worktree add --orphan topic ../x' 'git worktree add --track -b t ../x origin/t' 'git fetch . HEAD:refs/heads/topic' 'git fetch -u origin main:main' 'git fetch -qu origin' "git fetch --refmap='+refs/heads/*:refs/heads/*' origin main"; do
    run_guard "$c"
    [ "$status" -eq 2 ]
    [[ $output == *"leave it to the user"* ]]
  done
  run_guard "bash -c 'git worktree add ../x'"
  [ "$status" -eq 2 ]
  [[ $output == *"shell string"* ]]
}

@test "passes plumbing that reads, or touches only the index and objects" {
  commit_file a.sh
  git -C "$WORK" tag v1.1.5
  local c
  for c in 'git symbolic-ref HEAD' 'git symbolic-ref --short -q HEAD' 'git symbolic-ref --short HEAD 2>/dev/null' 'git symbolic-ref HEAD 2> /dev/null' 'git branch -a --contains HEAD 2>&1' 'git worktree list' 'git worktree add -q --detach ../x v1.1.5' 'git -C . worktree add -q --detach ../x 1.1.5 2>&1' 'git worktree add ../x v1.1.5' 'git worktree prune' 'git update-index --refresh' 'git write-tree' 'git rev-parse HEAD' 'git fetch -q origin' 'git fetch --tags -q origin' 'git fetch --dry-run' 'git fetch git@github.com:user/repo.git main'; do
    run_guard "$c"
    [ "$status" -eq 0 ]
  done
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
