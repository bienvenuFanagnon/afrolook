'use strict';
// sendPush : notifications automatiques. Tourne toutes les 15 minutes et décide seule :
//  - 3 créneaux par jour (matin : coupons du jour, midi : pronostic le plus confiant, soir : coupon du soir), chacun envoyé une seule fois ;
//  - une alerte une heure environ avant les matchs des équipes suivies par chaque abonné (2 par jour au plus).
// Un abonnement refusé par le service de notification (404, 410) est supprimé.

const { dayStr } = require('./helpers');
const M = require('../push/messages');

const SLOTS = [
  { id: 'matin', from: 7 * 60 + 30, to: 10 * 60 + 30 },
  { id: 'midi', from: 12 * 60 + 30, to: 15 * 60 + 30 },
  { id: 'soir', from: 16 * 60 + 30, to: 20 * 60 },
];
const TEAM_MAX_PER_DAY = 2;
const CONCURRENCY = 25;

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

/** Envoie `payloadFor(sub)` à chaque abonné de la liste ; renvoie { envoyes, echecs, retires }. */
async function deliver(db, send, subs, payloadFor, deadline) {
  const out = { envoyes: 0, echecs: 0, retires: 0 };
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
        if (sub.echecs) await db.collection('push_subs').doc(sub.id).set(Object.assign({}, sub, { echecs: 0 }));
      } catch (e) {
        const code = e && e.statusCode;
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
  return out;
}

async function loadSubs(db) { return (await db.collection('push_subs').get()).docs.map((d) => d.data()); }

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
  if (!msgs.fr) { await db.collection('push_log').doc(id).set({ id, slot: slot.id, jour, au: now.toISOString(), ignore: 'rien à annoncer', envoyes: 0 }); return; }
  if (!(await claim(db, id, { id, slot: slot.id, jour, au: now.toISOString(), abonnes: subs.length, envoyes: 0 }))) return;
  const r = await deliver(db, send, subs, (sub) => msgs[sub.lang === 'en' ? 'en' : 'fr'], deadline);
  await db.collection('push_log').doc(id).set({ id, slot: slot.id, jour, au: now.toISOString(), abonnes: subs.length, ...r });
  report.infos[slot.id] = r;
  report.traites += r.envoyes;
}

async function runTeams(db, send, now, jour, subs, report, deadline) {
  const from = new Date(now.getTime() + 45 * 60e3).toISOString(), to = new Date(now.getTime() + 105 * 60e3).toISOString();
  const matches = (await db.collection('matches').where('coupDEnvoi', '>=', from).where('coupDEnvoi', '<=', to).get()).docs.map((d) => d.data()).filter((m) => m.statut === 'prevu');
  let sent = 0;
  for (const m of matches) {
    const ids = [m.domicile.teamId, m.exterieur.teamId].filter((x) => x != null).map(String);
    const targets = subs.filter((s) => (s.equipes || []).some((t) => ids.includes(t)) && !(s.equipesJour === jour && (s.equipesN || 0) >= TEAM_MAX_PER_DAY));
    if (!targets.length) continue;
    if (!(await claim(db, `eq_${m.id}`, { id: `eq_${m.id}`, slot: 'equipe', jour, au: now.toISOString(), abonnes: targets.length }))) continue;
    const msgs = { fr: M.equipe(m, 'fr'), en: M.equipe(m, 'en') };
    const r = await deliver(db, send, targets, (sub) => msgs[sub.lang === 'en' ? 'en' : 'fr'], deadline);
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

/** opts : { db, send(sub, payload), now, budgetMs } */
async function sendPush(opts, report) {
  const { db, send } = opts;
  const now = opts.now || new Date();
  const cfg = await db.collection('config').doc('push').get();
  if (cfg.exists && cfg.data().actif === false) { report.infos.actif = false; return; }
  const jour = dayStr(now);
  const minute = now.getUTCHours() * 60 + now.getUTCMinutes();
  const deadline = opts.budgetMs ? Date.now() + opts.budgetMs : null;
  const due = SLOTS.filter((s) => minute >= s.from && minute < s.to);
  const subs = await loadSubs(db);
  report.infos.abonnes = subs.length;
  if (!subs.length) return;
  for (const s of due) await runSlot(db, send, s, now, jour, subs, report, deadline);
  await runTeams(db, send, now, jour, subs.filter((x) => (x.equipes || []).length), report, deadline);
}

module.exports = { sendPush, SLOTS, TEAM_MAX_PER_DAY };
