/**
 * Migration des pseudos : « Olivier_Bernard » → « olivier.bernard ».
 * Même règle que lib/utils/pseudo_format.dart et functions/src/users/pseudoMigration.ts.
 *
 *   Simulation (rien n'est écrit, écrit un rapport JSON) :
 *     node functions/scripts/migrate_pseudos.js
 *   Application :
 *     node functions/scripts/migrate_pseudos.js --apply
 *
 * Nécessite : firebase login / gcloud auth application-default login (droits d'écriture Firestore).
 * FAIRE UNE SAUVEGARDE DE FIRESTORE AVANT --apply (gcloud firestore export).
 *
 * Règles :
 * - minuscules, espaces / _ / - → « . », accents retirés, seuls a-z 0-9 « . » ; pas de point au bord ni doublé ;
 * - doublon après normalisation : le premier (ordre des identifiants) garde le pseudo, les suivants reçoivent
 *   un numéro (olivier.bernard2) ;
 * - trop court (< 3) : ignoré et listé ; trop long (> 20) : converti mais listé « à raccourcir » — le compte devra
 *   choisir un pseudo plus court à sa prochaine modification ;
 * - écrit : Users.pseudo (+ pseudo_before, pseudo_migrated_at), collection Pseudo, creatorSnapshot.pseudo des posts.
 * - reprise possible : un compte déjà au bon format est ignoré.
 */
const fs = require("fs");
const admin = require("firebase-admin");

const PROJECT_ID = "afrolooki";
const APPLY = process.argv.includes("--apply");
const MAX_LEN = 20;
const MIN_LEN = 3;
const POST_LIMIT_PER_USER = 500;

const FROM = "àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ";
const TO = ["a","a","a","a","a","a","c","e","e","e","e","i","i","i","i","n","o","o","o","o","o","u","u","u","u","y","y","oe","ae"];
function normalizePseudo(input) {
  let s = "";
  for (const ch of String(input).trim().toLowerCase()) {
    const i = FROM.indexOf(ch);
    s += i >= 0 ? TO[i] : ch;
  }
  s = s.replace(/[\s_-]+/g, ".").replace(/[^a-z0-9.]/g, "").replace(/\.{2,}/g, ".");
  return s.replace(/^\.+|\.+$/g, "");
}

async function main() {
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: PROJECT_ID });
  const db = admin.firestore();
  console.log(`🔄 Migration des pseudos — ${APPLY ? "APPLICATION" : "SIMULATION (aucune écriture)"}`);

  // 1) Pseudos déjà pris (forme normalisée) et documents Pseudo
  const taken = new Set();
  const pseudoDocByName = new Map();
  const pseudoSnap = await db.collection("Pseudo").select("name").get();
  pseudoSnap.forEach((d) => {
    const name = String(d.get("name") ?? "");
    pseudoDocByName.set(name, d.id);
    if (name === normalizePseudo(name)) taken.add(name);
  });

  // 2) Parcours des comptes
  const report = { changed: [], suffixed: [], tooShort: [], tooLong: [], unchanged: 0, errors: [] };
  let last = null;
  for (;;) {
    let q = db.collection("Users").orderBy(admin.firestore.FieldPath.documentId()).limit(400);
    if (last) q = q.startAfter(last);
    const page = await q.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      last = doc.id;
      const old = doc.get("pseudo");
      if (typeof old !== "string" || !old) continue;
      const base = normalizePseudo(old);
      if (base === old) { taken.add(old); report.unchanged++; if (old.length > MAX_LEN) report.tooLong.push({ id: doc.id, pseudo: old }); continue; }
      if (base.length < MIN_LEN) { report.tooShort.push({ id: doc.id, pseudo: old }); continue; }
      let target = base, n = 2;
      while (taken.has(target)) target = `${base}${n++}`;
      taken.add(target);
      const entry = { id: doc.id, from: old, to: target };
      report.changed.push(entry);
      if (target !== base) report.suffixed.push(entry);
      if (target.length > MAX_LEN) report.tooLong.push({ id: doc.id, pseudo: target });
      if (!APPLY) continue;
      try {
        const batch = db.batch();
        batch.update(doc.ref, { pseudo: target, pseudo_before: old, pseudo_migrated_at: Date.now() });
        const pid = pseudoDocByName.get(old);
        if (pid) batch.update(db.collection("Pseudo").doc(pid), { name: target });
        else batch.set(db.collection("Pseudo").doc(), { name: target });
        await batch.commit();
        const posts = await db.collection("Posts").where("user_id", "==", doc.id).limit(POST_LIMIT_PER_USER).get();
        let pb = db.batch(), inBatch = 0;
        for (const p of posts.docs) {
          if (p.get("creatorSnapshot.pseudo") === undefined) continue;
          pb.update(p.ref, { "creatorSnapshot.pseudo": target });
          if (++inBatch === 400) { await pb.commit(); pb = db.batch(); inBatch = 0; }
        }
        if (inBatch > 0) await pb.commit();
      } catch (e) {
        report.errors.push({ id: doc.id, error: String(e) });
      }
    }
    console.log(`… ${report.changed.length} à changer, ${report.unchanged} déjà conformes`);
  }

  const file = `migrate_pseudos_${APPLY ? "applique" : "simulation"}_${Date.now()}.json`;
  fs.writeFileSync(file, JSON.stringify(report, null, 2));
  console.log(`\n✅ Terminé — modifiés: ${report.changed.length} (dont ${report.suffixed.length} avec numéro), ` +
    `trop courts: ${report.tooShort.length}, trop longs (à raccourcir): ${report.tooLong.length}, erreurs: ${report.errors.length}`);
  console.log(`Rapport : ${file}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
