import json
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

L = timezone(timedelta(hours=2))
agg = defaultdict(lambda: defaultdict(int))
for p in Path.home().joinpath(".claude/projects").glob("*/*.jsonl"):
    seen = set()
    for line in open(p):
        try:
            r = json.loads(line)
        except:
            continue
        if r.get("type") != "assistant":
            continue
        m = r["message"]
        mid = m.get("id")
        if mid in seen or m.get("model") == "<synthetic>":
            continue
        seen.add(mid)
        t = datetime.fromisoformat(r["timestamp"].replace("Z", "+00:00")).astimezone(L)
        key = t.strftime("%m-%d") + (
            " pm"
            if t.strftime("%m-%d %H:%M") >= t.strftime("%m-%d") + " 16:37"
            and t.strftime("%m-%d") == "09-26"
            else ""
        )
        u = m.get("usage") or {}
        a = agg[(key, m.get("model"))]
        a["resp"] += 1
        a["think"] += (u.get("output_tokens_details") or {}).get("thinking_tokens", 0)
        a["out"] += u.get("output_tokens", 0)
        a["ctx"] += (
            u.get("input_tokens", 0)
            + u.get("cache_read_input_tokens", 0)
            + u.get("cache_creation_input_tokens", 0)
        )
for k in sorted(agg):
    a = agg[k]
    print(
        f"{k[0]:9} {k[1]:18} responses={a['resp']:5} think/resp={a['think'] / a['resp']:5.0f} out/resp={a['out'] / a['resp']:5.0f} ctx/resp={a['ctx'] / a['resp'] / 1000:4.0f}k"
    )
