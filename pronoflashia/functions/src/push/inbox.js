'use strict';
// Boîte de réception des notifications, sans compte : chaque abonnement (navigateur) a sa propre liste, retrouvée avec son adresse d'envoi.
// Chaque notification porte un identifiant (n) dans son lien : ouvrir la page marque la notification comme lue. Le compteur de non lues
// est gardé dans le document de l'abonnement (une seule lecture par page) et recalculé exactement à chaque ouverture de la liste.
// Gardées : 50 notifications au plus, 30 jours au plus, par abonnement.

const crypto = require('crypto');
const { idOf, validEndpoint } = require('./subs');

const COL = 'push_inbox';
const MAX_ITEMS = 50;
const KEEP_MS = 30 * 864e5;
const PAGE = 10;
const NID = /^[a-f0-9]{8,16}$/;

class InboxError extends Error { constructor(status, message) { super(message); this.status = status; } }

/** Identifiant de la notification, ajouté une seule fois au lien (même valeur pour tous les abonnés). */
function prepare(payload) {
  if (payload._nid) return payload;
  const nid = crypto.createHash('sha1').update(`${payload.url}|${payload.titre}|${Date.now()}|${Math.random()}`).digest('hex').slice(0, 12);
  payload._nid = nid;
  if (typeof payload.url === 'string' && payload.url.startsWith('/') && payload.inbox !== false) payload.url += `${payload.url.includes('?') ? '&' : '?'}n=${nid}`;
  return payload;
}

/** Enregistre la notification dans la boîte de l'abonné. */
async function add(db, sub, payload, now) {
  await db.collection(COL).doc(`${sub.id}_${payload._nid}`).set({
    id: `${sub.id}_${payload._nid}`, sub: sub.id, nid: payload._nid, titre: String(payload.titre || '').slice(0, 120), corps: String(payload.corps || '').slice(0, 220),
    url: String(payload.url || '/'), image: payload.image || null, au: (now || new Date()).toISOString(), lu: false,
  });
}

async function load(db, endpoint) {
  if (!validEndpoint(endpoint)) throw new InboxError(400, 'Abonnement invalide.');
  const d = await db.collection('push_subs').doc(idOf(endpoint)).get();
  if (!d.exists) throw new InboxError(404, 'Abonnement inconnu.');
  return d.data();
}

/** Nombre de non lues (sans lire la liste). */
async function count(db, endpoint) {
  const s = await load(db, endpoint);
  return { nonLus: Math.max(0, s.nl || 0) };
}

/** Page de la liste : { items, nonLus, suite }. offset : nombre de notifications déjà affichées. */
async function list(db, endpoint, offset, now) {
  const s = await load(db, endpoint);
  const docs = (await db.collection(COL).where('sub', '==', s.id).get()).docs.map((d) => d.data()).sort((a, b) => (a.au < b.au ? 1 : -1));
  const limit = new Date((now || new Date()).getTime() - KEEP_MS).toISOString();
  const keep = docs.filter((x, i) => i < MAX_ITEMS && x.au >= limit);
  for (const x of docs) if (!keep.includes(x)) await db.collection(COL).doc(x.id).delete();
  const nonLus = keep.filter((x) => !x.lu).length;
  if ((s.nl || 0) !== nonLus) await db.collection('push_subs').doc(s.id).set(Object.assign({}, s, { nl: nonLus }));
  const from = Math.max(0, Math.floor(Number(offset)) || 0);
  const items = keep.slice(from, from + PAGE).map((x) => ({ id: x.nid, titre: x.titre, corps: x.corps, url: x.url, image: x.image, au: x.au, lu: !!x.lu }));
  return { items, nonLus, suite: from + PAGE < keep.length, total: keep.length };
}

/** Marque une notification (id) ou toutes (tous) comme lues. */
async function markRead(db, endpoint, nid, tous) {
  const s = await load(db, endpoint);
  let n = 0;
  if (tous) {
    for (const d of (await db.collection(COL).where('sub', '==', s.id).get()).docs) { const x = d.data(); if (!x.lu) { await db.collection(COL).doc(x.id).set(Object.assign({}, x, { lu: true })); n++; } }
  } else {
    if (!NID.test(String(nid || ''))) throw new InboxError(400, 'Notification invalide.');
    const ref = db.collection(COL).doc(`${s.id}_${nid}`);
    const d = await ref.get();
    if (d.exists && !d.data().lu) { await ref.set(Object.assign({}, d.data(), { lu: true })); n = 1; }
  }
  const nl = tous ? 0 : Math.max(0, (s.nl || 0) - n);
  if (nl !== (s.nl || 0)) await db.collection('push_subs').doc(s.id).set(Object.assign({}, s, { nl }));
  return { nonLus: nl };
}

module.exports = { COL, PAGE, MAX_ITEMS, InboxError, prepare, add, count, list, markRead };
