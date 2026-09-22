import pickle,re,os
from collections import Counter
d=pickle.load(open('msgs.pkl','rb'))
prop=re.compile(r"/audit:(walkthrough|blindspot)\s+([^\s`]+)?")
dates=[]
S_prop=0;S_audit=0;props=[];runs=[]
for f,ms in d.items():
    b=os.path.basename(f)[:8]
    for t,dt,x in ms: dates.append(dt)
    ap=[(i,dt,m.group(1),m.group(2)) for i,(t,dt,x) in enumerate(ms) if t=='assistant' for m in prop.finditer(x)]
    if ap: S_prop+=1; props.append((b,ap[0][1],len(ap),Counter(a[2] for a in ap),sorted(set(str(a[3]) for a in ap))[:4]))
    ur=[(i,dt,x[:160]) for i,(t,dt,x) in enumerate(ms) if t=='user' and re.search(r'(CMD /?audit:(walkthrough|blindspot))|^\s*/audit:(walkthrough|blindspot)',x)]
    if ur: S_audit+=1; runs.append((b,ur[0][1],ur[0][0],ur[0][2].replace('\n',' ')))
dates=[x for x in dates if x]
print('date range',min(dates),max(dates),'sessions',len(d))
print('sessions proposing',S_prop,'sessions running audit',S_audit)
print('--- runs');[print(r) for r in runs]
print('--- props');[print(p) for p in props]
