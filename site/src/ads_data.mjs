// Données partagées des pages Afrolook Ads : règles des diffuseurs et catégories d'annonces.
// Elles viennent des fichiers ads_rules.json et ads_categories.json, générés à partir du serveur (functions/src/ads/adsRules.ts et adsCategories.ts) :
// « node functions/scripts/sync-ads-site.cjs ». Un test du serveur (adsSiteSync.test.ts) échoue si ces copies ne sont plus identiques.
import { readFileSync } from 'node:fs';

export const RULES = JSON.parse(readFileSync(new URL('./ads_rules.json', import.meta.url), 'utf8'));
export const CATS = JSON.parse(readFileSync(new URL('./ads_categories.json', import.meta.url), 'utf8'));

export const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const entries = (level) => Object.entries(CATS.categories).filter(([, c]) => c.level === level);

/** Liste déroulante des catégories d'annonces, courantes puis sensibles (option data-s = sensible). */
export const catOptions = () => `<optgroup label="Catégories courantes">${entries('standard').map(([k, c]) => `<option value="${k}">${esc(c.label)}</option>`).join('')}</optgroup>` +
  `<optgroup label="Catégories sensibles : diffusées seulement chez les diffuseurs qui les acceptent">${entries('sensitive').map(([k, c]) => `<option value="${k}" data-s="1">${esc(c.label)}</option>`).join('')}</optgroup>`;

/** Sélection multiple des catégories qu'un diffuseur accepte d'afficher : les courantes retenues par défaut, les sensibles jamais.
 *  Les vraies cases sont cachées (`.catpick-store`) : le script (catPick dans ads.js) en fait des pastilles et une liste déroulante pour ajouter. */
export const catChecks = (name, id) => `<div class="catpick"${id ? ` id="${id}"` : ''}><div class="catpick-store" hidden>` +
  [['standard', true], ['sensitive', false]].map(([lvl, on]) => entries(lvl).map(([k, c]) => `<input type="checkbox" name="${name}" value="${k}"${on ? ' checked' : ''} data-lvl="${lvl}" data-label="${esc(c.label)}"${c.hint ? ` data-hint="${esc(c.hint)}"` : ''}>`).join('')).join('') +
  `</div></div>`;

/** Texte officiel des règles, en HTML (même contenu que celui affiché et accepté dans l'espace diffuseur). */
export const rulesHtml = () => RULES.blocks.map((b) => `<section class="rule"><h3>${esc(b.title)}</h3><ul>${b.items.map((i) => `<li>${esc(i)}</li>`).join('')}</ul></section>`).join('');
