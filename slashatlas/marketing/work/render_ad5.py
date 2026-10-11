# Tutoriel vidéo Afrolook n° 5 : créer une carte Afrolook (à partir d'un post, ou de zéro), français, ~1 min 25.
# Usage : python3 render_ad5.py <largeur> <hauteur> <sortie.mp4> fr <secondes> <mix.wav>   |   … test <t1,t2,…>
# Les cartes montrées sont les vraies cartes d'exemple du site (site/static/img/card-*.webp) ; les écrans de l'application sont redessinés.
import sys, math, subprocess
import numpy as np
import render_ad2 as R
from PIL import Image, ImageDraw, ImageFilter
import imageio_ffmpeg
W, H, U, LAND = R.W, R.H, R.U, R.LAND
GREEN = (46, 204, 113); YEL = (255, 225, 77); WHITE = R.WHITE; MUT = (154, 154, 149)
DARK = (14, 14, 14); SURF = (26, 26, 26); SURF2 = (36, 36, 36); BORD = (47, 47, 47); BLUE = (91, 156, 250); RED = (255, 107, 111); ORANGE = (255, 146, 72)
clamp, ease_out, ease_io, ease_back = R.clamp, R.ease_out, R.ease_io, R.ease_back
FPS = 30
def lerp(a, b, k): return a + (b - a) * k
def seg(tt, a, b): return clamp((tt - a) / (b - a))
SITE = '/home/user/afrolook/site/static/img/'
ASSET = '/home/user/afrolook/assets/'
_c = {}
def card(n):
    if n not in _c: _c[n] = Image.open(f'{SITE}card-{n}.webp').convert('RGB')
    return _c[n]
_p = {}
def photo(n):
    if n not in _p: _p[n] = Image.open(f'{ASSET}images/{n}.jpg').convert('RGB')
    return _p[n]
LOGO = Image.open(ASSET + 'logo/afrolook_logo.png').convert('RGBA')
# ---------- minuterie ----------
TL = dict(hook=(0, 6.2), styles=(6.2, 14.6), t1=(14.6, 17.4), post=(17.4, 28.0), studio=(28.0, 36.0), share=(36.0, 43.0), t2=(43.0, 46.2), create=(46.2, 60.0), ex=(60.0, 68.2), upd=(68.2, 76.0), cta=(76.0, 99))
# ---------- fond ----------
_bg = None
def bg(t):
    global _bg
    if _bg is None:
        a = np.linspace(0, 1, H)[:, None, None]; g = np.array((10, 14, 11))[None, None, :] * (1 - a) + np.array((0, 0, 0))[None, None, :] * a
        _bg = Image.fromarray(np.broadcast_to(g, (H, W, 3)).astype(np.uint8)).convert('RGBA')
    img = _bg.copy(); ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    cx = W * (0.5 + 0.12 * math.sin(t * 0.6)); cy = H * (0.42 + 0.06 * math.cos(t * 0.45)); r = max(W, H) * 0.55
    for i in range(14, 0, -1):
        rr = r * i / 14; d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=GREEN + (max(1, int(34 * (1 - i / 14) ** 1.8)),))
    return Image.alpha_composite(img, ov)
def txt(img, s, x, y, sz, col=WHITE, kind='b', anchor='mm', alpha=1.0, maxw=None, shadow_=True):
    return R.text(img, s, x, y, sz, col=col, kind=kind, anchor=anchor, alpha=alpha, maxw=maxw, shadow_=shadow_)
def pill(img, s, cx, cy, sz, bgc=GREEN, fg=(6, 30, 14), a=1.0, sc=1.0, padx=40, pady=18):
    return R.pill(img, s, cx, cy, sz, bgc=bgc, fg=fg, alpha=clamp(a, 0, 1), scale=clamp(sc, 0.01, 1.08), padx=padx, pady=pady)
def pop_in(tt, t0, d=0.45): return ease_back((tt - t0) / d)
def arrow_r(img, cx, cy, size, col=GREEN, alpha=1.0):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay); w = int(size * 0.16); a = int(255 * clamp(alpha))
    d.line([(cx - size * 0.5, cy), (cx + size * 0.45, cy)], fill=col + (a,), width=w)
    d.line([(cx + size * 0.1, cy - size * 0.38), (cx + size * 0.5, cy), (cx + size * 0.1, cy + size * 0.38)], fill=col + (a,), width=w, joint='curve')
    return Image.alpha_composite(img, lay)
# ---------- écran de téléphone dessiné à l'échelle 390 × 844 ----------
class Scr:
    def __init__(self, k=2.0, bgc=DARK):
        self.k = k; self.w = int(390 * k); self.h = int(844 * k); self.im = Image.new('RGBA', (self.w, self.h), bgc + (255,)); self.d = ImageDraw.Draw(self.im)
    def rr(self, x0, y0, x1, y1, r, fill=None, outline=None, width=1):
        k = self.k; self.d.rounded_rectangle((x0 * k, y0 * k, x1 * k, y1 * k), max(1, r * k), fill=(fill + (255,)) if fill else None, outline=(outline + (255,)) if outline else None, width=int(width * k))
    def t(self, x, y, s, size=14, col=WHITE, kind='b', anchor='lm'):
        self.d.text((x * self.k, y * self.k), s, font=R.font(size * self.k, kind), fill=col + (255,), anchor=anchor)
    def tw(self, s, size=14, kind='b'): return self.d.textlength(s, font=R.font(size * self.k, kind)) / self.k
    def circ(self, cx, cy, r, fill=None, outline=None, width=1):
        k = self.k; self.d.ellipse(((cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k), fill=(fill + (255,)) if fill else None, outline=(outline + (255,)) if outline else None, width=int(width * k))
    def line(self, pts, col=WHITE, width=2):
        k = self.k; self.d.line([(x * k, y * k) for x, y in pts], fill=col + (255,), width=int(width * k), joint='curve')
    def poly(self, pts, fill):
        k = self.k; self.d.polygon([(x * k, y * k) for x, y in pts], fill=fill + (255,))
    def pic(self, im, x, y, w, h, r=10):
        k = self.k; self.im.alpha_composite(R.fit(im, int(w * k), int(h * k), r / U if U else r), (int(x * k), int(y * k)))
    def overlay(self, a):
        self.im = Image.alpha_composite(self.im, Image.new('RGBA', self.im.size, (0, 0, 0, int(255 * a)))); self.d = ImageDraw.Draw(self.im)
    def sheet_from(self, im, y):
        self.im.alpha_composite(im, (0, int(y * self.k))); self.d = ImageDraw.Draw(self.im)
# icônes
def ic_sparkle(s, cx, cy, r, col):
    s.poly([(cx, cy - r), (cx + r * .22, cy - r * .22), (cx + r, cy), (cx + r * .22, cy + r * .22), (cx, cy + r), (cx - r * .22, cy + r * .22), (cx - r, cy), (cx - r * .22, cy - r * .22)], col)
    s.poly([(cx + r * .7, cy - r * .9), (cx + r * .8, cy - r * .6), (cx + r * 1.1, cy - r * .5), (cx + r * .8, cy - r * .4), (cx + r * .7, cy - r * .1), (cx + r * .6, cy - r * .4), (cx + r * .3, cy - r * .5), (cx + r * .6, cy - r * .6)], col)
def ic_dots(s, cx, cy, col, r=2.2):
    for i in (-7, 0, 7): s.circ(cx + i, cy, r, fill=col)
def ic_heart(s, cx, cy, r, col):
    s.circ(cx - r * .5, cy - r * .25, r * .55, outline=col, width=1.6); s.circ(cx + r * .5, cy - r * .25, r * .55, outline=col, width=1.6)
    s.line([(cx - r, cy), (cx, cy + r * 1.05), (cx + r, cy)], col, 1.6)
def ic_comment(s, cx, cy, r, col):
    s.rr(cx - r, cy - r * .8, cx + r, cy + r * .6, r * .5, outline=col, width=1.6); s.poly([(cx - r * .3, cy + r * .5), (cx - r * .8, cy + r * 1.1), (cx + r * .1, cy + r * .5)], col)
def ic_plus(s, cx, cy, r, col, w=2.4):
    s.line([(cx - r, cy), (cx + r, cy)], col, w); s.line([(cx, cy - r), (cx, cy + r)], col, w)
def ic_x(s, cx, cy, r, col, w=2):
    s.line([(cx - r, cy - r), (cx + r, cy + r)], col, w); s.line([(cx - r, cy + r), (cx + r, cy - r)], col, w)
def ic_check(s, cx, cy, r, col, w=2.4):
    s.line([(cx - r, cy), (cx - r * .3, cy + r * .75), (cx + r, cy - r * .7)], col, w)
def ic_back(s, cx, cy, r, col):
    s.line([(cx + r * .5, cy - r), (cx - r * .5, cy), (cx + r * .5, cy + r)], col, 2.2)
def gradient_circle(s, cx, cy, r):
    k = s.k; n = int(r * 2 * k); g = Image.new('RGBA', (n, n)); gd = ImageDraw.Draw(g)
    for i in range(n): gd.line([(0, i), (n, i)], fill=(int(lerp(GREEN[0], YEL[0], i / n)), int(lerp(GREEN[1], YEL[1], i / n)), int(lerp(GREEN[2], YEL[2], i / n)), 255))
    m = Image.new('L', (n, n), 0); ImageDraw.Draw(m).ellipse((0, 0, n - 1, n - 1), fill=255); g.putalpha(m); s.im.alpha_composite(g, (int((cx - r) * k), int((cy - r) * k)))
def circle_avatar(s, im, cx, cy, r):
    k = s.k; n = int(r * 2 * k); a = R.fit(im, n, n, 0).convert('RGBA'); m = Image.new('L', (n, n), 0); ImageDraw.Draw(m).ellipse((0, 0, n - 1, n - 1), fill=255); a.putalpha(m); s.im.alpha_composite(a, (int((cx - r) * k), int((cy - r) * k)))
# ---------- les écrans ----------
POST_DOTS = (362, 126); POST_PHOTO = (195, 280); NAV_PLUS = (240, 805)
def nav(s, pulse=0.0, plus_hl=False):
    s.rr(0, 756, 390, 844, 0, fill=SURF); s.line([(0, 756), (390, 756)], BORD, 1)
    items = [('Invitations', 39), ('Messages', 117), ('Business', 195), ('Créer', 273), ('Vidéos', 351)]
    for i, (lb, x) in enumerate(items):
        if lb == 'Créer':
            if pulse: s.circ(x, 790, 20 + 6 * pulse, fill=None, outline=GREEN, width=2)
            gradient_circle(s, x, 790, 15); ic_plus(s, x, 790, 7, (14, 14, 14), 2.6)
        else:
            s.circ(x, 786, 9, outline=MUT, width=1.6) if i != 1 else ic_comment(s, x, 786, 8, MUT)
        s.t(x, 822, lb, 9.5, MUT if lb != 'Créer' else WHITE, 'r', 'mm')
def feed(menu=0.0, ring=None, hl=False, old=False, quick=False, plus_pulse=0.0, dim=0.0):
    s = Scr()
    # barre du haut
    s.line([(18, 34), (38, 34)], WHITE, 2); s.line([(18, 41), (38, 41)], WHITE, 2); s.line([(18, 48), (30, 48)], WHITE, 2)
    s.t(58, 41, 'Afrolook', 21, GREEN, 'b')
    s.circ(272, 41, 9, outline=WHITE, width=1.8); s.circ(268, 41, 0.1, fill=WHITE); s.circ(298, 39, 8, outline=WHITE, width=1.8); s.line([(304, 45), (311, 51)], WHITE, 2); s.circ(340, 41, 3, fill=YEL); s.circ(272, 41, 1, fill=WHITE)
    s.rr(16, 66, 94, 94, 14, fill=SURF2, outline=BORD); s.circ(32, 80, 3, fill=MUT); s.t(42, 80, 'Tendance', 12, WHITE, 'r')
    # post
    circle_avatar(s, photo('intro3'), 38, 126, 20)
    s.t(68, 118, '@aminata_k', 15, WHITE, 'b'); s.circ(s.tw('@aminata_k', 15) + 68 + 12, 118, 7, fill=BLUE); s.line([(s.tw('@aminata_k', 15) + 68 + 9, 118), (s.tw('@aminata_k', 15) + 68 + 11, 121), (s.tw('@aminata_k', 15) + 68 + 15, 114)], WHITE, 1.4)
    s.t(68, 136, '3,4 k abonnés', 11, MUT, 'r')
    ic_dots(s, POST_DOTS[0], POST_DOTS[1], WHITE if ring != 'dots' else GREEN)
    s.t(18, 172, 'Coucher de soleil sur la corniche de Dakar,', 14, WHITE, 'r'); s.t(18, 192, 'ma plus belle séance photo de la semaine.', 14, WHITE, 'r')
    s.pic(photo('intro1'), 16, 212, 358, 358, 14)
    ic_comment(s, 32, 604, 9, MUT); s.t(48, 604, '214', 12, MUT, 'r'); ic_heart(s, 112, 602, 8, MUT); s.t(128, 604, '1,2 k', 12, MUT, 'r')
    s.rr(18, 632, 150, 660, 14, fill=SURF2); s.t(30, 646, 'Magnifique !', 12, MUT, 'r')
    s.rr(16, 676, 374, 780, 14, fill=SURF)
    nav(s, plus_pulse)
    if dim: s.overlay(dim)
    if ring == 'post' or ring == 'dots' or ring == 'tile':
        pass
    return s
def menu_items(old=False, quick=False):
    items = []
    if not old: items.append(('card', 'Créer une carte Afrolook', GREEN))
    if not quick:
        items += [('rocket', 'Booster ce post', ORANGE), ('flag', 'Signaler', WHITE), ('block', 'Bloquer cet utilisateur', WHITE)]
    items.append(('cancel', 'Annuler', MUT))
    return items
def sheet(s, prog, hl=False, old=False, quick=False, badge=True):
    items = menu_items(old, quick); h = 24 + 56 * len(items) + 24; y0 = 844 - h * ease_out(prog)
    s.overlay(0.62 * ease_out(prog))
    s.rr(0, y0, 390, 844 + 20, 20, fill=SURF); s.rr(165, y0 + 8, 225, y0 + 12, 2, fill=BORD)
    for i, (ic, lb, col) in enumerate(items):
        y = y0 + 24 + 56 * i + 28
        if i == 0 and hl and ic == 'card': s.rr(10, y - 26, 380, y + 26, 12, fill=(24, 60, 40))
        x = 36
        if ic == 'card': ic_sparkle(s, x, y, 9, GREEN)
        elif ic == 'rocket': s.poly([(x - 6, y + 7), (x + 8, y - 8), (x + 4, y + 6)], col)
        elif ic == 'flag': s.line([(x - 6, y - 9), (x - 6, y + 9)], col, 2); s.poly([(x - 6, y - 9), (x + 8, y - 5), (x - 6, y)], col)
        elif ic == 'block': s.circ(x, y, 9, outline=col, width=2); s.line([(x - 6, y + 6), (x + 6, y - 6)], col, 2)
        else: s.circ(x, y, 9, outline=col, width=2); ic_x(s, x, y, 4, col, 1.8)
        s.t(64, y, lb, 16, WHITE if ic != 'cancel' else MUT, 'r')
        if ic == 'card' and badge:
            tx = 64 + s.tw(lb, 16, 'r') + 10; s.rr(tx, y - 9, tx + 62, y + 9, 5, fill=YEL); s.t(tx + 31, y, 'NOUVEAU', 9.5, (31, 31, 31), 'b', 'mm')
STYLE_PACKS = [('Héritage', ['kente', 'wax', 'bogolan']), ('Moderne', ['neon', 'glass', 'pro', 'manga', 'anime', 'collector']), ('Drapeaux', ['flag', 'passport', 'stamp', 'supporter']), ('Idées', ['film', 'newspaper', 'music', 'quote'])]
STYLE_NAMES = {'kente': 'Kenté', 'wax': 'Wax', 'bogolan': 'Bogolan', 'neon': 'Néon', 'glass': 'Glass', 'pro': 'Pro', 'manga': 'Manga', 'anime': 'Anime', 'collector': 'Collector', 'flag': 'Drapeau', 'passport': 'Passeport', 'stamp': 'Timbre', 'supporter': 'Supporter', 'film': 'Film', 'newspaper': 'Journal', 'music': 'Musique', 'quote': 'Citation', 'story_neon': 'Story'}
def studio(sel='neon', pack=1, fmt='Portrait', hl=None, tapped=None, text=None, thumbs=0, compose=False, bar_hl=None, prev=None, fade=1.0):
    s = Scr()
    ic_back(s, 24, 34, 8, WHITE); s.t(50, 34, 'Carte Afrolook', 18, WHITE, 'b'); s.circ(356, 34, 11, outline=MUT, width=1.6); s.t(356, 34, '?', 13, MUT, 'b', 'mm')
    pw, ph = (240, 300) if sel != 'story_neon' else (172, 306)
    if fmt == 'Carré': pw, ph = 280, 280
    x = 195 - pw / 2; y = 56 + (330 - ph) / 2 + 8
    if prev and fade < 1: s.pic(card(prev[0]), 195 - prev[1] / 2, 56 + (330 - prev[2]) / 2 + 8, prev[1], prev[2], 16)
    cim = card(sel).copy()
    if fade < 1: cim.putalpha(int(255 * fade))
    s.im.alpha_composite(R.fit(card(sel), int(pw * s.k), int(ph * s.k), 16 / U), (int(x * s.k), int(y * s.k))) if fade >= 1 else None
    if fade < 1:
        base = R.fit(card(sel), int(pw * s.k), int(ph * s.k), 16 / U); a = base.getchannel('A').point(lambda v: int(v * fade)); base.putalpha(a); s.im.alpha_composite(base, (int(x * s.k), int(y * s.k)))
    # familles de styles
    ty = 396; xs = 16
    for i, (nm, _) in enumerate(STYLE_PACKS):
        wv = s.tw(nm, 13) + 22; on = (i == pack)
        s.rr(xs, ty - 15, xs + wv, ty + 15, 15, fill=GREEN if on else SURF2); s.t(xs + wv / 2, ty, nm, 13, (6, 30, 14) if on else WHITE, 'b', 'mm'); xs += wv + 8
    # vignettes
    names = STYLE_PACKS[pack][1]
    for i, n in enumerate(names[:5]):
        cx0 = 16 + i * 72; on = n == sel
        s.rr(cx0 - 3, 424 - 3, cx0 + 56 + 3, 424 + 70 + 3, 10, outline=GREEN if on else None, width=2)
        s.pic(card(n), cx0, 424, 56, 70, 8); s.t(cx0 + 28, 508, STYLE_NAMES[n], 10, WHITE if on else MUT, 'r', 'mm')
    # format et pays
    s.t(16, 540, 'Format', 12, MUT, 'r')
    for i, f in enumerate(['Portrait', 'Carré', 'Story']):
        fx = 76 + i * 100; on = f == fmt
        s.rr(fx, 526, fx + 90, 554, 14, fill=GREEN if on else SURF2); s.t(fx + 45, 540, f, 12.5, (6, 30, 14) if on else WHITE, 'b', 'mm')
    s.t(16, 580, 'Pays', 12, MUT, 'r'); s.rr(76, 566, 196, 594, 14, fill=SURF2); s.t(136, 580, 'Togo' if sel != 'passport' else 'Sénégal', 12.5, WHITE, 'b', 'mm')
    if hl == 'country': s.rr(70, 560, 202, 600, 18, outline=YEL, width=2)
    if hl == 'format': s.rr(70, 520, 380, 560, 18, outline=YEL, width=2)
    if hl == 'style': s.rr(10, 380, 380, 516, 14, outline=YEL, width=2)
    # texte et images
    s.t(16, 618, 'Le texte de ta carte', 12, MUT, 'r'); s.rr(16, 630, 374, 690, 12, fill=SURF2, outline=BORD)
    shown = text if text is not None else 'Coucher de soleil sur la corniche de Dakar, ma plus belle séance photo de la semaine.'
    for i, ln in enumerate(wrap(s, shown, 12.5, 340)[:3]): s.t(26, 648 + i * 18, ln, 12.5, WHITE, 'r')
    s.t(16, 708, 'Images (4 au maximum)', 12, MUT, 'r')
    for i in range(4):
        px = 16 + i * 62
        if i < thumbs: s.pic(photo(['intro1', 'intro2', 'intro3', 'intro6'][i]), px, 718, 54, 54, 10)
        else: s.rr(px, 718, px + 54, 772, 10, outline=BORD, width=1.5); ic_plus(s, px + 27, 745, 8, MUT, 1.8)
    if hl == 'images': s.rr(10, 700, 270, 778, 14, outline=YEL, width=2)
    # barre d'action
    s.rr(0, 780, 390, 844, 0, fill=SURF); s.line([(0, 780), (390, 780)], BORD, 1)
    for i, (lb, pri) in enumerate([('Enregistrer', False), ('Partager', False), ('Publier', True)]):
        bx = 16 + i * 120; on = (bar_hl == lb)
        s.rr(bx, 794, bx + 112, 832, 19, fill=GREEN if pri else SURF2, outline=YEL if on else None, width=2.2); s.t(bx + 56, 813, lb, 13.5, (6, 30, 14) if pri else WHITE, 'b', 'mm')
    return s
def wrap(s, text, size, maxw):
    out, cur = [], ''
    for w_ in text.split(' '):
        t_ = (cur + ' ' + w_).strip()
        if s.tw(t_, size, 'r') <= maxw: cur = t_
        else: out.append(cur); cur = w_
    if cur: out.append(cur)
    return out
def create_page(tab='Image', btn_hl=None, link_hl=False, chips_hl=False):
    s = Scr()
    ic_back(s, 24, 34, 8, WHITE); s.t(50, 34, 'Créer un post', 18, WHITE, 'b')
    xs = 16
    for lb in ['Audio', 'Texte', 'Image', 'Vidéo', 'Carte']:
        wv = s.tw(lb, 13) + 30; on = lb == tab
        s.rr(xs, 62, xs + wv, 96, 17, fill=GREEN if on else SURF2); s.t(xs + wv / 2, 79, lb, 13, (6, 30, 14) if on else WHITE, 'b', 'mm'); xs += wv + 7
    if tab == 'Carte':
        s.im.alpha_composite(R.fit(card('wax'), int(130 * s.k), int(162 * s.k), 14 / U).rotate(4, expand=True, resample=Image.BICUBIC), (int(70 * s.k), int(120 * s.k)))
        s.im.alpha_composite(R.fit(card('neon'), int(130 * s.k), int(162 * s.k), 14 / U).rotate(-4, expand=True, resample=Image.BICUBIC), (int(190 * s.k), int(118 * s.k)))
        s.t(195, 320, 'Crée une carte Afrolook', 19, WHITE, 'b', 'mm')
        for i, ln in enumerate(['Écris ton texte, ajoute jusqu\'à 4 images, choisis un', 'style africain unique et publie directement ta carte.', 'Aucune image n\'est coupée.']): s.t(195, 348 + i * 18, ln, 12, MUT, 'r', 'mm')
        s.rr(20, 416, 370, 462, 23, fill=GREEN, outline=YEL if btn_hl else None, width=2.5); ic_sparkle(s, 112, 439, 8, (6, 30, 14)); s.t(210, 439, 'Créer ma carte', 15, (6, 30, 14), 'b', 'mm')
        s.rr(20, 472, 370, 514, 21, outline=YEL if link_hl else BORD, width=2.2 if link_hl else 1.6); s.t(195, 493, 'Carte à partir d\'un lien', 14, WHITE, 'b', 'mm')
        s.t(20, 544, 'Ou commence par un modèle', 14, WHITE, 'b')
        xs, ys = 20, 576
        for lb in ['Événement', 'Promo', 'Annonce', 'Citation', 'Carte de visite', 'Anniversaire', 'Mariage', 'Félicitations', 'Condoléances']:
            wv = s.tw(lb, 12) + 34
            if xs + wv > 372: xs = 20; ys += 40
            s.rr(xs, ys - 15, xs + wv, ys + 15, 15, fill=SURF2, outline=YEL if chips_hl else BORD, width=2 if chips_hl else 1); s.circ(xs + 14, ys, 4.5, fill=GREEN); s.t(xs + 25, ys, lb, 12, WHITE, 'b'); xs += wv + 8
        s.poly([(118, 714), (118, 730), (131, 722)], GREEN); s.t(140, 722, 'Voir comment ça marche', 13, GREEN, 'b', 'lm')
    else:
        s.rr(16, 130, 374, 470, 14, fill=SURF); s.t(195, 300, 'Ajouter des photos', 15, MUT, 'r', 'mm')
    return s
def share_sheet(s, prog):
    y0 = 844 - 270 * ease_out(prog); s.overlay(0.55 * ease_out(prog)); s.rr(0, y0, 390, 880, 20, fill=SURF); s.rr(165, y0 + 8, 225, y0 + 12, 2, fill=BORD)
    s.t(195, y0 + 40, 'Partager', 16, WHITE, 'b', 'mm')
    for i, (lb, col, ch) in enumerate([('WhatsApp', (37, 211, 102), 'W'), ('Instagram', (214, 62, 130), 'I'), ('TikTok', (30, 30, 36), 'T'), ('Plus', (60, 60, 66), '+')]):
        cx = 52 + i * 95; s.circ(cx, y0 + 110, 30, fill=col, outline=BORD if lb == 'TikTok' else None, width=1.2); s.t(cx, y0 + 110, ch, 22, WHITE, 'b', 'mm'); s.t(cx, y0 + 158, lb, 11.5, MUT, 'r', 'mm')
    s.t(195, y0 + 210, 'Ta carte, prête à envoyer', 12, MUT, 'r', 'mm')
def publish_sheet(s, prog, hl=0):
    y0 = 844 - 330 * ease_out(prog); s.overlay(0.55 * ease_out(prog)); s.rr(0, y0, 390, 880, 20, fill=SURF); s.rr(165, y0 + 8, 225, y0 + 12, 2, fill=BORD)
    s.t(195, y0 + 40, 'Où publier ta carte ?', 17, WHITE, 'b', 'mm')
    for i, (a, b) in enumerate([('Publier en Chronique', 'Format Story · visible 24 h'), ('Publier en post', 'Sur ton profil, avec légende')]):
        yy = y0 + 70 + i * 100; s.rr(16, yy, 374, yy + 86, 16, fill=(24, 60, 40) if hl == i + 1 else SURF2, outline=GREEN if hl == i + 1 else BORD, width=1.6)
        ic_sparkle(s, 48, yy + 43, 10, GREEN); s.t(76, yy + 32, a, 16, WHITE, 'b'); s.t(76, yy + 56, b, 12, MUT, 'r')
def toast(s, prog, msg):
    if prog <= 0: return
    y = 700 - 8 * (1 - ease_out(prog)); s.rr(20, y, 370, y + 50, 25, fill=(235, 235, 235)); s.circ(46, y + 25, 12, fill=GREEN); ic_check(s, 46, y + 25, 5, WHITE, 2.4); s.t(68, y + 25, msg, 12.5, (20, 20, 20), 'b')
# ---------- téléphone dans la scène ----------
def geom():
    if LAND: ph = H * 0.90; pw = ph / 2.1; return pw, ph, W * 0.70, H * 0.5
    pw = W * 0.64; ph = pw * 2.1
    if ph > H * 0.80: ph = H * 0.80; pw = ph / 2.1
    return pw, ph, W / 2, H * 0.535
def draw_phone(img, scr, k=1.0, dx=0.0):
    pw, ph, cx, cy = geom(); pw_, ph_ = int(pw), int(ph); m = int(12 * U); body = Image.new('RGBA', (pw_, ph_), (0, 0, 0, 0)); d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, pw_ - 1, ph_ - 1), pw_ * 0.12, fill=(16, 18, 20, 255), outline=(78, 82, 86, 255), width=3)
    sw, sh = pw_ - 2 * m, ph_ - 2 * m; sc = scr.im.resize((sw, sh), Image.LANCZOS); mk = Image.new('L', (sw, sh), 0); ImageDraw.Draw(mk).rounded_rectangle((0, 0, sw - 1, sh - 1), pw_ * 0.10, fill=255); sc.putalpha(mk); body.alpha_composite(sc, (m, m))
    d.rounded_rectangle((pw_ / 2 - pw_ * 0.12, m + 6 * U, pw_ / 2 + pw_ * 0.12, m + 6 * U + 22 * U), 11 * U, fill=(16, 18, 20, 255))
    return R.paste(img, body, cx + dx, cy, scale=clamp(k, 0.01, 1.05))
def to_screen(lx, ly):
    pw, ph, cx, cy = geom(); m = 12 * U; sw, sh = pw - 2 * m, ph - 2 * m
    return cx - pw / 2 + m + lx / 390 * sw, cy - ph / 2 + m + ly / 844 * sh
def finger(img, lx, ly, ph0, ph1, tt):
    """Pastille de toucher : apparaît puis s'élargit (ph0 → ph1)."""
    if not (ph0 - 0.25 < tt < ph1 + 0.35): return img
    x, y = to_screen(lx, ly); a = ease_out((tt - (ph0 - 0.25)) / 0.25) * (1 - seg(tt, ph1, ph1 + 0.35)); r = (34 + 40 * seg(tt, ph0, ph1)) * U
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(ov); d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, int(70 * a)), outline=(255, 255, 255, int(220 * a)), width=int(4 * U)); d.ellipse((x - 14 * U, y - 14 * U, x + 14 * U, y + 14 * U), fill=(255, 255, 255, int(200 * a)))
    return Image.alpha_composite(img, ov)
def caption(img, s_, tt, t0, slot=0, col=GREEN, fg=(6, 30, 14), sz=50):
    a = pop_in(tt, t0)
    if a <= 0: return img
    if LAND: cx, cy = W * 0.28, H * (0.30 + 0.15 * slot)
    else: cx, cy = W / 2, H * (0.075 + 0.0 * slot)
    return pill(img, s_, cx, cy, sz if not LAND else sz - 8, bgc=col, fg=fg, a=a, sc=a, padx=40, pady=18)
def title_block(img, big, small, tt, t0=0.1):
    a = ease_out((tt - t0) / 0.45)
    if LAND: return txt(img, small, W * 0.28, H * 0.50, 56, alpha=a, maxw=W * 0.42)
    return txt(img, small, W / 2, H * 0.50, 78, alpha=a, maxw=W * 0.9)
def badge_ai(img, t, t0):
    return img
# ---------- scènes ----------
def s_hook(t):
    tt = max(0, t); img = bg(t)
    a = ease_out((tt - 0.15) / 0.5)
    lw = int(150 * U * (1 if not LAND else 0.8)); lg = LOGO.resize((lw, lw), Image.LANCZOS)
    tx = W / 2 if not LAND else W * 0.27
    img = R.paste(img, lg, tx, H * (0.11 if not LAND else 0.20), alpha=a, shadowed=False)
    img = txt(img, 'Créer une carte', tx, H * (0.215 if not LAND else 0.38), 92 if not LAND else 76, alpha=ease_out((tt - 0.5) / 0.5), maxw=W * (0.9 if not LAND else 0.46))
    img = txt(img, 'Afrolook', tx, H * (0.285 if not LAND else 0.52), 120 if not LAND else 96, col=GREEN, alpha=ease_out((tt - 0.7) / 0.5), maxw=W * (0.9 if not LAND else 0.46))
    k = pop_in(tt, 1.3); img = pill(img, 'NOUVEAU', tx, H * (0.35 if not LAND else 0.64), 54 if not LAND else 44, bgc=YEL, fg=(31, 31, 31), a=k, sc=k * (1 + 0.04 * math.sin(tt * 6)))
    names = ['kente', 'neon', 'manga', 'passport', 'film']
    for i, n in enumerate(names):
        k = pop_in(tt, 0.9 + i * 0.28, 0.55)
        if k <= 0: continue
        cw = int(W * (0.36 if not LAND else 0.15)); chh = int(cw * 1.25)
        if LAND: px = W * (0.61 + 0.085 * i); py = H * 0.5 + (abs(i - 2) * 26 - 30) * U
        else: px = W * (0.18 + 0.16 * i); py = H * 0.66 + abs(i - 2) * 30 * U
        img = R.paste(img, R.fit(card(n), cw, chh, 22), px, py + math.sin(tt * 1.6 + i) * 8 * U, angle=(i - 2) * 7, scale=clamp(k, 0.01, 1.06))
    return img
def s_styles(t):
    tt = max(0, t - TL['styles'][0]); img = bg(t)
    allc = ['kente', 'wax', 'neon', 'bogolan', 'glass', 'pro', 'manga', 'anime', 'collector', 'sport', 'gamer', 'y2k', 'street', 'flag', 'passport', 'stamp', 'supporter', 'duo', 'pride', 'film', 'newspaper', 'music', 'boarding', 'tarot', 'quote', 'magazine']
    rows = 2; ch = int(H * (0.25 if LAND else 0.22)); cw = int(ch * 0.8); gap = int(22 * U)
    for r in range(rows):
        items = allc[r::rows]; n = len(items); length = n * (cw + gap)
        strip = Image.new('RGBA', (length * 2, ch), (0, 0, 0, 0))
        for rep in range(2):
            for i, nm in enumerate(items): strip.alpha_composite(R.fit(card(nm), cw, ch, 20), (rep * length + i * (cw + gap), 0))
        off = (tt * (170 if r == 0 else -170) * U + r * 400 * U) % length
        x = int(off) if r == 1 else int(length - off) % length
        y = H * (0.22 if LAND else 0.26) + r * (ch + 26 * U)
        crop = strip.crop((x, 0, x + W, ch)); a = ease_out((tt - 0.2 - 0.2 * r) / 0.6)
        if a < 1: crop.putalpha(crop.getchannel('A').point(lambda v: int(v * a)))
        img.alpha_composite(crop, (0, int(y)))
    img = txt(img, '26 styles', W * (0.5 if not LAND else 0.5), H * (0.075 if not LAND else 0.10), 100 if not LAND else 84, col=GREEN, alpha=ease_out((tt - 4.2) / 0.5) if False else 1.0)
    chips = [('Wax', 0.6), ('Kenté', 1.2), ('Manga', 2.0), ('Passeport', 2.7), ('Film', 3.9)]
    for i, (lb, t0) in enumerate(chips):
        a = pop_in(tt, t0)
        if a <= 0: continue
        cx = W * (0.14 + 0.18 * i) if not LAND else W * (0.20 + 0.15 * i); cy = H * (0.835 if not LAND else 0.84)
        img = pill(img, lb, cx, cy, 40 if not LAND else 34, bgc=(30, 34, 32), fg=WHITE, a=a, sc=a, padx=30, pady=15)
    a = pop_in(tt, 5.6)
    if a > 0: img = pill(img, 'Aucune image coupée', W / 2, H * (0.925 if not LAND else 0.93), 48 if not LAND else 40, bgc=GREEN, fg=(6, 30, 14), a=a, sc=a, padx=44, pady=20)
    return img
def s_t1(t):
    tt = max(0, t - TL['t1'][0]); img = bg(t)
    k = pop_in(tt, 0.1); cx = W / 2 if not LAND else W * 0.30
    img = R.pill(img, '1', cx, H * (0.28 if not LAND else 0.30), 150, bgc=GREEN, fg=(6, 30, 14), alpha=clamp(k, 0, 1), scale=clamp(k, 0.01, 1.05), padx=60, pady=34)
    img = txt(img, 'À partir d’un post', cx, H * (0.40 if not LAND else 0.50), 84 if not LAND else 68, alpha=ease_out((tt - 0.3) / 0.45), maxw=W * (0.9 if not LAND else 0.5))
    # avant / après
    pw = int(W * (0.26 if not LAND else 0.15)); ph = int(pw * 1.25); y = H * (0.66 if not LAND else 0.5); x0 = W * (0.26 if not LAND else 0.64); x1 = W * (0.74 if not LAND else 0.84)
    a = pop_in(tt, 0.7); post = Image.new('RGBA', (pw, ph), (0, 0, 0, 0)); d = ImageDraw.Draw(post); d.rounded_rectangle((0, 0, pw - 1, ph - 1), 22 * U, fill=SURF + (255,), outline=BORD + (255,), width=3)
    av = R.fit(photo('intro3'), int(pw * 0.14), int(pw * 0.14), 100); post.alpha_composite(av, (int(pw * 0.06), int(pw * 0.06)))
    d.text((pw * 0.24, pw * 0.11), '@aminata_k', font=R.font(pw * 0.085), fill=WHITE + (255,), anchor='lm'); post.alpha_composite(R.fit(photo('intro1'), int(pw * 0.88), int(pw * 0.88), 16), (int(pw * 0.06), int(pw * 0.26))); d.text((pw * 0.06, pw * 1.22), 'Coucher de soleil sur Dakar', font=R.font(pw * 0.07, 'r'), fill=MUT + (255,), anchor='lm')
    img = R.paste(img, post, x0, y, scale=clamp(a, 0.01, 1.04), angle=-3)
    a2 = ease_out((tt - 1.2) / 0.4); img = arrow_r(img, (x0 + x1) / 2, y, 90 * U if not LAND else 70 * U, GREEN, a2)
    b = pop_in(tt, 1.5); img = R.paste(img, R.fit(card('neon'), pw, ph, 22), x1, y, scale=clamp(b, 0.01, 1.04), angle=3)
    return img
def s_post(t):
    tt = max(0, t - TL['post'][0]); img = bg(t)
    ring = None; menu = 0.0; quick = False; hl = False
    if 2.4 <= tt < 3.8: ring = 'post'
    if 3.8 <= tt < 5.2: quick = True; menu = seg(tt, 3.8, 4.2)
    if 5.2 <= tt < 5.5: quick = True; menu = 1 - seg(tt, 5.2, 5.5)
    if 5.6 <= tt < 6.9: ring = 'dots'
    if 6.9 <= tt < 9.2: menu = seg(tt, 6.9, 7.4); hl = tt > 7.6
    if 9.2 <= tt < 9.7: menu = 1 - seg(tt, 9.2, 9.7)
    scr = feed(ring=ring)
    if menu > 0: sheet(scr, menu, hl=hl, quick=quick)
    img = draw_phone(img, scr, pop_in(tt, 0.0, 0.6), dx=0)
    if 2.4 <= tt < 3.8: img = finger(img, *POST_PHOTO, 2.4, 3.7, tt)
    if 5.6 <= tt < 6.9: img = finger(img, *POST_DOTS, 6.2, 6.8, tt)
    if 7.6 <= tt < 9.2:
        items = menu_items(); h = 24 + 56 * len(items) + 24; y0 = 844 - h; img = finger(img, 195, y0 + 24 + 28, 8.0, 8.5, tt)
    if tt < 5.5: img = caption(img, 'Appui long sur le post', tt, 2.4)
    elif tt < 7.5: img = caption(img, 'ou touchez les 3 points', tt, 5.6, col=(30, 34, 32), fg=WHITE, sz=46)
    else: img = caption(img, 'Créer une carte Afrolook', tt, 7.6, sz=46)
    return img
def s_studio(t):
    tt = max(0, t - TL['studio'][0]); img = bg(t)
    sel, pack, fmt, hl, prev, fade = 'neon', 1, 'Portrait', None, None, 1.0
    if tt >= 1.6: hl = 'style'
    if 2.0 <= tt < 3.0: sel = 'manga'; prev = ('neon', 240, 300); fade = seg(tt, 2.0, 2.4)
    if 3.0 <= tt < 3.8: sel = 'collector'; prev = ('manga', 240, 300); fade = seg(tt, 3.0, 3.4)
    if 3.8 <= tt < 4.6: fmt = 'Story'; sel = 'story_neon'; hl = 'format'; prev = ('collector', 240, 300); fade = seg(tt, 3.8, 4.2)
    if 4.6 <= tt < 5.4: sel = 'collector'; hl = 'images'; prev = ('story_neon', 172, 306); fade = seg(tt, 4.6, 5.0)
    if tt >= 5.4: pack = 2; sel = 'passport'; hl = 'country'; prev = ('collector', 240, 300); fade = seg(tt, 5.4, 5.8)
    scr = studio(sel=sel, pack=pack, fmt=fmt, hl=hl, prev=prev, fade=fade, thumbs=4 if tt >= 4.4 else 0)
    img = draw_phone(img, scr, pop_in(tt, 0.0, 0.5) if tt < 0.6 else 1.0)
    shown = [('Style', 1.6, 3.8), ('Format', 3.8, 4.6), ('Images', 4.6, 5.4), ('Pays', 5.4, 99)]
    for i, (lb, t0, t1) in enumerate(shown):
        a = pop_in(tt, t0)
        if a <= 0: continue
        on = t0 <= tt < t1
        if LAND: cx, cy = W * 0.28, H * (0.26 + 0.12 * i)
        else: cx, cy = W * (0.14 + 0.24 * i), H * 0.075
        img = pill(img, lb, cx, cy, 44 if not LAND else 38, bgc=GREEN if on else (30, 34, 32), fg=(6, 30, 14) if on else WHITE, a=a, sc=a, padx=30, pady=16)
    if tt >= 6.2:
        a = pop_in(tt, 6.2); img = pill(img, 'Votre carte est prête', W * (0.5 if not LAND else 0.28), H * (0.93 if not LAND else 0.80), 52 if not LAND else 42, bgc=YEL, fg=(31, 31, 31), a=a, sc=a)
        for (sx, sy, off, r) in R.SPK[:8]:
            aa = math.sin(clamp((tt - 6.3 - off * 0.5) / 0.8) * math.pi)
            if aa > 0:
                pw, ph, cx, cy = geom(); img = R.sparkle(img, cx + (sx - 0.5) * pw * 1.1, cy + (sy - 0.5) * ph * 0.6, r * U * aa, aa)
    return img
def s_share(t):
    tt = max(0, t - TL['share'][0]); img = bg(t)
    scr = studio(sel='passport', pack=2, fmt='Portrait', thumbs=4, bar_hl='Enregistrer' if 0.3 < tt < 1.5 else ('Partager' if 1.6 <= tt < 3.8 else ('Publier' if tt >= 3.9 else None)))
    if tt >= 1.0: toast(scr, seg(tt, 1.0, 1.3) * (1 - seg(tt, 2.2, 2.5)), 'Carte enregistrée dans ta galerie')
    if 2.6 <= tt < 3.9: share_sheet(scr, seg(tt, 2.6, 3.0) * (1 if tt < 3.7 else 1 - seg(tt, 3.7, 3.9)))
    if tt >= 4.6: publish_sheet(scr, seg(tt, 4.6, 5.0), hl=0 if tt < 5.6 else (1 if tt < 6.3 else 2))
    img = draw_phone(img, scr)
    img = finger(img, 62, 813, 0.5, 1.0, tt); img = finger(img, 195 - 0, 813, 2.0, 2.5, tt) if False else img
    img = finger(img, 180, 813, 2.0, 2.5, tt); img = finger(img, 318, 813, 4.1, 4.6, tt)
    cap = [('Enregistrer', 0.3), ('Partager', 2.0), ('Publier', 4.0)]
    cur = 0 if tt < 1.9 else (1 if tt < 3.9 else 2)
    for i, (lb, t0) in enumerate(cap):
        a = pop_in(tt, t0)
        if a <= 0: continue
        on = i == cur
        if LAND: cx, cy = W * 0.28, H * (0.30 + 0.13 * i)
        else: cx, cy = W * (0.20 + 0.30 * i), H * 0.075
        img = pill(img, lb, cx, cy, 46 if not LAND else 38, bgc=GREEN if on else (30, 34, 32), fg=(6, 30, 14) if on else WHITE, a=a, sc=a, padx=34, pady=16)
    if tt >= 5.0: img = pill(img, 'En Chronique ou en post', W * (0.5 if not LAND else 0.28), H * (0.93 if not LAND else 0.76), 44 if not LAND else 36, bgc=(30, 34, 32), fg=WHITE, a=pop_in(tt, 5.0), sc=pop_in(tt, 5.0))
    return img
def s_t2(t):
    tt = max(0, t - TL['t2'][0]); img = bg(t)
    k = pop_in(tt, 0.1); cx = W / 2 if not LAND else W * 0.30
    img = R.pill(img, '2', cx, H * (0.28 if not LAND else 0.30), 150, bgc=YEL, fg=(31, 31, 31), alpha=clamp(k, 0, 1), scale=clamp(k, 0.01, 1.05), padx=60, pady=34)
    img = txt(img, 'Créer une carte\nde zéro', cx, H * (0.43 if not LAND else 0.52), 84 if not LAND else 68, alpha=ease_out((tt - 0.3) / 0.45), maxw=W * (0.9 if not LAND else 0.5))
    pw = int(W * (0.28 if not LAND else 0.16)); ph = int(pw * 1.25)
    for i, n in enumerate(['wax', 'quote', 'flag']):
        b = pop_in(tt, 0.7 + 0.2 * i); x = (W * (0.22 + 0.28 * i)) if not LAND else W * (0.58 + 0.13 * i); y = H * (0.72 if not LAND else 0.5)
        img = R.paste(img, R.fit(card(n), pw, ph, 22), x, y, angle=(i - 1) * 6, scale=clamp(b, 0.01, 1.05))
    return img
def s_create(t):
    tt = max(0, t - TL['create'][0]); img = bg(t)
    if tt < 3.6: scr = feed(plus_pulse=0.5 + 0.5 * math.sin(tt * 6) if tt > 0.8 else 0.0)
    elif tt < 7.6: scr = create_page('Image' if tt < 5.6 else 'Carte', btn_hl=(6.4 < tt < 7.6))
    elif tt < 11.4:
        thumbs = 0 if tt < 9.6 else min(4, 1 + int((tt - 9.6) / 0.5))
        full = 'Fête de l’indépendance : fiers de notre pays !'; typed = full[:int(len(full) * seg(tt, 8.0, 9.4))] if tt >= 8.0 else ''
        scr = studio(sel='wax', pack=0, fmt='Portrait', text=typed + ('|' if 8.0 <= tt < 9.5 and int(tt * 4) % 2 == 0 else ''), thumbs=thumbs, hl='images' if 9.6 <= tt < 11.4 else None)
    else: scr = create_page('Carte', link_hl=tt > 12.5, chips_hl=(11.4 < tt <= 12.5))
    img = draw_phone(img, scr, pop_in(tt, 0.0, 0.5) if tt < 0.6 else 1.0)
    if 2.6 <= tt < 3.6: img = finger(img, *NAV_PLUS, 2.8, 3.3, tt)
    if 5.0 <= tt < 5.9: img = finger(img, 355 - 8, 79, 5.2, 5.7, tt)
    if 6.3 <= tt < 7.6: img = finger(img, 195, 439, 6.6, 7.1, tt)
    caps = [('Bouton  +  Créer', 2.0, 3.6), ('Onglet  Carte', 5.0, 6.4), ('Créer ma carte', 6.4, 7.6), ('Votre texte', 8.0, 9.6), ('Jusqu’à 4 images', 9.6, 11.4), ('Modèle ou lien', 11.4, 14)]
    for lb, t0, t1 in caps:
        if t0 <= tt < t1: img = caption(img, lb, tt, t0, sz=48)
    return img
def s_ex(t):
    tt = max(0, t - TL['ex'][0]); img = bg(t)
    items = [('quote', 'Citation', 0.5), ('flag', 'Fête nationale', 1.4), ('music', 'Playlist', 2.3), ('passport', 'Passeport', 3.2), ('film', 'Affiche de film', 4.1)]
    cw = int(W * (0.31 if not LAND else 0.15)); chh = int(cw * 1.25)
    for i, (n, lb, t0) in enumerate(items):
        k = pop_in(tt, t0, 0.55)
        if k <= 0: continue
        if LAND: px = W * (0.12 + 0.19 * i); py = H * 0.46 + (i % 2) * 40 * U - 20 * U
        else: px = W * [0.27, 0.73, 0.27, 0.73, 0.5][i]; py = H * [0.17, 0.17, 0.41, 0.41, 0.65][i]
        img = R.paste(img, R.fit(card(n), cw, chh, 22), px, py, angle=(i - 2) * 3, scale=clamp(k, 0.01, 1.06))
        img = pill(img, lb, px, py + chh * 0.54, 34 if not LAND else 28, bgc=(20, 24, 22), fg=WHITE, a=k, sc=k, padx=22, pady=11)
    a = ease_out((tt - 5.0) / 0.45); img = txt(img, 'À chaque occasion, sa carte', W / 2, H * (0.915 if not LAND else 0.90), 64 if not LAND else 54, col=GREEN, alpha=a, maxw=W * 0.92)
    return img
def mini_phone(img, scr, cx, cy, pw):
    ph = pw * 2.1; m = int(8 * U); pw_, ph_ = int(pw), int(ph); body = Image.new('RGBA', (pw_, ph_), (0, 0, 0, 0)); d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, pw_ - 1, ph_ - 1), pw_ * 0.12, fill=(16, 18, 20, 255), outline=(78, 82, 86, 255), width=3)
    sw, sh = pw_ - 2 * m, ph_ - 2 * m; sc = scr.im.resize((sw, sh), Image.LANCZOS); mk = Image.new('L', (sw, sh), 0); ImageDraw.Draw(mk).rounded_rectangle((0, 0, sw - 1, sh - 1), pw_ * 0.10, fill=255); sc.putalpha(mk); body.alpha_composite(sc, (m, m))
    return R.paste(img, body, cx, cy)
def s_upd(t):
    tt = max(0, t - TL['upd'][0]); img = bg(t)
    pw = W * (0.40 if not LAND else 0.13)
    ya = H * (0.37 if not LAND else 0.50)
    xa = W * (0.26 if not LAND else 0.27); xb = W * (0.74 if not LAND else 0.73)
    a = pop_in(tt, 0.2, 0.55); old = feed(); sheet(old, 1.0, old=True)
    img = mini_phone(img, old, xa, ya + (1 - clamp(a)) * 60 * U, pw)
    ly = ya + pw * 1.05 + 50 * U
    img = pill(img, 'Version ancienne', xa, ly, 36 if not LAND else 30, bgc=RED, fg=WHITE, a=pop_in(tt, 0.9), sc=pop_in(tt, 0.9), padx=26, pady=13)
    img = txt(img, 'pas de carte', xa, ly + 70 * U, 36 if not LAND else 30, col=MUT, kind='r', alpha=ease_out((tt - 1.1) / 0.4))
    if tt > 2.4:
        a2 = ease_out((tt - 2.4) / 0.4); img = arrow_r(img, W / 2, ya, 90 * U if not LAND else 70 * U, GREEN, a2)
    if tt > 4.4:
        b = pop_in(tt, 4.6, 0.55); new = feed(); sheet(new, 1.0, hl=True)
        img = mini_phone(img, new, xb, ya + (1 - clamp(b)) * 60 * U, pw)
        img = pill(img, 'Dernière version', xb, ly, 36 if not LAND else 30, bgc=GREEN, fg=(6, 30, 14), a=pop_in(tt, 5.2), sc=pop_in(tt, 5.2), padx=26, pady=13)
        img = txt(img, 'Créer une carte Afrolook', xb, ly + 70 * U, 34 if not LAND else 28, col=WHITE, kind='r', alpha=ease_out((tt - 5.5) / 0.4), maxw=W * 0.4)
    if tt > 2.4:
        img = txt(img, 'Mettez Afrolook à jour', W / 2, (H * 0.80) if not LAND else (ya + 130 * U), 56 if not LAND else 44, col=GREEN, alpha=ease_out((tt - 2.5) / 0.4), maxw=W * (0.9 if not LAND else 0.26))
    for i, lb in enumerate(['Google Play', 'App Store']):
        a = pop_in(tt, 2.8 + 0.3 * i)
        if a > 0:
            cx, cy = (W * (0.34 + 0.32 * i), H * 0.89) if not LAND else (W / 2, ya + (240 + 100 * i) * U)
            img = pill(img, lb, cx, cy, 46 if not LAND else 36, bgc=(30, 34, 32), fg=WHITE, a=a, sc=a, padx=36 if not LAND else 30, pady=18 if not LAND else 15)
    a = ease_out((tt - 0.1) / 0.45); img = txt(img, 'Vous ne voyez pas cette fonction ?', W / 2, H * (0.075 if not LAND else 0.10), 60 if not LAND else 52, alpha=a, maxw=W * 0.92)
    return img
def s_cta(t):
    tt = max(0, t - TL['cta'][0]); img = bg(t)
    pw = int(W * (0.22 if not LAND else 0.095)); ph = int(pw * 1.25)
    for i, n in enumerate(['kente', 'neon', 'passport', 'manga', 'film']):
        a = pop_in(tt, 0.1 + 0.12 * i, 0.5)
        if a <= 0: continue
        if LAND: px = W * (0.06 + 0.078 * i); py = H * 0.52 + abs(i - 2) * 20 * U
        else: px = W * (0.12 + 0.19 * i); py = H * 0.70 + abs(i - 2) * 26 * U
        img = R.paste(img, R.fit(card(n), pw, ph, 18), px, py, angle=(i - 2) * 6, scale=clamp(a, 0.01, 1.08))
    tx = W * 0.72 if LAND else W / 2
    lw = int(170 * U * (0.8 if LAND else 1)); a = ease_back((tt - 0.2) / 0.5); img = R.paste(img, LOGO.resize((lw, lw), Image.LANCZOS), tx, H * (0.12 if not LAND else 0.22), scale=clamp(a, 0.01, 1.05), shadowed=False)
    img = txt(img, 'Afrolook', tx, H * (0.215 if not LAND else 0.37), 110 if not LAND else 90, col=GREEN, alpha=ease_out((tt - 0.5) / 0.4), maxw=W * 0.9)
    img = txt(img, 'Créez votre première carte', tx, H * (0.29 if not LAND else 0.48), 64 if not LAND else 52, alpha=ease_out((tt - 1.0) / 0.4), maxw=W * (0.92 if not LAND else 0.52))
    for i, (lb, t0) in enumerate([('Accueil', 1.8), ('Créer', 2.4), ('Carte', 3.0)]):
        a = pop_in(tt, t0)
        if a > 0:
            cx = tx + (i - 1) * (W * (0.24 if not LAND else 0.12)); cy = H * (0.38 if not LAND else 0.60)
            img = pill(img, lb, cx, cy, 44 if not LAND else 34, bgc=GREEN if i == 2 else (30, 34, 32), fg=(6, 30, 14) if i == 2 else WHITE, a=a, sc=a, padx=30, pady=15)
            if i < 2 and a > 0.8: img = arrow_r(img, cx + W * (0.12 if not LAND else 0.06), cy, 34 * U, MUT, a)
    a = ease_out((tt - 4.0) / 0.5); img = txt(img, 'Mettez l’application à jour si vous\nne voyez pas la fonction', tx, H * (0.47 if not LAND else 0.74), 38 if not LAND else 32, col=MUT, kind='r', alpha=a, maxw=W * (0.92 if not LAND else 0.52))
    return img
SC = [('hook', s_hook), ('styles', s_styles), ('t1', s_t1), ('post', s_post), ('studio', s_studio), ('share', s_share), ('t2', s_t2), ('create', s_create), ('ex', s_ex), ('upd', s_upd), ('cta', s_cta)]
TR = 0.45
def frame(t, limit):
    for i, (nm, fn) in enumerate(SC):
        a_, b_ = TL[nm]
        if a_ <= t < b_: break
    img = fn(t)
    if b_ < 900 and t > b_ - TR and i + 1 < len(SC):
        k = ease_io((t - (b_ - TR)) / TR); img = Image.blend(img, SC[i + 1][1](t), k)
    if t < 0.4: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * (1 - t / 0.4)))))
    if t > limit - 0.6: img = Image.alpha_composite(img, Image.new('RGBA', (W, H), (0, 0, 0, int(255 * clamp((t - (limit - 0.6)) / 0.6)))))
    return img.convert('RGB')
if __name__ == '__main__':
    OUT = sys.argv[3]; LIMIT = float(sys.argv[5]); MIX = sys.argv[6]
    if len(sys.argv) > 7 and sys.argv[7] == 'test':
        import os; os.makedirs('test', exist_ok=True)
        for tt in [float(x) for x in sys.argv[8].split(',')]: frame(tt, LIMIT).save(f'test/v5_{W}x{H}_{tt}.png')
        sys.exit(0)
    cmd = [imageio_ffmpeg.get_ffmpeg_exe(), '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-', '-i', MIX, '-t', str(LIMIT),
           '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '192k', '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', OUT]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
    for i in range(int(LIMIT * FPS)): p.stdin.write(frame(i / FPS, LIMIT).tobytes())
    p.stdin.close(); p.wait(); print('fini', OUT)
