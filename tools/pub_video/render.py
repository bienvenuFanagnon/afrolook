import sys, math, subprocess, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import imageio_ffmpeg
W,H=int(sys.argv[1]),int(sys.argv[2]); OUT=sys.argv[3]; LIMIT=float(sys.argv[4]) if len(sys.argv)>4 else 32.0
FPS=30; DUR=32.0; U=min(W,H)/1080.0; LAND=W>H*1.2; SQ=(not LAND) and W>=H*0.9
FB='/home/user/afrolook/assets/fonts/Nunito-ExtraBold.ttf'; FR='/home/user/afrolook/assets/fonts/Nunito-Regular.ttf'
GREEN=(0,191,99); YEL=(255,212,0); DARK=(11,11,11); RED=(255,77,77); WHITE=(255,255,255)
_f={}
def font(sz,bold=True):
    k=(max(2,int(sz)),bold)
    if k not in _f: _f[k]=ImageFont.truetype(FB if bold else FR,k[0])
    return _f[k]
clamp=lambda x,a=0.0,b=1.0:max(a,min(b,x))
def ease_out(x): x=clamp(x); return 1-(1-x)**3
def ease_back(x):
    x=clamp(x); c1=1.70158; c3=c1+1; return 1+c3*(x-1)**3+c1*(x-1)**2
def lerp(a,b,x): return a+(b-a)*x
# ---------- assets ----------
logo=Image.open('/home/user/afrolook/assets/logo/afrolook_logo.png').convert('RGBA')
bb=logo.getbbox(); logo=logo.crop(bb)
P=lambda n:Image.open(f'raw_91db130f/fr/{n:02d}.png').convert('RGB')
L=lambda n:Image.open(f'raw_683e46c0/fr/{n:02d}.png').convert('RGB')
slides={n:(L(n) if LAND else P(n)) for n in (1,2,3,4,6)}
def gradient(c1,c2):
    a=np.linspace(0,1,H)[:,None,None]; g=np.array(c1)[None,None,:]*(1-a)+np.array(c2)[None,None,:]*a
    return Image.fromarray(np.broadcast_to(g,(H,W,3)).astype(np.uint8))
def glow(base,cx,cy,r,col,alpha):
    ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    for i in range(12,0,-1):
        rr=r*i/12; a=int(alpha*255*(1-i/12)**1.6/ (1))
        d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),fill=col+(max(2,a//6),))
    return Image.alpha_composite(base.convert('RGBA'),ov)
_bg={}
def bg(key,c1,c2):
    if key not in _bg: _bg[key]=gradient(c1,c2)
    return _bg[key].copy()
blur6=slides[6].resize((W,int(slides[6].height*W/slides[6].width)) if not LAND else (W,H)).filter(ImageFilter.GaussianBlur(18*U)).point(lambda v:int(v*0.35))
# ---------- sprites ----------
def make_coin(d):
    d=int(d); S=Image.new('RGBA',(d,d),(0,0,0,0)); g=ImageDraw.Draw(S)
    g.ellipse((0,0,d-1,d-1),fill=(214,150,0,255)); g.ellipse((d*0.06,d*0.06,d*0.94,d*0.94),fill=(255,205,40,255))
    g.ellipse((d*0.17,d*0.17,d*0.83,d*0.83),outline=(214,150,0,255),width=max(2,int(d*0.05)))
    f=font(d*0.5); tw=g.textlength('A',font=f); g.text((d/2-tw/2,d*0.2),'A',font=f,fill=(150,95,0,255))
    g.ellipse((d*0.2,d*0.12,d*0.5,d*0.32),fill=(255,240,150,120)); return S
coins={s:make_coin(s) for s in (40,64,96,140)}
rng=np.random.default_rng(3)
RAIN=[(rng.uniform(0.03,0.97),rng.uniform(260,520),rng.choice([40,64,96]),rng.uniform(0,6.28),rng.uniform(2,6)) for _ in range(46)]
def coin_rain(img,t0,t,dur=3.0,fall=1.0):
    if not (t0<=t<=t0+dur): return img
    ov=Image.new('RGBA',(W,H),(0,0,0,0))
    for (x,sp,s,ph,rot) in RAIN:
        age=t-t0-(x*0.9)
        if age<0: continue
        y=-100*U+age*sp*U*fall*2.2
        if y>H+80: continue
        sz=int(s*U*(1.0 if not LAND else 0.9)); sprite=coins[s].resize((sz,sz))
        sx=max(0.12,abs(math.cos(ph+age*rot))); sprite=sprite.resize((max(2,int(sz*sx)),sz))
        ov.alpha_composite(sprite,(int(x*W-sprite.width/2),int(y)))
    return Image.alpha_composite(img,ov)
def burst(img,t0,t,cx,cy,n=16,dur=1.0,col=YEL):
    if not(t0<=t<=t0+dur): return img
    x=(t-t0)/dur; ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    for i in range(n):
        a=2*math.pi*i/n+0.3; r=ease_out(x)*340*U*(0.6+0.4*((i*7)%5)/4); rr=max(1,int(14*U*(1-x)))
        d.ellipse((cx+math.cos(a)*r-rr,cy+math.sin(a)*r-rr,cx+math.cos(a)*r+rr,cy+math.sin(a)*r+rr),fill=col+(int(255*(1-x)),))
    return Image.alpha_composite(img,ov)
# ---------- texte ----------
def text(img,s,cx,cy,size,fill=WHITE,scale=1.0,shadow=True,alpha=1.0,stroke=0,maxw=None):
    if alpha<=0 or scale<=0: return img
    sz=size*scale; f=font(sz); d0=ImageDraw.Draw(img)
    mw=maxw or (W*0.92); tw=d0.textlength(s,font=f)
    if tw>mw: sz*=mw/tw; f=font(sz); tw=d0.textlength(s,font=f)
    ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    x=cx-tw/2; y=cy-sz*0.6
    if shadow: d.text((x+4*U,y+6*U),s,font=f,fill=(0,0,0,int(150*alpha)))
    d.text((x,y),s,font=f,fill=fill+(int(255*alpha),),stroke_width=int(stroke),stroke_fill=(0,0,0,int(255*alpha)))
    return Image.alpha_composite(img,ov)
def pill(img,s,cx,cy,size,bgc=YEL,fg=DARK,scale=1.0,alpha=1.0):
    if alpha<=0 or scale<=0: return img
    f=font(size*scale); d0=ImageDraw.Draw(img); tw=d0.textlength(s,font=f); pw=tw+size*scale*1.1; ph=size*scale*1.7
    ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    d.rounded_rectangle((cx-pw/2+0,cy-ph/2+8*U,cx+pw/2,cy+ph/2+8*U),radius=ph/2,fill=(0,0,0,int(120*alpha)))
    d.rounded_rectangle((cx-pw/2,cy-ph/2,cx+pw/2,cy+ph/2),radius=ph/2,fill=bgc+(int(255*alpha),))
    d.text((cx-tw/2,cy-size*scale*0.62),s,font=f,fill=fg+(int(255*alpha),)); return Image.alpha_composite(img,ov)
def paste_logo(img,cx,cy,h,scale=1.0,alpha=1.0,rot=0):
    hh=int(h*scale); 
    if hh<4 or alpha<=0: return img
    lg=logo.resize((int(logo.width*hh/logo.height),hh))
    if rot: lg=lg.rotate(rot,expand=True,resample=Image.BICUBIC)
    if alpha<1: a=lg.getchannel('A').point(lambda v:int(v*alpha)); lg.putalpha(a)
    img.alpha_composite(lg,(int(cx-lg.width/2),int(cy-lg.height/2))); return img
def shadow_card(img,card,x,y,radius=44):
    ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
    d.rounded_rectangle((x-6*U,y+18*U,x+card.width+6*U,y+card.height+30*U),radius=radius*U,fill=(0,0,0,150)); ov=ov.filter(ImageFilter.GaussianBlur(22*U))
    img=Image.alpha_composite(img,ov)
    m=Image.new('L',card.size,0); ImageDraw.Draw(m).rounded_rectangle((0,0,card.width-1,card.height-1),radius=int(radius*U),fill=255)
    c=card.convert('RGBA'); c.putalpha(m); img.alpha_composite(c,(int(x),int(y))); return img
# ---------- scènes ----------
def scene_hook(t):
    img=bg('hook',(8,8,8),(0,35,18)).convert('RGBA'); pulse=0.5+0.5*math.sin(t*5)
    img=glow(img,W/2,H*0.55,min(W,H)*0.7,GREEN,0.25+0.1*pulse)
    cy=H*0.34 if not LAND else H*0.3
    a=clamp((t-0.4)/0.2); img=text(img,'TES VUES.',W/2,cy,150*U,WHITE,scale=ease_back((t-0.4)/0.35),alpha=a)
    a=clamp((t-1.3)/0.2); img=text(img,'TES LIKES.',W/2,cy+185*U,150*U,WHITE,scale=ease_back((t-1.3)/0.35),alpha=a)
    sh=(math.sin(t*40)*4*U if 2.3<t<3.0 else 0)
    a=clamp((t-2.3)/0.2); img=text(img,"ÇA VAUT",W/2+sh,cy+410*U,150*U,YEL,scale=ease_back((t-2.3)/0.35),alpha=a)
    img=text(img,"DE L'ARGENT.",W/2+sh,cy+595*U,150*U,YEL,scale=ease_back((t-2.5)/0.35),alpha=clamp((t-2.5)/0.2))
    img=burst(img,2.3,t,W/2,cy+500*U,18,1.1)
    img=coin_rain(img,2.4,t,3.0)
    return img
def scene_other(t):
    tt=t-4.8
    base=blur6.copy() if not LAND else blur6.copy()
    if base.size!=(W,H):
        base=base.crop((0,0,W,H)) if base.height>=H else base.resize((W,H))
    img=base.convert('RGBA'); ov=Image.new('RGBA',(W,H),(60,0,0,70)); img=Image.alpha_composite(img,ov)
    cy=H*0.33
    img=pill(img,'AILLEURS',W/2,H*0.18 if not LAND else H*0.15,56*U,bgc=(70,70,70),fg=WHITE,scale=ease_back(tt/0.3),alpha=clamp(tt/0.2))
    img=text(img,'TU POSTES.',W/2,cy,130*U,WHITE,scale=ease_back((tt-0.2)/0.35),alpha=clamp((tt-0.2)/0.2))
    img=text(img,'TU CRÉES.',W/2,cy+175*U,130*U,WHITE,scale=ease_back((tt-1.0)/0.35),alpha=clamp((tt-1.0)/0.2))
    sh=math.sin(t*35)*3*U if tt>1.9 else 0
    img=text(img,'ILS ENCAISSENT.',W/2+sh,cy+420*U,128*U,RED,scale=ease_back((tt-2.0)/0.4),alpha=clamp((tt-2.0)/0.2),stroke=2*U)
    return img
def scene_logo(t,t0,line1,line2,col_bg=GREEN):
    tt=t-t0
    img=bg('logo'+str(col_bg),col_bg,tuple(int(c*0.55) for c in col_bg)).convert('RGBA')
    for k in range(3):
        r=((tt*1.3+k/3)%1.0); rr=r*min(W,H)*0.9
        ov=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(ov).ellipse((W/2-rr,H*0.36-rr,W/2+rr,H*0.36+rr),outline=(255,255,255,int(90*(1-r))),width=int(6*U)); img=Image.alpha_composite(img,ov)
    sc=ease_back(tt/0.5)
    ty=0.62 if not (LAND or SQ) else 0.66
    lh=360*U if not (LAND or SQ) else (300*U if LAND else 300*U); ccx=W/2; ccy=H*0.36 if not (LAND or SQ) else H*0.32
    ov=Image.new('RGBA',(W,H),(0,0,0,0)); rr=lh*0.62*sc; ImageDraw.Draw(ov).ellipse((ccx-rr,ccy-rr,ccx+rr,ccy+rr),fill=(255,255,255,int(255*clamp(tt/0.15)))); img=Image.alpha_composite(img,ov)
    img=paste_logo(img,ccx,ccy,lh,sc,clamp(tt/0.15))
    img=text(img,line1,W/2,H*ty,92*U,DARK if col_bg==GREEN else WHITE,scale=ease_back((tt-0.5)/0.35),alpha=clamp((tt-0.5)/0.2),shadow=(col_bg!=GREEN))
    img=text(img,line2,W/2,H*ty+140*U,112*U,WHITE,scale=ease_back((tt-0.9)/0.35),alpha=clamp((tt-0.9)/0.2))
    return img
def card_scene(t,t0,n,label,col,end):
    tt=t-t0; dur=end-t0
    img=bg('card'+str(col),(10,10,10),tuple(int(c*0.35) for c in col)).convert('RGBA')
    img=glow(img,W/2,H*0.5,min(W,H)*0.8,col,0.3)
    s=slides[n]
    if LAND:
        z=1.0+0.05*(tt/dur); w=int(W*z); h=int(H*z); im=s.resize((w,h)); im=im.crop(((w-W)//2,(h-H)//2,(w-W)//2+W,(h-H)//2+H))
        enter=ease_out(tt/0.35); card=im; y=lerp(H*0.15,0,enter)
        img=Image.alpha_composite(img,Image.new('RGBA',(W,H),(0,0,0,0)))
        c=card.convert('RGBA'); c.putalpha(int(255*enter)); img.alpha_composite(c,(0,int(y)))
        img=pill(img,label,W*0.25,H*0.9,64*U,scale=ease_back((tt-0.1)/0.35),alpha=clamp((tt-0.1)/0.2))
    else:
        cw=int(W*0.88); ch=int(H*0.74 if W<H*0.9 else H*0.72)
        sw=cw; sh=int(s.height*cw/s.width); im=s.resize((sw,sh))
        maxoff=sh-ch; off=int(maxoff*ease_out(tt/ (dur*0.75)))
        card=im.crop((0,off,cw,off+ch))
        enter=ease_out(tt/0.4); y=lerp(H*1.0,H*0.2 if W<H*0.9 else H*0.22,enter)
        img=shadow_card(img,card,(W-cw)/2,y)
        img=pill(img,label,W/2,H*0.115 if W<H*0.9 else H*0.1,70*U,scale=ease_back((tt-0.05)/0.35),alpha=clamp((tt-0.05)/0.2))
    img=burst(img,t0+0.15,t,W/2,H*0.115,14,0.9)
    return img
def scene_withdraw(t):
    tt=t-18.2; end=21.2
    img=card_scene(t,18.2,3,'GAINS PAR VUES',YEL,end)
    # bouton retirer
    a=clamp((tt-1.2)/0.25); sc=ease_back((tt-1.2)/0.4)
    press=0.93 if 1.55<tt<1.7 else 1.0
    cy=H*0.86 if not LAND else H*0.82
    img=pill(img,'Retirer mes gains',W/2,cy,64*U,bgc=GREEN,fg=WHITE,scale=sc*press,alpha=a)
    if tt>1.75:
        a2=clamp((tt-1.75)/0.25); img=pill(img,'✔ Demande envoyée',W/2,cy+130*U,48*U,bgc=WHITE,fg=(0,120,60),scale=ease_back((tt-1.75)/0.35),alpha=a2)
    img=burst(img,19.55,t,W/2,cy,16,1.0,GREEN)
    return img
def scene_end(t):
    tt=t-23.8
    img=bg('end',(8,8,8),(0,45,22)).convert('RGBA'); pulse=0.5+0.5*math.sin(tt*4)
    img=glow(img,W/2,H*0.4,min(W,H)*0.8,GREEN,0.3+0.1*pulse)
    if LAND: ly,lh,t1,t2,t3,sz1,sz2,by=H*0.16,190,H*0.40,H*0.40+110*U,H*0.40+235*U,100,130,H*0.80
    elif SQ: ly,lh,t1,t2,t3,sz1,sz2,by=H*0.13,170,H*0.29,H*0.29+110*U,H*0.29+235*U,90,120,H*0.64
    else: ly,lh,t1,t2,t3,sz1,sz2,by=H*0.2,240,H*0.38,H*0.38+150*U,H*0.38+330*U,120,150,H*0.74
    img=paste_logo(img,W/2,ly,lh*U,ease_back(tt/0.4),clamp(tt/0.15))
    img=text(img,'TÉLÉCHARGE',W/2,t1,sz1*U,WHITE,scale=ease_back((tt-0.2)/0.35),alpha=clamp((tt-0.2)/0.2))
    img=text(img,'AFROLOOK',W/2,t2,sz2*U,GREEN,scale=ease_back((tt-0.4)/0.35),alpha=clamp((tt-0.4)/0.2),stroke=3*U)
    img=pill(img,'GRATUIT',W/2,t3,60*U,scale=ease_back((tt-0.7)/0.35)*(1+0.04*math.sin(tt*8)),alpha=clamp((tt-0.7)/0.2))
    for i,(small,big) in enumerate([('DISPONIBLE SUR','Google Play'),("TÉLÉCHARGER DANS L'",'App Store')]):
        sc=ease_back((tt-1.0-0.25*i)/0.4); a=clamp((tt-1.0-0.25*i)/0.2)
        bw0=560*U if (LAND or SQ) else 640*U; bh0=150*U if (LAND or SQ) else 170*U
        if LAND: cx=W/2+(-1 if i==0 else 1)*W*0.17; cy=by
        else: cx=W/2; cy=by+i*(bh0*1.25)
        bw=bw0*sc; bh=bh0*sc
        if sc<=0 or a<=0: continue
        ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
        d.rounded_rectangle((cx-bw/2,cy-bh/2,cx+bw/2,cy+bh/2),radius=34*U,fill=(0,0,0,int(255*a)),outline=(255,255,255,int(255*a)),width=int(4*U))
        f1=font(32*U*sc,False); f2=font(64*U*sc); t1_=d.textlength(small,font=f1); t2_=d.textlength(big,font=f2)
        d.text((cx-t1_/2,cy-bh*0.38),small,font=f1,fill=(220,220,220,int(255*a))); d.text((cx-t2_/2,cy-bh*0.12),big,font=f2,fill=(255,255,255,int(255*a)))
        img=Image.alpha_composite(img,ov)
    if not (LAND or SQ) and tt>1.2:
        ay=by-150*U+math.sin(tt*7)*14*U; ov=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(ov)
        cx=W/2; d.polygon([(cx-50*U,ay),(cx+50*U,ay),(cx,ay+60*U)],fill=YEL+(255,)); img=Image.alpha_composite(img,ov)
    img=text(img,'Les gains dépendent de ton activité et du programme de monétisation.',W/2,H*0.962,30*U,(190,190,190),shadow=False,alpha=clamp((tt-1.6)/0.4),maxw=W*0.9)
    img=burst(img,24.1,t,W/2,t3,14,1.0)
    return img
def frame(t):
    if t<4.8: img=scene_hook(t)
    elif t<9.1: img=scene_other(t)
    elif t<12.75: img=scene_logo(t,9.1,'SUR AFROLOOK,',"C'EST TOI QUI ES PAYÉ.")
    elif t<14.55: img=card_scene(t,12.75,4,'VUES = PIÈCES',YEL,14.55)
    elif t<16.35: img=card_scene(t,14.55,1,'LIKES = PIÈCES',GREEN,16.35)
    elif t<18.2: img=card_scene(t,16.35,2,'CADEAUX = PIÈCES',(255,90,160),18.2)
    elif t<21.2: img=scene_withdraw(t)
    elif t<23.8: img=scene_logo(t,21.2,'AFROLOOK,','LE RÉSEAU QUI TE PAIE.',(0,150,80))
    else: img=scene_end(t)
    if t>31.2: img=Image.alpha_composite(img,Image.new('RGBA',(W,H),(0,0,0,int(255*clamp((t-31.2)/0.8)))))
    return img.convert('RGB')
cmd=[imageio_ffmpeg.get_ffmpeg_exe(),'-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-i','mix.wav','-t',str(LIMIT),
     '-c:v','libx264','-preset','medium','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart','-c:a','aac','-b:a','192k','-af','loudnorm=I=-16:TP=-1.5:LRA=11',OUT]
p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
n=int(LIMIT*FPS)
for i in range(n):
    p.stdin.write(frame(i/FPS).tobytes())
p.stdin.close(); p.wait(); print('fini',OUT)
