#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère le pack officiel « Cadeaux Afrolook » : 10 stickers-cadeaux WebP animés payants à l'envoi.

Réutilise gen_pack.py (Frame, sprites emoji Noto, encodage WebP, scènes sc_love / sc_champion /
sc_record / sc_fireworks...) et y ajoute des scènes plus riches en 3 temps (2,4 s, boucle, 360x360,
<= 600 Ko) sur une pastille violette à contour DORÉ, distincte du pack universel. Aucun texte dans l'image.

Sortie : <out>/{id}.webp, <out>/{id}_thumb.webp  puis tools/stickers/gift_index.json
(même format que pack_index.json, avec giftPriceCoins > 0 et category 'afrolook').

Usage :
  python3 tools/stickers/gen_gifts.py [--out DOSSIER] [--only id1,id2] [--jobs N]
Par défaut : $GIFT_OUT ou tools/stickers/gift_out (ignoré par git : préférez --out hors dépôt).
Tout sticker > 600 Ko fait échouer le script.
"""
import argparse
import json
import math
import os
import random
import sys
from multiprocessing import Pool
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import gen_pack as g  # noqa: E402

W = g.W
TAU = g.TAU
seg, eo3, ei3, eio, eob, lerp, clamp = g.seg, g.eo3, g.ei3, g.eio, g.eob, g.lerp, g.clamp
GIFT_INDEX = HERE / "gift_index.json"
DEFAULT_OUT = os.environ.get("GIFT_OUT") or str(HERE / "gift_out")

GOLD = [(255, 255, 255), (255, 226, 110), (255, 196, 50), (255, 240, 170)]
GOLD_PINK = [(255, 255, 255), (255, 226, 110), (255, 170, 220), (206, 126, 255)]

# ------------------------------------------------------------------ pastille dorée/violette

GIFT_PALETTES = {
    "royal": ((176, 116, 255), (86, 34, 176)),
    "amethyst": ((214, 120, 246), (118, 36, 168)),
    "night": ((132, 96, 236), (56, 28, 136)),
    "plum": ((196, 96, 226), (96, 30, 140)),
}
GOLD_EDGE = ((255, 240, 160), (226, 158, 24))
_gift_cache = {}


def gift_pastille(color):
    """Pastille violette à liseré doré (au lieu du contour blanc du pack universel)."""
    if color in _gift_cache:
        return _gift_cache[color]
    k = 4
    top, bot = GIFT_PALETTES[color]
    big = W * k
    outer = Image.new("L", (big, big), 0)
    ImageDraw.Draw(outer).rounded_rectangle((6 * k, 6 * k, (W - 6) * k, (W - 6) * k), radius=98 * k, fill=255)
    inner = Image.new("L", (big, big), 0)
    ImageDraw.Draw(inner).rounded_rectangle((18 * k, 18 * k, (W - 18) * k, (W - 18) * k), radius=86 * k, fill=255)
    outer = outer.resize((W, W), Image.LANCZOS)
    inner = inner.resize((W, W), Image.LANCZOS)

    def vgrad(a, b, diag=False):
        im = Image.new("RGB", (W, W))
        d = ImageDraw.Draw(im)
        for y in range(W):
            u = y / (W - 1)
            d.line((0, y, W, y), fill=tuple(int(lerp(a[i], b[i], u)) for i in range(3)))
        return im

    edge = vgrad(*GOLD_EDGE).convert("RGBA")
    fill = vgrad(top, bot).convert("RGBA")
    # halo clair au centre pour faire ressortir le sujet
    halo = Image.radial_gradient("L").resize((W, W), Image.BICUBIC).point(lambda v: int(70 * clamp((170 - v) / 170)))
    fill = Image.composite(Image.new("RGBA", (W, W), (255, 240, 255, 255)), fill, halo)
    base = Image.composite(edge, Image.new("RGBA", (W, W), (0, 0, 0, 0)), outer)
    base = Image.composite(fill, base, inner)
    base.putalpha(outer)
    _gift_cache[color] = (base, inner)
    return base, inner


g.pastille = gift_pastille  # Frame.__init__ résout `pastille` dans le module gen_pack

# ------------------------------------------------------------------ briques d'effets


def twinkle(f, t):
    """Petites étoiles dorées discrètes en fond (signature « cadeau »)."""
    for i, (x, y) in enumerate(((60, 74), (300, 66), (326, 190), (40, 214), (84, 314), (286, 312), (180, 40))):
        u = (t * 2 + i * 0.31) % 1.0
        k = math.sin(math.pi * u) ** 2
        f.star(x, y, 4 + 8 * k, (255, 226, 110), 0.25 + 0.5 * k, rot=k * 45)


def gold_rain(f, t, t0, t1, n, seed, colors=GOLD):
    u = seg(t, t0, t1)
    if u <= 0:
        return
    rng = random.Random(seed)
    for i in range(n):
        d = rng.uniform(0, 0.4)
        x0 = rng.uniform(30, 330)
        ph = rng.uniform(0, TAU)
        w = (u - d) / 0.6
        spin = rng.uniform(-2, 2)
        if 0 < w < 1:
            y = -20 + 400 * (w ** 1.15)
            x = x0 + 14 * math.sin(w * TAU * 1.5 + ph)
            if i % 3 == 0:
                f.star(x, y, 9, colors[i % len(colors)], 0.95, rot=w * 180 * spin)
            else:
                f.piece(x, y, 6.5, 3.2, w * 360 * spin, colors[i % len(colors)])


def orbit_glints(f, t, cx, cy, rad, n, r, speed=1.0, alpha=1.0):
    for i in range(n):
        ang = TAU * (t * speed + i / n)
        u = (t * 2 + i * 0.37) % 1.0
        k = math.sin(math.pi * u) ** 2
        f.star(cx + math.cos(ang) * rad, cy + math.sin(ang) * rad * 0.85, r * k, (255, 255, 255),
               min(1, k * 1.4) * alpha, rot=k * 60)


def shock(f, t, t0, t1, cx, cy, rmax=140, col=(255, 236, 150)):
    u = seg(t, t0, t1)
    if 0 < u < 1:
        f.ring(cx, cy, 16 + rmax * eo3(u), 9 * (1 - u) + 1, col, 1 - u)


def pop_in(a, base=0.55):
    """Apparition en rebond partant d'une échelle lisible ; retombe à `base` en fin de boucle."""
    return base + (1 - base) * eob(a)


def end_shrink(t, base=0.55):
    return 1 - (1 - base) * eio(seg(t, 0.9, 1))


# ------------------------------------------------------------------ scènes (3 temps)


def sc_crown(f, t):
    """Acte 1 : la couronne tombe et rebondit. Acte 2 : elle brille, étincelles en orbite. Acte 3 : gerbe d'or."""
    a1, a2 = seg(t, 0, 0.33), seg(t, 0.33, 0.62)
    fin = seg(t, 0.9, 1)
    k = pop_in(a1) * end_shrink(t)
    y = 200 - 130 * (1 - eob(a1)) - 100 * eio(fin)
    rot = -22 * (1 - eo3(a1)) + 6 * math.sin(TAU * t * 3) * seg(t, 0.36, 0.7) * (1 - fin) - 22 * eio(fin) * 0
    if 0.3 < t < 0.92:
        gl = seg(t, 0.3, 0.45) * (1 - seg(t, 0.8, 0.92))
        g.glow(f, 180, 190, 100 + 18 * math.sin(TAU * t * 4), gl * 0.85)
    shock(f, t, 0.3, 0.46, 180, 262, 150)
    f.spr("👑", 180, y, 222 * k, rot=rot, pivot=(0, 0.4))
    if 0.36 < t < 0.95:
        orbit_glints(f, t, 180, 190, 118, 6, 30, speed=0.8)
    g.burst(f, seg(t, 0.62, 0.98), 180, 150, 14, 71, 40, 150, "star", 19, colors=GOLD)
    g.burst(f, seg(t, 0.66, 1.0), 180, 150, 10, 72, 30, 120, "dot", 16, gravity=40, colors=GOLD)
    for i, (dx, ch) in enumerate(((-84, "💎"), (0, "✨"), (84, "💎"))):
        u = seg(t, 0.64 + 0.05 * i, 0.9 + 0.05 * i)
        if 0 < u < 1:
            f.spr(ch, 180 + dx + 10 * math.sin(u * TAU), 130 - 90 * eo3(u), 46 * (0.6 + 0.6 * eob(clamp(u * 3))),
                  alpha=1 - u ** 3, rot=20 * math.sin(u * TAU))
    gold_rain(f, t, 0.66, 1.0, 16, 73)


def sc_heart(f, t):
    """Deux cœurs fusionnent puis explosent (sc_love) ; anneaux et pluie d'or en plus."""
    g.sc_love(f, t)
    shock(f, t, 0.56, 0.72, 180, 188, 150, (255, 210, 240))
    shock(f, t, 0.6, 0.78, 180, 188, 110, (255, 255, 255))
    gold_rain(f, t, 0.72, 1.0, 12, 74, GOLD_PINK)
    if t > 0.7:
        orbit_glints(f, t, 180, 188, 128, 5, 26, speed=-0.5, alpha=seg(t, 0.7, 0.8))


def sc_bravo(f, t):
    """Les mains applaudissent sur un rythme, chaque claquement lance anneau et étincelles."""
    a1 = seg(t, 0, 0.3)
    beats = [0.30, 0.38, 0.46, 0.60, 0.67, 0.74, 0.86]
    env = 0.0
    for bt in beats:
        env += math.sin(math.pi * seg(t, bt, bt + 0.075))
    env = min(1.0, env)
    k = pop_in(a1) * end_shrink(t)
    if 0.28 < t < 0.94:
        g.glow(f, 180, 195, 90 + 24 * env, 0.6 * seg(t, 0.28, 0.36) * (1 - seg(t, 0.84, 0.94)))
    for i, bt in enumerate(beats):
        g.burst(f, seg(t, bt, bt + 0.16), 180, 190, 8, 30 + i, 60, 140, "star", 16,
                colors=GOLD if i % 2 == 0 else GOLD_PINK)
        shock(f, t, bt, bt + 0.13, 180, 190, 100, (255, 255, 255))
    f.spr("👏", 180, 198 - 10 * env, 214 * k * (1 + 0.16 * env), rot=-7 * env * math.sin(TAU * t * 8) + 4 * (1 - eo3(a1)))
    for i, (x, y, ch) in enumerate(((76, 100, "👏"), (288, 104, "👏"), (296, 262, "👏"), (66, 266, "👏"))):
        u = seg(t, 0.5 + 0.09 * i, 0.72 + 0.09 * i)
        if 0 < u < 1:
            f.spr(ch, x, y - 34 * u, 62 * math.sin(math.pi * u) ** 0.5, alpha=1 - u ** 2,
                  rot=(-1) ** i * 16 * math.sin(u * TAU * 2))
    gold_rain(f, t, 0.62, 1.0, 20, 75, g.CONF_COLORS)


def sc_trophy(f, t):
    """Coupe qui surgit et brille (sc_champion) + couronne de petites étoiles dorées."""
    g.sc_champion(f, t)
    shock(f, t, 0.3, 0.46, 180, 262, 150)
    if t > 0.5:
        orbit_glints(f, t, 180, 190, 120, 5, 24, speed=0.6, alpha=seg(t, 0.5, 0.6) * (1 - seg(t, 0.9, 1)))


def sc_rocket(f, t):
    """La fusée décolle et éclate en étoiles (sc_record) ; traînée d'étincelles dorées en plus."""
    g.sc_record(f, t)
    if 0.3 < t < 0.6:
        u = seg(t, 0.3, 0.6)
        for i in range(5):
            uu = (u * 3 + i * 0.2) % 1.0
            f.star(lerp(108, 196, u) - 30 - 30 * uu, lerp(262, 176, u) + 34 + 40 * uu, 12 * (1 - uu), GOLD[i % 4], 1 - uu)
    shock(f, t, 0.58, 0.74, 182, 182, 150)
    gold_rain(f, t, 0.72, 1.0, 12, 76)


def sc_bouquet(f, t):
    """Le bouquet monte, les fleurs éclosent tout autour, puis les pétales s'envolent."""
    a1 = seg(t, 0, 0.33)
    fin = seg(t, 0.9, 1)
    k = pop_in(a1) * end_shrink(t)
    sway = 5 * math.sin(TAU * t * 2) * seg(t, 0.3, 0.9) * (1 - fin)
    if 0.33 < t < 0.9:
        g.glow(f, 180, 190, 96 + 14 * math.sin(TAU * t * 3), seg(t, 0.33, 0.45) * (1 - seg(t, 0.8, 0.9)) * 0.7)
    f.spr("💐", 180, 206 + 90 * (1 - eob(a1)) * 0.6 - 50 * eio(fin) * 0, 220 * k, rot=sway, pivot=(0, 0.45))
    spots = [(78, 112, "🌸"), (282, 108, "🌷"), (62, 232, "🌺"), (300, 232, "🌹"), (180, 62, "🌼")]
    for i, (x, y, ch) in enumerate(spots):
        s0 = 0.34 + 0.05 * i
        b = eob(seg(t, s0, s0 + 0.14))
        gone = seg(t, 0.7 + 0.03 * i, 0.98)
        if b > 0 and gone < 1:
            f.spr(ch, x, y - 30 * eo3(gone), 74 * b * (1 - 0.5 * gone), rot=(1 - b) * -120 + 10 * math.sin(TAU * t * 3 + i),
                  alpha=1 - gone ** 2)
        shock(f, t, s0, s0 + 0.12, x, y, 40, (255, 255, 255))
    # pétales emportés par le vent
    rng = random.Random(9)
    cols = [(255, 190, 215), (255, 150, 190), (255, 255, 255), (255, 220, 120)]
    for i in range(22):
        s0 = 0.62 + rng.uniform(0, 0.18)
        u = seg(t, s0, s0 + 0.34)
        if 0 < u < 1:
            x0, y0 = rng.uniform(70, 290), rng.uniform(110, 240)
            x = x0 + 150 * u * rng.uniform(0.4, 1) + 20 * math.sin(u * TAU * 1.5 + i)
            y = y0 - 110 * u * rng.uniform(0.3, 1) + 30 * math.sin(u * TAU + i)
            f.piece(x, y, 8, 4.5, u * 540 * rng.uniform(-1, 1), cols[i % 4], 1 - u ** 2)
    g.glints(f, t, [(88, 96), (272, 92), (290, 250), (70, 258)], speed=1.5, r=26)


def sc_fireworks_gift(f, t):
    """Feu d'artifice (sc_fireworks) + deux gerbes supplémentaires décalées."""
    g.sc_fireworks(f, t)
    g.burst(f, seg(t, 0.44, 0.78), 96, 118, 12, 81, 8, 80, "star", 16, gravity=40,
            colors=[(255, 214, 64), (255, 255, 255), (255, 120, 170)])
    g.burst(f, seg(t, 0.5, 0.84), 266, 110, 12, 82, 8, 84, "star", 16, gravity=40,
            colors=[(120, 230, 255), (255, 255, 255), (206, 126, 255)])
    shock(f, t, 0.34, 0.5, 180, 150, 150, (255, 255, 255))


def sc_diamond(f, t):
    """Le diamant tourne et se pose, éclats de lumière en croix, puis gerbe de cristaux."""
    a1 = seg(t, 0, 0.33)
    fin = seg(t, 0.9, 1)
    k = pop_in(a1) * end_shrink(t)
    ang = TAU * 2 * eo3(a1)
    sxw = max(0.14, abs(math.cos(ang)))
    y = 200 - 130 * (1 - eob(a1)) - 90 * eio(fin)
    pulse = 1 + 0.05 * math.sin(TAU * t * 4) * seg(t, 0.62, 0.9)
    if 0.3 < t < 0.94:
        g.glow(f, 180, 195, 100 + 20 * math.sin(TAU * t * 5), seg(t, 0.3, 0.42) * (1 - seg(t, 0.85, 0.94)) * 0.8)
    shock(f, t, 0.3, 0.46, 180, 262, 150, (200, 240, 255))
    f.spr("💎", 180, y, 216 * k * pulse, sx=sxw)
    # éclats en croix qui balayent les facettes
    for i, (x, yy) in enumerate(((132, 150), (232, 176), (170, 236))):
        s0 = 0.36 + 0.09 * i
        u = seg(t, s0, s0 + 0.16)
        if 0 < u < 1:
            r = 70 * math.sin(math.pi * u)
            f.star(x, yy, r, (255, 255, 255), 1.0, rot=0)
            f.star(x, yy, r * 0.55, (200, 236, 255), 0.9, rot=45)
    ccols = [(255, 255, 255), (170, 226, 255), (222, 190, 255), (255, 226, 110)]
    g.burst(f, seg(t, 0.62, 0.98), 180, 186, 16, 91, 50, 155, "star", 20, colors=ccols)
    g.burst(f, seg(t, 0.66, 1.0), 180, 186, 10, 92, 30, 125, "dot", 15, colors=ccols)
    for i, ang2 in enumerate((-140, -40, 40, 140)):
        u = seg(t, 0.64, 0.92)
        if 0 < u < 1:
            r = 60 + 100 * eo3(u)
            f.spr("💎", 180 + math.cos(math.radians(ang2)) * r, 186 + math.sin(math.radians(ang2)) * r, 42 * (1 - 0.4 * u),
                  alpha=1 - u ** 2, rot=u * 200)
    if t > 0.7:
        orbit_glints(f, t, 180, 190, 122, 5, 26, speed=0.5, alpha=seg(t, 0.7, 0.78) * (1 - fin))


def sc_ingot(f, t):
    """Des pièces pleuvent et rebondissent, la médaille d'or surgit, puis tout brille."""
    fin = seg(t, 0.9, 1)
    rng = random.Random(5)
    n = 10
    for i in range(n):
        s0 = -0.16 + 0.4 * (i / n) + rng.uniform(-0.02, 0.02)
        x = rng.uniform(56, 304)
        land = 246 + rng.uniform(-10, 22)
        w = (t - s0) / 0.24
        fade = 1 - seg(t, 0.62 + 0.02 * (i % 4), 0.8)
        if w <= 0 or fade <= 0:
            continue
        if w < 1:
            y = -30 + (land + 30) * w * w
            ang = TAU * (2 + rng.uniform(0, 1)) * w
        else:
            b = clamp((w - 1) / 0.5)
            y = land - 36 * 4 * b * (1 - b) if b < 1 else land
            ang = TAU * 2.5
        f.spr("🪙", x, y, 84, sx=max(0.15, abs(math.cos(ang))), alpha=fade)
    a2 = seg(t, 0.36, 0.66)
    k = eob(a2) * end_shrink(t, 0.5)
    if a2 > 0:
        fl = seg(t, 0.36, 0.5)
        if 0 < fl < 1:
            g.glow(f, 180, 190, 20 + 160 * fl, 1 - fl)
        if t > 0.5:
            g.glow(f, 180, 190, 96 + 16 * math.sin(TAU * t * 4), seg(t, 0.5, 0.62) * (1 - seg(t, 0.85, 0.95)) * 0.7)
        shock(f, t, 0.38, 0.56, 180, 190, 150)
        f.spr("🥇", 180, 196 - 10 * math.sin(math.pi * a2), 226 * k * (1 + 0.05 * math.sin(TAU * t * 4) * seg(t, 0.7, 0.9)),
              rot=(1 - eo3(a2)) * -25)
    g.burst(f, seg(t, 0.4, 0.8), 180, 192, 12, 51, 60, 150, "star", 18, colors=GOLD)
    if t > 0.62:
        orbit_glints(f, t, 180, 192, 118, 5, 30, speed=0.7, alpha=seg(t, 0.62, 0.7) * (1 - fin))
        g.glints(f, t, [(78, 110), (290, 120), (270, 282), (90, 270)], speed=1.4, r=26)
    gold_rain(f, t, 0.66, 1.0, 12, 52)


def sc_surprise(f, t):
    """Le paquet tremble, s'ouvre dans un flash, étincelles et confettis jaillissent."""
    a1 = seg(t, 0, 0.33)
    fin = seg(t, 0.9, 1)
    k = pop_in(seg(t, 0, 0.12)) * end_shrink(t)
    if t < 0.4:
        amp = a1 ** 1.5
        dx = 9 * amp * math.sin(TAU * t * 16)
        rot = 9 * amp * math.sin(TAU * t * 13 + 1)
        sq = 1 + 0.06 * amp * math.sin(TAU * t * 9)
        y = 204
    else:
        a2 = seg(t, 0.4, 0.62)
        dx = 0
        rot = 10 * math.sin(math.pi * a2) * -1 + 3 * math.sin(TAU * t * 5) * seg(t, 0.62, 0.9)
        hop = math.sin(math.pi * seg(t, 0.36, 0.56))
        sq = 1 + 0.1 * math.sin(TAU * seg(t, 0.55, 0.75) * 1.5) * (1 - seg(t, 0.75, 0.8)) - 0.1 * hop * 0
        y = 204 - 46 * hop + 6 * math.sin(TAU * t * 3) * seg(t, 0.7, 0.9)
    fl = seg(t, 0.5, 0.62)
    if 0 < fl < 1:
        g.glow(f, 180, 170, 20 + 170 * fl, 1 - fl)
    shock(f, t, 0.5, 0.68, 180, 175, 150, (255, 255, 255))
    if t > 0.42:
        g.glow(f, 180, 190, 80 + 14 * math.sin(TAU * t * 4), seg(t, 0.56, 0.7) * (1 - seg(t, 0.8, 0.92)) * 0.5)
    f.spr("🎁", 180 + dx, y + 4, 200 * k * sq, rot=rot, pivot=(0, 0.45), sy=1 / sq)
    # gerbe d'objets qui jaillissent du paquet
    for i, (ch, ang, sz) in enumerate((("🎊", -125, 56), ("✨", -95, 52), ("🎉", -65, 58), ("⭐", -150, 44), ("🌟", -30, 46),
                                       ("🎀", -110, 44))):
        s0 = 0.5 + 0.02 * i
        u = seg(t, s0, s0 + 0.36)
        if 0 < u < 1:
            r = 40 + 130 * eo3(u)
            x = 180 + math.cos(math.radians(ang)) * r
            yy = 150 + math.sin(math.radians(ang)) * r * 1.05 + 70 * u * u
            f.spr(ch, x, yy, sz * (0.5 + 0.6 * eob(clamp(u * 3))), alpha=1 - u ** 3, rot=u * 240 * (-1) ** i)
    g.burst(f, seg(t, 0.5, 0.86), 180, 165, 22, 61, 20, 155, "mix", 22, gravity=70)
    g.burst(f, seg(t, 0.54, 0.92), 180, 165, 12, 62, 20, 120, "star", 18, colors=GOLD)
    g.rain(f, t, 0.62, 1.0, 22, 63)
    if t > 0.75:
        g.glints(f, t, [(80, 100), (286, 110), (276, 282), (84, 274)], speed=1.5, r=26)


# id, emoji miniature, scène, prix, pastille
GIFTS = [
    ("cadeau_couronne", "👑", "scene_gift_couronne", sc_crown, 20, "royal"),
    ("cadeau_coeur_explose", "❤️", "scene_gift_coeur", sc_heart, 20, "plum"),
    ("cadeau_bravo", "👏", "scene_gift_bravo", sc_bravo, 20, "night"),
    ("cadeau_coupe", "🏆", "scene_gift_coupe", sc_trophy, 50, "amethyst"),
    ("cadeau_fusee", "🚀", "scene_gift_fusee", sc_rocket, 50, "night"),
    ("cadeau_bouquet", "💐", "scene_gift_bouquet", sc_bouquet, 50, "plum"),
    ("cadeau_feu_artifice", "🎆", "scene_gift_feu_artifice", sc_fireworks_gift, 100, "night"),
    ("cadeau_diamant", "💎", "scene_gift_diamant", sc_diamond, 100, "royal"),
    ("cadeau_lingot_or", "🥇", "scene_gift_lingot", sc_ingot, 100, "amethyst"),
    ("cadeau_surprise", "🎁", "scene_gift_surprise", sc_surprise, 100, "royal"),
]
SCENE_FN = {m: fn for _, _, m, fn, _, _ in GIFTS}

# légendes fr, en, es, de, ar, pt, zh, sw
CAPTIONS = {
    "cadeau_couronne": ("Couronne", "Crown", "Corona", "Krone", "تاج", "Coroa", "皇冠", "Taji"),
    "cadeau_coeur_explose": ("Cœur qui explose", "Exploding heart", "Corazón que explota", "Explodierendes Herz",
                             "قلب ينفجر", "Coração explodindo", "爆炸的心", "Moyo unaolipuka"),
    "cadeau_bravo": ("Bravo", "Bravo", "¡Bravo!", "Bravo", "أحسنت", "Bravo", "太棒了", "Vizuri sana"),
    "cadeau_coupe": ("Coupe", "Trophy", "Trofeo", "Pokal", "كأس", "Troféu", "奖杯", "Kombe"),
    "cadeau_fusee": ("Fusée", "Rocket", "Cohete", "Rakete", "صاروخ", "Foguete", "火箭", "Roketi"),
    "cadeau_bouquet": ("Bouquet", "Bouquet", "Ramo de flores", "Blumenstrauß", "باقة ورد", "Buquê", "花束", "Shada la maua"),
    "cadeau_feu_artifice": ("Feu d'artifice", "Fireworks", "Fuegos artificiales", "Feuerwerk", "ألعاب نارية",
                            "Fogos de artifício", "烟花", "Fataki"),
    "cadeau_diamant": ("Diamant", "Diamond", "Diamante", "Diamant", "ألماس", "Diamante", "钻石", "Almasi"),
    "cadeau_lingot_or": ("Lingot d'or", "Gold bar", "Lingote de oro", "Goldbarren", "سبيكة ذهب", "Barra de ouro",
                         "金条", "Dhahabu safi"),
    "cadeau_surprise": ("Cadeau surprise", "Surprise gift", "Regalo sorpresa", "Überraschungsgeschenk", "هدية مفاجأة",
                        "Presente surpresa", "惊喜礼物", "Zawadi ya kushtukiza"),
}
LANGS = ["fr", "en", "es", "de", "ar", "pt", "zh", "sw"]

# mots-clés : minuscules sans accents ; ar/zh en mots entiers
KEYWORDS = {
    "cadeau_couronne": "cadeau gift regalo geschenk presente zawadi couronne crown corona krone coroa taji roi reine king queen rey reina konig konigin rei rainha mfalme malkia royal royaute realeza 皇冠 تاج",
    "cadeau_coeur_explose": "cadeau gift regalo geschenk presente zawadi coeur heart corazon herz coracao moyo explose explosion exploding explota explodiert explodindo unaolipuka amour love amor liebe upendo 爆炸的心 قلب ينفجر",
    "cadeau_bravo": "cadeau gift regalo geschenk presente zawadi bravo applaudir applaudissements applause clap aplauso applaus aplausos makofi hongera vizuri felicitations 太棒了 أحسنت",
    "cadeau_coupe": "cadeau gift regalo geschenk presente zawadi coupe trophee trophy trofeo pokal troféu troféu kombe champion victoire victory victoria sieg vitoria ushindi 奖杯 كأس",
    "cadeau_fusee": "cadeau gift regalo geschenk presente zawadi fusee rocket cohete rakete foguete roketi decollage espace space espacio weltraum espaco anga 火箭 صاروخ",
    "cadeau_bouquet": "cadeau gift regalo geschenk presente zawadi bouquet fleurs flowers flores blumen blumenstrauss ramo buque maua shada rose roses 花束 باقة ورد",
    "cadeau_feu_artifice": "cadeau gift regalo geschenk presente zawadi feu artifice fireworks fuegos artificiales feuerwerk fogos fataki fete party fiesta festa sherehe 烟花 ألعاب نارية",
    "cadeau_diamant": "cadeau gift regalo geschenk presente zawadi diamant diamond diamante almasi bijou joyau gem jewel joya juwel brillant luxe luxury lujo luxo 钻石 ألماس",
    "cadeau_lingot_or": "cadeau gift regalo geschenk presente zawadi lingot or gold oro ouro dhahabu goldbarren barra lingote riche rich rico reich tajiri argent money dinero geld dinheiro pesa fortune 金条 سبيكة ذهب",
    "cadeau_surprise": "cadeau gift regalo geschenk presente zawadi surprise sorpresa uberraschung surpresa paquet package paket pacote kushtukiza anniversaire birthday cumpleanos geburtstag aniversario siku ya kuzaliwa 惊喜礼物 هدية مفاجأة",
}


def build_gifts():
    prev = json.load(open(HERE / "pack_index.json", encoding="utf-8"))
    taken = {s["id"] for s in prev}
    out = []
    for order, (sid, emoji, motion, _fn, price, color) in enumerate(GIFTS, 1):
        if sid in taken:
            raise SystemExit("collision d'id avec le pack universel : " + sid)
        caps = dict(zip(LANGS, CAPTIONS[sid]))
        kws = []
        for w in KEYWORDS[sid].split():
            w = w if any(ord(c) > 0x590 for c in w) else g.strip_accents(w).lower()
            if len(w) >= 2 and w not in kws:
                kws.append(w)
        for l in ("fr", "en", "es", "de", "pt", "sw"):
            for w in g.strip_accents(caps[l]).lower().replace("'", " ").replace("!", " ").replace("¡", " ").split():
                if len(w) >= 3 and w not in g.STOP and w not in kws:
                    kws.append(w)
        out.append({"id": sid, "category": "afrolook", "order": order, "emoji": emoji, "motion": motion,
                    "captions": caps, "keywords": kws, "file": sid + ".webp", "thumbFile": sid + "_thumb.webp",
                    "color": color, "giftPriceCoins": price})
    return out


def render_frame(sticker, t):
    f = g.Frame(sticker["color"])
    twinkle(f, t)
    SCENE_FN[sticker["motion"]](f, t)
    return f.render()


def process(args):
    sticker, out = args
    frames = [render_frame(sticker, i / g.NFRAMES) for i in range(g.NFRAMES)]
    p = Path(out) / sticker["file"]
    size, dur, q, step = g.save_webp_anim(frames, p, g.FRAME_MS)  # SystemExit si > 600 Ko
    if size > g.MAX_BYTES:
        raise SystemExit("ECHEC : %s pèse %d octets" % (sticker["id"], size))
    if dur > g.MAX_DURATION_MS:
        raise SystemExit("ECHEC : %s dure %d ms" % (sticker["id"], dur))
    tsize = g.save_thumb(g.render_thumb(sticker), Path(out) / sticker["thumbFile"])
    return sticker["id"], size, dur, tsize, q, step


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--only", default="", help="ids séparés par des virgules (test)")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    stickers = build_gifts()
    todo = [s for s in stickers if not a.only or s["id"] in a.only.split(",")]
    with Pool(max(1, a.jobs)) as pool:
        res = {r[0]: r for r in pool.map(process, [(s, str(out)) for s in todo])}
    if a.only:
        print("Mode --only : gift_index.json non réécrit.", len(res), "stickers générés.")
        return
    index = []
    for s in stickers:
        _, size, dur, tsize, q, step = res[s["id"]]
        index.append({
            "id": s["id"], "category": s["category"], "order": s["order"], "emoji": s["emoji"],
            "motion": s["motion"], "captions": s["captions"], "keywords": s["keywords"],
            "file": s["file"], "thumbFile": s["thumbFile"], "sizeBytes": size, "durationMs": dur,
            "giftPriceCoins": s["giftPriceCoins"],
        })
    json.dump(index, open(GIFT_INDEX, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    sizes = [r[1] for r in res.values()]
    print("OK %d stickers -> %s" % (len(sizes), out))
    print("poids Ko : min %.1f / moyen %.1f / max %.1f" % (min(sizes) / 1024, sum(sizes) / len(sizes) / 1024,
                                                           max(sizes) / 1024))
    degraded = [r[0] for r in res.values() if r[4] != 70 or r[5] != 1]
    if degraded:
        print("qualité/fréquence dégradées pour :", ", ".join(degraded))
    print("index :", GIFT_INDEX)


if __name__ == "__main__":
    main()
