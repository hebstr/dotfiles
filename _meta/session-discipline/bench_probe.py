import json

BENCH = "/home/julien/dotfiles/_meta/session-discipline/recall_bench.json"
HARNESS = ("stop hook feedback:", "<command-message>", "<bash-input>", "<local-command")
NOT_A_LEMMA = {"commande", "commandes", "commander", "commandez"}

rows = json.load(open(BENCH))["rows"]

for r in rows:
    b = r["bucket"]
    if b == "typo" and r["token"] == "recommande":
        b = "anchor"
    if b == "noise":
        low = " ".join(r["prompt"].lower().split())
        b = "harness" if any(n in low for n in HARNESS) else "notalemma"
    r["fixed"] = b

counts = {}
for r in rows:
    counts[r["fixed"]] = counts.get(r["fixed"], 0) + 1
print("corrected buckets:", counts)


def q(p):
    return "?" in p


def short(n):
    return lambda p: len(p) < n


RULES = {
    "?": q,
    "len<80": short(80),
    "len<120": short(120),
    "? and len<80": lambda p: q(p) and len(p) < 80,
    "? and len<120": lambda p: q(p) and len(p) < 120,
    "? and len<200": lambda p: q(p) and len(p) < 200,
}

order = ["fires", "typo", "anchor", "harness", "notalemma", "other"]
print()
print(f"{'rule':16s} " + " ".join(f"{b[:9]:>9s}" for b in order))
for name, fn in RULES.items():
    hits = dict.fromkeys(order, 0)
    for r in rows:
        if fn(r["prompt"]):
            hits[r["fixed"]] += 1
    print(f"{name:16s} " + " ".join(f"{hits[b]:>4d}/{counts.get(b, 0):<4d}" for b in order))

print("\n--- rows a '?' rule would miss, by bucket")
for b in ("typo", "anchor", "fires"):
    miss = [r["prompt"] for r in rows if r["fixed"] == b and not q(r["prompt"])]
    print(f"[{b}] {len(miss)}")
    for m in miss:
        print("   ", m[:110])

print("\n--- length distribution of the required-to-fire rows")
for b in ("typo", "anchor", "fires"):
    ls = sorted(len(r["prompt"]) for r in rows if r["fixed"] == b)
    print(
        f"[{b}] n={len(ls)} min={ls[0]} med={ls[len(ls) // 2]} p90={ls[int(len(ls) * 0.9)]} max={ls[-1]}"
    )

print("\n--- harness + notalemma rows that a '? and len<120' rule would hit")
for r in rows:
    if r["fixed"] in ("harness", "notalemma") and q(r["prompt"]) and len(r["prompt"]) < 120:
        print(f"  [{r['fixed']}] {r['prompt'][:110]}")
