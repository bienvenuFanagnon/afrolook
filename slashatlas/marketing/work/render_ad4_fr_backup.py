# Publicité SlashAtlas n° 4 : le QR code sur l'affiche (créer, scanner, commander), version française, ~1 min.
# Usage : python3 render_ad4.py <largeur> <hauteur> <sortie.mp4> fr <secondes> <mix.wav>   |   … test <t1,t2,…>
import sys, math, json, subprocess
import numpy as np
import render_ad2 as R
from PIL import Image, ImageDraw, ImageFilter
import imageio_ffmpeg
W, H, U, LAND = R.W, R.H, R.U, R.LAND
ACC, ACC2, WHITE, MUT, OK, RED = R.ACC, R.ACC2, R.WHITE, R.MUT, R.OK, (255, 85, 85)
WA = (37, 211, 102)
clamp, ease_out, ease_io, ease_back = R.clamp, R.ease_out, R.ease_io, R.ease_back
FPS = 30
QRM = json.load(open('qrm.json')); QN = len(QRM)  # vrai QR code de https://maboutique.com/robes
AP = R.load('fashionposter', 'apres'); AV = R.load('fashionposter', 'avant')
TL = dict(hook=(0, 6.2), prob=(6.2, 11.8), idea=(11.8, 15.3), create=(15.3, 25.9), scan=(25.9, 32.9), ctrl=(32.9, 39.9), trust=(39.9, 47.3), cta=(47.3, 99))
LINK = 'maboutique.com/robes'; CTA = 'Scannez pour commander'
def lerp(a, b, k): return a + (b - a) * k
def seg(tt, a, b): return clamp((tt - a) / (b - a))
# ---------- dessin : icônes ----------
def check(img, cx, cy, r, col=(255, 255, 255), w=None, alpha=1.0):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay); w = int(w or r * 0.28)
    d.line([(cx - r * 0.55, cy), (cx - r * 0.12, cy + r * 0.45), (cx + r * 0.6, cy - r * 0.4)], fill=col + (int(255 * alpha),), width=w, joint='curve')
    return Image.alpha_composite(img, lay)
def cross(img, cx, cy, r, col=RED, alpha=1.0):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay); w = int(r * 0.3)
    d.line([(cx - r * 0.5, cy - r * 0.5), (cx + r * 0.5, cy + r * 0.5)], fill=col + (int(255 * alpha),), width=w)
    d.line([(cx - r * 0.5, cy + r * 0.5), (cx + r * 0.5, cy - r * 0.5)], fill=col + (int(255 * alpha),), width=w)
    return Image.alpha_composite(img, lay)
def disc(img, cx, cy, r, col, alpha=1.0):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); ImageDraw.Draw(lay).ellipse((cx - r, cy - r, cx + r, cy + r), fill=col + (int(255 * alpha),)); return Image.alpha_composite(img, lay)
def ring(img, cx, cy, r, col, w=6, alpha=1.0):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); ImageDraw.Draw(lay).ellipse((cx - r, cy - r, cx + r, cy + r), outline=col + (int(255 * alpha),), width=int(w)); return Image.alpha_composite(img, lay)
def arrow(img, x0, y0, x1, y1, col, frac=1.0, w=10):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    xe, ye = lerp(x0, x1, frac), lerp(y0, y1, frac); d.line([(x0, y0), (xe, ye)], fill=col + (255,), width=int(w * U))
    if frac > 0.95:
        ang = math.atan2(y1 - y0, x1 - x0); s = 30 * U
        d.polygon([(x1, y1), (x1 - s * math.cos(ang - 0.5), y1 - s * math.sin(ang - 0.5)), (x1 - s * math.cos(ang + 0.5), y1 - s * math.sin(ang + 0.5))], fill=col + (255,))
    return Image.alpha_composite(img, lay)
# ---------- le cartouche QR (même dessin que sur le site) ----------
_tile = {}
def qr_tile(tw, reveal=1.0, cta=CTA):
    tw = int(tw); key = (tw, round(reveal, 2), cta)
    if key in _tile: return _tile[key]
    top = int(tw * 0.17); bot = int(tw * 0.27); th = top + tw + bot
    im = Image.new('RGBA', (tw, th), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, tw - 1, th - 1), tw * 0.07, fill=(255, 255, 255, 255))
    fs = tw * 0.082; f = R.font(fs, 'b')
    while d.textlength(cta, font=f) > tw * 0.94 and fs > 8: fs -= 1; f = R.font(fs, 'b')
    d.text((tw / 2, top * 0.62), cta, font=f, fill=(17, 17, 17, 255), anchor='mm')
    cell = tw / (QN + 6); rows = QN * clamp(reveal)
    for r in range(QN):
        if r >= rows: break
        for c in range(QN):
            if QRM[r][c]:
                x = int((c + 3) * cell); y = top + int((r + 3) * cell); d.rectangle((x, y, int((c + 4) * cell), top + int((r + 4) * cell)), fill=(0, 0, 0, 255))
    d.text((tw / 2, top + tw + bot * 0.36), 'Créé avec', font=R.font(tw * 0.07, 'r'), fill=(68, 68, 68, 255), anchor='mm')
    d.text((tw / 2, top + tw + bot * 0.78), 'slashatlas.com', font=R.font(tw * 0.105, 'b'), fill=(17, 17, 17, 255), anchor='mm')
    _tile[key] = im; return im
def tile_h(tw): return int(tw * 0.17) + int(tw) + int(tw * 0.27)
_pq = {}
def poster_qr(w, h, ax=0.97, ay=0.97, frac=0.21, reveal=1.0, cta=CTA, tile=True, contact=False):
    """Affiche de mode ; le cartouche QR est ancré par son coin (ax, ay) en fraction de l'affiche."""
    w, h = int(w), int(h); key = (w, h, round(ax, 3), round(ay, 3), round(frac, 3), round(reveal, 2), cta, tile, contact)
    if key in _pq: return _pq[key]
    im = R.fit(AP, w, h, 22).convert('RGBA'); d = ImageDraw.Draw(im)
    if contact:
        d.rectangle((0, h * 0.88, w, h), fill=(0, 0, 0, 150)); d.text((w / 2, h * 0.94), 'Maison Awa  ·  07 00 00 00 00', font=R.font(h * 0.032, 'b'), fill=(255, 255, 255, 235), anchor='mm')
    if tile:
        tw = int(w * frac); t_ = qr_tile(tw, reveal, cta); th = t_.height; m = w * 0.03
        x = int(clamp(ax * w - tw / 2 * (1 if ax > 0.5 else -1) - (tw / 2 if ax > 0.5 else 0) + (tw / 2 if ax > 0.5 else 0), 0, w))
        x = int(m + ax * (w - tw - 2 * m)); y = int(m + ay * (h - th - 2 * m))
        sh = Image.new('RGBA', im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rounded_rectangle((x, y + 6, x + tw, y + th + 6), tw * 0.07, fill=(0, 0, 0, 90)); sh = sh.filter(ImageFilter.GaussianBlur(8))
        im = Image.alpha_composite(im, sh); im.alpha_composite(t_, (x, y))
    if len(_pq) > 400: _pq.clear()
    _pq[key] = im; return im
def tile_center(w, h, ax=1.0, ay=1.0, frac=0.21):
    tw = int(w * frac); th = tile_h(tw); m = w * 0.03
    return m + ax * (w - tw - 2 * m) + tw / 2, m + ay * (h - th - 2 * m) + th / 2, tw, th
# ---------- téléphone ----------
def phone(pw, ph, screen):
    pw, ph = int(pw), int(ph); m = int(14 * U); im = Image.new('RGBA', (pw, ph), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, pw - 1, ph - 1), pw * 0.12, fill=(16, 18, 24, 255), outline=(70, 74, 86, 255), width=3)
    sw, sh = pw - 2 * m, ph - 2 * m; sc = screen.convert('RGBA').resize((sw, sh), Image.LANCZOS)
    mk = Image.new('L', (sw, sh), 0); ImageDraw.Draw(mk).rounded_rectangle((0, 0, sw - 1, sh - 1), pw * 0.095, fill=255); sc.putalpha(mk); im.alpha_composite(sc, (m, m))
    d.rounded_rectangle((pw / 2 - pw * 0.13, m + 8 * U, pw / 2 + pw * 0.13, m + 8 * U + 26 * U), 14 * U, fill=(16, 18, 24, 255))
    return im
def pbox(sw, sh):
    return int(sw), int(sh)
def screen_camera(sw, sh, tt):
    """Vue de l'appareil photo : l'affiche, le zoom vers le QR, le cadre de scan puis le lien proposé."""
    U = sw / 660.0
    sw, sh = int(sw), int(sh)
    pw0, ph0 = int(sw * 1.5), int(sw * 1.5 * 1.24); P = poster_qr(pw0, ph0, 0.97, 0.97, 0.26)
    cx, cy, tw, th = tile_center(pw0, ph0, 0.97, 0.97, 0.26)
    z = lerp(0.9, 2.3, ease_io(seg(tt, 0.2, 2.0))); vx = lerp(pw0 / 2, cx, ease_io(seg(tt, 0.2, 2.0))); vy = lerp(ph0 / 2, cy, ease_io(seg(tt, 0.2, 2.0)))
    vw, vh = sw / z, sh / z; x0, y0 = vx - vw / 2, vy - vh / 2
    base = Image.new('RGBA', (sw, sh), (176, 170, 160, 255))
    cr = P.crop((int(x0), int(y0), int(x0 + vw), int(y0 + vh)))
    base.alpha_composite(cr.resize((int(cr.width * z), int(cr.height * z)), Image.BILINEAR), (int(max(0, -x0) * z), int(max(0, -y0) * z)))
    d = ImageDraw.Draw(base)
    sx, sy = (cx - x0) * z, (cy - y0) * z; hw, hh = tw * z / 2 * 1.12, th * z / 2 * 1.04
    lock = seg(tt, 1.6, 2.2); col = tuple(int(lerp(255, c, lock)) for c in OK)
    if tt > 1.0:
        a = clamp((tt - 1.0) / 0.3); L_ = 46 * U * (1 - 0.12 * lock); wd = int(7 * U)
        for (ox, oy, dx, dy) in ((-1, -1, 1, 1), (1, -1, -1, 1), (-1, 1, 1, -1), (1, 1, -1, -1)):
            px, py = sx + ox * hw, sy + oy * hh
            d.line([(px, py + dy * L_), (px, py), (px + dx * L_, py)], fill=col + (int(255 * a),), width=wd)
        if lock < 1: ly = sy - hh + (2 * hh) * ((tt * 1.8) % 1.0); d.line([(sx - hw, ly), (sx + hw, ly)], fill=OK + (180,), width=int(5 * U))
    if tt > 2.5:
        k = ease_back((tt - 2.5) / 0.45); bw, bh = sw * 0.84, 120 * U; bx, by = sw / 2, sh * 0.13 + (1 - clamp(k)) * -60 * U
        lay = Image.new('RGBA', (sw, sh), (0, 0, 0, 0)); dd = ImageDraw.Draw(lay)
        dd.rounded_rectangle((bx - bw / 2, by - bh / 2, bx + bw / 2, by + bh / 2), 30 * U, fill=(250, 250, 252, int(255 * clamp(k))))
        dd.text((bx - bw / 2 + 30 * U, by - 18 * U), LINK, font=R.font(34 * U, 'b'), fill=(20, 20, 24, int(255 * clamp(k))), anchor='lm')
        dd.text((bx - bw / 2 + 30 * U, by + 26 * U), 'Ouvrir le lien', font=R.font(25 * U, 'r'), fill=(90, 94, 104, int(255 * clamp(k))), anchor='lm')
        dd.rounded_rectangle((bx + bw / 2 - 150 * U, by - 30 * U, bx + bw / 2 - 24 * U, by + 30 * U), 30 * U, fill=ACC + (int(255 * clamp(k)),)); dd.text((bx + bw / 2 - 87 * U, by), 'Ouvrir', font=R.font(28 * U), fill=(255, 255, 255, int(255 * clamp(k))), anchor='mm')
        base = Image.alpha_composite(base, lay)
    return base
def screen_shop(sw, sh, tt):
    U = sw / 660.0
    sw, sh = int(sw), int(sh); im = Image.new('RGBA', (sw, sh), (247, 245, 242, 255)); d = ImageDraw.Draw(im)
    d.rectangle((0, 0, sw, int(sh * 0.12)), fill=(30, 24, 22, 255)); d.text((sw / 2, sh * 0.068), 'Maison Awa', font=R.font(46 * U), fill=(255, 235, 200, 255), anchor='mm')
    d.rounded_rectangle((sw * 0.30, sh * 0.135, sw * 0.70, sh * 0.135 + 38 * U), 19 * U, fill=(228, 224, 218, 255)); d.text((sw / 2, sh * 0.135 + 19 * U), 'Exemple de boutique', font=R.font(21 * U, 'r'), fill=(100, 96, 90, 255), anchor='mm')
    ph = int(sh * 0.40); pimg = R.fit(AP, int(sw * 0.84), ph, 24); im.alpha_composite(pimg, (int(sw * 0.08), int(sh * 0.19)))
    y = sh * 0.19 + ph + 36 * U
    d.text((sw * 0.08, y), 'Robe wax', font=R.font(46 * U), fill=(25, 22, 20, 255), anchor='lm'); d.text((sw * 0.08, y + 56 * U), '25 000 FCFA', font=R.font(38 * U, 'r'), fill=(120, 80, 30, 255), anchor='lm')
    press = seg(tt, 1.5, 1.7) * (1 - seg(tt, 1.8, 2.1)); by = y + 150 * U
    bw = sw * 0.84 * (1 - 0.03 * press)
    d.rounded_rectangle((sw / 2 - bw / 2, by - 48 * U, sw / 2 + bw / 2, by + 48 * U), 48 * U, fill=WA + (255,)); d.text((sw / 2, by), 'Commander sur WhatsApp', font=R.font(34 * U), fill=(4, 33, 15, 255), anchor='mm')
    d.rounded_rectangle((sw * 0.08, by + 76 * U, sw * 0.92, by + 76 * U + 90 * U), 45 * U, outline=(190, 184, 176, 255), width=3); d.text((sw / 2, by + 121 * U), 'Voir la collection', font=R.font(30 * U, 'r'), fill=(90, 84, 78, 255), anchor='mm')
    if 1.4 < tt < 2.3:
        r = (1 - seg(tt, 1.5, 2.2)) * 40 * U + 22 * U; ov = Image.new('RGBA', (sw, sh), (0, 0, 0, 0)); ImageDraw.Draw(ov).ellipse((sw * 0.62 - r, by - r, sw * 0.62 + r, by + r), outline=(40, 40, 40, 190), width=5); im = Image.alpha_composite(im, ov)
    return im
def screen_chat(sw, sh, tt):
    U = sw / 660.0
    sw, sh = int(sw), int(sh); im = Image.new('RGBA', (sw, sh), (229, 221, 213, 255)); d = ImageDraw.Draw(im)
    d.rectangle((0, 0, sw, int(sh * 0.11)), fill=(7, 94, 84, 255)); d.ellipse((sw * 0.06, sh * 0.03, sw * 0.06 + 70 * U, sh * 0.03 + 70 * U), fill=(255, 235, 200, 255)); d.text((sw * 0.06 + 96 * U, sh * 0.055), 'Maison Awa', font=R.font(38 * U), fill=(255, 255, 255, 255), anchor='lm')
    def bubble(y, text, right, a, col, fg):
        if a <= 0: return
        f = R.font(32 * U, 'r'); lines = R.wrap_text(d, text, f, sw * 0.62); bw = max(d.textlength(l, font=f) for l in lines) + 56 * U; bh = len(lines) * f.size * 1.3 + 40 * U
        x1 = sw * 0.95 if right else sw * 0.05 + bw; x0 = x1 - bw; yy = y + (1 - clamp(a)) * 20 * U
        lay = Image.new('RGBA', (sw, sh), (0, 0, 0, 0)); dd = ImageDraw.Draw(lay); dd.rounded_rectangle((x0, yy, x1, yy + bh), 26 * U, fill=col + (int(255 * clamp(a)),))
        for i, l in enumerate(lines): dd.text((x0 + 28 * U, yy + 20 * U + i * f.size * 1.3), l, font=f, fill=fg + (int(255 * clamp(a)),), anchor='la')
        im.alpha_composite(lay); return yy + bh
    e1 = bubble(sh * 0.17, 'Bonjour, je veux commander la robe wax, taille M.', True, ease_out(seg(tt, 0.2, 0.6)), (217, 253, 211), (20, 30, 20))
    e2 = bubble(sh * 0.17 + 190 * U, 'Merci ! Votre commande est bien reçue.', False, ease_out(seg(tt, 1.2, 1.6)), (255, 255, 255), (20, 20, 20))
    if tt > 1.9:
        k = ease_back((tt - 1.9) / 0.45); cx, cy = sw / 2, sh * 0.60; im = disc(im, cx, cy, 70 * U * clamp(k), OK); im = check(im, cx, cy, 70 * U * clamp(k), (255, 255, 255), w=int(14 * U))
        im = R.text(im, 'Commande reçue', cx, cy + 130 * U, 40, col=(30, 90, 50), shadow_=False, alpha=clamp(k))
    return im
# ---------- scènes ----------
def stage(img, t, t0):
    return R.badge(img, t, t0 + 0.6)
def bubble_say(img, text, cx, cy, tt, t0, sz=36):
    a = ease_back((tt - t0) / 0.4)
    if a <= 0: return img
    return R.pill(img, text, cx, cy, sz, bgc=(245, 245, 247), fg=(20, 20, 24), scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=30, pady=16)
def s_hook(t):
    tt = max(0, t); img = R.bg(t)
    pw = int(W * (0.29 if LAND else 0.62)); ph = int(pw * 1.24); cx = W / 2 if not LAND else W * 0.27; cy = H * (0.50 if not LAND else 0.52)
    a = ease_back((tt - 0.3) / 0.6); img = R.paste(img, poster_qr(pw, ph, tile=False, contact=True), cx, cy + (1 - clamp(a)) * 80 * U, angle=-2, scale=clamp(a, 0.01, 1.04))
    tx = W / 2 if not LAND else W * 0.68
    a1 = ease_out((tt - 0.8) / 0.4); img = R.text(img, 'Votre affiche est belle.', tx, H * (0.10 if not LAND else 0.30), 64 if not LAND else 60, alpha=a1, maxw=W * (0.92 if not LAND else 0.40))
    a2 = ease_out((tt - 2.6) / 0.4); img = R.text(img, 'Mais comment vos clients\ncommandent-ils ?', tx, H * (0.90 if not LAND else 0.50), 64 if not LAND else 56, col=ACC2, alpha=a2, maxw=W * (0.92 if not LAND else 0.40))
    if LAND: pos = [(0.50, 0.70), (0.82, 0.74), (0.66, 0.86)]
    else: pos = [(0.22, 0.30), (0.78, 0.40), (0.24, 0.68)]
    for (txt, (px, py), t0) in zip(['C’est où ?', 'Quel numéro ?', 'Vous livrez ?'], pos, [3.4, 4.2, 5.0]): img = bubble_say(img, txt, W * px, H * py, tt, t0, 36 if not LAND else 32)
    return img
def s_prob(t):
    tt = max(0, t - TL['prob'][0]); img = R.bg(t); img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (60, 0, 0, 34)))
    items = ['Noter le numéro', 'Chercher la page', 'Taper le lien']; t0s = [0.3, 1.4, 2.5]
    for i, (s_, t0) in enumerate(zip(items, t0s)):
        a = ease_back((tt - t0) / 0.45)
        if a <= 0: continue
        cx = W * 0.5 if not LAND else W * 0.5; cy = H * ((0.22 + 0.16 * i) if not LAND else (0.27 + 0.17 * i))
        img = R.pill(img, s_, cx, cy, 56 if not LAND else 50, bgc=(30, 32, 40), fg=WHITE, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=54, pady=26)
        if tt > t0 + 0.9:
            k = ease_back((tt - t0 - 0.9) / 0.35); x = cx + (W * 0.30 if not LAND else W * 0.19); img = disc(img, x, cy, 38 * U * clamp(k), RED); img = cross(img, x, cy, 38 * U * clamp(k), (255, 255, 255))
    if tt > 3.9:
        a = ease_back((tt - 3.9) / 0.5); img = R.pill(img, 'Clients perdus en chemin', W / 2, H * (0.78 if not LAND else 0.80), 62 if not LAND else 54, bgc=RED, fg=WHITE, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=48, pady=24)
    return img
def s_idea(t):
    tt = max(0, t - TL['idea'][0]); img = R.bg(t)
    pw = int(W * (0.29 if LAND else 0.62)); ph = int(pw * 1.24); cx = W / 2 if not LAND else W * 0.30; cy = H * (0.57 if not LAND else 0.52)
    k = ease_back(seg(tt, 1.4, 1.9)); fr = 0.21
    img = R.paste(img, poster_qr(pw, ph, 0.97, 0.97, fr, reveal=clamp(seg(tt, 1.4, 2.4)), tile=tt > 1.4), cx, cy, scale=1.0 + 0.02 * math.sin(tt * 3))
    tx = W / 2 if not LAND else W * 0.72
    a = ease_out((tt - 0.1) / 0.4); img = R.text(img, 'Un QR code', tx, H * (0.10 if not LAND else 0.34), 110 if not LAND else 92, col=ACC2, alpha=a, maxw=W * (0.92 if not LAND else 0.46))
    a = ease_out((tt - 0.5) / 0.4); img = R.text(img, 'sur votre affiche', tx, H * (0.185 if not LAND else 0.47), 76 if not LAND else 62, alpha=a, maxw=W * (0.92 if not LAND else 0.46))
    if tt > 1.5:
        px, py, tw, th = tile_center(pw, ph, 0.97, 0.97, fr); gx, gy = cx - pw / 2 + px, cy - ph / 2 + py
        r = seg(tt, 1.5, 2.6)
        if r < 1: img = ring(img, gx, gy, (60 + 220 * r) * U, ACC2, w=6 * U, alpha=1 - r)
        for (sx, sy, off, rr) in R.SPK[:8]:
            aa = math.sin(clamp((tt - 1.7 - off * 0.5) / 0.8) * math.pi)
            if aa > 0: img = R.sparkle(img, gx + (sx - 0.5) * 360 * U, gy + (sy - 0.5) * 360 * U, rr * U * aa, aa)
    return stage(img, t, TL['idea'][0])
def field(d, x0, y0, x1, y1, label, value, caret=False, active=False):
    d.text((x0, y0 - 30 * U), label, font=R.font(26 * U, 'r'), fill=MUT + (255,), anchor='lm')
    d.rounded_rectangle((x0, y0, x1, y1), 18 * U, fill=(13, 14, 16, 255), outline=(ACC if active else (60, 64, 74)) + (255,), width=3)
    d.text((x0 + 22 * U, (y0 + y1) / 2), value + ('|' if caret else ''), font=R.font(34 * U, 'b'), fill=(235, 235, 240, 255), anchor='lm')
def s_create(t):
    tt = max(0, t - TL['create'][0]); img = R.bg(t)
    if LAND: cx0, cy0, cw, ch = W * 0.05, H * 0.17, W * 0.48, H * 0.66
    else: cx0, cy0, cw, ch = W * 0.06, H * 0.05, W * 0.88, H * 0.40
    a = ease_back(tt / 0.5); sc = clamp(a, 0.01, 1.0)
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    mx, my = cx0 + cw / 2, cy0 + ch / 2
    d.rounded_rectangle((mx - cw * sc / 2, my - ch * sc / 2, mx + cw * sc / 2, my + ch * sc / 2), max(1, min(30 * U, cw * sc / 2 - 1, ch * sc / 2 - 1)), fill=(22, 24, 30, 255), outline=(60, 64, 74, 255), width=1 if sc < 0.2 else 3)
    if sc > 0.97:
        pad = 34 * U; x0 = cx0 + pad; x1 = cx0 + cw - pad; y = cy0 + 36 * U
        d.text((x0, y + 8 * U), 'Studio', font=R.font(34 * U), fill=ACC2 + (255,), anchor='lm')
        # 1. photo
        y1 = y + 62 * U; d.text((x0, y1), '1  Votre photo', font=R.font(28 * U, 'b'), fill=WHITE + (255,), anchor='lm')
        if tt > 1.0: img = Image.alpha_composite(img, lay); lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay); kk = ease_back((tt - 0.7) / 0.45); img = R.paste(img, R.fit(AV, int(110 * U), int(110 * U), 16), x1 - 70 * U, y1 + 12 * U, scale=clamp(kk, 0.01, 1.0), shadowed=False)
        if tt > 1.3:
            img = disc(img, x0 + 270 * U, y1, 20 * U * clamp(ease_back((tt - 1.3) / 0.3)), OK); img = check(img, x0 + 270 * U, y1, 20 * U * clamp(ease_back((tt - 1.3) / 0.3)), (0, 40, 12), w=int(5 * U))
        # 2. lien
        y2 = y1 + 150 * U; d = ImageDraw.Draw(lay)
        typed = LINK[:int(len(LINK) * seg(tt, 2.0, 4.6))]
        d.text((x0, y2 - 60 * U), '2  Lien du QR code', font=R.font(28 * U, 'b'), fill=WHITE + (255,), anchor='lm') if tt > 1.7 else None
        if tt > 1.9: field(d, x0, y2, x1, y2 + 74 * U, '', typed, caret=(tt < 5.0 and int(tt * 4) % 2 == 0), active=tt < 5.0)
        if tt > 5.2:
            a2 = ease_out((tt - 5.2) / 0.4); d.text((x0, y2 + 118 * U), 'Texte au-dessus du QR code', font=R.font(26 * U, 'r'), fill=MUT + (int(255 * a2),), anchor='lm')
            d.rounded_rectangle((x0, y2 + 140 * U, x1, y2 + 140 * U + 66 * U), 16 * U, fill=(13, 14, 16, int(255 * a2)), outline=(60, 64, 74, int(255 * a2)), width=2)
            d.text((x0 + 22 * U, y2 + 173 * U), CTA, font=R.font(30 * U, 'b'), fill=(235, 235, 240, int(255 * a2)), anchor='lm')
            d.rounded_rectangle((x1 - 230 * U, y2 + 152 * U, x1 - 14 * U, y2 + 194 * U), 21 * U, fill=ACC + (int(255 * a2),)); d.text((x1 - 122 * U, y2 + 173 * U), 'Auto', font=R.font(26 * U), fill=(255, 255, 255, int(255 * a2)), anchor='mm')
        # 3. bouton
        by = cy0 + ch - 70 * U; tap = tt > 7.0
        d.rounded_rectangle((x0, by - 44 * U, x1, by + 44 * U), 44 * U, fill=(ACC if not tap or tt < 7.6 else (30, 80, 140)) + (255,)); d.text(((x0 + x1) / 2, by), 'Générer ici' if tt < 7.2 else 'Création en cours…' if tt < 8.7 else 'Terminé', font=R.font(34 * U), fill=(255, 255, 255, 255), anchor='mm')
    img = Image.alpha_composite(img, lay)
    if 6.8 < tt < 7.6 and sc > 0.97:
        bx, by = (cx0 + cw / 2), (cy0 + ch - 70 * U); r = (1 - seg(tt, 7.0, 7.5)) * 34 * U + 22 * U; ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ImageDraw.Draw(ov).ellipse((bx - r, by - r, bx + r, by + r), outline=(255, 255, 255, 210), width=5); img = Image.alpha_composite(img, ov)
    # résultat
    if LAND: pw = int(W * 0.30); rx, ry = W * 0.78, H * 0.52
    else: pw = int(W * 0.50); rx, ry = W / 2, H * 0.735
    ph = int(pw * 1.24)
    if 7.2 <= tt < 8.7:
        img = R.pill(img, 'Création en cours…', rx, ry + ph * 0.0, 36, bgc=(30, 32, 40), fg=MUT, padx=28, pady=14) if False else img
        lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ang = (tt * 360 * 1.4) % 360; rr = 56 * U; ImageDraw.Draw(lay).arc((rx - rr, ry - rr, rx + rr, ry + rr), ang, ang + 260, fill=ACC + (255,), width=int(12 * U)); img = Image.alpha_composite(img, lay)
    if tt >= 8.7:
        k = ease_back((tt - 8.7) / 0.55); rev = seg(tt, 9.2, 10.4)
        img = R.paste(img, poster_qr(pw, ph, 0.97, 0.97, 0.21, reveal=rev, tile=tt > 9.2), rx, ry, scale=clamp(k, 0.01, 1.05))
        for (sx, sy, off, rr) in R.SPK:
            aa = math.sin(clamp((tt - 8.9 - off * 0.6) / 0.8) * math.pi)
            if aa > 0: img = R.sparkle(img, rx + (sx - 0.5) * pw * 1.2, ry + (sy - 0.5) * ph * 1.1, rr * U * aa, aa)
    return stage(img, t, TL['create'][0])
def s_scan(t):
    tt = max(0, t - TL['scan'][0]); img = R.bg(t)
    if LAND: pw_ = W * 0.30; ph_ = pw_ * 2.05; px, py = W * 0.70, H * 0.51
    else: pw_ = W * 0.64; ph_ = pw_ * 2.0; px, py = W / 2, H * 0.52
    if ph_ > H * 0.92: ph_ = H * 0.92; pw_ = ph_ / 2.05
    k = ease_back(tt / 0.55); m = 14 * U; sw, sh = pw_ - 2 * m, ph_ - 2 * m
    if tt < 2.9: scr = screen_camera(sw, sh, tt)
    elif tt < 3.2: scr = Image.blend(screen_camera(sw, sh, tt), screen_shop(sw, sh, tt - 2.9), seg(tt, 2.9, 3.2))
    elif tt < 5.2: scr = screen_shop(sw, sh, tt - 2.9)
    elif tt < 5.5: scr = Image.blend(screen_shop(sw, sh, tt - 2.9), screen_chat(sw, sh, tt - 5.2), seg(tt, 5.2, 5.5))
    else: scr = screen_chat(sw, sh, tt - 5.2)
    img = R.paste(img, phone(pw_, ph_, scr), px + (1 - clamp(k)) * W * 0.25, py, scale=clamp(k, 0.01, 1.0))
    labs = ['Il scanne', 'Il arrive chez vous', 'Il commande']; cur = 0 if tt < 2.9 else (1 if tt < 5.2 else 2)
    for i, lb in enumerate(labs):
        a = ease_back((tt - [0.5, 2.9, 5.2][i]) / 0.4)
        if a <= 0: continue
        if LAND: cx, cy = W * 0.26, H * (0.30 + 0.16 * i)
        else: cx, cy = W * (0.20 + 0.30 * i), H * 0.075
        img = R.pill(img, f'{i + 1}  {lb}', cx, cy, 44 if LAND else 34, bgc=(ACC if i == cur else (30, 32, 40)), fg=WHITE, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=34, pady=18)
    return stage(img, t, TL['scan'][0])
def s_ctrl(t):
    tt = max(0, t - TL['ctrl'][0]); img = R.bg(t)
    pw = int(W * (0.34 if LAND else 0.60)); ph = int(pw * 1.24); cx = W * (0.64 if LAND else 0.5); cy = H * (0.50 if LAND else 0.50)
    corners = [(1, 1), (0, 1), (0, 0), (1, 0), (1, 1)]
    # emplacement : bas droite → bas gauche → haut gauche → haut droite → bas droite
    if tt < 1.7: ax, ay = 1, 1
    elif tt < 4.0:
        u = (tt - 1.7) / 2.3 * 4; i = min(3, int(u)); k = ease_io(clamp(u - i)); ax = lerp(corners[i][0], corners[i + 1][0], k); ay = lerp(corners[i][1], corners[i + 1][1], k)
    else: ax, ay = 1, 1
    frac = 0.21 * (1.0 if tt < 4.0 else (lerp(1.0, 1.4, ease_io(seg(tt, 4.0, 4.6))) if tt < 5.0 else lerp(1.4, 0.8, ease_io(seg(tt, 5.0, 5.5)))))
    if tt >= 5.5: frac = lerp(0.8, 0.21, ease_io(seg(tt, 6.2, 6.7))) if tt > 6.2 else 0.8
    cta = CTA if tt < 1.2 else 'Scannez pour réserver'
    vis = 1.0
    if 5.5 <= tt < 6.2: vis = 0.0  # retiré
    P = poster_qr(pw, ph, ax, ay, frac, cta=cta, tile=vis > 0)
    img = R.paste(img, P, cx, cy)
    labels = [('Texte', 0.3), ('Emplacement', 1.8), ('Taille', 4.0), ('Retirer', 5.4)]
    for i, (lb, t0) in enumerate(labels):
        a = ease_back((tt - t0) / 0.4)
        if a <= 0: continue
        if LAND: lx, ly = W * 0.21, H * (0.26 + 0.14 * i)
        else: lx, ly = W * (0.17 + 0.222 * i), H * 0.095
        on = (t0 <= tt < (labels[i + 1][1] if i < 3 else 6.2)); img = R.pill(img, lb, lx, ly, 42 if LAND else 32, bgc=(ACC if on else (30, 32, 40)), fg=WHITE, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=30, pady=16)
    if tt > 6.0:
        a = ease_out((tt - 6.0) / 0.4); img = R.pill(img, 'Gratuit, même après la création', W / 2, H * (0.92 if not LAND else 0.90), 46 if not LAND else 40, bgc=OK, fg=(0, 30, 10), alpha=a, padx=40, pady=18)
    return stage(img, t, TL['ctrl'][0])
def s_trust(t):
    tt = max(0, t - TL['trust'][0]); img = R.bg(t)
    tw = int(W * (0.30 if not LAND else 0.15)); T_ = qr_tile(tw); th = T_.height
    tx, ty = (W / 2, H * 0.34) if not LAND else (W * 0.28, H * 0.50)
    k = ease_back(tt / 0.5); img = R.paste(img, T_, tx, ty, scale=clamp(k, 0.01, 1.04))
    # flèche vers « votre lien »
    bx, by = (W / 2, H * 0.60) if not LAND else (W * 0.72, H * 0.36)
    fr = ease_out(seg(tt, 0.9, 1.9))
    if fr > 0: img = arrow(img, tx + (0 if not LAND else tw * 0.55), ty + (th * 0.58 if not LAND else -th * 0.1), bx - (0 if not LAND else 230 * U), by - (62 * U if not LAND else 0), OK, fr)
    if tt > 1.7:
        a = ease_back((tt - 1.7) / 0.5); img = R.pill(img, f'Votre lien · {LINK}', bx, by, 44 if not LAND else 38, bgc=OK, fg=(0, 30, 10), scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=44, pady=22)
    a = ease_out((tt - 0.2) / 0.4); img = R.text(img, 'Le QR code ouvre uniquement\nvotre lien', W / 2 if not LAND else W * 0.62, H * (0.10 if not LAND else 0.12), 62 if not LAND else 56, alpha=a, maxw=W * (0.92 if not LAND else 0.60))
    if tt > 3.6:
        a = ease_back((tt - 3.6) / 0.5); gx, gy = tx, ty + th * 0.40
        pul = 1 + 0.05 * math.sin(tt * 6); img = ring(img, gx, gy, (tw * 0.42) * pul, ACC2, w=6 * U, alpha=clamp(a))
        cx2, cy2 = (W / 2, H * 0.76) if not LAND else (W * 0.28, H * 0.84)
        img = R.pill(img, 'Sous le code : une simple mention', cx2, cy2, 38 if not LAND else 34, bgc=(30, 32, 40), fg=WHITE, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=36, pady=18)
        img = R.pill(img, 'créé avec slashatlas.com', cx2, cy2 + 90 * U, 34 if not LAND else 30, bgc=(24, 26, 32), fg=ACC2, scale=clamp(a, 0.01, 1.05), alpha=clamp(a, 0, 1), padx=34, pady=16)
    return img
def s_cta(t):
    tt = max(0, t - TL['cta'][0]); img = R.bg(t)
    names = [0.9, 0.8, 0.9]; fr = 0.24
    pw = int(W * (0.17 if LAND else 0.29)); ph = int(pw * 1.24)
    for i in range(3):
        a = ease_back((tt - 0.1 - i * 0.12) / 0.5)
        if a <= 0: continue
        if LAND: px = W * (0.115 + 0.145 * i); py = H * 0.50 + (i % 2) * 40 * U - 20 * U
        else: px = W * (0.20 + 0.30 * i); py = H * 0.72 + (i % 2) * 26 * U
        pos = [(1, 1), (0, 1), (1, 0)][i]
        img = R.paste(img, poster_qr(pw, ph, pos[0], pos[1], fr), px, py, angle=(-6 + 6 * i), scale=clamp(a, 0.01, 1.1))
    tx = W * 0.70 if LAND else W / 2; ty0 = 0.15 if LAND else 0.08
    a = ease_out((tt - 0.3) / 0.4); img = R.text(img, '/SlashAtlas', tx, H * ty0, 92 if not LAND else 78, col=ACC2, alpha=a, maxw=W * (0.9 if not LAND else 0.5))
    a = ease_back((tt - 0.9) / 0.5)
    if a > 0: img = R.pill(img, 'slashatlas.com', tx, H * (ty0 + (0.10 if not LAND else 0.15)), 72 if not LAND else 54, alpha=clamp(a, 0, 1), scale=clamp(a, 0.01, 1.1) * (1 + 0.03 * math.sin(tt * 6)), padx=48, pady=24)
    a = ease_out((tt - 1.6) / 0.4); img = R.text(img, '650 commandes gratuites à copier', tx, H * (ty0 + (0.19 if not LAND else 0.28)), 46 if not LAND else 38, col=WHITE, alpha=a, maxw=W * (0.92 if not LAND else 0.52))
    a = ease_out((tt - 2.4) / 0.4); img = R.text(img, 'Studio « Générer ici » :\nvotre marque, vos contacts, un QR code', tx, H * (ty0 + (0.29 if not LAND else 0.44)), 40 if not LAND else 34, col=MUT, kind='r', alpha=a, maxw=W * (0.92 if not LAND else 0.52))
    a = ease_back((tt - 4.2) / 0.5)
    if a > 0:
        yy = H * (ty0 + (0.42 if not LAND else 0.62)); lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(lay); f = R.font(44 * U if not LAND else 36 * U)
        label = 'Canal WhatsApp SlashAtlas'; wtxt = d.textlength(label, font=f); bw = wtxt + 150 * U; sc_ = clamp(a, 0.01, 1.05)
        x0, x1 = tx - bw / 2 * sc_, tx + bw / 2 * sc_
        d.rounded_rectangle((x0, yy - 52 * U * sc_, x1, yy + 52 * U * sc_), 52 * U * sc_, fill=WA + (int(255 * clamp(a)),))
        d.ellipse((x0 + 20 * U, yy - 34 * U, x0 + 88 * U, yy + 34 * U), fill=(4, 33, 15, int(255 * clamp(a)))); d.text((x0 + 54 * U, yy), 'W', font=R.font(38 * U), fill=WA + (int(255 * clamp(a)),), anchor='mm')
        d.text((x0 + 108 * U, yy), label, font=f, fill=(4, 33, 15, int(255 * clamp(a))), anchor='lm'); img = Image.alpha_composite(img, lay)
        img = R.text(img, 'Des surprises pour les abonnés', tx, yy + 88 * U, 34 if not LAND else 30, col=MUT, kind='r', alpha=clamp(a), maxw=W * 0.9)
    return stage(img, t, TL['cta'][0])
SC = [(0, 6.2, s_hook), (6.2, 11.8, s_prob), (11.8, 15.3, s_idea), (15.3, 25.9, s_create), (25.9, 32.9, s_scan), (32.9, 39.9, s_ctrl), (39.9, 47.3, s_trust), (47.3, 999, s_cta)]
TR = 0.45  # fondu enchaîné entre deux scènes
def frame(t, limit):
    for i, (a_, b_, fn) in enumerate(SC):
        if a_ <= t < b_: break
    img = fn(t)
    if b_ < 900 and t > b_ - TR and i + 1 < len(SC):
        k = ease_io((t - (b_ - TR)) / TR); nxt = SC[i + 1][2](t)
        img = Image.blend(img, nxt, k)
    if t < 0.4: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * (1 - t / 0.4)))))
    if t > limit - 0.6: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * clamp((t - (limit - 0.6)) / 0.6)))))
    return img.convert('RGB')
if __name__ == '__main__':
    OUT = sys.argv[3]; LIMIT = float(sys.argv[5]); MIX = sys.argv[6]
    if len(sys.argv) > 7 and sys.argv[7] == 'test':
        import os; os.makedirs('test', exist_ok=True)
        for tt in [float(x) for x in sys.argv[8].split(',')]: frame(tt, LIMIT).save(f'test/v4_{W}x{H}_{tt}.png')
        sys.exit(0)
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-i', MIX, '-t', str(LIMIT),
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for i in range(int(LIMIT * FPS)): p.stdin.write(frame(i / FPS, LIMIT).tobytes())
    p.stdin.close(); p.wait(); print('fini', OUT)
