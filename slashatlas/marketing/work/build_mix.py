import numpy as np, wave, math, os
SR=44100; DUR=25.0; N=int(SR*DUR)
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
DROP=4.0
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
VO=[('l1',0.3),('l2',3.5),('l3',7.4),('l4',13.0),('l5',19.4)]
voice=np.zeros(N,np.float32)
for k,t in VO:
    d=load(VODIR+f'/{k}.wav'); d=d/np.max(np.abs(d))*0.9; place(voice,d,t,1.0)
win=int(0.05*SR); env=np.convolve(np.abs(voice),np.ones(win)/win,'same'); env=np.clip(env*6,0,1)
env=np.convolve(env,np.ones(int(0.2*SR))/int(0.2*SR),'same')
music_d=music*(1-0.6*env)
sfx=np.zeros(N,np.float32); AS='/home/user/afrolook/assets/sounds/'
pop=load(AS+'tuto_pop.wav'); whoosh=load(AS+'tuto_whoosh.wav'); rise=load(AS+'tuto_rise.wav'); success=load(AS+'tuto_success.wav'); tick=load(AS+'tuto_tick.wav')
place(sfx,pop,0.45,0.9); place(sfx,pop,1.7,0.6)
place(sfx,rise,3.0,0.8); place(sfx,whoosh,3.4,0.7); place(sfx,success,4.0,0.9); place(sfx,whoosh,4.1,0.6)
for t in (7.5,9.0,10.5): place(sfx,pop,t,0.9)
for t in np.arange(9.3,10.5,0.1): place(sfx,tick,t,0.35)
place(sfx,whoosh,11.0,0.8); place(sfx,success,11.35,0.9)
place(sfx,whoosh,12.9,0.8)
for t in np.arange(13.2,14.9,0.085): place(sfx,tick,t,0.4)
place(sfx,pop,15.0,0.9)
place(sfx,whoosh,19.3,0.8); place(sfx,pop,19.7,0.8); place(sfx,pop,20.6,0.9); place(sfx,success,20.75,0.9)
mix=voice*1.0+music_d*0.55+sfx*0.7
mix=np.tanh(mix*1.2)/np.tanh(1.2); mix=mix/np.max(np.abs(mix))*0.92
w=wave.open(OUT,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix*32767).astype(np.int16).tobytes()); w.close(); print('ok',N/SR)
