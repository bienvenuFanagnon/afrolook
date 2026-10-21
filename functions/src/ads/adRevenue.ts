import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Revenus publicitaires par emplacement (AdMob et Appodeal) et pubs Afrolook envoyées par notification.
 *
 * - `recordAdRevenue` : l'application envoie, toutes les 5 minutes environ, le total des revenus estimés par emplacement (événements « paid » des SDK) ;
 *   le serveur les additionne par jour dans `AdRevenueDaily/{AAAAMMJJ}`. Aucune règle Firestore à ouvrir : seul le serveur écrit.
 * - `adRevenueReport` (administrateurs) : les derniers jours, emplacement par emplacement.
 * - `adPushList` / `setAdPush` (administrateurs) : choisir quelles pubs Afrolook actives peuvent aussi partir en notification (plafond d'envois par pub).
 */
const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];
const PLACEMENT = /^[a-z0-9_:\-]{1,40}$/;
const CURRENCY = /^[A-Z]{3}$/;
const MAX_ITEMS = 40;
const MAX_MICROS_PER_ITEM = 5_000_000_000; // 5 000 unités : au-delà, valeur aberrante (ignorée)

const dayKey = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, "");

async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const role = String((await db.collection("Users").doc(uid).get()).data()?.["role"] ?? "");
  if (!ADMIN_ROLES.includes(role)) throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  return uid;
}

export interface RevenueItem { p: string; c: string; m: number; n: number }

/** Garde les lignes valides (emplacement, devise, montant et nombre plausibles) ; le reste est ignoré sans erreur. */
export function cleanRevenueItems(raw: unknown): RevenueItem[] {
  if (!Array.isArray(raw)) return [];
  const out: RevenueItem[] = [];
  for (const it of raw.slice(0, MAX_ITEMS)) {
    const o = (it ?? {}) as Record<string, unknown>;
    const p = String(o["p"] ?? ""), c = String(o["c"] ?? "").toUpperCase(), m = Number(o["m"]), n = Math.trunc(Number(o["n"]));
    if (!PLACEMENT.test(p) || !CURRENCY.test(c) || !Number.isFinite(m) || m < 0 || m > MAX_MICROS_PER_ITEM || !Number.isFinite(n) || n < 0 || n > 5000) continue;
    out.push({ p, c, m: Math.round(m), n });
  }
  return out;
}

export const recordAdRevenue = onCall({ region: "us-central1", timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const items = cleanRevenueItems((request.data as Record<string, unknown> | undefined)?.["items"]);
  if (!items.length) return { saved: 0 };
  const rev: Record<string, Record<string, { micros: FieldValue; n: FieldValue }>> = {};
  for (const it of items) {
    rev[it.p] = rev[it.p] ?? {};
    rev[it.p][it.c] = { micros: FieldValue.increment(it.m), n: FieldValue.increment(it.n) };
  }
  await db.collection("AdRevenueDaily").doc(dayKey()).set({ day: dayKey(), rev }, { merge: true });
  return { saved: items.length };
});

export const adRevenueReport = onCall({ region: "us-central1", timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  await requireAdmin(request);
  const days = Math.max(1, Math.min(30, Math.trunc(Number((request.data as Record<string, unknown> | undefined)?.["days"] ?? 7)) || 7));
  const keys = Array.from({ length: days }, (_, i) => dayKey(Date.now() - i * 86400000));
  const snaps = await db.getAll(...keys.map((k) => db.collection("AdRevenueDaily").doc(k)));
  return { days: snaps.map((s, i) => ({ day: keys[i], rev: (s.data()?.["rev"] ?? {}) as Record<string, unknown> })) };
});

export const adPushList = onCall({ region: "us-central1", timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  await requireAdmin(request);
  const snap = await db.collection("Advertisements").where("status", "==", "active").limit(40).get();
  return {
    ads: snap.docs.map((d) => {
      const a = d.data();
      return { id: d.id, postId: String(a["postId"] ?? ""), actionType: String(a["actionType"] ?? ""), views: Number(a["views"] ?? 0), clicks: Number(a["clicks"] ?? 0),
        pushEnabled: a["pushEnabled"] === true, pushSent: Number(a["pushSent"] ?? 0), pushLimit: Number(a["pushLimit"] ?? 5000) };
    }),
  };
});

export const setAdPush = onCall({ region: "us-central1", timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const adId = String(d["adId"] ?? "");
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(adId)) throw new HttpsError("invalid-argument", "Pub invalide");
  const patch: Record<string, unknown> = { pushEnabled: d["enabled"] === true };
  if (d["limit"] !== undefined) patch["pushLimit"] = Math.max(100, Math.min(100000, Math.trunc(Number(d["limit"])) || 5000));
  await db.collection("Advertisements").doc(adId).update(patch);
  return { ok: true };
});
