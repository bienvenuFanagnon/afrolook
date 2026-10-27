// Pages publiques des commandes communautaires : /c/u-<id>/ et /createur/<pseudo>/ (et leurs versions anglaises).
// Le site étant statique, la fonction prend une « coquille » de page générée au déploiement (/_shell/*.html : en-tête, pied, styles) et y insère le contenu :
// le titre, la description et l'image d'aperçu (pour WhatsApp, Facebook, Google) sont donc dans le HTML envoyé, sans attendre du JavaScript.
const community = require('./community');
const studio = require('./studio');

const SITE = 'https://slashatlas-studio.web.app';
const shells = new Map();
async function shell(kind, l) {
  const key = `${kind}-${l}`, hit = shells.get(key);
  if (hit && Date.now() - hit.at < 300000) return hit.html;
  const r = await fetch(`${SITE}/_shell/${key}.html`);
  if (!r.ok) throw new Error('shell ' + key + ' ' + r.status);
  const html = await r.text();
  shells.set(key, { at: Date.now(), html });
  return html;
}
const e = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const cut = (s, n) => (String(s).length > n ? String(s).slice(0, n - 1).trimEnd() + '…' : String(s));
const fill = (html, map) => Object.entries(map).reduce((h, [k, v]) => h.split(k).join(v), html);

const TX = {
  fr: {
    home: 'Accueil', cmds: 'Commandes', kicker: 'Commande de la communauté', by: 'Créée par', uses: (n) => `${n} utilisation${n > 1 ? 's' : ''}`, free: 'Gratuite', paid: 'Payante',
    gen: 'Générer ici', share: 'Partager', copy: 'Copier la commande', copied: 'Copié ✓', copyH: 'Commande gratuite : copiez-la dans votre outil IA', paidNote: 'Cette commande est payante : son texte reste privé. Générez l’affiche ici, ou débloquez le texte pour 1 crédit (qui revient à son créateur).', unlock: 'Débloquer et copier · 1 crédit', unlockH: 'Texte de la commande', cr: 'cr',
    creator: 'Créateur', cc: (n) => `${n} commande${n > 1 ? 's' : ''} publiée${n > 1 ? 's' : ''}`, shareProfile: 'Partager ce profil', otherBy: 'Ses commandes',
    gone: 'Cette commande n’existe pas ou n’est plus disponible.', goneBtn: 'Voir toutes les commandes', goneC: 'Ce créateur n’a pas de commande publiée.',
    titleC: (t) => `${t} · commande de la communauté | SlashAtlas`, titleP: (h) => `@${h} · créateur de commandes | SlashAtlas`, descP: (h, n) => `Découvrez les ${n} commande${n > 1 ? 's' : ''} d’affiches IA créée${n > 1 ? 's' : ''} par @${h} sur SlashAtlas et utilisez-les avec votre photo.`,
  },
  en: {
    home: 'Home', cmds: 'Commands', kicker: 'Community command', by: 'Created by', uses: (n) => `${n} use${n > 1 ? 's' : ''}`, free: 'Free', paid: 'Paid',
    gen: 'Generate here', share: 'Share', copy: 'Copy the command', copied: 'Copied ✓', copyH: 'Free command: copy it into your AI tool', paidNote: 'This command is paid: its text stays private. Generate the poster here, or unlock the text for 1 credit (which goes to its creator).', unlock: 'Unlock and copy · 1 credit', unlockH: 'Command text', cr: 'cr',
    creator: 'Creator', cc: (n) => `${n} published command${n > 1 ? 's' : ''}`, shareProfile: 'Share this profile', otherBy: 'Their commands',
    gone: 'This command does not exist or is no longer available.', goneBtn: 'See all commands', goneC: 'This creator has no published command.',
    titleC: (t) => `${t} · community command | SlashAtlas`, titleP: (h) => `@${h} · command creator | SlashAtlas`, descP: (h, n) => `Discover the ${n} AI poster command${n > 1 ? 's' : ''} created by @${h} on SlashAtlas and use them with your photo.`,
  },
};
const P = { fr: { home: '/', cmds: '/commandes/', try: '/generer/', cmd: (id) => `/c/u-${id}/`, cr: (h) => `/createur/${h}/` }, en: { home: '/en/', cmds: '/en/commands/', try: '/en/generate/', cmd: (id) => `/en/c/u-${id}/`, cr: (h) => `/en/creator/${h}/` } };
const LOCK = '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>';
const THUMB = '<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"><path d="M7 10v12"/><path d="M15 5.88 14 10h5.83a2 2 0 0 1 1.92 2.56l-2.33 8A2 2 0 0 1 17.5 22H4a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2h2.76a2 2 0 0 0 1.79-1.11L12 2a3.13 3.13 0 0 1 3 3.88Z"/></svg>';
const likeBtn = (slug, l, cls = '') => `<button class="lk-btn${cls ? ' ' + cls : ''}" type="button" data-like="${slug}" aria-pressed="false" aria-label="${l === 'en' ? 'Like this command (public)' : 'J’aime cette commande (visible par tous)'}">${THUMB}<b hidden></b></button>`;
const other = (l) => (l === 'fr' ? 'en' : 'fr');
const prev = (id) => `/api/community/preview/${id}.jpg`;
const jsonIn = (o) => JSON.stringify(o).replace(/</g, '\\u003c');

const ORIGIN = 'https://slashatlas.com';
function page(l, kind, { title, desc, path, altFr, altEn, img, body, data, status, ld }) {
  return shell(kind, l).then((html) => ({
    status: status || 200,
    html: fill(html, { '@@TITLE@@': e(title), '@@DESC@@': e(desc), '/@@URL@@': path, '/@@ALTFR@@': altFr, '/@@ALTEN@@': altEn, '/@@IMG@@': img, '@@BODY@@': body, '@@DATA@@': jsonIn(data || {}), '"@@LD@@"': jsonIn(ld || {}) }),
  }));
}

async function commandPage(l, id) {
  const t = TX[l], p = P[l];
  let c;
  try { c = await community.publicCmd(id); } catch (err) {
    return page(l, 'cmd', { title: t.gone, desc: t.gone, path: p.cmd(id), altFr: P.fr.cmd(id), altEn: P.en.cmd(id), img: '/og.jpg', status: 404, data: {}, body: `<div class="wrap narrow center"><h1 class="big sm">${e(t.gone)}</h1><a class="btn pri" href="${p.cmds}">${e(t.goneBtn)}</a></div>` });
  }
  const title = l === 'en' ? c.te : c.tf, desc = l === 'en' ? c.de : c.df, cat = l === 'en' ? c.ke : c.kf, cost = studio.GEN_COST + (c.mode === 'paid' ? (await community.settings()).extra : 0);
  const free = c.mode === 'free', prompt = free ? (l === 'en' ? c.pe : c.pf) : '';
  const body = `<div class="wrap"><div class="crumb"><a href="${p.home}">${t.home}</a> › <a href="${p.cmds}">${t.cmds}</a> › <b>@${e(c.h)}</b></div>
<div class="cv"><div class="cv-img"><img src="${prev(id)}" alt="${e(title)}" style="aspect-ratio:${e(String(c.r).replace(':', '/'))}"></div>
<div class="cv-info"><div class="eyebrow">${t.kicker}</div><h1 class="big sm">${e(title)}</h1><p class="lead">${e(desc)}</p>
<div class="chips"><span>${e(cat)}</span><span>${free ? t.free : LOCK + ' ' + t.paid}</span><span>${e(c.r)}</span></div>
<p class="cv-by">${t.by} <a href="${p.cr(c.h)}">@${e(c.h)}</a>${c.u ? ' · ' + t.uses(c.u) : ''}</p>
<div class="acts big"><a class="btn pri" href="${p.try}?c=u-${id}" data-try="u-${id}">${t.gen} <small>· ${cost} ${t.cr}</small></a><button class="btn gl" type="button" id="cv-share">${t.share}</button>${likeBtn('u-' + id, l, 'big')}</div>
${free && prompt ? `<div class="cv-copy"><b>${t.copyH}</b><pre id="cv-prompt">${e(prompt)}</pre><button class="btn gl" type="button" id="cv-copy" data-done="${e(t.copied)}">${t.copy}</button></div>` : `<div class="cv-copy"><p class="hint" style="margin:0">${t.paidNote}</p><button class="btn gl" type="button" id="cv-buy">${t.unlock}</button><p class="fmsg err" id="cv-msg" role="alert"></p><div id="cv-unlocked" hidden><b>${t.unlockH}</b><pre></pre><button class="btn gl" type="button">${t.copy}</button></div></div>`}
</div></div></div>`;
  const url = ORIGIN + p.cmd(id);
  const ld = { '@context': 'https://schema.org', '@graph': [
    { '@type': 'CreativeWork', '@id': url + '#cmd', name: title, description: desc, url, image: ORIGIN + prev(id), inLanguage: l, genre: cat, isAccessibleForFree: free, author: { '@type': 'Person', name: '@' + c.h, url: ORIGIN + p.cr(c.h) }, publisher: { '@type': 'Organization', name: 'SlashAtlas', url: ORIGIN + '/' } },
    { '@type': 'BreadcrumbList', itemListElement: [{ '@type': 'ListItem', position: 1, name: t.home, item: ORIGIN + p.home }, { '@type': 'ListItem', position: 2, name: t.cmds, item: ORIGIN + p.cmds }, { '@type': 'ListItem', position: 3, name: title, item: url }] },
  ] };
  return page(l, 'cmd', { ld, title: cut(t.titleC(title), 74), desc: cut(desc, 200), path: p.cmd(id), altFr: P.fr.cmd(id), altEn: P.en.cmd(id), img: prev(id), body, data: { id, h: c.h, t: title } });
}

async function creatorPage(l, handle) {
  const t = TX[l], p = P[l];
  let c;
  try { c = await community.creatorProfile(handle); } catch (err) {
    return page(l, 'creator', { title: t.goneC, desc: t.goneC, path: p.cr(handle), altFr: P.fr.cr(handle), altEn: P.en.cr(handle), img: '/og.jpg', status: 404, data: {}, body: `<div class="wrap narrow center"><h1 class="big sm">${e(t.goneC)}</h1><a class="btn pri" href="${p.cmds}">${e(t.goneBtn)}</a></div>` });
  }
  const cards = c.commands.map((x) => `<a class="cv-card" href="${p.cmd(x.id)}"><img src="${prev(x.id)}" alt="${e(l === 'en' ? x.te : x.tf)}" loading="lazy" style="aspect-ratio:${e(String(x.r).replace(':', '/'))}"><b>${e(l === 'en' ? x.te : x.tf)}</b><small>${e(l === 'en' ? x.ke : x.kf)} · ${x.mode === 'free' ? t.free : LOCK + ' ' + t.paid}${x.u ? ' · ' + t.uses(x.u) : ''}</small><span class="lk-ro" data-likecount="u-${x.id}" hidden></span></a>`).join('');
  const body = `<div class="wrap"><div class="crumb"><a href="${p.home}">${t.home}</a> › <a href="${p.cmds}">${t.cmds}</a> › <b>@${e(c.handle)}</b></div>
<div class="eyebrow">${t.creator}</div><h1 class="big sm">@${e(c.handle)}</h1><div class="chips"><span>${t.cc(c.commands.length)}</span>${c.uses ? `<span>${t.uses(c.uses)}</span>` : ''}</div>
<div class="acts"><button class="btn gl" type="button" id="cv-share">${t.shareProfile}</button></div>
<h2 class="refh">${t.otherBy}</h2><div class="cv-grid">${cards}</div></div>`;
  const curl = ORIGIN + p.cr(c.handle);
  const ld = { '@context': 'https://schema.org', '@graph': [
    { '@type': 'ProfilePage', url: curl, inLanguage: l, mainEntity: { '@type': 'Person', name: '@' + c.handle, url: curl, description: t.descP(c.handle, c.commands.length) } },
    { '@type': 'ItemList', itemListElement: c.commands.slice(0, 30).map((x, i) => ({ '@type': 'ListItem', position: i + 1, url: ORIGIN + p.cmd(x.id), name: l === 'en' ? x.te : x.tf })) },
    { '@type': 'BreadcrumbList', itemListElement: [{ '@type': 'ListItem', position: 1, name: t.home, item: ORIGIN + p.home }, { '@type': 'ListItem', position: 2, name: t.cmds, item: ORIGIN + p.cmds }, { '@type': 'ListItem', position: 3, name: '@' + c.handle, item: curl }] },
  ] };
  return page(l, 'creator', { ld, title: cut(t.titleP(c.handle), 74), desc: cut(t.descP(c.handle, c.commands.length), 200), path: p.cr(c.handle), altFr: P.fr.cr(c.handle), altEn: P.en.cr(c.handle), img: prev(c.commands[0].id), body, data: { h: c.handle } });
}

/** Plan du site des commandes communautaires et des profils : une entrée par langue, avec les liens hreflang. */
async function sitemap() {
  const list = await community.publicList();
  const alt = (fr, en) => `<xhtml:link rel="alternate" hreflang="fr" href="${ORIGIN}${fr}"/><xhtml:link rel="alternate" hreflang="en" href="${ORIGIN}${en}"/><xhtml:link rel="alternate" hreflang="x-default" href="${ORIGIN}${fr}"/>`;
  const url = (path, fr, en, at) => `<url><loc>${ORIGIN}${path}</loc>${at ? '<lastmod>' + new Date(at).toISOString().slice(0, 10) + '</lastmod>' : ''}${alt(fr, en)}</url>`;
  const rows = [];
  for (const c of list) { rows.push(url(P.fr.cmd(c.id), P.fr.cmd(c.id), P.en.cmd(c.id), c.at)); rows.push(url(P.en.cmd(c.id), P.fr.cmd(c.id), P.en.cmd(c.id), c.at)); }
  const handles = [...new Set(list.map((c) => c.h).filter(Boolean))];
  for (const h of handles) { rows.push(url(P.fr.cr(h), P.fr.cr(h), P.en.cr(h))); rows.push(url(P.en.cr(h), P.fr.cr(h), P.en.cr(h))); }
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${rows.join('\n')}\n</urlset>\n`;
}

module.exports = { commandPage, creatorPage, sitemap };
