'use strict';
// Abonnements aux notifications : stockés sous push_subs/{empreinte}. L'adresse d'envoi (endpoint) doit venir d'un service de
// notification connu (Google, Mozilla, Apple, Microsoft) : sans cette liste, quelqu'un pourrait faire envoyer des requêtes à n'importe quelle adresse.

const crypto = require('crypto');

const HOSTS = [/^fcm\.googleapis\.com$/, /^updates\.push\.services\.mozilla\.com$/, /^[a-z0-9.-]+\.push\.services\.mozilla\.com$/, /^[a-z0-9.-]+\.push\.apple\.com$/, /^web\.push\.apple\.com$/, /^[a-z0-9.-]+\.notify\.windows\.com$/, /^[a-z0-9.-]+\.push\.microsoft\.com$/];
const MAX_TEAMS = 12;

const idOf = (endpoint) => crypto.createHash('sha256').update(endpoint).digest('hex').slice(0, 24);

function validEndpoint(e) {
  if (typeof e !== 'string' || e.length > 600) return false;
  let u;
  try { u = new URL(e); } catch { return false; }
  return u.protocol === 'https:' && !u.username && HOSTS.some((re) => re.test(u.hostname));
}

const b64url = (s) => typeof s === 'string' && /^[A-Za-z0-9_-]{16,200}$/.test(s);
const cleanTeams = (arr) => [...new Set((Array.isArray(arr) ? arr : []).map(String).filter((x) => /^\d{1,12}$/.test(x)))].slice(0, MAX_TEAMS);

/** Enregistre ou met à jour un abonnement. Renvoie { id } ou lève une erreur d'entrée. */
async function subscribe(db, body, now) {
  const sub = body && body.subscription;
  if (!sub || !validEndpoint(sub.endpoint) || !sub.keys || !b64url(sub.keys.p256dh) || !b64url(sub.keys.auth)) throw Object.assign(new Error('Abonnement invalide.'), { status: 400 });
  const id = idOf(sub.endpoint);
  const ref = db.collection('push_subs').doc(id);
  const cur = await ref.get();
  const prev = cur.exists ? cur.data() : null;
  await ref.set({
    id, endpoint: sub.endpoint, keys: { p256dh: sub.keys.p256dh, auth: sub.keys.auth },
    lang: body.lang === 'en' ? 'en' : 'fr', equipes: body.equipes === undefined ? (prev ? prev.equipes || [] : []) : cleanTeams(body.equipes),
    creeLe: prev ? prev.creeLe : now.toISOString(), majLe: now.toISOString(), echecs: 0,
  });
  return { id, nouveau: !prev };
}

async function unsubscribe(db, endpoint) {
  if (!validEndpoint(endpoint)) throw Object.assign(new Error('Abonnement invalide.'), { status: 400 });
  await db.collection('push_subs').doc(idOf(endpoint)).delete();
  return { ok: true };
}

/** Équipes suivies : ajoute ou retire un identifiant d'équipe (action = 'add' | 'remove'). */
async function setTeam(db, endpoint, teamId, action) {
  if (!validEndpoint(endpoint) || !/^\d{1,12}$/.test(String(teamId))) throw Object.assign(new Error('Demande invalide.'), { status: 400 });
  const ref = db.collection('push_subs').doc(idOf(endpoint));
  const d = await ref.get();
  if (!d.exists) throw Object.assign(new Error('Abonnement inconnu : active d\'abord les notifications.'), { status: 404 });
  const cur = d.data().equipes || [];
  const next = action === 'remove' ? cur.filter((x) => x !== String(teamId)) : cleanTeams(cur.concat(String(teamId)));
  await ref.set(Object.assign({}, d.data(), { equipes: next }));
  return { equipes: next };
}

module.exports = { idOf, validEndpoint, subscribe, unsubscribe, setTeam, cleanTeams, MAX_TEAMS };
