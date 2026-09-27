#!/usr/bin/env python3
import collections
import json
import statistics
import sys

d = json.load(open(sys.argv[1]))["sessions"]

durs = []
by_day = collections.defaultdict(list)
for sid, s in d.items():
    for vid, v in s["verifiers"].items():
        if v.get("ms"):
            durs.append((v["ms"] / 1000, v.get("tu"), v.get("tok"), sid[:8], v["start"][:10]))
            by_day[v["start"][:10]].append(v["ms"] / 1000)

print("verifier passes with usage:", len(durs), "of", sum(len(s["verifiers"]) for s in d.values()))
secs = [x[0] for x in durs]
print(
    "median s:",
    round(statistics.median(secs)),
    "mean s:",
    round(statistics.mean(secs)),
    "p90:",
    round(sorted(secs)[int(0.9 * len(secs))]),
    "max:",
    round(max(secs)),
)
print(
    "over 600 s:",
    sum(x > 600 for x in secs),
    "over 300 s:",
    sum(x > 300 for x in secs),
    "total h:",
    round(sum(secs) / 3600, 2),
)
for day in sorted(by_day):
    v = by_day[day]
    print(
        " ",
        day,
        "n",
        len(v),
        "median",
        round(statistics.median(v)),
        "max",
        round(max(v)),
        "sum_min",
        round(sum(v) / 60),
    )
print("longest:")
for x in sorted(durs, reverse=True)[:12]:
    print("  ", round(x[0]), "s", x[1], "tools", x[2], "tok", x[3], x[4])

print()
print("sessions by verifier passes:", collections.Counter(len(s["verifiers"]) for s in d.values()))

print()
print("what precedes each verifier pass after the first in a session:")
trig = collections.Counter()
for sid, s in d.items():
    ev = s["events"]
    seen_first = False
    for i, (t, kind, data) in enumerate(ev):
        if kind != "verifier":
            continue
        if not seen_first:
            seen_first = True
            continue
        prev = None
        for j in range(i - 1, -1, -1):
            if ev[j][1] in (
                "guard_stale",
                "gate_block",
                "skill_user",
                "commit_ok",
                "verifier",
                "guard_other",
            ):
                prev = ev[j][1]
                break
        trig[prev] += 1
print(" ", dict(trig))

print()
print("stale events:")
for sid, s in sorted(d.items(), key=lambda kv: kv[1]["first"] or ""):
    for t, kind, data in s["events"]:
        if kind == "guard_stale":
            print(f"  {t[:16]} {sid[:8]} {s['project'][13:40]:<28} GUARD cmd={data['cmd'][:110]!r}")
            for p in data["paths"]:
                print("       ", p)
        elif kind == "gate_block":
            print(f"  {t[:16]} {sid[:8]} {s['project'][13:40]:<28} GATE")
            for p in data:
                print("       ", p)
