"""Freeze the bench of assistant messages ending-gate.sh sees at Stop.

The transcripts behind any measure of that hook expire after `cleanupPeriodDays`
(7), so the corpus cannot be rebuilt later. This writes every stop point to a
JSON file that outlives them, which `.gitignore` keeps out of this public
repository since it quotes assistant messages.

A *stop point* is an assistant text entry, outside a sidechain, that the harness
offered to the Stop hook: one followed by a real user prompt (the hook let the
turn end), by a `Stop hook feedback` entry (the hook fired, exit 2), or by the
end of the transcript. The payload field `.last_assistant_message` is
reconstructed from the entry's text blocks rather than captured, an assumption
the rows carrying a real feedback entry test: their `real` verdict comes from
the hook itself and must match `replay`.

The bench carries no judgement on whether a message genuinely ends on an offer
without a position. That labelling is a separate pass, which the frozen text no
longer makes urgent.

Usage: python3 ending_bench.py [out.json]   (default: ending_bench.json here)
"""

import collections
import json
import re
import subprocess
import sys
from collections.abc import Iterator
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
ROOT = Path("~/.claude/projects").expanduser()
HOOK = Path("~/dotfiles/claude/.claude/hooks/ending-gate.sh").expanduser()

FEEDBACK = "Stop hook feedback:"
OFFER = "offers an action without taking a position"
CLOSE = "hands the session closure to the user"

HARNESS_PREFIXES = (
    "<command-name>",
    "<local-command-stdout>",
    "<local-command-stderr>",
    "<bash-stdout>",
    "<bash-stderr>",
    "<user-prompt-submit-hook>",
    "Caveat: The messages below",
    "[Request interrupted",
    "API Error",
)


def text_of(msg):
    """Return the concatenated text blocks of a message, None for a tool result."""
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        parts = []
        for b in c:
            if isinstance(b, dict):
                if b.get("type") == "tool_result":
                    return None
                if b.get("type") == "text":
                    parts.append(b.get("text", ""))
        return "\n".join(parts)
    return None


def strip_reminders(t):
    return re.sub(r"<system-reminder>.*?</system-reminder>", "", t, flags=re.S).strip()


def verdict(stderr):
    """Return the families and quoted phrases of an ending-gate message."""
    families = []
    if OFFER in stderr:
        families.append("offer")
    if CLOSE in stderr:
        families.append("close")
    return families, sorted(set(re.findall(r'"([^"]+)"', stderr)))


def sequence(path: Path) -> list[tuple[str, str, Any]]:
    """Return the non-sidechain entries of a transcript as (kind, text, timestamp)."""
    seq: list[tuple[str, str, Any]] = []
    with path.open(encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if o.get("isSidechain"):
                continue
            kind = o.get("type")
            msg = o.get("message") or {}
            ts = o.get("timestamp")
            if kind == "assistant":
                txt = text_of(msg)
                if txt and txt.strip():
                    seq.append(("assistant", txt, ts))
            elif kind == "user":
                if o.get("toolUseResult") is not None:
                    continue
                txt = text_of(msg)
                if txt is None:
                    continue
                txt = strip_reminders(txt)
                if not txt:
                    continue
                if txt.startswith(FEEDBACK):
                    seq.append(("feedback", txt, ts))
                elif not txt.startswith(HARNESS_PREFIXES):
                    seq.append(("prompt", txt, ts))
    return seq


def stop_points() -> Iterator[dict[str, Any]]:
    """Yield one row per assistant message the harness offered to the Stop hook."""
    for path in sorted(ROOT.glob("*/*.jsonl")):
        seq = sequence(path)
        for i, (kind, txt, ts) in enumerate(seq):
            if kind != "assistant":
                continue
            nxt = seq[i + 1] if i + 1 < len(seq) else None
            if nxt is None:
                stop, real = "eof", None
            elif nxt[0] == "prompt":
                stop, real = "prompt", None
            elif nxt[0] == "feedback":
                stop, real = "feedback", nxt[1]
            else:
                continue
            yield {
                "session": path.stem,
                "project": path.parent.name,
                "timestamp": ts,
                "stop": stop,
                "text": txt,
                "feedback": real,
            }


def replay(text: str) -> tuple[list[str], list[str]]:
    """Run the real hook over a reconstructed payload and read its verdict."""
    payload = json.dumps({"stop_hook_active": False, "last_assistant_message": text})
    p = subprocess.run(
        ["bash", str(HOOK)], input=payload, capture_output=True, text=True, check=False
    )
    return verdict(p.stderr)


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE / "ending_bench.json"
    rows: list[dict[str, Any]] = []
    for row in stop_points():
        families, phrases = replay(row["text"])
        real = None
        if row["feedback"] is not None and (OFFER in row["feedback"] or CLOSE in row["feedback"]):
            rf, rp = verdict(row["feedback"])
            real = {"families": rf, "phrases": rp}
        rows.append(
            {
                "session": row["session"],
                "project": row["project"],
                "timestamp": row["timestamp"],
                "stop": row["stop"],
                "replay": {"families": families, "phrases": phrases},
                "real": real,
                "text": row["text"],
            }
        )

    counts = collections.Counter("+".join(r["replay"]["families"]) or "silent" for r in rows)
    stops = collections.Counter(r["stop"] for r in rows)
    phrases = collections.Counter(p for r in rows for p in r["replay"]["phrases"])
    checked = [r for r in rows if r["real"] is not None]
    agree = [
        r
        for r in checked
        if r["real"]["families"] == r["replay"]["families"]
        and r["real"]["phrases"] == r["replay"]["phrases"]
    ]
    stamps = sorted(r["timestamp"] for r in rows if r["timestamp"])

    meta = {
        "rows": len(rows),
        "span": [stamps[0], stamps[-1]] if stamps else None,
        "replay": dict(counts),
        "stops": dict(stops),
        "phrases": dict(phrases.most_common()),
        "validated": {"checked": len(checked), "agree": len(agree)},
    }
    with out.open("w", encoding="utf-8") as fh:
        json.dump({"meta": meta, "rows": rows}, fh, ensure_ascii=False, indent=1)

    print(f"{len(rows)} stop points -> {out}")
    print(f"  span {stamps[0]} .. {stamps[-1]}" if stamps else "  no timestamp")
    for k in sorted(counts):
        print(f"  replay {k:12s} {counts[k]}")
    for k in sorted(stops):
        print(f"  stop   {k:12s} {stops[k]}")
    print(f"  validated {len(agree)}/{len(checked)} against real hook feedback")
    for r in checked:
        if r not in agree:
            print(f"    diverges [{r['session'][:8]}] real={r['real']} replay={r['replay']}")


if __name__ == "__main__":
    main()
