// Génère le site statique dans dist/ : node build.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { T } from './src/i18n.mjs';
import { CATEGORIES, COMMANDS } from './src/data.mjs';

const root = path.dirname(new URL(import.meta.url).pathname);
const dist = path.join(root, 'dist');
const cfg = JSON.parse(fs.readFileSync(path.join(root, 'src/config.json'), 'utf8'));
const esc = (s) => String(s).replace(/ ([?!:;»])/g, '\u00a0$1').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const abs = (p) => cfg.domain + p;
const write = (p, c) => { const f = path.join(dist, p); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, c); };
const hashOf = (f) => createHash('sha1').update(fs.readFileSync(path.join(root, 'static', f))).digest('hex').slice(0, 8);
const V = { css: hashOf('css/site.css'), js: hashOf('js/site.js') };

const P = {
  fr: { home: '/', cmds: '/commandes/', tuto: '/tutoriel/', pack: '/pack/', pro: '/pro/', privacy: '/confidentialite/', cookies: '/cookies/', cat: (id) => `/categorie/${id}/`, cmd: (s) => `/c/${s}/` },
  en: { home: '/en/', cmds: '/en/commands/', tuto: '/en/tutorial/', pack: '/en/pack/', pro: '/en/pro/', privacy: '/en/privacy/', cookies: '/en/cookies/', cat: (id) => `/en/category/${id}/`, cmd: (s) => `/en/c/${s}/` },
};
const other = (l) => (l === 'fr' ? 'en' : 'fr');
const catOf = (id) => CATEGORIES.find((c) => c.id === id);
const pages = []; // pour le sitemap : { fr, en }

// ───────── composants ─────────
const ad = (kind) => (cfg.ads.enabled ? `<div class="ad ad-${kind}" data-slot="${kind}" aria-label="Publicité"></div>` : '');

function poster(c, l, big = false) {
  const t = c[l];
  return `<div class="poster${big ? ' big' : ''}" style="--x:${c.x};--y:${c.y};--r:${c.r}"><span class="tag">${esc(catOf(c.cat)[l])}</span><span class="shape"></span><b>${esc(t.poster)}</b><small>${esc(c.code)}</small><span class="ex">${T[l].posterEx}</span></div>`;
}
function card(c, l) {
  const t = c[l];
  const search = `${c.code} ${t.title} ${catOf(c.cat)[l]} ${t.desc}`.toLowerCase();
  return `<article class="card" data-search="${esc(search)}" data-cat="${c.cat}"><a href="${P[l].cmd(c.slug)}" class="cl" aria-label="${esc(t.title)}">${poster(c, l)}</a><div class="cb"><div class="code">${esc(c.code)}</div><h3><a href="${P[l].cmd(c.slug)}">${esc(t.title)}</a></h3><div class="meta"><span>${esc(catOf(c.cat)[l])} · ${c.ratio}</span><button class="mini" type="button" data-copy="#p-${c.slug}" data-slug="${c.slug}">${T[l].cmd.copy}</button></div><pre id="p-${c.slug}" hidden>${esc(c.code + ' : ' + t.prompt)}</pre></div></article>`;
}
function bandForm(l, kind = 'request') {
  const b = T[l].band;
  return `<form class="row" data-form="${kind}" data-ok="${esc(b.ok)}" data-err="${esc(b.err)}" data-invalid="${esc(b.invalid)}" data-sending="${esc(b.sending)}" data-lang="${l}" novalidate><input type="email" name="email" placeholder="${esc(b.ph)}" aria-label="E-mail" autocomplete="email" required><input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true"><button class="btn pri" type="submit">${b.btn}</button><p class="fmsg" role="status" aria-live="polite"></p></form>`;
}
function band(l) {
  const b = T[l].band;
  return `<div class="band"><h3>${b.h}</h3><p>${b.p}</p><form class="col" data-form="request" data-ok="${esc(b.ok)}" data-err="${esc(b.err)}" data-invalid="${esc(b.invalid)}" data-sending="${esc(b.sending)}" data-lang="${l}" novalidate><input type="text" name="note" maxlength="140" placeholder="${esc(b.note)}" aria-label="${esc(b.note)}"><div class="row"><input type="email" name="email" placeholder="${esc(b.ph)}" aria-label="E-mail" autocomplete="email" required><input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true"><button class="btn pri" type="submit">${b.btn}</button></div><p class="fmsg" role="status" aria-live="polite"></p></form></div>`;
}
function tuto(l, h1 = false) {
  const t = T[l].tuto;
  const c = COMMANDS.find((x) => x.slug === 'productglow');
  const cmdText = c[l].prompt;
  return `<section class="tuto" id="tuto" data-copied="${esc(t.copied)}"><div><div class="eyebrow">${t.k}</div><${h1 ? 'h1' : 'h2'} class="t">${t.h}</${h1 ? 'h1' : 'h2'}><p class="lead">${t.l}</p><div class="tsteps">${t.steps.map((s, i) => `<button class="ts" type="button" data-tstep="${i}"><span class="n">${i + 1}</span><span><b>${s[0]}</b>${s[1]}</span></button>`).join('')}</div></div>
<div><div class="demo" id="demo">
<div class="pane" data-p="0"><div class="ph"><span>${t.p1}</span></div><div class="toast" id="ttoast">${t.copied}</div><div class="mcmd"><div class="code">${esc(c.code)}</div><p>${esc(cmdText)}</p><button class="btn pri pulse" id="tcopy" type="button" tabindex="-1">${T[l].cmd.copy}</button></div></div>
<div class="pane" data-p="1"><div class="ph"><span>${t.p2}</span><span>${t.yourTool}</span></div><div class="chat"><div class="bub">${t.bubble}</div><div class="comp"><div class="att"><div class="thumb"></div><small>${t.attach}</small></div><div class="typed" id="typed" data-text="${esc(c.code + ' ' + cmdText)}"></div><div class="send">↑</div></div></div></div>
<div class="pane" data-p="2"><div class="ph"><span>${t.p3}</span></div><div class="res"><div class="rposter"><span class="bottle"></span><b>${t.resH}</b><small>${t.resS}</small></div><div class="rcap">${t.resC}</div></div></div>
</div><div class="dots" id="dots"><i></i><i></i><i></i></div><div class="cta center"><button class="btn gl sm" id="replay" type="button">↻ ${t.replay}</button></div></div></section>`;
}

function layout({ l, key, title, desc, body, alt, noindex, ld, path: pth, authJs, extraJs }) {
  const t = T[l], p = P[l];
  const robots = (!cfg.indexable || noindex) ? '<meta name="robots" content="noindex,nofollow">' : '';
  const hl = alt ? `<link rel="alternate" hreflang="fr" href="${abs(alt.fr)}"><link rel="alternate" hreflang="en" href="${abs(alt.en)}"><link rel="alternate" hreflang="x-default" href="${abs(alt.fr)}">` : '';
  const sw = alt ? `<a class="langsw" href="${alt[other(l)]}" hreflang="${other(l)}" data-lang-switch="${other(l)}">${t.ft.lang}</a>` : '';
  const nav = [[p.cmds, t.nav.cmds, 'cmds'], [p.pack, t.nav.pack, 'pack'], [p.tuto, t.nav.tuto, 'tuto']].map(([h, n, k]) => `<a href="${h}"${key === k ? ' class="on" aria-current="page"' : ''}>${n}</a>`).join('');
  return `<!doctype html><html lang="${t.htmlLang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>${esc(title)}</title><meta name="description" content="${esc(desc)}"><meta name="theme-color" content="#000000"><meta name="color-scheme" content="dark">${robots}<link rel="canonical" href="${abs(pth)}">${hl}
<meta property="og:title" content="${esc(title)}"><meta property="og:description" content="${esc(desc)}"><meta property="og:type" content="website"><meta property="og:url" content="${abs(pth)}"><meta property="og:site_name" content="${cfg.name}"><meta name="twitter:card" content="summary">
<link rel="icon" href="/favicon.svg" type="image/svg+xml"><link rel="preload" href="/fonts/manrope-latin.woff2" as="font" type="font/woff2" crossorigin><link rel="stylesheet" href="/css/site.css?v=${V.css}">${ld ? `<script type="application/ld+json">${JSON.stringify(ld)}</script>` : ''}</head>
<body data-page="${key}" data-lang="${l}"><a class="skip" href="#main">${l === 'fr' ? 'Aller au contenu' : 'Skip to content'}</a>
<header class="hd"><a class="logo" href="${p.home}"><i>/</i>${cfg.name}</a><nav aria-label="Navigation">${nav}</nav><span class="sp"></span>${sw}<a class="btn gl sm hpro" href="${p.pro}">${t.nav.pro}</a></header>
<main id="main">${body}</main>
<footer class="ft"><span>${cfg.name} · ${t.ft.tag}</span><a href="${p.privacy}">${t.ft.privacy}</a><a href="${p.cookies}">${t.ft.cookies}</a></footer>
<script src="/js/site.js?v=${V.js}" defer></script>${extraJs ? `<script src="${extraJs}?v=${V.js}" defer></script>` : ''}</body></html>`;
}
function emit(l, key, pth, o) { write(pth.endsWith('/') ? pth + 'index.html' : pth, layout({ l, key, path: pth, ...o })); }
const alt2 = (fr, en) => ({ fr, en });

// ───────── pages ─────────
function home(l) {
  const t = T[l].home, p = P[l];
  const doms = t.doms.map(([cat, h, d, link]) => `<a class="dom" href="${p.cat(cat)}"><h3>${h}</h3><p>${d}</p><span class="link">${link} ›</span></a>`).join('');
  const featured = ['fashionposter', 'productglow', 'menuhero', 'openhouse', 'matchday', 'coverdrop', 'reelcover', 'eventnight'].map((s) => COMMANDS.find((c) => c.slug === s));
  const body = `<div class="wrap"><div class="eyebrow">${t.eb}</div><h1 class="big">${t.h1a.replace(/ ([?!:;])/g, "\u00a0$1")} <span>${t.h1b}</span></h1><p class="lead">${t.lead}</p>
<div class="cta"><a class="btn pri" href="${p.cmds}">${t.cta1}</a><a class="link" href="${p.tuto}">${t.cta2} ›</a></div>
<div class="who">${t.who.map((x) => `<span>${x}</span>`).join('')}</div>${ad('lb')}
<div class="sec"><h2>${t.domH}</h2><span>${t.domK}</span></div><div class="doms">${doms}</div>
<div class="gap"></div>${tuto(l)}
<div class="sec"><h2>${t.latest}</h2><a class="more" href="${p.cmds}">${t.all} ›</a></div><div class="grid">${featured.map((c) => card(c, l)).join('')}</div>${ad('rect')}${band(l)}</div>`;
  emit(l, 'home', p.home, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.home, P.en.home),
    ld: { '@context': 'https://schema.org', '@graph': [{ '@type': 'WebSite', '@id': abs('/') + '#site', name: cfg.name, alternateName: cfg.alternateNames, url: abs(p.home), inLanguage: T[l].htmlLang, publisher: { '@id': abs('/') + '#org' } }, { '@type': 'Organization', '@id': abs('/') + '#org', name: cfg.name, alternateName: cfg.alternateNames, url: abs('/'), logo: abs('/favicon.svg') }] } });
  if (l === 'fr') pages.push({ fr: P.fr.home, en: P.en.home });
}
function cmdsPage(l) {
  const t = T[l].cmds, p = P[l];
  const chips = [`<button class="chip" data-cat="" aria-pressed="true" type="button">${t.all}</button>`, ...CATEGORIES.map((c) => `<button class="chip" data-cat="${c.id}" aria-pressed="false" type="button">${c[l]}</button>`)].join('');
  const body = `<div class="wrap"><h1 class="big sm">${t.h}</h1><div class="search"><span aria-hidden="true">⌕</span><input id="q" type="search" placeholder="${esc(t.search)}" aria-label="${esc(t.search)}"></div><div class="chips2">${chips}</div>${ad('lb')}<div class="grid" id="list">${COMMANDS.map((c) => card(c, l)).join('')}</div><p class="none" id="none" hidden>${t.none}</p>${band(l)}</div>`;
  emit(l, 'cmds', p.cmds, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.cmds, P.en.cmds) });
  if (l === 'fr') pages.push({ fr: P.fr.cmds, en: P.en.cmds });
}
function catPage(l, c) {
  const t = T[l].cat, p = P[l];
  const list = COMMANDS.filter((x) => x.cat === c.id);
  const body = `<div class="wrap"><div class="crumb"><a href="${p.home}">${T[l].cmd.crumbHome}</a> › <a href="${p.cmds}">${T[l].nav.cmds}</a> › <b>${c[l]}</b></div><h1 class="big sm">${t.h(c[l])}</h1><p class="lead">${c[l + '_d']}</p>${ad('lb')}<div class="grid">${list.map((x) => card(x, l)).join('')}</div><div class="cta"><a class="link" href="${p.cmds}">‹ ${t.back}</a></div>${band(l)}</div>`;
  emit(l, 'cat', p.cat(c.id), { title: t.title(c[l]), desc: c[l + '_d'], body, alt: alt2(P.fr.cat(c.id), P.en.cat(c.id)) });
  if (l === 'fr') pages.push({ fr: P.fr.cat(c.id), en: P.en.cat(c.id) });
}
function cmdPage(l, c) {
  const t = T[l].cmd, p = P[l], ct = c[l], cat = catOf(c.cat);
  const same = COMMANDS.filter((x) => x.cat === c.cat && x.slug !== c.slug);
  const rel = [...same, ...COMMANDS.filter((x) => x.cat !== c.cat)].slice(0, 3);
  const tools = [['ChatGPT', 'https://chatgpt.com/'], ['Gemini', 'https://gemini.google.com/'], ['Midjourney', 'https://www.midjourney.com/']];
  const fullText = `${c.code} : ${ct.prompt}`;
  const body = `<div class="wrap"><div class="crumb"><a href="${p.home}">${t.crumbHome}</a> › <a href="${p.cat(c.cat)}">${cat[l]}</a> › <b>${esc(c.code)}</b></div>
<div class="fiche"><div>${poster(c, l, true)}${ad('rect')}</div><div><div class="eyebrow">${cat[l]}</div><h1>${esc(ct.title)}</h1><p class="lead sm">${esc(ct.desc)}</p>
<div class="chips"><span>${t.ratio} : ${c.ratio}</span><span>${t.compat} ${tools.map((x) => x[0]).join(', ')}</span></div>
<div class="cmd"><pre id="p-${c.slug}">${esc(fullText)}</pre><button class="btn pri big" type="button" data-copy="#p-${c.slug}" data-slug="${c.slug}" data-after="1">${t.copy}</button></div><p class="hint">${t.notTested}</p>${ad('lb')}
<h2 class="h3">${t.steps}</h2><ol class="steps"><li>${t.s1}</li><li>${t.s2}</li><li>${t.s3}</li></ol>
<div class="test">${tools.map(([n, u]) => `<a class="btn gl sm" href="${u}" target="_blank" rel="noopener noreferrer nofollow" data-test="${n}">${t.testOn} ${n} ↗</a>`).join('')}</div>
<p class="tip"><b>${t.tip} :</b> ${t.tipT}</p>
<div class="after" id="after"><b>${t.afterT}</b> ${t.afterB}<div class="grid">${rel.map((x) => card(x, l)).join('')}</div></div></div></div>
${same.length ? `<div class="sec"><h2>${t.similar}</h2></div><div class="grid">${same.map((x) => card(x, l)).join('')}</div>` : ''}${band(l)}</div>`;
  const ld = { '@context': 'https://schema.org', '@type': 'BreadcrumbList', itemListElement: [{ '@type': 'ListItem', position: 1, name: t.crumbHome, item: abs(p.home) }, { '@type': 'ListItem', position: 2, name: cat[l], item: abs(p.cat(c.cat)) }, { '@type': 'ListItem', position: 3, name: c.code, item: abs(p.cmd(c.slug)) }] };
  emit(l, 'cmd', p.cmd(c.slug), { title: t.title(c.code, ct.title), desc: ct.desc, body, alt: alt2(P.fr.cmd(c.slug), P.en.cmd(c.slug)), ld });
  if (l === 'fr') pages.push({ fr: P.fr.cmd(c.slug), en: P.en.cmd(c.slug) });
}
function tutoPage(l) {
  const t = T[l].tuto, p = P[l];
  const body = `<div class="wrap">${tuto(l, true)}${ad('lb')}<div class="sec"><h2>${t.faqH}</h2></div><div class="faq">${t.faq.map(([q, a]) => `<details><summary>${q}</summary><p>${a}</p></details>`).join('')}</div><div class="cta"><a class="btn pri" href="${p.cmds}">${T[l].home.cta1}</a></div>${band(l)}</div>`;
  const ld = { '@context': 'https://schema.org', '@type': 'FAQPage', mainEntity: t.faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) };
  emit(l, 'tuto', p.tuto, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.tuto, P.en.tuto), ld });
  if (l === 'fr') pages.push({ fr: P.fr.tuto, en: P.en.tuto });
}
function packText(l) {
  const head = l === 'fr'
    ? 'Tu es mon assistant de visuels publicitaires. Quand mon message commence par « / » suivi d’un nom de commande, applique cette commande à l’image jointe. Si aucune image n’est jointe, demande-moi de l’envoyer. Garde toujours le produit, le visage ou le lieu identiques à la photo.'
    : 'You are my advertising visuals assistant. When my message starts with “/” followed by a command name, apply that command to the attached image. If no image is attached, ask me to send one. Always keep the product, face or place identical to the photo.';
  return head + '\n\n' + COMMANDS.map((c) => `${c.code} : ${c[l].prompt}`).join('\n\n');
}
function packPage(l) {
  const t = T[l].pack, p = P[l];
  const body = `<div class="wrap"><div class="eyebrow">${t.k}</div><h1 class="big sm">${t.h}</h1><p class="lead">${t.l}</p>
<div class="pack"><div class="ver">● ${t.ver} · ${COMMANDS.length} ${l === 'fr' ? 'commandes' : 'commands'}</div><div class="cmd"><pre id="pack-text" style="max-height:200px">${esc(packText(l))}</pre><button class="btn pri big" type="button" data-copy="#pack-text" data-slug="pack">${t.copy}</button></div>
<h2 class="h3">${t.how}</h2><div class="how2"><div><b>${t.h1}</b><p>${t.t1}</p></div><div><b>${t.h2}</b><p>${t.t2}</p></div></div><p class="hint">${t.note}</p>
<h2 class="h3">${t.inc}</h2><div class="inc">${COMMANDS.map((c) => `<a href="${p.cmd(c.slug)}"><code>${c.code}</code></a>`).join('')}</div></div>${ad('lb')}
<div class="band"><h3 style="font-size:20px">${t.notify}</h3>${bandForm(l, 'newsletter')}</div></div>`;
  emit(l, 'pack', p.pack, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.pack, P.en.pack) });
  if (l === 'fr') pages.push({ fr: P.fr.pack, en: P.en.pack });
}
function proPage(l) {
  const t = T[l].pro, b = T[l].band;
  const price = l === 'fr' ? cfg.pro.price : cfg.pro.priceEn;
  const body = `<div class="wrap narrow"><div class="eyebrow">${t.k}</div><h1 class="big sm">${t.h}</h1><div class="plans"><div class="plan"><h3>${t.free}</h3><div class="price">0 €</div><ul><li>${t.f1}</li><li>${t.f2}</li><li>${t.f3}</li></ul></div>
<div class="plan hot"><h3>${t.pro} <span class="soon">${t.soon}</span></h3><div class="price">${price} <small>${t.mo}</small></div><ul><li>${t.p1}</li><li>${t.p2}</li><li>${t.p3}</li><li>${t.p4}</li></ul>${bandForm(l, 'waitlist').replace('>' + b.btn + '<', '>' + t.wl + '<')}<p class="hint">${t.note}</p></div></div></div>`;
  emit(l, 'pro', P[l].pro, { title: t.title, desc: t.desc, body, alt: alt2(P.fr.pro, P.en.pro) });
  if (l === 'fr') pages.push({ fr: P.fr.pro, en: P.en.pro });
}
function legalPage(l, kind) {
  const t = T[l].legal, key = kind === 'privacy' ? 'p' : 'c';
  const body = `<div class="wrap narrow prose"><h1 class="big sm">${t[key + 'H']}</h1>${t[key + 'Body'].map((x) => `<p>${x}</p>`).join('')}</div>`;
  emit(l, kind, P[l][kind], { title: t[key + 'Title'], desc: t[key + 'Desc'], body, alt: alt2(P.fr[kind], P.en[kind]) });
  if (l === 'fr') pages.push({ fr: P.fr[kind], en: P.en[kind] });
}

function adminPage() {
  const body = `<div class="wrap"><div class="eyebrow">Administration</div><h1 class="big sm">Suivi de SlashAtlas</h1>
<form id="adm-out" class="adm-login" novalidate><p class="lead">Accès réservé à l’administrateur. Utilisez votre compte Afrolook.</p><label>E-mail<input type="email" name="email" autocomplete="username" required></label><label>Mot de passe<input type="password" name="password" autocomplete="current-password" required></label><button class="btn pri big" type="submit">Se connecter</button><p class="fmsg" id="auth-msg" role="status" aria-live="polite"></p></form>
<div id="adm-no" hidden><p class="lead">Ce compte n’a pas accès à l’administration.</p><button class="btn gl" type="button" data-logout>Changer de compte</button></div>
<div id="adm" hidden></div></div>`;
  emit('fr', 'admin', '/admin/', { title: 'Administration | SlashAtlas', desc: 'Tableau de bord privé de SlashAtlas : audience, commandes copiées et inscriptions. Accès réservé à l’administrateur.', body, noindex: true, extraJs: '/js/admin.js' });
}
function notFound() {
  const t = T.fr.nf;
  write('404.html', layout({ l: 'fr', key: '404', path: '/404.html', title: t.title, desc: t.p, noindex: true, body: `<div class="wrap narrow center"><h1 class="big sm">${t.h}</h1><p class="lead">${t.p}</p><a class="btn pri" href="/commandes/">${t.btn}</a></div>` }));
}

// ───────── génération ─────────
fs.rmSync(dist, { recursive: true, force: true });
fs.mkdirSync(dist, { recursive: true });
fs.cpSync(path.join(root, 'static'), dist, { recursive: true });
for (const l of ['fr', 'en']) {
  home(l); cmdsPage(l); tutoPage(l); packPage(l); proPage(l); legalPage(l, 'privacy'); legalPage(l, 'cookies');
  for (const c of CATEGORIES) catPage(l, c);
  for (const c of COMMANDS) cmdPage(l, c);
}
adminPage();
notFound();
const xml = (u) => `<url><loc>${abs(u.fr)}</loc><xhtml:link rel="alternate" hreflang="fr" href="${abs(u.fr)}"/><xhtml:link rel="alternate" hreflang="en" href="${abs(u.en)}"/></url>\n<url><loc>${abs(u.en)}</loc><xhtml:link rel="alternate" hreflang="fr" href="${abs(u.fr)}"/><xhtml:link rel="alternate" hreflang="en" href="${abs(u.en)}"/></url>`;
write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${pages.map(xml).join('\n')}\n</urlset>\n`);
write('robots.txt', cfg.indexable ? `User-agent: *\nAllow: /\nDisallow: /api/\nSitemap: ${abs('/sitemap.xml')}\n` : 'User-agent: *\nDisallow: /\n');
console.log(`SlashAtlas : ${pages.length * 2 + 1} pages (${COMMANDS.length} commandes, ${CATEGORIES.length} catégories), indexable=${cfg.indexable}`);
