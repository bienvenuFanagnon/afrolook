'use strict';
// Images de notification : cartes 1200 × 600 (format 2:1 des grandes images de notification) dessinées par nous, aux couleurs du site.
// Rien n'est repris d'un journal ni d'un club : seulement du texte (noms d'équipes, pourcentages, titre rédigé par nous).
// Une carte est décrite par { badge, titre, lignes: [{ l, v }], pied } et enregistrée sous push_cards/{id} ; l'image est dessinée à la demande
// par /api/img/{id}.png (puis gardée par le CDN). Dessin en SVG puis PNG (resvg, polices embarquées : aucune police système n'est requise).

const crypto = require('crypto');
const path = require('path');

const W = 1200, H = 600;
const FONTS = [path.join(__dirname, '..', '..', 'assets', 'fonts', 'Inter-ExtraBold.otf'), path.join(__dirname, '..', '..', 'assets', 'fonts', 'Inter-Medium.otf')];

const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
// largeur approchée d'un texte en Inter ExtraBold (majuscules et chiffres plus larges que les minuscules)
const widthOf = (s, size) => [...String(s)].reduce((w, c) => w + size * (/[A-ZÀ-ÖØ-Þ0-9%@#&]/.test(c) ? 0.68 : /[ ijlt.,:;'!|()]/.test(c) ? 0.32 : /[mwMW]/.test(c) ? 0.86 : 0.57), 0);

/** Coupe un texte en lignes qui tiennent dans `max` pixels ; la dernière finit par « … » si le texte est trop long. */
function wrap(text, size, max, maxLines) {
  const words = String(text || '').trim().split(/\s+/).filter(Boolean);
  const lines = [];
  let cur = '';
  for (let i = 0; i < words.length; i++) {
    const next = cur ? `${cur} ${words[i]}` : words[i];
    if (widthOf(next, size) <= max || !cur) { cur = next; continue; }
    lines.push(cur); cur = words[i];
    if (lines.length === maxLines) { cur = ''; break; }
  }
  if (cur) lines.push(cur);
  if (lines.length > maxLines) lines.length = maxLines;
  const used = lines.join(' ').split(/\s+/).length;
  if (used < words.length) {
    let last = lines[lines.length - 1];
    while (last.length > 1 && widthOf(`${last}…`, size) > max) last = last.slice(0, -1).trimEnd();
    lines[lines.length - 1] = `${last}…`;
  }
  return lines;
}

/** Nettoie une description de carte reçue du serveur ou de l'admin : longueurs bornées, types vérifiés. */
function cleanCard(c) {
  // la police embarquée n'a pas d'emoji : ils sont retirés du texte de l'image (ils restent dans le titre de la notification)
  const s = (v, n) => String(v == null ? '' : v).replace(/[\p{Extended_Pictographic}\uFE0F\u200D]/gu, '').replace(/\s+/g, ' ').trim().slice(0, n);
  const lignes = (Array.isArray(c && c.lignes) ? c.lignes : []).slice(0, 4).map((x) => ({ l: s(x && x.l, 60), v: s(x && x.v, 14) })).filter((x) => x.l);
  return { badge: s(c && c.badge, 28), titre: s(c && c.titre, 120), lignes, pied: s(c && c.pied, 40) || 'PronoFlash IA' };
}

/** Identifiant stable d'une carte : deux envois identiques partagent la même image. */
const cardId = (c) => crypto.createHash('sha1').update(JSON.stringify(cleanCard(c))).digest('hex').slice(0, 16);

function svgOf(card) {
  const c = cleanCard(card);
  const Y = '#FFD60A';
  const parts = [];
  parts.push(`<rect width="${W}" height="${H}" fill="#0B1220"/>`);
  parts.push(`<polygon points="760,0 1200,0 1200,600 560,600" fill="#121C33"/>`);
  parts.push(`<rect x="0" y="0" width="14" height="${H}" fill="${Y}"/>`);
  // éclair de la marque, très grand et discret, à droite
  parts.push(`<g transform="translate(900 60) scale(11)" opacity="0.13"><path d="M13 0 L0 28 H11 L7 48 L26 18 H14 L20 0 Z" fill="${Y}"/></g>`);
  let y = 78;
  if (c.badge) {
    const bw = Math.min(520, widthOf(c.badge, 30) + 56);
    parts.push(`<rect x="64" y="46" width="${bw}" height="56" rx="28" fill="${Y}"/>`);
    parts.push(`<text x="${64 + bw / 2}" y="84" font-family="Inter" font-weight="800" font-size="30" text-anchor="middle" fill="#0B1220">${esc(c.badge.toUpperCase())}</text>`);
    y = 160;
  }
  if (c.titre) {
    const size = c.lignes.length ? 54 : 70;
    const lines = wrap(c.titre, size, 1070, c.lignes.length ? 2 : 4);
    for (const ln of lines) { y += size; parts.push(`<text x="64" y="${y}" font-family="Inter" font-weight="800" font-size="${size}" fill="#FFFFFF">${esc(ln)}</text>`); y += 12; }
    y += 14;
  }
  if (c.lignes.length) {
    const room = 500 - y;
    const row = Math.min(84, Math.floor(room / c.lignes.length));
    const size = row >= 76 ? 44 : row >= 62 ? 38 : 32;
    for (const x of c.lignes) {
      y += row;
      const vw = x.v ? widthOf(x.v, size) + 40 : 0;
      const txt = wrap(x.l, size, 1070 - vw - 30, 1)[0];
      parts.push(`<text x="64" y="${y - row * 0.28}" font-family="Inter" font-weight="800" font-size="${size}" fill="#E8EEFF">${esc(txt)}</text>`);
      if (x.v) {
        parts.push(`<rect x="${1136 - vw}" y="${y - row * 0.28 - size * 0.86}" width="${vw}" height="${size * 1.2}" rx="${size * 0.6}" fill="${Y}"/>`);
        parts.push(`<text x="${1136 - vw / 2}" y="${y - row * 0.28}" font-family="Inter" font-weight="800" font-size="${size - 4}" text-anchor="middle" fill="#0B1220">${esc(x.v)}</text>`);
      }
    }
  }
  parts.push(`<g transform="translate(64 538) scale(0.62)"><path d="M13 0 L0 28 H11 L7 48 L26 18 H14 L20 0 Z" fill="${Y}"/></g>`);
  parts.push(`<text x="96" y="568" font-family="Inter" font-weight="500" font-size="28" fill="#8FA0C8">${esc(c.pied)}</text>`);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${parts.join('')}</svg>`;
}

/** PNG de la carte (Buffer). resvg est chargé à la demande : le reste du site n'en dépend pas. */
function renderPng(card) {
  const { Resvg } = require('@resvg/resvg-js');
  return new Resvg(svgOf(card), { font: { fontFiles: FONTS, loadSystemFonts: false, defaultFontFamily: 'Inter' }, fitTo: { mode: 'width', value: W } }).render().asPng();
}

const COL = 'push_cards';
const imageUrl = (id, type) => `/api/img/${id}.${type === 'image/jpeg' ? 'jpg' : 'png'}`;

/** Enregistre la description d'une carte (une seule fois par contenu) et renvoie l'adresse de son image. */
async function saveCard(db, card, now) {
  const c = cleanCard(card);
  const id = cardId(c);
  await db.collection(COL).doc(id).set({ id, card: c, creeLe: (now || new Date()).toISOString() });
  return imageUrl(id);
}

module.exports = { COL, imageUrl, saveCard, svgOf, renderPng, cleanCard, cardId, wrap, widthOf, W, H };
