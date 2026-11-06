# -*- coding: utf-8 -*-
# Génère pour le site : site/src/screens.mjs (HTML des 8 écrans fr/en), site/static/css/screens.css, site/static/img/people/*.webp
# Écrans : A cadeau sur un post, B cadeau en live, C vente en direct, E fil, F détail, G vidéo, H audio, I image avec texte (le portefeuille est retiré).
import os, re, subprocess, json
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
ns = {'__file__': os.path.join(HERE, '_v3_build.py')}
exec(open('_v3_build.py', encoding='utf-8').read(), ns)
S, CSS = ns['S'], ns['CSS']
SITE = os.path.abspath(os.path.join(HERE, '..', '..', 'site'))

ORDER = ['E', 'A', 'G', 'F', 'B', 'H', 'C', 'I']   # fil, cadeau post, vidéo, détail, cadeau live, audio, vente, image + texte
CAP = {
 'E': ('Le fil et les chroniques', 'Le fil, les chroniques de 24 h et le bouton Cadeau sous chaque publication.', 'The feed and chronicles', 'The feed, 24-hour chronicles and a Gift button under every post.'),
 'A': ('Un cadeau sur une publication', 'Le bouton Cadeau ouvre le menu : ton solde, les cadeaux, Envoyer.', 'A gift on a post', 'The Gift button opens the menu: your balance, the gifts, Send.'),
 'G': ('Vidéos verticales', 'Plein écran : cœur, commentaires, cadeau, partage et son original.', 'Vertical videos', 'Full screen: like, comments, gift, share and original sound.'),
 'F': ('Détail d\'une publication', 'La photo, les cadeaux reçus et les commentaires, avec un cadeau depuis un commentaire.', 'Post details', 'The photo, the gifts received and the comments, with a gift from a comment.'),
 'B': ('Un cadeau en live', 'Le panneau Envoyer un cadeau, l\'effet à l\'écran et le total de cadeaux.', 'A gift in a live', 'The Send a gift panel, the on-screen effect and the gift total.'),
 'H': ('Audio avec image', 'Pochette, extrait gratuit, puis Acheter le titre ou Soutenir l\'artiste.', 'Audio with a cover', 'Cover art, free preview, then Buy the track or Support the artist.'),
 'C': ('Vente en direct', 'Produit épinglé : prix, stock, vente flash, Acheter et Négocier.', 'Live selling', 'Pinned product: price, stock, flash sale, Buy and Negotiate.'),
 'I': ('Image avec texte', 'Une carte du Studio : ta photo, ton texte, prête à partager.', 'Image with text', 'A Studio card: your photo, your text, ready to share.'),
}
EN = [('Quiz &amp; Étude', 'Quiz &amp; Study'), ('Nouveau son, merci pour vos cadeaux', 'New track, thanks for the gifts'),
 ('Merci pour vos cadeaux, vous êtes les meilleurs', 'Thanks for the gifts, you are the best'), ('Le thieboudienne du dimanche, qui veut la recette ?', 'Sunday thieboudienne, who wants the recipe?'),
 ('Ça donne trop faim, bravo !', 'So hungry now, bravo!'), ('Je prends la recette, merci', 'I will take the recipe, thanks'), ('Un petit cadeau pour toi', 'A little gift for you'),
 ('Écris un commentaire…', 'Write a comment…'), ('Studio ce soir, nouveau son', 'Studio tonight, new track'), ('Mon nouveau titre est sorti, écoutez !', 'My new track is out, listen!'),
 ('Extrait gratuit · 30 s', 'Free preview · 30 s'), ('Acheter le titre', 'Buy the track'), ('Soutenir l\'artiste', 'Support the artist'), ('Soleil d\'Afrique', 'Sun of Africa'),
 ('ON NE LÂCHE RIEN', 'NEVER GIVE UP'), ('Carte Studio Afrolook', 'Afrolook Studio card'), ('Une carte pour tous ceux qui y croient.', 'A card for everyone who believes.'),
 ('Envoyer un cadeau à', 'Send a gift to'), ('Envoyer un cadeau', 'Send a gift'), ('>Envoyer<', '>Send<'), ('Recharger', 'Top up'), ('Couronne offerte<br>par Kofi', 'Crown sent<br>by Kofi'),
 ('Couronne<br>offerte par Kofi', 'Crown<br>sent by Kofi'), ('>Coeur<', '>Heart<'), ('>Couronne<', '>Crown<'), ('>Diamant<', '>Diamond<'), ('>Étoile<', '>Star<'), ('>Chocolat<', '>Chocolate<'), ('>Coffre<', '>Chest<'),
 (' pcs<', ' coins<'), ('EN DIRECT', 'LIVE'), ('312 cadeaux', '312 gifts'), ('trop forte !', 'so good!'), ('Jupe en wax, taille unique', 'Wax skirt, one size'), ('Vendeur fiable · 312 avis', 'Trusted seller · 312 reviews'),
 ('Vente flash', 'Flash sale'), ('Plus que 5', 'Only 5 left'), ('28 vendus', '28 sold'), ('>Acheter<', '>Buy<'), ('>Négocier<', '>Negotiate<'), ('je prends la rouge', 'I take the red one'), ('livraison à Lomé ?', 'delivery to Lomé?'),
 ('✨ Pour toi', '✨ For you'), ('📅 Sorties', '📅 Outings'), ('Actualités', 'News'), ('🏆 Défis', '🏆 Challenges'), ('>Créer<', '>Create<'), ('>Vidéos<', '>Videos<'), ('Chroniques', 'Chronicles'),
 ('● 3 actives', '● 3 active'), ('Ma chronique', 'My chronicle'), ('abonné(s)', 'follower(s)'), ('abonnés', 'followers'), ('il y a 2 h', '2 h ago'), ('← Publication', '← Post'), ('Commentaires (124)', 'Comments (124)'),
 ('>Suivis<', '>Following<'), ('>Pour toi<', '>For you<'), ('Partager', 'Share'), ('Son original', 'Original sound'), ('Cadeau ', 'Gift ')]

def xcls(html):
    return re.sub(r'class="([^"]*)"', lambda m: 'class="' + ' '.join(('x-' + t) for t in m.group(1).split()) + '"', html)

def conv(html, lang):
    html = xcls(html)
    html = re.sub(r'src="img/([^"]+)\.(jpg|webp)"', lambda m: 'src="/img/people/%s.webp" loading="lazy"' % m.group(1), html)
    if lang == 'en':
        for a, b in EN:
            html = html.replace(a, b)
    return html

# images utilisées
used = set()
for k in ORDER:
    used |= set(re.findall(r'img/([^"]+?)\.(?:jpg|webp)"', S[k]))
os.makedirs(os.path.join(SITE, 'static', 'img', 'people'), exist_ok=True)
for n in sorted(used):
    src = os.path.join(HERE, 'img', n + '.jpg')
    if not os.path.exists(src):
        src = os.path.join(HERE, 'img', n + '.webp')
    dst = os.path.join(SITE, 'static', 'img', 'people', n + '.webp')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, '-vf', "scale='min(460,iw)':-2", '-q:v', '72', dst], check=True)

# CSS des écrans, préfixé
i = CSS.index('.bar{display:flex')
tail = CSS[i:]
out = ['.afx{--green:#1b8a3c;--gold:#ffc400}\n.afx .phone{position:relative;width:250px;height:510px;border-radius:34px;background:#0b0f0d;border:7px solid #232f28;box-shadow:0 0 0 1px rgba(255,255,255,.22),0 14px 40px rgba(0,0,0,.45);overflow:hidden;flex:none;margin-inline:auto}\n.afx .scr{position:absolute;inset:0;background:#fafaf8;color:#14201a;font-size:10px;overflow:hidden;font-family:Roboto,system-ui,sans-serif;text-align:left}\n.afx .scr *{box-sizing:border-box}\n']
for rule in tail.split('}'):
    rule = rule.strip()
    if not rule or '{' not in rule:
        continue
    sel, body = rule.split('{', 1)
    sels = ','.join('.afx ' + x.strip() for x in sel.split(','))
    out.append(sels + '{' + body + '}\n')
out.append('''.afx .phone::before,.afx .phone::after{display:none}
.afx-stage{position:relative;width:100%;max-width:340px;height:560px;margin:0 auto}
.afx-sc{position:absolute;inset:0;opacity:0;transition:opacity .6s;pointer-events:none;display:flex;flex-direction:column;align-items:center}
.afx-sc.on{opacity:1;pointer-events:auto}
.afx-sc .phone{transform:rotate(-2deg)}
.afx-cap{margin-top:14px;font-weight:800;background:#FFD21F;color:#3a2c00;border-radius:99px;padding:7px 16px;font-size:14px;box-shadow:0 8px 20px rgba(0,0,0,.15);text-align:center}
.afx-dots{display:flex;gap:7px;justify-content:center;margin-top:10px}.afx-dots i{width:8px;height:8px;border-radius:50%;background:rgba(120,130,125,.35);display:block;cursor:pointer}.afx-dots i.on{background:#1b8a3c}
.afx-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:28px 18px;margin-top:36px}
.afx-grid figure{margin:0;text-align:center}.afx-grid figcaption{margin-top:12px;font-weight:800;font-size:16px}.afx-grid figcaption small{display:block;font-weight:400;color:var(--muted);font-size:13.5px;margin-top:3px}
@media(max-width:1100px){.afx-grid{grid-template-columns:repeat(2,1fr)}}
@media(max-width:620px){.afx-grid{grid-template-columns:1fr}.afx-stage{height:540px}}
''')
css_txt = re.sub(r'\.(?!afx)([A-Za-z][A-Za-z0-9_-]*)', lambda m: '.x-' + m.group(1), ''.join(out))
css_txt = css_txt.replace('.afx-sc.x-on', '.afx-sc.on').replace('.afx-dots i.x-on', '.afx-dots i.on')
open(os.path.join(SITE, 'static', 'css', 'screens.css'), 'w', encoding='utf-8').write(css_txt)

def phone(k, lang):
    return '<div class="x-phone">%s</div>' % conv(S[k], lang)

mjs = ['// Fichier généré par docs/maquettes/_gen_site.py : 8 écrans de l\'application (fil, cadeaux, vidéo, détail, audio, vente, image avec texte).\n']
for lang, ci in (('fr', 0), ('en', 2)):
    hero = ''.join('<div class="afx-sc%s">%s<span class="afx-cap">%s</span></div>' % (' on' if n == 0 else '', phone(k, lang), CAP[k][ci]) for n, k in enumerate(ORDER))
    dots = ''.join('<i%s></i>' % (' class="on"' if n == 0 else '') for n in range(len(ORDER)))
    grid = ''.join('<figure>%s<figcaption>%s<small>%s</small></figcaption></figure>' % (phone(k, lang), CAP[k][ci], CAP[k][ci + 1]) for k in ORDER)
    mjs.append('export const %sHero = %s;\n' % (lang, json.dumps('<div class="afx afx-stage" id="afxh">%s</div><div class="afx afx-dots" id="afxd">%s</div>' % (hero, dots), ensure_ascii=False)))
    mjs.append('export const %sGrid = %s;\n' % (lang, json.dumps('<div class="afx afx-grid">%s</div>' % grid, ensure_ascii=False)))
open(os.path.join(SITE, 'src', 'screens.mjs'), 'w', encoding='utf-8').write(''.join(mjs))
print('images', len(used), 'ok')
