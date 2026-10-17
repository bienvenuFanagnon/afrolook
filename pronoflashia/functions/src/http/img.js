'use strict';
// Images des notifications : /api/img/{id}.png (carte dessinée par nous) ou /api/img/{id}.jpg (image envoyée depuis l'admin).
// Le contenu d'une image ne change jamais pour un même identifiant : le CDN la garde longtemps.

const { renderPng, COL } = require('../push/card');

const ID = /^\/api\/img\/([a-z0-9]{8,24})\.(png|jpg)$/;

/** req : { path }, deps : { db }. Renvoie { status, type, body, cache }. */
async function handleImg(req, deps) {
  const m = ID.exec(req.path);
  if (!m) return { status: 404, type: 'text/plain', body: 'Inconnu', cache: 'public, max-age=60' };
  const d = await deps.db.collection(COL).doc(m[1]).get();
  if (!d.exists) return { status: 404, type: 'text/plain', body: 'Inconnu', cache: 'public, max-age=60' };
  const doc = d.data();
  const long = 'public, max-age=86400, s-maxage=2592000';
  if (doc.img) return { status: 200, type: doc.type === 'image/png' ? 'image/png' : 'image/jpeg', body: Buffer.from(doc.img, 'base64'), cache: long };
  if (m[2] !== 'png') return { status: 404, type: 'text/plain', body: 'Inconnu', cache: 'public, max-age=60' };
  return { status: 200, type: 'image/png', body: Buffer.from(renderPng(doc.card)), cache: long };
}

module.exports = { handleImg };
