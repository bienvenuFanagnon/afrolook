import { onCall, HttpsError } from "firebase-functions/v2/https";
import { RtcRole, RtcTokenBuilder } from "agora-access-token";
import * as dotenv from "dotenv";

dotenv.config();

const appId = process.env.AGORA_APP_ID!;
const appCertificate = process.env.AGORA_APP_CERTIFICATE!;

if (!appId || !appCertificate) {
  console.error("AGORA_APP_ID et AGORA_APP_CERTIFICATE doivent être configurés.");
}

export const generateAgoraToken = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    try {
      const { channelName, uid, role } = request.data as {
        channelName: string;
        uid: string;
        role: "host" | "audience";
      };

      if (!channelName || !uid || !role) {
        throw new HttpsError("invalid-argument", "Paramètres manquants");
      }

      const agoraRole = role === "host" ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

      const expirationTimeInSeconds = 3600;
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

      const token = RtcTokenBuilder.buildTokenWithUid(
        appId!,
        appCertificate!,
        channelName,
        Number(uid),
        agoraRole,
        privilegeExpiredTs
      );

      return { token };
    } catch (error: any) {
      console.error("Erreur génération token Agora:", error);
      throw new HttpsError("internal", "Impossible de générer un token Agora");
    }
  }
);
