import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

LOCAL = timezone(timedelta(hours=2))
GAP = timedelta(minutes=10)


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def is_prompt(r):
    if r.get("type") != "user" or r.get("isMeta") or r.get("isCompactSummary"):
        return False
    c = r.get("message", {}).get("content")
    if not isinstance(c, str):
        return False
    return not c.startswith(("<task-notification>", "<bash-", "<local-command", "Caveat:"))


def analyse(path):
    rows = []
    with open(path) as fh:
        for line in fh:
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    stamped = sorted((r for r in rows if r.get("timestamp")), key=lambda r: r["timestamp"])
    if not stamped:
        return None
    times = [ts(r["timestamp"]) for r in stamped]
    active = sum((b - a for a, b in zip(times, times[1:]) if b - a <= GAP), timedelta())
    prompts = [r for r in stamped if is_prompt(r)]
    usage = {}
    tools = {}
    tracking_edits = code_edits = 0
    skill_commit = None
    commit_calls = []
    tool_ids = {}
    for r in stamped:
        if r.get("type") != "assistant":
            continue
        m = r.get("message", {})
        mid = m.get("id")
        u = m.get("usage") or {}
        if mid:
            usage[mid] = u
        for b in m.get("content") or []:
            if b.get("type") != "tool_use":
                continue
            n = b["name"]
            tools[n] = tools.get(n, 0) + 1
            inp = b.get("input") or {}
            if n in ("Edit", "Write"):
                p = inp.get("file_path", "")
                if "/.claude/" in p and p.endswith(".md"):
                    tracking_edits += 1
                else:
                    code_edits += 1
            if n == "Skill" and "commit" in str(inp.get("skill", "")) and skill_commit is None:
                skill_commit = ts(r["timestamp"])
            if n == "Bash" and "git commit -m" in inp.get("command", ""):
                commit_calls.append(b["id"])
                tool_ids[b["id"]] = ts(r["timestamp"])
    failed_commits = 0
    last_commit = None
    for r in stamped:
        if r.get("type") != "user":
            continue
        c = r.get("message", {}).get("content")
        if not isinstance(c, list):
            continue
        for b in c:
            if b.get("type") == "tool_result" and b.get("tool_use_id") in tool_ids:
                if b.get("is_error"):
                    failed_commits += 1
                last_commit = ts(r["timestamp"])
    out_tok = sum(u.get("output_tokens", 0) for u in usage.values())
    think_tok = sum(
        (u.get("output_tokens_details") or {}).get("thinking_tokens", 0) for u in usage.values()
    )
    ctx = [
        u.get("input_tokens", 0)
        + u.get("cache_read_input_tokens", 0)
        + u.get("cache_creation_input_tokens", 0)
        for u in usage.values()
    ]
    turn_ms = sum(
        r.get("durationMs", 0)
        for r in stamped
        if r.get("type") == "system" and r.get("subtype") == "turn_duration"
    )
    hook_ctx = sum(
        len(json.dumps(r["attachment"].get("content", "")))
        for r in stamped
        if r.get("type") == "attachment"
        and r["attachment"].get("type") == "hook_additional_context"
    )
    blocks = sum(
        1
        for r in stamped
        if r.get("type") == "system"
        and r.get("subtype") == "stop_hook_summary"
        and r.get("preventedContinuation")
    )
    compacts = sum(
        1 for r in stamped if r.get("type") == "system" and r.get("subtype") == "compact_boundary"
    )
    first = prompts[0]["message"]["content"] if prompts else ""
    first = first.replace("\n", " ")
    if "<command-name>" in first and "</command-name>" in first:
        s = first.index("<command-name>") + len("<command-name>")
        first = (
            first[s : first.index("</command-name>")]
            + " "
            + first[first.find("<command-args>") + 14 : first.find("</command-args>")]
        )
    closure = None
    if skill_commit:
        closure = ((last_commit or times[-1]) - skill_commit).total_seconds() / 60
    return {
        "id": path.stem[:8],
        "project": path.parent.name.replace("-home-julien-", "")[:18],
        "start": times[0].astimezone(LOCAL).strftime("%m-%d %H:%M"),
        "span_min": round((times[-1] - times[0]).total_seconds() / 60),
        "active_min": round(active.total_seconds() / 60),
        "turn_min": round(turn_ms / 60000),
        "prompts": len(prompts),
        "calls": len(usage),
        "out_ktok": round(out_tok / 1000),
        "think_ktok": round(think_tok / 1000),
        "ctx_max_k": round(max(ctx) / 1000) if ctx else 0,
        "ctx_med_k": round(sorted(ctx)[len(ctx) // 2] / 1000) if ctx else 0,
        "bash": tools.get("Bash", 0),
        "edit_track": tracking_edits,
        "edit_other": code_edits,
        "agents": tools.get("Agent", 0),
        "hook_kchar": round(hook_ctx / 1000),
        "stop_blocks": blocks,
        "compacts": compacts,
        "closure_min": round(closure) if closure is not None else "",
        "commits": len(commit_calls),
        "commit_fail": failed_commits,
        "first": first[:70],
    }


rows = []
for p in sorted(Path.home().joinpath(".claude/projects").glob("*/*.jsonl")):
    a = analyse(p)
    if a and a["prompts"] > 0:
        rows.append(a)
rows.sort(key=lambda r: r["start"])
keys = list(rows[0].keys())
w = csvw = None
import csv

w = csv.DictWriter(sys.stdout, fieldnames=keys, delimiter="\t")
w.writeheader()
w.writerows(rows)
