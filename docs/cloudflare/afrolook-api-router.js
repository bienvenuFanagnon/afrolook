// Worker Cloudflare « afrolook-api-router » : envoie vers l'API Afrolook les chemins de afrolookmedia.com qui ne sont plus servis par Firebase.
//   /v1/*          -> https://api.afrolookmedia.com/v1/*
//   /ads/api/*     -> https://api.afrolookmedia.com/v1/ads/*   (adresses publiques stables de la régie)
//   /p/*           -> https://api.afrolookmedia.com/p/*        (liens suivis de Partage et gagne)
//   /share, /share/* -> https://api.afrolookmedia.com/share*   (aperçus de liens partagés)
// Variable secrète du Worker : EDGE_SECRET (la MÊME valeur dans le .env du serveur : EDGE_SECRET=...). Elle permet à l'API de croire l'adresse et le pays du visiteur.
// Routes du Worker (plan gratuit) : afrolookmedia.com/v1/*, afrolookmedia.com/ads/api/*, afrolookmedia.com/p/*, afrolookmedia.com/share, afrolookmedia.com/share/*
const API = 'https://api.afrolookmedia.com';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    let path = url.pathname;
    if (path.startsWith('/ads/api/')) path = '/v1/ads/' + path.slice('/ads/api/'.length);
    const headers = new Headers(request.headers);
    headers.set('X-Edge-Secret', env.EDGE_SECRET || '');
    headers.set('X-Edge-IP', request.headers.get('CF-Connecting-IP') || '');
    headers.set('X-Edge-Country', request.headers.get('CF-IPCountry') || (request.cf && request.cf.country) || '');
    headers.set('X-Forwarded-Host', url.host);
    const hasBody = request.method !== 'GET' && request.method !== 'HEAD';
    return fetch(new Request(API + path + url.search, { method: request.method, headers, body: hasBody ? request.body : undefined, redirect: 'manual' }));
  },
};
