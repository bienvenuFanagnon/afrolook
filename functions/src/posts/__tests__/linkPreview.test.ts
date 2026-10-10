import { firstUrl, isPrivateIp, providerOf, parseMeta } from "../linkPreview";

describe("linkPreview", () => {
  it("trouve le premier lien et retire la ponctuation finale", () => {
    expect(firstUrl("Regardez ça https://youtu.be/abc123, génial #video")).toBe("https://youtu.be/abc123");
    expect(firstUrl("(https://www.tiktok.com/@a/video/1).")).toBe("https://www.tiktok.com/@a/video/1");
    expect(firstUrl("aucun lien ici")).toBeNull();
  });

  it("refuse les adresses internes", () => {
    for (const ip of ["127.0.0.1", "10.0.0.5", "192.168.1.1", "172.20.0.1", "169.254.169.254", "100.64.0.1", "::1", "fd00::1", "::ffff:10.0.0.1", "0.0.0.0"]) expect(isPrivateIp(ip)).toBe(true);
    for (const ip of ["8.8.8.8", "142.250.74.14", "2a00:1450:4007:80d::200e"]) expect(isPrivateIp(ip)).toBe(false);
    expect(isPrivateIp("pas-une-ip")).toBe(true);
  });

  it("reconnaît les réseaux", () => {
    expect(providerOf("www.youtube.com")).toBe("youtube");
    expect(providerOf("youtu.be")).toBe("youtube");
    expect(providerOf("vm.tiktok.com")).toBe("tiktok");
    expect(providerOf("www.instagram.com")).toBe("instagram");
    expect(providerOf("fb.watch")).toBe("facebook");
    expect(providerOf("exemple.org")).toBe("web");
    expect(providerOf("evil-youtube.com.attaquant.io")).toBe("web");
  });

  it("lit les balises Open Graph et le titre", () => {
    const m = parseMeta(`<html><head><title> Ma page &amp; moi </title><meta property="og:title" content="Titre &quot;OG&quot;"><meta name='description' content='Une description'><meta property="og:image" content="https://x.test/i.jpg"></head>`);
    expect(m["og:title"]).toBe('Titre "OG"');
    expect(m["description"]).toBe("Une description");
    expect(m["og:image"]).toBe("https://x.test/i.jpg");
    expect(m["_title"]).toBe("Ma page & moi");
  });
});
