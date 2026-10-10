// Génère le site statique dans dist/ : node build.mjs
import fs from 'node:fs';
import path from 'node:path';
import QRCode from 'qrcode';
import { CARDS, PACKS, EARN, NATIONAL_DAYS, AFRICA, svgIcon } from './src/data.mjs';
import { T } from './src/i18n.mjs';

const root = path.dirname(new URL(import.meta.url).pathname);
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'src/config.json'), 'utf8'));
const MONEY = /commission|\d+(,\d+)? ?%|RPM|FCFA|minimum|\$|part du créateur|palier|taux de change|encaiss|parrain/i;
// Page publique : les règles de fonctionnement, sans les montants ni les parts (ils restent dans l'application).
const rules = JSON.parse(fs.readFileSync(path.join(root, 'src/rules.json'), 'utf8'))
  .map((s) => ({ ...s, rules: s.rules.filter(([a, b]) => !MONEY.test(a) && !MONEY.test(b)) }))
  .filter((s) => s.rules.length && !/RPM|Rémunération|Gains|Retrait|monétis|Monétis|Publicité|Récompenses|DÉFI/i.test(s.title));
const dist = path.join(root, 'dist');
const flagsDir = process.env.FLAGS_DIR || path.join(root, 'static/img/flags');

const ASSET_V = '1';
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const slug = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const write = (p, c) => { const f = path.join(dist, p); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, c); };

// ───────── pays ─────────
const regionNames = { fr: new Intl.DisplayNames(['fr'], { type: 'region' }), en: new Intl.DisplayNames(['en'], { type: 'region' }) };
const COUNTRIES = Object.keys(NATIONAL_DAYS).map((code) => {
  const fr = regionNames.fr.of(code), en = regionNames.en.of(code);
  return { code, fr, en, slugFr: slug(fr), slugEn: slug(en), md: NATIONAL_DAYS[code], africa: AFRICA.has(code) };
}).sort((a, b) => a.fr.localeCompare(b.fr, 'fr'));
const deFr = (n) => (/^[AEIOUYÉÈÎÂÔ]/i.test(n) ? `l'${n}` : /^(Les |États)/.test(n) ? `des ${n.replace(/^Les /, '')}` : `${/^(Maroc|Sénégal|Togo|Bénin|Ghana|Kenya|Cameroun|Gabon|Mali|Niger|Tchad|Congo|Burkina|Rwanda|Burundi|Mozambique|Botswana|Zimbabwe|Lesotho|Libéria|Soudan|Cap|Malawi|Nigeria|Brésil|Canada|Danemark|Liban|Japon)/.test(n) ? 'le' : 'la'} ${n}`);

// ───────── chemins ─────────
const P = {
  fr: { home: '/', earn: '/gagner/', cards: '/cartes/', holidays: '/fetes/', contact: '/contact/', download: '/telecharger/', del: '/supprimer-mon-compte/', rules: '/conditions/', privacy: '/confidentialite/', holiday: (c) => `/fetes/${c.slugFr}/` },
  en: { home: '/en/', earn: '/en/earn/', cards: '/en/cards/', holidays: '/en/holidays/', contact: '/en/contact/', download: '/en/download/', del: '/en/delete-account/', rules: '/conditions/', privacy: '/confidentialite/', holiday: (c) => `/en/holidays/${c.slugEn}/` },
};
const abs = (p) => cfg.domain + p;
const sitemap = []; // { loc, alts: {fr, en} }

// ───────── composants ─────────
const storeBtns = (t) => `<a class="store" href="${cfg.playUrl}" rel="noopener"><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M4 2.8v18.4c0 .5.5.8.9.5l15-9.2c.4-.2.4-.8 0-1L4.9 2.3c-.4-.3-.9 0-.9.5z"/></svg><span><small>${t.store.avail}</small><b>${t.store.play}</b></span></a>
<a class="store" href="${cfg.appStoreUrl}" rel="noopener"><svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.7c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.2-2.8.8-3.5.8-.7 0-1.8-.8-3-.8-1.6 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7c1.3 0 2.1-1.1 2.8-2.2.9-1.3 1.3-2.5 1.3-2.6-.1 0-2.5-1-2.5-3.8zM14.2 5.9c.6-.8 1.1-1.8.9-2.9-.9 0-2 .6-2.7 1.4-.6.7-1.1 1.8-.9 2.8 1 .1 2-.5 2.7-1.3z"/></svg><span><small>${t.store.get}</small><b>${t.store.apple}</b></span></a>`;

const card = (id) => `/img/card-${id}.webp`;
const cardMeta = (c, lang) => ({ id: c.id, name: c[lang][0], sub: c[lang][1] });

function header(lang, key, alt) {
  const t = T[lang], p = P[lang];
  const links = [[p.earn, t.nav.earn, 'earn'], [p.cards, t.nav.cards, 'cards'], [p.holidays, t.nav.holidays, 'holidays'], [p.contact, t.nav.contact, 'contact']];
  const nav = links.map(([h, l, k]) => `<a href="${h}"${key === k ? ' aria-current="page"' : ''}>${l}</a>`).join('');
  const other = lang === 'fr' ? 'en' : 'fr';
  const sw = `<span class="lang-sw" aria-label="Langue"><${lang === 'fr' ? 'span aria-current="true"' : `a href="${alt.fr}" hreflang="fr" lang="fr"`}>FR</${lang === 'fr' ? 'span' : 'a'}><${lang === 'en' ? 'span aria-current="true"' : `a href="${alt.en}" hreflang="en" lang="en"`}>EN</${lang === 'en' ? 'span' : 'a'}></span>`;
  return `<a class="skip" href="#main">${t.nav.skip}</a>
<header class="top"><div class="wrap in">
 <a class="brand" href="${p.home}"><img src="/img/logo.webp" width="36" height="36" alt=""><span>afro<i>look</i></span></a>
 <nav class="main" aria-label="${t.nav.menu}">${nav}</nav>
 <div class="right">${sw}<a class="btn btn-line" href="${cfg.appWebUrl}" rel="noopener">${t.nav.web}</a><a class="btn btn-primary" href="${p.download}">${t.nav.download}</a>
 <button class="burger" id="burger" aria-label="${t.nav.menu}" aria-expanded="false" aria-controls="drawer"><span></span></button></div>
</div>
<div class="drawer" id="drawer">${links.map(([h, l]) => `<a href="${h}">${l}</a>`).join('')}<a href="${cfg.appWebUrl}">${t.nav.web}</a><a href="${p.download}">${t.nav.download}</a><a href="${other === 'en' ? alt.en : alt.fr}" hreflang="${other}">${other === 'en' ? 'English' : 'Français'}</a></div>
<div class="tri"></div></header>`;
}

function footer(lang) {
  const t = T[lang], p = P[lang], f = t.footer;
  return `<footer><div class="tri" style="position:absolute;left:0;right:0;top:0"></div><div class="wrap">
<div class="cols">
 <div><a class="brand" href="${p.home}" style="color:#fff"><img src="/img/logo.webp" width="36" height="36" alt=""><span>afro<i>look</i></span></a><p class="about">${f.about}</p></div>
 <div><h4>${f.product}</h4><ul><li><a href="${p.earn}">${t.nav.earn}</a></li><li><a href="${p.cards}">${t.nav.cards}</a></li><li><a href="${p.holidays}">${t.nav.holidays}</a></li><li><a href="${p.download}">${t.nav.download}</a></li><li><a href="${cfg.appWebUrl}">${f.web}</a></li></ul></div>
 <div><h4>${f.help}</h4><ul><li><a href="${p.home}#faq">${f.faq}</a></li><li><a href="${p.contact}">${t.nav.contact}</a></li><li><a href="${p.del}">${f.delete}</a></li></ul></div>
 <div><h4>${f.legal}</h4><ul><li><a href="${p.rules}" hreflang="fr">${f.rules}</a></li><li><a href="${p.privacy}" hreflang="fr">${f.privacy}</a></li></ul></div>
</div>
<div class="bottom"><span>© ${new Date().getFullYear()} Afrolook. ${f.rights}</span><span>afrolookmedia.com</span></div>
</div></footer>`;
}

function layout({ lang, key, path: pth, alt, title, desc, body, ogImage = '/img/og.png', jsonld = [], noindex = false, extraHead = '' }) {
  const t = T[lang];
  const canon = abs(pth);
  const hl = alt ? `<link rel="alternate" hreflang="fr" href="${abs(alt.fr)}"><link rel="alternate" hreflang="en" href="${abs(alt.en)}"><link rel="alternate" hreflang="x-default" href="${abs(alt.fr)}">` : '';
  const ld = jsonld.map((j) => `<script type="application/ld+json">${JSON.stringify(j)}</script>`).join('');
  return `<!doctype html>
<html lang="${t.htmlLang}"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>${esc(title)}</title><meta name="description" content="${esc(desc)}">
<link rel="canonical" href="${canon}">${hl}${noindex ? '<meta name="robots" content="noindex">' : ''}
<meta name="theme-color" content="#0A100C"><meta name="color-scheme" content="light dark">
<link rel="icon" href="/img/favicon-32.png" sizes="32x32"><link rel="apple-touch-icon" href="/img/apple-touch-icon.png"><link rel="manifest" href="/manifest.webmanifest">
<meta property="og:type" content="website"><meta property="og:site_name" content="Afrolook"><meta property="og:title" content="${esc(title)}"><meta property="og:description" content="${esc(desc)}"><meta property="og:url" content="${canon}"><meta property="og:image" content="${abs(ogImage)}"><meta property="og:locale" content="${lang === 'fr' ? 'fr_FR' : 'en_US'}">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${esc(title)}"><meta name="twitter:description" content="${esc(desc)}"><meta name="twitter:image" content="${abs(ogImage)}">
<script>if(location.pathname==='/'&&location.hash.indexOf('#/')===0)location.replace('/app/'+location.hash)</script>
<link rel="preload" href="/fonts/FONT_PRELOAD" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="/css/site.css?v=${ASSET_V}">${extraHead}
<script>document.documentElement.classList.add('js')</script>${ld}
</head><body>
${header(lang, key, alt || { fr: P.fr.home, en: P.en.home })}
<main id="main">${body}</main>
${footer(lang)}
<script src="/js/site.js?v=${ASSET_V}" defer></script>
</body></html>`;
}

const emit = (lang, key, pth, opts) => { write(path.join(pth, 'index.html'), layout({ lang, key, path: pth, ...opts })); sitemap.push({ loc: pth, alt: opts.alt, noindex: opts.noindex }); };

// ───────── sections réutilisables ─────────
const waysHtml = (lang) => {
  const t = T[lang].home;
  return `<div class="groups">${t.groups.map((g, gi) => `<div class="grp"><h3>${g[0]}</h3><p>${g[1]}</p>${EARN.filter((e) => e.g === gi).map((e) => `<div class="way">${svgIcon(e.icon)}<div><b>${e[lang][0]}</b><span>${e[lang][1]}</span></div></div>`).join('')}</div>`).join('')}</div>`;
};
const fmt = (lang, c) => (lang === 'fr' ? [c.coins, c.fcfa] : [c.coinsEn, c.fcfaEn]);

const showcase = (lang, { all = false } = {}) => {
  const t = T[lang].home;
  const first = CARDS.find((c) => c.id === 'neon');
  const thumbs = PACKS.map((pk, i) => `<div class="thumbs" data-pack="${pk.id}"${i ? ' hidden' : ''}>${CARDS.filter((c) => c.pack === pk.id).map((c) => `<button type="button" data-id="${c.id}" data-name="${esc(c[lang][0])}" data-sub="${esc(c[lang][1])}" data-src="${card(c.id)}" aria-pressed="${c.id === 'neon'}" title="${esc(c[lang][0])}"><img src="${card(c.id)}" alt="${esc(c[lang][0])}" width="72" height="90"></button>`).join('')}</div>`).join('');
  return `<div class="showcase" data-showcase>
<img class="big" id="big" src="${card('neon')}" width="340" height="425" alt="${esc(first[lang][0])}">
<div class="cap"><b id="capname">${first[lang][0]}</b><span id="capsub">${first[lang][1]}</span></div>
<div class="tabs" role="tablist">${PACKS.map((pk, i) => `<button type="button" role="tab" data-pack="${pk.id}" aria-selected="${i === 0}">${pk[lang]}</button>`).join('')}</div>
${thumbs}
<p class="cap">${t.real} <span class="count">26</span></p></div>`;
};

const faqHtml = (lang) => `<div class="faq">${T[lang].faq.map(([q, a]) => `<details><summary>${q}</summary><p>${a}</p></details>`).join('')}</div>`;
const faqLd = (lang) => ({ '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: T[lang].faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) });

function contactForm(lang) {
  const f = T[lang].contact.form;
  return `<form class="card" id="contact-form" data-endpoint="${cfg.contactEndpoint}" data-ok="${esc(f.ok)}" data-err="${esc(f.err)}" data-invalid="${esc(f.invalid)}" data-sending="${esc(f.sending)}" data-mail="${cfg.contactEmail}" data-lang="${lang}" novalidate>
<div class="two"><label for="f-nom">${f.name}<input id="f-nom" name="name" type="text" autocomplete="name" maxlength="80" placeholder="${esc(f.namePh)}" required></label><label for="f-mail">${f.email}<input id="f-mail" name="email" type="email" autocomplete="email" maxlength="120" placeholder="${esc(f.emailPh)}" required></label></div>
<label for="f-sujet">${f.subject}<select id="f-sujet" name="subject">${f.subjects.map((s) => `<option>${s}</option>`).join('')}</select></label>
<label for="f-msg">${f.message}<textarea id="f-msg" name="message" maxlength="3000" placeholder="${esc(f.msgPh)}" required></textarea></label>
<div class="hp" aria-hidden="true"><label>Site<input type="text" name="website" tabindex="-1" autocomplete="off"></label></div>
<button class="btn btn-primary" type="submit">${f.send}</button><p class="status" role="status" aria-live="polite"></p></form>`;
}
const contactBlock = (lang) => {
  const c = T[lang].contact;
  return `<div class="mail"><code id="mailtxt">${cfg.contactEmail}</code><button class="btn btn-line" id="copymail" type="button" data-done="${c.copied}" data-label="${c.mail}">${c.mail}</button></div>
<div class="chan">${c.chans.map(([k, n, s]) => `<a href="${cfg.social[k]}" rel="noopener">${svgIcon(k)}<span>${n}<small>${s}</small></span></a>`).join('')}</div>`;
};

const mailtoOrg = { '@context': 'https://schema.org', '@type': 'Organization', name: 'Afrolook', url: cfg.domain, logo: abs('/img/icon-512.png'), email: cfg.contactEmail, sameAs: Object.values(cfg.social) };
const appLd = (lang) => ({ '@context': 'https://schema.org', '@type': 'MobileApplication', name: 'Afrolook', operatingSystem: 'Android, iOS', applicationCategory: 'SocialNetworkingApplication', description: T[lang].home.desc, offers: { '@type': 'Offer', price: '0', priceCurrency: 'EUR' }, installUrl: cfg.playUrl, url: cfg.domain });
const crumbs = (lang, items) => `<nav class="crumbs" aria-label="Fil d'Ariane">${items.map(([h, l], i) => (i < items.length - 1 ? `<a href="${h}">${l}</a><span aria-hidden="true">/</span>` : `<span>${l}</span>`)).join('')}</nav>`;
const ctaStores = (lang) => `<div class="cta">${storeBtns(T[lang])}</div>`;

// ───────── pages ─────────
function homePage(lang) {
  const t = T[lang], h = t.home, [coins, fcfa] = fmt(lang, cfg.example);
  const eur = cfg.example.eur;
  const alt = { fr: P.fr.home, en: P.en.home };
  const body = `
<section class="hero"><div class="wrap grid">
 <div>
  <span class="eyebrow">${h.eyebrow}</span>
  <h1>${h.h1a || h.h1a} <em>${h.h1b}</em></h1>
  <p class="lead">${h.lead}</p>
  <div class="pillars"><a class="pil" href="${P[lang].earn}"><i>${svgIcon('coin')}</i><span><b>${h.pil1[0]}</b><small>${h.pil1[1]}</small></span></a><a class="pil" href="${P[lang].cards}"><i>${svgIcon('sparkle')}</i><span><b>${h.pil2[0]}</b><small>${h.pil2[1]}</small></span></a></div>
  <div class="cta">${storeBtns(t)}</div>
  <p class="note">${h.note}</p>
 </div>
 <div class="stage">
  <div class="wallet"><div class="scr"><div class="t">${h.wallet}</div><div class="bal">${coins}<small>${h.coins}</small></div>
   <div class="conv"><span><b>${fcfa}</b> FCFA</span><span><b>${eur}</b> €</span></div>
   <div class="row"><i>${svgIcon('heart')}</i><span><b>${h.likes[0]}</b><small>${h.likes[1]}</small></span><em>+${lang === 'fr' ? '118 400' : '118,400'}</em></div>
   <div class="row"><i>${svgIcon('gift')}</i><span><b>${h.gifts[0]}</b><small>${h.gifts[1]}</small></span><em>+${lang === 'fr' ? '96 350' : '96,350'}</em></div>
   <div class="row"><i>${svgIcon('tv')}</i><span><b>${h.channel[0]}</b><small>${h.channel[1]}</small></span><em>+${lang === 'fr' ? '252 000' : '252,000'}</em></div>
   <div class="row"><i>${svgIcon('live')}</i><span><b>${h.lives[0]}</b><small>${h.lives[1]}</small></span><em>+${lang === 'fr' ? '158 000' : '158,000'}</em></div>
   <div class="btnw">${h.withdraw}</div></div></div>
  <div class="fan"><span class="lab">${svgIcon('sparkle')} ${t.nav.cards}</span>
   <img class="k1" src="${card('manga')}" width="230" height="288" alt="Carte Afrolook, style manga"><img class="k2" src="${card('collector')}" width="230" height="288" alt="Carte Afrolook, style collector"><img class="k3" src="${card('passport')}" width="230" height="288" alt="Carte Afrolook, style passeport"><img class="k4" src="${card('pride')}" width="230" height="288" alt="Carte Afrolook, style couronne de drapeaux">
   <span class="share">${svgIcon('send')} ${h.share}</span></div>
  <div class="toast c"><i>${svgIcon('send')}</i><span><b>${h.withdrawn[0]}</b><small>${fcfa} FCFA ${h.withdrawn[1]}</small></span></div>
  <p class="fine">${h.fine}</p>
 </div></div></section>

<div class="platforms"><div class="wrap in"><span>${h.payment}</span>${h.plat.map((x) => `<span>${x}</span>`).join('')}</div></div>

<section class="duo2"><div class="wrap two">
 <a class="big1" href="${P[lang].earn}"><span class="tagx">${h.b1[0]}</span><h2>${h.b1[1]}</h2><p>${h.b1[2]}</p><span class="more">${h.b1[3]} →</span><div class="ex"><b>${coins}</b> ${h.coins} <em>≈ ${fcfa} FCFA ≈ ${eur} €</em></div></a>
 <a class="big2" href="${P[lang].cards}"><span class="tagx">${h.b2[0]}</span><h2>${h.b2[1]}</h2><p>${h.b2[2]}</p><span class="more">${h.b2[3]} →</span><div class="mi"><img src="${card('neon')}" width="130" height="163" alt="" loading="lazy"><img src="${card('tarot')}" width="130" height="163" alt="" loading="lazy"><img src="${card('film')}" width="130" height="163" alt="" loading="lazy"></div></a>
</div></section>

<section class="earn" id="gagner"><div class="wrap"><span class="kicker">${h.earnK}</span><h2 class="h2">${h.earnH}</h2><p class="sub">${h.earnSub}</p>${waysHtml(lang)}<p class="fine" style="text-align:left;margin-top:18px">${h.earnFine}</p></div></section>

<section id="retrait"><div class="wrap"><span class="kicker">${h.flowK}</span><h2 class="h2">${h.flowH}</h2><p class="sub">${h.flowSub(coins, fcfa, eur)}</p>
 <div class="flow">${h.flow.map((s, i) => `<div class="st"><span class="big">${i + 1}</span>${svgIcon(['img', 'coin', 'send'][i])}<h3>${s[0]}</h3><p>${s[1]}</p></div>`).join('')}</div>
 <div class="pay">${h.pay.map((x) => `<span>${x}</span>`).join('')}</div></div></section>

<section class="studio" id="cartes"><div class="wrap grid"><div>
 <span class="kicker">${h.studioK}</span><h2 class="h2">${h.studioH[0]}<span class="count">${h.studioH[1]}</span>${h.studioH[2]}</h2><p class="sub">${h.studioSub}</p>
 <ol class="steps">${h.steps.map((s, i) => `<li><span class="n">${i + 1}</span><div><b>${s[0]}</b><p>${s[1]}</p></div></li>`).join('')}</ol>
 <div class="bul">${h.bul.map((b) => `<span>${b}</span>`).join('')}</div>
 <div class="cta" style="margin-top:30px"><a class="btn btn-primary" href="${P[lang].download}">${h.studioCta}</a><a class="btn btn-line" style="background:transparent;color:inherit;border-color:#2a3a30" href="${P[lang].cards}">${h.allStyles}</a></div>
</div>${showcase(lang)}</div></section>

<section id="fonctionnalites"><div class="wrap"><span class="kicker">${h.featK}</span><h2 class="h2">${h.featH}</h2><p class="sub">${h.featSub}</p>
 <div class="feats three">${h.feats.map((f) => `<article class="feat">${svgIcon(f[0])}<h3>${f[1]}</h3><p>${f[2]}</p></article>`).join('')}</div></div></section>

<section class="fetes" id="fetes" style="background:var(--surface);border-block:1px solid var(--line)"><div class="wrap grid">
 <div><span class="kicker">${h.fetesK}</span><h2 class="h2">${h.fetesH}</h2><p class="sub">${h.fetesSub}</p>
  <div class="chips">${['SN', 'TG', 'CM', 'GH', 'CI', 'BJ', 'NG'].map((c) => { const k = COUNTRIES.find((x) => x.code === c); return `<a class="chip" href="${P[lang].holiday(k)}"><img src="/img/flags/${c.toLowerCase()}.svg" width="30" height="30" alt="" loading="lazy"><span>${k[lang]} <i>· ${T[lang].holidays.day(k.md[1], k.md[0], T[lang].holidays.months)}</i></span></a>`; }).join('')}</div>
  <div class="cta" style="margin-top:22px"><a class="btn btn-line" href="${P[lang].holidays}">${h.allHol}</a></div></div>
 <div><div class="modal" aria-label="${esc(h.modal[0])}"><div class="hd"><img src="/img/flags/sn.svg" alt="" width="360" height="150" style="width:100%;height:100%;object-fit:cover"><b>🎉</b></div><div class="bd"><h3>${h.modal[0]}</h3><p>${h.modal[1]}</p><span class="tag">${h.modal[2]}</span></div><div class="ft"><div class="go">${h.modal[3]}</div><div class="later">${h.modal[4]}</div></div></div></div>
</div></section>

<section class="dl" id="telecharger"><div class="wrap grid"><div>
 <span class="kicker">${h.dlK}</span><h2 class="h2">${h.dlH}</h2><p class="sub">${h.dlSub}</p>
 <div class="stores">${storeBtns(t)}</div>
 <div class="web" id="web"><p><b>${h.web[0]}</b><br>${h.web[1]}</p><a class="btn btn-primary" href="${cfg.appWebUrl}" rel="noopener">${h.web[2]}</a></div>
</div><div class="qrbox"><div id="qr"><img src="/img/qr-telecharger.svg" width="168" height="168" alt="QR code ${cfg.domain}${P.fr.download}"></div><b>${h.qr[0]}</b><span>${h.qr[1]}</span></div></div></section>

<section id="faq"><div class="wrap"><span class="kicker">${h.faqK}</span><h2 class="h2">${h.faqH}</h2>${faqHtml(lang)}</div></section>

<section class="contact" id="contact" style="background:var(--soft)"><div class="wrap"><span class="kicker">${t.nav.contact}</span><h2 class="h2">${lang === 'fr' ? 'Une question, une idée, un partenariat ?' : 'A question, an idea, a partnership?'}</h2>
 <div class="grid"><div><p class="sub" style="margin-top:0">${t.contact.lead}</p>${contactBlock(lang)}</div>${contactForm(lang)}</div></div></section>`;
  emit(lang, 'home', P[lang].home, { alt, title: h.title, desc: h.desc, body, jsonld: [mailtoOrg, appLd(lang), faqLd(lang)] });
}

function earnPage(lang) {
  const t = T[lang], e = t.earn, h = t.home, [coins, fcfa] = fmt(lang, cfg.example), eur = cfg.example.eur;
  const alt = { fr: P.fr.earn, en: P.en.earn };
  const body = `<section class="pagehead"><div class="wrap">${crumbs(lang, [[P[lang].home, 'Afrolook'], [P[lang].earn, t.nav.earn]])}<h1>${e.h1}</h1><p>${e.lead}</p><div class="cta" style="margin-top:24px">${storeBtns(t)}</div></div></section>
<section class="earn" style="padding-block:56px"><div class="wrap">${waysHtml(lang)}<p class="fine" style="text-align:left;margin-top:18px">${h.earnFine}</p></div></section>
<section><div class="wrap twocol"><div><span class="kicker">${e.example}</span><h2 class="h2">${coins} ${h.coins}</h2><p class="sub">${h.flowSub(coins, fcfa, eur)}</p><div class="pay">${h.pay.map((x) => `<span>${x}</span>`).join('')}</div><p class="fine" style="text-align:left">${h.fine}</p></div>
<div class="grp"><h3>${e.rules}</h3><p>${e.rulesText}</p><p><a class="btn btn-line" href="${P[lang].download}">${e.rulesCta}</a></p></div></div></section>
<section style="padding-top:0"><div class="wrap"><span class="kicker">${h.faqK}</span><h2 class="h2">${h.faqH}</h2>${faqHtml(lang)}</div></section>`;
  emit(lang, 'earn', P[lang].earn, { alt, title: e.title, desc: e.desc, body, jsonld: [faqLd(lang)] });
}

function cardsPage(lang) {
  const t = T[lang], c = t.cards;
  const alt = { fr: P.fr.cards, en: P.en.cards };
  const grid = PACKS.map((pk) => `<h2 class="h2" style="font-size:28px;margin-top:44px" id="${pk.id}">${pk[lang]}</h2><div class="cards-grid">${CARDS.filter((x) => x.pack === pk.id).map((x) => `<figure class="cg" style="margin:0"><img src="${card(x.id)}" width="480" height="600" alt="${esc(c.h1.split(':')[0])} ${esc(x[lang][0])}" loading="lazy"><b>${x[lang][0]} <span class="pill ${x.free ? 'free' : 'pro'}">${x.free ? c.free : c.pro}</span></b><small>${x[lang][1]}</small></figure>`).join('')}</div>`).join('');
  const body = `<section class="pagehead"><div class="wrap">${crumbs(lang, [[P[lang].home, 'Afrolook'], [P[lang].cards, t.nav.cards]])}<h1>${c.h1}</h1><p>${c.lead}</p><div class="cta" style="margin-top:24px"><a class="btn btn-primary" href="${P[lang].download}">${c.createCta}</a></div>
<div class="toc">${PACKS.map((pk) => `<a href="#${pk.id}">${pk[lang]}</a>`).join('')}</div></div></section>
<section class="section-pad" style="padding-top:8px"><div class="wrap">${grid}
<div class="twocol" style="margin-top:70px"><div><span class="kicker">${c.shareK}</span><h2 class="h2" style="font-size:34px">${c.shareK}</h2><p class="sub">${c.shareT}</p><p class="sub">${c.formats}</p></div>
<div class="grp"><h3>${c.priceTitle}</h3>${c.prices.map((p) => `<div class="way">${svgIcon('coin')}<div><span style="margin:0">${p}</span></div></div>`).join('')}</div></div>
<div class="cta" style="margin-top:34px"><a class="btn btn-primary" href="${P[lang].holidays}">${c.moreIdeas}</a></div></div></section>`;
  emit(lang, 'cards', P[lang].cards, { alt, title: c.title, desc: c.desc, body, ogImage: '/img/og.png', jsonld: [appLd(lang)] });
}

function holidaysIndex(lang) {
  const t = T[lang], hd = t.holidays;
  const alt = { fr: P.fr.holidays, en: P.en.holidays };
  const list = (arr) => `<div class="countries">${arr.map((k) => `<a class="cty" href="${P[lang].holiday(k)}"><img src="/img/flags/${k.code.toLowerCase()}.svg" width="36" height="36" alt="" loading="lazy"><span><b>${k[lang]}</b><small>${hd.day(k.md[1], k.md[0], hd.months)}</small></span></a>`).join('')}</div>`;
  const sorted = [...COUNTRIES].sort((a, b) => a[lang].localeCompare(b[lang], lang));
  const body = `<section class="pagehead"><div class="wrap">${crumbs(lang, [[P[lang].home, 'Afrolook'], [P[lang].holidays, t.nav.holidays]])}<h1>${hd.h1}</h1><p>${hd.lead}</p></div></section>
<section class="section-pad" style="padding-top:8px"><div class="wrap"><h2 class="h2" style="font-size:28px">${hd.africa}</h2>${list(sorted.filter((k) => k.africa))}<h2 class="h2" style="font-size:28px;margin-top:48px">${hd.world}</h2>${list(sorted.filter((k) => !k.africa))}<p class="notice">${hd.alsoText}</p></div></section>`;
  emit(lang, 'holidays', P[lang].holidays, { alt, title: hd.title, desc: hd.desc, body });
}

function holidayPage(lang, k) {
  const t = T[lang], hd = t.holidays;
  const alt = { fr: P.fr.holiday(k), en: P.en.holiday(k) };
  const date = hd.day(k.md[1], k.md[0], hd.months);
  const name = lang === 'fr' ? deFr(k.fr) : k.en;
  const n = lang === 'fr' ? k.fr : k.en;
  const body = `<section class="pagehead"><div class="wrap">${crumbs(lang, [[P[lang].home, 'Afrolook'], [P[lang].holidays, t.nav.holidays], [P[lang].holiday(k), n]])}
<div class="flaghero"><img src="/img/flags/${k.code.toLowerCase()}.svg" width="88" height="88" alt="${esc(lang === 'fr' ? 'Drapeau : ' + k.fr : 'Flag of ' + k.en)}"><div><h1 style="margin-top:0">${hd.eachH(n)}</h1><span class="next">${lang === 'fr' ? 'Chaque' : 'Every'} ${date}</span></div></div>
<p>${hd.eachLead(lang === 'fr' ? name : n, date)}</p><div class="cta" style="margin-top:24px">${storeBtns(t)}</div></div></section>
<section class="section-pad"><div class="wrap twocol"><div><span class="kicker">${hd.howK}</span><ol class="steps" style="margin-top:18px">${hd.how.map((s, i) => `<li style="background:var(--surface);border-color:var(--line)"><span class="n">${i + 1}</span><div><p style="color:var(--ink)">${s}</p></div></li>`).join('')}</ol><p class="notice">${hd.note}</p></div>
<div class="cards-grid" style="grid-template-columns:repeat(3,1fr);margin-top:0">${['flag', 'passport', 'pride'].map((id) => `<figure class="cg" style="margin:0"><img src="${card(id)}" width="480" height="600" alt="" loading="lazy"></figure>`).join('')}<p class="fine" style="grid-column:1/-1;text-align:left;margin:0">${lang === 'fr' ? 'Exemples de styles drapeau (drapeaux d\'autres pays).' : 'Examples of flag styles (flags of other countries).'}</p></div></div></section>
<section style="padding-top:0"><div class="wrap"><h2 class="h2" style="font-size:28px">${hd.also}</h2><p class="sub">${hd.alsoText}</p><div class="cta" style="margin-top:20px"><a class="btn btn-line" href="${P[lang].holidays}">${t.home.allHol}</a><a class="btn btn-primary" href="${P[lang].cards}">${t.nav.cards}</a></div></div></section>`;
  emit(lang, 'holidays', P[lang].holiday(k), { alt, title: hd.eachTitle(n), desc: hd.eachDesc(n, date), body, ogImage: '/img/og.png' });
}

function contactPage(lang) {
  const t = T[lang], c = t.contact;
  const alt = { fr: P.fr.contact, en: P.en.contact };
  const body = `<section class="pagehead"><div class="wrap">${crumbs(lang, [[P[lang].home, 'Afrolook'], [P[lang].contact, t.nav.contact]])}<h1>${c.h1}</h1><p>${c.lead}</p></div></section>
<section class="section-pad" style="padding-top:8px"><div class="wrap contact"><div class="grid" style="margin-top:0"><div>${contactBlock(lang)}</div>${contactForm(lang)}</div></div></section>`;
  emit(lang, 'contact', P[lang].contact, { alt, title: c.title, desc: c.desc, body, jsonld: [mailtoOrg] });
}

function downloadPage(lang) {
  const t = T[lang], d = t.dl;
  const alt = { fr: P.fr.download, en: P.en.download };
  const body = `<section class="dlpage"><div class="wrap"><img src="/img/logo.webp" width="96" height="96" alt="" style="margin:0 auto 18px;border-radius:24px"><h1 class="h2" style="margin-top:0">${d.h1}</h1><p class="sub" style="margin-inline:auto">${d.lead}</p><p class="sub" id="redir" style="margin-inline:auto;display:none">${d.redirect}</p><div class="stores">${storeBtns(t)}</div></div></section>`;
  emit(lang, 'download', P[lang].download, { alt, title: d.title, desc: d.desc, body, extraHead: `<meta name="afrolook-play" content="${cfg.playUrl}"><meta name="afrolook-ios" content="${cfg.appStoreUrl}">` });
}

function deletePage(lang) {
  const t = T[lang], d = t.del;
  const alt = { fr: P.fr.del, en: P.en.del };
  const body = `<section class="pagehead"><div class="wrap">${crumbs(lang, [[P[lang].home, 'Afrolook'], [P[lang].del, d.h1]])}<h1>${d.h1}</h1><p>${d.lead}</p></div></section>
<section class="section-pad" style="padding-top:8px"><div class="wrap prose"><h2>${d.stepsH}</h2><ol>${d.steps.map((s) => `<li>${s}</li>`).join('')}</ol><h2>${d.afterH}</h2><ul>${d.after.map((s) => `<li>${s}</li>`).join('')}</ul><h2>${d.helpH}</h2><p>${d.help} <a href="mailto:${cfg.contactEmail}">${cfg.contactEmail}</a>.</p></div></section>`;
  emit(lang, 'del', P[lang].del, { alt, title: d.title, desc: d.desc, body });
}

function legalPages() {
  const t = T.fr, L = t.legal;
  const sections = (list) => list.map((s) => `<h2 id="${slug(s.title)}">${esc(s.title)}</h2>${s.rules.map(([a, b]) => `<h3>${esc(a)}</h3><p>${esc(b)}</p>`).join('')}`).join('');
  const privSections = rules.filter((s) => /Confidentialité|Sécurité du compte|Droits d'auteur/.test(s.title));
  const alt = { fr: P.fr.rules, en: P.fr.rules };
  const toc = (list) => `<div class="toc">${list.map((s) => `<a href="#${slug(s.title)}">${esc(s.title)}</a>`).join('')}</div>`;
  emit('fr', 'rules', P.fr.rules, { alt, title: `${L.rulesTitle}`, desc: L.rulesDesc, body: `<section class="pagehead"><div class="wrap">${crumbs('fr', [[P.fr.home, 'Afrolook'], [P.fr.rules, L.rulesH1]])}<h1>${L.rulesH1}</h1><p>${L.rulesIntro}</p>${toc(rules)}</div></section><section class="section-pad" style="padding-top:8px"><div class="wrap prose">${sections(rules)}<p class="notice">${L.same} : <a href="${P.fr.privacy}">${t.footer.privacy}</a> · <a href="${P.fr.del}">${t.footer.delete}</a> · <a href="${P.fr.contact}">${t.nav.contact}</a></p></div></section>` });
  const palt = { fr: P.fr.privacy, en: P.fr.privacy };
  emit('fr', 'privacy', P.fr.privacy, { alt: palt, title: L.privTitle, desc: L.privDesc, body: `<section class="pagehead"><div class="wrap">${crumbs('fr', [[P.fr.home, 'Afrolook'], [P.fr.privacy, L.privH1]])}<h1>${L.privH1}</h1><p>${L.privIntro}</p></div></section><section class="section-pad" style="padding-top:8px"><div class="wrap prose">${sections(privSections)}<h2>Nous écrire</h2><p>Pour toute question ou demande sur tes données : <a href="mailto:${cfg.contactEmail}">${cfg.contactEmail}</a>.</p><p class="notice">${L.same} : <a href="${P.fr.rules}">${t.footer.rules}</a> · <a href="${P.fr.del}">${t.footer.delete}</a></p></div></section>` });
}

function notFound() {
  const t = T.fr.notFound;
  write('404.html', layout({ lang: 'fr', key: '404', path: '/404.html', title: `${t.title} | Afrolook`, desc: t.text, noindex: true, body: `<section class="dlpage"><div class="wrap"><h1 class="h2" style="margin-top:0">${t.h1}</h1><p class="sub" style="margin-inline:auto">${t.text}</p><div class="cta" style="justify-content:center;margin-top:24px"><a class="btn btn-primary" href="/">${t.home}</a><a class="btn btn-line" href="/cartes/">${T.fr.nav.cards}</a></div></div></section>` }));
}

// ───────── génération ─────────
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });
fs.cpSync(path.join(root, 'static'), dist, { recursive: true });

for (const lang of ['fr', 'en']) {
  homePage(lang); earnPage(lang); cardsPage(lang); holidaysIndex(lang); contactPage(lang); downloadPage(lang); deletePage(lang);
  for (const k of COUNTRIES) holidayPage(lang, k);
}
legalPages(); notFound();

// police préchargée : la plus utilisée (titres gras, alphabet latin)
const fontCss = fs.readFileSync(path.join(root, 'static/css/site.css'), 'utf8');
const latin = [...fontCss.matchAll(/font-family:'Bricolage Grotesque'[^}]*?font-weight:800[^}]*?url\(\/fonts\/([^)]+)\)[^}]*?unicode-range:U\+0000-00FF/g)].map((m) => m[1])[0];
for (const f of walk(dist)) if (f.endsWith('.html')) fs.writeFileSync(f, fs.readFileSync(f, 'utf8').replace('FONT_PRELOAD', latin || ''));
function walk(d) { return fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)])); }

// QR du téléchargement
write('img/qr-telecharger.svg', await QRCode.toString(abs(P.fr.download), { type: 'svg', margin: 1, errorCorrectionLevel: 'M', color: { dark: '#0D1511', light: '#ffffff' } }));

// robots, sitemap, manifeste
write('robots.txt', `User-agent: *\nAllow: /\nDisallow: /404.html\n\nSitemap: ${abs('/sitemap.xml')}\n`);
const entries = sitemap.filter((s) => !s.noindex);
const seen = new Set();
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${entries.filter((s) => !seen.has(s.loc) && seen.add(s.loc)).map((s) => `<url><loc>${abs(s.loc)}</loc>${s.alt && s.alt.fr !== s.alt.en ? `<xhtml:link rel="alternate" hreflang="fr" href="${abs(s.alt.fr)}"/><xhtml:link rel="alternate" hreflang="en" href="${abs(s.alt.en)}"/>` : ''}</url>`).join('\n')}\n</urlset>\n`);
write('manifest.webmanifest', JSON.stringify({ name: 'Afrolook', short_name: 'Afrolook', start_url: '/', display: 'browser', background_color: '#0A100C', theme_color: '#0A100C', icons: [{ src: '/img/icon-192.png', sizes: '192x192', type: 'image/png' }, { src: '/img/icon-512.png', sizes: '512x512', type: 'image/png' }] }));
console.log(`site : ${walk(dist).filter((f) => f.endsWith('.html')).length} pages, ${entries.length} URL dans le sitemap`);
