#!/usr/bin/env python3
import json
import sys

d = json.load(open(sys.argv[1]))["sessions"]
for prefix in sys.argv[2:]:
    for sid, s in d.items():
        if not sid.startswith(prefix):
            continue
        print(f"== {sid[:8]} {s['cwd']} {s['first'][:16]} -> {s['last'][:16]}")
        for t, kind, data in s["events"]:
            extra = ""
            if kind == "verifier":
                v = s["verifiers"].get(data, {})
                extra = f"{round((v.get('ms') or 0) / 1000)} s, {v.get('tu')} tools, end {str(v.get('end'))[11:19]}"
            elif kind in ("guard_stale", "guard_other"):
                extra = (
                    (
                        data["msg"][60:200]
                        if kind == "guard_other"
                        else f"{len(data['paths'])} paths"
                    )
                    + " | "
                    + data["cmd"][:80]
                )
            elif kind == "gate_block":
                extra = f"{len(data)} paths"
            elif kind in ("commit_call", "commit_ok"):
                extra = data[:90]
            print(f"   {t[11:19]} {kind:<12} {extra}".replace("\n", " "))
