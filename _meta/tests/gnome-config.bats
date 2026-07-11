#!/usr/bin/env bats

# Tests for gnome-config
# Mocks: dconf — a PATH stub that logs calls and returns path-specific dump
# output, so the per-domain curation filters can be exercised. HOME is
# redirected; the real dconf is never reached, no real config is touched.
# Restore tests write tiny backups to the real /tmp (the script hardcodes it);
# they are harmless and left in place to avoid deleting genuine user backups.

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/gnome-config"
PROFILES="dotfiles/_meta/profiles/gnome"

setup() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
  export HOME="$TEST_DIR"
  export DCONF_LOG="$TEST_DIR/dconf-calls.log"
  export PATH="$TEST_DIR/bin:$PATH"
  mkdir -p "$TEST_DIR/bin"
  mkdir -p "$TEST_DIR/$PROFILES"

  # Stub dconf: log every call; `dump` returns content keyed on the path so
  # curation (gsconnect / tablets stripping) is observable; `read` and `load`
  # cover the shell domain and restore.
  cat >"$TEST_DIR/bin/dconf" <<STUB
#!/usr/bin/env bash
echo "\$@" >>"$DCONF_LOG"
case "\$1" in
dump)
  case "\$2" in
  */shell/extensions/)
    printf '[dash-to-dock]\ndock-position=%s\n\n[gsconnect]\ncertificate-pem=%s\n\n[gsconnect/device/abc]\npaired=true\n' "'LEFT'" "'SECRET'"
    ;;
  */peripherals/)
    printf '[mouse]\nspeed=0.0\n\n[tablets/056a:1]\narea=%s\n\n[touchpad]\ntap-to-click=true\n' "[0.0]"
    ;;
  *)
    printf '[/]\nkey=value\n'
    ;;
  esac
  ;;
read) printf "['x']\n" ;;
load) cat >/dev/null ;;
esac
STUB
  chmod +x "$TEST_DIR/bin/dconf"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- CLI surface --------------------------------------------------------------

@test "no args prints usage and exits 0" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: gnome-config"* ]]
}

@test "--help lists all subcommands and domains" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"dump"* ]]
  [[ "$output" == *"restore"* ]]
  [[ "$output" == *"diff"* ]]
  [[ "$output" == *"terminal"* ]]
  [[ "$output" == *"tracker"* ]]
}

@test "unknown command exits 1 with error message" {
  run "$SCRIPT" bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command: bogus"* ]]
}

@test "unknown domain exits 1 and lists known domains" {
  run "$SCRIPT" dump bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown domain: bogus"* ]]
  [[ "$output" == *"Known domains:"* ]]
}

@test "an unknown domain among valid ones aborts before writing any file" {
  run "$SCRIPT" dump terminal bogus
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown domain: bogus"* ]]
  # validation runs fully before any write: a typo applies nothing partially
  [ ! -f "$HOME/$PROFILES/terminal.dconf" ]
}

# --- dump ---------------------------------------------------------------------

@test "dump of one domain writes its file" {
  run "$SCRIPT" dump terminal
  [ "$status" -eq 0 ]
  [ -f "$HOME/$PROFILES/terminal.dconf" ]
  grep -q "^\[/\]" "$HOME/$PROFILES/terminal.dconf"
}

@test "dump invokes dconf dump with the domain path" {
  run "$SCRIPT" dump terminal
  [ "$status" -eq 0 ]
  grep -q "^dump /org/gnome/terminal/" "$DCONF_LOG"
}

@test "dump of several explicit domains writes each file" {
  run "$SCRIPT" dump terminal tracker
  [ "$status" -eq 0 ]
  [ -f "$HOME/$PROFILES/terminal.dconf" ]
  [ -f "$HOME/$PROFILES/tracker.dconf" ]
}

@test "dump with no domain writes every domain file" {
  run "$SCRIPT" dump
  [ "$status" -eq 0 ]
  [ -f "$HOME/$PROFILES/desktop-interface.dconf" ]
  [ -f "$HOME/$PROFILES/tracker.dconf" ]
  [ -f "$HOME/$PROFILES/shell.dconf" ]
}

@test "dump creates the profiles directory if missing" {
  rm -rf "$HOME/dotfiles/_meta"
  run "$SCRIPT" dump terminal
  [ "$status" -eq 0 ]
  [ -d "$HOME/$PROFILES" ]
}

# --- curation -----------------------------------------------------------------

@test "shell dump is the two curated keys only, not a full dump" {
  run "$SCRIPT" dump shell
  [ "$status" -eq 0 ]
  # curation reads the two keys directly, never dumps the noisy subtree
  grep -q "^read /org/gnome/shell/enabled-extensions" "$DCONF_LOG"
  grep -q "^read /org/gnome/shell/favorite-apps" "$DCONF_LOG"
  run ! grep -q "^dump /org/gnome/shell/$" "$DCONF_LOG"
  run cat "$HOME/$PROFILES/shell.dconf"
  [ "${lines[0]}" = "[/]" ]
  [ "${lines[1]}" = "enabled-extensions=['x']" ]
  [ "${lines[2]}" = "favorite-apps=['x']" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "shell dump omits an unset key instead of emitting an empty-value line" {
  # dconf read on an unset key prints nothing (exit 0). A bare
  # `enabled-extensions=` line is invalid GVariant and crashes `dconf load` at
  # restore, so the dump must skip the key entirely like `dconf dump` does.
  cat >"$TEST_DIR/bin/dconf" <<'STUB'
#!/usr/bin/env bash
case "$1" in
read)
  case "$2" in
  */enabled-extensions) : ;;
  */favorite-apps) printf "['x']\n" ;;
  esac
  ;;
esac
STUB
  chmod +x "$TEST_DIR/bin/dconf"
  run "$SCRIPT" dump shell
  [ "$status" -eq 0 ]
  run ! grep -q '^enabled-extensions=$' "$HOME/$PROFILES/shell.dconf"
  run cat "$HOME/$PROFILES/shell.dconf"
  [ "${lines[0]}" = "[/]" ]
  [ "${lines[1]}" = "favorite-apps=['x']" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "shell-extensions dump strips gsconnect but keeps other extensions" {
  run "$SCRIPT" dump shell-extensions
  [ "$status" -eq 0 ]
  local f="$HOME/$PROFILES/shell-extensions.dconf"
  grep -q "^\[dash-to-dock\]" "$f"
  run ! grep -q "gsconnect" "$f"
  run ! grep -q "certificate-pem" "$f"
}

@test "shell-extensions round-trips through the gsconnect filter" {
  "$SCRIPT" dump shell-extensions
  run "$SCRIPT" diff shell-extensions
  [ "$status" -eq 0 ]
}

@test "peripherals dump strips tablet blocks but keeps mouse and touchpad" {
  run "$SCRIPT" dump peripherals
  [ "$status" -eq 0 ]
  local f="$HOME/$PROFILES/peripherals.dconf"
  grep -q "^\[mouse\]" "$f"
  grep -q "^\[touchpad\]" "$f"
  run ! grep -q "tablets" "$f"
}

# --- restore ------------------------------------------------------------------

@test "restore exits 1 when no dump file exists" {
  run "$SCRIPT" restore terminal
  [ "$status" -eq 1 ]
  [[ "$output" == *"No dump file"* ]]
}

@test "restore backs up current state to /tmp before loading" {
  printf '[/]\nkey=value\n' >"$HOME/$PROFILES/terminal.dconf"
  run "$SCRIPT" restore terminal
  [ "$status" -eq 0 ]
  [[ "$output" == *"backed up terminal to /tmp/gnome-config-backup-terminal-"* ]]
}

@test "restore invokes dconf load with the domain path" {
  printf '[/]\nkey=value\n' >"$HOME/$PROFILES/terminal.dconf"
  run "$SCRIPT" restore terminal
  [ "$status" -eq 0 ]
  grep -q "^load /org/gnome/terminal/" "$DCONF_LOG"
}

# --- diff ---------------------------------------------------------------------

@test "diff exits 1 when no dump file exists" {
  run "$SCRIPT" diff terminal
  [ "$status" -eq 1 ]
  [[ "$output" == *"No dump file"* ]]
}

@test "diff exits 0 when saved dump matches live state" {
  "$SCRIPT" dump terminal
  run "$SCRIPT" diff terminal
  [ "$status" -eq 0 ]
}

@test "diff exits 1 and shows the delta when saved dump drifts" {
  printf '[/]\nkey=STALE\n' >"$HOME/$PROFILES/terminal.dconf"
  run "$SCRIPT" diff terminal
  [ "$status" -eq 1 ]
  [[ "$output" == *"key=value"* ]]
  [[ "$output" == *"key=STALE"* ]]
}
