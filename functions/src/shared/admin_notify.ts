import { db } from "./firebase";
import { sendToOneSignal } from "./notification_utils";

// Alerte des administrateurs dans l'application : une notification dans leur liste + une notification push (OneSignal).
// Les administrateurs sont les comptes dont le rôle est ADM / admin / ADMIN / super_admin. Ne lève jamais d'erreur.
const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";

export async function adminDocs(): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const snaps = await Promise.all(["ADM", "admin", "ADMIN", "super_admin"].map((role) => db.collection("Users").where("role", "==", role).get()));
  const byId = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  snaps.forEach((s) => s.docs.forEach((d) => byId.set(d.id, d)));
  return [...byId.values()];
}

export async function notifyAdmins(opts: { title: string; message: string; fromUserId?: string | null; refId?: string }): Promise<void> {
  try {
    const [admins, appDoc] = await Promise.all([adminDocs(), db.collection("AppData").doc(APP_DATA_DOC).get()]);
    const cfg = appDoc.data() ?? {};
    const nowMicros = Date.now() * 1000;
    await Promise.all(admins.map(async (admin) => {
      const ref = db.collection("Notifications").doc();
      await ref.set({
        id: ref.id,
        titre: opts.title,
        description: opts.message,
        type: "POST",
        user_id: opts.fromUserId ?? admin.id,
        receiver_id: admin.id,
        post_id: "",
        post_data_type: "",
        is_open: false,
        users_id_view: [],
        status: "VALIDE",
        created_at: nowMicros,
        updated_at: nowMicros,
        createdAt: nowMicros,
        updatedAt: nowMicros,
        adminAlertRef: opts.refId ?? null,
      });
      const oneSignalId = (admin.data()["oneIgnalUserid"] as string | undefined) ?? "";
      if (oneSignalId && cfg["one_signal_app_id"] && cfg["one_signal_api_key"]) {
        try {
          await sendToOneSignal([oneSignalId], opts.message, opts.title, cfg["app_logo"] ?? "", cfg["one_signal_app_id"], cfg["one_signal_api_key"],
            { type_notif: "POST", post_id: "", post_type: "", chat_id: "" });
        } catch (e) {
          console.error("[notifyAdmins] push non envoyé à", admin.id, e);
        }
      }
    }));
  } catch (err) {
    console.error("[notifyAdmins]", err);
  }
}
