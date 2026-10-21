import axios from "axios";
import { FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { db } from "./firebase";
import { ONESIGNAL_ID_REGEX, chunk, isDeadTokenCode, isQuotaError, stringifyData, tokensOf } from "./push_logic";
import { Budget, PushCategory, PushPrefs, consume, decide } from "../notifications/policy_logic";

/**
 * Envoi des notifications push, en trois niveaux :
 *   1. FCM (Firebase Cloud Messaging) : canal principal, gratuit et sans quota. Les jetons sont dans `Users/{id}.fcmTokens`
 *      (enregistrés par l'application) ; les jetons devenus invalides sont retirés du profil à chaque envoi.
 *   2. OneSignal : seulement pour les personnes sans jeton FCM (application pas encore mise à jour) ou dont l'envoi FCM a échoué.
 *      Protégé par un coupe-circuit : dès que OneSignal répond « quota épuisé », on cesse de l'appeler pendant quelques heures
 *      et les administrateurs sont prévenus (notification dans l'application + e-mail).
 *   3. La notification enregistrée dans Firestore (liste de l'application, relevée par WorkManager) reste le dernier filet.
 * Ne lève jamais d'erreur : un échec d'envoi ne doit pas faire échouer le traitement qui l'a déclenché.
 */

const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";
const FCM_BATCH = 500;
const ONESIGNAL_BATCH = 2000;
const BLOCK_MS = 6 * 60 * 60 * 1000;
const STATE_CACHE_MS = 60 * 1000;
/**
 * Canal Android créé par l'application (importance haute, son Afrolook). Un canal garde son son pour toujours : le son a été ajouté avec la
 * version 2 du canal. Doit rester identique à PushService.channelId (application) et au manifest.
 */
export const ANDROID_CHANNEL_ID = "afrolook_push_v2";
/** Fichier du son Afrolook (android/app/src/main/res/raw/afrolook_chime.wav ; iPhone : afrolook_chime.wav dans le projet Xcode). */
export const NOTIFICATION_SOUND = "afrolook_chime";

export interface PushPayload {
  title: string;
  message: string;
  /**
   * Image d'APERÇU du contenu (photo du post, miniature de vidéo, pochette de musique, média de chronique) : montrée en grande image.
   * Pour un contenu sans aperçu (texte, message, rappel), on n'en met pas : la notification reste en texte.
   */
  image?: string;
  /** Photo de l'expéditeur (OneSignal seulement : icône ; FCM n'affiche pas d'icône personnalisée). */
  avatar?: string;
  /** Données transmises à l'application pour ouvrir le bon écran (type_notif, post_id, post_type, chat_id, send_user_id…). */
  data?: Record<string, unknown>;
}

/** Une personne à prévenir : par identifiant de profil, par identifiant OneSignal, ou avec ses jetons déjà connus. */
export interface PushTarget {
  userId?: string;
  oneSignalId?: string;
  fcmTokens?: string[];
  /** Infos du profil déjà lues par l'appelant (évite de relire le profil pour appliquer les règles). */
  prefs?: PushPrefs;
  tz?: number;
  lastActive?: number;
}

export interface PushDetail {
  userId?: string;
  /** Canal par lequel la notification est partie : FCM, OneSignal, ou aucun. */
  channel: "FCM" | "OneSignal" | "aucun";
  /** Nombre d'appareils enregistrés pour FCM. */
  tokens: number;
  /** Identifiant OneSignal présent dans le profil. */
  hasOneSignalId: boolean;
}

export interface PushResult {
  fcm: number;
  oneSignal: number;
  unreachable: number;
  /** Détail par personne (seulement si demandé : page de test des notifications). */
  details?: PushDetail[];
}

interface Recipient {
  key: string;
  userId?: string;
  oneSignalId: string;
  tokens: string[];
  prefs?: PushPrefs;
  tz?: number;
  lastActive?: number;
}

interface OneSignalConfig {
  appId: string;
  apiKey: string;
}

// ─── Résolution des destinataires ────────────────────────────────────────────────────────────────

function toRecipient(userId: string | undefined, data: Record<string, unknown> | undefined, fallbackOs = ""): Recipient {
  const os = String(data?.["oneIgnalUserid"] ?? fallbackOs ?? "").trim();
  const tz = Number(data?.["tzOffsetMin"]);
  return {
    key: userId ?? `os:${os}`, userId, oneSignalId: os, tokens: tokensOf(data),
    prefs: (data?.["pushPrefs"] as PushPrefs | undefined) ?? undefined,
    tz: Number.isFinite(tz) ? tz : undefined,
    lastActive: Number(data?.["last_time_active"]) || 0,
  };
}

async function resolveRecipients(targets: PushTarget[]): Promise<Recipient[]> {
  const out = new Map<string, Recipient>();
  const byUser = new Set<string>();
  const byOs = new Set<string>();

  for (const t of targets) {
    const os = (t.oneSignalId ?? "").trim();
    if (t.fcmTokens) {
      const r: Recipient = { key: t.userId ?? `os:${os}`, userId: t.userId, oneSignalId: os, tokens: tokensOf({ fcmTokens: t.fcmTokens }), prefs: t.prefs, tz: t.tz, lastActive: t.lastActive };
      if (!out.has(r.key)) out.set(r.key, r);
    } else if (t.userId) {
      byUser.add(t.userId);
    } else if (os.length > 5) {
      byOs.add(os);
    }
  }

  // Profils connus par leur identifiant
  for (const ids of chunk([...byUser].filter((id) => !out.has(id)), 300)) {
    const snaps = await db.getAll(...ids.map((id) => db.collection("Users").doc(id)));
    for (const s of snaps) if (s.exists) out.set(s.id, toRecipient(s.id, s.data()));
  }

  // Profils connus seulement par leur identifiant OneSignal : recherche par lots de 30 (limite de l'opérateur « in »)
  const osLists = chunk([...byOs], 30);
  for (const group of chunk(osLists, 10)) {
    const snaps = await Promise.all(group.map((ids) => db.collection("Users").where("oneIgnalUserid", "in", ids).get()));
    const found = new Set<string>();
    snaps.forEach((snap) => snap.docs.forEach((d) => {
      const r = toRecipient(d.id, d.data());
      out.set(r.key, r);
      found.add(r.oneSignalId);
    }));
    for (const ids of group) {
      for (const os of ids) if (!found.has(os)) out.set(`os:${os}`, { key: `os:${os}`, oneSignalId: os, tokens: [] });
    }
  }
  return [...out.values()];
}

// ─── FCM ─────────────────────────────────────────────────────────────────────────────────────────

/** Envoie par FCM. Retourne les clés des destinataires joints au moins sur un appareil. */
async function sendFcm(recipients: Recipient[], payload: PushPayload): Promise<{ delivered: Set<string>; sent: number }> {
  const delivered = new Set<string>();
  const entries: Array<{ token: string; r: Recipient }> = [];
  for (const r of recipients) for (const token of r.tokens) entries.push({ token, r });
  if (!entries.length) return { delivered, sent: 0 };

  const data = stringifyData(payload.data);
  // Image de la notification (photo de l'expéditeur, logo…) : seulement une adresse https valide, sinon la notification part sans image
  const imageUrl = /^https:\/\/\S{6,1000}$/.test(payload.image ?? "") ? payload.image : undefined;
  const dead = new Map<string, string[]>(); // userId → jetons à supprimer
  let sent = 0;

  for (const group of chunk(entries, FCM_BATCH)) {
    try {
      const res = await getMessaging().sendEachForMulticast({
        tokens: group.map((e) => e.token),
        notification: { title: payload.title, body: payload.message, ...(imageUrl ? { imageUrl } : {}) },
        data,
        android: { priority: "high", ttl: 24 * 60 * 60 * 1000, notification: { channelId: ANDROID_CHANNEL_ID, sound: NOTIFICATION_SOUND, ...(imageUrl ? { imageUrl } : {}) } },
        // « mutable-content » + image : permet à l'extension de service iPhone (ios/NOTIFICATION_IMAGES_IOS.md) de télécharger l'image d'aperçu
        apns: { headers: { "apns-priority": "10" }, payload: { aps: { sound: NOTIFICATION_SOUND + ".wav", "mutable-content": 1 } }, ...(imageUrl ? { fcmOptions: { imageUrl } } : {}) },
      });
      res.responses.forEach((resp, i) => {
        const { token, r } = group[i];
        if (resp.success) {
          sent++;
          delivered.add(r.key);
        } else if (isDeadTokenCode(resp.error?.code) && r.userId) {
          dead.set(r.userId, [...(dead.get(r.userId) ?? []), token]);
        } else {
          console.warn("[push] FCM non remis", resp.error?.code, r.userId ?? r.oneSignalId);
        }
      });
    } catch (e) {
      console.error("[push] FCM lot en échec", e);
    }
  }

  // Ménage : jetons invalides retirés des profils
  await Promise.all([...dead.entries()].map(([userId, tokens]) =>
    db.collection("Users").doc(userId).update({ fcmTokens: FieldValue.arrayRemove(...tokens) }).catch(() => undefined)));
  return { delivered, sent };
}

// ─── OneSignal (secours, avec coupe-circuit) ─────────────────────────────────────────────────────

let stateCache: { at: number; blockedUntil: number } | null = null;

async function oneSignalBlockedUntil(): Promise<number> {
  if (stateCache && Date.now() - stateCache.at < STATE_CACHE_MS) return stateCache.blockedUntil;
  let blockedUntil = 0;
  try {
    const snap = await db.collection("AppConfig").doc("push_state").get();
    blockedUntil = Number(snap.data()?.["oneSignalBlockedUntil"] ?? 0) || 0;
  } catch (e) {
    console.warn("[push] état du coupe-circuit illisible", e);
  }
  stateCache = { at: Date.now(), blockedUntil };
  return blockedUntil;
}

/** Ouvre le coupe-circuit OneSignal (quota épuisé) et prévient les administrateurs, une seule fois par période de blocage. */
async function openCircuit(reason: string): Promise<void> {
  const already = (await oneSignalBlockedUntil()) > Date.now();
  const until = Date.now() + BLOCK_MS;
  stateCache = { at: Date.now(), blockedUntil: until };
  try {
    await db.collection("AppConfig").doc("push_state").set({ oneSignalBlockedUntil: until, reason: reason.slice(0, 300), updatedAt: Date.now() }, { merge: true });
  } catch (e) {
    console.error("[push] coupe-circuit non enregistré", e);
  }
  if (already) return;
  try {
    const { notifyAdminsAll } = await import("./user_notify.js"); // import différé : user_notify dépend lui-même de ce module
    await notifyAdminsAll({
      title: "Notifications push : OneSignal bloqué",
      message: "Le quota OneSignal est épuisé. Les personnes qui n'ont pas mis l'application à jour ne reçoivent plus de notifications ; les autres passent par Firebase (FCM).",
      email: {
        subject: "Afrolook — quota OneSignal épuisé",
        heading: "Quota OneSignal épuisé",
        icon: "🔕",
        intro: "OneSignal refuse maintenant les envois. Les notifications passent par Firebase Cloud Messaging pour toutes les personnes ayant la dernière version de l'application ; les autres n'en reçoivent plus tant que le quota n'est pas rétabli.",
        rows: [["Réponse de OneSignal", reason.slice(0, 200)], ["Nouvel essai automatique", new Date(until).toISOString()]],
        outro: "Pour réduire le nombre de personnes concernées : publier la mise à jour de l'application. Pour rétablir OneSignal : relever le plan ou attendre le renouvellement du quota.",
      },
    });
  } catch (e) {
    console.error("[push] alerte administrateurs non envoyée", e);
  }
}

async function loadOneSignalConfig(): Promise<OneSignalConfig | null> {
  try {
    const cfg = (await db.collection("AppData").doc(APP_DATA_DOC).get()).data() ?? {};
    if (cfg["one_signal_app_id"] && cfg["one_signal_api_key"]) return { appId: String(cfg["one_signal_app_id"]), apiKey: String(cfg["one_signal_api_key"]) };
  } catch (e) {
    console.warn("[push] configuration OneSignal illisible", e);
  }
  return null;
}

async function sendOneSignal(ids: string[], payload: PushPayload, cfgIn?: OneSignalConfig, fallbackImage = ""): Promise<number> {
  const valid = [...new Set(ids.filter((id) => ONESIGNAL_ID_REGEX.test(id)))];
  if (!valid.length) return 0;
  if ((await oneSignalBlockedUntil()) > Date.now()) {
    console.log(`[push] OneSignal en pause (quota) : ${valid.length} personne(s) non jointes par ce canal`);
    return 0;
  }
  const cfg = cfgIn ?? (await loadOneSignalConfig());
  if (!cfg) return 0;

  let sent = 0;
  for (const group of chunk(valid, ONESIGNAL_BATCH)) {
    try {
      await axios.post("https://onesignal.com/api/v1/notifications", {
        app_id: cfg.appId,
        contents: { en: payload.message },
        include_player_ids: group,
        headings: { en: payload.title },
        large_icon: payload.avatar || fallbackImage,
        ...(payload.image ? { big_picture: payload.image } : {}),
        android_accent_color: "FFD700",
        data: payload.data ?? {},
      }, { headers: { "Content-Type": "application/json", Authorization: `Basic ${cfg.apiKey}` }, timeout: 30000 });
      sent += group.length;
    } catch (e) {
      const err = e as { response?: { status?: number; data?: unknown }; message?: string };
      const status = err.response?.status;
      console.error("[push] OneSignal en échec", status, JSON.stringify(err.response?.data ?? err.message ?? "").slice(0, 300));
      if (isQuotaError(status, err.response?.data)) {
        await openCircuit(`HTTP ${status} ${JSON.stringify(err.response?.data ?? "")}`);
        break;
      }
    }
  }
  return sent;
}

// ─── Point d'entrée ──────────────────────────────────────────────────────────────────────────────

// ─── Règles unifiées (budget quotidien, heures calmes, préférences) ──────────────────────────────

/** Ne garde que les personnes à qui cette catégorie de notification peut être envoyée maintenant. Les messages directs passent toujours. */
async function applyPolicy(recipients: Recipient[], category: PushCategory): Promise<{ allowed: Recipient[]; budgets: Map<string, Partial<Budget>>; blocked: Record<string, number> }> {
  const budgets = new Map<string, Partial<Budget>>();
  const blocked: Record<string, number> = {};
  if (category === "direct") return { allowed: recipients, budgets, blocked };
  const ids = recipients.map((r) => r.userId).filter((x): x is string => !!x);
  for (const group of chunk(ids, 300)) {
    const snaps = await db.getAll(...group.map((id) => db.collection("PushBudget").doc(id)));
    snaps.forEach((sn) => { if (sn.exists) budgets.set(sn.id, sn.data() as Partial<Budget>); });
  }
  const now = Date.now();
  const allowed = recipients.filter((r) => {
    if (!r.userId) return true; // identifiant OneSignal inconnu du serveur : pas de profil, donc pas de règle à appliquer
    const d = decide(category, { nowMs: now, tzMin: r.tz, prefs: r.prefs, budget: budgets.get(r.userId), lastActiveMs: r.lastActive });
    if (!d.allow) blocked[d.reason ?? "autre"] = (blocked[d.reason ?? "autre"] ?? 0) + 1;
    return d.allow;
  });
  return { allowed, budgets, blocked };
}

/** Compte l'envoi dans le budget du jour de chaque personne jointe, et dans les statistiques du jour (PushStats). */
async function recordSent(reached: Recipient[], budgets: Map<string, Partial<Budget>>, category: PushCategory, blocked: Record<string, number>): Promise<void> {
  try {
    const now = Date.now();
    if (category !== "direct") {
      for (const group of chunk(reached.filter((r) => r.userId), 400)) {
        const batch = db.batch();
        for (const r of group) batch.set(db.collection("PushBudget").doc(r.userId!), consume(category, budgets.get(r.userId!), now, r.tz));
        await batch.commit();
      }
    }
    const inc: Record<string, FieldValue> = { ["sent_" + category]: FieldValue.increment(reached.length) };
    for (const [k, v] of Object.entries(blocked)) inc["blocked_" + k] = FieldValue.increment(v);
    await db.collection("PushStats").doc(new Date(now).toISOString().slice(0, 10).replace(/-/g, "")).set(inc, { merge: true });
  } catch (e) {
    console.warn("[push] budget / statistiques non enregistrés", e);
  }
}

/**
 * Envoie une notification push à ces personnes : FCM d'abord, OneSignal pour celles qui n'ont pas de jeton (ou dont l'envoi FCM a échoué).
 * `category` : direct (toujours envoyée), social ou reminder (heures calmes, préférences et budget quotidien : voir notifications/policy_logic.ts).
 * `oneSignal` : identifiants de l'API OneSignal, lus dans AppData si absents.
 */
export async function deliverPush(
  targets: PushTarget[],
  payload: PushPayload,
  oneSignal?: OneSignalConfig,
  withDetails = false,
  category: PushCategory = "direct",
): Promise<PushResult> {
  const result: PushResult = { fcm: 0, oneSignal: 0, unreachable: 0 };
  try {
    if (!targets.length) return result;
    const resolved = await resolveRecipients(targets);
    const { allowed: recipients, budgets, blocked } = await applyPolicy(resolved, category);
    const withTokens = recipients.filter((r) => r.tokens.length > 0);

    const { delivered, sent } = await sendFcm(withTokens, payload);
    result.fcm = sent;

    // Repli OneSignal : pas de jeton FCM, ou aucun appareil joint par FCM
    const fallbackIds = recipients.filter((r) => !delivered.has(r.key) && r.oneSignalId.length > 5).map((r) => r.oneSignalId);
    if (fallbackIds.length) result.oneSignal = await sendOneSignal(fallbackIds, payload, oneSignal);

    result.unreachable = recipients.length - delivered.size - result.oneSignal;
    const viaOneSignal = new Set(result.oneSignal > 0 ? fallbackIds : []);
    if (withDetails) {
      result.details = resolved.map((r) => ({
        userId: r.userId,
        channel: delivered.has(r.key) ? "FCM" : viaOneSignal.has(r.oneSignalId) ? "OneSignal" : "aucun",
        tokens: r.tokens.length,
        hasOneSignalId: r.oneSignalId.length > 5,
      }));
    }
    const reached = recipients.filter((r) => delivered.has(r.key) || viaOneSignal.has(r.oneSignalId));
    await recordSent(reached, budgets, category, blocked);
    console.log(`[push] ${category} · FCM: ${delivered.size} personne(s) · OneSignal: ${result.oneSignal} · non jointes: ${Math.max(0, result.unreachable)} · bloquées par les règles: ${resolved.length - recipients.length}`);
  } catch (e) {
    console.error("[push] deliverPush", e);
  }
  return result;
}
