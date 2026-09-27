import csv
import statistics as st
import sys

rows = list(csv.DictReader(open(sys.argv[1]), delimiter="\t"))
num = [
    "span_min",
    "active_min",
    "turn_min",
    "prompts",
    "calls",
    "out_ktok",
    "think_ktok",
    "ctx_max_k",
    "ctx_med_k",
    "bash",
    "edit_track",
    "edit_other",
    "agents",
    "hook_kchar",
    "stop_blocks",
    "compacts",
    "commits",
    "commit_fail",
]
for r in rows:
    for k in num:
        r[k] = float(r[k])
    r["closure_min"] = float(r["closure_min"]) if r["closure_min"] else None


def period(s):
    if s < "09-22 15:32":
        return "P0 before gate"
    if s < "09-26 16:37":
        return "P1 gate, high"
    return "P2 gate, xhigh"


def group(r):
    return "dotfiles" if r["project"] == "dotfiles" else "other"


def summary(sel, label):
    if not sel:
        return
    tot = lambda k: sum(r[k] for r in sel)
    p = tot("prompts")
    c = tot("calls")
    closures = [r["closure_min"] for r in sel if r["closure_min"] is not None]
    print(
        f"{label:28} n={len(sel):3} prompts={p:5.0f} "
        f"active/prompt={tot('active_min') / p:5.1f}m turn/prompt={tot('turn_min') / p:5.1f}m "
        f"calls/prompt={c / p:5.1f} out_tok/prompt={1000 * tot('out_ktok') / p:6.0f} "
        f"think/call={1000 * tot('think_ktok') / c:5.0f} ctx_med={st.median(r['ctx_med_k'] for r in sel):4.0f}k "
        f"track_edits={tot('edit_track'):4.0f} other_edits={tot('edit_other'):4.0f} "
        f"agents={tot('agents'):3.0f} hook_kchar/prompt={tot('hook_kchar') / p:4.1f} blocks={tot('stop_blocks'):3.0f} "
        f"closures={len(closures):2} closure_med={st.median(closures) if closures else 0:4.0f}m "
        f"commit_fail={tot('commit_fail'):2.0f}/{tot('commits'):2.0f}"
    )


for g in ("dotfiles", "other", None):
    for per in ("P0 before gate", "P1 gate, high", "P2 gate, xhigh"):
        sel = [r for r in rows if period(r["start"]) == per and (g is None or group(r) == g)]
        summary(sel, f"{g or 'all'} {per}")
    print()
