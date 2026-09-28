import json

BENCH = "/home/julien/dotfiles/_meta/session-discipline/recall_bench.json"
HARNESS = ("stop hook feedback:", "<command-message>", "<bash-input>", "<local-command")

rows = json.load(open(BENCH))["rows"]
for r in rows:
    b = r["bucket"]
    if b == "typo" and r["token"] == "recommande":
        b = "anchor"
    if b == "noise":
        low = " ".join(r["prompt"].lower().split())
        b = "harness" if any(n in low for n in HARNESS) else "notalemma"
    r["fixed"] = b

print("--- the 2 harness rows holding a '?'")
for r in rows:
    if r["fixed"] == "harness" and "?" in r["prompt"]:
        print("   ", r["prompt"][:180])

print("\n--- the 12 anchor rows a bare '?' catches")
for r in rows:
    if r["fixed"] == "anchor" and "?" in r["prompt"]:
        print("   ", r["prompt"][:130])

order = ["fires", "typo", "anchor", "harness", "notalemma"]
counts = {b: sum(1 for r in rows if r["fixed"] == b) for b in order}
print("\n--- '?' plus a length cap")
for n in (150, 200, 250, 300, 400, 10**9):
    hits = dict.fromkeys(order, 0)
    for r in rows:
        if "?" in r["prompt"] and len(r["prompt"]) < n:
            hits[r["fixed"]] += 1
    print(f"len<{n:<12d} " + " ".join(f"{b}={hits[b]}/{counts[b]}" for b in order))

print("\n--- '?' in the LAST 120 chars of the prompt (trailing question)")
for n in (60, 120, 200, 10**9):
    hits = dict.fromkeys(order, 0)
    for r in rows:
        if "?" in r["prompt"][-n:]:
            hits[r["fixed"]] += 1
    print(f"tail{n:<10d} " + " ".join(f"{b}={hits[b]}/{counts[b]}" for b in order))
