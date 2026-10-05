import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { recordAppCommission } from "../payments/coinShares";

/**
 * Afrolook Étude : parcours scolaire et professionnel en jeu (classes à valider, brevet, BAC, licence, attestations).
 *
 * - EtudeCatalog/{parcours} (lisible par l'app) : structure (classes, matières, chapitres, prix) — produite par tools/etude/build_etude.js.
 * - EtudeContent/{chapitre} (serveur seulement) : fiche de cours + 3 niveaux de 5 questions.
 * - EtudeProgress/{uid} (serveur seulement) : progression, déblocages, diplômes.
 * - EtudeSessions/{uid}_{type}_{id} (serveur seulement) : questions d'une partie en cours.
 *
 * Un chapitre = 3 niveaux. Une classe est validée par sa « composition » (20 questions des chapitres de la classe, une fois
 * tous les chapitres terminés). Le diplôme du parcours (BEPC, BAC, licence…) se passe quand toutes les classes sont validées.
 * Les attestations sont des parcours courts (un domaine) avec un examen final.
 * Déblocages : pièces, ou pubs regardées (pubs en réserve de AdRewards, même circuit que la page Récompenses).
 */

const DAY = 86400000;
const dayKey = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, "");
const num = (v: unknown, def: number) => (typeof v === "number" && Number.isFinite(v) ? v : def);

const DEFAULTS = {
  enabled: true,
  adValueCoins: 3, // 1 pub regardée = 3 pièces de prix de déblocage (à ajuster avec le vrai eCPM des pubs récompensées)
  chapterPrice: 20,
  classPassPrice: 150,
  compoPrice: 30,
  examPrice: 60,
  certPrice: 40,
  minAnswerMs: 500,
  xpPerCorrect: 5,
  levelPerfectBonus: 10,
  chapterBonus: 30,
  classBonus: 100,
  diplomaBonus: 300,
  levelPassMin: 3,
};
type Cfg = typeof DEFAULTS & { prices: Record<string, number> };

type Q = { q: string; o: string[]; a: number; e: string };
type CatChapter = { id: string; title: string; levels: number; free?: boolean; price?: number };
type CatSubject = { id: string; title: string; icon?: string; chapters: CatChapter[] };
type CatClass = { id: string; title: string; subjects: CatSubject[]; compo?: { price?: number; count?: number; passPct?: number; seconds?: number }; passPrice?: number };
type CatTrack = {
  id: string; kind: "cycle" | "cert"; title: string; country?: string; order: number; after?: string;
  classes: CatClass[];
  exam?: { id: string; title: string; diploma: string; price?: number; count?: number; passPct?: number; seconds?: number };
  cert?: { id: string; title: string; from: string[]; price?: number; count?: number; passPct?: number; seconds?: number };
};
type Content = { id: string; title: string; lesson: { t: string; x: string }[]; levels: Q[][] };

type Prog = {
  entries: Record<string, string>; // parcours → classe de départ
  declared: Record<string, boolean>; // parcours précédent déclaré déjà réussi
  freeEpreuve: Record<string, string>; // parcours → première épreuve offerte (composition, examen ou attestation)
  xp: number;
  streak: { count: number; last: string };
  levels: Record<string, number>; // chapitre → niveaux réussis (0 à 3)
  classes: Record<string, { pct: number; at: number }>; // classes validées
  unlocked: Record<string, boolean>;
  adsPaid: Record<string, number>;
  diplomas: Record<string, { title: string; kind: string; serial: string; pct: number; at: number; track: string }>;
  answered: number;
  correct: number;
  createdAt: number;
};

const progRef = (uid: string) => db.collection("EtudeProgress").doc(uid);
const sessRef = (id: string) => db.collection("EtudeSessions").doc(id);

function uidOf(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  return uid;
}

let cfgCache: { at: number; cfg: Cfg } | null = null;
async function loadCfg(): Promise<Cfg> {
  if (cfgCache && Date.now() - cfgCache.at < 60000) return cfgCache.cfg;
  const d = (await db.collection("AppConfig").doc("etude").get()).data() ?? {};
  const cfg = { ...DEFAULTS, prices: {} } as Cfg;
  (Object.keys(DEFAULTS) as (keyof typeof DEFAULTS)[]).forEach((k) => {
    const def = DEFAULTS[k];
    const target = cfg as unknown as Record<string, unknown>;
    if (typeof def === "boolean") target[k] = d[k] === undefined ? def : !!d[k];
    else target[k] = Math.max(0, num(d[k], def as number));
  });
  cfg.prices = d["prices"] && typeof d["prices"] === "object" ? d["prices"] : {};
  cfgCache = { at: Date.now(), cfg };
  return cfg;
}

// ── Catalogue et contenu ────────────────────────────────────────────────────

let catCache: { at: number; tracks: CatTrack[] } | null = null;
async function loadCatalog(): Promise<CatTrack[]> {
  if (catCache && Date.now() - catCache.at < 300000) return catCache.tracks;
  const snap = await db.collection("EtudeCatalog").get();
  const tracks = snap.docs.map((d) => d.data() as CatTrack).sort((a, b) => a.order - b.order);
  catCache = { at: Date.now(), tracks };
  return tracks;
}

const contentCache = new Map<string, { at: number; c: Content }>();
async function loadContent(id: string): Promise<Content> {
  const hit = contentCache.get(id);
  if (hit && Date.now() - hit.at < 600000) return hit.c;
  const snap = await db.collection("EtudeContent").doc(id).get();
  if (!snap.exists) throw new HttpsError("not-found", "Chapitre introuvable.");
  const c = snap.data() as Content;
  contentCache.set(id, { at: Date.now(), c });
  return c;
}

type ChapterRef = { track: CatTrack; cls: CatClass; subject: CatSubject; ch: CatChapter };
function chapterIndex(tracks: CatTrack[]): Map<string, ChapterRef> {
  const m = new Map<string, ChapterRef>();
  for (const track of tracks) for (const cls of track.classes) for (const subject of cls.subjects) for (const ch of subject.chapters) m.set(ch.id, { track, cls, subject, ch });
  return m;
}
const classChapters = (cls: CatClass) => cls.subjects.flatMap((s) => s.chapters);

function freshProg(): Prog {
  return {
    entries: {}, declared: {}, freeEpreuve: {}, xp: 0, streak: { count: 0, last: "" }, levels: {}, classes: {}, unlocked: {}, adsPaid: {},
    diplomas: {}, answered: 0, correct: 0, createdAt: Date.now(),
  };
}
function normalise(p: Prog): Prog {
  const f = freshProg();
  return { ...f, ...p, streak: p.streak ?? f.streak };
}

function bumpStreak(p: Prog, now: number) {
  const today = dayKey(now);
  if (p.streak.last === today) return;
  p.streak.count = p.streak.last === dayKey(now - DAY) ? p.streak.count + 1 : 1;
  p.streak.last = today;
}

// ── Prix et accès ───────────────────────────────────────────────────────────

type Item = { id: string; title: string; price: number };
function itemInfo(itemId: string, tracks: CatTrack[], cfg: Cfg): Item | null {
  const [kind, id] = [itemId.slice(0, itemId.indexOf(":")), itemId.slice(itemId.indexOf(":") + 1)];
  const override = (def: number) => (typeof cfg.prices[itemId] === "number" ? cfg.prices[itemId] : def);
  if (kind === "ch") {
    const r = chapterIndex(tracks).get(id);
    if (!r || r.ch.free) return null;
    return { id: itemId, title: r.ch.title, price: override(r.ch.price ?? cfg.chapterPrice) };
  }
  for (const t of tracks) {
    if (kind === "cls") {
      const c = t.classes.find((x) => x.id === id);
      if (c) return { id: itemId, title: `Pass ${c.title}`, price: override(c.passPrice ?? cfg.classPassPrice) };
    } else if (kind === "compo") {
      const c = t.classes.find((x) => x.id === id);
      if (c) return { id: itemId, title: `Composition ${c.title}`, price: override(c.compo?.price ?? cfg.compoPrice) };
    } else if (kind === "exam" && t.exam && t.id === id) {
      return { id: itemId, title: t.exam.title, price: override(t.exam.price ?? cfg.examPrice) };
    } else if (kind === "cert" && t.cert && t.cert.id === id) {
      return { id: itemId, title: t.cert.title, price: override(t.cert.price ?? cfg.certPrice) };
    }
  }
  return null;
}

/** Parcours auquel appartient un contenu à débloquer. */
function trackOfItem(itemId: string, tracks: CatTrack[]): string {
  const kind = itemId.slice(0, itemId.indexOf(":"));
  const id = itemId.slice(itemId.indexOf(":") + 1);
  if (kind === "exam") return id;
  if (kind === "cert") return tracks.find((t) => t.cert?.id === id)?.id ?? "";
  return tracks.find((t) => t.classes.some((c) => c.id === id))?.id ?? "";
}

function hasAccess(p: Prog, itemId: string, tracks: CatTrack[]): boolean {
  if (p.unlocked[itemId]) return true;
  const k0 = itemId.slice(0, itemId.indexOf(":"));
  // La première épreuve de chaque parcours est offerte : on la débloque en la commençant, puis pièces ou pubs pour les suivantes
  if (k0 === "compo" || k0 === "exam" || k0 === "cert") {
    const free = p.freeEpreuve[trackOfItem(itemId, tracks)];
    if (free === itemId) return true;
  }
  const [kind, id] = [itemId.slice(0, itemId.indexOf(":")), itemId.slice(itemId.indexOf(":") + 1)];
  if (kind === "ch") {
    const r = chapterIndex(tracks).get(id);
    if (!r) return false;
    return !!r.ch.free || !!p.unlocked[`cls:${r.cls.id}`];
  }
  if (kind === "compo") return !!p.unlocked[`cls:${id}`];
  return false;
}

/** Une épreuve est jouable si elle est débloquée, ou si la première épreuve offerte du parcours n'est pas encore prise. */
function epreuveAccess(p: Prog, itemId: string, tracks: CatTrack[]): boolean {
  if (hasAccess(p, itemId, tracks)) return true;
  return !p.freeEpreuve[trackOfItem(itemId, tracks)];
}

const chapterDone = (p: Prog, ch: CatChapter) => (p.levels[ch.id] ?? 0) >= ch.levels;
const classAllDone = (p: Prog, cls: CatClass) => {
  const chs = classChapters(cls);
  return chs.length > 0 && chs.every((c) => chapterDone(p, c));
};

/** État de chaque classe d'un parcours commencé : validated, open, locked (classe d'avant non validée) ou soon (pas encore de contenu). */
function trackStatus(p: Prog, track: CatTrack) {
  const entry = p.entries[track.id];
  if (!entry) return null;
  const start = Math.max(0, track.classes.findIndex((c) => c.id === entry));
  const classes: Record<string, { status: string; done: number; total: number; pct?: number }> = {};
  let prevOk = true;
  let allValidated = true;
  track.classes.forEach((cls, i) => {
    const chs = classChapters(cls);
    const done = chs.filter((c) => chapterDone(p, c)).length;
    const validated = !!p.classes[cls.id];
    let status: string;
    if (i < start) status = "skipped";
    else if (chs.length === 0) status = "soon";
    else if (validated) status = "validated";
    else if (prevOk) status = "open";
    else status = "locked";
    classes[cls.id] = { status, done, total: chs.length, ...(validated ? { pct: p.classes[cls.id].pct } : {}) };
    if (i >= start) {
      if (!validated) allValidated = false;
      prevOk = prevOk && validated;
    }
  });
  const examReady = track.kind === "cycle" && !!track.exam && allValidated;
  return { entry, classes, examReady, diploma: track.exam ? p.diplomas[track.exam.id] ?? null : null };
}

// ── Lecture de l'état ───────────────────────────────────────────────────────

async function pendingAds(uid: string): Promise<number> {
  const d = (await db.collection("AdRewards").doc(`${uid}_${dayKey()}`).get()).data() ?? {};
  return num(d["pending"], 0);
}

async function publicState(uid: string, p: Prog, cfg: Cfg, tracks: CatTrack[]) {
  const status: Record<string, unknown> = {};
  for (const t of tracks) {
    if (t.kind === "cycle") {
      const s = trackStatus(p, t);
      if (s) status[t.id] = s;
    }
  }
  const certs: Record<string, unknown> = {};
  for (const t of tracks) {
    if (t.kind === "cert" && t.cert) {
      const idx = chapterIndex(tracks);
      const chs = t.cert.from.map((id) => idx.get(id)?.ch).filter((c): c is CatChapter => !!c);
      certs[t.cert.id] = { done: chs.filter((c) => chapterDone(p, c)).length, total: chs.length, diploma: p.diplomas[t.cert.id] ?? null };
    }
  }
  return {
    entries: p.entries, declared: p.declared, freeEpreuve: p.freeEpreuve, xp: p.xp, streak: p.streak.last === dayKey() || p.streak.last === dayKey(Date.now() - DAY) ? p.streak.count : 0,
    levels: p.levels, classes: p.classes, unlocked: p.unlocked, adsPaid: p.adsPaid,
    diplomas: Object.values(p.diplomas),
    tracks: status, certs,
    pendingAds: await pendingAds(uid),
    config: { adValueCoins: cfg.adValueCoins, chapterPrice: cfg.chapterPrice, classPassPrice: cfg.classPassPrice, compoPrice: cfg.compoPrice, examPrice: cfg.examPrice, certPrice: cfg.certPrice, prices: cfg.prices },
    level: Math.floor(Math.sqrt(p.xp / 50)) + 1,
  };
}

async function readProg(uid: string): Promise<Prog> {
  const s = await progRef(uid).get();
  return normalise(s.exists ? (s.data() as Prog) : freshProg());
}

export const etudeGetState = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "ETUDE_OFF");
  const [p, tracks] = await Promise.all([readProg(uid), loadCatalog()]);
  return { ok: true, ...(await publicState(uid, p, cfg, tracks)) };
});

/** Commence un parcours à la classe choisie (par défaut la première). Les parcours qui suivent un autre demandent le diplôme d'avant, ou de le déclarer déjà obtenu. */
export const etudeStartTrack = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "ETUDE_OFF");
  const trackId = String(request.data?.track ?? "");
  const entry = String(request.data?.entry ?? "");
  const declared = request.data?.declared === true;
  const tracks = await loadCatalog();
  const t = tracks.find((x) => x.id === trackId && x.kind === "cycle");
  if (!t) throw new HttpsError("not-found", "Parcours introuvable.");
  const cls = entry ? t.classes.find((c) => c.id === entry) : t.classes[0];
  if (!cls) throw new HttpsError("invalid-argument", "Classe inconnue.");
  const out = await db.runTransaction(async (tx) => {
    const snap = await tx.get(progRef(uid));
    const p = normalise(snap.exists ? (snap.data() as Prog) : freshProg());
    const prev = t.after ? tracks.find((x) => x.id === t.after) : undefined;
    if (prev?.exam && !p.diplomas[prev.exam.id]) {
      if (!declared) throw new HttpsError("failed-precondition", "NEED_PREVIOUS");
      p.declared[prev.id] = true;
    }
    p.entries[t.id] = cls.id;
    tx.set(progRef(uid), p);
    return p;
  });
  return { ok: true, ...(await publicState(uid, out, cfg, tracks)) };
});

// ── Contenu d'un chapitre ───────────────────────────────────────────────────

export const etudeOpenChapter = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const chapterId = String(request.data?.chapter ?? "");
  const [p, tracks] = await Promise.all([readProg(uid), loadCatalog()]);
  const r = chapterIndex(tracks).get(chapterId);
  if (!r) throw new HttpsError("not-found", "Chapitre introuvable.");
  if (!hasAccess(p, `ch:${chapterId}`, tracks)) throw new HttpsError("failed-precondition", "LOCKED");
  const c = await loadContent(chapterId);
  return { ok: true, id: c.id, title: c.title, lesson: c.lesson, levels: r.ch.levels, done: p.levels[chapterId] ?? 0 };
});

// ── Parties (niveau, composition, examen, attestation) ──────────────────────

function randomPerm(): number[] {
  const p = [0, 1, 2, 3];
  for (let i = 3; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [p[i], p[j]] = [p[j], p[i]];
  }
  return p;
}
const enc = (p: number[]) => p.join("");
const dec = (v: string) => v.split("").map(Number);

function pickBalanced(groups: Q[][], count: number): Q[] {
  const g = groups.map((x) => {
    const a = x.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = crypto.randomInt(0, i + 1);
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  });
  const out: Q[] = [];
  let k = 0;
  while (out.length < count && g.some((x) => x.length)) {
    const x = g[k % g.length];
    if (x.length) out.push(x.pop() as Q);
    k++;
  }
  return out;
}

async function chapterQuestions(ids: string[]): Promise<Q[][]> {
  const cs = await Promise.all(ids.map((id) => loadContent(id)));
  return cs.map((c) => c.levels.flat());
}

type SessDoc = { uid: string; kind: string; ref: string; title: string; pct: number; seconds: number; qs: Q[]; perms: string[]; answers: { c: number; ok: boolean }[]; status: string; lastAt: number; result?: Record<string, unknown> };

export const etudeStart = onCall({ timeoutSeconds: 25 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "ETUDE_OFF");
  const kind = String(request.data?.kind ?? "");
  const ref = String(request.data?.id ?? "");
  const [p, tracks] = await Promise.all([readProg(uid), loadCatalog()]);
  const idx = chapterIndex(tracks);
  let qs: Q[] = [];
  let title = "";
  let pct = 0.5;
  let seconds = 0;
  let practice = false;

  if (kind === "level") {
    const [chapterId, lvS] = ref.split(":");
    const lv = Number(lvS);
    const r = idx.get(chapterId);
    if (!r || !Number.isInteger(lv) || lv < 1 || lv > r.ch.levels) throw new HttpsError("invalid-argument", "Niveau invalide.");
    if (!hasAccess(p, `ch:${chapterId}`, tracks)) throw new HttpsError("failed-precondition", "LOCKED");
    const done = p.levels[chapterId] ?? 0;
    if (lv > done + 1) throw new HttpsError("failed-precondition", "LEVEL_LOCKED");
    practice = lv <= done;
    const c = await loadContent(chapterId);
    qs = c.levels[lv - 1];
    title = `${r.ch.title} · niveau ${lv}`;
    pct = cfg.levelPassMin / qs.length;
  } else if (kind === "compo") {
    const t = tracks.find((x) => x.classes.some((c) => c.id === ref));
    const cls = t?.classes.find((c) => c.id === ref);
    if (!t || !cls) throw new HttpsError("not-found", "Classe introuvable.");
    if (!epreuveAccess(p, `compo:${cls.id}`, tracks)) throw new HttpsError("failed-precondition", "LOCKED");
    if (!classAllDone(p, cls)) throw new HttpsError("failed-precondition", "CHAPTERS_TODO");
    const st = trackStatus(p, t);
    if (!st || st.classes[cls.id]?.status === "locked") throw new HttpsError("failed-precondition", "PREVIOUS_CLASS");
    qs = pickBalanced(await chapterQuestions(classChapters(cls).map((c) => c.id)), cls.compo?.count ?? 20);
    title = `Composition · ${cls.title}`;
    pct = cls.compo?.passPct ?? 0.5;
    seconds = cls.compo?.seconds ?? 1800;
  } else if (kind === "exam") {
    const t = tracks.find((x) => x.id === ref && x.kind === "cycle" && x.exam);
    if (!t || !t.exam) throw new HttpsError("not-found", "Examen introuvable.");
    if (!epreuveAccess(p, `exam:${t.id}`, tracks)) throw new HttpsError("failed-precondition", "LOCKED");
    const st = trackStatus(p, t);
    if (!st?.examReady) throw new HttpsError("failed-precondition", "CLASSES_TODO");
    const start = t.classes.findIndex((c) => c.id === p.entries[t.id]);
    const groups: Q[][] = [];
    for (const cls of t.classes.slice(Math.max(0, start))) groups.push((await chapterQuestions(classChapters(cls).map((c) => c.id))).flat());
    qs = pickBalanced(groups, t.exam.count ?? 40);
    title = t.exam.title;
    pct = t.exam.passPct ?? 0.5;
    seconds = t.exam.seconds ?? 3600;
  } else if (kind === "cert") {
    const t = tracks.find((x) => x.kind === "cert" && x.cert?.id === ref);
    if (!t?.cert) throw new HttpsError("not-found", "Attestation introuvable.");
    if (!epreuveAccess(p, `cert:${t.cert.id}`, tracks)) throw new HttpsError("failed-precondition", "LOCKED");
    const chs = t.cert.from.map((id) => idx.get(id)?.ch).filter((c): c is CatChapter => !!c);
    if (!chs.length || !chs.every((c) => chapterDone(p, c))) throw new HttpsError("failed-precondition", "CHAPTERS_TODO");
    qs = pickBalanced(await chapterQuestions(chs.map((c) => c.id)), t.cert.count ?? 30);
    title = t.cert.title;
    pct = t.cert.passPct ?? 0.7;
    seconds = t.cert.seconds ?? 1500;
  } else throw new HttpsError("invalid-argument", "Type inconnu.");

  if (!qs.length) throw new HttpsError("failed-precondition", "EMPTY");
  if (kind !== "level") {
    const itemId = `${kind}:${ref}`;
    const tid = trackOfItem(itemId, tracks);
    if (!p.unlocked[itemId] && !p.unlocked[`cls:${ref}`] && !p.freeEpreuve[tid]) {
      p.freeEpreuve[tid] = itemId;
      await progRef(uid).set(p);
    }
  }
  const sid = `${uid}_${kind}_${ref.replace(/[^A-Za-z0-9_:-]/g, "")}`;
  const perms = qs.map(() => randomPerm());
  const now = Date.now();
  const doc: SessDoc = { uid, kind, ref, title, pct, seconds, qs, perms: perms.map(enc), answers: [], status: "open", lastAt: now };
  await sessRef(sid).set({ ...doc, practice, startedAt: now });
  return {
    ok: true, sid, kind, id: ref, title, total: qs.length, passPct: pct, seconds, practice,
    questions: qs.map((q, i) => ({ q: q.q, o: perms[i].map((orig) => q.o[orig]) })),
  };
});

export const etudeAnswer = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const sid = String(request.data?.sid ?? "");
  const i = Number(request.data?.i);
  const choice = Number(request.data?.choice);
  if (!Number.isInteger(i) || !Number.isInteger(choice) || choice < 0 || choice > 3 || i < 0) throw new HttpsError("invalid-argument", "Réponse invalide.");
  if (!sid.startsWith(`${uid}_`)) throw new HttpsError("permission-denied", "Partie inconnue.");
  const now = Date.now();
  return db.runTransaction(async (tx) => {
    const ss = await tx.get(sessRef(sid));
    const s = ss.data() as SessDoc | undefined;
    if (!s || s.uid !== uid || s.status !== "open") throw new HttpsError("failed-precondition", "NO_SESSION");
    if (i >= s.qs.length || s.answers.length !== i) throw new HttpsError("failed-precondition", "OUT_OF_ORDER");
    if (now - s.lastAt < cfg.minAnswerMs) throw new HttpsError("resource-exhausted", "TOO_FAST");
    const q = s.qs[i];
    const perm = dec(s.perms[i]);
    const ok = perm[choice] === q.a;
    s.answers.push({ c: choice, ok });
    tx.update(sessRef(sid), { answers: s.answers, lastAt: now });
    return { ok: true, correct: ok, correctIndex: perm.indexOf(q.a), explanation: q.e };
  });
});

function serialFor(): string {
  return `AFR-${crypto.randomBytes(4).toString("hex").toUpperCase()}`;
}

export const etudeFinish = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const sid = String(request.data?.sid ?? "");
  if (!sid.startsWith(`${uid}_`)) throw new HttpsError("permission-denied", "Partie inconnue.");
  const tracks = await loadCatalog();
  const idx = chapterIndex(tracks);
  const now = Date.now();
  const userSnap = await db.collection("Users").doc(uid).get();
  const userName = String(userSnap.data()?.["pseudo"] ?? userSnap.data()?.["nom"] ?? "").slice(0, 60);

  return db.runTransaction(async (tx) => {
    const [ss, ps] = await Promise.all([tx.get(sessRef(sid)), tx.get(progRef(uid))]);
    const s = ss.data() as (SessDoc & { practice?: boolean }) | undefined;
    if (!s || s.uid !== uid) throw new HttpsError("failed-precondition", "NO_SESSION");
    if (s.status === "done" && s.result) return s.result;
    if (s.answers.length !== s.qs.length) throw new HttpsError("failed-precondition", "NOT_FINISHED");
    const p = normalise(ps.exists ? (ps.data() as Prog) : freshProg());
    const correct = s.answers.filter((a) => a.ok).length;
    const total = s.qs.length;
    const ratio = correct / total;
    const pass = ratio + 1e-9 >= s.pct;
    let xp = 0;
    let chapterFinished = false;
    let classValidated = "";
    let diploma: Prog["diplomas"][string] | null = null;
    p.answered += total;
    p.correct += correct;

    if (s.kind === "level") {
      const [chapterId, lvS] = s.ref.split(":");
      const lv = Number(lvS);
      const r = idx.get(chapterId);
      if (pass && r && lv > (p.levels[chapterId] ?? 0) && !s.practice) {
        p.levels[chapterId] = lv;
        xp += correct * cfg.xpPerCorrect + (correct === total ? cfg.levelPerfectBonus : 0);
        if (lv >= r.ch.levels) {
          chapterFinished = true;
          xp += cfg.chapterBonus;
        }
      }
    } else if (s.kind === "compo" && pass && !p.classes[s.ref]) {
      p.classes[s.ref] = { pct: Math.round(ratio * 100), at: now };
      classValidated = s.ref;
      xp += cfg.classBonus;
    } else if ((s.kind === "exam" || s.kind === "cert") && pass) {
      const t = s.kind === "exam" ? tracks.find((x) => x.id === s.ref) : tracks.find((x) => x.cert?.id === s.ref);
      const did = s.kind === "exam" ? t?.exam?.id : t?.cert?.id;
      if (t && did && !p.diplomas[did]) {
        diploma = {
          title: s.kind === "exam" ? (t.exam?.diploma ?? t.title) : (t.cert?.title ?? t.title),
          kind: s.kind, serial: serialFor(), pct: Math.round(ratio * 100), at: now, track: t.id,
        };
        p.diplomas[did] = diploma;
        xp += cfg.diplomaBonus;
        tx.set(db.collection("EtudeDiplomas").doc(diploma.serial), { ...diploma, uid, name: userName, id: did });
      }
    }
    p.xp += xp;
    if (pass) bumpStreak(p, now);
    const result = {
      ok: true, pass, correct, total, pct: Math.round(ratio * 100), need: Math.round(s.pct * 100), xp,
      chapterFinished, classValidated, diploma, kind: s.kind, id: s.ref,
    };
    tx.update(sessRef(sid), { status: "done", result });
    tx.set(progRef(uid), p);
    return result;
  });
});

// ── Déblocage : pièces ou pubs ──────────────────────────────────────────────

/** Nombre de pubs équivalent à un prix en pièces. */
const adsFor = (price: number, cfg: Cfg) => Math.max(1, Math.ceil(price / Math.max(1, cfg.adValueCoins)));

export const etudeUnlock = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "ETUDE_OFF");
  const itemId = String(request.data?.item ?? "");
  const via = String(request.data?.via ?? "coins");
  if (via !== "coins" && via !== "ads") throw new HttpsError("invalid-argument", "Mode inconnu.");
  const tracks = await loadCatalog();
  const item = itemInfo(itemId, tracks, cfg);
  if (!item) throw new HttpsError("not-found", "Contenu introuvable ou déjà gratuit.");
  const now = Date.now();
  const userRef = db.collection("Users").doc(uid);
  const adsRef = db.collection("AdRewards").doc(`${uid}_${dayKey(now)}`);

  const out = await db.runTransaction(async (tx) => {
    const [ps, us, ar] = await Promise.all([tx.get(progRef(uid)), tx.get(userRef), tx.get(adsRef)]);
    const p = normalise(ps.exists ? (ps.data() as Prog) : freshProg());
    if (p.unlocked[itemId]) return { unlocked: true, already: true, spent: 0, adsPaid: p.adsPaid[itemId] ?? 0, adsNeeded: adsFor(item.price, cfg) };
    const adsNeeded = adsFor(item.price, cfg);
    if (via === "coins") {
      const balance = num(us.data()?.["giftCoinsBalance"], 0);
      if (balance < item.price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: item.price, balance });
      tx.update(userRef, { giftCoinsBalance: FieldValue.increment(-item.price), totalGiftCoinsSpent: FieldValue.increment(item.price), updatedAt: now });
      const t = db.collection("TransactionSoldes").doc();
      tx.set(t, {
        id: t.id, user_id: uid, type: "PAIEMENT_PIECES", statut: "VALIDER",
        description: `Étude : ${item.title} — ${item.price} pièces`,
        montant: item.price, frais: 0, montant_total: item.price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "etude", purchaseRefId: itemId,
      });
      recordAppCommission(tx, "etude", item.price, now);
      p.unlocked[itemId] = true;
      delete p.adsPaid[itemId];
      tx.set(progRef(uid), p);
      return { unlocked: true, spent: item.price, adsPaid: 0, adsNeeded };
    }
    // pubs : on prend dans la réserve du jour (les pubs regardées via « Récompenses » ou ici)
    const pending = num(ar.data()?.["pending"], 0);
    const paid = p.adsPaid[itemId] ?? 0;
    const take = Math.min(pending, adsNeeded - paid);
    if (take <= 0) throw new HttpsError("failed-precondition", "NO_ADS");
    p.adsPaid[itemId] = paid + take;
    tx.set(adsRef, { pending: pending - take }, { merge: true });
    const unlocked = p.adsPaid[itemId] >= adsNeeded;
    if (unlocked) {
      p.unlocked[itemId] = true;
      delete p.adsPaid[itemId];
    }
    tx.set(progRef(uid), p);
    tx.set(db.collection("AdRewardStats").doc(dayKey(now)), { day: dayKey(now), claims: { [`etude_${itemId.split(":")[0]}`]: FieldValue.increment(unlocked ? 1 : 0) }, adsSpent: FieldValue.increment(take) }, { merge: true });
    return { unlocked, spent: 0, adsPaid: unlocked ? adsNeeded : paid + take, adsNeeded };
  });
  const [p2, tr2] = [await readProg(uid), tracks];
  return { ok: true, ...out, state: await publicState(uid, p2, cfg, tr2) };
});

// ── Vérification d'un diplôme par son numéro ────────────────────────────────

export const etudeVerifyDiploma = onCall({ timeoutSeconds: 10 }, async (request) => {
  uidOf(request);
  const serial = String(request.data?.serial ?? "").trim().toUpperCase();
  if (!/^AFR-[0-9A-F]{8}$/.test(serial)) throw new HttpsError("invalid-argument", "Numéro invalide.");
  const d = (await db.collection("EtudeDiplomas").doc(serial).get()).data();
  if (!d) return { ok: true, valid: false };
  return { ok: true, valid: true, title: d["title"], name: d["name"], pct: d["pct"], at: d["at"] };
});
