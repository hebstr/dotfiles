#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""clean-out-meta: pin the write metadata of a rendered binary output, as a git clean filter.

Every write of an OOXML package or of a PNG stamps metadata no content change
touches: the package creation and modification timestamps, the editing time, the
account the write came from, the ZIP entry dates and the PNG `tIME` chunk. Each
is pinned to a fixed value its own type accepts rather than dropped, so the
package keeps the types it declares, and a re-render that changed nothing else
produces a blob identical to the stored one, whichever account rendered it.

It normalises strictly less than the `out-textconv` diff driver beside it. The
`w:fontKey` GUID and the ODTTF obfuscation header it XORs into each font subset
are left alone, since blanking the key without re-keying the payload yields a
file Word refuses, and PNG pixel payloads are never re-encoded. What this filter
cannot silence is what the `metadata-only` prek hook still catches.

Unlike the driver, the output is what git stores, so anything that fails to parse
is written through byte for byte: a clean filter that mangles its input destroys
content git has no way to recover.
"""

import io
import re
import struct
import sys
import zipfile
import zlib

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
ZIP_MAGIC = b"PK\x03\x04"
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)
COMPRESS_LEVEL = 6
W3CDTF_EPOCH = b"1980-01-01T00:00:00Z"
VOLATILE_ELEMENTS = (
    (b"dcterms:created", W3CDTF_EPOCH),
    (b"dcterms:modified", W3CDTF_EPOCH),
    (b"TotalTime", b"0"),
    (b"cp:lastModifiedBy", b""),
)
STAMPS = tuple(
    (
        re.compile(rb"(<%s[^>]*>)[^<]*(</%s>)" % (name, name)),
        rb"\g<1>" + value + rb"\g<2>",
    )
    for name, value in VOLATILE_ELEMENTS
)


def xml_bytes(blob: bytes) -> bytes:
    for stamp, pinned in STAMPS:
        blob = stamp.sub(pinned, blob)

    return blob


def png_bytes(blob: bytes) -> bytes:
    out = bytearray(PNG_MAGIC)
    position = len(PNG_MAGIC)

    while position < len(blob):
        (length,) = struct.unpack(">I", blob[position : position + 4])
        name = blob[position + 4 : position + 8]
        end = position + length + 12

        if end > len(blob):
            raise ValueError("chunk runs past the end of the file")

        if name != b"tIME":
            out += blob[position:end]

        position = end

        if name == b"IEND":
            out += blob[position:]
            break

    return bytes(out)


def member_bytes(name: str, blob: bytes) -> bytes:
    if name.endswith((".xml", ".rels")):
        return xml_bytes(blob)
    if name.endswith(".png") and blob.startswith(PNG_MAGIC):
        return png_bytes(blob)

    return blob


def package_bytes(blob: bytes) -> bytes:
    buffer = io.BytesIO()

    with (
        zipfile.ZipFile(io.BytesIO(blob)) as source,
        zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED, compresslevel=COMPRESS_LEVEL) as target,
    ):
        target.comment = source.comment

        for item in source.infolist():
            member = zipfile.ZipInfo(item.filename, ZIP_EPOCH)
            member.compress_type = item.compress_type
            member.external_attr = item.external_attr
            member.internal_attr = item.internal_attr
            member.create_system = item.create_system
            target.writestr(member, member_bytes(item.filename, source.read(item)))

    return buffer.getvalue()


def main() -> int:
    blob = sys.stdin.buffer.read()

    try:
        if blob.startswith(ZIP_MAGIC):
            cleaned = package_bytes(blob)
        elif blob.startswith(PNG_MAGIC):
            cleaned = png_bytes(blob)
        else:
            cleaned = blob
    except (
        NotImplementedError,
        RuntimeError,
        ValueError,
        struct.error,
        zipfile.BadZipFile,
        zlib.error,
    ):
        cleaned = blob

    sys.stdout.buffer.write(cleaned)

    return 0


if __name__ == "__main__":
    sys.exit(main())
