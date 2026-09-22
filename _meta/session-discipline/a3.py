import pickle,re,os
d=pickle.load(open('msgs.pkl','rb'))
pat=re.compile(r"(que |qu'est-ce que tu |quelle? .{0,20})recommand|ton avis|tu es s[uû]r|vraiment ?\?|\breco\b ?\?|tu conseilles|ta reco|tu ferais quoi|que ferais-tu",re.I)
rev=re.compile(r"je r[ée]vise|je change (ma|mon)|ne tient (plus|pas)|je ne recommande plus|en y repensant|ni l'une ni l'autre|ni A ni B|recommandation (pr[ée]c[ée]dente|r[ée]vis[ée]e)|change la reco|je maintiens|reste la m[êe]me|apr[èe]s r[ée]examen|en r[ée][ée]valuant|j'avais tort|à tort",re.I)
n=0;c={}
for f,ms in d.items():
    for i,(t,dt,x) in enumerate(ms):
        if t=='user' and not x.startswith('CMD') and len(x)<600 and pat.search(x):
            n+=1
            k=i+1;nxt=[]
            while k<len(ms) and ms[k][0]=='assistant': nxt.append(ms[k][2]); k+=1
            N=' '.join(nxt)
            m=[mm.group(0) for mm in rev.finditer(N)]
            if m: print(n,os.path.basename(f)[:8],dt,m)
