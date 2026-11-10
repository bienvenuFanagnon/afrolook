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

/** Accueil français. */
export function v2Home(cfg, lang = 'fr') {
  let h = fill(read(lang === 'en' ? 'home.en.html' : 'home.html'), cfg);
  // QR code d'installation (même fichier que la page Télécharger), visible sur grand écran
  const qr = `<div class="v-qr2"><img src="/img/qr-telecharger.svg" width="96" height="96" alt="QR code : ${cfg.domain}${lang === 'en' ? '/en/download/' : '/telecharger/'}" loading="lazy"><span>${lang === 'en' ? '<b>Scan to install</b>This QR opens the right store for your phone.' : '<b>Scanne pour installer</b>Ce QR ouvre la bonne boutique selon ton téléphone.'}</span></div>`;
  const i = h.indexOf('Ouvrir sur le web</a>');
  return i < 0 ? h : h.slice(0, h.indexOf('</div>', i) + 6) + qr + h.slice(h.indexOf('</div>', i) + 6);
}

/** Page Afrolook Ads (français). */
export function v2Ads(cfg, lang = 'fr') {
  return fill(read(lang === 'en' ? 'ads.en.html' : 'ads.html'), cfg);
}
