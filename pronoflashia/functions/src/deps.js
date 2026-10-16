'use strict';
// Construction des dépendances réelles (API sportive, fournisseurs d'IA) à partir des secrets Firebase.

const apiFootball = require('./data/apiFootball');
const footballData = require('./data/footballData');
const { cloudflareProvider, geminiProvider } = require('./ai/providers');

/**
 * Source des données de football. s = { source, footballData, apiFootball, ... } : valeurs des secrets (peuvent être vides).
 * « football-data » (offre gratuite : scores et calendriers) ou « api-football » (offre payante : statistiques, cotes, Afrique).
 * Sans choix explicite : football-data.org si son jeton existe, sinon API-Football.
 */
function sourceOf(s) {
  if (s.source === 'api-football' || s.source === 'football-data') return s.source;
  return s.footballData ? 'football-data' : 'api-football';
}

function makeApi(s, opts = {}) {
  if (sourceOf(s) === 'football-data') {
    if (!s.footballData) throw new Error('Secret FOOTBALL_DATA_TOKEN manquant');
    return footballData.createClient({ key: s.footballData, maxWaitMs: opts.maxWaitMs });
  }
  if (!s.apiFootball) throw new Error('Secret API_FOOTBALL_KEY manquant');
  return apiFootball.createClient({ key: s.apiFootball });
}

/** Ordre d'essai : Workers AI d'abord (quota gratuit), Gemini en secours. Un fournisseur sans clé est simplement ignoré. */
function makeProviders(s, models = {}) {
  const list = [];
  if (s.cfToken && s.cfAccount) list.push(cloudflareProvider({ accountId: s.cfAccount, token: s.cfToken, model: models.cf }));
  if (s.gemini) list.push(geminiProvider({ apiKey: s.gemini, models: models.gemini }));
  return list;
}

module.exports = { makeApi, makeProviders, sourceOf };
