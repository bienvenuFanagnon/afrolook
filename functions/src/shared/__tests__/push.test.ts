/* Routage de deliverPush : FCM d'abord, OneSignal en secours, coupe-circuit sur quota épuisé. Firestore, FCM et OneSignal simulés. */

const TOKEN_A = "t".repeat(60);
const TOKEN_DEAD = "d".repeat(60);
const OS_A = "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa";
const OS_B = "bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb";

type Doc = Record<string, unknown>;
const store: Record<string, Record<string, Doc>> = {};
const updates: Array<{ path: string; data: Doc }> = [];
const sets: Array<{ path: string; data: Doc }> = [];

const snap = (id: string, data?: Doc) => ({ id, exists: data !== undefined, data: () => data });

jest.mock("../firebase", () => ({
  db: {
    collection: (c: string) => ({
      doc: (id: string) => ({
        id,
        get: async () => snap(id, store[c]?.[id]),
        set: async (data: Doc) => { sets.push({ path: `${c}/${id}`, data }); },
        update: async (data: Doc) => { updates.push({ path: `${c}/${id}`, data }); },
      }),
      where: (_f: string, _op: string, ids: string[]) => ({
        get: async () => ({
          docs: Object.entries(store[c] ?? {}).filter(([, d]) => ids.includes(String(d["oneIgnalUserid"]))).map(([id, d]) => snap(id, d)),
        }),
      }),
    }),
    getAll: async (...refs: Array<{ id: string }>) => refs.map((r) => snap(r.id, store["Users"]?.[r.id])),
  },
}));

const sendEachForMulticast = jest.fn();
jest.mock("firebase-admin/messaging", () => ({ getMessaging: () => ({ sendEachForMulticast }) }));

const post = jest.fn();
jest.mock("axios", () => ({ __esModule: true, default: { post: (...a: unknown[]) => post(...a) } }));

const notifyAdminsAll = jest.fn().mockResolvedValue(undefined);
jest.mock("../user_notify.js", () => ({ notifyAdminsAll: (...a: unknown[]) => notifyAdminsAll(...a) }));

jest.mock("firebase-admin/firestore", () => ({ FieldValue: { arrayRemove: (...v: unknown[]) => ({ remove: v }) } }));

import { deliverPush } from "../push";

const CFG = { appId: "app", apiKey: "key" };
const PAYLOAD = { title: "T", message: "M", image: "https://exemple.com/photo.jpg", data: { type_notif: "MESSAGE", n: 3 } };

beforeEach(() => {
  jest.clearAllMocks();
  updates.length = 0;
  sets.length = 0;
  store["Users"] = {
    u1: { oneIgnalUserid: OS_A, fcmTokens: [TOKEN_A] }, // application à jour
    u2: { oneIgnalUserid: OS_B }, // ancienne version : pas de jeton FCM
    u3: { oneIgnalUserid: OS_B, fcmTokens: [TOKEN_DEAD] }, // jeton périmé
  };
  store["AppConfig"] = {};
});

test("personne avec jeton FCM : FCM seulement, aucun appel OneSignal", async () => {
  sendEachForMulticast.mockResolvedValue({ responses: [{ success: true }] });
  const r = await deliverPush([{ oneSignalId: OS_A }], PAYLOAD, CFG);
  expect(r).toEqual({ fcm: 1, oneSignal: 0, unreachable: 0 });
  expect(post).not.toHaveBeenCalled();
  const msg = sendEachForMulticast.mock.calls[0][0];
  expect(msg.tokens).toEqual([TOKEN_A]);
  expect(msg.data).toEqual({ type_notif: "MESSAGE", n: "3" }); // données converties en texte
  expect(msg.android.priority).toBe("high");
  expect(msg.notification.imageUrl).toBe("https://exemple.com/photo.jpg"); // l'image de la notification est conservée avec FCM
  expect(msg.android.notification.imageUrl).toBe("https://exemple.com/photo.jpg");
});

test("personne sans jeton : OneSignal", async () => {
  post.mockResolvedValue({ status: 200 });
  store["Users"] = { u2: { oneIgnalUserid: OS_B } };
  const r = await deliverPush([{ userId: "u2" }], PAYLOAD, CFG);
  expect(r.oneSignal).toBe(1);
  expect(sendEachForMulticast).not.toHaveBeenCalled();
  expect(post.mock.calls[0][1].include_player_ids).toEqual([OS_B]);
});

test("jeton périmé : retiré du profil, puis repli OneSignal", async () => {
  sendEachForMulticast.mockResolvedValue({ responses: [{ success: false, error: { code: "messaging/registration-token-not-registered" } }] });
  post.mockResolvedValue({ status: 200 });
  const r = await deliverPush([{ userId: "u3" }], PAYLOAD, CFG);
  expect(updates).toHaveLength(1);
  expect(updates[0].path).toBe("Users/u3");
  expect(updates[0].data).toEqual({ fcmTokens: { remove: [TOKEN_DEAD] } });
  expect(r).toEqual({ fcm: 0, oneSignal: 1, unreachable: 0 });
});

test("quota OneSignal épuisé : coupe-circuit ouvert, administrateurs prévenus, plus d'appel ensuite", async () => {
  post.mockRejectedValue({ response: { status: 429, data: { errors: ["quota exceeded"] } } });
  store["Users"] = { u2: { oneIgnalUserid: OS_B } };
  await deliverPush([{ userId: "u2" }], PAYLOAD, CFG);
  expect(post).toHaveBeenCalledTimes(1);
  expect(sets.some((s) => s.path === "AppConfig/push_state" && Number(s.data["oneSignalBlockedUntil"]) > Date.now())).toBe(true);
  expect(notifyAdminsAll).toHaveBeenCalledTimes(1);

  // Deuxième envoi : le coupe-circuit est ouvert (mémorisé), OneSignal n'est plus appelé
  post.mockClear();
  const r = await deliverPush([{ userId: "u2" }], PAYLOAD, CFG);
  expect(post).not.toHaveBeenCalled();
  expect(r.oneSignal).toBe(0);
  expect(notifyAdminsAll).toHaveBeenCalledTimes(1); // une seule alerte
});
