import { FieldValue, Transaction } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { APP_DATA_DOC } from "../posts/defiShared";

/**
 * Règles de partage communes à tous les paiements en pièces (barème validé le 2026-09-27) :
 * - créateur : 70 % en Pièces gagnées (convertibles) ;
 * - parrain de celui qui paie : 2,5 % ; parrain du créateur : 2,5 % — pris sur la part de l'app ;
 * - pas de parrainage sur les likes (ni les commentaires) : 2,5 % de 2 pièces = 0 ;
 * - le reste revient à l'app et est enregistré par source et par jour (page admin « Commissions »).
 */
export const CREATOR_SHARE = 0.7;
export const SPONSOR_SHARE = 0.025;

/** Sources de gain de l'app (clés de CommissionsDaily/{jour}). */
export type CommissionSource =
  | "likes" | "commentaires" | "cadeaux" | "cadeaux_live" | "defi"
  | "groupes" | "canaux" | "lives_prives" | "participation_live"
  | "premium" | "gold" | "compte_officiel" | "pubs_boosts" | "contenus" | "abonnement_entreprise";

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

/** Parrain d'un utilisateur (champ code_parrain → Users.code_parrainage), hors lui-même. */
export async function sponsorOf(userId: string | undefined): Promise<string | undefined> {
  if (!userId) return undefined;
  const u = await db.collection("Users").doc(userId).get();
  const code = u.data()?.code_parrain as string | undefined;
  if (!code) return undefined;
  const q = await db.collection("Users").where("code_parrainage", "==", code).limit(1).get();
  const id = q.docs[0]?.id;
  return id && id !== userId ? id : undefined;
}

export interface SponsorShare { id: string; coins: number; role: string }

/** Commissions de parrainage (2,5 % chacune) pour un paiement de `coins` pièces. À appeler hors transaction. */
export async function resolveSponsors(payerId: string, creatorId: string | undefined, coins: number): Promise<SponsorShare[]> {
  const [payerSponsor, creatorSponsor] = await Promise.all([sponsorOf(payerId), sponsorOf(creatorId)]);
  const out: SponsorShare[] = [];
  const c = Math.floor(coins * SPONSOR_SHARE);
  if (c <= 0) return out;
  if (payerSponsor) out.push({ id: payerSponsor, coins: c, role: "filleul acheteur" });
  if (creatorSponsor) out.push({ id: creatorSponsor, coins: c, role: "filleul créateur" });
  return out;
}

/** Crédite les parrains (Pièces gagnées) et écrit leurs transactions. */
export function creditSponsors(tx: Transaction, sponsors: SponsorShare[], label: string, now: number, extra: Record<string, unknown> = {}) {
  for (const s of sponsors) {
    if (s.coins <= 0) continue;
    tx.update(db.collection("Users").doc(s.id), {
      giftCoinsBalance: FieldValue.increment(s.coins),
      totalCoinsEarnedFromSponsorship: FieldValue.increment(s.coins),
    });
    const ref = db.collection("TransactionSoldes").doc();
    tx.set(ref, {
      id: ref.id,
      user_id: s.id,
      type: "GAIN_PIECES",
      statut: "VALIDER",
      description: `Commission de parrainage (${s.role}) — ${label} — ${s.coins} pièces`,
      montant: s.coins,
      frais: 0,
      montant_total: s.coins,
      methode_paiement: "commission_parrainage",
      createdAt: now,
      updatedAt: now,
      ...extra,
    });
  }
}

/** Jour (UTC, = heure de Lomé) au format AAAA-MM-JJ. */
export function dayKey(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

/** Enregistre le gain de l'app : AppData.solde_gain_pieces + CommissionsDaily/{jour}.{source}. */
export function recordAppCommission(tx: Transaction, source: CommissionSource, coins: number, now: number) {
  if (coins <= 0) return;
  tx.update(db.collection("AppData").doc(APP_DATA_DOC), {
    solde_gain_pieces: FieldValue.increment(coins),
  });
  tx.set(db.collection("CommissionsDaily").doc(dayKey(now)), {
    date: dayKey(now),
    [source]: FieldValue.increment(coins),
    total: FieldValue.increment(coins),
    updatedAt: now,
  }, { merge: true });
}

export { num };
