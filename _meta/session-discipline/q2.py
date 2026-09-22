import pickle,re,json
S=pickle.load(open("s.pkl","rb"));R=pickle.load(open("rows.pkl","rb"))
TP=re.compile(r"(\.claude/|PLAN|DEFERRED|memory/|CLAUDE\.md|MEMORY\.md|_meta/notes|DESIGN|HANDOFF|CONTEXT)",re.I)
ADM=re.compile(r"(\bnon\b[ ,.:]|pas (tout à fait|encore|entièrement)|pas à jour|stale|obsolète|périmé|manqu|oubli|dérive|désaligné|n'était pas|n'est pas (à jour|consigné|reflété)|il reste|restait|à corriger|je corrige|corrigé|incohéren|pas été (mis|consign|report))",re.I)
asks=0;edit=0;adm=0;either=0;sess_e=set();sess_a=set();ex=[]
for r in R:
    if r["nu"]<5: continue
    t=S[r["f"]]
    for i in r["a"]:
        asks+=1
        j=i+1;E=False;txt=""
        while j<len(t) and t[j][0]!="user":
            k,ts,s=t[j]
            if k=="tool":
                d=json.loads(s) if s.endswith("}") else {"name":"?","input":{}}
                try: d=json.loads(s)
                except: d={"name":s[:40],"input":{"file_path":s}}
                if d.get("name") in ("Edit","Write","MultiEdit") and TP.search(json.dumps(d.get("input",{}))[:400]): E=True
            elif k=="atext": txt+=s+"\n"
            j+=1
        A_=bool(ADM.search(txt[:3000]))
        edit+=E;adm+=A_;either+=(E or A_)
        if E: sess_e.add(r["f"])
        if E or A_: sess_a.add(r["f"])
        ex.append((r["f"],t[i][1][:10],t[i][2][:80],E,A_,txt[:500].replace("\n"," ")))
print("asks",asks,"edit",edit,"admit",adm,"either",either)
print("sessions with A",sum(1 for r in R if r["nu"]>=5 and r["a"]),"sess edit",len(sess_e),"sess either",len(sess_a))
pickle.dump(ex,open("ex.pkl","wb"))
