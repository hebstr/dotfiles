#!/usr/bin/env python3
import collections
import datetime as dt
import glob
import json
import os
import re
import sys

ROOT = os.path.expanduser("~/.claude/projects")
SELF = "b1278201-a50e-4b9b-a9df-4d7274777f96"
WRITE_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}
NOTIF = re.compile(
    r"<tool-use-id>(?P<id>[^<]+)</tool-use-id>.*?<status>(?P<st>[^<]+)</status>.*?"
    r"<usage><subagent_tokens>(?P<tok>\d+)</subagent_tokens><tool_uses>(?P<tu>\d+)</tool_uses>"
    r"<duration_ms>(?P<ms>\d+)</duration_ms></usage>",
    re.S,
)


def when(s):
    if not s:
        return None
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def real(p):
    if not p:
        return p
    try:
        return os.path.realpath(os.path.expanduser(p))
    except OSError:
        return p


def text_of(content):
    if isinstance(content, str):
        return content
    out = []
    for c in content or []:
        if isinstance(c, dict):
            if c.get("type") == "text":
                out.append(c.get("text", ""))
            elif c.get("type") == "tool_result":
                out.append(text_of(c.get("content")))
    return "\n".join(out)


def listed_paths(text):
    return [ln.strip() for ln in text.splitlines() if ln.startswith("  /")]


def is_verifier(prompt):
    head = (prompt or "")[:400]
    return "# Tracking verifier" in head or "rificateur de tracking" in head


sessions = {}
writes = collections.defaultdict(list)

for f in sorted(glob.glob(f"{ROOT}/*/*.jsonl")):
    sid = os.path.basename(f)[:-6]
    if sid == SELF:
        continue
    project = os.path.basename(os.path.dirname(f))
    s = {
        "sid": sid,
        "project": project,
        "cwd": None,
        "events": [],
        "tools": {},
        "verifiers": {},
        "first": None,
        "last": None,
    }
    with open(f, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                continue
            t = when(r.get("timestamp"))
            if t:
                s["first"] = s["first"] or t
                s["last"] = t
            if r.get("cwd") and not s["cwd"]:
                s["cwd"] = r["cwd"]
            typ = r.get("type")
            if typ == "queue-operation" and r.get("operation") == "enqueue":
                c = r.get("content") or ""
                if "<task-notification>" in c:
                    m = NOTIF.search(c)
                    if m and m["id"] in s["verifiers"] and m["ms"]:
                        v = s["verifiers"][m["id"]]
                        v.setdefault("ms", int(m["ms"]))
                        v.setdefault("tok", int(m["tok"]))
                        v.setdefault("tu", int(m["tu"]))
                        v.setdefault("end", t)
                continue
            msg = r.get("message") or {}
            content = msg.get("content")
            if typ == "assistant" and isinstance(content, list):
                for c in content:
                    if not isinstance(c, dict) or c.get("type") != "tool_use":
                        continue
                    name, inp = c.get("name"), c.get("input") or {}
                    s["tools"][c.get("id")] = (name, inp, t)
                    if name == "Skill" and (inp.get("skill") or "").split(":")[-1] == "commit":
                        s["events"].append((t, "skill_model", ""))
                    elif name == "Agent" and is_verifier(inp.get("prompt")):
                        s["verifiers"][c["id"]] = {"start": t, "bg": inp.get("run_in_background")}
                        s["events"].append((t, "verifier", c["id"]))
                    elif name in WRITE_TOOLS and inp.get("file_path"):
                        writes[real(inp["file_path"])].append((t, sid))
                    elif name == "Bash":
                        cmd = inp.get("command") or ""
                        if re.search(r"(^|[;&|(\s])git\s+commit\b", cmd):
                            s["events"].append((t, "commit_call", cmd[:300]))
            elif typ == "user":
                if isinstance(content, str):
                    if re.search(r"<command-name>/(claude:)?commit</command-name>", content):
                        s["events"].append((t, "skill_user", ""))
                    if content.startswith("Stop hook feedback") and "Commit gate:" in content:
                        s["events"].append((t, "gate_block", listed_paths(content)))
                    if "<task-notification>" in content:
                        m = NOTIF.search(content)
                        if m and m["id"] in s["verifiers"] and m["ms"]:
                            v = s["verifiers"][m["id"]]
                            v.setdefault("ms", int(m["ms"]))
                            v.setdefault("tok", int(m["tok"]))
                            v.setdefault("tu", int(m["tu"]))
                            v.setdefault("end", t)
                    continue
                for c in content or []:
                    if not isinstance(c, dict) or c.get("type") != "tool_result":
                        continue
                    tid = c.get("tool_use_id")
                    body = text_of(c.get("content"))
                    if tid in s["verifiers"]:
                        tur = r.get("toolUseResult")
                        v = s["verifiers"][tid]
                        if isinstance(tur, dict):
                            v["agentId"] = tur.get("agentId")
                            v["model"] = tur.get("resolvedModel")
                            if tur.get("totalDurationMs"):
                                v.setdefault("ms", tur["totalDurationMs"])
                                v.setdefault("tok", tur.get("totalTokens"))
                                v.setdefault("tu", tur.get("totalToolUseCount"))
                                v.setdefault("end", t)
                    if "hooks/git-write-guard.sh]: git write guard:" in body:
                        cmd = (s["tools"].get(tid) or (None, {}, None))[1].get("command", "")
                        kind = (
                            "guard_stale"
                            if "outside the tracking files changed" in body
                            else "guard_other"
                        )
                        s["events"].append(
                            (
                                t,
                                kind,
                                {"paths": listed_paths(body), "cmd": cmd[:300], "msg": body[:300]},
                            )
                        )
                    elif tid in s["tools"] and s["tools"][tid][0] == "Bash":
                        cmd = s["tools"][tid][1].get("command", "")
                        if re.search(r"(^|[;&|(\s])git\s+commit\b", cmd) and not c.get("is_error"):
                            s["events"].append((t, "commit_ok", cmd[:200]))
    if any(
        e[1] in ("skill_model", "skill_user", "verifier", "guard_stale", "gate_block")
        for e in s["events"]
    ):
        sessions[sid] = s

for p in writes:
    writes[p].sort()


def attribute(path, t, sid, since):
    own_after = [
        w
        for w in writes.get(path, [])
        if w[1] == sid and w[0] <= t and (since is None or w[0] >= since)
    ]
    own_before = [
        w for w in writes.get(path, []) if w[1] == sid and since is not None and w[0] < since
    ]
    others = [
        w
        for w in writes.get(path, [])
        if w[1] != sid and w[0] <= t and (since is None or w[0] >= since)
    ]
    if own_after and others:
        return "own_and_other", {w[1][:8] for w in others}
    if own_after:
        return "own_after_verifier", set()
    if others:
        return "other_session", {w[1][:8] for w in others}
    if own_before:
        return "own_before_verifier_only", set()
    return "unattributed", set()


json.dump(
    {
        "sessions": {
            sid: {
                "project": s["project"],
                "cwd": s["cwd"],
                "first": s["first"].isoformat() if s["first"] else None,
                "last": s["last"].isoformat() if s["last"] else None,
                "events": [(e[0].isoformat() if e[0] else None, e[1], e[2]) for e in s["events"]],
                "verifiers": {
                    k: {
                        kk: (vv.isoformat() if isinstance(vv, dt.datetime) else vv)
                        for kk, vv in v.items()
                    }
                    for k, v in s["verifiers"].items()
                },
            }
            for sid, s in sessions.items()
        },
    },
    open(sys.argv[1], "w"),
    default=str,
)

rows = []
attrib = collections.Counter()
attrib_by_kind = collections.Counter()
for sid, s in sorted(
    sessions.items(), key=lambda kv: kv[1]["first"] or dt.datetime.min.replace(tzinfo=dt.UTC)
):
    ev = s["events"]
    vs = [v for v in s["verifiers"].values()]
    ms = [v.get("ms") for v in vs if v.get("ms")]
    last_verifier = None
    per_event = []
    for t, kind, data in ev:
        if kind == "verifier":
            last_verifier = t
        if kind in ("guard_stale", "gate_block"):
            paths = data["paths"] if kind == "guard_stale" else data
            for p in paths:
                a, who = attribute(p, t, sid, last_verifier)
                attrib[a] += 1
                attrib_by_kind[(kind, a)] += 1
                per_event.append((kind, t, p, a, sorted(who)))
    rows.append((s, ev, vs, ms, per_event))

print("sessions with commit activity:", len(rows))
print()
fmt = "{:<9} {:<34} {:>3} {:>3} {:>3} {:>3} {:>3} {:>3} {:>8} {:>8}"
print(fmt.format("sid", "project", "sk", "ver", "gst", "goth", "gat", "cok", "ver_s", "max_s"))
tot = collections.Counter()
for s, ev, vs, ms, _ in rows:
    k = collections.Counter(e[1] for e in ev)
    sk = k["skill_model"] + k["skill_user"]
    tot.update(k)
    tot["ver_ms"] += sum(ms)
    print(
        fmt.format(
            s["sid"][:8],
            s["project"].replace("-home-julien-", "")[:34],
            sk,
            len(vs),
            k["guard_stale"],
            k["guard_other"],
            k["gate_block"],
            k["commit_ok"],
            round(sum(ms) / 1000),
            round(max(ms) / 1000) if ms else 0,
        )
    )
print()
print("totals:", dict(tot))
print()
print("stale path attribution:", dict(attrib))
print("by kind:", {f"{k[0]}/{k[1]}": v for k, v in attrib_by_kind.items()})
print()
for s, ev, vs, ms, per_event in rows:
    for kind, t, p, a, who in per_event:
        wc = [sessions[w]["cwd"] for w in sessions if w[:8] in who] if who else []
        other_cwds = sorted(
            {(sessions[k]["cwd"] if k in sessions else "?") for k in sessions if k[:8] in who}
        )
        print(
            f"{t.isoformat()[:16]} {s['sid'][:8]} {kind:<11} {a:<25} {p.replace('/home/julien/', '~/')} {sorted(who)}"
        )
