import { createHash } from "crypto";
import { pubscaleSignature } from "../offerwall_logic";

// exemple de la documentation Pubscale : valeur décimale tronquée à l'entier dans la chaîne signée
const SECRET = "fa072672-d432-11c4-885a-EB1CdEc4Bb13";
const USER = "30356439-8d15-4f47-B133-010a37C19eBD";
const TOKEN = "525a5B8e-512b-441A-a10B-72d218c370e5";
const md5 = (s: string): string => createHash("md5").update(s, "utf8").digest("hex");

describe("signature Pubscale (MD5 de clé.user_id.valeur_entière.token)", () => {
  test("valeur décimale tronquée comme dans l'exemple de la documentation", () => {
    expect(pubscaleSignature(SECRET, USER, "100.1234", TOKEN)).toBe(md5(`${SECRET}.${USER}.100.${TOKEN}`));
  });
  test("une autre clé ou un autre jeton donne une autre signature", () => {
    const ok = pubscaleSignature(SECRET, USER, "100.1234", TOKEN);
    expect(pubscaleSignature("autre", USER, "100.1234", TOKEN)).not.toBe(ok);
    expect(pubscaleSignature(SECRET, USER, "100.1234", "autre")).not.toBe(ok);
  });
  test("valeur illisible : traitée comme 0, jamais d'exception", () => {
    expect(pubscaleSignature(SECRET, USER, "abc", TOKEN)).toBe(md5(`${SECRET}.${USER}.0.${TOKEN}`));
  });
});
