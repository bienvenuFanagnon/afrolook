"""Prépare les visuels générés (JPEG de 900 px et plus) pour le site : WebP léger, 3 tailles.
Usage : python3 scripts/optimize_images.py <dossier>[:<dossier>…] (le dernier dossier qui contient un slug l'emporte)
Sortie : static/img/c/<slug>-apres.webp (1280 px), <slug>-t.webp (720 px, vignettes) et <slug>-avant.webp (640 px)."""
import sys, os
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, '..', 'static', 'img', 'c')
os.makedirs(out, exist_ok=True)
found = {}
for d in sys.argv[1].split(':'):
    for f in os.listdir(d):
        if f.endswith('-apres.jpg') or f.endswith('-apres.png'):
            slug = f.rsplit('-apres', 1)[0]
            ext = f.rsplit('.', 1)[1]
            if os.path.exists(os.path.join(d, f'{slug}-avant.{ext}')):
                found[slug] = (d, ext)
def save(im, name, w, q):
    im = im.convert('RGB')
    if im.width > w:
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    im.save(os.path.join(out, name), 'WEBP', quality=q, method=6)
for slug, (d, ext) in sorted(found.items()):
    a = Image.open(os.path.join(d, f'{slug}-apres.{ext}'))
    b = Image.open(os.path.join(d, f'{slug}-avant.{ext}'))
    save(a, f'{slug}-apres.webp', 1280, 90)
    save(a, f'{slug}-t.webp', 720, 86)
    save(b, f'{slug}-avant.webp', 640, 84)
    print(slug, a.size)
