# Prompt de reprise du projet Afrolook (à donner à un autre agent)

> Copier tout ce qui suit la ligne « ---- DÉBUT DU PROMPT ---- » dans la première consigne du nouvel agent.
> Préparé le vendredi 30 octobre 2026. Période couverte : du lundi 26 octobre au vendredi 30 octobre 2026.

---- DÉBUT DU PROMPT ----

Tu reprends le projet **Afrolook** (dépôt `D:\bienvenu\Projets\otherProjets\afrolook\V2\afrolookofficiel_v2`, branche de travail `refonte_claude`, projet Firebase `afrolooki`). Un autre agent y a travaillé toute la semaine avec le propriétaire. Ton premier travail est de **comprendre l'état exact du projet avant de toucher à quoi que ce soit**. Réponds toujours en **français** (accents corrects), simplement et directement.

## 1. À lire en premier (dans cet ordre)
1. `CLAUDE.md` (racine) : règles d'agent.
2. `docs/PROJET_MEMOIRE.md` : **mémoire unique du projet** (état, décisions, règles métier, journal de bord du plus récent au plus ancien, section 9). Les entrées du 26 au 30 octobre racontent tout ce qui suit en détail.
3. `docs/SECURITE_API.md` avant de toucher aux règles, aux paiements, aux comptes ou aux administrateurs.
4. `docs/AGENTS_ET_ORGANISATION.md` (organisation, conservation du legacy, comptes d'équipe).
5. Selon le sujet : `docs/PARTAGE_WHATSAPP_ADS.md`, `docs/OFFERWALL_TACHES.md`, `docs/ADS_EDITEURS_PROPOSITION.md`, `docs/ADS_VERROUILLAGE_ADVERTISEMENTS.md`, `docs/MIGRATION_API_LARAVEL.md`.
6. `git log --oneline -12` et `git status` pour voir ce qui est commité, poussé, et ce qui reste local.

## 2. Règles du propriétaire (à respecter strictement)
- **Poser les questions avant d'agir** quand une information manque ; **proposer avant tout changement important** ; ne rien décider seul.
- **Ne jamais commiter ni pousser sans demande explicite** (« commit et push »). **Ne jamais déployer en production sans un « oui, déploie » explicite** pour l'action en cours (un accord précédent ne couvre pas la suivante). Le propriétaire peut aussi préférer lancer lui-même les commandes : lui donner alors la commande exacte, une fonction par commande.
- **Aucun secret** dans le dépôt, les messages ou les captures. Les clés sont dans `functions/.env`, `assets/env/*.env`, Firebase Secrets, groupes Codemagic : tous ignorés par Git. Ne jamais les afficher.
- **Vocabulaire** : sur toutes les pages de la régie, écrire **« Afrolook Ads »** (pas « Afrolook » seul pour la régie). **Ne jamais afficher la part gardée par Afrolook** (ni les 25 %, ni « Afrolook garde ») dans une interface ou un texte public. Les calculs de marge ne se donnent qu'au propriétaire, dans la conversation.
- **Tout ce que dit le propriétaire est consigné** dans `docs/PROJET_MEMOIRE.md`. En fin de session : cases cochées + une ligne de journal datée.
- Tout texte visible est traduit via `context.tr('français', {args})` (dictionnaires `lib/l10n/tr_*.dart`, enregistrés dans `lib/l10n/tr.dart`) ; seul l'anglais est fait pour les nouveaux textes, les autres langues retombent sur le français.
- Windows : shell Git Bash ou PowerShell. `MSYS_NO_PATHCONV=1` devant les commandes Flutter dans Git Bash. Pour modifier un fichier avec des guillemets, des `$` ou des apostrophes, **écrire un petit script Node avec l'outil d'écriture de fichier** plutôt que des here-documents (les échappements se perdent). Les commandes `gcloud` se lancent dans PowerShell, avec les guillemets doubles échappés.

## 3. Ce qui a été fait, par jour

### Lundi 26 et mardi 27 octobre
- **Notifications** : rappels programmés en Firebase seul (plus de repli OneSignal), rotation quiz/étude ; **Afro Journal** (agents IA d'actualités, extension aux médias nationaux, AfroMode et AfroInfo) ; **SlashAtlas** : commandes de la communauté, classement, liens de partage avec aperçu, SEO, recherche tolérante (commits `637924e2`, `077ca211`).
- **Mémoire unique du projet** et plan de migration vers une API Laravel (commit `5a62c53c`). Afrolove et pronostics abandonnés.
- **Mur de tâches rémunérées (offerwall)** : intégration **Tapjoy + ayeT-Studios (+ PubScale)**. Serveur (`functions/src/offerwall/`), application (`lib/pages/offerwall/`, `lib/services/offerwall/`), administration, clés secrètes posées dans Firebase Secrets, retours serveur en ligne. Règles : conversion **2,5 pièces = 1 F** (25 pièces = 10 FCFA), répartition 50 % utilisateur, parrain en plus, retenue 48 h, plafonds par jour et par semaine. Android compile avec le SDK ; iPhone via Codemagic.

### Mercredi 28 octobre
- Site vitrine `afrolookmedia.com` (dossier `site/`) : section « L'application », mise en ligne ; **réparation de `/app/`** (application web Flutter, publiée avec `node with-app.mjs`).

### Mercredi 28 au jeudi 29 octobre : **Afrolook Ads** (régie publicitaire unifiée)
- Maquette validée, puis annonces web gratuites (3 annonces de 14 jours, vidéo 15 s maximum, plusieurs images), galerie publique, suivi des vues et clics.
- **Moteur unique** (`functions/src/ads/adsEngine*.ts`) : jeton signé HMAC, `adsServe` / `adsEvent` / `adsGo`, compteurs répartis, plafonds, App Check pour les applications. **Diffuseurs** (sites et applications avec identifiant `ap_…`), audience mesurée (comptage HLL) comparée à la déclarée, ciblage, catégories (sensibles réservées aux diffuseurs qui les acceptent), **protections et surveillance** (`adsWatch`, alertes, blocage des paiements).
- **SlashAtlas et PronoFlash** passent sur le moteur (PronoFlash : seulement Afrolook Ads, plus de réseaux tiers). Formats d'affichage refaits comme AdMob (bannière 320×50 / 320×100 / 300×250 / 728×90, bannières « prêtes » image seule), composant Flutter `lib/ads/afrolook_ads_banner.dart`.
- **Tarif validé** (par 1 000 affichages, part diffuseur 65 %) : bannière 1 000 F, sticky 1 250, native 1 500, carrousel 1 800, affiche 2 000, vidéo 2 500, interstitiel 3 000, récompensée 3 500 F ; **remise de lancement −30 % pendant 1 mois** (`LAUNCH_DISCOUNT` dans `adsGuard`). Profil annonceur entièrement validé avant publication ; espace administrateur détecté automatiquement (deux e-mails : `jorbienvenu@gmail.com`, `officiel.afrolook@gmail.com`), jamais de bouton « admin ».

### Jeudi 29 au vendredi 30 octobre : **Partage et gagne** (jobs et tâches Afrolook)
Décisions du propriétaire : ce sont des **jobs dans NOTRE application uniquement**, jamais servis chez les partenaires ; **aucune annonce gratuite** pour ces tâches ; elles se lancent depuis la plateforme annonceurs : **administrateur = campagne offerte** (aucun paiement), **autres annonceurs = ils paient l'audience à atteindre** (indicatif **500 F pour 1 000 personnes**, `AppConfig/share.audiencePricePer1000Fcfa`, validation manuelle « paiement reçu », **frais de paiement payés EN PLUS par l'annonceur** : 5,6 % mobile money, 9,9 % carte). Le plafond de gains réservé aux partageurs est **60 % du prix** et **la part du parrain y est comptée** (chaque clic consomme 5,5 F). Marge minimale 40 %.
- **Gain** : 5 F par clic valide (12,5 pièces), **plafond 100 clics par jour = 500 F**, 100 clics par lien et par jour, retenue 72 h, **parrainage 10 % en plus** (`AppConfig/share.sponsorPct`).
- **Partageur** : profil (WhatsApp, audience du statut, Telegram, groupes) **validé par l'équipe avant toute mission** ; lien personnel `https://afrolookmedia.com/p/<code>/` (page intermédiaire, 1 s, clic jugé côté serveur) ; chaque gain porte sa plateforme dans l'historique des tâches.
- **Antifraude** : un clic payé par personne et par campagne (identifiant navigateur à vie + doublon IP/appareil du jour), robots et aperçus de messagerie jamais comptés, auto-clic refusé ; surveillance horaire par partageur (`adsShareFraudScan`) : soupçon = gains bloqués, fraude grave = gains retirés (pièces reprises, dette si déjà dépensées), parrain repris, profil suspendu, alerte. Les consignes affichées le disent explicitement.
- **Audience touchée** : aperçus et ouvertures du lien comptés ; **publication prouvée** à la première ouverture par une autre personne que le partageur (`provenReach`) ; **vues déclarées** par le partageur (`adsShareReport`, contrôlées, jamais présentées comme mesurées). L'espace annonceur affiche ces chiffres.
- **Application** (`lib/pages/share/share_earn_page.dart`, `lib/services/share/share_service.dart`, `lib/widgets/offerwall_entry_card.dart`, `lib/widgets/feed/sections/offerwall_feed_card.dart`) : carte « Travaille et gagne de l'argent » dans le fil et sur la page Récompenses (comptes Gold inclus), page Partage et gagne (montants en FCFA d'abord), détail de mission, bannières réseau seulement (jamais de pub Afrolook gratuite dans les tâches), pub plein écran avant la page des missions. L'ancienne tâche « Regarder une pub » est désactivée (`adTask.enabled` faux par défaut).
- **Page d'administration dans l'application** (`lib/pages/admin/ads_regie_admin_page.dart`) : onglets Partageurs et Campagnes ajoutés. Le site a les mêmes onglets (`/ads/admin/`).
- **Site** : section « Campagne Partage » et bloc « Jobs et tâches Afrolook » (accueil, « Comment gagner », `/ads/`, page diffuseurs), **version anglaise `/en/ads/`** (les espaces annonceur et diffuseur restent en français), **kit de partage `/ads/partager/`** (liens, messages, affiches), affiches et images d'aperçu générées par `site/affiches/make.mjs` (Edge sans fenêtre, profil séparé obligatoire). Formulaire annonceur adapté au mode « Campagne Partage ».
- **Correctifs de fin de semaine** : contrôle d'ancienneté du compte (3 jours) **supprimé** (`minAccountAgeDays` à 0 ; beaucoup de comptes n'ont pas de `createdAt`, repli sur la date de création Firebase) ; messages d'erreur du profil simples et traduits (plus de trace technique) ; partage sur iPad (zone d'ancrage + repli sur le texte) ; page de tâches réorganisée (missions d'abord, bloc « Gains, parrainage et consigne » repliable, bouton « Consigne » par mission).

## 4. État actuel (à vérifier toi-même)
- **Poussé sur `origin/refonte_claude`** (5 commits du 30/10 : `c98eb72f` serveur, `d26ccbe9` sites, `ae040001` application, `554635e8` documentation, `30167052` mémoire).
- **Local, NON commité** (au moment de la rédaction) : `functions/src/offerwall/offerwall_logic.ts` et `offerwall_shared.ts` (suppression du contrôle des 3 jours + date Firebase), `lib/l10n/tr_share.dart`, `lib/pages/admin/admin_dashboard_page.dart`, `lib/pages/admin/ads_regie_admin_page.dart`, `lib/pages/share/share_earn_page.dart`, `lib/services/share/share_service.dart`, `docs/PROMPT_REPRISE_AGENT.md`, `functions/integration/` (tests d'intégration). Les fonctions serveur correspondantes ont été **déployées par le propriétaire** ; l'application ne l'est pas.
- **En production** : fonctions `ads*` (moteur, annonceurs, diffuseurs, partage), `adsShare*` (10), `offerwall*`, `adTask*`, règles Firestore, vitrine (jusqu'à `/en/ads/` et `/ads/partager/`). `AppConfig/share = {enabled: true}` (service ouvert). Une campagne de partage active et financée existe ; **aucun profil de partageur** n'était encore créé au moment de la rédaction.
- **Application** : version `2.0.17+267` (`pubspec.yaml` et `app_version_code` dans `lib/providers/authProvider.dart`, alignés). Codemagic (workflow « iOS TestFlight Build ») construit **depuis le dépôt distant** et fixe lui-même le numéro de build (dernier TestFlight + 1). Les builds testés avant le 30/10 ne contenaient pas le travail des tâches et du partage (rien n'était poussé).

## 5. Ce qui reste à faire ou à vérifier (par priorité)
1. **Valider le premier profil de partageur** de bout en bout : création dans l'application, validation (application ou site), partage d'une mission, clic d'un autre appareil, gain « en attente » 72 h. Vérifier sur iPad le partage (zone d'ancrage) et la carte d'entrée.
2. **Pubs absentes sur iPad (TestFlight)** : configuration `AppConfig/ads` correcte (activé, iOS activé, 100 %, emplacements iOS renseignés). Cause inconnue : demander au propriétaire le contenu du module admin « Pub AdMob » → « Voir les erreurs renvoyées par Google » (code d'erreur, ex. « No fill »). Piste : application/emplacements iOS peu servis par AdMob, consentement ou suivi refusé.
3. **Commit et push des changements locaux** (sur demande), puis nouveau build Codemagic et publication Android. Monter `pubspec.yaml` et `app_version_code` si la version 2.0.17 est déjà en production.
4. **Marge et tarif d'audience** : le propriétaire a gardé 500 F pour 1 000 personnes et accepté de compter le parrain dans le plafond ; paiement en ligne (FeexPay) des campagnes **pas encore branché** (validation manuelle « paiement reçu » aujourd'hui).
5. Traduire `lib/l10n/tr_share.dart` en es/pt/de/ar/zh/sw ; `/ads/` en anglais : seuls la page d'accueil de la régie est traduite.
6. Verrouiller la collection `Advertisements` (règle prête dans `docs/ADS_VERROUILLAGE_ADVERTISEMENTS.md`, non active) ; App Check pour le web ; intégration d'Épargne+ ; test instable `functions/src/ads/__tests__/adsHll.test.ts` (tolérance statistique 4 %, échoue environ une fois sur dix, sans lien avec le reste).
7. Application : analyser les nouveaux fichiers (`flutter analyze`) ; seuls des avertissements de style existaient à la dernière vérification.

## 6. Comment travailler et vérifier
- **Fonctions** : `cd functions && npm run build` (ou `npx tsc`), tests unitaires `npx jest` (45 suites, environ 440 tests) ; **tests d'intégration** contre l'émulateur : `functions/integration/run_all_it.ps1` (adv, watch, pub, engine, share ; le dernier doit afficher « 69 réussis »).
- **Application** : `MSYS_NO_PATHCONV=1 flutter analyze <fichiers>` (long : lancer en arrière-plan si besoin).
- **Site** : `cd site && node build.mjs`, puis **avant toute publication** `node with-app.mjs` (copie l'application web dans `dist/app/` : ne jamais publier `site/dist` sans elle) et supprimer `site/dist/_test` s'il existe. Contrôle local : petit serveur statique sur `site/dist`.
- **Déploiement** (seulement sur « oui, déploie ») : fonctions une par une `firebase deploy --project afrolooki --only functions:<nom>` ; règles `--only firestore:rules` ; vitrine `--only hosting:vitrine`. Les nouvelles fonctions appelables répondent publiquement (aucun accès `gcloud` à régler, vérifié le 30/10). Toute nouvelle collection côté serveur uniquement doit être ajoutée aux **deux** listes d'interdiction de `firestore.rules`.
- **Journaux** : `gcloud logging read 'resource.type="cloud_run_revision" AND resource.labels.service_name="<nom en minuscules>"' --project afrolooki --freshness=2h` (PowerShell). Les messages « App Check token rejected, enforcement is disabled » sont normaux.
- **Production** : lire la configuration avec un petit script Node utilisant `firebase-admin` (identifiants de l'utilisateur déjà connecté) : `AppConfig/share`, `AppConfig/ads`, `AppConfig/offerwall`, collections `ShareCampaigns`, `AdShareProfiles`, `AdShareStats`, `AdShareEarnings`.

## 7. Cartographie rapide
- Serveur : `functions/src/ads/` (régie : `adsEngine`, `adsWeb`, `adsAdvertisers`, `adsPublishers`, `adsWatch`, `adsGuard`, `adsShare*`), `functions/src/offerwall/` (tâches de partenaires, `userFacts` et `blockReason` dans `offerwall_shared.ts` et `offerwall_logic.ts`), `functions/src/index.ts` (exports).
- Application : `lib/ads/` (pubs), `lib/pages/share/`, `lib/pages/offerwall/`, `lib/services/share/`, `lib/services/offerwall/`, `lib/pages/admin/`, `lib/pages/rewards/rewards_page.dart`, `lib/l10n/`.
- Sites : `site/` (vitrine, `src/ads.mjs` pour la régie, `static/js/ads.js`, `static/css/ads.css`, `affiches/make.mjs`), `slashatlas/`, `pronoflashia/`.

## 8. Premier message attendu de ta part
Après lecture, réponds au propriétaire en français par : (1) un résumé de 10 lignes de ce que tu as compris, (2) l'état Git réel (commité / local), (3) les 3 points que tu proposes de traiter en premier, (4) tes questions. **N'agis pas avant sa réponse.**

---- FIN DU PROMPT ----
