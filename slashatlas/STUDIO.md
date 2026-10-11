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
