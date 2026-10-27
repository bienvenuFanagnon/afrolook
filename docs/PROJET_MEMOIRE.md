# MÉMOIRE UNIQUE DU PROJET AFROLOOK

**À lire en premier par tout agent (ou personne) qui reprend le travail.** Ce fichier est le point d'entrée : il dit où l'on en est, ce qui est décidé, ce qui est fait, ce qui reste, et vers quel document aller pour le détail. Il ne remplace pas les documents spécialisés, il les relie.

Dernière mise à jour : **27 octobre 2026** · Branche : `refonte_claude` · Dernier commit poussé : `077ca211` · Version de l'application dans `pubspec.yaml` : `2.0.17+266`.

---

## 0. Comment utiliser et tenir ce fichier

1. **Début de session** : lire ce fichier en entier, puis seulement les documents de la section 3 utiles à la tâche.
2. **Pendant le travail** : cocher les cases (`[x]`) des tableaux de la section 6 dès qu'une étape est faite et vérifiée.
3. **Fin de session** : ajouter **une ligne** au journal (section 9) : date, ce qui a été fait, ce qui reste, où reprendre. Mettre à jour « Dernière mise à jour » en haut.
4. **Ne pas dupliquer** : un plan détaillé vit dans son propre document ; ici on ne garde que le statut et le lien.
5. **Jamais de secrets ici** (clés, jetons, mots de passe). Dire où ils sont ; les redemander au propriétaire.
6. Si ce fichier contredit un autre document, **ce fichier fait foi** (puis corriger l'autre document).

---

## 1. Règles de collaboration (valables pour tout agent)

- **Langue** : tout en **français** correct (accents compris), simple et direct, sans jargon. Même les messages intermédiaires.
- **Proposer avant d'agir** pour tout changement important, risqué ou qui change le comportement visible. Le propriétaire valide (« ok », « on fait vos recommandations »). Les petites corrections évidentes peuvent être faites directement, en le disant.
- **Git** : ne **pas** committer ni pousser sans demande explicite du propriétaire. Faire des commits **séparés** par projet (Afrolook / SlashAtlas / API).
- **Déploiement** : le propriétaire a donné une autorisation permanente pour déployer le site et les fonctions (voir `docs/HANDOFF_AGENT.md`). Pour tout ce qui sort du cadre (suppression de données, e-mails à de vrais comptes, dépenses, soumission à un store), **demander d'abord**.
- **POSER TOUTES LES QUESTIONS (règle du propriétaire, 27/10/2026)** : un agent qui reprend ce projet **ne suppose rien et ne décide pas seul**. Dès qu'une information manque, qu'un choix est possible, qu'un compromis existe ou que la section « Questions ouvertes » (section 8) n'est pas entièrement répondue, il **pose ses questions au propriétaire — toutes, avant de commencer** — avec ses options et sa recommandation, puis consigne les réponses dans ce fichier (section 5.1 pour les décisions, section 8 pour fermer la question). Il rouvre une question s'il découvre un fait qui change la réponse. Ne jamais « choisir une valeur par défaut » en silence.
- **Tout ce que dit le propriétaire est consigné ici** (décisions, consignes, contraintes). **L'agent qui consigne ne met rien en place lui-même** : il écrit dans la mémoire, l'agent suivant exécute après avoir posé ses questions.
- **Honnêteté** : dire ce qui n'a pas pu être testé ; ne jamais annoncer « terminé » sans vérification.
- **Le propriétaire travaille avec plusieurs agents à la suite** : laisser le dépôt dans un état compréhensible (ce fichier à jour).

### Règles métier à ne jamais casser
- **Commission** : les 75 % du parrain peuvent être affichés ; **ne jamais afficher la part de 25 % de l'application** dans l'interface.
- **Fil** : au lancement, **T1 seul** (posts non vus des abonnements). T2 (intérêts) et T3 (découverte) **seulement sur demande** de l'utilisateur. Fin de fil : abonnement obligatoire à au moins un canal/créateur avant « voir de nouveaux posts ». Quand les posts non vus sont épuisés, des actualités s'ajoutent parmi les posts à découvrir (une carte tous les 4 posts). Détails : `FEED_ALGO_HANDOFF.md`.
- **Pièces** : deux soldes (dépôt = achats/abonnements, non convertible ; gagnées = convertibles, dépensables). **Tout en pièces** (Android et iPhone) sauf les contenus payants (restent en FCFA, masqués sur iPhone). Aucun frais de retrait (les 5,6 % du dépôt Mobile Money le couvrent).
- **Retraits** : **demandes manuelles dans Firestore uniquement**, pas d'appel API de paiement sortant (FeexPay payout).
- **Paiement des vues** : encaissement serveur seul, barème unique, **pas de paiement automatique**.
- **Suppression de compte** : accès coupé tout de suite, effacement à J+15, soldes à retirer avant ; **toute nouvelle collection doit être ajoutée à la purge** (`accountPurge`).
- **Apple** : ne pas soumettre de build avant test sandbox des achats intégrés ; vidéo de preuve demandée par Apple (voir `docs/HANDOFF_AGENT.md`).
- **Notifications** : les rappels programmés et les actualités passent **uniquement par Firebase Cloud Messaging** (OneSignal n'est qu'un repli désactivé pour les anciens comptes). Budget : 3 notifications « non directes » par jour et par personne, heures calmes 22 h – 7 h 30, créneaux locaux 8 h 30 / 13 h / 19 h 30.
- **Pubs** : AdMob et Appodeal **interdisent** leurs pubs dans une notification push ; seules les pubs Afrolook (annonceurs) peuvent y passer, avec la mention « Pub ».
- **Règle Storage temporaire** : une exception `user_profile/` à retirer après diffusion du correctif d'inscription (voir `storage.rules`).
- **Médias** : lecture par le CDN `cdn.afrolookmedia.com` (Cloudflare R2). Détails : `docs/CDN_R2.md`.
- **Pronostics** : module **supprimé** (décision du 27/09/2026). **Afrolove (rencontres)** : **abandonné** (décision du 27/10/2026), voir section 5.

---

## 2. Les projets du dépôt

| Projet | Où | Backend | Statut |
|---|---|---|---|
| **Afrolook** (application Flutter + fonctions) | racine : `lib/`, `functions/`, `docs/` | Firebase `afrolooki` (us-central1) | En production ; **migration vers API Laravel prévue** |
| **API Laravel + PostgreSQL** | *(à créer)* dossier frère ou sous-dossier (à décider) | VPS Docker + Cloudflare R2 | **À créer** — plan : `docs/MIGRATION_API_LARAVEL.md` |
| **SlashAtlas** (site de commandes IA pour affiches, communauté, studio) | `slashatlas/` | Firebase `slashatlas-studio` (europe-west1) | En production ; hors migration |
| **PronoFlash** | `pronoflashia/` | Firebase propre | Indépendant, hors migration |

Doc d'exploitation de SlashAtlas : `slashatlas/STUDIO.md` (très complet), `slashatlas/SEO.md`.

---

## 3. Carte des documents

| Document | Contenu | Statut |
|---|---|---|
| **`docs/PROJET_MEMOIRE.md`** | Ce fichier | **Référence unique** |
| `docs/MIGRATION_API_LARAVEL.md` | Plan détaillé de la migration (architecture, modules, tests locaux, VPS, phases) | Actif — plan à valider |
| `docs/AGENTS_ET_ORGANISATION.md` | **Organisation** : dossiers (legacy conservé, nouveau frontend, API, coordination), conservation de l'existant, **trois agents** et leur protocole, **modèle des comptes d'équipe/administrateurs** | Actif — instructions consignées, **rien de mis en place** |
| `docs/SECURITE_API.md` | **Sécurité** : registre des failles de la version actuelle (F1-F12), sécurité de la nouvelle plateforme (comptes, administrateurs, argent, anti-piratage, serveur), correctifs d'urgence | Actif — plan à valider |
| `docs/PAGES_ORPHELINES.md` | 80 classes de pages jamais référencées (candidates à la suppression) | Actif — à confirmer |
| `SECURITY_FINDINGS.md` (racine) | Ancien rapport de sécurité | **Périmé** : remplacé par `docs/SECURITE_API.md` |
| `docs/HANDOFF_AGENT.md` | Passation du 12/10 : accès, secrets (où), Apple, Cloudflare, SlashAtlas | Utile, **partiellement ancien** (version 2.0.10, environnement conteneur) |
| `docs/COUTS_FIRESTORE.md` | Analyse des coûts Firestore et quota CPU | Actif |
| `docs/CDN_R2.md`, `docs/MEDIA_RAPIDE.md` | CDN Cloudflare R2, audit des lectures, mesure par écran (`ReadStats`) | Actif |
| `docs/AUTH_EMAILS_GOOGLE.md`, `docs/SUPPRESSION_RESTAURATION_COMPTE.md` | Authentification, e-mails, suppression/restauration de compte | Actif |
| `docs/QUIZ.md`, `docs/ETUDE.md`, `docs/ETUDE_UNIVERSITES.md`, `docs/CONTES.md`, `docs/CONTES_SOURCES.md` | Jeux et contenus éducatifs | Actif |
| `docs/CARTES.md`, `docs/STICKERS_SPEC.md`, `docs/STUDIO_TEMPLATES.md`, `docs/BIBLIOTHEQUE_MUSIQUE.md`, `docs/CHRONIQUES_V2.md` | Studio, cartes, stickers, musique, chroniques | Actif |
| `docs/DEFI_EXTENSIONS.md` | DÉFI | Actif |
| `docs/SUIVI_PAIEMENTS.md`, `docs/PAIEMENT_CARTE_WEB.md`, `docs/HANDOFF_PLAY_BILLING_TEST.md` | Paiements, carte, test Play Billing | Actif |
| `docs/ADS_ADMOB.md`, `docs/PUB_VIDEO_GOOGLE_ADS.md` | Publicité | Actif |
| `docs/APP_STORE_CONNECT_TRADUCTIONS.md`, `docs/google_play_listing_monde.md`, `docs/app_store_listing_*.json` | Fiches des stores | Actif |
| `FEED_ALGO_HANDOFF.md` | Algorithme du fil | Actif |
| `NOTIFICATIONS_PEDAGOGIQUES.md`, `WEEKLY_REWARDS_SUIVI.md`, `BOOST_SYSTEM_PLAN.md`, `AFROSHOP_SOCIAL_PLAN.md`, `CORRECTIONS_AFFILIATION.md`, `PLAN_AI_SUGGESTIONS.md`, `PLAN_PUB_ENTITY_CARDS.md`, `RESPONSIVE_DESKTOP_PLAN.md`, `SECURITY_FINDINGS.md`, `SUIVI_STUDIO.md` | Plans et suivis par chantier | À relire avant de toucher au chantier |
| `SUIVI_REFONTE.md` (4 488 lignes), `PLAN_REPRISE.md` | Refonte UI (septembre) et plan de reprise de septembre | **Historique** : ne plus s'en servir pour l'état courant |

Quand on crée un nouveau plan : l'écrire dans `docs/<SUJET>.md` **et** l'ajouter à ce tableau.

---

## 4. État de la production (27/10/2026)

- **Fonctions Firebase** (`afrolooki`) : déployées avec les changements du journal d'actualités et des rappels (voir journal, section 9). Planificateur de rappels (`reengagementTick`) en marche depuis le 23/10 ; **Firebase seul** depuis le 27/10.
- **Application** : le code `2.0.17+266` contient des changements **pas encore publiés** sur les stores : date de disparition des articles, plus d'actualités parmi les posts à découvrir, partage d'un article par lien, agents AfroMode/AfroInfo, gabarit d'en-tête sans flash du créateur sur les pages de détails des posts de canal.
- **Afro Journal** (`functions/src/news/`) : 51 médias nationaux, agents AfroMode et AfroInfo, 30 pays, passage **toutes les heures**, plafond de 120 articles par jour réparti sur 24 h. Les **photos de profil des deux nouveaux agents ne sont pas créées** (bouton admin « Créer les photos » à utiliser). Détails : `docs/` n'a pas de fichier dédié ; voir `functions/src/news/*.ts` et la mémoire de session (journal, section 9).
- **SlashAtlas** : système de commandes de la communauté, espace créateur, retraits manuels, j'aime sans compte, SEO, liens de partage avec aperçu : déployés (projet `slashatlas-studio`), commit `637924e2`.
- **Mesures de référence** (avant migration) : ~2 000 inscrits, ~40 actifs/jour, 553 000 lectures Firestore/jour, sortie Cloud Storage ~10 Go/jour, fonctions ~0,3 $/jour.

---

## 5. Périmètre : ce qui est migré, ce qui reste, ce qui est abandonné

### 5.1 Décisions de périmètre
| Date | Décision | Conséquence |
|---|---|---|
| 27/09/2026 | **Pronostics supprimés** de l'application | Ne pas migrer. Retirer le code résiduel (`Pronostic`, `ParticipationPronostic`, `PostType.PRONOSTIC`, fonction de paiement `pronostic`, `homeSportPost.dart` à vérifier) |
| 27/10/2026 | **Afrolove (rencontres) abandonné** | Ne pas migrer le module « dating » (23 000 lignes, collections `dating_*`). Masquer les entrées, garder les données en archive, supprimer le code ensuite |
| 27/10/2026 | **Pages qu'on n'affiche plus** : ne pas migrer | Inventaire dans `docs/PAGES_ORPHELINES.md` ; le propriétaire confirme page par page avant suppression |
| 28/09/2026 | Pages vidéo inutilisées à supprimer (garder `YouTubeVideoCard`, `postDetailsVideo.dart`, `post_video_format_tel_details.dart`) | Voir la liste des candidats dans `docs/PAGES_ORPHELINES.md` |
| 27/10/2026 | **Migration vers API Laravel + PostgreSQL + VPS Docker** ; Firebase gardé pour Auth, FCM, chats, Remote Config, App Check ; médias directement sur Cloudflare R2 | Plan : `docs/MIGRATION_API_LARAVEL.md` |
| 27/10/2026 | **Hébergeur : LWS** (VPS à accès administrateur complet, avec Docker). **Domaine : `afrolookmedia.com`** (déjà possédé) | Sous-domaines prévus : `api.`, `api-staging.`, `api-dev.`, `admin.`, `cdn.` (existant), `cdn-dev.` |
| 27/10/2026 | **Firebase Dynamic Links : non utilisé** (liens et pages d'aperçu de partage sur le domaine propre `afrolookmedia.com`) | Retirer le paquet `firebase_dynamic_links` et le code résiduel (`main.dart`, `authProvider.dart`) ; les pages de partage/aperçu (aujourd'hui la fonction `sharePostLink`) passent dans Laravel (gabarits Blade) + fichiers de liens profonds (`assetlinks.json`, `apple-app-site-association`) |
| 27/10/2026 | **Tout recréer proprement et sécurisé** : sécurité de la nouvelle plateforme + correction de **toutes** les failles de la version actuelle | Plan : `docs/SECURITE_API.md` (registre F1 à F13, correctifs d'urgence U1 à U8) |
| 27/10/2026 | **Conserver l'application actuelle (legacy, Firebase) intacte et accessible**, au cas où : le **nouveau frontend** et l'**API** vont dans des **dossiers séparés** ; le legacy reste consultable pour **comprendre et purger les données** | Consigné dans `docs/AGENTS_ET_ORGANISATION.md` §1-3 ; **rien n'est encore mis en place** |
| 27/10/2026 | **Trois agents** : un qui **travaille sur l'API**, un qui **fournit les informations de l'application**, un qui **supervise, rappelle la mémoire et s'assure que tout est bon** | Définitions et protocole : `docs/AGENTS_ET_ORGANISATION.md` §5 ; **rien n'est encore créé** |
| 27/10/2026 | **Les administrateurs et l'équipe (stagiaires, collaborateurs) ne doivent plus être reconnus par un simple champ modifiable** (`role = ADM` dans le profil : dangereux) | Modèle cible : table de droits écrite par le serveur seulement, permissions fines, 2FA, quatre yeux, comptes d'équipe dédiés — `docs/AGENTS_ET_ORGANISATION.md` §4 et `docs/SECURITE_API.md` §3.2 ; correctif intermédiaire U8 |
| 27/10/2026 | **Le frontend n'est PAS à recréer** : l'application existe déjà. Le nouveau frontend = **une copie de l'application actuelle, réadaptée à l'API** | Seule la **couche d'accès aux données** change (appels Firestore/fonctions → appels API via `ApiClient`) ; **les écrans, le design et les parcours restent**. Les **bibliothèques du téléphone restent aussi** (publicité AdMob/Appodeal, achat intégré Apple/Google, lecteurs vidéo/audio/YouTube/lives, éditeurs) : seul le **traitement serveur** derrière elles passe dans l'API (tableau détaillé : `docs/AGENTS_ET_ORGANISATION.md` §5.6). Voir `docs/AGENTS_ET_ORGANISATION.md` §1 (point 7) et §5.6. Le travail de migration côté application est donc un travail d'**adaptation**, pas de refonte |
| 27/10/2026 | **Partage du travail (précision du propriétaire)** : les **pages et l'interface existent déjà** ; ce qui est à **créer**, ce sont les **traitements** (aujourd'hui les Cloud Functions : ~152 appelables, 28 déclencheurs, 7 points HTTP, 25 tâches planifiées, ≈ 21 000 lignes) qui deviennent **l'API** ; tout le reste de l'application est **à réadapter** seulement. **Firebase ne sert plus ni au traitement des données ni au stockage** | Firebase est **conservé uniquement** pour : **authentification** (e-mail, vérification, Google, Apple), **notifications (FCM)**, **chats** (Firestore), **Remote Config**, **App Check**, et les **tâches périodiques** (voir question 15 : comment elles appellent l'API). Données métier : PostgreSQL via l'API. Fichiers : Cloudflare R2. L'estimation (4 à 5 mois et demi) est à recalculer sur cette base |

### 5.2 À faire pour appliquer les abandons (avant la migration, pour réduire le travail)
- [ ] Faire confirmer par le propriétaire la liste de `docs/PAGES_ORPHELINES.md` (supprimer / garder / à revoir).
- [ ] Masquer toutes les entrées d'Afrolove (accueil `homeScreen.dart`, `listTopModal.dart`, modale quotidienne `daily_modal_service.dart`, notifications `workManagerService.dart`, tableau de bord admin).
- [ ] Décider du sort des données `dating_*` (archive puis suppression à date fixée, ou conservation gelée) et le consigner ici.
- [ ] Retirer le code des pronostics (modèles, `PostType.PRONOSTIC`, paiement) après vérification qu'aucune donnée vivante n'en dépend.
- [ ] Mettre à jour le plan de migration : module 18 (Rencontres) marqué « abandonné » (fait le 27/10), phase 6 allégée.

---

## 6. Suivi de la migration (tableau de coordination)

Légende : ⬜ à faire · 🟦 en cours · ✅ fait et vérifié · ⛔ abandonné · 🔒 reste sur Firebase.
Plan, critères de sortie et risques : `docs/MIGRATION_API_LARAVEL.md`.

**Statut global : le plan est écrit ; en attente de validation du propriétaire (voir « Questions ouvertes », section 8). Aucun code d'API n'existe encore.**

### 6.0 Sécurité (parallèle à toutes les phases) — détail : `docs/SECURITE_API.md`
Correctifs d'urgence sur la version en production (**chacun demande l'accord du propriétaire**) :
- [ ] U1 changer les clés OneSignal et CinetPay (par le propriétaire) ; retirer la clé OneSignal de l'application
- [ ] U7 contrôle de compromission (administrateurs : **fait le 27/10, 2 comptes attendus** ; reste soldes, transactions, notifications)
- [ ] U5 supprimer la page de dépôt CinetPay inutilisée (`depotPaiment.dart`)
- [ ] U2 protéger `role` et les soldes, fermer les collections critiques de la règle générale Firestore (tests dans l'émulateur, déploiement par lots)
- [ ] U3 retirer les secrets de `AppData` et sa lecture libre
- [ ] U4 resserrer les règles Storage
- [ ] U6 limiter par IP l'envoi dans `user_profile/` en attendant le retrait de la règle temporaire
- [ ] U8 sortir les droits administrateur/équipe du profil : collection `Staff` écrite par le serveur seulement, un seul utilitaire de contrôle dans les fonctions, fermeture de `TeamMembers`/`TeamProfiles` (`docs/AGENTS_ET_ORGANISATION.md` §4.3)

Dans l'application : [ ] F7 jetons en stockage sécurisé · [ ] F8 plus de journaux sensibles · [ ] F10 clés Firebase restreintes + App Check imposé · [ ] retrait de `firebase_dynamic_links`

Nouvelle plateforme : [ ] comptes administrateurs séparés (RBAC, 2FA, Cloudflare Access) · [ ] Cloudflare Tunnel / pare-feu · [ ] sauvegardes chiffrées testées · [ ] test d'intrusion externe avant la phase 5

### 6.1 Phase 0 — Fondations (livrable : API opérationnelle en local)
- [ ] Réponses aux questions ouvertes (hébergeur, emplacement du code, installations…)
- [ ] Création du projet Laravel 12 (PHP 8.3) + dépôt Git, Pest, Pint, Larastan
- [ ] Base PostgreSQL locale `afrolook_dev` et `afrolook_test` (PostgreSQL 17 déjà installé sur le poste du propriétaire)
- [ ] Garde d'authentification `firebase` (jetons réels + émulateur en local) + App Check
- [ ] Utilisateur créé à la première requête (`firebase_uid`) ; `GET /v1/me`, `PATCH /v1/me`, `GET /v1/config`, `GET /v1/health`
- [ ] Envoi de médias par URL signée vers Cloudflare R2 de **développement** (ou MinIO) : `POST /v1/uploads` + `complete` ; lecture par `cdn-dev`
- [ ] Docker Compose (Caddy, PHP-FPM, PostgreSQL, Redis, Horizon, Scheduler, MinIO) + mode sans Docker pour le poste actuel
- [ ] Tests automatiques + documentation OpenAPI + pipeline CI
- [ ] Squelette du script de rapprochement Firestore → PostgreSQL
- [ ] Côté Flutter : `ApiClient` (jeton, nouvelle tentative, ETag), `API_BASE` par environnement, interrupteurs de modules (Remote Config)
- [ ] Test sur un vrai téléphone via Cloudflare Tunnel (`api-dev.<domaine>`)

### 6.2 Modules
| # | Module | Destination | Phase | Statut |
|---|---|---|---|---|
| 0 | Fondations | API | 0 | ⬜ |
| 1 | Configuration (AppConfig, AppData…) | API | 1 | ⬜ |
| 2 | Notifications (liste, rappels, FCM) | API | 1 | ⬜ |
| 3 | Comptes et profils | API | 2 | ⬜ |
| 4 | Abonnements (follows) | API | 2 | ⬜ |
| 5 | Publications, fil, découverte | API | 2 | ⬜ |
| 6 | Commentaires | API | 2 | ⬜ |
| 7 | Canaux | API | 3 | ⬜ |
| 8 | Chroniques | API (réponses : Firebase) | 3 | ⬜ |
| 9 | Chats (privés, groupes, entreprise, réponses de chroniques) | 🔒 Firebase | — | 🔒 |
| 10 | Quiz / Étude / Contes | API | 4 | ⬜ |
| 11 | Musique et sons d'artistes | API | 4 | ⬜ |
| 12 | Studio, cartes, stickers | API | 4 | ⬜ |
| 13 | Afro Journal (actualités) | API (ou conteneur Node au début) | 4 | ⬜ |
| 14 | Pubs | API | 5 | ⬜ |
| 15 | Portefeuille, pièces, paiements | API | 5 | ⬜ |
| 16 | Contenu payant et créateurs | API | 5 | ⬜ |
| 17 | Boutique (AfroShop) | API | 5 | ⬜ |
| 18 | Rencontres (Afrolove) | — | — | ⛔ abandonné |
| 18b | Pronostics | — | — | ⛔ supprimé |
| 19 | Lives (liste, jetons Agora, cadeaux ; commentaires : Firebase) | API | 6 | ⬜ |
| 20 | Administration, équipe, modération, signalements | API | 6 | ⬜ |
| 21 | E-mails | API | 6 | ⬜ |
| 22 | Série, récompenses hebdomadaires, invitations | API | 6 | ⬜ |
| 23 | Médias (R2 direct) | API + R2 | 3, en continu | ⬜ |
| — | Extinction des fonctions et collections migrées | — | 7 | ⬜ |

---

## 7. Chantiers hors migration (à reprendre, dans cet ordre de priorité à confirmer)

État **connu au 27/10/2026** ; vérifier avant de reprendre.

- [ ] **Publier une nouvelle version de l'application** (2.0.17+266) : emporte les changements non publiés de la section 4. Ne rien soumettre aux stores sans accord.
- [ ] **Créer les photos d'AfroMode et d'AfroInfo** (bouton admin « Créer les photos »).
- [ ] **Activer ou non l'envoi aux 1 444 anciens comptes** (`AppConfig/push.legacyReachEnabled`, désactivé) : décision du propriétaire.
- [ ] **Vérifier le journal** après le passage de 14 h 20 UTC : les résumés refusés (« texte_recopie ») doivent baisser grâce au second essai en modèle de qualité ; surveiller la consommation (`NewsBudget`, plafond 17 000 neurons/jour).
- [ ] **Appodeal** : passer les bannières à Appodeal (médiation) ; demander les identifiants avant l'intégration.
- [ ] **Maximiser les pubs** : proposition à présenter (audit fait, rien d'implémenté sauf le socle `RewardedAds`).
- [ ] **Quiz / Étude** : classements complets, widget top 3 personnes/pays, anti-triche, quiz pour les contes, réserve de questions.
- [ ] **Chroniques** : une chronique postée n'apparaît pas tout de suite ; rythme des pubs ; pubs vidéo Afrolook lentes.
- [ ] **Musique** : lecture en arrière-plan en réglage (désactivé par défaut), pages de détails (mauvaise page), notifications/e-mails de soumission, déblocage et double achat.
- [ ] **Textes des stores** (positionnement « réseau qui paie »), fiche App Store traduite, réponse Apple 2.0.5 : voir `docs/HANDOFF_AGENT.md`.
- [ ] **Dialogue entre personnages** (SlashAtlas Film) et **musique des templates** : plans validés, à coder.
- [ ] **Intégration MiniMax H3** (SlashAtlas) : clé API en cours d'obtention.
- [ ] **Fonctions facturées à retirer** : `syncFollowsFromLegacy` (≈ 89 % du temps de calcul) quand les anciennes versions auront disparu.
- [ ] **Règle Storage temporaire** `user_profile/` à retirer après diffusion du correctif d'inscription.

---

## 8. Questions ouvertes (à poser au propriétaire)

1. Facture Firebase réelle des 3 derniers mois par ligne (seuil de rentabilité de la migration).
2. ~~Hébergeur~~ **LWS (décidé le 27/10)**. Reste : l'offre exacte et le budget mensuel (VPS à accès administrateur complet, pas de mutualisé).
3. Emplacement du code de l'API : dossier frère `afrolook-api` avec son propre dépôt (recommandé) ou sous-dossier `api/`.
4. Version minimale par module (écran « mise à jour obligatoire ») acceptée ?
5. Installations sur le poste (Docker Desktop + WSL2, Redis, MinIO, `cloudflared`, k6) et sur quel disque (C : 45 Go libres, D : 9,9 Go).
6. ~~Domaine~~ **`afrolookmedia.com` (décidé)**. Reste à confirmer : DNS géré par Cloudflare (le CDN existant le suggère) et choix des sous-domaines `api.`, `admin.`.
7. ~~Dynamic Links~~ **non utilisé (décidé le 27/10)** : pages de partage et d'aperçu sur le domaine propre ; à reprendre dans Laravel.
8. Afro Journal : réécriture en PHP ou conteneur Node temporaire.
9. Décisions de sécurité (liste en fin de `docs/SECURITE_API.md`, §7) : ordre des correctifs d'urgence, 2FA admin obligatoire, Cloudflare Access, Cloudflare Tunnel, App Check imposé, seuil des quatre yeux, destinataire des alertes.
10. Sort des données `dating_*` (archive puis suppression, ou gel) et confirmation de la liste `docs/PAGES_ORPHELINES.md`.
11. **Organisation** (`docs/AGENTS_ET_ORGANISATION.md` §2) : noms et emplacements des dossiers, un dépôt Git par dossier, la mémoire vivante quitte-t-elle le dépôt legacy, même identifiant d'application et même projet Firebase pour le nouveau frontend, où archiver la copie du legacy (le disque D : n'a que ~9,9 Go libres), accord pour l'export Firestore de sauvegarde et son coût.
12. **Équipe et administrateurs** (`docs/AGENTS_ET_ORGANISATION.md` §4.2) : niveaux (super administrateur, administrateur, collaborateur, stagiaire), liste des permissions, comptes d'équipe **dédiés** (adresse distincte du compte personnel), échéance automatique des stagiaires, qui peut accorder quoi, seuil de validation à deux personnes.
13. **Agents** (`docs/AGENTS_ET_ORGANISATION.md` §5) : valider les rôles, les interdits et le protocole des trois agents avant de les créer.
14. **Adaptation du frontend** (`docs/AGENTS_ET_ORGANISATION.md` §5.6) : qui adapte la copie de l'application à l'API — l'agent API, un agent dédié, ou vous ? Ordre des écrans à adapter, et critère d'acceptation par module (parité avec l'application actuelle).
15. **Tâches périodiques sur Firebase** (consigne du propriétaire : « sauf les tâches périodiques ») : la planification reste chez Firebase (Cloud Scheduler) mais, comme les données seront dans PostgreSQL, chaque tâche **ne fait plus que déclencher l'API** (appel HTTP authentifié, la logique est dans Laravel). Confirmer : (a) la logique des 25 tâches (rappels, classements, nettoyages, journal d'actualités…) passe-t-elle dans l'API, déclenchée par Firebase ? (b) ou la planification passe-t-elle aussi à l'API (planificateur Laravel, plus simple et sans coût Firebase) ? (c) les **28 déclencheurs sur les données** (création d'un commentaire, d'un message de groupe…) ne peuvent plus exister côté Firebase pour les données migrées : ils deviennent des événements de l'API ; seuls ceux des chats restent.

---

## 9. Journal de bord (une ligne par session, du plus récent au plus ancien)

- **2026-10-27 (nuit, suite)** — *Claude (Sonnet 5.5)* — Précision du propriétaire consignée : **pages et interface déjà là** ; à créer = **les traitements (Cloud Functions → API)** ; tout le reste est **à réadapter** ; **Firebase ne garde que** authentification, FCM, chats, Remote Config, App Check et **les tâches périodiques** (question 15). Rien mis en place.
- **2026-10-27 (nuit)** — *Claude (Sonnet 5.5)* — Précision du propriétaire consignée : **le frontend n'est pas à recréer**, c'est la copie de l'application actuelle **réadaptée à l'API** (seule la couche de données change). Mesure de taille du legacy : `lib` 17 Mo, `assets` 6,7 Mo, `android` 306 Mo (copie légère). Rien mis en place. Reprendre à : questions 3 à 5 et 11 à 14.

- **2026-10-27 (soir)** — *Claude (Sonnet 5.5)* — Réponses du propriétaire consignées (LWS, `afrolookmedia.com`, pas de Dynamic Links, tout recréer sécurisé, règle « poser toutes les questions »). **Audit de sécurité** de la version actuelle : faille critique F1 (règle générale Firestore : tout compte connecté lit/écrit presque tout), F2 (administrateur = champ du profil), clé OneSignal et clé CinetPay dans l'application ; 2 comptes admin seulement, attendus. Écrit `docs/SECURITE_API.md`. **Rien de corrigé encore.** **Consigné aussi (rien mis en place)** : conservation du legacy et dossiers séparés pour le nouveau frontend et l'API, trois agents (API, informateur, superviseur), modèle d'identification des administrateurs et de l'équipe sans champ modifiable, constat que `TeamMembers`/`TeamProfiles` sont ouverts par la règle générale (F13). Nouveau document : `docs/AGENTS_ET_ORGANISATION.md`. **Reprendre à** : réponses aux questions 11 à 13 et accord du propriétaire sur les correctifs d'urgence (U1 en premier).
- **2026-10-27** — *Claude (Sonnet 5.5)* — Notifications : rappels programmés **Firebase seul** (plus de repli OneSignal), rotation quiz/étude/conte corrigée (le quiz n'était jamais choisi), planificateur à la demi-heure ; vérifié dans les journaux (8 h 30 : 85 personnes examinées, 61 actualités). Journal d'actualités : 51 médias nationaux, AfroMode et AfroInfo, 30 pays, passage horaire, plafonds par périmètre, second essai en modèle de qualité (déployé ; 1er passage : 6 résumés refusés sur 8, correctif déployé à 13 h 30, à vérifier). Application : gabarit d'en-tête sur les trois pages de détails d'un post de canal (plus de flash du créateur). Commits `637924e2` (SlashAtlas) et `077ca211` (Afrolook), poussés. Plan de migration Laravel écrit (`docs/MIGRATION_API_LARAVEL.md`), mémoire unique créée (ce fichier), inventaire des pages orphelines. **Reprendre à** : validation du plan et réponses aux questions de la section 8, puis phase 0.
- **2026-10-23** — Correction des notifications : le déclencheur arrondissait mal l'heure (aucun rappel ne partait). Déployé. Option « anciens comptes » (OneSignal) ajoutée, désactivée.
- **2026-10-20/21** — SlashAtlas : commandes de la communauté, espace créateur, retraits manuels, Top 10, j'aime sans compte, SEO ; Afrolook : partage d'un article avec lien.
- **2026-10-17/18** — CDN Cloudflare R2 devant Firebase Storage (sortie Storage 33 → ~10 Go/jour) ; audit des lectures Firestore ; mesure par écran (`ReadStats`).
- **2026-10-12** — Passation `docs/HANDOFF_AGENT.md` (accès, secrets, Apple, SlashAtlas).
- **2026-09-24/28** — Conformité App Store (achats intégrés, tout en pièces, deux soldes, suppression de compte, EULA/blocage) ; plan en 8 groupes ; pronostics supprimés.

---

## 10. Où chercher quoi (aide-mémoire rapide)

| Besoin | Où |
|---|---|
| Règles de sécurité Firestore / Storage | `firestore.rules`, `storage.rules` (à porter en Policies Laravel lors de la migration) |
| Toutes les fonctions serveur | `functions/src/index.ts` et un dossier par domaine (`posts`, `payments`, `news`, `notifications`…) |
| Envoi des notifications | `functions/src/shared/push.ts`, `notification_utils.ts`, `functions/src/notifications/` |
| Comptage des lectures par écran | `lib/services/read_meter.dart`, écran Admin « Mesure des lectures », collection `ReadStats` |
| Journal d'actualités | `functions/src/news/` (sources, pipeline, agents), page admin `lib/pages/admin/news_admin_page.dart` |
| Données de test Firebase en local | `scripts/seed_emulator.js`, `scripts/seed_auth_emulator.js`, `emulator-data/` (non versionnés) |
| Mémoire privée d'un agent Claude | `~/.claude/projects/…/memory/` : **ne pas s'y fier** ; la vérité est ici |

---

## 11. Organisation du travail, conservation de l'existant et agents (résumé)

Détail et instructions complètes : `docs/AGENTS_ET_ORGANISATION.md`. **Statut : consigné, rien n'est mis en place.**
- **Legacy conservé et accessible** (application + fonctions Firebase + données), pour consulter, comprendre et, **sur demande explicite du propriétaire seulement et après sauvegarde**, purger.
- **Dossiers séparés** : nouveau frontend Flutter, API Laravel, et un dossier de coordination qui porte la mémoire vivante et la définition des agents (noms et emplacements à confirmer).
- **Trois agents** : **API** (construit), **Informateur** (connaît l'application actuelle, écrit les fiches de module, sonde les données en lecture seule), **Superviseur** (rappelle la mémoire, contrôle chaque livrable, valide, met à jour le suivi).
- **Administrateurs et équipe** : jamais reconnus par un champ modifiable ; table de droits écrite par le serveur, permissions fines, 2FA, validation à deux personnes, comptes d'équipe dédiés (`docs/AGENTS_ET_ORGANISATION.md` §4).
- **Frontend** : le nouveau frontend n'est **pas** une refonte : c'est **la copie de l'application actuelle**, dont la **couche d'accès aux données** est réadaptée à l'API (écrans et design inchangés). Détail : `docs/AGENTS_ET_ORGANISATION.md` §5.6.
- **Partage du travail** : interface existante (à réadapter) ; **traitements = API** ; Firebase = authentification, FCM, chats, Remote Config, App Check et tâches périodiques (question 15). Plus de traitement ni de stockage de données métier chez Firebase.
