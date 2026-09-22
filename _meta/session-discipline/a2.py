import pickle,re,os
d=pickle.load(open('msgs.pkl','rb'))
pat=re.compile(r"(que |qu'est-ce que tu |quelle? .{0,20})recommand|ton avis|tu es s[uû]r|vraiment ?\?|\breco\b ?\?|tu conseilles|ta reco|tu ferais quoi|que ferais-tu",re.I)
reco=re.compile(r"recommand|\breco\b|je (partirais|prendrais|choisirais|garderais)|mon choix|je conseille",re.I)
n=0;withprior=0
for f,ms in d.items():
    for i,(t,dt,x) in enumerate(ms):
        if t=='user' and not x.startswith('CMD') and len(x)<600 and pat.search(x):
            n+=1
            j=i-1;prev=[]
            while j>=0 and ms[j][0]=='assistant': prev.insert(0,ms[j][2]); j-=1
            k=i+1;nxt=[]
            while k<len(ms) and ms[k][0]=='assistant': nxt.append(ms[k][2]); k+=1
            P='\n'.join(prev);N='\n'.join(nxt)
            has=bool(reco.search(P))
            withprior+=has
            if not has: continue
            # extract reco sentences
            ps=[s for s in re.split(r'\n+',P) if reco.search(s)]
            print('#####',n,os.path.basename(f)[:8],dt,'USER:',x.replace('\n',' ')[:200])
            print('  PRIOR RECO:',' || '.join(p[:400] for p in ps[-3:]))
            print('  ANSWER:',N.replace('\n',' ')[:1200])
print(n,withprior)
