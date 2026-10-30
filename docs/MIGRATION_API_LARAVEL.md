# Migration d'Afrolook vers une API Laravel (plan du 27 octobre 2026, refait le 30 octobre 2026)

**Révision du 30/10/2026** : ajout des chantiers construits depuis le 27/10 : **régie Afrolook Ads** (module 24), **Partage et gagne** (module 26), **sites clients de l'API** (module 27) ; le **mur de tâches des partenaires** Tapjoy / ayeT / PubScale (module 25) est **abandonné** (partenaires non obtenus) ; relevé détaillé de la régie telle qu'elle existe (§17) ; nouvelle **phase préparatoire P** (sécurité, conservation du legacy, adresses stables) ; phase 5 coupée en **5a (argent)** et **5b (monétisation)** ; calendrier recalculé (§12) ; déroulé concret du travail (§16). Le chiffre « 4 à 5 mois et demi » de la première version **ne correspondait pas à la somme des phases** (29 à 37 semaines) : il est corrigé.

Statut : **plan à valider**. Rien n'est encore construit. Ce document est le **plan détaillé** ; **l'état d'avancement (ce qui est fait, ce qui reste) et les décisions sont dans `docs/PROJET_MEMOIRE.md`** (mémoire unique du projet, section 6). Le mettre à jour à chaque phase.

**Périmètre ajusté le 27/10/2026** : le module **Afrolove (rencontres) est abandonné** et les **pronostics sont supprimés** ; ils ne sont **pas migrés**. Les « pages qu'on n'affiche plus » ne sont pas migrées non plus (inventaire : `docs/PAGES_ORPHELINES.md`, à confirmer). Conséquences : le module 18 ci-dessous est barré, la phase 6 est allégée, et le travail total baisse d'environ 3 semaines.

## 1. Objectif et règles du jeu

- Séparer Afrolook en deux : **l'application Flutter** (affichage, interactions) et **une API Laravel** (toute la logique et les données), hébergée sur **un VPS avec Docker**, base **PostgreSQL**.
- **Raison** : la facture Firebase augmente avec les lectures / écritures Firestore, le transfert de données et le temps de calcul des fonctions. Sur un VPS, le coût est fixe.
- **Médias** : plus de Firebase Storage. Les fichiers vont **directement sur Cloudflare R2** (lecture par le CDN `cdn.afrolookmedia.com`).
- **On garde chez Firebase** : Authentification (e-mail, validation d'e-mail, Google, Apple), **Cloud Messaging (FCM)**, les **chats** (temps réel), Remote Config, App Check. Ces services sont gratuits ou bon marché, et le temps réel y est bien meilleur qu'ailleurs.
- **Précision du propriétaire (27/10/2026)** : les **pages et l'interface existent déjà** et sont **réadaptées** ; ce qui est **créé**, ce sont les **traitements** (les Cloud Functions) qui deviennent l'**API**. **Firebase ne sert plus au traitement ni au stockage des données métier** : il ne reste que l'authentification, FCM, les chats, Remote Config, App Check et **les tâches périodiques** (la planification reste chez Firebase et ne fait que **déclencher l'API** ; à confirmer, question 15 de `docs/PROJET_MEMOIRE.md`).
- **Règle d'or de la migration** : une fonctionnalité à la fois, chaque étape déployable, retour arrière possible, **jamais de coupure** pour les utilisateurs.

## 2. Ce que montre l'analyse du projet

| Mesure | Valeur |
|---|---|
| Application Flutter | 755 fichiers, ~377 000 lignes (pages : 300 000) |
| Code qui parle **directement** à Firestore | 290 fichiers (1 158 lectures, 1 123 `add`, 608 `update`, 299 `set`, 326 compteurs, 46 transactions, 38 lots) |
| Écoutes temps réel (`snapshots`) | 141 (Users 219 réf., Posts, Chats, Notifications, Messages, chroniques, rencontres, lives, groupes, canaux) |
| Fonctions serveur appelées par l'app (`httpsCallable`) | 93 distinctes |
| Fonctions Cloud | **Au 30/10 : ~180 appelables, 34 planifiées, 19 HTTP (webhooks, régie, retours des partenaires), 28 déclencheurs Firestore — ~28 100 lignes TypeScript** (le 27/10 : 152 / 25 / 7 / 28, ~21 000 lignes). Ajouts : régie `ads/` (~4 100 lignes, 24 fichiers) ; mur de tâches `offerwall/` (~1 500 lignes, 12 fichiers) **abandonné, non migré** |
| Tests serveur existants | 45 suites, 444 tests unitaires (Jest) + 5 scénarios d'intégration sur émulateur (`functions/integration/`) : **ils servent de cahier de recettes** pour réécrire les mêmes règles en Laravel |
| Règles de sécurité Firestore | 53 collections protégées : **c'est aujourd'hui la couche d'autorisation de l'application** |
| Documents | Users 2 046 · Posts 6 719 · **Notifications 318 391** · PostComments 5 502 · TransactionSoldes 5 370 · Invitations 3 916 · membres de canaux 8 231 · Chats 362 · messages 2 829 · rencontres 695 · lives 415 |
| Utilisateurs | ~2 000 inscrits, ~40 actifs par jour (très petit trafic) |
| Lectures Firestore | 553 000 par jour (mesure du 18/10), dont 98,9 % viennent de requêtes et d'écoutes |

**Où partent les lectures** (mesure par écran de l'application, 24-26 octobre, `ReadStats`) :
`discovery_boost_service` ≈ 40 % (3 sources), `feed_discovery_section` 5,6 %, `feed_preload_service` 4,4 %, `active_creators_service` ≈ 5 %, `feed_repository` ≈ 4 %, tableau de bord du contenu payant 5 %, `authProvider` ≈ 6 %, notifications ≈ 1 %.
→ **Plus de la moitié du coût vient du fil et de la découverte (module Publications).** C'est là qu'il faut commencer, après les fondations.

**Autres postes de coût déjà traités** : sortie de Cloud Storage (passée de 33 Go/jour à ~10 Go/jour grâce à R2), CPU des fonctions (~0,3 $/jour), poids des profils `Users`.

## 3. Avis franc sur l'intérêt de la migration

- **Ce que la migration règle vraiment** : le coût variable. Avec Postgres, une requête « le fil de cette personne » devient **une** requête SQL sur le VPS (et un cache Redis) au lieu de centaines de lectures facturées. Les compteurs, classements, listes de notifications et profils lourds (`followingIds`, `viewedPostIds`…) deviennent des tables normales. Le coût ne grandit plus avec le nombre de lectures.
- **Ce qu'elle ne règle pas** : à ~40 utilisateurs actifs par jour, la facture Firebase actuelle est probablement **modeste** (ordre de grandeur : quelques dizaines de dollars par mois). Un VPS coûte lui aussi de l'argent, plus du temps de maintenance. Le gain monte avec la croissance. **Il faut donc fixer un seuil de rentabilité avec la vraie facture** (voir « Questions à valider », n°1).
- **Le vrai coût du projet est le travail** : 290 fichiers de l'application écrivent aujourd'hui directement en base, et les règles Firestore font l'autorisation. Tout cela doit être **adapté** en appels API (les **écrans ne sont pas refaits** : le frontend est la copie de l'application actuelle dont seule la couche de données change), avec les règles portées côté serveur. Fourchette indicative recalculée le 30/10 (avec la régie, les tâches et le partage) : **9 à 12 mois** avec un seul chantier à la fois, **7 à 9 mois** avec deux chantiers en parallèle (détail §12), en livrant par étapes.
- **Parade au risque** : chaque phase a un **critère de sortie mesurable** (lectures Firestore en baisse, zéro écart de soldes, etc.). Si une phase ne rapporte pas, on s'arrête là : l'architecture « mixte » reste saine (Firebase pour le temps réel, Laravel pour le reste).

## 4. Architecture cible

```
  Application Flutter ──(HTTPS, jeton Firebase)──▶ Cloudflare (proxy, pare-feu, limite de débit)
        │                                                   │
        │                                                   ▼
        │                                         VPS (Docker Compose)
        │                                         ├─ Caddy/Nginx (TLS)
        │                                         ├─ Laravel (PHP-FPM ou Octane)  ◀── API /v1
        │                                         ├─ Horizon (files de travaux) + Scheduler
        │                                         ├─ PostgreSQL 16/17 (+ sauvegardes vers R2)
        │                                         └─ Redis (cache, files, limites de débit)
        │
        ├──▶ Firebase : Auth · FCM · Firestore (chats seulement) · Remote Config · App Check
        └──▶ Cloudflare R2 (envoi direct par URL signée) ──▶ CDN cdn.afrolookmedia.com
```

### 4.1 Authentification (Firebase reste la source d'identité)
1. L'application se connecte à Firebase comme aujourd'hui (e-mail, Google, Apple, validation d'e-mail).
2. Chaque requête API porte `Authorization: Bearer <jeton d'identité Firebase>` et `X-Firebase-AppCheck`.
3. Laravel vérifie la signature (clés publiques de Google, en cache), l'expiration et l'identifiant du projet, puis retrouve l'utilisateur par `firebase_uid`. Garde personnalisée `firebase`, paquet `kreait/laravel-firebase`.
4. Aucun mot de passe n'est jamais stocké chez nous. Suppression de compte : l'API supprime aussi l'utilisateur Firebase (SDK Admin).

### 4.2 Ce qui reste où, et pourquoi

| Élément | Où | Pourquoi |
|---|---|---|
| Connexion, e-mails de vérification, Google/Apple, réinitialisation | **Firebase Auth** | Demandé ; gratuit, fiable, déjà intégré |
| Notifications push | **FCM** (envoi depuis Laravel avec le SDK Admin) | Gratuit et sans quota ; seul l'envoi change de serveur. OneSignal : supprimé à la fin |
| Chats privés, groupes, discussions d'entreprise, réponses de chroniques | **Firestore** (inchangé) | Vrai temps réel, hors ligne, règles déjà écrites. Volume faible (2 800 messages) donc coût négligeable |
| Commentaires de lives (flux rapide) | **Firestore** | Temps réel pur |
| Remote Config, App Check, Crashlytics | **Firebase** | Gratuit, indépendant des données |
| Médias (images, vidéos, audio, stickers, musique) | **Cloudflare R2 + CDN** | Sortie gratuite ; envoi direct sans passer par le VPS (URL signée) |
| Données métier (utilisateurs, publications, commentaires, canaux, notifications, soldes, paiements, quiz, étude, contes, boutique, pubs, contenu payant, rencontres, classements) | **PostgreSQL via l'API Laravel** | C'est là que se trouve le coût variable |
| Tâches planifiées (34 au 30/10) | **Décidé le 30/10/2026 : planificateur Laravel sur le VPS** (sans coût supplémentaire : cron `* * * * * php artisan schedule:run`, files Horizon) ; Firebase Cloud Scheduler n'est plus utilisé pour ces tâches. Surveillance : alerte si une tâche ne s'exécute pas (Uptime Kuma / heartbeat), car si le VPS tombe, les tâches s'arrêtent | La logique et les données sont dans l'API ; la tâche Firebase est un simple déclencheur |
| Déclencheurs sur les données (28) | **Événements de l'API** (observateurs de modèles + files Horizon) pour les données migrées ; seuls les déclencheurs des **chats** restent sur Firestore | Un déclencheur Firestore ne peut plus voir des données qui sont dans PostgreSQL |
| Intelligence artificielle (résumés, traductions, suggestions) | Appels depuis Laravel vers **Cloudflare Workers AI** (inchangé côté fournisseur) | |
| Paiements (FeexPay, CinetPay, PayGate, Apple, Google Play) | **Laravel** (webhooks signés, journal de grand livre) | Transactions SQL vraies (`SELECT … FOR UPDATE`), plus sûr que Firestore pour l'argent |

### 4.3 Conventions de l'API
- `/api/v1/...`, JSON, **pagination par curseur** partout, `ETag` / `If-None-Match` (réponses 304 sans corps : économise la bande passante des téléphones), compression Brotli/gzip.
- Autorisation par **Policies Laravel** qui reprennent une à une les règles de `firestore.rules`.
- **`Idempotency-Key` obligatoire** sur tous les points d'écriture d'argent (dépôt, achat, cadeau, retrait) : un double clic ou un rejeu réseau ne double jamais un débit.
- Limitation de débit par utilisateur et par IP (Redis), journal d'audit des actions sensibles.
- Contrat décrit en **OpenAPI** (généré) ; le client Dart est généré à partir de lui (plus de modèles écrits à la main qui divergent).
- Erreurs au format unique `{ code, message, details }`, messages d'erreur en français (clés de traduction).

## 5. Modèle de données PostgreSQL (grandes lignes)

- **Clés** : les entités importées gardent leur **identifiant Firestore comme clé primaire texte** (les liens de partage existants `/post/<id>` et les références restent valables). Les nouvelles entités utilisent des ULID.
- **JSONB** seulement pour les champs réellement libres (préférences, métadonnées). Tout ce qui est liste qui grandit devient **table de liaison** : `follows`, `post_views` (avec durée de conservation), `post_likes`, `favorites`, `blocks`, `canal_members`…
- **Argent** : entiers (pièces / centimes), jamais de flottants. Table `ledger_entries` en **écriture double** (débit/crédit), le solde d'un portefeuille est vérifiable par somme. `wallets` (dépôt / gains, voir « deux soldes de pièces »), `transactions`, `withdrawal_requests`.
- **Notifications** (318 000 lignes) : table partitionnée par mois, purge automatique, index `(user_id, created_at desc)` ; compteurs de non-lus en Redis.
- **Recherche** : `pg_trgm` + index pour les pseudos, titres, canaux (remplace les requêtes « préfixe » de Firestore).
- **Fil** : classement calculé en SQL à partir de `post_scores` (le moteur de score actuel est porté en tâche planifiée), liste d'identifiants du fil mise en cache dans Redis par utilisateur.
- **Sauvegardes** : `pg_dump` quotidien + archivage continu (WAL) chez R2, restauration testée chaque mois.

## 6. Découpage par modules : API ou application, et phase

Légende : **API** = logique et données sur Laravel ; **Firebase** = reste sur Firebase ; **App** = reste dans Flutter (affichage, cache, saisie).
Difficulté : ● faible · ●● moyenne · ●●● élevée.

| # | Module | Collections / code actuel | Côté API Laravel | Reste dans Flutter / Firebase | Diff. | Phase |
|---|---|---|---|---|---|---|
| 0 | **Fondations** | — | Projet, Docker, authentification Firebase, utilisateurs (`firebase_uid`), envoi R2, observabilité, CI | Couche `ApiClient` (jeton, nouvelle tentative, 304), interrupteurs de bascule par module (Remote Config), version minimale par module | ●● | 0 |
| 1 | **Configuration** | AppConfig, AppData, Informations, Remote | Lecture publique mise en cache (une requête au démarrage) | Remote Config reste pour les interrupteurs | ● | 1 |
| 2 | **Notifications** | Notifications (318 k), rappels `reengagement` (FCM seul depuis le 27/10, rotation quiz/étude, 8 langues), budget (`PushBudget`), `newsPush`, `sendPush` | Liste paginée, non-lus, marquage, **orchestration des rappels** (créneaux 8 h 30 / 13 h / 19 h 30, budget 3/jour, heures calmes), envoi FCM | Réception FCM, affichage, ouverture d'écran | ●● | 1 |
| 3 | **Comptes et profils** | Users, Pseudo, UserKeys, BlockedUsers, Friends, UserPresence, `users/*`, `accountDeletion` (J+15) | Profil, pseudo unique, blocages, suppression J+15, présence (Redis), parrainage, certification | Saisie, cache du profil connecté | ●●● | 2 |
| 4 | **Abonnements (follows)** | `follows/*`, `followUser`, `syncFollowsFromLegacy` | Table `follows`, compteurs | Bouton, état local | ● | 2 |
| 5 | **Publications, fil, découverte** | Posts (6,7 k), `discovery_boost_service`, `feed_*`, `active_creators`, `scoreEngine`, `weeklyRankings`, `unreadCleanup` | Fil classé, découverte, créateurs actifs, vues, j'aime, favoris, partages, reposts, score, classements hebdomadaires | Défilement, lecture médias, cache | ●●● | 2 |
| 6 | **Commentaires** | PostComments (5,5 k), `comments_prefetch` | CRUD, comptes, réponses, notifications | Affichage, saisie | ●● | 2 |
| 7 | **Canaux** | Canaux (126), membres (8,2 k), CanalNames, `canalInactivity`, `adminCanaux` | Création, abonnements, privés/payants, règles d'accès | Écrans | ●● | 3 |
| 8 | **Chroniques** | chroniques (24 h), `chroniqueReply` | Création, expiration, aperçu | Lecteur. **Réponses (`chronique_messages`) : Firebase** | ● | 3 |
| 9 | **Chats** | Chats, Messages, GroupChats, GroupMessages, entreprise | Rien, sauf création de groupes si besoin de règles métier | **Firebase (inchangé)**. Notification de message : déclencheur Firestore conservé (`onGroupMessageCreated`) | — | — |
| 10 | **Quiz / Étude / Contes** | `quiz/*` (18 fonctions), `etude/*`, `contes/*` | Tirage, réponses, progression, classements, anti-triche, diplômes, rappels | Écrans de jeu, minuteur | ●● | 4 |
| 11 | **Musique et sons d'artistes** | MusicLibrary/Likes/Favorites/Playlists, artist_sounds, `studio/*` | Catalogue, droits, licences, comptes d'écoute, URL temporaires | Lecteur audio, cache chiffré du début | ●● | 4 |
| 12 | **Studio, cartes, stickers, montage** | StickerPacks, Stickers, UserStickers, `cards/*`, `studio/*` | Métadonnées, achats, modération, génération IA | Éditeur, rendu | ●● | 4 |
| 13 | **Afro Journal (actualités)** | `news/*` (2 843 lignes), NewsFeed, NewsDigests… ; *au 30/10* : 51 médias nationaux, agents AfroMode et AfroInfo, 30 pays, passage horaire, plafond 120 articles/jour, budget IA `NewsBudget` | Pipeline en **tâches Laravel** (ou conteneur Node qui réutilise le code TypeScript au début), mêmes plafonds, agents et budget IA | Cartes, page journal | ●● | 4 |
| 14 | **Pubs des réseaux (AdMob, Appodeal) et récompenses** *(élargi le 30/10)* | Advertisements, AdRewards, SSV, `ads/rewards.ts` (page Récompenses, vérification SSV), `ads/adFree.ts` (pub récompensée → 1 jour sans pub, plafond par jour), `ads/adRevenue.ts` (revenus par emplacement AdMob/Appodeal), `ads/ad_notifications.ts` (pubs Afrolook envoyées par notification, mention « Pub »), `AppConfig/ads` (activation par plateforme, pourcentage, emplacements iOS/Android), socle `RewardedAds` | Vérification serveur des pubs récompensées (SSV signée), crédit en pièces, jours sans pub, plafonds, **revenus par emplacement**, configuration des emplacements, pubs Afrolook dans les notifications (jamais AdMob/Appodeal en push), journal des erreurs de chargement | Affichage AdMob / Appodeal (bannières, plein écran, récompensées, natives du fil) reste dans l'app | ●● | 5b |
| 15 | **Portefeuille, pièces, paiements** | TransactionSoldes (5,4 k), wallets, `payments/*` (3 261 lignes), retraits, IAP Apple/Google, taux de change | Grand livre, dépôts, achats en pièces, conversions, **webhooks** FeexPay / CinetPay / PayGate, validation des reçus Apple et Google, retraits (demandes manuelles) | Écrans de paiement, SDK d'achat intégré | ●●● | 5 |
| 16 | **Contenu payant et créateurs** | ContentPaies, ContentComments, creator_*, PromoCodes | Achats, abonnements créateurs, codes promo, statistiques | Écrans | ●● | 5 |
| 17 | **Boutique (AfroShop)** | Articles (86), Entreprises (94), Commandes, UserServices | Produits, commandes, paiements | Écrans | ●● | 5 |
| 18 | ~~**Rencontres (Afrolove)**~~ **ABANDONNÉ le 27/10/2026** | dating_* (profils 695, 23 000 lignes de code) | **Rien** : non migré. Entrées masquées, données gardées en archive, code supprimé ensuite | — | — | — |
| 19 | **Lives** | lives (415), Agora | Liste, jetons Agora, cadeaux, gains | Flux vidéo Agora. **Commentaires : Firebase** | ●● | 6 |
| 20 | **Administration, équipe, modération, signalements** | `team/*`, `moderation`, Reports, AdminActions | Tableaux de bord, files de modération, journaux | Pages admin (clients de l'API) | ●● | 6 |
| 21 | **E-mails** | `emails/*` | Laravel Mail + files (modèles existants) ; e-mails de vérification restent Firebase | — | ● | 6 |
| 22 | **Série (streak), récompenses hebdomadaires, invitations** | `streak/*`, `weekly*`, Invitations | Tâches planifiées, compteurs | Écrans | ●● | 6 |
| 23 | **Médias** | Storage, `r2Mirror`, `media/*` | URL signées R2, nettoyage, aperçus | Envoi direct, compression (`media_shrink`) | ●● | 3 (en continu) |
| 24 | **Régie Afrolook Ads** *(ajout 30/10)* | `ads/adsEngine*`, `adsWeb*`, `adsAdvertisers*`, `adsPublishers*`, `adsWatch`, `adsGuard`, `adsHll`, `adsMeasure`, `adsTargeting` ; collections des annonceurs, diffuseurs (`ap_…`), compteurs répartis, audiences HLL, alertes | Moteur de diffusion (`serve` / `event` / `go`, jeton HMAC), compteurs en **Redis** (HyperLogLog natif, remplace les compteurs répartis), plafonds, ciblage, catégories, tarifs et remise de lancement, espace annonceur, diffuseurs et leurs gains, surveillance et blocage des paiements | Composant `afrolook_ads_banner.dart`, script `static/js/ads.js` des sites | ●●● | 5b |
| 25 | ~~**Mur de tâches des partenaires** (Tapjoy, ayeT, PubScale)~~ **ABANDONNÉ le 30/10/2026** : les partenaires n'ont pas accepté Afrolook | `offerwall/*`, `tapjoyOfferwallCallback`, `ayetOfferwallCallback`, `offerwallRelease`, `OfferwallEvents`, `OfferwallDaily`, `OfferwallPartners` | **Rien** : non migré. Code et fonctions à désactiver puis retirer du legacy (à décider avec le propriétaire) | — | — | — |
| 26 | **Partage et gagne** *(ajout 30/10)* | `adsShare*` (10 fonctions), `ShareCampaigns`, `AdShareProfiles`, `AdShareStats`, `AdShareEarnings`, `AdShareProof`, `AdShareReports`, lien `/p/<code>/` | Campagnes à l'audience, profils de partageurs et validation, **jugement du clic** (identifiant navigateur, IP/appareil, robots), gains 5 F/clic, plafonds, retenue 72 h, parrainage 10 % compté dans le plafond, analyse de fraude horaire, reprise des gains, audience touchée | Pages `share/`, partage natif | ●●● | 5b |
| 27 | **Sites clients de l'API** *(ajout 30/10)* | Vitrine `site/` (afrolookmedia.com, `/ads/`, `/gagner/`, `/p/`), SlashAtlas et PronoFlash (servis par la régie) | Rien de plus : ils appellent les mêmes points publics de la régie | Pages statiques ; **les adresses publiques ne doivent pas changer** (voir §11, point 7) | ● | 5b |

**Hors périmètre** : SlashAtlas (projet Firebase séparé, `slashatlas-studio`) et PronoFlash restent tels quels ; on pourra les rattacher plus tard.

## 7. Temps réel : comment on s'en passe (ou pas)

| Besoin actuel | Solution |
|---|---|
| Liste de notifications, badge | Interrogation légère (compteur en 1 requête, ETag), mise à jour quand FCM arrive pendant que l'app est ouverte |
| Compteurs d'un post (j'aime, commentaires, vues) | Valeur renvoyée avec le post, rafraîchie à l'ouverture et après une action ; pas d'écoute permanente |
| Présence en ligne | Battement de cœur toutes les 60 s vers Redis, lecture groupée pour une liste d'utilisateurs |
| Chats, commentaires de lives | **Restent Firestore** |
| Plus tard, si un besoin apparaît | Laravel Reverb (WebSocket) sur le même VPS |

## 8. Médias sur Cloudflare R2

1. L'app demande `POST /v1/uploads` (type, taille, hash) → l'API contrôle (taille max, types, quotas, droits) et renvoie une **URL signée de dépôt (PUT)** valable 10 minutes, avec une clé de la forme `u/{userId}/{aaaa}/{mm}/{ulid}.{ext}`.
2. L'app envoie le fichier **directement à R2** (rien ne transite par le VPS : zéro bande passante serveur).
3. L'app confirme `POST /v1/uploads/{id}/complete` → l'API vérifie l'objet (taille, type réel), enregistre le média et renvoie l'URL du CDN.
4. Lecture : `cdn.afrolookmedia.com/<clé>` (Worker existant, mis en cache). Plus de jetons Firebase dans les liens.
5. **Migration de l'existant** (15 747 fichiers, 25 Go déjà copiés dans R2 le 17/10) : script qui range chaque fichier sous sa nouvelle clé, réécrit les URL en base, garde l'ancien chemin en repli pendant 30 jours.
6. Vignettes et variantes : générées par tâche de file (ou par Cloudflare Images si le coût le justifie) ; vidéos : compression côté téléphone (`media_shrink`) conservée.

## 9. Tester en local, sans VPS (et avant d'acheter quoi que ce soit)

**État de ce poste** (vérifié aujourd'hui) : PHP 8.3 et Composer installés, **PostgreSQL 17 installé et démarré**, Node 22, Git, Flutter. **Docker et WSL ne sont pas installés** ; Redis non plus ; 16 Go de mémoire, 16 cœurs, disque C : 45 Go libres, disque D : 9,9 Go libres. Conclusion : on peut développer et tester **dès maintenant** sans Docker ; Docker sert seulement à valider les images avant le VPS.

### 9.1 Niveaux de test (du moins cher au plus réaliste)

| Niveau | Quoi | Comment |
|---|---|---|
| **1. Tests automatiques** | Chaque règle métier : autorisation, grand livre, webhooks, limites | Pest (PHPUnit) sur une base PostgreSQL `afrolook_test` locale. Cible : **chaque point d'API a au moins un test d'autorisation et un test métier**. Les paiements ont des tests de **rejeu** (même webhook deux fois = un seul crédit) |
| **2. API locale + Firebase en émulateur** | L'application ou des scripts parlent à l'API sur ce poste | `php artisan serve` + PostgreSQL local. Firebase Emulator Suite (Auth + Firestore) : les scripts `scripts/seed_emulator.js` et `seed_auth_emulator.js` existent déjà. En mode `local` seulement, Laravel accepte les jetons de l'émulateur |
| **3. Médias réels sans toucher la production** | Envoi par URL signée, lecture par le CDN | Compartiment R2 **de développement** `afrolook-media-dev` + sous-domaine `cdn-dev.<votre domaine>` + copie du Worker (gratuit, 10 Go offerts). Clés dans `.env`, jamais dans Git. Variante 100 % hors ligne : **MinIO** (compatible S3, comme R2) pour les tests automatiques |
| **4. Vrai téléphone sur l'API locale** | Tester l'application complète et les paiements bac à sable | **Cloudflare Tunnel** (`cloudflared`, gratuit) : `api-dev.<votre domaine>` pointe vers l'API de ce poste, en HTTPS, sans ouvrir de port. Le téléphone et les **webhooks** (FeexPay, CinetPay, Apple, Google) atteignent ainsi le poste. Application : `--dart-define=API_BASE=https://api-dev.…` (émulateur Android : `10.0.2.2`) |
| **5. Parité des données** | Prouver que la nouvelle base contient la même chose que Firestore | Export de production (lecture seule) → import dans Postgres de développement → **rapport de rapprochement** : nombres de lignes par collection, **somme des soldes**, empreintes (hash) d'échantillons, doublons, références orphelines. Rapport relu avant toute bascule |
| **6. Comparaison « à l'ombre »** | Vérifier les réponses sur de vrais usages | Pour chaque module en lecture : l'application appelle l'ancienne source ET l'API, compare, **journalise les écarts** (sans changer ce que voit l'utilisateur). On passe à l'API quand le taux d'écart est nul sur 7 jours |
| **7. Charge** | Tenir 10 à 100 fois le trafic actuel | k6 sur l'API locale puis sur le VPS de préproduction : scénarios « ouverture de l'accueil », « 50 j'aime/s », « rafale de webhooks » |
| **8. Préproduction sur le VPS** | Mêmes conteneurs que la production | `api-staging.<domaine>` avec une copie anonymisée des données ; c'est la dernière marche avant `api.<domaine>` |

### 9.2 Domaine et sous-domaines (le domaine existe déjà, hébergé chez Cloudflare)
`api.` (production) · `api-staging.` (préproduction) · `api-dev.` (tunnel vers ce poste) · `cdn.` (existant) · `cdn-dev.` (développement). Les trois jeux de clés (dev, préproduction, production) sont **séparés** : un test ne peut jamais écrire en production.

### 9.3 Règles de sécurité des tests
- Aucun test n'écrit dans la base Firebase de production. Les exports sont en lecture seule.
- Les données personnelles de la copie de développement sont **anonymisées** (e-mails, téléphones) avant d'aller en préproduction.
- Paiements : modes **bac à sable** des fournisseurs et cartes de test publiées uniquement ; aucune vraie transaction en développement.
- Les secrets (R2, Cloudflare, FCM, fournisseurs de paiement) restent dans `.env` non versionné puis dans les secrets Docker du VPS.

### 9.4 Ce qui sera installé sur ce poste (décision du 30/10/2026 : **pas de Docker sur le PC**)
**Décision du propriétaire (30/10/2026)** : le développement et les tests se font **sans Docker** sur le PC (Docker Desktop prendrait ~15 Go ; C : a 41 Go libres, D : 9,4 Go). **Docker sert seulement sur le VPS**, où les images sont construites (sur le VPS ou par GitHub Actions, jamais sur le PC).
À installer, avec l'accord du propriétaire au moment de la phase 0 : **PHP 8.3 + Composer** (~150 Mo ; PHP n'est plus trouvé dans le PATH au 30/10), **Memurai** (Redis pour Windows, facultatif : au début, cache et files peuvent utiliser PostgreSQL), **`cloudflared`** (tunnel vers le téléphone), k6 plus tard pour la charge. PostgreSQL 17 est déjà installé. Médias de développement : compartiment R2 `afrolook-media-dev` (rien à installer). Parade à l'absence de Docker local : vérification de l'image exacte sur la **préproduction** du VPS (`api-staging.`) avant chaque mise en production.

## 10. Infrastructure du VPS (quand on l'achètera)

- **Dimensionnement de départ** : 4 vCPU, 8 Go de RAM, 160 Go NVMe (largement suffisant pour 2 000 à 50 000 utilisateurs). Montée en charge : PgBouncer, réplique en lecture, Octane.
- **Conteneurs** (`docker compose`) : `caddy` (TLS automatique) → `app` (PHP-FPM) → `postgres`, `redis`, `horizon`, `scheduler`, `backup` (pg_dump + WAL vers R2). Sauvegarde hors VPS obligatoire.
- **Sécurité** : voir `docs/SECURITE_API.md` (comptes administrateurs séparés, 2FA, Cloudflare Access, Cloudflare Tunnel, sauvegardes chiffrées).
- **Hébergeur** : LWS, offre **« VPS M »** (KVM, 4 vCore 3,0 GHz, 8 Go, 150 Go NVMe, option accès root, 4,99 € HT/mois en promotion, 19,99 € ensuite) — décidé le 27/10/2026. À vérifier avant commande : prix de renouvellement, système, centre de données, sauvegardes, pare-feu.
- **Réseau** : le VPS n'accepte que Cloudflare (liste d'adresses Cloudflare au pare-feu), SSH par clé uniquement, port PostgreSQL fermé à l'extérieur.
- **Déploiement** : GitHub Actions → construction d'image → déploiement par SSH avec **bascule sans coupure** et retour arrière en une commande ; migrations de base exécutées avant la bascule, compatibles avec la version précédente.
- **Supervision** : Sentry (erreurs), Laravel Pulse/Horizon (files, lenteurs), Uptime Kuma (disponibilité), alerte sur espace disque, sauvegarde manquante, file bloquée, taux d'erreur.
- **Coût** : VPS LWS « VPS M » **4,99 € HT/mois en promotion (5,99 € TTC), 19,99 € HT ensuite (à confirmer)** ; R2 facturé à l'usage (déjà en place) ; Firebase réduit à l'authentification, FCM et aux chats. Constat du propriétaire : ~20 $ déjà dépensés sur Google Cloud avec ~2 000 utilisateurs et ~100 actifs/jour.

## 11. Stratégie de bascule (sans casser les anciennes versions)

Le point délicat : **des utilisateurs ont encore d'anciennes versions de l'application, qui écrivent directement dans Firestore** (1 444 comptes n'ont pas encore l'application à jour pour les notifications, par exemple).

1. **Interrupteur par module** dans Remote Config (`api_module_<nom>` : `off` / `shadow` / `on`) et **version minimale par module**.
2. **Étape « à l'ombre »** : l'application lit l'ancienne source, appelle aussi l'API et compare (niveau de test 6).
3. **Import final** : arrêt court des écritures du module (message « maintenance de 2 minutes » ou verrou), dernier import différentiel, rapprochement, bascule `on`.
4. **Anciennes versions** : pendant la transition, un pont Firestore → API (déclencheurs conservés pour le module concerné) garde les données synchronisées ; une fois la version minimale relevée (écran « mise à jour obligatoire »), le pont est supprimé. Vu la taille de la base active (~40 par jour), la mise à jour forcée est réaliste.
5. **Retour arrière** : l'interrupteur revient à `off` ; Firestore reste intact (lecture seule) **30 jours** après chaque bascule.
6. **Argent** : doublement d'écriture et rapprochement quotidien des soldes pendant 2 semaines avant de couper l'ancien circuit.
7. **Adresses publiques stables (ajout 30/10)** : des adresses sont **inscrites chez des tiers** et ne doivent jamais casser :
   - le script et les points de la régie (`adsServe`, `adsEvent`, `adsGo`) collés sur les **sites et applications des diffuseurs**, sur SlashAtlas et PronoFlash ;
   - les liens de partage `afrolookmedia.com/p/<code>/` **déjà envoyés sur WhatsApp et Telegram** ;
   - les **adresses de retour** réglées chez AdMob (SSV), FeexPay, Apple et Google.
   Parade : **dès la phase P**, toutes ces adresses passent par le domaine `afrolookmedia.com` (route Cloudflare qui renvoie aujourd'hui vers Firebase). Le jour de la bascule, seule la route change (vers Laravel) : rien à modifier chez les diffuseurs ni chez les partenaires. Les adresses de retour encore réglées sur `cloudfunctions.net` sont remplacées une par une chez chaque partenaire pendant la phase P.
8. **Pièces gagnées en cours de retenue** (72 h pour le partage) : l'import final reprend les gains « en attente » avec leur date de libération ; la libération est faite par l'API ensuite. Contrôle : somme des gains en attente identique avant et après.

### 11 bis. Aucune perte de données pour les utilisateurs (consigne du propriétaire, 30/10/2026)

L'application est **en production et utilisée** : **personne ne doit perdre ses données** (profil, publications, abonnés, pièces, gains, historique, messages). Garanties :
1. **Les comptes ne bougent pas** : Firebase Auth reste la source d'identité, l'`uid` de chaque utilisateur est conservé, aucun utilisateur ne recrée son compte. Les identifiants Firestore des entités importées deviennent les clés de PostgreSQL (les liens de partage existants restent valables). L'application garde le même identifiant (`com.afrotok.afrotok`) : c'est une **mise à jour** de la même fiche des stores.
2. **Copie, jamais déplacement** : Firestore n'est jamais vidé ni modifié par l'import ; il reste en **lecture seule pendant 30 jours** après chaque bascule (retour arrière immédiat).
3. **Sauvegarde complète avant tout** : export Firestore du 30/10/2026 dans un compartiment privé (`gs://afrolooki-legacy-backup-2026/`), étiquette Git `legacy-firebase-2026-10-30`, copie des fichiers déjà dans R2. Une nouvelle sauvegarde est faite juste avant chaque bascule.
4. **Répétitions** : chaque import est d'abord joué plusieurs fois sur une copie, avec un **rapport de rapprochement** (nombre de lignes par collection, **somme des soldes de pièces à l'unité près**, échantillons comparés, doublons, références orphelines). Aucune bascule tant que le rapport n'est pas à zéro écart.
5. **Import différentiel au moment de la bascule** : une copie complète est faite en avance (et refaite autant de fois que nécessaire), puis un **dernier import des seules différences** pendant une coupure d'écriture très courte (2 minutes, message « maintenance »). Aucune écriture d'utilisateur n'est perdue entre la copie et la bascule.
6. **Argent** : doublement d'écriture et rapprochement quotidien des soldes pendant 2 semaines avant de couper l'ancien circuit ; gains en retenue repris avec leur date de libération.
7. **Anciennes versions de l'application** : pont de synchronisation temporaire, puis mise à jour obligatoire (version minimale) ; aucune donnée écrite par une ancienne version n'est ignorée.

**Question ouverte (n°12 du §15) : migration en une seule fois ou module par module ?**
- *Une seule bascule générale* : l'application entière passe sur l'API le même jour. Simple à raconter, mais il faut avoir réécrit et testé **tous** les modules avant (≈ 290 fichiers, plusieurs mois sans rien livrer), une seule coupure plus longue, et si un module a un défaut tout le monde en souffre : risque le plus élevé pour des utilisateurs réels.
- *Une copie complète unique des données, puis bascule module par module* (**recommandé**) : **toutes les données existantes sont copiées une seule fois dans PostgreSQL au début** (et resynchronisées avant chaque bascule), puis chaque module bascule quand il est prêt, avec comparaison « à l'ombre » et retour arrière. Les utilisateurs ne voient aucune coupure notable et ne perdent rien ; en cas de problème, on ne revient en arrière que sur un module.
La phase 5 (argent) peut, au choix du propriétaire, être regroupée en une seule bascule courte, car les soldes doivent rester cohérents entre eux.

## 12. Phasage et critères de sortie (recalculé le 30/10/2026)

| Phase | Contenu | Durée indicative | Critère de sortie |
|---|---|---|---|
| **P. Préparation** *(nouvelle)* | Sur le legacy, sans API : correctifs de sécurité urgents validés (`docs/SECURITE_API.md` §5 : U1, U7, U5, U8, puis U2-U4), étiquette Git et **export Firestore de sauvegarde**, **adresses publiques stables** sur `afrolookmedia.com` (§11 point 7), facture Firebase réelle, réponses aux questions du §15, création des dossiers `afrolook-api` / `afrolook-coordination`, définition des trois agents, installations sur le poste | 2-3 semaines | Toutes les questions du §15 répondues ; sauvegarde vérifiée ; plus aucune adresse `cloudfunctions.net` chez un tiers ; failles F1, F2, F13 fermées ou planifiées |
| **0. Fondations** | Projet Laravel, authentification Firebase, utilisateurs, envoi R2, CI, observabilité, `ApiClient` Flutter, interrupteurs. **Livrable : API opérationnelle en local** (voir §13) | 2-3 semaines | Un téléphone se connecte, s'authentifie, envoie une image sur R2 de développement et la relit par le CDN |
| **1. Config + notifications** | Modules 1 et 2 | 3 semaines | Notifications servies par l'API, FCM envoyé par Laravel, rappels programmés identiques, lectures « Notifications » = 0 |
| **2. Cœur social** | Modules 3, 4, 5, 6 (comptes, follows, fil, commentaires) | 6-8 semaines | **Lectures Firestore divisées par 3 au moins** sur 7 jours, écarts « à l'ombre » nuls |
| **3. Canaux, chroniques, médias** | Modules 7, 8, 23 | 3-4 semaines | Plus aucun envoi vers Firebase Storage ; liens R2 partout |
| **4. Contenus** | Modules 10-13 (quiz, étude, contes, musique, studio, journal) | 5-6 semaines | Fonctions Cloud correspondantes supprimées |
| **5a. Argent** | Modules 15, 16, 17 (grand livre, deux soldes, paiements et webhooks, achats intégrés, retraits manuels, contenu payant, boutique) | 6-8 semaines | 2 semaines de rapprochement à 0 écart, tous webhooks rejoués sans doublon |
| **5b. Monétisation** *(nouvelle)* | Modules 14, 24, 26, 27 (pubs des réseaux et récompenses, régie Afrolook Ads, Partage et gagne, sites clients). **Après 5a** : tous créditent des pièces sur le grand livre | 6-8 semaines | Mêmes résultats que les 444 tests et les 5 scénarios d'intégration actuels, rejoués contre l'API ; compteurs de la régie identiques à l'ombre pendant 7 jours ; retours SSV et webhooks rejoués sans doublon ; gains en retenue repris à l'unité près |
| **6. Reste** | Modules 19-22 (lives, admin, e-mails, série) — rencontres abandonnées | 3 semaines | Plus de fonction Cloud métier ; il ne reste que le trafic Firebase prévu |
| **7. Extinction** | Retrait des fonctions et collections migrées, archivage, réduction du plan Firebase | 1-2 semaines | Facture Firebase ramenée au niveau visé |

**Total : 39 à 51 semaines, soit environ 9 à 12 mois** avec un seul agent de construction et la validation du propriétaire à chaque étape. **Avec deux chantiers en parallèle** (un agent sur l'argent et la monétisation pendant qu'un autre fait les contenus, phases 4 et 5a/5b en même temps), on peut viser **7 à 9 mois**. Calendrier indicatif si la phase P démarre début novembre 2026 : fondations en décembre, cœur social de mi-décembre à février, argent et monétisation au printemps 2027, extinction à l'été 2027.

Les modules 5 (fil), 15 (argent) et 26 (partage, argent versé au clic) sont les plus risqués : ils ont des **marches de contrôle** supplémentaires (comparaison à l'ombre, puis rapprochement).

**On peut s'arrêter après chaque phase** : l'architecture mixte reste saine. Le gain financier le plus fort vient des phases 1 et 2 (fil et notifications = plus de la moitié des lectures Firestore).

## 13. Contenu de la « première API opérationnelle » (phase 0)

À la fin de la phase 0, en local puis sur le VPS de préproduction :
- Projet Laravel 12 (PHP 8.3) dans un dossier à part du dépôt Flutter, avec Pest, Pint, Larastan, Horizon, Pulse.
- Mode **« sans Docker »** pour ce poste (décision du 30/10) ; `docker-compose` complet (Caddy, PHP-FPM, PostgreSQL, Redis, Horizon, Scheduler) **utilisé seulement sur le VPS** (préproduction puis production).
- Garde `firebase` (vérification des jetons réels et de l'émulateur en local), App Check, création automatique de l'utilisateur à la première requête.
- Points d'API de base : `GET /v1/me`, `PATCH /v1/me`, `POST /v1/uploads` + `complete`, `GET /v1/config`, `GET /v1/health`.
- Envoi par URL signée vers R2 (ou MinIO) et lecture par le CDN de développement.
- Tests automatiques, documentation OpenAPI, script de rapprochement Firestore → Postgres (squelette), pipeline CI.
- Côté Flutter : classe `ApiClient` (jeton, nouvelle tentative, ETag, erreurs), configuration `API_BASE` par environnement, interrupteurs de modules. Aucun écran existant n'est modifié à ce stade.
- **Principe consigné le 27/10/2026** : le frontend n'est **pas** recréé ; c'est **une copie de l'application actuelle, réadaptée à l'API** (voir `docs/AGENTS_ET_ORGANISATION.md` §5.6).

## 14. Risques et parades

| Risque | Parade |
|---|---|
| **Règles Firestore oubliées** (une règle non portée = faille) | Matrice « règle → Policy → test » établie module par module avant de migrer ; revue de sécurité à chaque phase |
| **Argent** (double crédit, solde faux) | Grand livre à écriture double, `Idempotency-Key`, verrous SQL, rapprochement quotidien, retraits restent manuels |
| **Anciennes versions de l'application** | Version minimale par module, pont de synchronisation temporaire |
| **Perte de données** | Sauvegardes quotidiennes + WAL hors VPS, restauration testée, Firestore conservé 30 jours |
| **Panne du VPS** (point unique) | Supervision et alertes, déploiement reproductible, procédure de reconstruction documentée ; plus tard, second serveur |
| **Temps réel dégradé** | Les chats et les commentaires de lives restent sur Firebase |
| **Effort sous-estimé** | Livraison par phases avec critère de sortie ; on peut s'arrêter à la phase 2 ou 3 et garder une architecture mixte |
| **Dépendance à une personne** | Plan, contrats OpenAPI, tests et scripts versionnés dans Git |

## 15. Questions à valider avant de lancer

1. ~~Facture Firebase réelle~~ **Plus nécessaire (30/10/2026)** : la migration est décidée ; l'ordre des phases suit les lectures mesurées par écran.
2. ~~Hébergeur~~ **LWS (décidé le 27/10/2026)**. Reste à préciser : l'offre exacte (VPS à accès administrateur complet, Docker possible) et le budget mensuel.
3. ~~Emplacement du code~~ **Décidé le 30/10 : dépôt GitHub séparé et privé `afrolook-api`** (dossier frère `D:\...\afrolook\V2\afrolook-api`), jamais dans le dépôt de l'application ; une branche ne peut pas être privée seule sur GitHub.
4. **Mise à jour obligatoire** : acceptez-vous une version minimale par module (les utilisateurs qui n'ont pas mis à jour verront un écran de mise à jour) ?
5. ~~Installations sur ce poste~~ **Pas de Docker sur le PC (décidé le 30/10)** : reste à donner l'accord pour installer PHP 8.3 + Composer, Memurai (facultatif) et `cloudflared` au début de la phase 0.
6. ~~Domaine~~ **`afrolookmedia.com` (décidé)**. À confirmer : DNS géré par Cloudflare ; sous-domaines `api.`, `api-staging.`, `api-dev.`, `admin.`, `cdn.`, `cdn-dev.`.
7. ~~Firebase Dynamic Links~~ **non utilisé (décidé le 27/10)** : le partage et les aperçus passent par le domaine propre (`afrolookmedia.com/share/...`). Les pages d'aperçu (aujourd'hui la fonction `sharePostLink`) seront reprises dans Laravel ; le paquet `firebase_dynamic_links` et son code résiduel seront retirés.
8. **Afro Journal** : réécrire en PHP, ou garder le code TypeScript dans un petit conteneur Node pendant la transition ?
9. *(ajout 30/10)* **Deux chantiers en parallèle** (7 à 9 mois au lieu de 9 à 12) : d'accord pour faire avancer les contenus (phase 4) et l'argent/monétisation (5a/5b) en même temps, avec deux agents de construction et le superviseur ?
10. *(ajout 30/10)* **Adresses publiques stables** : d'accord pour faire passer dès la phase P le script de la régie, les liens `/p/` et les adresses de retour des partenaires par `afrolookmedia.com` ? Il faudra alors mettre à jour l'adresse de retour chez AdMob (SSV), FeexPay et les autres (geste à faire par vous dans leurs tableaux de bord, je vous guide).
11. *(ajout 30/10)* **Gel des nouveautés** : pendant les phases 2 et 5, accepte-t-on de ne pas ajouter de grande fonctionnalité dans l'ancien système (chaque nouveauté sur Firebase est à écrire deux fois) ? Sinon, toute nouvelle fonctionnalité est construite directement dans l'API.

## 16. Comment ça va se faire, concrètement (ajout 30/10/2026)

### 16.1 Qui fait quoi
| Rôle | Qui | Ce qu'il fait |
|---|---|---|
| **Décideur** | Le propriétaire | Répond aux questions, valide chaque phase, teste sur son téléphone, achète le VPS, règle les tableaux de bord des partenaires, dit « oui, déploie » |
| **Coordinateur** | L'agent principal (cette conversation) | Pose les questions, consigne les réponses dans `docs/PROJET_MEMOIRE.md`, distribue le travail, rend compte |
| **Informateur** | Agent `informateur-app` | Pour chaque module : fiche « ce que fait l'application actuelle » (écrans, collections, règles, fonctions, pièges, tests existants à rejouer) |
| **Constructeur** | Agent `api-laravel` (un ou deux) | Écrit l'API du module, ses tests, son contrat OpenAPI ; adapte la couche de données de la copie de l'application |
| **Superviseur** | Agent `superviseur` | Vérifie tests, sécurité, parité, absence de secrets ; coche la case seulement après vérification |

### 16.2 Le cycle d'un module (toujours le même)
1. **Fiche** : l'informateur décrit le module tel qu'il existe (preuves : fichier et ligne).
2. **Questions** : tout choix ouvert est posé au propriétaire avant d'écrire du code.
3. **Construction** : tables PostgreSQL, points d'API, règles d'accès (une par règle Firestore), tests. Les **tests Jest et les scénarios d'intégration actuels** sont réécrits en tests Laravel : même entrée, même résultat attendu.
4. **Import** : script qui copie les données Firestore du module dans PostgreSQL (lecture seule sur la production) + rapport de rapprochement (nombres, sommes, échantillons).
5. **À l'ombre** : l'application appelle l'ancienne source ET l'API, compare et journalise les écarts, sans rien changer pour l'utilisateur. 7 jours sans écart.
6. **Bascule** : interrupteur du module sur `on` (Remote Config), version minimale si nécessaire. Firestore reste intact 30 jours (retour arrière immédiat).
7. **Nettoyage** : suppression des fonctions Cloud et de l'accès Firestore devenus inutiles ; règle de la collection fermée ; case cochée dans la mémoire.

### 16.3 Ce que le propriétaire voit et fait à chaque phase
- **Avant** : une liste de questions (avec recommandation) ; ses réponses sont consignées.
- **Pendant** : un point court à chaque étape importante (fiche prête, API prête en local, test sur téléphone via `api-dev`).
- **Fin de phase** : un rapport (ce qui marche, chiffres de lectures Firestore avant/après, écarts, ce qui reste) et la demande de bascule. Rien ne passe en production sans son « oui ».

### 16.4 Ordre de démarrage proposé
1. Phase P, dans cet ordre : questions du §15 → sauvegarde (étiquette Git + export Firestore) → correctifs de sécurité U1, U7, U5, U8 → adresses publiques stables → dossiers et agents → installations.
2. Phase 0 en local (aucune dépense), puis achat du VPS LWS seulement quand l'API locale passe le critère de sortie.
3. Phases 1 et 2 (le plus gros gain sur la facture), puis on décide de continuer au vu des chiffres.

## 17. Régie Afrolook Ads : ce qui existe aujourd'hui et ce qu'il faut porter (relevé du 30/10/2026)

Relevé fait en lisant les pages publiques de la vitrine (`/ads/`, `/ads/espace/`, `/ads/diffuseur/`, `/ads/diffuseur/regles/`, `/ads/diffuseur/documentation/`, `/ads/admin/`, `/ads/partager/`, `/gagner/`) et le code (`functions/src/ads/`, `site/src/ads*.mjs`, `site/static/js/ads.js`). **Ce qui est promis sur ces pages est un contrat public : l'API doit le reproduire à l'identique.**

### 17.1 Les acteurs et leurs profils
| Acteur | Connexion | Profil (validé par l'équipe avant toute action) | Ce qu'il peut faire |
|---|---|---|---|
| **Annonceur** | Compte Google sur le site (Firebase Auth) | **Profil de marque** obligatoire : logo, nom, secteur, pays, ville, site, WhatsApp, description (20 à 200 caractères), accord d'affichage comme partenaire | **Annonce affichée gratuite** : 3 annonces de 14 jours, renouvelables une fois ; promouvoir entreprise, site, application, projet ou affiche ; titre 60 caractères, texte 220 ; **catégorie obligatoire** (16 courantes, 10 sensibles) ; jusqu'à 5 images ou une vidéo de 15 s (25 Mo) ; **bannières prêtes** 728×90, 320×100, 320×50, 300×250 ; bouton d'action (site, télécharger, en savoir plus, WhatsApp, appeler) ; ciblage pays, langues, appareils, types de sites (au plus 40 % des vues hors des pays visés) ; e-mail à la validation puis tous les 100 vues. **Campagne Partage payante** : audience à atteindre, prix affiché avant validation, frais de paiement en plus, « paiement reçu » validé à la main ; campagne offerte pour l'administrateur |
| **Diffuseur** | Compte Google | **Profil diffuseur** : particulier ou entreprise, nom, pays, ville, WhatsApp, site, présentation (300 caractères), **acceptation des règles versionnées** (version 2026-10-29 ; nouvelle version = nouvelle acceptation) | Ajouter **jusqu'à 10 sites ou applications** en ligne, chacun validé séparément : type, catégories d'annonces acceptées (sensibles décochées par défaut), pays de l'audience, audience mensuelle déclarée, sessions, description ; **preuve de propriété** (balise ou fichier `/afrolook-ads.txt` ; retirée 3 jours = suspension) ; reçoit un **identifiant `ap_…`** lié au domaine ou à l'application |
| **Partageur** | Application Afrolook | Profil d'audience WhatsApp, Telegram, groupes, validé par l'équipe | Missions de partage, lien personnel `/p/<code>/`, gain au clic valide (module 26) |
| **Administrateur de la régie** | Compte Google **et** une des deux adresses autorisées (`ads/adsAdmin.ts`) | — | Valider ou refuser annonceurs, annonces, diffuseurs, sites, partageurs et campagnes ; site `/ads/admin/` et page d'administration de l'application |

### 17.2 Règles de diffusion et d'argent à porter telles quelles
- **Moteur** : `adsServe` (annonce choisie par le serveur, pays d'après l'adresse IP), `adsEvent` (vue, lecture complète), `adsGo` (clic par redirection). Jeton signé à usage unique : 30 min pour la vue, 2 h pour le clic. Vue = moitié de l'annonce visible pendant la durée du format. Motifs de refus publiés : `not_visible`, `too_fast`, `expired`, `replay`, `interval`, `ad_cap`, `device_cap`, `ip_cap`, `bot`, `origine`, `ad_inactive`.
- **Plafonds** : 3 vues de la même annonce par visiteur et par jour, 300 affichages par visiteur et par jour, intervalle par format (30 s bannière, 20 s native, 10 min interstitiel, 5 min récompensée), 3 emplacements par page, limites de rafale par adresse et par visiteur. Visiteurs « Ne pas suivre » : affichage sans comptage. Aucun cookie.
- **Neuf formats et tarifs** (pour 1 000 affichages valides) : bannière 1 000 F, bandeau collant 1 250, native 1 500, carrousel 1 800, affiche 2 000, vidéo 2 500, interstitiel 3 000, récompensée 3 500 (vue complète) ; notification sur sélection, 3 par jour au plus. **Part du diffuseur : 65 %** ; remise de lancement de 30 % le premier mois de l'offre Réseau. L'offre Réseau (payante, chez les diffuseurs) **n'est pas encore ouverte** : les affichages sont comptés, la rémunération démarre à son ouverture.
- **Audience et fraude des diffuseurs** : audience réelle mesurée sur 30 et 60 jours (HyperLogLog), comparée à la déclarée ; audience retenue jamais au-dessus de la déclarée ; répartition par pays contrôlée ; trafic invalide sous 10 % normal, de 10 à 25 % alerte, au-delà de 25 % emplacement suspendu ; identifiant utilisé depuis un autre domaine refusé et compté ; applications payées seulement après attestation (App Check).
- **Gains des diffuseurs** : bloqués 30 jours, réserve de 10 % pendant 90 jours, retrait minimum 10 000 F par Mobile Money, frais à la charge de l'annonceur, gains annulés en cas de fraude.
- **Vocabulaire** : toujours « Afrolook Ads » ; jamais la part gardée par Afrolook.

### 17.3 Données de la régie à importer (collections relevées dans le code)
- **Annonceurs et annonces** : `Advertisements`, `AdAdvertiserProfiles`, `AdsWebSeen`, `AdsWebRate`.
- **Diffuseurs** : `AdProperties` (sites et applications `ap_…`), `AdsPubDaily`, `AdsPubHealth`, `AdsHll` (audiences), `AdsSecure`.
- **Moteur et compteurs** : `AdsTokens`, `AdsShards`, `AdsDaily`, `AdsCaps`, `AdsRate`, `AdsAudit`, `AdsAlerts` → compteurs en Redis, totaux journaliers et audit en PostgreSQL.
- **Partage** : `ShareCampaigns`, `AdShareProfiles`, `AdShareLinks`, `AdShareStats`, `AdShareEarnings`, `AdShareSeen`, `AdShareSharerDay`, `AdShareProof`, `AdShareReports`, `AdShareState`.
- **Pubs des réseaux et récompenses** : `AdRewards`, `AdRewardsWeek`, `AdRewardStats`, `AdSsvTx`, `AdRevenueDaily`, `AdTaskState`.
- **Configuration** : `AppConfig/ads`, `AppConfig/share`.

### 17.4 Point à corriger dès la phase P (avant que des diffuseurs s'intègrent)
La documentation publique d'intégration donne aux diffuseurs les **adresses directes des fonctions Firebase** (`https://us-central1-afrolooki.cloudfunctions.net/adsServe`, `/adsEvent`, `/adsGo`) et leur demande d'autoriser `connect-src https://us-central1-afrolooki.cloudfunctions.net` et `img-src https://firebasestorage.googleapis.com`. L'exemple Flutter fourni aux applications partenaires contient aussi `_host = 'us-central1-afrolooki.cloudfunctions.net'`.
**Chaque diffuseur qui s'intègre avec ces adresses devra changer son code le jour de la migration.** Correction proposée (rien n'est fait, accord requis) :
1. Publier les points sous le domaine propre (`https://afrolookmedia.com/ads/api/serve`, `/event`, `/go`) par une réécriture vers les fonctions actuelles ; les anciennes adresses continuent de marcher.
2. Mettre à jour la documentation, `tag.js`, `afrolook_ads_banner.dart` et `site/static/js/ads.js` pour n'utiliser que ces adresses ; images servies par `cdn.afrolookmedia.com` au lieu de `firebasestorage.googleapis.com`.
3. Prévenir les diffuseurs déjà validés (s'il y en a) de mettre à jour leur balise ; garder les anciennes adresses jusqu'à la fin de la migration.

12. *(ajout 30/10)* **Une seule bascule générale ou module par module ?** Voir §11 bis : recommandation = **copie complète unique des données au début, puis bascule module par module** (aucune perte, retour arrière par module). Le propriétaire souhaite avant tout que **personne ne perde ses données**.
