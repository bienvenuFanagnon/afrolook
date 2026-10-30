// Afrolook Ads : pages de la régie publicitaire (annonceurs) : bloc de l'accueil, page /ads/ et espace annonceur /ads/espace/.
// Les annonces sont déposées sur le même système de pub que l'application (voir functions/src/ads/adsWeb.ts). Page FR seulement pour l'instant.
// L'audience affichée est un seul chiffre, ici : AUDIENCE (cumulée sur toutes nos plateformes, confirmée par le propriétaire le 29/10/2026).

import { catOptions, catChecks, rulesHtml, RULES } from './ads_data.mjs';
import { formatsSection } from './ads_formats.mjs';

export const AUDIENCE = 'plus de 50 000';
export const AUDIENCE_EN = 'over 50,000';

const IC = {
  globe: 'M12 2a10 10 0 100 20 10 10 0 000-20zm6.9 9h-3.2a15.7 15.7 0 00-1.4-5.2A8 8 0 0118.9 11zM12 4c.9 1.2 1.6 3.2 1.9 7h-3.8c.3-3.8 1-5.8 1.9-7zM4.1 13h3.2c.2 1.9.7 3.7 1.4 5.2A8 8 0 014.1 13zm3.2-2H4.1a8 8 0 014.6-5.2A15.7 15.7 0 007.3 11zM12 20c-.9-1.2-1.6-3.2-1.9-7h3.8c-.3 3.8-1 5.8-1.9 7zm3.3-1.8c.7-1.5 1.2-3.3 1.4-5.2h3.2a8 8 0 01-4.6 5.2z',
  phone: 'M17 1H7a2 2 0 00-2 2v18a2 2 0 002 2h10a2 2 0 002-2V3a2 2 0 00-2-2zm0 18H7V5h10v14z',
  rocket: 'M12 2c3.3 2 5 5.3 5 9 0 1.6-.4 3.1-1 4.4L18 18l-3 1-1.2-1.8H10.2L9 19l-3-1 2-2.6A9.8 9.8 0 017 11c0-3.7 1.7-7 5-9zm0 6a2 2 0 100 4 2 2 0 000-4z',
  poster: 'M5 3h14a2 2 0 012 2v14a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2zm1 12l3-4 2.3 3 3.2-4.2L19 15H6z',
  bag: 'M18 6h-2a4 4 0 00-8 0H6a2 2 0 00-2 2v11a2 2 0 002 2h12a2 2 0 002-2V8a2 2 0 00-2-2zm-6-2a2 2 0 012 2h-4a2 2 0 012-2z',
  check: 'M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4z',
  gift: 'M20 7h-2.2A3 3 0 0012 4.2 3 3 0 006.2 7H4a1 1 0 00-1 1v3a1 1 0 001 1v7a2 2 0 002 2h12a2 2 0 002-2v-7a1 1 0 001-1V8a1 1 0 00-1-1zM15 5a1 1 0 110 2h-3a2 2 0 013-2zM9 5a1 1 0 011 2H9a1 1 0 010-2zm2 15H6v-7h5v7zm7 0h-5v-7h5v7z',
  eye: 'M12 5C7 5 2.7 8.1 1 12c1.7 3.9 6 7 11 7s9.3-3.1 11-7c-1.7-3.9-6-7-11-7zm0 11a4 4 0 110-8 4 4 0 010 8zm0-6.4a2.4 2.4 0 100 4.8 2.4 2.4 0 000-4.8z',
  click: 'M9 2v14l3.5-3.5L16 20l2.5-1-3.5-7.5H20L9 2z',
  video: 'M17 10.5V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.5l4 4v-11l-4 4z',
  layers: 'M12 2L1 8l11 6 9-4.9V17h2V8L12 2zM5 13.2v4L12 21l7-3.8v-4L12 17l-7-3.8z',
  bell: 'M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.1-1.6-5.6-4.5-6.3V4a1.5 1.5 0 00-3 0v.7C7.6 5.4 6 7.9 6 11v5l-2 2v1h16v-1l-2-2z',
  banner: 'M3 6h18a1 1 0 011 1v6a1 1 0 01-1 1H3a1 1 0 01-1-1V7a1 1 0 011-1zm2 2v4h14V8H5zm-3 8h20v2H2v-2z',
  card: 'M4 4h16a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V6a2 2 0 012-2zm0 2v6h16V6H4zm0 8v4h9v-4H4zm11 0v4h5v-4h-5z',
  arrow: 'M5 12h12.2l-5.6-5.6L13 5l8 8-8 8-1.4-1.4 5.6-5.6H5z',
  mail: 'M20 4H4a2 2 0 00-2 2v12a2 2 0 002 2h16a2 2 0 002-2V6a2 2 0 00-2-2zm0 4l-8 5-8-5V6l8 5 8-5v2z',
  shield: 'M12 1L3 5v6c0 5.5 3.8 10.7 9 12 5.2-1.3 9-6.5 9-12V5l-9-4zm-1 15l-4-4 1.4-1.4L11 13.2l5.6-5.6L18 9l-7 7z',
};
export const ico = (n, s = 22) => `<svg class="ico" width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="${IC[n]}"/></svg>`;
export const G = '<svg width="20" height="20" viewBox="0 0 48 48" aria-hidden="true"><path fill="#FFC107" d="M43.6 20.1H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.1 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 13 4 4 13 4 24s9 20 20 20 20-9 20-20c0-1.3-.1-2.6-.4-3.9z"/><path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.1 7.9 3l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/><path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/><path fill="#1976D2" d="M43.6 20.1H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.6-.4-3.9z"/></svg>';

const stat = (big, label, note) => `<div class="adst"><b>${big}</b><span>${label}</span><small>${note}</small></div>`;

/** Téléphone : une annonce « Sponsorisé » dans le fil Afrolook, avec son bouton d'action. */
export const phone = (cap = '') => `<figure class="mkw"><div class="mkp"><div class="mk"><div class="mkb"><span>9:41</span><span class="mkn"></span><span>5G ▮</span></div>
<div class="mkab"><span>${ico('globe', 22)}</span><b class="logo">Afrolook</b><i></i><span>${ico('bell', 22)}</span></div>
<div class="mktabs2"><span class="on">✨ Pour toi</span><span>⚽ Sport</span><span>📅 Sorties</span></div>
<div class="admk"><div class="admk-top"><i class="admk-av" id="pv-av">K</i><span><b id="pv-name">Kofi Studio</b><small>Sponsorisé · Annonce gratuite</small></span></div>
 <p class="admk-txt" id="pv-text">Ton site web professionnel en 7 jours, paiement Mobile Money accepté. 🚀</p>
 <div class="admk-img" id="pv-img"><img src="/img/card-collector.webp" alt=""></div>
 <div class="admk-cta"><span id="pv-link">kofistudio.com</span><b id="pv-btn">Visiter</b></div>
 <div class="admk-meta"><span>${ico('eye', 14)} 2 480</span></div></div>
<div class="admk admk2"><div class="admk-top"><i class="admk-av g">M</i><span><b>Maman Ama Cuisine</b><small>Sponsorisé</small></span></div><p class="admk-txt">Commandes de plats togolais livrés à Lomé.</p></div>
</div></div><figcaption>${cap}</figcaption></figure>`;

// ───────── bloc de l'accueil ─────────
const HOME = {
  fr: {
    kick: 'Nouveau · Afrolook Ads', h: 'Annonce <em>gratuitement</em> ton entreprise, ta startup, ton site, ton app, ton projet.',
    p: `Notre régie publicitaire diffuse ton annonce sur <b>Afrolook</b>, <b>SlashAtlas</b>, <b>Pronoflash</b> et <b>Épargne+</b>, auprès de <b>${AUDIENCE} personnes</b>. Un compte Google suffit.`,
    pub: ['Tu as un site ou une application ?', 'Affiche les annonces Afrolook Ads chez toi : audience mesurée et comparée à ta déclaration, catégories d\'annonces choisies par toi, et 65 % du budget des annonces de l\'offre Réseau pour toi.', 'Devenir diffuseur', 'Documentation d\'intégration'],
    sh: ['Nouveau : la Campagne Partage', 'Des personnes inscrites sur Afrolook partagent ton annonce sur WhatsApp, Telegram, Facebook… Tu paies l\'audience, seuls les clics valides sont comptés.', 'Lancer une campagne Partage'],
    cta: 'Publier une annonce gratuite', ghost: 'Voir les annonces en ligne', s1: ['d\'audience', 'sur 4 plateformes'], s2: ['pour annoncer', '3 annonces gratuites de 14 jours chacune'], bar: 'Annonce gratuitement sur Afrolook Ads', barBtn: 'Annoncer',
  },
  en: {
    kick: 'New · Afrolook Ads', h: 'Advertise your business, startup, website, app or project <em>for free</em>.',
    p: `Our ad network shows your ad on <b>Afrolook</b>, <b>SlashAtlas</b>, <b>Pronoflash</b> and <b>Épargne+</b>, to an audience of <b>${AUDIENCE_EN} people</b>. A Google account is all you need.`,
    pub: ['Own a website or an app?', 'Show Afrolook Ads on it: measured audience compared with what you declared, ad categories chosen by you, and 65% of the Network offer budget for you.', 'Become a publisher', 'Integration guide'],
    sh: ['New: Share campaigns', 'People registered on Afrolook share your ad on WhatsApp, Telegram, Facebook… You pay for the audience, only valid clicks are counted.', 'Launch a Share campaign'],
    cta: 'Post a free ad', ghost: 'See live ads', s1: ['audience', 'across 4 platforms'], s2: ['to advertise', '3 free ads of 14 days each'], bar: 'Advertise for free on Afrolook Ads', barBtn: 'Advertise',
  },
};
/** Menu commun aux pages Afrolook Ads : annonceur, diffuseur, documentation, règles, administration (aucun bouton : le lien « Administration » est ajouté par ads.js seulement quand le compte connecté est administrateur). */
export const adsSubnav = (active) => {
  const L = [['ads', '/ads/', 'Annoncer'], ['espace', '/ads/espace/', 'Espace annonceur'], ['diffuseur', '/ads/diffuseur/', 'Espace diffuseur'], ['docs', '/ads/diffuseur/documentation/', 'Documentation d\'intégration'], ['regles', '/ads/diffuseur/regles/', 'Règles des diffuseurs']];
  return `<nav class="adsnav" aria-label="Afrolook Ads"><div class="wrap">${L.map(([k, h, l]) => `<a href="${h}"${k === active ? ' aria-current="page"' : ''}>${l}</a>`).join('')}<span class="sp"></span></div></nav>`;
};
export const adsNav = (lang) => (lang === 'fr' ? 'Annoncer' : 'Advertise');
export const adsBadge = (lang) => (lang === 'fr' ? 'Gratuit' : 'Free');

export function adsHomeBlock(lang) {
  const t = HOME[lang], aud = lang === 'fr' ? AUDIENCE : AUDIENCE_EN;
  return `<section class="adhome"><div class="wrap adhome-g">
 <div class="adhome-l"><span class="adh-kick">${ico('gift', 16)} ${t.kick}</span>
  <h2>${t.h}</h2><p>${t.p}</p>
  <div class="cta"><a class="btn btn-primary adbig" href="/ads/espace/">${G} ${t.cta}</a><a class="btn adghost adbig" href="${lang === 'fr' ? '/ads/' : '/en/ads/'}#annonces">${t.ghost} ${ico('arrow', 18)}</a></div>
  <a class="adshare" href="${lang === 'fr' ? '/ads/' : '/en/ads/'}#partage"><b>${t.sh[0]}</b><span>${t.sh[1]}</span><i>${t.sh[2]} →</i></a></div>
 <div class="adhome-r"><div class="adhome-st">${stat(aud, t.s1[0], t.s1[1])}${stat('0 FCFA', t.s2[0], t.s2[1])}</div>
  <div class="adhome-pl"><span><img src="/img/logo.webp" width="22" height="22" alt=""> Afrolook</span><span><img src="/img/partners/slashatlas.webp" width="22" height="22" alt=""> SlashAtlas</span><span><img src="/img/partners/pronoflash.webp" width="22" height="22" alt=""> Pronoflash</span><span><img src="/img/partners/epargneplus.webp" width="22" height="22" alt=""> Épargne+</span></div></div>
<div class="wrap adhome-pub"><div><b>${t.pub[0]}</b><span>${t.pub[1]}</span></div><a class="btn btn-primary adbig" href="/ads/diffuseur/">${t.pub[2]}</a><a class="adlinkbtn" href="/ads/diffuseur/documentation/">${t.pub[3]} ${ico('arrow', 16)}</a></div>
</section>`;
}
export const adsBar = (lang) => `<div class="adbar"><div class="wrap">${ico('gift', 18)} <b>${HOME[lang].bar}</b><a class="btn btn-primary adsm" href="${lang === 'fr' ? '/ads/' : '/en/ads/'}">${HOME[lang].barBtn}</a></div></div>`;

// ───────── page /ads/ ─────────
export const ADS_META = {
  title: 'Afrolook Ads : annonce gratuitement ton entreprise',
  desc: `Publie ton annonce gratuite avec ton compte Google : elle est diffusée sur Afrolook, SlashAtlas, Pronoflash et Épargne+, auprès de ${AUDIENCE} personnes. 3 annonces gratuites, 14 jours chacune.`,
};
export const PUB_META = { title: 'Espace diffuseur | Afrolook Ads', desc: 'Crée ton profil de diffuseur et ajoute tes sites et applications pour afficher les annonces Afrolook Ads.' };
const PARTNERS = [{ n: 'Afrolook', img: '/img/logo.webp' }, { n: 'SlashAtlas', img: '/img/partners/slashatlas.webp' }, { n: 'PronoFlash', img: '/img/partners/pronoflash.webp' }, { n: 'Épargne+', img: '/img/partners/epargneplus.webp' }];
const SECTORS = [['boutique', 'Boutique et commerce'], ['restauration', 'Restauration et alimentation'], ['mode', 'Mode et beauté'], ['services', 'Services aux particuliers et aux entreprises'], ['technologie', 'Technologie, applications, sites web'], ['immobilier', 'Immobilier et construction'], ['education', 'Éducation et formation'], ['sante', 'Santé et bien-être'], ['finance', 'Finance et assurance'], ['evenement', 'Événements, musique, spectacles'], ['medias', 'Médias et créateurs de contenu'], ['association', 'Association, ONG, institution'], ['autre', 'Autre']];
const PUB_CATS = [['actualites', 'Actualités et médias'], ['sport', 'Sport'], ['paris_sportifs', 'Pronostics et paris sportifs'], ['divertissement', 'Divertissement, musique, vidéo'], ['education', 'Éducation et formation'], ['finance', 'Finance, épargne, mobile money'], ['sante', 'Santé et bien-être'], ['boutique', 'Boutique et commerce en ligne'], ['technologie', 'Technologie et outils'], ['jeux', 'Jeux'], ['reseau_social', 'Réseau social et communauté'], ['emploi', 'Emploi et annonces'], ['religion', 'Religion et spiritualité'], ['jeunesse', 'Jeunesse et famille'], ['autre', 'Autre']];
export const ADMIN_META = { title: 'Administration de la régie | Afrolook Ads', desc: 'Annonceurs, diffuseurs, sites et applications : validation par l\'équipe Afrolook Ads.' };
export const SPACE_META = { title: 'Mon espace annonceur | Afrolook Ads', desc: 'Crée et suis tes annonces gratuites sur Afrolook, SlashAtlas, Pronoflash et Épargne+ avec ton compte Google.' };

const FAQ = [
  ['C\'est vraiment gratuit ?', 'Oui, pour les annonces affichées sur nos plateformes : pour le lancement, publier une annonce ne coûte rien, sans carte bancaire ni abonnement. La Campagne Partage (ton annonce partagée sur WhatsApp, Telegram, Facebook…) est un service payant, sans offre gratuite.'],
  ['Qu\'est-ce que la Campagne Partage ?', 'Des personnes validées par notre équipe publient ton annonce sur leur statut WhatsApp, leurs groupes, Telegram, Facebook ou TikTok. Tu choisis le nombre de personnes à atteindre et tu paies cette audience. Seuls les clics valides sont comptés : un clic par personne, sans doublon ni robot, et les fraudes sont écartées. Tu suis tes résultats dans ton espace annonceur.'],
  ['Faut-il créer un compte Afrolook Ads ?', 'Non. Ton compte Google suffit : pas de mot de passe de plus.'],
  ['Quelles annonces sont acceptées ?', 'Les entreprises, startups, sites web, applications, projets, événements et affiches. Chaque annonce est relue par notre équipe : les contenus trompeurs, illégaux ou choquants sont refusés.'],
  ['Où mon annonce est-elle diffusée ?', 'Automatiquement sur Afrolook, SlashAtlas, Pronoflash et Épargne+, dès qu\'elle est validée.'],
  ['Combien d\'annonces, et pendant combien de temps ?', 'Tu peux publier 3 annonces gratuites. Chacune reste en ligne 2 semaines (14 jours) et peut être renouvelée gratuitement une fois.'],
  ['Comment suivre mes résultats ?', 'Ton espace annonceur affiche les vues et les clics de chaque annonce, et tu reçois un e-mail à chaque palier de 100 vues.'],
];
export const adsFaqLd = { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) };

// ───────── page /en/ads/ (English) ─────────
export const ADS_META_EN = {
  title: 'Afrolook Ads: advertise your business for free',
  desc: 'Post a free ad with your Google account and reach over 50,000 people on Afrolook, SlashAtlas, Pronoflash and Épargne+. Or have people share your ad on WhatsApp, Telegram and Facebook with a Share campaign.',
};
export const adsSubnavEn = (active) => {
  const L = [['ads', '/en/ads/', 'Advertise'], ['espace', '/ads/espace/', 'Advertiser space'], ['diffuseur', '/ads/diffuseur/', 'Publisher space'], ['docs', '/ads/diffuseur/documentation/', 'Integration guide'], ['regles', '/ads/diffuseur/regles/', 'Publisher rules']];
  return `<nav class="adsnav" aria-label="Afrolook Ads"><div class="wrap">${L.map(([k, h, l]) => `<a href="${h}"${k === active ? ' aria-current="page"' : ''}>${l}</a>`).join('')}<span class="sp"></span></div></nav>`;
};
const FAQ_EN = [
  ['Is it really free?', 'Yes, for ads displayed on our platforms: during the launch, posting an ad costs nothing, with no card and no subscription. The Share campaign (your ad shared on WhatsApp, Telegram, Facebook…) is a paid service with no free offer.'],
  ['What is a Share campaign?', 'People approved by our team post your ad on their WhatsApp status, groups, Telegram, Facebook or TikTok. You choose how many people to reach and you pay for that audience. Only valid clicks are counted: one click per person, no duplicates or bots, and frauds are discarded. You follow the results in your advertiser space.'],
  ['What are Afrolook jobs and tasks?', 'On Afrolook, registered people do simple paid tasks. One of them is sharing ads: each valid click on their personal link earns them money. Their profile and audience are approved by our team before their first mission.'],
  ['Do I need an Afrolook Ads account?', 'No. Your Google account is enough: no extra password.'],
  ['Which ads are accepted?', 'Businesses, startups, websites, apps, projects, events and posters. Every ad is reviewed by our team: misleading, illegal or shocking content is refused.'],
  ['Where is my ad displayed?', 'Automatically on Afrolook, SlashAtlas, Pronoflash and Épargne+, as soon as it is approved.'],
  ['How many ads, and for how long?', 'You can post 3 free ads. Each one stays online for 2 weeks (14 days) and can be renewed once for free.'],
];
export const adsFaqLdEn = { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: FAQ_EN.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) };

export function adsLandingEn(api) {
  return `${adsSubnavEn('ads')}<section class="adfeat" id="adfeat" hidden aria-label="Ads of the moment"><div class="wrap"><b class="adfeat-t">Featured</b><div class="adfeat-row" id="adfeat-row"></div><a class="adfeat-all" href="#annonces">All ads →</a></div></section>
<section class="adh"><div class="wrap adh-grid">
 <div class="adh-l">
  <span class="adh-kick">${ico('gift', 16)} Launch offer · 100% free ads</span>
  <h1>Make <em>your business, startup, website, app or project</em> known. For free.</h1>
  <p class="lead">Post your ad in a few minutes with your Google account. It is shown automatically on <b>Afrolook</b>, <b>SlashAtlas</b>, <b>Pronoflash</b> and <b>Épargne+</b>, to an audience of <span data-aud>${AUDIENCE_EN}</span> people that grows every day.</p>
  <div class="cta"><a class="btn btn-primary adbig" href="/ads/espace/">${G} Post my free ad</a><a class="btn btn-line adbig" href="#partage">Share campaign: get your ad shared</a></div>
  <ul class="adh-pts"><li>${ico('check', 18)} 3 free ads</li><li>${ico('check', 18)} 14 days each</li><li>${ico('check', 18)} Brand profile in 2 minutes</li><li>${ico('check', 18)} Approved by our team</li></ul>
  <a class="adshare" href="#partage"><b>New: the Share campaign</b><span>People registered on Afrolook are paid to share your ad on WhatsApp, Telegram, Facebook… You pay for the audience, only valid clicks are counted.</span><i>Discover the Share campaign →</i></a>
 </div>
 <div class="adh-r"><div class="adh-glow"></div>${phone('Your ad in the Afrolook feed')}
  <div class="adh-chip c1">${ico('check', 16)} Ad approved</div><div class="adh-chip c2">${ico('eye', 16)} 2,480 views</div><div class="adh-chip c3">Free</div></div>
</div></section>

<section class="adsec soft" id="partage"><div class="wrap"><span class="kicker">Share campaign · Afrolook jobs and tasks</span><h2 class="h2">Your ad becomes a job: people are paid to share it.</h2>
<p class="sub">On Afrolook, registered people do paid tasks: sharing ads on their WhatsApp status, groups, Telegram, Facebook or TikTok. You choose the audience to reach; they are paid per valid click. It is a paid service with no free offer, because these people are paid.</p>
<div class="adp3">
 <article class="adp"><div class="adp-top"><i class="adp-logo plus">1</i><div><h3>You pay for the audience</h3><small>The number of people to reach</small></div></div><p>You choose how many people you want to reach. The price is calculated on that audience and shown before you confirm. Payment fees are added when you pay.</p></article>
 <article class="adp"><div class="adp-top"><i class="adp-logo plus">2</i><div><h3>Approved sharers</h3><small>Profile and audience checked</small></div></div><p>Each sharer describes their audience and our team approves it before their first mission. Your campaign closes as soon as the audience you chose is reached.</p></article>
 <article class="adp"><div class="adp-top"><i class="adp-logo plus">3</i><div><h3>Only valid clicks</h3><small>No duplicates, no fraud</small></div></div><p>One person = one counted click. Duplicates, self-clicks and bots are discarded; frauds are detected and never counted. You see the audience reached and your results in your space.</p></article>
</div>
<div class="cta" style="margin-top:22px"><a class="btn btn-primary adbig" href="/ads/espace/">Launch a Share campaign</a><a class="btn btn-line adbig" href="/en/earn/#jobs">See how sharers earn</a></div></div></section>

<section class="adpubbar"><div class="wrap"><div><b>Do you own a website or an app?</b><span>Become a publisher: show ads on it, see your real audience over 60 days and choose the ad categories you accept. No site? Share ads through Afrolook jobs and get paid per valid click.</span></div><a class="btn btn-primary adsm" href="/ads/diffuseur/">Become a publisher</a><a class="adlinkbtn" href="/ads/diffuseur/documentation/">Integration guide</a></div></section>

<section class="adstats"><div class="wrap"><div class="adst-row">
 ${stat(`<span data-aud>${AUDIENCE_EN}</span>`, 'people in the audience', 'across our platforms and our partners\' platforms')}
 ${stat('0 FCFA', 'to advertise', '3 free ads of 14 days each')}
 ${stat('4', 'platforms', 'one ad, shown everywhere')}
</div></div></section>

<section class="adsec"><div class="wrap"><span class="kicker">Where your ad is seen</span><h2 class="h2">One ad. Several platforms.</h2>
<p class="sub">As soon as your ad is approved, it is shown automatically, with nothing more to do on your side.</p>
<div class="adp3">
 <article class="adp"><div class="adp-top"><img src="/img/logo.webp" width="46" height="46" alt=""><div><h3>Afrolook</h3><small>The social network of African creators</small></div></div><p>Your ad appears in the feed, between creators' posts. An action button leads to your site, app or WhatsApp.</p></article>
 <article class="adp"><div class="adp-top"><img src="/img/partners/slashatlas.webp" width="46" height="46" alt=""><div><h3>SlashAtlas.com</h3><small>Posters and creations on order</small></div></div><p>An audience of creators and customers who order posters, visuals and video edits.</p></article>
 <article class="adp"><div class="adp-top"><img src="/img/partners/pronoflash.webp" width="46" height="46" alt=""><div><h3>Pronoflash</h3><small>Predictions and sports news</small></div></div><p>A passionate sports audience, very active on match days.</p></article>
 <article class="adp"><div class="adp-top"><img src="/img/partners/epargneplus.webp" width="46" height="46" alt=""><div><h3>Épargne+</h3><small>Savings in FCFA</small></div></div><p>An audience that saves and manages money from their phone, attentive to useful offers.</p></article>
</div></div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">What can you promote?</span><h2 class="h2">Anything worth being seen.</h2>
<div class="adt4">
 <article class="adt">${ico('bag', 30)}<h3>A business or a startup</h3><p>Your activity, your offer, your brand.</p></article>
 <article class="adt">${ico('globe', 30)}<h3>A website</h3><p>Shop, blog, portfolio, service: bring visitors.</p></article>
 <article class="adt">${ico('phone', 30)}<h3>An app</h3><p>Android or iPhone: a Download button takes people straight to the store.</p></article>
 <article class="adt">${ico('rocket', 30)}<h3>A project</h3><p>Association, event, fundraising: make it known.</p></article>
 <article class="adt">${ico('poster', 30)}<h3>A poster</h3><p>Concert, training, promotion: your visual, big.</p></article>
</div></div></section>

<section class="adsec"><div class="wrap"><span class="kicker">How it works</span><h2 class="h2">Four steps, a few minutes.</h2>
<div class="ads4">
 <article class="ads"><i>1</i><h3>Sign in with Google</h3><p>One click, no extra password. You enter your brand name and logo once.</p></article>
 <article class="ads"><i>2</i><h3>Create your ad</h3><p>Choose what you promote, add your image or video, your title and your button. Or pick a Share campaign.</p></article>
 <article class="ads"><i>3</i><h3>Our team approves it</h3><p>Every ad is reviewed before it goes live, to keep the platforms trustworthy.</p></article>
 <article class="ads"><i>4</i><h3>It is shown everywhere</h3><p>On Afrolook, SlashAtlas, Pronoflash and Épargne+. You follow the results in your space.</p></article>
</div>
<div class="cta" style="margin-top:34px"><a class="btn btn-primary adbig" href="/ads/espace/">${G} Start now, it is free</a></div></div></section>

<section class="adsec" id="annonces"><div class="wrap"><span class="kicker">Live ads</span><h2 class="h2">What advertisers are already posting.</h2>
<p class="sub">Every ad was approved by our team before appearing here.</p>
<div class="adg" id="adgallery" data-api="${api}/adsWebPublic"></div>
<p class="adempty" id="adempty" hidden>The first ads are coming. <a href="/ads/espace/">Be the first to advertise.</a></p>
<noscript><p class="adempty">Enable JavaScript to see the live ads.</p></noscript></div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">Frequently asked questions</span><h2 class="h2">You are wondering…</h2>
<div class="faq">${FAQ_EN.map(([q, a], i) => `<details${i === 0 ? ' open' : ''}><summary>${q}</summary><p>${a}</p></details>`).join('')}</div></div></section>

<section class="adfinal"><div class="wrap"><h2>Ready to be seen by <span data-aud>${AUDIENCE_EN}</span> people?</h2><p>Free and fast: your brand and logo, then your ad. The advertiser space is currently in French.</p>
 <div class="cta"><a class="btn btn-primary adbig" href="/ads/espace/">${G} Open the advertiser space</a></div></div></section>
<script src="/js/ads.js?v=__ASSET_V__" type="module"></script>`;
}

// ───────── page /ads/partager/ : kit de partage (liens, messages prêts, affiches) ─────────
export const KIT_META = { title: 'Kit de partage | Afrolook Ads', desc: 'Les liens, les messages et les affiches d\'Afrolook Ads à partager dans les groupes WhatsApp, Telegram et Facebook.' };
const KIT_LINKS = [
  ['Annonceurs : annonce gratuite', 'https://afrolookmedia.com/ads/', '📢 Fais connaître ton entreprise gratuitement sur Afrolook, SlashAtlas, Pronoflash et Épargne+ : une annonce, 4 plateformes, en quelques minutes avec ton compte Google.'],
  ['Annonceurs : Campagne Partage', 'https://afrolookmedia.com/ads/#partage', '💼 Tu as une activité ? Fais partager ton annonce sur WhatsApp, Telegram et Facebook par de vraies personnes : tu paies l\'audience que tu veux atteindre, seuls les clics valides sont comptés.'],
  ['Partageurs : jobs et tâches Afrolook', 'https://afrolookmedia.com/gagner/#jobs', '💰 Gagne de l\'argent en partageant des annonces avec les jobs Afrolook : environ 5 F par clic valide. Crée ton profil, partage, et retire tes gains en argent réel.'],
  ['Diffuseurs : sites et applications', 'https://afrolookmedia.com/ads/diffuseur/', '🌐 Tu as un site ou une application ? Affiche les annonces Afrolook Ads chez toi, vois ton audience réelle et choisis les catégories d\'annonces que tu acceptes.'],
  ['English : Advertise', 'https://afrolookmedia.com/en/ads/', '📢 Advertise your business for free on Afrolook, SlashAtlas, Pronoflash and Épargne+, or have people share your ad on WhatsApp, Telegram and Facebook.'],
];
const KIT_POSTERS = [
  ['Affiche : Campagne Partage (annonceurs)', '/img/ads/affiche-annonceurs.png', 'affiche-afrolook-ads-campagne-partage.png', 'https://afrolookmedia.com/ads/#partage', '💼 Fais partager ton annonce par de vraies personnes sur WhatsApp, Telegram, Facebook et TikTok. Tu paies l\'audience, seuls les clics valides sont comptés.'],
  ['Affiche : Jobs et tâches Afrolook (partageurs)', '/img/ads/affiche-jobs.png', 'affiche-afrolook-jobs.png', 'https://afrolookmedia.com/gagner/#jobs', '💰 Gagne de l\'argent en partageant des annonces : environ 5 F par clic valide, jusqu\'à 500 F par jour (montants indicatifs). Crée ton profil et commence.'],
];
const attr = (s) => String(s).replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');
const shareRow = (url, msg) => `<div class="kit-act"><button class="btn btn-primary adsm" type="button" data-copy="${attr(url)}">Copier le lien</button><button class="btn btn-line adsm" type="button" data-copy="${attr(msg + '\n' + url)}">Copier le message</button><a class="btn btn-line adsm" target="_blank" rel="noopener" data-wa="${attr(msg + '\n' + url)}" href="#">WhatsApp</a><a class="btn btn-line adsm" target="_blank" rel="noopener" data-tg-url="${attr(url)}" data-tg-text="${attr(msg)}" href="#">Telegram</a><a class="btn btn-line adsm" target="_blank" rel="noopener" data-fb="${attr(url)}" href="#">Facebook</a></div>`;
export function adsKitPage() {
  return `${adsSubnav('')}<section class="adsec"><div class="wrap"><span class="kicker">Afrolook Ads</span><h1 class="h2">Kit de partage</h1>
<p class="sub">Les liens, les messages prêts à coller et les affiches à publier dans les groupes WhatsApp, Telegram et Facebook. Les aperçus de lien affichent déjà l'affiche d'Afrolook Ads.</p>
<h2 class="h2" style="font-size:clamp(22px,2.6vw,30px);margin-top:30px">Liens à partager</h2>
<div class="kit-list">${KIT_LINKS.map(([t, u, m]) => `<article class="kit-card"><h3>${t}</h3><input class="kit-url" readonly value="${attr(u)}" aria-label="Lien"><p class="kit-msg">${m}</p>${shareRow(u, m)}</article>`).join('')}</div>
<h2 class="h2" style="font-size:clamp(22px,2.6vw,30px);margin-top:38px">Affiches</h2>
<div class="kit-posters">${KIT_POSTERS.map(([t, img, file, u, m]) => `<article class="kit-card kit-poster"><h3>${t}</h3><img src="${img}" width="1080" height="1350" alt="${attr(t)}" loading="lazy"><p class="kit-msg">${m}</p><div class="kit-act"><a class="btn btn-primary adsm" href="${img}" download="${file}">Télécharger l'affiche</a><button class="btn btn-line adsm" type="button" data-copy="${attr(m + '\n' + u)}">Copier le message</button></div></article>`).join('')}</div>
<p class="adnote">Les montants des affiches sont indicatifs. Publie l'affiche avec le message et le lien : les personnes qui cliquent arrivent directement sur la bonne page.</p></div></section>
<script>(function(){var q=function(s,r){return Array.prototype.slice.call((r||document).querySelectorAll(s))};
q('[data-wa]').forEach(function(a){a.href='https://wa.me/?text='+encodeURIComponent(a.dataset.wa)});
q('[data-tg-url]').forEach(function(a){a.href='https://t.me/share/url?url='+encodeURIComponent(a.dataset.tgUrl)+'&text='+encodeURIComponent(a.dataset.tgText)});
q('[data-fb]').forEach(function(a){a.href='https://www.facebook.com/sharer/sharer.php?u='+encodeURIComponent(a.dataset.fb)});
q('.kit-url').forEach(function(i){i.addEventListener('focus',function(){i.select()})});
q('[data-copy]').forEach(function(b){var t=b.textContent;b.addEventListener('click',function(){var v=b.dataset.copy,done=function(){b.textContent='Copié ✓';setTimeout(function(){b.textContent=t},1600)};
if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(v).then(done,function(){fb(v);done()})}else{fb(v);done()}});});
function fb(v){var e=document.createElement('textarea');e.value=v;e.style.position='fixed';e.style.opacity='0';document.body.appendChild(e);e.select();try{document.execCommand('copy')}catch(x){}document.body.removeChild(e)}})();</script>`;
}

export function adsLanding(api) {
  return `${adsSubnav('ads')}<section class="adfeat" id="adfeat" hidden aria-label="Annonces à la une"><div class="wrap"><b class="adfeat-t">À la une</b><div class="adfeat-row" id="adfeat-row"></div><a class="adfeat-all" href="#annonces">Toutes les annonces →</a></div></section>
<section class="adh"><div class="wrap adh-grid">
 <div class="adh-l">
  <span class="adh-kick">${ico('gift', 16)} Offre de lancement · annonces 100 % gratuites</span>
  <h1>Fais connaître <em>ton entreprise, ta startup, ton site, ton app, ton projet</em>. Gratuitement.</h1>
  <p class="lead">Publie ton annonce en quelques minutes avec ton compte Google. Elle est diffusée automatiquement sur <b>Afrolook</b>, <b>SlashAtlas</b>, <b>Pronoflash</b> et <b>Épargne+</b>, devant une audience de <span data-aud>${AUDIENCE}</span> personnes qui s'agrandit chaque jour.</p>
  <div class="cta"><a class="btn btn-primary adbig" href="/ads/espace/">${G} Publier mon annonce gratuite</a><a class="btn btn-line adbig" href="#partage">Campagne Partage : fais partager ton annonce</a></div>
  <ul class="adh-pts"><li>${ico('check', 18)} 3 annonces gratuites</li><li>${ico('check', 18)} 14 jours chacune</li><li>${ico('check', 18)} Profil de marque en 2 minutes</li><li>${ico('check', 18)} Validée par notre équipe</li></ul>
  <a class="adshare" href="#partage"><b>Nouveau : la Campagne Partage</b><span>Des personnes inscrites sur Afrolook sont payées pour partager ton annonce sur WhatsApp, Telegram, Facebook… Tu paies l’audience, seuls les clics valides sont comptés.</span><i>Découvrir la Campagne Partage →</i></a>
 </div>
 <div class="adh-r"><div class="adh-glow"></div>${phone('Ton annonce dans le fil Afrolook')}
  <div class="adh-chip c1">${ico('check', 16)} Annonce validée</div><div class="adh-chip c2">${ico('eye', 16)} 2 480 vues</div><div class="adh-chip c3">Gratuit</div></div>
</div></section>

<section class="adsec soft" id="partage"><div class="wrap"><span class="kicker">Campagne Partage · jobs et tâches Afrolook</span><h2 class="h2">Ton annonce devient un job : des personnes sont payées pour la partager.</h2>
<p class="sub">Sur Afrolook, des personnes inscrites font des tâches rémunérées : partager des annonces sur leur statut WhatsApp, leurs groupes, Telegram, Facebook ou TikTok. Tu choisis l'audience à atteindre ; elles sont payées au clic valide. C'est un service payant, sans offre gratuite, car ces personnes sont rémunérées.</p>
<div class="adp3">
 <article class="adp"><div class="adp-top"><i class="adp-logo plus">1</i><div><h3>Tu paies l'audience</h3><small>Le nombre de personnes à atteindre</small></div></div><p>Tu choisis combien de personnes tu veux atteindre. Le prix est calculé sur cette audience et affiché avant que tu valides. Les frais de paiement s'ajoutent au moment de payer.</p></article>
 <article class="adp"><div class="adp-top"><i class="adp-logo plus">2</i><div><h3>Des partageurs validés</h3><small>Profil et audience vérifiés</small></div></div><p>Chaque partageur présente son audience et notre équipe la valide avant sa première mission. Ta campagne se ferme dès que l'audience choisie est atteinte.</p></article>
 <article class="adp"><div class="adp-top"><i class="adp-logo plus">3</i><div><h3>Seuls les clics valides</h3><small>Sans doublon, sans fraude</small></div></div><p>Une personne = un clic compté. Les doublons, les auto-clics et les robots sont écartés, les fraudes sont détectées et jamais comptées. Tu vois l'audience touchée et tes résultats dans ton espace.</p></article>
</div>
<div class="cta" style="margin-top:22px"><a class="btn btn-primary adbig" href="/ads/espace/">Lancer une campagne Partage</a><a class="btn btn-line adbig" href="/gagner/#jobs">Voir comment les partageurs gagnent</a></div></div></section>
<section class="adpubbar"><div class="wrap"><div><b>Tu as un site ou une application ?</b><span>Deviens diffuseur : affiche les annonces chez toi, vois ton audience réelle sur 60 jours, choisis les catégories d'annonces que tu acceptes.</span></div><a class="btn btn-primary adsm" href="/ads/diffuseur/">Devenir diffuseur</a><a class="adlinkbtn" href="/ads/diffuseur/documentation/">Documentation d'intégration</a></div></section>

<section class="adstats"><div class="wrap"><div class="adst-row">
 ${stat(`<span data-aud>${AUDIENCE}</span>`, 'personnes d\'audience', 'sur nos plateformes et celles de nos partenaires')}
 ${stat('0 FCFA', 'pour annoncer', '3 annonces gratuites de 14 jours chacune')}
 ${stat('4', 'plateformes', 'une seule annonce, diffusée partout')}
</div></div></section>

<section class="adsec adwallsec"><div class="wrap"><span class="kicker">Nos partenaires</span><h2 class="h2">Ils font confiance à Afrolook Ads.</h2>
<p class="sub">Nos plateformes, et les marques qui annoncent chez nous.</p>
<div class="adwall" id="adpartners">${PARTNERS.map((p) => `<div class="adpart" title="${p.n}">${p.img ? `<img src="${p.img}" alt="${p.n}" width="56" height="56" loading="lazy">` : `<i class="adp-logo plus">${p.mark}</i>`}<span>${p.n}</span></div>`).join('')}<span id="adpartners-dyn" data-api="${api}/adsPartners" data-audience="${api}/adsAudience" style="display:contents"></span></div></div></section>

<section class="adsec"><div class="wrap"><span class="kicker">Où ton annonce est vue</span><h2 class="h2">Une annonce. Plusieurs plateformes.</h2>
<p class="sub">Dès que ton annonce est validée, elle est diffusée automatiquement, sans que tu aies rien à faire de plus.</p>
<div class="adp3">
 <article class="adp"><div class="adp-top"><img src="/img/logo.webp" width="46" height="46" alt=""><div><h3>Afrolook</h3><small>Réseau social des créateurs africains</small></div></div><p>Ton annonce apparaît dans le fil, entre les publications des créateurs. Un bouton d'action mène vers ton site ou ton application.</p><span class="adp-tag">Dans l'application et sur le web</span></article>
 <article class="adp"><div class="adp-top"><img src="/img/partners/slashatlas.webp" width="46" height="46" alt=""><div><h3>SlashAtlas.com</h3><small>Affiches et créations par commande</small></div></div><p>Une audience de créateurs et de clients qui commandent des affiches, des visuels et des montages.</p><span class="adp-tag">Sur le site et l'application mobile</span></article>
 <article class="adp"><div class="adp-top"><img src="/img/partners/pronoflash.webp" width="46" height="46" alt=""><div><h3>Pronoflash</h3><small>Pronostics et actualité sportive</small></div></div><p>Une audience passionnée de sport, très active les jours de match.</p><span class="adp-tag">Sur le site et l'application</span></article>
 <article class="adp"><div class="adp-top"><img src="/img/partners/epargneplus.webp" width="46" height="46" alt=""><div><h3>Épargne+</h3><small>Épargne en FCFA</small></div></div><p>Une audience qui épargne et gère son argent depuis son téléphone, attentive aux offres utiles.</p><span class="adp-tag">Dans l'application</span></article>
 <article class="adp more"><div class="adp-top"><i class="adp-logo plus">+</i><div><h3>D'autres plateformes</h3><small>Le réseau s'agrandit</small></div></div><p>De nouveaux partenaires rejoignent la régie : ton annonce y sera diffusée aussi, sans rien changer de ton côté.</p><span class="adp-tag">Bientôt</span></article>
</div></div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">Que peux-tu promouvoir ?</span><h2 class="h2">Tout ce qui mérite d'être vu.</h2>
<div class="adt4">
 <article class="adt">${ico('bag', 30)}<h3>Une entreprise ou une startup</h3><p>Ton activité, ton offre, ta marque : fais-toi connaître.</p></article>
 <article class="adt">${ico('globe', 30)}<h3>Un site web</h3><p>Boutique, blog, portfolio, service : amène des visiteurs.</p></article>
 <article class="adt">${ico('phone', 30)}<h3>Une application</h3><p>Android ou iPhone : un bouton « Télécharger » direct.</p></article>
 <article class="adt">${ico('rocket', 30)}<h3>Un projet</h3><p>Association, événement, financement : fais-le connaître.</p></article>
 <article class="adt">${ico('poster', 30)}<h3>Une affiche</h3><p>Concert, formation, promotion : ton visuel en grand.</p></article>
</div></div></section>

<section class="adsec"><div class="wrap"><span class="kicker">Comment ça marche</span><h2 class="h2">Quatre étapes, quelques minutes.</h2>
<div class="ads4">
 <article class="ads"><i>1</i><h3>Connecte-toi avec Google</h3><p>Un seul clic, pas de mot de passe de plus. Tu renseignes ensuite ta marque et ton logo, une seule fois.</p></article>
 <article class="ads"><i>2</i><h3>Crée ton annonce</h3><p>Choisis ce que tu promeus, ajoute ton image ou ta vidéo, ton texte et ton bouton d'action.</p></article>
 <article class="ads"><i>3</i><h3>Notre équipe la valide</h3><p>Chaque annonce est relue avant d'être publiée, pour garder une audience de confiance. Tu reçois un e-mail dès qu'elle est validée.</p></article>
 <article class="ads"><i>4</i><h3>Elle est diffusée partout</h3><p>Sur Afrolook, SlashAtlas, Pronoflash et Épargne+. Tu suis tes vues et tes clics, et tu reçois un e-mail à chaque palier de 100 vues.</p></article>
</div>
<div class="cta" style="margin-top:34px"><a class="btn btn-primary adbig" href="/ads/espace/">${G} Commencer maintenant, c'est gratuit</a></div></div></section>

${formatsSection()}

<section class="adsec" id="annonces"><div class="wrap"><span class="kicker">Annonces en ligne</span><h2 class="h2">Ce que les annonceurs publient déjà.</h2>
<p class="sub">Chaque annonce a été validée par notre équipe avant d'apparaître ici.</p>
<div class="adg" id="adgallery" data-api="${api}/adsWebPublic"></div>
<p class="adempty" id="adempty" hidden>Les premières annonces arrivent. <a href="/ads/espace/">Sois le premier à annoncer.</a></p>
<noscript><p class="adempty">Active JavaScript pour voir les annonces en ligne.</p></noscript></div></section>

<section class="adsec soft"><div class="wrap adtwo">
 <div><span class="kicker">Ton espace annonceur</span><h2 class="h2">Suis tes annonces en direct.</h2>
 <p class="sub">Vues, clics, statut de validation, jours restants : tout se gère dans ton espace, avec ton compte Google.</p>
 <ul class="adlist"><li>${ico('check', 18)} Crée, renouvelle ou arrête une annonce quand tu veux</li><li>${ico('check', 18)} Vois le nombre de vues et de clics, jour après jour</li><li>${ico('check', 18)} Reçois un e-mail à la validation, puis à chaque palier de 100 vues</li><li>${ico('check', 18)} Renouvelle gratuitement une annonce terminée</li></ul>
 <div class="cta"><a class="btn btn-primary adbig" href="/ads/espace/">${G} Ouvrir mon espace</a></div></div>
 <div class="addash"><div class="addash-h"><b>Mes annonces <small class="adcount">Aperçu</small></b><span class="btn btn-primary adsm">+ Nouvelle annonce</span></div>
  <div class="addash-r"><div><b>Kofi Studio</b><small>Visiter le site · 14 jours</small></div><span class="st ok">En ligne</span><span class="n">${ico('eye', 14)} 2 480</span><span class="n">${ico('click', 14)} 186</span></div>
  <div class="addash-r"><div><b>Festival Afro Beats</b><small>En savoir plus · 14 jours</small></div><span class="st wait">En validation</span><span class="n">—</span><span class="n">—</span></div>
  <div class="addash-r"><div><b>App Taxi Lomé</b><small>Télécharger · 14 jours</small></div><span class="st end">Terminée</span><span class="n">${ico('eye', 14)} 1 946</span><span class="n">${ico('click', 14)} 158</span></div>
 </div></div></section>

<section class="adsec"><div class="wrap adcontact">
 <div class="adcontact-l"><span class="kicker">Pour les diffuseurs : sites et applications</span><h2 class="h2">Affiche nos annonces chez toi.</h2>
 <p class="sub">Tu as un site ou une application en ligne ? Crée ton profil de diffuseur et ajoute-les : après validation par notre équipe, chacun reçoit son identifiant publicitaire. Une question ? Écris-nous.</p></div>
 <div class="adcontact-r"><a class="btn btn-primary adbig" href="/ads/diffuseur/">Devenir diffuseur</a><a class="adlinkbtn" href="/ads/diffuseur/documentation/">Documentation d'intégration</a><a class="adlinkbtn" href="/contact/">${ico('mail', 18)} Nous contacter</a></div>
</div></section>

<section class="adsec soft"><div class="wrap"><span class="kicker">Questions fréquentes</span><h2 class="h2">Tu te demandes…</h2>
<div class="faq">${FAQ.map(([q, a], i) => `<details${i === 0 ? ' open' : ''}><summary>${q}</summary><p>${a}</p></details>`).join('')}</div></div></section>

<section class="adfinal"><div class="wrap"><h2>Prêt à être vu par <span data-aud>${AUDIENCE}</span> personnes ?</h2><p>Gratuit et rapide : ta marque et ton logo, puis ton annonce.</p>
 <div class="cta" style="justify-content:center"><a class="btn adbig adwhite" href="/ads/espace/">${G} Publier mon annonce gratuite</a></div></div></section>
<dialog class="addlg" id="addetail" aria-label="Détail de l'annonce"><div class="addlg-in"><button class="addlg-x" type="button" id="addetail-x" aria-label="Fermer">×</button><div id="addetail-body"></div></div></dialog>
<script src="/js/ads.js?v=__ASSET_V__" type="module"></script>`;
}

// ───────── espace annonceur (page dynamique : connexion Google, création, suivi) ─────────
export function adsSpace(fbConfig, api) {
  const types = [['entreprise', 'bag', 'Entreprise / startup'], ['site', 'globe', 'Site web'], ['app', 'phone', 'Application'], ['projet', 'rocket', 'Projet'], ['affiche', 'poster', 'Affiche']];
  const actions = [['visit', 'Visiter le site'], ['download', 'Télécharger'], ['learn_more', 'En savoir plus'], ['whatsapp', 'WhatsApp'], ['call', 'Appeler']];
  const countries = [['ALL', 'Tous les pays'], ['AFRICA', 'Toute l\'Afrique'], ['TG', 'Togo'], ['CI', 'Côte d\'Ivoire'], ['BJ', 'Bénin'], ['SN', 'Sénégal'], ['CM', 'Cameroun'], ['BF', 'Burkina Faso'], ['ML', 'Mali'], ['GN', 'Guinée'], ['GA', 'Gabon'], ['CD', 'RD Congo'], ['FR', 'France']];
  const COUNTRIES = countries.filter(([c]) => c !== 'ALL' && c !== 'AFRICA');
  return `<link rel="modulepreload" href="https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js"><link rel="modulepreload" href="https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js"><link rel="modulepreload" href="https://www.gstatic.com/firebasejs/10.14.1/firebase-storage.js"><link rel="modulepreload" href="https://www.gstatic.com/firebasejs/10.14.1/firebase-functions.js">${adsSubnav('espace')}<section class="adsp"><div class="wrap" id="adspace" data-api="${api}">
 <script type="application/json" id="fbcfg">${JSON.stringify(fbConfig)}</script>
 <div class="adsp-top"><div><span class="kicker">Afrolook Ads</span><h1 class="h2" style="margin-top:6px">Mon espace annonceur</h1></div>
  <div class="adsp-user" id="adsp-user" hidden><i class="admk-av" id="u-av">K</i><span><b id="u-name"></b><small id="u-mail"></small></span><button class="adlinkbtn" id="signout" type="button">Déconnexion</button></div></div>
 <p class="adstatus" id="adstatus" role="status" aria-live="polite" hidden></p>

 <div class="adgate" id="adgate"><div class="adgate-c">${ico('shield', 34)}<h2>Connecte-toi pour annoncer gratuitement</h2>
  <p>Ton compte Google suffit : pas de mot de passe de plus. Tu renseignes ensuite ta marque et ton logo, une seule fois. Nous n'utilisons que ton nom et ton adresse e-mail pour te prévenir quand ton annonce est validée.</p>
  <button class="btn btn-primary adbig" id="signin" type="button">${G} Continuer avec Google</button><small>Offre de lancement : 3 annonces gratuites, 14 jours chacune.</small></div></div>

 <div id="adapp" hidden>
  <div class="profban" id="profban" role="status" hidden></div>
  <div class="adtabs"><a class="on" href="#tab-creer" data-tab="creer">Créer une annonce</a><a href="#tab-mes" data-tab="mes">Mes annonces <i id="mycount">0</i></a><a href="#tab-profil" data-tab="profil">Mon profil de marque <i id="profbadge">!</i></a></div>

  <div id="tab-creer"><div class="adform-g">
   <form class="adform" id="adform" novalidate>
    <div class="adfs"><h3><i>0</i> Comment veux-tu diffuser ?</h3>
     <div class="adtype" id="f-mode"><label class="on" data-v="ads"><b>Annonce affichée</b><small>Gratuite · affichée sur Afrolook, SlashAtlas, Pronoflash et Épargne+</small></label><label data-v="share"><b>Campagne Partage</b><small>Payante · des personnes partagent ton annonce sur WhatsApp, Telegram, Facebook…</small></label></div></div>
    <div class="adfs" data-adsonly><h3><i>1</i> Que veux-tu promouvoir ?</h3>
     <div class="adtype" id="f-kind">${types.map(([k, i, l], n) => `<label class="${n === 0 ? 'on' : ''}" data-v="${k}">${ico(i, 26)}<b>${l}</b></label>`).join('')}</div></div>
    <div class="adfs"><h3><i>2</i> Ton annonce</h3>
     <label class="fl" for="f-title">Titre <small>(60 caractères)</small><input id="f-title" maxlength="60" autocomplete="off" placeholder="Nom de ton entreprise, de ton site, de ton projet…"></label>
     <label class="fl" for="f-text">Texte <small>(220 caractères)</small><textarea id="f-text" rows="3" maxlength="220" placeholder="Explique en une ou deux phrases ce que tu proposes."></textarea></label>
     <p class="adnote" style="margin-top:-4px">Où s’affichent ton titre et ton texte : dans les annonces de type carte ou native, sur nos plateformes, et — pour une <b>Campagne Partage</b> — dans le message que les partageurs publient avec ton lien (WhatsApp, Telegram, Facebook…) et dans l’aperçu du lien. Les <b>bannières prêtes</b> (320×50, 300×250…) n’affichent que ton image.</p>
     <label class="fl" for="f-cat">Catégorie de l'annonce <small>(obligatoire)</small><select id="f-cat"><option value="">Choisir…</option>${catOptions()}</select></label>
     <p class="adnote" id="f-cat-note" hidden>Catégorie sensible : ton annonce n'est diffusée que chez les diffuseurs qui l'acceptent explicitement, et jamais dans la galerie publique. Le contenu sexuellement explicite est interdit.</p>
     <div class="fl"><span>Image ou vidéo</span>
      <label class="adup" for="f-file"><div class="adup-i">${ico('poster', 30)}</div><div><b id="f-file-name">Choisis une image ou une vidéo</b><small>Images JPG ou PNG (jusqu'à 5), ou une vidéo MP4 de <b>15 secondes maximum</b> (25 Mo)</small></div></label>
      <div class="imgtips" data-adsonly><b>Image idéale : carrée, 1080 × 1080 px</b><small>Sujet et texte au centre, gros et lisibles. Ton image s'affiche toujours entière : dans une petite bannière (carré), un rectangle (paysage) ou une carte (portrait), le reste se remplit d'un fond flouté. Évite les images très allongées et le texte minuscule.</small><b id="f-file-tip" class="imgtip" hidden></b>
      <div class="imgex" aria-hidden="true">
        <figure><div class="ex ex-ok"><b>-30 %</b><span>Boutique Kofi</span><u>Commande</u></div><figcaption><i class="y">✓</i> Bon : carré, texte gros au centre</figcaption></figure>
        <figure><div class="ex ex-no"><span>texte minuscule illisible sur le côté</span></div><figcaption><i class="n">✗</i> À éviter : très allongé, texte minuscule</figcaption></figure>
      </div>
      </div>
      <div class="imgtips" data-shareonly hidden><b>Ton image est publiée telle quelle sur WhatsApp, Telegram, Facebook…</b><small>Choisis un visuel <b>carré (1080 × 1080)</b> ou <b>vertical (1080 × 1920)</b> comme un statut : un texte court et gros, un appel clair (« Commande ton affiche »), des couleurs vives. Une vidéo de 15 secondes maximum marche très bien aussi.</small>
       <div class="imgex" aria-hidden="true"><figure><div class="ex ex-ok"><b>-30 %</b><span>Boutique Kofi</span><u>Commande</u></div><figcaption><i class="y">✓</i> Carré</figcaption></figure><figure><div class="ex ex-v"><b>-30 %</b><span>Boutique Kofi</span><u>Commande</u></div><figcaption><i class="y">✓</i> Vertical, comme un statut</figcaption></figure><figure><div class="ex ex-no"><span>texte minuscule illisible</span></div><figcaption><i class="n">✗</i> À éviter</figcaption></figure></div></div>
      <details class="bnbox" data-adsonly><summary><b>Bannières prêtes à l'emploi</b> (facultatif) : comme sur Google AdMob</summary>
       <p>Si tu as déjà dessiné tes bannières, dépose-les : elles s'affichent <b>en entier, cliquables, sans texte ajouté</b>, sur les emplacements de la même taille (haut et bas des pages, bas des applications). JPG, PNG ou WebP, 500 Ko au plus, à la taille exacte ou au double pour les écrans nets (ex. 1456 × 180). Sans bannière à la bonne taille, ton image et ton texte sont mis en page automatiquement.</p>
       <div class="bnrow"><label for="bn-b728x90"><b>Leaderboard</b> <i>728 × 90</i><small>haut ou bas des pages sur ordinateur</small></label><input id="bn-b728x90" data-k="b728x90" type="file" accept="image/jpeg,image/png,image/webp"><span class="bt" id="bt-b728x90"></span></div><div class="bnrow"><label for="bn-b320x100"><b>Grande bannière</b> <i>320 × 100</i><small>téléphone, dans les pages</small></label><input id="bn-b320x100" data-k="b320x100" type="file" accept="image/jpeg,image/png,image/webp"><span class="bt" id="bt-b320x100"></span></div><div class="bnrow"><label for="bn-b320x50"><b>Mini bannière</b> <i>320 × 50</i><small>bas des applications</small></label><input id="bn-b320x50" data-k="b320x50" type="file" accept="image/jpeg,image/png,image/webp"><span class="bt" id="bt-b320x50"></span></div><div class="bnrow"><label for="bn-b300x250"><b>Rectangle moyen</b> <i>300 × 250</i><small>dans le contenu</small></label><input id="bn-b300x250" data-k="b300x250" type="file" accept="image/jpeg,image/png,image/webp"><span class="bt" id="bt-b300x250"></span></div>
      </details>
      <input id="f-file" type="file" accept="image/jpeg,image/png,image/webp,video/mp4,video/quicktime" multiple hidden></div></div>
    <div class="adfs"><h3><i>3</i> Bouton d'action</h3>
     <div class="adbtn" id="f-action">${actions.map(([k, l], n) => `<label class="${n === 0 ? 'on' : ''}" data-v="${k}">${l}</label>`).join('')}</div>
     <label class="fl" for="f-link" id="f-link-l">Lien du bouton<input id="f-link" inputmode="url" autocomplete="off" placeholder="https://tonsite.com"></label></div>
    <div class="adfs"><h3><i>4</i> Durée et audience</h3>
     <div data-adsonly><div class="adbtn"><label class="on">14 jours · offre gratuite</label></div><p class="adnote">Ton annonce reste en ligne 2 semaines. Tu peux la renouveler gratuitement une fois.</p></div>
     <div class="adchips" id="f-countries">${countries.map(([c, l], n) => `<span class="${n === 0 ? 'on' : ''}" data-v="${c}">${l}</span>`).join('')}</div>
     <div class="fl" data-adsonly><span>Langues <small>(facultatif : toutes si rien n'est choisi)</small></span><div class="adchips" id="f-langs"><span data-v="fr">Français</span><span data-v="en">Anglais</span><span data-v="pt">Portugais</span></div></div>
     <div class="fl" data-adsonly><span>Appareils <small>(facultatif)</small></span><div class="adchips" id="f-devs"><span data-v="mobile">Téléphone</span><span data-v="desktop">Ordinateur</span></div></div>
     <details class="adfold" data-adsonly><summary>Types de sites et d'applications <small>(facultatif)</small></summary><div class="adchips" id="f-types">${PUB_CATS.map(([k, l]) => `<span data-v="${k}">${l}</span>`).join('')}</div></details>
     <p class="adnote" data-adsonly>C'est toi qui définis à qui s'adresse ton annonce, et nous le respectons : au plus <b>40 %</b> des vues peuvent venir d'autres pays que ceux choisis. Le pays du visiteur est déterminé par nos serveurs, jamais par le site qui affiche l'annonce.</p></div>
    <div class="adfs" id="f-share" hidden><h3><i>5</i> Audience à atteindre <small>(service payant)</small></h3>
     <p class="adnote">Il n'y a <b>pas d'offre gratuite</b> pour ce service : des personnes sont payées pour partager ton annonce. <b>Tu paies l'audience</b>, c'est-à-dire le nombre de personnes à atteindre. Les partageurs sont validés par notre équipe et leur audience est vérifiée ; ta campagne s'arrête quand l'audience choisie est atteinte : <b>tu ne dépasses jamais ton budget</b>. Seuls les clics valides sont comptés, sans doublon, et tu les vois uniquement dans ton espace.</p>
     <label class="fl" id="f-sbrand-l" for="f-sbrand" hidden>Marque affichée <small>(équipe : ex. SlashAtlas)</small><input id="f-sbrand" maxlength="60" autocomplete="off" placeholder="SlashAtlas"></label>
     <label class="fl" for="f-aud">Nombre de personnes à atteindre<input id="f-aud" type="number" min="1000" max="5000000" step="1000" value="10000"></label>
     <div class="sharebox"><b id="f-aud-price">—</b><small id="f-aud-note"></small></div></div>
    <p class="aderr" id="aderr" role="alert" hidden></p>
    <div class="adsub"><div><b id="f-sub-t">Gratuit</b><small id="f-quota">Validation par notre équipe avant diffusion</small></div><button class="btn btn-primary adbig" id="f-send" type="submit">Envoyer pour validation</button></div>
   </form>
   <aside class="adprev"><span class="kicker">Aperçu en direct</span>${phone('Tel que ton annonce apparaîtra')}
    <div class="adprev-n" data-adsonly>${ico('shield', 18)}<span>Ton annonce sera diffusée sur <b>Afrolook</b>, <b>SlashAtlas</b>, <b>Pronoflash</b> et <b>Épargne+</b> après validation.</span></div>
    <div class="adprev-n" data-shareonly hidden>${ico('shield', 18)}<span>Ton annonce sera partagée par des personnes <b>validées par notre équipe</b> sur WhatsApp, Telegram, Facebook… Seuls les clics valides sont comptés.</span></div></aside>
  </div></div>

  <div id="tab-profil" hidden><form class="adform adprof" id="adprof" novalidate>
   <div class="adfs"><h3><i>1</i> Ta marque et ton logo</h3>
    <div class="logo-up"><label class="logo-box" for="f-logo" id="logo-pv"><span>Logo</span></label>
     <div class="logo-t"><b>Le logo de ta marque</b><small>PNG, JPG ou WebP, fond transparent conseillé. Il est affiché comme partenaire une fois ton profil validé par notre équipe.</small>
      <div class="logo-r"><label class="btn btn-line adsm" for="f-logo">Choisir un logo</label><span class="st wait" id="logo-st" hidden></span></div><p class="aderr" id="logo-why" hidden></p></div>
     <input id="f-logo" type="file" accept="image/png,image/jpeg,image/webp" hidden></div>
    <label class="fl" for="f-brand">Nom de la marque<input id="f-brand" maxlength="60" autocomplete="organization" placeholder="Ex. Kofi Studio"></label>
    <label class="fl" for="f-sector">Secteur d'activité <small>(facultatif)</small><select id="f-sector"><option value="">Choisir…</option>${SECTORS.map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}</select></label></div>
   <div class="adfs"><h3><i>2</i> Où et comment te joindre</h3>
    <label class="fl" for="f-pcountry">Pays<select id="f-pcountry">${COUNTRIES.map(([c, l]) => `<option value="${c}">${l}</option>`).join('')}</select></label>
    <label class="fl" for="f-city">Ville <small>(facultatif)</small><input id="f-city" maxlength="60" autocomplete="address-level2" placeholder="Ex. Lomé"></label>
    <label class="fl" for="f-site">Site web <small>(facultatif)</small><input id="f-site" inputmode="url" placeholder="https://tonsite.com"></label>
    <label class="fl" for="f-wa">WhatsApp pour te contacter <small>(avec l'indicatif)</small><input id="f-wa" inputmode="tel" placeholder="+228 90 00 00 00"></label>
    <label class="fl" for="f-about">Ce que fait ta marque <small>(20 à 200 caractères)</small><textarea id="f-about" rows="3" maxlength="200" placeholder="Ex. Boutique de vêtements africains modernes, livraison à Lomé et Cotonou."></textarea></label></div>
   <label class="adcheck"><input type="checkbox" id="f-consent"><span>J'accepte que le nom et le logo de ma marque soient affichés comme partenaire sur Afrolook Ads, après validation de mon profil par l'équipe.</span></label>
   <p class="aderr" id="perr" role="alert" hidden></p>
   <div class="adsub"><div><b>Profil de marque</b><small>Obligatoire avant ta première annonce.</small></div><button class="btn btn-primary adbig" id="p-send" type="submit">Enregistrer mon profil</button></div>
  </form></div>

  <div id="tab-mes" hidden><div class="admine"><h2 class="h2" style="font-size:clamp(24px,3vw,34px)">Mes annonces <small class="adcount" id="myquota"></small></h2>
   <div class="addash" id="mylist" style="margin-top:18px"><p class="adempty">Chargement…</p></div></div>
   <div class="admine" id="sharemine" hidden><h2 class="h2" style="font-size:clamp(22px,2.6vw,30px);margin-top:28px">Mes campagnes Partage</h2>
    <div class="addash" id="sharelist" style="margin-top:14px"></div></div></div>
 </div>
</div></section>
<dialog class="addlg" id="addetail" aria-label="Détail de l'annonce"><div class="addlg-in"><button class="addlg-x" type="button" id="addetail-x" aria-label="Fermer">×</button><div id="addetail-body"></div></div></dialog>
<script src="/js/ads.js?v=__ASSET_V__" type="module"></script>`;
}

// ───────── espace diffuseur (page dynamique : connexion Google, profil, sites et applications) ─────────
export function adsPublisherSpace(fbConfig, api) {
  const countries = [['TG', 'Togo'], ['CI', 'Côte d\'Ivoire'], ['BJ', 'Bénin'], ['SN', 'Sénégal'], ['CM', 'Cameroun'], ['BF', 'Burkina Faso'], ['ML', 'Mali'], ['GN', 'Guinée'], ['GA', 'Gabon'], ['CD', 'RD Congo'], ['NE', 'Niger'], ['FR', 'France']];
  return `${adsSubnav('diffuseur')}<section class="adsp"><div class="wrap" id="pubspace" data-api="${api}" data-rules="${RULES.version}">
 <script type="application/json" id="fbcfg">${JSON.stringify(fbConfig)}</script>
 <div class="adsp-top"><div><span class="kicker">Afrolook Ads</span><h1 class="h2" style="margin-top:6px">Mon espace diffuseur</h1></div>
  <div class="adsp-user" id="adsp-user" hidden><i class="admk-av" id="u-av">K</i><span><b id="u-name"></b><small id="u-mail"></small></span><button class="adlinkbtn" id="signout" type="button">Déconnexion</button></div></div>
 <p class="adstatus" id="adstatus" role="status" aria-live="polite" hidden></p>

 <div class="adways" id="adways"><article class="adway on"><span class="adway-t">Nouveau · sans site ni application</span><h2>Partage des annonces avec les jobs Afrolook</h2><p>Tu as une audience sur WhatsApp, Telegram, Facebook ou TikTok ? Fais les tâches de partage : tu publies une annonce avec ton lien personnel et tu es payé pour chaque clic valide. Ton profil de partageur est validé par notre équipe avant ta première mission.</p><a class="btn btn-primary" href="/gagner/#jobs">Voir comment ça marche</a></article>
  <article class="adway"><span class="adway-t">Tu as un site ou une application</span><h2>Affiche les annonces chez toi</h2><p>Ajoute ton site ou ton application : après validation, tu reçois ton identifiant publicitaire et les annonces s'affichent chez toi.</p><a class="adlinkbtn" href="#adgate">Créer mon profil de diffuseur</a></article></div>
 <div class="adgate" id="adgate"><div class="adgate-c">${ico('globe', 34)}<h2>Affiche les annonces Afrolook Ads chez toi</h2>
  <p>Tu as un site ou une application en ligne ? Connecte-toi avec Google, crée ton profil de diffuseur, puis ajoute chaque site ou application : après validation par notre équipe, chacun reçoit son <b>identifiant publicitaire</b>.</p>
  <button class="btn btn-primary adbig" id="signin" type="button">${G} Continuer avec Google</button><small>Quand l'offre Réseau sera ouverte, tu recevras 65 % du budget des annonces affichées chez toi.</small><p class="adnote"><a href="/ads/diffuseur/documentation/">Documentation d'intégration</a> · <a href="/ads/diffuseur/regles/">Règles des diffuseurs</a></p></div></div>

 <div id="adapp" hidden>
  <div class="pubaud"><div><small>Audience du réseau Afrolook Ads</small><b id="aud-total">plus de 50 000</b></div><p>Elle augmente à chaque site ou application validé : <b>50 000</b> sur nos plateformes <b>+ l'audience retenue de chaque diffuseur</b>.</p></div>
  <div class="profban" id="profban" role="status" hidden></div>
  <div class="adtabs"><a class="on" href="#tab-profil" data-tab="profil">Mon profil <i id="pbadge">!</i></a><a href="#tab-sites" data-tab="sites">Mes sites et applications <i id="pcount">0</i></a></div>

  <div id="tab-profil"><div class="adform-g">
   <form class="adform" id="pform" novalidate>
    <div class="adfs"><h3><i>1</i> Toi ou ton entreprise</h3>
     <div class="adbtn" id="p-type"><label class="on" data-v="individual">Particulier</label><label data-v="company">Entreprise</label></div>
     <label class="fl" for="p-name">Nom ou nom de l'entreprise<input id="p-name" maxlength="80" autocomplete="organization"></label>
     <label class="fl" for="p-country">Pays<select id="p-country">${countries.map(([c, l]) => `<option value="${c}">${l}</option>`).join('')}</select></label>
     <label class="fl" for="p-city">Ville<input id="p-city" maxlength="60" autocomplete="address-level2"></label></div>
    <div class="adfs"><h3><i>2</i> Contact</h3>
     <label class="fl" for="p-phone">WhatsApp, avec l'indicatif<input id="p-phone" inputmode="tel" placeholder="+228 90 00 00 00"></label>
     <label class="fl" for="p-web">Site web <small>(facultatif)</small><input id="p-web" inputmode="url" placeholder="https://tonsite.com"></label>
     <label class="fl" for="p-about">Que fais-tu ? <small>(300 caractères)</small><textarea id="p-about" rows="3" maxlength="300" placeholder="Présente ton activité, tes sites ou tes applications."></textarea></label></div>
    <div class="warn" id="p-rules-new" hidden><b>Les règles ont changé.</b> Lis-les puis accepte-les pour pouvoir ajouter un site ou une application. <button class="btn btn-primary adsm" id="p-rules-accept" type="button">J'accepte la nouvelle version</button></div>
    <details class="adrules" id="p-rules"><summary>Lire les règles des diffuseurs <small>version ${RULES.version}</small></summary><div class="rules">${rulesHtml()}</div></details>
    <label class="adcheck"><input type="checkbox" id="p-terms"><span>J'ai lu et j'accepte les <a href="/ads/diffuseur/regles/" target="_blank" rel="noopener">règles des diffuseurs</a> (version ${RULES.version}) : audience mesurée par Afrolook Ads et comparée à ma déclaration, annonces validées, catégories que j'accepte, aucun clic sur mes propres annonces, aucun trafic acheté ou automatique, rémunération selon l'offre Réseau.</span></label>
    <p class="aderr" id="perr" role="alert" hidden></p>
    <div class="adsub"><div><b id="p-state">Profil à valider</b><small>Notre équipe valide chaque profil avant de traiter tes sites et applications.</small></div><button class="btn btn-primary adbig" id="p-send" type="submit">Envoyer mon profil</button></div>
   </form>
   <aside class="adprev"><span class="kicker">Comment ça marche</span><ol class="adsteps"><li><b>Ton profil</b> est validé par notre équipe.</li><li>Tu <b>ajoutes tes sites et applications</b> (en ligne obligatoirement).</li><li>Chacun est <b>accepté ou refusé</b> séparément.</li><li>Il reçoit son <b>identifiant publicitaire</b> (ap_…).</li><li>Tu intègres la balise ou le composant fourni, et tu suis tes statistiques ici.</li></ol><p class="adnote"><a href="/ads/diffuseur/documentation/">Documentation d'intégration</a> · <a href="/ads/diffuseur/regles/">Règles des diffuseurs</a></p></aside>
  </div></div>

  <div id="tab-sites" hidden><div class="adform-g">
   <div><h2 class="h2" style="font-size:clamp(22px,3vw,30px)">Mes sites et applications</h2><div class="pubprops" id="plist" style="margin-top:16px"><p class="adempty">Chargement…</p></div></div>
   <form class="adform" id="propform" novalidate>
    <div class="adfs"><h3>Ajouter un site ou une application</h3>
     <div class="adbtn" id="q-kind"><label class="on" data-v="site">Site web</label><label data-v="app">Application</label></div>
     <label class="fl" for="q-name">Nom<input id="q-name" maxlength="80" placeholder="Ex. Kofi Sport"></label>
     <label class="fl" for="q-url" id="q-site">Adresse du site <small>(https, en ligne)</small><input id="q-url" inputmode="url" placeholder="https://tonsite.com"></label>
     <div id="q-app" hidden><label class="fl" for="q-and">Lien Google Play <small>(si Android)</small><input id="q-and" inputmode="url" placeholder="https://play.google.com/store/apps/details?id=…"></label>
      <label class="fl" for="q-ios">Lien App Store <small>(si iPhone)</small><input id="q-ios" inputmode="url" placeholder="https://apps.apple.com/…/id123456789"></label></div>
     <label class="fl" for="q-cat">Type de ton site ou de ton application<select id="q-cat">${PUB_CATS.map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}</select></label>
     <div class="fl"><span>Catégories d'annonces que tu acceptes d'afficher</span><div class="cats" id="q-cats">${catChecks('qcat')}</div><small>Seules ces catégories s'afficheront chez toi. Les catégories sensibles (finance, paris, alcool, médicaments, rencontres, contenu sensuel, politique, religion…) ne s'affichent jamais sans ton accord : coche-les seulement si tu les acceptes. Tu peux changer ce choix à tout moment.</small></div>
     <div class="fl"><span>Pays de ton audience</span><div class="adchips" id="q-countries">${countries.map(([c, l], n) => `<span class="${n === 0 ? 'on' : ''}" data-v="${c}">${l}</span>`).join('')}</div></div>
     <label class="fl" for="q-aud">Audience : personnes différentes par mois<input id="q-aud" type="number" min="100" step="100" inputmode="numeric" placeholder="Ex. 25000"></label>
     <label class="fl" for="q-ses">Pages vues ou sessions par mois <small>(facultatif)</small><input id="q-ses" type="number" min="0" step="100" inputmode="numeric"></label>
     <label class="fl" for="q-desc">Décris ton site ou ton application <small>(400 caractères)</small><textarea id="q-desc" rows="3" maxlength="400"></textarea></label></div>
    <p class="adnote">Ton site ou ton application doit être <b>en ligne</b> : nous vérifions l'adresse. L'audience que tu déclares est contrôlée ; notre équipe retient le chiffre validé.</p>
    <p class="aderr" id="qerr" role="alert" hidden></p>
    <button class="btn btn-primary adbig" id="q-send" type="submit">Envoyer la demande</button>
   </form>
  </div></div>
 </div>
</div></section>
<script src="/js/ads.js?v=__ASSET_V__" type="module"></script>`;
}

// ───────── administration de la régie (page réservée aux administrateurs, non indexée) ─────────
export function adsAdminSpace(fbConfig, api) {
  return `${adsSubnav('admin')}<section class="adsp"><div class="wrap" id="regieadmin" data-api="${api}">
 <script type="application/json" id="fbcfg">${JSON.stringify(fbConfig)}</script>
 <div class="adsp-top"><div><span class="kicker">Afrolook Ads</span><h1 class="h2" style="margin-top:6px">Administration de la régie</h1></div>
  <div class="adsp-user" id="adsp-user" hidden><i class="admk-av" id="u-av">A</i><span><b id="u-name"></b><small id="u-mail"></small></span><button class="adlinkbtn" id="signout" type="button">Déconnexion</button></div></div>
 <p class="adstatus" id="adstatus" role="status" aria-live="polite" hidden></p>
 <div class="adgate" id="adgate"><div class="adgate-c">${ico('shield', 34)}<h2>Réservé à l'équipe Afrolook Ads</h2>
  <p>Connecte-toi avec ton compte Google administrateur. Tu pourras voir tous les annonceurs, tous les diffuseurs et leurs sites ou applications, et les valider ou les refuser.</p>
  <button class="btn btn-primary adbig" id="signin" type="button">${G} Continuer avec Google</button></div></div>
 <div id="adapp" hidden>
  <div class="adtabs" id="rg-tabs"></div>
  <div class="rg-filters" id="rg-filters"></div>
  <div class="rg-list" id="rg-list"></div>
 </div>
</div></section>
<script src="/js/ads.js?v=__ASSET_V__" type="module"></script>`;
}
