/**
 * Afrolook Ads : profil annonceur. Logique pure, testée dans __tests__/adsAdvertisers.test.ts.
 *
 * Chaque annonceur remplit un profil de marque AVANT de publier. Minimum demandé : nom de l'entreprise ou de la marque, LOGO, ce qu'il fait (présentation),
 * contact (WhatsApp ; l'e-mail est celui du compte Google) et pays. Le secteur, la ville et le site web sont facultatifs.
 * Le logo (validé par l'administration) est affiché comme celui d'un partenaire sur afrolookmedia.com, avec l'accord de l'annonceur.
 * Par défaut, les partenaires affichés sont nos propres plateformes : Afrolook, SlashAtlas et Épargne+.
 */
import { cleanSiteUrl } from "./adsPublishers_logic";

export const SECTORS: Record<string, string> = {
  boutique: "Boutique et commerce",
  restauration: "Restauration et alimentation",
  mode: "Mode et beauté",
  services: "Services aux particuliers et aux entreprises",
  technologie: "Technologie, applications, sites web",
  immobilier: "Immobilier et construction",
  education: "Éducation et formation",
  sante: "Santé et bien-être",
  finance: "Finance et assurance",
  evenement: "Événements, musique, spectacles",
  medias: "Médias et créateurs de contenu",
  association: "Association, ONG, institution",
  autre: "Autre",
};

export type LogoStatus = "pending" | "approved" | "rejected";
export interface AdvertiserInput { brandName: string; sector: string; country: string; city: string; website: string; whatsapp: string; about: string; logoUrl: string; partnerConsent: true }
type Res<T> = { ok: true; value: T } | { ok: false; error: string };

const clean = (v: unknown, n: number): string => String(v ?? "").replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim().slice(0, n);

/** Le logo est déposé par l'annonceur dans SON dossier du stockage : ad_logos/<uid>/<fichier>. */
export function logoUrlPattern(bucket: string, uid: string): RegExp {
  const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(`^https://firebasestorage\\.googleapis\\.com/v0/b/${esc(bucket)}/o/ad_logos%2F${esc(uid)}%2F[A-Za-z0-9._-]{1,100}\\?alt=media&token=[A-Za-z0-9-]{8,80}$`);
}

export function validateAdvertiser(d: unknown, uid: string, bucket: string): Res<AdvertiserInput> {
  const o = (d ?? {}) as Record<string, unknown>;
  const brandName = clean(o["brandName"], 60);
  if (brandName.length < 2) return { ok: false, error: "nom de la marque manquant" };
  const sector = String(o["sector"] ?? "") || "autre";
  if (!Object.prototype.hasOwnProperty.call(SECTORS, sector)) return { ok: false, error: "secteur invalide" };
  const country = String(o["country"] ?? "").toUpperCase();
  if (!/^[A-Z]{2}$/.test(country)) return { ok: false, error: "pays manquant" };
  const city = clean(o["city"], 60);
  const about = clean(o["about"], 200);
  if (about.length < 20) return { ok: false, error: "présente ton activité en 20 caractères au moins" };
  const wRaw = String(o["website"] ?? "").trim();
  const website = wRaw ? cleanSiteUrl(wRaw) : "";
  if (wRaw && !website) return { ok: false, error: "adresse du site invalide (https obligatoire)" };
  const waRaw = String(o["whatsapp"] ?? "").replace(/[^\d+]/g, "");
  if (!/^\+?\d{8,15}$/.test(waRaw)) return { ok: false, error: "numéro WhatsApp invalide ou manquant" };
  const logoUrl = String(o["logoUrl"] ?? "").trim();
  if (!logoUrl) return { ok: false, error: "logo obligatoire" };
  if (!logoUrlPattern(bucket, uid).test(logoUrl)) return { ok: false, error: "logo non reconnu" };
  if (o["partnerConsent"] !== true) return { ok: false, error: "accord d'affichage du logo à donner" };
  return { ok: true, value: { brandName, sector, country, city, website: website ?? "", whatsapp: waRaw, about, logoUrl, partnerConsent: true } };
}

/** Statut du PROFIL annonceur après une modification : un nouveau logo ou un nouveau nom de marque repasse en validation ; sinon le statut est conservé (le champ garde son ancien nom « logoStatus »). */
export function nextLogoStatus(prevUrl: unknown, prevStatus: unknown, newUrl: string, sameBrand = true): LogoStatus {
  if (sameBrand && prevUrl === newUrl && (prevStatus === "approved" || prevStatus === "pending")) return prevStatus;
  return "pending";
}

export interface Partner { name: string; logo: string; url: string }
/** Partenaires affichés : l'annonceur doit avoir un logo validé, avoir donné son accord et avoir au moins une annonce en ligne. Une seule fois par annonceur. */
export function selectPartners(profiles: Array<{ uid: string; brandName?: string; logoUrl?: string; logoStatus?: string; partnerConsent?: boolean; website?: string }>, activeUids: Set<string>, max = 40): Partner[] {
  const out: Partner[] = [];
  const seen = new Set<string>();
  for (const p of profiles) {
    if (!p.uid || seen.has(p.uid) || !activeUids.has(p.uid)) continue;
    if (p.logoStatus !== "approved" || p.partnerConsent !== true || !p.logoUrl || !p.brandName) continue;
    seen.add(p.uid);
    out.push({ name: String(p.brandName), logo: String(p.logoUrl), url: p.website && /^https:\/\//.test(p.website) ? p.website : "" });
    if (out.length >= max) break;
  }
  return out;
}
