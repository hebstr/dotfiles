"""Classify the misses of reco-relance.sh: harness noise, typo, or syntactic anchor.

Reads nothing on disk of its own: recall_fuzzy.py carries the lemma pass and the
hook replay, recall_load.py the transcripts.
"""

import re

from recall_fuzzy import fold, fuzzy_hit, hook_fires
from recall_load import load

NOISE = ("stop hook feedback:", "<command-message>", "<bash-input>", "<local-command")
# 'commande'/'commandes' sit 2 edits from 'recommande' but are a different word
NOT_A_LEMMA = {"commande", "commandes", "commander", "commandez"}


def main():
    sessions = load()
    prompts = [t for s in sessions for t in s["turns"] if len(t) < 600]

    noise, typo, anchor, other, fired = [], [], [], [], 0
    for t in prompts:
        low = " ".join(fold(t).split())
        f, tok, lem, d = fuzzy_hit(t)
        r = hook_fires(t)
        if r:
            fired += 1
            continue
        if not f:
            continue
        if low.startswith(NOISE) or any(n in low for n in NOISE):
            noise.append((t, tok))
            continue
        if tok in NOT_A_LEMMA:
            noise.append((t, tok))
            continue
        m = re.search(r"\b(re?c?o?m+[a-z]*)\b", low)
        verb = m.group(1) if m else tok
        if d == 0 and lem in ("recommandes", "recommande", "conseil", "reco", "maintenir"):
            anchor.append((t, verb))
        elif d > 0:
            typo.append((t, verb, lem, d))
        else:
            other.append((t, tok, lem))

    print(f"prompts under 600 chars      : {len(prompts)}")
    print(f"hook fires                   : {fired}")
    print(f"missed, harness noise        : {len(noise)}")
    print(f"missed, correctly spelled    : {len(anchor)}   <- syntactic anchor")
    print(f"missed, misspelled           : {len(typo)}   <- typo")
    print(f"missed, other                : {len(other)}")

    print("\n--- correctly spelled, missed by the anchor:")
    for t, _v in anchor:
        print(f"  {' '.join(t.split())[:105]}")
    print("\n--- misspelled, missed:")
    for t, v, _lem, d in typo:
        print(f"  d={d} {v!r}  {' '.join(t.split())[:95]}")
    print("\n--- other:")
    for t, tok, lem in other:
        print(f"  {tok!r}~{lem!r}  {' '.join(t.split())[:95]}")


if __name__ == "__main__":
    main()
