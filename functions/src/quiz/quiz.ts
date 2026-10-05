import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { isoWeekId } from "../posts/weeklyRankings";
import { regionOf, QuizRegion } from "./regions";
import { recordAppCommission } from "../payments/coinShares";

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
  challengeEnabled: true,
  challengeFree: 1,
  challengeExtraMax: 2,
  challengeSeconds: 30,
  challengeDailyCap: 1500,
  challengeRescue: true,
  heartPriceCoins: 25,
  heartsFullPriceCoins: 100,
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

type Level = { n: number; region?: string; unit: number; tier: number; theme: string; questions: { q: string; o: string[]; a: number; e: string; r?: string }[] };

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
  day: { id: string; pts: number; doubled: number; refills: number; chal?: number; chalPts?: number };
  chalBest?: number;
  chalWins?: number;
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

const levelCache = new Map<string, { at: number; lv: Level }>();
/** Niveau n du jeu de la région (af, eu, as, am, mx). Jeu absent : on retombe sur le jeu africain, puis sur l'ancien jeu unique. */
async function getLevel(n: number, region: string = "af"): Promise<Level> {
  const key = `${region}_${n}`;
  const hit = levelCache.get(key);
  if (hit && Date.now() - hit.at < 600000) return hit.lv;
  const tries = [`${region}_${pad(n)}`, `af_${pad(n)}`, pad(n)];
  for (const id of tries) {
    const snap = await db.collection("QuizLevels").doc(id).get();
    if (snap.exists) {
      const lv = snap.data() as Level;
      levelCache.set(key, { at: Date.now(), lv });
      return lv;
    }
  }
  throw new HttpsError("not-found", "Niveau introuvable.");
}

type PoolQ = { q: string; c: string; w: string[]; e: string; r: string };
const poolCache = new Map<string, { at: number; list: PoolQ[] }>();
/** Toutes les questions d'une même difficulté et d'un même thème (toutes régions), de la plus facile à la plus difficile. */
async function getPool(theme: string, tier: number): Promise<PoolQ[]> {
  const key = `${theme}_${tier}`;
  const hit = poolCache.get(key);
  if (hit && Date.now() - hit.at < 600000) return hit.list;
  const snap = await db.collection("QuizPool").doc(key).get();
  const list = snap.exists ? ((snap.data()?.["list"] ?? []) as PoolQ[]) : [];
  poolCache.set(key, { at: Date.now(), list });
  return list;
}

/** Rejouer un niveau déjà gagné : 5 questions nouvelles du même thème et de la même difficulté (4 de sa région, 1 d'ailleurs), tirées au hasard. */
function practiceQuestions(lv: Level, pool: PoolQ[], region: string): Level["questions"] {
  const seen = new Set(lv.questions.map((q) => q.q));
  const idx = pool.map((x, i) => i).filter((i) => !seen.has(pool[i].q));
  const shuffle = <T>(a: T[]) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
  const own = shuffle(idx.filter((i) => region !== "mx" && pool[i].r === region));
  const rest = shuffle(idx.filter((i) => !own.includes(i)));
  const pick = [...own.slice(0, region === "mx" ? 0 : PER_LEVEL - 1), ...rest].slice(0, PER_LEVEL);
  if (pick.length < PER_LEVEL) return lv.questions; // réservoir absent ou trop petit : mêmes questions
  return pick.sort((a, b) => a - b).map((i) => ({ q: pool[i].q, o: [pool[i].c, ...pool[i].w], a: 0, e: pool[i].e }));
}

/** Région du joueur d'après son profil (ou le pays gardé dans sa progression). */
async function regionFor(uid: string, info: { country: string }): Promise<QuizRegion> {
  if (info.country) return regionOf(info.country);
  const ps = await progRef(uid).get();
  return regionOf(String(ps.data()?.["country"] ?? ""));
}

async function sessionRegion(sid: string): Promise<string> {
  const s = await sessRef(sid).get();
  return String(s.data()?.["region"] ?? "af");
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
    challengeLeft: Math.max(0, cfg.challengeFree - (p.day.chal ?? 0)),
    challengeBest: p.chalBest ?? 0,
    levels: LEVELS,
    region: regionOf(p.country),
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
    const before = snap.exists ? JSON.stringify(snap.data()) : "";
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (info.country && p.country !== info.country) p.country = info.country;
    // Pas d'écriture quand rien n'a changé (le fil appelle cette fonction à chaque session)
    if (JSON.stringify(p) !== before) tx.set(progRef(uid), p);
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
  const info = await userInfo(uid);
  const region = await regionFor(uid, info);
  const lv = await getLevel(n, region);
  const pool = await getPool(lv.theme, lv.tier);
  const now = Date.now();
  const sid = `${uid}_${n}`;

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (n > p.level) throw new HttpsError("failed-precondition", "LEVEL_LOCKED");
    const practice = n < p.level;
    if (!practice && p.hearts <= 0) throw new HttpsError("failed-precondition", "NO_HEARTS");
    const qs = practice ? practiceQuestions(lv, pool, region) : lv.questions;
    const perms = qs.map(() => randomPerm());
    tx.set(sessRef(sid), { uid, n, practice, region, startedAt: now, lastAt: now, perms: perms.map(enc), answers: [], status: "open", ...(practice && qs !== lv.questions ? { pq: qs } : {}) });
    tx.set(progRef(uid), p);
    return { practice, perms, qs, state: publicState(p, cfg, now) };
  });

  return {
    ok: true, n, practice: result.practice, unit: lv.unit, theme: lv.theme,
    questions: result.qs.map((q, i) => ({ q: q.q, o: result.perms[i].map((orig) => q.o[orig]) })),
    ...result.state,
  };
});

export const quizAnswer = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const n = intArg(request.data?.n, 1, LEVELS, "n");
  const i = intArg(request.data?.i, 0, PER_LEVEL - 1, "i");
  const choice = intArg(request.data?.choice, 0, 3, "choice");
  const sid = `${uid}_${n}`;
  const lv = await getLevel(n, await sessionRegion(sid));
  const now = Date.now();

  return db.runTransaction(async (tx) => {
    const [ss, ps] = await Promise.all([tx.get(sessRef(sid)), tx.get(progRef(uid))]);
    const s = ss.data() as { uid: string; practice: boolean; lastAt: number; perms: string[]; answers: { c: number; ok: boolean }[]; status: string; pq?: Level["questions"] } | undefined;
    if (!s || s.uid !== uid || s.status !== "open") throw new HttpsError("failed-precondition", "NO_SESSION");
    if (s.answers.length !== i) throw new HttpsError("failed-precondition", "OUT_OF_ORDER");
    const q = (s.pq ?? lv.questions)[i];
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
  const sid = `${uid}_${n}`;
  const lv = await getLevel(n, await sessionRegion(sid));
  const now = Date.now();
  const info = await userInfo(uid);

  const out = await db.runTransaction(async (tx) => {
    const [ss, ps] = await Promise.all([tx.get(sessRef(sid)), tx.get(progRef(uid))]);
    const s = ss.data() as { uid: string; practice: boolean; perms: string[]; answers: { c: number; ok: boolean }[]; status: string; result?: Record<string, unknown>; pq?: Level["questions"] } | undefined;
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

    const details = (s.pq ?? lv.questions).map((q, i) => ({
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

/** Recharge de cœurs avec des pièces : « one » = 1 cœur, « full » = tous les cœurs manquants (prix fixe, plus avantageux). */
export const quizBuyHearts = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const pack = String(request.data?.pack ?? "one");
  if (pack !== "one" && pack !== "full") throw new HttpsError("invalid-argument", "Offre inconnue.");
  const now = Date.now();
  const info = await userInfo(uid);
  const userRef = db.collection("Users").doc(uid);
  return db.runTransaction(async (tx) => {
    const [snap, us] = await Promise.all([tx.get(progRef(uid)), tx.get(userRef)]);
    if (!us.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg(info.country), cfg, now);
    if (p.hearts >= cfg.heartsMax) throw new HttpsError("failed-precondition", "ALREADY_FULL");
    const missing = cfg.heartsMax - p.hearts;
    const price = pack === "full" ? Math.min(cfg.heartsFullPriceCoins, missing * cfg.heartPriceCoins) : cfg.heartPriceCoins;
    const gain = pack === "full" ? missing : 1;
    const balance = num(us.data()?.["giftCoinsBalance"], 0);
    if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });
    tx.update(userRef, { giftCoinsBalance: FieldValue.increment(-price), totalGiftCoinsSpent: FieldValue.increment(price), updatedAt: now });
    const t = db.collection("TransactionSoldes").doc();
    tx.set(t, {
      id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
      description: gain > 1 ? `Quiz : ${gain} cœurs rechargés — ${price} pièces` : `Quiz : 1 cœur rechargé — ${price} pièces`,
      montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
      purchaseKind: "quiz_hearts",
    });
    recordAppCommission(tx, "quiz", price, now);
    p.hearts += gain;
    if (p.hearts >= cfg.heartsMax) p.heartsAt = now;
    tx.set(progRef(uid), p);
    return { ok: true, price, gain, ...publicState(p, cfg, now) };
  });
});

// ── Questions du jour ───────────────────────────────────────────────────────

/** Part de questions de la région du joueur (quiz du jour et Grand Défi) ; le reste vient d'ailleurs. Région inconnue : tout est mélangé. */
const OWN_SHARE = 0.8;

/** Les questions du jour sont les mêmes pour tous les joueurs d'une même région (tirées de son jeu selon la date, ~80 % de sa région). */
async function dailyQuestions(dayNo: number, region: string) {
  const out: Level["questions"] = [];
  const seenQ = new Set<string>();
  for (let k = 0; k < DAILY_COUNT; k++) {
    const h = crypto.createHash("sha256").update(`${dayNo}:${region}:${k}`).digest();
    const wantOwn = region === "mx" || h[0] % 100 < OWN_SHARE * 100;
    let pick: Level["questions"][number] | null = null;
    for (let t = 0; t < 30 && !pick; t++) {
      const g = (h.readUInt32BE((t * 4) % 28) + t * 7919) % POOL;
      const lv = await getLevel(Math.floor(g / PER_LEVEL) + 1, region);
      const q = lv.questions[g % PER_LEVEL];
      if (seenQ.has(q.q)) continue;
      const own = !q.r || region === "mx" || q.r === region;
      if (t < 25 && own !== wantOwn && q.r) continue;
      pick = q;
    }
    if (!pick) pick = (await getLevel(1, region)).questions[k];
    seenQ.add(pick.q);
    out.push(pick);
  }
  return out;
}

export const quizDailyGet = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const now = Date.now();
  const dayNo = Math.floor(now / DAY);
  const info = await userInfo(uid);
  const region = await regionFor(uid, info);
  const sid = `${uid}_d${dayNo}`;
  // le jeu du jour est figé à la première ouverture (si le pays change en cours de journée, les questions restent les mêmes)
  const stored = (await sessRef(sid).get()).data() as { region?: string } | undefined;
  const qs = await dailyQuestions(dayNo, stored?.region ?? region);
  const perms = await db.runTransaction(async (tx) => {
    const ss = await tx.get(sessRef(sid));
    if (ss.exists) return (ss.data() as { perms: string[] }).perms.map(dec);
    const pm = qs.map(() => randomPerm());
    tx.set(sessRef(sid), { uid, daily: true, day: dayNo, region, startedAt: now, lastAt: 0, perms: pm.map(enc), answers: [], status: "open" });
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
  const sid = `${uid}_d${dayNo}`;
  const qs = await dailyQuestions(dayNo, await sessionRegion(sid));
  const q = qs[i];
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

// ── Grand Défi : 15 questions d'affilée, de plus en plus dures, avec paliers et jokers ──────────────

const CH_STEPS = 15;
/** Points gagnés si on s'arrête (ou si on tombe) après chaque bonne réponse. */
const CH_PRIZES = [10, 20, 30, 50, 100, 150, 200, 300, 400, 600, 800, 1000, 1500, 2000, 3000];
/** Après la 5e et la 10e bonne réponse, le gain est garanti. */
const CH_FLOOR = (step: number) => (step >= 10 ? CH_PRIZES[9] : step >= 5 ? CH_PRIZES[4] : 0);
const chalRef = (uid: string) => sessRef(`${uid}_c`);

type ChalSess = {
  uid: string; status: "open" | "pending" | "done"; step: number; refs: string[]; perms: string[];
  region?: string; shownAt: number; startedAt: number; j50: boolean; swap: boolean; rescue: boolean; hide: string; prize: number;
};

/** Question tirée au hasard dans la difficulté de l'étape (3 questions par difficulté), jamais deux fois la même, ~80 % de la région du joueur. */
async function chalPick(step: number, used: Set<string>, region: string): Promise<string> {
  const tier = Math.floor(step / 3);
  const wantOwn = region === "mx" || Math.random() < OWN_SHARE;
  let last = `${tier * 40 + 1}:0`;
  for (let k = 0; k < 40; k++) {
    const n = tier * 40 + crypto.randomInt(1, 41);
    const i = crypto.randomInt(0, PER_LEVEL);
    const ref = `${n}:${i}`;
    if (used.has(ref)) continue;
    last = ref;
    const q = (await getLevel(n, region)).questions[i];
    const own = !q.r || region === "mx" || q.r === region;
    if (own === wantOwn || !q.r) return ref;
  }
  return last;
}

async function chalQuestion(ref: string, region: string = "af") {
  const [n, i] = ref.split(":").map(Number);
  return (await getLevel(n, region)).questions[i];
}

async function chalView(s: ChalSess) {
  const q = await chalQuestion(s.refs[s.step], s.region);
  const perm = dec(s.perms[s.step]);
  return {
    step: s.step, q: q.q, o: perm.map((orig) => q.o[orig]),
    hide: s.hide ? s.hide.split("").map(Number) : [],
    j50: s.j50, swap: s.swap, rescue: s.rescue,
    prize: s.step > 0 ? CH_PRIZES[s.step - 1] : 0,
  };
}

export const quizChallenge = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled || !cfg.challengeEnabled) throw new HttpsError("failed-precondition", "QUIZ_OFF");
  const action = String(request.data?.action ?? "");
  const info = await userInfo(uid);
  const now = Date.now();
  const lateMs = (cfg.challengeSeconds + 4) * 1000;

  const out = await db.runTransaction(async (tx) => {
    const [ps, ss] = await Promise.all([tx.get(progRef(uid)), tx.get(chalRef(uid))]);
    const p = normalise(ps.exists ? (ps.data() as Prog) : freshProg(info.country), cfg, now);
    let s: ChalSess | null = ss.exists ? (ss.data() as ChalSess) : null;
    let gain = 0;
    let ended = false;
    const end = (prize: number) => {
      const capLeft = Math.max(0, cfg.challengeDailyCap - (p.day.chalPts ?? 0));
      gain = Math.min(prize, capLeft);
      p.points += gain; p.lifetime += gain; p.week.pts += gain;
      p.day.chalPts = (p.day.chalPts ?? 0) + gain;
      p.chalBest = Math.max(p.chalBest ?? 0, s!.step);
      if (s!.step >= CH_STEPS) p.chalWins = (p.chalWins ?? 0) + 1;
      bumpStreak(p, now);
      s!.status = "done";
      s!.prize = prize;
      ended = true;
    };
    const late = !!s && s.status === "open" && now - s.shownAt > lateMs;

    // Le joueur est parti sans finir : une question restée sans réponse ou une chance non utilisée compte comme une chute
    if (s && ["info", "start", "resume"].includes(action)) {
      if (s.status === "pending" || late) end(CH_FLOOR(s.step));
    }
    const savePush = () => {
      if (s) tx.set(chalRef(uid), s);
      tx.set(progRef(uid), p);
    };
    const attempts = () => ({
      free: cfg.challengeFree, extraMax: cfg.challengeExtraMax, used: p.day.chal ?? 0,
      left: Math.max(0, cfg.challengeFree - (p.day.chal ?? 0)),
      extraLeft: Math.max(0, cfg.challengeFree + cfg.challengeExtraMax - Math.max(p.day.chal ?? 0, cfg.challengeFree)),
    });
    const base = () => ({ ok: true, ended, gain, prizes: CH_PRIZES, seconds: cfg.challengeSeconds, capLeft: Math.max(0, cfg.challengeDailyCap - (p.day.chalPts ?? 0)), best: p.chalBest ?? 0, wins: p.chalWins ?? 0, attempts: attempts(), state: publicState(p, cfg, now), weekId: p.week.id });

    if (action === "info") {
      savePush();
      return { ...base(), active: !!s && s.status === "open" };
    }

    if (action === "start") {
      if (s && s.status === "open") throw new HttpsError("failed-precondition", "ALREADY_ACTIVE");
      const used = p.day.chal ?? 0;
      const extra = request.data?.extra === true;
      if (!(used < cfg.challengeFree || (extra && used < cfg.challengeFree + cfg.challengeExtraMax))) throw new HttpsError("failed-precondition", "NO_ATTEMPTS");
      p.day.chal = used + 1;
      const region = regionOf(info.country || p.country);
      const refs: string[] = [];
      const seen = new Set<string>();
      for (let k = 0; k < CH_STEPS; k++) {
        const r = await chalPick(k, seen, region);
        seen.add(r);
        refs.push(r);
      }
      s = { uid, status: "open", step: 0, region, refs, perms: refs.map(() => enc(randomPerm())), shownAt: now, startedAt: now, j50: false, swap: false, rescue: false, hide: "", prize: 0 };
      savePush();
      return { ...base(), question: await chalView(s) };
    }

    if (!s) throw new HttpsError("failed-precondition", "NO_SESSION");

    if (action === "resume") {
      if (s.status !== "open") throw new HttpsError("failed-precondition", "NO_SESSION");
      savePush();
      return { ...base(), question: await chalView(s) };
    }

    if (action === "giveup") {
      if (s.status !== "pending") throw new HttpsError("failed-precondition", "NO_SESSION");
      end(CH_FLOOR(s.step));
      savePush();
      return { ...base(), reached: s.step, prize: s.prize };
    }

    if (action === "rescue") {
      if (s.status !== "pending" || s.rescue || !cfg.challengeRescue) throw new HttpsError("failed-precondition", "NO_RESCUE");
      s.rescue = true;
      s.status = "open";
      s.refs[s.step] = await chalPick(s.step, new Set(s.refs), s.region ?? "af");
      s.perms[s.step] = enc(randomPerm());
      s.hide = "";
      s.shownAt = now;
      savePush();
      return { ...base(), question: await chalView(s) };
    }

    if (s.status !== "open") throw new HttpsError("failed-precondition", "NO_SESSION");

    if (action === "answer") {
      const choice = intArg(request.data?.choice, -1, 3, "choice"); // -1 : temps écoulé
      if (now - s.shownAt < cfg.minAnswerMs) throw new HttpsError("resource-exhausted", "TOO_FAST");
      const q = await chalQuestion(s.refs[s.step], s.region);
      const perm = dec(s.perms[s.step]);
      const ok = !late && choice >= 0 && perm[choice] === q.a;
      p.answered += 1;
      const res = { correct: ok, late: late || choice < 0, correctIndex: perm.indexOf(q.a), explanation: q.e };
      if (ok) {
        p.correct += 1;
        s.step += 1;
        s.hide = "";
        s.shownAt = now;
        if (s.step >= CH_STEPS) {
          end(CH_PRIZES[CH_STEPS - 1]);
          savePush();
          return { ...base(), ...res, win: true, reached: s.step, prize: s.prize };
        }
        savePush();
        return { ...base(), ...res, question: await chalView(s) };
      }
      const canRescue = cfg.challengeRescue && !s.rescue && !late;
      if (canRescue) {
        s.status = "pending";
        savePush();
        return { ...base(), ...res, pending: true, canRescue: true, floor: CH_FLOOR(s.step) };
      }
      end(CH_FLOOR(s.step));
      savePush();
      return { ...base(), ...res, reached: s.step, prize: s.prize };
    }

    if (late) {
      end(CH_FLOOR(s.step));
      savePush();
      return { ...base(), expired: true, reached: s.step, prize: s.prize };
    }

    if (action === "cashout") {
      if (s.step <= 0) throw new HttpsError("failed-precondition", "NOTHING_TO_KEEP");
      end(CH_PRIZES[s.step - 1]);
      savePush();
      return { ...base(), reached: s.step, prize: s.prize };
    }

    if (action === "j50") {
      if (s.j50) throw new HttpsError("failed-precondition", "JOKER_USED");
      const q = await chalQuestion(s.refs[s.step], s.region);
      const perm = dec(s.perms[s.step]);
      const wrong = [0, 1, 2, 3].filter((d) => perm[d] !== q.a);
      const keep = wrong[crypto.randomInt(0, wrong.length)];
      s.hide = wrong.filter((d) => d !== keep).join("");
      s.j50 = true;
      savePush();
      return { ...base(), question: await chalView(s) };
    }

    if (action === "swap") {
      if (s.swap) throw new HttpsError("failed-precondition", "JOKER_USED");
      s.swap = true;
      s.refs[s.step] = await chalPick(s.step, new Set(s.refs), s.region ?? "af");
      s.perms[s.step] = enc(randomPerm());
      s.hide = "";
      s.shownAt = now;
      savePush();
      return { ...base(), question: await chalView(s) };
    }

    throw new HttpsError("invalid-argument", "action invalide.");
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

/** Chaque nuit : supprime les parties de plus de 7 jours (surtout les sessions du quiz du jour, une par joueur et par jour). */
export const quizCleanupSessions = onSchedule(
  { schedule: "every day 03:30", region: "us-central1", timeZone: "UTC", timeoutSeconds: 300, memory: "256MiB" },
  async () => {
    const limit = Date.now() - 7 * DAY;
    for (let round = 0; round < 20; round++) {
      const snap = await db.collection("QuizSessions").where("startedAt", "<", limit).limit(400).get();
      if (snap.empty) break;
      const batch = db.batch();
      snap.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
      if (snap.size < 400) break;
    }
  },
);
