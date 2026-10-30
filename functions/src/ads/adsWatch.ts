import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { notifyAdminsAll } from "../shared/user_notify";
import { INTERNAL_PUBLISHERS } from "./adsEngine_logic";
import { Alert, AdDay, PubDay, Severity, detectAdAnomalies, detectPubAnomalies, worse } from "./adsGuard";

/**
 * Afrolook Ads : surveillance des plateformes (toutes les heures).
 * Compare les vues, clics, affichages invalides, appels depuis un autre domaine et personnes différentes de chaque plateforme (et de chaque annonce
 * sur chaque plateforme) à leur propre historique et à leur audience déclarée. Chaque anomalie devient une ALERTE (collection AdsAlerts) :
 *  - l'administration est prévenue (notification dans l'application et sur le site ; e-mail pour les alertes de gravité haute) ;
 *  - une alerte de gravité haute sur un site ou une application externe met un BLOCAGE DES PAIEMENTS (reviewHold) jusqu'à vérification : la diffusion continue,
 *    mais plus aucun gain n'est versable (voir payable() dans adsGuard).
 * Gestion par l'administration : adsPubAdminList (alertes) et adsPubAdminReview (cible « alert »).
 */
const OPTS = { region: "us-central1" as const, memory: "256MiB" as const };
const DAY_MS = 86_400_000;
const dayOf = (t: number): string => new Date(t).toISOString().slice(0, 10);
const rank = (s: Severity): number => (s === "high" ? 2 : 1);

export type AlertStatus = "open" | "reviewed" | "held";
export interface AlertDoc { id: string; day: string; pub: string; pubName: string; adId: string; type: string; severity: Severity; message: string; metrics: Record<string, number>; status: AlertStatus; createdAt: number; updatedAt: number; autoHold: boolean; reviewedBy?: string; reviewedAt?: number; note?: string }

const external = (pub: string): boolean => /^ap_[a-z0-9]{10}$/.test(pub);

async function pubNames(pubs: string[]): Promise<Map<string, { name: string; declared?: number; hold?: boolean }>> {
  const out = new Map<string, { name: string; declared?: number; hold?: boolean }>();
  const ext = pubs.filter(external);
  for (const p of pubs) if (!external(p)) out.set(p, { name: INTERNAL_PUBLISHERS[p]?.name ?? p });
  for (let i = 0; i < ext.length; i += 100) {
    const docs = await db.getAll(...ext.slice(i, i + 100).map((id) => db.collection("AdProperties").doc(id)));
    for (const d of docs) { const v = d.data(); out.set(d.id, { name: String(v?.["name"] ?? d.id), declared: Number(v?.["audienceDeclared"]) || undefined, hold: v?.["reviewHold"] === true }); }
  }
  return out;
}

/** Enregistre (ou met à jour) une alerte du jour. Renvoie true si l'administration doit être prévenue (nouvelle alerte, ou gravité qui monte). */
async function raise(day: string, pub: string, pubName: string, adId: string, a: Alert, now: number): Promise<{ notify: boolean; high: boolean }> {
  const id = `${day}_${pub}_${adId || "-"}_${a.type}`;
  const ref = db.collection("AdsAlerts").doc(id);
  const cur = (await ref.get()).data() as AlertDoc | undefined;
  if (!cur) {
    await ref.set({ id, day, pub, pubName, adId, type: a.type, severity: a.severity, message: a.message, metrics: a.metrics, status: "open", createdAt: now, updatedAt: now, autoHold: false } satisfies AlertDoc);
    return { notify: true, high: a.severity === "high" };
  }
  const sev = worse(cur.severity, a.severity), escalated = rank(sev) > rank(cur.severity);
  const upd: Record<string, unknown> = { message: a.message, metrics: a.metrics, severity: sev, updatedAt: now };
  if (escalated && cur.status === "reviewed") upd["status"] = "open"; // vérifiée plus tôt, mais la situation s'aggrave : à revoir
  await ref.update(upd);
  return { notify: escalated, high: sev === "high" };
}

export async function runWatch(now = Date.now()): Promise<{ raised: number; held: number }> {
  const today = dayOf(now), yesterday = dayOf(now - DAY_MS);
  const days = Array.from({ length: 8 }, (_, i) => dayOf(now - i * DAY_MS)); // aujourd'hui + 7 jours précédents
  const [pubSnap, adSnap] = await Promise.all([
    db.collection("AdsPubDaily").where("day", "in", days).limit(3000).get(),
    db.collection("AdsDaily").where("day", "==", today).limit(3000).get(),
  ]);

  const byPub = new Map<string, { today?: Record<string, unknown>; past: number[] }>();
  for (const d of pubSnap.docs) {
    const v = d.data(), pub = String(v["pub"]);
    const e = byPub.get(pub) ?? { past: [] };
    if (v["day"] === today) e.today = v; else e.past.push(Number(v["valid"]) || 0);
    byPub.set(pub, e);
  }
  const names = await pubNames([...byPub.keys()]);
  const uniques = new Map<string, number>();
  await Promise.all([...byPub.keys()].filter(external).map(async (p) => { const n = Number((await db.collection("AdsHll").doc(`${p}_${yesterday}`).get()).data()?.["n"]); if (n) uniques.set(p, n); }));

  let raised = 0, held = 0;
  const notices: Array<{ pub: string; name: string; alert: Alert; high: boolean }> = [];
  const handle = async (pub: string, name: string, adId: string, alerts: Alert[]) => {
    for (const a of alerts) {
      const r = await raise(today, pub, name, adId, a, now);
      raised++;
      if (r.notify) notices.push({ pub, name: adId ? `${name} · annonce ${adId.slice(0, 8)}` : name, alert: a, high: r.high });
      if (a.severity === "high" && external(pub) && !names.get(pub)?.hold) {
        await db.collection("AdProperties").doc(pub).update({ reviewHold: true, holdReason: a.message.slice(0, 200), holdAt: now }).then(() => { held++; names.set(pub, { ...(names.get(pub) ?? { name }), hold: true }); }).catch((e) => console.error("[adsWatch] blocage", pub, e));
        await db.collection("AdsAlerts").doc(`${today}_${pub}_${adId || "-"}_${a.type}`).update({ autoHold: true }).catch(() => undefined);
      }
    }
  };

  for (const [pub, e] of byPub) {
    const t = e.today; if (!t) continue;
    const info = names.get(pub);
    const m: PubDay = {
      valid: Number(t["valid"]) || 0, invalid: Number(t["invalid"]) || 0, clicks: Number(t["clicks"]) || 0, foreign: Number(t["foreign"]) || 0,
      baselineValid: e.past.length ? e.past.reduce((n, x) => n + x, 0) / e.past.length : 0,
      ...(info?.declared ? { declaredMonthly: info.declared } : {}), ...(uniques.has(pub) ? { uniquesYesterday: uniques.get(pub) } : {}),
    };
    await handle(pub, info?.name ?? pub, "", detectPubAnomalies(m));
  }
  for (const d of adSnap.docs) {
    const v = d.data(), pub = String(v["pub"]), adId = String(v["adId"]);
    const m: AdDay = { views: Number(v["views"]) || 0, clicks: Number(v["clicks"]) || 0 };
    const alerts = detectAdAnomalies(m);
    if (alerts.length) await handle(pub, names.get(pub)?.name ?? INTERNAL_PUBLISHERS[pub]?.name ?? pub, adId, alerts);
  }

  // l'administration est prévenue une seule fois par alerte (et de nouveau si elle s'aggrave) ; e-mail seulement pour la gravité haute
  for (const n of notices.slice(0, 10)) {
    await notifyAdminsAll({
      title: `${n.high ? "🚨" : "⚠️"} Alerte régie : ${n.name}`, message: n.alert.message, target: "ADMIN_ADS", refId: n.pub,
      ...(n.high ? { email: { subject: `Alerte régie Afrolook Ads : ${n.name}`, heading: "Alerte à vérifier", icon: "🚨", intro: n.alert.message, rows: [["Plateforme", n.name], ["Gravité", "Haute"]], outro: "Les paiements de cette plateforme sont bloqués tant que l'alerte n'est pas vérifiée dans l'administration de la régie.", tone: "no" as const } } : {}),
    });
  }
  if (notices.length > 10) await notifyAdminsAll({ title: "⚠️ Plusieurs alertes régie", message: `${notices.length} alertes à vérifier dans l'administration de la régie.`, target: "ADMIN_ADS" });
  return { raised, held };
}

export const adsWatch = onSchedule({ ...OPTS, schedule: "every 60 minutes", timeoutSeconds: 300 }, async () => {
  const r = await runWatch();
  console.log("[adsWatch]", JSON.stringify(r));
});

// ─── Administration ─────────────────────────────────────────────────────────────────────────────────────────────────

/** Alertes pour l'administration : « open » = à vérifier (défaut), « all » = toutes ; les plus graves et les plus récentes d'abord. */
export async function listAlerts(status: string): Promise<AlertDoc[]> {
  const base = db.collection("AdsAlerts");
  const snap = await (status === "all" ? base.orderBy("createdAt", "desc") : base.where("status", "==", status === "reviewed" ? "reviewed" : status === "held" ? "held" : "open")).limit(200).get();
  return snap.docs.map((d) => d.data() as AlertDoc).sort((a, b) => rank(b.severity) - rank(a.severity) || b.updatedAt - a.updatedAt);
}

/** Décisions : ack = vérifiée, rien d'anormal ; hold = bloquer les paiements de la plateforme ; release = lever le blocage. */
export async function reviewAlert(adminUid: string, id: string, decision: string, note: string): Promise<void> {
  const ref = db.collection("AdsAlerts").doc(id);
  const a = (await ref.get()).data() as AlertDoc | undefined;
  if (!a) throw new Error("alerte_inconnue");
  const t = Date.now();
  if (decision === "hold" && external(a.pub)) {
    await db.collection("AdProperties").doc(a.pub).update({ reviewHold: true, holdReason: (note || a.message).slice(0, 200), holdAt: t });
    await ref.update({ status: "held", reviewedBy: adminUid, reviewedAt: t, note, updatedAt: t });
  } else if (decision === "release" && external(a.pub)) {
    await db.collection("AdProperties").doc(a.pub).update({ reviewHold: false, holdReason: FieldValue.delete(), holdAt: FieldValue.delete() });
    await ref.update({ status: "reviewed", reviewedBy: adminUid, reviewedAt: t, note, updatedAt: t });
  } else if (decision === "ack") {
    await ref.update({ status: "reviewed", reviewedBy: adminUid, reviewedAt: t, note, updatedAt: t });
  } else throw new Error("decision_invalide");
  await db.collection("AdsAudit").add({ at: t, by: adminUid, target: "alert", id, decision, reason: note.slice(0, 300) }).catch(() => undefined);
}

/** Vrai si la plateforme a une alerte à vérifier ou un blocage : aucun versement (utilisé par le paiement des diffuseurs). */
export async function hasOpenAlert(pub: string): Promise<boolean> {
  const snap = await db.collection("AdsAlerts").where("pub", "==", pub).limit(60).get();
  return snap.docs.some((d) => d.data()["status"] !== "reviewed");
}
