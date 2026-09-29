import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Migrations des noms : pseudos des comptes et noms des canaux.
 * Format : minuscules, mots séparés par un point (« Olivier_Bernard » → « olivier.bernard »,
 * « Mode Afro » → « mode.afro »). Même règle que lib/utils/pseudo_format.dart (normalizePseudo).
 *
 * Appel (administrateur uniquement, depuis la page admin), par lots — répéter avec `cursor` jusqu'à `done: true` :
 *   { action: "status" }                              → état enregistré
 *   { dryRun: true }                                  → simulation, rien n'est écrit (valeur par défaut)
 *   { dryRun: false, limit: 300, cursor? }            → applique un lot ; verrouillée une fois terminée
 *
 * Pseudos : Users.pseudo + collection Pseudo + creatorSnapshot.pseudo des posts.
 * Canaux  : Canaux.titre + collection CanalNames + canalSnapshot.titre des posts.
 * En cas de doublon après normalisation, le nom reçoit un numéro (olivier.bernard2) ; le premier (ordre des
 * identifiants) garde le nom sans numéro. Non modifiés : @mentions / #mentions déjà écrites dans d'anciens textes.
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

const MAX_POSTS_PER_ITEM = 500;

/** Suffixe stable à 4 chiffres tiré de l'identifiant. */
function digitsOf(id: string): string {
  let h = 0;
  for (const ch of id) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return String(1000 + (h % 9000));
}

/**
 * Nom de remplacement quand l'ancien ne contient rien de valable une fois nettoyé (emojis seuls, symboles…) :
 * prénom.nom, puis début de l'e-mail, sinon « afro1234 » (« canal1234 » pour un canal).
 */
function fallbackName(collection: string, doc: FirebaseFirestore.QueryDocumentSnapshot): string {
  const cands: string[] = [];
  if (collection === "Users") {
    cands.push(normalizePseudo(`${doc.get("prenom") ?? ""}.${doc.get("nom") ?? ""}`));
    cands.push(normalizePseudo(String(doc.get("email") ?? "").split("@")[0]));
  }
  for (const c of cands) if (c.length >= 3) return c.slice(0, 20);
  return `${collection === "Users" ? "afro" : "canal"}${digitsOf(doc.id)}`;
}

interface MigrationConfig {
  collection: string; // Users | Canaux
  field: string; // pseudo | titre
  namesCollection: string; // Pseudo | CanalNames
  statusDoc: string;
  postOwnerField: string; // user_id | canal_id
  postSnapshotField: string; // creatorSnapshot.pseudo | canalSnapshot.titre
  before: string;
  migratedAt: string;
}

function buildMigration(cfg: MigrationConfig) {
  return onCall({ timeoutSeconds: 540, memory: "512MiB" }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
    const me = await db.collection("Users").doc(uid).get();
    if (me.data()?.role !== "ADM") throw new HttpsError("permission-denied", "Réservé aux administrateurs.");

    const statusRef = db.collection("AppConfig").doc(cfg.statusDoc);
    const { dryRun = true, limit = 100, cursor, action } = (request.data ?? {}) as {
      dryRun?: boolean; limit?: number; cursor?: string; action?: string;
    };
    if (action === "status") return { status: (await statusRef.get()).data() ?? { status: "never" } };

    // Une seule exécution : une fois terminée, plus aucune application possible.
    const current = (await statusRef.get()).data();
    if (!dryRun && current?.status === "done") {
      throw new HttpsError("failed-precondition", "Cette migration a déjà été effectuée.");
    }
    const pageSize = Math.min(Math.max(Number(limit) || 100, 1), 300);

    // Noms déjà pris (forme normalisée) et documents de la collection des noms
    const taken = new Set<string>();
    const nameDocs = await db.collection(cfg.namesCollection).select("name").get();
    const nameDocByName = new Map<string, string>();
    nameDocs.forEach((d) => {
      const name = String(d.get("name") ?? "");
      nameDocByName.set(name, d.id);
      if (name === normalizePseudo(name)) taken.add(name);
    });

    let q = db.collection(cfg.collection).orderBy(FieldPath.documentId()).limit(pageSize);
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();

    type Change = { id: string; from: string; to: string; suffix: boolean; replaced?: boolean; postsLeft?: number };
    const changes: Change[] = [];
    const skipped: Array<{ id: string; pseudo: string; reason: string }> = [];

    for (const doc of page.docs) {
      const old = doc.get(cfg.field);
      if (typeof old !== "string" || !old) continue;
      let base = normalizePseudo(old);
      if (base === old) { taken.add(old); continue; }
      // Rien de valable après nettoyage (emojis seuls, symboles…) : nom de remplacement
      const replaced = base.length < 3;
      if (replaced) base = fallbackName(cfg.collection, doc);

      let target = base;
      let n = 2;
      while (taken.has(target)) target = `${base}${n++}`;
      taken.add(target);
      const change: Change = { id: doc.id, from: old, to: target, suffix: target !== base, ...(replaced ? { replaced: true } : {}) };

      if (!dryRun) {
        const batch = db.batch();
        batch.update(doc.ref, { [cfg.field]: target, [cfg.before]: old, [cfg.migratedAt]: Date.now() });
        const nameDocId = nameDocByName.get(old);
        if (nameDocId) batch.update(db.collection(cfg.namesCollection).doc(nameDocId), { name: target });
        else batch.set(db.collection(cfg.namesCollection).doc(), { name: target });
        await batch.commit();

        // Copies dans les posts (snapshot affiché avant le chargement du profil / du canal)
        const posts = await db.collection("Posts").where(cfg.postOwnerField, "==", doc.id).limit(MAX_POSTS_PER_ITEM + 1).get();
        let pb = db.batch();
        let inBatch = 0;
        for (const p of posts.docs.slice(0, MAX_POSTS_PER_ITEM)) {
          if (p.get(cfg.postSnapshotField) === undefined) continue;
          pb.update(p.ref, { [cfg.postSnapshotField]: target });
          if (++inBatch === 400) { await pb.commit(); pb = db.batch(); inBatch = 0; }
        }
        if (inBatch > 0) await pb.commit();
        if (posts.size > MAX_POSTS_PER_ITEM) change.postsLeft = posts.size - MAX_POSTS_PER_ITEM;
      }
      changes.push(change);
    }

    const last = page.docs.length ? page.docs[page.docs.length - 1].id : null;
    const finished = page.size < pageSize;
    if (!dryRun) {
      await statusRef.set({
        status: finished ? "done" : "running",
        startedAt: current?.startedAt ?? Date.now(),
        updatedAt: Date.now(),
        ...(finished ? { finishedAt: Date.now() } : {}),
        changed: FieldValue.increment(changes.length),
        suffixed: FieldValue.increment(changes.filter((c) => c.suffix).length),
        skipped: FieldValue.increment(skipped.length),
        replaced: FieldValue.increment(changes.filter((c) => c.replaced).length),
        lastCursor: finished ? null : last,
      }, { merge: true });
    }
    return {
      dryRun,
      scanned: page.size,
      changed: changes.length,
      skipped: skipped.length,
      replaced: changes.filter((c) => c.replaced).length,
      done: finished,
      nextCursor: finished ? null : last,
      changes: changes.slice(0, 200),
      skippedList: skipped.slice(0, 100),
    };
  });
}

export const migratePseudos = buildMigration({
  collection: "Users", field: "pseudo", namesCollection: "Pseudo", statusDoc: "pseudoMigration",
  postOwnerField: "user_id", postSnapshotField: "creatorSnapshot.pseudo",
  before: "pseudo_before", migratedAt: "pseudo_migrated_at",
});

export const migrateCanalNames = buildMigration({
  collection: "Canaux", field: "titre", namesCollection: "CanalNames", statusDoc: "canalMigration",
  postOwnerField: "canal_id", postSnapshotField: "canalSnapshot.titre",
  before: "titre_before", migratedAt: "titre_migrated_at",
});
