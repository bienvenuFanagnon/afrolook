# -*- coding: utf-8 -*-
# Génère chroniques_studio_proposition.html (+ autonome) : les chroniques passent par le Studio de montage, avec chroniques business.
import os, re, base64
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
ns = {'__file__': os.path.join(HERE, '_chroniques_build.py')}
src = open('_chroniques_build.py', encoding='utf-8').read()
src = src[:src.index(chr(10) + "HTML = '''")]
exec(src, ns)
CSS, SV, im, phone, LIST, VIEW, PREV = ns['CSS'], ns['SV'], ns['im'], ns['phone'], ns['LIST'], ns['VIEW'], ns['PREV']

CSS += r'''
.ed{position:absolute;inset:0;background:#0f1a14;color:#fff;font-family:Roboto,system-ui,sans-serif;font-size:10px;overflow:hidden}
.ed>img.bg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.ed .top{position:absolute;z-index:3;top:8px;left:10px;right:10px;display:flex;justify-content:space-between;align-items:center;font-weight:800;font-size:11px}
.ed .top .nx{background:#ffc400;color:#3a2c00;border-radius:99px;padding:6px 12px;font-weight:900}
.tools{position:absolute;z-index:3;right:8px;top:48px;display:flex;flex-direction:column;gap:9px;align-items:center;font-size:8px;font-weight:700}
.tools .btn{width:34px;height:34px}.tools .btn svg{width:18px;height:18px}
.tools .on{outline:2px solid #ffc400;border-radius:50%}
.pinbox{position:absolute;z-index:2;left:12px;top:120px;width:84px;height:112px;border-radius:12px;overflow:hidden;border:2px solid #fff;box-shadow:0 6px 16px rgba(0,0,0,.45)}.pinbox img{width:100%;height:100%;object-fit:cover}
.pinbox:after{content:"▶";position:absolute;inset:0;display:grid;place-items:center;font-size:16px;color:#fff;text-shadow:0 1px 4px rgba(0,0,0,.6)}
.cc{position:absolute;z-index:3;left:12px;right:12px;bottom:112px;background:#fff;color:#14201a;border-radius:16px;padding:9px 11px;box-shadow:0 8px 22px rgba(0,0,0,.4)}
.cc b{font-size:12px;display:block}.cc .pr{color:#1b8a3c;font-weight:900;font-size:13px}.cc .rw{display:flex;gap:6px;margin-top:7px}.cc .rw span{flex:1;text-align:center;border-radius:12px;padding:7px 4px;font-weight:800;font-size:9.5px}.cc .go{background:#1b8a3c;color:#fff}.cc .wa{background:#e6f6ec;color:#14663a}
.sh3{position:absolute;left:0;right:0;bottom:0;background:#fff;color:#14201a;z-index:6;border-radius:22px 22px 0 0;padding:12px 14px 14px;box-shadow:0 -10px 30px rgba(0,0,0,.4)}.sh3 h4{margin:0 0 8px;font-size:13px}
.sh3 .fi{border:1px solid #dcdcd4;border-radius:11px;padding:8px 10px;margin-bottom:6px;color:#777;font-size:10px;display:flex;justify-content:space-between}.sh3 .fi b{color:#14201a}.sh3 .go2{background:#ffc400;color:#3a2c00;border-radius:20px;padding:10px;text-align:center;font-weight:900;font-size:11.5px;margin-top:8px}
.dim3{position:absolute;inset:0;background:rgba(0,0,0,.4);z-index:5}
.chooser{display:flex;flex-direction:column;gap:7px;padding:10px 12px}.chooser div{border:1.5px solid #dcdcd4;border-radius:16px;padding:11px;background:#fff}.chooser div.sel{border-color:#ffc400;background:#fff9de}.chooser b{font-size:11.5px;display:block}.chooser small{color:#666;font-size:9px}
'''

ICON = lambda p: '<svg viewBox="0 0 24 24">%s</svg>' % p
T_TEXT = ICON('<path d="M5 6h14M12 6v13M9 19h6"/>')
T_STICK = ICON('<path d="M4 4h12l4 4v12H4z"/><path d="M16 4v4h4"/>')
T_MUSIC = ICON('<path d="M9 18V6l10-2v12M9 18a3 3 0 1 1-3-3M19 16a3 3 0 1 1-3-3"/>')
T_PIN = ICON('<path d="M9 3h6l-1 6 4 3v2H6v-2l4-3z"/><path d="M12 14v7"/>')
T_SHOP = ICON('<path d="M4 7h16l-1 5H5zM6 12v8h12v-8"/>')
T_LINK = ICON('<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>')
T_MIC = ICON('<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>')

def toolbtn(svg, lab, on=False): return '<div style="text-align:center"><div class="btn %s">%s</div>%s</div>' % ('on' if on else '', svg, lab)

CHOOSE = ('<div class="chs"><div class="hd"><b>← Créer</b></div>'
          '<div class="chooser"><div><b>Publication</b><small>Photo, vidéo, audio ou texte dans le fil</small></div>'
          '<div class="sel"><b>Chronique (24 h)</b><small>Ouvre le Studio : montage, musique, texte, épinglage</small></div>'
          '<div><b>Chronique business</b><small>Vends un produit : carte de vente, lien, WhatsApp, appel</small></div>'
          '<div><b>Live</b><small>En direct, avec cadeaux ou vente</small></div></div></div>')

ED = ('<div class="phone"><div class="ed"><img class="bg" src="%s" alt="" style="object-position:center 15%%"><div class="shade"></div>'
      '<div class="top"><span>✕</span><span>Chronique · Studio</span><span class="nx">Aperçu →</span></div>'
      '<div class="tools">%s%s%s%s%s%s</div><div class="pinbox"><img src="%s" alt=""></div></div></div>') % (
    im('f_8727469.jpg'), toolbtn(T_TEXT, 'Texte'), toolbtn(T_STICK, 'Autocoll.'), toolbtn(T_MUSIC, 'Musique'), toolbtn(T_PIN, 'Épingler', True), toolbtn(T_SHOP, 'Vente'), toolbtn(T_MIC, 'Voix'), im('n_av_mic.jpg'))

BIZ = ('<div class="phone"><div class="ed"><img class="bg" src="%s" alt="" style="object-position:center 25%%"><div class="shade"></div>'
       '<div class="top"><span>✕</span><span>Chronique business</span><span class="nx">Aperçu →</span></div>'
       '<div class="pinbox" style="top:70px"><img src="%s" alt=""></div><div class="dim3"></div>'
       '<div class="sh3"><h4>Carte de vente</h4><div class="fi"><span>Produit</span><b>Jupe en wax</b></div><div class="fi"><span>Prix</span><b>12 500 F</b></div>'
       '<div class="fi"><span>WhatsApp</span><b>+228 90 00 00 00</b></div><div class="fi"><span>Lien (facultatif)</span><b>afrolookmedia.com/…</b></div><div class="go2">Ajouter à la chronique</div></div></div></div>') % (im('n_av_food.jpg'), im('n_av_mic.jpg'))

PREVB = ('<div class="phone"><div class="v"><img class="bg" src="%s" alt="" style="object-position:center 25%%"><div class="shade"></div>'
         '<div class="seg"><i class="c"></i></div><div class="chh"><img src="%s" alt=""><span>boutique_mariam<small>maintenant</small></span></div><div class="chip24">Disparaît dans 24 h</div>'
         '<div class="pinbox" style="top:96px;left:12px"><img src="%s" alt=""></div>'
         '<div class="cc"><b>Jupe en wax, taille unique</b><span class="pr">12 500 F</span><div class="rw"><span class="go">Commander maintenant</span><span class="wa">WhatsApp</span></div></div>'
         '<div class="ban" style="top:50px;left:auto;right:12px;width:104px"><b>Aperçu</b>Tel que le verront tes abonnés</div>'
         '<div class="pb"><div class="cost">Chronique business · 24 h · 1 sur 2 gratuites</div><div class="two"><span class="b">Modifier</span><span class="a">Publier</span></div></div></div></div>') % (im('n_av_food.jpg'), im('n_av_food.jpg'), im('n_av_mic.jpg'))

HTML = '''<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Chroniques par le Studio · proposition</title><style>%(css)s</style></head><body><div class="wrap">
<h1>Chroniques : tout passe par le Studio, avec des chroniques business</h1>
<p class="lead"><b>Rien n'est modifié.</b> Votre remarque change l'architecture, et je la trouve meilleure : la chronique devient une « story » fabriquée dans le Studio de montage, comme les posts. <b>Un seul système d'édition et un seul contrôle</b> : musique, texte, autocollants, vidéo ou image épinglée, voix, carte de vente. Le formulaire à part (<code>chroniqueform.dart</code>, 1 379 lignes) disparaît. Cette proposition complète celle des chroniques (liste, lecture, aperçu), qui reste valable.</p>

<h2>1. Le parcours</h2>
<div class="row"><figure>%(choose)s<figcaption>1. Créer<small>« Chronique » et « Chronique business » ouvrent le Studio</small></figcaption></figure>
<figure>%(ed)s<figcaption>2. Studio, mode chronique<small>Texte, autocollants, musique, épingler, vente, voix, au format story</small></figcaption></figure>
<figure>%(biz)s<figcaption>3. Chronique business<small>Carte de vente : produit, prix, WhatsApp, appel, lien</small></figcaption></figure>
<figure>%(prev)s<figcaption>4. Aperçu avant publication<small>Exactement la lecture réelle, avec la carte « Commander maintenant »</small></figcaption></figure></div>

<h2>2. Ce que ça permet</h2>
<div class="card"><ul class="t" style="margin:0;padding-left:18px">
<li><b>Photo, vidéo (30 s) ou audio</b> choisis ou filmés dans l'application (caméra du Studio, enregistrements en priorité), puis montés.</li>
<li><b>Superposer une vidéo ou une image</b> (épingle) et <b>parler par-dessus</b> (voix), comme dans les posts : on explique son produit en montrant le produit.</li>
<li><b>Chronique business</b> : carte de vente avec prix, « Commander maintenant » (lien), WhatsApp, appel. <b>Seule la carte est cliquable</b>, comme sur les posts (règle validée).</li>
<li><b>Un seul contrôle d'authenticité</b> : tout ce qui sort du Studio passe par l'examen des vidéos d'autres réseaux (déjà codé), et reçoit la mention « Fait sur Afrolook ».</li>
<li><b>Mêmes règles qu'avant</b> : 24 h, 2 chroniques gratuites actives puis 10 pièces, 30 secondes de vidéo.</li></ul></div>

<h2>3. Comment je le code</h2>
<div class="card tbl"><table><tr><th>Sujet</th><th>Proposition</th></tr>
<tr><td>Studio</td><td>Un mode « chronique » du Studio : format story 9:16, même éditeur, même export serveur (<code>POST /studio/montages</code>). Le bouton « Aperçu → » remplace « Suivant ».</td></tr>
<tr><td>Publication</td><td>Le film exporté est publié par le point d'accès des chroniques existant (<code>POST /chronicles</code>, avec le film en média). Aucune nouvelle logique de durée ni de coût.</td></tr>
<tr><td>Carte de vente</td><td>Colonne <code>commerce</code> (JSON : produit, prix, WhatsApp, téléphone, lien) sur les chroniques, avec la même validation que la carte Commerce des posts ; le serveur renvoie la carte à la lecture.</td></tr>
<tr><td>Épinglage</td><td>La vidéo ou l'image épinglée est intégrée au film à l'export (comme pour les vidéos des posts). Rendre l'épingle cliquable vers l'original, comme sur les posts, demande une colonne de plus : je le propose en deuxième temps.</td></tr>
<tr><td>Chronique texte</td><td>Elle aussi passe par le Studio (modèles de fond coloré) : plus de formulaire à part.</td></tr>
<tr><td>Anciennes chroniques</td><td>Inchangées (elles expirent en 24 h) ; l'ancien formulaire est retiré une fois le Studio en place.</td></tr>
<tr><td>Chronique business</td><td>Ouverte à toute personne qui a une boutique (entreprise) dans Afrolook ; sinon le lien externe reste possible mais la carte porte la mention « lien externe ».</td></tr></table></div>

<h2>À valider</h2>
<div class="card"><ol style="margin:0;padding-left:20px"><li>Les chroniques passent <b>toutes</b> par le Studio (le formulaire à part disparaît).</li><li>La « Chronique business » avec la carte de vente cliquable (produit, prix, Commander maintenant, WhatsApp, appel).</li><li>L'épingle intégrée au film dans un premier temps, cliquable plus tard.</li><li>Chronique business réservée aux personnes qui ont une boutique Afrolook, ou ouverte à tous avec la mention « lien externe » ?</li><li>L'ordre de travail : Studio en mode chronique + aperçu, puis lecture, puis liste.</li></ol>
<p class="note">Rappel : les écrans de lecture, de liste et d'aperçu sont dans la proposition précédente (chroniques_proposition_autonome.html).</p></div>
</div></body></html>''' % {'css': CSS, 'choose': phone(CHOOSE), 'ed': ED, 'biz': BIZ, 'prev': PREVB}
open('chroniques_studio_proposition.html', 'w', encoding='utf-8').write(HTML)
emb = lambda m: 'src="data:image/jpeg;base64,%s"' % base64.b64encode(open(m.group(1), 'rb').read()).decode()
open('chroniques_studio_proposition_autonome.html', 'w', encoding='utf-8').write(re.sub(r'src="(img/[^"]+)"', emb, HTML))
print(len(HTML) // 1024, 'Ko')
