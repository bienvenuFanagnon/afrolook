'use strict';
// Fournisseurs d'IA. Chaque fonction renvoie le texte brut de la réponse ; les clés viennent de Firebase Secrets.

const DEFAULT_CF_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
// Même liste de modèles que SlashAtlas (filmStudio.js) : on passe au suivant si un modèle répond 404, 429 ou 503.
const DEFAULT_GEMINI_MODELS = ['gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-3.1-flash-lite'];

async function fetchJson(url, init, timeoutMs, fetchImpl) {
  const f = fetchImpl || fetch;
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs || 30000);
  try {
    const res = await f(url, Object.assign({}, init, { signal: ctrl.signal }));
    const text = await res.text();
    let json = null;
    try { json = JSON.parse(text); } catch { /* corps non JSON */ }
    return { status: res.status, ok: res.ok, json, text };
  } finally {
    clearTimeout(t);
  }
}

class ProviderError extends Error {
  constructor(message, status, retryable) { super(message); this.status = status; this.retryable = !!retryable; }
}

/** Cloudflare Workers AI (premier choix : quota gratuit quotidien). */
function cloudflareProvider({ accountId, token, model, fetchImpl }) {
  const m = model || DEFAULT_CF_MODEL;
  let last = null;
  return {
    name: 'workers-ai',
    /** Consommation du dernier appel : { neurons, tokens } (Cloudflare facture en « neurons »). */
    lastUsage: () => last,
    async call(messages) {
      last = null;
      const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${m}`;
      const r = await fetchJson(url, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages, max_tokens: 900, temperature: 0.4 }),
      }, 40000, fetchImpl);
      if (!r.ok || !r.json || r.json.success === false) {
        const quota = r.status === 429 || /neurons|quota|limit/i.test(r.text || '');
        throw new ProviderError(`workers-ai ${r.status}${quota ? ' quota' : ''}`, r.status, quota);
      }
      const res = r.json.result;
      const u = res && res.usage;
      if (u) last = { neurons: typeof u.neurons === 'number' ? u.neurons : null, tokens: u.total_tokens || null };
      // Selon le modèle, la réponse est { response } (format Cloudflare) ou { choices: [{ message: { content } }] } (format OpenAI).
      const choice = res && res.choices && res.choices[0] && res.choices[0].message;
      const out = choice ? choice.content : res && (res.response != null ? res.response : null);
      if (out == null) throw new ProviderError('workers-ai réponse vide', r.status, false);
      return typeof out === 'string' ? out : JSON.stringify(out);
    },
  };
}

/** Gemini (secours). */
function geminiProvider({ apiKey, models, fetchImpl }) {
  const list = models && models.length ? models : DEFAULT_GEMINI_MODELS;
  return {
    name: 'gemini',
    lastUsage: () => null,
    async call(messages) {
      const system = messages.filter((x) => x.role === 'system').map((x) => x.content).join('\n');
      const user = messages.filter((x) => x.role !== 'system').map((x) => x.content).join('\n');
      let last = null;
      for (const model of list) {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
        const r = await fetchJson(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: system }] },
            contents: [{ role: 'user', parts: [{ text: user }] }],
            generationConfig: { temperature: 0.4, maxOutputTokens: 900, responseMimeType: 'application/json' },
          }),
        }, 40000, fetchImpl);
        if (r.ok && r.json) {
          const t = r.json.candidates && r.json.candidates[0] && r.json.candidates[0].content && r.json.candidates[0].content.parts;
          const text = t && t.map((p) => p.text || '').join('');
          if (text) return text;
          last = new ProviderError(`gemini ${model} réponse vide`, r.status, false);
          continue;
        }
        last = new ProviderError(`gemini ${model} ${r.status}`, r.status, [404, 429, 503].includes(r.status));
        if (![404, 429, 503].includes(r.status)) break; // erreur de clé ou de requête : inutile d'essayer les autres modèles
      }
      throw last || new ProviderError('gemini indisponible', 0, true);
    },
  };
}

module.exports = { ProviderError, cloudflareProvider, geminiProvider, fetchJson, DEFAULT_CF_MODEL, DEFAULT_GEMINI_MODELS };
