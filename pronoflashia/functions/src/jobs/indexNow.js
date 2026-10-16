'use strict';
// Référencement automatique : protocole IndexNow (Bing, Yandex, Seznam, Naver). Chaque nouvelle page de match ou d'analyse est signalée
// une seule fois, dès sa publication. Google n'accepte pas IndexNow : il découvre les pages par le sitemap (robots.txt + Search Console).
// La clé est générée une fois (config/seo) et publiée à /{clé}.txt par le routeur, ce qui prouve que le site nous appartient.

const crypto = require('crypto');
const { pathFor } = require('../render/i18n');
const { addDays } = require('./helpers');

const ENDPOINT = 'https://api.indexnow.org/indexnow';
const KEY_RE = /^[a-f0-9]{32}$/;

async function getKey(db) {
  const ref = db.collection('config').doc('seo');
  const d = await ref.get();
  const cur = d.exists ? d.data() : {};
  if (cur.indexNowKey && KEY_RE.test(cur.indexNowKey)) return cur.indexNowKey;
  const key = crypto.randomBytes(16).toString('hex');
  await ref.set({ indexNowKey: key }, { merge: true });
  return key;
}

const pagesOf = (m) => {
  const out = [{ kind: 'match', paths: [pathFor('fr', 'match', m), pathFor('en', 'match', m)] }];
  if (m.prono && m.prono.marches) out.push({ kind: 'analyse', paths: [pathFor('fr', 'analysis', m), pathFor('en', 'analysis', m)] });
  return out;
};

/**
 * Signale les pages nouvelles (match et analyse) à IndexNow. Renvoie { envoyees, matchs } ou { ignore: raison }.
 * deps : { db, site, now, fetchImpl, max }. Une erreur réseau ne casse pas la tâche : elle est renvoyée dans `erreur`.
 */
async function submitNewUrls({ db, site, now, fetchImpl, max }) {
  if (!site.indexable) return { ignore: 'site non indexable' };
  const origin = site.origine;
  let host;
  try { host = new URL(origin).host; } catch { return { ignore: 'origine invalide' }; }
  const f = fetchImpl || fetch;
  const snap = await db.collection('matches').where('coupDEnvoi', '>=', addDays(now, -1).toISOString()).get();
  const rows = snap.docs.map((d) => d.data()).filter((m) => m.statut !== 'reporte' && m.prono && m.prono.principal && m.prono.visible !== false);
  const todo = [];
  for (const m of rows) {
    const done = m.indexNow || {};
    const pages = pagesOf(m).filter((p) => !done[p.kind]);
    if (pages.length) todo.push({ m, pages });
  }
  const seo = (await db.collection('config').doc('seo').get()).data() || {};
  const staticDue = !seo.staticEnvoyeLe;
  const batch = todo.slice(0, max || 100);
  if (!batch.length && !staticDue) return { envoyees: 0, matchs: 0 };

  const urls = new Set();
  for (const { pages } of batch) for (const p of pages) for (const path of p.paths) urls.add(origin + path);
  if (staticDue) for (const n of ['home', 'coupon', 'bilan']) for (const l of ['fr', 'en']) urls.add(origin + pathFor(l, n));

  const key = await getKey(db);
  let res;
  try {
    res = await f(ENDPOINT, { method: 'POST', headers: { 'Content-Type': 'application/json; charset=utf-8' }, body: JSON.stringify({ host, key, keyLocation: `${origin}/${key}.txt`, urlList: [...urls] }) });
  } catch (e) { return { envoyees: 0, matchs: 0, erreur: `IndexNow injoignable : ${e.message}` }; }
  if (res.status !== 200 && res.status !== 202) return { envoyees: 0, matchs: 0, erreur: `IndexNow a répondu ${res.status}` };

  const stamp = now.toISOString();
  for (const { m, pages } of batch) {
    const indexNow = Object.assign({}, m.indexNow || {});
    for (const p of pages) indexNow[p.kind] = stamp;
    await db.collection('matches').doc(m.id).set({ indexNow }, { merge: true });
  }
  if (staticDue) await db.collection('config').doc('seo').set({ staticEnvoyeLe: stamp }, { merge: true });
  return { envoyees: urls.size, matchs: batch.length };
}

module.exports = { submitNewUrls, getKey, KEY_RE, ENDPOINT };
