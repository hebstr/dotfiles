import pickle,re,os,sys
d=pickle.load(open('msgs.pkl','rb'))
pat=re.compile(r"(que |qu'est-ce que tu |quelle? .{0,20})recommand|ton avis|tu es s[uû]r|vraiment ?\?|\breco\b ?\?|tu conseilles|ta reco|tu ferais quoi|que ferais-tu",re.I)
want=set(map(int,sys.argv[1].split(',')))
n=0
for f,ms in d.items():
    for i,(t,dt,x) in enumerate(ms):
        if t=='user' and not x.startswith('CMD') and len(x)<600 and pat.search(x):
            n+=1
            if n not in want: continue
            j=i-1;prev=[]
            while j>=0 and ms[j][0]=='assistant': prev.insert(0,ms[j][2]); j-=1
            k=i+1;nxt=[]
            while k<len(ms) and ms[k][0]=='assistant': nxt.append(ms[k][2]); k+=1
            print('#####',n,os.path.basename(f)[:8],dt,'USER:',x[:200])
            print('  PRIOR END:',' '.join(prev).replace('\n',' ')[-900:])
            print('  ANSWER:',' '.join(nxt).replace('\n',' ')[:1100])
