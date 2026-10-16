'use strict';
// Construction des dépendances réelles (API sportive, fournisseurs d'IA) à partir des secrets Firebase.

const { createClient } = require('./data/apiFootball');
const { cloudflareProvider, geminiProvider } = require('./ai/providers');

/** s = { apiFootball, cfToken, cfAccount, gemini } : valeurs des secrets (peuvent être vides). */
function makeApi(s) {
  if (!s.apiFootball) throw new Error('Secret API_FOOTBALL_KEY manquant');
  return createClient({ key: s.apiFootball });
}

/** Ordre d'essai : Workers AI d'abord (quota gratuit), Gemini en secours. Un fournisseur sans clé est simplement ignoré. */
function makeProviders(s, models = {}) {
  const list = [];
  if (s.cfToken && s.cfAccount) list.push(cloudflareProvider({ accountId: s.cfAccount, token: s.cfToken, model: models.cf }));
  if (s.gemini) list.push(geminiProvider({ apiKey: s.gemini, models: models.gemini }));
  return list;
}

module.exports = { makeApi, makeProviders };
