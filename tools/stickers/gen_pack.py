#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère le pack officiel « Universel » d'Afrolook : 64 stickers WebP animés.

Sortie (par sticker) : <out>/{id}.webp (360x360, boucle, <= 3 s, <= 600 Ko)
                       <out>/{id}_thumb.webp (256x256 fixe, <= 40 Ko)
Puis écrit tools/stickers/pack_index.json (légendes 8 langues, mots-clés, poids...).

Les stickers sont fabriqués à partir de l'emoji couleur Noto (police bitmap CBDT)
animé sur une pastille colorée à contour blanc « découpé ». Aucun texte n'est
dessiné dans l'image. Remplaçable plus tard par des illustrations : il suffit de
remplacer les fichiers .webp en conservant les identifiants de pack_index.json.

Usage :
  python3 tools/stickers/gen_pack.py [--out DOSSIER] [--only id1,id2] [--jobs N]
Par défaut le dossier de sortie est $PACK_OUT ou tools/stickers/pack_out (ignoré par git).
"""
import argparse
import json
import math
import os
import random
import sys
import unicodedata
from multiprocessing import Pool
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import pack_texts  # noqa: E402

FONT_PATH = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
CATALOG = HERE / "catalog_universel.json"
INDEX_PATH = HERE / "pack_index.json"

W = 360                # côté du sticker
NFRAMES = 30           # images par boucle
FRAME_MS = 80          # durée d'une image -> 2,4 s
MAX_BYTES = 600 * 1024
MAX_THUMB_BYTES = 40 * 1024
MAX_DURATION_MS = 3000
SPR = 232              # taille (cellule) de l'emoji principal
TAU = 2 * math.pi

# ------------------------------------------------------------------ utilitaires


def clamp(x, a=0.0, b=1.0):
    return a if x < a else b if x > b else x


def seg(t, a, b):
    return clamp((t - a) / (b - a))


def eo3(x):
    return 1 - (1 - x) ** 3


def ei3(x):
    return x ** 3


def eio(x):
    return x * x * (3 - 2 * x)


def eob(x):
    c1 = 1.70158
    c3 = c1 + 1
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def lerp(a, b, x):
    return a + (b - a) * x


def strip_accents(s):
    s = s.replace("œ", "oe").replace("Œ", "Oe").replace("æ", "ae")
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def slugify(s):
    s = strip_accents(s).lower()
    out = []
    for c in s:
        out.append(c if c.isalnum() and c.isascii() else "_")
    slug = "_".join(p for p in "".join(out).split("_") if p)
    return slug[:34].rstrip("_")


# ------------------------------------------------------------------ pastille

PALETTES = {
    "violet": ((170, 130, 255), (98, 60, 205)),
    "blue": ((100, 175, 255), (40, 92, 212)),
    "teal": ((72, 216, 202), (0, 138, 150)),
    "pink": ((255, 135, 195), (218, 52, 132)),
    "magenta": ((232, 118, 242), (150, 42, 182)),
    "indigo": ((96, 96, 208), (38, 30, 120)),
    "sky": ((150, 214, 255), (74, 144, 232)),
    "coral": ((255, 146, 124), (226, 78, 84)),
    "green": ((110, 222, 124), (30, 150, 84)),
}
CAT_COLORS = {
    "joie": ["blue", "violet", "teal", "magenta", "indigo", "pink", "violet", "teal",
             "blue", "indigo", "magenta", "indigo"],
    "reussite": ["violet", "blue", "indigo", "magenta", "teal", "blue", "violet", "indigo",
                 "pink", "teal", "magenta", "indigo", "violet", "teal"],
    "compliments": ["indigo", "violet", "magenta", "blue", "indigo", "teal", "coral", "blue",
                    "violet", "teal", "indigo", "teal"],
    "amour": ["teal", "violet", "teal", "indigo", "blue", "indigo", "magenta", "indigo",
              "violet", "teal"],
    "reponses": ["blue", "magenta", "violet", "teal", "indigo", "violet", "blue", "indigo",
                 "indigo", "teal", "violet", "blue", "magenta", "indigo", "violet", "teal"],
}

_pastille_cache = {}


def pastille(color):
    """Retourne (image RGBA 360x360 de la pastille, masque L de l'intérieur)."""
    if color in _pastille_cache:
        return _pastille_cache[color]
    k = 4
    top, bot = PALETTES[color]
    big = W * k
    outer = Image.new("L", (big, big), 0)
    ImageDraw.Draw(outer).rounded_rectangle((6 * k, 6 * k, (W - 6) * k, (W - 6) * k), radius=98 * k, fill=255)
    inner = Image.new("L", (big, big), 0)
    ImageDraw.Draw(inner).rounded_rectangle((16 * k, 16 * k, (W - 16) * k, (W - 16) * k), radius=88 * k, fill=255)
    outer = outer.resize((W, W), Image.LANCZOS)
    inner = inner.resize((W, W), Image.LANCZOS)
    # dégradé vertical
    grad = Image.new("RGB", (W, W))
    gd = ImageDraw.Draw(grad)
    for y in range(W):
        u = y / (W - 1)
        gd.line((0, y, W, y), fill=tuple(int(lerp(top[i], bot[i], u)) for i in range(3)))
    base = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    white = Image.new("RGBA", (W, W), (255, 255, 255, 255))
    base = Image.composite(white, base, outer)
    fill = grad.convert("RGBA")
    base = Image.composite(fill, base, inner)
    base.putalpha(outer)
    _pastille_cache[color] = (base, inner)
    return base, inner


# ------------------------------------------------------------------ sprites emoji

_font = None
_sprites = {}


def sprite(ch):
    """Emoji Noto sur une cellule carrée (RGBA 272x272, 2x la taille native)."""
    ch = ch.replace("️", "")
    if ch in _sprites:
        return _sprites[ch]
    global _font
    if _font is None:
        _font = ImageFont.truetype(FONT_PATH, 109)
    im = Image.new("RGBA", (260, 260), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((40, 40), ch, font=_font, embedded_color=True)
    if im.getchannel("A").getbbox() is None:
        raise RuntimeError("emoji non rendu : %r" % ch)
    cell = im.crop((40, 36, 176, 172)).resize((272, 272), Image.LANCZOS)
    if ch == "🎆":  # l'emoji a un fond carré sombre : on le fond dans un disque doux
        rg = Image.radial_gradient("L").resize((272, 272), Image.BICUBIC)  # 0 centre -> 255 bord
        soft = rg.point(lambda v: int(255 * clamp((150 - v) / 60)))
        cell.putalpha(ImageChops.multiply(cell.getchannel("A"), soft))
    _sprites[ch] = cell
    return cell


# ------------------------------------------------------------------ image (une frame)

CONF_COLORS = [(255, 90, 120), (255, 214, 64), (92, 224, 152), (96, 176, 255), (255, 255, 255), (206, 126, 255)]


class Frame:
    def __init__(self, color):
        self.base, self.mask = pastille(color)
        self.content = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        self.fx = None
        self.fxd = None

    # -- effets vectoriels dessinés en 2x puis réduits
    def _fx(self):
        if self.fx is None:
            self.fx = Image.new("RGBA", (W * 2, W * 2), (0, 0, 0, 0))
            self.fxd = ImageDraw.Draw(self.fx)
        return self.fxd

    def flush(self):
        if self.fx is not None:
            small = self.fx.resize((W, W), Image.BILINEAR)
            self.content = Image.alpha_composite(self.content, small)
            self.fx = None
            self.fxd = None

    def circle(self, x, y, r, col, a=1.0):
        if r <= 0 or a <= 0:
            return
        d = self._fx()
        d.ellipse(((x - r) * 2, (y - r) * 2, (x + r) * 2, (y + r) * 2), fill=col + (int(255 * clamp(a)),))

    def ring(self, x, y, r, width, col, a=1.0):
        if r <= 0 or a <= 0:
            return
        d = self._fx()
        d.ellipse(((x - r) * 2, (y - r) * 2, (x + r) * 2, (y + r) * 2), outline=col + (int(255 * clamp(a)),),
                  width=max(1, int(width * 2)))

    def star(self, x, y, r, col=(255, 255, 255), a=1.0, rot=0.0):
        if r <= 0.5 or a <= 0:
            return
        d = self._fx()
        pts = []
        for i in range(8):
            rr = r if i % 2 == 0 else r * 0.27
            ang = math.radians(rot) + i * math.pi / 4 - math.pi / 2
            pts.append(((x + math.cos(ang) * rr) * 2, (y + math.sin(ang) * rr) * 2))
        d.polygon(pts, fill=col + (int(255 * clamp(a)),))

    def piece(self, x, y, w, h, rot, col, a=1.0):
        if a <= 0:
            return
        d = self._fx()
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        pts = []
        for px, py in ((-w, -h), (w, -h), (w, h), (-w, h)):
            pts.append(((x + px * c - py * s) * 2, (y + px * s + py * c) * 2))
        d.polygon(pts, fill=col + (int(255 * clamp(a)),))

    # -- sprites emoji
    def spr(self, ch, cx, cy, size=SPR, rot=0.0, sx=1.0, sy=1.0, alpha=1.0, pivot=(0.0, 0.0)):
        w = int(size * abs(sx))
        h = int(size * abs(sy))
        if w < 2 or h < 2 or alpha <= 0:
            return
        self.flush()
        im = sprite(ch).resize((w, h), Image.BICUBIC)
        if sx < 0:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        if alpha < 1:
            im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
        px, py = pivot
        vx, vy = -px * w, -py * h
        if rot:
            im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
            th = math.radians(rot)
            vx, vy = vx * math.cos(th) + vy * math.sin(th), -vx * math.sin(th) + vy * math.cos(th)
        nx = cx + px * w + vx
        ny = cy + py * h + vy
        layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        layer.paste(im, (int(round(nx - im.width / 2)), int(round(ny - im.height / 2))))
        self.content = Image.alpha_composite(self.content, layer)

    def render(self):
        self.flush()
        a = ImageChops.multiply(self.content.getchannel("A"), self.mask)
        c = self.content.copy()
        c.putalpha(a)
        return Image.alpha_composite(self.base, c)


# ------------------------------------------------------------------ effets composés


def burst(f, u, cx, cy, n, seed, r0, r1, kind="star", size=14, gravity=0.0, colors=None):
    if u <= 0 or u >= 1:
        return
    rng = random.Random(seed)
    colors = colors or CONF_COLORS
    for i in range(n):
        ang = (i / n) * TAU + rng.uniform(-0.25, 0.25)
        rr = r0 + (r1 - r0) * eo3(u) * rng.uniform(0.65, 1.0)
        x = cx + math.cos(ang) * rr
        y = cy + math.sin(ang) * rr + gravity * u * u
        s = size * (1 - u * 0.8) * rng.uniform(0.6, 1.1)
        col = colors[i % len(colors)]
        a = 1 - u ** 2
        k = kind if kind != "mix" else ("star", "dot", "conf")[i % 3]
        if k == "star":
            f.star(x, y, s * 1.3, col, a, rot=u * 90 * rng.uniform(-1, 1))
        elif k == "dot":
            f.circle(x, y, s * 0.45, col, a)
        else:
            f.piece(x, y, s * 0.5, s * 0.25, u * 360 * rng.uniform(-1, 1), col, a)


def rain(f, t, t0, t1, n, seed):
    u = seg(t, t0, t1)
    if u <= 0:
        return
    rng = random.Random(seed)
    for i in range(n):
        d = rng.uniform(0, 0.4)
        x0 = rng.uniform(30, 330)
        ph = rng.uniform(0, TAU)
        w = (u - d) / 0.6
        col = CONF_COLORS[i % len(CONF_COLORS)]
        spin = rng.uniform(-2, 2)
        if 0 < w < 1:
            y = -20 + 400 * (w ** 1.15)
            x = x0 + 14 * math.sin(w * TAU * 1.5 + ph)
            f.piece(x, y, 6.5, 3.2, w * 360 * spin, col)


def glow(f, x, y, r, a):
    for k, m in ((1.0, 0.35), (0.72, 0.5), (0.46, 0.7)):
        f.circle(x, y, r * k, (255, 255, 255), a * m * 0.5)


def glints(f, t, pts, speed=2, r=26):
    for i, (x, y) in enumerate(pts):
        u = (t * speed + i * 0.27) % 1.0
        k = math.sin(math.pi * u) ** 2
        f.star(x, y, r * k, (255, 255, 255), min(1, k * 1.4), rot=k * 40)


GLINT_PTS = [(78, 96), (288, 112), (262, 290), (92, 268)]

# ------------------------------------------------------------------ mouvements simples
# Chaque mouvement retourne des kwargs pour Frame.spr (dx, dy sont ajoutés au centre)


def m_bounce(t):
    p = abs(math.sin(math.pi * 3 * t))
    q = clamp(1 - p / 0.18)
    return dict(dy=-p * 46 + q * 8, sx=1 + 0.10 * q, sy=1 - 0.13 * q)


def m_laugh_shake(t):
    env = 0.55 + 0.45 * math.sin(TAU * t * 2 - 1)
    return dict(rot=9 * math.sin(TAU * t * 8) * env, dy=-7 * abs(math.sin(TAU * t * 8)) * env)


def m_rock_laugh(t):
    return dict(rot=22 * math.sin(TAU * t * 2), dy=-10 * abs(math.sin(TAU * t * 4)),
                sx=1 + 0.05 * math.sin(TAU * t * 4), sy=1 + 0.05 * math.sin(TAU * t * 4))


def m_pulse(t):
    s = 1 + 0.10 * math.sin(TAU * t * 2)
    return dict(sx=s, sy=s)


def _beat(u):
    if u < 0.2:
        return math.sin(math.pi * u / 0.2)
    if 0.28 < u < 0.48:
        return 0.6 * math.sin(math.pi * (u - 0.28) / 0.2)
    return 0.0


def m_heartbeat(t):
    s = 1 + 0.2 * _beat((t * 2) % 1.0)
    return dict(sx=s, sy=s)


def m_sway(t):
    return dict(rot=12 * math.sin(TAU * t * 2), dx=6 * math.sin(TAU * t * 2), pivot=(0, 0.4))


def m_float(t):
    return dict(dy=11 * math.sin(TAU * t * 2), rot=3 * math.sin(TAU * t))


def m_pop_spin(t):
    a = seg(t, 0, 0.3)
    s = eob(a)
    rot = (1 - eo3(a)) * 360
    s *= 1 + 0.04 * math.sin(TAU * t * 4) * seg(t, 0.3, 0.4)
    s *= 1 - eio(seg(t, 0.88, 1))
    return dict(sx=s, sy=s, rot=rot)


def m_fire(t):
    sx = 1 + 0.05 * math.sin(TAU * t * 7) + 0.03 * math.sin(TAU * t * 11 + 1)
    sy = 1 + 0.09 * math.sin(TAU * t * 9) + 0.04 * math.sin(TAU * t * 5)
    return dict(sx=sx, sy=sy, rot=3 * math.sin(TAU * t * 6), pivot=(0, 0.5))


def m_wave(t):
    return dict(rot=24 * math.sin(TAU * t * 3), pivot=(0.05, 0.5))


def m_slide(t):
    a = seg(t, 0, 0.3)
    c = seg(t, 0.82, 1)
    dx = -330 * (1 - eob(a)) + 330 * ei3(c)
    return dict(dx=dx, dy=6 * math.sin(TAU * t * 3) * seg(t, 0.3, 0.4), rot=4 * math.sin(TAU * t * 2))


def m_shine(t):
    s = 1 + 0.05 * math.sin(TAU * t * 2)
    return dict(sx=s, sy=s, rot=3 * math.sin(TAU * t))


def x_shine(f, t):
    glints(f, t, GLINT_PTS)


def m_jelly(t):
    k = math.sin(TAU * t * 3)
    return dict(sx=1 + 0.12 * k, sy=1 - 0.12 * k, dy=-4 * abs(k))


def m_dance(t):
    return dict(rot=10 * math.sin(TAU * t * 3), dy=-16 * abs(math.sin(math.pi * t * 6)),
                dx=12 * math.sin(TAU * t * 3), pivot=(0, 0.4))


def m_giggle(t):
    env = max(0.0, math.sin(TAU * t * 2)) ** 0.6
    return dict(rot=10 * math.sin(TAU * t * 10) * env, dy=-4 * env)


def m_clap(t):
    k = max(0.0, math.sin(TAU * t * 4)) ** 3
    return dict(sx=1 + 0.14 * k, sy=1 + 0.14 * k, rot=5 * math.sin(TAU * t * 8) * k)


def m_jump_spin(t):
    a = seg(t, 0.1, 0.62)
    dy = -74 * 4 * a * (1 - a)
    rot = -360 * eio(a)
    q = clamp(1 - min(a, 1 - a) / 0.12) if 0 < a < 1 else 0
    return dict(dy=dy + q * 6, rot=rot, sy=1 - 0.1 * q, sx=1 + 0.06 * q)


def m_rise(t):
    tri = 1 - abs(2 * t - 1)
    u = eio(tri)
    s = 0.92 + 0.16 * u
    return dict(dx=lerp(-20, 20, u), dy=lerp(24, -24, u), sx=s, sy=s)


def m_cheer(t):
    return dict(rot=10 * math.sin(TAU * t * 3), dy=-22 * abs(math.sin(math.pi * t * 6)), pivot=(0, 0.4))


def m_tip(t):
    return dict(rot=-24 * max(0.0, math.sin(TAU * t * 2)), pivot=(-0.15, 0.45), dy=2)


def m_flex(t):
    k = max(0.0, math.sin(TAU * t * 2)) ** 0.7
    return dict(sx=1 + 0.22 * k, sy=1 + 0.22 * k, rot=6 * math.sin(TAU * t * 6) * k)


def m_nod(t):
    return dict(dy=15 * math.sin(TAU * t * 3), rot=3 * math.sin(TAU * t * 3))


def m_shake_no(t):
    return dict(dx=22 * math.sin(TAU * t * 5) * (0.6 + 0.4 * math.sin(TAU * t)),
                rot=6 * math.sin(TAU * t * 5))


def m_tremble(t):
    return dict(dx=6 * math.sin(TAU * t * 12), dy=4 * math.sin(TAU * t * 9), rot=2 * math.sin(TAU * t * 7))


def m_turn(t):
    return dict(rot=360 * eio(seg(t, 0.25, 0.8)), sx=1 + 0.04 * math.sin(TAU * t * 2),
                sy=1 + 0.04 * math.sin(TAU * t * 2))


def m_walk(t):
    return dict(dx=18 * math.sin(TAU * t), dy=-9 * abs(math.sin(math.pi * t * 8)),
                rot=6 * math.sin(TAU * t * 4), pivot=(0, 0.45))


MOTIONS = {
    "bounce": (m_bounce, None), "laugh_shake": (m_laugh_shake, None), "rock_laugh": (m_rock_laugh, None),
    "pulse": (m_pulse, None), "heartbeat": (m_heartbeat, None), "sway": (m_sway, None),
    "float": (m_float, None), "pop_spin": (m_pop_spin, None), "fire_flicker": (m_fire, None),
    "wave_hand": (m_wave, None), "slide": (m_slide, None), "shine": (m_shine, x_shine),
    "jelly": (m_jelly, None), "dance": (m_dance, None), "giggle": (m_giggle, None),
    "clap": (m_clap, None), "jump_spin": (m_jump_spin, None), "rise": (m_rise, None),
    "cheer": (m_cheer, None), "tip": (m_tip, None), "flex": (m_flex, None), "nod": (m_nod, None),
    "shake_no": (m_shake_no, None), "tremble": (m_tremble, None), "turn": (m_turn, None),
    "walk": (m_walk, None),
}


def draw_simple(f, ch, motion, t):
    fn, extra = MOTIONS[motion]
    kw = fn(t)
    dx = kw.pop("dx", 0)
    dy = kw.pop("dy", 0)
    f.spr(ch, W / 2 + dx, W / 2 + dy + 4, SPR, **kw)
    if extra:
        extra(f, t)


# ------------------------------------------------------------------ mini-scènes en 3 temps
# t in [0,1) ; acte 1 : 0-.33, acte 2 : .33-.62, acte 3 : .62-1


def life(t):
    """Facteur d'apparition (début) et de disparition (fin) pour boucler proprement."""
    return pop(seg(t, 0, 0.12)) * fade_out(t)


def pop(a):
    """Apparition en rebond, mais jamais à 0 : la première image reste lisible."""
    return 0.45 + 0.55 * eob(a)


def fade_out(t):
    """1 -> 0,45 en fin de boucle (= l'échelle de départ) : boucle sans à-coup."""
    return 1 - 0.55 * eio(seg(t, 0.9, 1))


def sc_love(f, t, ch="❤️"):
    """❤️ et 💙 se rapprochent, fusionnent en 💜, explosent en étincelles."""
    a1, a2 = seg(t, 0, 0.33), seg(t, 0.33, 0.6)
    lf, fo = life(t), fade_out(t)
    dist = 96 - 44 * eio(a1) - 52 * ei3(a2)
    m = seg(t, 0.52, 0.62)
    cy = 188 + 5 * math.sin(TAU * t * 6) * (1 - m)
    lean = 12 * math.sin(math.pi * a1)
    if m < 1:
        f.spr("❤️", 180 - dist, cy, 150 * lf, rot=lean, alpha=1 - m)
        f.spr("💙", 180 + dist, cy, 150 * lf, rot=-lean, alpha=1 - m)
    if m > 0:
        grow = 1 + 0.45 * eob(seg(t, 0.55, 0.74)) + 0.05 * math.sin(TAU * t * 5) * seg(t, 0.75, 0.8)
        f.spr("💜", 180, 188, 150 * grow * lf, alpha=m * fo)
    fl = seg(t, 0.56, 0.66)
    if 0 < fl < 1:
        glow(f, 180, 188, 30 + 130 * fl, 1 - fl)
    u = seg(t, 0.62, 0.95)
    burst(f, u, 180, 188, 10, 11, 40, 150, "star", 17, colors=[(255, 255, 255), (255, 210, 90), (255, 150, 220)])
    burst(f, seg(t, 0.66, 0.98), 180, 188, 6, 5, 30, 125, "dot", 16, colors=[(255, 255, 255), (255, 170, 230)])
    if 0.66 < t < 0.97:
        uu = seg(t, 0.66, 0.97)
        for i, (ang, ch2) in enumerate(((-150, "💖"), (-90, "💗"), (-30, "💖"), (30, "💕"), (150, "💕"))):
            rr = 40 + 115 * eo3(uu)
            x = 180 + math.cos(math.radians(ang)) * rr
            y = 188 + math.sin(math.radians(ang)) * rr - 20 * uu
            f.spr(ch2, x, y, 50 * (1 - 0.5 * uu), alpha=1 - uu ** 2)


def sc_kiss(f, t, ch="😘"):
    """😘 et 😍 s'approchent puis des cœurs s'envolent."""
    a1, a2 = seg(t, 0, 0.3), seg(t, 0.3, 0.6)
    lf = life(t)
    dist = 104 - 42 * eio(a1)
    lean = 14 * eio(a2) * (1 + 0.3 * math.sin(TAU * t * 6))
    k = 1 + 0.08 * math.sin(TAU * t * 6) * seg(t, 0.3, 0.7)
    cy = 205 + 4 * math.sin(TAU * t * 5)
    f.spr("😘", 180 - dist, cy, 150 * lf * k, rot=lean)
    f.spr("😍", 180 + dist, cy, 150 * lf * k, rot=-lean)
    if 0.6 < t < 0.98:
        pass
    hearts = ["❤️", "💕", "💗", "💖", "❤️"]
    for i, hch in enumerate(hearts):
        s0 = 0.46 + 0.06 * i
        u = seg(t, s0, s0 + 0.28)
        if 0 < u < 1:
            x = 180 + (i - 2) * 22 + 22 * math.sin(u * TAU * 1.2 + i)
            y = 175 - 230 * eo3(u) * (0.75 + 0.05 * i)
            sz = (44 + 8 * (i % 3)) * (0.6 + 0.6 * eob(clamp(u * 3)))
            f.spr(hch, x, y, sz, alpha=1 - u ** 3, rot=10 * math.sin(u * TAU))
    for i in range(3):
        u = seg(t, 0.48 + i * 0.1, 0.6 + i * 0.1)
        if 0 < u < 1:
            f.star(180 + (i - 1) * 26, 190 - 30 * u, 12 * math.sin(math.pi * u) + 2, (255, 255, 255), 1 - u)


def sc_champion(f, t, ch="🏆"):
    """🏆 surgit, brille, pluie de confettis."""
    a1 = seg(t, 0, 0.33)
    fo = fade_out(t)
    pos = (1 - eob(a1))
    dy = pos * 150
    s = (0.55 + 0.45 * eob(a1)) * 218
    a2 = seg(t, 0.33, 0.66)
    pulse = 1 + 0.06 * math.sin(math.pi * a2 * 2)
    hop = -10 * abs(math.sin(math.pi * seg(t, 0.66, 1) * 3)) * (1 - seg(t, 0.85, 1))
    if 0.3 < t < 0.9:
        g = seg(t, 0.3, 0.5) * (1 - seg(t, 0.7, 0.9))
        glow(f, 180, 190, 95 + 20 * math.sin(TAU * t * 4), g * 0.9)
    f.spr("🏆", 180, 194 + dy + hop, s * pulse * fo, rot=4 * math.sin(math.pi * a2 * 4) * (1 - a2))
    if 0.36 < t < 0.9:
        glints(f, (t - 0.36) * 2.2, [(88, 96), (272, 92), (296, 214), (64, 220), (180, 60)], speed=1.6, r=30)
    rain(f, t, 0.5, 1.0, 26, 3)


def sc_congrats(f, t, ch="🎉"):
    """🎉 éclate, 👏 arrive, confettis et étincelles."""
    a1 = seg(t, 0, 0.3)
    fo = fade_out(t)
    sz = 178 * pop(a1) * fo
    wob = 6 * math.sin(TAU * t * 5) * seg(t, 0.35, 0.8)
    f.spr("🎉", 132, 220, sz, rot=-30 * (1 - eo3(a1)) + wob)
    u = seg(t, 0.3, 0.62)
    burst(f, u, 180, 165, 16, 21, 10, 150, "mix", 20, gravity=50)
    b = eob(seg(t, 0.4, 0.56))
    clap = 1 + 0.16 * max(0.0, math.sin(TAU * t * 6)) * seg(t, 0.56, 0.9)
    f.spr("👏", 250, 232, 150 * b * clap * fo, rot=-8 * math.sin(TAU * t * 6) * seg(t, 0.56, 0.9))
    rain(f, t, 0.6, 1.0, 20, 8)
    for i, (x, y) in enumerate(((90, 80), (270, 90), (300, 160))):
        uu = seg(t, 0.6 + i * 0.07, 0.8 + i * 0.07)
        if 0 < uu < 1:
            f.star(x, y, 22 * math.sin(math.pi * uu), (255, 236, 130))


def sc_goal(f, t, ch="✅"):
    """🎯 apparaît, ✅ frappe la cible, éclats."""
    a1 = seg(t, 0, 0.3)
    fo = fade_out(t)
    hit = seg(t, 0.46, 0.6)
    dip = -0.09 * math.sin(math.pi * hit) if hit < 1 else 0
    wob = 5 * math.sin(TAU * t * 5) * (1 - hit) * seg(t, 0.2, 0.34)
    f.spr("🎯", 180, 185, 226 * pop(a1) * (1 + dip) * fo, rot=wob)
    k = seg(t, 0.36, 0.46)
    if 0 < k:
        sz = 150 * (1 + 1.6 * (1 - eo3(k))) * fo
        pulse = 1 + 0.07 * math.sin(TAU * t * 4) * seg(t, 0.6, 0.9)
        f.spr("✅", 216, 218, sz * pulse, alpha=min(1, k * 4) * fo, rot=-10 * (1 - k))
    r = seg(t, 0.46, 0.68)
    if 0 < r < 1:
        f.ring(216, 218, 20 + 110 * eo3(r), 8 * (1 - r) + 1, (255, 255, 255), 1 - r)
    burst(f, seg(t, 0.5, 0.95), 216, 218, 9, 4, 50, 135, "star", 18,
          colors=[(255, 255, 255), (255, 232, 120), (160, 255, 190)])


def sc_record(f, t, ch="🚀"):
    """🚀 décolle, s'élève puis éclate en étoiles."""
    a1, a2 = seg(t, 0, 0.3), seg(t, 0.3, 0.58)
    lf = life(t)
    p0, p1 = (108, 262), (196, 176)
    u = ei3(a2) * 0.8 + a2 * 0.2
    x, y = lerp(p0[0], p1[0], u), lerp(p0[1], p1[1], u)
    if t < 0.3:
        x += 4 * math.sin(TAU * t * 22) * a1
        y += 3 * math.sin(TAU * t * 17) * a1
    size = lerp(150, 105, u)
    # traînée / fumée
    for k in range(7):
        tk = a2 - k * 0.06
        if tk <= 0:
            continue
        uk = ei3(tk) * 0.8 + tk * 0.2
        xk, yk = lerp(p0[0], p1[0], uk) - 16, lerp(p0[1], p1[1], uk) + 18
        f.circle(xk, yk, 15 - k * 1.5 + 6 * (a2 > 0), (255, 255, 255), (1 - k / 7) * 0.7 * (1 - seg(t, 0.55, 0.62)))
    if t < 0.3:
        for k in range(4):
            uu = (t * 5 + k * 0.25) % 1.0
            f.circle(84 - 22 * uu, 290 + 6 * uu, 10 + 16 * uu, (255, 255, 255), 0.7 * (1 - uu) * a1)
    if t < 0.6:
        f.spr("🚀", x, y, size * lf, alpha=1 - seg(t, 0.55, 0.6))
    fl = seg(t, 0.56, 0.68)
    if 0 < fl < 1:
        glow(f, 190, 180, 20 + 120 * fl, 1 - fl)
    st = eob(seg(t, 0.6, 0.75))
    f.spr("🌟", 182, 182, 170 * st * fade_out(t) * (1 + 0.06 * math.sin(TAU * t * 5) * seg(t, 0.75, 0.9)),
          rot=(1 - st) * -90, alpha=1 - seg(t, 0.93, 1))
    burst(f, seg(t, 0.6, 0.97), 182, 182, 12, 9, 60, 158, "star", 20,
          colors=[(255, 255, 255), (255, 226, 96), (255, 170, 210), (150, 220, 255)])
    burst(f, seg(t, 0.64, 0.99), 182, 182, 8, 2, 40, 120, "dot", 15,
          colors=[(255, 255, 255), (255, 226, 96)])


def sc_celebrate(f, t, ch="🍾"):
    """🍾 secoué, le bouchon saute (confettis), 🥂 trinquent."""
    a1, a2 = seg(t, 0, 0.33), seg(t, 0.33, 0.6)
    fo = fade_out(t)
    lf = pop(seg(t, 0, 0.12))
    shift = eio(seg(t, 0.6, 0.72))
    bx = lerp(170, 116, shift)
    by = lerp(200, 214, shift)
    bs = lerp(206, 170, shift) * lf * fo
    shake = 12 * a1 * math.sin(TAU * t * 14) if t < 0.33 else 0
    kick = -24 * math.sin(math.pi * seg(t, 0.33, 0.5)) if 0.33 < t < 0.5 else 0
    f.spr("🍾", bx + shake, by, bs * (1 + 0.05 * a1), rot=kick, pivot=(0, 0.4))
    burst(f, seg(t, 0.36, 0.7), 210, 120, 16, 31, 10, 150, "mix", 22, gravity=70)
    if 0.36 < t < 0.5:
        u = seg(t, 0.36, 0.5)
        f.ring(208, 122, 10 + 60 * u, 6 * (1 - u) + 1, (255, 255, 255), 1 - u)
    g = eob(seg(t, 0.6, 0.74))
    clink = 8 * math.sin(TAU * t * 6) * seg(t, 0.72, 0.85) * (1 - seg(t, 0.85, 0.95))
    f.spr("🥂", 246, 216, 150 * g * fo, rot=clink)
    rain(f, t, 0.62, 1.0, 22, 12)
    if 0.72 < t < 0.9:
        u = seg(t, 0.72, 0.9)
        f.star(178, 150, 26 * math.sin(math.pi * u), (255, 255, 255))


def sc_thanks(f, t, ch="🙏"):
    """🙏 s'incline, halo doux, cœurs qui s'élèvent."""
    a1 = seg(t, 0, 0.3)
    fo = fade_out(t)
    bow = 9 * math.sin(TAU * t * 3) * seg(t, 0.2, 0.9)
    if 0.3 < t < 0.95:
        g = seg(t, 0.3, 0.45) * (1 - seg(t, 0.8, 0.95))
        glow(f, 180, 200, 100 + 25 * math.sin(TAU * t * 3), g)
    f.spr("🙏", 180, 208, 206 * pop(a1) * fo, rot=bow, pivot=(0, 0.45))
    hs = ["💛", "🧡", "❤️", "💜", "💛", "🧡"]
    for i, h in enumerate(hs):
        s0 = 0.34 + 0.08 * i
        u = seg(t, s0, s0 + 0.26)
        if 0 < u < 1:
            x = 180 + (-70 + 28 * i) * 0.9 + 12 * math.sin(u * TAU + i)
            y = 150 - 170 * eo3(u)
            f.spr(h, x, y, (40 + 10 * (i % 3)) * (0.5 + 0.7 * eob(clamp(u * 3))), alpha=1 - u ** 3)


def sc_medal(f, t, ch="🥇"):
    """🪙 tombe, rebondit en tournant, éclat puis 🥇."""
    a1, a2 = seg(t, 0, 0.33), seg(t, 0.33, 0.62)
    fo = fade_out(t)
    m = seg(t, 0.68, 0.76)
    if t < 0.33:
        y = 20 + 230 * a1 ** 2
        ang = TAU * 3 * a1
        q = 0
    elif t < 0.62:
        y = 250 - 150 * 4 * a2 * (1 - a2)
        ang = TAU * (3 + 2 * a2)
        q = clamp(1 - a2 / 0.1)
    else:
        r = eo3(seg(t, 0.62, 0.78))
        y = lerp(250, 196, r)
        ang = TAU * 5
        q = 0
    sxw = max(0.08, abs(math.cos(ang)))
    size = 140 if t < 0.62 else lerp(140, 190, eo3(seg(t, 0.62, 0.78)))
    if m < 1:
        f.spr("🪙", 180, y, size * fo, sx=sxw * (1 + 0.15 * q), sy=1 - 0.15 * q, alpha=(1 - m) * fo)
    fl = seg(t, 0.64, 0.78)
    if 0 < fl < 1:
        glow(f, 180, 196, 20 + 140 * fl, 1 - fl)
    if m > 0:
        pulse = 1 + 0.06 * math.sin(TAU * t * 4) * seg(t, 0.8, 0.9)
        f.spr("🥇", 180, 196, 224 * eob(seg(t, 0.68, 0.84)) * fo * pulse, alpha=m * fo)
    burst(f, seg(t, 0.64, 0.96), 180, 196, 10, 6, 50, 140, "star", 18,
          colors=[(255, 255, 255), (255, 226, 96)])
    if t > 0.8:
        glints(f, (t - 0.8) * 4, [(98, 110), (268, 120), (250, 280)], speed=1.2, r=24)
    # impact au sol
    imp = seg(t, 0.33, 0.42)
    if 0 < imp < 1:
        f.ring(180, 262, 20 + 60 * imp, 4, (255, 255, 255), 0.7 * (1 - imp))


def sc_fireworks(f, t, ch="🎉"):
    """🎆 part en flèche, éclate, puis 🎉."""
    a1 = seg(t, 0, 0.33)
    fo = fade_out(t)
    if t < 0.36:
        hy = lerp(300, 150, eo3(a1))
        for k in range(9):
            yk = hy + k * 13 * (1 - a1 * 0.4)
            f.circle(180 + 5 * math.sin(k + t * 30), yk, max(1.0, 8 - k * 0.8), (255, 226, 130), (1 - k / 9) * 0.9)
        f.circle(180, hy, 10, (255, 255, 255))
    u = seg(t, 0.33, 0.64)
    ex = seg(t, 0.35, 0.44) * (1 - seg(t, 0.52, 0.64))
    f.spr("🎆", 180, 160, 230 * eob(seg(t, 0.35, 0.47)) * fo, alpha=ex)
    burst(f, u, 180, 150, 20, 41, 10, 150, "mix", 20, gravity=45,
          colors=[(255, 90, 120), (255, 214, 64), (120, 230, 255), (255, 255, 255), (206, 126, 255)])
    burst(f, seg(t, 0.4, 0.7), 180, 150, 12, 42, 5, 95, "dot", 18, gravity=30,
          colors=[(255, 255, 255), (255, 214, 64)])
    g = eob(seg(t, 0.6, 0.76))
    f.spr("🎉", 180, 200, 190 * g * fo, rot=(1 - g) * 200 + 5 * math.sin(TAU * t * 6) * seg(t, 0.8, 0.9))
    rain(f, t, 0.62, 1.0, 20, 17)


SCENES = {
    "scene_love": sc_love, "scene_kiss": sc_kiss, "scene_champion": sc_champion,
    "scene_congrats": sc_congrats, "scene_goal": sc_goal, "scene_record": sc_record,
    "scene_celebrate": sc_celebrate, "scene_thanks": sc_thanks, "scene_medal": sc_medal,
    "scene_fireworks": sc_fireworks,
}

# Mouvement de chaque sticker : (catégorie, index dans le catalogue) -> mouvement
MOTION_MAP = {
    "joie": ["laugh_shake", "rock_laugh", "bounce", "pop_spin", "jelly", "float", "pulse", "dance",
             "giggle", "sway", "float", "scene_fireworks"],
    "reussite": ["scene_congrats", "clap", "scene_champion", "scene_goal", "jump_spin", "slide", "rise",
                 "scene_medal", "cheer", "tip", "flex", "scene_record", "shine", "scene_celebrate"],
    "compliments": ["heartbeat", "shine", "slide", "float", "fire_flicker", "pulse", "shine", "pop_spin",
                    "nod", "tip", "jelly", "sway"],
    "amour": ["scene_love", "jelly", "scene_kiss", "heartbeat", "float", "scene_thanks", "bounce", "shine",
              "float", "tremble"],
    "reponses": ["nod", "shake_no", "sway", "pulse", "nod", "bounce", "wave_hand", "float", "pulse",
                 "heartbeat", "turn", "walk", "slide", "sway", "pop_spin", "giggle"],
}


def render_frame(sticker, t):
    f = Frame(sticker["color"])
    m = sticker["motion"]
    if m in SCENES:
        SCENES[m](f, t)
    else:
        draw_simple(f, sticker["emoji"], m, t)
    return f.render()


def render_thumb(sticker):
    f = Frame(sticker["color"])
    f.spr(sticker["emoji"], W / 2, W / 2 + 4, SPR)
    return f.render().resize((256, 256), Image.LANCZOS)


# ------------------------------------------------------------------ encodage


def save_webp_anim(frames, path, duration):
    tried = []
    # (qualité, pas d'image conservé) : on dégrade jusqu'à passer sous 600 Ko
    for q, step in ((70, 1), (60, 1), (50, 1), (45, 2), (35, 2)):
        fr = frames[::step]
        dur = duration * step
        fr[0].save(path, save_all=True, append_images=fr[1:], duration=dur, loop=0, quality=q, method=6,
                   lossless=False, minimize_size=False)
        size = os.path.getsize(path)
        tried.append((q, step, size))
        if size <= MAX_BYTES:
            return size, dur * len(fr), q, step
    raise SystemExit("ECHEC : %s dépasse %d Ko après dégradation %s" % (path, MAX_BYTES // 1024, tried))


def save_thumb(im, path):
    for q in (80, 70, 60, 50, 40):
        im.save(path, "WEBP", quality=q, method=6)
        size = os.path.getsize(path)
        if size <= MAX_THUMB_BYTES:
            return size
    raise SystemExit("ECHEC : miniature %s > %d Ko" % (path, MAX_THUMB_BYTES // 1024))


def process(args):
    sticker, out = args
    frames = [render_frame(sticker, i / NFRAMES) for i in range(NFRAMES)]
    p = Path(out) / sticker["file"]
    size, dur, q, step = save_webp_anim(frames, p, FRAME_MS)
    if dur > MAX_DURATION_MS:
        raise SystemExit("ECHEC : %s dure %d ms" % (sticker["id"], dur))
    tsize = save_thumb(render_thumb(sticker), Path(out) / sticker["thumbFile"])
    return sticker["id"], size, dur, tsize, q, step


# ------------------------------------------------------------------ catalogue -> stickers

STOP = {"de", "du", "la", "le", "les", "un", "une", "des", "et", "a", "au", "aux", "en", "me", "te", "tu",
        "je", "il", "ton", "ta", "the", "you", "for", "of", "to", "is", "on", "my", "your", "ya", "por",
        "con", "el", "los", "las", "der", "die", "das", "ich", "dich", "fur", "da", "do", "um", "uma", "eu",
        "ni", "wa", "kwa", "st", "d", "l", "j", "t", "s", "qu"}


def build_stickers():
    data = json.load(open(CATALOG, encoding="utf-8"))
    stickers = []
    seen = set()
    order = 0
    for cat in data:
        cid = cat["category"]
        for i, it in enumerate(cat["stickers"]):
            order += 1
            fr, en = it["fr"], it["en"]
            if fr not in pack_texts.TR:
                raise SystemExit("traduction manquante : %s" % fr)
            caps = {"fr": fr, "en": en}
            for lang, txt in zip(pack_texts.EXTRA_LANGS, pack_texts.TR[fr]):
                caps[lang] = txt
            sid = "%s_%s" % (cid, slugify(fr))
            if sid in seen:
                raise SystemExit("id en double : " + sid)
            seen.add(sid)
            kws = []
            key = strip_accents(fr)
            extra = pack_texts.KW.get(key, "")
            for src in (extra, " ".join(caps[l] for l in ("fr", "en", "es", "de", "pt", "sw"))):
                for w in strip_accents(src).lower().replace("'", " ").replace(",", " ").replace("!", " ") \
                        .replace("¡", " ").replace("-", " ").split():
                    w = w.strip(".")
                    if len(w) >= 2 and w not in STOP and w not in kws:
                        kws.append(w)
            for l in ("ar", "zh"):  # pas de casse/accents : mot entier
                w = caps[l].strip()
                if w and w not in kws:
                    kws.append(w)
            motion = MOTION_MAP[cid][i]
            stickers.append({
                "id": sid, "category": cid, "order": order, "emoji": it["emoji"], "motion": motion,
                "captions": caps, "keywords": kws,
                "file": sid + ".webp", "thumbFile": sid + "_thumb.webp",
                "color": CAT_COLORS[cid][i],
            })
    return stickers


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.environ.get("PACK_OUT") or str(HERE / "pack_out"))
    ap.add_argument("--only", default="", help="ids séparés par des virgules (test)")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    stickers = build_stickers()
    if len(stickers) != 64:
        raise SystemExit("le pack doit contenir 64 stickers, trouvé %d" % len(stickers))
    todo = [s for s in stickers if not a.only or s["id"] in a.only.split(",")]
    with Pool(max(1, a.jobs)) as pool:
        res = {r[0]: r for r in pool.map(process, [(s, str(out)) for s in todo])}
    if a.only:
        print("Mode --only : pack_index.json non réécrit.", len(res), "stickers générés.")
        return
    index = []
    for s in stickers:
        _, size, dur, tsize, q, step = res[s["id"]]
        index.append({
            "id": s["id"], "category": s["category"], "order": s["order"], "emoji": s["emoji"],
            "motion": s["motion"], "captions": s["captions"], "keywords": s["keywords"],
            "file": s["file"], "thumbFile": s["thumbFile"], "sizeBytes": size, "durationMs": dur,
            "giftPriceCoins": 0,
        })
    json.dump(index, open(INDEX_PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    sizes = [r[1] for r in res.values()]
    print("OK %d stickers -> %s" % (len(sizes), out))
    print("poids Ko : min %.1f / moyen %.1f / max %.1f" % (min(sizes) / 1024, sum(sizes) / len(sizes) / 1024,
                                                           max(sizes) / 1024))
    degraded = [r[0] for r in res.values() if r[4] != 70 or r[5] != 1]
    if degraded:
        print("qualité/fréquence dégradées pour :", ", ".join(degraded))
    print("index :", INDEX_PATH)


if __name__ == "__main__":
    main()
