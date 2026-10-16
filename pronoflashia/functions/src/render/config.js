'use strict';
// Réglages du site et des publicités (config/site, config/ads), avec valeurs par défaut sûres :
// tant que l'admin n'a pas activé la publicité, aucun emplacement tiers n'est affiché.

const DEFAULT_SITE = {
  nom: 'PronoFlash IA',
  // Adresse provisoire ; à remplacer par pronoflashia.com (Réglages de l'admin) quand le nom de domaine est acheté.
  domaine: 'pronoflashia.web.app',
  origine: 'https://pronoflashia.web.app',
  email: '',
  editeur: '',
  adresse: '',
  statutJuridique: '',
  loi: '',
  hebergeur: 'Google Cloud (Firebase Hosting), Google Ireland Limited, Gordon House, Barrow Street, Dublin 4, Irlande',
  indexable: true,
  googleVerification: '', // code de vérification de propriété Google Search Console (balise HTML)
  analyticsGa: '',
  whatsapp: '',
  telegram: '',
};

const SLOTS = {
  haut: { actif: false, dk: [728, 90], mo: [320, 50] },
  native: { actif: false, every: 4 },
  verdict: { actif: false, dk: [728, 90], mo: [320, 100] },
  fiche_native: { actif: false },
  colonne_rect: { actif: false, dk: [300, 250] },
  colonne_tall: { actif: false, dk: [300, 600] },
  collante: { actif: false, mo: [320, 50] },
  socialbar: { actif: false, delaiSec: 20 },
  popunder: { actif: false, parJours: 1 },
};

const DEFAULT_ADS = {
  actif: false, // interrupteur général : rien ne s'affiche tant qu'il est coupé
  afrolook: { actif: true, every: 8, part: 25 }, // encarts maison ; part = % des emplacements où Afrolook passe en premier
  emplacements: SLOTS,
  adsTxt: '',
  verifications: [], // balises meta de vérification de propriété demandées par les réseaux
};

function merge(def, over) {
  const out = JSON.parse(JSON.stringify(def));
  for (const [k, v] of Object.entries(over || {})) {
    if (v && typeof v === 'object' && !Array.isArray(v) && out[k] && typeof out[k] === 'object' && !Array.isArray(out[k])) out[k] = merge(out[k], v);
    else out[k] = v;
  }
  return out;
}

const mergeSite = (over) => merge(DEFAULT_SITE, over);
const mergeAds = (over) => merge(DEFAULT_ADS, over);

/** Un emplacement est-il actif ? (interrupteur général ET emplacement) */
const slotOn = (ads, id) => !!(ads.actif && ads.emplacements[id] && ads.emplacements[id].actif);

/** Version publique de la config des pubs : ce que le navigateur a le droit de lire (codes compris, ce sont des codes publics). */
function publicAds(ads) {
  const out = { actif: ads.actif, afrolook: ads.afrolook, emplacements: {} };
  for (const [id, e] of Object.entries(ads.emplacements)) {
    out.emplacements[id] = { actif: !!(ads.actif && e.actif), reseaux: (e.reseaux || []).map((r) => ({ reseau: r.reseau, code: r.code || '', codeMobile: r.codeMobile || '' })), delaiSec: e.delaiSec, parJours: e.parJours, every: e.every };
  }
  return out;
}

module.exports = { DEFAULT_SITE, DEFAULT_ADS, SLOTS, mergeSite, mergeAds, slotOn, publicAds, merge };
