// Refonte 2026 « Verre et lumière » : accueil, page Afrolook Ads. Le HTML vient de src/v2/*.html (issu de la maquette validée),
// les adresses (boutiques, application web) sont posées ici à partir de config.json.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), 'v2');
const read = (f) => fs.readFileSync(path.join(dir, f), 'utf8');

const fill = (html, cfg) => html
  .replaceAll('{{PLAY}}', cfg.playUrl)
  .replaceAll('{{APPSTORE}}', cfg.appStoreUrl)
  .replaceAll('{{APPWEB}}', cfg.appWebUrl);

/**
 * Accueil (fr ou en).
 * hasApp : l'application web sera-t-elle publiée sous /app/ avec ce site ? Sinon, aucun bouton ne doit y mener
 * (il ouvrirait une page introuvable) et la mention « Web » est retirée.
 */
export function v2Home(cfg, lang = 'fr', hasApp = true) {
  let h = read(lang === 'en' ? 'home.en.html' : 'home.html');
  if (!hasApp) {
    h = h.replace(/\s*<a class="v-btn v-b-line" href="\{\{APPWEB\}\}">[^<]*<\/a>/, '').replace('Android · iPhone · Web.', 'Android · iPhone.');
  }
  h = fill(h, cfg);
  // QR code d'installation (même fichier que la page Télécharger), visible sur grand écran : posé après les boutons du bloc Télécharger
  const qr = `<div class="v-qr2"><img src="/img/qr-telecharger.svg" width="96" height="96" alt="QR code : ${cfg.domain}${lang === 'en' ? '/en/download/' : '/telecharger/'}" loading="lazy"><span>${lang === 'en' ? '<b>Scan to install</b>This QR opens the right store for your phone.' : '<b>Scanne pour installer</b>Ce QR ouvre la bonne boutique selon ton téléphone.'}</span></div>`;
  const s = h.indexOf('id="telecharger"'), c = s < 0 ? -1 : h.indexOf('class="v-cta"', s);
  if (c < 0) return h;
  const e = h.indexOf('</div>', c) + 6;
  return h.slice(0, e) + qr + h.slice(e);
}

/** Page Afrolook Ads (fr ou en). */
export function v2Ads(cfg, lang = 'fr') {
  return fill(read(lang === 'en' ? 'ads.en.html' : 'ads.html'), cfg);
}
