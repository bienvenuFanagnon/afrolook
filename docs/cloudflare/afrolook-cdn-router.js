/**
 * Worker « afrolook-cdn-router » (cdn.afrolookmedia.com).
 *
 * /media/<chemin>?alt=media&token=<jeton>
 *   1. cherche le fichier dans R2 (liaison MEDIA = compartiment afrolook-media) : lecture sans frais de sortie ;
 *      le jeton du lien doit figurer dans les métadonnées du fichier (copiées depuis Firebase Storage), sinon R2 n'est pas utilisé ;
 *   2. sinon (fichier pas encore copié, jeton absent ou différent, liaison absente) : repli sur Firebase Storage, comme avant.
 * Lecture à travers : quand R2 n'a pas encore le fichier et que Google l'accepte avec le jeton du lien, le Worker le sert ET le range dans R2
 * (une lecture chez Google pour la première personne, R2 pour toutes les suivantes). Au-delà de 40 Mo, c'est la copie périodique qui s'en charge.
 * Tout le reste du domaine passe tel quel.
 */
const FIREBASE = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/';
const FILL_MAX = 40 * 1024 * 1024;
const CORS = {
  'access-control-allow-origin': '*',
  'access-control-expose-headers': 'Content-Length, Content-Range, Accept-Ranges, Content-Type, ETag',
};

// Certains fichiers ont été rangés sans type (« application/octet-stream ») : iPhone et iPad ne lisent pas un son ou une vidéo sans type.
// Le type est donc déduit de l'extension du fichier quand il manque.
const TYPES = {
  mp3: 'audio/mpeg', m4a: 'audio/mp4', aac: 'audio/aac', wav: 'audio/wav', flac: 'audio/flac', ogg: 'audio/ogg',
  mp4: 'video/mp4', m4v: 'video/mp4', mov: 'video/quicktime', webm: 'video/webm',
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', gif: 'image/gif',
};
function fixType(headers, key) {
  const t = (headers.get('content-type') || '').toLowerCase();
  if (t && t !== 'application/octet-stream' && t !== 'binary/octet-stream') return;
  const m = /\.([a-z0-9]+)$/i.exec(key);
  const type = m && TYPES[m[1].toLowerCase()];
  if (type) headers.set('content-type', type);
}

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
      fixType(headers, key);
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
    fixType(headers, key);
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

/** Range le fichier entier dans R2 (jeton = celui que Google vient d'accepter). */
async function storeInR2(env, key, token, body, len, type) {
  const fixed = new FixedLengthStream(len);
  const piping = body.pipeTo(fixed.writable);
  await Promise.all([
    piping,
    env.MEDIA.put(key, fixed.readable, {
      httpMetadata: { contentType: type, cacheControl: 'public, max-age=2592000' },
      customMetadata: { tokens: token, src: 'worker' },
    }),
  ]);
}

/** Demande complète en arrière-plan (cas d'une lecture partielle) puis rangement dans R2. */
async function fillFromGoogle(env, targetUrl, key, token) {
  if (await env.MEDIA.head(key)) return; // déjà rangé entre-temps
  const full = await fetch(targetUrl);
  const len = Number(full.headers.get('content-length') || 0);
  if (!full.ok || !full.body || !len || len > FILL_MAX) {
    if (full.body) await full.body.cancel();
    return;
  }
  await storeInR2(env, key, token, full.body, len, full.headers.get('content-type') || 'application/octet-stream');
}

async function fromGoogle(request, env, ctx, targetUrl, key, token) {
  const res = await fetch(targetUrl, { method: request.method, headers: request.headers });
  const canFill = request.method === 'GET' && env.MEDIA && key && token && res.ok;
  if (!canFill) return res;
  try {
    if (res.status === 200 && res.body) {
      const len = Number(res.headers.get('content-length') || 0);
      if (len > 0 && len <= FILL_MAX) {
        const [toClient, toR2] = res.body.tee();
        ctx.waitUntil(storeInR2(env, key, token, toR2, len, res.headers.get('content-type') || 'application/octet-stream').catch(() => {}));
        return new Response(toClient, res);
      }
    } else if (res.status === 206) {
      ctx.waitUntil(fillFromGoogle(env, targetUrl, key, token).catch(() => {}));
    }
  } catch (e) {
    // le rangement est un bonus : en cas de souci on sert simplement la réponse de Google
  }
  return res;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname.startsWith('/media/')) {
      if (request.method === 'OPTIONS') {
        return new Response(null, { status: 204, headers: { ...CORS, 'access-control-allow-methods': 'GET, HEAD, OPTIONS', 'access-control-allow-headers': 'Range, If-None-Match, If-Modified-Since', 'access-control-max-age': '86400' } });
      }
      const token = url.searchParams.get('token');
      if (request.method === 'GET' || request.method === 'HEAD') {
        let key = null;
        try {
          key = decodeURIComponent(url.pathname.slice('/media/'.length));
        } catch (e) {
          key = null;
        }
        if (key) {
          const r2 = await fromR2(request, env, key, token);
          if (r2) return r2;
        }
      }

      // Repli : le Worker va chercher le fichier chez Google et le renvoie en restant sur ton domaine.
      const remainingPath = request.url.split('/media/')[1];
      const targetUrl = `${FIREBASE}${remainingPath}`;
      let fillKey = null;
      try {
        fillKey = decodeURIComponent(url.pathname.slice('/media/'.length));
      } catch (e) {
        fillKey = null;
      }
      return fromGoogle(request, env, ctx, targetUrl, fillKey, token);
    }

    return fetch(request);
  },
};
