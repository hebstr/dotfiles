#!/usr/bin/env bats

# Tests for gnome-terminal-config
# Mocks: dconf — no real config dump/load, no real /tmp backups (HOME redirected)

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/gnome-terminal-config"

setup() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
  export HOME="$TEST_DIR"
  export DCONF_LOG="$TEST_DIR/dconf-calls.log"
  export PATH="$TEST_DIR/bin:$PATH"
  mkdir -p "$TEST_DIR/bin"
  mkdir -p "$TEST_DIR/dotfiles/_meta/profiles"

  cat >"$TEST_DIR/bin/dconf" <<STUB
#!/usr/bin/env bash
echo "\$@" >>"$DCONF_LOG"
case "\$1" in
  dump) printf '[legacy]\nkey=value\n' ;;
  load) cat >/dev/null ;;
esac
STUB
  chmod +x "$TEST_DIR/bin/dconf"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "no args prints usage and exits 0" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: gnome-terminal-config"* ]]
}

@test "--help prints usage with all subcommands" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"dump"* ]]
  [[ "$output" == *"restore"* ]]
  [[ "$output" == *"diff"* ]]
}

@test "unknown command exits 1 with error message" {
  run "$SCRIPT" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command: bogus"* ]]
}

@test "dump writes dconf output to expected dotfiles path" {
  run "$SCRIPT" dump
  [ "$status" -eq 0 ]
  [ -f "$HOME/dotfiles/_meta/profiles/gnome-terminal.dconf" ]
  grep -q "^\[legacy\]" "$HOME/dotfiles/_meta/profiles/gnome-terminal.dconf"
}

@test "dump invokes dconf with the gnome-terminal path" {
  run "$SCRIPT" dump
  [ "$status" -eq 0 ]
  grep -q "^dump /org/gnome/terminal/" "$DCONF_LOG"
}

@test "dump creates _meta/profiles directory if missing" {
  rm -rf "$HOME/dotfiles/_meta"
  run "$SCRIPT" dump
  [ "$status" -eq 0 ]
  [ -d "$HOME/dotfiles/_meta/profiles" ]
}

@test "restore exits 1 when no dump file exists" {
  run "$SCRIPT" restore
  [ "$status" -eq 1 ]
  [[ "$output" == *"No dump file"* ]]
}

@test "restore backs up current state to /tmp before loading" {
  echo "[legacy]" >"$HOME/dotfiles/_meta/profiles/gnome-terminal.dconf"
  run "$SCRIPT" restore
  [ "$status" -eq 0 ]
  [[ "$output" == *"backed up to /tmp/gnome-terminal-backup-"* ]]
}

@test "restore invokes dconf load with the gnome-terminal path" {
  echo "[legacy]" >"$HOME/dotfiles/_meta/profiles/gnome-terminal.dconf"
  run "$SCRIPT" restore
  [ "$status" -eq 0 ]
  grep -q "^load /org/gnome/terminal/" "$DCONF_LOG"
}

@test "diff exits 1 when no dump file exists" {
  run "$SCRIPT" diff
  [ "$status" -eq 1 ]
  [[ "$output" == *"No dump file"* ]]
}

@test "diff exits 0 when stub dconf output matches saved dump" {
  "$SCRIPT" dump
  run "$SCRIPT" diff
  [ "$status" -eq 0 ]
}
