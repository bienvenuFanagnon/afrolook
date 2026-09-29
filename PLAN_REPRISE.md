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
- [ ] À faire : brancher aussi les listes secondaires (`mesAmis`, `listTopModal`, `detailsOtherUser`, `afrovideo`, `video_details`, `entreprisePost*`, etc.) si l'écart y est vu ; appeler `FollowersCountService.instance.invalidate(userId)` après abonnement/désabonnement.
- [ ] Vérifier si le compteur `abonnes` et la liste `userAbonnesIds` divergent dans Firestore (cause probable de 171 vs 123) et réparer les données.

### Suite LOT 4 (29/09) — V1 livrée
Fichiers : `lib/pages/intro/tutos/tuto_catalog.dart` (12 scènes, `tutoScenesAvailable`), `tuto_scene_card.dart` (`TutoSceneCard`, `TutoRotation`, `TutoListPage`, `TutoScenePage`, `TutoBeforeLoginPage`).
- Feeds : `FeedMonetizationReminder` alterne l'animation « like » (créneau 0) puis les 12 scènes, une nouvelle scène à chaque affichage (1×/jour/feed).
- Avant login : après le tutoriel initial, une scène publique tous les 2 jours (`splashChargement.dart`).
- Textes en français seulement (repli si absent de `tr_tuto.dart`) → [ ] ajouter les 7 langues dans `tr_tuto.dart`.
- [ ] Ajouter « Tous les tutoriels » (`TutoListPage`) au menu.
- [ ] Vérifier sur iOS : scène « contenu payant » masquée ; aucun montant en argent dans les textes.
- [ ] Vérifier chaque `action` (pages ouvertes sans argument requis) et le rendu plein écran (feed vidéo).
- [ ] Valider les textes/chiffres avec le propriétaire (surtout 70 %/30 % groupes, 2 pièces/commentaire, DÉFI).

### Suite LOT 5 (29/09) — nettoyage prudent
Supprimé (code mort, aucune référence) : `getChallengeUsers`, `canJoinChallengesFreely`, clé `page_challenge_mois_active`, `FeedType.challenges`.
Volontairement GARDÉ (compatibilité anciennes données Firestore / catégorie de contenu) : `PostType.CHALLENGE(PARTICIPATION)`, filtres de `mixed_feedvideo_service`, champs `challenge_id`/`votesChallenge`/`challengeMonth` du modèle, catégorie « Challenges » des contenus payants, textes l10n.
- [ ] Reste : décider si l'on supprime aussi ces champs après migration des anciens posts.

### 29/09 — Traductions des 12 scènes faites (7 langues, `tr_tuto.dart`). Page admin : module « Tutoriels » (`TutoListPage(showAll: true)`) liste toutes les scènes avec étiquettes (avant connexion / masquée iOS).
- [ ] Reste : entrée « Tous les tutoriels » dans le menu utilisateur.
