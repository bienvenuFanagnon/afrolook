'use strict';
// Inscription par e-mail (facultative) aux coupons « VIP » gratuits. Aucun e-mail n'est envoyé pour l'instant : on enregistre l'adresse
// et la preuve du consentement (date, texte accepté, page d'inscription). Le premier envoi sera un message de confirmation (double accord),
// et chaque message portera un lien de désinscription qui utilise le jeton propre à l'inscrit (jeton).
// Même réponse que l'adresse soit nouvelle ou déjà connue : on ne révèle pas qui est inscrit.

const crypto = require('crypto');

const COL = 'email_subs';
const CONSENT_VERSION = '2026-10';
const EMAIL = /^[^\s@<>"'(),;:\\[\]]{1,64}@[A-Za-z0-9.-]{1,200}\.[A-Za-z]{2,24}$/;
const SOURCES = ['notifs', 'coupon', 'autre'];

const norm = (e) => String(e || '').trim().toLowerCase();
const idOf = (email) => crypto.createHash('sha256').update(norm(email)).digest('hex').slice(0, 24);
const fail = (status, message) => Object.assign(new Error(message), { status });

/** body : { email, consent: true, lang, source, site (piège à robots : doit rester vide) }. */
async function subscribe(db, body, now) {
  const b = body || {};
  if (typeof b.site === 'string' && b.site.trim()) return { ok: true }; // un robot a rempli le champ caché : réponse normale, rien enregistré
  const email = norm(b.email);
  if (!EMAIL.test(email) || email.length > 120 || /\.\./.test(email)) throw fail(400, 'Adresse e-mail invalide.');
  if (b.consent !== true) throw fail(400, 'Ton accord est nécessaire pour recevoir nos e-mails.');
  const id = idOf(email);
  const ref = db.collection(COL).doc(id);
  const cur = await ref.get();
  const prev = cur.exists ? cur.data() : null;
  if (prev && prev.statut !== 'desinscrit') return { ok: true };
  await ref.set({
    id, email, lang: b.lang === 'en' ? 'en' : 'fr', statut: 'en_attente', confirme: false, jeton: crypto.randomBytes(12).toString('hex'),
    consentement: { au: now.toISOString(), version: CONSENT_VERSION, page: SOURCES.includes(b.source) ? b.source : 'autre' },
    creeLe: prev ? prev.creeLe : now.toISOString(),
  });
  return { ok: true };
}

/** Désinscription par le lien d'un e-mail : { id, t (jeton) }. */
async function unsubscribe(db, id, token, now) {
  if (!/^[a-f0-9]{24}$/.test(String(id || '')) || !/^[a-f0-9]{24}$/.test(String(token || ''))) throw fail(400, 'Lien invalide.');
  const ref = db.collection(COL).doc(id);
  const d = await ref.get();
  const ok = d.exists && crypto.timingSafeEqual(Buffer.from(String(d.data().jeton || '').padEnd(24, '0')), Buffer.from(token));
  if (!ok) throw fail(400, 'Lien invalide.');
  await ref.set(Object.assign({}, d.data(), { statut: 'desinscrit', desinscritLe: now.toISOString() }));
  return { ok: true };
}

module.exports = { COL, CONSENT_VERSION, EMAIL, idOf, subscribe, unsubscribe };
