import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { regionOf } from "./regions";

/**
 * Outils admin du Quiz : participation du jour, temps passé, questions (avec leur taux de réussite).
 * Le temps est rapporté par l'app (une fois par minute tant que le quiz est ouvert) dans QuizUsage/{jour}_{uid}.
 */

const DAY = 86400000;
const dayKey = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, "");
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);

async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const a = await db.collection("Users").doc(uid).get();
  if (a.data()?.["role"] !== "ADM") throw new HttpsError("permission-denied", "Réservé aux admins.");
  return uid;
}

/** Temps passé dans le quiz : appelé par l'app toutes les 60 s environ. */
export const quizPing = onCall({ timeoutSeconds: 10 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const sec = Math.max(0, Math.min(120, Math.round(num(request.data?.sec))));
  if (sec <= 0) return { ok: true };
  const day = dayKey();
  await db.collection("QuizUsage").doc(`${day}_${uid}`).set({
    day, uid, sec: FieldValue.increment(sec), pings: FieldValue.increment(1), lastAt: Date.now(),
  }, { merge: true });
  return { ok: true };
});


const REASONS = ["wrong", "ambiguous", "typo", "other"];
const clip = (v: unknown, n: number) => String(v ?? "").trim().slice(0, n);

/**
 * Signalement d'une question par un joueur (réponse validée fausse, question ambiguë…).
 * Un seul signalement par joueur et par question (il est mis à jour s'il recommence) ; 15 par jour au maximum.
 */
export const quizReport = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const q = clip(request.data?.q, 400);
  if (q.length < 5) throw new HttpsError("invalid-argument", "Question invalide.");
  const reason = REASONS.includes(String(request.data?.reason)) ? String(request.data?.reason) : "other";
  const kind = ["level", "daily", "challenge"].includes(String(request.data?.kind)) ? String(request.data?.kind) : "level";
  const options = (Array.isArray(request.data?.options) ? request.data.options : []).slice(0, 4).map((o: unknown) => clip(o, 160));
  const qHash = crypto.createHash("sha1").update(q).digest("hex").slice(0, 16);
  const id = `${qHash}_${uid}`;
  const day = dayKey();
  const ref = db.collection("QuizReports").doc(id);
  const exists = (await ref.get()).exists;
  if (!exists) {
    const today = await db.collection("QuizReports").where("uid", "==", uid).where("day", "==", day).count().get();
    if (today.data().count >= 15) throw new HttpsError("resource-exhausted", "TOO_MANY");
  }
  await ref.set({
    uid, qHash, q, options, shown: clip(request.data?.shown, 160), chosen: clip(request.data?.chosen, 160),
    reason, comment: clip(request.data?.comment, 400), kind, n: Math.round(num(request.data?.n)),
    day, status: "open", updatedAt: Date.now(), ...(exists ? {} : { createdAt: Date.now() }),
  }, { merge: true });
  return { ok: true };
});

async function names(uids: string[]): Promise<Record<string, { name: string; photo: string; country: string }>> {
  const out: Record<string, { name: string; photo: string; country: string }> = {};
  const refs = uids.map((u) => db.collection("Users").doc(u));
  if (!refs.length) return out;
  const snaps = await db.getAll(...refs);
  snaps.forEach((s, i) => {
    const d = s.data() ?? {};
    const cd = (d["countryData"] ?? {}) as Record<string, string>;
    out[uids[i]] = { name: String(d["pseudo"] ?? d["nom"] ?? ""), photo: String(d["imageUrl"] ?? ""), country: String(cd["countryCode"] ?? "") };
  });
  return out;
}

export const quizAdmin = onCall({ timeoutSeconds: 60, memory: "512MiB" }, async (request) => {
  await requireAdmin(request);
  const action = String(request.data?.action ?? "stats");
  const now = Date.now();
  const today = dayKey(now);

  if (action === "stats") {
    const days = Math.max(1, Math.min(30, Math.round(num(request.data?.days) || 7)));
    const keys: string[] = [];
    for (let k = days - 1; k >= 0; k--) keys.push(dayKey(now - k * DAY));
    const startMs = now - (days - 1) * DAY;
    const startOfDay = Date.UTC(new Date(startMs).getUTCFullYear(), new Date(startMs).getUTCMonth(), new Date(startMs).getUTCDate());

    const [usageSnap, progSnap, attSnap] = await Promise.all([
      db.collection("QuizUsage").where("day", ">=", keys[0]).get(),
      db.collection("QuizProgress").limit(10000).get(),
      db.collection("QuizAttempts").where("at", ">=", startOfDay).get(),
    ]);

    const perDay: Record<string, { players: number; sec: number; levels: number; passed: number }> = {};
    keys.forEach((k) => { perDay[k] = { players: 0, sec: 0, levels: 0, passed: 0 }; });
    const todayUsers: { uid: string; sec: number; pings: number; lastAt: number }[] = [];
    const usageByDay: Record<string, Set<string>> = {};
    usageSnap.docs.forEach((d) => {
      const x = d.data();
      const k = String(x["day"]);
      if (!perDay[k]) return;
      perDay[k].players += 1;
      perDay[k].sec += num(x["sec"]);
      (usageByDay[k] ??= new Set()).add(String(x["uid"]));
      if (k === today) todayUsers.push({ uid: String(x["uid"]), sec: num(x["sec"]), pings: num(x["pings"]), lastAt: num(x["lastAt"]) });
    });
    attSnap.docs.forEach((d) => {
      const x = d.data();
      const k = dayKey(num(x["at"]));
      if (!perDay[k]) return;
      perDay[k].levels += 1;
      if (x["passed"]) perDay[k].passed += 1;
    });

    // Photographie de la progression
    const dayNo = Math.floor(now / DAY);
    let total = 0, playedToday = 0, dailyDone = 0, chalToday = 0, chalPlayers = 0, ptsToday = 0, lifetime = 0, streak3 = 0, wins = 0;
    const byRegion: Record<string, number> = { af: 0, eu: 0, as: 0, am: 0, mx: 0 };
    const levelBuckets = [0, 0, 0, 0, 0, 0]; // 1-5, 6-20, 21-50, 51-100, 101-200, terminé
    const chalBest = new Array(16).fill(0);
    const activeToday: string[] = [];
    progSnap.docs.forEach((d) => {
      const p = d.data();
      total += 1;
      byRegion[regionOf(String(p["country"] ?? ""))] += 1;
      lifetime += num(p["lifetime"]);
      const lvl = num(p["level"]);
      levelBuckets[lvl > 200 ? 5 : lvl > 100 ? 4 : lvl > 50 ? 3 : lvl > 20 ? 2 : lvl > 5 ? 1 : 0] += 1;
      const day = (p["day"] ?? {}) as Record<string, unknown>;
      const streak = (p["streak"] ?? {}) as Record<string, unknown>;
      const daily = (p["daily"] ?? {}) as Record<string, unknown>;
      if (streak["last"] === today) { playedToday += 1; activeToday.push(d.id); }
      if (num(streak["count"]) >= 3 && (streak["last"] === today || streak["last"] === dayKey(now - DAY))) streak3 += 1;
      if (num(daily["day"]) === dayNo && daily["done"]) dailyDone += 1;
      if (day["id"] === today) {
        ptsToday += num(day["pts"]) + num(day["chalPts"]);
        if (num(day["chal"]) > 0) { chalPlayers += 1; chalToday += num(day["chal"]); }
      }
      chalBest[Math.min(15, num(p["chalBest"]))] += 1;
      wins += num(p["chalWins"]);
    });

    // Retour : parmi ceux d'hier, combien reviennent aujourd'hui
    const y = usageByDay[dayKey(now - DAY)] ?? new Set<string>();
    const t = usageByDay[today] ?? new Set<string>();
    let back = 0;
    y.forEach((u) => { if (t.has(u)) back += 1; });

    todayUsers.sort((a, b) => b.sec - a.sec);
    const top = todayUsers.slice(0, 20);
    const nm = await names(top.map((u) => u.uid));
    const cfg = (await db.collection("AppConfig").doc("quiz").get()).data() ?? {};

    return {
      ok: true, today,
      days: keys.map((k) => ({ day: k, ...perDay[k], avgSec: perDay[k].players ? Math.round(perDay[k].sec / perDay[k].players) : 0 })),
      overview: { byRegion, total, playedToday, dailyDone, chalPlayers, chalToday, ptsToday, lifetime, streak3, chalWins: wins, levelBuckets, chalBest },
      retention: { yesterday: y.size, back },
      top: top.map((u) => ({ ...u, ...(nm[u.uid] ?? { name: "", photo: "", country: "" }) })),
      config: cfg,
      truncated: progSnap.size >= 10000,
    };
  }

  if (action === "unit") {
    const u = Math.round(num(request.data?.u));
    if (u < 1 || u > 40) throw new HttpsError("invalid-argument", "u invalide.");
    const first = (u - 1) * 5 + 1;
    const region = ["af", "eu", "as", "am", "mx"].includes(String(request.data?.region)) ? String(request.data?.region) : "af";
    const refs = [0, 1, 2, 3, 4].map((k) => db.collection("QuizLevels").doc(`${region}_${String(first + k).padStart(3, "0")}`));
    const [levels, attempts] = await Promise.all([
      db.getAll(...refs),
      db.collection("QuizAttempts").where("unit", "==", u).limit(3000).get(),
    ]);
    const stat: Record<string, { ok: number; total: number }> = {};
    attempts.docs.forEach((d) => {
      const det = d.data()["details"];
      if (!Array.isArray(det)) return;
      det.forEach((x: { q?: string; ok?: boolean }) => {
        if (!x?.q) return;
        const s = (stat[x.q] ??= { ok: 0, total: 0 });
        s.total += 1;
        if (x.ok) s.ok += 1;
      });
    });
    return {
      ok: true, u, region,
      levels: levels.filter((s) => s.exists).map((s) => {
        const l = s.data() as { n: number; theme: string; tier: number; questions: { q: string; o: string[]; a: number; e: string }[] };
        return {
          n: l.n, theme: l.theme, tier: l.tier,
          questions: l.questions.map((q) => ({ q: q.q, o: q.o, a: q.a, e: q.e, ok: stat[q.q]?.ok ?? 0, total: stat[q.q]?.total ?? 0 })),
        };
      }),
    };
  }

  if (action === "reports") {
    const snap = await db.collection("QuizReports").where("status", "==", "open").limit(500).get();
    const groups: Record<string, { qHash: string; q: string; options: string[]; shown: string; count: number; reasons: Record<string, number>; comments: string[]; last: number }> = {};
    snap.docs.forEach((d) => {
      const x = d.data();
      const g = (groups[x["qHash"]] ??= { qHash: x["qHash"], q: x["q"], options: x["options"] ?? [], shown: x["shown"] ?? "", count: 0, reasons: {}, comments: [], last: 0 });
      g.count += 1;
      g.reasons[x["reason"]] = (g.reasons[x["reason"]] ?? 0) + 1;
      if (x["comment"] && g.comments.length < 5) g.comments.push(x["comment"]);
      g.last = Math.max(g.last, num(x["updatedAt"]));
    });
    const list = Object.values(groups).sort((a, b) => b.count - a.count || b.last - a.last);
    return { ok: true, total: snap.size, reports: list };
  }

  if (action === "resolve") {
    const qHash = clip(request.data?.qHash, 40);
    const status = request.data?.status === "ignored" ? "ignored" : "done";
    if (!qHash) throw new HttpsError("invalid-argument", "qHash manquant.");
    const snap = await db.collection("QuizReports").where("qHash", "==", qHash).get();
    const batch = db.batch();
    snap.docs.forEach((d) => batch.update(d.ref, { status, resolvedAt: Date.now() }));
    await batch.commit();
    return { ok: true, updated: snap.size };
  }

  throw new HttpsError("invalid-argument", "action invalide.");
});
