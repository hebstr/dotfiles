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

@test "ignores broken symlinks pointing to paths with dotfiles as substring" {
  ln -s "/tmp/dotfiles_backup/foo" "$HOME/.substring-trap"

  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
