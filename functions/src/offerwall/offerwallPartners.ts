import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { requireAdmin } from "../news/adminAuth";

/**
 * Suivi des partenaires de tâches (ayeT, Tapjoy, Adscend…) : la liste de ceux qu'on a contactés ou intégrés, où en est leur validation,
 * et la prochaine relance. Page « Partenaires de tâches » du hub d'administration ; réservé aux administrateurs.
 * Collection OfferwallPartners : lue et écrite SEULEMENT par ces fonctions (refusée aux clients dans firestore.rules).
 * Voir docs/OFFERWALL_TACHES.md §19.4.
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 30, memory: "256MiB" as const };

export const PARTNER_STATUSES = ["a_demander", "demande_envoyee", "en_revue", "accepte", "refuse", "abandonne"] as const;
export const PARTNER_INTEGRATIONS = ["aucune", "prete", "integre"] as const;
export const PARTNER_KINDS = ["taches", "sondages", "mixte"] as const;

interface Partner {
  name: string; kind: string; status: string; integration: string; notes: string; link: string;
  appliedAt: number; lastCheckAt: number; nextActionAt: number; order: number;
}

const D = (y: number, m: number, d: number): number => Date.UTC(y, m - 1, d);

/** Situation au 28/10/2026, limitée aux 4 plateformes démarchées (inscrite à la première ouverture de la page ; ensuite, seul l'administrateur la modifie). */
const SEED: Record<string, Partner> = {
  ayet: {
    name: "ayeT-Studios", kind: "taches", status: "refuse", integration: "integre", order: 1,
    notes: "Placements Android n° 25815 et iPhone n° 25818 REFUSÉS (« declined »), aucun motif affiché. Compte et facturation complétés, app-ads.txt publié, relance envoyée le 28/10. Aperçu : aucune offre, même France/États-Unis. Android seulement dans l'application.",
    link: "https://publisher.ayet.io/placements", appliedAt: D(2026, 10, 27), lastCheckAt: D(2026, 10, 28), nextActionAt: D(2026, 10, 30),
  },
  tapjoy: {
    name: "Tapjoy (Unity Grow)", kind: "taches", status: "en_revue", integration: "integre", order: 2,
    notes: "Compte « en revue », aucune offre. Support par ticket Unity Grow (bouton « Need help? »). Des éditeurs signalent que l'inscription de nouveaux éditeurs est suspendue : demander l'état de la validation.",
    link: "", appliedAt: D(2026, 10, 13), lastCheckAt: D(2026, 10, 28), nextActionAt: D(2026, 10, 30),
  },
  adscend: {
    name: "Adscend Media", kind: "taches", status: "demande_envoyee", integration: "aucune", order: 3,
    notes: "Demande d'éditeur envoyée le 28/10 (mur d'offres + sondages). Un gestionnaire doit répondre sous 1 à 2 jours ouvrés. Lire les conditions du bonus de 100 $. Poser : pays couverts, offres pour le Togo, seuil et mode de paiement, SDK ou mur web, retour serveur.",
    link: "https://www.adscendmedia.com", appliedAt: D(2026, 10, 28), lastCheckAt: D(2026, 10, 28), nextActionAt: D(2026, 10, 30),
  },
  pubscale: {
    name: "Pubscale", kind: "taches", status: "en_revue", integration: "prete", order: 4,
    notes: "Formulaire envoyé le 28/10 ; compte créé, deux Offerwalls créés (iPhone n° 49234432, Android n° 24622114), tous deux « Pending Approval » (examen jusqu'à 72 h). Coordonnées bancaires enregistrées (en cours de vérification). Retours serveur déployés (pubscaleOfferwallCallback, pubscaleChargebackCallback), clés secrètes posées ; reste : adresse d'annulation (Chargebacks), test Sandbox, écran dans l'application. À surveiller : approbation, pays et offres, seuil de paiement.",
    link: "https://pubscale.com", appliedAt: D(2026, 10, 28), lastCheckAt: D(2026, 10, 28), nextActionAt: D(2026, 10, 31),
  },
  torox: {
    name: "Torox", kind: "taches", status: "demande_envoyee", integration: "aucune", order: 5,
    notes: "Message envoyé le 28/10 par le formulaire de contact (publisher), inscription commencée. FAQ : aucun prépaiement ni engagement ; condition : monnaie virtuelle (nos pièces, retirables) ; paiement mensuel par virement ou PayPal. Questions posées : audience minimale, pays, seuil de paiement, postback, mur web ou SDK pour Flutter. En attente de réponse ; ne pas renvoyer avant le 04/11.",
    link: "https://torox.io/monetise/", appliedAt: D(2026, 10, 28), lastCheckAt: D(2026, 10, 28), nextActionAt: D(2026, 11, 4),
  },
  notik: {
    name: "Notik", kind: "taches", status: "a_demander", integration: "aucune", order: 6,
    notes: "Message préparé le 28/10 pour support@notik.me (à passer en « Demande envoyée » une fois envoyé). SDK Android 0.2.2 et Flutter 1.3.0 (paquet non officiel), SDK iOS « bientôt », mur web ou iframe disponible. Postback et conditions visibles seulement après inscription. Recommandation : commencer par le mur web.",
    link: "https://notik.me", appliedAt: 0, lastCheckAt: D(2026, 10, 28), nextActionAt: D(2026, 11, 3),
  },
};

const num = (v: unknown, max = 4_102_444_800_000): number => {
  const n = Math.trunc(Number(v));
  return Number.isFinite(n) && n >= 0 && n <= max ? n : 0;
};
const str = (v: unknown, n: number): string => String(v ?? "").slice(0, n);

/** Liste des partenaires (les inscrit au premier appel). */
export const offerwallAdminPartners = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const col = db.collection("OfferwallPartners");
  let snap = await col.get();
  if (snap.empty) {
    const batch = db.batch();
    for (const [id, p] of Object.entries(SEED)) batch.set(col.doc(id), { ...p, createdAt: Date.now(), updatedAt: Date.now() });
    await batch.commit();
    snap = await col.get();
  }
  // ajout unique (marqueur _seed2) de Torox et Notik à une liste déjà créée : sans lui, la liste d'origine ne les contiendrait jamais
  if (!snap.empty && !snap.docs.some((d) => d.id === "_seed2")) {
    const batch = db.batch();
    for (const id of ["torox", "notik"]) {
      if (!snap.docs.some((d) => d.id === id)) batch.set(col.doc(id), { ...SEED[id], createdAt: Date.now(), updatedAt: Date.now() });
    }
    batch.set(col.doc("_seed2"), { marker: true, createdAt: Date.now() });
    await batch.commit();
    snap = await col.get();
  }
  // mise à jour unique (marqueur _seed3) de Tapjoy et de Pubscale d'après les événements du 28/10/2026 ; l'administrateur peut ensuite tout modifier
  if (!snap.empty && !snap.docs.some((d) => d.id === "_seed3")) {
    const batch = db.batch();
    const now = Date.now();
    if (snap.docs.some((d) => d.id === "tapjoy")) {
      batch.set(col.doc("tapjoy"), {
        status: "abandonne", integration: "integre", lastCheckAt: now, nextActionAt: D(2026, 12, 1), updatedAt: now,
        notes: "Suspendu par Tapjoy : réponse officielle du 28/10/2026 (onboarding des nouveaux éditeurs en libre-service temporairement suspendu, aucune date de reprise). Ticket Unity n° 00942613 traité. Code Tapjoy conservé dans l'application et le serveur. Revérifier vers le 01/12/2026.",
      }, { merge: true });
    }
    if (snap.docs.some((d) => d.id === "pubscale")) {
      batch.set(col.doc("pubscale"), {
        status: "en_revue", integration: "prete", lastCheckAt: now, updatedAt: now,
        notes: "Deux Offerwalls créés (iPhone n° 49234432, Android n° 24622114), en attente d'approbation. Coordonnées bancaires enregistrées (en vérification). Serveur déployé (conversion et annulation), clés posées. Pubscale a demandé une preuve d'audience (DAU/MAU) : envoi REPORTÉ par le propriétaire (utiliser seulement les captures récentes). Reste : adresse d'annulation (Chargebacks), configuration iPhone, test Sandbox, écran dans l'application.",
      }, { merge: true });
    }
    batch.set(col.doc("_seed3"), { marker: true, createdAt: now });
    await batch.commit();
    snap = await col.get();
  }
  // mise à jour unique (marqueur _seed4) d'après les événements du 28/10/2026 : Torox inscrit, Monlix et AdGate Media (Prodege) ajoutés
  if (!snap.empty && !snap.docs.some((d) => d.id === "_seed4")) {
    const batch = db.batch();
    const now = Date.now();
    const has = (id: string): boolean => snap.docs.some((d) => d.id === id);
    batch.set(col.doc("torox"), {
      status: "en_revue", integration: "aucune", lastCheckAt: now, nextActionAt: D(2026, 11, 4), updatedAt: now,
      notes: "Inscription éditeur envoyée le 28/10 (« Success : compte en cours de traitement ») après un message de questions par le formulaire de contact. À faire : confirmer l'adresse e-mail (lien reçu), puis attendre l'approbation. FAQ : aucun prépaiement ni engagement ; condition : monnaie virtuelle (nos pièces) ; paiement mensuel, virement ou PayPal. À obtenir : audience minimale, pays, seuil de paiement, documentation du postback.",
    }, { merge: true });
    if (!has("monlix")) {
      batch.set(col.doc("monlix"), {
        name: "Monlix", kind: "taches", status: "demande_envoyee", integration: "aucune", order: 7,
        notes: "Message de questions envoyé le 28/10 par le propriétaire (formulaire monlix.com/contact) : audience minimale, pays, moyens de paiement hors crypto, postback ; réponse annoncée sous 48 h. Documentation publique : approbation sous 3 jours ouvrés, seuil 20 $, NET30 (paiement vers le 15 du mois), paiement par Payeer, FaucetPay, AirTM ou Bitcoin (ni PayPal ni virement cités : POINT DÉCISIF). Postback sans signature (clé secrète dans l'adresse), statut 2 = annulation ; IP sources, mode test et réponse attendue non documentés. Mur web HTML5, SDK Android/iOS, pas de SDK Flutter.",
        link: "https://monlix.com", appliedAt: now, lastCheckAt: now, nextActionAt: D(2026, 10, 30), createdAt: now, updatedAt: now,
      });
    }
    if (!has("adgate-media")) {
      batch.set(col.doc("adgate-media"), {
        name: "AdGate Media (Prodege)", kind: "taches", status: "a_demander", integration: "aucune", order: 8,
        notes: "ATTENTION : ne pas confondre avec adgate.com (régie publicitaire sans mur d'offres). AdGate Media a rejoint Prodege (communiqué du 08/09/2026). Formulaire https://www.prodege.com/contact : le bouton d'envoi n'a pas réagi le 28/10 (cause non trouvée) ; autre voie : LinkedIn de Prodege. Éditeurs : https://www.prodege.com/partners/. Pays et conditions non précisés. Mis de côté par le propriétaire pour l'instant.",
        link: "https://www.prodege.com/partners/", appliedAt: 0, lastCheckAt: now, nextActionAt: 0, createdAt: now, updatedAt: now,
      });
    }
    batch.set(col.doc("_seed4"), { marker: true, createdAt: now });
    await batch.commit();
    snap = await col.get();
  }
  const partners = snap.docs.filter((d) => !d.id.startsWith("_")).map((d) => ({ id: d.id, ...(d.data() as Partner) })).sort((a, b) => (a.order ?? 99) - (b.order ?? 99));
  return { partners, statuses: PARTNER_STATUSES, integrations: PARTNER_INTEGRATIONS, kinds: PARTNER_KINDS };
});

/** Modifie un partenaire (statut, intégration, notes, relance…) ou en ajoute un nouveau. */
export const offerwallAdminPartnerSave = onCall(OPTS, async (request) => {
  const adminId = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = str(d["id"], 40).toLowerCase().replace(/[^a-z0-9_-]/g, "");
  if (id.length < 2) throw new HttpsError("invalid-argument", "Identifiant invalide.");
  const ref = db.collection("OfferwallPartners").doc(id);
  const exists = (await ref.get()).exists;
  const patch: Record<string, unknown> = { updatedAt: Date.now(), updatedBy: adminId };
  if ("status" in d) {
    if (!(PARTNER_STATUSES as readonly string[]).includes(str(d["status"], 30))) throw new HttpsError("invalid-argument", "Statut invalide.");
    patch["status"] = str(d["status"], 30);
  }
  if ("integration" in d) {
    if (!(PARTNER_INTEGRATIONS as readonly string[]).includes(str(d["integration"], 30))) throw new HttpsError("invalid-argument", "Intégration invalide.");
    patch["integration"] = str(d["integration"], 30);
  }
  if ("kind" in d) {
    if (!(PARTNER_KINDS as readonly string[]).includes(str(d["kind"], 30))) throw new HttpsError("invalid-argument", "Type invalide.");
    patch["kind"] = str(d["kind"], 30);
  }
  if ("notes" in d) patch["notes"] = str(d["notes"], 1200);
  if ("link" in d) {
    const link = str(d["link"], 300).trim();
    if (link && !/^https:\/\//i.test(link)) throw new HttpsError("invalid-argument", "Le lien doit commencer par https://");
    patch["link"] = link;
  }
  if ("name" in d) patch["name"] = str(d["name"], 80).trim();
  if ("nextActionAt" in d) patch["nextActionAt"] = num(d["nextActionAt"]);
  if (d["touch"] === true) patch["lastCheckAt"] = Date.now();
  if (!exists) {
    const name = str(d["name"], 80).trim();
    if (!name) throw new HttpsError("invalid-argument", "Nom manquant.");
    Object.assign(patch, { name, kind: patch["kind"] ?? "taches", status: patch["status"] ?? "a_demander", integration: patch["integration"] ?? "aucune",
      notes: patch["notes"] ?? "", link: patch["link"] ?? "", appliedAt: 0, lastCheckAt: patch["lastCheckAt"] ?? 0, nextActionAt: patch["nextActionAt"] ?? 0, order: 100, createdAt: Date.now() });
  }
  await ref.set(patch, { merge: true });
  await db.collection("AdminActions").doc().set({ type: "offerwall_partner", adminId, at: Date.now(), partnerId: id, fields: Object.keys(patch).filter((k) => !["updatedAt", "updatedBy"].includes(k)) }).catch(() => undefined);
  return { ok: true };
});
