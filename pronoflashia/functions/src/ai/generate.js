'use strict';
// Chaîne de génération : Workers AI → Gemini → texte de secours. Un match n'est jamais laissé sans texte.

const { buildPrompt } = require('./prompt');
const { validateOutput } = require('./validate');
const { fallbackText, fallbackTextEn } = require('./fallback');

/**
 * providers : [{ name, call(messages) }] dans l'ordre d'essai.
 * Renvoie { texte, sourceTexte, latencyMs, erreurs[] } ; sourceTexte = nom du fournisseur ou « secours ».
 * Une sortie invalide est redemandée une fois au même fournisseur avant de passer au suivant.
 */
async function generateText(ctx, providers, opts = {}) {
  const lang = opts.lang === 'en' ? 'en' : 'fr';
  const { messages, faits } = buildPrompt(ctx, lang);
  const erreurs = [];
  const retries = opts.retries == null ? 1 : opts.retries;
  for (const p of providers) {
    for (let attempt = 0; attempt <= retries; attempt++) {
      const t0 = Date.now();
      try {
        const raw = await p.call(messages);
        const v = validateOutput(raw, faits, lang);
        if (v.ok) return { texte: v.value, sourceTexte: p.name, latencyMs: Date.now() - t0, erreurs };
        erreurs.push({ provider: p.name, type: 'sortie_invalide', detail: v.errors.join(' ') });
      } catch (e) {
        erreurs.push({ provider: p.name, type: 'appel', detail: String(e.message || e), status: e.status || null });
        if (e.retryable) break; // quota ou surcharge : on passe directement au suivant
      }
    }
  }
  return { texte: lang === 'en' ? fallbackTextEn(ctx) : fallbackText(ctx), sourceTexte: 'secours', latencyMs: 0, erreurs };
}

module.exports = { generateText };
