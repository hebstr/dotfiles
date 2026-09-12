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
