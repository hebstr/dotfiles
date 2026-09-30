#!/usr/bin/env python3
import json
import os
import re
import statistics
import sys

ROOT = os.path.expanduser("~/.claude/projects")
d = json.load(open(sys.argv[1]))["sessions"]

PATH = re.compile(r"^\s*(/|~/)\S+$")
BLOCK = re.compile(r"\nWRITES[:=]\s*\n(.*?)\n\s*STAMP_FILE=", re.S)
TRACKING = ("PLAN.md", "README.md", "CLAUDE.md")


def writes_of(prompt):
    m = BLOCK.search(prompt)
    if not m:
        return []
    return [ln.strip() for ln in m.group(1).splitlines() if PATH.match(ln)]


def is_code(p):
    return "/.claude/" not in p and "/memory/" not in p and not p.endswith(TRACKING)


rows = []
for sid, s in d.items():
    tpath = f"{ROOT}/{s['project']}/{sid}.jsonl"
    prompts = {}
    if os.path.exists(tpath):
        with open(tpath) as fh:
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
                        and x.get("type") == "tool_use"
                        and x.get("name") == "Agent"
                    ):
                        prompts[x["id"]] = (x.get("input") or {}).get("prompt", "")
    for vid, v in s["verifiers"].items():
        ms = v.get("ms")
        if not ms:
            continue
        w = writes_of(prompts.get(vid, ""))
        rows.append(
            {
                "date": v["start"][:10],
                "proj": s["project"].replace("-home-julien-", ""),
                "sid": sid[:8],
                "model": str(v.get("model")),
                "s": round(ms / 1000),
                "tok": v.get("tok") or 0,
                "tu": v.get("tu") or 0,
                "writes": len(w),
                "code": sum(1 for x in w if is_code(x)),
            }
        )

rows.sort(key=lambda r: (r["date"], r["s"]))
print(f"passes with a duration: {len(rows)}")
known = [r for r in rows if r["writes"]]
print(f"passes with a readable WRITES list: {len(known)}")
print()
print(f"{'date':<11}{'sid':<10}{'model':<18}{'s':>5}{'tok':>8}{'tu':>5}{'|W|':>5}{'code':>5}  proj")
for r in rows:
    print(
        f"{r['date']:<11}{r['sid']:<10}{r['model']:<18}{r['s']:>5}{r['tok']:>8}"
        f"{r['tu']:>5}{r['writes']:>5}{r['code']:>5}  {r['proj'][:34]}"
    )


def show(tag, g):
    if len(g) < 3:
        print(f"{tag:<34} n={len(g)}")
        return
    sec = [r["s"] for r in g]
    q = statistics.quantiles(sec, n=4)
    print(
        f"{tag:<34} n={len(g):<4} median {round(statistics.median(sec)):>5} s"
        f"   q1 {round(q[0]):>4}  q3 {round(q[2]):>4}"
        f"   median |W| {statistics.median([r['writes'] for r in g])}"
    )


REGIMES = (
    ("2026-09-23", "2026-09-26", "opus-5-5, effort xhigh"),
    ("2026-09-27", "2026-09-30", "opus-5, effort high"),
)
BUCKETS = ((0, 4, "|W| <= 4"), (5, 9, "|W| 5-9"), (10, 10**6, "|W| >= 10"))

print()
for lo, hi, label in REGIMES:
    g = [r for r in known if lo <= r["date"] <= hi]
    show(f"{lo}..{hi} all ({label})", g)
    for blo, bhi, blabel in BUCKETS:
        show(f"  {blabel}", [r for r in g if blo <= r["writes"] <= bhi])
    print()

for proj, label in (("dotfiles", "dotfiles only"), (None, "other repositories")):
    g = [
        r
        for r in known
        if r["date"] >= "2026-09-27" and ((r["proj"] == "dotfiles") == (proj == "dotfiles"))
    ]
    show(f"{label}, from 2026-09-27", g)
    for blo, bhi, blabel in BUCKETS:
        show(f"  {blabel}", [r for r in g if blo <= r["writes"] <= bhi])
    print()

print(f"{'day':<12}{'n':>4}{'median s':>10}{'max s':>8}")
byday = {}
for r in rows:
    byday.setdefault(r["date"], []).append(r["s"])
for k in sorted(byday):
    v = byday[k]
    print(f"{k:<12}{len(v):>4}{round(statistics.median(v)):>10}{max(v):>8}")
