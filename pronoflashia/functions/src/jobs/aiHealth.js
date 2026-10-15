'use strict';
// aiHealthCheck : petit appel de test à chaque fournisseur, état enregistré dans ai_status/current (+ historique court).

const SLOW_MS = 8000;

async function aiHealthCheck({ db, providers, now }, report) {
  const t = now || new Date();
  const messages = [
    { role: 'system', content: 'Réponds uniquement par un objet JSON.' },
    { role: 'user', content: 'Réponds exactement : {"ok":true}' },
  ];
  const res = {};
  let actif = null;
  for (const p of providers) {
    const t0 = Date.now();
    try {
      const out = await p.call(messages);
      const ok = /"ok"\s*:\s*true/.test(String(out));
      res[p.name] = { ok, latenceMs: Date.now() - t0, erreur: ok ? null : 'réponse inattendue' };
      if (ok && !actif) actif = p.name;
    } catch (e) {
      res[p.name] = { ok: false, latenceMs: Date.now() - t0, erreur: String(e.message || e).slice(0, 200) };
    }
  }
  const act = actif ? res[actif] : null;
  const etat = !act ? 'panne' : act.latenceMs >= SLOW_MS ? 'lent' : 'ok';
  const upd = { etat, fournisseur: actif, dernierTestLe: t.toISOString(), providers: res };
  if (act) { upd.dernierTestOk = t.toISOString(); upd.latenceMs = act.latenceMs; }
  else upd.derniereErreur = Object.entries(res).map(([k, v]) => `${k} : ${v.erreur}`).join(' · ').slice(0, 300);
  await db.collection('ai_status').doc('current').set(upd, { merge: true });
  await db.collection('ai_status_log').doc(t.toISOString().replace(/[:.]/g, '-')).set({
    le: t.toISOString(), etat, fournisseur: actif, latenceMs: act ? act.latenceMs : null,
    // à configurer dans la console Firestore : stratégie TTL sur le champ expireAt
    expireAt: new Date(t.getTime() + 7 * 864e5),
  });
  report.traites = providers.length;
  report.infos.etat = etat;
  if (etat === 'panne') report.erreurs.push('Aucun fournisseur d\'IA ne répond');
  return etat;
}

module.exports = { aiHealthCheck, SLOW_MS };
