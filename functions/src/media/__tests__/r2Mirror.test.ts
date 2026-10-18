jest.mock("firebase-functions/v2/scheduler", () => ({ onSchedule: jest.fn(() => ({})) }));
jest.mock("firebase-admin/storage", () => ({ getStorage: jest.fn() }));
jest.mock("../../shared/firebase", () => ({ db: {} }));

import { shouldMirror, updatedMs } from "../r2Mirror";

describe("miroir R2 : quels fichiers", () => {
  it("copie les médias publics et les fichiers de chat", () => {
    for (const n of ["post_media/a.jpg", "post_videos/video_x_1.mp4", "chat_images/c.png", "user_profile/u.jpg", "thumbnails/t.jpg"]) expect(shouldMirror(n)).toBe(true);
  });
  it("ne copie jamais les liens temporaires, les titres payants ni les versions de test", () => {
    for (const n of ["artist_sound_tmp/x.m4a", "artist_sounds/full.m4a", "test-builds/app.apk", "test_builds/app.apk"]) expect(shouldMirror(n)).toBe(false);
  });
  it("ignore les dossiers et les noms vides", () => {
    expect(shouldMirror("")).toBe(false);
    expect(shouldMirror("post_media/")).toBe(false);
  });
});

describe("miroir R2 : date d'un fichier de la liste", () => {
  it("lit les dates dans metadata (liste complète) ou sur le fichier (liste allégée)", () => {
    expect(updatedMs({ metadata: { updated: "2026-10-18T10:00:00.000Z" } })).toBe(Date.parse("2026-10-18T10:00:00.000Z"));
    expect(updatedMs({ updated: "2026-10-18T11:00:00.000Z", timeCreated: "2026-10-18T09:00:00.000Z" })).toBe(Date.parse("2026-10-18T11:00:00.000Z"));
    expect(updatedMs({ timeCreated: "2026-10-18T09:00:00.000Z" })).toBe(Date.parse("2026-10-18T09:00:00.000Z"));
  });
  it("renvoie 0 quand il n'y a aucune date : le fichier est alors ignoré, jamais copié par erreur", () => {
    expect(updatedMs({})).toBe(0);
    expect(updatedMs({ updated: "n'importe quoi" })).toBe(0);
  });
});
