#!/usr/bin/env python3
import collections
import datetime as dt
import json
import os
import re
import statistics
import sys

ROOT = os.path.expanduser("~/.claude/projects")
d = json.load(open(sys.argv[1]))["sessions"]

S5 = re.compile(r"transcripts\.sh|DEFERRED|--since|next\|blocker|-i --grep|statut\|status")


def when(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def classify(name, inp):
    if name == "Bash":
        cmd = inp.get("command") or ""
        if "STAMP" in cmd or ".stamp" in cmd:
            return "stamp"
        if S5.search(cmd):
            return "s5_live_items"
        if re.search(r"\bgit (log|status|diff|show|rev-list)", cmd):
            return "git_read"
        return "bash_other"
    if name == "Read":
        p = inp.get("file_path") or ""
        if "DEFERRED" in p:
            return "s5_live_items"
        if "/.claude/" in p and re.search(r"(PLAN|DESIGN|RECO|TRIAGE)", p):
            return "read_tracking"
        if "/memory/" in p:
            return "read_memory"
        return "read_other"
    return name


agg = collections.Counter()
rows = []
long_waits = []
for sid, s in d.items():
    proj = s["project"]
    for vid, v in s["verifiers"].items():
        aid = v.get("agentId")
        if not aid:
            continue
        path = f"{ROOT}/{proj}/{sid}/subagents/agent-{aid}.jsonl"
        if not os.path.exists(path):
            continue
        uses = {}
        order = []
        first = last = None
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
                            classify(x.get("name"), x.get("input") or {}),
                            (x.get("input") or {}).get("command", "")[:120],
                        ]
                        order.append(x["id"])
                    elif x.get("type") == "tool_result" and x.get("tool_use_id") in uses:
                        uses[x["tool_use_id"]][1] = t
        if not order:
            continue
        wall = (last - first).total_seconds()
        per = collections.Counter()
        prev_end = first
        exec_total = 0.0
        for i in order:
            t0, t1, cls, cmd = uses[i]
            think = max(0.0, (t0 - prev_end).total_seconds())
            ex = (t1 - t0).total_seconds() if t1 else 0.0
            exec_total += ex
            per[cls] += think + ex
            if ex > 60:
                long_waits.append((round(ex), sid[:8], cls, cmd))
            prev_end = max(prev_end, t1 or t0)
        tail = (last - prev_end).total_seconds()
        per["final_report"] += tail
        agg.update(per)
        rows.append((wall, exec_total, per, sid[:8], v["start"][:10], len(order)))

print("verifier transcripts analysed:", len(rows))
walls = [r[0] for r in rows]
execs = [r[1] for r in rows]
print(
    "wall total h:",
    round(sum(walls) / 3600, 2),
    " tool execution share:",
    round(sum(execs) / sum(walls) * 100),
    "%",
)
tot = sum(agg.values())
print("share of wall time by activity (model time before a call counted with the call):")
for k, v in agg.most_common():
    print(f"  {k:<16} {round(v / 60):>5} min  {round(v / tot * 100):>3} %")
print()
print("tool calls lasting > 60 s:", len(long_waits))
for w in sorted(long_waits, reverse=True)[:15]:
    print("  ", w)
print()
print("per pass, s5 share:")
s5 = [r[2]["s5_live_items"] / r[0] * 100 for r in rows if r[0] > 0]
print("  median s5 share", round(statistics.median(s5)), "%")
