import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, Transaction } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { APP_DATA_DOC, defaultRewardSplit, defiLabel, sendDefiNotification } from "./defiShared";

/**
 * settleEndedDefis — toutes les 15 minutes, clôture les DÉFI arrivés à échéance :
 * classement des participations (votes, puis score, puis likes), versement des gains
 * aux gagnants selon la répartition, parts non attribuées rendues au créateur,
 * notifications, puis DÉFI marqué "termine".
 *
 * Cagnotte non financée à la création (DÉFI créés avant le débit à la création) :
 * les gains sont débités au créateur au moment du versement ; s'il n'a pas assez de
 * pièces, le DÉFI reste en attente et est retenté au passage suivant.
 */
export const settleEndedDefis = onSchedule(
  { schedule: "every 15 minutes", timeZone: "UTC", memory: "512MiB", cpu: 1, timeoutSeconds: 300 },
  async () => {
    const snap = await db.collection("Posts")
      .where("type", "==", "DEFI")
      .where("defi_config.status", "==", "en_cours")
      .where("defi_config.end_date", "<=", Date.now())
      .limit(50)
      .get();

    for (const doc of snap.docs) {
      try {
        await settleDefi(doc.id);
      } catch (err) {
        console.error(`[settleEndedDefis] DÉFI ${doc.id} :`, err);
      }
    }
  }
);

type Winner = {
  userId: string; postId: string; rank: number; coins: number; votes: number; dataType: string;
  pseudo: string; imageUrl: string;
};

type SettleResult =
  | { kind: "paid"; creatorId: string; description: string; winners: Winner[]; returnedToCreator: number }
  | { kind: "waiting_funds"; creatorId: string; description: string; needed: number; firstTime: boolean };

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

function logCoins(tx: Transaction, p: {
  userId: string; type: string; description: string; coins: number; defiPostId: string; now: number;
}) {
  const ref = db.collection("TransactionSoldes").doc();
  tx.set(ref, {
    id: ref.id,
    user_id: p.userId,
    type: p.type,
    statut: "VALIDER",
    description: p.description,
    montant: p.coins,
    frais: 0,
    montant_total: p.coins,
    methode_paiement: "pieces",
    createdAt: p.now,
    updatedAt: p.now,
    defiPostId: p.defiPostId,
  });
}

async function settleDefi(defiId: string): Promise<void> {
  const defiRef = db.collection("Posts").doc(defiId);

  const result = await db.runTransaction<SettleResult | null>(async (tx) => {
    const now = Date.now();
    const defiDoc = await tx.get(defiRef);
    if (!defiDoc.exists) return null;
    const defi = defiDoc.data()!;
    const cfg = (defi["defi_config"] ?? {}) as Record<string, unknown>;
    if (cfg["status"] !== "en_cours" || num(cfg["end_date"]) > now) return null;

    const creatorId = defi["user_id"] as string;
    const description = (defi["description"] as string | undefined) ?? "";
    const cagnotte = Math.max(0, Math.floor(num(cfg["cagnotte_pieces"])));
    const funded = cfg["cagnotte_funded"] === true;
    const winnersCount = Math.min(3, Math.max(1, Math.floor(num(cfg["winners_count"]) || 1)));
    const splitRaw = cfg["reward_split"];
    const split = Array.isArray(splitRaw) && splitRaw.length === winnersCount
        && splitRaw.reduce((a: number, b: unknown) => a + num(b), 0) === 100
      ? splitRaw.map(num)
      : defaultRewardSplit(winnersCount);

    // Parts par rang ; l'arrondi restant va au 1er.
    const shares = split.map((pct) => Math.floor((cagnotte * pct) / 100));
    shares[0] += cagnotte - shares.reduce((a, b) => a + b, 0);

    // Classement identique à la page du DÉFI ; une seule place par utilisateur.
    const responsesSnap = await tx.get(
      db.collection("Posts").where("defi_response_to_post_id", "==", defiId)
    );
    const ranked = responsesSnap.docs
      .map((d) => d.data())
      .filter((p) => typeof p["user_id"] === "string" && p["user_id"])
      .sort((a, b) =>
        (num(b["defi_votes"]) - num(a["defi_votes"]))
        || (num(b["postScore"]) - num(a["postScore"]))
        || (num(b["likes"]) - num(a["likes"]))
        || (num(a["created_at"]) - num(b["created_at"])));
    const seen = new Set<string>();
    const podium = ranked.filter((p) => !seen.has(p["user_id"]) && !!seen.add(p["user_id"])).slice(0, winnersCount);

    const userRefs = [...new Set([creatorId, ...podium.map((p) => p["user_id"] as string)])]
      .map((id) => db.collection("Users").doc(id));
    const userDocs = await Promise.all(userRefs.map((r) => tx.get(r)));
    const userExists = new Map(userDocs.map((d) => [d.id, d.exists]));
    const userData = new Map(userDocs.map((d) => [d.id, d.data() ?? {}]));
    const creatorDoc = userDocs.find((d) => d.id === creatorId);

    const winners: Winner[] = podium
      .filter((p) => userExists.get(p["user_id"]))
      .map((p, i) => ({
        userId: p["user_id"] as string,
        postId: p["id"] as string,
        rank: i + 1,
        coins: shares[i],
        votes: num(p["defi_votes"]),
        dataType: (p["dataType"] as string | undefined) ?? "",
        pseudo: (userData.get(p["user_id"])?.["pseudo"] as string | undefined) ?? "",
        imageUrl: (userData.get(p["user_id"])?.["imageUrl"] as string | undefined) ?? "",
      }))
      .filter((w) => w.coins > 0);
    const awarded = winners.reduce((a, w) => a + w.coins, 0);

    if (!funded) {
      // Cagnotte jamais débitée : on prélève maintenant ce qui est versé aux gagnants.
      if (awarded > 0) {
        const creatorBalance = num(creatorDoc?.data()?.["giftCoinsBalance"]);
        if (!creatorDoc?.exists || creatorBalance < awarded) {
          const firstTime = cfg["payout_status"] !== "fonds_insuffisants";
          tx.update(defiRef, {
            "defi_config.payout_status": "fonds_insuffisants",
            "defi_config.payout_checked_at": now,
          });
          return { kind: "waiting_funds", creatorId, description, needed: awarded, firstTime };
        }
        tx.update(db.collection("Users").doc(creatorId), {
          giftCoinsBalance: FieldValue.increment(-awarded),
          totalGiftCoinsSpent: FieldValue.increment(awarded),
          updatedAt: now,
        });
        logCoins(tx, {
          userId: creatorId, type: "DEPENSE", coins: awarded, defiPostId: defiId, now,
          description: `Cagnotte DÉFI versée aux gagnants — ${awarded} pièces`,
        });
      }
    }

    const returnedToCreator = funded ? cagnotte - awarded : 0;
    if (returnedToCreator > 0 && creatorDoc?.exists) {
      // Annule la dépense de la cagnotte (et non un gain) : des pièces achetées mises en jeu
      // puis rendues restent non convertibles.
      tx.update(db.collection("Users").doc(creatorId), {
        giftCoinsBalance: FieldValue.increment(returnedToCreator),
        totalGiftCoinsSpent: FieldValue.increment(-returnedToCreator),
        updatedAt: now,
      });
      logCoins(tx, {
        userId: creatorId, type: "GAIN_PIECES", coins: returnedToCreator, defiPostId: defiId, now,
        description: `Cagnotte DÉFI non attribuée rendue — ${returnedToCreator} pièces`,
      });
    }

    for (const w of winners) {
      tx.update(db.collection("Users").doc(w.userId), {
        giftCoinsBalance: FieldValue.increment(w.coins),
        totalCoinsEarnedFromDefi: FieldValue.increment(w.coins),
        updatedAt: now,
      });
      logCoins(tx, {
        userId: w.userId, type: "GAIN_PIECES", coins: w.coins, defiPostId: defiId, now,
        description: `🏆 ${w.rank === 1 ? "1er" : `${w.rank}e`} du DÉFI — ${w.coins} pièces`,
      });
    }

    tx.update(defiRef, {
      "defi_config.status": "termine",
      "defi_config.payout_status": "paye",
      "defi_config.payout_checked_at": now,
      defi_winners: winners.map(({ userId, postId, rank, coins, votes, pseudo, imageUrl }) =>
        ({ userId, postId, rank, coins, votes, pseudo, imageUrl })),
      defi_settled_at: now,
    });

    return { kind: "paid", creatorId, description, winners, returnedToCreator };
  });

  if (!result) return;
  try {
    await notifySettlement(defiId, result);
  } catch (err) {
    console.error(`[settleEndedDefis] Notifications DÉFI ${defiId} :`, err);
  }
}

async function notifySettlement(defiId: string, r: SettleResult): Promise<void> {
  const appConfig = (await db.collection("AppData").doc(APP_DATA_DOC).get()).data() ?? {};
  const label = defiLabel(r.description);
  const base = { senderId: "afrolook_system", defiPostId: defiId, appConfig };

  if (r.kind === "waiting_funds") {
    if (!r.firstTime) return;
    await sendDefiNotification({
      ...base,
      receiverId: r.creatorId,
      postId: defiId,
      titre: "⏳ Gains du DÉFI en attente",
      message: `⏳ Ton DÉFI${label} est terminé, mais ton solde est insuffisant pour verser `
        + `${r.needed} pièces aux gagnants. Recharge ton solde : le versement se fera automatiquement.`,
    });
    return;
  }

  const rankLabel = (rank: number) => (rank === 1 ? "🥇 1ère" : rank === 2 ? "🥈 2e" : "🥉 3e");
  await Promise.all(r.winners.map((w) => sendDefiNotification({
    ...base,
    receiverId: w.userId,
    postId: w.postId,
    postDataType: w.dataType,
    titre: "🏆 Tu as gagné un DÉFI !",
    message: `🏆 ${rankLabel(w.rank)} place au DÉFI${label} : +${w.coins} pièces ajoutées à ton solde !`,
  })));

  const creatorIsOnlyWinner = r.winners.length > 0 && r.winners.every((w) => w.userId === r.creatorId);
  if (creatorIsOnlyWinner) return;
  const summary = r.winners.length === 0
    ? "aucune participation n'a été classée"
    : `${r.winners.length} gagnant${r.winners.length > 1 ? "s" : ""} récompensé${r.winners.length > 1 ? "s" : ""}`;
  const refund = r.returnedToCreator > 0 ? ` ${r.returnedToCreator} pièces non attribuées t'ont été rendues.` : "";
  await sendDefiNotification({
    ...base,
    receiverId: r.creatorId,
    postId: defiId,
    titre: "🏁 Ton DÉFI est terminé",
    message: `🏁 Ton DÉFI${label} est terminé : ${summary}.${refund}`,
  });
}
