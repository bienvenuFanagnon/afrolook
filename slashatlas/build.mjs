// Génère le site statique dans dist/ : node build.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { T } from './src/i18n.mjs';
import { CATEGORIES, COMMANDS } from './src/data.mjs';
import { termsBody, TERMS_VERSION } from './src/terms.mjs';
import { aboutBody } from './src/about.mjs';
import { GUIDES } from './src/guides.mjs';

const root = path.dirname(new URL(import.meta.url).pathname);
// Illustrations ajoutées au fil de l'eau : une commande qui a ses fichiers -apres.webp et -t.webp dans static/img/c affiche son image ;
// le moteur (Gemini par défaut, ou celui noté dans engines.json) est affiché honnêtement ; sans fichier -avant.webp, pas de « photo de départ ».
{
  const dir = path.join(root, 'static', 'img', 'c'); let engines = {};
  try { engines = JSON.parse(fs.readFileSync(path.join(dir, 'engines.json'), 'utf8')); } catch (e) {}
  for (const c of COMMANDS) {
    c.engine = engines[c.slug] || 'Gemini';
    if (c.noImage && fs.existsSync(path.join(dir, `${c.slug}-apres.webp`)) && fs.existsSync(path.join(dir, `${c.slug}-t.webp`))) { c.noImage = false; c.noBefore = !fs.existsSync(path.join(dir, `${c.slug}-avant.webp`)); }
  }
}

const dist = path.join(root, 'dist');
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'src/config.json'), 'utf8'));
const esc = (s) => String(s).replace(/ ([?!:;»])/g, '\u00a0$1').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const abs = (p) => cfg.domain + p;
const write = (p, c) => { const f = path.join(dist, p); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, c); };
const hashOf = (f) => createHash('sha1').update(fs.readFileSync(path.join(root, 'static', f))).digest('hex').slice(0, 8);
const V = { css: hashOf('css/site.css'), js: hashOf('js/site.js') };

const P = {
  fr: { home: '/', cmds: '/commandes/', try: '/generer/', tuto: '/tutoriel/', pack: '/pack/', pro: '/pro/', studio: '/studio-contenu/', privacy: '/confidentialite/', cookies: '/cookies/', terms: '/conditions/', about: '/a-propos/', guides: '/guides/', cat: (id) => `/categorie/${id}/`, cmd: (s) => `/c/${s}/` },
  en: { home: '/en/', cmds: '/en/commands/', try: '/en/generate/', tuto: '/en/tutorial/', pack: '/en/pack/', pro: '/en/pro/', studio: '/en/content-studio/', privacy: '/en/privacy/', cookies: '/en/cookies/', terms: '/en/terms/', about: '/en/about/', guides: '/en/guides/', cat: (id) => `/en/category/${id}/`, cmd: (s) => `/en/c/${s}/` },
};
const other = (l) => (l === 'fr' ? 'en' : 'fr');
const catOf = (id) => CATEGORIES.find((c) => c.id === id);
const pages = []; // pour le sitemap : { fr, en }

// ───────── composants ─────────
const CLAUSE = {
  fr: {
    product: ['S’il y a plusieurs produits sur la photo, garde-les tous, identiques et bien visibles. Adapte le décor à la nature du produit{T} : n’ajoute aucun élément sans rapport avec lui (pas d’eau si ce n’est pas un produit lié à l’eau).', 'La photo contient plusieurs produits{T} : garde-les tous, identiques, bien visibles et harmonieusement disposés. Adapte le décor à leur nature : n’ajoute aucun élément sans rapport avec eux.'],
    dish: ['S’il y a plusieurs plats ou boissons sur la photo, garde-les tous, identiques et bien visibles. Adapte l’ambiance au type de cuisine{T}.', 'La photo contient plusieurs plats ou boissons{T} : garde-les tous, identiques, bien visibles et bien disposés. Adapte l’ambiance à leur type de cuisine.'],
    person: ['S’il y a plusieurs personnes sur la photo, garde-les toutes, visages, tenues et proportions identiques{T}.', 'La photo contient plusieurs personnes{T} : garde-les toutes, visages, tenues et proportions identiques, bien visibles et bien cadrées.'],
    place: ['Adapte l’ambiance au type de bien{T} et garde l’architecture identique : ne change ni la structure, ni les dimensions.', 'La photo contient plusieurs pièces ou plusieurs vues du bien{T} : traite chacune avec la même ambiance, structure et dimensions identiques.'],
    poster: ['Si la photo montre plusieurs sujets, garde-les tous identiques et bien visibles{T}. Accorde les couleurs du décor et des lettres à la marque ou au sujet, avec un fort contraste pour que le texte reste lisible.', 'La photo contient plusieurs sujets{T} : garde-les tous identiques, bien visibles et bien disposés. Accorde les couleurs du décor et des lettres à la marque ou au sujet, avec un fort contraste pour que le texte reste lisible.'],
    logo: ['Respecte le logo à l’identique{T} : si certains détails sont trop fins pour la matière, simplifie-les sans changer la forme générale ni les proportions.', 'Les logos joints sont plusieurs{T} : traite chacun avec la même matière, formes et proportions identiques, sur des fonds assortis.'],
    free: ['Adapte tous les éléments au sujet indiqué{T} : couleurs, objets, ambiance et vocabulaire visuel doivent rester cohérents entre eux.', 'Décline l’idée pour plusieurs sujets{T} : chacun garde son identité propre, avec le même style et la même qualité pour tous.'],
    motion: ['Adapte les couleurs, le rythme et le style à votre activité{T} : mouvements fluides et texte très lisible. Durée de 6 à 8 secondes.', 'Adapte les couleurs, le rythme et le style à vos activités{T} : mouvements fluides, texte très lisible. Durée de 6 à 8 secondes.'],
    text: ['Adapte les exemples, le vocabulaire et le ton à ce contexte{T}.', 'Adapte les exemples, le vocabulaire et le ton à ce contexte{T}.'],
    video: ['Mouvement fluide et naturel, sans déformation du produit{T}, sans coupure brusque ni texte à l’écran. Durée de 6 à 8 secondes.', 'La photo contient plusieurs produits{T} : garde-les tous identiques et visibles pendant tout le plan. Mouvement fluide, sans déformation, sans texte à l’écran. Durée de 6 à 8 secondes.'],
  },
  en: {
    product: ['If the photo shows several products, keep them all, identical and clearly visible. Adapt the setting to the nature of the product{T}: add nothing unrelated to it (no water unless it is a water-related product).', 'The photo contains several products{T}: keep them all, identical, clearly visible and nicely arranged. Adapt the setting to their nature: add nothing unrelated to them.'],
    dish: ['If the photo shows several dishes or drinks, keep them all, identical and clearly visible. Adapt the mood to the type of cuisine{T}.', 'The photo contains several dishes or drinks{T}: keep them all, identical, clearly visible and well arranged. Adapt the mood to their type of cuisine.'],
    person: ['If the photo shows several people, keep them all, faces, outfits and proportions identical{T}.', 'The photo contains several people{T}: keep them all, faces, outfits and proportions identical, clearly visible and well framed.'],
    place: ['Adapt the mood to the type of property{T} and keep the architecture identical: change neither the structure nor the dimensions.', 'The photo contains several rooms or several views of the property{T}: treat each with the same mood, structure and dimensions identical.'],
    poster: ['If the photo shows several subjects, keep them all identical and clearly visible{T}. Match the colors of the setting and the lettering to the brand or subject, with strong contrast so the text stays legible.', 'The photo contains several subjects{T}: keep them all identical, clearly visible and well arranged. Match the colors of the setting and the lettering to the brand or subject, with strong contrast so the text stays legible.'],
    logo: ['Keep the logo identical{T}: if some details are too fine for the material, simplify them without changing the overall shape or proportions.', 'There are several attached logos{T}: treat each with the same material, shapes and proportions identical, on matching backgrounds.'],
    free: ['Adapt every element to the subject given{T}: colors, objects, mood and visual vocabulary must stay consistent with one another.', 'Adapt the idea for several subjects{T}: each keeps its own identity, with the same style and quality for all.'],
    motion: ['Adapt the colors, rhythm and style to your business{T}: smooth movements and very legible text. Length 6 to 8 seconds.', 'Adapt the colors, rhythm and style to your businesses{T}: smooth movements, very legible text. Length 6 to 8 seconds.'],
    text: ['Adapt the examples, vocabulary and tone to this context{T}.', 'Adapt the examples, vocabulary and tone to this context{T}.'],
    video: ['Smooth, natural motion, with no distortion of the product{T}, no abrupt cuts and no on-screen text. Length 6 to 8 seconds.', 'The photo contains several products{T}: keep them all identical and visible throughout the shot. Smooth motion, no distortion, no on-screen text. Length 6 to 8 seconds.'],
  },
};
const canGen = (c) => !['video', 'motion', 'text'].includes(c.kind) && c.kind !== 'poster' && c.kind !== 'free' && !/[\[«]/.test(c.fr.prompt + c.en.prompt); // seuls les sujets avec photo sans texte à écrire passent par le Studio // les commandes vidéo se testent dans un générateur de vidéo, pas dans le Studio d'images
const tryBtn = (c, l, cls) => (canGen(c) ? `<a class="btn pri ${cls}" href="${P[l].try}?c=${c.slug}" data-try="${c.slug}">${TEST[l]}</a>` : '');
// Marque et contacts à inscrire sur le visuel (3 champs au plus) : les mêmes modèles servent au site (commande copiée) et au serveur (Studio).
const BRAND = {
  fr: {
    title: 'Ajouter ma marque ou mes contacts', hint: 'Facultatif, 3 textes au plus. Ils seront placés sur le visuel avec une mise en page soignée.',
    fields: [['brand', 'Nom de marque', 'ex. Maison Awa', 60], ['contact', 'Téléphone ou contact', 'ex. +225 07 00 00 00 00', 60], ['other', 'Autre texte', 'ex. adresse, slogan ou prix', 80]],
    intro: 'Par exception à toute consigne qui interdit ou limite le texte, écris sur le visuel uniquement ces textes : {L}. Recopie chaque texte exactement, caractère par caractère (chiffres du numéro compris), sans faute, dans une typographie nette et très lisible, avec un fort contraste avec le fond.',
    names: { brand: 'nom de marque', contact: 'contact', other: 'texte' },
    place: { brand: 'le nom de marque en logotype élégant, bien visible, en haut ou en bas', contact: 'le contact en plus petit mais lisible, sur une seule ligne ou dans un discret bandeau, en bas', other: 'l’autre texte en accroche ou en sous-titre, plus petit que le nom de marque' },
    lay: 'Mise en page soignée : ', outro: 'Garde des marges de sécurité, ne cache ni le sujet ni le visage, n’ajoute aucun autre mot, et accorde les couleurs des lettres à la palette du visuel.',
    kind: { product: 'Dans l’esprit d’une publicité de marque.', person: 'Dans l’esprit d’une affiche de mode ou d’une couverture de magazine, sans masquer le visage ni la tenue.', dish: 'Dans l’esprit d’une publicité de restaurant.', place: 'Dans l’esprit d’une annonce immobilière, avec les coordonnées dans un bandeau en bas.', logo: 'Autour du logo, sans jamais le modifier.' },
  },
  en: {
    title: 'Add my brand or contact details', hint: 'Optional, up to 3 texts. They will be placed on the visual with a clean layout.',
    fields: [['brand', 'Brand name', 'e.g. Maison Awa', 60], ['contact', 'Phone or contact', 'e.g. +225 07 00 00 00 00', 60], ['other', 'Other text', 'e.g. address, slogan or price', 80]],
    intro: 'As an exception to any instruction that forbids or limits text, write only these texts on the visual: {L}. Copy each text exactly, character by character (phone digits included), without errors, in a sharp, very legible typeface with strong contrast against the background.',
    names: { brand: 'brand name', contact: 'contact', other: 'text' },
    place: { brand: 'the brand name as an elegant, clearly visible wordmark, at the top or bottom', contact: 'the contact smaller but legible, on a single line or in a discreet band, at the bottom', other: 'the other text as a tagline or subtitle, smaller than the brand name' },
    lay: 'Careful layout: ', outro: 'Keep safe margins, do not hide the subject or the face, add no other word, and match the letter colors to the visual’s palette.',
    kind: { product: 'In the spirit of a brand advertisement.', person: 'In the spirit of a fashion poster or magazine cover, without hiding the face or the outfit.', dish: 'In the spirit of a restaurant advertisement.', place: 'In the spirit of a real-estate listing, with the contact details in a band at the bottom.', logo: 'Around the logo, never altering it.' },
  },
};
const BRAND_KINDS = ['product', 'person', 'dish', 'place', 'logo'];
const KIND_LABEL = {
  fr: { product: ['Votre produit', 'ex. crème visage, 3 bouteilles de jus'], dish: ['Votre plat', 'ex. poulet braisé, 2 pizzas et une boisson'], person: ['Sur la photo', 'ex. un coach sportif, un groupe de 3 amies'], place: ['Votre bien', 'ex. appartement 3 pièces, villa avec piscine'], video: ['Votre produit', 'ex. flacon de parfum, baskets, boîte de thé'], motion: ['Votre activité', 'ex. boutique de mode, salon de coiffure'], text: ['Votre activité', 'ex. salon de coiffure à Abidjan'], poster: ['Votre sujet', 'ex. baskets rouges, une coach sportive'], logo: ['Votre logo', 'ex. logo d’un café, emblème d’un club'], free: ['Votre sujet', 'ex. un salon de coiffure, une appli de livraison'] },
  en: { product: ['Your product', 'e.g. face cream, 3 juice bottles'], dish: ['Your dish', 'e.g. grilled chicken, 2 pizzas and a drink'], person: ['In the photo', 'e.g. a fitness coach, a group of 3 friends'], place: ['Your property', 'e.g. 3-room flat, villa with a pool'], video: ['Your product', 'e.g. perfume bottle, sneakers, tea box'], motion: ['Your business', 'e.g. fashion shop, hair salon'], text: ['Your business', 'e.g. hair salon in Abidjan'], poster: ['Your subject', 'e.g. red sneakers, a fitness coach'], logo: ['Your logo', 'e.g. a café logo, a club emblem'], free: ['Your subject', 'e.g. a hair salon, a delivery app'] },
};
const MULTI = { fr: ['Un seul', 'Plusieurs'], en: ['Single', 'Several'] };
const clauseOf = (c, l, multi = false, type = '') => CLAUSE[l][c.kind || 'product'][multi ? 1 : 0].replace('{T}', type ? ` (${type})` : '');
const fullPrompt = (c, l) => `${c.code} : ${c[l].prompt} ${clauseOf(c, l)}`;
const TEST = { fr: 'Générer ici', en: 'Generate here' };

// Publicité Google AdSense : les emplacements sont masqués dans la page ; le script du site les active
// seulement si l'administration a activé la publicité (réglages lus via /api/config). Jamais sur /generer/ ni /admin/.
const ad = (kind, l = 'fr', late = false) => `<aside class="ad ad-${kind}" data-ad="${kind}"${late ? ' data-adlate' : ''} hidden aria-label="${l === 'fr' ? 'Publicité' : 'Advertisement'}"><small>${l === 'fr' ? 'Publicité' : 'Advertisement'}</small></aside>`;

const AIWORD = { fr: 'Généré par IA', en: 'AI-generated' };
const BEFORE = { fr: 'Photo de départ', en: 'Starting photo' };
const imgAlt = (c, l) => (c.noBefore ? (l === 'fr' ? `Exemple illustrant la commande ${c.code} : ${c.fr.title}` : `Example illustrating the ${c.code} command: ${c.en.title}`) : (l === 'fr' ? `Résultat de la commande ${c.code} : ${c.fr.title}` : `Result of the ${c.code} command: ${c.en.title}`));
const PLAY = '<span class="vplay2" aria-hidden="true"></span>';
function poster(c, l, big = false) {
  const t = c[l], pl = c.kind === 'video' || c.kind === 'motion' ? PLAY : '';
  if (c.noImage) {
    return `<div class="poster${big ? ' big' : ''}" style="--x:${c.x};--y:${c.y};--r:${c.r}"><span class="tag">${esc(catOf(c.cat)[l])}</span><span class="shape"></span><b>${esc(t.poster)}</b><small>${esc(c.code)}</small>${pl}</div>`;
  }
  if (big) {
    return `<div class="poster img big" style="--ar:${c.ratio.replace(':', '/')}"><img src="/img/c/${c.slug}-apres.webp" alt="${esc(imgAlt(c, l))}" fetchpriority="high"><span class="ai">${AIWORD[l]} · ${c.engine}</span>${c.noBefore ? '' : `<div class="av"><img src="/img/c/${c.slug}-avant.webp" alt="" loading="lazy"><small>${BEFORE[l]}</small></div>`}${pl}</div>`;
  }
  return `<div class="poster img${c.ratio === '16:9' ? ' ls' : ''}"><img src="/img/c/${c.slug}-t.webp" alt="${esc(imgAlt(c, l))}" loading="lazy" decoding="async"><span class="tag">${esc(catOf(c.cat)[l])}</span><span class="ai">${AIWORD[l]}</span>${pl}</div>`;
}
function card(c, l) {
  const t = c[l];
  const search = `${c.code} ${t.title} ${catOf(c.cat)[l]} ${t.desc}`.toLowerCase();
  return `<article class="card" data-slug="${c.slug}" data-search="${esc(search)}" data-cat="${c.cat}"><a href="${P[l].cmd(c.slug)}" class="cl" aria-label="${esc(t.title)}">${poster(c, l)}</a><div class="cb"><div class="code">${esc(c.code)}</div><h3><a href="${P[l].cmd(c.slug)}">${esc(t.title)}</a></h3><div class="meta"><span>${esc(catOf(c.cat)[l])}${c.kind === 'text' ? '' : ' · ' + c.ratio}</span>${c.steps ? `<span class="stp">${c.steps.length + 1} ${l === 'fr' ? 'étapes' : 'steps'}</span>` : ''}<span class="cnt" hidden></span></div><div class="acts">${tryBtn(c, l, 'sm')}<button class="btn ${canGen(c) ? 'gl' : 'pri'} sm" type="button" data-copy="#p-${c.slug}" data-slug="${c.slug}">${T[l].cmd.copy}</button></div><pre id="p-${c.slug}" hidden>${esc(fullPrompt(c, l))}</pre></div></article>`;
}
function bandForm(l, kind = 'request') {
  const b = T[l].band;
  return `<form class="row" data-form="${kind}" data-ok="${esc(b.ok)}" data-err="${esc(b.err)}" data-invalid="${esc(b.invalid)}" data-sending="${esc(b.sending)}" data-lang="${l}" novalidate><input type="email" name="email" placeholder="${esc(b.ph)}" aria-label="E-mail" autocomplete="email" required><input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true"><button class="btn pri" type="submit">${b.btn}</button><p class="fmsg" role="status" aria-live="polite"></p></form>`;
}
// Canal WhatsApp : tant que le lien d'invitation (src/config.json → community.whatsapp) est vide, aucune invitation n'est affichée.
const WA_URL = (cfg.community && /^https:\/\/(whatsapp\.com\/channel\/|chat\.whatsapp\.com\/|wa\.me\/)/.test(cfg.community.whatsapp || '')) ? cfg.community.whatsapp : '';
const WA = {
  fr: { h: 'Rejoignez le canal WhatsApp SlashAtlas', p: 'Nouvelles commandes, astuces et surprises, directement dans vos notifications. Gratuit, et personne ne voit votre numéro.', btn: 'Rejoindre le canal', ft: 'Canal WhatsApp', after: 'Des surprises arrivent bientôt sur notre canal WhatsApp.' },
  en: { h: 'Join the SlashAtlas WhatsApp channel', p: 'New commands, tips and surprises, straight to your notifications. Free, and nobody sees your number.', btn: 'Join the channel', ft: 'WhatsApp channel', after: 'Surprises are coming soon on our WhatsApp channel.' },
};
const WA_ICON = '<svg viewBox="0 0 24 24" width="26" height="26" aria-hidden="true"><path fill="currentColor" d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 18.2c-1.5 0-3-.4-4.2-1.2l-.3-.2-3 .8.8-2.9-.2-.3A8.2 8.2 0 1 1 12 20.200z"/><path fill="currentColor" d="M16.600 14.400c-.2-.1-1.300-.7-1.500-.7s-.4-.1-.5.100-.6.7-.7.900-.3.200-.5.100a6.700 6.700 0 0 1-3.300-2.900c-.2-.4.200-.4.700-1.300.1-.2 0-.3 0-.4l-.7-1.600c-.2-.4-.4-.4-.5-.4h-.4a.8.800 0 0 0-.6.300 2.500 2.500 0 0 0-.8 1.900c0 1.100.8 2.200.9 2.300s1.600 2.600 4 3.600c1.500.6 2.100.7 2.800.6.400-.1 1.300-.5 1.500-1.100s.2-1 .1-1.100-.2-.2-.4-.3z"/></svg>';
const waCard = (l, from) => (WA_URL ? `<div class="wacard"><span class="waic">${WA_ICON}</span><div><b>${WA[l].h}</b><p>${WA[l].p}</p></div><a class="btn wa" href="${WA_URL}" target="_blank" rel="noopener" data-wa="${from}">${WA[l].btn}</a></div>` : '');
function band(l) {
  const b = T[l].band;
  return `<div class="band"><h3>${b.h}</h3><p>${b.p}</p><form class="col" data-form="request" data-ok="${esc(b.ok)}" data-err="${esc(b.err)}" data-invalid="${esc(b.invalid)}" data-sending="${esc(b.sending)}" data-lang="${l}" novalidate><input type="text" name="note" maxlength="140" placeholder="${esc(b.note)}" aria-label="${esc(b.note)}"><div class="row"><input type="email" name="email" placeholder="${esc(b.ph)}" aria-label="E-mail" autocomplete="email" required><input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true"><button class="btn pri" type="submit">${b.btn}</button></div><p class="fmsg" role="status" aria-live="polite"></p></form></div>`;
}
function tuto(l, h1 = false) {
  const t = T[l].tuto;
  const c = COMMANDS.find((x) => x.slug === 'productglow');
  const cmdText = c[l].prompt;
  return `<section class="tuto" id="tuto" data-copied="${esc(t.copied)}"><div><div class="eyebrow">${t.k}</div><${h1 ? 'h1' : 'h2'} class="t">${t.h}</${h1 ? 'h1' : 'h2'}><p class="lead">${t.l}</p><div class="tsteps">${t.steps.map((s, i) => `<button class="ts" type="button" data-tstep="${i}"><span class="n">${i + 1}</span><span><b>${s[0]}</b><em class="d">${s[1]}</em></span></button>`).join('')}</div></div>
<div><div class="demo" id="demo">
<div class="pane" data-p="0"><div class="ph"><span>${t.p1}</span></div><div class="toast" id="ttoast">${t.copied}</div><div class="mcmd"><div class="code">${esc(c.code)}</div><p>${esc(cmdText)}</p><button class="btn pri pulse" id="tcopy" type="button" tabindex="-1">${T[l].cmd.copy}</button></div></div>
<div class="pane" data-p="1"><div class="ph"><span>${t.p2}</span><span>${t.yourTool}</span></div><div class="chat"><div class="bub">${t.bubble}</div><div class="comp"><div class="att"><img class="thumb" src="/img/c/productglow-avant.webp" alt="" width="62" height="76" loading="lazy"><small>${t.attach}</small></div><div class="typed" id="typed" data-text="${esc(c.code + ' ' + cmdText)}"></div><div class="send">↑</div></div></div></div>
<div class="pane" data-p="2"><div class="ph"><span>${t.p3}</span></div><div class="res"><div class="rposter"><img src="/img/c/productglow-apres.webp" alt="${esc(imgAlt(c, l))}" loading="lazy"></div><div class="rcap">${t.resC}</div></div></div>
</div><div class="dots" id="dots"><i></i><i></i><i></i></div><div class="cta center"><button class="btn gl sm" id="replay" type="button">↻ ${t.replay}</button></div></div></section>`;
}

const LANG_JS = `<script>(function(){try{if(location.search||/bot|crawl|spider|lighthouse|preview/i.test(navigator.userAgent))return;var c=localStorage.getItem('sa_lang_choice');var w=c;if(!w){var L=navigator.languages&&navigator.languages.length?navigator.languages:[navigator.language||'fr'];w=String(L[0]).toLowerCase().indexOf('fr')===0?'fr':'en'}var here=location.pathname.indexOf('/en')===0?'en':'fr';if(w!==here)location.replace(w==='en'?'/en/':'/')}catch(e){}})()</script>`;
function layout({ l, key, title, desc, body, alt, noindex, ld, path: pth, authJs, extraJs, img, ogTitle }) {
  const ogImg = img || '/og.jpg'; // sans image propre à la page : un visuel d'exemple tiré au hasard à chaque partage
  const ogDim = img ? '' : '<meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">';
  const t = T[l], p = P[l];
  const robots = (!cfg.indexable || noindex) ? '<meta name="robots" content="noindex,nofollow">' : '';
  const hl = alt ? `<link rel="alternate" hreflang="fr" href="${abs(alt.fr)}"><link rel="alternate" hreflang="en" href="${abs(alt.en)}"><link rel="alternate" hreflang="x-default" href="${abs(alt.fr)}">` : '';
  const sw = alt ? `<a class="langsw" href="${alt[other(l)]}" hreflang="${other(l)}" data-lang-switch="${other(l)}">${t.ft.lang}</a>` : '';
  const nav = [[p.cmds, t.nav.cmds, 'cmds'], [p.pack, t.nav.pack, 'pack'], [p.tuto, t.nav.tuto, 'tuto']].map(([h, n, k]) => `<a href="${h}"${key === k ? ' class="on" aria-current="page"' : ''}>${n}</a>`).join('');
  return `<!doctype html><html lang="${t.htmlLang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">${key === 'home' ? LANG_JS : ''}<title>${esc(title)}</title><meta name="description" content="${esc(desc)}"><meta name="theme-color" content="#000000"><meta name="color-scheme" content="dark">${robots}<link rel="canonical" href="${abs(pth)}">${hl}
<meta property="og:title" content="${esc(ogTitle || title)}"><meta property="og:description" content="${esc(desc)}"><meta property="og:type" content="website"><meta property="og:url" content="${abs(pth)}"><meta property="og:site_name" content="${cfg.name}"><meta property="og:image" content="${abs(ogImg)}">${ogDim}<meta name="twitter:card" content="summary_large_image"><meta name="twitter:image" content="${abs(ogImg)}">
${!robots ? [].concat(cfg.adsenseAccount || []).map((a) => `<meta name="google-adsense-account" content="${a}">`).join('') : ''}<link rel="icon" href="/favicon.svg" type="image/svg+xml"><link rel="manifest" href="/manifest.webmanifest"><link rel="apple-touch-icon" href="/icons/apple-touch-icon.png"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="SlashAtlas"><meta name="apple-mobile-web-app-status-bar-style" content="black"><link rel="preload" href="/fonts/manrope-latin.woff2" as="font" type="font/woff2" crossorigin><link rel="stylesheet" href="/css/site.css?v=${V.css}">${ld ? `<script type="application/ld+json">${JSON.stringify(ld)}</script>` : ''}</head>
<body data-page="${key}" data-lang="${l}"${WA_URL && key !== 'admin' ? ` data-wa="${esc(WA_URL)}"` : ''}><a class="skip" href="#main">${l === 'fr' ? 'Aller au contenu' : 'Skip to content'}</a>
<header class="hd"><a class="logo" href="${p.home}"><i>/</i>${cfg.name}</a><nav aria-label="Navigation">${nav}</nav><span class="sp"></span>${sw}<a class="btn gl sm hpro" href="${p.pro}">${t.nav.pro}</a><button class="menubtn" type="button" aria-label="${t.nav.menu}" aria-expanded="false" aria-controls="mnav"><i></i><i></i><i></i></button></header>
<div class="mnav" id="mnav" hidden><a class="btn pri big" href="${p.try}">${TEST[l]}</a>${[[p.cmds, t.nav.cmds, 'cmds'], [p.pack, t.nav.pack, 'pack'], [p.studio, STUDIO[l].nav, 'studio'], [p.tuto, t.nav.tuto, 'tuto'], [p.guides, t.ft.guides, 'guides'], [p.pro, t.nav.pro, 'pro'], [p.about, t.ft.about, 'about']].map(([h, n, k]) => `<a href="${h}"${key === k ? ' class="on" aria-current="page"' : ''}>${n}</a>`).join('')}</div>
<main id="main">${body}</main>
<footer class="ft"><span>${cfg.name} · ${t.ft.tag}</span>${cfg.legal && cfg.legal.email ? `<a class="ftmail" href="mailto:${cfg.legal.email}">${t.ft.contact} : ${cfg.legal.email}</a>` : ''}${WA_URL ? `<a class="ftwa" href="${WA_URL}" target="_blank" rel="noopener" data-wa="footer">${WA[l].ft}</a>` : ''}<a href="${p.studio}">${STUDIO[l].nav}</a><a href="${p.privacy}">${t.ft.privacy}</a><a href="${p.guides}">${t.ft.guides}</a><a href="${p.about}">${t.ft.about}</a><a href="${p.terms}">${t.ft.terms}</a><a href="${p.cookies}">${t.ft.cookies}</a>${body.includes('data-ad=') ? `<a href="#" data-adprefs hidden>${l === 'fr' ? 'Préférences publicitaires' : 'Ad preferences'}</a>` : ''}</footer>
${cfg.ga && key !== 'admin' ? `<script src="/js/ga.js?v=${V.js}" data-id="${cfg.ga}" defer></script>` : ''}<script src="/js/site.js?v=${V.js}" defer></script>${key !== 'admin' ? `<script src="/js/pwa.js?v=${V.js}" defer></script>` : ''}${extraJs ? `<script src="${extraJs}?v=${V.js}" defer></script>` : ''}</body></html>`;
}
function emit(l, key, pth, o) { write(pth.endsWith('/') ? pth + 'index.html' : pth, layout({ l, key, path: pth, ...o })); }
const alt2 = (fr, en) => ({ fr, en });

// ───────── pages ─────────
const HOME = {
  fr: {
    h1: ['Copiez. Collez.', 'Votre contenu IA est prêt.'],
    sub: 'Affiches, vidéos motion design et textes : des commandes toutes prêtes pour ChatGPT, Gemini, Midjourney, Veo ou Runway. Le studio rapide pour vos réseaux.',
    steps: [['Copiez', 'une commande'], ['Collez', 'avec votre photo dans votre IA'], ['Publiez', 'votre visuel']],
    rail: 'Essayez une commande', tabSel: 'À la une', tabNew: 'Nouveautés', tabVid: 'Vidéos', copy: 'Copier', cats: 'Par métier', all: 'Voir les {n} commandes', n: (k) => `${k} commandes`,
    tools: 'Fonctionne avec', tapHint: 'Faites glisser',
  },
  en: {
    h1: ['Copy. Paste.', 'Your AI content is ready.'],
    sub: 'Posters, motion design videos and texts: ready-made commands for ChatGPT, Gemini, Midjourney, Veo or Runway. The fast studio for your social media.',
    steps: [['Copy', 'a command'], ['Paste', 'with your photo in your AI'], ['Post', 'your visual']],
    rail: 'Try a command', tabSel: 'Featured', tabNew: 'New', tabVid: 'Videos', copy: 'Copy', cats: 'By trade', all: 'See all {n} commands', n: (k) => `${k} commands`,
    tools: 'Works with', tapHint: 'Swipe',
  },
};
const ICON = {
  copy: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="8" y="8" width="12" height="12" rx="3"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/></svg>',
  paste: '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="m4 18 5-5 4 4 3-3 5 5"/></svg>',
  spark: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18"/></svg>',
};
function railCard(c, l) {
  const t = c[l], H = HOME[l];
  return `<article class="rc" data-slug="${c.slug}" data-search="${esc(c.code)}"><a class="rp" href="${P[l].cmd(c.slug)}" aria-label="${esc(t.title)}">${poster(c, l)}</a><div class="rb"><code>${esc(c.code)}</code><span class="rt">${esc(t.title)}</span><span class="cnt" hidden></span><div class="acts">${tryBtn(c, l, 'copy')}<button class="btn ${canGen(c) ? 'gl' : 'pri'} copy" type="button" data-copy="#p-${c.slug}" data-slug="${c.slug}">${H.copy}</button></div><pre id="p-${c.slug}" hidden>${esc(fullPrompt(c, l))}</pre></div></article>`;
}
// Vidéo YouTube : image locale + lecteur chargé seulement au clic (youtube-nocookie.com) : aucune requête vers Google avant que le visiteur lise la vidéo.
const VIDEO_T = { fr: { h: 'Voyez-le en 30 secondes', play: 'Lire la vidéo', alt: 'Vidéo : copier une commande gratuite, obtenir une affiche pro' }, en: { h: 'See it in 30 seconds', play: 'Play the video', alt: 'Video: copy a free command, get a pro poster' } };
function videoBlock(l) {
  const id = cfg.video && cfg.video[l]; if (!id) return '';
  const v = VIDEO_T[l];
  // Vidéo hébergée sur le site (1,4 Mo, lecture immédiate) : préchargée en arrière-plan après le chargement de la page, démarrée par le clic.
  return `<div class="sec"><h2>${v.h}</h2></div><div class="vid" data-vid><video playsinline preload="none" poster="/img/video-${l}.webp" aria-label="${esc(v.alt)}" data-yt="${id}"><source src="/video/slashatlas-${l}.mp4" type="video/mp4"></video><button class="vfacade" type="button" aria-label="${esc(v.play)}"><span class="vplay" aria-hidden="true"></span></button></div><p class="vyt"><a href="https://youtu.be/${id}" target="_blank" rel="noopener">${l === 'fr' ? 'Voir aussi sur YouTube' : 'Also on YouTube'} ↗</a></p>`;
}

const STUDIO = {
  fr: {
    nav: 'Studio de contenu', title: 'Studio de contenu IA : affiches, vidéos, textes | SlashAtlas', desc: 'Du script à la vidéo, de l’affiche à la légende : le studio rapide de SlashAtlas pour créer vos contenus TikTok, Instagram, Reels et Shorts avec l’IA.',
    k: 'Studio de contenu', h: 'Créez vos contenus en quelques minutes, du script à la vidéo.', lead: 'Vous postez sur TikTok, Instagram, Facebook ou YouTube Shorts ? SlashAtlas réunit au même endroit tout ce qu’il faut pour passer de l’idée au contenu prêt à publier : les textes, l’affiche, la vidéo, la légende. Vous copiez une commande, vous la collez dans l’outil IA de votre choix, et c’est fait.',
    flowH: 'Votre chaîne de création en 4 étapes',
    flow: [['1', 'Idée et script', 'Le kit créateur écrit vos accroches, votre script de 15 ou 30 secondes, votre voix off et votre plan de tournage.', 'kit'], ['2', 'Visuel', 'Affiche, couverture de Reel, miniature : une commande gratuite, ou le Studio « Générer ici » qui crée l’image à votre place.', 'reseaux'], ['3', 'Vidéo', 'Motion design (texte animé, logo qui apparaît, compte à rebours, promo) ou vidéo publicitaire à partir de votre photo.', 'motion'], ['4', 'Légende et calendrier', 'Légende, hashtags, réponses aux clients, calendrier de 7 ou 30 jours : tout ce qui vient après la création.', 'kit']],
    famH: 'Quatre familles de commandes', fam: [['Commandes gratuites', 'Plus de 600 commandes d’affiches à copier, par métier.'], ['Studio « Générer ici »', 'L’image est créée directement sur le site, à partir de votre photo, avec votre marque et un QR code si vous le souhaitez.'], ['Motion design vidéo', 'Des commandes pour générateurs de vidéo (Veo, Runway, Kling) : prêtes à poster sur vos réseaux.'], ['Kit créateur', 'Des commandes texte pour ChatGPT, Gemini ou Claude : scripts, accroches, légendes, calendriers.']],
    honestH: 'Ce que fait le site, et ce qu’il ne fait pas', honest: ['Les commandes vidéo et texte se collent dans l’outil IA de votre choix : SlashAtlas ne génère pas encore les vidéos lui-même.', 'Le Studio « Générer ici » crée des images (affiches, visuels de produit) et les ajoute à votre compte ; il est payant au crédit, les commandes restent gratuites.', 'Les résultats dépendent de l’outil IA utilisé : relisez toujours le texte et vérifiez les informations avant de publier.'],
    sCats: 'Découvrir', cta: 'Voir les commandes', cta2: 'Essayer le Studio', stripH: 'Studio de création rapide de contenu IA', stripP: 'Du script à la vidéo, de l’affiche à la légende : tout ce qu’il faut pour vos réseaux, au même endroit.', stripBtn: 'Découvrir le studio',
  },
  en: {
    nav: 'Content studio', title: 'AI content studio: posters, videos, texts | SlashAtlas', desc: 'From script to video, from poster to caption: SlashAtlas’s fast studio to create your TikTok, Instagram, Reels and Shorts content with AI.',
    k: 'Content studio', h: 'Create your content in minutes, from script to video.', lead: 'Do you post on TikTok, Instagram, Facebook or YouTube Shorts? SlashAtlas puts everything in one place to go from idea to ready-to-post content: the texts, the poster, the video, the caption. You copy a command, paste it into the AI tool of your choice, and you are done.',
    flowH: 'Your creation chain in 4 steps',
    flow: [['1', 'Idea and script', 'The creator kit writes your hooks, your 15 or 30 second script, your voice-over and your shot plan.', 'kit'], ['2', 'Visual', 'Poster, Reel cover, thumbnail: a free command, or the “Generate here” Studio that creates the image for you.', 'reseaux'], ['3', 'Video', 'Motion design (animated text, logo reveal, countdown, promo) or an advertising video from your photo.', 'motion'], ['4', 'Caption and calendar', 'Caption, hashtags, customer replies, 7 or 30 day calendar: everything that comes after creating.', 'kit']],
    famH: 'Four families of commands', fam: [['Free commands', 'Over 600 poster commands to copy, by trade.'], ['“Generate here” Studio', 'The image is created directly on the site from your photo, with your brand and a QR code if you wish.'], ['Motion design video', 'Commands for video generators (Veo, Runway, Kling): ready to post on your networks.'], ['Creator kit', 'Text commands for ChatGPT, Gemini or Claude: scripts, hooks, captions, calendars.']],
    honestH: 'What the site does, and what it does not', honest: ['Video and text commands are pasted into the AI tool of your choice: SlashAtlas does not generate the videos itself yet.', 'The “Generate here” Studio creates images (posters, product visuals) and adds them to your account; it is paid by credit, while the commands stay free.', 'Results depend on the AI tool used: always reread the text and check the information before publishing.'],
    sCats: 'Explore', cta: 'See the commands', cta2: 'Try the Studio', stripH: 'Fast AI content creation studio', stripP: 'From script to video, from poster to caption: everything for your social media, in one place.', stripBtn: 'Discover the studio',
  },
};
function studioStrip(l) {
  const S = STUDIO[l], p = P[l];
  return `<div class="studio-strip"><div><b>${S.stripH}</b><p>${S.stripP}</p></div><div class="ss-links"><a class="btn pri" href="${p.studio}">${S.stripBtn}</a><a class="btn gl" href="${p.cat('motion')}">${catOf('motion')[l]}</a><a class="btn gl" href="${p.cat('kit')}">${catOf('kit')[l]}</a></div></div>`;
}
function studioPage(l) {
  const S = STUDIO[l], p = P[l];
  const nCmd = COMMANDS.length;
  const flow = S.flow.map((f) => `<li><span class="si">${f[0]}</span><b>${f[1]}</b><small>${f[2]}</small><a class="more" href="${p.cat(f[3])}">${catOf(f[3])[l]} ›</a></li>`).join('');
  const fam = S.fam.map((f) => `<div class="plan"><h3>${f[0]}</h3><p>${f[1]}</p></div>`).join('');
  const pick = (cat, k) => COMMANDS.filter((c) => c.cat === cat).slice(0, k);
  const cards = [...pick('motion', 3), ...pick('kit', 3)];
  const body = `<div class="wrap"><div class="eyebrow">${S.k}</div><h1 class="big sm">${S.h}</h1><p class="lead">${S.lead}</p>
<div class="cta"><a class="btn pri big" href="${p.cmds}">${S.cta}</a><a class="btn gl big" href="${p.try}">${S.cta2}</a></div>
<div class="sec"><h2>${S.flowH}</h2></div><ol class="steps3 studio-flow">${flow}</ol>
<div class="sec"><h2>${S.famH}</h2></div><div class="plans studio-fam">${fam.replace(/Plus de 600/, 'Plus de ' + Math.floor(nCmd / 50) * 50).replace(/Over 600/, 'Over ' + Math.floor(nCmd / 50) * 50)}</div>
<div class="sec"><h2>${S.sCats}</h2></div><div class="grid">${cards.map((c) => card(c, l)).join('')}</div>
<div class="sec"><h2>${S.honestH}</h2></div><ul class="prose">${S.honest.map((x) => `<li>${x}</li>`).join('')}</ul>${band(l)}</div>`;
  emit(l, 'studio', p.studio, { title: S.title, desc: S.desc, body, alt: alt2(P.fr.studio, P.en.studio) });
  if (l === 'fr') pages.push({ fr: P.fr.studio, en: P.en.studio });
}
function home(l) {
  const t = T[l].home, p = P[l], H = HOME[l];
  const featured = ['fashionposter', 'productglow', 'skincareglow', 'lookbook', 'splashshot', 'hairshowcase', 'menuhero', 'openhouse'].map((s) => COMMANDS.find((c) => c.slug === s)); // mode, produit et cosmétique d'abord ; l'accueil les remplace par les plus utilisées dès qu'il y a des données
  const newest = ['typobehind', 'logoglass', 'sheetpose9', 'infoexploded', 'dioskislope', 'brandboard', 'magcover', 'shopflash', 'mascotproduct', 'animeposter'].map((s) => COMMANDS.find((c) => c.slug === s));
  const vids = ['mgkinetic', 'revealvid', 'mglogoreveal', 'turntable', 'mgcountdown', 'splashslow', 'mgsaleburst', 'unboxing', 'mgphoneframe', 'flashsale', 'mgstory', 'kithooks'].map((s) => COMMANDS.find((c) => c.slug === s)).filter(Boolean);
  const cats = CATEGORIES.map((c) => `<a class="cat" href="${p.cat(c.id)}"><b>${esc(c[l])}</b><small>${H.n(COMMANDS.filter((x) => x.cat === c.id).length)}</small></a>`).join('');
  const steps = H.steps.map((x, i) => `<li><span class="si">${[ICON.copy, ICON.paste, ICON.spark][i]}</span><b>${x[0]}</b><small>${x[1]}</small></li>`).join('');
  const body = `<div class="wrap hero"><h1 class="big">${H.h1[0]} <span>${H.h1[1]}</span></h1><p class="lead">${H.sub}</p>
<ol class="steps3" aria-label="${l === 'fr' ? 'Comment ça marche' : 'How it works'}">${steps}</ol>
<div class="sec tight"><h2 id="rail-h">${H.rail}</h2><span class="swipe">${H.tapHint} →</span></div>
<div class="rtabs" role="tablist" aria-label="${esc(H.rail)}"><button type="button" class="rtab on" data-rail="sel" role="tab" aria-selected="true">${H.tabSel}</button><button type="button" class="rtab" data-rail="new" role="tab">${H.tabNew}</button><button type="button" class="rtab" data-rail="vid" role="tab">${H.tabVid}</button></div></div>
<div class="rail" id="rail-sel" role="list">${featured.map((c) => railCard(c, l)).join('')}</div>
<div class="rail" id="rail-new" role="list" hidden>${newest.map((c) => railCard(c, l)).join('')}</div>
<div class="rail" id="rail-vid" role="list" hidden>${vids.map((c) => railCard(c, l)).join('')}</div>
<div class="wrap"><div class="cta"><a class="btn gl" href="${p.cmds}">${H.all.replace('{n}', COMMANDS.length)} ›</a></div>${ad('lb', l)}
<div class="tools"><span>${H.tools}</span><b>ChatGPT</b><b>Gemini</b><b>Midjourney</b><b>Veo</b><b>Runway</b></div>${studioStrip(l)}
${videoBlock(l)}
<div class="sec"><h2>${H.cats}</h2></div><div class="cats">${cats}</div>
<div class="gap"></div>${tuto(l)}${ad('rect', l)}${waCard(l, 'home')}${band(l)}</div>`;
  emit(l, 'home', p.home, { ogTitle: t.ogTitle, title: t.title, desc: t.desc, body, alt: alt2(P.fr.home, P.en.home),
    ld: { '@context': 'https://schema.org', '@graph': [{ '@type': 'WebSite', '@id': abs('/') + '#site', name: cfg.name, alternateName: cfg.alternateNames, url: abs(p.home), inLanguage: T[l].htmlLang, publisher: { '@id': abs('/') + '#org' } }, { '@type': 'Organization', '@id': abs('/') + '#org', name: cfg.name, alternateName: cfg.alternateNames, url: abs('/'), logo: abs('/favicon.svg') }] } });
  if (l === 'fr') pages.push({ fr: P.fr.home, en: P.en.home });
}
function cmdsPage(l) {
  const t = T[l].cmds, p = P[l];
  const chips = [`<button class="chip" data-cat="" aria-pressed="true" type="button">${t.all}</button>`, ...CATEGORIES.map((c) => `<button class="chip" data-cat="${c.id}" aria-pressed="false" type="button">${c[l]}</button>`)].join('');
  const body = `<div class="wrap"><h1 class="big sm">${t.h}</h1><div class="search"><span aria-hidden="true">⌕</span><input id="q" type="search" placeholder="${esc(t.search)}" aria-label="${esc(t.search)}"></div><div class="chips2">${chips}</div>${ad('lb', l)}<div class="grid" id="list">${COMMANDS.map((c) => card(c, l)).join('')}</div><p class="none" id="none" hidden>${t.none}</p><div class="cta center"><button class="btn gl" id="more" type="button" hidden></button></div>${band(l)}</div>`;
  emit(l, 'cmds', p.cmds, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.cmds, P.en.cmds) });
  if (l === 'fr') pages.push({ fr: P.fr.cmds, en: P.en.cmds });
}
function catPage(l, c) {
  const t = T[l].cat, p = P[l];
  const list = COMMANDS.filter((x) => x.cat === c.id);
  const body = `<div class="wrap"><div class="crumb"><a href="${p.home}">${T[l].cmd.crumbHome}</a> › <a href="${p.cmds}">${T[l].nav.cmds}</a> › <b>${c[l]}</b></div><h1 class="big sm">${t.h(c[l])}</h1><p class="lead">${c[l + '_d']}</p>${ad('lb', l)}<div class="grid">${list.map((x) => card(x, l)).join('')}</div><div class="cta"><a class="link" href="${p.cmds}">‹ ${t.back}</a></div>${band(l)}</div>`;
  emit(l, 'cat', p.cat(c.id), { title: t.title(c[l]), desc: c[l + '_d'], body, alt: alt2(P.fr.cat(c.id), P.en.cat(c.id)) });
  if (l === 'fr') pages.push({ fr: P.fr.cat(c.id), en: P.en.cat(c.id) });
}
function cmdPage(l, c) {
  const t = T[l].cmd, p = P[l], ct = c[l], cat = catOf(c.cat);
  const catList = COMMANDS.filter((x) => x.cat === c.cat), ci = catList.findIndex((x) => x.slug === c.slug);
  const same = [...catList.slice(ci + 1), ...catList.slice(0, ci)]; // les voisines de la liste d'abord, pour varier d'une page à l'autre
  const rel = [...same, ...COMMANDS.filter((x) => x.cat !== c.cat)].slice(0, 3);
  const tools = c.kind === 'text' ? [['ChatGPT', 'https://chatgpt.com/'], ['Gemini', 'https://gemini.google.com/'], ['Claude', 'https://claude.ai/']] : c.kind === 'video' || c.kind === 'motion' ? [['Gemini (Veo)', 'https://gemini.google.com/'], ['Runway', 'https://runwayml.com/'], ['Kling', 'https://klingai.com/'], ['Pika', 'https://pika.art/']] : [['ChatGPT', 'https://chatgpt.com/'], ['Gemini', 'https://gemini.google.com/'], ['Midjourney', 'https://www.midjourney.com/']];
  const fullText = fullPrompt(c, l);
  const KL = KIND_LABEL[l][c.kind || 'product'];
  const brandBox = BRAND_KINDS.includes(c.kind || 'product') && canGen(c) ? `<details class="brandbox" data-brand="${esc(JSON.stringify({ k: c.kind || 'product', ...BRAND[l] }))}"><summary>${BRAND[l].title}</summary><p class="hint">${BRAND[l].hint}</p><div class="bgrid">${BRAND[l].fields.map((f) => `<label>${f[1]}<input type="text" data-role="${f[0]}" maxlength="${f[3]}" placeholder="${esc(f[2])}" autocomplete="off"></label>`).join('')}</div></details>` : '';
  const adapt = `<div class="adapt" data-for="p-${c.slug}" data-code="${esc(c.code)}" data-base="${esc(ct.prompt)}" data-c1="${esc(CLAUSE[l][c.kind || 'product'][0])}" data-cn="${esc(CLAUSE[l][c.kind || 'product'][1])}"><label>${KL[0]}<input type="text" maxlength="60" placeholder="${esc(KL[1])}" autocomplete="off"></label>${c.kind === 'text' ? '' : `<div class="seg2" role="group"><button type="button" data-n="1" aria-pressed="true">${MULTI[l][0]}</button><button type="button" data-n="n" aria-pressed="false">${MULTI[l][1]}</button></div>`}</div>`;
const FS = { fr: ['Copiez', 'Collez', 'Publiez'], en: ['Copy', 'Paste', 'Post'] };
  const fsteps = FS[l].map((x, i) => `<li><span class="si">${[ICON.copy, ICON.paste, ICON.spark][i]}</span><b>${x}</b></li>`).join('');
  const body = `<div class="wrap"><div class="crumb"><a href="${p.home}">${t.crumbHome}</a> › <a href="${p.cat(c.cat)}">${cat[l]}</a> › <b>${esc(c.code)}</b></div>
<div class="fiche"><div class="fhead"><div class="eyebrow">${cat[l]}${c.kind === 'text' ? '' : ' · ' + c.ratio}</div><h1>${esc(ct.title)}</h1></div><div class="fpost">${poster(c, l, true)}${c.kind === 'video' || c.kind === 'motion' ? `<p class="vnote">${l === 'fr' ? 'Image d’illustration. Cette commande crée une vidéo : collez-la dans un générateur de vidéo avec votre photo.' : 'Illustration image. This command creates a video: paste it into a video generator with your photo.'}</p>` : ''}</div>
<div class="fbody">${adapt}${brandBox}<div class="cmd"><pre id="p-${c.slug}">${esc(fullText)}</pre><div class="acts big">${tryBtn(c, l, 'big')}<button class="btn ${canGen(c) ? 'gl' : 'pri'} big" type="button" data-copy="#p-${c.slug}" data-slug="${c.slug}" data-after="1">${ICON.copy}${t.copy}</button></div><p class="cnt big" id="cmd-cnt" data-slug="${c.slug}" hidden></p></div>${c.steps ? `<p class="hint stepnote">${l === 'fr' ? `Commande en ${c.steps.length + 1} étapes : envoyez la commande ci-dessus (étape 1), puis les étapes suivantes dans l’ordre, dans la même conversation.` : `${c.steps.length + 1}-step command: send the command above (step 1), then the next steps in order, in the same conversation.`}</p>${c.steps.map((st, i) => `<div class="cmd step"><pre id="p-${c.slug}-${i + 2}">${esc(st[l])}</pre><div class="acts big"><button class="btn gl big" type="button" data-copy="#p-${c.slug}-${i + 2}" data-slug="${c.slug}">${ICON.copy}${t.copy}</button></div></div>`).join('')}` : ''}
<ol class="steps3 mini3">${fsteps}</ol>
<div class="test"><span class="tl">${t.testOn}</span>${tools.map(([n, u]) => `<a class="btn gl sm" href="${u}" target="_blank" rel="noopener noreferrer nofollow" data-test="${n}">${n} ↗</a>`).join('')}</div>
${c.slug === 'splashshot' ? `<div class="ex2"><b>${l === 'fr' ? 'Même commande, autre produit' : 'Same command, another product'}</b><div><figure><img src="/img/c/splashshot-ex-avant.webp" alt="" loading="lazy"><figcaption>${BEFORE[l]}</figcaption></figure><span>→</span><figure><img src="/img/c/splashshot-ex-apres.webp" alt="${l === 'fr' ? 'La même commande appliquée à un produit de soin' : 'The same command applied to a skincare product'}" loading="lazy"><figcaption>${l === 'fr' ? 'Crème de soin' : 'Skincare cream'}</figcaption></figure></div><small>${AIWORD[l]} · Gemini</small></div>` : ''}<div class="after" id="after"><b>${t.afterT}</b>${waCard(l, 'after')}<div class="grid">${rel.map((x) => card(x, l)).join('')}</div>${ad('rect', l, true)}</div></div></div>
${same.length ? `<div class="sec"><h2>${t.similar}</h2></div><div class="grid">${same.slice(0, 6).map((x) => card(x, l)).join('')}</div>${same.length > 6 ? `<div class="cta"><a class="btn gl" href="${p.cat(c.cat)}">${l === 'fr' ? `Voir les ${catList.length} commandes de la catégorie` : `See all ${catList.length} commands in this category`} ›</a></div>` : ''}` : ''}</div>`;
  const ld = { '@context': 'https://schema.org', '@type': 'BreadcrumbList', itemListElement: [{ '@type': 'ListItem', position: 1, name: t.crumbHome, item: abs(p.home) }, { '@type': 'ListItem', position: 2, name: cat[l], item: abs(p.cat(c.cat)) }, { '@type': 'ListItem', position: 3, name: c.code, item: abs(p.cmd(c.slug)) }] };
  emit(l, 'cmd', p.cmd(c.slug), { img: c.noImage ? undefined : `/img/c/${c.slug}-apres.webp`, title: t.title(c.code, ct.title), desc: ct.desc, body, alt: alt2(P.fr.cmd(c.slug), P.en.cmd(c.slug)), ld });
  if (l === 'fr') pages.push({ fr: P.fr.cmd(c.slug), en: P.en.cmd(c.slug) });
}
function tutoPage(l) {
  const t = T[l].tuto, p = P[l];
  const body = `<div class="wrap">${tuto(l, true)}${videoBlock(l)}${ad('lb', l)}<div class="sec"><h2>${t.faqH}</h2></div><div class="faq">${t.faq.map(([q, a]) => `<details><summary>${q}</summary><p>${a}</p></details>`).join('')}</div><div class="cta"><a class="btn pri" href="${p.cmds}">${T[l].home.cta1}</a></div>${band(l)}</div>`;
  const ld = { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: t.faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) };
  emit(l, 'tuto', p.tuto, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.tuto, P.en.tuto), ld });
  if (l === 'fr') pages.push({ fr: P.fr.tuto, en: P.en.tuto });
}
function packText(l) {
  const head = l === 'fr'
    ? 'Tu es mon assistant de visuels publicitaires. Quand mon message commence par « / » suivi d’un nom de commande, applique cette commande à l’image jointe. Si aucune image n’est jointe, demande-moi de l’envoyer. Garde toujours le produit, le visage ou le lieu identiques à la photo.'
    : 'You are my advertising visuals assistant. When my message starts with “/” followed by a command name, apply that command to the attached image. If no image is attached, ask me to send one. Always keep the product, face or place identical to the photo.';
  return head + '\n\n' + COMMANDS.filter((c) => !['video', 'free', 'motion', 'text'].includes(c.kind)).map((c) => `${c.code} : ${c[l].prompt}`).join('\n\n');
}
function packPage(l) {
  const t = T[l].pack, p = P[l];
  const body = `<div class="wrap"><div class="eyebrow">${t.k}</div><h1 class="big sm">${t.h}</h1><p class="lead">${t.l}</p>
<div class="pack"><div class="ver">● ${t.ver} · ${COMMANDS.length} ${l === 'fr' ? 'commandes' : 'commands'}</div><div class="cmd"><pre id="pack-text" style="max-height:200px">${esc(packText(l))}</pre><button class="btn pri big" type="button" data-copy="#pack-text" data-slug="pack">${t.copy}</button></div>
<h2 class="h3">${t.how}</h2><div class="how2"><div><b>${t.h1}</b><p>${t.t1}</p></div><div><b>${t.h2}</b><p>${t.t2}</p></div></div><p class="hint">${t.note}</p>
<h2 class="h3">${t.inc}</h2><div class="inc">${COMMANDS.map((c) => `<a href="${p.cmd(c.slug)}"><code>${c.code}</code></a>`).join('')}</div></div>${ad('lb', l)}
<div class="band"><h3 style="font-size:20px">${t.notify}</h3>${bandForm(l, 'newsletter')}</div></div>`;
  emit(l, 'pack', p.pack, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.pack, P.en.pack) });
  if (l === 'fr') pages.push({ fr: P.fr.pack, en: P.en.pack });
}
function proPage(l) {
  const t = T[l].pro;
  const price = l === 'fr' ? cfg.pro.price : cfg.pro.priceEn;
  const body = `<div class="wrap narrow"><div class="eyebrow">${t.k}</div><h1 class="big sm">${t.h}</h1><div class="plans"><div class="plan"><h3>${t.free}</h3><div class="price">${l === 'fr' ? '0 $' : '$0'}</div><ul><li>${t.f1}</li><li>${t.f2}</li><li>${t.f3}</li></ul></div>
<div class="plan hot"><h3>${t.pro} <span class="soon">${t.soon}</span></h3><div class="price">${price} <small>${t.mo}</small></div><div class="conv">≈ ${cfg.pro.convFcfa}</div><ul><li>${t.p1}</li><li>${t.p2}</li><li>${t.p3}</li><li>${t.p4}</li></ul><a class="btn pri big" href="${P[l].try}?pass=1" data-nopub-buy>${t.wl}</a><p class="hint">${t.note}</p></div></div></div>`;
  emit(l, 'pro', P[l].pro, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.pro, P.en.pro) });
  if (l === 'fr') pages.push({ fr: P.fr.pro, en: P.en.pro });
}
function legalPage(l, kind) {
  const t = T[l].legal, key = kind === 'privacy' ? 'p' : 'c';
  const body = `<div class="wrap narrow prose"><h1 class="big sm">${t[key + 'H']}</h1>${t[key + 'Body'].map((x) => `<p>${x}</p>`).join('')}</div>`;
  emit(l, kind, P[l][kind], { title: t[key + 'Title'], desc: t[key + 'Desc'], body, alt: alt2(P.fr[kind], P.en[kind]) });
  if (l === 'fr') pages.push({ fr: P.fr[kind], en: P.en[kind] });
}

const GT = {
  fr: { idxTitle: 'Guides pour réussir vos affiches IA | SlashAtlas', idxDesc: 'Photographier un produit, écrire un bon prompt, choisir le format : des guides simples pour des affiches IA réussies, par SlashAtlas.', idxH: 'Guides', idxLead: 'Des conseils concrets pour de meilleures photos et de meilleures affiches, avec ou sans IA.', read: 'min de lecture', tryIt: 'Essayer la commande', cat: 'Voir la catégorie', also: 'À lire aussi', all: 'Tous les guides', home: 'Accueil', cta: 'Passez de la théorie à l’affiche' },
  en: { idxTitle: 'Guides to better AI posters | SlashAtlas', idxDesc: 'Photograph a product, write a good prompt, pick the right format: simple guides to successful AI posters, by SlashAtlas.', idxH: 'Guides', idxLead: 'Practical advice for better photos and better posters, with or without AI.', read: 'min read', tryIt: 'Try the command', cat: 'See the category', also: 'Read next', all: 'All guides', home: 'Home', cta: 'Turn the advice into a poster' },
};
const gp = (g, l) => (l === 'fr' ? `/guides/${g.slug.fr}/` : `/en/guides/${g.slug.en}/`);
const gAlt = (g) => alt2(`/guides/${g.slug.fr}/`, `/en/guides/${g.slug.en}/`);
function guidesIndexPage(l) {
  const t = GT[l], p = P[l];
  const cards = GUIDES.map((g) => `<a class="gcard" href="${gp(g, l)}"><b>${esc(g[l].title)}</b><span>${esc(g[l].desc)}</span><small>${g.min} ${t.read}</small></a>`).join('');
  const body = `<div class="wrap narrow"><h1 class="big sm">${t.idxH}</h1><p class="lead">${t.idxLead}</p><div class="gcards">${cards}</div></div>`;
  emit(l, 'guides', p.guides, { title: t.idxTitle, desc: t.idxDesc, body, alt: alt2(P.fr.guides, P.en.guides) });
  if (l === 'fr') pages.push({ fr: P.fr.guides, en: P.en.guides });
}
function guidePage(l, g) {
  const t = GT[l], p = P[l], x = g[l], cat = CATEGORIES.find((c) => c.id === g.cat), cmd = COMMANDS.find((c) => c.slug === g.cmd);
  const sec = ([h, items]) => `<h2>${esc(h)}</h2>${items.map((it) => (Array.isArray(it) ? `<ul>${it.map((li) => `<li>${esc(li)}</li>`).join('')}</ul>` : `<p>${esc(it)}</p>`)).join('')}`;
  const secs = x.sections.map(sec);
  const rel = GUIDES.filter((o) => o !== g).slice(0, 3).map((o) => `<a class="gcard" href="${gp(o, l)}"><b>${esc(o[l].title)}</b><small>${o.min} ${t.read}</small></a>`).join('');
  const cta = `<aside class="gcta"><b>${t.cta}</b><div class="acts big">${cmd ? `<a class="btn pri" href="${p.cmd(cmd.slug)}">${t.tryIt} ${esc(cmd.code)}</a>` : ''}<a class="btn gl" href="${p.cat(cat.id)}">${t.cat} · ${esc(cat[l])}</a></div></aside>`;
  const body = `<div class="wrap narrow prose guide"><div class="crumb"><a href="${p.home}">${t.home}</a> › <a href="${p.guides}">${t.idxH}</a></div><h1 class="big sm">${esc(x.title)}</h1><p class="meta">${g.min} ${t.read}</p><p class="lead">${esc(x.intro)}</p>${secs.slice(0, 2).join('')}${ad('lb', l)}${secs.slice(2).join('')}${cta}<div class="sec"><h2>${t.also}</h2></div><div class="gcards">${rel}</div><p><a href="${p.guides}">${t.all} ›</a></p></div>`;
  const ld = { '@context': 'https://schema.org', '@type': 'Article', headline: x.title, description: x.desc, inLanguage: l, datePublished: '2026-10-11', author: { '@type': 'Organization', name: cfg.name, url: abs('/') }, publisher: { '@type': 'Organization', name: cfg.name }, mainEntityOfPage: abs(gp(g, l)) };
  emit(l, 'guide', gp(g, l), { title: x.title + ' | ' + cfg.name, desc: x.desc, body, alt: gAlt(g), ld });
  if (l === 'fr') pages.push({ fr: gp(g, 'fr'), en: gp(g, 'en') });
}
function aboutPage(l) {
  const x = aboutBody(l, cfg.legal || {}, COMMANDS.length);
  const body = `<div class="wrap narrow prose"><h1 class="big sm">${x.h}</h1>${x.sections.map(([h, ps]) => `<h2>${h}</h2>${ps.filter(Boolean).map((q) => `<p>${q}</p>`).join('')}`).join('')}</div>`;
  emit(l, 'about', P[l].about, { title: x.title, desc: x.desc, body, alt: alt2(P.fr.about, P.en.about) });
  if (l === 'fr') pages.push({ fr: P.fr.about, en: P.en.about });
}
function termsPage(l) {
  const x = termsBody(l, cfg.legal || {});
  const body = `<div class="wrap narrow prose"><h1 class="big sm">${x.title.replace(/ \| SlashAtlas$/, "")}</h1>${x.sections.map(([h, ps]) => `<h2>${h}</h2>${ps.map((q) => `<p>${q}</p>`).join('')}`).join('')}</div>`;
  emit(l, 'terms', P[l].terms, { title: x.title, desc: x.desc, body, alt: alt2(P.fr.terms, P.en.terms) });
  if (l === 'fr') pages.push({ fr: P.fr.terms, en: P.en.terms });
}

function adminPage() {
  const body = `<div class="wrap"><div class="eyebrow">Administration</div><h1 class="big sm">Suivi de SlashAtlas</h1>
<div id="adm-out" class="adm-login"><p class="lead">Accès réservé à l’administrateur. Connectez-vous avec le compte Google autorisé.</p><button class="btn pri big" type="button" data-login>Continuer avec Google</button><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></div>
<div id="adm-no" hidden><p class="lead">Ce compte n’a pas accès à l’administration.</p><button class="btn gl" type="button" data-logout>Changer de compte</button></div>
<div id="adm" hidden></div></div>`;
  emit('fr', 'admin', '/admin/', { title: 'Administration | SlashAtlas', desc: 'Tableau de bord privé de SlashAtlas : audience, commandes copiées et inscriptions. Accès réservé à l’administrateur.', body, noindex: true, extraJs: '/js/admin.js' });
}

const TRY = {
  fr: { title: 'Générer votre visuel sur SlashAtlas', desc: 'Importez votre photo, choisissez une commande et obtenez votre visuel directement sur SlashAtlas, avec des crédits payables par mobile money.', k: 'Studio', h: 'Générez votre visuel ici' },
  en: { title: 'Generate your visual on SlashAtlas', desc: 'Upload your photo, pick a command and get your visual right on SlashAtlas, with credits you can pay by mobile money.', k: 'Studio', h: 'Generate your visual here' },
};
function tryPage(l) {
  const t = TRY[l], p = P[l];
  const map = { commands: Object.fromEntries(COMMANDS.filter(canGen).map((c) => [c.slug, { code: c.code, title: c[l].title, kind: c.kind || 'product', img: !c.noImage }])), brand: BRAND[l] };
  const body = `<div class="wrap narrow"><div class="eyebrow">${t.k}</div><h1 class="big sm">${t.h}</h1>
<div id="studio"${WA_URL ? ` data-wa="${esc(WA_URL)}"` : ''} data-contact="${esc((cfg.legal && cfg.legal.email) || '')}" data-map="${esc(JSON.stringify(map))}"></div></div>`;
  emit(l, 'try', p.try, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.try, P.en.try), noindex: true, extraJs: '/js/try.js' });
}
function notFound() {
  const t = T.fr.nf;
  write('404.html', layout({ l: 'fr', key: '404', path: '/404.html', title: t.title, desc: t.p, noindex: true, body: `<div class="wrap narrow center"><h1 class="big sm">${t.h}</h1><p class="lead">${t.p}</p><a class="btn pri" href="/commandes/">${t.btn}</a></div>` }));
}

// ───────── génération ─────────
// Données des commandes pour le serveur (la commande finale est composée côté serveur : le client ne peut pas la modifier).
fs.writeFileSync(path.join(root, 'functions', 'commands.json'), JSON.stringify({
  commands: Object.fromEntries(COMMANDS.map((c) => [c.slug, { code: c.code, ratio: c.ratio, kind: c.kind || 'product', fr: c.fr.prompt, en: c.en.prompt, titleFr: c.fr.title, titleEn: c.en.title, cat: c.cat, can: canGen(c) ? 1 : 0, img: c.noImage ? 0 : 1, x: c.x, y: c.y, r: c.r, posterFr: c.fr.poster, posterEn: c.en.poster, full: { fr: fullPrompt(c, 'fr'), en: fullPrompt(c, 'en') } }])),
  cats: Object.fromEntries(CATEGORIES.map((k) => [k.id, { fr: k.fr, en: k.en }])),
  clauses: CLAUSE,
  brand: BRAND,
  termsVersion: TERMS_VERSION,
}));
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });
fs.cpSync(path.join(root, 'static'), dist, { recursive: true });
{ const sw = path.join(dist, 'sw.js'); fs.writeFileSync(sw, fs.readFileSync(sw, 'utf8').replace(/__V__/g, createHash('sha1').update(V.js + V.css + Date.now()).digest('hex').slice(0, 8))); } // une version du service worker par construction
for (const l of ['fr', 'en']) {
  home(l); studioPage(l); cmdsPage(l); tutoPage(l); packPage(l); proPage(l); legalPage(l, 'privacy'); legalPage(l, 'cookies'); termsPage(l); aboutPage(l); guidesIndexPage(l); GUIDES.forEach((g) => guidePage(l, g)); tryPage(l);
  for (const c of CATEGORIES) catPage(l, c);
  for (const c of COMMANDS) cmdPage(l, c);
}
adminPage();
notFound();
const xml = (u) => `<url><loc>${abs(u.fr)}</loc><xhtml:link rel="alternate" hreflang="fr" href="${abs(u.fr)}"/><xhtml:link rel="alternate" hreflang="en" href="${abs(u.en)}"/></url>\n<url><loc>${abs(u.en)}</loc><xhtml:link rel="alternate" hreflang="fr" href="${abs(u.fr)}"/><xhtml:link rel="alternate" hreflang="en" href="${abs(u.en)}"/></url>`;
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${pages.map(xml).join('\n')}\n</urlset>\n`);
write('robots.txt', cfg.indexable ? `User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: ${abs('/sitemap.xml')}\n` : 'User-agent: *\nDisallow: /\n');
console.log(`SlashAtlas : ${pages.length * 2 + 1} pages (${COMMANDS.length} commandes, ${CATEGORIES.length} catégories), indexable=${cfg.indexable}`);
