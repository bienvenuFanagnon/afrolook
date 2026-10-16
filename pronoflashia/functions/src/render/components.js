'use strict';
// Briques HTML réutilisables, en français ou en anglais selon rc.lang. Tout est rendu côté serveur : les pages sont lisibles sans JavaScript.

const { esc, dateCourte, dateLongue, heure, fr } = require('../util/format');
const { slotOn } = require('./config');
const labels = require('../shared/labels');

const STORE_ANDROID = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok';
const STORE_IOS = 'https://apps.apple.com/gh/app/afrolook/id6811423047';

/** Messages Afrolook adaptés au football (le client les fait tourner). */
const AFL_MSGS = {
  fr: ['Débats foot sur Afrolook : donne ton avis sur le match', 'Partage tes pronos entre amis sur Afrolook', 'Tes likes deviennent des pièces sur Afrolook', 'Tu postes des vidéos ? Afrolook te paie tes vues', 'Afrolook : le réseau africain des créateurs'],
  en: ['Football debates on Afrolook: share your take on the match', 'Share your tips with friends on Afrolook', 'Your likes turn into coins on Afrolook', 'Post videos? Afrolook pays you for your views', 'Afrolook: the African creators network'],
};
const AFL_PHOTOS = ['/img/afl1.jpg', '/img/afl4.jpg'];

const url = (rc, path) => `${rc.site.origine}${path}`;
const matchPath = (rc, m) => rc.u('match', m);

/** Deux-points : « : » en français (espace avant), « : » collé en anglais. */
const colon = (rc) => (rc.lang === 'en' ? ':' : ' :');

/** Pourcentage : « 62 % » en français, « 62% » en anglais. */
const pct = (rc, v) => (rc.lang === 'en' ? `${v}%` : `${v} %`);

/** Nom du championnat dans la langue de la page (noms.fr / noms.en dans l'admin, sinon le nom d'origine). */
function leagueName(rc, leagueIdOrMatch) {
  const id = typeof leagueIdOrMatch === 'object' ? leagueIdOrMatch.leagueId : leagueIdOrMatch;
  const l = rc.leagues.find((x) => String(x.apiId) === String(id));
  const fallback = typeof leagueIdOrMatch === 'object' ? leagueIdOrMatch.leagueNom : String(id);
  return (l && ((l.noms && l.noms[rc.lang]) || l.nom)) || fallback;
}
const leagueLabel = (rc, l) => (l.noms && l.noms[rc.lang]) || l.nom;

/** Libellé du pronostic principal dans la langue de la page. */
function pickLabel(rc, m) {
  const p = m.prono && m.prono.principal;
  if (!p) return '';
  if (rc.lang !== 'en') return p.libelle;
  if (p.manuel && p.libelleEn) return p.libelleEn;
  return labels.principalLabel(p.cle, m.domicile.nomCourt, m.exterieur.nomCourt, 'en') || p.libelle;
}

/** Libellé d'un marché (le libellé français est stocké ; l'anglais est déduit de la clé). */
function betLabel(rc, m, mk) {
  if (rc.lang !== 'en') return mk.libelle;
  return labels.marketLabel(mk.cle, m.domicile.nomCourt, m.exterieur.nomCourt, 'en') || mk.libelle;
}
const famLabel = (rc, f) => labels.familyLabel(f, rc.lang);

function crest(team, big) {
  const c = team.couleurs || ['#1b3a8a', '#0a1f4d'];
  const size = big ? 46 : 26;
  // le logo recouvre les initiales ; s'il ne charge pas, l'image vide disparaît et l'écusson généré reste visible
  const img = team.logo ? `<img src="${esc(team.logo)}" alt="" width="${size}" height="${size}" loading="lazy" decoding="async" referrerpolicy="no-referrer">` : '';
  return `<span class="cr${big ? ' lgx' : ''}" style="background:linear-gradient(135deg,${esc(c[0])},${esc(c[1])})" aria-hidden="true">${esc(team.initiales || '?')}${img}</span>`;
}

/** Heure en UTC côté serveur ; le navigateur la convertit dans le fuseau du visiteur. */
const timeEl = (rc, iso) => `<time datetime="${esc(iso)}" data-t="hm" title="${esc(rc.t.utcTitle)}">${heure(iso)}</time>`;

/** Forme récente : V/N/D en français, W/D/L en anglais. */
function formBadges(rc, f) {
  if (!f) return '';
  const map = rc.lang === 'en' ? { V: 'W', N: 'D', D: 'L' } : { V: 'V', N: 'N', D: 'D' };
  return `<span class="fm" aria-label="${esc(rc.t.recentForm)}">${f.split('').map((c) => `<i class="${c}">${map[c] || c}</i>`).join('')}</span>`;
}

/** Carte de match : pronostic principal visible tout de suite, sans clic. */
function matchCard(rc, m) {
  const t = rc.t;
  const p = m.prono;
  const href = matchPath(rc, m);
  const head = `<div class="hd"><span><b class="num">${timeEl(rc, m.coupDEnvoi)}</b>${esc(leagueName(rc, m))}</span><span>${esc(dateCourte(m.coupDEnvoi, rc.lang))}</span></div>`;
  const teams = `<div class="tm"><div class="tr">${crest(m.domicile)}${esc(m.domicile.nomCourt)}${formBadges(rc, p && p.formeDom)}</div><div class="tr">${crest(m.exterieur)}${esc(m.exterieur.nomCourt)}${formBadges(rc, p && p.formeExt)}</div></div>`;
  if (m.statut === 'termine' && m.resultat) {
    const r = m.resultat;
    const mark = r.reussi === true ? '<span class="badge-ok">✅</span>' : r.reussi === false ? '<span class="badge-ko">❌</span>' : '';
    return `<a class="mc" href="${href}">${head}${teams}<div class="pr"><div><span class="pk1">${t.finalScore}</span><b>${r.scoreDom} - ${r.scoreExt}</b></div><div class="res">${mark}</div></div>${p ? `<div class="sc"><span>${t.ourPrediction}${colon(rc)} ${esc(pickLabel(rc, m))}</span></div>` : ''}<span class="more off">${t.moreDetailsDone} <i aria-hidden="true">›</i></span></a>`;
  }
  if (!p || p.visible === false) return `<a class="mc" href="${href}">${head}${teams}<div class="pr"><div><span class="pk1">${t.prediction}</span><b>${t.inPrep}</b></div></div></a>`;
  const pr = p.probas;
  const low = p.principal.basseConfiance ? ' low' : '';
  const sec = (p.secondaires || []).map((s) => `<span>${esc(betLabel(rc, m, s))} · ${pct(rc, s.pct)}</span>`).join('');
  return `<a class="mc" href="${href}">${head}${teams}<div class="pr"><div><span class="pk1">${t.prediction}</span><b>${esc(pickLabel(rc, m))}</b></div><div class="cf num${low}">${pct(rc, p.principal.confiance)}<small>${t.confidence}</small></div></div>` +
    `<div class="bars" role="img" aria-label="${esc(t.probsAria)}"><i style="flex:${pr['1']};background:var(--flash)"></i><i style="flex:${pr.N};background:#6b7899"></i><i style="flex:${pr['2']};background:var(--cy)"></i></div>` +
    `<div class="bl num"><span>1 · ${pct(rc, pr['1'])}</span><span>${t.draw} · ${pct(rc, pr.N)}</span><span>2 · ${pct(rc, pr['2'])}</span></div>` +
    `<div class="sc">${sec}</div><span class="more">${t.moreDetails} <i aria-hidden="true">›</i></span></a>`;
}

/**
 * Emplacement publicitaire (espace réservé, rempli par le navigateur). Rien n'est rendu si l'admin ne l'a pas activé.
 * variant : 'dk' (ordinateur seulement), 'mo' (téléphone seulement) ou '' (partout).
 */
function adSlot(rc, id, { variant = '', cls = '' } = {}) {
  if (!slotOn(rc.ads, id)) return '';
  const e = rc.ads.emplacements[id];
  const dim = (variant === 'dk' ? e.dk : variant === 'mo' ? e.mo : e.dk || e.mo) || [300, 250];
  return `<div class="ad ${cls} ${variant}" data-ad="${esc(id)}" data-v="${variant || 'all'}" data-w="${dim[0]}" data-h="${dim[1]}" style="min-height:${dim[1]}px" aria-label="${esc(rc.t.adLabel)}"></div>`;
}

/** Bannière responsive : deux variantes (ordinateur / téléphone), une seule est visible donc une seule se charge. */
const adResponsive = (rc, id, cls) => adSlot(rc, id, { variant: 'dk', cls }) + adSlot(rc, id, { variant: 'mo', cls });

/** Encart Afrolook (maison). Le navigateur choisit le lien magasin selon l'appareil et fait tourner le message. */
function aflCard(rc, slot, i = 0) {
  if (!rc.ads.afrolook || !rc.ads.afrolook.actif) return '';
  const msgs = AFL_MSGS[rc.lang] || AFL_MSGS.fr;
  const msg = msgs[i % msgs.length];
  const photo = AFL_PHOTOS[i % AFL_PHOTOS.length];
  const utm = `utm_source=pronoflashia&utm_campaign=${encodeURIComponent(slot)}`;
  return `<a class="afl" href="${esc(`${STORE_ANDROID}&${utm}`)}" target="_blank" rel="noopener sponsored" data-afl="${esc(slot)}" data-i="${i}"><span class="sp2">${rc.t.sponsored}</span><div class="im" style="background-image:url(${photo})"></div><div class="bd"><span class="bg"><img src="/img/afrolook.png" alt="" width="12" height="12" loading="lazy">AFROLOOK</span><p>${esc(msg)}</p><span class="cta">${rc.t.aflCta}</span></div></a>`;
}

/**
 * Insère les publicités dans une liste de cartes (identique sur téléphone et ordinateur).
 * Un encart Afrolook après la 2e carte (visible sans défiler loin), une annonce « native » après la 3e puis toutes les N cartes,
 * un encart Afrolook toutes les M cartes ensuite. Jamais deux pubs d'affilée, jamais une pub après la dernière carte.
 */
function listWithAds(rc, cards) {
  const nat = rc.ads.emplacements.native || {};
  const afl = rc.ads.afrolook || {};
  const natOn = slotOn(rc.ads, 'native') && nat.every;
  const aflOn = afl.actif && afl.every;
  const out = [];
  let a = 0;
  let nextNat = 3, nextAfl = 2;
  cards.forEach((c, i) => {
    out.push(c);
    const n = i + 1;
    if (n >= cards.length) return;
    if (natOn && n === nextNat) { out.push(adSlot(rc, 'native', { cls: 'ad-nat', variant: '' })); nextNat += nat.every; if (nextAfl === n) nextAfl = n + 1; return; }
    if (aflOn && n === nextAfl) { out.push(aflCard(rc, 'liste', a++)); nextAfl += afl.every; }
  });
  return out.join('');
}

/** Fin de liste : bannière puis, sur téléphone, un encart Afrolook (la colonne de droite n'existe que sur ordinateur). */
const listEnd = (rc, slot) => adResponsive(rc, 'fin', 'ad-end') + (rc.ads.afrolook && rc.ads.afrolook.actif ? `<div class="mob-only">${aflCard(rc, slot || 'fin', 1)}</div>` : '');

function header(rc, active, alternates) {
  const t = rc.t;
  const a = (k) => (active === k ? ' aria-current="page"' : '');
  const other = rc.lang === 'en' ? 'fr' : 'en';
  const switchHref = (alternates && alternates[other]) || (other === 'en' ? '/en' : '/');
  return `<header class="hdr"><div class="wrap"><a class="logo" href="${rc.u('home')}" aria-label="${esc(t.homeAria)}"><span class="bolt" aria-hidden="true">⚡</span><span>Prono<em>Flash</em><small>IA</small></span></a>` +
    `<nav class="nav" aria-label="${esc(t.navMain)}"><a href="${rc.u('day', 'aujourdhui')}"${a('football')}>${t.navFootball}</a><a href="${rc.u('coupon')}"${a('coupon')}>${t.navCoupon}</a><a href="${rc.u('bilan')}"${a('bilan')}>${t.navBilan}</a><a href="${rc.u('legal', 'a-propos')}"${a('apropos')}>${t.navAbout}</a></nav>` +
    `<span class="sp"></span><a class="cpn" id="pf-cpn" href="${rc.u('coupon')}" hidden>${t.myCoupon}</a><a class="lang" href="${esc(switchHref)}" hreflang="${other}" lang="${other}" aria-label="${esc(t.langSwitchAria)}">${t.langSwitch}</a></div></header>`;
}

function sportTabs(rc) {
  const t = rc.t;
  return `<div class="rail" role="navigation" aria-label="${esc(t.sports)}"><a class="sport" href="${rc.u('day', 'aujourdhui')}" aria-current="page">⚽ Football</a><span class="sport off">🏀 ${t.basketball} <i>${t.soon}</i></span><span class="sport off">🎾 ${t.tennis} <i>${t.soon}</i></span></div>`;
}

/** Jours : aujourd'hui, demain, puis les 4 suivants. */
function dayRail(rc, activeDay) {
  const t = rc.t;
  const items = [['aujourdhui', t.today, rc.today], ['demain', t.tomorrow, rc.tomorrow]];
  for (let i = 2; i <= 5; i++) {
    const d = new Date(rc.now.getTime() + i * 864e5).toISOString().slice(0, 10);
    items.push([d, dateCourte(d + 'T12:00:00Z', rc.lang).replace(/\.$/, ''), d]);
  }
  return `<div class="rail" role="navigation" aria-label="${esc(t.days)}">${items.map(([slug, label, d]) => `<a class="chip" href="${rc.u('day', slug)}"${activeDay === d ? ' aria-current="true"' : ''}>${esc(label)}</a>`).join('')}</div>`;
}

function leagueRail(rc, activeSlug) {
  const t = rc.t;
  return `<div class="rail" role="navigation" aria-label="${esc(t.leagues)}"><a class="lg" href="${rc.u('day', 'aujourdhui')}"${!activeSlug ? ' aria-current="true"' : ''}>${t.all}</a>${rc.leagues.map((l) => `<a class="lg" href="${rc.u('league', l.slug)}"${activeSlug === l.slug ? ' aria-current="true"' : ''}>${esc(leagueLabel(rc, l))}</a>`).join('')}</div><p class="tznote">${t.tzNote}</p>`;
}

function footer(rc) {
  const t = rc.t;
  const legal = Object.entries(t.footerLegal).map(([slug, lab]) => `<a href="${rc.u('legal', slug)}">${lab}</a>`).join('');
  return `<footer class="ftr"><div class="wrap" style="display:grid;gap:10px"><div class="r18"><b>18+</b>${t.footer18}</div><p>${t.footerInfo}</p>` +
    `<nav aria-label="${esc(t.footerNav)}">${legal}<button type="button" id="pf-prefs">${t.adPrefs}</button></nav>` +
    `<p class="cpy">© ${rc.now.getUTCFullYear()} ${esc(rc.site.nom)} · ${esc(rc.site.domaine)}<a class="adm" href="/admin" rel="nofollow noopener">Hub</a></p></div></footer>`;
}

/** Colonne de droite (ordinateur) : bilan, pavé, Afrolook, grand format collant. */
function sideColumn(rc, { bilan, afl = 'colonne', extra = '' } = {}) {
  const t = rc.t;
  const bil = bilan && bilan.taux != null ? `<div class="box bil"><div class="big num">${pct(rc, bilan.taux)}</div><div><p>${t.bilanSide(bilan.n)}</p><a href="${rc.u('bilan')}">${t.seeBilan}</a></div></div>` : '';
  return `<aside class="side"><div class="sticky">${bil}${extra}${adSlot(rc, 'colonne_rect', { cls: 'ad-rect', variant: 'dk' })}${aflCard(rc, afl, 1)}${adSlot(rc, 'colonne_tall', { cls: 'ad-tall', variant: 'dk' })}</div></aside>`;
}

const stickyBar = (rc) => (slotOn(rc.ads, 'collante') ? `<div class="stk" id="pf-stk"><button type="button" aria-label="${esc(rc.t.closeBanner)}">✕</button>${adSlot(rc, 'collante', { variant: 'mo' })}</div>` : '');

/** Page HTML complète, avec les liens hreflang vers l'autre langue. */
function html(rc, { title, description, path, body, ld, noindex, active, bodyClass = '', ogImage, head = '', alternates }) {
  const t = rc.t;
  const canonical = url(rc, path);
  const tt = esc(title);
  const d = esc(description || '');
  const robots = noindex || !rc.site.indexable ? '<meta name="robots" content="noindex,nofollow">' : '<meta name="robots" content="index,follow,max-image-preview:large">';
  const hasStk = slotOn(rc.ads, 'collante');
  const verif = (rc.ads.verifications || []).map((v) => (/^<meta /i.test(v) ? v : '')).join('');
  const gsc = rc.site.googleVerification && /^[A-Za-z0-9_-]{10,100}$/.test(rc.site.googleVerification) ? `<meta name="google-site-verification" content="${esc(rc.site.googleVerification)}">` : '';
  const alt = alternates && !noindex ? `<link rel="alternate" hreflang="fr" href="${esc(url(rc, alternates.fr))}"><link rel="alternate" hreflang="en" href="${esc(url(rc, alternates.en))}"><link rel="alternate" hreflang="x-default" href="${esc(url(rc, alternates.fr))}">` : '';
  return `<!doctype html><html lang="${t.htmlLang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>${tt}</title><meta name="description" content="${d}">` +
    `<link rel="canonical" href="${esc(canonical)}">${alt}${robots}<meta name="theme-color" content="#080D18"><link rel="icon" href="/favicon.svg" type="image/svg+xml"><link rel="manifest" href="/manifest.webmanifest">` +
    `<meta property="og:type" content="website"><meta property="og:site_name" content="${esc(rc.site.nom)}"><meta property="og:title" content="${tt}"><meta property="og:description" content="${d}"><meta property="og:url" content="${esc(canonical)}"><meta property="og:image" content="${esc(url(rc, ogImage || '/og.png'))}"><meta property="og:locale" content="${t.ogLocale}"><meta name="twitter:card" content="summary_large_image">` +
    `${verif}${gsc}<link rel="preload" href="/fonts/barlow-condensed-800.woff2" as="font" type="font/woff2" crossorigin><link rel="preload" href="/fonts/inter-400-700.woff2" as="font" type="font/woff2" crossorigin>` +
    `<style>${rc.css}</style>${head}${ld ? `<script type="application/ld+json">${JSON.stringify(ld).replace(/</g, '\\u003c')}</script>` : ''}</head>` +
    `<body class="${hasStk ? 'hasstk ' : ''}${bodyClass}"><a class="skip" href="#main">${t.skip}</a>${header(rc, active, alternates)}<main id="main">${body}</main>${footer(rc)}${stickyBar(rc)}` +
    `<div class="cbar" id="pf-cbar" hidden></div><div class="cmp-b" id="pf-cmp" role="dialog" aria-label="${esc(t.adPrefs)}" hidden></div><div class="sbar" id="pf-sbar" hidden><button type="button" aria-label="${esc(t.close)}">✕</button></div>` +
    `<script>window.PF={lang:"${rc.lang}",ads:${rc.ads.actif ? 1 : 0},coupon:"${rc.u('coupon')}"};</script><script src="/js/goalmarkets.js?v=${rc.version}" defer></script><script src="/js/coupon.js?v=${rc.version}" defer></script><script src="/js/pf.js?v=${rc.version}" defer></script></body></html>`;
}

module.exports = {
  AFL_MSGS, STORE_ANDROID, STORE_IOS, url, matchPath, pct, colon, leagueName, leagueLabel, pickLabel, betLabel, famLabel, crest, timeEl, formBadges, matchCard,
  adSlot, adResponsive, aflCard, listWithAds, listEnd, header, sportTabs, dayRail, leagueRail, footer, sideColumn, stickyBar, html, esc, fr, dateLongue, heure, dateCourte,
};
