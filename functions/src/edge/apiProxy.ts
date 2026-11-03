import { onRequest } from "firebase-functions/v2/https";

/**
 * Relais vers la nouvelle API Afrolook. Firebase Hosting envoie ici les chemins `/v1/**` et `/ads/api/**` du site afrolookmedia.com (voir firebase.json) :
 * le site garde son adresse et ses habitudes, et les opérations passent par l'API (serveur api.afrolookmedia.com).
 *   /v1/...        -> https://api.afrolookmedia.com/v1/...
 *   /ads/api/...   -> https://api.afrolookmedia.com/v1/ads/...   (adresses publiques stables de la régie)
 *   /p/<code>/     -> https://api.afrolookmedia.com/p/<code>/      (lien suivi de Partage et gagne : page d'aperçu, comptage, redirection ; POST = clic)
 * L'adresse et le pays du VISITEUR (lus dans les en-têtes de Cloudflare) sont transmis dans X-Edge-IP et X-Edge-Country avec un secret partagé (EDGE_SECRET,
 * le même dans functions/.env et dans le .env du serveur de l'API) : sans lui, l'API ne croit jamais ces en-têtes (EdgeClient).
 */
const API = "https://api.afrolookmedia.com";

// en-têtes qui ne doivent pas être recopiés tels quels vers l'API
const SKIP_REQUEST = new Set(["host", "connection", "content-length", "transfer-encoding", "accept-encoding", "x-forwarded-for", "x-forwarded-host", "x-forwarded-proto",
  "forwarded", "x-cloud-trace-context", "traceparent", "x-appengine-user-ip", "x-edge-secret", "x-edge-ip", "x-edge-country", "cookie", "fastly-client-ip", "x-orig-path"]);
// en-têtes de réponse à ne pas recopier (la taille et le codage sont recalculés)
const SKIP_RESPONSE = new Set(["content-encoding", "content-length", "transfer-encoding", "connection", "keep-alive", "set-cookie"]);

export const apiProxy = onRequest({ region: "us-central1", memory: "256MiB", timeoutSeconds: 60, maxInstances: 40, cors: false }, async (req, res) => {
  let path = req.originalUrl || req.url;
  if (path.startsWith("/ads/api/")) path = "/v1/ads/" + path.slice("/ads/api/".length);
  if (!path.startsWith("/v1/") && !path.startsWith("/p/")) { res.status(404).json({ error: "not_found" }); return; }

  const headers: Record<string, string> = {};
  for (const [k, v] of Object.entries(req.headers)) {
    if (SKIP_REQUEST.has(k.toLowerCase()) || v === undefined) continue;
    headers[k] = Array.isArray(v) ? v.join(", ") : String(v);
  }
  const secret = process.env["EDGE_SECRET"] ?? "";
  const ip = String(req.headers["cf-connecting-ip"] ?? "").trim() || String(req.headers["x-forwarded-for"] ?? "").split(",")[0].trim();
  if (secret) {
    headers["X-Edge-Secret"] = secret;
    headers["X-Edge-IP"] = ip;
    headers["X-Edge-Country"] = String(req.headers["cf-ipcountry"] ?? "");
  }
  headers["X-Forwarded-Host"] = "afrolookmedia.com";

  const hasBody = req.method !== "GET" && req.method !== "HEAD";
  try {
    const r = await fetch(API + path, { method: req.method, headers, body: hasBody && req.rawBody?.length ? new Uint8Array(req.rawBody) : undefined, redirect: "manual", signal: AbortSignal.timeout(55000) });
    r.headers.forEach((value, key) => { if (!SKIP_RESPONSE.has(key.toLowerCase())) res.setHeader(key, value); });
    res.status(r.status).send(Buffer.from(await r.arrayBuffer()));
  } catch (e) {
    console.error("[apiProxy]", req.method, path.split("?")[0], e);
    res.status(502).json({ error: "api_indisponible" });
  }
});
