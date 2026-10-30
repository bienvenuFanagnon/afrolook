import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { requireAdmin } from "../news/adminAuth";
import { readOfferwallConfig, dayOf } from "./offerwall_logic";
import { Risk, activityFromEvents, riskOf } from "./offerwall_fraud";

/**
 * Administration du mur de tâches (page « Tâches » du hub d'administration). Réservé aux administrateurs.
 *  - offerwallAdminOverview : totaux par statut, courbe par jour, meilleurs gains, comptes suspects ;
 *  - offerwallAdminUser     : recherche d'un utilisateur (identifiant, pseudo ou e-mail) et détail de ses gains ;
 *  - offerwallAdminEvents   : liste d'événements (par défaut ceux « en revue ») ;
 *  - offerwallAdminReview   : approuver ou refuser une tâche mise en revue ;
 *  - offerwallAdminBlock    : suspendre / rétablir un compte pour les tâches.
 * Chaque action est journalisée (AdminActions). Voir docs/OFFERWALL_TACHES.md §12.
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 60, memory: "256MiB" as const };
const DAY = 86_400_000;
const MAX_EVENTS = 3000;

const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : Number(v) || 0);
const s = (v: unknown, n = 200): string => String(v ?? "").slice(0, n);
const clamp = (v: unknown, def: number, min: number, max: number): number => { const x = Math.trunc(Number(v)); return Number.isFinite(x) && x >= min && x <= max ? x : def; };

type Ev = Record<string, unknown> & { id: string };
const evOut = (e: Ev) => ({
  id: e.id, userId: s(e["userId"]), provider: s(e["provider"]), platform: s(e["platform"]), status: s(e["status"]),
  coins: num(e["coins"]), sponsorCoins: num(e["sponsorCoins"]), studioCoins: num(e["studioCoins"]),
  createdAt: num(e["createdAt"]), releaseAt: num(e["releaseAt"]), validatedAt: num(e["validatedAt"]),
  reason: s(e["reason"] ?? e["reviewReason"] ?? ""),
});

async function pseudos(ids: string[]): Promise<Record<string, { pseudo: string; imageUrl: string }>> {
  const out: Record<string, { pseudo: string; imageUrl: string }> = {};
  const uniq = [...new Set(ids)].filter(Boolean).slice(0, 100);
  if (!uniq.length) return out;
  const snaps = await db.getAll(...uniq.map((id) => db.collection("Users").doc(id)));
  for (const sn of snaps) out[sn.id] = { pseudo: s(sn.data()?.["pseudo"], 60), imageUrl: s(sn.data()?.["imageUrl"], 400) };
  return out;
}

async function logAction(adminId: string, type: string, extra: Record<string, unknown>): Promise<void> {
  const ref = db.collection("AdminActions").doc();
  await ref.set({ id: ref.id, type, adminId, at: Date.now(), ...extra }).catch(() => undefined);
}

export const offerwallAdminOverview = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const days = clamp((request.data as Record<string, unknown> | undefined)?.["days"], 7, 1, 90);
  const now = Date.now();
  const cfg = readOfferwallConfig((await db.collection("AppConfig").doc("offerwall").get()).data());
  const snap = await db.collection("OfferwallEvents").where("createdAt", ">=", now - days * DAY).orderBy("createdAt", "desc").limit(MAX_EVENTS).get();
  const events: Ev[] = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

  const byStatus: Record<string, { events: number; coins: number }> = {};
  const perDay = new Map<string, { events: number; coins: number }>();
  const perUser = new Map<string, Ev[]>();
  const byPlatform: Record<string, number> = {};
  // par partenaire de tâches (tapjoy, ayet) : nombre, pièces des utilisateurs, et pour les tâches validées la part de l'application et celle des parrains
  const byProvider: Record<string, { events: number; coins: number; validatedCoins: number; studioCoins: number; sponsorCoins: number }> = {};
  let sponsorCoins = 0, studioCoins = 0;
  for (const e of events) {
    const st = s(e["status"]);
    const c = num(e["coins"]);
    byStatus[st] = { events: (byStatus[st]?.events ?? 0) + 1, coins: (byStatus[st]?.coins ?? 0) + c };
    if (st === "pending" || st === "validee" || st === "en_revue") {
      const d = perDay.get(dayOf(num(e["createdAt"]))) ?? { events: 0, coins: 0 };
      perDay.set(dayOf(num(e["createdAt"])), { events: d.events + 1, coins: d.coins + c });
      byPlatform[s(e["platform"]) || "?"] = (byPlatform[s(e["platform"]) || "?"] ?? 0) + 1;
    }
    if (st === "validee") { sponsorCoins += num(e["sponsorCoins"]); studioCoins += num(e["studioCoins"]); }
    if (st === "pending" || st === "validee" || st === "en_revue") {
      const pk = s(e["provider"]) || "?";
      const p = byProvider[pk] ?? { events: 0, coins: 0, validatedCoins: 0, studioCoins: 0, sponsorCoins: 0 };
      p.events += 1; p.coins += c;
      if (st === "validee") { p.validatedCoins += c; p.studioCoins += num(e["studioCoins"]); p.sponsorCoins += num(e["sponsorCoins"]); }
      byProvider[pk] = p;
    }
    const uid = s(e["userId"]);
    if (uid) perUser.set(uid, [...(perUser.get(uid) ?? []), e]);
  }

  // activité et risque de chaque utilisateur ayant des tâches sur la période
  const users = [...perUser.entries()].map(([userId, list]) => {
    const a = activityFromEvents(list.map((e) => ({ coins: num(e["coins"]), createdAt: num(e["createdAt"]), status: s(e["status"]) })), now, null);
    const validated = list.filter((e) => e["status"] === "validee").reduce((t, e) => t + num(e["coins"]), 0);
    const pending = list.filter((e) => e["status"] === "pending").reduce((t, e) => t + num(e["coins"]), 0);
    const review = list.filter((e) => e["status"] === "en_revue").reduce((t, e) => t + num(e["coins"]), 0);
    return { userId, events: a.events, coins: a.coins, validated, pending, review, risk: riskOf(a, cfg) as Risk };
  });
  const top = [...users].sort((x, y) => y.coins - x.coins).slice(0, 15);
  const suspects = users.filter((u) => u.risk.level !== "faible").sort((x, y) => y.risk.score - x.risk.score).slice(0, 15);
  const names = await pseudos([...top, ...suspects].map((u) => u.userId));
  const dress = (u: (typeof users)[number]) => ({ ...u, pseudo: names[u.userId]?.pseudo ?? "", imageUrl: names[u.userId]?.imageUrl ?? "" });

  return {
    days, truncated: snap.size >= MAX_EVENTS, users: users.length, events: events.length,
    byStatus, byPlatform, byProvider, sponsorCoins, studioCoins,
    series: [...perDay.entries()].sort((a, b) => a[0].localeCompare(b[0])).map(([day, v]) => ({ day, ...v })),
    top: top.map(dress), suspects: suspects.map(dress),
    config: { holdHours: cfg.holdHours, dailyCapCoins: cfg.dailyCapCoins, weeklyCapCoins: cfg.weeklyCapCoins, sponsorPct: cfg.sponsorPct },
  };
});

export const offerwallAdminUser = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  let userId = s(d["userId"], 128).trim();
  if (!userId) {
    const q = s(d["query"], 120).trim().replace(/^@/, "");
    if (q.length < 2) throw new HttpsError("invalid-argument", "Saisissez au moins 2 caractères.");
    const found = new Map<string, Record<string, unknown>>();
    const direct = await db.collection("Users").doc(q.replace(/\//g, "")).get().catch(() => undefined);
    if (direct?.exists) found.set(direct.id, direct.data() ?? {});
    for (const [field, value] of [["pseudo", q], ["pseudo", q.toLowerCase()], ["email", q.toLowerCase()]] as const) {
      const r = await db.collection("Users").where(field, "==", value).limit(5).get();
      r.docs.forEach((x) => found.set(x.id, x.data()));
    }
    const list = [...found.entries()].slice(0, 8).map(([id, u]) => ({ id, pseudo: s(u["pseudo"], 60), email: s(u["email"], 120), imageUrl: s(u["imageUrl"], 400), pending: num(u["offerwallPendingCoins"]), earned: num(u["totalOfferwallCoinsEarned"]) }));
    if (list.length !== 1) return { matches: list };
    userId = list[0].id;
  }

  const now = Date.now();
  const cfg = readOfferwallConfig((await db.collection("AppConfig").doc("offerwall").get()).data());
  const userSnap = await db.collection("Users").doc(userId).get();
  if (!userSnap.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
  const u = userSnap.data() ?? {};
  const evSnap = await db.collection("OfferwallEvents").where("userId", "==", userId).limit(300).get();
  const events: Ev[] = evSnap.docs.map((x): Ev => ({ id: x.id, ...x.data() })).sort((a, b) => num(b["createdAt"]) - num(a["createdAt"]));
  const created = num(u["createdAt"]) > 1e14 ? Math.floor(num(u["createdAt"]) / 1000) : num(u["createdAt"]);
  const activity = activityFromEvents(events.map((e) => ({ coins: num(e["coins"]), createdAt: num(e["createdAt"]), status: s(e["status"]) })), now, created || null);
  const sponsorCode = s(u["code_parrain"], 40);
  let sponsor: { id: string; pseudo: string } | null = null;
  if (sponsorCode) {
    const sp = await db.collection("Users").where("code_parrainage", "==", sponsorCode).limit(1).get();
    if (sp.docs[0] && sp.docs[0].id !== userId) sponsor = { id: sp.docs[0].id, pseudo: s(sp.docs[0].data()["pseudo"], 60) };
  }
  const referred = await db.collection("Users").where("code_parrain", "==", s(u["code_parrainage"], 40) || "__aucun__").limit(1).get().then((r) => r.size).catch(() => 0);
  return {
    user: {
      id: userId, pseudo: s(u["pseudo"], 60), email: s(u["email"], 120), imageUrl: s(u["imageUrl"], 400), createdAt: created,
      country: s((u["countryData"] as Record<string, unknown> | undefined)?.["countryName"], 60),
      pending: num(u["offerwallPendingCoins"]), earned: num(u["totalOfferwallCoinsEarned"]),
      blocked: u["offerwallBlocked"] === true, blockedReason: s(u["offerwallBlockedReason"], 200), hasReferrals: referred > 0, sponsor,
    },
    activity, risk: riskOf(activity, cfg), events: events.slice(0, 100).map(evOut),
  };
});

export const offerwallAdminEvents = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const status = ["pending", "validee", "en_revue", "refusee", "refusee_admin", "expiree", "annulee"].includes(s(d["status"])) ? s(d["status"]) : "en_revue";
  const snap = await db.collection("OfferwallEvents").where("status", "==", status).limit(clamp(d["limit"], 100, 1, 200)).get();
  const list: Ev[] = snap.docs.map((x): Ev => ({ id: x.id, ...x.data() })).sort((a, b) => num(b["createdAt"]) - num(a["createdAt"]));
  const names = await pseudos(list.map((e) => s(e["userId"])));
  return { status, events: list.map((e) => ({ ...evOut(e), pseudo: names[s(e["userId"])]?.pseudo ?? "" })) };
});

export const offerwallAdminReview = onCall(OPTS, async (request) => {
  const adminId = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const eventId = s(d["eventId"], 80).replace(/\//g, "");
  const action = s(d["action"], 10);
  if (!eventId || !["approve", "reject"].includes(action)) throw new HttpsError("invalid-argument", "Action invalide.");
  const ref = db.collection("OfferwallEvents").doc(eventId);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Tâche introuvable.");
    const e = snap.data() ?? {};
    if (e["status"] !== "en_revue") throw new HttpsError("failed-precondition", "Cette tâche n'est plus en revue.");
    const coins = Math.floor(num(e["coins"]));
    if (action === "approve") {
      // elle repart dans le circuit normal : libération à la prochaine échéance si le compte remplit les conditions
      tx.update(ref, { status: "pending", releaseAt: now, reviewedBy: adminId, reviewedAt: now, updatedAt: now });
    } else {
      tx.update(ref, { status: "refusee_admin", reviewedBy: adminId, reviewedAt: now, updatedAt: now });
      tx.update(db.collection("Users").doc(s(e["userId"], 128)), { offerwallPendingCoins: FieldValue.increment(-coins) });
    }
  });
  await logAction(adminId, "offerwall_review", { eventId, action });
  return { ok: true };
});

export const offerwallAdminBlock = onCall(OPTS, async (request) => {
  const adminId = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const userId = s(d["userId"], 128).replace(/\//g, "");
  const blocked = d["blocked"] === true;
  const reason = s(d["reason"], 200);
  if (!userId) throw new HttpsError("invalid-argument", "Utilisateur manquant.");
  const ref = db.collection("Users").doc(userId);
  if (!(await ref.get()).exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
  await ref.update(blocked
    ? { offerwallBlocked: true, offerwallBlockedReason: reason, offerwallBlockedAt: Date.now() }
    : { offerwallBlocked: false, offerwallBlockedReason: "", offerwallBlockedAt: 0 });
  await logAction(adminId, "offerwall_block", { userId, blocked, reason });
  return { ok: true };
});
