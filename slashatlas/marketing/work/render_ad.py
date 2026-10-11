# Publicité SlashAtlas : python3 render_ad.py <largeur> <hauteur> <sortie.mp4> <fr|en> [secondes]
import sys, math, subprocess, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import imageio_ffmpeg
W, H = int(sys.argv[1]), int(sys.argv[2]); OUT = sys.argv[3]; LANG = sys.argv[4]; LIMIT = float(sys.argv[5]) if len(sys.argv) > 5 else 25.0
FPS = 30; U = min(W, H) / 1080.0; LAND = W > H * 1.2; SQ = (not LAND) and W >= H * 0.9; SPL = LAND or SQ  # mise en page en deux colonnes (paysage et carré)
FB = '/home/user/afrolook/assets/fonts/Nunito-ExtraBold.ttf'; FR_ = '/home/user/afrolook/assets/fonts/Nunito-Regular.ttf'
MONO = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'
ACC = (41, 151, 255); ACC2 = (108, 184, 255); WHITE = (245, 245, 247); MUT = (161, 161, 166); BLACK = (0, 0, 0); OK = (48, 209, 88)
IMG = '/home/user/afrolook/slashatlas/static/img/c/'
_f = {}
def font(sz, kind='b'):
    k = (max(2, int(sz)), kind)
    if k not in _f: _f[k] = ImageFont.truetype({'b': FB, 'r': FR_, 'm': MONO}[kind], k[0])
    return _f[k]
clamp = lambda x, a=0.0, b=1.0: max(a, min(b, x))
def ease_out(x): x = clamp(x); return 1 - (1 - x) ** 3
def ease_io(x): x = clamp(x); return 3 * x * x - 2 * x ** 3
def ease_back(x):
    x = clamp(x); c1 = 1.70158; c3 = c1 + 1; return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2
S = {  # textes (fr / en)
 'hook': ('Une photo de produit\ntoute plate ?', 'Plain product\nphoto?'),
 'pro': ('Une affiche pro', 'A pro ad poster'), 'sec': ('en quelques secondes', 'in seconds'),
 's1': ('Copiez une commande gratuite', 'Copy a free command'), 's2': ('Collez-la avec votre photo', 'Paste it with your photo'), 's3': ('Recevez votre affiche', 'Get your poster'),
 'free': ('commandes gratuites', 'free commands'), 'cats': ('Mode  ·  Food  ·  Immobilier  ·  Beauté  ·  Événements', 'Fashion  ·  Food  ·  Real estate  ·  Beauty  ·  Events'),
 'try': ('Essayez gratuitement', 'Try it free'), 'nosign': ('Sans inscription', 'No sign-up needed'), 'ai': ('Visuels générés par IA', 'AI-generated visuals'),
 'ai2': ('ChatGPT · Gemini · Midjourney', 'ChatGPT · Gemini · Midjourney'),
}
T_ = lambda k: S[k][0 if LANG == 'fr' else 1]
def load(n, k):
    return Image.open(f'{IMG}{n}-{k}.webp').convert('RGB')
POST = ['productglow', 'fashionposter', 'menuhero', 'skincareglow', 'openhouse', 'workoutbanner', 'weddinginvite', 'bakerymorning', 'gigflyer', 'eventnight']
posters = {n: load(n, 'apres') for n in POST}
before = load('productglow', 'avant')
def rounded(img, r):
    m = Image.new('L', img.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, img.width - 1, img.height - 1), r, fill=255)
    out = img.convert('RGBA'); out.putalpha(m); return out
def fit(img, w, h, r=28):
    s = max(w / img.width, h / img.height); im = img.resize((int(img.width * s) + 1, int(img.height * s) + 1), Image.LANCZOS)
    x = (im.width - w) // 2; y = (im.height - h) // 2; return rounded(im.crop((x, y, x + w, y + h)), int(r * U))
def shadow(card, blur=40, op=140):
    pad = int(blur * 2.2 * U); sh = Image.new('RGBA', (card.width + 2 * pad, card.height + 2 * pad), (0, 0, 0, 0))
    a = Image.new('L', card.size, op); sh.paste((0, 0, 0, 255), (pad, pad + int(14 * U)), a)
    return sh.filter(ImageFilter.GaussianBlur(blur * U)), pad
def paste(base, card, cx, cy, angle=0, scale=1.0, alpha=1.0, shadowed=True):
    if scale != 1.0: card = card.resize((max(2, int(card.width * scale)), max(2, int(card.height * scale))), Image.LANCZOS)
    if angle: card = card.rotate(angle, expand=True, resample=Image.BICUBIC)
    if alpha < 1.0:
        a = card.getchannel('A').point(lambda v: int(v * alpha)); card = card.copy(); card.putalpha(a)
    if shadowed:
        sh, pad = shadow(card); base.alpha_composite(sh, (int(cx - sh.width / 2), int(cy - sh.height / 2)))
    base.alpha_composite(card, (int(cx - card.width / 2), int(cy - card.height / 2)))
    return base
_bg = None
def bg(t):
    global _bg
    if _bg is None:
        a = np.linspace(0, 1, H)[:, None, None]; g = np.array((8, 10, 16))[None, None, :] * (1 - a) + np.array((0, 0, 0))[None, None, :] * a
        _bg = Image.fromarray(np.broadcast_to(g, (H, W, 3)).astype(np.uint8)).convert('RGBA')
    img = _bg.copy(); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    cx = W * (0.5 + 0.12 * math.sin(t * 0.7)); cy = H * (0.42 + 0.06 * math.cos(t * 0.5)); r = max(W, H) * 0.55
    for i in range(14, 0, -1):
        rr = r * i / 14; d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=ACC + (max(1, int(38 * (1 - i / 14) ** 1.8)),))
    return Image.alpha_composite(img, ov)
def text(img, s, x, y, sz, col=WHITE, kind='b', anchor='mm', alpha=1.0, maxw=None, shadow_=True, spacing=0.12):
    f = font(sz * U, kind)
    if maxw:
        while f.size > 12 and max(ImageDraw.Draw(img).textlength(l, font=f) for l in s.split('\n')) > maxw: f = font(f.size - 2, kind)
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    if shadow_: d.multiline_text((x + 3 * U, y + 4 * U), s, font=f, fill=(0, 0, 0, int(150 * alpha)), anchor=anchor, align='center', spacing=f.size * spacing)
    d.multiline_text((x, y), s, font=f, fill=col + (int(255 * alpha),), anchor=anchor, align='center', spacing=f.size * spacing)
    return Image.alpha_composite(img, lay)
def pill(img, s, cx, cy, sz, bgc=ACC, fg=WHITE, alpha=1.0, padx=44, pady=22, scale=1.0):
    f = font(sz * U * scale); d0 = ImageDraw.Draw(img); tw = d0.textlength(s, font=f); w = tw + padx * 2 * U * scale; h = f.size + pady * 2 * U * scale
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    d.rounded_rectangle((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), h / 2, fill=bgc + (int(255 * alpha),))
    d.text((cx, cy), s, font=f, fill=fg + (int(255 * alpha),), anchor='mm'); return Image.alpha_composite(img, lay)
def sparkle(img, cx, cy, r, a=1.0, col=(255, 255, 255)):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    d.polygon([(cx, cy - r), (cx + r * 0.18, cy - r * 0.18), (cx + r, cy), (cx + r * 0.18, cy + r * 0.18), (cx, cy + r), (cx - r * 0.18, cy + r * 0.18), (cx - r, cy), (cx - r * 0.18, cy - r * 0.18)], fill=col + (int(255 * a),))
    return Image.alpha_composite(img, lay)
rng = np.random.default_rng(5)
SPK = [(rng.uniform(0.15, 0.85), rng.uniform(0.15, 0.85), rng.uniform(0.0, 0.7), rng.uniform(12, 34)) for _ in range(16)]
# ---------- géométrie par format ----------
def card_box(ratio=1.24):  # (largeur, hauteur) d'une affiche portrait
    if LAND: h = H * 0.80; return int(h / ratio), int(h)
    if SQ: h = H * 0.68; return int(h / ratio), int(h)
    w = W * 0.74; return int(w), int(w * ratio)
def badge(img, t, t0):
    a = ease_out((t - t0) / 0.4)
    return pill(img, T_('ai'), W / 2 if not LAND else W * 0.82, H * 0.965 if not LAND else H * 0.93, 26, bgc=(30, 30, 36), fg=MUT, alpha=a, padx=26, pady=12) if a > 0 else img
# ---------- scènes ----------
def s_hook(t):  # 0 – 3.4
    img = bg(t); cw, ch = card_box(); tt = t
    cy = H * (0.60 if not SPL else 0.5); cx = W / 2 if not SPL else W * 0.28
    pop = ease_back(tt / 0.6)
    card = fit(before, cw, ch)
    img = paste(img, card, cx, cy + (1 - ease_out(tt / 0.5)) * 120 * U, angle=-3 + math.sin(tt * 2) * 0.6, scale=0.92 * clamp(pop, 0.01, 1.2))
    ty = H * (0.17 if not SPL else 0.5); tx = W / 2 if not SPL else W * 0.70
    words = T_('hook').split('\n')
    for i, w in enumerate(words):
        a = ease_out((tt - 0.25 - i * 0.28) / 0.35)
        img = text(img, w, tx, ty + (i - (len(words) - 1) / 2) * 118 * U + (1 - a) * 40 * U, 104 if not SPL else 96, alpha=a, maxw=W * (0.9 if not SPL else 0.36))
    # étiquette « plat » sur la photo
    a = ease_out((tt - 1.4) / 0.4)
    if a > 0: img = pill(img, '…flat' if LANG == 'en' else '…plat', cx + cw * 0.28, cy - ch * 0.38, 40, bgc=(60, 60, 66), alpha=a, padx=26, pady=12)
    return img
def s_reveal(t):  # 3.4 – 7.3
    tt = t - 3.4; img = bg(t); cw, ch = card_box()
    cy = H * (0.58 if not SPL else 0.5); cx = W / 2 if not SPL else W * 0.28
    prog = ease_io((tt - 0.55) / 0.9)
    a_img = fit(before, cw, ch); b_img = fit(posters['productglow'], cw, ch)
    m = Image.new('L', (cw, ch), 0); x = int(cw * prog); ImageDraw.Draw(m).rectangle((0, 0, x, ch), fill=255)
    comp = a_img.copy(); comp.paste(b_img, (0, 0), ImageChops_mul(m, b_img.getchannel('A'))) if False else comp.paste(b_img.convert('RGB'), (0, 0), m)
    comp.putalpha(a_img.getchannel('A'))
    sc = 1.0 + 0.05 * math.sin(clamp((tt - 0.5) / 1.6) * math.pi)
    img = paste(img, comp, cx, cy, angle=-3 * (1 - prog), scale=0.94 * sc)
    if 0 < prog < 1:  # trait lumineux
        lx = cx - cw * 0.94 * sc / 2 + cw * 0.94 * sc * prog; lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
        for k, al in ((26, 40), (12, 90), (4, 255)): d.rectangle((lx - k * U, cy - ch * 0.47 * sc, lx + k * U, cy + ch * 0.47 * sc), fill=(190, 225, 255, al))
        img = Image.alpha_composite(img, lay)
    for (sx, sy, off, r) in SPK:
        a = math.sin(clamp((tt - 1.3 - off) / 0.8) * math.pi)
        if a > 0: img = sparkle(img, cx + (sx - 0.5) * cw * 1.2, cy + (sy - 0.5) * ch * 1.1, r * U * a, a)
    tx = W / 2 if not SPL else W * 0.67; ty = H * (0.14 if not SPL else 0.4)
    a1 = ease_out((tt - 0.1) / 0.4); img = text(img, T_('pro'), tx, ty + (1 - a1) * 30 * U, 92 if not SPL else 84, alpha=a1, maxw=W * (0.92 if not SPL else 0.45))
    a2 = ease_out((tt - 1.5) / 0.4); img = text(img, T_('sec'), tx, ty + 104 * U + (1 - a2) * 30 * U, 70 if not SPL else 62, col=ACC2, alpha=a2, maxw=W * (0.92 if not SPL else 0.45))
    return badge(img, t, 4.6)
def s_steps(t):  # 7.3 – 12.9
    tt = t - 7.3; img = bg(t)
    steps = [(T_('s1'), 'copy'), (T_('s2'), 'paste'), (T_('s3'), 'post')]
    pw = W * 0.30 if LAND else (H * 0.40 if SQ else W * 0.60)
    cw, ch = int(pw), int(pw * 1.24)
    x0 = W * 0.05
    ys = [H * 0.24, H * 0.37, H * 0.50] if SPL else [H * 0.10, H * 0.175, H * 0.25]
    for i, (s_, k) in enumerate(steps):
        a = clamp(ease_back((tt - 0.2 - i * 1.5) / 0.5), 0, 1.15)
        if a <= 0: continue
        fs = (54 if LAND else 46) if SPL else 58; f = font(fs * U); d0 = ImageDraw.Draw(img); tw = d0.textlength(s_, font=f) + 150 * U
        cx = (x0 + tw / 2) if SPL else W / 2; cy = ys[i]
        lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
        sc = min(a, 1.0); w2 = tw * sc; h2 = 96 * U * sc
        d.rounded_rectangle((cx - w2 / 2, cy - h2 / 2, cx + w2 / 2, cy + h2 / 2), h2 / 2, fill=(22, 24, 30, 255), outline=(60, 64, 74, 255), width=2)
        if sc > 0.9:
            d.ellipse((cx - w2 / 2 + 14 * U, cy - 34 * U, cx - w2 / 2 + 82 * U, cy + 34 * U), fill=ACC + (255,))
            d.text((cx - w2 / 2 + 48 * U, cy), str(i + 1), font=font(44 * U), fill=(255, 255, 255, 255), anchor='mm')
            d.text((cx - w2 / 2 + 104 * U, cy), s_, font=f, fill=(245, 245, 247, 255), anchor='lm')
        img = Image.alpha_composite(img, lay)
    cmd = '/productglow'; typed = cmd[:int(clamp((tt - 2.0) / 1.2) * len(cmd))]
    if SPL: bx, by, bw = W * 0.27, H * 0.80, W * 0.44
    else: bx, by, bw = W / 2, H * 0.88, W * 0.86
    bh = 140 * U; a = ease_out((tt - 1.6) / 0.4)
    if a > 0:
        lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
        d.rounded_rectangle((bx - bw / 2, by - bh / 2, bx + bw / 2, by + bh / 2), bh / 2, fill=(30, 32, 40, int(255 * a)), outline=(70, 74, 86, int(255 * a)), width=2)
        d.text((bx - bw / 2 + 146 * U, by), typed + ('|' if int(tt * 3) % 2 == 0 and tt < 3.4 else ''), font=font(42 * U, 'm'), fill=ACC2 + (int(255 * a),), anchor='lm')
        ax, ay = bx + bw / 2 - 64 * U, by; d.ellipse((ax - 36 * U, ay - 36 * U, ax + 36 * U, ay + 36 * U), fill=ACC + (int(255 * a),)); d.polygon([(ax, ay - 17 * U), (ax + 16 * U, ay + 3 * U), (ax + 6 * U, ay + 3 * U), (ax + 6 * U, ay + 17 * U), (ax - 6 * U, ay + 17 * U), (ax - 6 * U, ay + 3 * U), (ax - 16 * U, ay + 3 * U)], fill=(255, 255, 255, int(255 * a)))
        img = Image.alpha_composite(img, lay)
        th = fit(before, int(106 * U), int(106 * U), 18); img = paste(img, th, bx - bw / 2 + 78 * U, by, shadowed=False, alpha=a)
    a3 = ease_back((tt - 3.9) / 0.6)
    if a3 > 0:
        px, py = (W * 0.76, H * 0.48) if SPL else (W / 2, H * 0.56)
        img = paste(img, fit(posters['productglow'], cw, ch), px, py, angle=4 * (1 - clamp(a3)) + 2, scale=clamp(a3, 0.01, 1.08))
    return img
def s_grid(t):  # 12.9 – 19.3
    tt = t - 12.9; img = bg(t)
    names = ['fashionposter', 'menuhero', 'skincareglow', 'openhouse', 'workoutbanner', 'weddinginvite', 'bakerymorning', 'gigflyer', 'eventnight']
    cw, ch = ((int(W * 0.17), int(W * 0.17 * 1.24)) if LAND else ((int(W * 0.36), int(W * 0.36 * 1.24)) if not SQ else (int(H * 0.26), int(H * 0.26 * 1.24))))
    rows = 2
    for r in range(rows):
        ry = H * (0.30 + 0.40 * r) if LAND else (H * (0.43 + 0.27 * r) if not SQ else H * (0.50 + 0.30 * r))
        n = 7 if LAND else 5; gap = cw + 26 * U; off = (tt * (140 if r % 2 == 0 else -140) * U) % (gap * len(names))
        for i in range(n + len(names)):
            x = i * gap - off + (W / 2 - gap * 2 if not LAND else 0)
            if not (-cw < x < W + cw): continue
            img = paste(img, fit(posters[names[i % len(names)]], cw, ch, 22), x, ry, shadowed=False, alpha=0.8)
    # voile + compteur
    veil = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(veil)
    d.rectangle((0, 0, W, H), fill=(0, 0, 0, 110)); img = Image.alpha_composite(img, veil)
    plate = Image.new('RGBA', (W, H), (0, 0, 0, 0)); pd = ImageDraw.Draw(plate)
    pcx = W / 2; pcy = H * (0.155 if not LAND else 0.5); pr = (W * 0.46, H * 0.15) if not LAND else (W * 0.30, H * 0.30)
    pd.ellipse((pcx - pr[0], pcy - pr[1], pcx + pr[0], pcy + pr[1]), fill=(0, 0, 0, 215)); img = Image.alpha_composite(img, plate.filter(ImageFilter.GaussianBlur(60 * U)))
    n = int(225 * ease_out((tt - 0.3) / 1.6)); cx = W / 2; cy = H * (0.115 if not LAND else 0.5)
    sc = 1 + 0.06 * math.sin(clamp((tt - 1.9) / 0.5) * math.pi)
    img = text(img, str(n), cx, cy, 250 * sc if not LAND else 230 * sc, col=WHITE, alpha=ease_out(tt / 0.3), shadow_=True)
    img = text(img, T_('free'), cx, cy + (150 if not LAND else 140) * U, 70 if not LAND else 60, col=ACC2, alpha=ease_out((tt - 0.3) / 0.4))
    a = ease_out((tt - 2.4) / 0.5)
    img = pill(img, T_('cats'), W / 2, H * (0.915 if not LAND else 0.88), 30 if not LAND else 28, bgc=(14, 16, 22), fg=WHITE, alpha=a * 0.96, padx=34, pady=16)
    return badge(img, t, 14.0)
def s_cta(t):  # 19.3 – fin
    tt = t - 19.3; img = bg(t)
    pw = W * 0.18 if LAND else (H * 0.20 if SQ else W * 0.31); cw, ch = int(pw), int(pw * 1.24)
    for i, nme in enumerate(['fashionposter', 'productglow', 'menuhero']):
        a = ease_back((tt - 0.1 - i * 0.12) / 0.5)
        if a <= 0: continue
        if SPL: px = W * (0.10 + 0.145 * i) if LAND else W * (0.10 + 0.17 * i); py = H * 0.5 + (i % 2) * 36 * U - 18 * U
        else: px = W * (0.22 + 0.28 * i); py = H * 0.70 + (i % 2) * 24 * U
        img = paste(img, fit(posters[nme], cw, ch), px, py, angle=(-6 + 6 * i), scale=clamp(a, 0.01, 1.1))
    tx = W * 0.70 if LAND else (W * 0.72 if SQ else W / 2)
    ty0 = 0.27 if SPL else 0.15
    a = ease_out((tt - 0.3) / 0.4); img = text(img, '/SlashAtlas', tx, H * ty0, 96 if not SPL else 80, col=ACC2, alpha=a, maxw=W * (0.9 if not SPL else 0.50))
    a = ease_out((tt - 0.8) / 0.4); img = text(img, T_('try'), tx, H * (ty0 + (0.12 if not SPL else 0.15)), 86 if not SPL else 70, alpha=a, maxw=W * (0.9 if not SPL else 0.50))
    a = ease_back((tt - 1.3) / 0.5)
    if a > 0:
        pulse = 1 + 0.035 * math.sin(tt * 6)
        img = pill(img, 'slashatlas.com', tx, H * (ty0 + (0.25 if not SPL else 0.31)), 80 if not SPL else 56, alpha=clamp(a, 0, 1), scale=clamp(a, 0.01, 1.1) * pulse, padx=50, pady=26)
    a = ease_out((tt - 1.9) / 0.4); img = text(img, T_('nosign'), tx, H * (ty0 + (0.34 if not SPL else 0.44)), 46 if not SPL else 38, col=MUT, kind='r', alpha=a)
    return badge(img, t, 20.5)
def frame(t):
    if t < 3.4: img = s_hook(t)
    elif t < 7.3: img = s_reveal(t)
    elif t < 12.9: img = s_steps(t)
    elif t < 19.3: img = s_grid(t)
    else: img = s_cta(t)
    # fondus courts entre scènes
    for tb in (3.4, 7.3, 12.9, 19.3):
        if tb - 0.0 <= t < tb + 0.18:
            img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(200 * (1 - (t - tb) / 0.18)))))
    if t > LIMIT - 0.5: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * clamp((t - (LIMIT - 0.5)) / 0.5)))))
    return img.convert('RGB')
if __name__ == '__main__':
    MIX = sys.argv[6] if len(sys.argv) > 6 else 'mix.wav'
    if len(sys.argv) > 7 and sys.argv[7] == 'test':
        import os; os.makedirs('test', exist_ok=True)
        for tt in [float(x) for x in sys.argv[8].split(',')]: frame(tt).save(f'test/{LANG}_{W}x{H}_{tt}.png')
        sys.exit(0)
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-i', MIX, '-t', str(LIMIT),
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for i in range(int(LIMIT * FPS)): p.stdin.write(frame(i / FPS).tobytes())
    p.stdin.close(); p.wait(); print('fini', OUT)
