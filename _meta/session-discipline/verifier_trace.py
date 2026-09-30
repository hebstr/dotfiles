#!/usr/bin/env python3
import datetime as dt
import json
import os
import sys

ROOT = os.path.expanduser("~/.claude/projects")
d = json.load(open(sys.argv[1]))["sessions"]
prefixes = sys.argv[2:]


def when(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def label(inp):
    v = inp.get("command") or inp.get("file_path") or inp.get("pattern") or ""
    return " ".join(str(v).split())[:150]


for sid, s in d.items():
    if prefixes and not any(sid.startswith(p) for p in prefixes):
        continue
    for vid, v in s["verifiers"].items():
        aid = v.get("agentId")
        if not aid:
            continue
        path = f"{ROOT}/{s['project']}/{sid}/subagents/agent-{aid}.jsonl"
        if not os.path.exists(path):
            continue
        uses, order, first, last = {}, [], None, None
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
                    if not isinstance(x, dict):
                        continue
                    if x.get("type") == "tool_use":
                        uses[x["id"]] = [
                            t,
                            None,
                            x.get("name"),
                            label(x.get("input") or {}),
                        ]
                        order.append(x["id"])
                    elif x.get("type") == "tool_result" and x.get("tool_use_id") in uses:
                        uses[x["tool_use_id"]][1] = t
        if not order:
            continue
        print(
            f"=== {sid[:8]} {v['start'][:16]} {round((v.get('ms') or 0) / 1000)} s, {len(order)} calls ==="
        )
        prev = first
        for i in order:
            t0, t1, name, text = uses[i]
            think = (t0 - prev).total_seconds()
            run = (t1 - t0).total_seconds() if t1 else 0.0
            prev = max(prev, t1 or t0)
            print(f"  {round(think):>5}s think {round(run):>4}s run  {name!s:<16} {text}")
        print(f"  {round((last - prev).total_seconds()):>5}s final report")
        print()
