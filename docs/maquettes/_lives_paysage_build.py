# -*- coding: utf-8 -*-
# Génère lives_et_paysage_proposition.html (+ autonome) : page vidéo paysage, création de live (2 modes), onglet Lives vertical.
import os, re, base64
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
ns = {'__file__': os.path.join(HERE, '_videos_build.py')}
src = open('_videos_build.py', encoding='utf-8').read()
src = src[:src.index("HTML = '''")]          # on ne garde que le CSS et les petites fonctions
exec(src, ns)
CSS, SV, im = ns['CSS'], ns['SV'], ns['im']

EXTRA = r'''
.lp{position:absolute;inset:0;background:#fafaf8;color:#14201a;font-family:Roboto,system-ui,sans-serif;font-size:10px;overflow:hidden}
.lp .hd{display:flex;align-items:center;gap:8px;padding:10px 12px;font-weight:800;font-size:13px}
.player{position:relative;height:148px;background:#000}.player img{width:100%;height:100%;object-fit:cover;display:block}
.player .ctl{position:absolute;left:0;right:0;bottom:0;padding:6px 9px;color:#fff;font-size:9px;display:flex;gap:7px;align-items:center;background:linear-gradient(transparent,rgba(0,0,0,.6))}
.player .ctl i{flex:1;height:3px;background:rgba(255,255,255,.35);border-radius:3px;position:relative}.player .ctl i:after{content:"";position:absolute;left:0;top:0;bottom:0;width:35%;background:#fff;border-radius:3px}
.ttl{padding:8px 12px 0;font-weight:800;font-size:12.5px;line-height:1.25}.meta{padding:2px 12px;color:#777;font-size:9px}
.cr{display:flex;align-items:center;gap:8px;padding:6px 12px}.cr img{width:32px;height:32px;border-radius:50%;object-fit:cover}.cr b{display:block;font-size:11px}.cr small{color:#777;font-size:8.5px}
.cr .fo{margin-left:auto;background:#1b8a3c;color:#fff;border-radius:99px;padding:5px 13px;font-weight:800;font-size:10px}
.pl{display:flex;gap:6px;padding:2px 12px}.pl span{display:flex;align-items:center;gap:4px;border:1px solid #dcdcd4;background:#fff;border-radius:99px;padding:5px 9px;font-weight:700;font-size:9.5px}
.pl svg{width:14px;height:14px;fill:none;stroke:#14201a;stroke-width:1.9;stroke-linecap:round;stroke-linejoin:round}.pl .on svg{stroke:#e5383b;fill:#e5383b}
.cf{margin:8px 12px;height:32px;border-radius:16px;background:#f0f0ea;border:1px solid #e2e2dc;display:flex;align-items:center;padding:0 12px;color:#777;font-size:10px}
.sg{display:flex;gap:8px;padding:4px 12px}.sg img{width:92px;height:56px;border-radius:8px;object-fit:cover;flex:none}.sg b{font-size:10px;display:block;line-height:1.25}.sg small{color:#777;font-size:8.5px}
.nat{margin:6px 12px;border:1px solid #e2e2dc;border-radius:12px;background:#fff;padding:7px 9px;display:flex;gap:8px;align-items:center;font-size:9px}.nat span{background:#eee;border-radius:6px;padding:1px 6px;font-size:8px;font-weight:800;color:#555}
.cam{position:relative;margin:4px 12px;height:190px;border-radius:18px;overflow:hidden}.cam img{width:100%;height:100%;object-fit:cover}.cam .tg{position:absolute;left:8px;top:8px;background:rgba(0,0,0,.5);color:#fff;border-radius:99px;padding:2px 8px;font-size:8.5px;font-weight:700}
.cam .fl{position:absolute;right:8px;top:8px;display:flex;gap:6px}.cam .fl div{width:26px;height:26px;border-radius:50%;background:rgba(0,0,0,.45);display:grid;place-items:center;color:#fff;font-size:12px}
.mo{display:flex;gap:7px;padding:6px 12px}.mo div{flex:1;border:1.5px solid #dcdcd4;background:#fff;border-radius:14px;padding:8px}.mo div.sel{border-color:#ffc400;background:#fff9de}
.mo b{font-size:11px;display:block}.mo small{color:#666;font-size:8.5px;line-height:1.25;display:block;margin-top:2px}
.fi{margin:4px 12px;border:1px solid #dcdcd4;background:#fff;border-radius:12px;padding:8px 10px;color:#888;font-size:10px}
.sgm{display:flex;margin:6px 12px;background:#eee;border-radius:99px;padding:3px}.sgm span{flex:1;text-align:center;padding:5px;border-radius:99px;font-weight:700;font-size:10px;color:#555}.sgm .on{background:#fff;color:#14201a;box-shadow:0 1px 3px rgba(0,0,0,.15)}
.opt{margin:4px 12px;display:flex;justify-content:space-between;padding:8px 2px;border-top:1px solid #e6e6e0;font-size:10px;font-weight:700}
.go{position:absolute;left:12px;right:12px;bottom:12px;background:#ffc400;color:#3a2c00;text-align:center;font-weight:900;border-radius:24px;padding:12px;font-size:13px}
.prods{display:flex;gap:6px;padding:2px 12px}.prods div{width:70px;font-size:8px}.prods img{width:70px;height:70px;border-radius:10px;object-fit:cover;display:block}.prods b{display:block;margin-top:2px}.prods .ck{position:relative}.prods .ck:after{content:"✓";position:absolute;right:4px;top:4px;width:15px;height:15px;border-radius:50%;background:#1b8a3c;color:#fff;font-size:9px;display:grid;place-items:center}
.liveE{position:absolute;inset:0;color:#fff;background:#000}.liveE>img{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.tag{position:absolute;z-index:3;top:50px;left:11px;display:flex;gap:6px}.tag span{border-radius:99px;padding:2px 9px;font-size:9px;font-weight:800;background:rgba(0,0,0,.55)}.tag .r{background:#e5383b}
.jn{position:absolute;z-index:3;left:11px;right:66px;bottom:22px}.jn b{font-size:13px;display:block;text-shadow:0 1px 4px rgba(0,0,0,.7)}.jn p{margin:3px 0 8px;font-size:10.5px;text-shadow:0 1px 4px rgba(0,0,0,.7)}.jn .b{background:#ffc400;color:#3a2c00;border-radius:22px;padding:10px;text-align:center;font-weight:900;font-size:12px}
.emp{position:absolute;inset:0;background:#000;color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:0 26px}.emp h4{margin:16px 0 6px;font-size:16px}.emp p{margin:0 0 18px;font-size:11px;opacity:.75;line-height:1.4}.emp .b{background:#ffc400;color:#3a2c00;border-radius:24px;padding:12px;width:100%;font-weight:900;font-size:13px}.emp small{margin-top:10px;opacity:.7}
.nd{position:absolute;inset:0;background:rgba(0,0,0,.35)}.nc{position:absolute;left:10px;right:10px;bottom:10px;background:rgba(255,255,255,.96);border:1.5px solid #ffd21f;border-radius:26px;padding:12px;text-align:center}
.nc h5{margin:6px 0 2px;font-size:13px}.nc p{margin:0 0 8px;font-size:9.5px;color:#666}.nc .gs{display:flex;gap:6px;justify-content:center;margin-bottom:8px}.nc .gs div{background:#f0f0ea;border-radius:12px;padding:6px 12px;font-size:9px;font-weight:700}.nc .gs i{display:block;font-style:normal;font-size:18px}
.nc .b{background:#ffc400;border-radius:20px;padding:9px;font-weight:900;font-size:11.5px}.nc small{display:block;margin-top:6px;color:#888}
'''
CSS = CSS + EXTRA

def phone(inner):
    return '<div class="phone">%s</div>' % inner

TOP = '<div class="hd"><span style="font-size:15px">←</span> Vidéo</div>'
PL = '<div class="pl"><span class="on">%s 12,4 k</span><span>%s 320</span><span>%s 58</span><span>%s</span><span>%s</span></div>' % (SV['heart'], SV['chat'], SV['gift'], SV['share'], SV['more'])
LAND = ('<div class="lp">' + TOP + '<div class="player"><img src="%s" alt="" style="object-position:center 25%%"><div class="ctl">▶ <i></i> 1:12</div></div>'
        '<div class="ttl">Mon premier concert à Lomé : les coulisses</div><div class="meta">24 k vues · il y a 2 h</div>'
        '<div class="cr"><img src="%s" alt=""><div><b>jay.beats</b><small>50 k abonnés</small></div><span class="fo">Suivre</span></div>' + PL +
        '<div class="cf">Ajouter un commentaire…</div>'
        '<div class="nat"><span>Annonce</span><div>Emplacement pub du réseau (Appodeal / AdMob), sinon Afrolook Ads</div></div>'
        '<div class="sg"><img src="%s" alt=""><div><b>Répétition du week-end</b><small>zuri.danse · 12 k vues</small></div></div>'
        '<div class="sg"><img src="%s" alt=""><div><b>Cuisine du dimanche</b><small>mama.cuisine · 8 k vues</small></div></div></div>') % (
    im('n_ig_b.jpg'), im('h_3864774.jpg'), im('n_dj.jpg'), im('n_food.jpg'))
NUDGE = LAND.replace('</div></div>', '</div></div>', 0)[:-6] + ('<div class="nd"></div><div class="nc"><h5>Cette vidéo te plaît ?</h5><p>Remercie jay.beats avec un cadeau : il le reçoit tout de suite.</p>'
        '<div class="gs"><div><i>🌹</i>Rose 10</div><div><i>❤️</i>Coeur 25</div><div><i>👑</i>Couronne 50</div></div><div class="b">Offrir un cadeau</div><small>Plus tard</small></div></div>')
CREATE = ('<div class="lp"><div class="hd"><span style="font-size:15px">←</span> Lancer un live</div>'
          '<div class="cam"><img src="%s" alt="" style="object-position:center 20%%"><span class="tg">Aperçu · caméra avant</span><div class="fl"><div>⟲</div><div>✦</div></div></div>'
          '<div class="mo"><div class="sel"><b>Discussion</b><small>Parle, échange, reçois des cadeaux</small></div><div><b>Vente en direct</b><small>Vends les articles de ta boutique</small></div></div>'
          '<div class="fi">Donne un titre à ton live…</div>'
          '<div class="sgm"><span class="on">Gratuit</span><span>Payant</span></div>'
          '<div class="opt"><span>Options</span><span>Qualité, flou, invités ›</span></div>'
          '<div class="go">Passer en direct</div></div>') % im('f_7229044.jpg')
CREATE2 = ('<div class="lp"><div class="hd"><span style="font-size:15px">←</span> Lancer un live</div>'
           '<div class="cam" style="height:120px"><img src="%s" alt="" style="object-position:center 20%%"><span class="tg">Aperçu · caméra arrière</span></div>'
           '<div class="mo"><div><b>Discussion</b><small>Parle, échange, reçois des cadeaux</small></div><div class="sel"><b>Vente en direct</b><small>Vends les articles de ta boutique</small></div></div>'
           '<div class="ttl" style="padding-top:4px;font-size:11px">Produits à épingler (3 sur 5)</div>'
           '<div class="prods"><div class="ck"><img src="%s" alt=""><b>Jupe wax</b>12 500 F</div><div class="ck"><img src="%s" alt=""><b>Robe</b>18 000 F</div><div><img src="%s" alt=""><b>Sac</b>9 000 F</div></div>'
           '<div class="fi" style="margin-top:8px">Titre : Vente flash du samedi</div>'
           '<div class="opt"><span>Livraison et codes promo</span><span>Mes réglages ›</span></div>'
           '<div class="go">Passer en direct</div></div>') % (im('n_av_food.jpg'), im('n_av_mic.jpg'), im('n_av_mic.jpg'), im('n_av_food.jpg'))
LIVEV = ('<div class="phone"><div class="v"><div class="liveE"><img src="%s" alt="" style="object-position:center 15%%"><div class="shade"></div>'
         '<div class="tabs"><span>Suivis</span><span>Pour toi</span><span class="on">Lives</span></div>'
         '<div class="tag"><span class="r">EN DIRECT</span><span>12,4 k</span></div>'
         '<div class="rail"><div class="btn">%s</div></div>'
         '<div class="jn"><b>@mariam.live</b><p>Vente flash du samedi, jupes en wax</p><div class="b">Rejoindre le live</div></div></div></div></div>') % (im('f_7229044.jpg'), SV['mute'].replace('mute', 'cam'))
EMPTY = ('<div class="phone"><div class="v"><div class="emp"><div class="btn" style="width:70px;height:70px"><svg viewBox="0 0 24 24" style="width:34px;height:34px"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="M16 10l5-3v10l-5-3z"/></svg></div>'
         '<h4>Aucun live en ce moment</h4><p>Sois le premier : lance ton live et ta communauté te rejoint, avec cadeaux et vente en direct.</p><div class="b">Lancer un live</div><small>Voir les vidéos</small></div>'
         '<div class="tabs"><span>Suivis</span><span>Pour toi</span><span class="on">Lives</span></div></div></div>')

HTML = '''<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Vidéo paysage, création de live, onglet Lives · proposition</title><style>%(css)s</style></head><body><div class="wrap">
<h1>Vidéo paysage, création de live et onglet Lives : proposition à valider</h1>
<p class="lead"><b>Rien n'est modifié pour ces trois pages.</b> Déjà fait et commité (à tester sur téléphone) : la page des vidéos verticales validée, avec l'invitation à offrir un cadeau et un premier onglet Lives vertical. Ici, ce que je propose pour harmoniser le reste.</p>

<h2>1. Page vidéo paysage (YouTube-like)</h2>
<div class="row"><figure>%(land)s<figcaption>Nouvelle page<small>Même famille d'icônes et de pastilles que la page verticale</small></figcaption></figure>
<figure>%(nudge)s<figcaption>Invitation à offrir un cadeau<small>La même modale fluide que dans les vidéos verticales</small></figcaption></figure>
<div style="flex:1;min-width:300px;max-width:520px"><div class="card"><h3>Ce que j'ai relevé dans la page actuelle (<code>postDetailsVideo.dart</code>, 2 563 lignes)</h3><ul class="t">
<li>Lecteur 16/9, en-tête créateur avec « Suivre », rangée de statistiques, rangée de boutons d'action, aperçu du dernier commentaire, badge de score, section « Booster », liste de vidéos suggérées, bannière et pub native.</li>
<li>Plusieurs couleurs et tailles d'icônes, boutons sans pastille, textes en dur (pas tous traduits), badge de score et pièces en plus.</li></ul></div>
<div class="card"><h3>Ce que je propose</h3><ul class="t">
<li><b>Une seule rangée de boutons en pastilles claires</b> : j'aime, commentaires, cadeau, partager, « ⋯ » (favoris, booster, signaler, supprimer dans le menu).</li>
<li><b>Champ « Ajouter un commentaire… »</b> qui ouvre la page des commentaires (même règle que dans les vidéos verticales), plus d'aperçu de commentaire.</li>
<li><b>Titre, vues, date, créateur + Suivre</b> en tête ; description repliée (« plus »).</li>
<li><b>Pub</b> : un emplacement entre la description et les suggestions et un autre toutes les 4 suggestions : pub du réseau (Appodeal / AdMob) d'abord, Afrolook Ads sinon, jamais pour les comptes Gold.</li>
<li><b>Invitation à offrir un cadeau</b> après 14 secondes de lecture, mêmes règles qu'en vertical.</li>
<li><b>Plein écran paysage</b> : le lecteur passe en plein écran, les pastilles restent dessous. Le badge de score et les pièces reçues quittent la page (visibles dans « ⋯ »).</li></ul></div></div></div>

<h2>2. Création d'un live : deux modes, une seule page</h2>
<div class="row"><figure>%(create)s<figcaption>Mode « Discussion »<small>Aperçu caméra, titre, Gratuit / Payant, Options repliées</small></figcaption></figure>
<figure>%(create2)s<figcaption>Mode « Vente en direct »<small>Produits à épingler, livraison et codes promo</small></figcaption></figure>
<div style="flex:1;min-width:300px;max-width:520px"><div class="card"><h3>Page actuelle (<code>create_live_page.dart</code>, 2 615 lignes)</h3><ul class="t">
<li>Choix « Format du live » (Discussion ou Vente en direct), « Type de live » (gratuit ou payant), titre, prix, durée d'essai, comportement du son et du flou après l'essai, limites mensuelles.</li>
<li><b>Écrans qui vendent encore « Premium »</b> (comparaison SD / HD, « Passer à Premium », « 500 pièces/mois ») alors que le plan Premium n'existe plus : à remplacer par Gold (abonnement ou pubs).</li>
<li>Des icônes en emoji dans les listes (« ✅ », « ❌ », « 🔇 »), des boutons en majuscules, un formulaire long.</li></ul></div>
<div class="card"><h3>Ce que je propose</h3><ul class="t">
<li><b>Aperçu de la caméra tout en haut</b> (on se voit avant de lancer), boutons pour retourner la caméra et pour les effets.</li>
<li><b>Deux grandes cartes</b> pour le mode : « Discussion » et « Vente en direct ». Le choix change la suite du formulaire : en vente, la liste des produits à épingler, la livraison et les codes promo.</li>
<li><b>Gratuit / Payant</b> en sélecteur ; le prix, l'essai gratuit et le comportement après l'essai n'apparaissent que si « Payant ».</li>
<li><b>Options repliées</b> (qualité, flou, invités) ; un grand bouton jaune « Passer en direct ».</li>
<li><b>Gold</b> remplace Premium : la qualité HD s'obtient avec Gold (abonnement ou pubs), expliquée en une ligne, pas en deux pages de comparaison.</li>
<li>Couleurs et icônes du thème (aucun emoji), textes dans les 8 langues.</li></ul></div></div></div>

<h2>3. Onglet Lives de la page verticale</h2>
<div class="row"><figure>%(livev)s<figcaption>Un live en plein écran<small>On défile de live en live, un toucher rejoint</small></figcaption></figure>
<figure>%(empty)s<figcaption>Aucun live<small>La page invite à lancer le sien</small></figcaption></figure>
<div style="flex:1;min-width:300px;max-width:520px"><div class="card"><h3>État de ce qui est déjà codé</h3><ul class="t">
<li>Les lives en cours défilent en plein écran (image de couverture, EN DIRECT, spectateurs, @hôte, titre, « Rejoindre le live »).</li>
<li>Sans live : « Aucun live en ce moment », bouton « Lancer un live » (ouvre la page de création) et « Voir les vidéos ».</li>
<li><b>Limite actuelle</b> : la vignette est une image ; lire le live directement dans le défilement (flux Agora) demande de tester à deux téléphones, je le propose en deuxième temps.</li></ul></div></div></div>

<h2>À valider</h2>
<div class="card"><ol style="margin:0;padding-left:20px"><li>La page vidéo paysage : une rangée de 5 pastilles, champ qui ouvre les commentaires, pubs en 2 emplacements, invitation cadeau.</li>
<li>La création de live : aperçu caméra, deux cartes de mode, formulaire qui change selon le mode, options repliées, Gold à la place de Premium.</li>
<li>L'onglet Lives : image de couverture au début, lecture directe du flux plus tard.</li></ol>
<p class="note">Photos d'exemple (Pexels). Après votre accord, je code la page paysage, puis la création de live.</p></div>
</div></body></html>''' % {'css': CSS, 'land': phone(LAND), 'nudge': phone(NUDGE), 'create': phone(CREATE), 'create2': phone(CREATE2), 'livev': LIVEV, 'empty': EMPTY}

open('lives_et_paysage_proposition.html', 'w', encoding='utf-8').write(HTML)

def emb(m):
    return 'src="data:image/jpeg;base64,%s"' % base64.b64encode(open(m.group(1), 'rb').read()).decode()

open('lives_et_paysage_proposition_autonome.html', 'w', encoding='utf-8').write(re.sub(r'src="(img/[^"]+)"', emb, HTML))
print(len(HTML) // 1024, 'Ko')
