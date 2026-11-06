# -*- coding: utf-8 -*-
# Génère authentique_proposition.html (+ autonome) : avertissement « plus monétisé », badge « Validé », vérification en 3 lectures.
import os, re, base64
HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)
ns = {'__file__': os.path.join(HERE, '_videos_build.py')}
src = open('_videos_build.py', encoding='utf-8').read()
src = src[:src.index("HTML = '''")]
exec(src, ns)
CSS, SV, im = ns['CSS'], ns['SV'], ns['im']

CSS += r'''
.warnchip{position:absolute;z-index:4;left:11px;bottom:96px;display:inline-flex;align-items:center;gap:6px;background:rgba(255,196,0,.96);color:#3a2c00;border-radius:99px;padding:6px 11px;font-weight:800;font-size:10px;box-shadow:0 4px 14px rgba(0,0,0,.35)}
.warnchip svg{width:14px;height:14px;fill:none;stroke:#3a2c00;stroke-width:2;stroke-linecap:round;stroke-linejoin:round}
.okbadge{display:inline-flex;align-items:center;gap:4px;background:rgba(27,138,60,.95);color:#fff;border-radius:99px;padding:2px 8px 2px 5px;font-size:9px;font-weight:800;margin-left:6px;text-shadow:none;vertical-align:middle}
.okbadge svg{width:11px;height:11px;fill:none;stroke:#fff;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}
.sheet2{position:absolute;left:0;right:0;bottom:0;background:#fff;color:#14201a;border-radius:22px 22px 0 0;padding:14px 14px 16px;z-index:6;box-shadow:0 -10px 30px rgba(0,0,0,.35)}
.sheet2 .grab{width:36px;height:4px;border-radius:3px;background:#ddd;margin:0 auto 10px}.sheet2 h4{margin:0 0 6px;font-size:13.5px}.sheet2 p{margin:0 0 8px;font-size:10px;line-height:1.45;color:#444}
.sheet2 ul{margin:0 0 10px;padding-left:15px;font-size:10px;line-height:1.5;color:#444}.sheet2 .btn2{border-radius:20px;padding:9px;text-align:center;font-weight:900;font-size:11px}.btn2.y{background:#ffc400;color:#3a2c00}.btn2.o{border:1.5px solid #bbb;margin-top:6px}
.dim2{position:absolute;inset:0;background:rgba(0,0,0,.45);z-index:5}
.fd{position:absolute;inset:0;background:#fafaf8;color:#14201a;font-family:Roboto,system-ui,sans-serif;font-size:10px;overflow:hidden}
.fd .hd{padding:10px 12px;font-weight:800;font-size:13px}
.fcard{margin:6px 10px;border:1px solid #e2e2dc;border-radius:16px;background:#fff;overflow:hidden}.fcard .who{display:flex;gap:7px;align-items:center;padding:8px 9px}.fcard .who img{width:26px;height:26px;border-radius:50%;object-fit:cover}.fcard b{font-size:10.5px}.fcard small{display:block;color:#777;font-size:8.5px}
.fcard .im{position:relative;height:170px;background:#000}.fcard .im>img{width:100%;height:100%;object-fit:cover;display:block}.fcard .im .tg{position:absolute;left:8px;bottom:8px}
.fcard .ac{display:flex;gap:12px;padding:7px 10px;font-size:9.5px;color:#555}
.cb{display:inline-flex;align-items:center;gap:5px;border-radius:99px;padding:2px 9px 2px 6px;font-size:8.5px;font-weight:800}.cb.ok{background:#1b8a3c;color:#fff}.cb.wn{background:#ffc400;color:#3a2c00}
.cb svg{width:10px;height:10px;fill:none;stroke:currentColor;stroke-width:2.4;stroke-linecap:round;stroke-linejoin:round}
.own{margin:8px 10px;background:#fff7d6;border:1px solid #ffd66b;border-radius:14px;padding:10px;font-size:9.5px;line-height:1.45}.own b{display:block;font-size:11px;margin-bottom:3px}.own .b2{display:inline-block;margin-top:6px;background:#ffc400;color:#3a2c00;border-radius:99px;padding:6px 12px;font-weight:900}
.st{width:100%;border-collapse:collapse;font-size:13.5px}.st td,.st th{padding:8px 10px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}
.tl3{display:flex;gap:10px;flex-wrap:wrap;margin:6px 0}.tl3 div{flex:1;min-width:150px;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:10px;font-size:13px}.tl3 b{display:block;font-size:12px;color:var(--green);margin-bottom:3px}
'''
CHECK = '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'
WARN = '<svg viewBox="0 0 24 24"><path d="M12 3l10 18H2z"/><path d="M12 10v5M12 18v.5"/></svg>'

def phone(x): return '<div class="phone">%s</div>' % x

def vid(photo, with_warn=False, with_badge=False, sheet=False, pos='center 15%'):
    badge = '<span class="okbadge">%s Validé</span>' % CHECK if with_badge else ''
    warn = '<div class="warnchip">%s Ce post n\'est plus monétisé · En savoir plus ›</div>' % WARN if with_warn else ''
    sh = ''
    if sheet:
        sh = ('<div class="dim2"></div><div class="sheet2"><div class="grab"></div><h4>Pourquoi ce post n\'est plus monétisé ?</h4>'
              '<p>Plusieurs lectures de cette vidéo ont montré la marque d\'un autre réseau (TikTok). Afrolook met en avant les contenus authentiques, propres à la plateforme.</p>'
              '<ul><li>Les vues de ce post ne rapportent plus de pièces.</li><li>Il reste visible, mais n\'est plus mis en avant.</li><li>Les cadeaux restent possibles.</li></ul>'
              '<p><b>C\'est ta vidéo ?</b> Dis-le-nous : notre équipe la vérifie.</p><div class="btn2 y">C\'est ma vidéo</div><div class="btn2 o">Lire les règles</div></div>')
    return ('<div class="v"><img class="bg" src="%s" alt="" style="object-position:%s"><div class="shade"></div>'
            '<div class="tabs"><span>Suivis</span><span class="on">Pour toi</span><span>Lives</span></div>'
            '<div class="rail"><div class="av"><img src="%s" alt=""><i>+</i></div><div class="btn">%s</div><div class="btn">%s</div><div class="btn">%s</div><div class="btn">%s</div></div>'
            '%s<div class="info"><b>@zuri.danse%s</b><span class="s">58 k abonnés</span><p>Chorégraphie du week-end</p></div>'
            '<div class="field">Ajouter un commentaire…</div>%s</div>') % (im(photo), pos, im(photo), SV['heart'], SV['chat'], SV['gift'], SV['share'], warn, badge, sh)

VID_WARN = phone(vid('h_6774139.jpg', with_warn=True))
VID_SHEET = phone(vid('h_6774139.jpg', with_warn=True, sheet=True))
VID_OK = phone(vid('f_8727469.jpg', with_badge=True))

FEED = ('<div class="phone"><div class="fd"><div class="hd">Afrolook</div>'
        '<div class="fcard"><div class="who"><img src="%s" alt=""><div><b>aminata_k</b><small>1,2 M abonnés</small></div></div><div class="im"><img src="%s" alt="" style="object-position:center 20%%"><span class="tg"><span class="cb ok">%s Validé</span></span></div><div class="ac"><span>♡ 340</span><span>💬 12</span><span>🎁 58</span></div></div>'
        '<div class="fcard"><div class="who"><img src="%s" alt=""><div><b>jay.beats</b><small>50 k abonnés</small></div></div><div class="im"><img src="%s" alt="" style="object-position:center 20%%"><span class="tg"><span class="cb wn">%s Non monétisé</span></span></div><div class="ac"><span>♡ 12</span><span>💬 1</span></div></div></div></div>') % (
    im('f_8727469.jpg'), im('f_8727469.jpg'), CHECK, im('h_3864774.jpg'), im('h_3864774.jpg'), WARN)

OWNER = ('<div class="phone"><div class="fd"><div class="hd">← Ma publication</div>'
         '<div class="fcard"><div class="im" style="height:150px"><img src="%s" alt="" style="object-position:center 20%%"><span class="tg"><span class="cb wn">%s Non monétisé</span></span></div></div>'
         '<div class="own"><b>Cette vidéo semble venir d\'un autre réseau</b>La marque TikTok a été vue lors de plusieurs lectures. Ses vues ne rapportent plus de pièces et elle n\'est plus mise en avant.<br><span class="b2">C\'est ma vidéo</span></div>'
         '<div class="own" style="background:#eaf6ee;border-color:#bfe3c9"><b>Comment retrouver la monétisation ?</b>Si la vidéo est la tienne, notre équipe la vérifie. Si elle est validée, elle redevient monétisée et reçoit le badge Validé.</div></div></div>') % (im('h_3864774.jpg'), WARN)

HTML = '''<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Vidéos authentiques : avertissement et badge · proposition</title><style>%(css)s</style></head><body><div class="wrap">
<h1>Vidéos déjà publiées : avertissement « plus monétisé » et badge « Validé »</h1>
<p class="lead"><b>Rien n'est modifié.</b> Voici ce que verrait la personne qui regarde, celle qui a publié, et ce que deviennent les vues. Je donne aussi les règles de décision, pour que vous jugiez si la vérification vous convient.</p>

<h2>1. Ce que voit la personne qui regarde</h2>
<div class="row"><figure>%(w)s<figcaption>Vidéo détectée<small>Pastille jaune au-dessus du bas : « Ce post n'est plus monétisé · En savoir plus »</small></figcaption></figure>
<figure>%(s)s<figcaption>En savoir plus<small>Feuille d'explication, avec « C'est ma vidéo » et un lien vers les règles</small></figcaption></figure>
<figure>%(o)s<figcaption>Vidéo validée<small>Badge vert « Validé » à côté du @pseudo</small></figcaption></figure>
<figure>%(f)s<figcaption>Dans le fil<small>Badge « Validé » ou « Non monétisé » sur la vignette</small></figcaption></figure>
<figure>%(ow)s<figcaption>Vu par la personne qui a publié<small>Explication, « C'est ma vidéo », comment retrouver la monétisation</small></figcaption></figure></div>

<h2>2. Les quatre états d'une vidéo</h2>
<div class="card"><table class="st"><tr><th>État</th><th>Ce qu'on affiche</th><th>Monétisation par les vues</th></tr>
<tr><td><b>Non vérifiée</b> (nouvelle, ou moins de 3 lectures contrôlées)</td><td>Aucun badge</td><td>Normale</td></tr>
<tr><td><b>Validée</b> (3 lectures différentes, rien trouvé)</td><td>Badge vert « Validé »</td><td>Normale</td></tr>
<tr><td><b>Marquée</b> (une marque d'un autre réseau vue à plusieurs lectures)</td><td>Pastille « Ce post n'est plus monétisé », feuille d'explication</td><td><b>Aucune vue ne rapporte</b> ; le post n'est plus mis en avant</td></tr>
<tr><td><b>En examen</b> (la personne a dit « C'est ma vidéo », ou les lectures se contredisent)</td><td>« En vérification » pour la personne qui a publié ; rien pour les autres</td><td>Suspendue jusqu'à la décision de l'équipe</td></tr></table></div>

<h2>3. Comment la vérification se fait (gratuit, sur les téléphones)</h2>
<div class="tl3"><div><b>Lecture 1</b>Quand quelqu'un regarde la vidéo, son téléphone lit 3 à 5 images avec la reconnaissance de texte gratuite de Google et envoie seulement le résultat : « rien » ou « TikTok vu ». Aucune image n'est envoyée.</div>
<div><b>Lecture 2 et 3</b>Deux autres personnes <b>différentes</b>, à d'autres moments, refont le même contrôle. Un même compte ne compte qu'une fois.</div>
<div><b>Décision</b>3 contrôles propres : badge « Validé ». TikTok vu par 2 personnes différentes : « Marquée ». Une seule détection isolée ou des résultats contraires : « En examen » par l'équipe, rien n'est affiché.</div></div>
<div class="card"><ul class="t" style="margin:0;padding-left:18px"><li><b>Pourquoi plusieurs lectures :</b> un téléphone peut se tromper (image floue, texte caché) ou envoyer un faux résultat. Trois lectures différentes rendent un faux badge, ou une fausse accusation, très difficile.</li>
<li><b>Les vidéos déjà publiées</b> sont contrôlées au fil des lectures, sans rien refaire pour les créateurs.</li><li><b>Les vidéos filmées dans l'application</b> peuvent être validées d'office (elles viennent de notre caméra) : à confirmer.</li><li><b>Limites :</b> les logos recadrés ou floutés et les téléchargeurs « sans filigrane » passent ; ils auront le badge « Validé » à tort. Le badge dit « aucune marque détectée », pas « authentifié par un humain ».</li></ul></div>

<h2>4. Textes proposés pour les pages « Règles » et « Confidentialité »</h2>
<div class="row"><div class="card" style="flex:1;min-width:300px"><h3>Règles (nouvelle section « Contenus authentiques »)</h3><ul class="t" style="margin:0;padding-left:18px"><li>Afrolook met en avant les contenus authentiques, propres à la plateforme.</li><li>Les vidéos téléchargées d'autres réseaux (TikTok, Instagram, Facebook…) sont refusées. Les vidéos montées avec un éditeur (CapCut, InShot…) sont acceptées.</li><li>Une vidéo identifiée comme venant d'un autre réseau n'est plus monétisée : ses vues ne rapportent plus de pièces, et elle n'est plus mise en avant.</li><li>Si la vidéo est la tienne, tu peux demander une vérification : « C'est ma vidéo ».</li><li>Le badge « Validé » signifie qu'aucune marque d'un autre réseau n'a été détectée après plusieurs contrôles.</li></ul></div>
<div class="card" style="flex:1;min-width:300px"><h3>Confidentialité (nouvelle section « Vérification des vidéos »)</h3><ul class="t" style="margin:0;padding-left:18px"><li>Pendant la lecture d'une vidéo, ton téléphone peut en analyser quelques images pour y chercher le logo ou le nom d'un autre réseau.</li><li>L'analyse se fait <b>sur ton téléphone</b>, avec une reconnaissance de texte qui fonctionne hors ligne.</li><li>Aucune image ni aucun texte n'est envoyé : seul le résultat (« rien détecté » ou « marque détectée ») est envoyé à Afrolook, avec l'identifiant de la vidéo.</li><li>Ce résultat sert à afficher le badge et à décider de la monétisation de la vidéo ; il n'est pas lié à ton profil publicitaire.</li></ul></div></div>

<h2>À valider</h2>
<div class="card"><ol style="margin:0;padding-left:20px"><li>Les quatre états et leurs affichages (pastille jaune, feuille d'explication, badge vert, étiquettes dans le fil).</li><li>La règle de décision : 3 contrôles propres de 3 personnes différentes pour « Validé » ; 2 détections de personnes différentes pour « Marquée » ; sinon examen par l'équipe.</li><li>Aucune vue ne rapporte pour une vidéo marquée ; elle n'est plus mise en avant.</li><li>Les vidéos filmées dans l'application : badge « Validé » d'office ?</li><li>Les deux textes (règles et confidentialité), que je mettrai dans l'application et sur le site dans les 8 langues.</li></ol>
<p class="note">Après votre accord : API (résultats, états, vues non monétisées, tests), application (analyse pendant la lecture, pastille, feuille, badge), pages de règles et de confidentialité.</p></div>
</div></body></html>''' % {'css': CSS, 'w': VID_WARN, 's': VID_SHEET, 'o': VID_OK, 'f': FEED, 'ow': OWNER}
open('authentique_proposition.html', 'w', encoding='utf-8').write(HTML)
emb = lambda m: 'src="data:image/jpeg;base64,%s"' % base64.b64encode(open(m.group(1), 'rb').read()).decode()
open('authentique_proposition_autonome.html', 'w', encoding='utf-8').write(re.sub(r'src="(img/[^"]+)"', emb, HTML))
print(len(HTML) // 1024, 'Ko')
