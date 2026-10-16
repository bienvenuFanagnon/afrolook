'use strict';
// Coupons flash du jour : archivés une seule fois, avant les coups d'envoi, puis réglés quand les matchs sont terminés.
// Aucun tri a posteriori : les trois coupons de chaque jour sont enregistrés automatiquement, gagnés comme perdus.
// C'est cet historique complet qui sert de preuve sur le site (accueil : derniers coupons gagnants ; bilan : tout).

const coupon = require('../shared/coupon');
const { dayStr } = require('./helpers');
const { isFragile } = require('../engine/fragility');

const COL = 'coupons_flash';
const TIERS = [{ n: 2, nom: 'prudent' }, { n: 3, nom: 'equilibre' }, { n: 5, nom: 'audacieux' }];
const STALE_MS = 3 * 864e5; // un match jamais terminé 3 jours après son coup d'envoi rend sa sélection non évaluable

const titleOf = (m) => `${m.domicile.nomCourt} – ${m.exterieur.nomCourt}`;

/**
 * Enregistre les coupons du jour s'ils n'existent pas encore (jamais remplacés ni modifiés ensuite).
 * Seuls les matchs du jour pas encore commencés et déjà pronostiqués entrent dans le choix.
 * Renvoie le nombre de coupons créés.
 */
async function archiveCoupons(db, now) {
  const jour = dayStr(now);
  const ids = TIERS.map((t) => `${jour}_${t.n}`);
  const existing = await Promise.all(ids.map((id) => db.collection(COL).doc(id).get()));
  if (existing.every((d) => d.exists)) return 0;
  const snap = await db.collection('matches').where('jour', '==', jour).get();
  const list = snap.docs.map((d) => d.data())
    .filter((m) => m.statut === 'prevu' && m.coupDEnvoi > now.toISOString() && m.prono && m.prono.visible !== false && m.prono.marches && !isFragile(m));
  if (list.length < 2) return 0;
  const byId = {};
  const poolMap = {};
  for (const m of list) {
    byId[m.id] = m;
    poolMap[m.id] = m.prono.marches.map((mk) => ({ key: mk.cle, libelle: mk.libelle, famille: mk.famille, pct: mk.pct, fiabilite: mk.fiabilite }));
  }
  let created = 0;
  for (let i = 0; i < TIERS.length; i++) {
    if (existing[i].exists) continue;
    const { n, nom } = TIERS[i];
    const sel = coupon.suggest(poolMap, n);
    if (sel.length !== n) continue;
    const { prob, approx } = coupon.couponProbability(sel.map((s) => ({ matchId: s.matchId, key: s.key, pct: s.pct })), null);
    const doc = {
      id: ids[i], jour, n, nom, creeLe: now.toISOString(), statut: 'ouvert',
      prob: Math.round(prob * 1000) / 1000, approx: !!approx,
      selections: sel.map((s) => {
        const m = byId[s.matchId];
        return {
          matchId: s.matchId, key: s.key, libelle: s.libelle, famille: s.famille, pct: s.pct, titre: titleOf(m),
          dom: m.domicile.nomCourt, ext: m.exterieur.nomCourt, slug: m.slug, leagueSlug: m.leagueSlug, coupDEnvoi: m.coupDEnvoi, ok: null,
        };
      }),
    };
    await db.collection(COL).doc(ids[i]).set(doc);
    created++;
  }
  return created;
}

/** Résultat d'une sélection d'après le match terminé : true, false, ou null (pas encore joué / non évaluable). */
function selectionOutcome(sel, m, now) {
  if (!m) return { ok: null, final: now.getTime() - new Date(sel.coupDEnvoi).getTime() > STALE_MS };
  if (m.statut === 'termine' && m.resultat) {
    const v = m.resultat.marches && m.resultat.marches[sel.key];
    return v === true || v === false ? { ok: v, final: true } : { ok: null, final: true };
  }
  if (m.statut === 'reporte') return { ok: null, final: true };
  return { ok: null, final: now.getTime() - new Date(sel.coupDEnvoi).getTime() > STALE_MS };
}

/**
 * Règle les coupons ouverts : perdu dès qu'une sélection est ratée, gagné quand toutes sont réussies,
 * annulé si une sélection n'est pas évaluable (match reporté, statistique manquante) sans autre sélection ratée.
 * Les matchs sont lus dans les documents « matches » déjà réglés par syncResults.
 */
async function settleCoupons(db, now) {
  const snap = await db.collection(COL).where('statut', '==', 'ouvert').get();
  let settled = 0;
  for (const d of snap.docs) {
    const c = d.data();
    const out = [];
    for (const s of c.selections) {
      const md = await db.collection('matches').doc(String(s.matchId)).get();
      out.push(selectionOutcome(s, md.exists ? md.data() : null, now));
    }
    const selections = c.selections.map((s, i) => Object.assign({}, s, { ok: out[i].ok }));
    let statut = 'ouvert';
    if (out.some((o) => o.ok === false)) statut = 'perdu';
    else if (out.every((o) => o.final)) statut = out.every((o) => o.ok === true) ? 'gagne' : 'annule';
    const changed = statut !== 'ouvert' || out.some((o, i) => o.ok !== c.selections[i].ok);
    if (!changed) continue;
    await db.collection(COL).doc(c.id).set(Object.assign({}, c, { selections, statut, reglesLe: statut === 'ouvert' ? null : now.toISOString() }));
    if (statut !== 'ouvert') settled++;
  }
  return settled;
}

/** Statistiques d'une liste de coupons : réglés (gagnés + perdus), taux, probabilité annoncée moyenne, par niveau. */
function summarizeCoupons(list) {
  const agg = () => ({ gagnes: 0, perdus: 0, enCours: 0, annules: 0, probSum: 0 });
  const total = agg();
  const par = {};
  for (const c of list) {
    const a = par[c.nom] || (par[c.nom] = agg());
    for (const t of [total, a]) {
      if (c.statut === 'gagne') { t.gagnes++; t.probSum += c.prob; } else if (c.statut === 'perdu') { t.perdus++; t.probSum += c.prob; } else if (c.statut === 'annule') t.annules++; else t.enCours++;
    }
  }
  const fin = (t) => {
    const n = t.gagnes + t.perdus;
    return { gagnes: t.gagnes, perdus: t.perdus, enCours: t.enCours, annules: t.annules, n, taux: n ? Math.round((t.gagnes / n) * 100) : null, annonce: n ? Math.round((t.probSum / n) * 100) : null };
  };
  const out = fin(total);
  out.parNiveau = Object.fromEntries(Object.entries(par).map(([k, v]) => [k, fin(v)]));
  return out;
}

module.exports = { COL, TIERS, archiveCoupons, settleCoupons, summarizeCoupons, selectionOutcome };
