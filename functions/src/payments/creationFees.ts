import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../shared/firebase";
import { FieldValue } from "firebase-admin/firestore";
import { num } from "./coinShares";

/**
 * Création de canaux et de groupes : le PREMIER est gratuit, chaque suivant coûte 500 pièces.
 *
 * - `creationQuote` : prix à payer pour créer le prochain canal / groupe (0 = gratuit ou déjà payé).
 * - `payWithCoins` (kind canal_create / group_create) débite 500 pièces et crédite Users.canalCreationCredits /
 *   groupCreationCredits (+1) : c'est le « ticket » de création.
 * - À la création du document, le serveur consomme le ticket ; sans ticket, le canal / groupe supplémentaire
 *   est supprimé (l'app demande le paiement AVANT, donc cela ne sert que de garde-fou).
 * Les administrateurs (role ADM) ne paient jamais.
 */
export const CREATION_PRICE_COINS = 500;

export type CreationType = "canal" | "group";
const TYPES: Record<CreationType, { collection: string; ownerField: string; creditField: string }> = {
  canal: { collection: "Canaux", ownerField: "userId", creditField: "canalCreationCredits" },
  group: { collection: "GroupChats", ownerField: "owner_id", creditField: "groupCreationCredits" },
};

export function creditFieldOf(type: CreationType): string { return TYPES[type].creditField; }

/** Combien de canaux / groupes possède déjà l'utilisateur (hors document en cours de création). */
async function ownedCount(type: CreationType, uid: string, excludeId?: string): Promise<number> {
  const t = TYPES[type];
  const snap = await db.collection(t.collection).where(t.ownerField, "==", uid).limit(5).get();
  return snap.docs.filter((d) => d.id !== excludeId).length;
}

export async function creationCost(type: CreationType, uid: string, excludeId?: string):
  Promise<{ cost: number; owned: number; credits: number }> {
  const user = await db.collection("Users").doc(uid).get();
  const u = user.data();
  if (!u) throw new HttpsError("not-found", "Compte introuvable.");
  const owned = await ownedCount(type, uid, excludeId);
  const credits = num(u[TYPES[type].creditField]);
  if (u["role"] === "ADM" || owned === 0 || credits > 0) return { cost: 0, owned, credits };
  return { cost: CREATION_PRICE_COINS, owned, credits };
}

function parseType(v: unknown): CreationType {
  if (v === "canal" || v === "group") return v;
  throw new HttpsError("invalid-argument", "Type inconnu.");
}

export const creationQuote = onCall({ timeoutSeconds: 15, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const type = parseType((request.data as { type?: string })?.type);
  const q = await creationCost(type, uid);
  return { cost: q.cost, owned: q.owned, hasTicket: q.credits > 0 };
});

/** Création d'un canal / groupe supplémentaire : consomme le ticket payé, sinon supprime le document. */
async function chargeOrRefuse(type: CreationType, ref: FirebaseFirestore.DocumentReference, ownerId: string | undefined) {
  if (!ownerId) return;
  const userRef = db.collection("Users").doc(ownerId);
  const q = await creationCost(type, ownerId, ref.id);
  if (q.owned === 0) return; // premier : gratuit
  const admin = (await userRef.get()).data()?.["role"] === "ADM";
  if (admin) return;
  const ok = await db.runTransaction(async (tx) => {
    const d = await tx.get(userRef);
    const credits = num(d.data()?.[TYPES[type].creditField]);
    if (credits <= 0) return false;
    tx.update(userRef, { [TYPES[type].creditField]: FieldValue.increment(-1) });
    return true;
  });
  if (!ok) await ref.delete();
}

export const onCanalCreatedCharge = onDocumentCreated("Canaux/{id}", async (event) => {
  await chargeOrRefuse("canal", event.data!.ref, event.data?.get("userId") as string | undefined);
});
export const onGroupCreatedCharge = onDocumentCreated("GroupChats/{id}", async (event) => {
  await chargeOrRefuse("group", event.data!.ref, event.data?.get("owner_id") as string | undefined);
});
