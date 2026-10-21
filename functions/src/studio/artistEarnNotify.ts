import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../shared/firebase";
import { deliverPush } from "../shared/push";
import { previewFromSound } from "../shared/preview";
import { EARN_TEXT, Lang, fmt, langOf } from "../notifications/tips_library";

/**
 * Alerte de gain d'un artiste : à chaque vente d'un de ses titres ou utilisation de son son dans un post (transaction « GAIN_PIECES »
 * créée par musicBuy / chargeArtistSound), l'artiste reçoit une notification (application + push) qui ouvre son Espace artiste.
 * Pour ne pas le submerger, une alerte au plus toutes les 30 minutes : les gains survenus entre-temps sont regroupés dans la suivante.
 */
export const EARN_GAP_MS = 30 * 60 * 1000;
const KINDS: Record<string, "sale" | "use"> = { musique_achat: "sale", studio_son_artiste: "use" };

export interface EarnState { coins: number; count: number; lastAt: number; soundId: string; title: string; kind: "sale" | "use" }
export interface EarnSend { coins: number; count: number; soundId: string; title: string; kind: "sale" | "use" }

/** Ajoute un gain à l'état de l'artiste et dit s'il faut envoyer l'alerte maintenant (sinon le gain attend la prochaine). */
export function foldEarning(prev: Partial<EarnState> | undefined, gain: { coins: number; soundId: string; title: string; kind: "sale" | "use" }, now: number, gapMs = EARN_GAP_MS): { next: EarnState; send: EarnSend | null } {
  const coins = (prev?.coins ?? 0) + gain.coins;
  const count = (prev?.count ?? 0) + 1;
  const lastAt = prev?.lastAt ?? 0;
  const merged: EarnState = { coins, count, lastAt, soundId: gain.soundId, title: gain.title, kind: gain.kind };
  if (now - lastAt < gapMs) return { next: merged, send: null };
  return { next: { coins: 0, count: 0, lastAt: now, soundId: gain.soundId, title: gain.title, kind: gain.kind }, send: { coins, count, soundId: gain.soundId, title: gain.title, kind: gain.kind } };
}

export function earnMessage(lang: Lang, s: EarnSend): { title: string; body: string } {
  const t = EARN_TEXT[lang];
  const pattern = s.count > 1 ? t.many : s.kind === "sale" ? t.sale : t.use;
  return { title: t.title, body: pattern.replace("{title}", s.title).replace("{coins}", fmt(s.coins)).replace("{n}", String(s.count)) };
}

export const notifyArtistOnEarning = onDocumentCreated(
  { document: "TransactionSoldes/{id}", timeoutSeconds: 60, memory: "256MiB", maxInstances: 5 },
  async (event) => {
    const t = event.data?.data();
    if (!t || t["type"] !== "GAIN_PIECES") return;
    const kind = KINDS[String(t["purchaseKind"] ?? "")];
    const artistId = String(t["user_id"] ?? "");
    const soundId = String(t["purchaseRefId"] ?? "");
    const coins = Math.round(Number(t["montant"]) || 0);
    if (!kind || !artistId || !soundId || coins <= 0) return;
    try {
      const soundSnap = await db.collection("artist_sounds").doc(soundId).get();
      const sound = soundSnap.data() ?? {};
      const title = String(sound["title"] ?? "").trim().slice(0, 60) || "—";
      const stateRef = db.collection("ArtistEarnPush").doc(artistId);
      const send = await db.runTransaction(async (tx) => {
        const cur = (await tx.get(stateRef)).data() as Partial<EarnState> | undefined;
        const r = foldEarning(cur, { coins, soundId, title, kind }, Date.now());
        tx.set(stateRef, r.next);
        return r.send;
      });
      if (!send) return;
      const lang = langOf((await db.collection("Users").doc(artistId).get()).data()?.["appLang"]);
      const msg = earnMessage(lang, send);
      const now = Date.now() * 1000;
      const ref = db.collection("Notifications").doc();
      await ref.set({
        id: ref.id, titre: msg.title, description: msg.body, type: "COMPTE_OFFICIEL", post_data_type: "MY_SOUND",
        user_id: artistId, receiver_id: artistId, post_id: soundId, is_open: false, users_id_view: [], status: "VALIDE",
        created_at: now, updated_at: now, createdAt: now, updatedAt: now,
      });
      // « direct » : un gain est toujours notifié (hors budget des rappels), au plus une alerte par 30 minutes
      await deliverPush([{ userId: artistId }], {
        title: msg.title, message: msg.body, image: previewFromSound(sound),
        data: { type_notif: "RAPPEL_ARTISTE", sound_id: soundId, send_user_id: "", post_id: "", post_type: "", chat_id: "" },
      }, undefined, false, "direct");
    } catch (e) {
      console.error("[gain artiste] alerte non envoyée", e);
    }
  },
);
