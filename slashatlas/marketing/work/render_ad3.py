# Publicité SlashAtlas n° 3 (mode, cosmétique, looks), version française, ~1 min 30.
# Usage : python3 render_ad3.py <largeur> <hauteur> <sortie.mp4> fr <secondes> <mix.wav>   |   … test <t1,t2,…>
import sys, math, subprocess
import numpy as np
import render_ad2 as R
from PIL import Image, ImageDraw, ImageEnhance, ImageOps, ImageFilter
import imageio_ffmpeg
W, H, U, LAND = R.W, R.H, R.U, R.LAND
ACC, ACC2, WHITE, MUT, OK, RED = R.ACC, R.ACC2, R.WHITE, R.MUT, R.OK, (255, 85, 85)
clamp, ease_out, ease_io, ease_back = R.clamp, R.ease_out, R.ease_io, R.ease_back
FPS = 30
IMG = R.IMG
ld = lambda n, k: R.load(n, k)
TL = dict(hook=(0, 6.4), struggle=(6.4, 22.0), faster=(22.0, 24.8), demo=(24.8, 41.3), cat=(41.3, 60.3), catb=(60.3, 72.3), studio=(72.3, 82.8), cta=(82.8, 99))
BND = [6.4, 22.0, 24.8, 41.3, 60.3, 72.3, 82.8]
# ---------- images ----------
AV = {n: ld(n, 'avant') for n in ('fashionposter', 'skincareglow', 'lookbook')}
AP = {n: ld(n, 'apres') for n in ('fashionposter', 'skincareglow', 'lookbook')}
def bad_img(before, variant, w, h, word, word2):
    im = before.copy()
    if variant == 0:
        im = ImageOps.fit(im, (w, h), centering=(0.2, 0.7)); im = ImageEnhance.Color(im).enhance(1.9); im = ImageEnhance.Contrast(im).enhance(1.25)
        d = ImageDraw.Draw(im); d.rectangle((0, int(h * 0.78), w, int(h * 0.93)), fill=(220, 30, 60)); d.text((w / 2, h * 0.855), word, font=R.font(h * 0.07), fill=(255, 255, 255), anchor='mm')
    elif variant == 1:
        im = ImageOps.fit(im, (w, h), centering=(0.5, 0.2)); im = ImageEnhance.Color(im).enhance(0.55); im = Image.blend(im, Image.new('RGB', im.size, (60, 140, 90)), 0.35)
        d = ImageDraw.Draw(im); d.text((w * 0.08, h * 0.1), word, font=R.font(h * 0.08), fill=(255, 235, 120)); d.text((w * 0.08, h * 0.19), word2, font=R.font(h * 0.045), fill=(255, 255, 255))
    else:
        im = ImageOps.fit(im, (w, h), centering=(0.9, 0.5)); im = ImageEnhance.Brightness(im).enhance(1.35); im = im.filter(ImageFilter.GaussianBlur(2))
        im = Image.blend(im, Image.new('RGB', im.size, (255, 120, 190)), 0.22)
        d = ImageDraw.Draw(im); d.text((w / 2, h * 0.5), word, font=R.font(h * 0.2), fill=(255, 255, 0), anchor='mm'); d.text((w / 2, h * 0.7), word2, font=R.font(h * 0.05), fill=(40, 40, 40), anchor='mm')
    return R.fit(im, w, h, 22)
_bad = {}
def bad(k, w, h):
    key = (k, w, h)
    if key not in _bad:
        src = ['fashionposter', 'skincareglow', 'lookbook'][k]
        _bad[key] = bad_img(AV[src], k, w, h, ['SUPER ROBE!!!', 'nouveau produit', 'SOLDES'][k], ['', 'acheter acheter', 'look look look'][k])
    return _bad[key]
S = dict(hook1='Mode, cosmétiques, looks…', hook2='Voilà comment la plupart des gens\nfont leurs visuels avec l’IA…',
 p=['fais une belle affiche pour ma robe',
    'Plus pro, fond plus joli, meilleure lumière, enlève la plante, mets du texte, plus de contraste, garde bien le flacon…',
    'Tu es un directeur artistique. Fais une page de lookbook élégante avec ce look, fond neutre texturé, lumière douce, cadrage éditorial, garde la tenue exactement identique, laisse de la place pour le titre, style magazine, haute qualité, 3:4…'],
 faster='Il y a bien plus rapide.', ready='Prompts prêts à l’emploi', copy='Copier', copied='Copié', gen='Générer ici', done='Terminé.', secs='20 secondes', time='temps passé')
CAT_ITEMS = ['fashionposter', 'lookbook', 'skincareglow', 'hairshowcase', 'makeuplook', 'serumdrop', 'perfumegarden', 'braidstyle', 'mannequinstudio', 'streetfit', 'bagluxury', 'lipstickline', 'weddingdress', 'africanprint', 'nailart', 'summerstyle', 'bridalmakeup', 'naturalhair', 'mensuit', 'cozyknit', 'productglow', 'packshot', 'lifestyle', 'giftbox']
_th = {}
def thumb(n):
    if n not in _th: _th[n] = ld(n, 'apres')
    return _th[n]
def mmss(sec): sec = int(max(0, sec)); return f'{sec // 60}:{sec % 60:02d}'
def geom():
    if LAND: return dict(px=W * 0.05, py=H * 0.20, pw=W * 0.52, ph=H * 0.50, rx=W * 0.78, ry=H * 0.50, rw=int(W * 0.23), tx=W * 0.31, ty=H * 0.09, sx=W * 0.08, sy=H * 0.86)
    return dict(px=W * 0.06, py=H * 0.17, pw=W * 0.88, ph=H * 0.23, rx=W / 2, ry=H * 0.64, rw=int(W * 0.56), tx=W / 2, ty=H * 0.075, sx=W * 0.22, sy=H * 0.885)
def pbox(img, g, text_s, frac, label, col, photo=None):
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    x0, y0, x1, y1 = g['px'], g['py'], g['px'] + g['pw'], g['py'] + g['ph']
    d.rounded_rectangle((x0, y0, x1, y1), 28 * U, fill=(24, 26, 33, 255), outline=col + (255,), width=3)
    f = R.font((36 if not LAND else 32) * U, 'r'); tx = x0 + (150 if photo is not None else 36) * U
    typed = text_s[:int(len(text_s) * clamp(frac))]
    lines = R.wrap_text(d, typed, f, (x1 - tx) - 30 * U)[:7]
    ys = y0 + 34 * U
    for ln in lines: d.text((tx, ys), ln, font=f, fill=(235, 235, 240, 255), anchor='la'); ys += f.size * 1.3
    if frac < 1 and int(frac * 40) % 2 == 0: d.text((tx + (d.textlength(lines[-1], font=f) if lines else 0) + 4 * U, ys - f.size * 1.3), '|', font=f, fill=col + (255,), anchor='la')
    if label: d.text((x0 + 30 * U, y1 - 34 * U), label, font=R.font(28 * U, 'b'), fill=col + (255,), anchor='lm')
    img = Image.alpha_composite(img, lay)
    if photo is not None: img = R.paste(img, R.fit(photo, int(96 * U), int(96 * U), 16), x0 + 76 * U, y0 + 72 * U, shadowed=False)
    return img
def timer(img, g, sec, col, label):
    img = R.pill(img, mmss(sec), g['tx'], g['ty'], 80 if not LAND else 70, bgc=(20, 22, 28), fg=col, padx=46, pady=18)
    return R.text(img, label, g['tx'], g['ty'] + 92 * U, 34, col=MUT, kind='r', shadow_=False)
# ---------- scènes ----------
def s_hook(t):
    img = R.bg(t)
    a = ease_out((t - 0.2) / 0.5); img = R.text(img, S['hook1'], W / 2, H * (0.30 if not LAND else 0.30), 84 if not LAND else 76, col=ACC2, alpha=a, maxw=W * 0.92)
    for i, ln in enumerate(S['hook2'].split('\n')):
        a = ease_out((t - 1.4 - i * 0.4) / 0.4)
        img = R.text(img, ln, W / 2, H * 0.46 + i * 112 * U + (1 - a) * 30 * U, 70 if not LAND else 62, alpha=a, maxw=W * 0.92)
    # trois photos « avant » en bas
    for i, n in enumerate(('fashionposter', 'skincareglow', 'lookbook')):
        a = ease_back((t - 3.0 - i * 0.3) / 0.5)
        if a <= 0: continue
        cw = int(W * (0.14 if LAND else 0.26)); ch = int(cw * 1.2)
        img = R.paste(img, R.fit(AV[n], cw, ch), W * (0.37 + 0.13 * i) if LAND else W * (0.2 + 0.3 * i), H * (0.83 if LAND else 0.76), angle=(-5 + 5 * i), scale=clamp(a, 0.01, 1.05))
    return img
def s_struggle(t):
    tt = t - TL['struggle'][0]; img = R.bg(t); g = geom()
    img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (60, 0, 0, 40)))
    starts = [0.4, 5.0, 9.0]; dur_t = [2.6, 2.4, 4.0]; res_at = [3.6, 8.0, 13.4]
    k = 0 if tt < 4.9 else (1 if tt < 8.9 else 2)
    frac = (tt - starts[k]) / dur_t[k]
    ph = [AV['fashionposter'], AV['skincareglow'], AV['lookbook']][k]
    img = pbox(img, g, S['p'][k], frac, f"Essai {k + 1}", RED if k == 2 else ACC2, ph)
    if tt >= res_at[k]:
        a = ease_back((tt - res_at[k]) / 0.5); rw = g['rw']; rh = int(rw * 1.24)
        img = R.paste(img, bad(k, rw, rh), g['rx'], g['ry'], angle=(-2 + k * 2), scale=clamp(a, 0.01, 1.05))
        if a > 0.8: img = R.pill(img, 'Toujours pas ça' if k == 2 else 'Bof…', g['rx'], g['ry'] + rh * 0.58, 34, bgc=(RED if k == 2 else (70, 72, 82)), fg=WHITE, padx=26, pady=12)
    elif tt >= starts[k] + dur_t[k] + 0.2:
        n = int(tt * 4) % 4; img = R.text(img, '.' * (n + 1), g['rx'], g['ry'], 120, col=MUT)
    for v in range(k):
        if tt >= res_at[v] + 0.9: img = R.paste(img, bad(v, int(150 * U), int(186 * U)), g['sx'] + v * 170 * U, g['sy'], shadowed=False, alpha=0.9)
    img = timer(img, g, 892 * ease_io(tt / 15.4), RED, S['time'])
    return R.badge(img, t, TL['struggle'][0] + 0.6)
def s_faster(t):
    tt = t - TL['faster'][0]; img = R.bg(t)
    a = ease_out((tt - 0.2) / 0.45); img = R.text(img, S['faster'], W / 2, H * 0.5, 100 if not LAND else 92, alpha=a, maxw=W * 0.9)
    for (sx, sy, off, r) in R.SPK[:10]:
        aa = math.sin(clamp((tt - 0.8 - off) / 0.8) * math.pi)
        if aa > 0: img = R.sparkle(img, W * sx, H * (0.3 + 0.4 * sy), r * U * aa * 1.4, aa)
    return img
DEMOS = [(24.8, 31.8, '/fashionposter', 'ma robe', 'Une robe', 'fashionposter'), (31.8, 36.0, '/skincareglow', 'ma crème visage', 'Un soin de peau', 'skincareglow'), (36.0, 41.3, '/lookbook', 'mon look', 'Un look', 'lookbook')]
def s_demo(t):
    for (a0, a1, code, usertext, label, n) in DEMOS:
        if a0 <= t < a1: break
    tt = t - a0; img = R.bg(t); g = geom()
    cw = int(W * 0.84) if not LAND else int(W * 0.46); ch = int(H * 0.17) if not LAND else int(H * 0.26)
    cx = W / 2 if not LAND else W * 0.30; cy = H * 0.255 if not LAND else H * 0.47
    x0, y0 = cx - cw / 2, cy - ch / 2
    a = ease_back(tt / 0.45); sc = clamp(a, 0.01, 1.0)
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    d.rounded_rectangle((cx - cw * sc / 2, cy - ch * sc / 2, cx + cw * sc / 2, cy + ch * sc / 2), 30 * U, fill=(20, 22, 28, 255), outline=(60, 64, 74, 255), width=3)
    tap0 = 0.9
    if sc > 0.95:
        d.text((x0 + 36 * U, y0 + 44 * U), code, font=R.font(48 * U, 'm'), fill=ACC2 + (255,), anchor='lm')
        d.text((x0 + 36 * U, y0 + 96 * U), S['ready'], font=R.font(30 * U, 'r'), fill=MUT + (255,), anchor='lm')
        by = y0 + ch - 54 * U
        d.rounded_rectangle((x0 + 36 * U, by - 34 * U, x0 + 36 * U + 270 * U, by + 34 * U), 34 * U, fill=ACC + (255,)); d.text((x0 + (36 + 135) * U, by), S['gen'], font=R.font(30 * U), fill=(255, 255, 255, 255), anchor='mm')
        bx0 = x0 + 330 * U; copied = tt > tap0 + 0.3
        d.rounded_rectangle((bx0, by - 34 * U, bx0 + 200 * U, by + 34 * U), 34 * U, fill=(OK + (255,)) if copied else (30, 32, 40, 255), outline=None if copied else (80, 84, 96, 255), width=2)
        d.text((bx0 + 100 * U, by), S['copied'] if copied else S['copy'], font=R.font(30 * U), fill=(255, 255, 255, 255), anchor='mm')
    img = Image.alpha_composite(img, lay)
    if tap0 - 0.2 < tt < tap0 + 0.5:
        px = x0 + 330 * U + 100 * U; py = y0 + ch - 54 * U; r = (1 - clamp((tt - tap0) / 0.4)) * 30 * U + 26 * U
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(ov).ellipse((px - r, py - r, px + r, py + r), outline=(255, 255, 255, 200), width=5); img = Image.alpha_composite(img, ov)
    if tt > 1.6:
        g2 = dict(g)
        if not LAND: g2.update(py=H * 0.375, ph=H * 0.115)
        img = pbox(img, g2, f'{code} {usertext}', (tt - 1.6) / 0.5, '', OK, AV[n])
    if tt >= 2.6:
        a = ease_back((tt - 2.6) / 0.5); rw = g['rw']; rh = int(rw * 1.25); yy = g['ry'] + (0 if LAND else 0.07 * H)
        img = R.paste(img, R.fit(AP[n], rw, rh), g['rx'], yy, scale=clamp(a, 0.01, 1.06))
        for (sx, sy, off, r) in R.SPK:
            aa = math.sin(clamp((tt - 2.9 - off * 0.6) / 0.8) * math.pi)
            if aa > 0: img = R.sparkle(img, g['rx'] + (sx - 0.5) * rw * 1.2, yy + (sy - 0.5) * rh * 1.1, r * U * aa, aa)
        if a > 0.8: img = R.pill(img, S['done'], g['rx'], yy + rh * 0.58, 38, bgc=OK, fg=(0, 30, 10), padx=30, pady=14)
    img = R.pill(img, label, g['tx'], g['ty'], 52 if not LAND else 44, bgc=(20, 22, 28), fg=ACC2, padx=40, pady=16)
    return R.badge(img, t, a0 + 0.8)
_strip = {}
POOL = None
def pool():
    """Toutes les illustrations disponibles (celles de mode, beauté et produit en premier), réparties en rangées."""
    global POOL
    if POOL is None:
        import os, random
        NOTEXT = set('saleposter forrent newarrivals bundleoffer sidebyside menulineup openday shopfront beautypromo blueprint cyberpunk barbershop vintagerack'.split())  # images avec du texte parasite
        names = sorted({f[:-len('-t.webp')] for f in os.listdir(IMG) if f.endswith('-t.webp') and f[:-len('-t.webp')] not in NOTEXT and os.path.exists(IMG + f[:-len('-t.webp')] + '-apres.webp')})
        pri = ['fashionposter', 'lookbook', 'skincareglow', 'hairshowcase', 'productglow', 'splashshot']
        rest = [n for n in names if n not in pri]
        random.Random(11).shuffle(rest)
        POOL = [n for n in pri if n in names] + rest
    return POOL
def thumb_t(n):
    k = ('t', n)
    if k not in _th: _th[k] = R.load(n, 't')
    return _th[k]
def strip_row(row, ch, rows):
    key = (row, ch)
    if key in _strip: return _strip[key]
    items = pool()[row::rows][:34]
    cw = int(ch * 0.8); gap = int(18 * U); n = len(items); length = n * (cw + gap)
    s = Image.new('RGBA', (length * 2, ch + int(40 * U)), (0, 0, 0, 0)); d = ImageDraw.Draw(s)
    for rep in range(2):
        for i, nm in enumerate(items):
            x = rep * length + i * (cw + gap)
            s.alpha_composite(R.fit(thumb_t(nm), cw, ch, 18), (x, 0))
            d.text((x + cw / 2, ch + 20 * U), ('/' + nm) if len(nm) < 13 else ('/' + nm[:11] + '…'), font=R.font(20 * U, 'm'), fill=ACC2 + (255,), anchor='mm')
    _strip[key] = (s, length); return _strip[key]
CATS = ['Mode', 'Beauté', 'Pub produit', 'Food', 'Immobilier', 'Événements', 'Marque', 'Vidéo pub']
def s_cat(t):
    tt = t - TL['cat'][0]; img = R.bg(t)
    n = int(650 * ease_out(tt / 3.0))
    a = ease_out((tt - 0.1) / 0.4)
    if LAND:
        img = R.text(img, str(n), W * 0.36, H * 0.085, 120, col=ACC2, alpha=a, anchor='rm')
        img = R.text(img, 'commandes gratuites', W * 0.38, H * 0.088, 64, alpha=a, anchor='lm')
    else:
        img = R.text(img, f'{n} commandes gratuites', W / 2, H * 0.065, 76, alpha=a, maxw=W * 0.94)
    rows = 3 if LAND else 4; ch = int(H * (0.17 if LAND else 0.115)); top = H * (0.235 if LAND else 0.215); hh = ch + 40 * U
    for r in range(rows):
        s, length = strip_row(r, ch, rows); off = (tt * (230 if r % 2 == 0 else -230) * U + r * 300 * U) % length
        x = int(off) if r % 2 == 1 else int(length - off) % length
        crop = s.crop((x, 0, x + W, s.height)); y = top + r * (hh + 12 * U)
        aa = ease_out((tt - 0.3 - r * 0.15) / 0.5)
        if aa < 1: crop.putalpha(crop.getchannel('A').point(lambda v: int(v * aa)))
        img.alpha_composite(crop, (0, int(y)))
    cols = 8 if LAND else 4; y0 = H * (0.155 if LAND else 0.108)
    for i, c in enumerate(CATS):
        aa = ease_back((tt - 3.2 - i * 0.45) / 0.4)
        if aa <= 0: continue
        cx = W * (0.085 + 0.119 * (i % cols)) if LAND else W * (0.14 + 0.24 * (i % cols)); cy = y0 + (i // cols) * 74 * U
        img = R.pill(img, c, cx, cy, 27 if LAND else 28, bgc=(ACC if i < 2 else (30, 32, 40)), fg=WHITE, scale=clamp(aa, 0.01, 1.05), alpha=clamp(aa, 0, 1), padx=24, pady=12)
    for i, (c, col) in enumerate([('Copier', ACC), ('Coller', ACC), ('Gratuit', OK)]):
        aa = ease_back((tt - 11.5 - i * 0.7) / 0.45)
        if aa <= 0: continue
        pulse = 1 + 0.03 * math.sin(tt * 5 + i)
        cx = W * (0.30 + 0.20 * i) if LAND else W * (0.2 + 0.30 * i); cy = H * (0.935 if LAND else 0.885)
        img = R.pill(img, c, cx, cy, 52 if LAND else 46, bgc=col, fg=(WHITE if col != OK else (0, 30, 10)), scale=clamp(aa, 0.01, 1.05) * pulse, alpha=clamp(aa, 0, 1), padx=40, pady=18)
    return img if LAND else R.badge(img, t, TL['cat'][0] + 0.8)
def s_catb(t):
    tt = t - TL['catb'][0]; img = R.bg(t)
    mode = tt < 5.7
    names = ['fashionposter', 'lookbook', 'streetfit', 'weddingdress'] if mode else ['skincareglow', 'makeuplook', 'hairshowcase', 'nailart']
    chips = ['Affiche de collection', 'Lookbook', 'Tenue de rue', 'Robe de mariée'] if mode else ['Soin du visage', 'Maquillage', 'Coiffure', 'Ongles', 'Parfum']
    t0 = 0.0 if mode else 5.7; lt = tt - t0
    a = ease_out(lt / 0.4); img = R.pill(img, 'Pour la mode' if mode else 'Pour la beauté', W / 2, H * (0.10 if LAND else 0.07), 54 if LAND else 48, bgc=ACC, fg=WHITE, alpha=a, padx=44, pady=18)
    cw = int(W * (0.17 if LAND else 0.40)); chh = int(cw * 1.25)
    for i, n in enumerate(names):
        aa = ease_back((lt - 0.3 - i * 0.25) / 0.5)
        if aa <= 0: continue
        if LAND: px = W * (0.16 + 0.225 * i); py = H * 0.45
        else: px = W * (0.28 + 0.44 * (i % 2)); py = H * (0.24 + 0.205 * (i // 2))
        img = R.paste(img, R.fit(thumb(n), cw, chh), px, py, angle=(-4 + 2.7 * i) if LAND else (-3 + 6 * (i % 2)), scale=clamp(aa, 0.01, 1.05))
    for i, c in enumerate(chips):
        aa = ease_back((lt - 0.8 - i * 0.7) / 0.4)
        if aa <= 0: continue
        if LAND: cx = W * (0.15 + 0.175 * i) if not mode else W * (0.17 + 0.22 * i); cy = H * 0.82
        else: cx = W * (0.27 + 0.46 * (i % 2)); cy = H * (0.67 + 0.075 * (i // 2))
        img = R.pill(img, c, cx, cy, 36 if LAND else 34, bgc=(30, 32, 40), fg=WHITE, scale=clamp(aa, 0.01, 1.05), alpha=clamp(aa, 0, 1), padx=28, pady=15)
    return R.badge(img, t, TL['catb'][0] + 0.8)
def s_studio(t):
    tt = t - TL['studio'][0]; img = R.bg(t)
    a = ease_back((tt - 0.2) / 0.5)
    img = R.pill(img, S['gen'], W / 2, H * (0.10 if LAND else 0.08), 70 if LAND else 64, bgc=ACC, fg=WHITE, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=56, pady=24)
    cw = int(W * (0.20 if LAND else 0.38)); chh = int(cw * 1.25)
    lx, ly = (W * 0.27, H * 0.47) if LAND else (W * 0.27, H * 0.37)
    rx, ry = (W * 0.73, H * 0.47) if LAND else (W * 0.73, H * 0.37)
    a = ease_back((tt - 1.0) / 0.5)
    if a > 0:
        img = R.paste(img, R.fit(AV['fashionposter'], cw, chh), lx, ly, angle=-3, scale=clamp(a, 0.01, 1.05))
        img = R.pill(img, 'Votre photo', lx, ly + chh * 0.60, 32, bgc=(30, 32, 40), fg=WHITE, alpha=clamp(a, 0, 1), padx=24, pady=12)
    if 2.4 <= tt < 5.4:  # création en cours : arc qui tourne
        ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov); r = 56 * U; ang = (tt * 360 * 1.3) % 360
        d.arc((rx - r, ry - r, rx + r, ry + r), ang, ang + 260, fill=ACC + (255,), width=int(12 * U)); img = Image.alpha_composite(img, ov)
        img = R.text(img, 'Création en cours…', rx, ry + 110 * U, 38, col=MUT, kind='r', shadow_=False)
    if tt >= 5.4:
        a = ease_back((tt - 5.4) / 0.5)
        img = R.paste(img, R.fit(AP['fashionposter'], cw, chh), rx, ry, scale=clamp(a, 0.01, 1.06))
        for (sx, sy, off, r) in R.SPK:
            aa = math.sin(clamp((tt - 5.7 - off * 0.6) / 0.8) * math.pi)
            if aa > 0: img = R.sparkle(img, rx + (sx - 0.5) * cw * 1.2, ry + (sy - 0.5) * chh * 1.1, r * U * aa, aa)
        if a > 0.8: img = R.pill(img, S['done'], rx, ry + chh * 0.60, 36, bgc=OK, fg=(0, 30, 10), padx=28, pady=13)
    for i, c in enumerate(['Mobile money', 'dès 500 FCFA']):
        aa = ease_back((tt - 6.8 - i * 0.8) / 0.4)
        if aa <= 0: continue
        cx = W * (0.40 + 0.20 * i) if LAND else W * (0.30 + 0.40 * i); cy = H * (0.90 if LAND else 0.72)
        img = R.pill(img, c, cx, cy, 44 if LAND else 40, bgc=(OK if i == 1 else (30, 32, 40)), fg=((0, 30, 10) if i == 1 else WHITE), scale=clamp(aa, 0.01, 1.05), alpha=clamp(aa, 0, 1), padx=36, pady=18)
    return R.badge(img, t, TL['studio'][0] + 0.8)
def s_cta(t):
    tt = t - TL['cta'][0]; img = R.bg(t)
    pw = W * 0.18 if LAND else W * 0.31; cw, ch = int(pw), int(pw * 1.24)
    for i, nme in enumerate(['fashionposter', 'skincareglow', 'lookbook']):
        a = ease_back((tt - 0.1 - i * 0.12) / 0.5)
        if a <= 0: continue
        if LAND: px = W * (0.10 + 0.145 * i); py = H * 0.5 + (i % 2) * 36 * U - 18 * U
        else: px = W * (0.22 + 0.28 * i); py = H * 0.70 + (i % 2) * 24 * U
        img = R.paste(img, R.fit(AP[nme], cw, ch), px, py, angle=(-6 + 6 * i), scale=clamp(a, 0.01, 1.1))
    tx = W * 0.70 if LAND else W / 2; ty0 = 0.22 if LAND else 0.12
    a = ease_out((tt - 0.3) / 0.4); img = R.text(img, '/SlashAtlas', tx, H * ty0, 96 if not LAND else 80, col=ACC2, alpha=a, maxw=W * (0.9 if not LAND else 0.50))
    a = ease_out((tt - 0.8) / 0.4); img = R.text(img, 'Essayez gratuitement', tx, H * (ty0 + (0.11 if not LAND else 0.15)), 80 if not LAND else 66, alpha=a, maxw=W * (0.9 if not LAND else 0.50))
    a = ease_back((tt - 1.3) / 0.5)
    if a > 0:
        pulse = 1 + 0.035 * math.sin(tt * 6)
        img = R.pill(img, 'slashatlas.com', tx, H * (ty0 + (0.22 if not LAND else 0.29)), 76 if not LAND else 56, alpha=clamp(a, 0, 1), scale=clamp(a, 0.01, 1.1) * pulse, padx=50, pady=26)
    a = ease_out((tt - 2.2) / 0.4); img = R.text(img, 'Gratuit, sans inscription pour copier', tx, H * (ty0 + (0.31 if not LAND else 0.42)), 42 if not LAND else 36, col=MUT, kind='r', alpha=a, maxw=W * (0.9 if not LAND else 0.52))
    a = ease_out((tt - 4.2) / 0.5); img = R.text(img, 'Dites-nous ce que vous en pensez', tx, H * (ty0 + (0.38 if not LAND else 0.52)), 44 if not LAND else 38, alpha=a, maxw=W * (0.9 if not LAND else 0.52))
    a = ease_out((tt - 5.2) / 0.5); img = R.text(img, 'Collaboration : contact@slashatlas.com', tx, H * (ty0 + (0.44 if not LAND else 0.60)), 38 if not LAND else 32, col=ACC2, kind='r', alpha=a, maxw=W * (0.92 if not LAND else 0.52))
    return R.badge(img, t, TL['cta'][0] + 0.8)
SC = [(0, 6.4, s_hook), (6.4, 22.0, s_struggle), (22.0, 24.8, s_faster), (24.8, 41.3, s_demo), (41.3, 60.3, s_cat), (60.3, 72.3, s_catb), (72.3, 82.8, s_studio), (82.8, 999, s_cta)]
def frame(t, limit):
    for a_, b_, fn in SC:
        if a_ <= t < b_: img = fn(t); break
    for tb in BND + [31.8, 36.0]:
        if tb <= t < tb + 0.18: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(200 * (1 - (t - tb) / 0.18)))))
    if t > limit - 0.6: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * clamp((t - (limit - 0.6)) / 0.6)))))
    return img.convert('RGB')
if __name__ == '__main__':
    OUT = sys.argv[3]; LIMIT = float(sys.argv[5]); MIX = sys.argv[6]
    if len(sys.argv) > 7 and sys.argv[7] == 'test':
        import os; os.makedirs('test', exist_ok=True)
        for tt in [float(x) for x in sys.argv[8].split(',')]: frame(tt, LIMIT).save(f'test/v3_{W}x{H}_{tt}.png')
        sys.exit(0)
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-i', MIX, '-t', str(LIMIT),
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for i in range(int(LIMIT * FPS)): p.stdin.write(frame(i / FPS, LIMIT).tobytes())
    p.stdin.close(); p.wait(); print('fini', OUT)
