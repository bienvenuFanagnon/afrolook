# -*- coding: utf-8 -*-
# Génère chroniques_proposition.html (+ autonome) : refonte des pages de chronique avec aperçu avant publication.
import os, re, base64
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
ns = {'__file__': os.path.join(HERE, '_videos_build.py')}
src = open('_videos_build.py', encoding='utf-8').read()
src = src[:src.index("HTML = '''")]
exec(src, ns)
CSS, SV, im = ns['CSS'], ns['SV'], ns['im']

CSS += r'''
.chs{position:absolute;inset:0;background:#fafaf8;color:#14201a;font-family:Roboto,system-ui,sans-serif;font-size:10px;overflow:hidden}
.chs .hd{display:flex;align-items:center;justify-content:space-between;padding:10px 12px 4px}.chs .hd b{font-size:15px}
.fl2{display:flex;gap:5px;padding:4px 12px;overflow:hidden}.fl2 span{border:1px solid #dcdcd4;background:#fff;border-radius:99px;padding:4px 9px;font-size:9px;font-weight:700;white-space:nowrap}.fl2 .on{background:#14201a;color:#fff;border-color:#14201a}
.ring{display:flex;gap:9px;padding:6px 12px}.ring div{text-align:center;font-size:8px;width:42px}.ring img{width:40px;height:40px;border-radius:50%;object-fit:cover;border:2.5px solid #1b8a3c;display:block;margin:0 auto 2px}
.ring i{width:40px;height:40px;border-radius:50%;border:2px dashed #aaa;display:grid;place-items:center;font-style:normal;color:#1b8a3c;font-size:16px;margin:0 auto 2px}
.gr{display:grid;grid-template-columns:1fr 1fr;gap:7px;padding:4px 12px}.gr div{position:relative;border-radius:14px;overflow:hidden;height:150px;background:#222}.gr img{width:100%;height:100%;object-fit:cover;display:block}
.gr div:after{content:"";position:absolute;inset:0;background:linear-gradient(transparent 50%,rgba(0,0,0,.65))}
.gr .tg{position:absolute;z-index:2;left:6px;top:6px;background:rgba(0,0,0,.5);color:#fff;border-radius:99px;padding:1px 7px;font-size:8px;font-weight:700}.gr .nm{position:absolute;z-index:2;left:7px;bottom:6px;color:#fff;font-weight:800;font-size:10px;display:flex;gap:5px;align-items:center}
.gr .nm img{width:18px;height:18px;border-radius:50%;border:1.5px solid #fff}
.fab{position:absolute;right:12px;bottom:14px;background:#ffc400;color:#3a2c00;border-radius:99px;padding:10px 16px;font-weight:900;font-size:11px;box-shadow:0 6px 18px rgba(0,0,0,.25)}
.seg{position:absolute;z-index:3;top:8px;left:10px;right:10px;display:flex;gap:3px}.seg i{flex:1;height:2.5px;border-radius:3px;background:rgba(255,255,255,.35);display:block;position:relative}.seg i.d{background:#fff}.seg i.c:after{content:"";position:absolute;left:0;top:0;bottom:0;width:55%;background:#fff;border-radius:3px}
.chh{position:absolute;z-index:3;top:20px;left:10px;right:10px;display:flex;align-items:center;gap:7px;font-size:11px;font-weight:800}.chh img{width:28px;height:28px;border-radius:50%;object-fit:cover;border:1.5px solid #fff}.chh small{display:block;font-weight:400;opacity:.85;font-size:8.5px}
.rep{position:absolute;z-index:3;left:11px;right:11px;bottom:10px;display:flex;gap:7px;align-items:center}.rep .f{flex:1;height:36px;border-radius:18px;background:rgba(0,0,0,.45);border:1px solid rgba(255,255,255,.22);display:flex;align-items:center;padding:0 13px;font-size:10px;color:rgba(255,255,255,.88)}
.rep .btn{width:36px;height:36px}.rep .btn svg{width:19px;height:19px}
.stp{display:flex;gap:4px;padding:2px 12px}.stp i{flex:1;height:3px;border-radius:3px;background:#dcdcd4;display:block}.stp i.on{background:#1b8a3c}
.tl{display:grid;grid-template-columns:1fr 1fr;gap:7px;padding:8px 12px}.tl div{border:1.5px solid #dcdcd4;background:#fff;border-radius:16px;padding:12px 8px;text-align:center;font-weight:800;font-size:11px}.tl div.sel{border-color:#ffc400;background:#fff9de}.tl small{display:block;color:#777;font-weight:400;font-size:8.5px;margin-top:3px}.tl svg{width:24px;height:24px;fill:none;stroke:#14201a;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round;display:block;margin:0 auto 5px}
.cv{position:absolute;left:10px;right:10px;top:42px;bottom:96px;border-radius:20px;display:grid;place-items:center;text-align:center;color:#fff;font-weight:900;font-size:20px;line-height:1.15;padding:18px;box-shadow:0 8px 24px rgba(0,0,0,.25)}
.pal{position:absolute;left:0;right:0;bottom:52px;display:flex;gap:7px;justify-content:center}.pal i{width:24px;height:24px;border-radius:50%;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.3);display:block}.pal i.on{outline:2px solid #14201a}
.tbr{position:absolute;left:12px;right:12px;bottom:10px;display:flex;justify-content:space-between;align-items:center}.tbr span{background:#fff;border:1px solid #dcdcd4;border-radius:99px;padding:7px 11px;font-weight:800;font-size:10px}.tbr .nx{background:#1b8a3c;color:#fff;border-color:#1b8a3c}
.ban{position:absolute;z-index:4;top:48px;left:12px;right:12px;background:rgba(255,255,255,.95);color:#14201a;border-radius:14px;padding:8px 10px;font-size:9.5px;line-height:1.35;box-shadow:0 6px 18px rgba(0,0,0,.3)}.ban b{display:block;font-size:10.5px}
.pb{position:absolute;z-index:4;left:11px;right:11px;bottom:10px;background:rgba(255,255,255,.96);color:#14201a;border-radius:20px;padding:10px}.pb .cost{font-size:9.5px;color:#555;margin-bottom:7px}.pb .two{display:flex;gap:7px}.pb .two span{flex:1;text-align:center;border-radius:14px;padding:9px;font-weight:900;font-size:11px}.pb .a{background:#ffc400;color:#3a2c00}.pb .b{border:1.5px solid #bbb}
.chip24{position:absolute;z-index:3;right:10px;top:20px;background:rgba(0,0,0,.5);border:1px solid rgba(255,255,255,.25);border-radius:99px;padding:3px 9px;font-size:8.5px;font-weight:800}
'''

def phone(i): return '<div class="phone">%s</div>' % i
TOP = '<div class="hd"><b>Chroniques</b><span style="font-size:14px">⌕</span></div>'

LIST = ('<div class="chs">' + TOP + '<div class="fl2"><span class="on">Pour toi</span><span>Abonnements</span><span>Populaires</span><span>Vidéos</span><span>Musique</span></div>'
        '<div class="ring"><div><i>+</i>Ma chronique</div><div><img src="%s" alt="">kofi</div><div><img src="%s" alt="">awa</div><div><img src="%s" alt="">jay</div><div><img src="%s" alt="">mariam</div></div>'
        '<div class="gr"><div><img src="%s" alt=""><span class="tg">Vidéo</span><span class="nm"><img src="%s" alt="">zuri</span></div><div><img src="%s" alt=""><span class="tg">Photo</span><span class="nm"><img src="%s" alt="">awa</span></div>'
        '<div><img src="%s" alt=""><span class="tg">Musique</span><span class="nm"><img src="%s" alt="">jay</span></div><div style="background:linear-gradient(160deg,#7b3fe4,#f0507a)"><span class="tg">Texte</span><span class="nm" style="font-size:11px;left:9px;bottom:auto;top:46px;right:9px;line-height:1.2">Demain, on se lance. Qui est avec moi ?</span></div></div>'
        '<div class="fab">+ Créer</div></div>') % (im('h_2033447.jpg'), im('f_8727469.jpg'), im('h_6774139.jpg'), im('f_7229044.jpg'), im('h_15929275.jpg'), im('f_5688730.jpg'), im('f_5622572.jpg'), im('f_8727469.jpg'), im('n_dj.jpg'), im('h_6774139.jpg'))

VIEW = ('<div class="v"><img class="bg" src="%s" alt="" style="object-position:center 15%%"><div class="shade"></div>'
        '<div class="seg"><i class="d"></i><i class="c"></i><i></i></div>'
        '<div class="chh"><img src="%s" alt=""><span>kofi.vibes<small>il y a 3 h</small></span></div>'
        '<div class="rail" style="bottom:64px"><div class="btn">%s</div><div class="btn">%s</div><div class="btn">%s</div></div>'
        '<div class="rep"><div class="f">Répondre à kofi.vibes…</div><div class="btn">%s</div></div></div>') % (im('h_2033447.jpg'), im('h_2033447.jpg'), SV['heart'], SV['gift'], SV['more'], SV['share'])

TYPES = ('<div class="chs"><div class="hd"><b>← Nouvelle chronique</b></div><div class="stp"><i class="on"></i><i></i><i></i></div>'
         '<div style="padding:8px 12px 0;font-weight:800;font-size:12px">Que veux-tu partager pendant 24 h ?</div>'
         '<div class="tl"><div class="sel"><svg viewBox="0 0 24 24"><path d="M5 6h14M12 6v13M9 19h6"/></svg>Texte<small>Un message sur un fond coloré</small></div>'
         '<div><svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M21 17l-5-5-9 7"/></svg>Photo<small>Depuis la caméra ou la galerie</small></div>'
         '<div><svg viewBox="0 0 24 24"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/></svg>Vidéo<small>30 secondes au plus</small></div>'
         '<div><svg viewBox="0 0 24 24"><path d="M9 18V6l10-2v12M9 18a3 3 0 1 1-3-3M19 16a3 3 0 1 1-3-3"/></svg>Audio<small>Ta voix ou un son</small></div></div>'
         '<div style="padding:4px 12px;color:#666;font-size:9px;line-height:1.4">2 chroniques gratuites actives en même temps, puis 10 pièces pour chaque chronique de plus.</div></div>')

COMP = ('<div class="chs"><div class="hd"><b>← Texte</b></div><div class="stp"><i class="on"></i><i class="on"></i><i></i></div>'
        '<div class="cv" style="background:linear-gradient(160deg,#7b3fe4,#f0507a 60%,#ffc400);top:44px;bottom:100px">Demain, on se lance.<br>Qui est avec moi ?</div>'
        '<div class="pal"><i style="background:linear-gradient(160deg,#7b3fe4,#f0507a)" class="on"></i><i style="background:linear-gradient(160deg,#0f8a3c,#06210f)"></i><i style="background:linear-gradient(160deg,#ffc400,#e5383b)"></i><i style="background:linear-gradient(160deg,#1f8aa8,#0f3a52)"></i><i style="background:#14201a"></i></div>'
        '<div class="tbr"><span>Aa</span><span>♪ Musique</span><span>Fond</span><span class="nx">Aperçu →</span></div></div>')

PREV = ('<div class="v"><img class="bg" src="%s" alt="" style="object-position:center 15%%"><div class="shade"></div>'
        '<div class="seg"><i class="c"></i></div><div class="chh"><img src="%s" alt=""><span>toi<small>maintenant</small></span></div><div class="chip24">Disparaît dans 24 h</div>'
        '<div class="ban"><b>Aperçu avant publication</b>Voici exactement ce que tes abonnés verront.</div>'
        '<div class="pb"><div class="cost">Chronique 1 sur 2 gratuites · publiée pendant 24 h</div><div class="two"><span class="b">Modifier</span><span class="a">Publier</span></div></div></div>') % (im('h_31679357.jpg'), im('f_5688730.jpg'))

HTML = '''<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Chroniques refaites · proposition</title><style>%(css)s</style></head><body><div class="wrap">
<h1>Chroniques : refonte des pages, avec aperçu avant publication</h1>
<p class="lead"><b>Rien n'est modifié.</b> Même famille de pastilles, d'icônes et de couleurs que les pages de post et de vidéo. J'ai relu les pages actuelles : <code>chroniquehome.dart</code> (liste), <code>chroniquedetails.dart</code> (lecture, 2 324 lignes), <code>chroniqueform.dart</code> (création, 1 379 lignes), <code>mychroniquepage.dart</code> et les feuilles de commentaires et de réponses.</p>
<h2>1. Les écrans proposés</h2>
<div class="row"><figure>%(list)s<figcaption>Liste<small>Filtres, anneaux des personnes, cartes verticales, bouton Créer</small></figcaption></figure>
<figure>%(view)s<figcaption>Lecture<small>Barres de progression, pastilles, « Répondre… » qui ouvre la feuille de réponse</small></figcaption></figure>
<figure>%(types)s<figcaption>Création : le type<small>Quatre grandes cartes au lieu de quatre onglets</small></figcaption></figure>
<figure>%(comp)s<figcaption>Création : le texte<small>Fond en dégradé, palette, police, musique, déplacement du texte</small></figcaption></figure>
<figure>%(prev)s<figcaption>Aperçu avant publication<small>Exactement ce que verront les abonnés, puis Modifier ou Publier</small></figcaption></figure></div>
<h2>2. Ce que j'ai relevé, ce que je change</h2>
<div class="card tbl"><table><tr><th>Page</th><th>Aujourd'hui</th><th>Proposition</th></tr>
<tr><td>Liste</td><td>Filtres (Pour toi, Abonnements, Populaires, Vidéos, Musique), recherche par pseudo, anneaux, textes en dur (« CRÉER UNE CHRONIQUE », « Vous avez tout vu »)</td><td>Mêmes filtres en pastilles claires, anneaux plus grands, <b>cartes verticales avec vignette réelle</b> (photo, vidéo, texte en couleur, pochette musique), type et pseudo sur la carte, bouton « Créer » flottant ; tous les textes traduits.</td></tr>
<tr><td>Lecture</td><td>Longue page de 2 324 lignes, pub et boosts mélangés, commentaires et réponses en feuilles</td><td>Lecture plein écran : <b>barres de progression</b>, en-tête créateur, <b>pastilles</b> (j'aime, cadeau, menu), champ « Répondre… » qui ouvre la feuille de réponse existante ; pub entre deux personnes (réseau d'abord, Afrolook Ads ensuite, pas pour Gold) ; toucher = pause, bord gauche/droit = précédent/suivant, comme les vidéos.</td></tr>
<tr><td>Création</td><td>Quatre onglets (texte, image, vidéo, audio), un formulaire long, aperçu de texte seulement</td><td><b>Trois étapes</b> : type (grandes cartes), contenu (texte sur dégradé, photo, vidéo 30 s, audio), <b>aperçu avant publication</b>.</td></tr>
<tr><td>Aperçu</td><td>Seul le texte a un aperçu</td><td><b>Aperçu pour tous les types</b> : l'écran de lecture réel, avec la mention « Aperçu avant publication », la durée de 24 h, le coût (2 gratuites, 10 pièces au-delà) et les boutons Modifier / Publier.</td></tr>
<tr><td>Vidéos d'autres réseaux</td><td>Pas de contrôle</td><td><b>Refusées</b> (déjà codé : ML Kit gratuit), sans recours car la chronique ne dure que 24 h.</td></tr>
<tr><td>Mes chroniques</td><td>Page à part</td><td>Même présentation que la liste ; vues par chronique et suppression en un geste.</td></tr></table></div>
<h2>3. Ce que je garde</h2>
<div class="card"><ul class="t" style="margin:0;padding-left:18px"><li>Les règles : 24 h, 2 gratuites actives puis 10 pièces, 30 secondes de vidéo, 20 Mo.</li><li>La musique, les filtres, le texte déplaçable, les feuilles de commentaires et de réponses.</li><li>Les chroniques de l'équipe, les boosts et les chiffres de vues.</li></ul></div>
<h2>À valider</h2>
<div class="card"><ol style="margin:0;padding-left:20px"><li>La liste en cartes verticales avec vignettes.</li><li>La lecture plein écran avec pastilles et « Répondre… ».</li><li>La création en 3 étapes, avec aperçu pour tous les types avant « Publier ».</li><li>Un aperçu qui montre aussi le coût quand la chronique est payante.</li></ol>
<p class="note">Après votre accord, je code dans cet ordre : création + aperçu, lecture, liste. Photos d'exemple (Pexels).</p></div>
</div></body></html>''' % {'css': CSS, 'list': phone(LIST), 'view': phone(VIEW), 'types': phone(TYPES), 'comp': phone(COMP), 'prev': phone(PREV)}
open('chroniques_proposition.html', 'w', encoding='utf-8').write(HTML)
emb = lambda m: 'src="data:image/jpeg;base64,%s"' % base64.b64encode(open(m.group(1), 'rb').read()).decode()
open('chroniques_proposition_autonome.html', 'w', encoding='utf-8').write(re.sub(r'src="(img/[^"]+)"', emb, HTML))
print(len(HTML) // 1024, 'Ko')
