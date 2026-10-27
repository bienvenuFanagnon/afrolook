// SlashAtlas : « J'aime » sur les commandes (celles du site comme celles de la communauté), avec ou sans compte.
// Une personne connectée est reconnue par son compte, une personne sans compte par un identifiant anonyme de son appareil : un seul J'aime par commande dans les deux cas.
// Les totaux sont rangés dans un seul document (SlashAtlasGlobals/likes) pour que la liste complète s'affiche en une lecture ;
// chaque J'aime est aussi gardé (StudioLikes/{commande}_{identité}). Sans compte, rien d'autre que l'identifiant anonyme n'est conservé.
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const studio = require('./studio');
const COMMANDS = require('./commands.json');

const db = () => getFirestore();
const { fail } = studio;
const SLUG = /^[a-z0-9-]{2,48}$/;
const ANON = /^a[a-z0-9]{15,40}$/;
const DAILY_MAX = 200; // actions par identité et par jour : freine les scripts sans gêner une vraie personne

let cache = { at: 0, v: {} };
/** Totaux par commande (seulement ceux qui ont au moins un J'aime) : une lecture, mise en cache 2 minutes dans la fonction. */
async function counts() {
  if (Date.now() - cache.at < 120000) return cache.v;
  const s = await db().collection('SlashAtlasGlobals').doc('likes').get();
  const n = (s.exists && s.data().n) || {};
  const v = {};
  for (const [k, c] of Object.entries(n)) if (c > 0) v[k] = c;
  cache = { at: Date.now(), v };
  return v;
}
async function exists(slug) {
  if (COMMANDS.commands[slug]) return true;
  if (/^u-[a-f0-9]{10}$/.test(slug)) { const s = await db().collection('StudioCommunity').doc(slug.slice(2)).get(); return s.exists && s.data().status === 'published'; }
  return false;
}
/** Identités de la personne : son compte (si connectée) et/ou l'identifiant anonyme de son appareil. */
function identity(u, b) {
  const keys = [];
  if (u && u.uid) keys.push('u_' + u.uid);
  const anon = String((b && b.anon) || '');
  if (ANON.test(anon)) keys.push('a_' + anon);
  return keys.length ? { keys, primary: keys[0] } : null;
}
async function dailyCap(key) {
  const d = studio.day(), ref = db().collection('StudioCounters').doc(`lk_${d}_${key}`);
  await db().runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if ((s.exists ? s.data().n : 0) >= DAILY_MAX) throw fail(429, 'daily_limit');
    tx.set(ref, { n: FieldValue.increment(1), day: d }, { merge: true });
  });
}
/** Ajoute ou retire le J'aime (b.on = true / false pour forcer, sinon on inverse). Connecté + appareil anonyme : le même J'aime n'est jamais compté deux fois. */
async function toggle(who, b) {
  const slug = String((b && b.slug) || '').slice(0, 48);
  if (!who || !SLUG.test(slug) || !(await exists(slug))) throw fail(404, 'unknown_command');
  await dailyCap(who.primary);
  const refs = who.keys.map((k) => db().collection('StudioLikes').doc(`${slug}_${k}`)), gref = db().collection('SlashAtlasGlobals').doc('likes');
  const want = b.on === true ? true : b.on === false ? false : null;
  const r = await db().runTransaction(async (tx) => {
    const [docs, g] = await Promise.all([Promise.all(refs.map((x) => tx.get(x))), tx.get(gref)]);
    const have = docs.filter((d) => d.exists), has = have.length > 0, cur = ((g.exists && g.data().n) || {})[slug] || 0, next = want === null ? !has : want;
    if (next === has) return { liked: has, count: cur };
    if (next) { tx.set(refs[0], { slug, uid: who.keys[0], at: FieldValue.serverTimestamp() }); tx.set(gref, { n: { [slug]: FieldValue.increment(1) } }, { merge: true }); return { liked: true, count: cur + 1 }; }
    have.forEach((d) => tx.delete(d.ref));
    tx.set(gref, { n: { [slug]: FieldValue.increment(-have.length) } }, { merge: true });
    return { liked: false, count: Math.max(0, cur - have.length) };
  });
  cache.at = 0;
  return r;
}
/** Les commandes aimées par cette personne (compte et appareil confondus). */
async function mine(who) {
  if (!who) return { slugs: [] };
  const out = new Set();
  for (const k of who.keys) { const q = await db().collection('StudioLikes').where('uid', '==', k).limit(3000).get(); q.docs.forEach((d) => out.add(d.data().slug)); }
  return { slugs: [...out] };
}

module.exports = { counts, toggle, mine, identity };
