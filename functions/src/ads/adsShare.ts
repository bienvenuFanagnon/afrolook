import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { createHash, createHmac, timingSafeEqual } from "crypto";
import { db } from "../shared/firebase";
import { notifyAdminsAll, notifyByEmail } from "../shared/user_notify";
import { signingKey } from "./adsEngine";
import { ipHash } from "./adsEngine_logic";
import { requireGoogle } from "./adsWeb";
import { isRegieAdminAccount } from "./adsAdmin";
import { validateAdInput } from "./adsWeb_logic";
import { blockReason, dayOf, eventId, readOfferwallConfig, repayDebt, splitCoins } from "../offerwall/offerwall_logic";
import { sponsorOf } from "../payments/coinShares";
import { userFacts } from "../offerwall/offerwall_shared";
import { PLATFORM_LABEL, ShareConfig, addHundredths, captionFor, hundredthsFor, isPreviewAgent, newCode, platformOf, readShareConfig, releaseAtFor, shareClickDecision, validChannel, validCode } from "./adsShare_logic";
import { EMPTY_METRICS, SharerMetrics, addMetrics, clawback, detectSharerFraud } from "./adsShare_fraud";
import {
  DEFAULT_AUDIENCE_PRICE_PER_1000, DEFAULT_EXPECTED_CTR, MAX_TARGET_AUDIENCE, MIN_TARGET_AUDIENCE, SHARE_RULES, SHARE_RULES_VERSION, audiencePricing, campaignOpen, declaredReach, pricingOf, remainingClicks, validateSharerProfile,
} from "./adsShare_campaign";

/**
 * « Partage et gagne » : missions WhatsApp (statut et groupes). Voir docs/PARTAGE_WHATSAPP_ADS.md.
 * Les campagnes sont des MISSIONS réservées à notre application : collection ShareCampaigns, jamais lue par le moteur de diffusion (adsServe), la galerie
 * publique ou les sites et applications partenaires.
 *
 *  Annonceur (site, connexion Google) : adsShareCampaignCreate, adsShareCampaignMine
 *  Partageur (application) : adsShareProfileMe, adsShareProfileSave, adsShareList, adsShareCreate
 *  Lien suivi (public) : adsShareGo  (GET /p/<code> = aperçu ou page intermédiaire ; POST = le clic est jugé et payé s'il est valide)
 *  Gains : adsShareRollup (toutes les heures : les gains arrivés au terme de la retenue deviennent des pièces, avec un événement « WhatsApp » dans l'historique des tâches)
 *  Administration : listSharers / reviewSharer / listCampaigns / reviewCampaign / listShareStats (branchés dans adsPubAdminList et adsPubAdminReview)
 * Collections fermées aux clients : ShareCampaigns, AdShareProfiles, AdShareLinks, AdShareSeen, AdShareEarnings, AdShareStats, AdShareState.
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 30, memory: "256MiB" as const };
const SITE = "https://afrolookmedia.com";
const BUCKET = "afrolooki.appspot.com";
export const PROVIDER = "whatsapp_partage";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const geoip: { lookup(ip: string): { country: string } | null } = require("geoip-country");
const countryOf = (ip: string): string | null => { try { const r = geoip.lookup(ip); return r && /^[A-Z]{2}$/.test(r.country) ? r.country : null; } catch { return null; } };
const clientIp = (req: { headers: Record<string, unknown>; ip?: string }): string => String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
const esc = (s: unknown): string => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
const cfgOf = async (): Promise<ShareConfig & { userPct: number; sponsorPct: number; expectedCtr: number; audiencePricePer1000Fcfa: number }> => {
  const d = (await db.collection("AppConfig").doc("share").get()).data();
  const num = (v: unknown, def: number, lo: number, hi: number): number => { const x = Number(v); return Number.isFinite(x) && x >= lo && x <= hi ? x : def; };
  return { ...readShareConfig(d), userPct: num(d?.["userPct"], 60, 10, 95), sponsorPct: num(d?.["sponsorPct"], 10, 0, 50), expectedCtr: num(d?.["expectedCtr"], DEFAULT_EXPECTED_CTR, 0.001, 0.5), audiencePricePer1000Fcfa: num(d?.["audiencePricePer1000Fcfa"], DEFAULT_AUDIENCE_PRICE_PER_1000, 1, 100000) };
};
const httpsUrl = (u: unknown): string => { try { const x = new URL(String(u)); return x.protocol === "https:" ? x.href : ""; } catch { return ""; } };
const now = (): number => Date.now();

// ─── Campagne (mission) ───────────────────────────────────────────────────────────────────────────────────────────────

interface Campaign { targetAudience: number; id: string; ownerUid: string; brand: string; title: string; text: string; cta: string; dest: string; image: string; video: boolean; mediaUrl: string; countries: string[]; category: string; status: string; cpcFcfa: number; userFcfa: number; budgetFcfa: number }
const ACTION_LABEL: Record<string, string> = { visit: "Visiter", download: "Télécharger", learn_more: "En savoir plus", whatsapp: "Écrire sur WhatsApp", call: "Appeler" };
function campaignOf(id: string, v: FirebaseDocumentData | undefined, userPct: number): Campaign | null {
  if (!v) return null;
  const dest = httpsUrl(v["actionUrl"]);
  const images = Array.isArray(v["images"]) ? (v["images"] as unknown[]).map(String).filter(Boolean) : [];
  const video = v["mediaType"] === "video";
  const image = video ? httpsUrl(v["thumbnailUrl"]) : httpsUrl(images[0]);
  if (!dest || !image) return null;
  const p = pricingOf(v as { cpcFcfa?: unknown; budgetFcfa?: unknown; userFcfa?: unknown }, userPct);
  return { id, ownerUid: String(v["ownerUid"] ?? ""), brand: String(v["brand"] ?? ""), title: String(v["title"] ?? ""), text: String(v["text"] ?? ""), cta: ACTION_LABEL[String(v["action"])] ?? "En savoir plus", dest, image, video, mediaUrl: video ? httpsUrl(v["videoUrl"]) : image, countries: Array.isArray(v["countries"]) ? (v["countries"] as unknown[]).map(String) : ["ALL"], category: String(v["category"] ?? ""), status: String(v["status"] ?? ""), targetAudience: Number(v["targetAudience"]) || 0, ...p };
}
type FirebaseDocumentData = FirebaseFirestore.DocumentData;
async function loadCampaign(id: string, userPct: number): Promise<Campaign | null> { return campaignOf(id, (await db.collection("ShareCampaigns").doc(id).get()).data(), userPct); }

// ─── Jeton de la page intermédiaire (prouve que la page a été servie, et quand) ─────────────────────────────────────

const b64 = (s: string): string => Buffer.from(s).toString("base64url");
async function signPage(code: string, key: string): Promise<string> {
  const body = b64(JSON.stringify({ c: code, t: now() }));
  return `${body}.${createHmac("sha256", key).update(body).digest("base64url")}`;
}
function verifyPage(tok: unknown, key: string): { c: string; t: number } | null {
  const [body, sig] = String(tok ?? "").split(".");
  if (!body || !sig) return null;
  const want = createHmac("sha256", key).update(body).digest("base64url");
  const a = Buffer.from(sig), b = Buffer.from(want);
  if (a.length !== b.length || !timingSafeEqual(a, b)) return null;
  try { const j = JSON.parse(Buffer.from(body, "base64url").toString()); return typeof j.c === "string" && typeof j.t === "number" ? j : null; } catch { return null; }
}

// ─── Annonceur : créer et suivre une campagne ───────────────────────────────────────────────────────────────────────────

export const adsShareCampaignCreate = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  // campagne de l'équipe (administrateur de la régie) : OFFERTE, aucun paiement, activée tout de suite ; les autres annonceurs achètent de l'audience
  const admin = await isRegieAdminAccount(request);
  const adv = (await db.collection("AdAdvertiserProfiles").doc(me.uid).get()).data();
  if (!admin) {
    if (!adv || !adv["brandName"]) throw new HttpsError("failed-precondition", "profil_manquant");
    if (adv["logoStatus"] !== "approved") throw new HttpsError("failed-precondition", adv["logoStatus"] === "rejected" ? "logo_refuse" : "profil_en_validation");
  }
  const v = validateAdInput({ kind: "entreprise", ...d }, BUCKET);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  const target = Math.round(Number(d["targetAudience"]));
  if (!Number.isFinite(target) || target < MIN_TARGET_AUDIENCE || target > MAX_TARGET_AUDIENCE) throw new HttpsError("invalid-argument", `audience à atteindre : entre ${MIN_TARGET_AUDIENCE} et ${MAX_TARGET_AUDIENCE} personnes`);
  if (!admin) {
    const mine = await db.collection("ShareCampaigns").where("ownerUid", "==", me.uid).limit(60).get();
    if (mine.docs.filter((x) => ["pending", "active"].includes(String(x.data()["status"]))).length >= 5) throw new HttpsError("resource-exhausted", "limite_atteinte");
  }
  const cfg = await cfgOf();
  // chaque clic valide consomme le plafond des gains pour le partageur ET la part du parrain (10 % en plus, comptée même sans parrain) : la marge de la campagne ne descend jamais sous 40 %
  const costPerClick = Math.round(cfg.perClickFcfa * (1 + cfg.sponsorPct / 100) * 100) / 100, p = audiencePricing(target, cfg.audiencePricePer1000Fcfa, cfg.userPct, costPerClick);
  const ref = db.collection("ShareCampaigns").doc(), t = now(), ad = v.value;
  const brand = admin ? String(d["brand"] ?? "").replace(/<[^>]*>/g, "").trim().slice(0, 60) || "Afrolook Ads" : String(adv?.["brandName"]);
  await ref.set({
    id: ref.id, ownerUid: me.uid, ownerEmail: me.email, brand, logoUrl: adv?.["logoUrl"] ?? "", title: ad.title, text: ad.text, mediaType: ad.mediaType, images: ad.images, videoUrl: ad.videoUrl, thumbnailUrl: ad.thumbnailUrl,
    action: ad.action, actionUrl: ad.actionUrl, countries: ad.countries, category: ad.category,
    // audience achetée, prix, plafond des gains versés aux partageurs (par clic valide : userFcfa ; chaque clic consomme ce plafond)
    targetAudience: target, listPriceFcfa: p.priceFcfa, priceFcfa: admin ? 0 : p.priceFcfa, free: admin, userFcfa: cfg.perClickFcfa, cpcFcfa: costPerClick, budgetFcfa: p.payoutBudgetFcfa,
    status: admin ? "active" : "pending", funded: admin, createdAt: t, updatedAt: t,
  });
  if (!admin) {
    await notifyAdminsAll({
      title: "📲 Campagne WhatsApp à valider", message: `${brand} veut atteindre ${target} personnes (prix ${p.priceFcfa} F). Ouvre la validation des campagnes : valide après réception du paiement.`, target: "ADMIN_ADS", refId: ref.id,
      email: { subject: "Campagne WhatsApp à valider", heading: "Nouvelle campagne Partage et gagne", icon: "📲", intro: "Un annonceur achète de l'audience pour une mission WhatsApp. Valide la campagne une fois le paiement reçu.", rows: [["Marque", brand], ["Audience à atteindre", String(target)], ["Prix", `${p.priceFcfa} F`]], tone: "info" },
    });
  }
  return { id: ref.id, status: admin ? "active" : "pending", free: admin, priceFcfa: admin ? 0 : p.priceFcfa, targetAudience: target };
});

/**
 * Audience touchée, avec ce qui est MESURÉ et ce qui est DÉCLARÉ :
 *  - provenReach : audience validée des partageurs dont la publication est prouvée (une vraie personne a ouvert leur lien), plafonnée à l'audience achetée ;
 *  - uniqueOpens : personnes qui ont ouvert le lien (une fois par jour et par personne) ; previews : lectures du lien par les messageries (pas des personnes) ;
 *  - declaredViews : vues déclarées par les partageurs (contrôlées pour leur vraisemblance, jamais présentées comme mesurées).
 */
const reachOf = (s: Record<string, unknown>, target: number): Record<string, number> => ({
  provenReach: Math.min(Number(s["provenReach"]) || 0, target || Infinity), sharersPublished: Number(s["sharersPublished"]) || 0,
  uniqueOpens: Number(s["uniqueOpens"]) || 0, opens: Number(s["opens"]) || 0, previews: Number(s["previews"]) || 0, declaredViews: Number(s["declaredViews"]) || 0,
});

/** Les campagnes de l'annonceur et leurs chiffres : visibles uniquement dans son espace. */
export const adsShareCampaignMine = onCall(OPTS, async (request) => {
  const me = requireGoogle(request);
  const snap = await db.collection("ShareCampaigns").where("ownerUid", "==", me.uid).limit(60).get();
  const items = await Promise.all(snap.docs.map(async (d) => {
    const v = d.data(), s = (await db.collection("AdShareStats").doc(d.id).get()).data() ?? {};
    const spent = Number(s["spentFcfa"]) || 0, budget = Number(v["budgetFcfa"]) || 0, target = Number(v["targetAudience"]) || 0, engaged = Number(s["allocatedReach"]) || 0;
    return { id: d.id, title: v["title"], status: v["status"], funded: v["funded"] === true, free: v["free"] === true, reason: v["reason"] ?? "", priceFcfa: Number(v["priceFcfa"]) || 0, listPriceFcfa: Number(v["listPriceFcfa"]) || 0, targetAudience: target, engagedAudience: Math.min(engaged, target), createdAt: v["createdAt"], clicks: Number(s["clicks"]) || 0, valid: Number(s["valid"]) || 0, sharers: Number(s["sharers"]) || 0, ...reachOf(s, target), usedPct: budget > 0 ? Math.min(100, Math.round((spent / budget) * 100)) : 0 };
  }));
  return { items: items.sort((a, b) => Number(b.createdAt) - Number(a.createdAt)) };
});

// ─── Partageur : profil ──────────────────────────────────────────────────────────────────────────────────────────────

const profOut = (p: FirebaseDocumentData) => ({ status: p["status"], reason: p["reason"] ?? "", whatsapp: p["whatsapp"], country: p["country"], city: p["city"], statusAudience: p["statusAudience"], telegramAudience: Number(p["telegramAudience"]) || 0, otherAudience: Number(p["otherAudience"]) || 0, groups: p["groups"] ?? [], about: p["about"], declared: declaredReach(p), retained: Number(p["audienceRetained"]) || 0, fraudHold: p["fraudHold"] === true });

export const adsShareProfileMe = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const [cfg, p] = await Promise.all([cfgOf(), db.collection("AdShareProfiles").doc(uid).get()]);
  const v = p.data();
  return { enabled: cfg.enabled, profile: v ? profOut(v) : null, rules: { version: SHARE_RULES_VERSION, accepted: v?.["rulesVersion"] === SHARE_RULES_VERSION, text: SHARE_RULES } };
});

export const adsShareProfileSave = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const cfg = await cfgOf();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "indisponible");
  const v = validateSharerProfile(request.data);
  if (!v.ok) throw new HttpsError("invalid-argument", v.error);
  const [userSnap, ofSnap] = await Promise.all([db.collection("Users").doc(uid).get(), db.collection("AppConfig").doc("offerwall").get()]);
  const why = blockReason(await userFacts(uid, userSnap.data()), readOfferwallConfig(ofSnap.data()), now());
  if (why) throw new HttpsError("failed-precondition", `compte : ${why}`);
  const ref = db.collection("AdShareProfiles").doc(uid), cur = (await ref.get()).data(), t = now();
  if (cur?.["status"] === "suspended") throw new HttpsError("permission-denied", "profil_suspendu");
  const reach = declaredReach(v.value);
  // un profil déjà validé reste validé si le numéro ne change pas et que l'audience déclarée n'augmente pas ; sinon il repasse en validation
  const keep = cur?.["status"] === "active" && cur["whatsapp"] === v.value.whatsapp && reach <= declaredReach(cur);
  const status = keep ? "active" : "pending";
  await ref.set({ ...v.value, uid, email: String(userSnap.data()?.["email"] ?? ""), name: String(userSnap.data()?.["pseudo"] ?? userSnap.data()?.["name"] ?? ""), status, reason: status === "pending" ? "" : cur?.["reason"] ?? "", audienceRetained: keep ? Math.min(Number(cur?.["audienceRetained"]) || 0, reach) : 0, rulesVersion: SHARE_RULES_VERSION, rulesAcceptedAt: t, createdAt: cur?.["createdAt"] ?? t, updatedAt: t }, { merge: true });
  if (status === "pending") {
    await notifyAdminsAll({
      title: "📲 Profil partageur à valider", message: `Un utilisateur a déclaré une audience WhatsApp de ${reach} personnes. Ouvre la validation des partageurs.`, target: "ADMIN_ADS", refId: uid,
      email: { subject: "Profil partageur WhatsApp à valider", heading: "Nouveau profil partageur", icon: "📲", intro: "Un utilisateur de l'application veut faire des missions Partage et gagne.", rows: [["Pays", v.value.country], ["Audience déclarée", String(reach)]], tone: "info" },
    });
  }
  return { ok: true, status };
});

// ─── Partageur : missions ───────────────────────────────────────────────────────────────────────────────────────────

export const adsShareList = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const cfg = await cfgOf();
  if (!cfg.enabled) return { enabled: false, items: [] };
  const today = dayOf(now());
  const [prof, camp, earn, links] = await Promise.all([
    db.collection("AdShareProfiles").doc(uid).get(),
    db.collection("ShareCampaigns").where("status", "==", "active").limit(40).get(),
    db.collection("AdShareEarnings").where("uid", "==", uid).limit(120).get(),
    db.collection("AdShareLinks").where("uid", "==", uid).limit(200).get(),
  ]);
  const reportsSnap = await db.collection("AdShareReports").where("uid", "==", uid).limit(100).get();
  const reportOf = new Map(reportsSnap.docs.map((r) => [String(r.data()["cid"]), Number(r.data()["views"]) || 0]));
  const resultsOf = (cid: string): Record<string, number> => {
    const mine = links.docs.map((l) => l.data()).filter((l) => l["campaignId"] === cid);
    const sum = (k: string): number => mine.reduce((n, l) => n + (Number(l[k]) || 0), 0);
    return { opens: sum("uniqueOpens"), valid: sum("valid"), views: reportOf.get(cid) ?? 0, published: mine.some((l) => l["proven"] === true) ? 1 : 0 };
  };
  let todayFcfa = 0, pendingFcfa = 0, paidCoins = 0, validClicks = 0;
  for (const d of earn.docs) { const v = d.data(), f = Number(v["fcfa"]) || 0; validClicks += Number(v["validClicks"]) || 0; if (v["day"] === today) todayFcfa += f; if (v["status"] === "pending") pendingFcfa += f; else paidCoins += Number(v["coins"]) || 0; }
  const status = String(prof.data()?.["status"] ?? "none");
  const joined = new Set(links.docs.map((l) => String(l.data()["campaignId"])));
  const items: Array<Record<string, unknown>> = [];
  if (status === "active") {
    for (const d of camp.docs) {
      if (d.data()["funded"] !== true) continue;
      const c = campaignOf(d.id, d.data(), cfg.userPct); if (!c) continue;
      const s = (await db.collection("AdShareStats").doc(d.id).get()).data() ?? {};
      const rem = remainingClicks(c.budgetFcfa, Number(s["spentFcfa"]) || 0, c.cpcFcfa);
      const open = campaignOpen(Number(s["allocatedReach"]) || 0, c.targetAudience, rem);
      if (!open && !joined.has(d.id)) continue; // campagne complète : plus de nouvelle participation
      items.push({ campaignId: d.id, brand: c.brand, title: c.title, text: c.text, cta: c.cta, image: c.image, video: c.video, mediaUrl: c.mediaUrl, userFcfa: c.userFcfa, coinsPerClick: Math.round(c.userFcfa * 2.5 * 10) / 10, joined: joined.has(d.id), countries: c.countries, results: joined.has(d.id) ? resultsOf(d.id) : null });
    }
  }
  const retained = Number(prof.data()?.["audienceRetained"]) || 0;
  // de quoi expliquer les gains dans l'application : valeur d'un clic, plafond du jour, part du parrain, estimation selon l'audience validée (estimation, jamais une promesse)
  return { enabled: true, profileStatus: status, dailyCapFcfa: cfg.dailyCapFcfa, holdHours: cfg.holdHours, perClickFcfa: cfg.perClickFcfa, coinsPerClick: Math.round(cfg.perClickFcfa * 2.5 * 10) / 10, sponsorPct: cfg.sponsorPct, expectedCtr: cfg.expectedCtr, retainedAudience: retained, me: { todayFcfa, pendingFcfa, paidCoins, validClicks }, items };
});

export const adsShareCreate = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const d = (request.data ?? {}) as Record<string, unknown>;
  const cid = String(d["campaignId"] ?? ""), channel = validChannel(d["channel"]), lang = d["lang"] === "en" ? "en" : "fr";
  if (!channel || !/^[A-Za-z0-9_-]{6,64}$/.test(cid)) throw new HttpsError("invalid-argument", "demande invalide");
  const cfg = await cfgOf();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "indisponible");
  const t = now(), today = dayOf(t);
  const [userSnap, ofSnap, profSnap, campDoc] = await Promise.all([db.collection("Users").doc(uid).get(), db.collection("AppConfig").doc("offerwall").get(), db.collection("AdShareProfiles").doc(uid).get(), db.collection("ShareCampaigns").doc(cid).get()]);
  const why = blockReason(await userFacts(uid, userSnap.data()), readOfferwallConfig(ofSnap.data()), t);
  if (why) throw new HttpsError("failed-precondition", `compte : ${why}`);
  const prof = profSnap.data();
  if (!prof || prof["status"] !== "active") throw new HttpsError("failed-precondition", "profil_a_valider");
  if (prof["rulesVersion"] !== SHARE_RULES_VERSION) throw new HttpsError("failed-precondition", "regles_a_accepter");
  const c = campaignOf(cid, campDoc.data(), cfg.userPct);
  if (!c || c.status !== "active" || campDoc.data()?.["funded"] !== true) throw new HttpsError("failed-precondition", "campagne_indisponible");
  const mine = await db.collection("AdShareLinks").where("uid", "==", uid).limit(200).get();
  const joined = mine.docs.some((x) => x.data()["campaignId"] === cid);
  let link = mine.docs.find((x) => x.data()["campaignId"] === cid && x.data()["channel"] === channel && t - Number(x.data()["createdAt"]) < 7 * 86_400_000);
  if (!link) {
    if (mine.docs.filter((x) => x.data()["day"] === today).length >= cfg.maxLinksPerDay) throw new HttpsError("resource-exhausted", "limite_du_jour");
    // contrôle de l'audience : une campagne dont l'audience engagée suffit à épuiser le budget n'accepte plus de nouveau partageur
    if (!joined) {
      const reach = Number(prof["audienceRetained"]) || 0;
      await db.runTransaction(async (tx) => {
        const sRef = db.collection("AdShareStats").doc(cid), s = (await tx.get(sRef)).data() ?? {};
        const rem = remainingClicks(c.budgetFcfa, Number(s["spentFcfa"]) || 0, c.cpcFcfa);
        if (!campaignOpen(Number(s["allocatedReach"]) || 0, c.targetAudience, rem)) throw new HttpsError("failed-precondition", "campagne_complete");
        tx.set(sRef, { allocatedReach: FieldValue.increment(reach), sharers: FieldValue.increment(1), title: c.title.slice(0, 80), updatedAt: t }, { merge: true });
      });
    }
    const key = await signingKey(), code = newCode();
    await db.collection("AdShareLinks").doc(code).create({ code, uid, campaignId: cid, channel, createdAt: t, day: today, creIp: ipHash(clientIp(request.rawRequest as never), today, key), clicks: 0, valid: 0, dayValid: { day: today, n: 0 } });
    link = await db.collection("AdShareLinks").doc(code).get() as FirebaseFirestore.QueryDocumentSnapshot;
  }
  const code = String(link.data()["code"]), url = `${SITE}/p/${code}/`;
  return { code, url, caption: captionFor(c.title, c.text, url, lang), video: c.video, mediaUrl: c.mediaUrl, image: c.image, channel };
});

// ─── Lien suivi : aperçu, page intermédiaire, clic ─────────────────────────────────────────────────────────────────

const page = (title: string, desc: string, image: string, body: string): string => `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title><meta name="robots" content="noindex,nofollow"><meta property="og:type" content="website"><meta property="og:title" content="${esc(title)}"><meta property="og:description" content="${esc(desc)}">${image ? `<meta property="og:image" content="${esc(image)}"><meta name="twitter:card" content="summary_large_image">` : ""}
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b0b0b;color:#fff;font:16px system-ui,sans-serif;text-align:center;padding:24px}small{color:#aaa;display:block;margin-top:14px}</style></head><body>${body}</body></html>`;

export const adsShareGo = onRequest({ ...OPTS, cors: true, maxInstances: 20 }, async (req, res) => {
  res.set("Cache-Control", "no-store");
  const code = req.path.split("/").filter(Boolean).pop() ?? "";
  if (!validCode(code)) { res.redirect(302, `${SITE}/ads/`); return; }
  try {
    const link = (await db.collection("AdShareLinks").doc(code).get()).data();
    const cfg = await cfgOf();
    const camp = link ? await loadCampaign(String(link["campaignId"]), cfg.userPct) : null;
    if (!link || !camp || camp.status !== "active") { res.redirect(302, `${SITE}/ads/`); return; }
    const key = await signingKey();
    if (req.method === "GET") {
      const ua0 = String(req.headers["user-agent"] ?? ""), preview0 = isPreviewAgent(ua0);
      await countLanding(code, link, camp, clientIp(req), ua0, key, preview0);
      if (preview0) { res.status(200).send(page(camp.title, camp.text, camp.image, `<p><b>${esc(camp.title)}</b></p><p>${esc(camp.text)}</p><a href="${esc(camp.dest)}" style="color:#ffb830">${esc(camp.cta)}</a>`)); return; }
      const tok = await signPage(code, key), dest = camp.dest;
      res.status(200).send(page(camp.title, camp.text, camp.image,
        `<div><p><b>${esc(camp.title)}</b></p><p>Redirection…</p><small>Pub · ce lien est suivi pour compter les clics, sans cookie.</small></div>
<noscript><meta http-equiv="refresh" content="3;url=${esc(dest)}"></noscript>
<script>(function(){var d=${JSON.stringify(dest).replace(/</g, "\\u003c")},t=${JSON.stringify(tok)},go=function(){location.replace(d)},v='';
try{v=localStorage.getItem('afv')||'';if(!v){v=(window.crypto&&crypto.randomUUID?crypto.randomUUID():(Math.random().toString(36).slice(2)+Date.now().toString(36)+Math.random().toString(36).slice(2)));localStorage.setItem('afv',v)}}catch(e){}
setTimeout(function(){var done=false,f=function(){if(!done){done=true;go()}};setTimeout(f,2500);
try{fetch(location.pathname,{method:'POST',headers:{'Content-Type':'text/plain'},body:JSON.stringify({t:t,v:v}),keepalive:true}).then(f,f)}catch(e){f()}},900)})();</script>`));
      return;
    }
    if (req.method !== "POST") { res.status(405).send("Method Not Allowed"); return; }
    const body = (() => { try { return JSON.parse(typeof req.body === "string" ? req.body : JSON.stringify(req.body ?? {})) as { t?: unknown; v?: unknown }; } catch { return {} as { t?: unknown; v?: unknown }; } })();
    const tk = verifyPage(body.t, key);
    if (!tk || tk.c !== code) { res.status(204).end(); return; }
    await registerShareClick(code, link, camp, tk.t, key, clientIp(req), String(req.headers["user-agent"] ?? ""), cfg, /^[A-Za-z0-9-]{12,64}$/.test(String(body.v ?? "")) ? String(body.v) : "");
    res.status(204).end();
  } catch (e) {
    console.error("[adsShareGo]", e);
    if (!res.headersSent) res.redirect(302, `${SITE}/ads/`);
  }
});

/**
 * Ouverture du lien, hors clic payé : c'est ce qui PROUVE que l'annonce a été publiée et qui mesure l'audience réellement touchée.
 *  - aperçu : un robot de messagerie (WhatsApp, Telegram…) a lu le lien au moment de la publication (compté à part, jamais une personne) ;
 *  - ouverture : une vraie personne arrive sur la page (comptée une fois par jour et par personne = ouvertures uniques) ;
 *  - publication prouvée : la première ouverture par une autre personne que le partageur ; l'audience validée de ce partageur est alors comptée comme « atteinte » (une seule fois par partageur et par campagne).
 * Ne bloque jamais la page : une erreur est journalisée et ignorée.
 */
async function countLanding(code: string, link: FirebaseDocumentData, c: Campaign, ip: string, ua: string, key: string, preview: boolean): Promise<void> {
  try {
    const t = now(), day = dayOf(t), uid = String(link["uid"]), cid = c.id;
    const linkRef = db.collection("AdShareLinks").doc(code), statRef = db.collection("AdShareStats").doc(cid);
    if (preview) {
      await Promise.all([linkRef.set({ previews: FieldValue.increment(1) }, { merge: true }), statRef.set({ previews: FieldValue.increment(1), title: c.title.slice(0, 80), updatedAt: t }, { merge: true })]);
      return;
    }
    const iph = ipHash(ip, day, key), vh = createHash("sha256").update(`v:${iph}:${ua}`).digest("hex").slice(0, 20);
    const self = link["day"] === day && link["creIp"] === iph;
    const seenRef = db.collection("AdShareSeen").doc(`${cid}_o_${vh}_${day}`), proofRef = db.collection("AdShareProof").doc(`${cid}_${uid}`);
    const retained = !self && link["proven"] !== true ? Number((await db.collection("AdShareProfiles").doc(uid).get()).data()?.["audienceRetained"]) || 0 : 0;
    await db.runTransaction(async (tx) => {
      const [seen, proof] = await Promise.all([tx.get(seenRef), self ? Promise.resolve(null) : tx.get(proofRef)]);
      const stat: Record<string, unknown> = { opens: FieldValue.increment(1), title: c.title.slice(0, 80), updatedAt: t }, lk: Record<string, unknown> = { opens: FieldValue.increment(1) };
      if (!seen.exists) { tx.create(seenRef, { cid, day, at: t }); stat["uniqueOpens"] = FieldValue.increment(1); lk["uniqueOpens"] = FieldValue.increment(1); }
      if (!self) {
        lk["proven"] = true;
        if (proof && !proof.exists) { tx.create(proofRef, { cid, uid, code, at: t, reach: retained }); stat["provenReach"] = FieldValue.increment(retained); stat["sharersPublished"] = FieldValue.increment(1); }
      }
      tx.set(statRef, stat, { merge: true });
      tx.set(linkRef, lk, { merge: true });
    });
  } catch (e) { console.error("[adsShare] ouverture", e); }
}

/**
 * Le partageur déclare combien de personnes ont vu sa publication (ex. « Vu par … » de son statut WhatsApp). Chiffre DÉCLARÉ, jamais présenté comme mesuré :
 * compté seulement si la publication est prouvée (une vraie personne a ouvert le lien) et plausible (au plus 1,5 fois son audience validée + 20), sinon gardé à part pour l'équipe.
 */
export const adsShareReport = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const d = (request.data ?? {}) as Record<string, unknown>, cid = String(d["campaignId"] ?? ""), views = Math.round(Number(d["views"]));
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(cid) || !Number.isFinite(views) || views < 0 || views > 1_000_000) throw new HttpsError("invalid-argument", "demande invalide");
  const [prof, proof, mineLinks] = await Promise.all([db.collection("AdShareProfiles").doc(uid).get(), db.collection("AdShareProof").doc(`${cid}_${uid}`).get(), db.collection("AdShareLinks").where("uid", "==", uid).where("campaignId", "==", cid).limit(1).get()]);
  if (mineLinks.empty) throw new HttpsError("failed-precondition", "mission_non_partagee");
  const retained = Number(prof.data()?.["audienceRetained"]) || 0, plausible = views <= Math.round(retained * 1.5) + 20, proven = proof.exists;
  const counted = proven && plausible ? views : 0;
  const repRef = db.collection("AdShareReports").doc(`${uid}_${cid}`), statRef = db.collection("AdShareStats").doc(cid), t = now();
  await db.runTransaction(async (tx) => {
    const old = Number((await tx.get(repRef)).data()?.["counted"]) || 0;
    tx.set(repRef, { uid, cid, views, counted, plausible, proven, updatedAt: t }, { merge: true });
    if (counted !== old) tx.set(statRef, { declaredViews: FieldValue.increment(counted - old), updatedAt: t }, { merge: true });
  });
  return { counted: counted > 0, proven, plausible };
});

const PLATFORMS = ["whatsapp", "telegram", "facebook", "tiktok", "other"];
const REASON_KEY: Record<string, keyof SharerMetrics> = { self: "self", dup: "dup", too_fast: "tooFast" };

async function registerShareClick(code: string, link: FirebaseDocumentData, c: Campaign, issuedAt: number, key: string, ip: string, ua: string, cfg: ShareConfig, vid: string): Promise<void> {
  if (!cfg.enabled) return;
  const t = now(), day = dayOf(t), uid = String(link["uid"]), cid = c.id, plat = platformOf((validChannel(link["channel"]) ?? "other"));
  const iph = ipHash(ip, day, key), vh = createHash("sha256").update(`v:${iph}:${ua}`).digest("hex").slice(0, 20), cc = countryOf(ip);
  const countryOk = !c.countries.length || c.countries.includes("ALL") || (cc !== null && c.countries.includes(cc));
  const linkRef = db.collection("AdShareLinks").doc(code);
  // un clic n'est compté qu'UNE fois par personne et par campagne : le même navigateur (identifiant local) à vie, la même adresse + le même appareil dans la journée,
  // quel que soit le lien ou le partageur par lequel il arrive
  const seenDay = db.collection("AdShareSeen").doc(`${cid}_d_${vh}_${day}`);
  const seenVid = vid ? db.collection("AdShareSeen").doc(`${cid}_v_${createHash("sha256").update(vid).digest("hex").slice(0, 24)}`) : null;
  const earnRef = db.collection("AdShareEarnings").doc(`${uid}_${day}_${plat}`), statRef = db.collection("AdShareStats").doc(cid);
  const dayRef = db.collection("AdShareSharerDay").doc(`${uid}_${day}`);
  const allEarn = PLATFORMS.map((p) => db.collection("AdShareEarnings").doc(`${uid}_${day}_${p}`));
  const bot = isPreviewAgent(ua);
  await db.runTransaction(async (tx) => {
    const [l, sd, sv, stat] = await Promise.all([tx.get(linkRef), tx.get(seenDay), seenVid ? tx.get(seenVid) : Promise.resolve(null), tx.get(statRef)]);
    const earns = await tx.getAll(...allEarn);
    const L = l.data() ?? link, S = stat.data() ?? {}, dv = (L["dayValid"] ?? {}) as { day?: string; n?: number };
    const decision = shareClickDecision({
      bot, visitMs: t - issuedAt, active: true, sameIpAsCreator: L["day"] === day ? L["creIp"] === iph : false, sinceCreationMs: t - Number(L["createdAt"]),
      firstForVisitor: !sd.exists && !(sv && sv.exists), countryOk, linkValidToday: dv.day === day ? Number(dv.n) || 0 : 0,
      userEarnedTodayFcfa: earns.reduce((n, e) => n + (Number(e.data()?.["fcfa"]) || 0), 0), userPayFcfa: c.userFcfa, costFcfa: c.cpcFcfa, spentFcfa: Number(S["spentFcfa"]) || 0, budgetFcfa: c.budgetFcfa,
    }, cfg);
    const base = { title: c.title.slice(0, 80), updatedAt: t };
    // comportement du partageur (les robots d'aperçu de lien ne comptent pas : WhatsApp et Telegram lisent chaque lien envoyé)
    if (!bot) {
      const m: Record<string, unknown> = { uid, day, total: FieldValue.increment(1), updatedAt: t };
      if (decision.valid) m["valid"] = FieldValue.increment(1);
      else { m["invalid"] = FieldValue.increment(1); const k = REASON_KEY[decision.reason]; if (k) m[k] = FieldValue.increment(1); }
      tx.set(dayRef, m, { merge: true });
    }
    if (!decision.valid) {
      tx.set(linkRef, { clicks: FieldValue.increment(1) }, { merge: true });
      tx.set(statRef, { ...base, clicks: FieldValue.increment(1), invalid: { [decision.reason]: FieldValue.increment(1) } }, { merge: true });
      return;
    }
    tx.create(seenDay, { cid, day, at: t });
    if (seenVid && !(sv && sv.exists)) tx.create(seenVid, { cid, at: t });
    tx.set(linkRef, { clicks: FieldValue.increment(1), valid: FieldValue.increment(1), dayValid: { day, n: (dv.day === day ? Number(dv.n) || 0 : 0) + 1 } }, { merge: true });
    tx.set(earnRef, { uid, day, platform: plat, status: "pending", validClicks: FieldValue.increment(1), fcfa: FieldValue.increment(c.userFcfa), hundredths: FieldValue.increment(hundredthsFor(c.userFcfa)), releaseAt: releaseAtFor(day, cfg.holdHours), updatedAt: t }, { merge: true });
    tx.set(statRef, { ...base, clicks: FieldValue.increment(1), valid: FieldValue.increment(1), spentFcfa: FieldValue.increment(c.cpcFcfa) }, { merge: true });
  });
}

// ─── Gains : de « en attente » à pièces, après la retenue ────────────────────────────────────────────────────────────

export const adsShareRollup = onSchedule({ ...OPTS, schedule: "every 60 minutes", timeoutSeconds: 240 }, async () => {
  const t = now(), cfg = await cfgOf();
  const snap = await db.collection("AdShareEarnings").where("status", "==", "pending").where("releaseAt", "<=", t).limit(100).get();
  let paid = 0;
  for (const d of snap.docs) {
    const uid = String(d.data()["uid"]);
    const sponsorId = (await sponsorOf(uid)) ?? null; // le parrain touche sa part comme sur les autres tâches (pris sur la marge d'Afrolook Ads, pas sur le gain du partageur)
    await db.runTransaction(async (tx) => {
      const e = await tx.get(d.ref), v = e.data();
      if (!v || v["status"] !== "pending") return;
      const userRef = db.collection("Users").doc(uid), stRef = db.collection("AdShareState").doc(uid), spRef = sponsorId ? db.collection("Users").doc(sponsorId) : null;
      const [u, st, sp] = await Promise.all([tx.get(userRef), tx.get(stRef), spRef ? tx.get(spRef) : Promise.resolve(null)]);
      if (!u.exists) { tx.update(d.ref, { status: "void", updatedAt: t }); return; }
      const sum = addHundredths(Number(st.data()?.["carry"]) || 0, Number(v["hundredths"]) || 0), n = Number(v["validClicks"]) || 0;
      const plat = String(v["platform"] ?? "other"), label = PLATFORM_LABEL[plat] ?? "Partage";
      const split = splitCoins(sum.coins, cfg.sponsorPct, !!sponsorId && !!sp?.exists);
      tx.set(stRef, { carry: sum.carry, updatedAt: t }, { merge: true });
      tx.update(d.ref, { status: "paid", coins: sum.coins, sponsorId: split.sponsor > 0 ? sponsorId : null, sponsorCoins: split.sponsor, paidAt: t, updatedAt: t });
      if (sum.coins > 0) {
        const pay = repayDebt(Number(u.data()?.["offerwallDebtCoins"]), sum.coins);
        tx.update(userRef, { giftCoinsBalance: FieldValue.increment(pay.credited), totalOfferwallCoinsEarned: FieldValue.increment(sum.coins), ...(pay.repaid > 0 ? { offerwallDebtCoins: FieldValue.increment(-pay.repaid) } : {}) });
        // même historique que les tâches (OfferwallEvents) : l'écran des tâches montre la plateforme d'où vient le gain (WhatsApp, Telegram…)
        tx.create(db.collection("OfferwallEvents").doc(eventId(PROVIDER, d.id)), { provider: PROVIDER, platform: plat, requestId: d.id, userId: uid, coins: sum.coins, sponsorId: split.sponsor > 0 ? sponsorId : null, sponsorCoins: split.sponsor, studioCoins: 0, status: "validee", validatedAt: t, createdAt: t, updatedAt: t, day: v["day"], clicks: n });
        const tRef = db.collection("TransactionSoldes").doc();
        tx.set(tRef, { id: tRef.id, user_id: uid, type: "GAIN_PIECES", statut: "VALIDER", description: `Partage ${label} — ${n} clic${n > 1 ? "s" : ""} valide${n > 1 ? "s" : ""} (${sum.coins} pièce${sum.coins > 1 ? "s" : ""})`, montant: sum.coins, frais: 0, montant_total: sum.coins, methode_paiement: "partage_" + plat, createdAt: t, updatedAt: t });
        if (spRef && sponsorId && split.sponsor > 0) {
          const sPay = repayDebt(Number(sp?.data()?.["offerwallDebtCoins"]), split.sponsor);
          tx.update(spRef, { giftCoinsBalance: FieldValue.increment(sPay.credited), totalCoinsEarnedFromSponsorship: FieldValue.increment(split.sponsor), ...(sPay.repaid > 0 ? { offerwallDebtCoins: FieldValue.increment(-sPay.repaid) } : {}) });
          const sRef = db.collection("TransactionSoldes").doc();
          tx.set(sRef, { id: sRef.id, user_id: sponsorId, type: "GAIN_PIECES", statut: "VALIDER", description: `Commission de parrainage (partage ${label} d'un filleul) — ${split.sponsor} pièces`, montant: split.sponsor, frais: 0, montant_total: split.sponsor, methode_paiement: "commission_parrainage", createdAt: t, updatedAt: t });
        }
      }
      paid++;
    }).catch((err) => console.error("[adsShareRollup]", d.id, err));
  }
  console.log("[adsShareRollup] gains validés", paid);
});

// ─── Fraude : détection automatique, blocage et retrait des gains ───────────────────────────────────────────────────

/** Retire les gains d'un partageur des [days] derniers jours : en attente annulés, pièces déjà versées reprises (reste en dette remboursée par les prochains gains), commission de parrainage reprise aussi. */
export async function reverseSharerEarnings(uid: string, by: string, reason: string, days = 30): Promise<{ cancelled: number; takenBack: number; debt: number }> {
  const t = now(), since = dayOf(t - days * 86_400_000);
  const snap = await db.collection("AdShareEarnings").where("uid", "==", uid).limit(300).get();
  let cancelled = 0, takenBack = 0, debt = 0;
  for (const d of snap.docs) {
    const v0 = d.data();
    if (String(v0["day"]) < since || !["pending", "held", "paid"].includes(String(v0["status"]))) continue;
    await db.runTransaction(async (tx) => {
      const e = await tx.get(d.ref), v = e.data();
      if (!v || !["pending", "held", "paid"].includes(String(v["status"]))) return;
      if (v["status"] !== "paid") { tx.update(d.ref, { status: "reversed", reversedAt: t, reversedBy: by, reversedReason: reason.slice(0, 200), updatedAt: t }); cancelled++; return; }
      const coins = Math.floor(Number(v["coins"]) || 0), spId = typeof v["sponsorId"] === "string" ? String(v["sponsorId"]) : "", spCoins = Math.floor(Number(v["sponsorCoins"]) || 0);
      const userRef = db.collection("Users").doc(uid), spRef = spId && spCoins > 0 ? db.collection("Users").doc(spId) : null;
      const [u, sp] = await Promise.all([tx.get(userRef), spRef ? tx.get(spRef) : Promise.resolve(null)]);
      const uTake = clawback(coins, Number(u.data()?.["giftCoinsBalance"]));
      tx.update(userRef, { giftCoinsBalance: FieldValue.increment(-uTake.take), totalOfferwallCoinsEarned: FieldValue.increment(-coins), ...(uTake.debt > 0 ? { offerwallDebtCoins: FieldValue.increment(uTake.debt) } : {}) });
      const tRef = db.collection("TransactionSoldes").doc();
      tx.set(tRef, { id: tRef.id, user_id: uid, type: "GAIN_PIECES", statut: "ANNULER", description: `Gains de partage retirés (fraude détectée) : -${coins} pièces${uTake.debt > 0 ? ` (dont ${uTake.debt} en dette)` : ""}`, montant: coins, frais: 0, montant_total: coins, methode_paiement: "annulation_partage", createdAt: t, updatedAt: t });
      if (spRef && sp?.exists) {
        const sTake = clawback(spCoins, Number(sp.data()?.["giftCoinsBalance"]));
        tx.update(spRef, { giftCoinsBalance: FieldValue.increment(-sTake.take), totalCoinsEarnedFromSponsorship: FieldValue.increment(-spCoins), ...(sTake.debt > 0 ? { offerwallDebtCoins: FieldValue.increment(sTake.debt) } : {}) });
      }
      const evRef = db.collection("OfferwallEvents").doc(eventId(PROVIDER, d.id));
      tx.set(evRef, { status: "refusee_admin", reason: "fraude détectée", updatedAt: t }, { merge: true });
      tx.update(d.ref, { status: "reversed", reversedAt: t, reversedBy: by, reversedReason: reason.slice(0, 200), updatedAt: t });
      takenBack += uTake.take; debt += uTake.debt; cancelled++;
    }).catch((err) => console.error("[adsShare] reprise", d.id, err));
  }
  return { cancelled, takenBack, debt };
}

/** Met en attente (blocage) ou libère les gains non versés d'un partageur. */
async function setHold(uid: string, hold: boolean): Promise<void> {
  const snap = await db.collection("AdShareEarnings").where("uid", "==", uid).limit(300).get();
  const from = hold ? "pending" : "held", to = hold ? "held" : "pending";
  await Promise.all(snap.docs.filter((d) => d.data()["status"] === from).map((d) => d.ref.update({ status: to, updatedAt: now() })));
  await db.collection("AdShareProfiles").doc(uid).set({ fraudHold: hold, updatedAt: now() }, { merge: true });
}

export const adsShareFraudScan = onSchedule({ ...OPTS, schedule: "every 60 minutes", timeoutSeconds: 240 }, async () => {
  const t = now(), today = dayOf(t), days = [today, dayOf(t - 86_400_000)];
  const snap = await db.collection("AdShareSharerDay").where("day", "in", days).limit(1000).get();
  const byUid = new Map<string, SharerMetrics>();
  for (const d of snap.docs) { const v = d.data(), u = String(v["uid"]); byUid.set(u, addMetrics(byUid.get(u) ?? EMPTY_METRICS, v as Partial<SharerMetrics>)); }
  for (const [uid, m] of byUid) {
    const r = detectSharerFraud(m);
    if (r.level === "none") continue;
    const prof = (await db.collection("AdShareProfiles").doc(uid).get()).data();
    if (!prof || prof["status"] === "suspended") continue;
    const alertRef = db.collection("AdsAlerts").doc(`${today}_share_${uid}_fraud`), first = !(await alertRef.get()).exists;
    await alertRef.set({ id: alertRef.id, day: today, pub: "whatsapp", pubName: `Partageur ${String(prof["name"] || uid.slice(0, 6))}`, adId: "", type: "share_fraud", severity: r.level === "severe" ? "high" : "medium", message: `Fraude possible : ${r.reasons.join(" ; ")}.`, metrics: { ...m }, status: "open", createdAt: t, updatedAt: t, autoHold: true }, { merge: true });
    if (r.level === "severe") {
      const out = await reverseSharerEarnings(uid, "robot", r.reasons.join(" ; "));
      await db.collection("AdShareProfiles").doc(uid).update({ status: "suspended", reason: "Fraude détectée automatiquement : " + r.reasons.join(" ; "), fraudHold: true, updatedAt: t });
      await notifyByEmail(String(prof["email"] ?? ""), { subject: "Ton profil partageur est suspendu", heading: "Profil suspendu", icon: "⛔", tone: "no", intro: `Nos contrôles ont détecté une fraude sur ton compte (${r.reasons.join(" ; ")}). Les gains concernés ont été retirés et ton profil est suspendu. Si tu penses à une erreur, réponds à cet e-mail.` }).catch(() => undefined);
      console.log("[adsShareFraudScan] fraude grave", uid, out);
    } else { await setHold(uid, true); }
    if (first) await notifyAdminsAll({ title: `${r.level === "severe" ? "🚨" : "⚠️"} Fraude possible : partageur`, message: `${r.reasons.join(" ; ")}. ${r.level === "severe" ? "Gains retirés et profil suspendu." : "Gains bloqués en attente de ta vérification."}`, target: "ADMIN_ADS", refId: uid });
  }
});

// ─── Administration ─────────────────────────────────────────────────────────────────────────────────────────────────────

export async function listSharers(status: string): Promise<Array<Record<string, unknown>>> {
  const base = db.collection("AdShareProfiles");
  const snap = await (status === "all" ? base.orderBy("createdAt", "desc") : base.where("status", "==", ["pending", "active", "refused", "suspended"].includes(status) ? status : "pending")).limit(200).get();
  return snap.docs.map((d) => ({ uid: d.id, email: d.data()["email"], name: d.data()["name"], createdAt: d.data()["createdAt"], ...profOut(d.data()) }));
}
export async function reviewSharer(adminUid: string, uid: string, decision: string, reason: string, audienceRetained: number): Promise<void> {
  const ref = db.collection("AdShareProfiles").doc(uid), p = (await ref.get()).data();
  if (!p) throw new Error("profil_inconnu");
  if (decision === "clear") { await setHold(uid, false); await db.collection("AdsAudit").add({ at: now(), by: adminUid, target: "sharer", id: uid, decision, reason: reason.slice(0, 300) }).catch(() => undefined); return; }
  if (decision === "fraud") {
    const out = await reverseSharerEarnings(uid, adminUid, reason || "fraude confirmée");
    await ref.update({ status: "suspended", reason: "Fraude confirmée : " + reason, fraudHold: true, reviewedBy: adminUid, reviewedAt: now(), updatedAt: now() });
    await db.collection("AdsAudit").add({ at: now(), by: adminUid, target: "sharer", id: uid, decision, reason: reason.slice(0, 300), ...out }).catch(() => undefined);
    return;
  }
  const status = ({ approve: "active", reactivate: "active", refuse: "refused", suspend: "suspended" } as Record<string, string>)[decision];
  if (!status) throw new Error("decision_invalide");
  const reach = declaredReach(p), retained = status === "active" ? Math.max(0, Math.min(Number.isFinite(audienceRetained) ? Math.round(audienceRetained) : reach, reach)) : 0;
  await ref.update({ status, reason: status === "active" ? "" : reason, audienceRetained: status === "active" ? retained : Number(p["audienceRetained"]) || 0, reviewedBy: adminUid, reviewedAt: now(), updatedAt: now() });
  await db.collection("AdsAudit").add({ at: now(), by: adminUid, target: "sharer", id: uid, decision, reason: reason.slice(0, 300) }).catch(() => undefined);
  const ok = status === "active";
  await notifyByEmail(String(p["email"] ?? ""), {
    subject: ok ? "Ton profil partageur est validé" : status === "refused" ? "Ton profil partageur n'a pas été accepté" : "Ton profil partageur est suspendu", heading: ok ? "Profil validé" : "Profil non validé", icon: ok ? "✅" : "⛔", tone: ok ? "ok" : "no",
    intro: ok ? "Ton profil partageur est validé : tu peux faire les missions Partage et gagne dans l'application." : `Ton profil n'a pas pu être validé. Motif : ${reason}`,
  }).catch((e) => console.error("[adsShare] mail", e));
}
export async function listCampaigns(status: string): Promise<Array<Record<string, unknown>>> {
  const base = db.collection("ShareCampaigns");
  const snap = await (status === "all" ? base.orderBy("createdAt", "desc") : base.where("status", "==", ["pending", "active", "paused", "refused", "ended"].includes(status) ? status : "pending")).limit(100).get();
  return Promise.all(snap.docs.map(async (d) => { const v = d.data(), s = (await db.collection("AdShareStats").doc(d.id).get()).data() ?? {}; return { id: d.id, brand: v["brand"], title: v["title"], text: v["text"], status: v["status"], funded: v["funded"] === true, free: v["free"] === true, targetAudience: v["targetAudience"], priceFcfa: v["priceFcfa"], listPriceFcfa: v["listPriceFcfa"], reason: v["reason"] ?? "", budgetFcfa: v["budgetFcfa"], cpcFcfa: v["cpcFcfa"], userFcfa: v["userFcfa"], countries: v["countries"], category: v["category"], actionUrl: v["actionUrl"], createdAt: v["createdAt"], ownerEmail: v["ownerEmail"], clicks: Number(s["clicks"]) || 0, valid: Number(s["valid"]) || 0, spentFcfa: Number(s["spentFcfa"]) || 0, sharers: Number(s["sharers"]) || 0, allocatedReach: Number(s["allocatedReach"]) || 0, ...reachOf(s, Number(v["targetAudience"]) || 0) }; }));
}
/** Décisions : approve (active la campagne, budget confirmé comme encaissé), refuse, pause, resume, end. */
export async function reviewCampaign(adminUid: string, id: string, decision: string, reason: string): Promise<void> {
  const ref = db.collection("ShareCampaigns").doc(id), v = (await ref.get()).data();
  if (!v) throw new Error("campagne_inconnue");
  const t = now();
  const upd: Record<string, unknown> = { reviewedBy: adminUid, reviewedAt: t, updatedAt: t };
  if (decision === "approve") Object.assign(upd, { status: "active", funded: true, reason: "" });
  else if (decision === "resume") Object.assign(upd, { status: "active" });
  else if (decision === "refuse") Object.assign(upd, { status: "refused", reason });
  else if (decision === "pause") Object.assign(upd, { status: "paused", reason });
  else if (decision === "end") Object.assign(upd, { status: "ended", reason });
  else throw new Error("decision_invalide");
  await ref.update(upd);
  await db.collection("AdsAudit").add({ at: t, by: adminUid, target: "share_campaign", id, decision, reason: reason.slice(0, 300) }).catch(() => undefined);
  if (decision === "approve" || decision === "refuse") {
    await notifyByEmail(String(v["ownerEmail"] ?? ""), {
      subject: decision === "approve" ? "Ta campagne WhatsApp est validée" : "Ta campagne WhatsApp n'a pas été acceptée", heading: decision === "approve" ? "Campagne validée" : "Campagne refusée", icon: decision === "approve" ? "✅" : "⛔", tone: decision === "approve" ? "ok" : "no",
      intro: decision === "approve" ? "Ta campagne est validée : elle est proposée comme mission aux partageurs de l'application, jusqu'à épuisement de ton budget." : `Ta campagne n'a pas pu être acceptée. Motif : ${reason}`,
      button: { label: "Ouvrir mon espace annonceur", url: `${SITE}/ads/espace/` },
    }).catch((e) => console.error("[adsShare] mail", e));
  }
}
