# Passation : Afrolook et SlashAtlas (à lire en premier par un autre agent IA)

Dernière mise à jour : 12 octobre 2026, fin d'après-midi (UTC). Branche de travail : `refonte_claude` (PR brouillon : https://github.com/bienvenuFanagnon/afrolook/pull/2).
Propriétaire : francophone, répondre **en français**, simple et direct, sans jargon. Il a donné une autorisation permanente de déployer le site et les fonctions ; pour tout ce qui sort du cadre (suppression de données, e-mails à de vrais comptes, dépenses, soumission à un store sans qu'il l'ait demandé), demander d'abord. Dire honnêtement ce qui n'a pas pu être testé.

> **Aucun secret n'est écrit dans ce fichier.** Il dit où ils se trouvent et comment les redemander au propriétaire. Ne jamais les copier dans le dépôt. **Ne pas aller les chercher dans l'historique d'une conversation** : une vérification de sécurité a déjà bloqué ce réflexe. Les redemander au propriétaire, qui les colle dans le chat.

---

## 1. Les deux projets

| | Afrolook | SlashAtlas |
|---|---|---|
| Quoi | Application sociale Flutter (Android, iPhone, web) + fonctions Firebase | Site statique FR/EN https://slashatlas.com : commandes IA pour affiches + Studio « Générer ici » payant en crédits |
| Dossier | racine du dépôt (`lib/`, `functions/`, `docs/`) | `slashatlas/` |
| Firebase | projet `afrolooki` (fonctions `us-central1`) | projet `slashatlas-studio` (fonctions `europe-west1`) |
| Doc d'exploitation | `docs/*.md` (un fichier par chantier : CARTES, QUIZ, CONTES, ETUDE, DEFI_EXTENSIONS, AUTH_EMAILS_GOOGLE…) | `slashatlas/STUDIO.md` (très complet : lire en entier) |

Application : ID `com.afrotok.afrotok`, nom « Afrolook », version `2.0.10+253` (`pubspec.yaml`). iOS : App Store Connect app `6811423047`. L'entreprise est **AFROLOOK, entreprise individuelle** (Lomé, Togo) ; le propriétaire exploite aussi Epargne+ (budget et épargne par mobile money, sans carte).

---

## 2. Accès et secrets (où ils sont, comment les obtenir)

Les sessions sont des conteneurs temporaires : **rien de local ne survit**. Au démarrage, demander au propriétaire ce qui manque.

1. **Clé de compte de service Firebase** (fichier JSON `…firebase-adminsdk…json` du projet `afrolooki`). Elle fonctionne aussi pour `slashatlas-studio` (déployer, lire/écrire Firestore, API Firebase Management et Identity Toolkit).
   - Utilisation : `export GOOGLE_APPLICATION_CREDENTIALS=/chemin/cle.json`, puis `npx firebase-tools deploy … --project afrolooki|slashatlas-studio --non-interactive`. Pour lire Firestore : `firebase-admin` avec `initializeApp({projectId})`.
   - Si perdue : console Firebase → Paramètres du projet → Comptes de service → Générer une clé.
2. **GitHub** : outils MCP `mcp__github__*` (pas de CLI `gh` classique). Dépôt `bienvenuFanagnon/afrolook`. Toujours pousser sur `refonte_claude`.
3. **App Store Connect (Apple)** : clé d'API (rôle App Manager) fournie par le propriétaire le 12/10 : Key ID `92635PJ66F`, Issuer ID `f8d00327-4eda-47d2-bcab-0e09d7253cd5`, fichier privé `AuthKey_92635PJ66F.p8` (**à redemander**, ne pas le mettre dans le dépôt ; le propriétaire doit la supprimer après usage). Méthode : JWT signé ES256 (`aud: appstoreconnect-v1`, durée ≤ 20 min), appels REST sur `https://api.appstoreconnect.apple.com/v1/…` (builds, `appStoreVersions`, localisations « Nouveautés », `appStoreReviewDetail`, `reviewSubmissions`). Le contenu exact d'un build (commit) n'est pas dans l'API : le déduire des heures ou de Codemagic.
4. **Cloudflare Workers AI (images gratuites FLUX)** : jeton API + ID de compte **donnés par le propriétaire dans la conversation** (compte n°1 : jeton fourni le 12/10, quota épuisé de nouveau après ≈ 100 images ; le compte n°2 n'a pas été retrouvé). Variables : `CF_ACCOUNT_ID`, `CF_API_TOKEN`. Quota : 10 000 « neurones » par jour et par compte ; la doc dit remise à zéro à 00:00 UTC mais on a observé un blocage bien après (hypothèse : renouvellement 24 h après la première utilisation). Option qui lève la limite : passer le compte en **Workers Paid** (≈ 5 $/mois, < 1 $ de conso pour tout ce qui reste). **À la fin, rappeler au propriétaire de supprimer les jetons.**
5. **Gemini** : secret `GEMINI_API_KEY` dans Secret Manager de `slashatlas-studio` (illisible pour un agent). **Tout ce qui dépend de Gemini n'a jamais été testé en production par nous** : génération d'images du Studio, `polishPhoto`, clause « qualité studio », `studioShot` et `autoCopy` des vidéos, et la qualité des nouvelles commandes (drone, Afro Fashion). Demander au propriétaire un essai réel et les erreurs éventuelles.
6. **FeexPay** (paiement mobile money et, bientôt, carte) : secret `FEEXPAY_API_KEY` (Secret Manager) ; boutique `crZfM9il1xK9uJ6`. Voir §5 pour le dossier carte (KYC).
7. **SMTP LWS (e-mails d'Afrolook)** : `functions/.env` (`SMTP_USER`, `SMTP_PASS`), **ignoré par git**. Un clone neuf ne l'a pas : copier `functions/.env.example` et demander les valeurs. **Ne jamais déployer les fonctions Afrolook sans ce fichier** (les e-mails casseraient). Le serveur n'accepte que l'adresse du compte SMTP comme expéditeur. Le port 587 est bloqué depuis les conteneurs : impossible de tester l'envoi d'ici.
8. **Codemagic** (builds iOS/Android), **Shorebird** (correctifs Dart sans store, `shorebird.yaml`), **Google Play Console** : accès du propriétaire uniquement. Un agent prépare le code et `codemagic.yaml`, le propriétaire lance les builds.
9. **Compte administrateur du site** : `jorbienvenu@gmail.com` (hub `/admin/`).
10. **Environnement** : Flutter 3.47 / Dart 3.13 installables dans un dossier temporaire (`flutter pub get`, `flutter analyze`). Pas d'Android SDK : impossible de reproduire un build Android ici. Playwright + Chromium dans `/opt/pw-browsers` pour tester le site (`cd slashatlas/dist && python3 -m http.server 8099`).

---

## 3. Commandes utiles

SlashAtlas (depuis `slashatlas/`) :
```
node build.mjs && node check.mjs                      # génère dist/ + vérifie ~1596 pages
npx firebase-tools deploy --only hosting --project slashatlas-studio --non-interactive
npx firebase-tools deploy --only hosting,functions:slashatlas:slashatlasApi --project slashatlas-studio --non-interactive
```
Le groupe de fonctions s'appelle `slashatlas` (`slashatlasApi`, `slashatlasVideo`). Vidéo : `functions:slashatlas:slashatlasVideo` (4 Gio, 2 CPU, limite de quota Cloud Run dans `STUDIO.md`).

Afrolook : `cd functions && npm run build`, puis `npx firebase-tools deploy --only functions:NOM --project afrolooki`. Application : `flutter analyze` (aucune erreur attendue ; des centaines d'avertissements anciens sont normaux).

---

## 4. Ce qui est fait

### SlashAtlas (site + Studio), 742 commandes, 36 catégories
- **Site** FR/EN, générateur statique (`build.mjs`, `check.mjs`, `src/*.mjs`), cache d'images versionné (`IMGV`), images affichées en entier, cartes plus larges, bouton **« Se connecter »** dans l'en-tête (mobile et ordinateur, connexion Google directe, « Mon compte » ensuite).
- **Studio « Générer ici »** : connexion Google, crédits (`StudioUsers`, `StudioLedger`), génération Gemini, retouche, QR code, marque/contacts, partage ; paiement FeexPay ; pass « sans pub ».
- **Affiches de vente** (À VENDRE / prix / devise / remise / marque / contact / petit QR) : `static/js/sale.js`, options dans le Studio **et** sur la page de la commande ; 194 images d'exemple recomposées (mélange $ et FCFA).
- **Vidéos publicitaires v3** (onglet Vidéo) : HD 1080p, retouche de la photo, modèles `classique`/`lancement`/`tour360`/`zoom`/`promo`/`catalogue`, détourage, rendu en parallèle.
- **Étiquette « ★ Meilleur rendu avec SlashAtlas »** + encart « Pourquoi générer ici ». Elle n'annonce que ce qui existe vraiment (photo retouchée avant l'IA, textes/QR dessinés par le site, clause qualité, retouche gratuite).
- **Parrainage** (`STUDIO.md`) : lien `?ref=CODE`, commission **en crédits**, à **chaque** rechargement du filleul (mobile money, pas la carte), sans limite de durée : +1 / +3 / +8 / +24 pour les packs 6 / 20 / 55 / 160 ; marges ≥ 33 %. Page `/parrainage/` (`/en/referral/`), bandeaux partout, texte « jusqu'à 24 crédits par ami ». Testé sur Firestore avec des comptes jetables (compteurs nettoyés).
- **Deux catégories ajoutées le 12/10** (dans `src/data_extra.mjs` ; images « Vue du ciel » faites, « Afro Fashion » à refaire) :
  - **« Vue du ciel (drone) »** : 8 commandes `skyview`, `skypet`, `skygroup`, `skyproduct`, `skyshop`, `skybeach`, `skyfood`, `skycar` (la photo vue d'un drone, sujet petit au centre d'un grand décor) ;
  - **« Afro Fashion et top modèles »** : 16 commandes `afro*` (studio, défilé, soirée, poupée glamour rose, portrait réaliste, toit, plage, tissus wax, jardin, rue, voiture, villa, néon, cérémonie, couple, story). Consigne commune de fidélité : visage, **couleur de peau exacte sans l'éclaircir ni la lisser**, coiffure, morphologie ; tenue élégante, aucune nudité.
- **Statistiques du 11 au 12/10** (peu de trafic, en partie des tests) : 484 pages vues, 91 copies, 18 clics « Générer ici », 5 comptes, 1 commande payée (500 FCFA). Pas de métrique de visiteurs uniques. **Les publicités sont désactivées** (`SlashAtlasSettings/ads.enabled = false`, aucun emplacement) : à activer dans `/admin` après création des emplacements « lb » et « rect » dans AdSense. Prévision pour 50 000 visiteurs/jour : ≈ 1,4 / 4,9 / 14,4 millions de FCFA par mois (prudent / moyen / optimiste) ; les ventes de crédits peuvent peser davantage.

### Afrolook
- **Cartes** : correction de « Impossible de créer la carte » (LateError `debugNeedsPaint`), rapport `cardReport` (collection `CardErrors`) ; **carte neuve : boutons Enregistrer et Partager ajoutés** en mode création (pas pour une participation à un défi, `presetPostId`).
- **Défis** : jamais monétisés (option masquée, imposée côté serveur, conversion refusée) ; un défi peut être boosté en publicité avec bouton Participer.
- **E-mails de validation / mot de passe oublié** : fonctions `authSendVerificationEmail` et `authSendPasswordReset` (déployées), repli sur Firebase (`lib/services/auth/auth_email_service.dart`), journal `AuthEmailLog`. **Envoi réel non testé.**
- **Connexion / inscription avec Google** (Android et web ; **masquée sur iPhone**, règle App Store 4.8) : `lib/services/auth/google_auth_service.dart`, bouton `google_sign_in_button.dart`, mode « profil à compléter » (`SignUpScreen(googleUser)`, `SignUpFormEtap3(googleUser)`). Google activé dans Firebase, fichiers de config et schéma d'URL iPhone à jour, SHA-1 Play Store enregistré. Détails : `docs/AUTH_EMAILS_GOOGLE.md`.
- **Sessions** : 60 jours sans ouvrir l'app avant déconnexion (avant : 3), plus de retour à la connexion sur simple panne réseau (écran « Réessayer »).
- **Android (R8)** : règle `android/app/r8-missing-rules.pro` pour les classes `auth.api.credentials` (ajout de `google_sign_in`). `codemagic.yaml` : `beta_groups` retiré.
- **iPhone** : version 2.0.10, build **22**, créée et **envoyée à la revue Apple le 12/10** (état « En attente de revue », publication **manuelle**, « Nouveautés » en 7 langues). Hypothèse non vérifiée : le build 22 contient le commit `4b59788` (Google masqué) mais probablement pas `ad8215d` (Enregistrer/Partager).
- Versions : 2.0.9+252 puis 2.0.10+253.

---

## 5. Ce qui reste à faire

### À faire par un agent
1. **Images d'exemple de la catégorie Afro Fashion (16 commandes `afro*`)** : à régénérer quand le quota Cloudflare revient (≈ 24 h après la dernière utilisation, soit vers le 13/10 15h40 UTC ; ou Workers Paid). Les premières images montraient des personnes d'origine asiatique : le script `scripts/genimages_cf.mjs` a maintenant un prompt « Black African person » pour cette catégorie, les anciennes images ont été supprimées. Commande : `node scripts/genimages_cf.mjs --cats afrofashion --limit 20`, puis `node build.mjs && node check.mjs`, déploiement de l'hébergement, commit/push. Le rappel du 13/10 15h50 UTC a échoué : le jeton Cloudflare du compte n°1 répond **401 Authentication error** (supprimé ou révoqué par le propriétaire) ; il faut un nouveau jeton (ou Workers Paid) fourni par le propriétaire dans le chat. Déjà faites le 12/10 : vidéo/motion (78), « Vue du ciel » (8), et les affiches de vente (208 commandes avec image, aucune à refaire). Pas d'image : cartes `portalrise` ok ; si Cloudflare refuse un prompt comme « NSFW » (faux positif), réessayer, ça passe souvent.
2. **Suivre la revue Apple** de la 2.0.10 (API App Store Connect : `reviewSubmissions`, état de la version) ; si refus, lire le message et répondre. Si le propriétaire valide, la publication est manuelle.
3. **FeexPay carte** : dossier KYC **validé le 16 octobre 2026** et paiement carte activé sur SlashAtlas (voir `slashatlas/STUDIO.md`, reste à faire : premier paiement test du propriétaire, puis la carte pour l'application Afrolook si voulu). Ancien état : dossier soumis (« Dossier en cours de validation »). Quand FeexPay l'active : régler `CARD.payin/payout` dans `slashatlas/functions/studio.js` avec la vraie grille (commission 3,9 % internationale / 3,5 % UEMOA + 3 % de frais de conversion, soit ≈ 6,9 % ; **utiliser un calcul `prix / (1 - taux)`** pour que le client paie tout, l'actuel multiplie), mettre `CARD.enabled = true`, tester avec un petit paiement du propriétaire. Limites carte actuelles : `CARD_LIMITS` (packs p20/p55/pass, 2 achats/jour/compte, 20 000 FCFA/mois). Chargeback : 70 $, seuil 1 %.
4. **Afficher dans `/admin`** les compteurs `SlashAtlasStats.referrals` et `referral_credits` (collectés, pas encore affichés).
5. **Vérifier de bout en bout avec le propriétaire** : une génération d'image payante, une vidéo complète, un parrainage complet, l'envoi réel des e-mails d'Afrolook (puis `AuthEmailLog`), le rendu des commandes drone et Afro Fashion.
6. **Plus tard** : « Se connecter avec Apple » (puis rouvrir Google sur iPhone), Stickers phase 2, Étude (eCPM, examens blancs, duels), documentation vidéo (#50). Voir `docs/STICKERS_SPEC.md`, `docs/ETUDE.md`, `docs/ETUDE_UNIVERSITES.md`.

### À faire par le propriétaire (le lui rappeler)
- **Relancer le build Android** (Shorebird ou Codemagic) après la règle R8 ; si R8 réclame d'autres classes, lire `android/app/build/outputs/mapping/release/missing_rules.txt` (le compléter dans `r8-missing-rules.pro`). Publier ensuite sur Google Play. **La connexion Google sur Android exige un build store** (Shorebird ne suffit pas : plugin natif + fichiers de config). Les correctifs Dart seuls (e-mails, cartes, sessions) peuvent passer par Shorebird depuis une version sans le plugin Google.
- **Activer les publicités** du site (AdSense : 2 emplacements « lb » et « rect », puis `/admin`).
- Ajouter `afrolookmedia.com` aux domaines autorisés (Firebase, Authentication) pour Google sur le web.
- Décider pour Cloudflare : Workers Paid (≈ 5 $/mois) ou attendre le quota ; **supprimer ensuite les jetons Cloudflare et la clé d'API App Store Connect**.
- Demander une augmentation du quota CPU Cloud Run (`slashatlasVideo` à 4 CPU) ; règle de cycle de vie GCS pour `videos/` (30 jours).
- Tester les e-mails d'Afrolook ; si l'expéditeur (`SMTP_USER`, compte d'un autre domaine) gêne, fournir le mot de passe de `contact@afrolookmedia.com`.
- Dossier FeexPay : répondre à leurs demandes éventuelles ; le contrat est rempli au nom d'AFROLOOK (entreprise individuelle), signature électronique à placer ou à faire sur leur plateforme. Déclarer clairement la vente de crédits numériques (SaaS). Epargne+ n'utilise pas la carte.

---

## 6. Pièges connus

- **iPhone : bouton Google masqué** (règle App Store 4.8 : Google exige aussi « Se connecter avec Apple »). `GoogleAuthService.isAvailable` = `false` sur iOS. Pour le rouvrir, ajouter Sign in with Apple d'abord.
- **Build Android release (R8)** : voir `android/app/r8-missing-rules.pro`. `android/app/proguard-rules.pro` est référencé mais **absent du dépôt** (il n'existe que chez le propriétaire).
- Afrolook : `functions/.env` hors git (voir §2). Fichiers Dart avec BOM (ex. `confirm_user.dart`) : éditer en UTF-8 sans casser le début.
- Afrolook garde sa **propre session** (SharedPreferences `token` + `last_active_timestamp`), pas seulement Firebase ; les règles Firestore exigent `request.auth`.
- SlashAtlas : `dist/` est généré, ne pas l'éditer ; changer `static/js/*` ou `src/*` puis `node build.mjs`. Les URL d'images portent un numéro de version (`IMGV`), les mp4 un hachage, à cause du cache `immutable` d'un an.
- Cloud Run : le quota CPU compte les révisions transitoires en double ; ne pas dépasser 2 CPU sur `slashatlasVideo` sans quota.
- Les scripts Node en ESM ont besoin de `.cjs` ou d'`import()` dynamique ; `NODE_PATH=slashatlas/functions/node_modules` pour les scripts hors dossier.
- Un autre générateur d'images gratuit (Pollinations) a été testé et **rejeté** : filigrane imposé et textes illisibles.
- Ne jamais écrire de clé ou de mot de passe dans le dépôt ; ne pas envoyer de vrais e-mails pour « tester » ; ne pas fabriquer de chiffres (revenus, adresses, déclarations légales) dans les formulaires des partenaires.
- Messages de commit : terminer par les lignes d'attribution demandées par l'environnement ; ne jamais y mettre l'identifiant du modèle.
