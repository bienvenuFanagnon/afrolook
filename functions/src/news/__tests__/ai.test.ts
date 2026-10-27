const store: Record<string, Record<string, unknown>> = {};
jest.mock("../../shared/firebase", () => ({
  db: {
    collection: (c: string) => ({
      add: async () => ({}),
      doc: (id: string) => ({
        get: async () => ({ data: () => store[`${c}/${id}`] }),
        set: async (v: Record<string, unknown>) => {
          const cur = (store[`${c}/${id}`] ??= {});
          const acc = v["accounts"] as Record<string, number> | undefined;
          if (acc && c === "NewsBudget") {
            const a = ((cur["accounts"] as Record<string, number> | undefined) ?? {});
            for (const [k, n] of Object.entries(acc)) a[k] = (a[k] ?? 0) + n;
            cur["accounts"] = a;
          }
        },
      }),
    }),
  },
}));
jest.mock("firebase-admin/firestore", () => ({ FieldValue: { increment: (n: number) => n } }));
jest.mock("firebase-functions/params", () => ({ defineSecret: () => ({ value: () => "[]" }) }));

import { AiError, estimateNeurons, maskId, parseAccounts, pickAccount, runAi, DEFAULT_MODELS } from "../ai";

const A = { id: "a".repeat(32), token: "t".repeat(40) };
const B = { id: "b".repeat(32), token: "u".repeat(40) };

describe("comptes Cloudflare des actualités", () => {
  test("lecture du secret : liste JSON valide, entrées invalides ignorées, BOM toléré", () => {
    expect(parseAccounts(JSON.stringify([A, B]))).toHaveLength(2);
    expect(parseAccounts("﻿" + JSON.stringify([A]))).toHaveLength(1);
    expect(parseAccounts(JSON.stringify([A, A]))).toHaveLength(1);
    expect(parseAccounts(JSON.stringify([{ id: "court", token: "x".repeat(40) }]))).toEqual([]);
    expect(parseAccounts(JSON.stringify([{ id: A.id, token: "court" }]))).toEqual([]);
    expect(parseAccounts("cfat_pas_du_json")).toEqual([]);
    expect(parseAccounts(undefined)).toEqual([]);
  });

  test("affichage masqué : jamais l'identifiant complet", () => {
    expect(maskId("1234567890abcdef1234567890abcdef")).toBe("1234…cdef");
  });

  test("estimation des neurons d'après la grille", () => {
    expect(Math.round(estimateNeurons(DEFAULT_MODELS.quality, 1500, 600))).toBe(163);
    expect(Math.round(estimateNeurons(DEFAULT_MODELS.light, 1500, 600))).toBe(27);
  });

  test("choix du compte : le moins consommé, jamais un compte plein, jamais au-delà du total du jour", () => {
    expect(pickAccount([A, B], {})?.id).toBe(A.id);
    expect(pickAccount([A, B], { [A.id]: 500, [B.id]: 100 })?.id).toBe(B.id);
    expect(pickAccount([A, B], { [A.id]: 9000, [B.id]: 100 })?.id).toBe(B.id);
    expect(pickAccount([A, B], { [A.id]: 9000, [B.id]: 9000 })).toBeNull();
    expect(pickAccount([A, B], { [A.id]: 8700, [B.id]: 8700 })).toBeNull(); // total de 17 400 > 17 000
    expect(pickAccount([], {})).toBeNull();
  });
});

describe("appel à Workers AI", () => {
  const ok = (body: unknown, status = 200) => jest.fn(async () => ({ ok: status < 400, status, json: async () => body }) as unknown as Response);

  test("réponse au format Cloudflare ou OpenAI, neurons comptés sur le compte utilisé", async () => {
    for (const k of Object.keys(store)) delete store[k];
    const f = ok({ success: true, result: { response: "OK", usage: { prompt_tokens: 20, completion_tokens: 2 } } });
    const r = await runAi([{ role: "user", content: "test" }], { accounts: [A, B], fetchImpl: f as unknown as typeof fetch, model: DEFAULT_MODELS.light });
    expect(r.text).toBe("OK");
    expect(r.accountId).toBe(A.id);
    const call = (f.mock.calls as unknown as Array<[string, RequestInit]>)[0];
    expect(call[0]).toContain(`/accounts/${A.id}/ai/run/`);
    expect((call[1].headers as Record<string, string>)["Authorization"]).toBe(`Bearer ${A.token}`);
    // 2e appel : le compte A a consommé quelques neurons, B (à zéro) passe en premier
    const f2 = ok({ success: true, result: { choices: [{ message: { content: "Bonjour" } }], usage: { neurons: 12.5 } } });
    const r2 = await runAi([{ role: "user", content: "test" }], { accounts: [A, B], fetchImpl: f2 as unknown as typeof fetch });
    expect(r2.text).toBe("Bonjour");
    expect(r2.accountId).toBe(B.id);
    expect(r2.neurons).toBe(12.5);
  });

  test("erreurs : aucun compte, quota, réponse vide", async () => {
    await expect(runAi([{ role: "user", content: "x" }], { accounts: [] })).rejects.toMatchObject({ code: "no_account" });
    const quota = ok({ success: false, errors: [{ message: "neurons limit reached" }] }, 429);
    await expect(runAi([{ role: "user", content: "x" }], { accounts: [A], fetchImpl: quota as unknown as typeof fetch })).rejects.toMatchObject({ code: "quota" });
    const empty = ok({ success: true, result: { response: "" } });
    await expect(runAi([{ role: "user", content: "x" }], { accounts: [A], fetchImpl: empty as unknown as typeof fetch })).rejects.toBeInstanceOf(AiError);
  });
});
