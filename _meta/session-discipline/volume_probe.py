import sys

sys.path.insert(0, "/home/julien/dotfiles/_meta/session-discipline")
from recall_load import load

HARNESS = ("stop hook feedback:", "<command-message>", "<bash-input>", "<local-command")

prompts = [t for s in load() for t in s["turns"] if len(t) < 600]
print(f"prompts under 600 chars: {len(prompts)}")

kept = [p for p in prompts if not any(h in " ".join(p.lower().split()) for h in HARNESS)]
print(f"after the formal harness strip: {len(kept)}")

q = [p for p in kept if "?" in p]
print(f"holding a question mark: {len(q)}  ({100 * len(q) / len(kept):.0f} % of the stripped base)")

for n in (80, 120, 200, 300):
    sub = [p for p in q if len(p) < n]
    print(f"  and under {n} chars: {len(sub)}")
