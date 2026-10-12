# Passation : Afrolook et SlashAtlas (à lire en premier par un autre agent IA)

Dernière mise à jour : 12 octobre 2026. Branche de travail : `refonte_claude` (PR brouillon : https://github.com/bienvenuFanagnon/afrolook/pull/2).
Propriétaire : francophone, répondre **en français**, simple et direct, sans jargon. Il a donné une autorisation permanente de déployer (hébergement, fonctions) ; pour tout ce qui sort du cadre (suppression de données, envoi d'e-mails à de vrais comptes, dépenses), demander d'abord.

> **Aucun secret n'est écrit dans ce fichier.** Il dit où ils se trouvent et comment les redemander au propriétaire. Ne jamais les copier dans le dépôt.

---

## 1. Les deux projets

| | Afrolook | SlashAtlas |
|---|---|---|
| Quoi | Application sociale Flutter (Android, iPhone, web) + fonctions Firebase | Site statique FR/EN https://slashatlas.com : commandes IA pour affiches + Studio « Générer ici » payant en crédits |
| Dossier | racine du dépôt (`lib/`, `functions/`, `docs/`) | `slashatlas/` |
| Firebase | projet `afrolooki` (fonctions `us-central1`) | projet `slashatlas-studio` (fonctions `europe-west1`) |
| Doc d'exploitation | `docs/*.md` (un fichier par chantier : CARTES, QUIZ, CONTES, ETUDE, DEFI_EXTENSIONS, AUTH_EMAILS_GOOGLE…) | `slashatlas/STUDIO.md` (très complet : lire en entier) |

Application : ID `com.afrotok.afrotok`, nom « Afrolook », version actuelle `2.0.10+253` (`pubspec.yaml`). iOS : App Store Connect app `6811423047`.

---

## 2. Accès et secrets (où ils sont, comment les obtenir)

Les sessions sont des conteneurs temporaires : **rien de local ne survit**. Au démarrage, demander au propriétaire ce qui manque.

1. **Clé de compte de service Firebase** (fichier JSON `…firebase-adminsdk…json` du projet `afrolooki`).
   - Elle fonctionne aussi pour `slashatlas-studio` (rôle suffisant pour déployer et lire Firestore).
   - Utilisation : `export GOOGLE_APPLICATION_CREDENTIALS=/chemin/cle.json`, puis `npx firebase-tools deploy … --project afrolooki|slashatlas-studio --non-interactive`.
   - Si perdue : console Firebase → Paramètres du projet → Comptes de service → Générer une clé. Elle permet aussi d'appeler les API Google (Firebase Management, Identity Toolkit) avec `google-auth-library`.
2. **GitHub** : accès via les outils MCP `mcp__github__*` (pas de CLI `gh` classique). Dépôt `bienvenuFanagnon/afrolook`. Toujours pousser sur `refonte_claude`.
3. **Cloudflare Workers AI (images gratuites FLUX)** : 2 comptes gratuits, un jeton API chacun, **donnés par le propriétaire dans la conversation** (pas dans le dépôt). Variables : `CF_ACCOUNT_ID`, `CF_API_TOKEN`. Quota : 10 000 « neurones » par jour et par compte ; la doc dit remise à zéro à 00:00 UTC mais on a observé un blocage jusqu'à au moins 04:04 UTC. **À la fin, rappeler au propriétaire de supprimer ces jetons** (il le sait).
4. **Gemini** : secret `GEMINI_API_KEY` dans Secret Manager de `slashatlas-studio` (illisible pour un agent). Conséquence : tout ce qui dépend de Gemini **n'a jamais été testé en production par nous** : génération d'images du Studio, `polishPhoto`, clause « qualité studio », `studioShot` et `autoCopy` des vidéos. Demander au propriétaire de faire un essai réel et de coller les erreurs éventuelles.
5. **FeexPay** (paiement mobile money) : secret `FEEXPAY_API_KEY` (Secret Manager) ; boutique `crZfM9il1xK9uJ6` ; l'activation de la carte bancaire attend le KYC (`CARD.enabled = false`).
6. **SMTP LWS (e-mails d'Afrolook)** : `functions/.env` (`SMTP_USER`, `SMTP_PASS`), **ignoré par git**. Un clone neuf ne l'a pas : copier `functions/.env.example` et demander les valeurs. **Ne jamais déployer les fonctions Afrolook sans ce fichier** (les e-mails casseraient). Le serveur n'accepte que l'adresse du compte SMTP comme expéditeur. Le port 587 est bloqué depuis les conteneurs : impossible de tester l'envoi d'ici.
7. **Codemagic** (builds iOS/Android), **Shorebird** (correctifs Dart sans passer par le store, `shorebird.yaml`), **Play Console**, **App Store Connect** : accès du propriétaire uniquement. Un agent prépare le code et `codemagic.yaml`, le propriétaire lance les builds.
8. **Compte administrateur du site** : `jorbienvenu@gmail.com` (hub `/admin/`).
9. **Environnement** : Flutter 3.47 / Dart 3.13 installables dans un dossier temporaire (`flutter pub get`, `flutter analyze`). Playwright + Chromium dans `/opt/pw-browsers` pour tester le site. Test local du site : `cd slashatlas/dist && python3 -m http.server 8099`.

---

## 3. Commandes utiles

SlashAtlas (depuis `slashatlas/`) :
```
node build.mjs && node check.mjs                      # génère dist/ + vérifie ~1544 pages
npx firebase-tools deploy --only hosting --project slashatlas-studio --non-interactive
npx firebase-tools deploy --only hosting,functions:slashatlas:slashatlasApi --project slashatlas-studio --non-interactive
```
Le groupe de fonctions s'appelle `slashatlas` (`slashatlasApi`, `slashatlasVideo`). Pour la vidéo : `functions:slashatlas:slashatlasVideo` (4 Gio, 2 CPU, limite de quota Cloud Run expliquée dans `STUDIO.md`).

Afrolook : `cd functions && npm run build`, puis `npx firebase-tools deploy --only functions:NOM --project afrolooki`. Application : `flutter analyze` (pas d'erreurs attendues ; des centaines d'avertissements anciens sont normaux).

---

## 4. Ce qui est fait (résumé par chantier)

### SlashAtlas (site + Studio)
- **Site** FR/EN, 718 commandes, 34 catégories, générateur statique (`build.mjs`, `check.mjs`, `src/*.mjs`), cache d'images versionné (`IMGV`), images affichées en entier (cadre au format de la commande), cartes plus larges.
- **Studio « Générer ici »** : connexion Google, crédits (`StudioUsers`, `StudioLedger`), génération Gemini, retouche, QR code, marque/contacts, partage ; paiement FeexPay ; pass « sans pub ».
- **Affiches de vente** (À VENDRE / prix / devise / remise / marque / contact / petit QR) : compositeur `static/js/sale.js` (même code navigateur et serveur), options dans le Studio **et** sur la page de la commande (mêmes valeurs partagées via `localStorage sa_sale_v1`), clause ajoutée à la commande copiée, 194 images d'exemple recomposées avec un mélange dollars / FCFA.
- **Vidéos publicitaires v3** (onglet Vidéo du Studio) : HD 1080p, retouche automatique de la photo, plusieurs modèles (`classique`, `lancement`, `tour360`, `zoom`, `promo`, `catalogue`), détourage, QR plus petit, rendu en parallèle (threads). Section « vidéos créées avec le studio » sur l'accueil, après la section des images.
- **Statistiques** : événements, visites des pages de détail comptées, classement populaire, hub admin.
- **Étiquette « ★ Meilleur rendu avec SlashAtlas »** + encart « Pourquoi générer ici » (pages de commande, Studio, bloc après copie). Elle n'annonce que : photo retouchée avant l'IA, textes/QR dessinés par le site, clause qualité studio, retouche gratuite. À mesurer : essais vs copies par commande dans `/admin`.
- **Parrainage** (voir `STUDIO.md` section Parrainage) : lien `?ref=CODE`, commission **en crédits** à chaque rechargement du filleul (mobile money), **sans limite de durée** : +1 / +3 / +8 / +24 crédits pour les packs 6 / 20 / 55 / 160 ; marges calculées (≥ 33 %). Page `/parrainage/` (`/en/referral/`), compteurs, bandeaux (accueil, détail d'une commande, Studio quand le solde est à 0, fenêtre d'achat), texte « jusqu'à 24 crédits par ami ». Testé sur Firestore avec des comptes jetables.
- **Bouton « Se connecter »** dans l'en-tête (mobile et ordinateur), connexion Google directe depuis toutes les pages, « Mon compte » ensuite.

### Afrolook
- **Cartes** : correction de l'erreur « Impossible de créer la carte » (LateError venant de `debugNeedsPaint` en release), rapport d'erreurs `cardReport` (collection `CardErrors`).
- **Défis** : jamais monétisés (option masquée, imposée côté serveur, un post monétisé ne peut pas devenir un défi) ; un défi peut être boosté en publicité avec son propre bouton Participer (`lib/pages/defi/defi_boost.dart`, `lib/pages/pub/ad_actions.dart`).
- **E-mails de validation / mot de passe oublié** : fonctions `authSendVerificationEmail` et `authSendPasswordReset` (déployées sur `afrolooki`), envoi par notre SMTP, repli sur l'envoi natif de Firebase (`lib/services/auth/auth_email_service.dart`). Journal `AuthEmailLog`. **L'envoi réel n'a pas pu être testé** : à vérifier avec un vrai compte puis lire `AuthEmailLog`.
- **Connexion / inscription avec Google** (Android, iPhone, web) : `lib/services/auth/google_auth_service.dart`, bouton dans `lib/pages/auth/authTest/components/google_sign_in_button.dart`, mode « profil à compléter » dans `SignUpScreen(googleUser)` et `SignUpFormEtap3(googleUser)`. Google est activé dans Firebase, `google-services.json`, `GoogleService-Info.plist` et le schéma d'URL de `Info.plist` sont à jour. Détails : `docs/AUTH_EMAILS_GOOGLE.md`. Le SHA-1 de signature Play Store est bien enregistré.
- **Sessions** : 60 jours sans ouvrir l'app avant déconnexion (avant : 3), plus de retour à la connexion sur simple panne réseau (écran « Réessayer »), attente de la restauration Firebase avant « session expirée ».
- **Codemagic** : `beta_groups` retiré (erreur « Cannot add internal group to a build »).
- Versions : 2.0.9+252 puis 2.0.10+253.

---

## 5. Ce qui reste à faire

### À faire par un agent
1. **Régénérer les images d'exemple (Cloudflare)**, dès que le quota est revenu (le propriétaire sait que c'est le soir/le lendemain) :
   - catégories vidéo/motion : `CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/genimages_cf.mjs --cats video,motion --limit 90` ;
   - affiches de vente (les deux comptes en parallèle) : `node scripts/regen_sale_cf.mjs --mod 2 --rem 0` puis `--rem 1` avec l'autre compte ;
   - ensuite `node scripts/salemark.mjs && node build.mjs && node check.mjs`, déployer l'hébergement, commit/push ;
   - 33 commandes de vente n'ont pas encore d'image de base (`assets/c-base`, `composited.json`, `regen.json` suivent l'avancement).
   - Un déclencheur planifié existait (`trig_01XfqaDe84DxeUMBZACpEhSw`, 12/10 15:40 UTC) : il appartient à la session précédente, vérifier s'il a tourné (`list_triggers`) ou refaire à la main.
2. **Vérifier de bout en bout** (avec le propriétaire, car il faut des comptes réels) : une génération d'image payante, une vidéo complète (voix TTS, `studioShot`), un parrainage complet (inscription via lien → achat → crédits du parrain, `StudioReferrals`), l'envoi réel des e-mails d'Afrolook.
3. **Afficher les compteurs de parrainage** (`SlashAtlasStats.referrals`, `referral_credits`) dans `/admin` (collectés, pas encore affichés).
4. **Afrolook** : ajouter une phrase sur le parrainage de SlashAtlas dans les conditions du site si le propriétaire le veut ; surveiller `CardErrors`, `AuthEmailLog`.
5. **Anciennes tâches nominalement ouvertes** : Stickers phase 2 (sélecteur, récents, pack officiel), Étude plus tard (eCPM, examens blancs, duels, plan universités), documentation vidéo (#50). Voir `docs/STICKERS_SPEC.md`, `docs/ETUDE.md`, `docs/ETUDE_UNIVERSITES.md`.

3bis. **Images d'exemple des deux nouvelles catégories** « Vue du ciel (drone) » (8 commandes `sky*`) et « Afro Fashion et top modèles » (16 commandes `afro*`) : aujourd'hui des dégradés sans image. Les créer avec `scripts/genimages_cf.mjs` quand le quota Cloudflare revient (voir STUDIO.md).

### À faire par le propriétaire (le lui rappeler)
- **Compiler et publier Afrolook** (version 2.0.10+253) sur Play Store et App Store : correctifs cartes, défis, Google, e-mails, sessions. **La connexion Google exige un build store** (Shorebird ne suffit pas : nouveau plugin natif + fichiers de configuration). Un patch Shorebird depuis le code actuel afficherait un bouton Google qui échoue ; proposé : masquer le bouton tant que le plugin est absent pour livrer les e-mails par patch.
- Ajouter `afrolookmedia.com` aux domaines autorisés (Firebase, Authentication, Paramètres) pour Google sur le web.
- Demander une **augmentation du quota CPU Cloud Run** pour passer `slashatlasVideo` à 4 CPU (limité à 2 actuellement).
- Règle de cycle de vie GCS : supprimer `videos/` après 30 jours.
- Supprimer les jetons Cloudflare une fois les images régénérées.
- Tester les e-mails (mot de passe oublié, renvoi du lien) puis ouvrir `AuthEmailLog` ; si l'expéditeur actuel (`SMTP_USER`, compte d'un autre domaine) gêne, fournir le mot de passe de `contact@afrolookmedia.com`.

---

## 6. Pièges connus

- **iPhone : bouton Google masqué** (règle App Store 4.8 : Google exige aussi « Se connecter avec Apple »). `GoogleAuthService.isAvailable` = `false` sur iOS. Pour le rouvrir, ajouter Sign in with Apple d'abord (voir `docs/AUTH_EMAILS_GOOGLE.md`).

- **Build Android release (R8)** : l'ajout de `google_sign_in` a fait échouer R8 (« Missing class com.google.android.gms.auth.api.credentials.* », ancienne API mentionnée par `smart_auth`, utilisée par `pinput`). Corrigé par `android/app/r8-missing-rules.pro` (référencé dans `android/app/build.gradle`). Si R8 réclame d'autres classes, lire `android/app/build/outputs/mapping/release/missing_rules.txt` et compléter ce fichier. `android/app/proguard-rules.pro` est référencé mais **absent du dépôt** (il n'existe que sur la machine du propriétaire).

- Afrolook : `functions/.env` hors git (voir §2). Fichiers Dart avec BOM (ex. `confirm_user.dart`) : éditer en UTF-8 sans casser le début.
- Afrolook garde sa **propre session** (SharedPreferences `token` + `last_active_timestamp`), pas seulement Firebase ; les règles Firestore exigent `request.auth`.
- SlashAtlas : `dist/` est généré, ne pas l'éditer ; changer `static/js/*` ou `src/*` puis `node build.mjs`. Les URL d'images portent un numéro de version (`IMGV`), les mp4 un hachage, à cause du cache `immutable` d'un an.
- Cloud Run : le quota CPU compte les révisions transitoires en double ; ne pas augmenter `slashatlasVideo` au-delà de 2 CPU sans quota.
- Les scripts Node en ESM ont besoin de `.cjs` ou d'`import()` dynamique ; `NODE_PATH=slashatlas/functions/node_modules` pour les scripts hors dossier.
- Ne jamais écrire de clé ou de mot de passe dans le dépôt ; ne pas envoyer de vrais e-mails pour « tester ».
- Messages de commit : terminer par les lignes d'attribution demandées par l'environnement ; ne jamais y mettre l'identifiant du modèle.
