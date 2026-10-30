import { createHmac } from "crypto";
import { COINS_PER_USD, ayetAmountsCoherent, ayetSignedStrings, ayetVerify } from "../offerwall_logic";

const params = { transaction_id: "abc123", external_identifier: "uid42", currency_amount: "375", payout_usd: "0.50", is_chargeback: "0", callback_type: "conversion", offer_name: "Puzzle Kingdom" };
const sign = (s: string, key = "cle-de-test"): string => createHmac("sha256", key).update(s, "utf8").digest("hex");

describe("signature ayeT (HMAC-SHA256, paramètres triés)", () => {
  test("écriture « k=v&k=v » triée : reconnue", () => {
    const s = ayetSignedStrings(params)[0];
    expect(s.startsWith("callback_type=conversion&currency_amount=375&external_identifier=uid42")).toBe(true);
    expect(ayetVerify(params, sign(s), "cle-de-test")).toBe(0);
  });
  test("valeurs encodées (espace) : reconnues par une autre écriture", () => {
    const s = ayetSignedStrings(params)[1];
    expect(s).toContain("offer_name=Puzzle%20Kingdom");
    expect(ayetVerify(params, sign(s), "cle-de-test")).toBe(1);
    expect(ayetSignedStrings(params)[2]).toContain("offer_name=Puzzle+Kingdom");
  });
  test("mauvaise clé, montant modifié, en-tête vide : refusés", () => {
    const h = sign(ayetSignedStrings(params)[0]);
    expect(ayetVerify(params, h, "autre-cle")).toBe(-1);
    expect(ayetVerify({ ...params, currency_amount: "99999" }, h, "cle-de-test")).toBe(-1);
    expect(ayetVerify(params, "", "cle-de-test")).toBe(-1);
    expect(ayetVerify(params, h, "")).toBe(-1);
  });
  test("signature en majuscules ou en base64 acceptée", () => {
    const s = ayetSignedStrings(params)[0];
    expect(ayetVerify(params, sign(s).toUpperCase(), "cle-de-test")).toBe(0);
    expect(ayetVerify(params, createHmac("sha256", "cle-de-test").update(s).digest("base64"), "cle-de-test")).toBe(0);
  });
});

describe("cohérence pièces / paiement en dollars", () => {
  test("750 pièces par dollar", () => {
    expect(COINS_PER_USD).toBe(750);
    expect(ayetAmountsCoherent(375, "0.50")).toBe(true);
    expect(ayetAmountsCoherent(225, "0.30")).toBe(true);
  });
  test("montant gonflé : incohérent ; sans paiement exploitable : on ne juge pas", () => {
    expect(ayetAmountsCoherent(3750, "0.50")).toBe(false);
    expect(ayetAmountsCoherent(3750, "")).toBe(true);
    expect(ayetAmountsCoherent(3750, "-0.5")).toBe(true);
  });
});

import { repayDebt, takeBack } from "../offerwall_logic";

describe("annulation après validation : reprise et dette", () => {
  test("solde suffisant : tout est repris, aucune dette", () => {
    expect(takeBack(1500, 1000)).toEqual({ taken: 1000, debt: 0 });
  });
  test("solde insuffisant : on reprend ce qui reste, le manque devient une dette", () => {
    expect(takeBack(300, 1000)).toEqual({ taken: 300, debt: 700 });
    expect(takeBack(0, 200)).toEqual({ taken: 0, debt: 200 });
  });
  test("valeurs aberrantes : jamais négatif, toujours entier", () => {
    expect(takeBack(-50, 100)).toEqual({ taken: 0, debt: 100 });
    expect(takeBack(NaN, 100)).toEqual({ taken: 0, debt: 100 });
    expect(takeBack(10.9, 20.7)).toEqual({ taken: 10, debt: 10 });
  });
  test("un gain rembourse d'abord la dette", () => {
    expect(repayDebt(700, 400)).toEqual({ repaid: 400, credited: 0 });
    expect(repayDebt(700, 1000)).toEqual({ repaid: 700, credited: 300 });
    expect(repayDebt(0, 250)).toEqual({ repaid: 0, credited: 250 });
  });
  test("aucune dette ou valeurs invalides", () => {
    expect(repayDebt(undefined as unknown as number, 100)).toEqual({ repaid: 0, credited: 100 });
    expect(repayDebt(50, -5)).toEqual({ repaid: 0, credited: 0 });
  });
});
