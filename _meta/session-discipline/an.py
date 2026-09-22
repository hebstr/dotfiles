import pickle,re,os,collections,json
S=pickle.load(open("s.pkl","rb"))
A=re.compile(r"(t[ou]t?[a-z]{0,2}\s+(est|ets|et|st|sst|ça est|ca est)\s+(bien\s+)?(update|updtae|à jour|a jour|consign|track)|tracking\s*\?|vérifi\w* le tracking|as[- ]tu (vérifié|fait|fais) (le tracking|une dernière vérif)|avant de (propos|prpos|commit)|checkup|check si tout|vérifie si tout|tout (est )?(consigné|tracké)|des choses à consigner|staleness)",re.I)
B=re.compile(r"((je|on) (peux|peut|va|vais) (commit et )?(clore|clôtur|clotur|marr|m'arr|arr[êe]ter|fermer)|que reste|reste[- ]t[- ]il|rien d'autre|quoi d'autre|clore ici)",re.I)
first=lambda t:t[0][1][:10] if t else ""
rows=[]
for f,t in S.items():
    nu=sum(1 for x in t if x[0]=="user")
    proj=os.path.basename(os.path.dirname(f)).replace("-home-julien-","").replace("Documents-","")
    dates=[x[1][:10] for x in t if x[1]]
    a=[i for i,x in enumerate(t) if x[0]=="user" and A.search(x[2]) and len(x[2])<600]
    b=[i for i,x in enumerate(t) if x[0]=="user" and B.search(x[2]) and len(x[2])<600]
    rows.append(dict(f=f,proj=proj,nu=nu,a=a,b=b,d0=min(dates) if dates else "",d1=max(dates) if dates else ""))
pickle.dump(rows,open("rows.pkl","wb"))
el=[r for r in rows if r["nu"]>=5]
print("eligible",len(el),"date range",min(r["d0"] for r in el),max(r["d1"] for r in el))
c=collections.defaultdict(lambda:[0,0,0,0])
for r in el:
    k=c[r["proj"]]; k[0]+=1; k[1]+=bool(r["a"]); k[2]+=bool(r["b"]); k[3]+=bool(r["a"] or r["b"])
tot=[sum(v[i] for v in c.values()) for i in range(4)]
for p,v in sorted(c.items(),key=lambda x:-x[1][0]): print(p,v)
print("TOTAL",tot)
# by date: sessions starting on/after 2026-09-15
for cut in ["2026-09-01","2026-09-15"]:
    e2=[r for r in el if r["d0"]>=cut]
    print(cut,len(e2),sum(bool(r["a"]) for r in e2),sum(bool(r["b"]) for r in e2),sum(bool(r["a"] or r["b"]) for r in e2))
import collections as C
print(C.Counter(r["d0"][:7] for r in el))
print("total asks A",sum(len(r["a"]) for r in el),"B",sum(len(r["b"]) for r in el))
