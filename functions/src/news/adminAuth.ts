import { HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";

/** Rôles administrateurs (même liste que partout dans le serveur). */
export const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];

/** Vérifie que l'appelant est connecté et administrateur ; retourne son identifiant. */
export async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const role = String((await db.collection("Users").doc(uid).get()).data()?.["role"] ?? "");
  if (!ADMIN_ROLES.includes(role)) throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  return uid;
}
