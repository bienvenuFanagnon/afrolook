'use strict';
// Sponsors directs : encarts « offert par… » vendus par le propriétaire, sans réseau publicitaire.
// config/sponsors { items: [ { id, nom, phrase, lien, logo, emplacements[], debut, fin, actif } ] } ; logos dans sponsor_media ; mesure dans sponsor_stats/{id}_{jour}.
// Règles : lien https obligatoire, mention « Sponsorisé » toujours affichée, texte court, logo envoyé depuis l'admin (jamais d'adresse d'image externe).

const crypto = require('crypto');

const PLACEMENTS = ['coupon', 'accueil', 'actus'];
const MAX_ITEMS = 20;
const ROTATION_MS = 15 * 60e3;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const ID = /^s[a-f0-9]{10,16}$/;

const txt = (v, n) => String(v == null ? '' : v).replace(/\s+/g, ' ').trim().slice(0, n);

class SponsorError extends Error { constructor(message) { super(message); this.status = 400; } }

/** Valide et nettoie un sponsor reçu de l'admin. logoId est géré à part (envoi d'image). */
function clean(raw, prev) {
  const nom = txt(raw && raw.nom, 40);
  if (nom.length < 2) throw new SponsorError('Le nom du sponsor est obligatoire (2 caractères au moins).');
  const phrase = txt(raw && raw.phrase, 90);
  let lien = String((raw && raw.lien) || '').trim();
  let u;
  try { u = new URL(lien); } catch { u = null; }
  if (!u || u.protocol !== 'https:' || u.username || u.password || lien.length > 300 || /[\s"'<>]/.test(lien)) throw new SponsorError('Le lien du sponsor doit être une adresse https complète (https://…), sans espace.');
  lien = u.href;
  const emplacements = [...new Set((Array.isArray(raw && raw.emplacements) ? raw.emplacements : []).filter((p) => PLACEMENTS.includes(p)))];
  if (!emplacements.length) throw new SponsorError('Choisissez au moins un emplacement.');
  const day = (v) => { const s = String(v || '').trim(); if (!s) return ''; if (!DAY.test(s) || isNaN(new Date(`${s}T00:00:00Z`))) throw new SponsorError('Dates : format AAAA-MM-JJ.'); return s; };
  const debut = day(raw && raw.debut), fin = day(raw && raw.fin);
  if (debut && fin && fin < debut) throw new SponsorError('La date de fin est avant la date de début.');
  const id = prev && ID.test(prev.id) ? prev.id : `s${crypto.randomBytes(6).toString('hex')}`;
  return { id, nom, phrase, lien, logo: (prev && prev.logo) || '', logoExt: (prev && prev.logoExt) || '', emplacements, debut, fin, actif: !!(raw && raw.actif), creeLe: (prev && prev.creeLe) || null };
}

/** Sponsors visibles maintenant sur un emplacement (actifs, dans leurs dates). */
function activeFor(items, placement, now) {
  const day = now.toISOString().slice(0, 10);
  return (items || []).filter((s) => s && s.actif && (s.emplacements || []).includes(placement) && (!s.debut || day >= s.debut) && (!s.fin || day <= s.fin));
}

/** Un sponsor par emplacement et par tranche de 15 minutes, à tour de rôle (les pages sont gardées en mémoire par le CDN). */
function pick(items, placement, now) {
  const list = activeFor(items, placement, now);
  if (!list.length) return null;
  const sorted = list.slice().sort((a, b) => (a.id < b.id ? -1 : 1));
  return sorted[Math.floor(now.getTime() / ROTATION_MS) % sorted.length];
}

module.exports = { PLACEMENTS, MAX_ITEMS, ID, SponsorError, clean, activeFor, pick };
