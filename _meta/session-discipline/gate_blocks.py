#!/usr/bin/env python3
import collections
import glob
import json
import os
import re

ROOT = os.path.expanduser("~/.claude/projects")
SELF = "b1278201-a50e-4b9b-a9df-4d7274777f96"
ASSIGN = r'(?:[A-Za-z_][A-Za-z0-9_]*=(?:"[^"\n]*"|[^ \t\n"])*[ \t]+)*'
GATE = re.compile(
    r"^[ \t]*(?:"
    + ASSIGN
    + r"git [^\n]*[;&|][ \t]*)?"
    + ASSIGN
    + r"git(?:[ \t]+-[Cc][ \t]+[^ \t\n]+)*[ \t]+commit\b"
)
CD_COMMIT = re.compile(r"^[ \t]*(?:cd|pushd)\b[^\n]*[;&|][ \t]*git[ \t]+(?:add|commit)\b")
FALLBACK = re.compile(
    r"git[ \t]+add[^\n;&|]*(?:\s-A\b|\s--all\b|\s-p\b|\s--patch\b|\s-i\b|[*?\[])|git[ \t]+mv\b"
)

stats = collections.Counter()
examples = []
for f in glob.glob(f"{ROOT}/*/*.jsonl"):
    if SELF in f or "instructions-ab" in f:
        continue
    for line in open(f, encoding="utf-8", errors="replace"):
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if r.get("type") != "assistant":
            continue
        c = (r.get("message") or {}).get("content")
        if not isinstance(c, list):
            continue
        for x in c:
            if not isinstance(x, dict) or x.get("type") != "text":
                continue
            lines = x["text"].split("\n")
            fence = False
            fence_lang = ""
            hits = []
            cd_hits = 0
            for ln in lines:
                s = ln.strip()
                if s.startswith("```"):
                    fence = not fence
                    fence_lang = s[3:].strip() if fence else ""
                    continue
                if GATE.search(ln):
                    hits.append((fence, fence_lang, ln))
                if fence and CD_COMMIT.search(ln):
                    cd_hits += 1
            if cd_hits:
                stats["texts_with_cd_then_git_in_fence"] += 1
            if not hits:
                continue
            stats["texts_matching_gate"] += 1
            if all(h[0] for h in hits):
                stats["all_hits_fenced"] += 1
                if all(h[1] == "bash" for h in hits):
                    stats["all_hits_in_bash_fence"] += 1
            else:
                stats["some_hit_unfenced"] += 1
                if len(examples) < 8:
                    examples.append(next(h[2] for h in hits if not h[0])[:140])
            if FALLBACK.search(x["text"]):
                stats["text_with_fallback_form"] += 1

print(dict(stats))
print("unfenced examples:")
for e in examples:
    print("  ", e)
