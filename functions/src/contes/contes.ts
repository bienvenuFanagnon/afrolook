import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { recordAppCommission } from "../payments/coinShares";

/**
 * Afrolook Contes et Récits : « La Case aux Contes ».
 *
 * - ContesIndex/meta et ContesIndex/c{n} (lisibles par l'app) : recueils et fiches légères des contes
 *   (produits par tools/contes/build_contes.js).
 * - ContesStories/{id} (serveur seulement) : fiche complète d'un conte (prix, pages gratuites…).
 * - ContesText/{id} (serveur seulement) : pages du conte. Les pages verrouillées ne sont envoyées qu'après déblocage.
 * - ContesUsers/{uid} (serveur seulement) : lus, terminés, déblocages, jauge de pubs, pass, lectures offertes.
 * - ContesStats/{jour}, ContesStoryStats/{id} : mesures pour l'administration.
 *
 * Déblocage d'un conte (item « st:<id> »), d'un recueil (« co:<recueil> ») ou du Pass Veillée (« pass ») :
 * pièces, pubs regardées (même circuit que Étude : pubs en réserve dans AdRewards) ou, quand aucune pub n'est disponible,
 * lecture offerte (quota par jour) pour que le lecteur ne reste jamais bloqué.
 */

const DAY = 86400000;
const dayKey = (t = Date.now()) => new Date(t).toISOString().slice(0, 10).replace(/-/g, "");
const num = (v: unknown, def: number) => (typeof v === "number" && Number.isFinite(v) ? v : def);

const DEFAULTS = {
  enabled: true,
  adValueCoins: 10, // 1 pub avec récompense = 10 pièces de prix de déblocage (même valeur que Étude)
  interstitialValueCoins: 7,
  interstitialMaxPerDay: 6,
  interstitialGapSec: 15,
  freePerDay: 2, // lectures offertes par jour quand aucune pub n'est disponible
  priceCourt: 10,
  priceLong: 20,
  priceChapitre: 20,
  priceRecueil: 70,
  pricePass: 80,
  passHours: 24,
  feedEnabled: true,
  feedFirstAfter: 7,
  feedSecondAfter: 22,
  interstitialEveryStories: 2,
  maxReadsKept: 800,
};
type Cfg = typeof DEFAULTS;

type Story = {
  id: string; title: string; collectionId: string; kind: string; price?: number; free: number; pages: number; active?: boolean; daily?: boolean;
};
type UserState = {
  reads: Record<string, number>;
  done: Record<string, number>;
  unlocked: Record<string, number>;
  adsPaid: Record<string, number>;
  passUntil: number;
  free: { day: string; used: number };
  daily: { day: string; id: string };
};

function uidOf(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  return uid;
}

let cfgCache: { at: number; cfg: Cfg } | null = null;
async function loadCfg(): Promise<Cfg> {
  if (cfgCache && Date.now() - cfgCache.at < 60000) return cfgCache.cfg;
  const d = (await db.collection("AppConfig").doc("contes").get()).data() ?? {};
  const cfg = { ...DEFAULTS };
  (Object.keys(DEFAULTS) as (keyof Cfg)[]).forEach((k) => {
    const def = DEFAULTS[k];
    const target = cfg as unknown as Record<string, unknown>;
    if (typeof def === "boolean") target[k] = d[k] === undefined ? def : !!d[k];
    else target[k] = Math.max(0, num(d[k], def as number));
  });
  cfgCache = { at: Date.now(), cfg };
  return cfg;
}

const userRef = (uid: string) => db.collection("ContesUsers").doc(uid);

function normalise(raw: Partial<UserState> | undefined): UserState {
  const r = raw ?? {};
  return {
    reads: r.reads ?? {}, done: r.done ?? {}, unlocked: r.unlocked ?? {}, adsPaid: r.adsPaid ?? {},
    passUntil: num(r.passUntil, 0), free: r.free ?? { day: "", used: 0 }, daily: r.daily ?? { day: "", id: "" },
  };
}

async function readUser(uid: string): Promise<UserState> {
  return normalise((await userRef(uid).get()).data() as Partial<UserState> | undefined);
}

function hash(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

async function loadMeta(): Promise<{ collections: Record<string, { price?: number }>; dailyPool: string[] }> {
  const d = (await db.collection("ContesIndex").doc("meta").get()).data() ?? {};
  const cols: Record<string, { price?: number }> = {};
  ((d["collections"] ?? []) as { id: string; price?: number }[]).forEach((c) => { cols[c.id] = { price: c.price }; });
  return { collections: cols, dailyPool: (d["dailyPool"] ?? []) as string[] };
}

function storyPrice(s: Story, cfg: Cfg): number {
  if (typeof s.price === "number") return Math.max(0, s.price);
  if (s.kind === "gratuit") return 0;
  if (s.kind === "long") return cfg.priceLong;
  if (s.kind === "chapitre") return cfg.priceChapitre;
  return cfg.priceCourt;
}

function accessKind(u: UserState, s: Story, cfg: Cfg, now: number): "free" | "daily" | "owned" | "pass" | "locked" {
  if (storyPrice(s, cfg) <= 0) return "free";
  if (u.daily.day === dayKey(now) && u.daily.id === s.id) return "daily";
  if (u.unlocked[`st:${s.id}`] || u.unlocked[`co:${s.collectionId}`]) return "owned";
  if (u.passUntil > now) return "pass";
  return "locked";
}

/** Le « conte du jour » de chaque lecteur : un conte qu'il n'a pas encore lu, gratuit en entier ce jour-là. */
async function ensureDaily(uid: string, u: UserState, now: number): Promise<UserState> {
  const today = dayKey(now);
  if (u.daily.day === today && u.daily.id) return u;
  const { dailyPool } = await loadMeta();
  if (dailyPool.length === 0) return u;
  const dayNum = Math.floor(now / DAY);
  const start = (dayNum + hash(uid)) % dailyPool.length;
  let pick = dailyPool[start];
  for (let k = 0; k < dailyPool.length; k++) {
    const id = dailyPool[(start + k) % dailyPool.length];
    if (!u.reads[id]) { pick = id; break; }
  }
  u.daily = { day: today, id: pick };
  await userRef(uid).set({ daily: u.daily }, { merge: true });
  return u;
}

function publicState(u: UserState, cfg: Cfg, now: number) {
  const today = dayKey(now);
  const unlockedStories = Object.keys(u.unlocked).filter((k) => k.startsWith("st:")).map((k) => k.slice(3));
  const unlockedCollections = Object.keys(u.unlocked).filter((k) => k.startsWith("co:")).map((k) => k.slice(3));
  const freeUsed = u.free.day === today ? u.free.used : 0;
  return {
    reads: u.reads, done: u.done, unlockedStories, unlockedCollections,
    adsPaid: u.adsPaid, passUntil: u.passUntil, passActive: u.passUntil > now,
    freeLeft: Math.max(0, cfg.freePerDay - freeUsed),
    dailyId: u.daily.day === today ? u.daily.id : "",
    cfg: {
      enabled: cfg.enabled, adValueCoins: cfg.adValueCoins, interstitialValueCoins: cfg.interstitialValueCoins,
      priceCourt: cfg.priceCourt, priceLong: cfg.priceLong, priceChapitre: cfg.priceChapitre,
      priceRecueil: cfg.priceRecueil, pricePass: cfg.pricePass, passHours: cfg.passHours,
      interstitialEveryStories: cfg.interstitialEveryStories, interstitialMaxPerDay: cfg.interstitialMaxPerDay,
      feedEnabled: cfg.feedEnabled, feedFirstAfter: cfg.feedFirstAfter, feedSecondAfter: cfg.feedSecondAfter,
    },
  };
}

export const conteGetState = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  const now = Date.now();
  let u = await readUser(uid);
  if (cfg.enabled) u = await ensureDaily(uid, u, now);
  return { ok: true, ...publicState(u, cfg, now) };
});

async function loadStory(id: string): Promise<Story> {
  const snap = await db.collection("ContesStories").doc(id).get();
  if (!snap.exists || snap.data()?.["active"] === false) throw new HttpsError("not-found", "Conte introuvable.");
  return { ...(snap.data() as Story), id };
}

const bump = (day: string, fields: Record<string, number>) => {
  const inc: Record<string, unknown> = { day };
  Object.entries(fields).forEach(([k, v]) => { inc[k] = FieldValue.increment(v); });
  return db.collection("ContesStats").doc(day).set(inc, { merge: true });
};

/** Ouvre un conte : pages gratuites, ou toutes les pages si le lecteur y a accès. */
export const conteOpen = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "CONTES_OFF");
  const id = String(request.data?.id ?? "");
  if (!id) throw new HttpsError("invalid-argument", "Conte requis.");
  const now = Date.now();
  const [story, textSnap, rawUser] = await Promise.all([loadStory(id), db.collection("ContesText").doc(id).get(), readUser(uid)]);
  const u = await ensureDaily(uid, rawUser, now);
  const pages = ((textSnap.data()?.["pages"] ?? []) as string[]).map(String);
  if (pages.length === 0) throw new HttpsError("not-found", "Conte vide.");
  const access = accessKind(u, story, cfg, now);
  const open = access !== "locked";
  const firstRead = !u.reads[id];
  const readsPatch: Record<string, unknown> = { [id]: now };
  if (firstRead) {
    // garde l'historique à une taille raisonnable (le document du lecteur est relu à chaque ouverture)
    const ids = Object.keys(u.reads);
    if (ids.length >= cfg.maxReadsKept) {
      ids.sort((a, b) => u.reads[a] - u.reads[b]).slice(0, ids.length - cfg.maxReadsKept + 1).forEach((k) => { readsPatch[k] = FieldValue.delete(); });
    }
  }
  await userRef(uid).set({ reads: readsPatch }, { merge: true });
  const day = dayKey(now);
  bump(day, { opens: 1, ...(firstRead ? { firstOpens: 1 } : {}) }).catch(() => undefined);
  db.collection("ContesStoryStats").doc(id).set({ id, opens: FieldValue.increment(1), ...(open ? {} : { lockedOpens: FieldValue.increment(1) }) }, { merge: true }).catch(() => undefined);
  const price = storyPrice(story, cfg);
  return {
    ok: true, id, access, locked: !open, price, total: pages.length, free: story.free,
    pages: open ? pages : pages.slice(0, Math.max(1, Math.min(story.free, pages.length))),
    adsPaid: u.adsPaid[`st:${id}`] ?? 0,
    morale: open ? String(textSnap.data()?.["morale"] ?? "") : "",
  };
});

function itemPrice(item: string, story: Story | null, collections: Record<string, { price?: number }>, cfg: Cfg): number {
  if (item === "pass") return cfg.pricePass;
  if (item.startsWith("co:")) return Math.max(1, num(collections[item.slice(3)]?.price, cfg.priceRecueil));
  if (story) return storyPrice(story, cfg);
  return 0;
}

export const conteUnlock = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = uidOf(request);
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "CONTES_OFF");
  const item = String(request.data?.item ?? "");
  const via = String(request.data?.via ?? "coins");
  const format = String(request.data?.format ?? "rewarded");
  if (via !== "coins" && via !== "ads" && via !== "free") throw new HttpsError("invalid-argument", "Mode inconnu.");
  if (format !== "rewarded" && format !== "interstitial") throw new HttpsError("invalid-argument", "Format inconnu.");
  if (item !== "pass" && !item.startsWith("st:") && !item.startsWith("co:")) throw new HttpsError("invalid-argument", "Contenu inconnu.");
  const { collections } = await loadMeta();
  const story = item.startsWith("st:") ? await loadStory(item.slice(3)) : null;
  if (item.startsWith("co:") && !collections[item.slice(3)]) throw new HttpsError("not-found", "Recueil introuvable.");
  const price = itemPrice(item, story, collections, cfg);
  if (price <= 0) throw new HttpsError("not-found", "Contenu déjà gratuit.");
  const now = Date.now();
  const today = dayKey(now);
  const adsRef = db.collection("AdRewards").doc(`${uid}_${today}`);
  const viewsRef = db.collection("ContesAds").doc(`${uid}_${today}`);
  const uRef = userRef(uid);
  const usersRef = db.collection("Users").doc(uid);

  // écritures partielles (fusion) : la jauge de l'élément est supprimée une fois le déblocage obtenu
  const grantPatch = (u: UserState): Record<string, unknown> => {
    const patch: Record<string, unknown> = { adsPaid: { [item]: FieldValue.delete() } };
    if (item === "pass") patch["passUntil"] = Math.max(now, u.passUntil) + cfg.passHours * 3600000;
    else patch["unlocked"] = { [item]: now };
    return patch;
  };

  const out = await db.runTransaction(async (tx) => {
    const [us, bal, ar, vr] = await Promise.all([tx.get(uRef), tx.get(usersRef), tx.get(adsRef), tx.get(viewsRef)]);
    const u = normalise(us.data() as Partial<UserState> | undefined);
    if (item !== "pass" && u.unlocked[item]) return { unlocked: true, already: true, spent: 0, adsPaid: 0, price };
    if (via === "free") {
      if (!item.startsWith("st:")) throw new HttpsError("failed-precondition", "Seuls les contes peuvent être offerts.");
      const used = u.free.day === today ? u.free.used : 0;
      if (used >= cfg.freePerDay) throw new HttpsError("resource-exhausted", "FREE_USED");
      tx.set(uRef, { ...grantPatch(u), free: { day: today, used: used + 1 } }, { merge: true });
      tx.set(db.collection("ContesStats").doc(today), { day: today, unlockFree: FieldValue.increment(1) }, { merge: true });
      return { unlocked: true, spent: 0, adsPaid: 0, price };
    }
    if (via === "coins") {
      const balance = num(bal.data()?.["giftCoinsBalance"], 0);
      if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });
      tx.update(usersRef, { giftCoinsBalance: FieldValue.increment(-price), totalGiftCoinsSpent: FieldValue.increment(price), updatedAt: now });
      const t = db.collection("TransactionSoldes").doc();
      tx.set(t, {
        id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
        description: `Contes : ${story?.title ?? (item === "pass" ? "Pass Veillée" : "Recueil")} — ${price} pièces`,
        montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "contes", purchaseRefId: item,
      });
      recordAppCommission(tx, "contes", price, now);
      tx.set(uRef, grantPatch(u), { merge: true });
      tx.set(db.collection("ContesStats").doc(today), { day: today, unlockCoins: FieldValue.increment(1), coinsSpent: FieldValue.increment(price) }, { merge: true });
      return { unlocked: true, spent: price, adsPaid: 0, price };
    }
    // via pubs : la jauge se remplit pub après pub
    const paid = u.adsPaid[item] ?? 0;
    let gain = 0;
    let used = 0;
    if (format === "rewarded") {
      const pending = num(ar.data()?.["pending"], 0);
      const each = Math.max(1, cfg.adValueCoins);
      const want = Math.ceil((price - paid) / each);
      used = Math.min(pending, want);
      if (used <= 0) throw new HttpsError("failed-precondition", "NO_ADS");
      gain = used * each;
      tx.set(adsRef, { pending: pending - used }, { merge: true });
    } else {
      const v = (vr.data() ?? {}) as { n?: number; lastAt?: number };
      if (num(v.n, 0) >= cfg.interstitialMaxPerDay) throw new HttpsError("resource-exhausted", "Limite de pubs du jour atteinte.");
      if (now - num(v.lastAt, 0) < cfg.interstitialGapSec * 1000) throw new HttpsError("resource-exhausted", "Trop rapide.");
      used = 1;
      gain = Math.max(1, cfg.interstitialValueCoins);
      tx.set(viewsRef, { userId: uid, day: today, n: num(v.n, 0) + 1, lastAt: now }, { merge: true });
    }
    const shown = Math.min(price, paid + gain);
    const unlocked = shown >= price;
    tx.set(uRef, unlocked ? grantPatch(u) : { adsPaid: { [item]: shown } }, { merge: true });
    tx.set(db.collection("AdRewardStats").doc(today), {
      day: today, claims: { contes: FieldValue.increment(unlocked ? 1 : 0) }, adsSpent: FieldValue.increment(used),
      ...(format === "interstitial" ? { contesInterstitials: FieldValue.increment(1) } : { contesRewarded: FieldValue.increment(used) }),
    }, { merge: true });
    tx.set(db.collection("ContesStats").doc(today), {
      day: today, ...(unlocked ? { unlockAds: FieldValue.increment(1) } : {}),
      ...(format === "interstitial" ? { adsInterstitial: FieldValue.increment(1) } : { adsRewarded: FieldValue.increment(used) }),
    }, { merge: true });
    return { unlocked, spent: 0, adsPaid: unlocked ? price : shown, price };
  });
  const u2 = await readUser(uid);
  return { ok: true, ...out, state: publicState(u2, cfg, Date.now()) };
});

/** Fin de lecture : le conte passe dans l'historique du lecteur. */
export const conteFinish = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = uidOf(request);
  const id = String(request.data?.id ?? "");
  if (!id) throw new HttpsError("invalid-argument", "Conte requis.");
  const now = Date.now();
  const u = await readUser(uid);
  const first = !u.done[id];
  await userRef(uid).set({ done: { [id]: now }, reads: { [id]: now } }, { merge: true });
  if (first) {
    const day = dayKey(now);
    bump(day, { finishes: 1 }).catch(() => undefined);
    db.collection("ContesStoryStats").doc(id).set({ id, finishes: FieldValue.increment(1) }, { merge: true }).catch(() => undefined);
  }
  return { ok: true };
});

const EVENTS = new Set(["feed_view", "feed_click", "feed_dismiss", "leave", "sound_off", "sound_on"]);
/** Mesures légères (carte du fil, page d'abandon, son). */
export const conteTrack = onCall({ timeoutSeconds: 10 }, async (request) => {
  uidOf(request);
  const ev = String(request.data?.event ?? "");
  if (!EVENTS.has(ev)) throw new HttpsError("invalid-argument", "Évènement inconnu.");
  const day = dayKey();
  const id = String(request.data?.id ?? "");
  if (ev === "leave" && id) {
    const page = Math.max(0, Math.min(40, Math.floor(num(request.data?.page, 0))));
    await db.collection("ContesStoryStats").doc(id).set({ id, drop: { [`p${page}`]: FieldValue.increment(1) } }, { merge: true });
    return { ok: true };
  }
  await bump(day, { [ev]: 1 });
  return { ok: true };
});

// ── Administration ──────────────────────────────────────────────────────────

async function assertAdmin(uid: string) {
  const me = await db.collection("Users").doc(uid).get();
  if (me.data()?.["role"] !== "ADM") throw new HttpsError("permission-denied", "Réservé aux admins.");
}

export const conteAdmin = onCall({ timeoutSeconds: 60, memory: "512MiB" }, async (request) => {
  await assertAdmin(uidOf(request));
  const now = Date.now();
  const today = dayKey(now);
  const cfg = await loadCfg();
  const [usersSnap, storiesSnap, storyStatsSnap, metaSnap] = await Promise.all([
    db.collection("ContesUsers").limit(10000).get(),
    db.collection("ContesStories").get(),
    db.collection("ContesStoryStats").limit(1500).get(),
    db.collection("ContesIndex").doc("meta").get(),
  ]);
  const titles: Record<string, { title: string; active: boolean; collectionId: string; kind: string }> = {};
  storiesSnap.docs.forEach((d) => { const s = d.data(); titles[d.id] = { title: String(s["title"] ?? d.id), active: s["active"] !== false, collectionId: String(s["collectionId"] ?? ""), kind: String(s["kind"] ?? "court") }; });

  const adFreeSnap = await db.collection("Users").where("modulesAdFreeUntil", ">", now).count().get();
  const adFreeActive = adFreeSnap.data().count;
  let readers = 0, activeToday = 0, active7 = 0, reads = 0, done = 0, passActive = 0;
  const lastReadCut7 = now - 6 * DAY;
  usersSnap.docs.forEach((d) => {
    const u = normalise(d.data() as Partial<UserState>);
    readers++;
    const times = Object.values(u.reads);
    reads += times.length;
    done += Object.keys(u.done).length;
    const last = times.length ? Math.max(...times) : 0;
    if (dayKey(last) === today) activeToday++;
    if (last >= lastReadCut7) active7++;
    if (u.passUntil > now) passActive++;
  });

  const keys: string[] = [];
  for (let k = 0; k < 7; k++) keys.push(dayKey(now - k * DAY));
  const [statDocs, commDocs] = await Promise.all([
    db.getAll(...keys.map((k) => db.collection("ContesStats").doc(k))),
    db.getAll(...keys.map((k) => db.collection("CommissionsDaily").doc(k))),
  ]);
  const t: Record<string, number> = {};
  const perDay: { day: string; opens: number; finishes: number }[] = [];
  statDocs.forEach((s, i) => {
    const d = s.data() ?? {};
    perDay.push({ day: keys[i], opens: num(d["opens"], 0), finishes: num(d["finishes"], 0) });
    Object.entries(d).forEach(([k, v]) => { if (typeof v === "number") t[k] = (t[k] ?? 0) + v; });
  });
  let coins7 = 0;
  commDocs.forEach((s) => { coins7 += num((s.data() ?? {})["contes"], 0); });

  const stats = storyStatsRows(storyStatsSnap, titles);
  const topOpened = [...stats].sort((a, b) => b.opens - a.opens).slice(0, 15);
  const topFinished = [...stats].sort((a, b) => b.finishes - a.finishes).slice(0, 10);
  const worstDrop = [...stats].filter((s) => s.opens >= 5).sort((a, b) => (a.finishes / a.opens) - (b.finishes / b.opens)).slice(0, 8);
  const collections = ((metaSnap.data()?.["collections"] ?? []) as { id: string; title: string; count: number }[]).map((c) => ({ id: c.id, title: c.title, count: c.count }));
  return {
    ok: true, readers, activeToday, active7, reads, done, passActive, adFreeActive,
    completionRate: reads ? Math.round((done * 100) / reads) : 0,
    week: {
      opens: t["opens"] ?? 0, finishes: t["finishes"] ?? 0, unlockCoins: t["unlockCoins"] ?? 0, unlockAds: t["unlockAds"] ?? 0, unlockFree: t["unlockFree"] ?? 0,
      adsRewarded: t["adsRewarded"] ?? 0, adsInterstitial: t["adsInterstitial"] ?? 0, coinsSpent: t["coinsSpent"] ?? 0,
      feedView: t["feed_view"] ?? 0, feedClick: t["feed_click"] ?? 0, feedDismiss: t["feed_dismiss"] ?? 0, soundOff: t["sound_off"] ?? 0, soundOn: t["sound_on"] ?? 0,
    },
    coins7, perDay: perDay.reverse(), topOpened, topFinished, worstDrop, collections,
    catalog: { stories: Object.keys(titles).length, active: Object.values(titles).filter((s) => s.active).length },
    config: cfg,
  };
});

function storyStatsRows(snap: FirebaseFirestore.QuerySnapshot, titles: Record<string, { title: string; collectionId: string }>) {
  return snap.docs.map((d) => {
    const s = d.data();
    const drop = (s["drop"] ?? {}) as Record<string, number>;
    const worstPage = Object.entries(drop).sort((a, b) => b[1] - a[1])[0];
    return {
      id: d.id, title: titles[d.id]?.title ?? d.id, opens: num(s["opens"], 0), finishes: num(s["finishes"], 0), lockedOpens: num(s["lockedOpens"], 0),
      dropPage: worstPage ? Number(worstPage[0].slice(1)) + 1 : 0,
    };
  });
}

/** Admin : activer/masquer un conte, le mettre à la une, changer son prix (met aussi à jour sa fiche dans l'index). */
export const conteAdminStory = onCall({ timeoutSeconds: 30 }, async (request) => {
  await assertAdmin(uidOf(request));
  const id = String(request.data?.id ?? "");
  const patch = (request.data?.patch ?? {}) as { active?: boolean; featured?: boolean; price?: number | null };
  if (!id) throw new HttpsError("invalid-argument", "Conte requis.");
  const ref = db.collection("ContesStories").doc(id);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Conte introuvable.");
  const chunk = num(snap.data()?.["chunk"], 0);
  const upd: Record<string, unknown> = {};
  if (typeof patch.active === "boolean") upd["active"] = patch.active;
  if (typeof patch.featured === "boolean") upd["featured"] = patch.featured;
  if (patch.price === null) upd["price"] = FieldValue.delete();
  else if (typeof patch.price === "number" && patch.price >= 0 && patch.price <= 500) upd["price"] = Math.round(patch.price);
  if (Object.keys(upd).length === 0) throw new HttpsError("invalid-argument", "Rien à changer.");
  await ref.set(upd, { merge: true });
  // fiche de l'index
  const idxRef = db.collection("ContesIndex").doc(`c${chunk}`);
  await db.runTransaction(async (tx) => {
    const s = await tx.get(idxRef);
    const cards = ((s.data()?.["cards"] ?? []) as Record<string, unknown>[]).map((c) => {
      if (c["id"] !== id) return c;
      const n = { ...c };
      if ("active" in upd) n["active"] = upd["active"];
      if ("featured" in upd) n["feat"] = upd["featured"];
      if ("price" in upd) { if (patch.price === null) delete n["pr"]; else n["pr"] = upd["price"]; }
      return n;
    });
    tx.set(idxRef, { cards }, { merge: true });
  });
  return { ok: true };
});
