jest.mock("../../shared/firebase", () => ({ db: {} }));
jest.mock("../../shared/email_utils", () => ({ emailTransporter: {} }));
import { cleanContact } from "../contact";

describe("cleanContact", () => {
  const ok = { name: "Aminata K", email: "Aminata@Exemple.com ", subject: "Presse", message: "Bonjour, une question sur les retraits.", lang: "fr" };
  it("accepte un message valide et normalise l'e-mail", () => {
    expect(cleanContact(ok)).toEqual({ name: "Aminata K", email: "aminata@exemple.com", subject: "Presse", message: "Bonjour, une question sur les retraits.", lang: "fr" });
  });
  it("refuse un nom ou un message trop court, un e-mail invalide", () => {
    expect(cleanContact({ ...ok, name: "A" })).toBeNull();
    expect(cleanContact({ ...ok, message: "court" })).toBeNull();
    expect(cleanContact({ ...ok, email: "pas-un-mail" })).toBeNull();
    expect(cleanContact(null)).toBeNull();
  });
  it("remplace un sujet inconnu par « Autre » et accepte l'anglais", () => {
    expect(cleanContact({ ...ok, subject: "<script>" })?.subject).toBe("Autre");
    expect(cleanContact({ ...ok, subject: "Press", lang: "en" })).toMatchObject({ subject: "Press", lang: "en" });
  });
  it("coupe les textes trop longs", () => {
    expect(cleanContact({ ...ok, message: "x".repeat(5000) })?.message.length).toBe(3000);
  });
});
