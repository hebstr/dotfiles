#!/usr/bin/env python3
import collections
import json
import os
import re
import sys

ROOT = os.path.expanduser("~/.claude/projects")
d = json.load(open(sys.argv[1]))["sessions"]

S5MARK = re.compile(
    r"(mark(ing)? (it|the item|this item)? ?as done|marquer .{0,30}comme (faite?|traitée?)|"
    r"already (carried out|been done|done)|déjà (fait|réalisé|effectué)|transcripts\.sh|"
    r"live to-do|item .{0,20}already)",
    re.I,
)
HEAD = re.compile(r"^#{1,4}\s*\**\s*(findings|constats)\b", re.I | re.M)
OOS = re.compile(r"^#{1,4}\s*\**\s*(out of scope|hors p[ée]rim)", re.I | re.M)
NONE = re.compile(r"(no findings|aucun constat)", re.I)

reports = collections.Counter()
carrying = collections.Counter()
marks = collections.Counter()
clean = 0
total = 0
rows = []
for sid, s in d.items():
    for vid, v in s["verifiers"].items():
        aid = v.get("agentId")
        if not aid:
            continue
        path = f"{ROOT}/{s['project']}/{sid}/subagents/agent-{aid}.jsonl"
        if not os.path.exists(path):
            continue
        report = ""
        with open(path) as fh:
            for line in fh:
                try:
                    r = json.loads(line)
                except json.JSONDecodeError:
                    continue
                c = (r.get("message") or {}).get("content")
                if not isinstance(c, list):
                    continue
                for x in c:
                    if (
                        isinstance(x, dict)
                        and x.get("type") == "text"
                        and len(x.get("text", "")) > 200
                    ):
                        report = x["text"]
        if not report:
            continue
        total += 1
        day = v["start"][:10]
        reports[day] += 1
        if NONE.search(report[:400]):
            clean += 1
        h, o = HEAD.search(report), OOS.search(report)
        body = report[h.end() : o.start()] if (h and o and o.start() > h.end()) else report
        n = len(S5MARK.findall(body))
        if n:
            carrying[day] += 1
            marks[day] += n
            rows.append((day, sid[:8], s["project"].replace("-home-julien-", "")[:22], n))

print(f"verifier reports read: {total}")
print(f"reports opening on 'no findings': {clean}")
print()
print(f"{'day':<12}{'reports':>9}{'with s5':>9}{'s5 marks':>10}")
for k in sorted(reports):
    print(f"{k:<12}{reports[k]:>9}{carrying[k]:>9}{marks[k]:>10}")
print()
for r in sorted(rows):
    print("  ", r)
