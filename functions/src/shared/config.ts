// Configuration email
export const EMAIL_FROM = "Afrolook Media <contact@afrolookmedia.com>";
export const APP_DOMAIN = "afrolookmedia.com";
export const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.afrotok.afrotok";

// URLs Afrolook
export const APP_PLAY_STORE_URL_AFRO = "https://play.google.com/store/apps/details?id=com.afrotok.afrotok&pcampaignid=web_share";
export const APP_WEB_URL_AFRO = "https://afrolookmedia.com/";

// FeexPay configuration (clés depuis les variables d'environnement)
export const FEEXPAY_API_KEY_AFROLOOK = process.env.FEEXPAY_API_KEY!;
export const FEEXPAY_SHOP_ID_AFROLOOK = process.env.FEEXPAY_SHOP_ID!;

// Configuration des frais FeexPay par opérateur
export const FEEXPAY_FEES_CONFIG_AFROLOOK: Record<string, { payin: number; payout: number; total: number }> = {
  // Bénin
  'mtn': { payin: 1.7, payout: 1.7, total: 3.4 },
  'moov': { payin: 1.7, payout: 1.7, total: 3.4 },
  'celtiis_bj': { payin: 1.7, payout: 1.7, total: 3.4 },
  'coris': { payin: 1.7, payout: 1.7, total: 3.4 },
  // Togo
  'togocom_tg': { payin: 3.0, payout: 2.4, total: 5.4 },
  'moov_tg': { payin: 3.0, payout: 2.4, total: 5.4 },
  // Côte d'Ivoire
  'mtn_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  'moov_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  'wave_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  'orange_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  // Sénégal
  'orange_sn': { payin: 2.0, payout: 2.0, total: 4.0 },
  'free_sn': { payin: 2.0, payout: 2.0, total: 4.0 },
  'wave_sn': { payin: 2.0, payout: 2.0, total: 4.0 },
  // Congo
  'mtn_cg': { payin: 3.0, payout: 2.0, total: 5.0 },
};

export const APP_FEE_RATE_AFROLOOK = 5.6;
