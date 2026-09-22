import pickle,re,json
S=pickle.load(open("s.pkl","rb"));R=pickle.load(open("rows.pkl","rb"))
TP=re.compile(r"(\.claude/|PLAN|DEFERRED|memory/|CLAUDE\.md|MEMORY\.md|_meta/notes)",re.I)
from an import A
props=0;first_before=0;sess=0;push_next=0;push_any=0;push_after_first_unverified=0;fu=0
for r in R:
    if r["nu"]<5: continue
    t=S[r["f"]]
    idx=[i for i,x in enumerate(t) if x[0]=="atext" and "git commit -m" in x[2]]
    if not idx: continue
    sess+=1
    for n,i in enumerate(idx):
        # dedupe: only count one proposal per assistant turn
        if n and not any(t[j][0]=="user" for j in range(idx[n-1],i)): continue
        props+=1
        nxt=next((j for j in range(i+1,len(t)) if t[j][0]=="user"),None)
        if nxt is not None and A.search(t[nxt][2]): push_next+=1
    i=idx[0]
    ver=any((x[0]=="user" and A.search(x[2])) or (x[0]=="tool" and ('"Edit"' in x[2] or '"Write"' in x[2]) and TP.search(x[2][:400])) for x in t[:i])
    if not ver:
        fu+=1
        us=[j for j in range(i+1,len(t)) if t[j][0]=="user"][:2]
        if any(A.search(t[j][2]) for j in us): push_after_first_unverified+=1
print("sessions with commit proposal",sess,"proposal turns",props,"next user msg is tracking ask",push_next)
print("first proposal with no prior tracking edit/ask",fu,"-> user tracking ask within next 2 msgs",push_after_first_unverified)
