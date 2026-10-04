import { FieldPath } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

// Lecture des abonnés (non exporté comme fonction Cloud) : voir follows.ts.
export const MAX_FOLLOWING = 5000;

export const followDocId = (creatorId: string, followerId: string) => `${creatorId}_${followerId}`;

/** Parcourt les abonnés d'un créateur par pages (identifiants des abonnés). */
export async function* followerIdPages(creatorId: string, pageSize = 500): AsyncGenerator<string[]> {
  const prefix = `${creatorId}_`;
  let last: string | undefined;
  for (;;) {
    let q = db.collection("Follows")
      .where(FieldPath.documentId(), ">=", prefix)
      .where(FieldPath.documentId(), "<", prefix + "")
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) return;
    yield snap.docs.map((d) => d.id.slice(prefix.length));
    if (snap.size < pageSize) return;
    last = snap.docs[snap.docs.length - 1].id;
  }
}

/**
 * Tous les abonnés d'un créateur. Repli sur l'ancienne liste si `Follows` est vide
 * (compte créé pendant la transition).
 */
export async function collectFollowerIds(creatorId: string, legacy: string[] = []): Promise<string[]> {
  const out: string[] = [];
  for await (const page of followerIdPages(creatorId)) out.push(...page);
  return out.length > 0 ? out : legacy;
}

