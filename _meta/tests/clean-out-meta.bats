#!/usr/bin/env bats
# Tests for git/.config/git/clean-out-meta.py

bats_require_minimum_version 1.5.0

SCRIPT="${CLEAN_OUT_META:-$BATS_TEST_DIRNAME/../../git/.config/git/clean-out-meta.py}"

EPOCH=1980-01-01T00:00:00Z

# ─── fixture factories ──────────────────────────────────────────────────────
# Every option defaults, so a test names only what it varies and a fixture pair
# differing in one option cannot drift on a second one.

_png() {
  local path="${BATS_TEST_TMPDIR}/$1" second=1 pixel=10 stamped=1 trailer=""
  shift

  while (($#)); do
    case $1 in
    --second) second=$2 ;;
    --pixel) pixel=$2 ;;
    --stamped) stamped=$2 ;;
    --trailer) trailer=$2 ;;
    *) return 1 ;;
    esac
    shift 2
  done

  SECOND="$second" PIXEL="$pixel" STAMPED="$stamped" TRAILER="$trailer" python3 - "$path" <<'EOF'
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
blob += chunk(b"pHYs", struct.pack(">IIB", 2835, 2835, 1))
if os.environ["STAMPED"] == "1":
    blob += chunk(b"tIME", struct.pack(">HBBBBB", 2026, 10, 24, 10, 0, second))
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
  local stamp=2026-10-24T16:00:00Z key=AAA header=x payload=PAYLOAD
  local body="Age median" total=42 mtime=2020 second=1 pixel=10 stored=0
  local author=julien
  shift

  while (($#)); do
    case $1 in
    --stamp) stamp=$2 ;;
    --author) author=$2 ;;
    --key) key=$2 ;;
    --header) header=$2 ;;
    --payload) payload=$2 ;;
    --body) body=$2 ;;
    --total) total=$2 ;;
    --mtime) mtime=$2 ;;
    --second) second=$2 ;;
    --pixel) pixel=$2 ;;
    --stored) stored=$2 ;;
    *) return 1 ;;
    esac
    shift 2
  done

  local media
  media=$(_png "media-$name.png" --second "$second" --pixel "$pixel")

  STAMP="$stamp" KEY="$key" HEADER="$header" PAYLOAD="$payload" BODY="$body" \
    TOTAL="$total" MTIME="$mtime" MEDIA="$media" STORED="$stored" AUTHOR="$author" \
    python3 - "$path" <<'EOF'
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
        f"<cp:lastModifiedBy>{env['AUTHOR']}</cp:lastModifiedBy>"
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

with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as package:
    for name, blob in members.items():
        item = zipfile.ZipInfo(name, mtime)
        if env["STORED"] == "1" and name == "word/fonts/font1.odttf":
            item.compress_type = zipfile.ZIP_STORED
        else:
            item.compress_type = zipfile.ZIP_DEFLATED
        package.writestr(item, blob)
EOF

  printf '%s' "$path"
}

# ─── helpers ────────────────────────────────────────────────────────────────
# The filter speaks bytes on both ends, so every assertion goes through a file
# rather than through bats' `$output`, which mangles a binary payload.

_clean() {
  "$SCRIPT" <"$1" >"$2" 2>"${BATS_TEST_TMPDIR}/stderr"
  [ ! -s "${BATS_TEST_TMPDIR}/stderr" ]
}

_member() {
  unzip -p "$1" "$2"
}

_names() {
  python3 -c '
import sys, zipfile
print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "$1"
}

_dates() {
  python3 -c '
import sys, zipfile
print("\n".join(str(i.date_time) for i in zipfile.ZipFile(sys.argv[1]).infolist()))' "$1"
}

_compress_types() {
  python3 -c '
import sys, zipfile
print("\n".join(f"{i.filename} {i.compress_type}" for i in zipfile.ZipFile(sys.argv[1]).infolist()))' "$1"
}

_chunks() {
  python3 -c '
import struct, sys
blob = open(sys.argv[1], "rb").read()
position = 8
while position < len(blob):
    (length,) = struct.unpack(">I", blob[position : position + 4])
    print(blob[position + 4 : position + 8].decode("latin1"))
    position += length + 12' "$1"
}

# ─── wiring ─────────────────────────────────────────────────────────────────

@test "the gitconfig filter points at this script inside the git package" {
  run -0 git config -f "$BATS_TEST_DIRNAME/../../git/.gitconfig" --get filter.out-meta.clean
  # shellcheck disable=SC2088
  [ "$output" = '~/.config/git/clean-out-meta.py' ]
  [ -x "$BATS_TEST_DIRNAME/../../git/.config/git/clean-out-meta.py" ]
}

# ─── what the filter pins ───────────────────────────────────────────────────

@test "both package timestamps are pinned to a valid epoch literal" {
  _clean "$(_pkg in.docx)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _member "$BATS_TEST_TMPDIR/out.docx" docProps/core.xml
  [[ "$output" == *"<dcterms:created xsi:type=\"dcterms:W3CDTF\">$EPOCH</dcterms:created>"* ]]
  [[ "$output" == *"<dcterms:modified xsi:type=\"dcterms:W3CDTF\">$EPOCH</dcterms:modified>"* ]]
}

@test "the editing time is pinned to zero rather than emptied" {
  _clean "$(_pkg in.docx --total 137)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _member "$BATS_TEST_TMPDIR/out.docx" docProps/app.xml
  [[ "$output" == *"<TotalTime>0</TotalTime>"* ]]
}

@test "the write account is pinned to an empty author" {
  _clean "$(_pkg in.docx --author edjulien)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _member "$BATS_TEST_TMPDIR/out.docx" docProps/core.xml
  [[ "$output" == *"<cp:lastModifiedBy></cp:lastModifiedBy>"* ]]
  [[ "$output" != *edjulien* ]]
}

@test "every ZIP entry date is pinned to the 1980 epoch" {
  _clean "$(_pkg in.docx --mtime 2024)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _dates "$BATS_TEST_TMPDIR/out.docx"
  [ -n "$output" ]
  run -1 grep -vFx '(1980, 1, 1, 0, 0, 0)' <<<"$output"
}

@test "two writes differing only in write metadata come out byte-identical" {
  _clean \
    "$(_pkg a.docx --stamp 2026-10-24T16:00:00Z --mtime 2024 --total 42 --second 1 --author julien)" \
    "$BATS_TEST_TMPDIR/a.out"
  _clean \
    "$(_pkg b.docx --stamp 2026-10-25T09:30:00Z --mtime 2026 --total 99 --second 7 --author edjulien)" \
    "$BATS_TEST_TMPDIR/b.out"
  cmp "$BATS_TEST_TMPDIR/a.out" "$BATS_TEST_TMPDIR/b.out"
}

@test "a PNG member loses its tIME chunk and keeps every other one" {
  _clean "$(_pkg in.docx)" "$BATS_TEST_TMPDIR/out.docx"
  _member "$BATS_TEST_TMPDIR/out.docx" word/media/rId52.png >"$BATS_TEST_TMPDIR/media.png"
  run -0 _chunks "$BATS_TEST_TMPDIR/media.png"
  [ "$output" = "IHDR
pHYs
IDAT
IEND" ]
}

@test "a standalone PNG loses its tIME chunk" {
  _clean "$(_png in.png)" "$BATS_TEST_TMPDIR/out.png"
  run -0 _chunks "$BATS_TEST_TMPDIR/out.png"
  [ "$output" = "IHDR
pHYs
IDAT
IEND" ]
}

@test "two PNG differing only in their tIME come out byte-identical" {
  _clean "$(_png a.png --second 1)" "$BATS_TEST_TMPDIR/a.out"
  _clean "$(_png b.png --second 42)" "$BATS_TEST_TMPDIR/b.out"
  cmp "$BATS_TEST_TMPDIR/a.out" "$BATS_TEST_TMPDIR/b.out"
}

# ─── what the filter must leave alone ───────────────────────────────────────

@test "the font key is left alone, re-keying an ODTTF payload being out of reach" {
  _clean "$(_pkg in.docx --key DEADBEEF)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _member "$BATS_TEST_TMPDIR/out.docx" word/fontTable.xml
  [[ "$output" == *'w:fontKey="{DEADBEEF}"'* ]]
}

@test "the ODTTF obfuscation header survives byte for byte" {
  _clean "$(_pkg in.docx --header z --payload SUBSET)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _member "$BATS_TEST_TMPDIR/out.docx" word/fonts/font1.odttf
  [ "$output" = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzSUBSET" ]
}

@test "a real body change still reaches the output" {
  _clean "$(_pkg in.docx --body 'Age moyen')" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _member "$BATS_TEST_TMPDIR/out.docx" word/document.xml
  [[ "$output" == *'<w:t>Age moyen</w:t>'* ]]
}

@test "two writes differing in content do not collapse" {
  _clean "$(_pkg a.docx --body 'Age median')" "$BATS_TEST_TMPDIR/a.out"
  _clean "$(_pkg b.docx --body 'Age moyen')" "$BATS_TEST_TMPDIR/b.out"
  run -1 cmp -s "$BATS_TEST_TMPDIR/a.out" "$BATS_TEST_TMPDIR/b.out"
}

@test "the member list keeps its order" {
  _clean "$(_pkg in.docx)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _names "$BATS_TEST_TMPDIR/out.docx"
  [ "$output" = "_rels/.rels
docProps/core.xml
docProps/app.xml
word/fontTable.xml
word/fonts/font1.odttf
word/document.xml
word/media/rId52.png" ]
}

@test "a stored member stays stored rather than being deflated" {
  _clean "$(_pkg in.docx --stored 1)" "$BATS_TEST_TMPDIR/out.docx"
  run -0 _compress_types "$BATS_TEST_TMPDIR/out.docx"
  [[ "$output" == *"word/fonts/font1.odttf 0"* ]]
  [[ "$output" == *"word/document.xml 8"* ]]
}

@test "an archive comment is preserved" {
  python3 - "$BATS_TEST_TMPDIR/commented.docx" <<'EOF'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as package:
    package.writestr("docProps/core.xml", "<cp:coreProperties/>")
    package.comment = b"written by officer"
EOF
  _clean "$BATS_TEST_TMPDIR/commented.docx" "$BATS_TEST_TMPDIR/out.docx"
  run -0 python3 -c '
import sys, zipfile
print(zipfile.ZipFile(sys.argv[1]).comment.decode())' "$BATS_TEST_TMPDIR/out.docx"
  [ "$output" = "written by officer" ]
}

@test "a trailer past IEND is preserved" {
  _clean "$(_png in.png --trailer TRAILING)" "$BATS_TEST_TMPDIR/out.png"
  run -0 tail -c 8 "$BATS_TEST_TMPDIR/out.png"
  [ "$output" = "TRAILING" ]
}

# ─── idempotence, since git re-filters on every add ─────────────────────────

@test "a second pass over a package changes nothing" {
  _clean "$(_pkg in.docx)" "$BATS_TEST_TMPDIR/once.docx"
  _clean "$BATS_TEST_TMPDIR/once.docx" "$BATS_TEST_TMPDIR/twice.docx"
  cmp "$BATS_TEST_TMPDIR/once.docx" "$BATS_TEST_TMPDIR/twice.docx"
}

@test "a PNG with no tIME comes out byte-identical" {
  local src
  src=$(_png in.png --stamped 0)
  _clean "$src" "$BATS_TEST_TMPDIR/out.png"
  cmp "$src" "$BATS_TEST_TMPDIR/out.png"
}

# ─── the fallback, which is a passthrough rather than a digest ──────────────

@test "a file that is neither a package nor a PNG passes through byte for byte" {
  printf 'plain bytes\n\000\001\002' >"$BATS_TEST_TMPDIR/in.bin"
  _clean "$BATS_TEST_TMPDIR/in.bin" "$BATS_TEST_TMPDIR/out.bin"
  cmp "$BATS_TEST_TMPDIR/in.bin" "$BATS_TEST_TMPDIR/out.bin"
}

@test "an empty input passes through" {
  : >"$BATS_TEST_TMPDIR/in.bin"
  _clean "$BATS_TEST_TMPDIR/in.bin" "$BATS_TEST_TMPDIR/out.bin"
  [ ! -s "$BATS_TEST_TMPDIR/out.bin" ]
}

@test "a truncated package passes through byte for byte and exits zero" {
  local src
  src=$(_pkg in.docx)
  head -c 200 "$src" >"$BATS_TEST_TMPDIR/truncated.docx"
  _clean "$BATS_TEST_TMPDIR/truncated.docx" "$BATS_TEST_TMPDIR/out.docx"
  cmp "$BATS_TEST_TMPDIR/truncated.docx" "$BATS_TEST_TMPDIR/out.docx"
}

@test "a PNG whose chunk runs past the end passes through byte for byte" {
  local src
  src=$(_png in.png)
  head -c 40 "$src" >"$BATS_TEST_TMPDIR/broken.png"
  _clean "$BATS_TEST_TMPDIR/broken.png" "$BATS_TEST_TMPDIR/out.png"
  cmp "$BATS_TEST_TMPDIR/broken.png" "$BATS_TEST_TMPDIR/out.png"
}

@test "a PNG truncated inside a chunk header passes through byte for byte" {
  local src
  src=$(_png in.png)
  head -c 35 "$src" >"$BATS_TEST_TMPDIR/stub.png"
  _clean "$BATS_TEST_TMPDIR/stub.png" "$BATS_TEST_TMPDIR/out.png"
  cmp "$BATS_TEST_TMPDIR/stub.png" "$BATS_TEST_TMPDIR/out.png"
}

@test "a package holding a member that is not XML under an .xml name passes it through" {
  python3 - "$BATS_TEST_TMPDIR/odd.docx" <<'EOF'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as package:
    package.writestr("docProps/core.xml", "<cp:coreProperties/>")
    package.writestr("word/settings.xml", "<w:settings/>".encode("utf-16"))
EOF
  _clean "$BATS_TEST_TMPDIR/odd.docx" "$BATS_TEST_TMPDIR/out.docx"
  run -0 python3 -c '
import sys, zipfile
a = zipfile.ZipFile(sys.argv[1]).read("word/settings.xml")
b = zipfile.ZipFile(sys.argv[2]).read("word/settings.xml")
print(a == b)' "$BATS_TEST_TMPDIR/odd.docx" "$BATS_TEST_TMPDIR/out.docx"
  [ "$output" = True ]
}

@test "a package whose members cannot be decompressed passes through byte for byte" {
  python3 - "$BATS_TEST_TMPDIR" <<'EOF'
import io
import struct
import sys
import zipfile
from pathlib import Path

buffer = io.BytesIO()
with zipfile.ZipFile(buffer, "w", zipfile.ZIP_STORED) as package:
    package.writestr("docProps/core.xml", "<cp:coreProperties/>")
    package.writestr("word/document.xml", "<w:document/>" * 50)
stored = buffer.getvalue()


def patch(blob, magic, offset, value):
    out = bytearray(blob)
    position = 0
    while True:
        position = out.find(magic, position)
        if position < 0:
            return bytes(out)
        struct.pack_into("<H", out, position + offset, value)
        position += 4


def methods(blob, value):
    return patch(patch(blob, b"PK\x03\x04", 8, value), b"PK\x01\x02", 10, value)


def encrypted(blob):
    return patch(patch(blob, b"PK\x03\x04", 6, 1), b"PK\x01\x02", 8, 1)


out = Path(sys.argv[1])
(out / "deflate.docx").write_bytes(methods(stored, 8))
(out / "method99.docx").write_bytes(methods(stored, 99))
(out / "encrypted.docx").write_bytes(encrypted(stored))
EOF
  local name
  for name in deflate method99 encrypted; do
    _clean "$BATS_TEST_TMPDIR/$name.docx" "$BATS_TEST_TMPDIR/$name.out"
    cmp "$BATS_TEST_TMPDIR/$name.docx" "$BATS_TEST_TMPDIR/$name.out"
  done
}

@test "a package holding a member that is not a PNG under an .png name passes it through" {
  python3 - "$BATS_TEST_TMPDIR/odd.docx" <<'EOF'
import struct
import sys
import zipfile

payload = b"\xff\xd8\xff\xe0JFIF" + struct.pack(">I", 8) + b"junk" + b"ABCDEFGH" + b"\x00\x01\x02\x03"

with zipfile.ZipFile(sys.argv[1], "w") as package:
    package.writestr("docProps/core.xml", "<cp:coreProperties/>")
    package.writestr("word/media/x.png", payload)
EOF
  _clean "$BATS_TEST_TMPDIR/odd.docx" "$BATS_TEST_TMPDIR/out.docx"
  run -0 python3 -c '
import sys, zipfile
a = zipfile.ZipFile(sys.argv[1]).read("word/media/x.png")
b = zipfile.ZipFile(sys.argv[2]).read("word/media/x.png")
print(a == b)' "$BATS_TEST_TMPDIR/odd.docx" "$BATS_TEST_TMPDIR/out.docx"
  [ "$output" = True ]
}
