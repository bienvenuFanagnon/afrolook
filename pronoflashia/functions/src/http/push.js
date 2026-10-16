'use strict';
// API publique des notifications : clé publique, abonnement, désabonnement, équipes suivies. Aucune donnée personnelle :
// un abonnement est une adresse d'envoi anonyme fournie par le navigateur.

const subs = require('../push/subs');
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
