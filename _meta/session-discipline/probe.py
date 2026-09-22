import pickle,re,os
S=pickle.load(open("s.pkl","rb"))
pat=re.compile(r"(à jour|a jour|update|consign|tracking|avant de (propos|commit)|clore|clôtur|clotur|c'est bon pour|rien d'autre|reste[- ]t[- ]il|qu'est-ce qui reste|ce qui reste|stale|workflow:sync|workflow:continue|synced|commit|fermer la session|terminer la session|on a fini|on peut fermer|oublié|oublie quelque)",re.I)
for f,t in S.items():
    for k,ts,s in t:
        if k=="user" and pat.search(s) and len(s)<400:
            print(os.path.basename(os.path.dirname(f))[-20:], ts[:10], "|", s.replace("\n"," ")[:220])
