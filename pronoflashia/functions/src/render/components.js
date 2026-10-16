'use strict';
// Briques HTML réutilisables. Tout est du texte rendu côté serveur : les pages sont lisibles sans JavaScript.

const { esc, dateCourte, dateLongue, heure, fr } = require('../util/format');
const { slotOn } = require('./config');

const STORE_ANDROID = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok';
const STORE_IOS = 'https://apps.apple.com/gh/app/afrolook/id6811423047';

/** Messages Afrolook adaptés au football (le client les fait tourner). */
const AFL_MSGS = [
  'Débats foot sur Afrolook : donne ton avis sur le match',
  'Partage tes pronos entre amis sur Afrolook',
  'Tes likes deviennent des pièces sur Afrolook',
  'Tu postes des vidéos ? Afrolook te paie tes vues',
  'Afrolook : le réseau africain des créateurs',
];
const AFL_PHOTOS = ['/img/afl1.jpg', '/img/afl4.jpg'];

const url = (rc, path) => `${rc.site.origine}${path}`;
const matchPath = (m) => `/football/${m.leagueSlug}/${m.slug}`;

function crest(team, big) {
  const c = team.couleurs || ['#1b3a8a', '#0a1f4d'];
  return `<span class="cr${big ? ' lgx' : ''}" style="background:linear-gradient(135deg,${esc(c[0])},${esc(c[1])})" aria-hidden="true">${esc(team.initiales || '?')}</span>`;
}

/** Heure en UTC côté serveur ; le navigateur la convertit dans le fuseau du visiteur. */
const timeEl = (iso) => `<time datetime="${esc(iso)}" data-t="hm" title="Heure UTC">${heure(iso)}</time>`;

function formBadges(f) {
  return f ? `<span class="fm" aria-label="Forme récente">${f.split('').map((c) => `<i class="${c}">${c}</i>`).join('')}</span>` : '';
}

/** Carte de match : pronostic principal visible tout de suite, sans clic. */
function matchCard(m) {
  const p = m.prono;
  const href = matchPath(m);
  const head = `<div class="hd"><span><b class="num">${timeEl(m.coupDEnvoi)}</b>${esc(m.leagueNom)}</span><span>${esc(dateCourte(m.coupDEnvoi))}</span></div>`;
  const teams = `<div class="tm"><div class="tr">${crest(m.domicile)}${esc(m.domicile.nomCourt)}${formBadges(p && p.formeDom)}</div><div class="tr">${crest(m.exterieur)}${esc(m.exterieur.nomCourt)}${formBadges(p && p.formeExt)}</div></div>`;
  if (m.statut === 'termine' && m.resultat) {
    const r = m.resultat;
    const mark = r.reussi === true ? '<span class="badge-ok">✅</span>' : r.reussi === false ? '<span class="badge-ko">❌</span>' : '';
    return `<a class="mc" href="${href}">${head}${teams}<div class="pr"><div><span class="pk1">Score final</span><b>${r.scoreDom} - ${r.scoreExt}</b></div><div class="res">${mark}</div></div>${p ? `<div class="sc"><span>Notre pronostic : ${esc(p.principal.libelle)}</span></div>` : ''}</a>`;
  }
  if (!p || p.visible === false) return `<a class="mc" href="${href}">${head}${teams}<div class="pr"><div><span class="pk1">Pronostic</span><b>En préparation</b></div></div></a>`;
  const pr = p.probas;
  const low = p.principal.basseConfiance ? ' low' : '';
  return `<a class="mc" href="${href}">${head}${teams}<div class="pr"><div><span class="pk1">Pronostic</span><b>${esc(p.principal.libelle)}</b></div><div class="cf num${low}">${p.principal.confiance} %<small>confiance</small></div></div>` +
    `<div class="bars" role="img" aria-label="Probabilités 1 N 2"><i style="flex:${pr['1']};background:var(--flash)"></i><i style="flex:${pr.N};background:#6b7899"></i><i style="flex:${pr['2']};background:var(--cy)"></i></div>` +
    `<div class="bl num"><span>1 · ${pr['1']} %</span><span>N · ${pr.N} %</span><span>2 · ${pr['2']} %</span></div>` +
    `<div class="sc">${(p.secondaires || []).map((s) => `<span>${esc(s.libelle)} · ${s.pct} %</span>`).join('')}</div></a>`;
}

/**
 * Emplacement publicitaire (espace réservé, rempli par le navigateur). Rien n'est rendu si l'admin ne l'a pas activé.
 * variant : 'dk' (ordinateur seulement), 'mo' (téléphone seulement) ou '' (partout).
 */
function adSlot(rc, id, { variant = '', cls = '', label = id } = {}) {
  if (!slotOn(rc.ads, id)) return '';
  const e = rc.ads.emplacements[id];
  const dim = (variant === 'dk' ? e.dk : variant === 'mo' ? e.mo : e.dk || e.mo) || [300, 250];
  return `<div class="ad ${cls} ${variant}" data-ad="${esc(id)}" data-v="${variant || 'all'}" data-w="${dim[0]}" data-h="${dim[1]}" style="min-height:${dim[1]}px" aria-label="Publicité"></div>`;
}

/** Bannière responsive : deux variantes (ordinateur / téléphone), une seule est visible donc une seule se charge. */
const adResponsive = (rc, id, cls) => adSlot(rc, id, { variant: 'dk', cls }) + adSlot(rc, id, { variant: 'mo', cls });

/** Encart Afrolook (maison). Le navigateur choisit le lien magasin selon l'appareil et fait tourner le message. */
function aflCard(rc, slot, i = 0) {
  if (!rc.ads.afrolook || !rc.ads.afrolook.actif) return '';
  const msg = AFL_MSGS[i % AFL_MSGS.length];
  const photo = AFL_PHOTOS[i % AFL_PHOTOS.length];
  const utm = `utm_source=pronoflashia&utm_campaign=${encodeURIComponent(slot)}`;
  return `<a class="afl" href="${esc(`${STORE_ANDROID}&${utm}`)}" target="_blank" rel="noopener sponsored" data-afl="${esc(slot)}" data-i="${i}"><span class="sp2">Sponsorisé</span><div class="im" style="background-image:url(${photo})"></div><div class="bd"><span class="bg"><img src="/img/afrolook.png" alt="" width="12" height="12" loading="lazy">AFROLOOK</span><p>${esc(msg)}</p><span class="cta">Télécharger gratuitement</span></div></a>`;
}

/** Insère les publicités dans une liste de cartes : native toutes les N cartes, Afrolook toutes les M. */
function listWithAds(rc, cards) {
  const nat = rc.ads.emplacements.native || {};
  const afl = rc.ads.afrolook || {};
  const out = [];
  let a = 0;
  cards.forEach((c, i) => {
    out.push(c);
    const n = i + 1;
    if (slotOn(rc.ads, 'native') && nat.every && n % nat.every === 0 && n < cards.length) out.push(adSlot(rc, 'native', { cls: 'ad-nat', variant: '' }));
    if (afl.actif && afl.every && n % afl.every === 0 && n < cards.length) out.push(aflCard(rc, 'liste', a++));
  });
  return out.join('');
}

function header(rc, active) {
  const a = (k) => (active === k ? ' aria-current="page"' : '');
  return `<header class="hdr"><div class="wrap"><a class="logo" href="/" aria-label="PronoFlash IA, accueil"><span class="bolt" aria-hidden="true">⚡</span><span>Prono<em>Flash</em><small>IA</small></span></a>` +
    `<nav class="nav" aria-label="Navigation principale"><a href="/football/aujourdhui"${a('football')}>Football</a><a href="/coupon"${a('coupon')}>Coupon</a><a href="/bilan"${a('bilan')}>Bilan</a><a href="/a-propos"${a('apropos')}>À propos</a></nav>` +
    `<span class="sp"></span><a class="cpn" id="pf-cpn" href="/coupon" hidden>Mon coupon</a><a class="lang" href="/" aria-label="Français"><b>FR</b> · EN</a></div></header>`;
}

function sportTabs(rc, day) {
  return `<div class="rail" role="navigation" aria-label="Sports"><a class="sport" href="/football/aujourdhui" aria-current="page">⚽ Football</a><span class="sport off">🏀 Basketball <i>bientôt</i></span><span class="sport off">🎾 Tennis <i>bientôt</i></span></div>`;
}

/** Jours : aujourd'hui, demain, puis les 4 suivants. */
function dayRail(rc, activeDay) {
  const items = [['aujourdhui', "Aujourd'hui", rc.today], ['demain', 'Demain', rc.tomorrow]];
  for (let i = 2; i <= 5; i++) {
    const d = new Date(rc.now.getTime() + i * 864e5).toISOString().slice(0, 10);
    items.push([d, dateCourte(d + 'T12:00:00Z').replace(/\.$/, ''), d]);
  }
  return `<div class="rail" role="navigation" aria-label="Jours">${items.map(([slug, label, d]) => `<a class="chip" href="/football/${slug}"${activeDay === d ? ' aria-current="true"' : ''}>${esc(label)}</a>`).join('')}</div>`;
}

function leagueRail(rc, activeSlug) {
  return `<div class="rail" role="navigation" aria-label="Championnats"><a class="lg" href="/football/aujourdhui"${!activeSlug ? ' aria-current="true"' : ''}>Tous</a>${rc.leagues.map((l) => `<a class="lg" href="/football/${esc(l.slug)}"${activeSlug === l.slug ? ' aria-current="true"' : ''}>${esc(l.nom)}</a>`).join('')}</div><p class="tznote">Heures affichées dans ton fuseau horaire (UTC par défaut).</p>`;
}

function footer(rc) {
  return `<footer class="ftr"><div class="wrap" style="display:grid;gap:10px"><div class="r18"><b>18+</b>Jouez de façon responsable</div>` +
    `<p>Pronostics fournis à titre d'information. Aucun gain n'est garanti. Les pronostics sont calculés par un modèle statistique et l'analyse est rédigée par une IA. PronoFlash IA ne prend aucun pari et ne vend aucun pronostic.</p>` +
    `<nav aria-label="Informations"><a href="/a-propos">À propos</a><a href="/contact">Contact</a><a href="/confidentialite">Confidentialité</a><a href="/conditions">Conditions</a><a href="/cookies">Cookies</a><a href="/mentions-legales">Mentions légales</a><a href="/jeu-responsable">Jeu responsable</a><button type="button" id="pf-prefs">Préférences publicitaires</button></nav>` +
    `<p>© ${rc.now.getUTCFullYear()} ${esc(rc.site.nom)} · ${esc(rc.site.domaine)}</p></div></footer>`;
}

/** Colonne de droite (ordinateur) : bilan, pavé, Afrolook, grand format collant. */
function sideColumn(rc, { bilan, afl = 'colonne', extra = '' } = {}) {
  const bil = bilan && bilan.taux != null ? `<div class="box bil"><div class="big num">${bilan.taux} %</div><div><p>de réussite sur 30 jours, ${bilan.n} pronostics.</p><a href="/bilan">Voir le bilan complet →</a></div></div>` : '';
  return `<aside class="side"><div class="sticky">${bil}${extra}${adSlot(rc, 'colonne_rect', { cls: 'ad-rect', variant: 'dk' })}${aflCard(rc, afl, 1)}${adSlot(rc, 'colonne_tall', { cls: 'ad-tall', variant: 'dk' })}</div></aside>`;
}

const stickyBar = (rc) => (slotOn(rc.ads, 'collante') ? `<div class="stk" id="pf-stk"><button type="button" aria-label="Fermer la bannière">✕</button>${adSlot(rc, 'collante', { variant: 'mo' })}</div>` : '');

/** Page HTML complète. */
function html(rc, { title, description, path, body, ld, noindex, active, bodyClass = '', ogImage, head = '' }) {
  const canonical = url(rc, path);
  const t = esc(title);
  const d = esc(description || '');
  const robots = noindex || !rc.site.indexable ? '<meta name="robots" content="noindex,nofollow">' : '<meta name="robots" content="index,follow,max-image-preview:large">';
  const hasStk = slotOn(rc.ads, 'collante');
  const verif = (rc.ads.verifications || []).map((v) => (/^<meta /i.test(v) ? v : '')).join('');
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>${t}</title><meta name="description" content="${d}">` +
    `<link rel="canonical" href="${esc(canonical)}">${robots}<meta name="theme-color" content="#080D18"><link rel="icon" href="/favicon.svg" type="image/svg+xml"><link rel="manifest" href="/manifest.webmanifest">` +
    `<meta property="og:type" content="website"><meta property="og:site_name" content="${esc(rc.site.nom)}"><meta property="og:title" content="${t}"><meta property="og:description" content="${d}"><meta property="og:url" content="${esc(canonical)}"><meta property="og:image" content="${esc(url(rc, ogImage || '/og.png'))}"><meta property="og:locale" content="fr_FR"><meta name="twitter:card" content="summary_large_image">` +
    `${verif}<link rel="preload" href="/fonts/barlow-condensed-800.woff2" as="font" type="font/woff2" crossorigin><link rel="preload" href="/fonts/inter-400-700.woff2" as="font" type="font/woff2" crossorigin>` +
    `<style>${rc.css}</style>${head}${ld ? `<script type="application/ld+json">${JSON.stringify(ld).replace(/</g, '\\u003c')}</script>` : ''}</head>` +
    `<body class="${hasStk ? 'hasstk ' : ''}${bodyClass}"><a class="skip" href="#main">Aller au contenu</a>${header(rc, active)}<main id="main">${body}</main>${footer(rc)}${stickyBar(rc)}` +
    `<div class="cbar" id="pf-cbar" hidden></div><div class="cmp-b" id="pf-cmp" role="dialog" aria-label="Préférences publicitaires" hidden></div><div class="sbar" id="pf-sbar" hidden><button type="button" aria-label="Fermer">✕</button></div>` +
    `<script>window.PF={lang:"fr",ads:${rc.ads.actif ? 1 : 0}};</script><script src="/js/goalmarkets.js?v=${rc.version}" defer></script><script src="/js/coupon.js?v=${rc.version}" defer></script><script src="/js/pf.js?v=${rc.version}" defer></script></body></html>`;
}

module.exports = {
  AFL_MSGS, STORE_ANDROID, STORE_IOS, url, matchPath, crest, timeEl, formBadges, matchCard, adSlot, adResponsive, aflCard, listWithAds,
  header, sportTabs, dayRail, leagueRail, footer, sideColumn, stickyBar, html, esc, fr, dateLongue, heure, dateCourte,
};
