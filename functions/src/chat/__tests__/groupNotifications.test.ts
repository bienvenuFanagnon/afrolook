jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({}) }));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: {} }));

import { groupPushContent, groupPushText } from "../groupNotifications";
import { safeChatImage } from "../../shared/preview";

describe("notifications de messages de groupe", () => {
  test("texte d'un membre : « @pseudo : message », identité du groupe pour un administrateur", () => {
    expect(groupPushText("Les Afros", "Aïcha", false, "Salut, tu es là ?")).toEqual({ title: "Les Afros", message: "@Aïcha : Salut, tu es là ?" });
    expect(groupPushText("Les Afros", "Aïcha", true, "Réunion à 18 h")).toEqual({ title: "Les Afros", message: "Réunion à 18 h" });
    expect(groupPushText("", "Aïcha", false, "Coucou").title).toBe("Afrolook");
  });

  test("types de messages : texte coupé, photo avec aperçu, partages", () => {
    expect(groupPushContent({ message_type: "text", message: "Salut   à tous" })).toEqual({ preview: "Salut à tous", image: "" });
    expect(groupPushContent({ message_type: "text", message: "x".repeat(300) }).preview).toHaveLength(100);
    const url = "https://firebasestorage.googleapis.com/v0/b/x/o/p.jpg?alt=media";
    expect(groupPushContent({ message_type: "image", message: url })).toEqual({ preview: "📷 Photo", image: url });
    expect(groupPushContent({ message_type: "multi_image", message: url, image_urls: [url, url] })).toEqual({ preview: "📷 Photos", image: url });
    expect(groupPushContent({ message_type: "video" })).toEqual({ preview: "🎥 Vidéo", image: "" });
    expect(groupPushContent({ message_type: "post", message: "Mon beau post" }).preview).toBe("📎 Mon beau post");
    expect(groupPushContent({ message_type: "post", message: "" }).preview).toBe("📎 Post partagé");
    expect(groupPushContent({ message_type: "link_share", item_title: "Sac en cuir", item_thumbnail: url })).toEqual({ preview: "📎 Sac en cuir", image: url });
  });

  test("aperçu photo : seulement nos hébergeurs en https", () => {
    expect(safeChatImage("https://cdn.afrolookmedia.com/media/a.jpg")).toBe("https://cdn.afrolookmedia.com/media/a.jpg");
    expect(safeChatImage("https://exemple.com/a.jpg")).toBe("");
    expect(safeChatImage("http://firebasestorage.googleapis.com/a.jpg")).toBe("");
    expect(safeChatImage("https://firebasestorage.googleapis.com.evil.com/a.jpg")).toBe("");
    expect(safeChatImage(undefined)).toBe("");
  });
});
