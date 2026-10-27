jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/storage", () => ({ getStorage: () => ({}) }));

import fs from "fs";
import path from "path";
import sharp from "sharp";
import { AVATAR_COLORS, AVATAR_SIZE, avatarPng, avatarSvg, glyphTransform } from "../avatars";
import { GLYPHS } from "../avatarGlyphs";
import { NEWS_AGENTS } from "../agents";

describe("photos de profil des agents", () => {
  test("une couleur et une icône pour chacun des 8 agents, plus le badge journal", () => {
    for (const a of NEWS_AGENTS) {
      expect(AVATAR_COLORS[a.key]).toMatch(/^#[0-9A-F]{6}$/);
      expect(GLYPHS[a.key].d.length).toBeGreaterThan(100);
    }
    expect(GLYPHS["journal"].d.length).toBeGreaterThan(100);
    expect(new Set(Object.values(AVATAR_COLORS)).size).toBe(8); // aucune couleur en double : on reconnaît un agent d'un coup d'œil
  });

  test("dessin : fond sombre, cercle teinté, icône du domaine et badge vert", () => {
    const svg = avatarSvg("sport");
    expect(svg).toContain(AVATAR_COLORS["sport"]);
    expect(svg).toContain('fill="#2ECC71" stroke="#0E0E0E"'); // badge journal
    expect(svg.match(/<path /g)).toHaveLength(2);
    expect(() => avatarSvg("inconnu")).toThrow();
  });

  test("l'icône est centrée à la taille demandée", () => {
    const g = { d: "", x1: 100, y1: -900, x2: 900, y2: -100 }; // boîte de 800 × 800
    expect(glyphTransform(g, 400, 256, 256)).toBe("translate(256 256) scale(0.50000) translate(-500.00 500.00)");
  });

  test("image PNG carrée de 512 pixels, pour chaque agent", async () => {
    for (const a of NEWS_AGENTS) {
      const png = await avatarPng(a.key);
      const meta = await sharp(png).metadata();
      expect([meta.format, meta.width, meta.height]).toEqual(["png", AVATAR_SIZE, AVATAR_SIZE]);
      // le coin reste sombre (fond) : le recadrage en rond ne montre rien d'autre que le cercle
      const { data } = await sharp(png).extract({ left: 2, top: 2, width: 1, height: 1 }).raw().toBuffer({ resolveWithObject: true });
      expect(data[0] + data[1] + data[2]).toBeLessThan(60);
      if (process.env.AVATAR_DUMP) fs.writeFileSync(path.join(process.env.AVATAR_DUMP, `${a.key}.png`), png);
    }
  });
});
