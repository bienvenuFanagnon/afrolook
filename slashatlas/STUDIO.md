# SlashAtlas Studio : exploitation

Projet Firebase : `slashatlas-studio` (Firestore et fonctions en `europe-west1`).

- **Comptes** : connexion Google. `StudioUsers/{uid}` est créé à la première connexion et simplement retrouvé ensuite.
- **Crédits** : champ `credits` + journal `StudioLedger` (identifiants fixes : une opération ne s'applique jamais deux fois). 1 génération = 1 crédit, rendu si Gemini échoue.
- **Génération** : `POST /api/generate` (Gemini `gemini-3.1-flash-image`). La commande est composée côté serveur à partir de `functions/commands.json` (généré par `node build.mjs`).
- **Paiement** : FeexPay mobile money. `POST /api/pay/start`, puis `POST /api/pay/status`. Le webhook `POST /api/pay/webhook` ne crédite jamais seul : il relance la vérification auprès de FeexPay.
- **Packs et plafonds** : `functions/studio.js` (`PACKS`, `LIMITS`). Opérateurs : `OPERATORS`.
- **Secrets** : `GEMINI_API_KEY`, `FEEXPAY_API_KEY` (Secret Manager). Changer une clé : `firebase functions:secrets:set NOM --project slashatlas-studio`, puis redéployer les fonctions.
- **Visuels générés** : stockés 30 jours dans `generations/` (suppression automatique).
- **Déploiement** : `node build.mjs && node check.mjs && firebase deploy --project slashatlas-studio --force`.

## Conditions générales, litiges et limites carte
- Texte : `src/terms.mjs` (FR/EN, `TERMS_VERSION`). Pages `/conditions/` et `/en/terms/`. Identité de l'éditeur : `src/config.json` → `legal` (name, form, registration, address, email, phone). À remplir, puis faire relire par un juriste.
- Tout achat exige la case « conditions » cochée ; le serveur refuse sans `terms` = version courante (`terms_required`) et enregistre sur la commande `terms:{version, at, ip, ua}` + e-mail. Si le texte change : changer `TERMS_VERSION` (les clients rechargent la config).
- Carte (désactivée tant que `CARD.enabled=false`) : packs p20/p55 seulement, 2 achats/jour/compte, 3/jour/IP, 20 000 FCFA/30 jours/compte, 30/jour au total (`CARD_LIMITS` dans `functions/studio.js`).
- Admin → « Dernières commandes » → bouton **Preuves** : télécharge le dossier de litige (commande, acceptation des conditions, crédits, images). Conservation des commandes : 18 mois.

## Hub d'administration (`/admin/`, compte autorisé uniquement)
Onglets : Vue d'ensemble (audience) · Studio (KPI, commandes + bouton Preuves, offrir/retirer des crédits, comptes, demandes « carte ») · Inscrits (CSV) · Publicité (réglages + affichages) · Outils (liens console, FeexPay, AdSense…). Les actions d'administration sont journalisées dans `SlashAtlasAdminLog`.

## Carte bancaire : mode « bientôt »
`CARD.enabled=false` : l'onglet « Carte bancaire » affiche « bientôt » ; chaque clic enregistre une statistique `cardwish` (et le pack visé) visible dans l'onglet Studio. Les frais carte seront payés par l'acheteur comme pour le mobile money (renseigner `CARD.payin`/`payout` puis `enabled=true` quand FeexPay valide le KYB carte).

## Publicité (Google AdSense)
- Réglée depuis l'admin → Publicité (activer, ID éditeur `ca-pub-…`, ID des blocs `lb` et `rect`) : stocké dans `SlashAtlasSettings/ads`, lu via `/api/config` (cache 1 min). Aucun redéploiement.
- Emplacements masqués par défaut dans les pages (accueil, tutoriel, packs) ; `static/js/site.js` les active et charge le script AdSense seulement si la publicité est activée. Jamais sur `/generer/`, `/admin/`, ni près d'un bouton. `/ads.txt` est servi par la fonction.
- Consentement : activer dans AdSense « Confidentialité et messagerie » le message GDPR (EEE/RU/CH) ; le lien « Préférences publicitaires » du pied de page le rouvre.
- AdSense exige un domaine propre validé (un sous-domaine `web.app` est souvent refusé) et un site indexable (`indexable: true`).

## Pass « sans pub » (30 jours, 1 000 FCFA)

- Serveur (`functions/studio.js`) : `PASS = { id: 'nopub', days: 30, xof: 1000 }`, vendu par le même parcours que les packs (mobile money, carte quand elle sera activée ; `nopub` est dans `CARD_LIMITS.packs`). Au paiement vérifié, `StudioUsers.adFreeUntil` (ms) est prolongé (cumulable), journal `StudioLedger/adfree_<commande>`, compteur du jour `adfree_orders`.
- `/api/me` et `/api/pay/status` renvoient `adFreeUntil`. La page « Générer ici » le copie dans `localStorage.sa_nopub` ; `site.js` ne charge alors aucune publicité. Sur un nouvel appareil : se connecter une fois sur « Générer ici » pour réactiver.
- Publicité à la copie : bloc `rect` sous « Copié » (`data-adlate`), rempli seulement après un clic sur « Copier » ou une copie par sélection (clic droit / Ctrl+C) dans la commande.
- Lien d'achat : `/generer/?pass=1` (page « Sans pub » `/pro/`).


## Marque et contacts sur le visuel
Sur la page d'une commande (photo : produit, plat, personne, lieu, logo) et dans le Studio, un bloc repliable « Ajouter ma marque ou mes contacts » propose 3 champs (nom de marque, téléphone ou contact, autre texte). Les modèles de phrase et de mise en page par type de sujet sont dans `BRAND` (`build.mjs`), partagés avec le site (commande copiée), le Studio (`try.js`) et le serveur (`commands.json` → `brandClause` dans `functions/studio.js`). Le serveur assainit les textes (guillemets, retours à la ligne, 60/60/80 caractères) et ne les compose que pour les types de sujet prévus ; les commandes vidéo, affiche à texte et libres sont inchangées.

## Partage du visuel
Bouton « Partager » dans le Studio : panneau avec aperçu, feuille de partage native (téléphone), liens WhatsApp/Facebook/X/LinkedIn/Telegram, copie de l’image et du lien. Le fichier partagé est celui du téléchargement (avec le QR de l’utilisateur s’il en a mis un). Événement `share` (via : open, native, réseau, copyimg, copylink).

## QR code de l'utilisateur sur l'affiche
Bloc « Ajouter un QR code vers mon site ou ma boutique » du Studio : l'utilisateur saisit un lien (ou un numéro, converti en `https://wa.me/…`) et choisit le coin. L'IA reçoit seulement la consigne de laisser ce coin libre (`qrClause` dans `functions/studio.js` ; le lien n'est jamais envoyé au serveur). Le QR est dessiné dans le navigateur (`static/js/qrcode-1.4.4.js`, qrcode-generator, MIT) sur l'image d'origine, d'où le changement de lien ou d'emplacement gratuit après la génération. Le QR ouvre uniquement le lien de l'utilisateur ; la mention « Créé avec slashatlas.com » sous le code est un simple texte. Événement `qr`.
