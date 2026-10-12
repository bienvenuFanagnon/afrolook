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

### QR code : emplacement, taille, texte
Emplacement « Automatique » (défaut) : l'IA garde libre le coin inférieur droit (ou un autre coin calme) et le navigateur choisit ensuite le coin le plus calme de l'image réelle ; l'utilisateur peut aussi imposer un coin ou choisir « Aucun QR code » (gratuit, y compris après la génération). Tailles Petit (12 % du petit côté, défaut) / Moyen / Grand, jamais moins de 3 px par module ni plus de 30 %. Texte au-dessus du code au choix (commander, réserver, nous écrire, voir la boutique) pour expliquer son rôle à celui qui regarde l'affiche ; sous le code, « Créé avec slashatlas.com » reste une simple mention.

## Canal WhatsApp
Le lien du canal se renseigne dans `src/config.json` → `community.whatsapp` (https://whatsapp.com/channel/…). Tant qu’il est vide, rien ne s’affiche ; une fois rempli, puis `node build.mjs` et déploiement, le site montre : carte sur l’accueil, carte dans le bloc « Copié ! » des pages de commande, lien vert dans le pied de page, petite invitation après une copie depuis les cartes (une fois par visite, jamais après avoir rejoint, 14 jours de pause après fermeture), ligne sous le résultat du Studio. Clics comptés (événement `wa`, par emplacement) et envoyés à GA (`join_group`) ; carte « Clics canal WhatsApp » dans l’admin. Logos du canal : `marketing/logo/`.

## Vidéos publicitaires (onglet « Vidéo » du Studio)
- Principe : montage maison (pas d'IA vidéo). Photos du client + textes → vidéo MP4 de 15 à 40 s : animations dessinées image par image (`functions/video.js`, @napi-rs/canvas), musique synthétisée par style, voix off facultative (Google Cloud Text-to-Speech, voix Chirp 3 HD Aoede/Puck, FR et EN), QR code de fin facultatif. Le produit reste identique à la photo.
- Styles : `mode`, `beaute`, `promo` (palette tirée de la photo). Formats : 9:16, 1:1, 16:9. Les durées des scènes s'adaptent à la voix.
- Prix : `VIDEO_COST` dans `functions/studio.js` (4 crédits, prix unique : détourage IA, texte écrit par l'IA, voix off et musique compris). Plafonds : `VIDEO_LIMITS` (8 par jour et par compte, 150 par jour au total). Débit avant le rendu, remboursement automatique en cas d'échec.
- Serveur : `functions/videoApi.js` (validation, crédits, stockage `videos/{uid}/{id}.mp4`, collection `StudioVideos`) ; fonction dédiée `slashatlasVideo` (2 Go, 2 processeurs, 300 s, appelée directement par le navigateur : le délai de Hosting est de 60 s) ; `/api/video/script` (texte proposé par Gemini, gratuit, 25 par jour), `/api/video/file`, `/api/video/list`.
- URL de la fonction de rendu : `src/config.json` → `video.renderUrl` (l'onglet Vidéo n'apparaît que si elle est renseignée).
- Interface : `static/js/videomode.js`, chargé par `try.js`. Exemples : `static/video/exemples/` (générés avec `functions/video.js`, voir l'historique du dépôt).
- Coût de revient mesuré : environ 20 s de calcul pour une vidéo de 20 s, quelques centimes de voix, quelques Mo de stockage.
- À prévoir : règle de cycle de vie du bucket pour supprimer `videos/` après 30 jours.

### Vidéo : tout est automatique (principe de simplicité)
La personne donne une photo et touche le bouton. Côté serveur (`videoApi.render`) : texte, style (beauté, mode ou promo) et phrases de la voix sont écrits par Gemini à partir de la **photo** (`autoCopy`) ; le détourage se fait avec un modèle de segmentation (IS-Net « general use », Apache 2.0, exécuté par onnxruntime-node, `functions/matting.js`) : gratuit, 3 à 6 s, les pixels du produit restent ceux de la photo ; si le modèle échoue : détourage local (`localCutout`), puis IA sur fond vert (`aiCutout`), puis photo entière dans un cadre. Le modèle (178 Mo) est dans Storage `models/isnet-general-use.onnx` et téléchargé une fois par instance (hors dépôt). `@imgly/background-removal-node` n'est pas utilisé (licence AGPL) ; un numéro WhatsApp ou un site dans le champ « contact » devient le QR code de fin ; voix off et musique par défaut. « Personnaliser » (facultatif) permet de changer style, format, textes, musique, voix, QR code. Après la création, « Modifier » reprend ce que le site a choisi (`used` dans la réponse).


### Visuels qui changent

L'accueil, la page Studio et le tutoriel changent à chaque visite (`static/js/site.js`, compteur `sa_rot` dans localStorage, hasard sinon) : paire avant/après des visuels (`IMGPAIRS` dans `build.mjs`), trio photo → détourage → vidéo et ordre des vidéos d'exemple (`VEX`). Pour ajouter un exemple : `static/img/video/{before,cut,ex}-<id>.webp` + `static/video/exemples/ex-<id>-{fr,en}.mp4`, puis ajouter `<id>` à `VEX` et son nom dans `SHOW.*.styles`.

### Vidéo pub v3 : HD, photo retouchée, gros plans, 360°

- **HD** : tout est dessiné dans une grille de 720 px puis rendu ×1,5 (1080 × 1920, 1080 × 1080, 1920 × 1080) ; image à 24 i/s, x264 crf 19, plus de grain (image plus nette et fichier plus léger). Le dessin est réparti sur les processeurs (`videoWorker.js`, une tranche d'images par fil, puis recollage avec ffmpeg) : environ 40 s pour 20 s de vidéo sur 4 processeurs, probablement 60 à 80 s sur 2. Fonction `slashatlasVideo` : 4 Go, 2 processeurs (le quota de la région interdit 4 processeurs × 6 instances : pour passer à 4, demander une hausse du quota Cloud Run « CPU allocation per project and region »), 9 minutes.
- **Photo retouchée avant tout** (`functions/enhance.js`) : étirement des niveaux, éclaircissement des photos sombres, équilibre des blancs léger, couleurs plus vives, netteté (fine + « clarté »), agrandissement doux des petites photos. Aucun pixel inventé.
- **Produit « refait en studio » par l'IA** (`studioShot` dans `videoApi.js`) : Gemini (modèle image) refait la photo du produit — même produit, même logo, mieux éclairé, net, ENTIER (un plat garde toute son assiette) — sur un fond gris uni, puis le détourage (IS-Net) est appliqué à cette image propre. Jamais pour une personne (`subject = person` : son visage et sa silhouette restent les siens). Si l'IA échoue (délai de 85 s, refus), la vidéo utilise le détourage de la photo retouchée ; pour un plat, la photo entière dans un cadre (un plat mal détouré perd son assiette). Compteurs d'administration : `videoStudioShot` et `videoStudioShotMiss`.
- **Types de vidéo** (`MODELS` dans `video.js`, choisis par la personne ou par l'IA d'après la photo, avec un peu de hasard) : `zoom` (gros plan cinéma), `tour360` (le produit tourne sur un plateau, perspective + face arrière + reflet), `lancement`, `classique`, `promo`, `catalogue` (plusieurs photos). Scènes : `hero` (produit en très gros plan, caméra qui avance, halo de lumière), `spin`, `detail` (zoom sur une partie du produit, limité à 1,9 pixel écran par pixel de la photo pour ne pas flouter), plus `hook`, `product`, `benefits`, `offer`, `cta`.
- **Intégration du produit** : lueur de la couleur du décor autour du produit (`haloOf`), ombre au sol, reflet, éclat de lumière : il ne paraît pas collé sur le fond.
- **QR code** : plus petit (27 % de la largeur), nettement séparé du numéro, avec « Scannez pour commander ».
- Le prix reste de 4 crédits, tout compris (retouche, studio IA, rendu HD). À surveiller : le coût de l'image IA (jusqu'à 3 par vidéo).

### Affiche de vente (À VENDRE, prix, devise, réduction, marque, contact, petit QR)

- **Quelles commandes** : `src/sale.mjs` (`isSale`) : mode, produit, beauté, bijoux, tech, auto, maison, packaging, food, immobilier (produit, plat, bien ; une personne seulement pour la mode et la beauté). Ni les affiches à texte, ni les effets, ni les commandes vidéo.
- **Studio « Générer ici »** : encadré « Affiche de vente » avec une case par élément (étiquette À VENDRE / PROMO / NOUVEAU / À LOUER, prix + devise au choix, ancien prix barré, réduction, marque, contact, petit QR code) et 7 présentations (bandeau, étiquette, pastille, colonne, ruban, sobre, promo flash ; « Automatique » en choisit une). Tout est dessiné par `static/js/sale.js` dans le navigateur à partir des textes tapés : aucune faute, chiffres exacts, recomposition gratuite et immédiate quand on change une case. L'IA reçoit seulement une consigne de composition (sujet centré, bas dégagé, aucun texte) : `sale: true` dans la requête `generate`.
- **Commande copiée** : même encadré sur la page de la commande ; les éléments cochés s'ajoutent à la consigne (`SALE` dans `build.mjs`), avec une zone libre en bas à droite pour le QR.
- **Images d'exemple du site** : `scripts/salemark.mjs` pose ces éléments (modèles, emplacements, marques, prix, devises et contacts variés, QR de 8 à 12 % de l'image) sur les images de base `assets/c-base/<slug>-apres.webp` (hors du site) et écrit `static/img/c/<slug>-apres.webp` et `-t.webp`. Relançable sans risque : `node scripts/salemark.mjs`.
- **Refaire les images** : `scripts/regen_sale_cf.mjs` (Cloudflare FLUX, gratuit, quota du jour) refait les bases avec une composition qui laisse la place (`CF_ACCOUNT_ID`, `CF_API_TOKEN` en variables d'environnement, jamais dans un fichier) ; une base n'est remplacée que si la nouvelle image est réussie ; reprise le lendemain si le quota est atteint. Ensuite : `node scripts/salemark.mjs && node build.mjs && node check.mjs`, puis déploiement.
- QR du Studio (hors affiche de vente) plus petit : 8,5 / 11,5 / 16 % de l'image (s / m / l).

### Versions des images et vidéos (cache)

Images et vidéos sont servies avec un cache d'un an (`immutable`) / 7 jours : un fichier remplacé sous le même nom restait chez ceux qui l'avaient déjà vu (vignettes sans affiche de vente, anciennes vidéos d'exemple). `build.mjs` ajoute donc `?v=…` à chaque adresse d'image (`IMGV` : empreinte des noms et tailles de `static/img/c` et `static/img/video`, aussi lue par `site.js` et `try.js` via `data-imgv` sur `<body>`) et à chaque vidéo d'exemple (empreinte du fichier). Rien à faire à la main : il suffit de reconstruire et de déployer.

## Étiquette « Meilleur rendu avec SlashAtlas »

Affichée sur les pages de commande (bloc « Pourquoi générer ici ? » + bouton), dans le bloc « après la copie » et en tête du Studio (`BEST` dans `build.mjs`, styles `.best*` dans `site.css`). Elle n'annonce que ce que le Studio fait réellement :

1. **Photo retouchée avant l'IA** (`polishPhoto` dans `functions/studio.js`, basé sur `enhance.js` : niveaux, gamma, balance des blancs, vibrance, netteté, taille).
2. **Textes exacts** : marque, prix, contact et QR code sont dessinés par le navigateur (`sale.js`, `try.js`), jamais par l'IA d'image.
3. **Clause « qualité studio »** ajoutée au prompt (`composePrompt`) : produit identique à la photo, lumière soignée.
4. **Retouche gratuite après génération** (QR, textes).

À mesurer pour confirmer la promesse : comparer dans `/admin` « essais » (Générer ici) et « copies » par commande ; la partie Gemini (clause qualité, `polishPhoto`) n'a pas encore été testée en production avec la clé de l'API.

## Parrainage (crédits gratuits)

- Chaque compte a un code de 7 caractères (`StudioUsers.refCode`, table `StudioRefCodes`) ; lien `https://slashatlas.com/?ref=CODE`, mémorisé 60 jours (`sa_ref`, `site.js`) et envoyé à la création du compte (`/api/me`, `attachReferrer`). Jamais à soi-même, jamais pour un compte déjà existant.
- Récompense : **crédits uniquement**, versés quand le filleul **paie** un pack par mobile money (`referralReward`, appelée dans `settle`, une seule fois par commande via le journal `referral_<commande>`). Rien à l'inscription (pas de faux comptes rentables), rien sur le pass sans pub ni sur les paiements par carte (rétrofacturation), commission à **chaque** rechargement du filleul, sans limite de durée (`REF.months = 0`).
- Barème : p6 → 1, p20 → 3, p55 → 8, p160 → 24 crédits (≈ 15 %). Un crédit coûte ≈ 40 FCFA (Gemini) ; marge brute si tous les crédits (achetés + commission) sont utilisés : p6 ≈ 49 %, p20 ≈ 39 %, p55 ≈ 35 %, p160 ≈ 33 %. Un auto-parrainage revient à un rabais d'environ 10 % pour le fraudeur, jamais à une perte.
- Tableau de bord : page `/parrainage/` (`/en/referral/`), API `/api/referrals` : lien, amis inscrits (`refCount`), acheteurs (`refBuyers`), crédits gagnés (`refCredits`), 50 derniers amis (`StudioReferrals`, nom masqué). Compteurs globaux dans `SlashAtlasStats` (`referrals`, `referral_credits`).
- Appels à l'action : accueil, page de détail d'une commande, Studio (bouton « Gagner des crédits », bandeau quand le solde est à 0, lien dans la fenêtre d'achat).

## Catégorie « Vue du ciel (drone) »
8 commandes (`skyview`, `skypet`, `skygroup`, `skyproduct`, `skyshop`, `skybeach`, `skyfood`, `skycar`) dans `src/data_extra.mjs` : la photo de l’utilisateur devient une vue de drone à la verticale (le sujet petit au centre d’un grand décor, tête levée vers la caméra). Elles passent par « Générer ici » comme les autres. Pas encore d’image d’exemple (poster en dégradé) : à créer quand le quota Cloudflare revient (un exemple par commande, `scripts/genimages_cf.mjs`, ajouter `drone` à `PRIORITY`).

## Catégorie « Afro Fashion et top modèles »
16 commandes (`afrotopmodel`, `afrorunway`, `afroelegant`, `afrodoll`, `afrorealistic`, `afrorooftop`, `afrobeach`, `afrowax`, `afrogarden`, `afrocity`, `afrocar`, `afrovilla`, `afroneon`, `afroceremony`, `afroduo`, `afrostory`) dans `src/data_extra.mjs` (bloc `AF`) : la personne de la photo mise en scène comme un top modèle dans différents décors. Consigne de fidélité commune (`AF_FR` / `AF_EN`) : visage, **couleur de peau exacte (sans l’éclaircir ni la lisser)**, coiffure, morphologie ; tenue élégante, aucune nudité, aucun texte. Le style « poupée » est nommé « poupée glamour rose » (sans marque). Pas encore d’image d’exemple : à créer quand le quota Cloudflare revient (ajouter `afrofashion` et `drone` à `PRIORITY` dans `scripts/genimages_cf.mjs`).
