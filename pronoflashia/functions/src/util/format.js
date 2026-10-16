'use strict';
// Formats français partagés (dates, nombres). Le fuseau d'affichage final est géré côté navigateur ; le serveur écrit en UTC.

const DAYS = ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'];
const MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const DAYS_EN = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS_EN = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const pad = (n) => String(n).padStart(2, '0');

/** « dimanche 18 octobre 2026 » / « Sunday 18 October 2026 » (UTC). */
function dateLongue(iso, lang) {
  const d = new Date(iso);
  if (lang === 'en') return `${DAYS_EN[d.getUTCDay()]} ${d.getUTCDate()} ${MONTHS_EN[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
  return `${DAYS[d.getUTCDay()]} ${d.getUTCDate()}${d.getUTCDate() === 1 ? 'er' : ''} ${MONTHS[d.getUTCMonth()]} ${d.getUTCFullYear()}`;
}
/** « dim. 18 oct. » / « Sun 18 Oct » (UTC). */
function dateCourte(iso, lang) {
  const d = new Date(iso);
  if (lang === 'en') return `${DAYS_EN[d.getUTCDay()].slice(0, 3)} ${d.getUTCDate()} ${MONTHS_EN[d.getUTCMonth()].slice(0, 3)}`;
  return `${DAYS[d.getUTCDay()].slice(0, 3)}. ${d.getUTCDate()} ${MONTHS[d.getUTCMonth()].slice(0, 4)}.`;
}
/** « 20:45 » (UTC). */
function heure(iso) {
  const d = new Date(iso);
  return `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}
/** 2.5 → « 2,5 » (anglais : « 2.5 »). */
const fr = (x, dec, lang) => { const v = dec == null ? String(x) : Number(x).toFixed(dec); return lang === 'en' ? v : v.replace('.', ','); };
/** Échappement HTML. */
const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

module.exports = { DAYS, MONTHS, pad, dateLongue, dateCourte, heure, fr, esc };
