import numpy as np, wave, math, os
SR=44100; DUR=91.5; N=int(SR*DUR)
rng=np.random.default_rng(7)
def load(path):
    w=wave.open(path); n=w.getnframes(); ch=w.getnchannels(); sr=w.getframerate()
    d=np.frombuffer(w.readframes(n),dtype=np.int16).astype(np.float32)/32768
    if ch>1: d=d.reshape(-1,ch).mean(1)
    if sr!=SR:
        x=np.arange(int(len(d)*SR/sr))*sr/SR; d=np.interp(x,np.arange(len(d)),d)
    return d
def place(buf,sig,t,gain=1.0):
    i=int(t*SR); 
    if i>=len(buf): return
    j=min(len(buf),i+len(sig)); buf[i:j]+=sig[:j-i]*gain
# ---------------- musique ----------------
BPM=100; beat=60/BPM; music=np.zeros(N,np.float32)
def kick(t,g=1.0):
    n=int(0.28*SR); x=np.arange(n)/SR
    f=48+90*np.exp(-x*28); ph=2*np.pi*np.cumsum(f)/SR
    s=np.sin(ph)*np.exp(-x*9); s+=0.25*np.sin(2*np.pi*1500*x)*np.exp(-x*140)
    place(music,s.astype(np.float32),t,0.95*g)
def clap(t,g=1.0):
    n=int(0.2*SR); x=np.arange(n)/SR
    nz=rng.standard_normal(n)*np.exp(-x*22)
    # filtre passe-bande simple
    nz=nz-np.convolve(nz,np.ones(40)/40,'same'); place(music,(nz*0.5).astype(np.float32),t,0.55*g)
def hat(t,g=1.0,o=False):
    n=int((0.18 if o else 0.05)*SR); x=np.arange(n)/SR
    nz=rng.standard_normal(n)*np.exp(-x*(18 if o else 90)); nz=np.diff(np.concatenate([[0],nz]))
    place(music,(nz*0.35).astype(np.float32),t,0.5*g)
def shaker(t,g=1.0):
    n=int(0.09*SR); x=np.arange(n)/SR
    nz=rng.standard_normal(n)*np.exp(-x*45)*(1-np.exp(-x*400)); nz=np.diff(np.concatenate([[0],nz]))
    place(music,(nz*0.28).astype(np.float32),t,0.45*g)
def bass(t,f,d,g=1.0):
    n=int(d*SR); x=np.arange(n)/SR
    s=np.sin(2*np.pi*f*x)+0.35*np.sin(2*np.pi*2*f*x)+0.12*np.sin(2*np.pi*3*f*x)
    env=np.minimum(1,x*60)*np.exp(-x*3.2); place(music,(s*env*0.5).astype(np.float32),t,0.8*g)
def pluck(t,f,g=1.0):
    n=int(0.5*SR); x=np.arange(n)/SR
    s=np.sin(2*np.pi*f*x)+0.5*np.sin(2*np.pi*2*f*x+0.3)*np.exp(-x*12)+0.2*np.sin(2*np.pi*4.01*f*x)*np.exp(-x*30)
    env=np.minimum(1,x*400)*np.exp(-x*7); place(music,(s*env*0.22).astype(np.float32),t,g)
def pad(t,freqs,d,g=1.0):
    n=int(d*SR); x=np.arange(n)/SR; s=np.zeros(n)
    for f in freqs:
        for det in (-0.4,0,0.4): s+=np.sin(2*np.pi*(f+det)*x)
    env=np.minimum(1,x*0.8)*np.minimum(1,(d-x)*1.5); place(music,(s*env*0.03).astype(np.float32),t,g)
A=55.0
note=lambda semi:A*2**(semi/12)
# gamme mineure pentatonique de La : 0,3,5,7,10
roots=[0,0,-2,-2,-4,-4,-2,-2]  # progression Am - G - F - G (une mesure par temps de 4)
t0=0.0; bars=int(DUR/(4*beat))+1
DROP=24.8
for b in range(bars):
    bt=b*4*beat
    if bt>=DUR: break
    r=[0,-2,-4,-2][b%4]  # Am G F G
    chord=[note(12+r),note(15+r),note(19+r)]
    if bt<DROP-1:  # tension : nappe + cœur de basse
        pad(bt,[f*2 for f in chord],4*beat,0.9)
        if bt>=4.6-4*beat:
            for k in (0,2): bass(bt+k*beat,note(r),beat*1.6,0.7)
            for k in range(8): shaker(bt+k*beat/2,0.6)
        else:
            bass(bt,note(r),beat*3,0.45)
    else:
        pad(bt,[f*2 for f in chord],4*beat,0.8)
        for k in range(4): kick(bt+k*beat)
        for k in (1,3): clap(bt+k*beat)
        for k in range(8): hat(bt+k*beat/2+beat/4,0.7)  # contretemps
        for k in range(16): shaker(bt+k*beat/4,0.5+0.3*(k%2))
        # basse syncopée
        pat=[(0,0),(1.5,0),(2.5,7),(3,5)]
        for pos,s_ in pat: bass(bt+pos*beat,note(r+s_ if s_ else r),beat*0.9)
        # arpège pentatonique
        arp=[12,15,19,22,19,15,17,14]
        for k in range(8): pluck(bt+k*beat/2,note(arp[k]+r+12),0.9 if k%2==0 else 0.6)
# remonter : montée de bruit avant le drop
n=int(1.0*SR); x=np.arange(n)/SR
nz=rng.standard_normal(n)*(x**2); nz=np.diff(np.concatenate([[0],nz]))
place(music,(nz*0.35).astype(np.float32),DROP-1.0,1.0)
music[int(DROP*SR)-int(0.02*SR):int(DROP*SR)]*=0.2  # micro-silence avant le drop
kick(DROP,1.4)
# fin : retombée douce
fade=np.ones(N); i0=int((DUR-1.2)*SR); fade[i0:]=np.linspace(1,0,N-i0); music*=fade.astype(np.float32)
# ---------------- voix + effets ----------------
import sys
VODIR=sys.argv[1]; OUT=sys.argv[2]
VO=[('l1',0.3),('l2',6.7),('l3',22.2),('l4',25.1),('l5',41.5),('l5b',60.5),('l6',72.5),('l7',83.0)]
voice=np.zeros(N,np.float32)
for k,t in VO:
    d=load(VODIR+f'/{k}.wav'); d=d/np.max(np.abs(d))*0.9; place(voice,d,t,1.0)
win=int(0.05*SR); env=np.convolve(np.abs(voice),np.ones(win)/win,'same'); env=np.clip(env*6,0,1)
env=np.convolve(env,np.ones(int(0.2*SR))/int(0.2*SR),'same')
music_d=music*(1-0.6*env)
sfx=np.zeros(N,np.float32); AS='/home/user/afrolook/assets/sounds/'
pop=load(AS+'tuto_pop.wav'); whoosh=load(AS+'tuto_whoosh.wav'); rise=load(AS+'tuto_rise.wav'); success=load(AS+'tuto_success.wav'); tick=load(AS+'tuto_tick.wav')
# --- effets (chronologie de la publicité 3) ---
for t in (4.4,9.3,14.2): place(sfx,whoosh,t,0.35)           # résultats moyens qui arrivent
for t0,t1 in ((7.0,8.2),(11.4,12.9),(16.0,18.8)):
    for t in np.arange(t0,t1,0.07): place(sfx,tick,t,0.22)     # frappe des prompts
place(sfx,rise,20.6,0.7); place(sfx,whoosh,22.0,0.7)           # « il y a plus rapide »
place(sfx,whoosh,24.8,0.9)
for (a0,b0,c0) in ((26.0,27.6,28.8),(31.8,32.9,33.8),(36.0,37.2,38.4)):   # trois démos : tap, collage, résultat
    place(sfx,pop,a0,0.9)
    for t in np.arange(b0,b0+1.0,0.08): place(sfx,tick,t,0.25)
    place(sfx,success,c0,0.9)
place(sfx,whoosh,41.3,0.8)
for t in (42.4,42.65,42.9,43.15): place(sfx,pop,t,0.7)
place(sfx,whoosh,60.3,0.7); place(sfx,whoosh,65.8,0.5)
place(sfx,whoosh,72.3,0.8); place(sfx,pop,73.4,0.9)
for t in np.arange(74.0,76.0,0.1): place(sfx,tick,t,0.28)
place(sfx,success,76.2,1.0)
place(sfx,whoosh,82.8,0.8); place(sfx,pop,84.3,0.9); place(sfx,success,84.6,0.9)
# montées de bruit avant les grandes transitions de la musique
for tt_ in (40.0,59.2,71.4):
    n=int(1.2*SR); x=np.arange(n)/SR; nz=rng.standard_normal(n)*(x**2); nz=np.diff(np.concatenate([[0],nz]))
    place(music_d,(nz*0.3).astype(np.float32),tt_,1.0)
    kick(tt_+1.2,1.1) if False else None
mix=voice*1.0+music_d*0.5+sfx*0.7
mix=np.tanh(mix*1.2)/np.tanh(1.2); mix=mix/np.max(np.abs(mix))*0.92
w=wave.open(OUT,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix*32767).astype(np.int16).tobytes()); w.close(); print('ok',N/SR)
