'use strict';
// Formats français partagés (dates, nombres). Le fuseau d'affichage final est géré côté navigateur ; le serveur écrit en UTC.

const DAYS = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
const MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const pad = (n) => String(n).padStart(2, '0');

/** « dimanche 18 octobre 2026 » (UTC). */
function dateLongue(iso) {
  const d = new Date(iso);
  return `${DAYS[d.getUTCDay()]} ${d.getUTCDate()}${d.getUTCDate() === 1 ? 'er' : ''} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}
/** « dim. 18 oct. » (UTC). */
function dateCourte(iso) {
  const d = new Date(iso);
  return `${DAYS[d.getUTCDay()].slice(0, 3)}. ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()].slice(0, 4)}.`;
}
/** « 20:45 » (UTC). */
function heure(iso) {
  const d = new Date(iso);
  return `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}
/** 2.5 → « 2,5 ». */
const fr = (x, dec) => (dec == null ? String(x) : Number(x).toFixed(dec)).replace('.', ',');
/** Échappement HTML. */
const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

module.exports = { DAYS, MONTHS, pad, dateLongue, dateCourte, heure, fr, esc };
