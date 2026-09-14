#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""out-textconv: render a binary output as stable text, as a git textconv driver.

Every write of an OOXML package or of a cropped PNG regenerates metadata no
content change touches: the package modification timestamp, the ODTTF
obfuscation key and the 32-byte header it XORs into each embedded font subset,
and the PNG `tIME` chunk. Each is neutralised rather than dropped, the `tIME`
chunk excepted since it carries nothing but the time, so a real change in the
same part stays visible: a font subset that actually moves, an alternative font
name, a title.

Stored bytes are never touched. The driver only feeds `git diff`, `git show`
and `git log -p`, which is what keeps it safe on a deliverable Word refuses at
the slightest OOXML breach.
"""

import hashlib
import io
import re
import struct
import sys
import zipfile
import zlib
from pathlib import Path

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
ZIP_MAGIC = b"PK\x03\x04"
OBFUSCATION_HEADER = 32
VOLATILE_ELEMENTS = ("dcterms:created", "dcterms:modified", "TotalTime")
FONT_KEY = re.compile(r'w:fontKey="\{[0-9A-Fa-f-]+\}"')
USAGE = "usage: out-textconv <file>"


def digest(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def chunks(blob: bytes):
    position = len(PNG_MAGIC)

    while position < len(blob):
        (length,) = struct.unpack(">I", blob[position : position + 4])
        name = blob[position + 4 : position + 8].decode("latin1")
        yield name, blob[position + 8 : position + 8 + length]
        position += length + 12

        if name == "IEND":
            if position < len(blob):
                yield "trailer", blob[position:]
            return


def png_text(blob: bytes) -> str:
    lines = []
    pixels = b""

    for name, payload in chunks(blob):
        if name == "tIME":
            continue
        if name == "IDAT":
            pixels += payload
        elif name == "IHDR":
            width, height, depth, color = struct.unpack(">IIBB", payload[:10])
            lines.append(f"IHDR {width}x{height} depth={depth} color={color}")
        else:
            lines.append(f"{name} {digest(payload)}")

    lines.append(f"pixels {digest(zlib.decompress(pixels))}")

    return "\n".join(lines)


def xml_text(blob: bytes) -> str:
    text = blob.decode("utf-8")

    for element in VOLATILE_ELEMENTS:
        text = re.sub(rf"(<{element}[^>]*>)[^<]*(</{element}>)", r"\1\2", text)

    # a line per tag, so a diff lands on the element that moved
    return FONT_KEY.sub('w:fontKey=""', text).replace(">", ">\n")


def member_text(name: str, blob: bytes) -> str:
    if name.endswith((".xml", ".rels")):
        return xml_text(blob)
    if name.endswith(".png"):
        return png_text(blob)
    if name.endswith(".odttf"):
        return digest(blob[OBFUSCATION_HEADER:])

    return digest(blob)


def package_text(blob: bytes) -> str:
    lines = []

    with zipfile.ZipFile(io.BytesIO(blob)) as package:
        for name in sorted(package.namelist()):
            member = package.read(name)
            lines.append(f"### {name}")

            try:
                lines.append(member_text(name, member))
            except (UnicodeDecodeError, struct.error, zlib.error):
                lines.append(digest(member))

    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 2:
        print(USAGE, file=sys.stderr)
        return 2

    path = Path(sys.argv[1])

    try:
        blob = path.read_bytes()
    except OSError as error:
        print(f"out-textconv: {error}", file=sys.stderr)
        return 2

    try:
        if blob.startswith(ZIP_MAGIC):
            print(package_text(blob))
        elif blob.startswith(PNG_MAGIC):
            print(png_text(blob))
        else:
            print(digest(blob))
    except (
        KeyError,
        NotImplementedError,
        RuntimeError,
        UnicodeDecodeError,
        struct.error,
        zipfile.BadZipFile,
        zlib.error,
    ):
        print(digest(blob))

    return 0


if __name__ == "__main__":
    sys.exit(main())
