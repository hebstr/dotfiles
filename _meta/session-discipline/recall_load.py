"""Load ~/.claude/projects/*/*.jsonl into a session index.

Written on 2026-09-28 for the recall measure of reco-relance.sh, separate from
the load.py of 2026-09-22, whose pickle chain it does not share.

A session is one .jsonl file. A *turn* is a top-level user entry that carries a
real human prompt: type == "user", isSidechain false, no toolUseResult, and a
text content that is not a <...> harness block (command-name, local-command
stdout, system-reminder-only) nor a tool_result array.
"""

import glob
import json
import os
import re

ROOT = os.path.expanduser("~/.claude/projects")

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


def _text(msg):
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


def _strip_reminders(t):
    return re.sub(r"<system-reminder>.*?</system-reminder>", "", t, flags=re.S).strip()


def load():
    sessions = []
    for path in sorted(glob.glob(os.path.join(ROOT, "*", "*.jsonl"))):
        entries = []
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        stamps = []
        turns = []
        assistant_texts = []
        for o in entries:
            ts = o.get("timestamp")
            if ts:
                stamps.append(ts)
            if o.get("isSidechain"):
                continue
            t = o.get("type")
            msg = o.get("message") or {}
            if t == "user":
                if o.get("toolUseResult") is not None:
                    continue
                txt = _text(msg)
                if txt is None:
                    continue
                txt = _strip_reminders(txt)
                if not txt:
                    continue
                if txt.startswith(HARNESS_PREFIXES):
                    continue
                turns.append(txt)
            elif t == "assistant":
                txt = _text(msg)
                if txt:
                    assistant_texts.append(txt)
        sessions.append(
            {
                "path": path,
                "project": os.path.basename(os.path.dirname(path)),
                "id": os.path.basename(path)[:-6],
                "first": min(stamps) if stamps else None,
                "last": max(stamps) if stamps else None,
                "n_entries": len(entries),
                "turns": turns,
                "assistant": assistant_texts,
            }
        )
    return sessions


if __name__ == "__main__":
    s = load()
    print(f"{len(s)} transcripts")
