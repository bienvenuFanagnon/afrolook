import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { deliverPush, PushTarget } from "../shared/push";
import { chunk } from "../shared/push_logic";
import { previewFromPost } from "../shared/preview";
import {
  Budget, SLOTS_MIN, isGoldActive, ReminderKind, budgetForToday, chooseReminder, daysInactive, decide, localDay, reminderGapMs, typeNotifFor, tzForSlot,
} from "./policy_logic";
import { NewsPlan, NewsPushSource, FLASH_MIN_SCORE } from "../news/newsPush";
import { readPipelineConfig } from "../news/pipeline";
import { AD_LABEL, NEW_CREATOR_BODY, NEW_CREATOR_LABEL, TIPS, TipVars, fmt, hashId, langOf, reminderText, tipText, topicIndex } from "./tips_library";

/**
 * Rappels programmés pour faire revenir les utilisateurs, même sans aucune action sur leur compte.
 *
 * Trois créneaux par jour, à l'heure locale de chaque personne : 8 h 30, 13 h 00 et 19 h 30. Le déclencheur passe toutes les 30 minutes ; à chaque
 * passage, pour chaque créneau, on retrouve les personnes dont l'heure locale est justement celle du créneau (fuseau `tzOffsetMin`, enregistré par
 * l'application avec le jeton FCM : `pushReady`), puis pour chacune on choisit UN contenu (quiz, étude, conte, nouveaux posts, retour) :
 *  - règles communes : budget quotidien, heures calmes, préférences, pas de rappel si la personne vient d'utiliser l'application (policy_logic.ts) ;
 *  - paliers pour les inactifs : tous les jours jusqu'à 14 jours, un jour sur deux jusqu'à 30, chaque semaine jusqu'à 90, puis on arrête ;
 *  - un clic ouvre directement la bonne page (type_notif RAPPEL_QUIZ / RAPPEL_ETUDE / RAPPEL_CONTE / RAPPEL_FEED / RAPPEL_RETOUR).
 * Les rappels de série existants (streakReminder*) restent gérés à part, mais passent désormais par les mêmes règles.
 * Notifications pédagogiques (monétisation, parrainage, lives, canaux, commentaire, musique…) : au créneau de midi, 4 jours sur 7, seulement si
 * `AppConfig/push.tipsEnabled` vaut true (le temps de relire les textes). Tous les textes suivent la langue choisie (`Users.appLang`).
 * Ces rappels ne sont PAS enregistrés dans la liste des notifications de l'application : la personne n'a rien à y retrouver.
 * Quiz, étude et contes n'ont pas d'image d'aperçu dans les données : ces rappels partent en texte (une couverture serait montrée automatiquement).
 */
const PAGE = 500;
const MAX_PAGES = 20;

/** Somme des nouveaux posts non vus (compteurs par créateur maintenus par le serveur). */
function unseenOf(map: unknown): number {
  if (!map || typeof map !== "object") return 0;
  return Object.values(map as Record<string, unknown>).reduce<number>((s, v) => s + (typeof v === "number" && v > 0 ? v : 0), 0);
}

interface Sponsor { id: string; postId: string; postType: string; title: string; body: string; image: string }

/** Pubs Afrolook actives que l'administrateur a autorisées en notification (Advertisements.pushEnabled), dans la limite de leur plafond d'envois. */
async function loadSponsors(nowMs: number): Promise<Sponsor[]> {
  const out: Sponsor[] = [];
  try {
    const snap = await db.collection("Advertisements").where("pushEnabled", "==", true).where("status", "==", "active").limit(10).get();
    for (const d of snap.docs) {
      const a = d.data();
      const end = Number(a["endDate"]) || 0;
      if ((end && end < nowMs) || Number(a["pushSent"] ?? 0) >= Number(a["pushLimit"] ?? 5000)) continue;
      const postId = String(a["postId"] ?? "");
      if (!postId) continue;
      const post = (await db.collection("Posts").doc(postId).get()).data();
      if (!post) continue;
      const text = String(post["description"] ?? "").replace(/\s+/g, " ").trim();
      out.push({ id: d.id, postId, postType: String(post["dataType"] ?? ""), title: text.slice(0, 50) || "…", body: text.slice(0, 110) || "…", image: previewFromPost(post) });
    }
  } catch (e) {
    console.warn("[rappels] pubs sponsorisées illisibles", e);
  }
  return out;
}

interface PromoCreator { id: string; pseudo: string; postId: string; postType: string; text: string; image: string; interests: string[]; countries: string[] }

/** Seuils identiques à ceux du fil (DiscoveryBoostService) : compte de moins de 60 jours, moins de 20 abonnés, un post récent (7 jours). */
const PROMO_AGE_DAYS = 60;
const PROMO_MAX_FOLLOWERS = 20;
const PROMO_POST_DAYS = 7;
/** Envois par créateur et par jour au plus : une promotion reste équitable (réglable : AppConfig/push.creatorPromoDailyCap). */
const PROMO_DAILY_CAP = 300;
/** Une promotion de créateur par personne tous les 40 h au plus. */
const PROMO_USER_GAP_MS = 40 * 3600 * 1000;
let promoCache: { at: number; list: PromoCreator[] } | null = null;

const toMs = (v: unknown): number => { const n = Number(v) || 0; return n > 1e14 ? Math.round(n / 1000) : n; };

/** Nouveaux créateurs à faire découvrir : même définition que le boost du fil, un post par créateur, avec son aperçu. Gardé 60 minutes. */
async function loadPromoCreators(nowMs: number): Promise<PromoCreator[]> {
  if (promoCache && nowMs - promoCache.at < 60 * 60 * 1000) return promoCache.list;
  const out: PromoCreator[] = [];
  try {
    const sinceUs = (nowMs - PROMO_POST_DAYS * 86400000) * 1000;
    const posts = await db.collection("Posts").where("created_at", ">", sinceUs).orderBy("created_at", "desc").limit(300).get();
    const latest = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
    for (const d of posts.docs) {
      const x = d.data();
      const uid = String(x["user_id"] ?? "");
      if (!uid || latest.has(uid) || String(x["type"] ?? "") !== "POST") continue;
      const status = x["status"];
      if (status !== undefined && status !== "VALIDE") continue;
      latest.set(uid, d);
    }
    const ids = [...latest.keys()];
    for (const group of chunk(ids, 10)) {
      const users = await db.collection("Users").where(FieldPath.documentId(), "in", group).get();
      for (const uSnap of users.docs) {
        const u = uSnap.data();
        const created = toMs(u["createdAt"]);
        if (!created || nowMs - created > PROMO_AGE_DAYS * 86400000) continue;
        if (Number(u["abonnes"] ?? 0) >= PROMO_MAX_FOLLOWERS) continue;
        if (u["accountStatus"] !== undefined && u["accountStatus"] !== "active" && u["accountStatus"] !== "ACTIVE") continue;
        const post = latest.get(uSnap.id)!.data();
        const image = previewFromPost(post);
        const text = String(post["description"] ?? "").replace(/\s+/g, " ").trim();
        if (!image && text.length < 15) continue; // rien à montrer : pas de promotion
        out.push({
          id: uSnap.id, pseudo: String(u["pseudo"] ?? "").slice(0, 30), postId: latest.get(uSnap.id)!.id, postType: String(post["dataType"] ?? ""), text, image,
          interests: Array.isArray(post["postInterests"]) ? (post["postInterests"] as string[]) : [],
          countries: Array.isArray(post["availableCountries"]) ? (post["availableCountries"] as string[]) : [],
        });
      }
    }
  } catch (e) {
    console.warn("[rappels] nouveaux créateurs illisibles", e);
  }
  promoCache = { at: nowMs, list: out.filter((c) => c.pseudo) };
  return promoCache.list;
}

/** Le meilleur nouveau créateur à proposer à cette personne : jamais elle-même ni un créateur qu'elle suit, pays compatible, quota du créateur non atteint ; priorité aux centres d'intérêt communs. */
function pickCreatorPromo(u: Record<string, unknown>, uid: string, list: PromoCreator[], counts: Record<string, number>, cap: number): PromoCreator | undefined {
  const following = new Set(Array.isArray(u["followingIds"]) ? (u["followingIds"] as string[]) : []);
  const country = String((u["countryData"] as Record<string, unknown> | undefined)?.["countryCode"] ?? "").toUpperCase();
  const mine = new Set(Array.isArray(u["interests"]) ? (u["interests"] as string[]) : []);
  let best: PromoCreator | undefined;
  let bestScore = -1;
  for (const c of list) {
    if (c.id === uid || following.has(c.id) || (counts[c.id] ?? 0) >= cap) continue;
    if (country && c.countries.length && !c.countries.includes("ALL") && !c.countries.includes(country)) continue;
    const score = c.interests.filter((i) => mine.has(i)).length * 2 + (hashId(c.id + uid) % 5) / 10; // intérêts communs d'abord, puis une répartition équitable
    if (score > bestScore) { bestScore = score; best = c; }
  }
  return best;
}

/** Variables des textes d'estimation : le barème réel (config/monetization), jamais un chiffre écrit dans le code. */
async function loadTipVars(): Promise<TipVars> {
  let rate = 1.0;
  try {
    const c = (await db.collection("config").doc("monetization").get()).data();
    if (typeof c?.["baseViewRate"] === "number" && c["baseViewRate"] > 0) rate = c["baseViewRate"];
  } catch (e) {
    console.warn("[rappels] barème illisible, valeur par défaut", e);
  }
  return { views: fmt(1000), amount: fmt(rate * 1000), min: fmt(1000) };
}

export async function runReengagementTick(nowMs: number = Date.now()): Promise<Record<string, number>> {
  const kinds: Record<string, number> = {};
  let scanned = 0, picked = 0;
  const tipsEnabled = (await db.collection("AppConfig").doc("push").get().catch(() => undefined))?.data()?.["tipsEnabled"] === true;
  const tipVars = tipsEnabled ? await loadTipVars() : { views: "", amount: "", min: "" };
  let sponsors: Sponsor[] | null = null; // chargées une seule fois, seulement au créneau du soir
  const pushCfg = (await db.collection("AppConfig").doc("push").get().catch(() => undefined))?.data() ?? {};
  const creatorPromoOn = pushCfg["creatorPromoEnabled"] !== false; // activée par défaut ; false pour la couper
  const promoCap = Math.max(20, Math.min(2000, Number(pushCfg["creatorPromoDailyCap"]) || PROMO_DAILY_CAP));
  let promoCreators: PromoCreator[] | null = null;
  const dayKey = new Date(nowMs).toISOString().slice(0, 10).replace(/-/g, "");
  let promoCounts: Record<string, number> | null = null;
  const promoSent: Record<string, number> = {};
  const promoRecipients: string[] = [];
  const sponsorSent: Record<string, number> = {};
  // actualités : journal du matin, semaine du lundi, alerte « À la une » (désactivées tant que AppConfig/push.newsPushEnabled n'est pas true)
  const newsFlashOn = pushCfg["newsFlashEnabled"] !== false;
  const newsSource = pushCfg["newsPushEnabled"] === true
    ? new NewsPushSource(nowMs, readPipelineConfig((await db.collection("AppConfig").doc("news").get().catch(() => undefined))?.data()).countries, Number(pushCfg["newsFlashMinScore"]) || FLASH_MIN_SCORE)
    : null;

  for (let slot = 0; slot < SLOTS_MIN.length; slot++) {
    const tz = tzForSlot(nowMs, SLOTS_MIN[slot]);
    if (Math.abs(tz) > 720) continue;
    let last: string | undefined;
    for (let page = 0; page < MAX_PAGES; page++) {
      let q = db.collection("Users").where("pushReady", "==", true).where("tzOffsetMin", "==", tz).orderBy(FieldPath.documentId()).limit(PAGE);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      last = snap.docs[snap.docs.length - 1].id;
      scanned += snap.size;

      const budgets = new Map<string, Partial<Budget>>();
      for (const ids of chunk(snap.docs.map((d) => d.id), 300)) {
        const bs = await db.getAll(...ids.map((id) => db.collection("PushBudget").doc(id)));
        bs.forEach((b) => { if (b.exists) budgets.set(b.id, b.data() as Partial<Budget>); });
      }

      // une notification par contenu (même titre et même texte) : un seul envoi pour tout le groupe
      const socialNudged: Record<string, string[]> = {}; // réseau → personnes à qui on vient de proposer de nous suivre
      const newsStamp: Array<{ id: string; storyId: string }> = []; // personnes à qui une actualité part : date et identifiant, pour ne pas la renvoyer
      if (slot === 2 && sponsors === null) sponsors = await loadSponsors(nowMs);
      if (slot === 0 && creatorPromoOn && promoCreators === null) {
        promoCreators = await loadPromoCreators(nowMs);
        promoCounts = ((await db.collection("CreatorPromoDaily").doc(dayKey).get().catch(() => undefined))?.data()?.["counts"] ?? {}) as Record<string, number>;
      }
      const groups = new Map<string, { kind: ReminderKind; typeNotif: string; title: string; body: string; image?: string; extra?: Record<string, string>; adId?: string; targets: PushTarget[] }>();
      for (const d of snap.docs) {
        const u = d.data();
        const lastActive = Number(u["last_time_active"]) || 0;
        const budget = budgets.get(d.id);
        const prefs = u["pushPrefs"] as { reminders?: boolean; activity?: boolean; news?: boolean } | undefined;
        const remindersOn = prefs?.reminders !== false;
        const newsOn = prefs?.news !== false;
        // « Rappels et idées » coupé : la personne peut garder les actualités (heures calmes, budget et paliers s'appliquent toujours)
        if (!decide("reminder", { nowMs, tzMin: tz, prefs: remindersOn ? prefs : { ...prefs, reminders: true }, budget, lastActiveMs: lastActive }).allow) continue;

        const days = daysInactive(nowMs, lastActive);
        const gap = reminderGapMs(days);
        if (gap === Infinity) continue; // 90 jours sans retour : on arrête
        const lastReminder = budgetForToday(budget, localDay(nowMs, tz)).lastReminderAt;
        if (lastReminder && nowMs - lastReminder < gap) continue;

        const unseen = unseenOf(u["newPostsByCreator"]);
        const dayIndex = Math.floor((nowMs + tz * 60000) / 86400000);
        const sponsorAvailable = slot === 2 && (sponsors?.length ?? 0) > 0 && !isGoldActive(u, nowMs);
        const promo = slot === 0 && promoCreators && promoCounts && nowMs - (Number(u["creatorPromoAt"]) || 0) > PROMO_USER_GAP_MS
          ? pickCreatorPromo(u, d.id, promoCreators, promoCounts, promoCap) : undefined;
        const lang = langOf(u["appLang"]);
        const newsPlan: NewsPlan | undefined = newsSource && newsOn ? await newsSource.plan(u, slot, tz, lang, newsFlashOn) : undefined;
        if (!remindersOn && !newsPlan) continue;
        const kind: ReminderKind = !remindersOn && newsPlan ? newsPlan.kind
          : chooseReminder({ slot, dayIndex, streak: 0, streakDoneToday: true, unseenPosts: unseen, daysInactive: days, tipsEnabled, sponsorAvailable, creatorPromoAvailable: !!promo, newsKind: newsPlan?.kind });
        let copy = reminderText(kind, lang, dayIndex + slot, unseen);
        let typeNotif = typeNotifFor(kind);
        let image: string | undefined;
        let extra: Record<string, string> | undefined;
        let adId: string | undefined;
        if (kind === "tip") {
          // Priorité : (1) nous suivre sur la chaîne WhatsApp, Facebook, TikTok (un réseau à la fois, tous les 14 jours tant que la personne n'y a pas été
          // dirigée : Users.<réseau>Followed est écrit par l'application) ; (2) une NOUVEAUTÉ tous les 3 jours ; (3) la rotation des autres sujets.
          const due = ["whatsapp", "facebook", "tiktok"].find((n) => u[n + "Followed"] !== true && nowMs - (Number(u[n + "NudgeAt"]) || 0) > 14 * 86400000);
          const news = TIPS.filter((t) => t.topic.startsWith("news"));
          let tip = TIPS[topicIndex(dayIndex, hashId(d.id))];
          if (due) {
            tip = TIPS.find((t) => t.topic === due)!;
            (socialNudged[due] = socialNudged[due] ?? []).push(d.id);
          } else if (news.length && dayIndex % 3 === 0) {
            tip = news[(Math.floor(dayIndex / 3) + hashId(d.id)) % news.length];
          } else if (["whatsapp", "facebook", "tiktok"].includes(tip.topic)) {
            // la rotation ne propose pas un réseau déjà suivi : sujet suivant
            while (["whatsapp", "facebook", "tiktok"].includes(tip.topic)) tip = TIPS[(TIPS.indexOf(tip) + 1) % TIPS.length];
          }
          copy = tipText(tip, lang, tipVars);
          typeNotif = tip.target;
        }
        // Pub Afrolook sponsorisée : le texte et l'image sont ceux de la pub (mention « Pub » dans la langue de la personne) ; un clic ouvre le post de la pub
        if (kind === "sponsor" && sponsors && sponsors.length) {
          const ad = sponsors[(dayIndex + hashId(d.id)) % sponsors.length];
          copy = { title: `📢 ${AD_LABEL[lang]} · ${ad.title}`, body: ad.body };
          typeNotif = typeNotifFor("sponsor");
          image = ad.image || undefined;
          extra = { post_id: ad.postId, post_type: ad.postType, ad_id: ad.id };
          adId = ad.id;
        }
        // Nouveau créateur : son pseudo, un extrait de son post (ou un texte de repli), l'aperçu de son post ; un clic ouvre ce post (on peut s'abonner depuis la page du post)
        if (kind === "creator" && promo && promoCounts) {
          copy = { title: `🌟 ${NEW_CREATOR_LABEL[lang]} · @${promo.pseudo}`, body: promo.text ? promo.text.slice(0, 100) : NEW_CREATOR_BODY[lang] };
          typeNotif = typeNotifFor("creator");
          image = promo.image || undefined;
          extra = { post_id: promo.postId, post_type: promo.postType, send_user_id: promo.id };
          promoCounts[promo.id] = (promoCounts[promo.id] ?? 0) + 1;
          promoSent[promo.id] = (promoSent[promo.id] ?? 0) + 1;
          promoRecipients.push(d.id);
        }
        // actualité : texte, aperçu et clic viennent de l'article (ou du résumé de la semaine)
        let isNews = false;
        if ((kind === "news" || kind === "newsflash" || kind === "newsweek") && newsPlan) {
          const { type_notif: tn, ...rest } = newsPlan.data;
          copy = { title: newsPlan.title, body: newsPlan.body };
          typeNotif = tn;
          image = newsPlan.image;
          extra = rest;
          isNews = true;
        }
        const key = `${typeNotif}|${copy.title}|${copy.body}`;
        const tokens = Array.isArray(u["fcmTokens"]) ? (u["fcmTokens"] as string[]) : [];
        if (!tokens.length) continue;
        if (isNews && newsPlan) newsStamp.push({ id: d.id, storyId: newsPlan.storyId });
        const g = groups.get(key) ?? { kind, typeNotif, title: copy.title, body: copy.body, image, extra, adId, targets: [] };
        // une actualité part avec l'interrupteur « Actualités » (déjà vérifié) et non avec « Rappels et idées »
        g.targets.push({ userId: d.id, fcmTokens: tokens, prefs: isNews ? { ...prefs, reminders: true } : prefs, tz, lastActive });
        groups.set(key, g);
      }

      for (const g of groups.values()) {
        picked += g.targets.length;
        kinds[g.kind] = (kinds[g.kind] ?? 0) + g.targets.length;
        await deliverPush(g.targets, {
          title: g.title,
          message: g.body,
          image: g.image,
          data: { type_notif: g.typeNotif, post_id: "", post_type: "", chat_id: "", send_user_id: "", ...(g.extra ?? {}) },
        }, undefined, false, "reminder");
        if (g.adId) sponsorSent[g.adId] = (sponsorSent[g.adId] ?? 0) + g.targets.length;
      }
      for (const ids of chunk(newsStamp, 400)) {
        const batch = db.batch();
        ids.forEach((s) => batch.set(db.collection("Users").doc(s.id), { newsAt: nowMs, newsLastId: s.storyId }, { merge: true }));
        await batch.commit().catch((e) => console.warn("[rappels] actualité non enregistrée", e));
      }
      for (const [network, all] of Object.entries(socialNudged)) {
        for (const ids of chunk(all, 400)) {
          const batch = db.batch();
          ids.forEach((id) => batch.set(db.collection("Users").doc(id), { [network + "NudgeAt"]: nowMs }, { merge: true }));
          await batch.commit().catch((e) => console.warn("[rappels] invitation réseau non enregistrée", network, e));
        }
      }
      if (snap.size < PAGE) break;
    }
  }

  // promotions de créateurs : quota du jour par créateur et date de la dernière promotion reçue par chaque personne
  if (Object.keys(promoSent).length) {
    const counts: Record<string, FieldValue> = {};
    for (const [id, n] of Object.entries(promoSent)) counts[id] = FieldValue.increment(n);
    await db.collection("CreatorPromoDaily").doc(dayKey).set({ day: dayKey, counts }, { merge: true }).catch((e) => console.warn("[rappels] quota créateurs non enregistré", e));
    for (const ids of chunk(promoRecipients, 400)) {
      const batch = db.batch();
      ids.forEach((id) => batch.set(db.collection("Users").doc(id), { creatorPromoAt: nowMs }, { merge: true }));
      await batch.commit().catch((e) => console.warn("[rappels] date de promotion non enregistrée", e));
    }
  }

  // nombre d'envois de chaque pub sponsorisée (plafond Advertisements.pushLimit)
  for (const [adId, n] of Object.entries(sponsorSent)) {
    await db.collection("Advertisements").doc(adId).update({ pushSent: FieldValue.increment(n) }).catch((e) => console.warn("[rappels] compteur de pub non mis à jour", adId, e));
  }

  if (picked > 0) {
    const inc: Record<string, FieldValue> = {};
    for (const [k, v] of Object.entries(kinds)) inc["reminder_" + k] = FieldValue.increment(v);
    await db.collection("PushStats").doc(new Date(nowMs).toISOString().slice(0, 10).replace(/-/g, "")).set(inc, { merge: true }).catch(() => undefined);
  }
  console.log(`[rappels] ${scanned} personne(s) examinées · ${picked} rappel(s) choisis`, kinds);
  return kinds;
}

export const reengagementTick = onSchedule(
  { schedule: "every 30 minutes", timeZone: "UTC", memory: "512MiB", timeoutSeconds: 300, maxInstances: 1 },
  async () => { await runReengagementTick(); },
);
