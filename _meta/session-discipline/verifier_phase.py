#!/usr/bin/env python3
import datetime as dt
import json
import os
import re
import statistics
import sys

ROOT = os.path.expanduser("~/.claude/projects")
d = json.load(open(sys.argv[1]))["sessions"]
since = sys.argv[2] if len(sys.argv) > 2 else "2026-09-27"

S5 = re.compile(r"transcripts\.sh|next\|blocker|DEFERRED\.md|--since=|-i --grep")


def when(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


rows = []
for sid, s in d.items():
    for vid, v in s["verifiers"].items():
        aid = v.get("agentId")
        if not aid or v["start"][:10] < since:
            continue
        path = f"{ROOT}/{s['project']}/{sid}/subagents/agent-{aid}.jsonl"
        if not os.path.exists(path):
            continue
        calls, first, last = [], None, None
        with open(path) as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                except json.JSONDecodeError:
                    continue
                t = r.get("timestamp")
                if not t:
                    continue
                t = when(t)
                first = first or t
                last = t
                c = (r.get("message") or {}).get("content")
                if not isinstance(c, list):
                    continue
                for x in c:
                    if isinstance(x, dict) and x.get("type") == "tool_use":
                        i = x.get("input") or {}
                        calls.append((t, f"{i.get('command') or ''} {i.get('file_path') or ''}"))
        wall = (last - first).total_seconds() if (first and last) else 0.0
        if not calls or wall <= 0:
            continue
        sweep = next((t for t, c in calls if S5.search(c)), None)
        stamp = None
        for t, c in calls:
            if "STAMP" in c or ".stamp" in c:
                stamp = t
        rows.append(
            {
                "wall": wall,
                "pre": ((sweep or last) - first).total_seconds(),
                "post": (stamp - sweep).total_seconds()
                if (sweep and stamp and stamp > sweep)
                else 0.0,
                "swept": sweep is not None,
            }
        )

have = [r for r in rows if r["swept"]]
print(f"passes since {since} with a tool trace: {len(rows)}, a section-5 command in {len(have)}")
if not have:
    raise SystemExit
print(f"median wall: {round(statistics.median([r['wall'] for r in rows]))} s")
print(
    f"median before the first section-5 command: {round(statistics.median([r['pre'] for r in have])):>4} s"
    f"  ({round(statistics.median([r['pre'] / r['wall'] for r in have]) * 100)} % of wall)"
)
print(
    f"median from that command to the stamp:     {round(statistics.median([r['post'] for r in have])):>4} s"
    f"  ({round(statistics.median([r['post'] / r['wall'] for r in have]) * 100)} % of wall)"
)
