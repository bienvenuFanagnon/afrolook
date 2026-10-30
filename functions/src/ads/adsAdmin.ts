import type { CallableRequest } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";

/**
 * Qui est administrateur de la régie Afrolook Ads : rôle administrateur ET adresse autorisée (pour le moment, seulement ces deux comptes).
 * Module commun à l'administration de la régie et aux campagnes « Partage et gagne » (les campagnes de l'administration sont offertes : aucun paiement).
 */
export const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];
export const ADMIN_EMAILS = ["jorbienvenu@gmail.com", "officiel.afrolook@gmail.com"];

export const isRegieAdminRequest = (request: CallableRequest, role: unknown): boolean =>
  ADMIN_ROLES.includes(String(role ?? "")) && ADMIN_EMAILS.includes(String(request.auth?.token?.["email"] ?? "").toLowerCase());

/** Le compte connecté est-il administrateur de la régie ? (jamais d'erreur : faux si inconnu) */
export async function isRegieAdminAccount(request: CallableRequest): Promise<boolean> {
  const uid = request.auth?.uid;
  if (!uid) return false;
  try { return isRegieAdminRequest(request, (await db.collection("Users").doc(uid).get()).data()?.["role"]); } catch { return false; }
}
