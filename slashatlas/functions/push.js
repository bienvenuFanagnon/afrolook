'use strict';
// Notifications « commande du jour » (Web Push, clés VAPID ; la clé privée est dans les secrets Firebase).
// Abonnés anonymes : PushSubs/{id}, id = empreinte de l'adresse d'abonnement (aucun compte requis, aucune donnée personnelle).
// Envoi : chaque heure (à la demie), les abonnés pour qui il est 9 h 30 reçoivent la commande du jour d'un de leurs thèmes, au plus 1 par jour.
// Thèmes et commandes : functions/push_pool.json, écrit par build.mjs (seulement des commandes illustrées et générables sur le site).
const crypto = require('crypto');
const webpush = require('web-push');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const VAPID_PRIVATE_KEY = defineSecret('VAPID_PRIVATE_KEY');
const VAPID_PUBLIC_KEY = 'BJkiNd43mvErTOOjqQBj5FVrvGUOpqEmuSwDSYgOdXF2NhzAK59PqDj7dqkjjTxM5nS-cAePSXl9MQVCPmXpYAo'; // aussi dans src/config.json (push.publicKey)
const SITE = 'https://slashatlas.com';
const THEMES = ['beaute', 'cheveux', 'mode', 'cadeaux', 'douceurs'];
let POOL = null;
const pool = () => POOL || (POOL = require('./push_pool.json'));
const db = () => getFirestore();
const idOf = (endpoint) => crypto.createHash('sha256').update(endpoint).digest('hex').slice(0, 32);
const day = (d = new Date()) => d.toISOString().slice(0, 10);
// heure UTC à laquelle il est 9 h 30 chez l'abonné (tz = getTimezoneOffset() du navigateur, en minutes, UTC − heure locale)
const hourFor = (tz) => (((Math.floor((570 + tz) / 60)) % 24) + 24) % 24;
const T = {
  fr: { title: (t) => `Commande du jour : ${t}`, body: 'Votre affiche pro en 1 minute, à partir de votre photo. Prix et contact ajoutés pour vous.', gen: 'Générer', see: 'Voir l’exemple', hello: 'Notifications activées', helloB: 'Vous recevrez une commande illustrée chaque matin, au plus une par jour.' },
  en: { title: (t) => `Command of the day: ${t}`, body: 'Your pro poster in 1 minute, from your photo. Price and contact added for you.', gen: 'Generate', see: 'See the example', hello: 'Notifications on', helloB: 'You will get an illustrated command every morning, at most one a day.' },
};
let vapidSet = false;
function vapid() {
  if (vapidSet) return;
  webpush.setVapidDetails('mailto:contact@slashatlas.com', VAPID_PUBLIC_KEY, String(process.env.VAPID_PRIVATE_KEY || '').trim());
  vapidSet = true;
}
// Seuls les services de notification des navigateurs sont acceptés : sans cela, quiconque pourrait faire envoyer des requêtes du serveur vers n'importe quelle adresse.
const PUSH_HOSTS = /^(fcm\.googleapis\.com|android\.googleapis\.com|updates\.push\.services\.mozilla\.com|updates-autopush\.(stage\.)?mozaws\.net|([a-z0-9-]+\.)*push\.apple\.com|([a-z0-9-]+\.)*notify\.windows\.com|web\.push\.apple\.com)$/;
function cleanSub(s) {
  if (!s || typeof s !== 'object' || typeof s.endpoint !== 'string' || !/^https:\/\/[^\s]{10,900}$/.test(s.endpoint)) return null;
  let host = ''; try { const u = new URL(s.endpoint); host = u.hostname; if (u.username || u.password || u.port) return null; } catch (e) { return null; }
  if (!PUSH_HOSTS.test(host)) return null;
  const k = s.keys || {};
  if (typeof k.p256dh !== 'string' || typeof k.auth !== 'string' || k.p256dh.length > 200 || k.auth.length > 100) return null;
  return { endpoint: s.endpoint, keys: { p256dh: k.p256dh, auth: k.auth } };
}
const cleanThemes = (t) => { const a = (Array.isArray(t) ? t : []).filter((x) => THEMES.includes(x)); return a.length ? [...new Set(a)] : THEMES.slice(); };
const stat = (fields) => db().collection('PushStats').doc(day()).set(Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, FieldValue.increment(v)])), { merge: true }).catch(() => {});

// commande du jour d'un thème : rotation quotidienne dans la liste (pas de répétition avant d'avoir tout vu)
function pick(theme, dayIndex) {
  const list = pool()[theme] || [];
  return list.length ? list[dayIndex % list.length] : null;
}
function payload(item, lang, welcome) {
  const t = T[lang] || T.fr, L = lang === 'en' ? 'en' : 'fr';
  if (welcome) return JSON.stringify({ title: t.hello, body: t.helloB, url: SITE + (L === 'en' ? '/en/' : '/'), tag: 'sa-hello' });
  const page = (L === 'en' ? '/en/c/' : '/c/') + item.s + '/', gen = (L === 'en' ? '/en/generate/' : '/generer/') + '?c=' + item.s;
  return JSON.stringify({ title: t.title(item[L]), body: t.body, image: SITE + '/img/c/' + item.s + '-apres.webp', url: SITE + page + '?utm_source=push', gen: SITE + gen + '&utm_source=push', slug: item.s, tag: 'sa-daily', actions: [{ action: 'gen', title: t.gen }, { action: 'see', title: t.see }] });
}

async function subscribe(b) {
  const sub = cleanSub(b.sub);
  if (!sub) return { error: 'bad_sub' };
  const tz = Math.max(-840, Math.min(840, Math.trunc(Number(b.tz)) || 0));
  const lang = b.lang === 'en' ? 'en' : 'fr', themes = cleanThemes(b.themes);
  const ref = db().collection('PushSubs').doc(idOf(sub.endpoint));
  const old = await ref.get();
  await ref.set({ sub, themes, lang, tz, hour: hourFor(tz), updatedAt: FieldValue.serverTimestamp(), ...(old.exists ? {} : { createdAt: FieldValue.serverTimestamp(), lastDay: '', sent: 0 }) }, { merge: true });
  if (!old.exists) {
    await stat({ subs: 1 });
    // message de bienvenue : la personne voit tout de suite que ça marche
    if (b.welcome) { try { vapid(); await webpush.sendNotification(sub, payload(null, lang, true), { TTL: 3600 }); } catch (e) { console.error('push hello', e.statusCode || e.message); } }
  }
  return { ok: true, themes };
}
async function unsubscribe(b) {
  if (typeof b.endpoint !== 'string') return { error: 'bad_sub' };
  const ref = db().collection('PushSubs').doc(idOf(b.endpoint));
  if ((await ref.get()).exists) { await ref.delete(); await stat({ unsubs: 1 }); }
  return { ok: true };
}
async function click(b) {
  const a = ['gen', 'see', 'open'].includes(b.a) ? b.a : 'open';
  await stat({ clicks: 1, ['click_' + a]: 1 });
  return { ok: true };
}

// Tâche planifiée (chaque heure à la demie)
async function sendHourly() {
  vapid();
  const now = new Date(), h = now.getUTCHours();
  const snap = await db().collection('PushSubs').where('hour', '==', h).limit(5000).get();
  let sent = 0, failed = 0, removed = 0;
  const docs = snap.docs.slice();
  const worker = async () => {
    while (docs.length) {
      const d = docs.shift(), s = d.data();
      const local = new Date(now.getTime() - (s.tz || 0) * 60000), ld = day(local);
      if (s.lastDay === ld) continue;
      const di = Math.floor(local.getTime() / 86400000), themes = cleanThemes(s.themes);
      const item = pick(themes[di % themes.length], Math.floor(di / themes.length)) || pick('mode', di);
      if (!item) continue;
      try {
        await webpush.sendNotification(s.sub, payload(item, s.lang), { TTL: 6 * 3600, urgency: 'normal' });
        sent++; await d.ref.update({ lastDay: ld, lastSlug: item.s, sent: FieldValue.increment(1) });
      } catch (e) {
        if (e.statusCode === 404 || e.statusCode === 410) { removed++; await d.ref.delete().catch(() => {}); }
        else { failed++; console.error('push send', e.statusCode || e.message); }
      }
    }
  };
  await Promise.all(Array.from({ length: 20 }, worker));
  if (sent || failed || removed) await stat({ sent, failed, removed });
  console.log('push', h, 'UTC', { abonnes: snap.size, sent, failed, removed });
}

// Hub admin : abonnés, envois et ouvertures des 14 derniers jours
async function adminStats() {
  const c = await db().collection('PushSubs').count().get();
  const days = [];
  for (let i = 0; i < 14; i++) days.push(day(new Date(Date.now() - i * 86400000)));
  const docs = await db().getAll(...days.map((d) => db().collection('PushStats').doc(d)));
  return { subs: c.data().count, days: docs.map((d, i) => ({ day: days[i], ...(d.exists ? d.data() : {}) })) };
}

module.exports = { VAPID_PRIVATE_KEY, subscribe, unsubscribe, click, sendHourly, adminStats, hourFor };
