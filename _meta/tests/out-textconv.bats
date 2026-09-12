#!/usr/bin/env bats
# Tests for git/.config/git/out-textconv.py

bats_require_minimum_version 1.5.0

SCRIPT="${OUT_TEXTCONV:-$BATS_TEST_DIRNAME/../../git/.config/git/out-textconv.py}"

# ─── fixture factories ──────────────────────────────────────────────────────
# Every option defaults, so a test names only what it varies and a fixture pair
# differing in one option cannot drift on a second one.

_png() {
  local path="${BATS_TEST_TMPDIR}/$1" second=1 pixel=10 gamma=45455 trailer=""
  shift

  while (($#)); do
    case $1 in
    --second) second=$2 ;;
    --pixel) pixel=$2 ;;
    --gamma) gamma=$2 ;;
    --trailer) trailer=$2 ;;
    *) return 1 ;;
    esac
    shift 2
  done

  SECOND="$second" PIXEL="$pixel" GAMMA="$gamma" TRAILER="$trailer" python3 - "$path" <<'EOF'
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
blob += chunk(b"gAMA", struct.pack(">I", int(os.environ["GAMMA"])))
blob += chunk(b"tIME", struct.pack(">HBBBBB", 2026, 9, 12, 10, 0, second))
blob += chunk(b"IDAT", zlib.compress(b"\x00" + bytes([pixel]) * 3))
blob += chunk(b"IEND", b"")
blob += os.environ["TRAILER"].encode()

with open(sys.argv[1], "wb") as out:
    out.write(blob)
EOF

  printf '%s' "$path"
}

_pkg() {
  local name=$1
  local path="${BATS_TEST_TMPDIR}/$name"
  local stamp=2026-09-12T16:00:00Z key=AAA header=x payload=PAYLOAD
  local body="Age median" total=42 mtime=2020 second=1 pixel=10
  shift

  while (($#)); do
    case $1 in
    --stamp) stamp=$2 ;;
    --key) key=$2 ;;
    --header) header=$2 ;;
    --payload) payload=$2 ;;
    --body) body=$2 ;;
    --total) total=$2 ;;
    --mtime) mtime=$2 ;;
    --second) second=$2 ;;
    --pixel) pixel=$2 ;;
    *) return 1 ;;
    esac
    shift 2
  done

  local media
  media=$(_png "media-$name.png" --second "$second" --pixel "$pixel")

  STAMP="$stamp" KEY="$key" HEADER="$header" PAYLOAD="$payload" BODY="$body" \
    TOTAL="$total" MTIME="$mtime" MEDIA="$media" python3 - "$path" <<'EOF'
import os
import sys
import zipfile

env = os.environ
stamp, key, header = env["STAMP"], env["KEY"], env["HEADER"]
mtime = (int(env["MTIME"]), 1, 1, 0, 0, 0)

members = {
    "_rels/.rels": (
        '<Relationships><Relationship Id="rId1" Target="word/document.xml"/>'
        "</Relationships>"
    ).encode(),
    "docProps/core.xml": (
        "<cp:coreProperties>"
        "<dc:title>report</dc:title>"
        f'<dcterms:created xsi:type="dcterms:W3CDTF">{stamp}</dcterms:created>'
        f'<dcterms:modified xsi:type="dcterms:W3CDTF">{stamp}</dcterms:modified>'
        "</cp:coreProperties>"
    ).encode(),
    "docProps/app.xml": (
        f"<Properties><TotalTime>{env['TOTAL']}</TotalTime>"
        "<Application>officer</Application></Properties>"
    ).encode(),
    "word/fontTable.xml": (
        '<w:fonts><w:font w:name="Luciole"><w:altName w:val="Arial"/>'
        f'<w:embedRegular w:fontKey="{{{key}}}"/></w:font></w:fonts>'
    ).encode(),
    "word/fonts/font1.odttf": (header * 32).encode() + env["PAYLOAD"].encode(),
    "word/document.xml": f"<w:document><w:t>{env['BODY']}</w:t></w:document>".encode(),
    "word/media/rId52.png": open(env["MEDIA"], "rb").read(),
}

with zipfile.ZipFile(sys.argv[1], "w") as package:
    for name, blob in members.items():
        package.writestr(zipfile.ZipInfo(name, mtime), blob)
EOF

  printf '%s' "$path"
}

_sheet() {
  local path="${BATS_TEST_TMPDIR}/$1"

  python3 - "$path" <<'EOF'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as book:
    book.writestr("docProps/core.xml", "<cp:coreProperties/>")
    book.writestr(
        "xl/worksheets/sheet1.xml",
        "<worksheet><sheetData><row><c><v>induc_adapt_pct</v></c>"
        "</row></sheetData></worksheet>",
    )
EOF

  printf '%s' "$path"
}

# ─── comparison helpers ─────────────────────────────────────────────────────
# Both sides are asserted non-empty: two crashed runs render identically, and a
# bare `diff` of them would report agreement.

_same() {
  local left right
  left=$("$SCRIPT" "$1")
  right=$("$SCRIPT" "$2")
  [ -n "$left" ]
  [ "$left" = "$right" ]
}

_differ() {
  local left right
  left=$("$SCRIPT" "$1")
  right=$("$SCRIPT" "$2")
  [ -n "$left" ]
  [ "$left" != "$right" ]
}

# ─── the noise sources, each neutralised ────────────────────────────────────

@test "package: a created and modified timestamp reads identical" {
  _same \
    "$(_pkg a.docx --stamp 2026-09-12T16:00:00Z)" \
    "$(_pkg b.docx --stamp 2026-09-12T19:30:00Z)"
}

@test "package: a TotalTime in app.xml reads identical" {
  _same "$(_pkg a.docx --total 42)" "$(_pkg b.docx --total 1337)"
}

@test "package: a fresh font key and its obfuscation header read identical" {
  _same \
    "$(_pkg a.docx --key AAA --header x)" \
    "$(_pkg b.docx --key BBB --header y)"
}

@test "package: ZIP member mtimes read identical" {
  _same "$(_pkg a.docx --mtime 2020)" "$(_pkg b.docx --mtime 2024)"
}

@test "package: an embedded PNG tIME chunk reads identical" {
  _same "$(_pkg a.docx --second 1)" "$(_pkg b.docx --second 59)"
}

# ─── real changes, each still visible ───────────────────────────────────────

@test "package: a body change reads as a difference" {
  _differ \
    "$(_pkg a.docx --body "Age median 64")" \
    "$(_pkg b.docx --body "Age median 65")"
}

@test "package: a font subset payload change reads as a difference" {
  _differ \
    "$(_pkg a.docx --payload PAYLOAD)" \
    "$(_pkg b.docx --payload OTHER)"
}

@test "package: an embedded PNG pixel change reads as a difference" {
  _differ "$(_pkg a.docx --pixel 10)" "$(_pkg b.docx --pixel 200)"
}

@test "package: an alternative font name stays visible" {
  run -0 "$SCRIPT" "$(_pkg a.docx)"
  [[ "$output" == *'w:val="Arial"'* ]]
}

@test "package: a title stays visible" {
  run -0 "$SCRIPT" "$(_pkg a.docx)"
  [[ "$output" == *$'<dc:title>\nreport</dc:title>'* ]]
}

@test "package: a relationship part is rendered as text, not digested" {
  run -0 "$SCRIPT" "$(_pkg a.docx)"
  [[ "$output" == *'Target="word/document.xml"'* ]]
}

# ─── output shape ───────────────────────────────────────────────────────────

@test "package: members are emitted in sorted order" {
  run -0 bash -c "'$SCRIPT' '$(_pkg a.docx)' | grep '^### '"
  [ "${lines[0]}" = "### _rels/.rels" ]
  [ "${lines[1]}" = "### docProps/app.xml" ]
  [ "${lines[2]}" = "### docProps/core.xml" ]
  [ "${lines[3]}" = "### word/document.xml" ]
  [ "${lines[4]}" = "### word/fontTable.xml" ]
  [ "${lines[5]}" = "### word/fonts/font1.odttf" ]
  [ "${lines[6]}" = "### word/media/rId52.png" ]
}

@test "package: a member outside word/ is rendered as text, not digested" {
  run -0 "$SCRIPT" "$(_sheet a.xlsx)"
  [[ "$output" == *"### xl/worksheets/sheet1.xml"* ]]
  [[ "$output" == *"induc_adapt_pct"* ]]
}

@test "package: an XML member is broken one line per tag" {
  run -0 bash -c "'$SCRIPT' '$(_pkg a.docx)' | grep -cFx '<dc:title>'"
  [ "$output" = "1" ]
}

# ─── standalone PNG ─────────────────────────────────────────────────────────

@test "png: a tIME chunk alone reads identical" {
  _same "$(_png a.png --second 1)" "$(_png b.png --second 42)"
}

@test "png: a pixel change reads as a difference" {
  _differ "$(_png a.png --pixel 10)" "$(_png b.png --pixel 200)"
}

@test "png: an ancillary chunk change reads as a difference" {
  _differ "$(_png a.png --gamma 45455)" "$(_png b.png --gamma 100000)"
}

@test "png: geometry is reported and the timestamp is not" {
  run -0 "$SCRIPT" "$(_png a.png)"
  [[ "$output" == *"IHDR 1x1"* ]]
  [[ "$output" != *"tIME"* ]]
}

@test "png: a short trailer after IEND leaves the tIME chunk neutralised" {
  _same \
    "$(_png a.png --second 1 --trailer xyz)" \
    "$(_png b.png --second 42 --trailer xyz)"
}

@test "png: a trailer change after IEND reads as a difference" {
  _differ \
    "$(_png a.png --trailer GARBAGE!!)" \
    "$(_png b.png --trailer OTHERJUNK)"
}

# ─── fallbacks: git must never see a failing driver ─────────────────────────

@test "unknown format: the file digest, and exit 0" {
  local f="${BATS_TEST_TMPDIR}/plain.bin"
  printf 'not a package' >"$f"
  run -0 --separate-stderr "$SCRIPT" "$f"
  [ "$output" = "$(sha256sum "$f" | cut -d' ' -f1)" ]
  [ -z "$stderr" ]
}

@test "empty file: the empty digest, and exit 0" {
  local f="${BATS_TEST_TMPDIR}/empty.docx"
  : >"$f"
  run -0 --separate-stderr "$SCRIPT" "$f"
  [ "$output" = "$(sha256sum "$f" | cut -d' ' -f1)" ]
  [ -z "$stderr" ]
}

@test "truncated package: the file digest rather than a traceback, exit 0" {
  local f="${BATS_TEST_TMPDIR}/broken.docx"
  printf 'PK\003\004 truncated' >"$f"
  run -0 --separate-stderr "$SCRIPT" "$f"
  [ "$output" = "$(sha256sum "$f" | cut -d' ' -f1)" ]
  [ -z "$stderr" ]
}

@test "encrypted member: the file digest rather than a traceback, exit 0" {
  local f="${BATS_TEST_TMPDIR}/encrypted.docx"
  python3 - "$f" <<'EOF'
import struct
import sys
import zipfile

path = sys.argv[1]
with zipfile.ZipFile(path, "w") as package:
    package.writestr("word/document.xml", "<w:t>x</w:t>")

blob = bytearray(open(path, "rb").read())
for signature, offset in ((b"PK\x03\x04", 6), (b"PK\x01\x02", 8)):
    at = blob.find(signature) + offset
    (flags,) = struct.unpack_from("<H", blob, at)
    struct.pack_into("<H", blob, at, flags | 1)

with open(path, "wb") as out:
    out.write(blob)
EOF
  run -0 --separate-stderr "$SCRIPT" "$f"
  [ "$output" = "$(sha256sum "$f" | cut -d' ' -f1)" ]
  [ -z "$stderr" ]
}

@test "non-UTF-8 XML member: that member's digest rather than a traceback, exit 0" {
  local f="${BATS_TEST_TMPDIR}/latin1.docx"
  python3 - "$f" <<'EOF'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as package:
    package.writestr("word/document.xml", b"<w:t>\xe9</w:t>")
EOF
  run -0 --separate-stderr "$SCRIPT" "$f"
  local member
  member=$(printf '<w:t>\351</w:t>' | sha256sum | cut -d' ' -f1)
  [ "$output" = $'### word/document.xml\n'"$member" ]
  [ -z "$stderr" ]
}

@test "unparseable member: the other members still hide their timestamps" {
  local stamp side
  for side in a b; do
    stamp=2026-09-12T16:00:00Z
    [ "$side" = b ] && stamp=2026-09-12T19:30:00Z
    STAMP="$stamp" python3 - "${BATS_TEST_TMPDIR}/$side.docx" <<'EOF'
import os
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as package:
    package.writestr(
        "docProps/core.xml",
        f"<cp><dcterms:modified>{os.environ['STAMP']}</dcterms:modified></cp>",
    )
    package.writestr("word/media/image1.png", b"\xff\xd8\xff\xe0 JFIF")
EOF
  done
  _same "${BATS_TEST_TMPDIR}/a.docx" "${BATS_TEST_TMPDIR}/b.docx"
}

@test "no argument: usage on stderr only, exit 2" {
  run -2 --separate-stderr "$SCRIPT"
  [ -z "$output" ]
  [[ "$stderr" == *"usage: out-textconv"* ]]
}

@test "missing path: a message on stderr only, exit 2" {
  run -2 --separate-stderr "$SCRIPT" "${BATS_TEST_TMPDIR}/absent.docx"
  [ -z "$output" ]
  [[ "$stderr" == "out-textconv: "* ]]
  [[ "$stderr" != *"Traceback"* ]]
}
