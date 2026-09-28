import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

/**
 * Taux de change du jour, base FCFA (XOF) : `AppConfig/exchangeRates.rates[DEVISE]`
 * = valeur de 1 FCFA dans la devise. L'app convertit les montants FCFA à
 * l'affichage (les montants restent enregistrés en FCFA). XAF vaut XOF.
 * Source : open.er-api.com (gratuit, sans clé, mis à jour une fois par jour).
 */
const SOURCE_URL = "https://open.er-api.com/v6/latest/XOF";

async function refreshRates(): Promise<number> {
  const res = await fetch(SOURCE_URL);
  if (!res.ok) throw new Error(`Taux indisponibles (HTTP ${res.status})`);
  const body = (await res.json()) as { result?: string; rates?: Record<string, number>; time_last_update_unix?: number };
  if (body.result !== "success" || !body.rates) throw new Error("Réponse de taux invalide");

  const rates: Record<string, number> = {};
  for (const [cur, v] of Object.entries(body.rates)) {
    if (typeof v === "number" && Number.isFinite(v) && v > 0) rates[cur.toUpperCase()] = v;
  }
  rates.XOF = 1;
  rates.XAF = 1;

  await getFirestore().collection("AppConfig").doc("exchangeRates").set({
    base: "XOF",
    rates,
    source: "open.er-api.com",
    sourceUpdatedAt: body.time_last_update_unix ? body.time_last_update_unix * 1000 : null,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return Object.keys(rates).length;
}

/** Mise à jour quotidienne (6 h, heure d'Abidjan). */
export const updateExchangeRates = onSchedule(
  { schedule: "0 6 * * *", timeZone: "Africa/Abidjan", timeoutSeconds: 60 },
  async () => {
    const n = await refreshRates();
    console.log(`Taux de change mis à jour : ${n} devises`);
  },
);

/** Mise à jour à la demande (admin), par exemple juste après le déploiement. */
export const refreshExchangeRatesNow = onCall(async (req) => {
  if (!req.auth) throw new HttpsError("unauthenticated", "Connexion requise");
  const user = await getFirestore().collection("Users").doc(req.auth.uid).get();
  if (user.get("role") !== "ADM") throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  const n = await refreshRates();
  return { currencies: n };
});
