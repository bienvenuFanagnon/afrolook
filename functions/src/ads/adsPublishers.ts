import { onCall, onRequest, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { fetchLimited } from "../posts/linkPreview";
import { listAlerts, reviewAlert } from "./adsWatch";
import { ADMIN_ROLES, isRegieAdminRequest } from "./adsAdmin";
import { listCampaigns, listSharers, reviewCampaign, reviewSharer } from "./adsShare";
import { notifyAdminsAll, notifyByEmail, EmailContent } from "../shared/user_notify";
import { requireGoogle } from "./adsWeb";
import { PUBLISHER_RULES, PUBLISHER_RULES_VERSION } from "./adsRules";
import { AD_CATEGORIES, FORBIDDEN_CONTENT } from "./adsCategories";
import { measure } from "./adsMeasure";
import {
  AudienceRow, CATEGORIES, MAX_PROPERTIES, audienceEstimate, countedAudience, hostOf, isPropertyId, newPropertyId, newVerifyToken,
  originsOf, pageHasToken, validateProfile, validateProperty,
} from "./adsPublishers_logic";

/**
 * Afrolook Ads : diffuseurs. Un profil (validé par l'administration), puis des sites et applications EN LIGNE, chacun avec sa propre demande
 * (acceptée ou refusée) et son identifiant publicitaire (ap_xxxxxxxxxx).
 *  Diffuseur (connexion Google) : adsPubMe, adsPubSaveProfile, adsPubAddProperty, adsPubVerifyProperty, adsPubUpdateProperty, adsPubDeleteProperty
 *  Administration (rôle administrateur) : adsPubAdminList, adsPubAdminReview
 *  Public : adsAudience (audience estimée du réseau = 50 000 + audience retenue des sites et applications validés)
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 30, memory: "256MiB" as const };
/** Pour le moment, seuls deux comptes ont accès à l'administration de la régie (rôle administrateur ET adresse autorisée) : voir adsAdmin.ts. */
const isRegieAdmin = isRegieAdminRequest;
const UA = "Mozilla/5.0 (compatible; AfrolookAdsBot/1.0; +https://afrolookmedia.com/ads/)";
const SPACE_URL = "https://afrolookmedia.com/ads/diffuseur/";
const now = (): number => Date.now();

export async function requireAdmin(request: CallableRequest): Promise<{ uid: string; email: string }> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const u = (await db.collection("Users").doc(uid).get()).data() ?? {};
  if (!isRegieAdmin(request, u["role"])) throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  return { uid, email: String(u["email"] ?? "") };
}

/** Détection à la connexion : le site n'affiche aucun bouton « Administration » ; l'espace admin n'apparaît que si ce compte est administrateur. Ne renvoie rien d'autre. */
export const adsWho = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const u = (await db.collection("Users").doc(uid).get()).data() ?? {};
  return { admin: isRegieAdmin(request, u["role"]) };
});

const profRef = (uid: string) => db.collection("AdPublisherProfiles").doc(uid);
const propRef = (id: string) => db.collection("AdProperties").doc(id);
const audit = (by: string, target: string, id: string, decision: string, reason: string) => db.collection("AdsAudit").add({ at: now(), by, target, id, decision, reason: reason.slice(0, 300) }).catch(() => undefined);

const mailTo = (to: string, c: Omit<EmailContent, "button"> & { button?: EmailContent["button"] }) => notifyByEmail(to, { ...c, button: c.button ?? { label: "Ouvrir mon espace diffuseur", url: SPACE_URL } }).catch((e) => console.error("[adsPub] mail", e));

/** Vérifie qu'une adresse est réellement en ligne. Une page protégée (401, 403, 429) compte comme en ligne : le site existe mais refuse les robots. */
async function isOnline(url: string): Promise<{ online: boolean; protectedSite: boolean }> {
  try {
    await fetchLimited(url, { ua: UA, max: 200_000 });
    return { online: true, protectedSite: false };
  } catch (e) {
    const m = String((e as Error)?.message ?? "");
    if (/^http (401|403|429)$/.test(m)) return { online: true, protectedSite: true };
    return { online: false, protectedSite: false };
  }
}

const profileOut = (p: Record<string, unknown>) => ({
  status: p["status"], reason: p["reason"] ?? "", type: p["type"], name: p["name"], country: p["country"], city: p["city"], phone: p["phone"], website: p["website"], about: p["about"], createdAt: p["createdAt"],
});
const propOut = (id: string, p: Record<string, unknown>, owner: boolean) => ({
  id, kind: p["kind"], name: p["name"], url: p["url"] ?? "", androidUrl: p["androidUrl"] ?? "", iosUrl: p["iosUrl"] ?? "", category: p["category"], countries: p["countries"] ?? [], languages: p["languages"] ?? [],
  acceptedCategories: p["acceptedCategories"] ?? [], audienceMonthly: p["audienceDeclared"] ?? 0, sessionsMonthly: p["sessionsMonthly"] ?? 0, audienceCounted: p["audienceCounted"] ?? 0, description: p["description"] ?? "", status: p["status"], reason: p["reason"] ?? "",
  verified: p["verified"] === true, online: p["online"] === true, formats: p["formats"] ?? [], createdAt: p["createdAt"], payable: p["payable"] === true, reviewHold: p["reviewHold"] === true, holdReason: p["holdReason"] ?? "", measured: p["measured"] ?? null, ...(owner ? { verifyToken: p["verifyToken"] ?? "" } : {}),
});

// ─── Audience du réseau ─────────────────────────────────────────────────────────────────────────────────────────────

let audCache: { at: number; v: ReturnType<typeof audienceEstimate> } | null = null;
async function computeAudience(): Promise<ReturnType<typeof audienceEstimate>> {
  if (audCache && Date.now() - audCache.at < 300_000) return audCache.v;
  const snap = await db.collection("AdProperties").where("status", "==", "active").limit(1000).get();
  const v = audienceEstimate(snap.docs.map((d) => ({ status: "active", audienceCounted: d.data()["audienceCounted"] } as AudienceRow)));
  audCache = { at: Date.now(), v };
  return v;
}

export const adsAudience = onRequest({ ...OPTS, cors: true, timeoutSeconds: 15 }, async (req, res) => {
  if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }
  try {
    const v = await computeAudience();
    res.set("Cache-Control", "public, max-age=300, s-maxage=300");
    res.json({ base: v.base, partners: v.partners, total: v.total, sites: v.count });
  } catch (e) {
    console.error("[adsAudience]", e);
    res.json({ base: 50000, partners: 0, total: 50000, sites: 0 });
  }
});

// ─── Diffuseur ──────────────────────────────────────────────────────────────────────────────────────────────────────

export const adsPubMe = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const [p, props, aud] = await Promise.all([profRef(me.uid).get(), db.collection("AdProperties").where("ownerUid", "==", me.uid).limit(40).get(), computeAudience()]);
  const items = props.docs.filter((d) => d.data()["status"] !== "removed").map((d) => propOut(d.id, d.data(), true)).sort((a, b) => Number(b.createdAt) - Number(a.createdAt));
  const prof = p.data();
  return {
    profile: p.exists ? profileOut(prof!) : null, properties: items, audience: { base: aud.base, total: aud.total }, maxProperties: MAX_PROPERTIES, categories: CATEGORIES, adCategories: AD_CATEGORIES, forbiddenContent: FORBIDDEN_CONTENT, email: me.email,
    // règles officielles : le diffuseur voit le texte exact et la version qu'il a acceptée ; à chaque changement de version, il doit accepter de nouveau
    rules: { version: PUBLISHER_RULES_VERSION, accepted: prof?.["rulesVersion"] === PUBLISHER_RULES_VERSION, acceptedVersion: prof?.["rulesVersion"] ?? "", acceptedAt: prof?.["rulesAcceptedAt"] ?? 0, text: PUBLISHER_RULES },
  };
});

export const adsPubSaveProfile = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const v = validateProfile(request.data);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  if ((request.data as { rulesVersion?: unknown } | undefined)?.rulesVersion !== PUBLISHER_RULES_VERSION) throw new HttpsError("failed-precondition", "regles_a_accepter");
  const ref = profRef(me.uid);
  const cur = (await ref.get()).data();
  if (cur?.["status"] === "suspended") throw new HttpsError("permission-denied", "profil_suspendu");
  const t = now();
  const status = cur?.["status"] === "active" ? "active" : "pending";
  await ref.set({ ...v.value, uid: me.uid, email: me.email, googleName: me.name, status, reason: status === "pending" ? "" : cur?.["reason"] ?? "", createdAt: cur?.["createdAt"] ?? t, updatedAt: t, rulesVersion: PUBLISHER_RULES_VERSION, rulesAcceptedAt: t }, { merge: true });
  await audit(me.uid, "rules", me.uid, "accept", PUBLISHER_RULES_VERSION);
  if (status === "pending") {
    await notifyAdminsAll({
      title: "📡 Nouveau profil diffuseur", message: `${v.value.name} (${v.value.country}) demande à devenir diffuseur Afrolook Ads. Ouvre la validation des diffuseurs.`, target: "ADMIN_ADS", refId: me.uid,
      email: { subject: "Nouveau profil diffuseur à valider", heading: "Nouveau profil diffuseur", icon: "📡", intro: "Un diffuseur demande à afficher les annonces Afrolook Ads sur ses sites ou applications.", rows: [["Nom", v.value.name], ["Type", v.value.type === "company" ? "Entreprise" : "Particulier"], ["Pays", v.value.country], ["E-mail", me.email]], tone: "info" },
    });
  }
  return { ok: true, status };
});

export const adsPubAddProperty = onCall({ ...OPTS, timeoutSeconds: 45 }, async (request) => {
  const me = requireGoogle(request);
  const prof = (await profRef(me.uid).get()).data();
  if (!prof) throw new HttpsError("failed-precondition", "profil_manquant");
  if (prof["status"] === "refused" || prof["status"] === "suspended") throw new HttpsError("permission-denied", "profil_non_valide");
  if (prof["rulesVersion"] !== PUBLISHER_RULES_VERSION) throw new HttpsError("failed-precondition", "regles_a_accepter");
  const v = validateProperty(request.data);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  const p = v.value;

  const mine = await db.collection("AdProperties").where("ownerUid", "==", me.uid).limit(60).get();
  if (mine.docs.filter((d) => ["pending", "active", "suspended"].includes(String(d.data()["status"]))).length >= MAX_PROPERTIES) throw new HttpsError("resource-exhausted", "limite_atteinte");

  // un même site ou une même application ne peut être déclaré que par un seul diffuseur
  const keys = [p.kind === "site" ? `site:${hostOf(p.url)}` : "", p.packageName ? `play:${p.packageName}` : "", p.iosUrl ? `ios:${p.iosUrl}` : ""].filter(Boolean);
  for (const k of keys) {
    const dup = await db.collection("AdProperties").where("uniqueKey", "array-contains", k).limit(5).get();
    if (dup.docs.some((d) => ["pending", "active", "suspended"].includes(String(d.data()["status"])))) throw new HttpsError("already-exists", "deja_enregistre");
  }

  // le site ou l'application doit être EN LIGNE
  const targets = p.kind === "site" ? [p.url] : [p.androidUrl, p.iosUrl].filter(Boolean);
  const checks = await Promise.all(targets.map(isOnline));
  if (checks.some((c) => !c.online)) throw new HttpsError("failed-precondition", "hors_ligne");

  const t = now();
  let id = newPropertyId();
  const verifyToken = newVerifyToken();
  const doc = {
    id, ownerUid: me.uid, ownerEmail: me.email, ownerName: String(prof["name"] ?? me.name), kind: p.kind, name: p.name, url: p.url, androidUrl: p.androidUrl, iosUrl: p.iosUrl, packageName: p.packageName,
    category: p.category, acceptedCategories: p.acceptedCategories, countries: p.countries, languages: p.languages, audienceDeclared: p.audienceMonthly, sessionsMonthly: p.sessionsMonthly, description: p.description,
    origins: p.kind === "site" ? originsOf(p.url) : [], uniqueKey: keys, verifyToken, verified: false, online: true, onlineAt: t, protectedSite: checks.some((c) => c.protectedSite),
    status: "pending", reason: "", audienceCounted: 0, formats: [], createdAt: t, updatedAt: t,
  };
  for (let i = 0; i < 5; i++) {
    try { await propRef(id).create(doc); break; } catch (e) { if (i === 4) throw e; id = newPropertyId(); doc.id = id; }
  }
  await notifyAdminsAll({
    title: "📡 Nouveau site ou application diffuseur", message: `${doc.ownerName} propose ${p.kind === "site" ? "le site" : "l'application"} « ${p.name} » (${p.audienceMonthly.toLocaleString("fr-FR")} personnes par mois). Ouvre la validation des diffuseurs.`, target: "ADMIN_ADS", refId: id,
    email: { subject: "Nouveau site ou application à valider", heading: "Nouvelle demande de diffusion", icon: "📡", intro: "Un diffuseur demande à afficher des annonces sur un nouveau site ou une nouvelle application.", rows: [["Nom", p.name], ["Type", p.kind === "site" ? "Site web" : "Application"], ["Adresse", p.url || p.androidUrl || p.iosUrl], ["Audience mensuelle déclarée", p.audienceMonthly.toLocaleString("fr-FR")], ["Diffuseur", doc.ownerName]], tone: "info" },
  });
  return { ok: true, id, verifyToken, status: "pending" };
});

export const adsPubVerifyProperty = onCall({ ...OPTS, timeoutSeconds: 45 }, async (request) => {
  const me = requireGoogle(request);
  const id = String((request.data as { id?: unknown } | undefined)?.id ?? "");
  if (!isPropertyId(id)) throw new HttpsError("invalid-argument", "identifiant invalide");
  const ref = propRef(id);
  const p = (await ref.get()).data();
  if (!p || p["ownerUid"] !== me.uid || p["status"] === "removed") throw new HttpsError("not-found", "inconnu");
  if (p["kind"] !== "site") throw new HttpsError("failed-precondition", "site_seulement");
  const base = new URL(String(p["url"]));
  const token = String(p["verifyToken"] ?? "");
  let ok = false;
  for (const path of ["/", "/afrolook-ads.txt"]) {
    try {
      const r = await fetchLimited(new URL(path, `${base.protocol}//${base.host}`).toString(), { ua: UA, max: 300_000 });
      if (pageHasToken(r.body.toString("utf8"), token)) { ok = true; break; }
    } catch { /* on essaie l'adresse suivante */ }
  }
  if (ok) await ref.update({ verified: true, verifiedAt: now(), updatedAt: now() });
  return { ok, verified: ok };
});

export const adsPubUpdateProperty = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = String(d["id"] ?? "");
  if (!isPropertyId(id)) throw new HttpsError("invalid-argument", "identifiant invalide");
  const ref = propRef(id);
  const p = (await ref.get()).data();
  if (!p || p["ownerUid"] !== me.uid || p["status"] === "removed") throw new HttpsError("not-found", "inconnu");
  const merged = { acceptedCategories: d["acceptedCategories"] ?? p["acceptedCategories"], kind: p["kind"], name: p["name"], url: p["url"], androidUrl: p["androidUrl"], iosUrl: p["iosUrl"], category: p["category"], countries: d["countries"] ?? p["countries"], languages: d["languages"] ?? p["languages"], audienceMonthly: d["audienceMonthly"] ?? p["audienceDeclared"], sessionsMonthly: d["sessionsMonthly"] ?? p["sessionsMonthly"], description: d["description"] ?? p["description"] };
  const v = validateProperty(merged);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  const upd: Record<string, unknown> = { acceptedCategories: v.value.acceptedCategories, countries: v.value.countries, languages: v.value.languages, audienceDeclared: v.value.audienceMonthly, sessionsMonthly: v.value.sessionsMonthly, description: v.value.description, updatedAt: now() };
  // l'audience retenue ne monte jamais toute seule : seule l'administration la relève ; elle baisse si le diffuseur déclare moins
  upd["audienceCounted"] = Math.min(Number(p["audienceCounted"]) || 0, v.value.audienceMonthly);
  await ref.update(upd);
  audCache = null;
  return { ok: true };
});

export const adsPubDeleteProperty = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const id = String((request.data as { id?: unknown } | undefined)?.id ?? "");
  if (!isPropertyId(id)) throw new HttpsError("invalid-argument", "identifiant invalide");
  const ref = propRef(id);
  const p = (await ref.get()).data();
  if (!p || p["ownerUid"] !== me.uid) throw new HttpsError("not-found", "inconnu");
  await ref.update({ status: "removed", audienceCounted: 0, updatedAt: now() });
  audCache = null;
  return { ok: true };
});

// ─── Administration ─────────────────────────────────────────────────────────────────────────────────────────────────

export const adsPubAdminList = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const flags = (request.data ?? {}) as { sharers?: unknown; campaigns?: unknown; status?: unknown };
  if (flags.sharers === true) return { sharers: await listSharers(String(flags.status ?? "pending")) }; // Partage et gagne : profils des partageurs
  if (flags.campaigns === true) return { campaigns: await listCampaigns(String(flags.status ?? "pending")) }; // Partage et gagne : campagnes des annonceurs
  if ((request.data as { alerts?: unknown } | undefined)?.alerts === true) return { alerts: await listAlerts(String((request.data as { status?: unknown }).status ?? "open")) }; // surveillance : alertes à vérifier
  const status = String((request.data as { status?: unknown } | undefined)?.status ?? "pending");
  const wanted = ["pending", "active", "refused", "suspended", "all"].includes(status) ? status : "pending";
  const pc = db.collection("AdPublisherProfiles"), qc = db.collection("AdProperties");
  const [profiles, props] = await Promise.all([
    (wanted === "all" ? pc.orderBy("createdAt", "desc") : pc.where("status", "==", wanted)).limit(200).get(),
    (wanted === "all" ? qc.orderBy("createdAt", "desc") : qc.where("status", "==", wanted)).limit(200).get(),
  ]);
  const owners = new Map<string, string>();
  await Promise.all([...new Set(props.docs.map((d) => String(d.data()["ownerUid"])))].map(async (uid) => { owners.set(uid, String((await profRef(uid).get()).data()?.["status"] ?? "none")); }));
  return {
    profiles: profiles.docs.map((d) => ({ uid: d.id, email: d.data()["email"], ...profileOut(d.data()) })),
    properties: props.docs.filter((d) => d.data()["status"] !== "removed").map((d) => ({ ...propOut(d.id, d.data(), false), ownerUid: d.data()["ownerUid"], ownerName: d.data()["ownerName"], ownerEmail: d.data()["ownerEmail"], ownerStatus: owners.get(String(d.data()["ownerUid"])) ?? "none", protectedSite: d.data()["protectedSite"] === true })),
  };
});

export const adsPubAdminReview = onCall(OPTS, async (request) => {
  const admin = await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  if (d["target"] === "sharer" || d["target"] === "campaign") {
    const note = String(d["reason"] ?? "").replace(/[ -<>]/g, " ").trim().slice(0, 300);
    if ((d["decision"] === "refuse" || d["decision"] === "suspend") && note.length < 5) throw new HttpsError("invalid-argument", "motif_obligatoire");
    try { if (d["target"] === "sharer") await reviewSharer(admin.uid, String(d["id"] ?? ""), String(d["decision"] ?? ""), note, Number(d["audienceRetained"])); else await reviewCampaign(admin.uid, String(d["id"] ?? ""), String(d["decision"] ?? ""), note); } catch (e) { throw new HttpsError("invalid-argument", String((e as Error).message)); }
    return { ok: true };
  }
  if (d["target"] === "alert") {
    const note = String(d["reason"] ?? "").replace(/[\u0000-\u001f<>]/g, " ").trim().slice(0, 300);
    try { await reviewAlert(admin.uid, String(d["id"] ?? ""), String(d["decision"] ?? ""), note); } catch (e) { throw new HttpsError("invalid-argument", String((e as Error).message)); }
    return { ok: true };
  }
  const target = d["target"] === "property" ? "property" : d["target"] === "profile" ? "profile" : "";
  const decision = ["approve", "refuse", "suspend", "reactivate"].includes(String(d["decision"])) ? String(d["decision"]) : "";
  const reason = String(d["reason"] ?? "").replace(/[\u0000-\u001f<>]/g, " ").trim().slice(0, 300);
  const id = String(d["id"] ?? "");
  if (!target || !decision || !id) throw new HttpsError("invalid-argument", "demande incomplète");
  if ((decision === "refuse" || decision === "suspend") && reason.length < 5) throw new HttpsError("invalid-argument", "motif_obligatoire");
  const t = now();
  const stateOf = { approve: "active", reactivate: "active", refuse: "refused", suspend: "suspended" } as const;
  const status = stateOf[decision as keyof typeof stateOf];

  if (target === "profile") {
    const ref = profRef(id);
    const p = (await ref.get()).data();
    if (!p) throw new HttpsError("not-found", "profil inconnu");
    await ref.update({ status, reason: status === "active" ? "" : reason, reviewedBy: admin.uid, reviewedAt: t, updatedAt: t });
    if (status === "suspended") {
      const props = await db.collection("AdProperties").where("ownerUid", "==", id).where("status", "==", "active").get();
      await Promise.all(props.docs.map((x) => x.ref.update({ status: "suspended", reason: "Profil suspendu", updatedAt: t })));
      audCache = null;
    }
    await audit(admin.uid, "profile", id, decision, reason);
    const ok = status === "active";
    await mailTo(String(p["email"] ?? ""), {
      subject: ok ? "Ton profil diffuseur est validé" : status === "refused" ? "Ton profil diffuseur n'a pas été accepté" : "Ton profil diffuseur est suspendu",
      heading: ok ? "Profil validé" : status === "refused" ? "Profil refusé" : "Profil suspendu", icon: ok ? "✅" : "⛔", tone: ok ? "ok" : "no",
      intro: ok ? "Bonne nouvelle : ton profil diffuseur est validé. Tu peux ajouter tes sites et applications pour demander leur validation." : `Ton profil n'a pas pu être accepté. Motif : ${reason}`,
    });
    return { ok: true, status };
  }

  const ref = propRef(id);
  const p = (await ref.get()).data();
  if (!p) throw new HttpsError("not-found", "inconnu");
  const upd: Record<string, unknown> = { status, reason: status === "active" ? "" : reason, reviewedBy: admin.uid, reviewedAt: t, updatedAt: t };
  if (status === "active") {
    const prof = (await profRef(String(p["ownerUid"])).get()).data();
    if (prof?.["status"] !== "active") throw new HttpsError("failed-precondition", "profil_non_valide");
    if (p["online"] !== true) throw new HttpsError("failed-precondition", "hors_ligne");
    if (prof?.["rulesVersion"] !== PUBLISHER_RULES_VERSION) throw new HttpsError("failed-precondition", "regles_a_accepter");
    // un site doit PROUVER qu'il appartient au diffuseur (sans cela, n'importe qui pourrait déclarer le site d'un autre) ; une application n'est payable qu'après attestation
    if (p["kind"] === "site" && p["verified"] !== true) throw new HttpsError("failed-precondition", "verification_requise");
    upd["audienceCounted"] = countedAudience(Number(p["audienceDeclared"]), d["audienceCounted"]);
    upd["formats"] = Array.isArray(d["formats"]) && (d["formats"] as unknown[]).length ? (d["formats"] as unknown[]).map(String).slice(0, 12) : ["banner", "sticky", "native", "carousel", "poster", "video", "interstitial", "rewarded"];
    upd["approvedAt"] = t;
    upd["payable"] = p["kind"] === "site";
  } else {
    upd["audienceCounted"] = 0;
  }
  await ref.update(upd);
  audCache = null;
  await audit(admin.uid, "property", id, decision, reason);
  const ok = status === "active";
  await mailTo(String(p["ownerEmail"] ?? ""), {
    subject: ok ? `« ${p["name"]} » est validé` : status === "refused" ? `« ${p["name"]} » n'a pas été accepté` : `« ${p["name"]} » est suspendu`,
    heading: ok ? "Site ou application validé" : status === "refused" ? "Demande refusée" : "Diffusion suspendue", icon: ok ? "✅" : "⛔", tone: ok ? "ok" : "no",
    intro: ok ? `« ${p["name"]} » est validé. Ton identifiant publicitaire est ${id}. Retrouve le code d'intégration dans ton espace diffuseur.` : `« ${p["name"]} » n'a pas pu être accepté. Motif : ${reason}`,
    rows: ok ? [["Identifiant publicitaire", id]] : undefined,
  });
  return { ok: true, status, id };
});

// ─── Règles : accepter la version courante ──────────────────────────────────────────────────────────────────────────

export const adsPubAcceptRules = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  if ((request.data as { version?: unknown } | undefined)?.version !== PUBLISHER_RULES_VERSION) throw new HttpsError("failed-precondition", "version_obsolete");
  const ref = profRef(me.uid);
  if (!(await ref.get()).exists) throw new HttpsError("failed-precondition", "profil_manquant");
  const t = now();
  await ref.update({ rulesVersion: PUBLISHER_RULES_VERSION, rulesAcceptedAt: t, updatedAt: t });
  await audit(me.uid, "rules", me.uid, "accept", PUBLISHER_RULES_VERSION);
  return { ok: true, version: PUBLISHER_RULES_VERSION };
});

// ─── Audience mesurée d'un site sur 60 jours, comparée à l'audience déclarée ────────────────────────────────────────

/** Pour le diffuseur propriétaire (et pour l'administration) : visiteurs différents sur 30 et 60 jours, courbe jour par jour, affichages valides, trafic invalide. */
export const adsPubStats = onCall({ ...OPTS, timeoutSeconds: 60 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const id = String((request.data as { id?: unknown } | undefined)?.id ?? "");
  if (!isPropertyId(id)) throw new HttpsError("invalid-argument", "identifiant invalide");
  const p = (await propRef(id).get()).data();
  if (!p || p["status"] === "removed") throw new HttpsError("not-found", "inconnu");
  if (p["ownerUid"] !== uid) {
    const u = (await db.collection("Users").doc(uid).get()).data() ?? {};
    if (!ADMIN_ROLES.includes(String(u["role"] ?? ""))) throw new HttpsError("permission-denied", "réservé au propriétaire");
  }
  const declared = Number(p["audienceDeclared"]) || 0;
  const m = await measure(id, declared, 60, Date.now(), (p["countries"] as string[]) ?? []);
  return {
    geo: m.geo, declaredGeo: m.declaredGeo, declaredCountries: p["countries"] ?? [],
    id, name: p["name"], kind: p["kind"], status: p["status"], declared, counted: Number(p["audienceCounted"]) || 0, payable: p["payable"] === true, verified: p["verified"] === true,
    report: m.report, series: m.series, totals: m.totals, thresholds: { alert: 0.1, suspend: 0.25 }, rulesVersion: PUBLISHER_RULES_VERSION,
  };
});
