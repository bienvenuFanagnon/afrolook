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
S = {
 'hook': ('Voilà comment la plupart\ndes gens font leurs affiches IA…', 'This is how most people\nmake AI posters…'),
 'try': ('Essai', 'Try'), 'meh': ('Bof…', 'Meh…'), 'still': ('Toujours pas ça', 'Still not right'),
 'p1': ('fais une belle affiche pour ma crème', 'make a nice poster for my cream'),
 'p2': ('Plus pro, fond plus joli, meilleure lumière, enlève la plante, mets du texte, plus de contraste…', 'More professional, nicer background, better light, remove the plant, add text, more contrast…'),
 'p3': ('Tu es un directeur artistique. Refais l’image avec un halo de lumière doux, un fond sombre dégradé, une ombre naturelle, garde les couleurs exactes du produit, ajoute de l’espace pour le titre, style magazine, haute qualité, 4:5…', 'You are an art director. Redo the image with a soft glow, dark gradient background, natural shadow, keep the exact product colors, leave room for a title, magazine style, high quality, 4:5…'),
 'faster': ('Il y a plus rapide.', 'There is a faster way.'),
 'ready': ('Prompts prêts à l’emploi', 'Ready-made prompts'), 'copy': ('Copier', 'Copy'), 'copied': ('Copié', 'Copied'), 'gen': ('Générer ici', 'Generate here'),
 'done': ('Terminé.', 'Done.'), 'secs': ('20 secondes', '20 seconds'),
 'testit': ('Testez-les sur notre plateforme ou dans', 'Test them on our platform or in'),
 'free': ('commandes gratuites', 'free commands'),
 'tryfree': ('Essayez gratuitement', 'Try it free'), 'nosign': ('Sans inscription', 'No sign-up needed'), 'ai': ('Illustration · visuels générés par IA', 'Illustration · AI-generated visuals'),
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
