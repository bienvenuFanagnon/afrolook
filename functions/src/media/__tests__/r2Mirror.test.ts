jest.mock("firebase-functions/v2/scheduler", () => ({ onSchedule: jest.fn(() => ({})) }));
jest.mock("firebase-admin/storage", () => ({ getStorage: jest.fn() }));
jest.mock("../../shared/firebase", () => ({ db: {} }));

import { shouldMirror } from "../r2Mirror";

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
