"""Size the miss rate of reco-relance.sh on the retained transcripts (2026-09-28).

Not circular with the hook's own regex: the lemma pass is built from lemmas, not
from the pattern, so it finds prompts the pattern never could. Each prompt is
then replayed through the hook itself, so "fires" is the hook's real verdict.
"""

import re
import subprocess
import unicodedata

from recall_load import load

HOOK = "/home/julien/dotfiles/claude/.claude/hooks/reco-relance.sh"

LEMMAS = [
    "recommandes",
    "recommande",
    "recommander",
    "recommandation",
    "recommandations",
    "recommend",
    "recommends",
    "conseilles",
    "conseille",
    "conseil",
    "maintiens",
    "maintenir",
]
SHORT = ["reco", "sur", "sure", "vraiment", "really"]


def fold(s):
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn")


def lev(a, b):
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def fuzzy_hit(text):
    """True when a token is within a typo's distance of a recommendation lemma."""
    for tok in re.findall(r"[a-z]+", fold(text)):
        n = len(tok)
        for lem in LEMMAS:
            if abs(n - len(lem)) > 2:
                continue
            d = lev(tok, lem)
            if d <= (2 if n >= 8 else 1):
                return True, tok, lem, d
        if n >= 4:
            for lem in SHORT:
                if tok == lem:
                    return True, tok, lem, 0
    return False, None, None, None


def hook_fires(prompt):
    payload = (
        '{"prompt":'
        + subprocess.run(
            ["jq", "-Rs", "."], input=prompt, capture_output=True, text=True
        ).stdout.strip()
        + ',"session_id":"probe","cwd":"/home/julien/dotfiles"}'
    )
    out = subprocess.run(["bash", HOOK], input=payload, capture_output=True, text=True)
    return bool(out.stdout.strip())


def main():
    sessions = load()
    prompts = [(s["id"], t) for s in sessions for t in s["turns"]]
    short = [(sid, t) for sid, t in prompts if len(t) < 600]
    print(f"typed prompts: {len(prompts)}  of which under 600 chars: {len(short)}")

    fuzzy, regex_only, fuzzy_only, both = [], [], [], []
    for sid, t in short:
        f, tok, lem, d = fuzzy_hit(t)
        r = hook_fires(t)
        if f:
            fuzzy.append((sid, t, tok, lem, d))
        if f and r:
            both.append((sid, t))
        elif f and not r:
            fuzzy_only.append((sid, t, tok, lem, d))
        elif r and not f:
            regex_only.append((sid, t))

    print(f"\nhook fires            : {len(both) + len(regex_only)}")
    print(f"fuzzy lemma match     : {len(fuzzy)}")
    print(f"both                  : {len(both)}")
    print(f"fuzzy only (MISSED)   : {len(fuzzy_only)}")
    print(f"regex only            : {len(regex_only)}")

    print("\n--- missed by the hook, caught by the lemma pass:")
    for sid, t, tok, lem, d in fuzzy_only:
        one = " ".join(t.split())[:110]
        print(f"  [{sid[:8]}] d={d} {tok!r}~{lem!r}  {one}")

    print("\n--- caught only by the regex (fuzzy pass blind to these):")
    for sid, t in regex_only:
        print(f"  [{sid[:8]}] {' '.join(t.split())[:110]}")


if __name__ == "__main__":
    main()
