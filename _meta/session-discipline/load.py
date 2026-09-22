import json, os, subprocess, pickle

root = os.path.expanduser("~/.claude/projects")
out = subprocess.run(["fdfind", "-e", "jsonl", ".", root, "--changed-within", "90d"], capture_output=True, text=True).stdout.split()
files = [f for f in out if "/subagents/" not in f and "/tool-results/" not in f]
sessions = {}
for f in files:
    turns = []
    with open(f) as fh:
        for line in fh:
            try:
                r = json.loads(line)
            except Exception:
                continue
            if r.get("isSidechain"):
                continue
            t = r.get("type")
            ts = r.get("timestamp", "")
            msg = r.get("message") or {}
            c = msg.get("content")
            if t == "user":
                texts = []
                if isinstance(c, str):
                    texts = [c]
                elif isinstance(c, list):
                    texts = [x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text"]
                for s in texts:
                    st = s.lstrip()
                    if not st or st.startswith(("<command-", "<system-reminder>", "<task-notification", "<local-command", "[Request interrupted", "Caveat:")):
                        if "<command-name>" in st:
                            turns.append(("cmd", ts, st[:300]))
                        continue
                    if r.get("isMeta"):
                        continue
                    turns.append(("user", ts, s))
            elif t == "assistant" and isinstance(c, list):
                for x in c:
                    if x.get("type") == "text":
                        turns.append(("atext", ts, x.get("text", "")))
                    elif x.get("type") == "tool_use":
                        turns.append(("tool", ts, json.dumps({"name": x.get("name"), "input": x.get("input")})[:2000]))
    sessions[f] = turns
pickle.dump(sessions, open(os.path.join(os.path.dirname(__file__), "s.pkl"), "wb"))
print(len(sessions), sum(1 for v in sessions.values() if sum(1 for t in v if t[0] == "user") >= 5))
