import numpy as np, wave
SR=44100; T=32.5; N=int(SR*T); rng=np.random.default_rng(7)
mix=np.zeros(N)
def add(x,t0,g=1.0):
    i=int(t0*SR); 
    if i>=N: return
    j=min(N,i+len(x)); mix[i:j]+=x[:j-i]*g
def env(n,a=.005,d=.2,s=0.0):
    t=np.arange(n)/SR; e=np.minimum(1,t/a)*np.exp(-t/d); return e
def kick(g=1):
    n=int(.35*SR); t=np.arange(n)/SR; f=45+110*np.exp(-t*28); ph=2*np.pi*np.cumsum(f)/SR
    return np.sin(ph)*np.exp(-t*9)*g
def clap(g=1):
    n=int(.22*SR); t=np.arange(n)/SR; x=rng.standard_normal(n); x=np.convolve(x,[1,-.9],'same')
    return x*(np.exp(-t*22)+.6*np.exp(-((t-.012)**2)*8e4))*g*.5
def hat(g=1,o=False):
    n=int((.25 if o else .06)*SR); t=np.arange(n)/SR; x=rng.standard_normal(n); x=np.diff(x,prepend=0)
    return x*np.exp(-t*(18 if o else 70))*g*.3
def tone(f,d,wave_='tri',a=.01,r=.2,g=1.0,vib=0):
    n=int(d*SR); t=np.arange(n)/SR; ph=2*np.pi*f*t+vib*np.sin(2*np.pi*5*t)
    if wave_=='tri': x=2/np.pi*np.arcsin(np.sin(ph))
    elif wave_=='saw': x=2*((f*t)%1)-1
    else: x=np.sin(ph)
    e=np.minimum(1,t/a)*np.minimum(1,(d-t)/r); return x*e*g
def pluck(f,d=.5,g=1):
    n=int(d*SR); t=np.arange(n)/SR; x=np.sin(2*np.pi*f*t)+.4*np.sin(4*np.pi*f*t)+.2*np.sin(6*np.pi*f*t)
    return x*np.exp(-t*7)*g
def ding(f=1318,g=1):
    n=int(.7*SR); t=np.arange(n)/SR; x=np.sin(2*np.pi*f*t)+.5*np.sin(2*np.pi*f*2.01*t)+.25*np.sin(2*np.pi*f*3.02*t)
    return x*np.exp(-t*7)*g
def whoosh(d,up=True,g=1):
    n=int(d*SR); t=np.arange(n)/SR; x=rng.standard_normal(n)
    # filtre passe-bas glissant approximé par moyenne mobile variable (rapide) : on mélange deux lissages
    sm=np.convolve(x,np.ones(60)/60,'same'); sm2=np.convolve(x,np.ones(6)/6,'same')
    k=(t/d) if up else (1-t/d); y=sm*(1-k)+sm2*k
    e=(k**2) if up else (k**2)*np.exp(-0*t)
    return y*e*g*2.2
BPM=118; B=60/BPM
# --- 0..9 : ambiance sobre (nappe + cœur qui bat) ---
for k,f in enumerate([220,261.6,329.6]): add(tone(f,9.2,'sine',a=1.5,r=1.5,g=.07),0)
t=1.9
while t<8.9: add(kick(.55),t); add(kick(.35),t+.28); t+=1.15
add(whoosh(.7,True,.6),8.35)   # montée avant la transition
# --- impacts « 0 FCFA » ---
for ti in (4.3,7.7):
    add(kick(1.3),ti); add(whoosh(.5,False,.5),ti-.02); add(tone(55,.9,'sine',a=.002,r=.6,g=.8),ti)
# --- 9.0 : transition ---
add(kick(1.4),9.0); add(whoosh(.9,False,1.0),9.0); add(clap(1.0),9.0)
# --- 9.7..28.5 : groove principal ---
prog=[(110,220,261.6,329.6),(87.3,174.6,220,261.6),(98,196,246.9,293.7),(82.4,164.8,207.7,246.9)]  # Am F G E
pent=[440,523.3,587.3,659.3,784,880,987.8,1046.5]
start=9.7; bars=int((28.5-start)/(4*B))+1
for bar in range(bars):
    b0=start+bar*4*B; ch=prog[bar%4]
    for k in range(4):
        tt=b0+k*B
        if tt>=28.5: break
        add(kick(1.0),tt)
        if k in (1,3): add(clap(.9),tt)
        add(hat(.8),tt+B/2); add(hat(.5),tt); add(hat(.5,True),tt+B*.75) if k%2 else None
    add(tone(ch[0],4*B,'saw',a=.01,r=.08,g=.26),b0)           # basse
    for q in range(1,4): add(tone(ch[q],4*B,'tri',a=.08,r=.3,g=.075),b0)   # accord
    for s in range(16):                                         # arpège
        ts=b0+s*B/4
        if ts>=28.5: break
        f=pent[(s*3+bar*2)%len(pent)]*(0.5 if bar%4==1 else 1)
        add(pluck(f,.3,.17 if s%2==0 else .11),ts)
# --- pings de pièces sur les "tap" et à l'arrivée des pièces au portefeuille ---
for ti in (12.3,16.4,21.2):
    add(ding(1318,.55),ti+.05); add(ding(1760,.4),ti+.15)
    for j in range(10): add(ding(1500+60*(j%5),.18),ti+.25+j*.07+.95)
# --- carte vue / S5 : petits "pop" ---
for tt in (25.3,25.85,26.4): add(ding(1046,.35),tt+.1)
# --- 28.5 : final ---
add(kick(1.4),28.5); add(whoosh(.5,False,.8),28.5)
for f in (220,277.2,329.6,440): add(tone(f,3.6,'tri',a=.01,r=1.2,g=.16),28.5)
add(ding(1318,.5),29.3); add(ding(1760,.5),29.9); add(ding(2093,.5),30.5)
# fade in/out & normalisation
fi=np.minimum(1,np.arange(N)/(SR*.4)); fo=np.minimum(1,(N-np.arange(N))/(SR*1.4)); mix*=fi*fo
mix=np.tanh(mix*1.4)/np.tanh(1.4)
mix=mix/np.max(np.abs(mix))*0.89
st=np.stack([mix,np.roll(mix,18)],1)  # léger élargissement
pcm=(st*32767).astype('<i2')
w=wave.open('music.wav','wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes()); w.close()
print('ok',N/SR,'s')
