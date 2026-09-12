#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# Tests for bin/.local/bin/prek-metadata-only

bats_require_minimum_version 1.5.0

SCRIPT="${BATS_TEST_DIRNAME}/../../bin/.local/bin/prek-metadata-only"
DRIVER="${BATS_TEST_DIRNAME}/../../git/.config/git/out-textconv.py"

# Each test runs in a fresh repository under a git config of its own, so neither
# the user's global config nor a system one decides whether the driver exists.
setup() {
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_CONFIG_GLOBAL="${BATS_TEST_TMPDIR}/gitconfig"
  cat >"$GIT_CONFIG_GLOBAL" <<EOF
[user]
  name = test
  email = test@example.com
[init]
  defaultBranch = main
[diff "out-textconv"]
  textconv = ${DRIVER}
EOF

  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$REPO"
  cd "$REPO" || return 1
  git init -q .
  printf '%s\n' '*.docx diff=out-textconv' '*.png diff=out-textconv' >.gitattributes
}

# ─── fixture factories ──────────────────────────────────────────────────────
# Every option defaults, so a test names only what it varies.

_png() {
  local path=$1 second=1 pixel=10
  shift

  while (($#)); do
    case $1 in
    --second) second=$2 ;;
    --pixel) pixel=$2 ;;
    *) return 1 ;;
    esac
    shift 2
  done

  mkdir -p "$(dirname "$path")"
  SECOND="$second" PIXEL="$pixel" python3 - "$path" <<'EOF'
import os
import struct
import sys
import zlib


def chunk(name, data):
    return (
        struct.pack(">I", len(data))
        + name
        + data
        + struct.pack(">I", zlib.crc32(name + data))
    )


second, pixel = int(os.environ["SECOND"]), int(os.environ["PIXEL"])

blob = b"\x89PNG\r\n\x1a\n"
blob += chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
blob += chunk(b"tIME", struct.pack(">HBBBBB", 2026, 9, 12, 10, 0, second))
blob += chunk(b"IDAT", zlib.compress(b"\x00" + bytes([pixel]) * 3))
blob += chunk(b"IEND", b"")

with open(sys.argv[1], "wb") as out:
    out.write(blob)
EOF
}

_docx() {
  local path=$1 stamp=2026-09-12T16:00:00Z body="Age median"
  shift

  while (($#)); do
    case $1 in
    --stamp) stamp=$2 ;;
    --body) body=$2 ;;
    *) return 1 ;;
    esac
    shift 2
  done

  mkdir -p "$(dirname "$path")"
  STAMP="$stamp" BODY="$body" python3 - "$path" <<'EOF'
import os
import sys
import zipfile

stamp, body = os.environ["STAMP"], os.environ["BODY"]

with zipfile.ZipFile(sys.argv[1], "w") as package:
    package.writestr(
        "docProps/core.xml",
        "<cp:coreProperties>"
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{stamp}</dcterms:modified>'
        "</cp:coreProperties>",
    )
    package.writestr(
        "word/document.xml", f"<w:document><w:t>{body}</w:t></w:document>"
    )
EOF
}

_commit() {
  git add -A
  git commit -qm fixture
}

# ─── exit 1: metadata-only rewrites are refused ─────────────────────────────

@test "docx with a new timestamp only: exit 1, file listed" {
  _docx out/a.docx
  _commit
  _docx out/a.docx --stamp 2027-01-01T00:00:00Z
  git add out/a.docx

  run -1 "$SCRIPT" out/a.docx
  [[ "$output" == *"write metadata"* ]]
  [[ "$output" == *$'\n  out/a.docx\n'* ]]
}

@test "png with a new tIME chunk only: exit 1" {
  _png out/fig.png
  _commit
  _png out/fig.png --second 59
  git add out/fig.png

  run -1 "$SCRIPT" out/fig.png
  [[ "$output" == *$'\n  out/fig.png\n'* ]]
}

@test "mixed commit: only the metadata-only file is listed" {
  _docx out/noise.docx
  _docx out/real.docx
  _commit
  _docx out/noise.docx --stamp 2027-01-01T00:00:00Z
  _docx out/real.docx --body "Age median 65"
  git add -A

  run -1 "$SCRIPT" out/noise.docx out/real.docx
  [[ "$output" == *"out/noise.docx"* ]]
  [[ "$output" != *"out/real.docx"* ]]
}

@test "glob characters in a name: only the metadata-only file is listed" {
  _docx "out/fig[1].docx"
  _docx out/fig1.docx
  _commit
  _docx "out/fig[1].docx" --stamp 2027-01-01T00:00:00Z
  _docx out/fig1.docx --body "Age median 65"
  git add -A

  run -1 "$SCRIPT" "out/fig[1].docx" out/fig1.docx
  [[ "$output" == *$'\n  out/fig[1].docx\n'* ]]
  [[ "$output" != *$'\n  out/fig1.docx\n'* ]]
}

@test "type with no out-textconv attribute: exit 1, file listed" {
  _docx out/table.xlsx
  _commit
  _docx out/table.xlsx --stamp 2027-01-01T00:00:00Z
  git add out/table.xlsx

  run -1 "$SCRIPT" out/table.xlsx
  [[ "$output" == *"not routed through the out-textconv diff driver"* ]]
  [[ "$output" == *$'\n  out/table.xlsx\n'* ]]
}

# ─── exit 0: real changes and untouched cases pass ──────────────────────────

@test "docx with a body change: exit 0, no output" {
  _docx out/a.docx
  _commit
  _docx out/a.docx --body "Age median 65"
  git add out/a.docx

  run -0 "$SCRIPT" out/a.docx
  [ "$output" = "" ]
}

@test "non-ASCII name with a body change: exit 0, no output" {
  _docx out/résumé.docx
  _commit
  _docx out/résumé.docx --body "Age median 65"
  git add -A

  run -0 "$SCRIPT" out/résumé.docx
  [ "$output" = "" ]
}

@test "png with a pixel change: exit 0" {
  _png out/fig.png
  _commit
  _png out/fig.png --second 59 --pixel 200
  git add out/fig.png

  run -0 "$SCRIPT" out/fig.png
}

@test "added file: exit 0, even when identical to a tracked one" {
  _docx out/a.docx
  _commit
  cp out/a.docx out/2027-01-01_report.docx
  git add out/2027-01-01_report.docx

  run -0 "$SCRIPT" out/2027-01-01_report.docx
}

@test "metadata-only rewrite left unstaged: exit 0" {
  _docx out/a.docx
  _commit
  _docx out/a.docx --stamp 2027-01-01T00:00:00Z

  run -0 "$SCRIPT" out/a.docx
}

@test "staged metadata-only file not passed as argument: exit 0" {
  _docx out/a.docx
  _docx out/b.docx
  _commit
  _docx out/a.docx --stamp 2027-01-01T00:00:00Z
  _docx out/b.docx --body "Age median 65"
  git add -A

  run -0 "$SCRIPT" out/b.docx
}

# ─── restore command ────────────────────────────────────────────────────────

@test "restore command quotes a path with spaces and restores HEAD" {
  _docx "out dir/a b.docx"
  _commit
  _docx "out dir/a b.docx" --stamp 2027-01-01T00:00:00Z
  git add -A

  run -1 "$SCRIPT" "out dir/a b.docx"
  local command
  command=$(printf '%s\n' "$output" | grep '^  for f in ')
  # shellcheck disable=SC2016
  [ "$command" = '  for f in out\ dir/a\ b.docx; do git --literal-pathspecs diff --quiet -- "$f" && git --literal-pathspecs restore --staged --worktree -- "$f" || git --literal-pathspecs restore --staged -- "$f"; done' ]

  eval "$command"
  run -0 git status --porcelain -- "out dir"
  [ "$output" = "" ]
}

@test "restore command keeps a newer unstaged render and only unstages it" {
  _docx out/a.docx
  _docx out/b.docx
  _commit
  _docx out/a.docx --stamp 2027-01-01T00:00:00Z
  git add out/a.docx

  run -1 "$SCRIPT" out/a.docx
  local command
  command=$(printf '%s\n' "$output" | grep '^  for f in ')

  _docx out/a.docx --body "Age median 65"
  _docx out/b.docx --body "Age median 65"
  git add out/b.docx
  eval "$command"

  run -0 python3 -c "import sys, zipfile; print(zipfile.ZipFile(sys.argv[1]).read('word/document.xml').decode())" out/a.docx
  [[ "$output" == *"Age median 65"* ]]
  run -0 git diff --cached --name-only
  [ "$output" = "out/b.docx" ]
}

# ─── fails closed on a missing driver ───────────────────────────────────────

@test "driver not configured: exit 1 with a message" {
  _docx out/a.docx
  _commit
  _docx out/a.docx --body "Age median 65"
  git add out/a.docx
  git config --file "$GIT_CONFIG_GLOBAL" --unset diff.out-textconv.textconv

  run -1 "$SCRIPT" out/a.docx
  [[ "$output" == *"out-textconv is not configured"* ]]
}

@test "driver configured but not executable: non-zero exit" {
  _docx out/a.docx
  _commit
  _docx out/a.docx --stamp 2027-01-01T00:00:00Z
  git add out/a.docx
  git config --file "$GIT_CONFIG_GLOBAL" diff.out-textconv.textconv "${BATS_TEST_TMPDIR}/missing.py"

  run "$SCRIPT" out/a.docx
  [ "$status" -ne 0 ]
  [[ "$output" != *"write metadata"* ]]
}
