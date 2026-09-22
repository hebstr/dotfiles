import pickle,re,os
from collections import Counter,defaultdict
d=pickle.load(open('msgs.pkl','rb'))
prop=re.compile(r"/audit:(walkthrough|blindspot)\s+[\"']?([~\w./*-]+)")
def norm(p): return os.path.basename(p.rstrip('/').replace('*','').replace('"','')) 
proj={}
for f in d: proj[f]=os.path.basename(os.path.dirname(f))
props=[];runs=[]
for f,ms in d.items():
    b=os.path.basename(f)[:8]
    for i,(t,dt,x) in enumerate(ms):
        if t=='assistant':
            for m in prop.finditer(x):
                tg=m.group(2)
                if tg.startswith('-') or tg in('sur','a','du','sans','appelle','first?') or tg.startswith('<'): continue
                props.append((b,proj[f],dt,m.group(1),norm(tg),i))
        if t=='user' and x.startswith('CMD') and re.search(r'audit:(walkthrough|blindspot)',x):
            m=re.search(r'audit:(walkthrough|blindspot)\s+(\S+)',x)
            if m: runs.append((b,proj[f],dt,m.group(1),norm(m.group(2)),x[:150]))
print('projects of runs:',Counter(r[1] for r in runs))
print('projects of proposals:',Counter(p[1] for p in props).most_common())
# unique (session,target) proposals
U=defaultdict(set)
for b,pj,dt,k,tg,i in props: U[(b,pj,k,tg)].add(dt)
runset=set((r[3],r[4]) for r in runs); runtg=set(r[4] for r in runs)
print('unique session-target proposals',len(U))
matched=[u for u in U if (u[2],u[3]) in runset]; matched_any=[u for u in U if u[3] in runtg]
print('matched same kind+target',len(matched),'target only',len(matched_any))
tg_prop=set((u[2],u[3]) for u in U)
print('distinct kind+target proposed',len(tg_prop),'of which run',len(tg_prop & runset))
for k in sorted(tg_prop): print(k, 'RUN' if k in runset else '')
print('run kinds',Counter(r[3] for r in runs))
