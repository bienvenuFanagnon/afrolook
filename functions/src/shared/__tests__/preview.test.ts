jest.mock("../firebase", () => ({ db: {} }));

import { previewFromChronique, previewFromPost, previewFromSound } from "../preview";

describe("aperçu des contenus", () => {
  test("post image : première photo ; post vidéo : miniature ; post texte : rien", () => {
    expect(previewFromPost({ dataType: "IMAGE", images: ["https://cdn.exemple.com/a.jpg", "https://cdn.exemple.com/b.jpg"] })).toBe("https://cdn.exemple.com/a.jpg");
    expect(previewFromPost({ dataType: "IMAGE", images: [], url_media: "https://cdn.exemple.com/m.jpg" })).toBe("https://cdn.exemple.com/m.jpg");
    expect(previewFromPost({ dataType: "VIDEO", thumbnail: "https://cdn.exemple.com/t.jpg", url_media: "https://cdn.exemple.com/v.mp4" })).toBe("https://cdn.exemple.com/t.jpg");
    expect(previewFromPost({ dataType: "VIDEO", url_media: "https://cdn.exemple.com/v.mp4" })).toBe(""); // jamais le fichier vidéo lui-même
    expect(previewFromPost({ dataType: "TEXT", description: "bonjour" })).toBe("");
    expect(previewFromPost(undefined)).toBe("");
  });
  test("adresses non sûres refusées", () => {
    expect(previewFromPost({ dataType: "IMAGE", images: ["http://exemple.com/a.jpg"] })).toBe("");
    expect(previewFromPost({ dataType: "IMAGE", images: ["javascript:alert(1)"] })).toBe("");
  });
  test("chronique : affiche, sinon média d'une image, sinon pochette ; texte : rien", () => {
    expect(previewFromChronique({ type: "TEXT" })).toBe("");
    expect(previewFromChronique({ type: "IMAGE", mediaUrl: "https://cdn.exemple.com/i.jpg" })).toBe("https://cdn.exemple.com/i.jpg");
    expect(previewFromChronique({ type: "VIDEO", coverImageUrl: "https://cdn.exemple.com/c.jpg", mediaUrl: "https://cdn.exemple.com/v.mp4" })).toBe("https://cdn.exemple.com/c.jpg");
    expect(previewFromChronique({ type: "VIDEO", posterUrl: "https://cdn.exemple.com/p.jpg" })).toBe("https://cdn.exemple.com/p.jpg");
  });
  test("musique : pochette", () => {
    expect(previewFromSound({ coverImageUrl: "https://cdn.exemple.com/cover.jpg" })).toBe("https://cdn.exemple.com/cover.jpg");
    expect(previewFromSound({})).toBe("");
  });
});
