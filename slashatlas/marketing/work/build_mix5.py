import numpy as np, wave, math, os
SR=44100; DUR=82.0; N=int(SR*DUR)
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
DROP=6.2
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
VO=[('l1',0.5),('l2',6.4),('l3',14.9),('l4',17.8),('l5',28.4),('l6',36.4),('l7',43.4),('l8',46.6),('l9',60.4),('l10',68.6),('l11',76.4)]
voice=np.zeros(N,np.float32)
for k,t in VO:
    d=load(VODIR+f'/{k}.wav'); d=d/np.max(np.abs(d))*0.9; place(voice,d,t,1.0)
win=int(0.05*SR); env=np.convolve(np.abs(voice),np.ones(win)/win,'same'); env=np.clip(env*6,0,1)
env=np.convolve(env,np.ones(int(0.2*SR))/int(0.2*SR),'same')
music_d=music*(1-0.6*env)
sfx=np.zeros(N,np.float32); AS='/home/user/afrolook/assets/sounds/'
pop=load(AS+'tuto_pop.wav'); whoosh=load(AS+'tuto_whoosh.wav'); rise=load(AS+'tuto_rise.wav'); success=load(AS+'tuto_success.wav'); tick=load(AS+'tuto_tick.wav')
# --- effets (chronologie du tutoriel cartes) ---
for t in (6.2,14.6,17.4,28.0,36.0,43.0,46.2,60.0,68.2,76.0): place(sfx,whoosh,t,0.45)   # fondus enchaînés
for t in (0.9,1.2,1.5,1.8,2.1,1.3): place(sfx,pop,t,0.7)                                  # cartes de l'ouverture
for t in (6.8,7.4,8.2,8.9,10.1): place(sfx,pop,t,0.7)                                     # Wax, Kenté, Manga…
place(sfx,success,11.8,0.8)
for t in (14.7,15.3,15.6): place(sfx,pop,t,0.8)
place(sfx,pop,17.4,0.7); place(sfx,rise,19.7,0.5)                                         # appui long
for t in (21.2,23.6,24.3,25.4): place(sfx,pop,t,0.8)
place(sfx,tick,25.0,0.6); place(sfx,success,26.1,0.8)
for t in (30.0,31.0,31.8,32.6,33.4): place(sfx,pop,t,0.7)                                 # style, format, images, pays
place(sfx,success,34.4,0.9)
for t in (36.6,38.0,40.1): place(sfx,pop,t,0.8)                                           # enregistrer, partager, publier
place(sfx,success,37.0,0.7); place(sfx,whoosh,38.6,0.5); place(sfx,whoosh,40.7,0.5)
for t in (41.6,42.3): place(sfx,tick,t,0.6)
for t in (43.1,43.7,43.9,44.1): place(sfx,pop,t,0.8)
place(sfx,pop,49.0,0.9); place(sfx,whoosh,49.8,0.5); place(sfx,pop,51.4,0.9); place(sfx,pop,52.8,0.9); place(sfx,whoosh,53.8,0.5)
for t in np.arange(54.2,55.6,0.07): place(sfx,tick,t,0.22)                               # saisie du texte
for t in (55.8,56.3,56.8,57.3): place(sfx,pop,t,0.7)                                      # images ajoutées
place(sfx,whoosh,57.6,0.5); place(sfx,tick,58.7,0.6)
for t in (60.5,61.4,62.3,63.2,64.1): place(sfx,pop,t,0.8)
place(sfx,success,65.0,0.8)
for t in (68.4,69.1,71.0,71.3,72.8): place(sfx,pop,t,0.7)
place(sfx,whoosh,70.6,0.5); place(sfx,success,73.4,0.9)
for t in (76.1,76.22,76.34,76.46,76.58,76.7): place(sfx,pop,t,0.6)
for t in (77.8,78.4,79.0): place(sfx,pop,t,0.8)
place(sfx,success,79.1,0.9)
# montées de bruit avant les grandes transitions de la musique
for tt_ in (5.4,59.2):
    n=int(1.2*SR); x=np.arange(n)/SR; nz=rng.standard_normal(n)*(x**2); nz=np.diff(np.concatenate([[0],nz]))
    place(music_d,(nz*0.3).astype(np.float32),tt_,1.0)
    kick(tt_+1.2,1.1) if False else None
mix=voice*1.0+music_d*0.5+sfx*0.7
mix=np.tanh(mix*1.2)/np.tanh(1.2); mix=mix/np.max(np.abs(mix))*0.92
w=wave.open(OUT,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
w.writeframes((mix*32767).astype(np.int16).tobytes()); w.close(); print('ok',N/SR)
