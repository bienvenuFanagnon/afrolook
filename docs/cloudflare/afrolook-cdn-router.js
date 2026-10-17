/**
 * Worker « afrolook-cdn-router » (cdn.afrolookmedia.com).
 *
 * /media/<chemin>?alt=media&token=<jeton>
 *   1. cherche le fichier dans R2 (liaison MEDIA = compartiment afrolook-media) : lecture sans frais de sortie ;
 *      le jeton du lien doit figurer dans les métadonnées du fichier (copiées depuis Firebase Storage), sinon R2 n'est pas utilisé ;
 *   2. sinon (fichier pas encore copié, jeton absent ou différent, liaison absente) : repli sur Firebase Storage, comme avant.
 * Tout le reste du domaine passe tel quel.
 */
const FIREBASE = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/';
const CORS = {
  'access-control-allow-origin': '*',
  'access-control-expose-headers': 'Content-Length, Content-Range, Accept-Ranges, Content-Type, ETag',
};

function validToken(obj, token) {
  if (!token) return false;
  const tokens = String((obj.customMetadata && obj.customMetadata.tokens) || '').split(',').map((t) => t.trim()).filter(Boolean);
  return tokens.includes(token);
}

async function fromR2(request, env, key, token) {
  if (!env.MEDIA) return null;
  try {
    if (request.method === 'HEAD') {
      const head = await env.MEDIA.head(key);
      if (!head || !validToken(head, token)) return null;
      const headers = new Headers(CORS);
      head.writeHttpMetadata(headers);
      headers.set('etag', head.httpEtag);
      headers.set('accept-ranges', 'bytes');
      headers.set('content-length', String(head.size));
      headers.set('x-served-from', 'r2');
      return new Response(null, { status: 200, headers });
    }
    const obj = await env.MEDIA.get(key, { range: request.headers, onlyIf: request.headers });
    if (!obj) return null;
    if (!validToken(obj, token)) {
      if (obj.body) await obj.body.cancel();
      return null;
    }
    const headers = new Headers(CORS);
    obj.writeHttpMetadata(headers);
    headers.set('etag', obj.httpEtag);
    headers.set('accept-ranges', 'bytes');
    headers.set('x-served-from', 'r2');
    let status = 200;
    if (!obj.body) {
      status = 304;
    } else if (obj.range && request.headers.get('range')) {
      status = 206;
      const start = obj.range.offset ?? 0;
      const end = obj.range.end ?? (obj.range.length !== undefined ? start + obj.range.length - 1 : obj.size - 1);
      headers.set('content-range', `bytes ${start}-${end}/${obj.size}`);
      headers.set('content-length', String(end - start + 1));
    } else {
      headers.set('content-length', String(obj.size));
    }
    return new Response(obj.body, { status, headers });
  } catch (e) {
    return null; // en cas de souci R2, on retombe sur Firebase Storage
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname.startsWith('/media/')) {
      if (request.method === 'OPTIONS') {
        return new Response(null, { status: 204, headers: { ...CORS, 'access-control-allow-methods': 'GET, HEAD, OPTIONS', 'access-control-allow-headers': 'Range, If-None-Match, If-Modified-Since', 'access-control-max-age': '86400' } });
      }
      if (request.method === 'GET' || request.method === 'HEAD') {
        let key = null;
        try {
          key = decodeURIComponent(url.pathname.slice('/media/'.length));
        } catch (e) {
          key = null;
        }
        if (key) {
          const r2 = await fromR2(request, env, key, url.searchParams.get('token'));
          if (r2) return r2;
        }
      }

      // Repli : le Worker va chercher le fichier chez Google et le renvoie en restant sur ton domaine.
      const remainingPath = request.url.split('/media/')[1];
      const targetUrl = `${FIREBASE}${remainingPath}`;
      return fetch(targetUrl, {
        method: request.method,
        headers: request.headers,
      });
    }

    return fetch(request);
  },
};
