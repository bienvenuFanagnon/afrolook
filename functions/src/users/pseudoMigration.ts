import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldPath } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Migration des pseudos : minuscules, mots séparés par un point (« Olivier_Bernard » → « olivier.bernard »).
 * Même règle que lib/utils/pseudo_format.dart (normalizePseudo).
 *
 * Appel (administrateur uniquement), par lots — répéter avec `cursor` jusqu'à `done: true` :
 *   migratePseudos({ dryRun: true })                 → simulation, rien n'est écrit (valeur par défaut)
 *   migratePseudos({ dryRun: false, limit: 100 })    → applique un lot
 *   migratePseudos({ dryRun: false, cursor: "<nextCursor>" })
 *
 * Écrit : Users.pseudo (+ pseudo_before, pseudo_migrated_at), document de la collection Pseudo, et
 * creatorSnapshot.pseudo des posts de l'utilisateur (500 max par utilisateur, le reste est signalé).
 * En cas de doublon après normalisation, le pseudo reçoit un numéro (olivier.bernard2) ; le premier
 * arrivé (ordre des identifiants) garde le pseudo sans numéro.
 * Non modifiés : @mentions déjà écrites dans d'anciens textes, codes de parrainage existants.
 */

const FROM = "àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ";
const TO = ["a", "a", "a", "a", "a", "a", "c", "e", "e", "e", "e", "i", "i", "i", "i", "n", "o", "o", "o", "o", "o", "u", "u", "u", "u", "y", "y", "oe", "ae"];

export function normalizePseudo(input: string): string {
  let s = "";
  for (const ch of input.trim().toLowerCase()) {
    const i = FROM.indexOf(ch);
    s += i >= 0 ? TO[i] : ch;
  }
  s = s.replace(/[\s_-]+/g, ".").replace(/[^a-z0-9.]/g, "").replace(/\.{2,}/g, ".");
  return s.replace(/^\.+|\.+$/g, "");
}

const MAX_POSTS_PER_USER = 500;

export const migratePseudos = onCall({ timeoutSeconds: 540, memory: "512MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const me = await db.collection("Users").doc(uid).get();
  if (me.data()?.role !== "ADM") throw new HttpsError("permission-denied", "Réservé aux administrateurs.");

  const { dryRun = true, limit = 100, cursor } = (request.data ?? {}) as {
    dryRun?: boolean; limit?: number; cursor?: string;
  };
  const pageSize = Math.min(Math.max(Number(limit) || 100, 1), 300);

  // Pseudos déjà pris (forme normalisée) : Pseudo + pseudos des comptes déjà au bon format
  const taken = new Set<string>();
  const pseudoDocs = await db.collection("Pseudo").select("name").get();
  const pseudoDocByName = new Map<string, string>();
  pseudoDocs.forEach((d) => {
    const name = String(d.get("name") ?? "");
    pseudoDocByName.set(name, d.id);
    if (name === normalizePseudo(name)) taken.add(name);
  });

  let q = db.collection("Users").orderBy(FieldPath.documentId()).limit(pageSize);
  if (cursor) q = q.startAfter(cursor);
  const page = await q.get();

  const changes: Array<{ id: string; from: string; to: string; suffix: boolean; postsLeft?: number }> = [];
  const skipped: Array<{ id: string; pseudo: string; reason: string }> = [];

  for (const doc of page.docs) {
    const old = doc.get("pseudo");
    if (typeof old !== "string" || !old) continue;
    const base = normalizePseudo(old);
    if (base === old) { taken.add(old); continue; }
    if (base.length < 3) { skipped.push({ id: doc.id, pseudo: old, reason: "trop court après normalisation" }); continue; }

    let target = base;
    let n = 2;
    while (taken.has(target)) target = `${base}${n++}`;
    taken.add(target);
    const change: { id: string; from: string; to: string; suffix: boolean; postsLeft?: number } =
      { id: doc.id, from: old, to: target, suffix: target !== base };

    if (!dryRun) {
      const now = Date.now();
      const batch = db.batch();
      batch.update(doc.ref, { pseudo: target, pseudo_before: old, pseudo_migrated_at: now });
      const pseudoDocId = pseudoDocByName.get(old);
      if (pseudoDocId) batch.update(db.collection("Pseudo").doc(pseudoDocId), { name: target });
      else batch.set(db.collection("Pseudo").doc(), { name: target });
      await batch.commit();

      // Copies dans les posts (snapshot affiché avant le chargement du profil)
      const posts = await db.collection("Posts").where("user_id", "==", doc.id).limit(MAX_POSTS_PER_USER + 1).get();
      let count = 0;
      let pb = db.batch();
      let inBatch = 0;
      for (const p of posts.docs.slice(0, MAX_POSTS_PER_USER)) {
        if (p.get("creatorSnapshot.pseudo") === undefined) continue;
        pb.update(p.ref, { "creatorSnapshot.pseudo": target });
        count++;
        if (++inBatch === 400) { await pb.commit(); pb = db.batch(); inBatch = 0; }
      }
      if (inBatch > 0) await pb.commit();
      if (posts.size > MAX_POSTS_PER_USER) change.postsLeft = posts.size - MAX_POSTS_PER_USER;
      void count;
    }
    changes.push(change);
  }

  const last = page.docs.length ? page.docs[page.docs.length - 1].id : null;
  return {
    dryRun,
    scanned: page.size,
    changed: changes.length,
    skipped: skipped.length,
    done: page.size < pageSize,
    nextCursor: page.size < pageSize ? null : last,
    changes: changes.slice(0, 200),
    skippedList: skipped.slice(0, 100),
  };
});
