import pickle,re
S=pickle.load(open("s.pkl","rb"));R=pickle.load(open("rows.pkl","rb"))
from an import A
TP=re.compile(r"(\.claude/|PLAN|DEFERRED|memory/|CLAUDE\.md|MEMORY\.md|_meta/notes)",re.I)
EXPL=re.compile(r"(avant de (propos|prpos|prop)|dernière vérif|revérifié les diffs|vérifi\w+ le tracking)",re.I)
tot=0;nov=0;nov_push=0;v_push=0;expl=0
for r in R:
    if r["nu"]<5: continue
    t=S[r["f"]]
    for i,x in enumerate(t):
        if x[0]!="atext" or "git commit -m" not in x[2]: continue
        p=max([j for j in range(i) if t[j][0]=="user"],default=-1)
        if any(t[j][0]=="atext" and "git commit -m" in t[j][2] for j in range(p+1,i)): continue
        tot+=1
        seg=t[p+1:i]
        v=any(y[0]=="tool" and TP.search(y[2][:600]) for y in seg)
        nxt=next((j for j in range(i+1,len(t)) if t[j][0]=="user"),None)
        pu=nxt is not None and A.search(t[nxt][2])
        if nxt is not None and EXPL.search(t[nxt][2]): expl+=1
        if v: v_push+=bool(pu)
        else: nov+=1; nov_push+=bool(pu)
print("proposal turns",tot,"no tracking touch in same turn",nov,"pushed",nov_push,"| with touch",tot-nov,"pushed",v_push,"| explicit 'avant de proposer' pushback",expl)
