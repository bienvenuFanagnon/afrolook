// Afrolook Ads : documentation d'intégration pour les diffuseurs (sites et applications) et page publique des règles des diffuseurs.
// Les chiffres (durées de vue, intervalles, prix) sont ceux du serveur : afrolook-api app/Ads/Engine.php (FORMATS). À mettre à jour ensemble.
import { ico, G, adsSubnav } from './ads.mjs';
import { RULES, CATS, esc, rulesHtml } from './ads_data.mjs';

export const RULES_META = { title: 'Règles des diffuseurs | Afrolook Ads', desc: 'Les règles à accepter pour afficher les annonces Afrolook Ads sur ton site ou ton application : audience, comptage, rémunération, catégories, données.' };
export const DOCS_META = { title: 'Documentation d\'intégration | Afrolook Ads', desc: 'Afficher les annonces Afrolook Ads sur un site ou une application : balise web, WordPress, React, composant Flutter, API, les 8 formats en images, comptage et paiement.' };

const code = (lang, text) => `<pre class="doc-code" data-lang="${lang}"><code>${esc(text.replace(/^\n/, ''))}</code></pre>`;

export function adsRulesPage() {
  return `${adsSubnav('regles')}<section class="adsp"><div class="wrap doc">
 <span class="kicker">Afrolook Ads · Diffuseurs</span><h1 class="h2" style="margin-top:6px">Règles des diffuseurs</h1>
 <p class="sub">Version <b>${esc(RULES.version)}</b>. Tu les acceptes en créant ton profil de diffuseur ; si elles changent, la version change et tu dois les accepter de nouveau pour ajouter un site ou une application.</p>
 <div class="rules">${rulesHtml()}</div>
 <p class="adnote">Contenus refusés pour tous les annonceurs : ${esc(CATS.forbidden.join(', '))}.</p>
 <div class="cta"><a class="btn btn-primary adbig" href="/ads/diffuseur/">Devenir diffuseur</a><a class="btn btn-line adbig" href="/ads/diffuseur/documentation/">Documentation d'intégration</a></div>
</div></section>`;
}

const FMT = [
  ['Bannière', 'banner', '1 s', '30 s', '1 000 F', 'oui'], ['Bandeau collant', 'sticky', '1 s', '30 s', '1 250 F', 'oui'], ['Carte native', 'native', '1 s', '20 s', '1 500 F', 'oui'],
  ['Carrousel', 'carousel', '1 s', '20 s', '1 800 F', 'oui'], ['Affiche', 'poster', '1 s', '20 s', '2 000 F', 'oui'], ['Vidéo dans le fil', 'video', '2 s', '20 s', '2 500 F', 'oui'],
  ['Interstitiel', 'interstitial', '1 s', '10 min', '3 000 F', 'oui'], ['Récompensée', 'rewarded', '1 s, puis lecture complète', '5 min', '3 500 F (vue complète)', 'oui'],
];

/** Part du diffuseur (65 %) d'un prix annonceur écrit « 1 250 F » ou « 3 500 F (vue complète) » : arrondie vers le bas au demi-franc, jamais au-dessus. */
const share = (p) => {
  const n = Math.floor(parseInt(String(p).replace(/[^\d]/g, ''), 10) * 0.65 * 2) / 2;
  const txt = (n % 1 ? n.toFixed(2) : String(n)).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '\u00a0');
  return txt + ' F' + (/complète/.test(p) ? ' (vue complète)' : '');
};

// ─── Documentation d'intégration (refonte du 17/11/2026, maquette validée) : menu fixe, code dans des cadres sombres à onglets avec « Copier »,
// seulement ce dont l'intégrateur a besoin (le comptage des vues est fait par nos composants), vraies captures des formats sur nos plateformes.
const hl = (text) => esc(text.replace(/^\n/, ''))
  .replace(/&lt;!--[\s\S]*?--&gt;/g, (m) => `<span class="c">${m}</span>`)
  .replace(/(^|[ \t])(\/\/[^\n]*)/gm, '$1<span class="c">$2</span>');   // un commentaire commence en début de ligne ou après un espace (pas les « // » d'une adresse)
const lines = (t) => hl(t).split('\n').map((l, i) => `<span class="ln">${i + 1}</span>${l}`).join('\n');
/** Cadre de code : onglets (libellé, texte), langue, fichier et pied facultatifs. */
const box = (tabs, { lang = '', file = '', foot = '', num = true } = {}) => `<div class="dcode"${tabs.length > 1 ? ' data-tabs' : ''}><div class="dcode-h">` +
  (tabs.length > 1 ? tabs.map(([l], i) => `<button class="tab${i ? '' : ' on'}" type="button">${esc(l)}</button>`).join('') : `<span class="file">${esc(file || tabs[0][0])}</span>`) +
  (lang ? `<span class="lang">${esc(lang)}</span>` : '') + '<button class="copy" type="button">Copier</button></div>' +
  tabs.map(([, t], i) => `<pre${i ? ' hidden' : ''}><code>${num ? lines(t) : hl(t)}</code></pre>`).join('') + (foot ? `<div class="dcode-f">${foot}</div>` : '') + '</div>';
const call = (kind, html) => `<div class="dcall ${kind}"><i>${kind === 'ok' ? '✓' : kind === 'info' ? 'i' : '!'}</i><p>${html}</p></div>`;
const params = (rows) => `<div class="dparams">${rows.map(([k, req, type, d]) => `<div><span><code>${k}</code>${req ? '<em>obligatoire</em>' : ''}${type ? `<small>${type}</small>` : ''}</span><span>${d}</span></div>`).join('')}</div>`;

const SHOTS = [
  ['banniere_320x100', 'Bannière 320 × 100', 'banner', 'PronoFlash IA · téléphone', 'Vue après 1 s · 650 F pour 1 000 vues'],
  ['rectangle_300x250', 'Rectangle 300 × 250', 'banner', 'SlashAtlas · téléphone', '1 s · 650 F pour 1 000'],
  ['bandeau_collant_320x50', 'Bandeau collant 320 × 50', 'sticky', 'SlashAtlas · bas de l’écran, fermable', '1 s · 812,50 F pour 1 000'],
  ['carte_native', 'Carte native', 'native', 'PronoFlash IA · dans le contenu', '1 s · 975 F pour 1 000'],
  ['carrousel', 'Carrousel', 'carousel', 'SlashAtlas · 2 à 5 images', '1 s · 1 170 F pour 1 000'],
  ['affiche', 'Affiche', 'poster', 'PronoFlash IA · pleine largeur', '1 s · 1 300 F pour 1 000'],
  ['video', 'Vidéo', 'video', 'SlashAtlas · sans son, 15 s au plus', '2 s · 1 625 F pour 1 000'],
  ['interstitiel', 'Interstitiel', 'interstitial', 'PronoFlash IA · plein écran, ✕ après 3 s', '1 s · 1 950 F pour 1 000'],
  ['recompensee', 'Récompensée', 'rewarded', 'SlashAtlas · regardée contre un avantage', 'Lecture complète · 2 275 F pour 1 000'],
];

export function adsDocsPage(api) {
  const A = (api || 'https://afrolookmedia.com') + '/ads/api';   // adresse publique stable de la régie (réécrite vers l'API)
  const ORIGIN = new URL(A).origin;
  const MEDIA = process.env.MEDIA_BASE || 'https://files.afrolookmedia.com';
  const TAG = '<script async src="https://afrolookmedia.com/ads/tag.js"></script>';
  const ins = (slot, fmt, extra = '') => `<ins class="afl-ad" data-pub="ap_xxxxxxxxxx" data-slot="${slot}" data-format="${fmt}"${extra}></ins>`;
  const nav = [
    ['Commencer', [['intro', 'Vue d’ensemble'], ['demarrer', 'Démarrage en 4 étapes'], ['choisir', 'Quelle intégration choisir ?']]],
    ['Intégrer', [['balise', 'Balise web'], ['wordpress', 'WordPress et sites sans code'], ['spa', 'React, Vue, Next.js'], ['flutter', 'Application Flutter'], ['natif', 'Android et iOS (API)']]],
    ['Référence de l’API', [['serve', 'Obtenir une annonce', 'GET'], ['erreurs', 'Codes d’erreur']]],
    ['Formats', [['formats', 'Les 8 formats'], ['matrice', 'Formats par intégration'], ['tailles', 'Tailles et bannières prêtes'], ['media', 'Vidéo + images']]],
    ['Règles et paiement', [['comptage', 'Comptage et fraude'], ['paiement', 'Gains et retraits'], ['categories', 'Catégories et ciblage'], ['verifier', 'Tester mon intégration'], ['faq', 'Questions fréquentes']]],
  ];
  return `${adsSubnav('docs')}<section class="adsp dx"><div class="dx-in">
<nav class="dx-side" aria-label="Documentation">${nav.map(([h, items]) => `<h4>${h}</h4>` + items.map(([id, l, m]) => `<a href="#${id}">${l}${m ? `<span class="m ${m.toLowerCase()}">${m}</span>` : ''}</a>`).join('')).join('')}</nav>
<div class="dx-main">

<section id="intro">
 <span class="kicker">Afrolook Ads · Diffuseurs</span>
 <h1 class="dx-h1">Affiche des annonces sur ton site ou ton application, et gagne à chaque vue</h1>
 <p class="dx-lead">Les annonces sont choisies, signées et comptées par les serveurs d’Afrolook Ads. Ton code se contente de les afficher : une balise de deux lignes sur un site, un composant prêt à l’emploi dans une application.</p>
 <div class="dx-cards">
  <a class="dx-card" href="#balise"><span class="ic">&lt;/&gt;</span><b>Balise web</b><span>Deux lignes à coller. Tous les formats, comptage automatique.</span><em>Le plus simple · 2 min</em></a>
  <a class="dx-card" href="#flutter"><span class="ic">F</span><b>Application Flutter</b><span>Un fichier à copier, une ligne par emplacement, les 8 formats.</span><em>Prêt à l’emploi · 5 min</em></a>
  <a class="dx-card" href="#serve"><span class="ic">{ }</span><b>API</b><span>Pour une application vérifiée qui dessine l’annonce elle-même.</span><em>Sur demande</em></a>
 </div>
</section>

<section id="demarrer">
 <h2>Démarrage en 4 étapes</h2>
 <ol class="dx-steps">
  <li><b>Crée ton profil de diffuseur</b>Dans <a href="/ads/diffuseur/">ton espace diffuseur</a> (connexion Google), en acceptant les <a href="/ads/diffuseur/regles/">règles</a>. Notre équipe le valide.</li>
  <li><b>Ajoute ton site ou ton application</b>Adresse du site, ou lien Google Play / App Store ; audience mensuelle ; pays ; catégories d’annonces que tu acceptes.</li>
  <li><b>Prouve que le site est à toi</b>Ajoute la balise de vérification de ton espace dans la page d’accueil, ou le code seul dans <code>/afrolook-ads.txt</code>.</li>
  <li><b>Reçois ton identifiant</b>Après validation : <code>ap_xxxxxxxxxx</code>. C’est lui qu’on met dans la balise.</li>
 </ol>
 ${box([['index.html · dans <head>', '<meta name="afrolook-ads-verify" content="afl-xxxxxxxxxxxxxxxxxxxxxxxx">']], { lang: 'HTML', num: false, foot: 'ou, seul dans le fichier <b>/afrolook-ads.txt</b> à la racine du site : <b>afl-xxxxxxxxxxxxxxxxxxxxxxxx</b> (ton code est dans ton espace)' })}
 ${call('warn', 'La balise de vérification doit <b>rester en place</b> : retirée 3 jours de suite, la diffusion est suspendue. L’identifiant ne marche que sur le site déclaré.')}
</section>

<section id="choisir">
 <h2>Quelle intégration choisir ?</h2>
 <div class="dx-tw"><table><thead><tr><th></th><th>Balise web</th><th>Composant Flutter</th><th>API</th></tr></thead><tbody>
  <tr><td>Pour</td><td>Sites (WordPress, HTML, React…)</td><td>Applications Flutter</td><td>Applications vérifiées, sur demande</td></tr>
  <tr><td>Code à écrire</td><td>Aucun : 2 lignes</td><td>1 ligne par emplacement</td><td>Dessin de l’annonce</td></tr>
  <tr><td>Comptage des vues</td><td class="y">Automatique</td><td class="y">Automatique</td><td>Avec notre équipe</td></tr>
  <tr><td>Formats</td><td class="y">Les 8</td><td class="y">Les 8</td><td>Les 8</td></tr>
 </tbody></table></div>
 ${call('info', 'Sur un site, utilise <b>toujours la balise</b> : c’est elle qui mesure que l’annonce a vraiment été vue par une personne, et c’est ce qui te fait payer.')}
</section>

<section id="balise">
 <h2>Balise web</h2>
 <p>Colle ces lignes là où l’annonce doit apparaître. La balise fait tout : demande, affichage, mesure de la vue, clic.</p>
 ${box([['Carte native', `${ins('article', 'native')}\n${TAG}`], ['Bannière 728 × 90', `${ins('haut', 'banner', ' data-size="728x90"')}\n${TAG}`], ['Bandeau collant', `<!-- fixé en bas de l'écran, fermable -->\n${ins('bas', 'sticky', ' data-size="320x50"')}\n${TAG}`],
   ['Plusieurs emplacements', `<!-- 3 emplacements au plus par page, un seul script -->\n${ins('haut', 'banner', ' data-size="728x90"')}\n${ins('article', 'native')}\n${ins('colonne', 'banner', ' data-size="300x250"')}\n${TAG}`]], { lang: 'HTML' })}
 <h3>Attributs</h3>
 ${params([['data-pub', true, '', 'Ton identifiant publicitaire <code>ap_xxxxxxxxxx</code>.'], ['data-format', true, '', '<code>banner</code>, <code>sticky</code>, <code>native</code>, <code>carousel</code>, <code>poster</code>, <code>video</code>, <code>interstitial</code>, <code>rewarded</code>.'],
   ['data-slot', false, 'texte', 'Nom de l’emplacement (lettres, chiffres, - et _), pour tes statistiques.'], ['data-size', false, 'facultatif', '<code>728x90</code>, <code>320x100</code>, <code>320x50</code>, <code>300x250</code> : demande une bannière prête à cette taille.']])}
 ${call('ok', 'Aucune annonce pour ce visiteur (pays, langue, catégories) ? L’emplacement reste vide : rien n’est compté, rien n’est payé, ta page n’est jamais bloquée.')}
 <h3>Politique de sécurité (CSP)</h3>
 ${box([['en-tête HTTP', `script-src https://afrolookmedia.com; connect-src ${ORIGIN}; img-src ${MEDIA}; media-src ${MEDIA};`]], { lang: 'CSP', num: false })}
</section>

<section id="wordpress">
 <h2>WordPress et sites sans code</h2>
 <ol class="dx-steps">
  <li><b>Ouvre l’éditeur de la page</b>Ajoute un bloc <b>« HTML personnalisé »</b> à l’endroit voulu.</li>
  <li><b>Colle la balise</b>Les lignes de la balise web ci-dessus, avec ton identifiant.</li>
  <li><b>Publie</b>L’annonce apparaît dès que ton site est validé.</li>
 </ol>
</section>

<section id="spa">
 <h2>React, Vue, Next.js</h2>
 <p>Charge la balise une fois (dans la page principale), puis après chaque changement de page sans rechargement, demande-lui de remplir les nouveaux emplacements.</p>
 ${box([['React', `export function AfrolookAd({ format = 'native', slot }) {\n  useEffect(() => { window.AflAds?.fill(); }, [slot]);\n  return <ins className="afl-ad" data-pub="ap_xxxxxxxxxx" data-slot={slot} data-format={format} />;\n}`],
   ['Vue', `<template>\n  <ins class="afl-ad" data-pub="ap_xxxxxxxxxx" :data-slot="slot" data-format="native" />\n</template>\n<script setup>\nonMounted(() => window.AflAds?.fill());\n</script>`]], { lang: 'JS' })}
</section>

<section id="flutter">
 <h2>Application Flutter</h2>
 <ol class="dx-steps">
  <li><b>Télécharge le composant</b><span class="dx-dl"><a class="btn btn-primary adsm" href="/ads/afrolook_ads_banner.dart" download>Télécharger afrolook_ads_banner.dart</a><small>Fichier Dart, 30 Ko</small></span></li>
  <li><b>Copie-le dans ton projet</b>Par exemple <code>lib/ads/afrolook_ads_banner.dart</code>, et ajoute ses 5 dépendances (onglet <code>pubspec.yaml</code>).</li>
  <li><b>Une ligne par emplacement</b>Avec ton identifiant <code>ap_xxxxxxxxxx</code>.</li>
 </ol>
 ${box([['Bas de l’écran', `// mini bannière fixe en bas d'un écran (320 × 50, fermable)\nScaffold(\n  body: …,\n  bottomNavigationBar: const AfrolookAdsBanner.bottom(pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiant),\n);`],
   ['Dans une liste', `const AfrolookAdsBanner(\n  pubId: 'ap_xxxxxxxxxx',\n  visitorId: monIdentifiant, // 12 à 64 caractères, stable, sans donnée personnelle\n  size: AdsBannerSize.medium, // 300 × 250\n  slot: 'liste',\n);`],
   ['Carte, affiche, carrousel, vidéo', `// dans une liste ou une page : AdsFormat.native, .poster, .carousel ou .video\nconst AfrolookAd(\n  pubId: 'ap_xxxxxxxxxx',\n  visitorId: monIdentifiant,\n  format: AdsFormat.native,\n  slot: 'liste',\n);`],
   ['Plein écran', `// entre deux écrans ; la croix s'active au bout de 3 secondes\nawait AfrolookAds.showInterstitial(context, pubId: 'ap_xxxxxxxxxx', visitorId: monIdentifiant);`],
   ['Récompensée', `// la personne choisit de regarder ; la récompense n'est donnée qu'après la lecture COMPLÈTE\nawait AfrolookAds.showRewarded(\n  context,\n  pubId: 'ap_xxxxxxxxxx',\n  visitorId: monIdentifiant,\n  onReward: () { /* donner la récompense */ },\n);`],
   ['pubspec.yaml', 'dependencies:\n  http: ^1.2.0\n  url_launcher: ^6.3.0\n  visibility_detector: ^0.4.0\n  video_player: ^2.8.2\n  shared_preferences: ^2.3.0']], { lang: 'Dart', foot: 'Bannières : <b>mini</b> 320×50, <b>large</b> 320×100, <b>medium</b> 300×250, <b>leaderboard</b> 728×90 · <b>AfrolookAd</b> : carte native, affiche, carrousel, vidéo' })}
 ${call('warn', 'Une application est rémunérée après la vérification de son authenticité par notre équipe. Le composant gère les 8 formats : bannières, carte native, affiche, carrousel, vidéo, plein écran et récompensée.')}
</section>

<section id="natif">
 <h2>Android et iOS (API)</h2>
 <p>Pour une application vérifiée qui dessine elle-même l’annonce : demande une annonce, affiche-la avec la mention « Annonce », et ouvre le lien <code>click</code> au toucher. Notre équipe te donne la façon de compter les vues avec ton accès.</p>
 ${box([['Kotlin', `val url = "${A}/serve?pub=ap_xxxxxxxxxx&fmt=native&slot=liste&vid=$visitorId"\nval ad = JSONObject(http.get(url)).optJSONObject("ad") ?: return // pas d'annonce : rien à afficher\n// afficher titre, image, bouton et la mention « Annonce »\n// au toucher : ouvrir ad.click (jamais l'adresse de l'annonceur)`],
   ['Swift', `let url = URL(string: "${A}/serve?pub=ap_xxxxxxxxxx&fmt=native&slot=liste&vid=\\(visitorId)")!\nlet (data, _) = try await URLSession.shared.data(from: url)\n// afficher l'annonce et la mention « Annonce », ouvrir ad.click au toucher`]], { lang: 'Mobile' })}
</section>

<section id="serve">
 <h2>API : obtenir une annonce</h2>
 ${call('warn', 'L’API brute sert aux applications <b>vérifiées</b>, sur demande à notre équipe. Pour un site ou une application Flutter, la balise ou le composant suffit.')}
 <div class="dx-ep"><span class="m get">GET</span><span>${A}/serve</span></div>
 <div class="dx-api">
  <div>${params([['pub', true, 'texte', 'Ton identifiant publicitaire.'], ['fmt', true, 'texte', 'Un des 8 formats.'], ['vid', true, '12 à 64 caractères', 'Identifiant du visiteur, stable, sans donnée personnelle.'], ['slot', false, 'texte', 'Nom de l’emplacement.'], ['size', false, 'texte', '<code>728x90</code>, <code>320x100</code>, <code>320x50</code>, <code>300x250</code>.'], ['lang', false, 'fr, en…', 'Langue de la page.']])}
   ${call('info', 'Le pays du visiteur est déterminé par nos serveurs : n’envoie pas de pays. Le bouton de l’annonce pointe vers <code>click</code>.')}</div>
  ${box([['Réponse', `{\n  "ok": true,\n  "ad": {\n    "format": "native", "label": "Annonce",\n    "title": "Boutique Kofi", "text": "Mode africaine…", "cta": "Visiter le site",\n    "brand": { "name": "Kofi", "logo": "https://…", "domain": "kofi.tg" },\n    "media": { "type": "image", "url": "https://…", "images": ["https://…"] },\n    "banner": { "url": "https://…", "w": 728, "h": 90 },\n    "click": "${A}/go?t=…"\n  }\n}`], ['Exemple d’appel', `curl "${A}/serve?pub=ap_xxxxxxxxxx&fmt=native&slot=article&vid=visiteur-0001&lang=fr"`]], { lang: 'JSON' })}
 </div>
</section>

<section id="erreurs">
 <h2>Codes d’erreur</h2>
 <div class="dx-tw"><table><thead><tr><th>Réponse</th><th>Signification</th><th>Que faire</th></tr></thead><tbody>
  <tr><td><code>"ad": null</code></td><td>Aucune annonce pour ce visiteur</td><td>Normal : l’emplacement reste vide</td></tr>
  <tr><td><code>403 diffuseur</code></td><td>Identifiant inconnu ou site pas encore validé</td><td>Vérifie l’identifiant, attends la validation</td></tr>
  <tr><td><code>403 origine</code></td><td>Appel depuis un domaine non déclaré</td><td>Ajoute le domaine dans ton espace</td></tr>
  <tr><td><code>429</code></td><td>Trop de demandes</td><td>Pas de rafraîchissement automatique</td></tr>
 </tbody></table></div>
</section>

<section id="formats">
 <h2>Les 8 formats</h2>
 <p>Chaque vue ci-dessous est une <b>vraie capture</b> : une vraie annonce de la régie, dessinée par la balise, dans une vraie page de nos plateformes. Montants : ta part (65 %) du prix payé par l’annonceur pour 1 000 vues valides.</p>
 <div class="dx-fmts">${SHOTS.map(([f, n, c, w, p]) => `<figure><div class="shot"><img src="/img/ads/formats/${f}.jpg" alt="${n} sur ${w}" loading="lazy" width="520" height="1126"></div><figcaption><b>${n}</b><code>${c}</code><small>${w}</small><small>${p}</small></figcaption></figure>`).join('')}</div>
 <figure class="wide"><div class="shot"><img src="/img/ads/formats/leaderboard_728x90.jpg" alt="Leaderboard 728 × 90 sur PronoFlash IA, ordinateur" loading="lazy" width="1100" height="653"></div><figcaption><b>Leaderboard 728 × 90</b><code>banner</code><small>PronoFlash IA · ordinateur, haut de page</small><small>1 s · 650 F pour 1 000</small></figcaption></figure>
 <div class="dx-tw"><table><thead><tr><th>Format</th><th>Code</th><th>Vue comptée après</th><th>Intervalle minimum</th><th>Prix payé par l’annonceur (pour 1 000)</th><th>Tu reçois (65 %)</th></tr></thead><tbody>
  ${FMT.map(([n, c, v, i, p]) => `<tr><td>${n}</td><td><code>${c}</code></td><td>${v}</td><td>${i}</td><td>${p}</td><td><b>${share(p)}</b></td></tr>`).join('')}
 </tbody></table></div>
 <p class="adnote">Mention « Annonce » toujours visible, fermeture possible pour le bandeau collant et l’interstitiel, pas de son qui démarre seul, jamais plus de 3 emplacements par page.</p>
</section>

<section id="matrice">
 <h2>Formats par intégration</h2>
 <div class="dx-tw"><table><thead><tr><th>Format</th><th>Balise web</th><th>Composant Flutter</th><th>API</th></tr></thead><tbody>
  ${[['Bannière (4 tailles)', 1, 1], ['Bandeau collant', 1, 1], ['Carte native', 1, 0], ['Carrousel', 1, 0], ['Affiche', 1, 0], ['Vidéo', 1, 0], ['Interstitiel', 1, 0], ['Récompensée', 1, 0]]
    .map(([n]) => `<tr><td>${n}</td><td class="y">✓</td><td class="y">✓</td><td class="y">✓</td></tr>`).join('')}
 </tbody></table></div>
</section>

<section id="tailles">
 <h2>Tailles et bannières prêtes</h2>
 <div class="dx-tw"><table><thead><tr><th>Taille</th><th>Nom</th><th>Où</th></tr></thead><tbody>
  <tr><td><code>728x90</code></td><td>Leaderboard</td><td>Haut ou bas de page sur ordinateur</td></tr>
  <tr><td><code>320x100</code></td><td>Grande bannière</td><td>Dans une page sur téléphone</td></tr>
  <tr><td><code>320x50</code></td><td>Mini bannière</td><td>Bandeau fixe en bas d’une application</td></tr>
  <tr><td><code>300x250</code></td><td>Rectangle moyen</td><td>Dans le contenu</td></tr>
 </tbody></table></div>
 ${call('info', 'L’image de l’annonceur est <b>toujours affichée entière</b>, jamais rognée : le reste de l’emplacement se remplit d’une copie floutée de la même image. Si l’annonceur a déposé une bannière prête à la taille demandée, c’est elle qui s’affiche.')}
</section>

<section id="media">
 <h2>Vidéo + images dans une même annonce</h2>
 <p>Un annonceur peut déposer une vidéo <b>et</b> jusqu’à 5 images. Tu n’as rien à faire : le serveur envoie le bon média selon ton format.</p>
 <div class="dx-tw"><table><thead><tr><th>Ton emplacement</th><th>Média reçu</th></tr></thead><tbody>
  <tr><td><code>video</code>, <code>rewarded</code>, <code>native</code>, <code>interstitial</code></td><td>La vidéo</td></tr>
  <tr><td><code>banner</code>, <code>sticky</code>, <code>poster</code>, <code>carousel</code></td><td>Les images</td></tr>
 </tbody></table></div>
</section>

<section id="comptage">
 <h2>Comptage et fraude</h2>
 ${call('ok', '<b>Vue valide</b> : annonce visible à moitié pendant la durée du format, par une vraie personne, sur le site déclaré, dans les limites de fréquence.')}
 ${call('danger', '<b>Interdit</b> : cliquer sur tes annonces ou inciter à cliquer, acheter du trafic, robots, rafraîchissement automatique, cadres cachés, masquer ou modifier l’annonce ou la mention « Annonce ». Fraude constatée : gains retirés et compte fermé.')}
 <p>Trafic invalide : moins de 10 % normal, 10 à 25 % alerte, plus de 25 % emplacement suspendu. Les vues payées d’un jour suivent l’audience retenue pour ton site.</p>
</section>

<section id="paiement">
 <h2>Gains et retraits</h2>
 <div class="dx-tw"><table><thead><tr><th>Étape</th><th>Délai</th></tr></thead><tbody>
  <tr><td>Gain du jour calculé</td><td>Chaque nuit</td></tr>
  <tr><td>Gain disponible</td><td>30 jours après (10 % gardés 90 jours)</td></tr>
  <tr><td>Retrait Mobile Money</td><td>À partir de 10 000 F</td></tr>
 </tbody></table></div>
 <p class="adnote">Prix de lancement : pendant le premier mois de l’offre Réseau, les annonceurs paient 30 % de moins ; ta part de 65 % est calculée sur le prix réellement payé.</p>
</section>

<section id="categories">
 <h2>Catégories et ciblage</h2>
 <ul class="list">
  <li>Chaque annonce a une catégorie vérifiée par notre équipe. <b>Tu choisis les catégories que tu acceptes</b> pour chaque site ; les catégories sensibles ne s’affichent jamais sans ton accord.</li>
  <li>Le ciblage (pays, langues, appareils, types de sites) est défini par l’annonceur : un visiteur n’est pas toujours éligible à toutes les annonces.</li>
  <li>Aucun cookie, aucun suivi d’un site à l’autre. Ta politique de confidentialité doit mentionner l’affichage d’annonces par Afrolook Ads.</li>
 </ul>
</section>

<section id="verifier">
 <h2>Tester mon intégration</h2>
 <p>Donne l’adresse d’une page de ton site : nous la lisons et te disons ce qui va et ce qui manque (balise de vérification, script, emplacements, identifiant, politique de sécurité). Rien n’est compté ni enregistré.</p>
 <form class="dx-test" id="dx-test" data-api="${A}"><input type="url" name="url" placeholder="https://monsite.com/une-page" required aria-label="Adresse de la page à tester"><button class="btn btn-primary adsm" type="submit">Tester</button></form>
 <ul class="dx-chk" id="dx-test-out" aria-live="polite"></ul>
</section>

<section id="faq">
 <h2>Questions fréquentes</h2>
 <div class="faq">
  <details><summary>Aucune annonce ne s’affiche.</summary><p>Pas d’annonce pour ce visiteur (pays, langue, appareil), aucune catégorie acceptée, intervalle non écoulé, ou site pas encore validé.</p></details>
  <details><summary>Puis-je mettre la balise sur plusieurs sites ?</summary><p>Non : un identifiant par site ou application. Ajoute chaque site dans ton espace (jusqu’à 10).</p></details>
  <details><summary>Pourquoi mon audience mesurée est plus basse que la déclarée ?</summary><p>Nous comptons les personnes différentes pour qui la balise a été chargée. Un écart important et durable fait ajuster l’audience retenue.</p></details>
  <details><summary>Où trouver de l’aide ?</summary><p><a href="/contact/">Écris-nous</a> avec ton identifiant publicitaire.</p></details>
 </div>
</section>
<div class="cta"><a class="btn btn-primary adbig" href="/ads/diffuseur/">${G} Ouvrir mon espace diffuseur</a><a class="btn btn-line adbig" href="/ads/diffuseur/regles/">${ico('shield', 18)} Règles des diffuseurs</a></div>
</div></div></section>
<script src="/js/docs.js?v=__ASSET_V__" defer></script>`;
}
