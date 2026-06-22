import { FEEXPAY_FEES_CONFIG_AFROLOOK, APP_FEE_RATE_AFROLOOK } from "./config";

/**
 * Formate un objet Date en une chaîne 'YYYY-MM-DD HH:MM:SS'.
 */
export function formatCinetpayDate(date: Date): string {
  const pad = (num: number) => num.toString().padStart(2, "0");
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());
  const hours = pad(date.getHours());
  const minutes = pad(date.getMinutes());
  const seconds = pad(date.getSeconds());
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

/**
 * Génère un numéro de dépôt unique (CinetPay / PayGate)
 */
export function generateDepositNumber(): string {
  const timestamp = Date.now().toString();
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, "0");
  return `DEP${timestamp}${random}`;
}

/**
 * Génère une clé de transaction FeexPay aléatoire
 */
export function generateFeexpayTransKeyAfrolook(): string {
  return Math.random().toString(36).substring(2, 17);
}

/**
 * Génère un numéro de dépôt pour FeexPay
 */
export function generateDepositNumberAfrolook(): string {
  const timestamp = Date.now().toString();
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, "0");
  return `DEP${timestamp}${random}`;
}

/**
 * Calcule le gain de l'application après frais FeexPay
 */
export function calculateAppGainAfrolook(amount: number, operatorCode: string): number {
  const feexpayTotal = FEEXPAY_FEES_CONFIG_AFROLOOK[operatorCode]?.total || 0;
  const appFee = amount * (APP_FEE_RATE_AFROLOOK / 100);
  const feexpayFee = amount * (feexpayTotal / 100);
  return Math.max(0, appFee - feexpayFee);
}
