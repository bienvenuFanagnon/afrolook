import { SECTORS, logoUrlPattern, nextLogoStatus, selectPartners, validateAdvertiser } from "../adsAdvertisers_logic";

const BUCKET = "afrolooki.appspot.com";
const UID = "uid123ABC";
const logo = `https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_logos%2F${UID}%2Fb2a1c3d4.png?alt=media&token=abcdef12-3456-7890-abcd-ef1234567890`;
const base = { brandName: "Boutique Kofi", sector: "boutique", country: "tg", city: "Lomé", website: "https://kofi.com", whatsapp: "+228 90 12 34 56", about: "Vêtements et accessoires.", logoUrl: logo, partnerConsent: true };

describe("profil annonceur", () => {
  test("valide et normalisé", () => {
    const v = validateAdvertiser(base, UID, BUCKET);
    expect(v.ok).toBe(true);
    if (v.ok) { expect(v.value.country).toBe("TG"); expect(v.value.whatsapp).toBe("+22890123456"); expect(v.value.website).toBe("https://kofi.com/"); expect(v.value.logoUrl).toBe(logo); }
  });
  test("le logo est obligatoire et doit être dans le dossier de l'annonceur", () => {
    expect(validateAdvertiser({ ...base, logoUrl: "" }, UID, BUCKET)).toEqual({ ok: false, error: "logo obligatoire" });
    expect(validateAdvertiser({ ...base, logoUrl: logo.replace(UID, "autreUid") }, UID, BUCKET).ok).toBe(false); // logo d'un autre compte
    expect(validateAdvertiser({ ...base, logoUrl: "https://exemple.com/logo.png" }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, logoUrl: logo.replace("ad_logos", "ad_images") }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, logoUrl: logo + "&x=1" }, UID, BUCKET).ok).toBe(false);
  });
  test("accord d'affichage comme partenaire obligatoire", () => {
    expect(validateAdvertiser({ ...base, partnerConsent: false }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, partnerConsent: "oui" }, UID, BUCKET).ok).toBe(false);
  });
  test("autres champs", () => {
    expect(validateAdvertiser({ ...base, brandName: "K" }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, sector: "adulte" }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, country: "Togo" }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, city: "" }, UID, BUCKET).ok).toBe(true); // la ville est facultative
    expect(validateAdvertiser({ ...base, website: "http://kofi.com" }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, whatsapp: "12" }, UID, BUCKET).ok).toBe(false);
    expect(validateAdvertiser({ ...base, website: "", city: "", sector: "" }, UID, BUCKET).ok).toBe(true); // minimum : marque, logo, activité, contact, pays
    expect(validateAdvertiser({ ...base, whatsapp: "" }, UID, BUCKET).ok).toBe(false); // le contact est obligatoire
    expect(validateAdvertiser({ ...base, about: "" }, UID, BUCKET).ok).toBe(false); // ce qu'il fait : obligatoire
    expect(validateAdvertiser({ ...base, about: "trop court" }, UID, BUCKET).ok).toBe(false);
    const d = validateAdvertiser({ ...base, sector: "" }, UID, BUCKET); expect(d.ok && d.value.sector).toBe("autre");
    expect(Object.keys(SECTORS)).toContain("technologie");
  });
  test("motif de l'adresse du logo : caractères spéciaux d'un identifiant neutralisés", () => {
    expect(logoUrlPattern(BUCKET, "a.b").test(logo.replace(UID, "a.b"))).toBe(true);
    expect(logoUrlPattern(BUCKET, "a.b").test(logo.replace(UID, "aXb"))).toBe(false);
  });
});

describe("statut du logo", () => {
  test("un nouveau logo repasse en validation, le même logo garde son statut", () => {
    expect(nextLogoStatus(undefined, undefined, "u1")).toBe("pending");
    expect(nextLogoStatus("u1", "approved", "u1")).toBe("approved");
    expect(nextLogoStatus("u1", "pending", "u1")).toBe("pending");
    expect(nextLogoStatus("u1", "approved", "u2")).toBe("pending");
    expect(nextLogoStatus("u1", "rejected", "u1")).toBe("pending"); // renvoyé après refus : revalidation
    expect(nextLogoStatus("u1", "approved", "u1", false)).toBe("pending"); // nouveau nom de marque : tout le profil repasse en validation
  });
});

describe("partenaires affichés", () => {
  const mk = (uid: string, over: Record<string, unknown> = {}) => ({ uid, brandName: `Marque ${uid}`, logoUrl: `https://x/${uid}.png`, logoStatus: "approved", partnerConsent: true, website: "https://m.com", ...over });
  test("logo validé + accord + annonce en ligne, une seule fois", () => {
    const p = selectPartners([mk("a"), mk("b", { logoStatus: "pending" }), mk("c", { partnerConsent: false }), mk("d"), mk("a"), mk("e", { logoStatus: "rejected" }), mk("f", { logoUrl: "" })], new Set(["a", "b", "c", "e", "f"]));
    expect(p.map((x) => x.name)).toEqual(["Marque a"]); // d : pas d'annonce en ligne ; b, e : logo non validé ; c : pas d'accord ; f : sans logo
  });
  test("adresse du site seulement en https ; plafond", () => {
    const p = selectPartners([mk("a", { website: "http://m.com" }), mk("b", { website: "" })], new Set(["a", "b"]));
    expect(p.every((x) => x.url === "")).toBe(true);
    const many = Array.from({ length: 60 }, (_, i) => mk(`u${i}`));
    expect(selectPartners(many, new Set(many.map((m) => m.uid)), 40)).toHaveLength(40);
  });
});
