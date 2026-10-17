'use strict';
// API publique des notifications : clé publique, abonnement, désabonnement, équipes suivies. Aucune donnée personnelle :
// un abonnement est une adresse d'envoi anonyme fournie par le navigateur.

const subs = require('../push/subs');
const inbox = require('../push/inbox');
const { limited } = require('./track');

/**
 * req : { method, path, body, ip }, deps : { db, now, publicKey() → Promise<string> }
 * Renvoie { status, json, cache? }.
 */
async function handlePush(req, deps) {
  const path = req.path.replace(/^\/api\/push\//, '');
  const now = deps.now || new Date();
  const lim = (n) => limited(`push:${req.ip}`, n, 60000, now.getTime());
  try {
    if (path === 'key' && req.method === 'GET') return { status: 200, json: { publicKey: await deps.publicKey() }, cache: 'public, max-age=3600' };
    if (req.method !== 'POST') return { status: 405, json: { erreur: 'Méthode non permise.' } };
    // boîte de réception : le compteur est demandé à chaque page par les abonnés (limite plus large)
    if (path === 'compte') {
      if (limited(`pushc:${req.ip}`, 120, 60000, now.getTime())) return { status: 429, json: { erreur: 'Trop de demandes.' } };
      return { status: 200, json: await inbox.count(deps.db, (req.body || {}).endpoint) };
    }
    if (path === 'inbox' || path === 'lu') {
      if (limited(`pushi:${req.ip}`, 60, 60000, now.getTime())) return { status: 429, json: { erreur: 'Trop de demandes.' } };
      const b2 = req.body || {};
      return { status: 200, json: path === 'inbox' ? await inbox.list(deps.db, b2.endpoint, b2.offset, now) : await inbox.markRead(deps.db, b2.endpoint, b2.id, b2.tous === true) };
    }
    if (lim(20)) return { status: 429, json: { erreur: 'Trop de demandes, réessaie dans une minute.' } };
    const b = req.body || {};
    if (path === 'subscribe') return { status: 200, json: await subs.subscribe(deps.db, b, now) };
    if (path === 'unsubscribe') return { status: 200, json: await subs.unsubscribe(deps.db, b.endpoint) };
    if (path === 'equipe') return { status: 200, json: await subs.setTeam(deps.db, b.endpoint, b.equipe, b.action === 'remove' ? 'remove' : 'add') };
    return { status: 404, json: { erreur: 'Inconnu.' } };
  } catch (e) {
    return { status: e.status || 500, json: { erreur: e.status ? e.message : 'Erreur temporaire.' } };
  }
}

module.exports = { handlePush };
