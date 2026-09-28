"""Freeze the labelled bench of the reco-relance.sh recall measure.

The transcripts behind the measure expire after `cleanupPeriodDays` (7), so the
counts of recall_classify.py cannot be reproduced later. This writes the labelled
prompts to a JSON file that outlives them, which `.gitignore` keeps out of this
public repository since it quotes user prompts.

Usage: python3 recall_bench.py [out.json]   (default: recall_bench.json here)
"""

import json
import os
import sys

from recall_classify import NOISE, NOT_A_LEMMA
from recall_fuzzy import fold, fuzzy_hit, hook_fires
from recall_load import load

HERE = os.path.dirname(os.path.abspath(__file__))


def classify(text):
    """Return the bucket a prompt falls in, mirroring recall_classify.main()."""
    low = " ".join(fold(text).split())
    f, tok, lem, d = fuzzy_hit(text)
    if hook_fires(text):
        return "fires", tok, lem, d
    if not f:
        return None, None, None, None
    if low.startswith(NOISE) or any(n in low for n in NOISE):
        return "noise", tok, lem, d
    if tok in NOT_A_LEMMA:
        return "noise", tok, lem, d
    if d == 0 and lem in ("recommandes", "recommande", "conseil", "reco", "maintenir"):
        return "anchor", tok, lem, d
    if d > 0:
        return "typo", tok, lem, d
    return "other", tok, lem, d


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "recall_bench.json")
    rows = []
    for s in load():
        for t in s["turns"]:
            if len(t) >= 600:
                continue
            bucket, tok, lem, d = classify(t)
            if bucket is None:
                continue
            rows.append(
                {
                    "session": s["id"],
                    "bucket": bucket,
                    "token": tok,
                    "lemma": lem,
                    "distance": d,
                    "prompt": " ".join(t.split()),
                }
            )
    counts = {}
    for r in rows:
        counts[r["bucket"]] = counts.get(r["bucket"], 0) + 1
    with open(out, "w", encoding="utf-8") as fh:
        json.dump({"counts": counts, "rows": rows}, fh, ensure_ascii=False, indent=1)
    print(f"{len(rows)} labelled prompts -> {out}")
    for b in sorted(counts):
        print(f"  {b:8s} {counts[b]}")


if __name__ == "__main__":
    main()
