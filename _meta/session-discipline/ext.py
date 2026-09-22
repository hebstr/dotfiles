import json,sys,os,pickle
out={}
for f in open('files.txt').read().split():
    msgs=[]
    for line in open(f,errors='replace'):
        try: r=json.loads(line)
        except: continue
        if r.get('isSidechain'): continue
        t=r.get('type')
        if t not in('user','assistant'): continue
        c=(r.get('message') or {}).get('content')
        txt=''
        if isinstance(c,str): txt=c
        elif isinstance(c,list):
            txt='\n'.join(i.get('text','') for i in c if isinstance(i,dict) and i.get('type')=='text')
        if not txt.strip(): continue
        if t=='user' and txt.lstrip().startswith(('<command-message','<command-stdout','<command-stderr','<local-command','<system-reminder','<task-notification')):
            # keep command-name invocation as marker
            if '<command-name>' in txt:
                import re
                m=re.search(r'<command-name>(.*?)</command-name>',txt); a=re.search(r'<command-args>(.*?)</command-args>',txt,re.S)
                txt='CMD '+m.group(1)+' '+(a.group(1) if a else '')
            else: continue
        if t=='user' and txt.startswith('<command-name>'):
            import re
            m=re.search(r'<command-name>(.*?)</command-name>',txt); a=re.search(r'<command-args>(.*?)</command-args>',txt,re.S)
            txt='CMD '+m.group(1)+' '+(a.group(1) if a else '')
        msgs.append((t,r.get('timestamp','')[:10],txt))
    out[f]=msgs
pickle.dump(out,open('msgs.pkl','wb'))
print(len(out),sum(len(v) for v in out.values()))
