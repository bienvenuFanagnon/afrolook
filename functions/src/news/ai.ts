import { defineSecret } from "firebase-functions/params";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { logNews, recordAiHealth } from "./log";

/**
 * IA des actualités : Cloudflare Workers AI sur plusieurs comptes. Le quota gratuit (10 000 neurons par jour) est PAR COMPTE ; chaque appel part sur
 * le compte le moins consommé, et on s'arrête avant le plafond. Les comptes viennent du secret Firebase `CF_NEWS_ACCOUNTS` (liste JSON de
 * { id, token }, posée par le propriétaire avec tools/news/set_cf_accounts.ps1) : aucune clé n'est dans le code ni renvoyée à l'application.
 * Consommation du jour : NewsBudget/{AAAAMMJJ UTC} { accounts: { <compte>: neurons }, total } (les quotas se remettent à zéro à minuit UTC).
 */
export const CF_NEWS_ACCOUNTS = defineSecret("CF_NEWS_ACCOUNTS");

/** Modèles utilisables (modifiables dans AppConfig/news.models) ; `quality` pour les articles importants, `light` pour la masse. */
export const DEFAULT_MODELS = { quality: "@cf/meta/llama-3.3-70b-instruct-fp8-fast", light: "@cf/meta/llama-3.1-8b-instruct-fp8-fast" };

/** Neurons facturés par million de jetons (entrée, sortie), d'après la grille publiée par Cloudflare ; sert d'estimation quand la réponse n'indique pas les neurons. */
const NEURON_RATES: Record<string, { input: number; output: number }> = {
  "@cf/meta/llama-3.3-70b-instruct-fp8-fast": { input: 26668, output: 204805 },
  "@cf/meta/llama-3.1-8b-instruct-fp8-fast": { input: 4119, output: 34868 },
};

/** Plafond par compte (sur 10 000 gratuits) et plafond total du jour : de la marge pour ne jamais passer en facturation. */
export const PER_ACCOUNT_CAP = 9000;
export const DAILY_TOTAL_CAP = 15000;

export interface CfAccount { id: string; token: string }

/** Lit le secret : liste JSON de comptes ; les entrées invalides sont ignorées. */
export function parseAccounts(raw: string | undefined): CfAccount[] {
  try {
    const list = JSON.parse(String(raw ?? "").replace(/^﻿/, "")) as unknown;
    if (!Array.isArray(list)) return [];
    const out: CfAccount[] = [];
    for (const it of list) {
      const o = (it ?? {}) as Record<string, unknown>;
      const id = String(o["id"] ?? "").trim();
      const token = String(o["token"] ?? "").trim();
      if (/^[a-f0-9]{32}$/i.test(id) && token.length >= 20 && !out.some((a) => a.id === id)) out.push({ id, token });
    }
    return out;
  } catch {
    return [];
  }
}

/** Identifiant de compte masqué pour l'affichage : « ad84…2471 ». */
export const maskId = (id: string): string => (id.length > 8 ? `${id.slice(0, 4)}…${id.slice(-4)}` : "…");

export function estimateNeurons(model: string, promptTokens: number, completionTokens: number): number {
  const r = NEURON_RATES[model] ?? NEURON_RATES[DEFAULT_MODELS.quality];
  return (promptTokens * r.input + completionTokens * r.output) / 1_000_000;
}

/** Compte à utiliser : le moins consommé, parmi ceux qui sont sous le plafond ; null s'il n'en reste aucun (ou si le total du jour est atteint). */
export function pickAccount(accounts: CfAccount[], used: Record<string, number>, perAccountCap = PER_ACCOUNT_CAP, totalCap = DAILY_TOTAL_CAP): CfAccount | null {
  const total = Object.values(used).reduce((s, n) => s + (Number(n) || 0), 0);
  if (total >= totalCap) return null;
  const open = accounts.filter((a) => (used[a.id] ?? 0) < perAccountCap);
  if (!open.length) return null;
  return open.reduce((best, a) => ((used[a.id] ?? 0) < (used[best.id] ?? 0) ? a : best));
}

export const budgetDay = (nowMs = Date.now()): string => new Date(nowMs).toISOString().slice(0, 10).replace(/-/g, "");

export async function loadUsage(nowMs = Date.now()): Promise<Record<string, number>> {
  const d = (await db.collection("NewsBudget").doc(budgetDay(nowMs)).get()).data();
  return ((d?.["accounts"] as Record<string, number> | undefined) ?? {});
}

async function addUsage(accountId: string, neurons: number, nowMs = Date.now()): Promise<void> {
  await db.collection("NewsBudget").doc(budgetDay(nowMs)).set(
    { day: budgetDay(nowMs), accounts: { [accountId]: FieldValue.increment(neurons) }, total: FieldValue.increment(neurons), updatedAt: nowMs },
    { merge: true },
  );
}

export interface AiResult { text: string; neurons: number; accountId: string; model: string; ms: number }
export class AiError extends Error {
  constructor(message: string, readonly status = 0, readonly code: "no_account" | "quota" | "http" | "empty" = "http") { super(message); }
}

interface RunOpts { model?: string; maxTokens?: number; temperature?: number; fetchImpl?: typeof fetch; accounts?: CfAccount[]; accountId?: string }

/** Un appel à Workers AI sur le compte le moins consommé (ou sur `accountId` pour un essai). Compte les neurons réellement utilisés. */
export async function runAi(messages: Array<{ role: "system" | "user" | "assistant"; content: string }>, opts: RunOpts = {}): Promise<AiResult> {
  const accounts = opts.accounts ?? parseAccounts(CF_NEWS_ACCOUNTS.value());
  if (!accounts.length) {
    await logNews({ kind: "ai", ok: false, message: "Aucun compte Cloudflare lisible dans le secret CF_NEWS_ACCOUNTS" });
    throw new AiError("Aucun compte Cloudflare configuré (secret CF_NEWS_ACCOUNTS)", 0, "no_account");
  }
  const used = await loadUsage();
  const account = opts.accountId ? accounts.find((a) => a.id === opts.accountId) ?? null : pickAccount(accounts, used);
  if (!account) {
    await logNews({ kind: "ai", ok: false, message: "Plafond de neurons atteint : l'IA est en pause jusqu'à minuit UTC" });
    throw new AiError("Plafond de neurons atteint pour aujourd'hui", 429, "quota");
  }

  const model = opts.model ?? DEFAULT_MODELS.quality;
  const masked = maskId(account.id);
  const f = opts.fetchImpl ?? fetch;
  const t0 = Date.now();
  try {
    const res = await f(`https://api.cloudflare.com/client/v4/accounts/${account.id}/ai/run/${model}`, {
      method: "POST",
      headers: { Authorization: `Bearer ${account.token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ messages, max_tokens: opts.maxTokens ?? 900, temperature: opts.temperature ?? 0.3 }),
      signal: AbortSignal.timeout(45_000),
    });
    const body = (await res.json().catch(() => null)) as { success?: boolean; result?: Record<string, unknown>; errors?: Array<{ message?: string }> } | null;
    if (!res.ok || !body || body.success === false) {
      const msg = String(body?.errors?.[0]?.message ?? `HTTP ${res.status}`).slice(0, 160);
      throw new AiError(`Workers AI : ${msg}`, res.status, res.status === 429 || /neurons|quota|limit/i.test(msg) ? "quota" : "http");
    }
    const result = body.result ?? {};
    const choice = (result["choices"] as Array<{ message?: { content?: string } }> | undefined)?.[0]?.message;
    const text = String(choice?.content ?? result["response"] ?? "").trim();
    if (!text) throw new AiError("Réponse vide", res.status, "empty");

    const usage = (result["usage"] as Record<string, number> | undefined) ?? {};
    const neurons = typeof usage["neurons"] === "number" ? usage["neurons"] : estimateNeurons(model, Number(usage["prompt_tokens"] ?? 0), Number(usage["completion_tokens"] ?? 0));
    await addUsage(account.id, neurons);
    const ms = Date.now() - t0;
    await Promise.all([
      logNews({ kind: "ai", ok: true, message: "Appel réussi", account: masked, model: model.split("/").pop(), neurons, ms }),
      recordAiHealth(masked, true, undefined),
    ]);
    return { text, neurons, accountId: account.id, model, ms };
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await Promise.all([logNews({ kind: "ai", ok: false, message: msg, account: masked, model: model.split("/").pop(), ms: Date.now() - t0 }), recordAiHealth(masked, false, msg)]);
    throw e;
  }
}
