import pickle,re,os
d=pickle.load(open('msgs.pkl','rb'))
pat=re.compile(r"(que |qu'est-ce que tu |quelle? .{0,20})recommand|ton avis|tu es s[uû]r|vraiment ?\?|\breco\b ?\?|tu conseilles|ta reco|tu ferais quoi|que ferais-tu|lequel tu|laquelle tu|tu pr[ée]f[èe]res",re.I)
n=0
for f,ms in d.items():
    for i,(t,dt,x) in enumerate(ms):
        if t=='user' and not x.startswith('CMD') and len(x)<600 and pat.search(x):
            n+=1
            print('=====',n,os.path.basename(f)[:8],dt,'|',x.replace('\n',' ')[:250])
print(n)
