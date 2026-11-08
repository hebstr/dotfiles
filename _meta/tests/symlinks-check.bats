#!/usr/bin/env bats

setup() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
  export HOME="$TEST_DIR"
  export SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/symlinks-check"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "exits 0 with no output when no symlinks exist" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 with no output when all dotfiles symlinks are valid" {
  mkdir -p "$HOME/dotfiles/bin"
  touch "$HOME/dotfiles/bin/foo"
  ln -s "$HOME/dotfiles/bin/foo" "$HOME/.foo"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 1 and prints BROKEN when a dotfiles symlink target is missing" {
  ln -s "$HOME/dotfiles/bin/missing" "$HOME/.broken"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BROKEN"* ]]
  [[ "$output" == *".broken"* ]]
}

@test "ignores broken symlinks not pointing to dotfiles" {
  ln -s "/nonexistent/path/elsewhere" "$HOME/.other-broken"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "reports a broken dotfiles symlink inside the Firefox profile" {
  mkdir -p "$HOME/.mozilla/firefox/z24d9fn6.default-release"
  ln -s "$HOME/dotfiles/firefox/.mozilla/firefox/z24d9fn6.default-release/user.js" \
    "$HOME/.mozilla/firefox/z24d9fn6.default-release/user.js"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BROKEN"* ]]
  [[ "$output" == *"user.js"* ]]
}

@test "ignores the Firefox runtime lock symlink" {
  mkdir -p "$HOME/.mozilla/firefox/z24d9fn6.default-release"
  ln -s "127.0.1.1:+386514" "$HOME/.mozilla/firefox/z24d9fn6.default-release/lock"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "reports a broken dotfiles symlink whose name contains a newline" {
  ln -s "$HOME/dotfiles/bin/missing" "$HOME/.two
lines"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"BROKEN"* ]]
  [[ "$output" == *"lines"* ]]
}

@test "ignores broken symlinks pointing to paths with dotfiles as substring" {
  ln -s "/tmp/dotfiles_backup/foo" "$HOME/.substring-trap"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# The missing-link half needs stow and reads $HOME/dotfiles as the stow dir, so
# each fixture below builds a package tree there and links from $HOME by hand.
# A package counts as deployed on the machine when one of its own files already
# resolves through a link, which is what keeps bash-cpd and the absent desktop
# applications from being demanded everywhere.

@test "exits 0 when every file of a deployed package is linked" {
  command -v stow >/dev/null || skip "stow not installed"
  mkdir -p "$HOME/dotfiles/bin/.local/bin" "$HOME/.local/bin"
  touch "$HOME/dotfiles/bin/.local/bin/foo"
  ln -s "$HOME/dotfiles/bin/.local/bin/foo" "$HOME/.local/bin/foo"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 1 and prints MISSING for an unlinked file of a deployed package" {
  command -v stow >/dev/null || skip "stow not installed"
  mkdir -p "$HOME/dotfiles/bin/.local/bin" "$HOME/.local/bin"
  touch "$HOME/dotfiles/bin/.local/bin/foo" "$HOME/dotfiles/bin/.local/bin/bar"
  ln -s "$HOME/dotfiles/bin/.local/bin/foo" "$HOME/.local/bin/foo"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"MISSING"* ]]
  [[ "$output" == *".local/bin/bar"* ]]
  [[ "$output" == *"stow --no-folding bin"* ]]
}

@test "says nothing about a package no link of its own resolves into" {
  command -v stow >/dev/null || skip "stow not installed"
  mkdir -p "$HOME/dotfiles/firefox/.mozilla/firefox/z24d9fn6.default-release"
  touch "$HOME/dotfiles/firefox/.mozilla/firefox/z24d9fn6.default-release/user.js"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "names the plain stow form for a folded package" {
  command -v stow >/dev/null || skip "stow not installed"
  mkdir -p "$HOME/dotfiles/claude/.claude/skills/one" "$HOME/.claude/skills"
  mkdir -p "$HOME/dotfiles/claude/.claude/skills/two"
  touch "$HOME/dotfiles/claude/.claude/skills/one/SKILL.md"
  touch "$HOME/dotfiles/claude/.claude/skills/two/SKILL.md"
  ln -s "$HOME/dotfiles/claude/.claude/skills/one" "$HOME/.claude/skills/one"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"skills/two"* ]]
  [[ "$output" == *"stow claude"* ]]
  [[ "$output" != *"stow --no-folding claude"* ]]
}

@test "ignores a file git ignores, and reports the one beside it" {
  command -v stow >/dev/null || skip "stow not installed"
  mkdir -p "$HOME/dotfiles/git/.config/git/__pycache__" "$HOME/.config/git"
  touch "$HOME/dotfiles/git/.config/git/filter.py"
  touch "$HOME/dotfiles/git/.config/git/__pycache__/filter.pyc"
  touch "$HOME/dotfiles/git/.config/git/other.py"
  ln -s "$HOME/dotfiles/git/.config/git/filter.py" "$HOME/.config/git/filter.py"
  printf '%s\n' '**/__pycache__/' >"$HOME/dotfiles/.gitignore"
  git -C "$HOME/dotfiles" init -q
  git -C "$HOME/dotfiles" add -A

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"other.py"* ]]
  [[ "$output" != *"pycache"* ]]
}

@test "treats _meta as no package of its own" {
  command -v stow >/dev/null || skip "stow not installed"
  mkdir -p "$HOME/dotfiles/bin/.local/bin" "$HOME/.local/bin"
  mkdir -p "$HOME/dotfiles/_meta/tests"
  touch "$HOME/dotfiles/bin/.local/bin/foo" "$HOME/dotfiles/bin/.local/bin/bar"
  touch "$HOME/dotfiles/_meta/tests/some.bats"
  ln -s "$HOME/dotfiles/bin/.local/bin/foo" "$HOME/.local/bin/foo"

  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *".local/bin/bar"* ]]
  [[ "$output" != *"some.bats"* ]]
}
