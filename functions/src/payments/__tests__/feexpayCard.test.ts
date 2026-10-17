jest.mock("../../shared/firebase", () => ({ db: { collection: jest.fn() } }));
jest.mock("../../shared/config", () => ({
  FEEXPAY_API_KEY_AFROLOOK: "k", FEEXPAY_SHOP_ID_AFROLOOK: "s", EMAIL_FROM: "x", EMAIL_REPLY_TO: "y",
}));
jest.mock("../paymentLog", () => ({ logPayment: jest.fn() }));
jest.mock("../../shared/admin_notify", () => ({ notifyAdmins: jest.fn() }));
jest.mock("../../shared/email_utils", () => ({ emailTransporter: {} }));

import { cardQuote, CARD_DEFAULTS } from "../feexpayCard";

describe("prix par carte", () => {
  const cfg = CARD_DEFAULTS;
  const price = (coins: number) => cardQuote(coins, cfg)!.total;

  it("applique 600 FCFA = 1 USD et 9,9 % de frais + marge", () => {
    expect([1000, 2500, 5000, 12000, 25000, 50000].map(price)).toEqual([0.89, 2.13, 4.07, 9.25, 18.5, 37]);
  });

  it("laisse au moins le prix du pack en FCFA après les frais FeexPay, même au taux réel de 583", () => {
    for (const c of [1000, 2500, 5000, 12000, 25000, 50000]) {
      const q = cardQuote(c, cfg)!;
      expect(q.net * 583.43).toBeGreaterThanOrEqual(q.xof);
    }
  });

  it("refuse un pack inconnu", () => {
    expect(cardQuote(777, cfg)).toBeNull();
  });
});
