'use strict';
// API publique de l'inscription par e-mail : inscription et désinscription. Limite de débit stricte par adresse IP.

const mail = require('../mail/subs');
const { limited } = require('./track');

/** req : { method, path, body, ip }, deps : { db, now }. Renvoie { status, json }. */
async function handleMail(req, deps) {
  const path = req.path.replace(/^\/api\/mail\//, '');
  const now = deps.now || new Date();
  try {
    if (req.method !== 'POST') return { status: 405, json: { erreur: 'Méthode non permise.' } };
    if (limited(`mail:${req.ip}`, 6, 60000, now.getTime())) return { status: 429, json: { erreur: 'Trop de demandes, réessaie dans une minute.' } };
    const b = req.body || {};
    if (path === 'subscribe') return { status: 200, json: await mail.subscribe(deps.db, b, now) };
    if (path === 'unsubscribe') return { status: 200, json: await mail.unsubscribe(deps.db, b.id, b.t, now) };
    return { status: 404, json: { erreur: 'Inconnu.' } };
  } catch (e) {
    return { status: e.status || 500, json: { erreur: e.status ? e.message : 'Erreur temporaire.' } };
  }
}

module.exports = { handleMail };
