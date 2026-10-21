import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { deliverPush, PushTarget } from "../shared/push";
import { chunk } from "../shared/push_logic";
import {
  Budget, SLOTS_MIN, ReminderKind, budgetForToday, chooseReminder, daysInactive, decide, localDay, reminderGapMs, typeNotifFor, tzForSlot,
} from "./policy_logic";
import { TIPS, TipVars, fmt, hashId, langOf, reminderText, tipText, topicIndex } from "./tips_library";

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
      const groups = new Map<string, { kind: ReminderKind; typeNotif: string; title: string; body: string; targets: PushTarget[] }>();
      for (const d of snap.docs) {
        const u = d.data();
        const lastActive = Number(u["last_time_active"]) || 0;
        const budget = budgets.get(d.id);
        const prefs = u["pushPrefs"] as { reminders?: boolean; activity?: boolean } | undefined;
        if (!decide("reminder", { nowMs, tzMin: tz, prefs, budget, lastActiveMs: lastActive }).allow) continue;

        const days = daysInactive(nowMs, lastActive);
        const gap = reminderGapMs(days);
        if (gap === Infinity) continue; // 90 jours sans retour : on arrête
        const lastReminder = budgetForToday(budget, localDay(nowMs, tz)).lastReminderAt;
        if (lastReminder && nowMs - lastReminder < gap) continue;

        const unseen = unseenOf(u["newPostsByCreator"]);
        const dayIndex = Math.floor((nowMs + tz * 60000) / 86400000);
        const kind = chooseReminder({ slot, dayIndex, streak: 0, streakDoneToday: true, unseenPosts: unseen, daysInactive: days, tipsEnabled });
        const lang = langOf(u["appLang"]);
        let copy = reminderText(kind, lang, dayIndex + slot, unseen);
        let typeNotif = typeNotifFor(kind);
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
        const key = `${typeNotif}|${copy.title}|${copy.body}`;
        const tokens = Array.isArray(u["fcmTokens"]) ? (u["fcmTokens"] as string[]) : [];
        if (!tokens.length) continue;
        const g = groups.get(key) ?? { kind, typeNotif, title: copy.title, body: copy.body, targets: [] };
        g.targets.push({ userId: d.id, fcmTokens: tokens, prefs, tz, lastActive });
        groups.set(key, g);
      }

      for (const g of groups.values()) {
        picked += g.targets.length;
        kinds[g.kind] = (kinds[g.kind] ?? 0) + g.targets.length;
        await deliverPush(g.targets, {
          title: g.title,
          message: g.body,
          data: { type_notif: g.typeNotif, post_id: "", post_type: "", chat_id: "", send_user_id: "" },
        }, undefined, false, "reminder");
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
