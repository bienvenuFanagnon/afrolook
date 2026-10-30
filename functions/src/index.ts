import "./shared/globalOptions"; // doit rester la première ligne : options communes à toutes les fonctions
export { translatePostDescription, translateComment } from "./translatePost";
export * from "./posts/scoreEngine";
export * from "./posts/viewEarnings";
export * from "./payments/cinetpay";
export * from "./payments/paygate";
export * from "./payments/feexpay";
export * from "./live/agora";
export * from "./live/autoTerminate";
export * from "./posts/sharing";
export * from "./posts/interactions";
export * from "./posts/lifecycle";
export * from "./posts/weeklyRewards";
export * from "./notifications/bulk";
export * from "./notifications/sendPush";
export * from "./notifications/reengagement";
export * from "./notifications/markRead";
export * from "./notifications/samples";
export * from "./emails/email_functions";
export * from "./chat/groupNotifications";
export * from "./contenu/contentPaie";
export * from "./contenu/payments";
export * from "./streak/streakReminder";
export * from "./ads/ad_notifications";
export * from "./posts/repostNotification";
export * from "./posts/defiActions";
export * from "./posts/defiSettlement";
export * from "./payments/coinConversion";
export * from "./payments/coinPayments";
export * from "./payments/coinInteractions";
export * from "./payments/coinPurchase";
export { offerwallRelease } from "./offerwall/offerwall";
export { adsWebCreate, adsWebRenew, adsWebMine, adsWebStop, adsWebDelete, adsWebPublic, adsWebTrack } from "./ads/adsWeb"; // Afrolook Ads : annonceurs sur afrolookmedia.com/ads/
export { adsServe, adsEvent, adsGo, adsRollup, adsCleanup, adsHealth, adsUniques, adsReverify } from "./ads/adsEngine"; // Afrolook Ads : moteur unique (jeton signé, clic par redirection, compteurs répartis)
export { adsAdvMe, adsAdvSaveProfile, adsAdvAdminList, adsAdvAdminReview, adsPartners } from "./ads/adsAdvertisers"; // Afrolook Ads : profil annonceur (logo de marque, partenaires)
export { adsShareList, adsShareCreate, adsShareGo, adsShareRollup, adsShareFraudScan, adsShareProfileMe, adsShareProfileSave, adsShareCampaignCreate, adsShareCampaignMine, adsShareReport } from "./ads/adsShare"; // Partage et gagne (statut et groupes WhatsApp, liens suivis, gains en pièces)
export { adsWatch } from "./ads/adsWatch"; // Afrolook Ads : surveillance horaire des plateformes (alertes, blocage des paiements)
export { adsAudience, adsWho, adsPubMe, adsPubSaveProfile, adsPubAddProperty, adsPubVerifyProperty, adsPubUpdateProperty, adsPubDeleteProperty, adsPubAdminList, adsPubAdminReview, adsPubAcceptRules, adsPubStats } from "./ads/adsPublishers"; // Afrolook Ads : diffuseurs (profil, sites et applications, validation)
export { adTaskStart, adTaskClaim } from "./offerwall/adTask"; // tâche « Regarder une pub » (docs/OFFERWALL_TACHES.md §20)
export { tapjoyOfferwallCallback } from "./offerwall/tapjoyCallback"; // secrets posés le 27/10/2026 (tool/offerwall/setup_secrets.cjs)
export { ayetOfferwallCallback } from "./offerwall/ayetCallback"; // secret AYET_API_KEY posé le 27/10/2026 (tool/offerwall/setup_ayet_secret.cjs)
export { pubscaleOfferwallCallback, pubscaleChargebackCallback } from "./offerwall/pubscaleCallback"; // à déployer après la pose des secrets PUBSCALE_SECRET_ANDROID / _IOS
export * from "./offerwall/offerwallAdmin";
export { offerwallMyHistory } from "./offerwall/offerwallUser";
export { offerwallAdminPartners, offerwallAdminPartnerSave } from "./offerwall/offerwallPartners";
export { r2MirrorSweep } from "./media/r2Mirror";
export { chroniqueReplyInvite, onInvitationAnswered } from "./chroniques/chroniqueReply";
export { chroniqueMusicCharge } from "./chroniques/chroniqueMusic";
export { chroniqueExpiryCleanup } from "./chroniques/chroniqueCleanup";
export { readStatsReport } from "./monitoring/readStats";
export { cardCoinQuote, cardCoinStart, cardCoinStatus, cardCoinReconcile, cardCoinAdminConfig, cardCoinAdminChargeback } from "./payments/feexpayCard";
export { paymentReport, paymentWatchdog } from "./payments/paymentLog";

export * from "./payments/appleIap";
export * from "./payments/googlePlayIap";
export * from "./moderation/moderation";
export * from "./users/accountDeletion";
export * from "./follows/follows";
export * from "./posts/unreadCleanup";
export * from "./users/presenceMirror";
export * from "./contes/contes";
export * from "./modules/adFree";
export * from "./cards/cards";
export * from "./auth/authEmails";
export { weeklyTopCreatorsRanking } from "./posts/weeklyRankings";
export * from "./social/socialClicks";
export * from "./ads/adFree";
export * from "./ads/adRevenue";
export { recordAdView, claimReward, adSsvCallback } from "./ads/rewards";
export * from "./users/accountPurge";
export * from "./payments/exchangeRates";
export { migratePseudos, migrateCanalNames } from "./users/pseudoMigration";
export * from "./posts/canalInactivity";
export { adminCanalAction } from "./posts/adminCanaux";
export { stickerAccess, onCommentMediaCreated, onReplyMediaUpdated } from "./stickers/stickers";
export { stickerGiftSend } from "./stickers/stickerPayments";
export { onUserStickerCreated, submitStickerPack, updateStickerPackPrice, adminStickerAction, reportStickerCopy } from "./stickers/stickerCreators";
export { convertStickerVideo } from "./stickers/stickerVideo";
export { creationQuote, onCanalCreatedCharge, onGroupCreatedCharge } from "./payments/creationFees";
export * from "./quiz/quiz";
export * from "./quiz/quizAdmin";
export * from "./etude/etude";
export * from "./site/contact";
export * from "./posts/linkPreview";
export * from "./team/teamHub";
export { renderStudioMontage } from "./studio/renderMontage";
export { artistSoundCountries, onArtistSoundCreated, artistSoundDelete, artistSoundAdminUrl, artistSoundReport, artistSoundLinkPost } from "./studio/artistSoundGuard";
export { notifyAdminsOnNewSound, notifyArtistOnSoundStatus } from "./studio/artistSoundNotify";
export { notifyArtistOnEarning } from "./studio/artistEarnNotify";
export { musicBuy, musicStreamUrl, musicLicense, musicAdListen, musicAdPaid, cleanupTempListen } from "./studio/musicLibrary";
export { playlistSave, playlistAdd, playlistDelete, musicStream } from "./studio/musicPlaylists";
export { musicToggleLike } from "./studio/musicLikes";

// Actualités : agents, publication, outils admin et notifications d'engagement
export * from "./news/admin";
export { onNewsCommentCreated } from "./news/engagement";
export { newsPipelineTick, newsRunPipeline, newsSourcesTest } from "./news/schedule";
export { newsCleanup } from "./news/cleanup";
export { newsDigestTick, newsBuildDigests } from "./news/digest";
