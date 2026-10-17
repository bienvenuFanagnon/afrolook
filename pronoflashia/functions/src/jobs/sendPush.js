'use strict';
// sendPush : notifications automatiques. Tourne toutes les 15 minutes et décide seule :
//  - 3 créneaux par jour (matin : coupons du jour, midi : pronostic le plus confiant, soir : coupon du soir), chacun envoyé une seule fois ;
//  - une alerte une heure environ avant les matchs des équipes suivies par chaque abonné (2 par jour au plus) ;
//  - des notifications d'actualité à heure variable (une actu de star, de pépite ou de classico dès qu'elle sort, voir push/buzz.js) : 1 toutes les 3 heures
//    au plus, 2 par jour et par abonné, jamais la nuit (heure locale de l'abonné) ; tous types confondus, 4 par jour et par abonné au plus.
// Un abonnement refusé par le service de notification (404, 410) est supprimé.

const { dayStr } = require('./helpers');
const M = require('../push/messages');
const buzz = require('../push/buzz');
const { saveCard, COL: CARDS } = require('../push/card');

const SLOTS = [
  { id: 'matin', from: 7 * 60 + 30, to: 10 * 60 + 30 },
  { id: 'midi', from: 12 * 60 + 30, to: 15 * 60 + 30 },
  { id: 'soir', from: 16 * 60 + 30, to: 20 * 60 },
];
const TEAM_MAX_PER_DAY = 2;
const MAX_PER_DAY = 4;      // notifications par abonné et par jour, tous types confondus (réglable dans l'admin)
const ACTU_MAX_PER_DAY = 2; // dont notifications d'actualité
const ACTU_GAP_MS = 3 * 3600e3;
const CONCURRENCY = 25;

const usedToday = (s, jour) => (s.nJour === jour ? s.n || 0 : 0);
const actuToday = (s, jour) => (s.actuJour === jour ? s.actuN || 0 : 0);
/** Minute locale de l'abonné (décalage tzo = minutes UTC − locale, comme Date.getTimezoneOffset ; UTC si inconnu). */
const localMinute = (s, now) => (((now.getUTCHours() * 60 + now.getUTCMinutes() - (Number.isFinite(s.tzo) ? s.tzo : 0)) % 1440) + 1440) % 1440;
const isQuiet = (s, now) => { const m = localMinute(s, now); return m < 7 * 60 || m >= 22 * 60; };

/** Réserve un envoi (un seul passage peut l'obtenir). */
async function claim(db, id, doc) {
  const ref = db.collection('push_log').doc(id);
  let won = false;
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.exists) return;
    tx.set(ref, doc);
    won = true;
  });
  return won;
}

/**
 * Envoie `payloadFor(sub)` à chaque abonné de la liste ; renvoie { envoyes, echecs, retires }.
 * track : { jour, kind } pour compter l'envoi dans les plafonds quotidiens de chaque abonné.
 */
async function deliver(db, send, subs, payloadFor, deadline, track) {
  const out = { envoyes: 0, echecs: 0, retires: 0 };
  const erreurs = []; // quelques causes (code et message), pour comprendre un envoi qui n'arrive pas
  let next = 0;
  const worker = async () => {
    while (next < subs.length) {
      if (deadline && Date.now() > deadline) return;
      const sub = subs[next++];
      const payload = payloadFor(sub);
      if (!payload) continue;
      try {
        await send(sub, payload);
        out.envoyes++;
        if (track) {
          const n = usedToday(sub, track.jour) + 1, a = actuToday(sub, track.jour) + (track.kind === 'actu' ? 1 : 0);
          Object.assign(sub, { nJour: track.jour, n, actuJour: track.jour, actuN: a, echecs: 0 });
          await db.collection('push_subs').doc(sub.id).set(sub);
        } else if (sub.echecs) await db.collection('push_subs').doc(sub.id).set(Object.assign({}, sub, { echecs: 0 }));
      } catch (e) {
        const code = e && e.statusCode;
        if (erreurs.length < 5) erreurs.push(`${code || 'erreur'} ${String((e && (e.body || e.message)) || '').slice(0, 120)}`.trim());
        if (code === 404 || code === 410) { await db.collection('push_subs').doc(sub.id).delete(); out.retires++; }
        else {
          out.echecs++;
          const n = (sub.echecs || 0) + 1;
          if (n >= 5) { await db.collection('push_subs').doc(sub.id).delete(); out.retires++; } else await db.collection('push_subs').doc(sub.id).set(Object.assign({}, sub, { echecs: n }));
        }
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, Math.max(1, subs.length)) }, worker));
  if (erreurs.length) out.erreurs = erreurs;
  return out;
}

async function loadSubs(db) { return (await db.collection('push_subs').get()).docs.map((d) => d.data()); }

/** Enregistre la carte de chaque message et y ajoute l'adresse de l'image. */
async function attachImages(db, msgs, now) {
  for (const m of Object.values(msgs)) if (m && m.carte) m.image = await saveCard(db, m.carte, now);
}

async function runSlot(db, send, slot, now, jour, subs, report, deadline) {
  const id = `${jour}_${slot.id}`;
  if ((await db.collection('push_log').doc(id).get()).exists) return;
  let built;
  if (slot.id === 'matin') {
    const coupons = (await db.collection('coupons_flash').where('jour', '==', jour).get()).docs.map((d) => d.data());
    built = (lang) => M.matin(coupons, lang);
  } else {
    const matches = (await db.collection('matches').where('jour', '==', jour).get()).docs.map((d) => d.data()).filter((m) => m.coupDEnvoi > now.toISOString());
    built = (lang) => (slot.id === 'midi' ? M.midi(matches, lang) : M.soir(matches, lang));
  }
  const msgs = { fr: built('fr'), en: built('en') };
  if (msgs.fr) await attachImages(db, msgs, now);
  if (!msgs.fr) { await db.collection('push_log').doc(id).set({ id, slot: slot.id, jour, au: now.toISOString(), ignore: 'rien à annoncer', envoyes: 0 }); return; }
  if (!(await claim(db, id, { id, slot: slot.id, jour, au: now.toISOString(), abonnes: subs.length, envoyes: 0 }))) return;
  const r = await deliver(db, send, subs, (sub) => msgs[sub.lang === 'en' ? 'en' : 'fr'], deadline, { jour, kind: slot.id });
  await db.collection('push_log').doc(id).set({ id, slot: slot.id, jour, au: now.toISOString(), abonnes: subs.length, ...r });
  report.infos[slot.id] = r;
  report.traites += r.envoyes;
}

async function runTeams(db, send, now, jour, subs, maxJour, report, deadline) {
  const from = new Date(now.getTime() + 45 * 60e3).toISOString(), to = new Date(now.getTime() + 105 * 60e3).toISOString();
  const matches = (await db.collection('matches').where('coupDEnvoi', '>=', from).where('coupDEnvoi', '<=', to).get()).docs.map((d) => d.data()).filter((m) => m.statut === 'prevu');
  let sent = 0;
  for (const m of matches) {
    const ids = [m.domicile.teamId, m.exterieur.teamId].filter((x) => x != null).map(String);
    const targets = subs.filter((s) => (s.equipes || []).some((t) => ids.includes(t)) && !(s.equipesJour === jour && (s.equipesN || 0) >= TEAM_MAX_PER_DAY) && usedToday(s, jour) < maxJour && !isQuiet(s, now));
    if (!targets.length) continue;
    if (!(await claim(db, `eq_${m.id}`, { id: `eq_${m.id}`, slot: 'equipe', jour, au: now.toISOString(), abonnes: targets.length }))) continue;
    const msgs = { fr: M.equipe(m, 'fr'), en: M.equipe(m, 'en') };
    await attachImages(db, msgs, now);
    const r = await deliver(db, send, targets, (sub) => msgs[sub.lang === 'en' ? 'en' : 'fr'], deadline, { jour, kind: 'equipe' });
    // plafond quotidien : compté une fois par abonné atteint
    for (const s of targets) {
      const ref = db.collection('push_subs').doc(s.id);
      const cur = await ref.get();
      if (!cur.exists) continue;
      const c = cur.data();
      const n = (c.equipesJour === jour ? c.equipesN || 0 : 0) + 1;
      await ref.set(Object.assign({}, c, { equipesJour: jour, equipesN: n }));
      // la liste en mémoire sert aux matchs suivants de ce même passage : le plafond doit y apparaître aussi
      s.equipesJour = jour; s.equipesN = n;
    }
    await db.collection('push_log').doc(`eq_${m.id}`).set({ id: `eq_${m.id}`, slot: 'equipe', jour, au: now.toISOString(), match: m.id, abonnes: targets.length, ...r });
    sent += r.envoyes;
  }
  if (matches.length) report.infos.alertesEquipes = sent;
  report.traites += sent;
}

const exists = async (db, id) => (await db.collection('push_log').doc(id).get()).exists;

/**
 * Notification d'actualité à heure variable : une seule par passage, au mieux une toutes les 3 heures.
 * Candidats : le gros match du jour (classico, choc de grands clubs) et les actus qui font parler (voir push/buzz.js).
 * Une actu de plus de SEUIL points part chez tous les abonnés éligibles ; entre 3 points et le seuil, chez ceux qui suivent l'équipe citée.
 */
async function runActu({ db, send, now, jour, subs, cfg, maxJour, providers, report, deadline }) {
  const st = (await db.collection('push_state').doc('actu').get()).data() || {};
  if (st.au && now.getTime() - new Date(st.au).getTime() < ACTU_GAP_MS) return;
  const ok = subs.filter((s) => !isQuiet(s, now) && usedToday(s, jour) < maxJour && actuToday(s, jour) < ACTU_MAX_PER_DAY);
  if (!ok.length) return;
  const seuil = Number(cfg.seuil) || buzz.SEUIL;
  const extra = Array.isArray(cfg.vedettes) ? cfg.vedettes : [];
  const cands = [];
  const matches = (await db.collection('matches').where('jour', '==', jour).get()).docs.map((d) => d.data());
  const gm = buzz.grosMatch(matches, now);
  if (gm) cands.push({ type: 'choc', score: 100, gm, id: `choc_${gm.m.id}` });
  const cutoff = new Date(now.getTime() - buzz.MAX_AGE_H * 3600e3).toISOString();
  for (const d of (await db.collection('news').where('date', '>=', cutoff).get()).docs) {
    const n = d.data();
    const a = buzz.assess(n, now, extra);
    if (a.sensible || a.score < buzz.SEUIL_EQUIPE) continue;
    cands.push({ type: 'actu', score: a.score, n, a, id: `actu_${n.id}` });
  }
  cands.sort((x, y) => y.score - x.score);
  for (const c of cands) {
    let aud;
    if (c.type === 'choc') aud = ok;
    else if (c.score >= seuil) aud = ok.filter((s) => s.lang === c.n.lang || (!s.lang && c.n.lang === 'fr'));
    else aud = ok.filter((s) => s.lang === c.n.lang && (s.equipes || []).some((t) => (c.n.teamIds || []).includes(t)));
    if (!aud.length || await exists(db, c.id)) continue;
    // une même histoire reprise par plusieurs sites ne part qu'une fois par jour
    const topic = c.type === 'actu' ? `${c.a.star || c.a.club || c.n.id}_${buzz.mainTheme(c.a)}`.toLowerCase().replace(/[^a-z0-9]+/g, '-') : null;
    if (topic && (await db.collection('push_state').doc(`sujet_${jour}_${topic}`).get()).exists) continue;
    if (!(await claim(db, c.id, { id: c.id, slot: 'actu', jour, au: now.toISOString(), abonnes: aud.length, envoyes: 0 }))) continue;
    if (topic) await db.collection('push_state').doc(`sujet_${jour}_${topic}`).set({ jour, au: now.toISOString() });
    const msgs = {};
    for (const lang of c.type === 'choc' ? ['fr', 'en'] : [c.n.lang === 'en' ? 'en' : 'fr']) {
      msgs[lang] = c.type === 'choc' ? M.choc(c.gm, lang) : M.actu(await buzz.buildHook(c.n, c.a, lang, providers), c.n, lang);
    }
    await attachImages(db, msgs, now);
    const r = await deliver(db, send, aud, (sub) => msgs[sub.lang === 'en' && msgs.en ? 'en' : 'fr'] || msgs.fr || msgs.en, deadline, { jour, kind: 'actu' });
    const sujet = c.type === 'choc' ? 'choc' : (c.a.star || c.a.club || c.n.source);
    await db.collection('push_log').doc(c.id).set({ id: c.id, slot: 'actu', jour, au: now.toISOString(), abonnes: aud.length, sujet: String(sujet).slice(0, 60), methode: c.type === 'actu' ? (msgs[Object.keys(msgs)[0]].methode || null) : null, score: c.score === 100 ? null : c.score, ...r });
    await db.collection('push_state').doc('actu').set({ au: now.toISOString(), jour, id: c.id });
    report.infos.actu = { sujet, score: c.score === 100 ? null : c.score, ...r };
    report.traites += r.envoyes;
    return; // une seule notification d'actualité par passage
  }
}

/** opts : { db, send(sub, payload), now, budgetMs, providers } */
async function sendPush(opts, report) {
  const { db, send } = opts;
  const now = opts.now || new Date();
  const cfgDoc = await db.collection('config').doc('push').get();
  const cfg = cfgDoc.exists ? cfgDoc.data() : {};
  if (cfg.actif === false) { report.infos.actif = false; return; }
  const maxJour = Math.min(8, Math.max(1, Number(cfg.maxJour) || MAX_PER_DAY));
  const jour = dayStr(now);
  const minute = now.getUTCHours() * 60 + now.getUTCMinutes();
  const deadline = opts.budgetMs ? Date.now() + opts.budgetMs : null;
  const due = SLOTS.filter((s) => minute >= s.from && minute < s.to);
  const subs = await loadSubs(db);
  report.infos.abonnes = subs.length;
  if (!subs.length) return;
  for (const s of due) await runSlot(db, send, s, now, jour, subs.filter((x) => usedToday(x, jour) < maxJour), report, deadline);
  await runTeams(db, send, now, jour, subs.filter((x) => (x.equipes || []).length), maxJour, report, deadline);
  await runActu({ db, send, now, jour, subs, cfg, maxJour, providers: opts.providers, report, deadline });
  // nettoyage : les cartes d'images de plus de 20 jours ne servent plus
  const old = await db.collection(CARDS).where('creeLe', '<', new Date(now.getTime() - 20 * 864e5).toISOString()).limit(100).get();
  for (const d of old.docs) await db.collection(CARDS).doc(d.id).delete();
}

module.exports = { sendPush, deliver, loadSubs, runActu, SLOTS, TEAM_MAX_PER_DAY, MAX_PER_DAY, ACTU_MAX_PER_DAY, isQuiet, localMinute };
