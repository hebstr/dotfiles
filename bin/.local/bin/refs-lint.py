#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Report the named references of a tracking file that no longer resolve.

Two passes over each target. The first collects every quoted span preceded by a
cue word and reports the ones that appear neither twice in the target nor once
anywhere else in the corpus. The second lists every reference to an internal
enumeration, which a cut breaks without breaking any name.

Exit status is 1 when the first pass reports anything, 0 otherwise. The second
pass never changes it: its output is a list to read, not a verdict.
"""

import argparse
import re
import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path

CUE = re.compile(r"(?:voir|see|section|sous|under|puce|bullet|d[ée]cision|decision|of)\s+[«\"]")
SPAN = re.compile(r"[«\"]\s*([^»\"\n]{12,120})\s*[»\"]")
ORDINAL = re.compile(
    r"\b(?:part|partie|point|d[ée]cision|decision|finding|constat)\s+(\d+)\b", re.I
)
CORPUS = ("*.md", "*.bats", "*.sh", "*.py", "*.lua")
PRUNED = frozenset({".git", "node_modules", ".venv", "__pycache__", "library", "renv", "_freeze"})


def default_root(target: Path) -> Path:
    start = target.resolve().parent
    try:
        out = subprocess.run(
            ["git", "-C", str(start), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return start
    root = Path(out.stdout.strip())
    return root.parent if root.name == ".claude" else root


def corpus_files(root: Path, patterns: Iterable[str]) -> list[Path]:
    found: list[Path] = []
    for pattern in patterns:
        for path in root.rglob(pattern):
            if PRUNED.isdisjoint(path.parts) and path.is_file():
                found.append(path)
    return found


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def named_spans(text: str) -> list[tuple[int, str]]:
    spans: list[tuple[int, str]] = []
    for match in SPAN.finditer(text):
        before = text[max(0, match.start() - 40) : match.start() + 1]
        if CUE.search(before):
            spans.append((match.start(), match.group(1).strip()))
    return spans


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def check(target: Path, others: dict[Path, str]) -> int:
    text = read(target)
    spans = named_spans(text)
    dangling = [
        (line_of(text, offset), name)
        for offset, name in spans
        if text.count(name) < 2 and not any(name in body for body in others.values())
    ]
    for line, name in dangling:
        print(f"{target}:{line}: {name[:100]}")
    print(
        f"--- {target}: {len(spans)} named references tested, {len(dangling)} dangling",
        file=sys.stderr,
    )
    ordinals = [(line_of(text, m.start()), m.group(0)) for m in ORDINAL.finditer(text)]
    for line, hit in ordinals:
        print(f"{target}:{line}: ordinal {hit}")
    print(
        f"--- {target}: {len(ordinals)} enumeration references, read each after a cut",
        file=sys.stderr,
    )
    return len(dangling)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("targets", nargs="+", type=Path)
    parser.add_argument("--root", type=Path)
    parser.add_argument("--corpus", action="append", metavar="GLOB")
    args = parser.parse_args()

    missing = [str(t) for t in args.targets if not t.is_file()]
    if missing:
        print(f"refs-lint: not a file: {', '.join(missing)}", file=sys.stderr)
        return 2

    patterns = args.corpus or list(CORPUS)
    total = 0
    for target in args.targets:
        root = args.root or default_root(target)
        resolved = target.resolve()
        others = {p: read(p) for p in corpus_files(root, patterns) if p.resolve() != resolved}
        print(f"--- {target}: corpus {len(others)} files under {root}", file=sys.stderr)
        total += check(target, others)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
