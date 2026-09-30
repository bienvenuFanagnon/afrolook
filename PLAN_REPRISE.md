# PLAN DE REPRISE — à suivre si le quota s'arrête
_Créé le 29 sept. 2026 — branche `refonte_claude` (dernier commit : `fee2244`)._
_Règle : tout en français. Cocher `[x]` au fur et à mesure et committer ce fichier avec chaque lot._
_Flutter n'est pas installé dans l'environnement cloud : pas de `flutter analyze`. Vérifier par recherche (grep) que chaque symbole supprimé n'est plus référencé._

## Contexte (ce qui est déjà fait, ne pas refaire)
Voir `git log` : pièces partout, rémunération/commissions côté serveur, DÉFI sécurisé, conformité App Store, devises locales, tutoriel de monétisation (`lib/pages/intro/monetization_tutorial.dart`), suppression de l'ancien module Challenge (modèles + providers).

---

## LOT 1 — ✅ FAIT (29/09) — Page détails des DÉFIs : carte « Ce DÉFI a rapporté »
Fichier : `lib/pages/defi/defi_details_section.dart` (classe `DefiRevenueCard`, ~l.274-395 ; appelée l.169).

Problèmes signalés :
- Calculs pas clairs.
- « Part de l'app » affichée comme si l'app prenait la cagnotte : faux. La cagnotte revient aux **gagnants**. L'app ne prend que sa **commission** sur les votes et participations.
- Trop de jargon (parts, commissions, parrainages).

À faire :
- [ ] Ne montrer que ce que le DÉFI a **remporté** au total (votes + participations), en gros, **sans retirer la commission de l'app**.
- [ ] Supprimer les lignes « Part du créateur (70 %) », « Parrainages », « Part de l'app » et le paramètre `showAppShare` (+ l'appel l.169).
- [ ] Garder : total en grand, puis 2 lignes simples (Votes : X pièces · N votes ; Participations : X pièces · N participations).
- [ ] Vérifier que la cagnotte des gagnants n'est présentée nulle part comme « part de l'app ».
- [ ] Chercher les autres endroits qui affichent ces parts (`grep -rn "Part de l'app\|Part du créateur" lib`) et nettoyer aussi `lib/l10n/tr_money.dart`.

## LOT 2 — ✅ FAIT (29/09, cause probable : format « 1,2K » dans le feed vs nombre brut dans les détails ; format unique `lib/utils/count_format.dart`. Si l'écart persiste, vérifier la source du compteur) — Nombre d'abonnés différent entre détails du post et feed
Constat : les deux utilisent `user.followersCount` (`model_data.dart` ~l.1014 : max entre `userAbonnesIds.length` et `abonnes`). La différence vient donc de la **source de l'objet `user`** :
- détails : `lib/pages/postDetails.dart` ~l.3216 ;
- feed : `lib/pages/userPosts/postWidgets/postView.dart` l.1478 et l.2225 ; cartes feed : `lib/widgets/feed/sections/feed_*`.
Certaines copies sont en cache sans la liste `userAbonnesIds`, d'autres avec un `abonnes` périmé.

À faire :
- [ ] Repérer d'où vient l'utilisateur dans chaque écran (cache vs lecture Firestore fraîche).
- [ ] Choisir UNE source de vérité : le compteur serveur `abonnes` (mis à jour par Cloud Function) ou la liste, et l'appliquer dans `followersCount`.
- [ ] Si besoin, recharger l'utilisateur dans `postDetails` avec la même méthode que le feed.
- [ ] Vérifier que la Cloud Function tient bien `abonnes` à jour à chaque abonnement/désabonnement.

## LOT 3 — ✅ FAIT (29/09) — Tutoriel : apparition plus tôt dans les feeds
Fichiers : `lib/pages/intro/monetization_tutorial.dart` (`MonetizationReminder`, `FeedMonetizationReminder`), inséré dans `HomeConstPost.dart` l.~3750 (`i == 5`), `homeSportPost.dart` l.~2946, `post_video_format_tel_details.dart` l.~3804.

- [ ] Faire apparaître le rappel plus tôt (FAIT : après le 2ᵉ post au lieu du 6ᵉ, et dès le premier affichage du feed de la session).
- [x] Fréquence décidée : **1 fois par jour** par feed → passer `_every` de 3 jours à 1 jour dans `MonetizationReminder`. Vérifier `_shownThisSession` : la première apparition ne doit pas être bloquée.

## LOT 4 — 🟡 V1 FAITE (29/09), à tester et compléter — 10+ tutoriels de rémunération, avec scènes tournantes
Idée : une **liste de tutoriels** (un par fonctionnalité qui rapporte), chacun composé de **scènes**, chaque scène ayant **son bouton d'action** (ex. « Créer mon canal »).

### 4.1 Liste proposée (à valider avec le propriétaire)
Hiérarchie : du plus simple/courant au plus avancé.
1. Likes payants (existant : scène « like → pièces »)
2. Cadeaux en pièces sur les posts
3. Commentaires payants (2 pièces)
4. Vues / Publicash (encaissement)
5. DÉFI (participer, voter, gagner la cagnotte)
6. Canaux privés par abonnement
7. Contenu payant à paiement unique (vidéos, ebooks, formations)
8. Groupes privés payants (70 % / 30 %, code unique)
9. Lives et cadeaux de live
10. Parrainage et affiliation
11. Boost et publicités
12. Retrait de ses gains (devise locale, Mobile Money / virement / PayPal, min. 100 $)

### 4.2 Structure des scènes (pour chaque tutoriel)
Ordre de lecture identique partout : **1) le problème/le gain en une phrase → 2) comment ça marche (démo animée) → 3) combien ça rapporte (chiffre) → 4) bouton d'action**.
- [ ] Créer un modèle `TutoScene { titre, accroche, animation, chiffre, labelBouton, routeAction }` et `TutoDef { id, titre, scenes }` (nouveau fichier `lib/pages/intro/tutos/tuto_catalog.dart`).
- [ ] Extraire le moteur d'animation de `monetization_tutorial.dart` (1 587 lignes) en composants réutilisables ; ne pas casser le tutoriel actuel (`MonetizationTutorialPage.alreadySeen()` dans `splashChargement.dart` l.~762).
- [ ] Écrire les textes dans `lib/l10n/tr_tuto.dart` (`context.tr`, 8 langues déjà gérées).
- [ ] Écran « Liste des tutoriels » (accessible depuis le menu et le bouton « Revoir »).
- [ ] Ne rien afficher en argent sur iOS : prix en pièces seulement (règle App Store 2.0.4).

### 4.3 Rotation d'affichage
- [ ] Dans les feeds : à **chaque affichage du rappel**, passer à la scène suivante (index sauvegardé dans SharedPreferences, clé par feed).
- [ ] Page d'avant login : afficher **une scène tous les 2 jours** (au lieu de tout le tutoriel).
- [ ] Chaque scène : son bouton d'action qui ouvre la bonne page (les tutoriels non connectés renvoient vers l'inscription).

---

## LOT 5 — Finir le retrait de l'ancien Challenge (reste du travail d'hier)
27 fichiers Dart mentionnent encore « challenge » (`grep -rIn -i challenge lib | grep -v l10n | grep -viE "defi|défi"`). Principaux :
- [ ] `mixed_feedvideo_service.dart` : `VideoFilter.CHALLENGE`, `PostType.CHALLENGEPARTICIPATION`
- [ ] `userProvider.getChallengeUsers`
- [ ] `feed_repository.dart` : `FeedType.challenges`
- [ ] `remote_config_service.dart` : `page_challenge_mois_active`
- [ ] `abonnement_utils.dart` : `canJoinChallengesFreely`
- [ ] `contenuPayantProvider.dart` (catégorie « Challenges » factice)
- [ ] `model_data.dart` : `challenge_id`, `votesChallenge`, `challengeMonth`, `challengeStartDate`, enums `CHALLENGE`, `inscriptionChallenge`. **Attention** : garder ce qui sert à lire d'anciennes données ; supprimer seulement le mort.
- [ ] `postDetails.dart`, `postDetailsVideo.dart`, `post_video_format_tel_details.dart`, `homeScreen.dart`, `listTopModal.dart`, `mes_notifications.dart`, `otherUser.dart`, `UserPubVibeTab.dart`, `userAbonnementPage.dart`
- [ ] Vérifier après chaque suppression qu'aucun import ni symbole n'est orphelin (`grep`).
- [ ] Attention : `model_data.g.dart` est généré ; le modifier avec la même logique que `model_data.dart`.

## LOT 6 — Clôture
- [ ] Balayer les écrans iOS pour repérer les montants en argent restants.
- [ ] Vérifier que `updateExchangeRates` est déployée et que `AppConfig/exchangeRates` existe.
- [ ] Mettre à jour `SUIVI_REFONTE.md` (dernière mise à jour : 7 juillet).
- [ ] Ouvrir une PR draft de `refonte_claude`.

---

## Ordre conseillé
LOT 1 → LOT 2 → LOT 3 (rapides, corrigent des bugs signalés) → LOT 4 (gros chantier, valider la liste 4.1 d'abord) → LOT 5 → LOT 6.

## Journal d'avancement
_(ajouter ici une ligne par lot terminé : date, commit)_

### Suite LOT 2 (29/09) — abonnés uniformisés
Nouveau `lib/services/followers_count_service.dart` (`FollowersCountBuilder`) : une seule source (doc `Users`, max(liste, compteur), cache 3 min) + format `formatCompactCount`. Branché sur : feed (`postWidgetPage`, `postView`), détails image/audio (`postDetails`), vidéo paysage/portrait (`postDetailsVideo`, `post_video_format_tel_details`, `youTube_video_card`), Mon profil (`profile.dart`, `profile_page.dart`), création de post (`userPostForm`).
- [x] Listes secondaires branchées (amis, invitations, autre profil, onglets profil, entreprise). Non branchés volontairement (listes longues, coût en lectures) : classements, top, découverte.
- [ ] Vérifier si le compteur `abonnes` et la liste `userAbonnesIds` divergent dans Firestore (cause probable de 171 vs 123) et réparer les données.

### Suite LOT 4 (29/09) — V1 livrée
Fichiers : `lib/pages/intro/tutos/tuto_catalog.dart` (12 scènes, `tutoScenesAvailable`), `tuto_scene_card.dart` (`TutoSceneCard`, `TutoRotation`, `TutoListPage`, `TutoScenePage`, `TutoBeforeLoginPage`).
- Feeds : `FeedMonetizationReminder` alterne l'animation « like » (créneau 0) puis les 12 scènes, une nouvelle scène à chaque affichage (1×/jour/feed).
- Avant login : après le tutoriel initial, une scène publique tous les 2 jours (`splashChargement.dart`).
- Textes en français seulement (repli si absent de `tr_tuto.dart`) → [ ] ajouter les 7 langues dans `tr_tuto.dart`.
- [ ] Ajouter « Tous les tutoriels » (`TutoListPage`) au menu.
- [ ] Vérifier sur iOS : scène « contenu payant » masquée ; aucun montant en argent dans les textes.
- [ ] Vérifier chaque `action` (pages ouvertes sans argument requis) et le rendu plein écran (feed vidéo).
- [ ] Valider les textes/chiffres avec le propriétaire (surtout 70 %/30 % groupes, 1 pièce au créateur par commentaire (le commentateur paie 2), DÉFI).

### Suite LOT 5 (29/09) — nettoyage prudent
Supprimé (code mort, aucune référence) : `getChallengeUsers`, `canJoinChallengesFreely`, clé `page_challenge_mois_active`, `FeedType.challenges`.
Volontairement GARDÉ (compatibilité anciennes données Firestore / catégorie de contenu) : `PostType.CHALLENGE(PARTICIPATION)`, filtres de `mixed_feedvideo_service`, champs `challenge_id`/`votesChallenge`/`challengeMonth` du modèle, catégorie « Challenges » des contenus payants, textes l10n.
- [ ] Reste : décider si l'on supprime aussi ces champs après migration des anciens posts.

### 29/09 — Traductions des 12 scènes faites (7 langues, `tr_tuto.dart`). Page admin : module « Tutoriels » (`TutoListPage(showAll: true)`) liste toutes les scènes avec étiquettes (avant connexion / masquée iOS).
- [x] Entrée « Tous les tutoriels » ajoutée au menu (mobile + ordinateur) dans `homeScreen.dart`.

### 29/09 — Correctif démarrage automatique (pièces absentes, @null, « Erreur technique » à l'abonnement)
Causes trouvées : (1) le cache de démarrage ne stockait ni les pièces (`giftCoinsBalance`, `lockedCoins`…) ni les listes d'abonnements, et rien ne prévenait les écrans après le rafraîchissement ; (2) les listes par défaut `const []` de `UserData` sont non modifiables → `.add()` levait « Unsupported operation » dans `abonner()` ; (3) `getLoginUser` renvoyait `false` (donc retour au login / pas de rafraîchissement) si une étape secondaire échouait.
Corrigé : cache complété, listes modifiables dans le constructeur, `notifyUserDataChanged()` après refresh (2 essais), `getLoginUser` tolérant, `abonner()` n'affiche plus d'erreur si seules les étapes secondaires échouent.
- [ ] À confirmer sur téléphone ; si « @null » persiste, chercher quel écran lit `loginUserData` avant le chargement (pseudo vide dans le cache ?).

### 29/09 — iOS + groupes
- Prix d'abonnement de canal affiché en pièces (feed, fil vidéo), bannière pub en pièces, équivalents « 1 FCFA = 2,5 pièces » et « 500 pièces à 250 FCFA » masqués sur iOS. Reste des FCFA à vérifier : `mesLives.dart` (totaux des entrées payantes, ancien champ FCFA), prix d'articles marketplace (masquée sur iOS), pages admin/retrait (légitimes).
- Groupes : carte « Ce groupe t'a rapporté » (`chat/group/group_revenue_card.dart`) pour le propriétaire, visible au-delà de 1 pièce, calculée depuis `TransactionSoldes` (`purchaseKind=group`). [ ] Vérifier l'accès en lecture aux transactions (règles Firestore) et l'index.

### 29/09 — Pièces du post (vidéos)
- Portrait (`post_video_format_tel_details.dart`) : la pastille était figée car les mises à jour temps réel ne touchaient que `_videoPosts`, alors que la page lit `_feedItems` → corrigé ; le tap était bloqué par la zone des commentaires en direct (`IgnorePointer` ajouté).
- Paysage (`postDetailsVideo.dart`) : `_postSubscription` n'était jamais branchée → abonnement temps réel ajouté ; le bandeau ouvre déjà le détail au tap.

### 29/09 — Images de canal (403)
`lib/widgets/safe_network_avatar.dart` (`SafeNetworkAvatar`, `SafeNetworkCover`) : repli sans exception si le lien est vide/périmé. Appliqué à `canaux/detailsCanal.dart` (couverture, avatar, propriétaire). Étendu à : listCanal, listCanauxByUser, canal_manage_admins, avatars du feed vidéo (youTube card, portrait) et vibes. [ ] Fait aussi en masse : ~100 `CircleAvatar` avec `NetworkImage` (profils, commentaires, chats…) reçoivent `onBackgroundImageError` (silencieux). Restent : `Image.network` sans `errorBuilder` et `DecorationImage` ailleurs.

### 29/09 — LOT 4 refait (tutoriels avec la vraie page)
Validé par le propriétaire (maquette artifact). Chaque tutoriel = téléphone animé (`TutoPhone`) : maquette de la vraie page → action en lumière (halo, doigt, bulle) → gain qui tombe → « ce que le créateur peut gagner » (exemple indicatif) → bouton d'action. Données dans `tutos/tuto_catalog.dart` (`MockEl`), rendu dans `tuto_scene_card.dart`.
- Le « Tutoriel de monétisation » d'origine (`MonetizationTutorialPage`, carte « Le savais-tu ? ») est le créneau 0 du cycle, dans les feeds et avant la connexion.
- Feeds : jusqu'à 5 tutoriels DIFFÉRENTS par jour (quota global `TutoRotation.dailyQuota`), un tous les 5 posts (accueil, sport) + 1 dans le feed vidéo. Avant login : 1 tutoriel tous les 2 jours.
- Boutons « Voir plus de tutoriels » sur chaque carte (`TutoListPage`) + entrée dans le menu + module admin.
- Traductions des nouveaux textes ajoutées (7 langues).
- [ ] À tester sur téléphone : rendu de la maquette (hauteur 470 px dans le feed vidéo plein écran, échelle 0.8), timings, boutons d'action.
- [ ] Les chiffres d'exemple (3 200 likes, 50 abonnés à 300 pièces, 40 entrées à 250 pièces…) sont indicatifs : à valider.

### 29/09 — Tutoriels en mode clair ET sombre
Cartes (`TutoSceneCard`), maquette (`TutoPhone`), liste (`TutoListPage`), pages `TutoScenePage`/`TutoBeforeLoginPage` et carte « Le savais-tu ? » du feed utilisent `AppColors.of(context)` (fonds, textes, bordures) ; l'or vif en sombre devient un ambre plus foncé en clair (`_goldOn`) pour rester lisible. Non modifié volontairement : la page plein écran « Tutoriel de monétisation » d'origine reste cinématique (fond noir dans les deux modes).
- [ ] À vérifier visuellement en mode clair (contrastes de la maquette, doigt, bulle dorée).

### 29/09 — Écrans plus fidèles + plus de pourcentages
- `tutos/tuto_layouts.dart` : reproductions plus proches des vraies pages — **live** (hôte, compteurs, messages et cadeaux, solde Dépôt/Gagnées, cadeaux rapides, barre « Envoyer un message… », actions), **live privé** (écran d'entrée payante), **commentaires** (en-tête du post, bandeau « Ce post a rapporté… », commentaires avec ❤ / Répondre / réponses / 🎁 cadeau, barre de saisie), **détails de post** (média, bandeau, stats). Scènes likes/cadeaux/commentaires/lives/live privé (nouvelle scène) les utilisent.
- Les tutoriels ne parlent plus de pourcentages (70 %, 2,5 %…) : uniquement des montants en pièces d'exemple.
- [ ] Autres scènes (groupes, canal, DÉFI, retrait, boost, parrainage, contenu payant) encore en maquette d'éléments : à rapprocher des vraies pages avec des captures.

### 29/09 — Migration des pseudos (format « prenom.nom »)
- Règle : `lib/utils/pseudo_format.dart` (`normalizePseudo`, `PseudoInputFormatter`) = même règle que `functions/src/users/pseudoMigration.ts` : minuscules, espaces/`_`/`-` → `.`, accents retirés, seuls a-z 0-9 `.`.
- Appliquée à l'inscription (`signup_form.dart`, 2 formulaires) et à la modification du pseudo (`profile_page.dart`), y compris la vérification d'unicité (forme normalisée + ancienne forme).
- Migration : fonction `migratePseudos` (admin) — simulation par défaut (`dryRun: true`), par lots (`cursor`). **PAS ENCORE EXÉCUTÉE** : à déployer puis lancer par le propriétaire (sauvegarde Firestore avant). Doublons → suffixe numérique.
- Longueur : 3 à 20 caractères (`kPseudoMinLength`/`kPseudoMaxLength`), appliquée à la saisie ; la migration ne raccourcit PAS les anciens pseudos trop longs (listés dans le rapport). Script à lancer par le propriétaire : `node functions/scripts/migrate_pseudos.js` (simulation) puis `--apply`.
- [ ] Non couvert : @mentions déjà écrites dans d'anciens posts/commentaires, liens d'invitation contenant l'ancien pseudo, recherches/affichages qui comparent l'ancien pseudo (Chat, Nom des canaux admins…), autres copies du pseudo (commentaires, notifications, chats).

### 29/09 — Pseudos : capsule (option C) + migration depuis l'admin
- `lib/widgets/pseudo_tag.dart` (`PseudoTag`) : capsule avec @ dans un médaillon doré, points du pseudo en or, thème clair/sombre, capsule translucide sur texte clair (vidéo/live). Branché : `TextCustomerUserTitle` / `TextCustomerPostDescription` (tout texte « @xxx ») + 55 `Text('@${…}')` convertis automatiquement (47 fichiers).
- Restent en texte simple : pseudos passés en `name:`/`appName:` à des widgets tiers, notifications, `TextSpan`, `.toLowerCase()`, textes avec autres arguments (`softWrap`…).
- Admin : carte « Pseudos » (`admin/pseudo_migration_page.dart`) : simuler → lancer (confirmation) → verrouillée une fois terminée (`AppConfig/pseudoMigration`, contrôlé par la fonction `migratePseudos`). **À déployer** (`firebase deploy --only functions:migratePseudos`) puis sauvegarder Firestore avant de lancer.
- [ ] Collection `Pseudo` conservée (nécessaire à l'inscription : `Users` illisible sans connexion). À revoir : id du document = pseudo pour l'unicité atomique et éviter de lire toute la collection.

### 29/09 — Canaux : badge carré (option B) + migration
- `lib/widgets/canal_tag.dart` (`CanalTag`) : badge à coins carrés, # dans un carré vert, points verts (distinct de la capsule ronde dorée des pseudos). `NameTag` choisit # → canal, @ → pseudo. Branché : `TextCustomer*` + 20 `Text(...)` (14 fichiers).
- Règle des noms de canaux : mêmes règles que les pseudos, 3 à 30 caractères (`kCanalMaxLength`), appliquée à la création (`newCanal.dart`) et à la modification (`editCanal.dart`, avec test d'unicité et mise à jour de `CanalNames`).
- Migration : fonction `migrateCanalNames` (même moteur que les pseudos, statut `AppConfig/canalMigration`, exécution unique), carte admin « Noms de canaux ». **À déployer** (`firebase deploy --only functions:migrateCanalNames,functions:migratePseudos`) puis sauvegarder Firestore.
- [ ] Restent en texte simple : noms de canaux tronqués (`substring(...)`), notifications, `name:`/`appName:` passés à des widgets tiers.

### 29/09 — Noms propres : emojis interdits, aperçu en direct, remplacement des anciens
- Emojis et tout caractère hors a-z 0-9 . déjà bloqués à la saisie (formatter) et à la collée ; ajout de `NamePreview` (aperçu du rendu final capsule/badge + compteur x/20 ou x/30) sous les champs : inscription (2 formulaires), modification du pseudo (profil), création et modification de canal.
- Migration : un pseudo/nom composé seulement d'emojis ou symboles reçoit un nom de remplacement (prénom.nom, sinon début d'e-mail, sinon `afro1234` / `canal1234`), signalé « remplacé » dans la simulation.
- Non appliqué : pseudos des profils Afrolove (dating), qui ont leur propre formulaire.

### 29/09 — Migration : traitement des emojis
Serveur (`pseudoMigration.ts`) : normalisation NFKD (lettres stylisées 𝓞, pleine largeur Ｏ et accents → lettres simples), puis suppression de tout ce qui n'est pas a-z 0-9 . ; nom vide/trop court après nettoyage (emojis seuls, alphabets non latins) → nom de remplacement (`prenom.nom` / e-mail / `afro1234`, `canal1234`). La simulation compte « avec emoji » et « entièrement remplacés ». Côté app (saisie), le nettoyage des lettres stylisées reste plus simple (supprimées) : écart mineur.

### 29/09 — Mes amis, Services & Jobs, likes de service
- Mes amis (`amis/mesAmis.dart`) : lenteur = flux Firestore recréé à chaque rebuild + une lecture d'abonnés par ami (que j'avais ajoutée) → flux créé une fois, dernier résultat gardé en mémoire (affichage immédiat au retour), abonnés lus dans le profil déjà chargé. Pseudo réduit (12), limité à 20 caractères, badge vérifié DEVANT le pseudo (aussi `mesInvitationTable.dart`).
- Services & Jobs (`UserServices/listUserService.dart`) : page en `CustomScrollView` — recherche, pub, filtres et grille défilent ensemble (pull-to-refresh conservé).
- Détails d'un service/job (`detailsUserService.dart`) : couleurs → `AppColors` (clair et sombre).
- Like d'un service : un seul like par utilisateur, une seule fois, par transaction (compteur recalculé depuis la liste `usersLikeId`) ; cœur plein si déjà aimé.

### 29/09 — Commentaires : pièces reçues + chargement du cadeau
- Le serveur cumule les pièces reçues par un commentaire (`coinsEarned`) ou une réponse (`replyCoins.<id>`) à chaque like payé et chaque cadeau ; l'app les affiche sous le texte (« 🪙 N pièces reçues »). Champs en lecture seule côté client (non réécrits par `updateComment`). **Redéployer** `sendCommentLike` et `sendCommentGift`.
- Feuille de cadeau : voile + roue + « Envoi du cadeau en cours… » pendant l'envoi.

### 29/09 — Canaux inactifs (blocage à 20 jours, déblocage payant)
- Serveur `functions/src/posts/canalInactivity.ts` : `onCanalPostCreated` (met `lastPostAt`, supprime toute publication sur un canal bloqué), `checkInactiveCanals` (quotidien 03:00 UTC : rappel à 15 j, blocage à 20 j, notification au propriétaire ; canaux existants : dernière publication retrouvée une seule fois, 200 max/jour), `unlockCanal` (propriétaire, paie 500 / 1 500 / 2 000 / 3 000 pièces selon <100 / <2 000 / <3 000 / ≥3 000 abonnés), `canalUnlockQuote`. **À déployer.**
- App : bandeau « Canal bloqué » + bouton « Débloquer · N pièces » (`detailsCanal.dart`), bouton Publier masqué et `UserPostForm` refusé si bloqué. Règles & Confidentialité mises à jour.
- [ ] Non fait : masquer les posts/canaux bloqués des feeds et suggestions ; tester le premier passage sur les canaux existants (surveiller le nombre de blocages).

## Inactivité des comptes (20 jours)
- Serveur : `accountPublishStatus`, `unlockAccount`, `onPostCreatedInactivity`, `onCanalCreatedCheckAccount`, `onGroupCreatedCheckAccount`, `onLiveCreatedCheckAccount` (canalInactivity.ts).
- Client : `lib/services/account_gate.dart` branché sur post, canal, groupe, live.
- Exemptés : admins et comptes n'ayant jamais publié. À déployer par l'utilisateur.

### 30/09 — Canaux et groupes : premier gratuit, suivants 500 pièces
- Serveur : `functions/src/payments/creationFees.ts` (`creationQuote`, `onCanalCreatedCharge`, `onGroupCreatedCharge`) et `payWithCoins` (kinds `canal_create`, `group_create`, +1 ticket `canalCreationCredits` / `groupCreationCredits`). Les administrateurs ne paient pas.
- App : `lib/services/creation_fee.dart` appelé dans `newCanal.dart` et `create_group_page.dart` (l'ancienne limite Premium de 2 groupes est remplacée).
- Règles Firestore : les 3 champs `canalCreationCredits`, `groupCreationCredits`, `lastPostAt` ne sont plus modifiables par l'app.
- Inactivité : dernière publication retrouvée avec les index existants (sans limite de 500 posts), 5 jours de grâce pour les canaux découverts déjà inactifs, `recheckBlockedCanals` (admin, `{dryRun:true}` pour compter) pour débloquer les canaux bloqués à tort.
- À déployer : functions `creationQuote`, `onCanalCreatedCharge`, `onGroupCreatedCharge`, `payWithCoins`, `checkInactiveCanals`, `onPostCreatedInactivity`, `recheckBlockedCanals`, `accountPublishStatus`, `unlockAccount` + `firebase deploy --only firestore:rules`.
