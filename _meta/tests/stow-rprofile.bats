#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../../bin/.local/bin/stow-rprofile"

setup() {
  TMPDIR_TEST=$(mktemp -d)
  export TMPDIR_TEST
  export PATH="$TMPDIR_TEST/bin:$PATH"
  mkdir -p "$TMPDIR_TEST/bin"

  export HOME="$TMPDIR_TEST/home"
  mkdir -p "$HOME/dotfiles/_meta/profiles"
  touch "$HOME/dotfiles/_meta/profiles/Rprofile.site"

  export OPT_R="$TMPDIR_TEST/opt/R"
  mkdir -p "$OPT_R"

  cat >"$TMPDIR_TEST/bin/sudo" <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB
  chmod +x "$TMPDIR_TEST/bin/sudo"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

make_rig_stub() {
  {
    printf '#!/usr/bin/env bash\n'
    printf "printf '* name   version  aliases\\n'\n"
    printf "printf -- '------------------------------------------\\n'\n"
    for v in "$@"; do
      printf "printf '%s\\n'\n" "$v"
    done
  } >"$TMPDIR_TEST/bin/rig"
  chmod +x "$TMPDIR_TEST/bin/rig"
}

make_r_dir() {
  mkdir -p "$OPT_R/$1/lib/R/etc"
}

# ---------------------------------------------------------------------------
# Guard: template missing
# ---------------------------------------------------------------------------

@test "exits 1 when Rprofile.site template is missing" {
  rm "$HOME/dotfiles/_meta/profiles/Rprofile.site"
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Template not found"* ]]
}

# ---------------------------------------------------------------------------
# Guard: no versions found
# ---------------------------------------------------------------------------

@test "exits 1 when rig returns no versions" {
  make_rig_stub
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No R versions found"* ]]
}

@test "exits 1 when find finds no R directories" {
  run env PATH="$TMPDIR_TEST/bin:/usr/bin:/bin" HOME="$HOME" OPT_R="$OPT_R" "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No R versions found"* ]]
}

# ---------------------------------------------------------------------------
# rig path — version extraction
# ---------------------------------------------------------------------------

@test "extracts plain version from rig list" {
  make_rig_stub "  4.5.3"
  make_r_dir "4.5.3"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$OPT_R/4.5.3/lib/R/etc/Rprofile.site" ]
}

@test "extracts default version marked with star prefix" {
  make_rig_stub "* 4.6.0"
  make_r_dir "4.6.0"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$OPT_R/4.6.0/lib/R/etc/Rprofile.site" ]
}

@test "processes all versions including default" {
  make_rig_stub "  4.5.3" "* 4.6.0"
  make_r_dir "4.5.3"
  make_r_dir "4.6.0"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$OPT_R/4.5.3/lib/R/etc/Rprofile.site" ]
  [ -L "$OPT_R/4.6.0/lib/R/etc/Rprofile.site" ]
}

# ---------------------------------------------------------------------------
# find path
# ---------------------------------------------------------------------------

@test "falls back to find when rig is absent" {
  make_r_dir "4.5.3"
  run env PATH="$TMPDIR_TEST/bin:/usr/bin:/bin" HOME="$HOME" OPT_R="$OPT_R" "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$OPT_R/4.5.3/lib/R/etc/Rprofile.site" ]
}

# ---------------------------------------------------------------------------
# Symlink correctness
# ---------------------------------------------------------------------------

@test "symlink points to the template file" {
  make_rig_stub "  4.5.3"
  make_r_dir "4.5.3"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$OPT_R/4.5.3/lib/R/etc/Rprofile.site")" = "$HOME/dotfiles/_meta/profiles/Rprofile.site" ]
}

@test "overwrites an existing symlink on re-run" {
  make_rig_stub "  4.5.3"
  make_r_dir "4.5.3"
  ln -sf /dev/null "$OPT_R/4.5.3/lib/R/etc/Rprofile.site"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(readlink "$OPT_R/4.5.3/lib/R/etc/Rprofile.site")" = "$HOME/dotfiles/_meta/profiles/Rprofile.site" ]
}

# ---------------------------------------------------------------------------
# Output format
# ---------------------------------------------------------------------------

@test "prints version arrow path for each symlinked version" {
  make_rig_stub "  4.5.3"
  make_r_dir "4.5.3"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"4.5.3 -> $OPT_R/4.5.3/lib/R/etc/Rprofile.site"* ]]
}

# ---------------------------------------------------------------------------
# Missing directory — skip and continue
# ---------------------------------------------------------------------------

@test "skips version whose directory is absent and continues" {
  make_rig_stub "  4.5.3" "  4.6.0"
  make_r_dir "4.6.0"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping 4.5.3"* ]]
  [ -L "$OPT_R/4.6.0/lib/R/etc/Rprofile.site" ]
}
