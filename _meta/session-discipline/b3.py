import pickle,re,os
d=pickle.load(open('msgs.pkl','rb'))
q=re.compile(r"revue|review|audit|blindspot|walkthrough|reviewer|adverse",re.I)
for f,ms in d.items():
    b=os.path.basename(f)[:8]
    seen=False
    for i,(t,dt,x) in enumerate(ms):
        if t=='assistant' and re.search(r'/audit:(walkthrough|blindspot)',x): seen=True
        if t=='user' and seen and not x.startswith('CMD') and len(x)<500 and q.search(x):
            k=i+1;nxt=[]
            while k<len(ms) and ms[k][0]=='assistant': nxt.append(ms[k][2]); k+=1
            print('####',b,dt,i,'U:',x.replace('\n',' ')[:250])
            print('   A:',' '.join(nxt).replace('\n',' ')[:500])
