import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { isoWeekId } from "../posts/weeklyRankings";

/**
 * Quiz Afrolook : parcours de 200 niveaux de 5 questions + 3 questions du jour.
 *
 * Tout est décidé ici : les questions vivent dans QuizLevels (illisible par l'app), l'app ne reçoit
 * que les questions et leurs choix (mélangés par joueur), jamais les réponses. Chaque réponse est
 * corrigée par le serveur, qui garde aussi la progression, les points, les cœurs et la série.
 * Les points n'ont aucune valeur en argent : ils servent au classement et à la boutique.
 *
 * Réglages modifiables sans mise à jour : Firestore AppConfig/quiz (voir DEFAULTS).
 */

const LEVELS = 200;
const PER_LEVEL = 5;
const DAILY_COUNT = 3;
const POOL = LEVELS * PER_LEVEL;
const DAY = 86400000;

const DEFAULTS = {
  enabled: true,
  heartsMax: 5,
  heartRegenMinutes: 30,
  pointsPerCorrect: 10,
  perfectBonus: 20,
  passMin: 3,
  dailyPointsCap: 400,
  dailyCorrect: 5,
  dailyBonus: 10,
  doubleMaxPerDay: 5,
  refillMaxPerDay: 3,
  minAnswerMs: 600,
  shieldMax: 3,
};

type Cfg = typeof DEFAULTS & { shop: Record<string, { price?: number; enabled?: boolean }> };

type ShopItem = { price: number; kind: "shield" | "cosmetic"; slot?: "frame" | "title" | "accessory" };
const SHOP: Record<string, ShopItem> = {
  shield: { price: 300, kind: "shield" },
  frame_green: { price: 500, kind: "cosmetic", slot: "frame" },
  frame_gold: { price: 800, kind: "cosmetic", slot: "frame" },
  title_lion: { price: 1000, kind: "cosmetic", slot: "title" },
  title_scholar: { price: 700, kind: "cosmetic", slot: "title" },
  acc_glasses: { price: 400, kind: "cosmetic", slot: "accessory" },
  acc_cap: { price: 500, kind: "cosmetic", slot: "accessory" },
  acc_crown: { price: 900, kind: "cosmetic", slot: "accessory" },
};

type Level = { n: number; unit: number; tier: number; theme: string; questions: { q: string; o: string[]; a: number; e: string }[] };

type Prog = {
  level: number;
  completed: number;
  points: number;
  lifetime: number;
  week: { id: string; pts: number };
  streak: { count: number; last: string };
  shields: number;
  hearts: number;
  heartsAt: number;
  correct: number;
  answered: number;
  day: { id: string; pts: number; doubled: number; refills: number };
  inventory: Record<string, boolean>;
  equipped: Record<string, string>;
  daily: { day: number; done: boolean; gain: number };
  country: string;
};

// ── Utilitaires ──────────────────────────────────────────────────────────────

const num = (v: unknown, def: number) => (typeof v === "number" && Number.isFinite(v) ? v : def);
const dayKey = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, "");
const pad = (n: number) => String(n).padStart(3, "0");
const progRef = (uid: string) => db.collection("QuizProgress").doc(uid);
const sessRef = (id: string) => db.collection("QuizSessions").doc(id);

function uidOf(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  return uid;
}

function intArg(v: unknown, min: number, max: number, name: string): number {
  const n = typeof v === "number" ? v : Number(v);
  if (!Number.isInteger(n) || n < min || n > max) throw new HttpsError("invalid-argument", `${name} invalide.`);
  return n;
}

let cfgCache: { at: number; cfg: Cfg } | null = null;
async function loadCfg(): Promise<Cfg> {
  if (cfgCache && Date.now() - cfgCache.at < 60000) return cfgCache.cfg;
  const d = (await db.collection("AppConfig").doc("quiz").get()).data() ?? {};
  const cfg = { ...DEFAULTS, shop: {} } as Cfg;
  (Object.keys(DEFAULTS) as (keyof typeof DEFAULTS)[]).forEach((k) => {
    const def = DEFAULTS[k];
    const target = cfg as unknown as Record<string, unknown>;
    if (typeof def === "boolean") target[k] = d[k] === undefined ? def : !!d[k];
    else target[k] = Math.max(0, num(d[k], def as number));
  });
  cfg.shop = d["shop"] && typeof d["shop"] === "object" ? d["shop"] : {};
  cfgCache = { at: Date.now(), cfg };
  return cfg;
}

const levelCache = new Map<number, { at: number; lv: Level }>();
async function getLevel(n: number): Promise<Level> {
  const hit = levelCache.get(n);
  if (hit && Date.now() - hit.at < 600000) return hit.lv;
  const snap = await db.collection("QuizLevels").doc(pad(n)).get();
  if (!snap.exists) throw new HttpsError("not-found", "Niveau introuvable.");
  const lv = snap.data() as Level;
  levelCache.set(n, { at: Date.now(), lv });
  return lv;
}

/** Permutation aléatoire des 4 choix (propre à chaque joueur et à chaque partie). */
function randomPerm(): number[] {
  const p = [0, 1, 2, 3];
  for (let i = 3; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [p[i], p[j]] = [p[j], p[i]];
  }
  return p;
}

/** Firestore refuse les tableaux imbriqués : un mélange [2,0,3,1] est stocké sous la forme « 2031 ». */
const enc = (p: number[]) => p.join("");
const dec = (v: string) => v.split("").map(Number);

function freshProg(country: string): Prog {
  const now = Date.now();
  return {
    level: 1, completed: 0, points: 0, lifetime: 0,
    week: { id: isoWeekId(new Date()), pts: 0 },
    streak: { count: 0, last: "" },
    shields: 0, hearts: DEFAULTS.heartsMax, heartsAt: now,
    correct: 0, answered: 0,
    day: { id: dayKey(), pts: 0, doubled: 0, refills: 0 },
    inventory: {}, equipped: {},
    daily: { day: 0, done: false, gain: 0 },
    country,
  };
}

/** Remet à jour ce qui dépend de la date : semaine, jour, cœurs. */
function normalise(p: Prog, cfg: Cfg, now: number): Prog {
  const wk = isoWeekId(new Date(now));
  if (p.week?.id !== wk) p.week = { id: wk, pts: 0 };
  const dk = dayKey(now);
  if (p.day?.id !== dk) p.day = { id: dk, pts: 0, doubled: 0, refills: 0 };
  p.streak = p.streak ?? { count: 0, last: "" };
  p.inventory = p.inventory ?? {};
  p.equipped = p.equipped ?? {};
  p.daily = p.daily ?? { day: 0, done: false, gain: 0 };
  p.shields = p.shields ?? 0;
  // Cœurs : un cœur revient toutes les heartRegenMinutes
  const max = cfg.heartsMax;
  const regenMs = Math.max(1, cfg.heartRegenMinutes) * 60000;
  if (p.hearts >= max) {
    p.hearts = max;
    p.heartsAt = now;
  } else {
    const gained = Math.floor((now - p.heartsAt) / regenMs);
    if (gained > 0) {
      p.hearts = Math.min(max, p.hearts + gained);
      p.heartsAt = p.hearts >= max ? now : p.heartsAt + gained * regenMs;
    }
  }
  return p;
}

/** Série : +1 par jour joué ; un bouclier sauve un jour manqué. */
function bumpStreak(p: Prog, now: number) {
  const today = dayKey(now);
  const last = p.streak.last;
  if (last === today) return;
  if (last === dayKey(now - DAY)) p.streak.count += 1;
  else if (last === dayKey(now - 2 * DAY) && p.shields > 0) {
    p.shields -= 1;
    p.streak.count += 1;
  } else p.streak.count = 1;
  p.streak.last = today;
}

function publicState(p: Prog, cfg: Cfg, now: number) {
  const regenMs = Math.max(1, cfg.heartRegenMinutes) * 60000;
  const today = dayKey(now);
  const streakAlive = p.streak.last === today || p.streak.last === dayKey(now - DAY);
  return {
    level: p.level, completed: p.completed, points: p.points, lifetime: p.lifetime,
    weeklyPoints: p.week.pts, weekId: p.week.id,
    streak: streakAlive ? p.streak.count : 0, playedToday: p.streak.last === today,
    shields: p.shields, hearts: p.hearts, heartsMax: cfg.heartsMax,
    nextHeartInSec: p.hearts >= cfg.heartsMax ? 0 : Math.max(0, Math.ceil((p.heartsAt + regenMs - now) / 1000)),
    inventory: p.inventory, equipped: p.equipped,
    daily: { done: p.daily.day === Math.floor(now / DAY) && p.daily.done },
    dailyPoints: p.day.pts, dailyCap: cfg.dailyPointsCap,
    refillsLeft: Math.max(0, cfg.refillMaxPerDay - p.day.refills),
    doublesLeft: Math.max(0, cfg.doubleMaxPerDay - p.day.doubled),
    levels: LEVELS,
  };
}

async function userInfo(uid: string): Promise<{ name: string; photo: string; country: string; countryName: string }> {
  const u = (await db.collection("Users").doc(uid).get()).data() ?? {};
  const cd = (u["countryData"] ?? {}) as Record<string, string>;
  return {
    name: String(u["pseudo"] ?? u["nom"] ?? "").slice(0, 40),
    photo: String(u["imageUrl"] ?? ""),
    country: String(cd["countryCode"] ?? "").toUpperCase().slice(0, 2),
    countryName: String(cd["country"] ?? "").slice(0, 40),
  };
}

/** Écrit les points gagnés dans le classement de la semaine et dans le total du pays. */
async function addWeekly(uid: string, weekId: string, gain: number, equipped: Record<string, string> = {}) {
  if (gain <= 0) return;
  const info = await userInfo(uid);
  await db.collection("QuizWeekly").doc(`${weekId}_${uid}`).set({
    weekId, uid, name: info.name, photo: info.photo, country: info.country, countryName: info.countryName,
    frame: equipped["frame"] ?? "", title: equipped["title"] ?? "",
    points: FieldValue.increment(gain), updatedAt: Date.now(),
  }, { merge: true });
  if (info.country) {
    const shard = crypto.randomInt(0, 10);
    await db.collection("QuizCountryShards").doc(`${weekId}_${shard}`).set({
      weekId,
      points: { [info.country]: FieldValue.increment(gain) },
      names: { [info.country]: info.countryName || info.country },
    }, { merge: true });
  }
}

// ── État du joueur ──────────────────────────────────────────────────────────

export const quizGetState = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const info = await userInfo(uid);
  const now = Date.now();
  const state = await db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (info.country && p.country !== info.country) p.country = info.country;
    tx.set(progRef(uid), p);
    return publicState(p, cfg, now);
  });
  return { ok: true, enabled: cfg.enabled, ...state };
});

/** Rang de la semaine (nombre de joueurs devant moi + 1). */
export const quizMyRank = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const weekId = isoWeekId(new Date());
  const me = (await db.collection("QuizWeekly").doc(`${weekId}_${uid}`).get()).data();
  const points = num(me?.["points"], 0);
  if (points <= 0) return { ok: true, weekId, points: 0, rank: 0 };
  const ahead = await db.collection("QuizWeekly").where("weekId", "==", weekId).where("points", ">", points).count().get();
  return { ok: true, weekId, points, rank: ahead.data().count + 1 };
});

// ── Niveaux ─────────────────────────────────────────────────────────────────

export const quizStartLevel = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "QUIZ_OFF");
  const n = intArg(request.data?.n, 1, LEVELS, "n");
  const lv = await getLevel(n);
  const info = await userInfo(uid);
  const now = Date.now();
  const sid = `${uid}_${n}`;

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (n > p.level) throw new HttpsError("failed-precondition", "LEVEL_LOCKED");
    const practice = n < p.level;
    if (!practice && p.hearts <= 0) throw new HttpsError("failed-precondition", "NO_HEARTS");
    const perms = lv.questions.map(() => randomPerm());
    tx.set(sessRef(sid), { uid, n, practice, startedAt: now, lastAt: now, perms: perms.map(enc), answers: [], status: "open" });
    tx.set(progRef(uid), p);
    return { practice, perms, state: publicState(p, cfg, now) };
  });

  return {
    ok: true, n, practice: result.practice, unit: lv.unit, theme: lv.theme,
    questions: lv.questions.map((q, i) => ({ q: q.q, o: result.perms[i].map((orig) => q.o[orig]) })),
    ...result.state,
  };
});

export const quizAnswer = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const n = intArg(request.data?.n, 1, LEVELS, "n");
  const i = intArg(request.data?.i, 0, PER_LEVEL - 1, "i");
  const choice = intArg(request.data?.choice, 0, 3, "choice");
  const lv = await getLevel(n);
  const q = lv.questions[i];
  const sid = `${uid}_${n}`;
  const now = Date.now();

  return db.runTransaction(async (tx) => {
    const [ss, ps] = await Promise.all([tx.get(sessRef(sid)), tx.get(progRef(uid))]);
    const s = ss.data() as { uid: string; practice: boolean; lastAt: number; perms: string[]; answers: { c: number; ok: boolean }[]; status: string } | undefined;
    if (!s || s.uid !== uid || s.status !== "open") throw new HttpsError("failed-precondition", "NO_SESSION");
    if (s.answers.length !== i) throw new HttpsError("failed-precondition", "OUT_OF_ORDER");
    if (now - s.lastAt < cfg.minAnswerMs) throw new HttpsError("resource-exhausted", "TOO_FAST");
    const perm = dec(s.perms[i]);
    const ok = perm[choice] === q.a;
    if (!ps.exists) throw new HttpsError("failed-precondition", "NO_SESSION");
    const p = normalise(ps.data() as Prog, cfg, now);
    p.answered += 1;
    if (ok) p.correct += 1;
    else if (!s.practice) {
      if (p.hearts >= cfg.heartsMax) p.heartsAt = now; // la recharge démarre à la première perte
      p.hearts = Math.max(0, p.hearts - 1);
    }
    s.answers.push({ c: choice, ok });
    tx.update(sessRef(sid), { answers: s.answers, lastAt: now });
    tx.set(progRef(uid), p);
    return {
      ok: true, correct: ok, correctIndex: perm.indexOf(q.a), explanation: q.e,
      hearts: p.hearts,
    };
  });
});

export const quizFinishLevel = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const n = intArg(request.data?.n, 1, LEVELS, "n");
  const lv = await getLevel(n);
  const sid = `${uid}_${n}`;
  const now = Date.now();
  const info = await userInfo(uid);

  const out = await db.runTransaction(async (tx) => {
    const [ss, ps] = await Promise.all([tx.get(sessRef(sid)), tx.get(progRef(uid))]);
    const s = ss.data() as { uid: string; practice: boolean; perms: string[]; answers: { c: number; ok: boolean }[]; status: string; result?: Record<string, unknown> } | undefined;
    if (!s || s.uid !== uid) throw new HttpsError("failed-precondition", "NO_SESSION");
    if (s.status === "done" && s.result) return { replay: true, result: s.result };
    if (s.answers.length !== PER_LEVEL) throw new HttpsError("failed-precondition", "NOT_FINISHED");

    const p = normalise(ps.exists ? (ps.data() as Prog) : freshProg(info.country), cfg, now);
    const correct = s.answers.filter((a) => a.ok).length;
    const pass = correct >= cfg.passMin;
    let gain = 0;
    let capped = false;
    const firstTime = !s.practice && n === p.level;
    if (firstTime && pass) {
      const base = correct * cfg.pointsPerCorrect + (correct === PER_LEVEL ? cfg.perfectBonus : 0);
      const room = Math.max(0, cfg.dailyPointsCap - p.day.pts);
      gain = Math.min(base, room);
      capped = gain < base;
      p.level = Math.min(LEVELS + 1, p.level + 1);
      p.completed += 1;
      p.points += gain;
      p.lifetime += gain;
      p.week.pts += gain;
      p.day.pts += gain;
    }
    if (!s.practice && pass) bumpStreak(p, now);

    const details = lv.questions.map((q, i) => ({
      q: q.q, a: q.o[q.a], c: q.o[dec(s.perms[i])[s.answers[i].c]], ok: s.answers[i].ok,
    }));
    const attempt = s.practice ?
      { uid, n, theme: lv.theme, unit: lv.unit, lastReplay: now, lastReplayCorrect: correct } :
      { uid, n, theme: lv.theme, unit: lv.unit, passed: pass, correct, gain, at: now, details };
    tx.set(db.collection("QuizAttempts").doc(`${uid}_${n}`), attempt, { merge: true });

    const result = {
      ok: true, pass, correct, total: PER_LEVEL, gain, capped, perfect: correct === PER_LEVEL,
      practice: s.practice, canDouble: gain > 0 && p.day.doubled < cfg.doubleMaxPerDay,
      ...publicState(p, cfg, now),
    };
    tx.update(sessRef(sid), { status: "done", result });
    tx.set(progRef(uid), p);
    return { replay: false, result, weekId: p.week.id, gain, equipped: p.equipped };
  });

  if (!out.replay && out.gain && out.weekId) await addWeekly(uid, out.weekId, out.gain, out.equipped);
  return out.result;
});

/** Après une vidéo récompensée : double les points du niveau qui vient d'être gagné (une seule fois). */
export const quizDoublePoints = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const n = intArg(request.data?.n, 1, LEVELS, "n");
  const now = Date.now();
  const attemptRef = db.collection("QuizAttempts").doc(`${uid}_${n}`);
  const out = await db.runTransaction(async (tx) => {
    const [as, ps] = await Promise.all([tx.get(attemptRef), tx.get(progRef(uid))]);
    const a = as.data();
    if (!a || a["uid"] !== uid || num(a["gain"], 0) <= 0 || a["doubled"]) throw new HttpsError("failed-precondition", "NOT_DOUBLABLE");
    if (now - num(a["at"], 0) > 15 * 60000) throw new HttpsError("failed-precondition", "TOO_LATE");
    if (!ps.exists) throw new HttpsError("failed-precondition", "NO_SESSION");
    const p = normalise(ps.data() as Prog, cfg, now);
    if (p.day.doubled >= cfg.doubleMaxPerDay) throw new HttpsError("resource-exhausted", "DOUBLE_LIMIT");
    const room = Math.max(0, cfg.dailyPointsCap - p.day.pts);
    const extra = Math.min(num(a["gain"], 0), room);
    p.points += extra;
    p.lifetime += extra;
    p.week.pts += extra;
    p.day.pts += extra;
    p.day.doubled += 1;
    tx.update(attemptRef, { doubled: true });
    tx.set(progRef(uid), p);
    return { extra, weekId: p.week.id, state: publicState(p, cfg, now) };
  });
  await addWeekly(uid, out.weekId, out.extra, out.state.equipped);
  return { ok: true, extra: out.extra, ...out.state };
});

/** Après une vidéo récompensée : rend un cœur (plafond par jour). */
export const quizRefillHeart = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const now = Date.now();
  const info = await userInfo(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (p.hearts >= cfg.heartsMax) return { ok: true, ...publicState(p, cfg, now) };
    if (p.day.refills >= cfg.refillMaxPerDay) throw new HttpsError("resource-exhausted", "REFILL_LIMIT");
    p.hearts += 1;
    p.day.refills += 1;
    if (p.hearts >= cfg.heartsMax) p.heartsAt = now;
    tx.set(progRef(uid), p);
    return { ok: true, ...publicState(p, cfg, now) };
  });
});

// ── Questions du jour ───────────────────────────────────────────────────────

/** Les 3 questions du jour sont les mêmes pour tout le monde (tirées de la banque selon la date). */
async function dailyQuestions(dayNo: number) {
  const out: { q: string; o: string[]; a: number; e: string }[] = [];
  for (let k = 0; k < DAILY_COUNT; k++) {
    const g = (dayNo * DAILY_COUNT + k) % POOL;
    const lv = await getLevel(Math.floor(g / PER_LEVEL) + 1);
    out.push(lv.questions[g % PER_LEVEL]);
  }
  return out;
}

export const quizDailyGet = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const now = Date.now();
  const dayNo = Math.floor(now / DAY);
  const qs = await dailyQuestions(dayNo);
  const sid = `${uid}_d${dayNo}`;
  const perms = await db.runTransaction(async (tx) => {
    const ss = await tx.get(sessRef(sid));
    if (ss.exists) return (ss.data() as { perms: string[] }).perms.map(dec);
    const pm = qs.map(() => randomPerm());
    tx.set(sessRef(sid), { uid, daily: true, day: dayNo, startedAt: now, lastAt: 0, perms: pm.map(enc), answers: [], status: "open" });
    return pm;
  });
  const sess = (await sessRef(sid).get()).data() as { answers: { c: number; ok: boolean }[] };
  const answers = sess?.answers ?? [];
  return {
    ok: true, day: dayNo, total: DAILY_COUNT, done: answers.length >= DAILY_COUNT,
    questions: qs.map((q, i) => ({ q: q.q, o: perms[i].map((orig) => q.o[orig]) })),
    results: answers.map((a, i) => ({
      choice: a.c, correct: a.ok, correctIndex: perms[i].indexOf(qs[i].a), explanation: qs[i].e,
    })),
  };
});

export const quizDailyAnswer = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const i = intArg(request.data?.i, 0, DAILY_COUNT - 1, "i");
  const choice = intArg(request.data?.choice, 0, 3, "choice");
  const now = Date.now();
  const dayNo = Math.floor(now / DAY);
  const qs = await dailyQuestions(dayNo);
  const q = qs[i];
  const sid = `${uid}_d${dayNo}`;
  const info = await userInfo(uid);

  const out = await db.runTransaction(async (tx) => {
    const [ss, ps] = await Promise.all([tx.get(sessRef(sid)), tx.get(progRef(uid))]);
    const s = ss.data() as { perms: string[]; lastAt: number; answers: { c: number; ok: boolean }[] } | undefined;
    if (!s) throw new HttpsError("failed-precondition", "NO_SESSION");
    if (s.answers.length !== i) throw new HttpsError("failed-precondition", "OUT_OF_ORDER");
    if (now - s.lastAt < cfg.minAnswerMs) throw new HttpsError("resource-exhausted", "TOO_FAST");
    const perm = dec(s.perms[i]);
    const ok = perm[choice] === q.a;
    s.answers.push({ c: choice, ok });
    const p = normalise(ps.exists ? (ps.data() as Prog) : freshProg(info.country), cfg, now);
    p.answered += 1;
    if (ok) p.correct += 1;
    let gain = 0;
    let finished = false;
    if (s.answers.length === DAILY_COUNT) {
      finished = true;
      const correct = s.answers.filter((a) => a.ok).length;
      const base = correct * cfg.dailyCorrect + (correct === DAILY_COUNT ? cfg.dailyBonus : 0);
      gain = Math.min(base, Math.max(0, cfg.dailyPointsCap - p.day.pts));
      p.points += gain;
      p.lifetime += gain;
      p.week.pts += gain;
      p.day.pts += gain;
      p.daily = { day: dayNo, done: true, gain };
      bumpStreak(p, now);
    }
    tx.update(sessRef(sid), { answers: s.answers, lastAt: now, status: finished ? "done" : "open" });
    tx.set(progRef(uid), p);
    return {
      ok: true, correct: ok, correctIndex: perm.indexOf(q.a), explanation: q.e,
      finished, gain, correctCount: s.answers.filter((a) => a.ok).length,
      weekId: p.week.id, state: publicState(p, cfg, now),
    };
  });
  if (out.gain > 0) await addWeekly(uid, out.weekId, out.gain, out.state.equipped);
  return out;
});

// ── Boutique de points ──────────────────────────────────────────────────────

function shopItem(id: string, cfg: Cfg): (ShopItem & { id: string }) | null {
  const base = SHOP[id];
  if (!base) return null;
  const o = cfg.shop[id] ?? {};
  if (o.enabled === false) return null;
  return { id, ...base, price: Math.max(0, num(o.price, base.price)) };
}

export const quizShopBuy = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const itemId = String(request.data?.itemId ?? "");
  const item = shopItem(itemId, cfg);
  if (!item) throw new HttpsError("not-found", "Objet indisponible.");
  const now = Date.now();
  const info = await userInfo(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (item.kind === "shield") {
      if (p.shields >= cfg.shieldMax) throw new HttpsError("failed-precondition", "SHIELD_MAX");
    } else if (p.inventory[item.id]) throw new HttpsError("already-exists", "ALREADY_OWNED");
    if (p.points < item.price) throw new HttpsError("failed-precondition", "NOT_ENOUGH_POINTS");
    p.points -= item.price;
    if (item.kind === "shield") p.shields += 1;
    else {
      p.inventory[item.id] = true;
      if (item.slot && !p.equipped[item.slot]) p.equipped[item.slot] = item.id;
    }
    tx.set(progRef(uid), p);
    return { ok: true, ...publicState(p, cfg, now) };
  });
});

export const quizEquip = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const slot = String(request.data?.slot ?? "");
  const itemId = request.data?.itemId == null ? "" : String(request.data.itemId);
  if (!["frame", "title", "accessory"].includes(slot)) throw new HttpsError("invalid-argument", "Emplacement inconnu.");
  const now = Date.now();
  const info = await userInfo(uid);
  const out = await db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (itemId) {
      const item = SHOP[itemId];
      if (!item || item.slot !== slot || !p.inventory[itemId]) throw new HttpsError("failed-precondition", "NOT_OWNED");
      p.equipped[slot] = itemId;
    } else delete p.equipped[slot];
    tx.set(progRef(uid), p);
    return { ok: true, ...publicState(p, cfg, now) };
  });
  // Le cadre et le titre se voient dans le classement de la semaine : on met à jour la ligne du joueur si elle existe
  try {
    await db.collection("QuizWeekly").doc(`${out.weekId}_${uid}`).update({ frame: out.equipped["frame"] ?? "", title: out.equipped["title"] ?? "" });
  } catch (_) { /* pas encore de points cette semaine */ }
  return out;
});

// ── Classement par pays ─────────────────────────────────────────────────────

/** Fusionne les compteurs par pays de la semaine en un seul document facile à lire pour l'app. */
export const quizMergeCountryBoard = onSchedule(
  { schedule: "every 10 minutes", region: "us-central1", timeZone: "UTC", timeoutSeconds: 60, memory: "256MiB" },
  async () => {
    const now = Date.now();
    for (const weekId of new Set([isoWeekId(new Date(now)), isoWeekId(new Date(now - 7 * DAY))])) {
      const shards = await db.collection("QuizCountryShards").where("weekId", "==", weekId).get();
      const totals: Record<string, number> = {};
      const names: Record<string, string> = {};
      shards.docs.forEach((d) => {
        const x = d.data();
        Object.entries((x["points"] ?? {}) as Record<string, number>).forEach(([cc, v]) => { totals[cc] = (totals[cc] ?? 0) + num(v, 0); });
        Object.assign(names, x["names"] ?? {});
      });
      const countries = Object.entries(totals)
        .map(([code, points]) => ({ code, name: names[code] ?? code, points }))
        .sort((a, b) => b.points - a.points)
        .slice(0, 40);
      await db.collection("QuizCountryBoard").doc(weekId).set({ weekId, countries, updatedAt: now });
    }
  },
);
