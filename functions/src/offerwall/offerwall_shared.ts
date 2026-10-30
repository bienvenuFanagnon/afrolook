import { getAuth } from "firebase-admin/auth";
import { db } from "../shared/firebase";
import { OfferwallConfig, UserFacts, readOfferwallConfig } from "./offerwall_logic";

/** Aides communes au retour des régies et à la libération des pièces (aucun secret ici : voir tapjoyCallback.ts). */
export const MAX_LEN = 128;
export const str = (v: unknown): string => (typeof v === "string" ? v : Array.isArray(v) && typeof v[0] === "string" ? v[0] : "");

export async function loadConfig(): Promise<OfferwallConfig> {
  return readOfferwallConfig((await db.collection("AppConfig").doc("offerwall").get().catch(() => undefined))?.data());
}

/** Éléments du compte utiles aux règles (e-mail vérifié lu auprès de Firebase Auth, jamais déduit du profil modifiable). */
export async function userFacts(uid: string, data: FirebaseFirestore.DocumentData | undefined): Promise<UserFacts> {
  if (!data) return { exists: false, deleted: false, pendingDeletion: false, createdAt: 0, emailVerified: false, blockedFromOffers: false };
  let emailVerified = false;
  try { emailVerified = (await getAuth().getUser(uid)).emailVerified === true; } catch { emailVerified = false; }
  const created = Number(data["createdAt"]) || 0;
  return {
    exists: true,
    deleted: data["deleted"] === true,
    pendingDeletion: data["accountStatus"] === "PENDING_DELETION",
    createdAt: created > 1e14 ? Math.floor(created / 1000) : created, // certains documents anciens sont en microsecondes
    emailVerified,
    blockedFromOffers: data["offerwallBlocked"] === true,
  };
}

