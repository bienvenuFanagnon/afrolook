# SUIVI REFONTE UI — AFROLOOK V2
_Dernière mise à jour : 24 juin 2026 (session 83)_

---

## CONTEXTE DU PROJET

**Afrolook** est un réseau social Flutter (Android/iOS) connecté à Firebase.  
L'application s'appelle aussi "afrotok" en interne.

**Demande principale :**  
Refaire le design UI avec 2 modes (clair / sombre) basculables par l'utilisateur.  
On n'améliore **pas** les modèles de données — uniquement les pages, widgets, affichage des posts (images, vidéos), et les performances de chargement.

**Règle de travail :**  
Chaque modification doit être **proposée et validée** par le propriétaire avant d'être appliquée.  
Tout est fait en **français**.

---

## ARCHITECTURE DU THÈME (déjà en place)

| Fichier | Rôle | Statut |
|---|---|---|
| `lib/theme/app_colors.dart` | Palette sémantique claire/sombre via `AppColors.of(context)` | ✅ Créé (non commité) |
| `lib/theme/app_theme.dart` | ThemeData light + dark (Material3, police Nunito) | ✅ Créé (non commité) |
| `lib/theme/theme_provider.dart` | ChangeNotifier + persistence SharedPreferences | ✅ Créé (non commité) |
| `lib/main.dart` | ThemeProvider + Consumer + AppTheme.light/dark | ✅ Intégré |

### Palette de couleurs

**Mode clair :**
- Background : `#FAFAF8`
- Surface : `#FFFFFF`
- Primaire (vert) : `#1FAA59`
- Accent (jaune) : `#FFD400`
- Texte : `#121212`

**Mode sombre :**
- Background : `#0E0E0E`
- Surface : `#1A1A1A`
- Primaire (vert) : `#2ECC71`
- Accent (jaune) : `#FFE14D`
- Texte : `#FFFFFF`

---

## ÉTAT DU TRAVAIL — CE QUI A ÉTÉ FAIT

### Pages et widgets déjà adaptés aux 2 modes (utilisent `AppColors.of(context)`)

| Fichier | Notes |
|---|---|
| `lib/pages/canaux/listCanal.dart` | ✅ Session 69 — AppColors + l10n (8 langues), imports dupliqués nettoyés |
| `lib/pages/canaux/listCanauxByUser.dart` | ✅ Session 69 — AppColors + l10n, réécriture complète |
| `lib/pages/canaux/detailsCanal.dart` | ✅ Session 69 — AppColors + l10n, AppBar titre dynamique |
| `lib/pages/canaux/listCanalfollowers.dart` | ✅ Session 69 — AppColors + l10n, pagination conservée |
| `lib/pages/canaux/canalPostNew.dart` | ✅ Session 69 — AppColors + l10n |
| `lib/pages/canaux/newCanal.dart` | ✅ Session 69 — AppColors + l10n, fix `_buildPrivacyOption` (bool isPrivateOption) |
| `lib/pages/canaux/editCanal.dart` | ✅ Session 69 — AppColors + l10n, imports dupliqués nettoyés |
| `lib/pages/canaux/canal_manage_admins.dart` | ✅ Session 69 — AppColors + l10n, l10n clés admin/membre/poster |
| `lib/pages/contenuPayant/contentDetails.dart` | ✅ Session 59 — 63 couleurs hardcodées migrées vers AppColors |
| `lib/pages/contenuPayant/contentDetailsEbook.dart` | ✅ Session 68 — AppColors complet, consts supprimées |
| `lib/pages/contenuPayant/contentForm.dart` | ✅ Session 68 — AppColors complet, const SnackBar corrigés |
| `lib/pages/contenuPayant/contentSerie.dart` | ✅ Session 68 — AppColors + helper `_typeColor()` VIDEO/EBOOK |
| `lib/pages/contenuPayant/ebookPadReader.dart` | ✅ Session 68 — AppColors, imports dupliqués nettoyés |
| `lib/pages/contenuPayant/seriesDetailScreenContenu.dart` | ✅ Session 68 — AppColors |
| `lib/pages/contenuPayant/TableauDeBord.dart` | ✅ Session 68 — AppColors, 3 blocs imports → 1, CategoryContentScreen + SearchDelegate |
| `lib/pages/contenuPayant/userAbonnerInfos.dart` | ✅ Session 68 — AppColors |
| `lib/pages/LiveAgora/livePage.dart` | ✅ R2 session 59-60 — suppression système encaissement, stats fin de live |
| `lib/pages/home/homeScreen.dart` | Page principale — déjà importé AppColors + ThemeProvider |
| `lib/pages/home/HomeConstPost.dart` | Feed principal — AppColors + toggle thème dans UI |
| `lib/pages/home/listTopModal.dart` | Modal liste top — AppColors |
| `lib/pages/home/HomePostType.dart` | Feed par type (Looks/Sport/etc.) — AppColors |
| `lib/pages/home/users_cards/card_exemple.dart` | Carte utilisateur — AppColors |
| `lib/pages/home/users_cards/allUsersCard.dart` | Liste utilisateurs — AppColors |
| `lib/pages/home/users_cards/videoCard.dart` | Carte vidéo — AppColors |
| `lib/pages/home/unitePostPage/chronique_section.dart` | Section chronique — AppColors |
| `lib/pages/userPosts/postWidgets/postWidgetPage.dart` | Widget post principal — AppColors (partiellement) |
| `lib/pages/userPosts/youTube_video_card.dart` | Card vidéo YouTube-style — AppColors |
| `lib/pages/postDetailsVideo.dart` | Détail post vidéo — AppColors |
| `lib/pages/post_video_format_tel_details.dart` | Format vidéo téléphone — AppColors |

---

## CE QUI RESTE À FAIRE

### PRIORITÉ 1 — Pages principales (fort impact visuel)

| Fichier | Problème | À faire |
|---|---|---|
| `lib/pages/userPosts/postWidgets/postWidgetPage.dart` | Encore des constantes `_twitterDarkBg`, `_twitterCardBg` hardcodées | Remplacer par AppColors |
| `lib/pages/postDetails.dart` | Couleurs hardcodées | Adapter aux 2 modes |
| `lib/pages/splashChargement.dart` | Couleurs hardcodées | Adapter aux 2 modes |
| `lib/pages/auth/authTest/Screens/Login/loginPageUser.dart` | Couleurs hardcodées | Adapter aux 2 modes |
| `lib/pages/userPosts/userPostForm.dart` | Formulaire publication | Adapter aux 2 modes |

### PRIORITÉ 2 — Profil et social

| Fichier | Statut |
|---|---|
| `lib/pages/user/profile/userProfileDetails.dart` | ✅ FAIT |
| `lib/pages/user/profile/profileTabsBar/tabBar.dart` | ✅ FAIT |
| `lib/pages/user/profile/profileDetail/page/profile_page.dart` | ✅ FAIT (session 2) |
| `lib/pages/user/amis/ami.dart` | ✅ FAIT (bug corrigé session 3) |
| `lib/pages/user/amis/pageMesInvitations.dart` | ✅ FAIT |

### PRIORITÉ 3 — Chat et notifications

| Fichier | Statut |
|---|---|
| `lib/pages/chat/myChat.dart` | ✅ FAIT |
| `lib/pages/mes_notifications.dart` | ✅ FAIT |
| `lib/pages/user/conversation/listUserConv.dart` | ✅ FAIT (session 2) |

### PRIORITÉ 4 — Autres écrans

| Fichier | À faire |
|---|---|
| `lib/pages/socialVideos/afrovideos/afrovideo.dart` | Adapter aux 2 modes |
| `lib/pages/socialVideos/video_details.dart` | Adapter aux 2 modes |
| `lib/pages/vibe/vibesPage.dart` | Adapter aux 2 modes |
| `lib/pages/challengeMonth/challenge_month_post_card.dart` | Adapter aux 2 modes |
| `lib/pages/userPosts/postTabs/userPostVideoTab.dart` | Vérifier/finaliser |

### PRIORITÉ 5 — Performances chargement des posts

| Amélioration | Statut |
|---|---|
| `cached_network_image` pour les images | Déjà utilisé dans certains fichiers |
| `skeletonizer` pour les placeholders | Déjà utilisé partiellement |
| Pagination Firestore (limit + startAfter) | À vérifier et optimiser |
| Preloading vidéos hors écran | À implémenter |
| Compression/resize images avant upload | À vérifier |
| Cache CDN Cloudflare | Commit "cdn cloudflare" — déjà fait côté backend |
| **Cache-first au démarrage (session 70)** | ✅ FAIT — `StartupCacheService` + splash instantané |
| **Centralisation feed — Phase 1 (session 71)** | ✅ FAIT — `FeedRepository` + `FeedProvider` créés |
| **Centralisation feed — Phase 2 (session 71)** | ✅ FAIT — `PostRenderer` + `FeedList` créés |
| **Centralisation feed — Phase 3 (session 71)** | ✅ FAIT — `UnifiedFeedPage` + onglets Sport/Vibes + preload splash |
| **Centralisation feed — Phase 4 (session 71 suite)** | ✅ FAIT — widgets `_build*` extraits en 6 composants partagés (`lib/widgets/feed/sections/`) + `FeedRepository` câblé dans `HomeConstPost`, `homeSportPost`, `PostDetailsVideoFormatTel` |
| **Unification score (session 74)** | ✅ FAIT — `FeedScoringService.calculateEngagementScore()` public, `_computeScore` ne double-compte plus la fraîcheur |
| **Requêtes Firestore parallèles (session 74)** | ✅ FAIT — `fetchFeed` FeedType.home passe de 5 awaits séquentiels à `Future.wait()` (dédup post-collection) |
| **AppColors postWidgetPage (session 74)** | ✅ FAIT — 8 constantes hardcodées supprimées, badge événement + badge pays + dialog pièces migrés vers AppColors |

---

## WIDGET TOGGLE THÈME

✅ Déjà implémenté (session antérieure).

---

## MÉTHODE DE TRAVAIL

1. **Proposition** : L'agent propose les modifications pour un fichier
2. **Validation** : Le propriétaire valide ou demande des ajustements
3. **Application** : L'agent applique uniquement ce qui est validé
4. **Mise à jour** de ce fichier SUIVI_REFONTE.md après chaque modification

---

## NOTES TECHNIQUES IMPORTANTES

- **Ne pas modifier les modèles de données** (lib/models/)
- **Ne pas modifier les providers** (lib/providers/) sauf si lié au thème
- Utiliser `AppColors.of(context)` pour toutes les couleurs UI
- Utiliser `Theme.of(context)` pour les textstyles
- Le projet utilise **Material3** (`useMaterial3: true`)
- Police : **Nunito**
- Le projet cible Android et iOS (pas Web en priorité)

---

## HISTORIQUE DES SESSIONS

### Session 70 (21 juin 2026)
- **Architecture cache-first au démarrage (lancement instantané)**
- `lib/services/cache/startup_cache_service.dart` créé :
  - Cache `UserData` (TTL 24h) + `AppDefaultData` (TTL 6h) dans SharedPreferences
  - Sérialisation/désérialisation manuelle incluant `countryData` (absent du `toJson()` natif)
  - `clear()` intégré dans `SessionUserFirebaseService.clearSession()` → cache vidé à la déconnexion
- `lib/pages/splashChargement.dart` :
  - `_handleAuthenticatedUserById` : cache-first — si cache valide → populate providers → navigate IMMÉDIATEMENT
  - Background refresh silencieux via `_backgroundRefresh()` (`Future.microtask`) après navigation
  - Cache miss → chemin Firestore classique + sauvegarde cache avec `unawaited`
- `lib/services/sessions/session_service.dart` : `clearSession()` appelle `StartupCacheService.clear()`
- Résultat : 2e lancement et suivants = **0ms de Firestore** avant affichage du Home
- 0 erreur `dart analyze`

### Session 71 (21 juin 2026)
- **Centralisation feed — Phase 1 : infrastructure centrale**
- `lib/services/feed/feed_repository.dart` créé :
  - `enum FeedType { home, looks, sport, events, video, vibes, challenges }`
  - Composition algorithmique home : 30% abo + 25% pays + 20% score + 15% découverte + 10% résurgence
  - Score composite : engagement×0.35 + fraîcheur×0.25 + pays×0.20 + boost_nouveau_créateur×0.15 + viralité×0.05
  - Boost nouveau créateur : `abonnes < 200` ET post < 30 jours → +0.15
  - Filtrage pays client-side : deux requêtes (`available_countries` contains countryCode + 'ALL'), merge
  - Résurgence : posts 2-6 mois avec feedScore ≥ 0.5
  - Fault-tolerant : chaque méthode a try/catch, retourne `[]` en cas d'erreur
  - `fetchChroniques/fetchCanaux/fetchArticles` : contenu global partagé
- `lib/providers/feed_provider.dart` créé :
  - `FeedState` immuable par `FeedType` (posts, mixedContent, isLoading, hasMore, isFromCache)
  - `Set<String> _globalSeenIds` : déduplication globale inter-feeds
  - Cache-first (TTL 30min via `FeedCacheService`) + background refresh silencieux
  - `loadGlobalContent()` : charge chroniques/canaux/articles en parallèle (une seule fois)
  - `preload(FeedType)` : préchargement en arrière-plan sans bloquer l'UI
  - `_buildMixed()` : contenu mixé standard pour feed home
- `lib/main.dart` : `FeedProvider` enregistré dans `MultiProvider`
- Aucune page existante modifiée — migration progressive possible
- 0 erreur `dart analyze` (11 infos avoid_print pré-existants)

### Session 71 suite — Phase 2 : widgets universels
- `lib/widgets/feed/post_renderer.dart` créé :
  - Dispatch par `post.type` + `post.dataType` : CHALLENGEPARTICIPATION → `LookChallengePostWidget`, VIDEO → `YouTubeVideoCard`, AUDIO → `AudioPostCard`, PRONOSTIC → invisible, défaut → `HomePostUsersWidget`
  - Transmet `filterCountry` et `index` aux widgets existants (pas de refactor)
- `lib/widgets/feed/feed_list.dart` créé :
  - Rendu de `List<dynamic>` (mixedContent de FeedProvider)
  - Pagination auto : détecte scroll à 85% → déclenche `onLoadMore`
  - Sections avec builders optionnels : `chroniqueBuilder`, `canauxBuilder`, `articlesBuilder` (les pages injectent leurs propres renderers le temps de la migration)
  - Fallback minimal pour chroniques (rangée d'avatars circulaires)
  - Footer dynamique : spinner si chargement, "Fin du feed" si hasMore=false
- 0 erreur `dart analyze`

### Session 71 suite — Phase 4 : extraction widgets + intégration FeedRepository
- **6 composants partagés créés** dans `lib/widgets/feed/sections/` :
  - `feed_articles_section.dart` : `FeedArticlesSection` (produits boostés horizontaux)
  - `feed_canaux_section.dart` : `FeedCanauxSection` (canaux horizontaux)
  - `feed_profiles_section.dart` : `FeedProfilesSection` + `_ProfileCard` (profils suggérés)
  - `feed_ad_widgets.dart` : `FeedAdBanner`, `FeedAdMrec`, `FeedAdCarousel`
  - `feed_filter_bar.dart` : `FeedFilterBar` + `FeedFilterChip` (filtres pays)
  - `feed_state_widgets.dart` : `FeedSectionLoader`, `FeedLoadingShimmer`, `FeedErrorWidget`, `FeedEmptyWidget`
- **`HomeConstPost.dart`** : tous les `_build*` remplacés par délégations aux 6 composants ; méthodes de chargement remplacées par `FeedRepository` ; variables cursor (`_lastAllDocument`, `_lastCountryDocument`, `_lastOtherDocument`) supprimées ; code mort `_loadCountrySpecificPosts2` supprimé ; cas EVENEMENT conservé en Firestore direct (tri par `eventDate`)
- **`homeSportPost.dart`** : même traitement — `_loadPostsWithTypeAndCountry` et `_loadChroniquesInBackground` remplacés par `FeedRepository` ; cursors supprimés ; helper `_addFetchedToList` ajouté
- **`PostDetailsVideoFormatTel`** : stratégie 1 de `_fetchSuggestedVideosBatch` remplacée par `FeedRepository().fetchByMediaType()` avec fallback Firestore direct si résultat vide
- 0 erreur `flutter analyze`

### Session 72 — Pubs au format post standard

**Objectif** : Les posts sponsorisés s'affichent avec le même format visuel que les posts ordinaires (`HomePostUsersWidget`), plus 3 éléments distinctifs : badge "SPONSORISÉ", bouton CTA, stats (vues + CTR).

**Fichiers modifiés** :
- `lib/pages/admin/AfrolookPub/advertisementPostImageWidget.dart` :
  - Supprimé : tous les builders d'images (`_buildImageGrid`, `_buildSingleImage`, etc.), `_buildVideoContent`, `_buildHeaderCompact`, `_loadUserData`, `_loadCanalData`, `_calculatePostHeight`, `_navigateToDetails`, variables user/canal
  - Ajouté import `HomePostUsersWidget`
  - Nouveau `build()` : `Stack(HomePostUsersWidget + badge Positioned top-right) + _buildAdExtras()`
  - Conservé : `_handleVisibilityChanged`, `_recordAdView`, `_handleActionButtonClick`, `_formatCount`
- `lib/pages/admin/AfrolookPub/advertisement_video_widget.dart` :
  - Même refactoring que l'image widget
  - Supprimé : `VideoPlayerController`, `SoundProvider`, toute la logique vidéo manuelle (gérée par `HomePostUsersWidget` en interne)
  - Badge, CTA, stats identiques

**Résultat** : 0 erreur `flutter analyze`, seulement 4 infos `deprecated_member_use` (withOpacity) pré-existantes dans le projet.

**Format visuel** :
- Pub = post ordinaire à 100% (même dimensions, même header avatar/nom, même zone média)
- Overlay badge "SPONSORISÉ" en haut à droite (semi-transparent, petite police)
- Rangée stats compacte (vues + CTR) + bouton CTA gradient rouge en dessous du post

### Session 83 (24 juin 2026) — Fix largeur bulles chat simple + HomeBootCache + flash permissions groupe

**1. Bulles de texte chat simple — largeur adaptative**
- `lib/widgets/chat/chat_bubble_widget.dart` — `TextBubble` :
  - **Problème** : la `Column` avec `Align(bottomRight, MessageMeta)` forçait la bulle à prendre toute la largeur disponible (jusqu'à `maxWidth: 72%`), même pour 1 ou 2 mots.
  - **Fix** : envelopper le `Container` avec `IntrinsicWidth` + `minWidth: 80` + passer `crossAxisAlignment` de `start` à `stretch` dans la `Column`.
  - Résultat : bulles courtes = largueur du texte, bulles longues = 72% max.

**2. HomeBootCache — pré-chargement splash pour posts instantanés**
- `lib/pages/home/home_boot_cache.dart` créé (singleton) :
  - Clé stable `home_boot_<userId>`, stocke 5 posts + chroniques + 8 profils suggérés.
  - `preload(userId)` appelé dans le splash AVANT navigation, < 20 ms.
  - `save()` appelé après chaque refresh réseau réussi.
  - `Post.toJson()` corrigé : `_tsToMs()` convertit `Timestamp` → `int` (fix sérialisation silencieuse).
- `lib/pages/home/HomeConstPost.dart` : lecture synchrone dans `initState()` (0 setState, 0 shimmer au premier build).
- `lib/pages/splashChargement.dart` : `_navigateToHomeWithDestination()` rendue async + `await HomeBootCache.preload(userId)`.

**3. Flash permissions groupe (group_chat_page.dart)**
- Banners et barre de saisie s'affichaient avec de mauvaises permissions avant `_loadGroup()`.
- Fix : `bool _permissionsLoaded = false` + gate `if (_permissionsLoaded)` sur banners + input.

**4. Sections feed — rien pendant le chargement**
- `feed_profiles_section.dart`, `feed_articles_section.dart`, `feed_canaux_section.dart` :
  - `if (isLoading || data.isEmpty) return SizedBox.shrink()` — plus aucun skeleton pour les sections.

---

### Session 80 (23 juin 2026) — WorkManager : grandes icônes dynamiques + audit Cloud Functions

**Objectif** : Remplacer l'icône statique Flutter dans les notifications locales par des images contextuelles (photo expéditeur, image groupe, image post).

**1. Grande icône dynamique par catégorie (`lib/services/workManagerService.dart`)**
- Nouvelle fonction `_downloadImageBitmap(String? url)` :
  - Télécharge l'image depuis une URL HTTP en fichier temporaire (`getTemporaryDirectory()`)
  - Timeout 5 secondes, fallback silencieux si erreur ou URL vide
  - Retourne `FilePathAndroidBitmap` (bitmap depuis chemin fichier) ou `null`
- `_showCategoryNotification` : nouveau paramètre optionnel `String? imageUrl`
  - Si image téléchargée → `largeIcon: FilePathAndroidBitmap(path)` (photo réelle)
  - Sinon → fallback `DrawableResourceAndroidBitmap('@mipmap/ic_launcher')` (icône app)
- **Mode DEBUG** — `_runDebugNotificationPreview` enrichi :
  - Messages directs → `send_by` → `Users.imageUrl` (photo expéditeur)
  - Groupes ← nouvelle catégorie ajoutée → `GroupChats.image_url` (image du groupe)
  - Notifications dating/app → `media_url` de la notification Firestore
  - Invitations → `sender_id` → `Users.imageUrl` (photo de l'inviteur)
- **Mode PRODUCTION** — `_runNotificationCheck` mis à jour :
  - Chaque `maybeShow` lambda fetche une image contextuelle (requête `limit(1)`) uniquement au moment d'afficher
  - Messages : `send_by` → `Users.imageUrl`
  - Groupes : `GroupChats.image_url`
  - Invitations : `sender_id` → `Users.imageUrl`
  - Dating/App : premier `media_url` des notifications non lues correspondantes

**2. Cloud Functions audit + correctifs**

`functions/src/notifications/bulk.ts` :
- Rate limit 30 min par expéditeur (`lastBulkNotifSentAt` sur doc Users)
- Chaque notification sauvegardée avec : `is_open: false`, `users_id_view: []`, `created_at`, `updated_at`, `createdAt`, `updatedAt` (double snake_case + camelCase pour compatibilité)
- Mise à jour `lastBulkNotifSentAt` après envoi réussi

`functions/src/posts/interactions.ts` :
- Garde anti auto-notification : `if (postOwnerId === userId) return`
- Sauvegarde `NotificationData` dans Firestore **avant** l'envoi email (LIKE/COMMENT/SHARE)
- Champs : `is_open: false`, `users_id_view: []`, `media_url: interactorData.imageUrl`, `post_id`, `post_data_type`, timestamps complets
- Email conditionnel : uniquement si `emailNotifications.interactions !== false`

**3. Architecture WorkManager debug/prod**
- Debug (`!kReleaseMode`) → `registerOneOffTask` avec `Duration.zero` (déclenchement immédiat)
- Production (`kReleaseMode`) → `registerPeriodicTask` 15 min avec `ExistingPeriodicWorkPolicy.keep`
- `isInDebugMode: false` dans les deux cas (évite les logs Workmanager verbeux)

**Résultat** : 0 erreur `flutter analyze`. Notifications affichent maintenant la photo de la personne/groupe à droite (grand cercle), style Facebook/Snapchat.

---

### Session 79 (23 juin 2026) — Système de groupes Gold/Premium + deep links groupes + modals de restriction

**Fonctionnalités implémentées :**

**1. Limites de groupes selon le plan**
- `lib/services/utils/abonnement_utils.dart` : 2 nouvelles méthodes statiques
  - `maxGroupsOwned()` : null = illimité (Gold), 2 (Premium), 0 (gratuit)
  - `maxGroupMembers()` : null = illimité (Gold), 100 (Premium), null (gratuit)
- `lib/pages/chat/group/create_group_page.dart` : vérification du nombre de groupes existants avant création → SnackBar orange si limite atteinte
- `lib/pages/user/conversation/listUserConv.dart` : vérification `maxGroupMembers` de l'owner avant jointure → SnackBar rouge si groupe plein
- `lib/services/linkService.dart` : même vérification dans `_doJoinGroup()` (via dialog)

**2. Page abonnement mise à jour**
- `lib/pages/user/userAbonnementPage.dart` :
  - Refresh automatique du plan après souscription : `refreshUserData()` appelé → plus besoin de relancer l'app
  - Premium : "2 groupes max · 100 membres/groupe"
  - Gold : "Groupes illimités · Membres illimités · Liens externes cliquables dans les messages"

**3. Liens cliquables dans les messages de groupe (Gold)**
- `lib/pages/chat/group/group_chat_page.dart` : toggle `allow_external_links` en Firestore
  - `flutter_linkify` + `url_launcher` : `Linkify` widget à la place de `Text` quand activé
  - Toggle affiché dans `group_info_page.dart` (feature #7 Gold)

**4. Deep link groupe — navigation complète**
- 3 maillons cassés corrigés :
  - `lib/main.dart` `_initDeepLinks()` : ajout du `case 'group'` → `NavigationCacheService().storeGroupNavigation(cleanId)`
  - `lib/pages/splashChargement.dart` : `DestinationData` étendu avec `joinCode`, 2 switch `case 'group'` ajoutés
  - `lib/pages/home/homeScreen.dart` : `case 'group'` dans `_handleInitialDestination()` → `AppLinkService().navigateToGroup()`
- Modal de chargement pendant la résolution du deep link (`CircularProgressIndicator` gold + "Chargement du groupe…")

**5. Infos membres dans group_info_page.dart**
- Compteur "X / 100 MEMBRE(S)" pour propriétaire Premium, "X MEMBRE(S)" sinon
- Icône `Icons.tune_rounded` visible sur chaque tile membre pour ouvrir le gestionnaire de permissions (remplace le long-press invisible)
- Fix `_showEditPriceSheet()` : `async` + `await showModalBottomSheet` + `controller.dispose()` après fermeture → plus de crash TextEditingController
- Fix `_showPermissionsDialog()` : `ConstrainedBox(maxHeight: 70%)` + `Flexible + SingleChildScrollView` → plus de RenderFlex overflow

**6. Modals de restriction dans les groupes**
- `lib/pages/chat/group/group_chat_page.dart` :
  - `_writeBlockReason()` et `_shareBlockReason()` : retournent un named record `({title, message, icon, color})` selon la cause (gelé, readOnly, perm individuelle, perm globale)
  - `_showRestrictionModal()` : dialog avec icône colorée + titre + message + bouton "Compris"
  - Zone de saisie bloquée : `GestureDetector` → ouvre le modal au tap
  - Envoi bloqué (`_sendTextMessage`, `_sendImageMessage`) : modal au lieu de SnackBar silencieux
  - Partage bloqué `_showShareBlockedSnackbar()` : remplacé par modal

**7. PostShareSheet — modal au lieu de SnackBar**
- `lib/widgets/chat/post_share_sheet.dart` : `ScaffoldMessenger.showSnackBar()` (caché derrière le bottom sheet) remplacé par `showDialog()` avec design cohérent (icône bloc/flocon + message + bouton Compris)
  - Groupe gelé : icône `ac_unit_rounded`
  - Partage non autorisé : icône `block_rounded`

**Résultat** : 0 regression — toutes les vérifications centralisées via `AbonnementUtils` et `GroupPermissionUtils`.

---

### Session 78 (22 juin 2026) — Fix double-flash feed au démarrage

**Problème corrigé** : à chaque lancement, l'utilisateur voyait un post s'afficher (cache), puis un flash de loading, puis les posts se réafficher avec un premier post différent du précédent.

**Cause racine** : dans `_loadInitialPosts()`, l'instruction `_posts = newPosts` remplaçait brutalement les posts du cache par les posts réseau — même quand le contenu était identique ou très similaire. Ce remplacement provoquait une rebuild visible de la liste (flash + changement de premier post).

**Fix appliqué** (`lib/pages/home/HomeConstPost.dart`) :
- Si `_posts` est vide (pas de cache) → comportement identique : réseau affiché directement
- Si `_posts` contient déjà le cache → **ne pas remplacer** ; calculer les posts vraiment nouveaux (absents de `_loadedPostIds`) et les **prépendre** silencieusement en tête de liste
- Dans les deux cas, `_saveFeedToCache()` est appelé → le cache est à jour pour le prochain lancement
- L'indicateur `_isLoadingPosts` reste `false` pendant tout le background refresh (protégé par `if (_posts.isEmpty)`)

**Résultat** :
1. Lancement → posts du cache s'affichent instantanément ✅
2. Réseau arrive → si nouveaux posts, prépendés discrètement en haut ✅
3. Si réseau = même contenu que cache → rien ne change à l'écran ✅
4. Le flash et le changement de premier post ont disparu ✅

---

### Session 77 (22 juin 2026) — AppColors : 6 pages de création de posts

**Problème corrigé** : les pages de création de posts utilisaient des `final Color _primaryColor = Color(0xFF...)` hardcodées définies une fois pour toutes — jamais mises à jour avec le thème. Aucun changement visuel n'était perceptible à l'écran.

**Solution** : suppression des constantes hardcodées, ajout de `late AppColors _c` + `didChangeDependencies()` dans chaque page.

**Fichiers migrés** (6 au total) :
- `userPostImageTab.dart` (UserPostLookImageTab) — mapping complet : `_primaryColor` → `_c.primary`, `_secondaryColor` → `_c.accent`, `_backgroundColor` → `_c.background`, `_cardColor` → `_c.surface`, `_textColor` → `_c.textPrimary`, `_hintColor` → `_c.textSecondary`, `_successColor` → `_c.primary` + `Colors.red/green/orange/grey[*]` → `_c.danger/primary/warning/border/surfaceVariant/textSecondary`
- `userPostVideoTab.dart` (UserPubVideo) — même migration complète
- `userPostAudioTab.dart` (UserPostLookAudioTab) — idem (conservé : `_audioColor = Color(0xFF2196F3)` intentionnel)
- `userPostTextTab.dart` (UserPubText) — idem
- `UserPubVibeTab.dart` (UserPubVibe) — idem
- `postLookImageTab.dart` (PostLookImageTab) — idem + migration `ConstColors.backgroundColor` → `_c.background`, `ConstColors.textColors` → `_c.textPrimary`

**Résultat** : 0 erreur `flutter analyze` sur les 6 fichiers. Les pages réagissent maintenant au thème clair/sombre.

---

### Session 76 (22 juin 2026) — AppColors : postWidgetPage.dart + post_video_format_tel_details.dart

**Fichiers migrés** :

`lib/pages/userPosts/postWidgets/postWidgetPage.dart` :
- `_showGiftDialog` entièrement migré : bg dialog → `dc.surface`, bordure → `dc.accent`, titre → `dc.accent`, texte subtitle → `dc.textSecondary`, GridView items (selected bg → `dc.primary`, unselected → `dc.surfaceVariant`, border → `dc.accent`, texte → `dc.textPrimary`), solde → `dc.accent`, Annuler → `dc.textSecondary`, bouton Envoyer bg → `dc.primary`, texte → `dc.onPrimary`
- SnackBar favoris : `Colors.white` → `onPrimary`, `Colors.grey` unfavorited → `surfaceVariant`
- SnackBar erreur modification : `Colors.white` → `onPrimary`
- SnackBar cadeau envoyé (x2) : `Colors.white` → `onPrimary`
- 0 erreur `flutter analyze`

`lib/pages/post_video_format_tel_details.dart` :
- 3 SnackBars `backgroundColor: Colors.green` → `AppColors.of(context).primary` (cadeau x2, partage)
- Overlays vidéo TikTok-style (texte white/black) laissés intentionnellement
- Bouton "+" follow overlay (rouge/blanc) laissé intentionnellement
- 0 erreur `flutter analyze`

---

### Session 75 (22 juin 2026) — Réorganisation Cloud Functions + cooldown post serveur

**Objectif** : Découper `functions/src/index.ts` (3384 lignes) en fichiers domaine distincts. index.ts ne ré-exporte plus que les noms — aucun appel Firebase/Flutter cassé.

**Structure créée** :

`functions/src/shared/` :
- `firebase.ts` — `initializeApp()` + export `db` (une seule initialisation)
- `config.ts` — toutes les constantes (EMAIL_FROM, APP_DOMAIN, PLAY_STORE_URL, FEEXPAY_*, APP_FEE_RATE_AFROLOOK…)
- `deposit_utils.ts` — `formatCinetpayDate`, `generateDepositNumber`, `generateFeexpayTransKeyAfrolook`, `generateDepositNumberAfrolook`, `calculateAppGainAfrolook`
- `notification_utils.ts` — `sendToOneSignal`, `getCanalImage`
- `email_utils.ts` — `emailTransporter`, `checkEmailRateLimit`, `canSendMarketingEmail`, `INACTIVE_USER_EMAIL_TEMPLATE`, `generateEmailHTML`, `generateInteractionEmailHTML`

`functions/src/payments/` :
- `cinetpay.ts` — `initiateAfrolookDeposit`, `afrolookDepositCallback`
- `paygate.ts` — `processAfrolookPaygatePayment`
- `feexpay.ts` — `initiateAfrolookFeexpayPayment`, `executeAfrolookFeexpayPayment`, `afrolookFeexpayWebhook`, `checkAfrolookFeexpayTransactionStatus`

`functions/src/live/` :
- `agora.ts` — `generateAgoraToken`

`functions/src/posts/` :
- `sharing.ts` — `sharePostLink`
- `interactions.ts` — `onPostInteraction`, `onNewPostFromSubscription`
- `lifecycle.ts` — **NOUVELLES FONCTIONS** : `moderatePostLifecycle` (trigger PENDING→VALIDE/NONVALIDE) + `checkPostCooldownServer` (callable cooldown 5 min, vérification serveur anti-fraude)

`functions/src/notifications/` :
- `bulk.ts` — `sendBulkNotification`

`functions/src/emails/` :
- `email_functions.ts` — `sendInactiveUserReminder`, `testAfrolookEmail`, `processInactiveUsersReminder`, `sendBulkEmail`, `testEmail`

`functions/src/index.ts` — réduit à 10 lignes de ré-exports uniquement

**Vérification** : `npm run build` → 0 erreur TypeScript

**Nouvelles fonctions Cloud (`posts/lifecycle.ts`)** :
- `moderatePostLifecycle` : déclenché à chaque création de document `Posts/{postId}` ; si `statut == "PENDING"` → valide `dataType` ∈ [IMAGE, VIDEO, AUDIO, TEXT] → met à jour `statut` (VALIDE ou NONVALIDE) + `moderatedAt`
- `checkPostCooldownServer` : callable authentifié ; cherche le dernier post de l'utilisateur (`user_id == uid`, tri `created_at` desc, timestamps en microseconds Flutter) ; retourne `{ canPost, remainingSeconds }` — cooldown 5 minutes strict côté serveur

**Intégration Flutter du cooldown serveur** :
- `lib/services/postService/post_cooldown_service.dart` créé : `PostCooldownService.check()` → appelle `checkPostCooldownServer`, retourne `({canPost, remainingSeconds})` ; `formatRemaining()` → MM:SS
- Intégré dans 6 tabs de publication (`_publishPost`/`_publishVideo`/`save`) :
  - `userPostImageTab.dart`, `userPostVideoTab.dart`, `userPostAudioTab.dart`
  - `userPostTextTab.dart`, `UserPubVibeTab.dart`, `postLookImageTab.dart`
- Pattern : vérification serveur APRÈS le check local (UX) → SnackBar avec temps restant si bloqué
- 0 erreur `flutter analyze` sur les fichiers modifiés

---

### Session 73 — WorkManager notifications réelles + fix crash chroniques + pub vidéo

**WorkManager — notifications Firestore réelles**
- `lib/services/workManagerService.dart` :
  - Fréquence : `Duration(hours: 3)` → `Duration(minutes: 15)` (minimum Android), policy `replace` pour mise à jour immédiate
  - Supprimé : `_sendAfrolookNotification()` et tous les messages statiques marketing (12 variantes)
  - Ajouté : `_fetchAndShowUserNotifications(userId, prefs)` :
    - Lit l'userId depuis `SharedPreferences['token']` (clé `SessionUserFirebaseService`)
    - Si pas d'userId → skip silencieux (utilisateur non connecté)
    - Requête Firestore `Notifications` : `where('receiver_id', isEqualTo: userId)`, limit 50
    - Filtre client-side : `users_id_view` ne contient pas l'userId + `created_at` < 7 jours + pas dans cache local
    - Tri client-side : plus récentes en premier
    - Affiche max 3 notifications par run
    - Après affichage : `arrayUnion([userId])` sur `users_id_view` Firestore + cache local `wm_shown_notif_ids`
    - Cache local limité à 500 entrées pour éviter croissance infinie
  - Conservé : `sendTestAfrolookNotification()` (tâche manuelle test uniquement)
  - Résultat : 0 message static jamais envoyé — uniquement les vraies notifications Firestore de l'utilisateur

**Fix RangeError crash chroniques (scroll en fin de liste)**
- `lib/pages/chronique/chroniquedetails.dart` :
  - **Cause** : `onPageChanged` appelait `_virtualToChronique(virtualIndex)` même pour les pages pub, retournant `_allChroniques.length` quand la dernière pub suit le dernier item → `setState(() => _currentPage = _allChroniques.length)` → crash `RangeError` à la ligne `_allChroniques[_currentPage]`
  - **Fix 1** : `onPageChanged` ne met à jour `_currentPage` que si `!_isVirtualAd(virtualIndex)` + guard `chroniqueIdx < _allChroniques.length`
  - **Fix 2** : clamp de sécurité `_allChroniques[_currentPage.clamp(0, _allChroniques.length - 1)]` dans `build()`

**Pub vidéo — format YouTubeVideoCard + auto-play muted**
- `lib/pages/admin/AfrolookPub/advertisement_video_widget.dart` — réécrit :
  - Supprimé : `HomePostUsersWidget` (trop générique, sans auto-play)
  - Ajouté : `VideoPlayerController` + `VideoPreloadManager.claimController()` (même mécanisme que le feed)
  - Hauteur vidéo : `(screenWidth * 1.15).clamp(320.0, 500.0)` — identique à `YouTubeVideoCard._buildVideoContent()`
  - **Auto-play muted** dès que `VisibilityDetector` détecte > 50% visible
  - Pause automatique quand le widget sort du viewport
  - Bouton son bas-droite (toggle mute/unmute) identique au style YouTubeVideoCard
  - Badge SPONSORISÉ haut-droite superposé sur la vidéo
  - Miniature (`widget.post.thumbnail`) affichée pendant le chargement
  - Stats (vues + CTR) + bouton CTA gradient rouge conservés en dessous
  - Container design identique à YouTubeVideoCard (même `borderRadius: 16`, `border: colors.border`)
  - 0 erreur `flutter analyze`

### Session 71 suite — Phase 3 : UnifiedFeedPage + preload splash
- **Approche révisée** : `HomeConstPost.dart` (4000+ lignes, pagination par curseurs, timers, ads) trop complexe pour migration directe — les onglets Sport/Vibes étaient `SizedBox.shrink()` → cibles idéales
- `lib/pages/feed/unified_feed_page.dart` créé :
  - Prend `FeedType feedType` en paramètre
  - `Consumer<FeedProvider>` → `FeedList` → `PostRenderer` (stack complet Phase 1-2-3)
  - Pull-to-refresh, shimmer skeleton, état vide et erreur avec retry
  - `AutomaticKeepAliveClientMixin` : state conservé entre onglets
  - Expose `refreshFeed()` pour compatibilité avec le mécanisme `GlobalKey` de `homeScreen.dart`
- `lib/pages/home/homeScreen.dart` :
  - Tab 1 (`tabSport`) : `SizedBox.shrink()` → `UnifiedFeedPage(FeedType.sport)`
  - Tab 2 (`tabVibe`) : `SizedBox.shrink()` → `UnifiedFeedPage(FeedType.vibes)`
  - Tab 4 (`tabVip`) : reste `SizedBox.shrink()` (contenu premium à définir)
  - Import `feed_repository.dart show FeedType` + `unified_feed_page.dart`
- `lib/pages/splashChargement.dart` — `_backgroundRefresh()` étendu :
  - `feedProvider.loadGlobalContent()` → chroniques + canaux + articles chargés pendant le splash
  - `feedProvider.preload(FeedType.home/sport/vibes, ...)` → données disponibles avant HomeScreen
  - Bénéfice : l'utilisateur voit les onglets Sport et Vibes instantanément dès la 1ère ouverture
- 0 erreur `dart analyze`

---

### Session 69 (21 juin 2026)
- **AppColors + AppLocalizations (8 langues) appliqués aux 8 pages canaux**
- `app_localizations.dart` : ~60 nouvelles clés canal (canalExplore, canalSearch, canalCreate, canalEdit, canalAdminList, etc.)
- `listCanal.dart`, `listCanauxByUser.dart`, `detailsCanal.dart`, `listCanalfollowers.dart`, `canalPostNew.dart` : AppColors + l10n
- `newCanal.dart` : fix logique `_buildPrivacyOption` (comparaison `title == 'Privé'` → paramètre `bool isPrivateOption`)
- `editCanal.dart` : AppColors + l10n, imports dupliqués nettoyés
- `canal_manage_admins.dart` : AppColors + l10n (rôles admin/membre/propriétaire, permissions poster)
- 0 erreur `dart analyze` sur les 8 fichiers

---

### Session 1 (agent précédent — date inconnue)
- Création du système de thème complet (`lib/theme/`)
- Intégration dans `main.dart`
- Adaptation des pages home et feed principal
- Gros travail sur `userPostVideoTab.dart`, `postWidgetPage.dart`, `youTube_video_card.dart`

### Session 2 (12 juin 2026 — agent actuel)
- Analyse complète du projet
- Création de ce fichier SUIVI_REFONTE.md

**P1 — Navigation top style Facebook ✅ FAIT**
- `lib/pages/home/homeScreen.dart` — AppBar remplacé par un `PreferredSize` à 2 lignes :
  - Ligne 1 : Logo + [Invitations, Messages, +Créer, Vidéos, Lives] + [🔔, dating, boutique, 🌙]
  - Ligne 2 : TabBar existant (onglets de filtres)
  - Icônes réduites (22px nav, 20px actions)
- `bottomNavigationBar` supprimé (remplacé par `SizedBox.shrink()`, ancien code commenté)
- Méthode helper `_navItem(...)` ajoutée pour les icônes avec badge

**P2 — Thème sur widgets du feed ✅ FAIT + BUGS CORRIGÉS**
- `lib/pages/admin/AfrolookPub/advertisementCarouselWidget.dart` — AppColors intégré, couleurs hardcodées remplacées
- `lib/pages/admin/AfrolookPub/advertisementPostImageWidget.dart` — `late AppColors _colors` champ de classe, `static const _primaryColor`, sous-méthodes corrigées
- `lib/pages/pronostics/pronostics_carousel_widget.dart` — `late AppColors _colors` champ de classe, `static const _primaryColor`, sous-méthodes corrigées
- `lib/pages/admin/AfrolookPub/advertisement_video_widget.dart` — `late AppColors _colors` champ de classe, `_buildHeaderCompact()` corrigée
- `lib/pages/contenuPayant/recent_vip_content_widget.dart` — AppColors intégré, Colors.black/grey remplacés
- `lib/pages/dating/widgets/top_dating_profiles_widget.dart` — AppColors intégré, Colors.white/black remplacés
- `lib/pages/home/HomeConstPost.dart` — indicateurs de chargement + section profils + _buildProfileCard adaptés

**BUG CORRIGÉ (session 2)** — Les variables couleur (`_secondaryColor`, `_cardColor`, `_textColor`, `_hintColor`) étaient définies comme locales dans `build()` mais utilisées dans des sous-méthodes (ex: `_buildCarouselItem`, `_buildHeaderCompact`, `_buildSingleImage`). Correction : ajout de `late AppColors _colors` en champ de classe, initialisé dans `build()`, et référencé via `_colors.accent`, `_colors.surfaceVariant`, etc. dans toutes les méthodes.

**P4 — Thème page détail post ✅ FAIT**
- `lib/pages/postDetails.dart` — `late AppColors _colors` ajouté dans `_DetailsPostState`
- Toutes les constantes twitter/afro remplacées :
  - `_twitterDarkBg`, `_afroBlack` → `_colors.background`
  - `_twitterCardBg`, `_afroDarkGrey` → `_colors.surfaceVariant`
  - `_twitterTextPrimary` → `_colors.textPrimary`
  - `_twitterTextSecondary`, `_afroLightGrey` → `_colors.textSecondary`
  - `_twitterGreen`, `_afroGreen` → `_colors.primary`
  - `_twitterYellow`, `_afroYellow` → `_colors.accent`
  - `_afroRed` → `_colors.danger`
  - Conservés intentionnellement : `_twitterBlue` (bleu info), `_twitterRed` (rouge social)

**P5 — Thème page splash ✅ FAIT**
- `lib/pages/splashChargement.dart` — import `app_colors.dart` + `late AppColors _colors`
- `_buildLoadingScreen`, `_buildLoadingStatus`, état d'erreur adaptés au thème

**P6 — Thème page login ✅ FAIT**
- `lib/pages/auth/authTest/Screens/Login/loginPageUser.dart` — import + `late AppColors _colors`
- `primaryGreen` → `_colors.primary`, `darkBackground` → `_colors.background`
- `lightBackground` → `_colors.surfaceVariant`, `textColor` → `_colors.textPrimary`
- Déclarations const inutiles supprimées

**P7 — Internationalisation FR/EN ✅ FAIT**
- `lib/providers/locale_provider.dart` — `LocaleProvider extends ChangeNotifier` + persistence SharedPreferences
- `lib/l10n/app_localizations.dart` — classe manuelle couvrant navigation, feed, auth, posts, pronostics, dating, VIP, canaux, profil, splash, commun, thème (~100 chaînes)
- `pubspec.yaml` — ajout `flutter_localizations: sdk: flutter`
- `lib/main.dart` — `LocaleProvider` dans MultiProvider + `Consumer2<ThemeProvider, LocaleProvider>` + `localizationsDelegates`, `supportedLocales`, `locale`
- `lib/pages/home/homeScreen.dart` — bouton drapeau 🇫🇷/🇬🇧 dans AppBar nav row + option "Langue" dans le drawer avec toggle

**Usage dans les widgets :**
```dart
final l10n = AppLocalizations.of(context);
Text(l10n.navHome)       // 'Accueil' ou 'Home'
Text(l10n.authSignIn)    // 'Se connecter' ou 'Sign in'
```

**P8 — Pages profil, amis, chat, notifications ✅ FAIT (session 3 — 12 juin 2026)**

- `lib/pages/user/amis/ami.dart` — Bug corrigé : `_ConversationListState` et `_InvitationsState` n'avaient pas `_colors` déclaré → ajout `late AppColors _colors` + `_colors = AppColors.of(context)` dans chaque classe
- `lib/pages/user/amis/pageMesInvitations.dart` — import + `late AppColors _colors` + remplacements :
  - `Color(0xFF0A0A0A)` → `_colors.background`
  - `Color(0xFFFFD700)` → `_colors.accent`
  - `Colors.grey[900]`/`[850]` → `_colors.surfaceVariant`
  - `Colors.grey[800]` → `_colors.border`
  - `Colors.grey[400]` → `_colors.textSecondary`
- `lib/pages/chat/myChat.dart` — import + `late AppColors _colors` dans `_MyChatState` + remplacements :
  - Scaffold/AppBar : `Colors.black` → `_colors.background`
  - Bulles : `Colors.green[800]` → `_colors.primary`, `Colors.grey[300]` → `_colors.surface`
  - Texte bulle : `Colors.black` → `_colors.textPrimary`
  - Audio slider : `Colors.green` → `_colors.primary`, `Colors.grey` → `_colors.textSecondary`
  - Barre de saisie : `Colors.grey[800/900]` → `_colors.surfaceVariant/border`
  - Bouton envoi : `canSend ? Colors.green : Colors.grey` → `canSend ? _colors.primary : _colors.textSecondary`
  - Bouton micro : `Colors.green` → `_colors.primary`
  - Statut message lu/non lu : `Colors.green` → `_colors.primary`
- `lib/pages/mes_notifications.dart` — import + `late AppColors _colors` + remplacements :
  - Scaffold background : `Colors.grey.shade50` → `_colors.surface`
  - AppBar : `Colors.white` → `_colors.surfaceVariant`
  - Texte titre : `Colors.black` → `_colors.textPrimary`
  - Texte notifications : `Colors.black`/`Colors.black54` → `_colors.textPrimary`/`_colors.textSecondary`
  - FilterChip : `Colors.grey.shade100` → `_colors.surface`
  - Icône filtre : `Colors.grey` → `_colors.textSecondary`
  - Loading overlay : `Colors.black.withOpacity(0.8)` → `_colors.background.withOpacity(0.9)`
  - (Conservées : couleurs sémantiques rouge/bleu/vert selon type de notification)
- `lib/pages/user/profile/userProfileDetails.dart` — import + `late AppColors _colors` + `ConstColors.textColors` → `_colors.textPrimary`
- `lib/pages/user/profile/profileTabsBar/tabBar.dart` — import + `late AppColors _colors` dans les 2 State classes + remplacements :
  - `ConstColors.menuItemsColors` → `_colors.primary`
  - `ConstColors.textColors` → `_colors.textPrimary`
  - `Colors.black`/`Colors.grey[400]` (labels) → `_colors.textPrimary`/`_colors.textSecondary`
  - `Colors.white` (fond card) → `_colors.surface`

**P9 — Corrections et nettoyage (session 3 — suite)**

- `lib/pages/home/homeScreen.dart` — AppBar restructuré en 3 lignes (titre + nav + TabBar), helper mort `_navItem` supprimé
- `lib/l10n/app_localizations.dart` — Correction doublon `profileFriends` (conflit Dart) → renommé en `amisTabFriends` ('Mes Amis'/'My Friends')
- `lib/pages/user/amis/ami.dart` — l10n connecté : AppBar title, tab "Mes Amis" → `l10n.amisTabFriends`, tab "Mes Invitations" → `l10n.profileInvites`
- Drawer `homeScreen.dart` — textes pseudo/abonnés/version fixes (blanc → `_colors.textPrimary`/`textSecondary`)
- `lib/pages/canaux/listCanal.dart` + `listCanauxByUser.dart` — truncation titre canal à 12 caractères
- `lib/pages/postDetails.dart` — pseudo et titre canal : `Colors.white` → `_colors.textPrimary` + truncation 12 chars

**EN ATTENTE (prochaines étapes)**
- [ ] Pages social : `afrovideo.dart`, `vibesPage.dart` (adapter aux 2 modes)
- [ ] P5 — Performances : preloading vidéos, pagination Firestore
- [ ] Connexion l10n restante : `splashChargement.dart`, pages profil public, autres pages adaptées

### Session 4 (12 juin 2026 — agent actuel)

**Correction des erreurs signalées par l'utilisateur (priorité immédiate) ✅ FAIT**
- `lib/pages/user/conversation/listUserConv.dart` — corrections de mapping sémantique :
  - Texte de l'heure : `_colors.border` → `_colors.textSecondary`
  - Texte du badge non-lu (sur fond `primary`) : `_colors.background` → `_colors.onPrimary`
  - Séparateur en bas de chaque item : `_colors.textSecondary` → `_colors.divider`
  - `flutter analyze` → 0 erreur
- `lib/pages/auth/authTest/Screens/Login/loginPageUser.dart` — `l10n` était une variable locale de `build()` mais utilisée dans des méthodes séparées (`_buildHeader`, `_buildLoginForm`, etc.) → 9 erreurs "Undefined name 'l10n'". Corrigé en ajoutant `late AppLocalizations l10n;` en champ de classe (comme `_colors`), assigné dans `build()`.
  - `flutter analyze` → 0 erreur
- `lib/pages/user/amis/pageMesInvitations.dart` — 5 erreurs "Invalid constant value" : des widgets `const` référençaient `_colors.accent` (getter non-const). `const` retiré sur : `CircularProgressIndicator`, icône retour, titre "Invitations", icônes notifications/mail.
  - `flutter analyze` → 0 erreur

**PRIORITÉ 1 — Pages principales ✅ FAIT**
- `lib/pages/userPosts/postWidgets/postWidgetPage.dart` :
  - Constantes legacy inutilisées supprimées (`_twitterDarkBg`, `_twitterCardBg`, `_twitterTextPrimary`, `_twitterTextSecondary`, `_twitterBlue`, `_twitterRed`, `_twitterGreen`, `_twitterYellow`, `_afroBlack`)
  - `showRepublishDialog()` et `showInsufficientBalanceDialog()` : remplacés par `AppColors.of(context)` local (`dialogColors.surface/.textPrimary/.textSecondary/.info`)
  - Note : `_afroDarkBg`, `_afroCardBg`, `_afroTextPrimary`, `_afroTextSecondary`, `_afroGreen`, `_afroYellow`, `_afroRed`, `_afroBlue` sont **encore utilisées** ailleurs dans le fichier (lignes ~627-2822) → non touchées, à traiter dans une passe future
  - `flutter analyze` → 0 erreur
- `lib/pages/splashChargement.dart` — icône d'erreur `Colors.red` → `_colors.danger` (const retiré). Écran vidéo (`_buildVideoScreen`) conservé en `Colors.black/white` (fond vidéo intentionnel).
  - `flutter analyze` → 3 erreurs PRÉ-EXISTANTES (non liées) : `DestinationData` défini deux fois avec une casse différente entre `splashchargement.dart` et `splashChargement.dart`, traité comme deux types distincts par l'analyseur (lignes 215, 410, 459). **Non corrigé dans cette session** — à traiter séparément (renommage de fichier/classe).
- `lib/pages/userPosts/userPostForm.dart` — vérifié, aucun changement nécessaire (les seules occurrences `Colors.black` sont des `BoxShadow` ou du code commenté).

**PRIORITÉ 3 — Chat/notifications ✅ VÉRIFIÉ**
- `lib/pages/chat/myChat.dart` et `lib/pages/mes_notifications.dart` — `flutter analyze` → 0 erreur, déjà adaptés (fait en session 3).

- `lib/pages/postDetails.dart` — en cours via agent en arrière-plan (couleurs hardcodées restantes ~213 occurrences, mapping `_twitterBlue`/`_twitterRed` → `_colors.info`/`_colors.danger`). **Ne pas dupliquer ce travail.**

**Demande utilisateur : fusion section "Découvrir" dans la barre du haut + harmonisation couleurs ✅ FAIT**

- `lib/pages/home/HomePostType.dart` (`_HomeConstPostTypePageState`) :
  - Suppression complète de l'AppBar "Découvrir" (titre + boutons filtre type / filtre pays / actualiser) → le `Scaffold` n'a plus d'`appBar`, juste `body` avec `RefreshIndicator`
  - Ajout de 3 méthodes publiques exposées pour la barre du haut de `homeScreen.dart` :
    - `showTypeFilter()` → `_showTypeFilterModal()`
    - `showCountryFilter()` → `_showCountryFilterModal()`
    - `refreshFeed()` → `_refreshData()`
  - `flutter analyze` → 0 erreur

- `lib/pages/home/homeScreen.dart` :
  - Import ajouté : `providers/sound_provider.dart`
  - `GlobalKey<State<HomeConstPostTypePage>> _discoverKey` ajouté, passé à `HomeConstPostTypePage(key: _discoverKey, ...)` dans le `TabBarView`
  - Nouvelles méthodes `_onTopBarFilterTap()` et `_onTopBarRefreshTap()` qui appellent les méthodes publiques de `HomePostType.dart` via `_discoverKey.currentState` + dynamic dispatch (pattern utilisé car privacy Dart bloque seulement les membres `_`)
  - Barre du haut (Ligne 1, AppBar) : **icône Boutique/store supprimée**, remplacée par 3 nouvelles icônes issues de "Découvrir" :
    - Filtre pays (`Icons.filter_alt_outlined`, `_onTopBarFilterTap`)
    - Son on/off (`Icons.volume_up`/`Icons.volume_off`, via `SoundProvider.toggleSound()`)
    - Actualiser (`Icons.refresh`, `_onTopBarRefreshTap`)
  - `actionIconSize` réduit de `20` → `18` pour que les 7 icônes (dating, filtre, son, actualiser, langue, thème + badge) tiennent sans débordement horizontal
  - `PreferredSize` de l'AppBar : hauteur `140` → `150` pour corriger le débordement de pixels en bas du `TabBar` (44+52+TabBar ≈ 142 > 140)
  - Bouton "Créer" (FAB style) réduit de `36x36`/icône `22` → `30x30`/icône `navIconSize-6` (18), animation pulse conservée
  - Item nav "Lives" : `activeColor: Colors.red` → `activeColor: colors.danger`
  - Drawer (`menu()`) — harmonisation couleurs sur ~30 `ListTile` (remplacements globaux) :
    - Textes : `Colors.white` → `colors.textPrimary` (s'adapte noir/blanc selon thème → corrige l'invisibilité en mode clair)
    - Icônes/chevrons : `Colors.green`/`Colors.yellow`/`Colors.greenAccent`/`Colors.red` (items admin) → `colors.primary` (vert harmonisé)
    - `Divider(color: Colors.green)` → `Divider(color: colors.primary)`
    - Bouton "Voir mon profil" : `Colors.blue` → `colors.primary`
    - Item "Déconnexion" : texte `Colors.yellow` → `colors.textPrimary`
  - `flutter analyze lib/pages/home/homeScreen.dart lib/pages/home/HomePostType.dart` → 0 erreur (110 lints `info` pré-existants type `prefer_const_constructors`, non bloquants)

**EN ATTENTE (mis à jour — prochaines étapes)**
- [ ] Vérification visuelle (émulateur/device) du rendu de la barre du haut (7 icônes avec `actionIconSize=18`) et du `TabBar` (plus de débordement) — non testé visuellement dans cette session, seulement `flutter analyze`
- [ ] Finaliser `lib/pages/postDetails.dart` (agent en arrière-plan en cours)
- [ ] `lib/pages/userPosts/postWidgets/postWidgetPage.dart` — traiter les constantes `_afro*` restantes (lignes ~627-2822)
- [ ] `lib/pages/splashChargement.dart` — corriger le conflit de classe `DestinationData` (casse de fichier `splashchargement.dart` vs `splashChargement.dart`)
- [ ] PRIORITÉ 4 — `afrovideo.dart`, `video_details.dart`, `vibesPage.dart`, `challenge_month_post_card.dart`, `userPostVideoTab.dart`
- [ ] PRIORITÉ 5 — Performances (pagination, preloading vidéos)

### Session 5 (12 juin 2026 — agent actuel)

**Demande utilisateur : espacement icônes, suppression 2e AppBar "Découvrir", harmonisation post details/widgets ✅ EN COURS**

- `lib/pages/home/homeScreen.dart` :
  - Espacement entre les icônes de la Ligne 1 (AppBar du haut) augmenté : `horizontal: 3` → `horizontal: 6` (et `EdgeInsets.only(left:3,right:8)` → `left:6,right:10`) pour une meilleure zone tactile
  - Titre "Afrolook" réduit : `fontSize: 20` → `15`, `letterSpacing: 1.2` → `1.0`, pour libérer de la place pour les icônes
  - "Voir mon profil" (drawer) → `l10n.btnViewProfile` (i18n FR/EN). Ajout de `final l10n = AppLocalizations.of(context);` au début de `menu()` (qui ne l'avait pas, contrairement à `build()`)
  - Ajout de `import 'HomeConstPost.dart';`
  - Nouvelles clés `_looksRecentKey` et `_looksPopularKey` (`GlobalKey<State<HomeConstPostPage>>`) + getter `_activeFeedKey` qui sélectionne la bonne clé (`_looksRecentKey` / `_discoverKey` / `_looksPopularKey`) selon `_tabController.index` (0 / 3 / 7). `_onTopBarFilterTap`/`_onTopBarRefreshTap` utilisent désormais `_activeFeedKey` au lieu de seulement `_discoverKey`
  - `LooksPage(...)` (onglets Récents/Populaires) reçoit maintenant `feedKey: _looksRecentKey` / `feedKey: _looksPopularKey`

- `lib/pages/home/homeLooks.dart` (`LooksPage`) : ajout du paramètre `feedKey` (GlobalKey<State<HomeConstPostPage>>?) transmis à `HomeConstPostPage(key: widget.feedKey, ...)`

- `lib/pages/home/HomeConstPost.dart` (`_HomeConstPostPageState`) — **2e AppBar "Découvrir" supprimée** (même traitement que `HomePostType.dart` en session 4) :
  - Pour `isVideoPage == false` (onglets Looks récents/populaires utilisés dans le TabBarView de homeScreen) : plus d'AppBar du tout (`appBar: null`)
  - Pour `isVideoPage == true` (page "Afrolook vidéos" ouverte en navigation séparée) : AppBar conservée (son/refresh/thème) car cette page n'a pas la barre supérieure combinée de homeScreen
  - Nouvelles méthodes publiques : `showCountryFilter()` → `_showCountryFilterModal()`, `refreshFeed()` → `_refreshData()` (même pattern GlobalKey + dynamic dispatch que session 4)
  - Note : `_getFilterDescription()`, `_getFilterBorderColor()`, `_getFilterIcon()` ne sont plus appelées (AppBar normale supprimée) → deviennent `unused_element` (info), non bloquant, à nettoyer dans une passe future si besoin

- `lib/pages/postDetails.dart` — fond noir derrière l'image en mode clair corrigé :
  - `_buildMediaContent()` (méthode active, ligne ~4402) : `Container` de l'image ajoute `color: _colors.surfaceVariant` (fond adapté au thème au lieu de transparent), et l'ombre `BoxShadow` passe de `Colors.black.withOpacity(0.5)` → `Colors.black.withOpacity(_colors.isDark ? 0.5 : 0.12)` (ombre douce en mode clair)
  - Carte "🎯 VOTER POUR CE LOOK" (~ligne 4996) : fond `Colors.black.withOpacity(0.3)` → `_colors.isDark ? Colors.black.withOpacity(0.3) : _colors.surfaceVariant`
  - `flutter analyze` → 0 erreur
  - Note : `_buildMediaContent2`/`_buildMediaContent3` sont des méthodes legacy non utilisées (non touchées)

- `lib/pages/userPosts/postWidgets/postWidgetPage.dart` (`HomePostUsersWidget`, `_buildPostHeader`, ~ligne 1558) :
  - Avatar : bordure verte (`colors.primary`) ajoutée autour de l'avatar de l'auteur du post
    - Utilisateur → `CircleAvatar` (rond)
    - Canal → `Container` carré (coins arrondis `BorderRadius.circular(10)`) avec `DecorationImage`/icône `Icons.group`
  - `flutter analyze` → 0 erreur
  - Like (cœur) : déjà correct — `colors.danger` (rouge) si déjà liké, `colors.textSecondary` sinon (ligne ~2780). **Aucun changement** demandé par l'utilisateur (système payant, like multiple autorisé)

**TERMINÉ — refactor `postWidgetPage.dart` / `youTube_video_card.dart` (3 tâches) ✅ FAIT**

- **Tâche 1 — Extraction du widget post audio** :
  - Nouveau fichier `lib/pages/userPosts/postWidgets/audioPostWidget.dart` — classe `AudioPostCard` (StatefulWidget, `_AudioPostCardState`), prend `post` et `isLocked` en paramètres
  - Reprend l'UI de l'ancien `_buildAudioContent()` (pochette, play/pause, slider de progression, durée, barres d'égaliseur, overlay "verrouillé")
  - Ajout d'une icône son on/off (`Icons.volume_up`/`Icons.volume_off`, via `Consumer<SoundProvider>` + `_toggleSound()`) dans la ligne d'en-tête "Audio", suivant le même pattern que `youTube_video_card.dart`
  - Logique audio déplacée dans le nouveau State : `AudioPlayer` unique (`_player`), `_initPlayer`, `_precacheAudio`, `_playPause`, `_stop`, `_pause`, `_seek`, `_formatDuration`, gestion de visibilité via `VisibilityDetector` (`_onVisibilityChanged`)
  - Dans `postWidgetPage.dart` (`_HomePostUsersWidgetState`) :
    - Appel `_buildAudioContent(h, isLocked)` remplacé par `AudioPostCard(post: widget.post, isLocked: isLocked)` (ligne ~1400)
    - Suppression de `_buildAudioContent()`, `_initAudioPlayer`, `_precacheAudio`, `_getAudioExtension`, `_playAudio`, `_incrementViews` (doublon audio-only de `recordUniquePostView`), `_seekAudio`, `_showAudioError`, `_formatDuration`, `_handleAudioVisibilityChanged`, `_onAudioBecameVisible/Invisible`, `_pauseAudio`, `_stopAudio`, `_recordAudioInteraction`
    - Suppression des champs : `_cachedAudioFiles`, `_activePlayers`, `_currentlyPlayingAudioId`, `_isAudioPlaying`, `_currentAudioPosition`, `_currentAudioDuration`, `_isAudioVisible`, `_audioVisibilityTimer`
    - `dispose()` simplifié (ne gère plus que `MediaPlaybackManager.unregisterMedia`)
    - Imports `audioplayers` et `firebase_storage` retirés (plus utilisés dans ce fichier)

- **Tâche 2 — Bug du contrôleur global de son (`MediaPlaybackManager`)** :
  - Vérifié `registerVideo`/`registerAudio` dans `youTube_video_card.dart` : ils relisent déjà `_soundProvider?.isMuted` à chaque appel (pas de valeur cache figée) → (a) déjà correct
  - Pour (b) : chaque carte vidéo (`_YouTubeVideoCardState`) avait déjà son propre listener `_soundProvider.addListener(_updateVolume)` + re-synchronisation dans `_onBecameVisible()`. Le nouveau `AudioPostCard` reproduit exactement ce pattern : `_soundProvider.addListener(_onGlobalSoundChanged)` (resynchronise/pause si le son est coupé globalement, peu importe le média "courant" suivi par `MediaPlaybackManager`) + re-application de `SoundProvider.isMuted` dans `_onVisibilityChanged` à chaque passage en visible
  - Aucun changement de comportement play/pause au scroll — seule la synchronisation du volume est concernée

- **Tâche 3 — Harmonisation couleurs icônes d'action** :
  - `lib/pages/userPosts/youTube_video_card.dart` (`_buildPostActions`, ~ligne 1570-1577) : commentaire/vues/cadeau/partage passés de `colors.info`/`colors.warning` → `colors.textSecondary`. Like : `color: isLiked ? colors.danger : null` → `colors.textSecondary` quand non-liké (au lieu de `null`), logique de like inchangée
  - `_buildFavoriteButton` (~ligne 1617-1621) : `colors.accent` (état favori actif) → `colors.textSecondary` (la distinction visuelle reste portée par l'icône `bookmark`/`bookmark_border`)
  - `lib/pages/userPosts/postWidgets/postWidgetPage.dart` (`_buildPostActions`, ~ligne 2660-2715) : icône "Vues" (`Icons.bar_chart`, `colors.info` → `colors.textSecondary`) et "Cadeau" (`FontAwesome.gift`, `colors.accent` → `colors.textSecondary`)
  - `_buildFavoriteButton` (~ligne 2839-2860) : `colors.accent` (favori actif) → `colors.textSecondary`, idem CircularProgressIndicator
  - CircularProgressIndicator du bouton "Partager" en cours d'envoi : `colors.accent` → `colors.textSecondary`
  - Like (cœur) : **inchangé** comme demandé — `colors.danger` si liké, `colors.textSecondary` sinon, multi-like sans limite conservé

- `flutter analyze lib/pages/userPosts/postWidgets/postWidgetPage.dart lib/pages/userPosts/youTube_video_card.dart lib/pages/userPosts/postWidgets/audioPostWidget.dart` → **0 erreur** (381 infos/warnings pré-existants, type `avoid_print`/`deprecated_member_use`/`prefer_const_constructors`, non bloquants)

### Session 6 (12 juin 2026 — agent actuel)

**P5 — Préchargement vidéo Facebook-style dans le feed Home/Sport ✅ FAIT**

Objectif : reproduire dans `youTube_video_card.dart` (utilisé par `HomeConstPost.dart`) le pattern de préchargement déjà présent dans `lib/pages/vibe/vibesPage.dart` (`_preloadNeighborhood`, `_preloadedControllers`, `_preloadRadius = 2`, `_preloadVideoAtIndex`), sans toucher aux modèles de données ni à la sémantique des requêtes Firestore.

- **Nouveau fichier** `lib/pages/userPosts/video_preload_manager.dart` — classe statique `VideoPreloadManager` :
  - `preloadRadius = 2` (même valeur que `vibesPage.dart`)
  - `Map<String, VideoPlayerController> _preloadedControllers` indexé par `postId` (au lieu de l'index numérique de `vibesPage.dart`, car le feed Home mélange posts/pubs/anciens posts)
  - `preload(postId, urlMedia)` : initialise un `VideoPlayerController.network(...)` (via `urlResolver`, voir plus bas) sans jouer, volume forcé à `0.0` en attendant la prise en charge par `MediaPlaybackManager`
  - `preloadNeighborhood(currentIndex, length, idAt, urlAt)` : précharge les voisins `±preloadRadius` (callbacks `idAt`/`urlAt` fournis par l'appelant pour ne traiter que les items `Post` de type VIDEO)
  - `cleanupOutOfRange(currentIndex, length, idAt)` : dispose les contrôleurs préchargés hors de la fenêtre `±preloadRadius` (gestion mémoire, point 4 du cahier des charges)
  - `claimController(postId)` / `takeController(postId)` : permet à `YouTubeVideoCard` de récupérer (et retirer) un contrôleur déjà préchargé et initialisé
  - `discard(postId)` / `disposeAll()` : nettoyage explicite
  - `urlResolver` : `String Function(String rawUrl)?` statique, assigné une fois par `YouTubeVideoCard.initState()` vers `_authProvider.convertToCdnUrl(...)` (le manager statique n'a pas accès à `UserAuthProvider`)

- `lib/pages/userPosts/youTube_video_card.dart` :
  - Import de `video_preload_manager.dart`
  - `initState()` (~ligne 332) : assigne `VideoPreloadManager.urlResolver` (une seule fois, `??=`) avant l'appel `_preInitializeVideo()` existant
  - `_preInitializeVideo()` (~ligne 355-365) : avant de créer un nouveau `VideoPlayerController`, appelle `VideoPreloadManager.claimController(widget.post.id)` — si un contrôleur préchargé existe déjà (initialisé par le voisin précédent via `onNeighborhoodPreload`), il est réutilisé directement (pas de nouvel `.initialize()`, lecture instantanée possible)
  - `_initializeVideo()` (chemin "à la demande", ~ligne 564-572) : même logique — `claimController` avant de créer un contrôleur à froid (chemin de repli si le scroll est trop rapide pour le préchargement)
  - `onVisibilityChanged` (callback `onNeighborhoodPreload` déjà présent dans le widget, ~ligne 700-707) : déclenche désormais `_preloadVideoNeighborhood` côté `HomeConstPost.dart` à chaque passage en visible
  - Le son au démarrage était déjà géré correctement dans les deux chemins (`_preInitializeVideo`/`_initializeVideo` appellent `MediaPlaybackManager.registerVideo` qui relit `_soundProvider.isMuted` et force le volume sur `chewieController` + `videoController`, et `_onBecameVisible`/`_playVideo` re-forcent le volume juste avant `.play()`) — aucun changement nécessaire sur ce point, vérifié pour les deux chemins (préchargé → play, et init à froid → play)

- `lib/pages/home/HomeConstPost.dart` :
  - Import de `video_preload_manager.dart`
  - Nouveau champ `List<Post> _renderedFeedPosts = []` (~ligne 99) — mémorise la liste `finalPosts` (posts + anciens posts mélangés, dans l'ordre de rendu) construite dans `_buildContent()` (~ligne 3093), pour permettre de retrouver les voisins d'un index donné
  - `_buildContent()` (~ligne 3137) : `_renderedFeedPosts = finalPosts;` juste après la construction de `finalPosts`
  - `_buildPostWidget(post, width, height, index)` (~ligne 2302-2312) : `YouTubeVideoCard` reçoit désormais `index: index` et `onNeighborhoodPreload: _preloadVideoNeighborhood`
  - Nouvelle méthode `_preloadVideoNeighborhood(int index)` (~ligne 3545) : à partir de `_renderedFeedPosts`, construit `idAt`/`urlAt` (ne renvoient un id/url que si `post.dataType == PostDataType.VIDEO.name`, sinon `null` — pubs/posts non-vidéo ignorés) puis appelle `VideoPreloadManager.preloadNeighborhood(...)` et `VideoPreloadManager.cleanupOutOfRange(...)`
  - Note : `_buildContent2()`/`_posts[i]` (méthode legacy non appelée par `build()`) non modifiée

- **Vérification son AudioPostCard (point 5)** : `lib/pages/userPosts/postWidgets/audioPostWidget.dart` déjà conforme (fait en session 5) — `Consumer<SoundProvider>` + icône `volume_up`/`volume_off` + `_toggleSound()` + `MediaPlaybackManager.registerAudio`/`unregisterMedia`. Aucune correction nécessaire.

- `flutter analyze lib/pages/home/HomeConstPost.dart lib/pages/userPosts/youTube_video_card.dart lib/pages/userPosts/postWidgets/audioPostWidget.dart lib/pages/vibe/vibesPage.dart lib/pages/userPosts/video_preload_manager.dart` → **0 erreur** (420 infos/warnings, tous pré-existants — principalement dans `vibesPage.dart` : `avoid_print`, `deprecated_member_use` `withOpacity`/`VideoPlayerController.network`, `prefer_const_constructors`, `unused_field`/`unused_element`, non bloquants, non liés à cette session)

**EN ATTENTE (mis à jour)**
- [ ] Test manuel sur device/émulateur du préchargement (vérifier qu'il n'y a pas de pic de bande passante excessif avec plusieurs vidéos préchargées en parallèle)
- [ ] PRIORITÉ 4 — `afrovideo.dart`, `video_details.dart`, `vibesPage.dart` (adaptation thème 2 modes), `challenge_month_post_card.dart`, `userPostVideoTab.dart`
- [ ] `lib/pages/splashChargement.dart` — conflit de classe `DestinationData` (casse de fichier)

### Session 8 (13 juin 2026 — agent actuel)

**Vérification post-refactor : séparation audio + contrôleur global de son ✅ FAIT**

- **Tâche 1 — Séparation widget audio** : `lib/pages/userPosts/postWidgets/postWidgetPage.dart` vérifié — **aucun résidu audio** (pas de `_buildAudioContent`, pas d'import `audioplayers`/`firebase_storage`, pas d'état audio). Les posts audio sont rendus uniquement via `AudioPostCard(post: widget.post, isLocked: isLocked)` (import `audioPostWidget.dart`, ligne ~848). Séparation déjà correcte (faite en session 5), confirmée — aucun changement nécessaire.

- **Tâche 2 — Contrôleur global de son : BUG TROUVÉ ET CORRIGÉ** :
  - `lib/pages/home/HomeConstPost.dart` (`_HomeConstPostPageState.initState()`, ~ligne 180-189) créait une **instance orpheline** `_soundProvider = SoundProvider()` (nouvel objet, déconnecté de l'arbre `Provider`), puis appelait `MediaPlaybackManager.init(_soundProvider)` sur cette instance.
  - Or l'icône son globale de l'AppBar (même fichier, ~ligne 3952-3960, `Consumer<SoundProvider>` + `soundProvider.toggleSound()`) utilise l'instance **fournie par `ChangeNotifierProvider` dans `main.dart`** (ligne 318) — la même que celle lue par `youTube_video_card.dart` et `audioPostWidget.dart` via `Provider.of<SoundProvider>(context, listen:false)`.
  - Conséquence : le listener `_onGlobalSoundChanged` enregistré par `MediaPlaybackManager.init()` écoutait un `SoundProvider` jamais notifié par le vrai toggle → le mécanisme de resynchronisation immédiate au niveau du manager global était mort (dead listener sur objet zombie).
  - **Fix** : remplacement de `_soundProvider = SoundProvider();` par `_soundProvider = Provider.of<SoundProvider>(context, listen: false);` (dans le `addPostFrameCallback`, pour disposer d'un `context` valide). `MediaPlaybackManager.init()` écoute désormais la vraie instance globale.
  - Note : ce bug n'empêchait PAS le son de fonctionner au quotidien car `youTube_video_card.dart` (`_soundProvider.addListener(_updateVolume)`) et `audioPostWidget.dart` (`_soundProvider.addListener(_onGlobalSoundChanged)`) ont chacun leur PROPRE listener sur la bonne instance (via `Provider.of` dans leur propre `initState`) — la resynchronisation immédiate (point b du cahier des charges) fonctionnait donc déjà par ce chemin. Le fix corrige néanmoins le mécanisme prévu au niveau de `MediaPlaybackManager` pour qu'il soit cohérent et non mort.
  - `registerVideo`/`registerAudio`/`_onBecameVisible`/`_onVisibilityChanged`/`_playPause` relisent tous `isMuted` au moment de la lecture — pas de valeur figée à l'init. (a) déjà correct, vérifié.

- **Tâche 3 — Icône son globale** : confirmée dans `lib/pages/home/HomeConstPost.dart` (AppBar de la page "Afrolook vidéos", `isVideoPage == true`) — `Consumer<SoundProvider>` + `IconButton` (`Icons.volume_up`/`Icons.volume_off`) appelant `soundProvider.toggleSound()`. Utilise l'instance globale du `ChangeNotifierProvider` de `main.dart`, désormais la même que celle utilisée par `MediaPlaybackManager`.

### Session 9 (13 juin 2026 — optimisation requêtes feed home/vibes)

**Objectif** : réduire les allers-retours Firestore séquentiels sur le feed home, sans changer le contenu affiché (mix pays 40/60, rotation anciens posts).

- **Tâche 1 — Chargement batché des profils des chroniques** : déjà fait par une session précédente. `_loadChroniqueUserDataInBackground()` (`lib/pages/home/HomeConstPost.dart`, ~ligne 2245-2282) collecte déjà les `userId` uniques non encore en cache et fait une requête `whereIn` chunkée par 30 sur `Users` au lieu d'un `get()` par auteur. Aucun changement nécessaire — vérifié conforme aux specs.

- **Tâche 2 — Cache de fenêtres vides + cascade de repli pour les "anciens posts"** :
  - `lib/pages/home/HomeConstPost.dart` :
    - Ajout du champ `_emptyOldPostsWindows` (Set<DateTime>, ~ligne 177) qui mémorise les fenêtres mensuelles déjà testées et trouvées vides/quasi-vides (<3 posts) dans la session.
    - `_loadOldPostsInBackground()` (ancien, ~ligne 239-360) refactorisé en 3 fonctions :
      - `_pickRandomOldPostsWindowStart(random)` : tire une fenêtre pondérée (50% 1-6 mois / 30% 6-18 mois / 20% 18-30 mois) en essayant d'éviter les fenêtres déjà marquées vides (jusqu'à 5 tentatives, sinon retombe sur la dernière tirée).
      - `_fetchOldPostsForWindow(startDate)` : exécute la requête Firestore pour une fenêtre donnée et retourne les posts valides (filtrage doublons/pubs/déjà vus inchangé).
      - `_loadOldPostsInBackground()` : boucle sur jusqu'à 3 fenêtres dans la même passe (fenêtre initiale + **2 fallbacks max**) — si une fenêtre retourne <3 posts elle est marquée vide dans `_emptyOldPostsWindows`, et on tente immédiatement la fenêtre suivante au lieu d'attendre le prochain tick du timer.
    - `_startOldPostsLoading()` (~ligne 510) : intervalle du `Timer.periodic` passé de **15s à 22s** — moins de polling, le cache (`_oldPostsCache`, seuil <4) reste suffisamment alimenté grâce à la cascade de repli qui rend chaque passe plus "productive".
  - `lib/pages/vibe/vibesPage.dart` (même logique, fenêtres 1-6 mois pour `_loadOldVibesInBackground`) :
    - Ajout `_emptyOldVibesWindows` (Set<DateTime>) et `_oldVibesLoadTimer` (Timer?), déclarés juste après `_oldVibesCache`/`_isLoadingOldVibes`.
    - Refactor en `_pickRandomOldVibesWindowStart()`, `_fetchOldVibesForWindow()`, `_loadOldVibesInBackground()` (même cascade : initial + 2 fallbacks, marquage des fenêtres vides).
    - Nouveau `_startOldVibesLoading()` (Timer.periodic 22s, recharge si `_oldVibesCache.length < 4`) appelé depuis `_initializeFeed()` juste après le premier `_loadOldVibesInBackground()` — auparavant il n'y avait **aucun rechargement périodique** côté vibes (un seul appel à l'init). `_oldVibesLoadTimer?.cancel()` ajouté dans `dispose()`.

- **Tâche 3 — `limit * 2` → limites calculées** :
  - `lib/pages/home/HomeConstPost.dart` : les 3 occurrences (`_loadCountrySpecificPosts` ~ligne 1483, `_loadCountrySpecificPosts2` ~ligne 1615, `_loadAllCountriesPosts` ~ligne 1730) passées de `limit * 2` à `(limit * 1.5).ceil()`. Le filtrage client (dédoublonnage `loadedIds`/`_loadedPostIds`, exclusion pubs) ne réduit que rarement le lot de plus de 50%, donc 1.5x reste une marge confortable tout en réduisant la sur-lecture Firestore d'environ 25%.
  - `lib/pages/vibe/vibesPage.dart` (`_fetchSuggestedVibesBatch`, ~lignes 620/622, `fetchOrdered`/`fetchRandom` avec `limit * 2`) : **laissé inchangé** — ces requêtes tournent déjà dans une boucle de retry (`maxAttempts = 5`) avec un filtrage dédoublonnage léger uniquement (`ids.contains`), donc le ratio de perte est moins prévisible ; à ré-évaluer dans une session future avec mesure réelle avant de réduire (follow-up noté).

- **Tâche 4 — Page Sport** : `lib/pages/home/homeSport.dart` enveloppe `HomeConstPostPage(type: TabBarType.SPORT.name)` (pas de logique de requête propre) — bénéficie automatiquement de toutes les optimisations ci-dessus (cache fenêtres vides, cascade de repli, timer 22s, limites 1.5x).

**Vérification** : `flutter analyze lib/pages/home/HomeConstPost.dart lib/pages/vibe/vibesPage.dart lib/pages/home/homeSport.dart` → 0 erreur (351 infos/warnings, tous pré-existants : `avoid_print`, `deprecated_member_use withOpacity`, `prefer_const_*`, `use_build_context_synchronously`, 2 `unused_*` pré-existants dans vibesPage.dart).

**Suivi / follow-up** :
- [ ] Réévaluer `limit * 2` dans `vibesPage.dart` (`_fetchSuggestedVibesBatch`) après mesure du taux de doublons réel.
- [ ] Surveiller en prod le nouveau ratio de fenêtres vides via `_emptyOldPostsWindows`/`_emptyOldVibesWindows` (logs `print` existants) pour ajuster éventuellement le nombre de fallbacks (actuellement 2) ou l'intervalle du timer (22s).

- `flutter analyze lib/pages/userPosts/postWidgets/postWidgetPage.dart lib/pages/userPosts/postWidgets/audioPostWidget.dart lib/pages/userPosts/youTube_video_card.dart lib/pages/home/HomeConstPost.dart` → **0 erreur** (669 infos/warnings pré-existants, type `avoid_print`/`deprecated_member_use`/`unused_element`/`sized_box_for_whitespace`, non liés à cette session)

### Session 10 (13 juin 2026 — cache local du feed pour affichage instantané "Facebook-style")

**Objectif** : à l'ouverture de la page (Home récents/populaires, Sport), afficher immédiatement le dernier contenu chargé avec succès (sans skeleton/shimmer), pendant qu'un rafraîchissement réseau s'exécute normalement en arrière-plan et remplace/complète les données affichées.

- **Nouveau fichier `lib/pages/home/feed_cache_service.dart`** : classe `FeedCacheService` (statique, basée sur `shared_preferences`) :
  - `buildKey(type, sortType)` → clé `feed_cache_${type}_${sortType ?? 'default'}` (une clé par onglet/tri : Home récents, Home populaires, Sport, etc. — pas de collision).
  - `saveFeedData(cacheKey, data)` → sérialise `{ cachedAt: <ISO8601>, data: <Map> }` en JSON string.
  - `loadFeedData(cacheKey, {maxAge})` → renvoie `{ data, cachedAt }` ou `null` si absent / périmé (si `maxAge` fourni). Sans `maxAge`, renvoie les données quel que soit leur âge.
  - `isStale(cachedAt, maxAge)` : helper pour décider d'un refresh immédiat (TTL ads 1h / VIP-produits boostés 6h — prévu pour usage futur, non bloquant sur l'affichage qui reste toujours instantané).

- **`lib/pages/home/HomeConstPost.dart`** :
  - Import ajouté (~ligne 55) : `import 'feed_cache_service.dart';`.
  - `_initializeData()` (~ligne 615-650) : ajout de `await _loadFromCacheAndDisplay();` juste avant `_resetPagination()` — affiche le cache **avant** tout appel réseau, sans impacter le flux réseau existant (préchargement vidéo, fenêtres anciens posts, timer, etc. inchangés).
  - Nouvelle section "CACHE LOCAL DU FEED" (~ligne 657-918) :
    - `_feedCacheKey` (getter) = `FeedCacheService.buildKey(widget.type, widget.sortType)`.
    - `_loadFromCacheAndDisplay()` : lit le cache, reconstruit `List<Post>` (via `Post.fromJson`, déjà 100% JSON-safe — `created_at` est un int, pas un `Timestamp`), `List<Chronique>` (reconversion ISO string → `Timestamp` pour `createdAt`/`expiresAt` avant `Chronique.fromMap`, filtrage `isExpired`), les auteurs de chroniques (`UserData.fromJson` → `_userDataCache`/`_userVerificationStatus`), `List<UserData>` (profils suggérés), `List<Canal>` et `List<ArticleData>` (produits boostés/Zone VIP). Un seul `setState` peuple `_posts`, `_chroniques`, `_suggestedUsers`, `_canaux`, `_articles`, marque `_isLoadingPosts = false` et `_isFirstLoad = false` pour sauter le shimmer initial si du contenu posts est en cache.
    - `_saveFeedToCache()` : sérialise l'état courant (`_posts.toJson()`, `_chroniques.toMap()` avec `Timestamp` → ISO string, auteurs résolus via `_userDataCache`, `_suggestedUsers`/`_canaux`/`_articles` via leurs `toJson()` respectifs — `isVerify` ajouté manuellement car absent de `UserData.toJson()`) puis appelle `FeedCacheService.saveFeedData`.
  - Appels de sauvegarde ajoutés (best-effort, n'affectent pas le flux existant) :
    - `_loadInitialPosts()` (~ligne 1426-1429, après le `setState` des posts) : `_saveFeedToCache()` si `newPosts.isNotEmpty`.
    - `_loadChroniquesInBackground()` (~ligne 2540-2545) : `await _loadChroniqueUserDataInBackground(...)` (était fire-and-forget, maintenant attendu pour que les auteurs soient résolus avant la sauvegarde) puis `_saveFeedToCache()`.
    - `_loadSuggestedUsersInBackground()`, `_loadCanauxInBackground()`, `_loadArticlesInBackground()` : `_saveFeedToCache()` après le `setState` de succès.

- **Cache structure / TTL** : un seul blob JSON par clé `feed_cache_${type}_${sortType}` contenant `posts`, `chroniques`, `chroniqueAuthors`, `suggestedUsers`, `canaux`, `articles` (produits boostés). Pas de TTL appliqué côté affichage (toujours instantané) — `FeedCacheService` expose `isStale`/`maxAge` pour un usage futur (ads 1h, VIP 6h) sans changement de comportement actuel : le refresh réseau tourne systématiquement après l'affichage du cache, comme avant.

- **Non touché** : préchargement vidéo Facebook-style, init `SoundProvider`/`MediaPlaybackManager`, cache fenêtres "anciens posts" (`_oldPostsCache`, `_emptyOldPostsWindows`, timers 22s) — uniquement lus, jamais modifiés.

**Vérification** : `flutter analyze lib/pages/home/HomeConstPost.dart lib/pages/home/feed_cache_service.dart lib/pages/home/homeSport.dart` → **0 erreur** (303 infos/warnings, tous pré-existants : `avoid_print`, `prefer_const_*`, `unused_element`, `unnecessary_null_comparison`, etc., non liés à cette session).

**Suivi / follow-up** :
- [ ] Si souhaité plus tard : afficher un indicateur "mise à jour..." discret quand le cache ads/VIP dépasse son TTL (`FeedCacheService.isStale`), sans changer le comportement actuel (toujours instantané + refresh systématique).

---

### Session 11 (13 juin 2026 — filtre pays par défaut, thèmes clair/sombre des sections boostées, i18n menu)

**1. Filtre pays par défaut = pays de l'utilisateur** (`lib/pages/home/HomeConstPost.dart`) :
- `_initializeData()` (~ligne 616-637) : pour les types non-EVENEMENT, le filtre par défaut passe de `'MIXED'` à `'COUNTRY'` lorsque `_selectedCountryCode` (issu de `authProvider.loginUserData.countryData?['countryCode']`) est non null. Fallback `'MIXED'` conservé si le pays utilisateur est inconnu. L'utilisateur peut toujours changer via `_showCountryFilterModal()` (modale inchangée).
- En filtre `'COUNTRY'`, `_loadInitialPosts()` (switch ~ligne 1511-1558, cas `'COUNTRY'`) charge déjà les posts du pays utilisateur puis complète avec `_loadAllCountriesPosts` si pas assez de posts (sauf EVENEMENT) — comportement existant réutilisé, non modifié.
- `_feedCacheKey` (getter, ~ligne 657-662) : intègre désormais `_currentFilter` et `_selectedCountryCode` dans la clé (`feed_cache_${type}_${sortType}_${currentFilter}_${countryCode}`) pour éviter qu'un changement de filtre via la modale n'écrase le cache du filtre par défaut (pays utilisateur) avec le contenu d'un autre filtre. `_currentFilter`/`_selectedCountryCode` sont déjà fixés avant l'appel à `_loadFromCacheAndDisplay()` dans `_initializeData()`, donc la clé est correcte dès le premier affichage.
- S'applique automatiquement à Sport via `homeSport.dart` (wrapper de `HomeConstPostPage`).

**2. Corrections thème clair/sombre** :
- `lib/pages/home/HomeConstPost.dart` :
  - `_buildArticlesSection()` (~ligne 2996-3024, "Produits Boostés") : fond `Colors.black` → `colors.surface`, titre `Colors.white` → `colors.textPrimary`.
  - `_buildCanauxSection()` (~ligne 3065-3092, "Afrolook Canal") : fond `Colors.black` → `colors.surface` (titre vert conservé, lisible sur les deux fonds).
- `lib/pages/UserServices/ServiceWidget.dart` (`channelWidget`, ~ligne 139-160 et 222-232, utilisé par la section Canaux) : `afroBlack` (fond carte canal) passe de `Color(0xFF000000)` fixe à `AppColors.of(context).surfaceVariant` ; titre `#canal` `Colors.white` → `colors.textPrimary`. Import `app_colors.dart` ajouté.
- `lib/pages/contenuPayant/recent_vip_content_widget.dart` (section "Zone VIP", déjà fond `colors.surface` depuis Session précédente mais textes restés blancs) : titre "Zone VIP" (~ligne 172-180), titre du contenu (~ligne 320-325) et infos secondaires (pages/durée, ~ligne 330-339) passent de `Colors.white`/`Colors.grey` → `colors.textPrimary`/`colors.textSecondary`. Les badges superposés sur miniatures (overlay `Colors.black.withOpacity(0.7)`) restent en blanc/jaune/vert/rouge intentionnellement (texte sur image, OK dans les deux thèmes).
- `lib/pages/afroshop/marketPlace/component.dart` (`ProductWidget`) : non modifié — carte image avec overlay dégradé sombre intentionnel, correct dans les deux thèmes.

**3. i18n** (`lib/l10n/app_localizations.dart`, nouvelles clés ~ligne 142-152) :
- Nouvelles clés ajoutées (FR/EN) : `sectionBoostedProducts` ("🔥 Produits Boostés" / "🔥 Boosted Products"), `sectionDiscoverProfiles` ("👑 Profils à découvrir" / "👑 Profiles to discover"), `sectionAfrolookCanal` ("📺 Afrolook Canal" / "📺 Afrolook Channel"), `sectionBoutiques` ("Boutiques" / "Shops"), `menuMyChroniques` ("Mes chroniques" / "My chronicles"), `menuCanaux` ("Canaux" / "Channels").
- Clés existantes réutilisées : `commonSeeAll` ("Voir tout", profils), `vipSeeMore` ("Voir plus", canaux), `feedVip` ("Zone VIP"), `vipNew`/`vipFree`/`vipSeries`/`vipEbook`/`vipVideo` (badges Zone VIP).
- Remplacements : `HomeConstPost.dart` (`_buildProfilesSection`, `_buildArticlesSection`, `_buildCanauxSection` — import `app_localizations.dart` ajouté), `recent_vip_content_widget.dart` (import ajouté), `homeScreen.dart` `menu()` (`titre: "Canaux"` → `l10n.menuCanaux` ~ligne 903, `titre: "Mes chroniques"` → `l10n.menuMyChroniques` ~ligne 920).
- Pas de fichiers `.arb` dans ce projet — `AppLocalizations` est une classe Dart manuscrite (`lib/l10n/app_localizations.dart`), aucune régénération nécessaire.

**Non touché** : préchargement vidéo, init `SoundProvider`, cache fenêtres "anciens posts", `_loadMixedPostsSmart` (toujours utilisée si filtre `'MIXED'`, ex. fallback sans pays connu), `feed_cache_service.dart`.

**Vérification** : `flutter analyze lib/pages/home/HomeConstPost.dart lib/pages/home/homeScreen.dart lib/pages/home/homeSport.dart lib/pages/contenuPayant/recent_vip_content_widget.dart lib/pages/UserServices/ServiceWidget.dart lib/l10n/app_localizations.dart` → **0 erreur** (warnings/infos pré-existants uniquement).

---

### Session 12 (13 juin 2026 — correction régression : feed bloqué ~60s après les Sessions 6-11)

**Symptôme rapporté** : depuis les sessions précédentes (cache local, filtre pays par défaut, préchargement vidéo), l'écran d'accueil reste sur le skeleton/shimmer pendant 60+ secondes avant d'afficher les posts, à chaque lancement de l'app (pas seulement à froid).

**Root cause identifiée** (`lib/pages/home/HomeConstPost.dart`, `_initializeData()` ~ligne 617-655 avant correctif) :

1. `await _loadFromCacheAndDisplay()` (Session 10) affichait correctement les posts en cache en `setState` (skip skeleton, `_isLoadingPosts = false`).
2. **Immédiatement après**, `_resetPagination()` (ligne ~644) faisait `_posts.clear()` et `_loadedPostIds.clear()` → effaçait instantanément les posts qui venaient d'être affichés depuis le cache. `_posts.isEmpty` redevenait `true`.
3. `await _loadInitialPosts()` était alors appelé et **bloquait** toute la suite (`_startBackgroundLoading()`, `_loadAllAdditionalDataInParallel()`). Cette fonction remet `_isLoadingPosts = true` (ligne ~1511) → le skeleton réapparaît, alors qu'on avait déjà du contenu à montrer.
4. `_loadInitialPosts()` exécute, en mode `'COUNTRY'` (nouveau filtre par défaut de la Session 11), une requête Firestore pour le pays utilisateur PUIS, si `newPosts.length < limit`, une 2e requête `_loadAllCountriesPosts` en complément (`await` séquentiel). Sur un réseau lent/émulateur, ces deux `await` Firestore enchaînés (+ tous les `await` de `_loadMixedPostsSmart`/`_loadAllCountriesMixed` pour les autres filtres) peuvent cumuler un temps important — et **tout le reste de l'initialisation attend la fin de cette chaîne** avant de démarrer (chargement background, chroniques, profils suggérés, canaux, articles boostés).

En résumé : le cache local affichait le feed pendant ~1 frame, puis l'effaçait et rebasculait sur le skeleton pour la durée complète de la chaîne réseau séquentielle — pire qu'avant la Session 10 où il n'y avait qu'un seul skeleton (sans flash + reset), et aggravé par la Session 11 qui a ajouté une 2e requête Firestore séquentielle possible (`COUNTRY` + fallback `ALL`) sur le chemin critique.

**Fixes appliqués** (`lib/pages/home/HomeConstPost.dart`) :

- `_loadFromCacheAndDisplay()` (~ligne 677) : signature changée de `Future<void>` à `Future<bool>` — retourne `true` si des posts ont été chargés et affichés depuis le cache (`cachedPosts.isNotEmpty`), `false` sinon (y compris si `!mounted` ou erreur).
- `_resetPagination()` (~ligne 903) : nouveau paramètre `{bool clearPosts = true}`. Si `clearPosts == false`, `_posts` et `_loadedPostIds` ne sont PAS effacés (seuls les curseurs de pagination `_lastXxxDocument`, compteurs, etc. sont réinitialisés).
- `_initializeData()` (~ligne 639-674) :
  - `final bool hasCachedPosts = await _loadFromCacheAndDisplay();`
  - `_resetPagination(clearPosts: !hasCachedPosts);` → si le cache a affiché des posts, ils restent visibles.
  - Si `hasCachedPosts == true` : `_loadInitialPosts()` est appelé **sans `await`** (fire-and-forget, rafraîchit `_posts` dès que le réseau répond, sans skeleton intermédiaire) et `_startBackgroundLoading()` + `_loadAllAdditionalDataInParallel()` démarrent **immédiatement**, en parallèle, sans attendre la fin de `_loadInitialPosts()`.
  - Si `hasCachedPosts == false` (pas de cache, 1er lancement) : comportement historique conservé — `await _loadInitialPosts()` puis démarrage du background/données additionnelles (rien ne change dans ce cas, donc pas de risque de régression pour les nouveaux utilisateurs).
- `_loadInitialPosts()` (~ligne 1511-1518) : le `setState(() { _isLoadingPosts = true; ... })` en début de fonction ne remet `_isLoadingPosts = true` que si `_posts.isEmpty`. Si des posts (cache ou précédents) sont déjà affichés, ils restent visibles pendant le rafraîchissement réseau — le `setState` final (`_posts = newPosts`) les remplace seulement quand la réponse arrive, sans état intermédiaire vide.

**Ce qui N'A PAS été modifié** (hors scope / non concerné) :
- Splash screen (`lib/pages/splashVideo.dart`, `lib/pages/splashChargement.dart`) : aucun commit récent ne les touche (`git log` sur ces fichiers ne montre aucune entrée dans les 15 derniers commits) → écran de démarrage non modifié et non responsable du ralentissement, conformément à la consigne de ne pas y toucher.
- `VideoPreloadManager` / `youTube_video_card.dart` : le préchargement (`_preInitializeVideo`, `VideoPreloadManager.preload/preloadNeighborhood`) est déclenché via `addPostFrameCallback` (après le premier frame) et sur visibilité, donc **après** l'affichage des posts — il n'est pas dans la chaîne bloquante du premier paint. Non modifié.
- `feed_cache_service.dart` : `loadFeedData`/`saveFeedData` sont déjà des opérations `SharedPreferences` simples (un seul blob JSON), pas de boucle ni d'appel répété détecté. `_saveFeedToCache()` est déjà appelé sans `await` dans `_loadInitialPosts()` (fire-and-forget). Non modifié.
- Logique de diversité/mélange des posts (`_loadCountrySpecificPosts`, `_loadAllCountriesPosts`, `_loadOtherCountriesPosts`, `_loadMixedPostsSmart`, whereIn chroniques, fenêtres date anciens posts) : entièrement conservée, seul le **moment** où `_loadInitialPosts()` s'exécute par rapport au premier paint a changé.

**Vérification** : `flutter analyze lib/pages/home/HomeConstPost.dart lib/pages/userPosts/youTube_video_card.dart lib/pages/userPosts/video_preload_manager.dart lib/pages/home/feed_cache_service.dart` → **0 erreur** (357 infos/warnings, tous pré-existants : `avoid_print`, `deprecated_member_use` (`withOpacity`), `unused_element`, `dead_null_aware_expression`, etc., non liés à cette session).

---

### Session 13 (13 juin 2026 — redesign splash screen + ordre des badges pays selon le filtre actif)

**1. Splash screen** (`lib/pages/splashChargement.dart`, `_buildSplashScreen` ~ligne 300-340) :
- Redesign de la mise en page uniquement : le logo Afrolook reste en haut (`SizedBox(height:100,width:100, Image.asset('assets/logo/afrolook_logo.png')`), mais le bloc de chargement (spinner, `_loadingText`, `LinearProgressIndicator`, et le statut `_buildLoadingStatus()` quand un post/chat est en cours de chargement) est désormais regroupé dans une `Column` placée en bas de l'écran via un `Spacer()` (au lieu de l'ancien `Column(mainAxisAlignment: spaceBetween)` + `Expanded` centré qui plaçait le texte au milieu de l'écran). Ajout d'un `SafeArea` autour du contenu. Les couleurs utilisent déjà `AppColors.of(context)` (`_colors.primary`, `_colors.textSecondary`, `_colors.border`) — pas de couleurs codées en dur à corriger.
- **Non modifié** : toute la logique de navigation/redirection (`_startSessionCheck`, `_checkSessionAndRedirect`, `_handleAuthenticatedUserById`, `_prepareDestination`, gestion du cache de navigation `NavigationCacheService`, redirections post/chat/chronique/etc.), ainsi que `_buildErrorScreen`, `_buildLoadingScreen`, `_buildVideoScreen` (chemin vidéo actuellement mort car `shouldPlayVideo=false` par défaut et `_startInitFlow`/`_checkIfShouldPlayVideo` ne sont jamais appelés depuis `initState` — uniquement `_startSessionCheck` l'est).

**2. Parallélisation — analyse, rien changé** :
- `initState` n'appelle que `_startSessionCheck()`. La chaîne active est : `_checkSessionAndRedirect()` → (si session valide) `_updateUserLastActive(storedUserId)` puis `_handleAuthenticatedUserById(storedUserId)` → `await authProvider.getAppData()` puis `await authProvider.getLoginUser(userId)` → `await _prepareDestination()` (qui charge le cache de navigation puis, selon le type, `_loadPostData()`/`_loadChatData()`).
- Chaque étape dépend du résultat de la précédente (résultat de session pour authentifier, résultat d'auth pour préparer la destination, type de destination pour charger le post/chat). Aucune paire d'`await` indépendants n'a été identifiée dans la chaîne active sur le chemin critique de navigation.
- **Cas limite noté en follow-up** : dans `_handleAuthenticatedUserById` (~ligne 343-344), `await authProvider.getAppData()` est suivi de `await authProvider.getLoginUser(userId)`, qui lui-même appelle `await getAppData()` en interne (`lib/providers/authProvider.dart` ligne 1082). Il y a donc un appel `getAppData()` redondant, mais corriger cela touche `lib/providers/authProvider.dart` (hors scope, fichier exclu de cette session) — laissé tel quel, signalé comme piste d'optimisation future hors scope.
- Conclusion : aucun `Future.wait` ajouté, par prudence, conformément à la consigne « si incertain, laisser séquentiel ».

**3. Ordre des badges pays — pays du filtre actif en premier** :
- `lib/pages/userPosts/youTube_video_card.dart` : ajout du paramètre `currentFilterCountry` (String?) au constructeur de `YouTubeVideoCard` (~ligne 226-244). Dans `_buildCountryBadge()` (~ligne 1134-1152), si `countryCodes.length > 1` et que `currentFilterCountry` (en majuscules) est présent dans `availableCountries`, la liste est réordonnée pour placer ce pays en première position (sans ajout/suppression), avant le calcul de `firstCountryCode`/`flagEmoji`/`displayText`.
- `lib/pages/userPosts/postWidgets/postWidgetPage.dart` : même ajout pour `HomePostUsersWidget` — nouveau champ `currentFilterCountry` (~ligne 84-101) et même logique de réordonnancement dans `_buildCountryBadge(Post post)` (~ligne 1204-1220).
- `lib/pages/userPosts/postWidgets/audioPostWidget.dart` (`AudioPostCard`) : pas de badge pays dans ce widget — non modifié.
- `lib/pages/home/HomeConstPost.dart`, `_buildPostWidget` (~ligne 2616-2660) : passe `currentFilterCountry: _currentFilter == 'ALL' || _currentFilter == 'MIXED' ? null : _selectedCountryCode` à `YouTubeVideoCard` et `HomePostUsersWidget`. Si le filtre actif est `'ALL'` ou `'MIXED'` (pas de pays spécifique), `null` est transmis → ordre des badges inchangé, conformément à la consigne.

**Vérification** : `flutter analyze lib/pages/splashChargement.dart lib/pages/home/HomeConstPost.dart lib/pages/userPosts/youTube_video_card.dart lib/pages/userPosts/postWidgets/postWidgetPage.dart` → **0 nouvelle erreur**. 3 erreurs `argument_type_not_assignable` sur `DestinationData?` (lignes 215/418/467 de `splashChargement.dart`, hors zone modifiée) sont **pré-existantes** : artefact de cache de l'analyzer dû à la casse du nom de fichier (`splashchargement.dart` vs `splashChargement.dart` sous Windows), non lié aux changements de cette session. Tout le reste : infos/warnings pré-existants (`avoid_print`, `deprecated_member_use`, `unused_element`, etc.).

---

### Session 13b (13 juin 2026 — i18n complémentaire : menu latéral + modale profil utilisateur)

**Objectif** : traduire les chaînes françaises codées en dur restantes dans le menu latéral (`menu()`) et dans la modale de profil utilisateur affichée au tap sur l'avatar d'un post (`UserProfileModal`).

**1. Menu latéral** (`lib/pages/home/homeScreen.dart`, méthode `menu()`, relue intégralement avant modification — pas de conflit avec les changements "Canaux"/"Mes chroniques" de la Session 11, déjà en `l10n.menuCanaux`/`l10n.menuMyChroniques`) :
- "Mode sombre"/"Mode clair" (~ligne 481) → `l10n.menuDarkMode`/`l10n.menuLightMode`
- "Langue"/"Language" (~ligne 501) → `l10n.menuLanguage`
- "Rechercher un utilisateur" (~ligne 540) → `l10n.menuSearchUsers`
- "Profile" (~ligne 557) → `l10n.menuProfile`
- "Meilleurs Posts du mois" (~ligne 572) → `l10n.menuTopPostsMonth`
- "Amis" (~ligne 593) → `l10n.menuFriends`
- "Marketing" (~ligne 610) → `l10n.menuMarketing`
- "TOP 10 Afrolooks Stars" (~ligne 627) → `l10n.menuTopStars`
- "Pronostics & Betting" (~ligne 661) → `l10n.menuPronosticsBetting`
- "Mes favoris" (~ligne 749) → `l10n.menuFavorites`
- "🛠️Services & Jobs 💼" + sous-titre "Chercher des gens pour bosser" (~ligne 778-784) → `l10n.menuServicesJobs` / `l10n.menuServicesJobsSubtitle`
- "Afroshop Market" (~ligne 800) → `l10n.menuAfroshopMarket`
- "AfroCoin Market" (~ligne 833) → `l10n.menuAfroCoinMarket`
- "Mes lives" (~ligne 852) → `l10n.menuMyLives`
- "Mes challenges" (~ligne 869) → `l10n.menuMyChallenges`
- "Actus & Infos AfroLook" (~ligne 887) → `l10n.menuNewsInfo`
- "Nos Contactes" (~ligne 985) → `l10n.menuContacts`
- "Partager l'application" (~ligne 1002) → `l10n.menuShareApp`
- "Déconnecter" (~ligne 1045) → `l10n.menuLogout`
- "${...} abonné(s)" dans l'en-tête du drawer (~ligne 418) → réutilise la clé existante `l10n.profileSubscribers` ("abonné(s)" / "subscriber(s)")
- Non modifié : "AfroLove" (~ligne 644, nom de marque identique FR/EN), blocs commentés (Discuter/Xilo, Challenges Disponibles, Mes Looks Challenges — code mort).

**2. Modale profil utilisateur** : trouvée via `showUserDetailsModalDialog` (`lib/pages/component/showUserDetails.dart`) → instancie `UserProfileModal` dans `lib/pages/user/detailsOtherUser.dart` (lignes 648-1998). C'est le bottom-sheet plein écran affiché au tap sur l'avatar d'un post (avec photo de fond, stats, boutons Message/Inviter/S'abonner). La classe `_DetailsOtherUserState`/`DetailsOtherUser` (lignes 51-644) est du code mort non utilisé par `showUserDetailsModalDialog` — non modifiée (hors scope, déjà signalée par `unused_element`/non référencée).
- Import ajouté : `import '../../l10n/app_localizations.dart';` (~ligne 20).
- `_buildStatItem` : "Abonnés"/"Popularité"/"Parrainages" (~ligne 1290-1302) → `l10n.profileFollowers`/`l10n.profilePopularity`/`l10n.profileReferrals` (réutilise `profileFollowers` existant).
- Boutons d'action (~ligne 1319-1383) : "Message"/"Invitation envoyée"/"Inviter" → `l10n.profileMessage`/`l10n.profileInviteSent`/`l10n.profileInvite` ; "Abonné"/"S'abonner" → `l10n.profileSubscribed`/`l10n.profileSubscribe`.
- "Voir le profil complet" (~ligne 1430) → `l10n.profileSeeFullProfile` (le `Row`/`Text` parent est passé de `const` à non-`const` car dépend de `l10n`).
- `_buildProfileLikesSection()` (~ligne 1766) : "Likes profil" → `l10n.profileLikes`.
- `_buildProfileLikeButton()` (~ligne 1809) : "Patientez..."/"Liked"/"Like" → `l10n.profilePleaseWait`/`l10n.profileLiked`/`l10n.profileLike` ; SnackBar "Erreur lors du like" → `l10n.profileLikeError`.
- Fallback pseudo `"Utilisateur"` (~ligne 1248) → `l10n.profileDefaultUser`.
- Non modifié : la map des 190+ noms de pays `_getCountryName()` (~ligne 699-910, noms de pays en français — hors scope, pas des chaînes UI à traduire au sens du cahier des charges) ; `_buildProfileLikeButton2()` (code mort, `unused_element`).

**3. Nouvelles clés `lib/l10n/app_localizations.dart`** (FR/EN) :
- Section "Menu latéral (suite)" (~ligne 154-178) : `menuDarkMode`, `menuLightMode`, `menuLanguage`, `menuSearchUsers`, `menuProfile`, `menuTopPostsMonth`, `menuFriends`, `menuMarketing`, `menuTopStars`, `menuPronosticsBetting`, `menuFavorites`, `menuServicesJobs`, `menuServicesJobsSubtitle`, `menuAfroshopMarket`, `menuAfroCoinMarket`, `menuMyLives`, `menuMyChallenges`, `menuNewsInfo`, `menuContacts`, `menuShareApp`, `menuLogout`.
- Section "Profil" (~ligne 173-184 après ajout) : `profilePopularity`, `profileReferrals`, `profileLikes`, `profileInvite`, `profileInviteSent`, `profileSubscribe`, `profileSubscribed`, `profileSeeFullProfile`, `profileLiked`, `profileLike`, `profilePleaseWait`, `profileDefaultUser`, `profileLikeError`.
- Clés existantes réutilisées : `profileFollowers`, `profileMessage`, `profileSubscribers`, `menuCanaux`, `menuMyChroniques`.

---

### Session 15 (13 juin 2026 — affichage instantané du premier post sur `post_video_format_tel_details.dart`)

**Objectif** : sur la page détail/plein-écran vidéo (`PostDetailsVideoFormatTel`), le post initial passé en paramètre était caché derrière un écran de chargement ("Chargement des vibes en cours...") tant que la liste complète des vidéos suggérées n'était pas chargée depuis Firestore.

**Ancienne séquence bloquante** (`lib/pages/post_video_format_tel_details.dart`) :
- `initState()` (ligne ~172) appelait `_initializeFeed()` qui mettait `_isLoadingFeed = true` (ligne 552), puis faisait `await _loadPostRelations(...)`, `await _loadMoreVideos(isInitial: true)` (requêtes Firestore) et `await _loadOldVideosInBackground()` avant de construire `_feedItems` (`_rebuildFeedItems()`, ligne 574) et de repasser `_isLoadingFeed = false` (ligne 576).
- `build()` (ligne ~2432) affichait un `CircularProgressIndicator` tant que `_isLoadingFeed == true`, donc même le post déjà connu (`widget.initialPost`) restait invisible pendant ces appels réseau.

**Changements** :
1. `initState()` (lignes ~172-194) : le `widget.initialPost` est désormais ajouté immédiatement à `_videoPosts`/`_feedItems` via `_rebuildFeedItems()`, et `_isLoadingFeed` est mis à `false` AVANT tout appel réseau — `build()` peut donc afficher le `PageView` avec le premier post dès le premier frame. Les relations (user/canal) sont chargées via `_lazyLoadPostRelations` (existant, fire-and-forget). Un `addPostFrameCallback` déclenche `_initializeVideo(_feedItems[0], index: 0)` + `_preloadNeighborhood(0)` dès que le widget est monté, sans attendre la liste complète.
2. `_initializeFeed()` (lignes ~556-600) : ne remet plus `_isLoadingFeed = true` au début (le feed est déjà visible). Elle se contente désormais de charger en arrière-plan les vidéos suggérées (`_loadMoreVideos`) et les anciennes vidéos (`_loadOldVideosInBackground`), puis appelle `_rebuildFeedItems()` dans un seul `setState` final qui APPEND les nouveaux éléments à `_feedItems` sans toucher à `_pageController` ni à `_currentPage` — la lecture en cours du premier post n'est donc jamais interrompue/réinitialisée. Le bloc d'ajout du post initial est conservé en fallback (cas où `initState` n'aurait pas pu le faire).

**Vérification** : `flutter analyze lib/pages/post_video_format_tel_details.dart` → 104 issues, toutes pré-existantes (infos `avoid_print`/`deprecated_member_use`/`prefer_const_*`, warnings `unused_element` sur méthodes mortes déjà présentes avant ce changement) — aucune nouvelle erreur.

**Vérification** : `flutter analyze lib/pages/home/homeScreen.dart lib/l10n/app_localizations.dart lib/pages/user/detailsOtherUser.dart` → **0 erreur** (248 infos/warnings, tous pré-existants : `avoid_print`, `deprecated_member_use withOpacity`, `prefer_const_*`, `use_build_context_synchronously`, `unused_element` sur `_buildProfileLikeButton2`, `unnecessary_non_null_assertion`, non liés à cette session).

## Session 14 — Mise à parité de `homeSportPost.dart` avec `HomeConstPost.dart` (Sessions 6, 9, 10, 11, 13)

Fichier modifié : `lib/pages/home/homeSportPost.dart` (`HomeSportPostPage` / `_HomeSportPostPageState`). C'est une implémentation indépendante (pas de classe parente partagée), donc chaque point a été porté/adapté individuellement.

1. **Préchargement vidéo (Session 6)** : ajout de l'import `video_preload_manager.dart`, du champ `List<Post> _renderedFeedPosts = []`, et de la méthode `_preloadVideoNeighborhood(int index)` (basée sur `PostDataType.VIDEO`, `VideoPreloadManager.preloadNeighborhood`/`cleanupOutOfRange`). `_renderedFeedPosts = finalPosts;` est positionné dans `_buildContent()` juste après la construction de `finalPosts`. `YouTubeVideoCard` reçoit désormais `index: index` et `onNeighborhoodPreload: _preloadVideoNeighborhood` dans `_buildPostWidget`.

2. **Contrôleur son global (Session 8)** : ajout du champ `late SoundProvider _soundProvider`, initialisé dans `initState()` via `addPostFrameCallback` avec `Provider.of<SoundProvider>(context, listen: false)` puis `MediaPlaybackManager.init(_soundProvider)` (classe déjà définie dans `youTube_video_card.dart`, déjà importé). `dispose()` appelle désormais `MediaPlaybackManager.dispose()`.

3. **Optimisations Firestore (Session 9)** :
   - `_loadChroniqueUserDataInBackground` réécrite pour utiliser des requêtes `whereIn` chunkées par 30 (`FieldPath.documentId`) au lieu d'un chargement séquentiel par auteur ; `_loadChroniquesInBackground` attend désormais cette méthode (`await`) avant `_saveFeedToCache()`.
   - `_loadPostsWithTypeAndCountry` : `query.limit(limit * 2)` remplacé par `query.limit((limit * 1.5).ceil())`.
   - Anciens posts : l'ancienne méthode `_loadOldPostsInBackground()` (une seule fenêtre, sans repli) a été remplacée par le trio `_pickRandomOldPostsWindowStart(Random)`, `_fetchOldPostsForWindow(DateTime)` et `_loadOldPostsInBackground()` (cascade jusqu'à 3 fenêtres par passe, marquage des fenêtres vides dans `_emptyOldPostsWindows` si `< 3` posts trouvés). Ajout de `_startOldPostsLoading()` (`Timer.periodic` 22s, relance si `_oldPostsCache.length < 4`), appelée depuis `_initializeData()`.

4. **Cache local instantané du feed (Session 10/12)** : ajout des imports `feed_cache_service.dart` ; nouveau getter `_feedCacheKey` = `FeedCacheService.buildKey(widget.type, '${widget.sortType ?? 'default'}_${_currentFilter}_${_selectedCountryCode ?? 'none'}')` (clé distincte de `HomeConstPost` car `widget.type` = SPORT). Ajout de `_loadFromCacheAndDisplay()` et `_saveFeedToCache()` (miroir de `HomeConstPost.dart`, posts/chroniques/profils/canaux/articles). `_initializeData()` réécrite : appelle `_loadFromCacheAndDisplay()`, puis `_resetPagination(clearPosts: !hasCachedPosts)` (nouveau paramètre, Session 12 : ne vide pas `_posts` si le cache a déjà affiché du contenu), puis `_startOldPostsLoading()`, puis charge `_loadInitialPosts()` en `await` seulement si pas de cache (sinon fire-and-forget). `_saveFeedToCache()` est appelé après chargement réussi des posts, suggestions, articles, canaux et chroniques.

5. **Filtre pays par défaut + ordre des badges (Sessions 11/13)** : `_initializeData()` initialise `_selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase()` et `_currentFilter = 'COUNTRY'` si disponible (sinon `'ALL'`). `_loadInitialPosts()` (cas `'COUNTRY'`) charge d'abord les posts du pays puis complète avec tous pays si `newPosts.length < limit`. `_buildPostWidget` passe `currentFilterCountry: _currentFilter == 'ALL' || _currentFilter == 'MIXED' ? null : _selectedCountryCode` à `YouTubeVideoCard` et `HomePostUsersWidget` (les deux widgets supportaient déjà ce paramètre depuis la Session 13).

6. **Thème clair/sombre (Session 11)** : ajout de l'import `app_colors.dart`. Conversion en `AppColors.of(context)` pour : `_buildProfilesSection` (titre, ligne ~2486), `_buildProfileCard` (fond, placeholders image, ligne ~2541/2564/2569), `_buildArticlesSection` (fond + titre, ligne ~2680/2691), `_buildCanauxSection` (fond, ligne ~2743), `_buildLoadingSection` (fond + titre, ligne ~2797/2811), `_buildErrorWidget` (texte, ligne ~2482 nouveau), `build()` (Scaffold `backgroundColor`, barres titre/actions, bouton retour, bouton rafraîchir, titres, ligne ~3995-4093), `_buildCompactSportTitle` et `_buildCompactButton` (ligne ~4144/4189-4205). Les modales de filtre (pays/type) et la boîte de dialogue de soutien (`_showSupportDialog`) restent en thème sombre fixe (`darkBackground`/`textColor`), comme conçu à l'origine — non modifiées, hors périmètre prioritaire de cette session.

**Vérification** : `flutter analyze lib/pages/home/homeSportPost.dart` → **0 erreur** (352 infos/warnings, tous pré-existants : `avoid_print`, `deprecated_member_use withOpacity`, `prefer_const_*`, `unused_element` sur `_recordPostView2/3/4`, `unnecessary_null_comparison`/`unnecessary_non_null_assertion`, non liés à cette session).

---

## Session 18 — Fonds noirs figés restants + i18n des filtres dans `homeSportPost.dart`

Fichier modifié : `lib/pages/home/homeSportPost.dart` + `lib/l10n/app_localizations.dart`. Ajout de l'import `../../l10n/app_localizations.dart` (ligne 54).

### Task 1 — Fonds noirs/sombres figés corrigés (AppColors.of(context))

1. **Boîte de dialogue de soutien `_showSupportDialog()` (lignes ~417-526)** : `backgroundColor: darkBackground` → `colors.surface` ; conteneur "Devenez Premium" `color: lightBackground` → `colors.surfaceVariant` ; textes `color: textColor`/`Colors.grey` → `colors.textPrimary`/`colors.textSecondary` ; bouton "S'abonner" `foregroundColor: Colors.black` → `colors.onAccent` ; bouton "Regarder la pub" `foregroundColor: Colors.white` → `colors.onPrimary`.

2. **Modale filtre pays `_showCountryFilterModal()` (lignes ~912-1136)** : conteneur principal `color: darkBackground` → `colors.surface` ; poignée `Colors.grey[600]` → `colors.border` ; titre `textColor` → `colors.textPrimary` ; bouton fermer/icônes `Colors.grey[400/500]` → `colors.textSecondary` ; barre de recherche `Colors.grey[900]`/`Colors.grey[700]`/`Colors.white` → `colors.surfaceVariant`/`colors.border`/`colors.textPrimary` ; séparateur `Colors.grey[800]` → `colors.border` ; libellés "Choisir un pays"/"X pays" `Colors.grey[400/500]` → `colors.textSecondary` ; bouton "Fermer" `Colors.grey[800]`/`Colors.white` → `colors.surfaceVariant`/`colors.textPrimary`.

3. **`_buildQuickFilterOption()` (lignes ~1140-1177)** : fond non sélectionné `Colors.grey[900]` → `colors.surfaceVariant` ; bordure/texte/icône sélectionnés `Colors.white` → `colors.onPrimary` ; texte non sélectionné `Colors.grey[300/400]` → `colors.textPrimary`/`colors.textSecondary`.

4. **`_buildCountryList()` (lignes ~1178-1290)** : icônes vide/recherche `Colors.grey[600/500]` → `colors.textSecondary` ; carte pays `Colors.grey[900]` → `colors.surfaceVariant` ; pastille drapeau `Colors.black.withOpacity(0.3)` → `colors.surface.withOpacity(0.5)` ; nom du pays `Colors.white` → `colors.textPrimary` ; code pays `Colors.grey[400]` → `colors.textSecondary`.

5. **Modale filtre type `_showTypeFilterModal()` (lignes ~1372-1556)** : mêmes remplacements que la modale pays (conteneur `darkBackground` → `colors.surface`, poignée/recherche/séparateurs/bouton fermer → `colors.border`/`colors.surfaceVariant`/`colors.textPrimary`/`colors.textSecondary`).

6. **`_buildTypeOption()` (lignes ~1591-1660)** : fond non sélectionné `Colors.grey[900]` → `colors.surfaceVariant` ; pastille icône `Colors.black.withOpacity(0.3)` → `colors.surface.withOpacity(0.5)` ; textes `Colors.white`/`Colors.grey[300/400/500]` → `colors.textPrimary`/`colors.textSecondary`.

7. **`_buildProfileCard()` bouton "S'abonner" (ligne ~2645)** : `foregroundColor: darkBackground` → `colors.onPrimary` (le `colors` de la fonction parente était déjà disponible).

Note : les gradients `Colors.black87`/`Colors.black.withOpacity(0.3)` utilisés en overlay sur les images de profil (lignes ~2581) ainsi que `textColor` (blanc, ligne ~2601) pour le texte par-dessus ces overlays ont été **conservés tels quels** : ce sont des dégradés de lisibilité sur image, identiques en clair/sombre, comme dans `HomeConstPost.dart`.

### Task 2 — Nouvelles clés i18n et remplacements

Nouvelles clés ajoutées dans `app_localizations.dart` (section "Feed Sport : filtres & soutien", après `themeLight`) : `feedFilterByCountry`, `feedSearchCountry`, `feedAllFilter`, `feedMyCountry`, `feedMixFilter`, `feedChooseCountry`, `feedCountriesSuffix`, `feedNoCountryFound`, `feedTryAnotherSearch`, `feedYourCountry`, `feedChooseType`, `feedSearchType`, `feedAvailableTypes`, `feedTypesSuffix`, `feedFilterLabel`, `feedCountryLabel`, `feedOtherFilter`, `supportTitle`, `supportMessage`, `supportBecomePremium`, `supportPremiumPrice`, `supportPremiumDesc`, `supportWatchAd`, `supportThankYouAd`, `feedPostButton`. Clés réutilisées (existantes) : `commonClose`, `profileSubscribe`, `commonLoading`, `commonRetry`, `commonRefresh` (nouvelle, section Commun), `commonLoadingError` (nouvelle, section Commun).

Remplacements dans `homeSportPost.dart` :
- "🌍 Filtrer par pays" → `l10n.feedFilterByCountry`
- "Rechercher un pays..." → `l10n.feedSearchCountry`
- "Tous" (modale + chips) → `l10n.feedAllFilter`
- "Mon pays" (modale + chips + `_getFilterLabel`) → `l10n.feedMyCountry`
- "Mix" (modale + chips + `_getFilterLabel`) → `l10n.feedMixFilter`
- "⚙️ Autre" (chip) → `l10n.feedOtherFilter`
- "Choisir un pays" / "X pays" → `l10n.feedChooseCountry` / `l10n.feedCountriesSuffix`
- "Chargement..." / "Aucun pays trouvé" / "Essayez une autre recherche" → `l10n.commonLoading` / `l10n.feedNoCountryFound` / `l10n.feedTryAnotherSearch`
- "Votre pays" → `l10n.feedYourCountry`
- "📝 Choisir un type" / "Rechercher un type..." / "Types disponibles" / "X types" → `l10n.feedChooseType` / `l10n.feedSearchType` / `l10n.feedAvailableTypes` / `l10n.feedTypesSuffix`
- "Fermer" (3 boutons) → `l10n.commonClose`
- "Pays"/"Filtre" (défauts `_getFilterLabel`) → `l10n.feedCountryLabel` / `l10n.feedFilterLabel`
- "Soutenez Afrolook !" / message long / "Devenez Premium" / "200 F/mois 😊..." / "Soutenez directement les créateurs..." / "Regarder la pub" → `l10n.supportTitle` / `l10n.supportMessage` / `l10n.supportBecomePremium` / `l10n.supportPremiumPrice` / `l10n.supportPremiumDesc` / `l10n.supportWatchAd`
- "S'abonner" (dialogue de soutien + carte profil) → `l10n.profileSubscribe` (réutilisé)
- "Merci d'avoir regardé la publicité ! ..." (snackbar) → `l10n.supportThankYouAd`
- "Poster" (bouton compact) → `l10n.feedPostButton`
- "Erreur de chargement" / "Réessayer" → `l10n.commonLoadingError` / `l10n.commonRetry`
- "Actualiser" (bouton vide) → `l10n.commonRefresh`

**Vérification** : `flutter analyze lib/pages/home/homeSportPost.dart lib/l10n/app_localizations.dart` → **0 erreur** (313 infos/warnings, tous pré-existants : `avoid_print`, `deprecated_member_use withOpacity`, `prefer_const_*`, `unused_element` sur `_recordPostView2/3/4`, `unnecessary_null_comparison`/`unnecessary_non_null_assertion`, `unnecessary_brace_in_string_interps`, `sized_box_for_whitespace` — non liés à cette session).

---

### Session 16 (13 juin 2026 — préchargement vidéo des publicités + redesign/instantanéité de la modale cadeau)

**1. Préchargement "Facebook-style" des vidéos de publicité** (`lib/pages/admin/AfrolookPub/advertisement_video_widget.dart`) :
- Imports ajoutés (~ligne 13-19) : `providers/sound_provider.dart`, `pages/userPosts/video_preload_manager.dart`.
- `_initializeVideo()` (~ligne 247-273, ex-ligne 239-245) : avant de créer un nouveau `VideoPlayerController.network(...)`, tente d'abord `VideoPreloadManager.claimController(widget.post.id ?? '')` (même API que `youTube_video_card.dart` ligne 370/570, cf. Session 6) — si un contrôleur préchargé existe déjà (initialisé en arrière-plan pendant le préchargement des posts voisins via `VideoPreloadManager.preloadNeighborhood`), il est réutilisé directement et la lecture démarre sans nouvelle initialisation/buffering. Sinon, l'URL est résolue via `VideoPreloadManager.urlResolver` (CDN, déjà configuré par `youTube_video_card.dart`) et le contrôleur est initialisé normalement. À la fin, un appel `VideoPreloadManager.preload(widget.post.id ?? '', widget.post.url_media)` est fait (sans effet si déjà préchargé/claim) pour que les pubs créées hors-écran soient préchargées avant d'être visibles.
- Application du son global (2e partie de la tâche) :
  - `_initializeVideo()` lit `SoundProvider.isMuted` (via `Provider.of<SoundProvider>(context, listen: false)`) et applique `setVolume(isMuted ? 0.0 : 1.0)` dès l'initialisation (au lieu du `setVolume(0.1)` fixe précédent).
  - `_handleVisibilityChanged()` (~ligne 156-179) : avant `_videoController!.play()`, le volume est de nouveau forcé selon `SoundProvider.isMuted` (même pattern que `_playVideo()` dans `youTube_video_card.dart` ligne 670-684).
  - Nouveau listener `_onSoundChanged()` (~ligne 76-80) ajouté sur `SoundProvider` dans `initState`/`dispose` : si l'utilisateur change le mode son global pendant qu'une pub est en cours de lecture, le volume du `_videoController` est mis à jour en direct (`removeListener` dans `dispose`).
- `MediaPlaybackManager` (classe statique de `youTube_video_card.dart`) n'a pas été utilisé pour l'enregistrement : son API `registerVideo` exige un `ChewieController` non-nullable, et la pub utilise un `VideoPlayer` brut (pas de Chewie) — l'intégrer aurait nécessité de migrer la pub vers Chewie (hors scope). La cohérence du son est néanmoins assurée via `SoundProvider` directement (lecture initiale + listener live), couvrant l'exigence fonctionnelle (respect du mute global).

**2. Modale d'envoi de cadeau** (`lib/pages/coins/coin_gift_dialog.dart`) :
- **Modale active confirmée** : `CoinGiftDialog` (`lib/pages/coins/coin_gift_dialog.dart`), ouverte via `_handleGift`/`_showGiftDialog` dans `lib/pages/post_video_format_tel_details.dart` (ligne ~1526), `postDetailsVideo.dart`, `postDetails.dart` et `postChallengeWidget.dart` — c'est le chemin du tap sur l'icône cadeau dans le feed vidéo principal. `lib/pages/userPosts/postWidgets/postCadeau.dart` (`GiftDialog`, classe legacy avec émojis 🎁❤️🥉🥈🥇💎 codés en dur) est utilisé uniquement par les anciennes pages `afrovideo.dart`, `socialVideos/video_details.dart` et `profileVideosTab.dart` — non touché (hors scope, pages différentes). `postWidgetPage.dart` a aussi sa propre implémentation inline (`_showGiftDialog`, ligne 3318) indépendante — non touchée non plus.
- **2a. Grille 4 colonnes plus petite** : `_buildGiftGrid()` (~ligne 313-432) : `SliverGridDelegateWithFixedCrossAxisCount` passe de `crossAxisCount: 3` à `4`, `crossAxisSpacing`/`mainAxisSpacing` de 12→8, `childAspectRatio` de 0.72→0.78, `padding` horizontal de 20→14. Tailles réduites à l'intérieur de chaque carte : icône `fontSize` 40→26, label 12→10 (avec `maxLines: 1` + ellipsis), badge prix (icône pièce 10→8, texte 11→9, padding 8/2→5/1), texte "Insuffisant" 8→7. `borderRadius` des cartes 16→12. Couleurs/thème (dégradés or existants) conservés à l'identique.
- **2b. Envoi instantané** : `_sendGift(CoinPack pack)` (~ligne 500-543) entièrement réécrit :
  1. Validation locale (déjà existante) : `_currentBalance < pack.coins` → dialog "solde insuffisant".
  2. Si OK : `setState(() => _currentBalance -= pack.coins)` (décrément optimiste local), puis **immédiatement** `Navigator.pop(context)` + `_showSuccessAnimation(pack)` (animation de confirmation déjà existante, inchangée) + callbacks `_recordLiveGift`/`widget.onGiftSuccess` — tout ceci de façon synchrone, sans `await`.
  3. L'appel réel `_coinProvider.sendGift(...)` (transaction Firestore + notifications dans `coin_gift_service.dart`, inchangé) est lancé en arrière-plan via `unawaited(...)` (import `dart:async` ajouté ligne 2) — la modale est déjà fermée pendant ce temps.
  4. En cas de succès : `onSuccess` appelle `_coinProvider.refreshBalance(senderId)` (méthode existante de `coin_gift_provider.dart`, inchangée) qui relit le solde Firestore réel et fait `notifyListeners()` — réconcilie le solde optimiste avec le solde serveur (70%/30% + commissions parrainage), sans nouvel état ajouté.
  5. En cas d'échec (`success == false` ou exception) : `_coinProvider.refreshBalance(senderId)` est appelé pour resynchroniser le solde réel partout où il est affiché, et l'erreur est loguée via `debugPrint` (pas de SnackBar sur le contexte de la modale, déjà fermée/démontée à ce stade).
- L'ancien `CircularProgressIndicator` plein-écran pendant tout l'aller-retour Firestore (`_isLoading` dans `_buildActions`, ~ligne 463-468) n'est plus déclenché par `_sendGift` (le `setState(() => _isLoading = ...)` a été retiré) — le bouton "Envoyer" reste dans son état normal, la modale se fermant avant que Firestore ne réponde.
- **Cohérence du solde** : aucune nouvelle source de vérité ajoutée — `_currentBalance` (état local du widget) reste une simple copie d'affichage de `_coinProvider.giftCoinsBalance` (`CoinGiftUserProvider`, `lib/providers/coin_gift_provider.dart`, non modifié), réconciliée via `refreshBalance` (déjà existant) dans tous les cas (succès et échec).

---

### Session 17 (13 juin 2026 — garantir 2 posts d'avance prêts dès l'affichage du post #1, `post_video_format_tel_details.dart`)

**Objectif** : après la Session 15 (affichage instantané du post initial), s'assurer qu'au moment où le post #1 s'affiche, au moins 2 posts suivants (#2/#3) sont déjà chargés dans `_feedItems`/`_videoPosts` et préchargés via `_preloadNeighborhood`, pour qu'un swipe immédiat ne tombe jamais sur un trou de chargement.

**Avant** : dans `_initializeFeed()` (lignes ~575-615), après l'ajout du post initial, la séquence était : `await _loadMoreVideos(isInitial: true)` (un seul lot de `_batchSize = 10` posts suggérés, requêtes Firestore avec `_loadPostRelations` séquentiel par post) **puis** `await _loadOldVideosInBackground()` (sélection d'anciennes vidéos sur une fenêtre de mois aléatoire), et seulement ensuite un unique `setState` faisait `_rebuildFeedItems()` + `_preloadNeighborhood(0)`. Les posts #2/#3 n'étaient donc disponibles qu'après la fin du lot de 10 ET des anciennes vidéos — un swipe rapide après l'affichage du post #1 pouvait tomber sur `_feedItems` ne contenant qu'un seul élément.

**Changements** (`lib/pages/post_video_format_tel_details.dart`) :
1. `_loadMoreVideos()` (ligne ~796) : nouveau paramètre optionnel `int? limit` (défaut `_batchSize` si non fourni), passé à `_fetchSuggestedVideosBatch(limit: limit ?? _batchSize, ...)` au lieu de toujours `_batchSize`.
2. `_initializeFeed()` (lignes ~592-628) : la requête de vidéos suggérées est désormais scindée en deux temps :
   - **Lot prioritaire** : `await _loadMoreVideos(isInitial: true, limit: 3)` — récupère rapidement 2-3 posts supplémentaires, suivi immédiatement d'un `setState(() => _rebuildFeedItems())` puis `_preloadNeighborhood(0)` (précharge les `VideoPlayerController` des posts #2/#3 pendant la lecture du post #1).
   - **Lot complémentaire** : `await _loadMoreVideos(isInitial: true, limit: _batchSize - 3)` puis `await _loadOldVideosInBackground()`, suivis du `setState` final existant (`_rebuildFeedItems()` + `_isLoadingFeed = false`) — inchangé sinon, toujours en append sans perturber `_pageController`/`_currentPage`.

Le post #1 continue de s'afficher dès le premier frame (logique Session 15 inchangée dans `initState`, lignes ~172-194) ; seul l'ordre/découpage des requêtes de suggestions dans `_initializeFeed` a changé.

**Vérification** : `flutter analyze lib/pages/post_video_format_tel_details.dart` → **104 issues**, identiques à la Session 15 (toutes pré-existantes : `avoid_print`, `deprecated_member_use withOpacity`, `prefer_const_*`, `unused_element`/`unused_local_variable` sur du code mort déjà présent) — **0 nouvelle erreur**.

**Vérification** : `flutter analyze lib/pages/admin/AfrolookPub/advertisement_video_widget.dart lib/pages/coins/coin_gift_dialog.dart` → **0 nouvelle erreur**. Quelques warnings pré-existants inchangés : `unused_import` (`cached_network_image`), `unused_field` (`_isLoadingUser`, `_hasRecordedClick`), `unused_element` (`_calculatePostHeight`, `_buildHeader2`), tous présents avant cette session et non liés aux changements.

---

### Session 19 (13 juin 2026 — "Voir la traduction" façon Facebook pour les descriptions de post)

**Objectif** : ajouter sous la description d'un post un lien "Voir la traduction" qui traduit le texte vers la langue courante de l'app (FR/EN) via une Cloud Function adossée à Google Cloud Translation API, avec mise en cache Firestore pour les lectures suivantes.

**1. Cloud Function** (`functions/src/translatePost.ts`, nouveau fichier) :
- Export `translatePostDescription` (`onCall`, `firebase-functions/v2/https`, `timeoutSeconds: 30`, région `us-central1`).
- Entrée : `{ postId, text, targetLang }`.
- **Cache** (lignes 44-49) : lit `Posts/{postId}`, et si `translations[targetLang]` existe déjà, le retourne directement avec `cached: true` — aucun appel API.
- Sinon (lignes 51-61) : appelle `@google-cloud/translate` v2 (`new translate.Translate()`, détection auto de la langue source) pour traduire `text` vers `targetLang`.
- Écrit le résultat dans `Posts/{postId}.translations.{targetLang}` via `update({[\`translations.${targetLang}\`]: translatedText})` (notation pointée, merge-safe, lignes 64-70) pour les prochaines lectures.
- Retourne `{ translatedText, cached }`. Erreurs API/Firestore gérées via `try/catch` + `HttpsError("internal", ...)` sans crash.
- Exporté depuis `functions/src/index.ts` (ligne 2) : `export {translatePostDescription} from "./translatePost";`.
- `functions/package.json` : ajout de la dépendance `"@google-cloud/translate": "^8.5.0"` (ligne 18) — **`npm install` à lancer dans `functions/` avant déploiement** (non exécutable dans cet environnement, pas d'accès réseau npm).

**2. Widget Flutter réutilisable** (`lib/pages/userPosts/postWidgets/translatable_description.dart`, nouveau fichier) :
- `TranslatableDescription` (StatefulWidget) : `{required postId, required text, required targetLang, required onToggle, TextStyle? style}`.
- Affiche uniquement le lien "Voir la traduction" / "Voir l'original" (le texte principal reste géré par le parent, qui reçoit la traduction via `onToggle`).
- Au tap : appelle `FirebaseFunctions.instance.httpsCallable('translatePostDescription')` avec `{postId, text, targetLang}`, affiche un petit loader (`l10n.translating`), puis bascule `onToggle(translatedText)`. Un second tap revient au texte original via `onToggle(null)` (sans nouvel appel réseau, cache local en mémoire via `_translatedText`).
- Couleur du lien : `colors.textSecondary` (`AppColors.of(context)`), taille 12, gras — cohérent avec le style existant des liens "Voir plus".

**3. Nouvelles clés l10n** (`lib/l10n/app_localizations.dart`, lignes 281-283) : `seeTranslation` ("Voir la traduction" / "See translation"), `seeOriginal` ("Voir l'original" / "See original"), `translating` ("Traduction..." / "Translating...").

**4. Intégration dans les pages de post** :
- `lib/pages/userPosts/postWidgets/postWidgetPage.dart` : nouvel état `_translatedDescription` (ligne ~117). Dans `_buildPostContent()` (~ligne 1492-1532), `fullText = _translatedDescription ?? text` est utilisé pour le `HashTagText` (affichage normal + "Voir plus"/"Voir moins" inchangés), et `TranslatableDescription` est inséré juste après, avec `targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode` (import `providers/locale_provider.dart` ajouté ligne 26).
- `lib/pages/userPosts/youTube_video_card.dart` : même pattern — nouvel état `_translatedDescription` (ligne ~284), `_buildPostContent()` (~ligne 1368-1392) utilise `fullText = _translatedDescription ?? text` pour le `HashTagText`, et `TranslatableDescription` est ajouté juste après (imports ajoutés lignes 42-43).
- `lib/pages/post_video_format_tel_details.dart` : la description affichée en overlay vidéo (bloc "Affichage normal", ~ligne 2040-2066) est enveloppée dans une `Column` ; le `Text` utilise `_translatedDescriptions[post.id] ?? post.description!` (map `Map<String, String>` ajoutée ligne 70, car cette page affiche un feed de plusieurs posts simultanément — une seule variable ne suffirait pas), et `TranslatableDescription` est ajouté en dessous avec mise à jour de la map via `onToggle`. Imports ajoutés lignes 40-41. Le bloc "Chargement..." (overlay temporaire pendant le chargement user/canal, ~ligne 1989-1996) n'a pas été modifié (hors scope, contenu transitoire).
- `lib/pages/userPosts/postWidgets/audioPostWidget.dart` et `lib/pages/postDetails.dart` n'ont pas été modifiés : `audioPostWidget.dart` n'affiche pas la description du post (uniquement métadonnées audio), et `postDetails.dart` (recherche `\.description`) n'a pas de rendu de description de post distinct identifiable simplement dans le temps imparti.

**Nouveau champ Firestore optionnel** : `Posts/{postId}.translations` (map `{ [langCode]: string }`), créé/mis à jour uniquement par la Cloud Function — aucune requête existante modifiée.

**Vérification** :
- `flutter analyze` sur les 5 fichiers touchés/créés → **0 nouvelle erreur** (478 issues au total, toutes pré-existantes : `avoid_print`, `deprecated_member_use withOpacity`/`VideoPlayerController.network`, `prefer_const_*`, `unused_field`/`unused_element`/`unused_local_variable` sur du code mort déjà présent, `dead_null_aware_expression`, `sized_box_for_whitespace`).
- `npx tsc --noEmit` dans `functions/` : **non exécuté** (accès Bash/PowerShell refusé pour cette commande dans cet environnement) — **à vérifier manuellement avant déploiement**, notamment après `npm install` (le type `@google-cloud/translate` n'est pas encore présent dans `node_modules`).

**Étapes manuelles de déploiement requises** :
1. Activer l'API **Cloud Translation API** dans la console GCP du projet Firebase (aucune clé API supplémentaire requise — utilise le compte de service par défaut des Cloud Functions).
2. `cd functions && npm install` (installe `@google-cloud/translate` ajouté au `package.json`).
3. `npx tsc --noEmit` (ou `npm run build`) pour vérifier la compilation TypeScript avant déploiement.
4. `firebase deploy --only functions` (ou `firebase deploy --only functions:translatePostDescription` pour cibler uniquement cette fonction).

---

## Session 20 — Déploiement de la traduction des posts + ajout de 6 langues d'interface

**Déploiement Cloud Function** :
- Correction de `functions/src/translatePost.ts` : suppression de `const db = getFirestore();` au niveau du module (s'exécutait avant `initializeApp()` dans `index.ts`, causant l'erreur `FirebaseAppError: The default Firebase app does not exist`). `getFirestore()` est maintenant appelé à l'intérieur de la fonction (lazy).
- `npm run build` → OK, `firebase deploy --only functions:translatePostDescription` → **déployé avec succès** sur `us-central1` (projet `afrolooki`).
- Rappel : l'**API Cloud Translation** doit être activée dans la console GCP pour que la fonction réponde correctement à l'exécution.

**Ajout de 6 langues d'interface (en plus de FR/EN)** : espagnol (es), allemand (de), arabe (ar), portugais (pt), chinois (zh), swahili (sw) — choisies pour couvrir les langues les plus parlées au monde et la diaspora africaine.

- `lib/l10n/app_localizations.dart` : refonte complète — toutes les ~150 chaînes converties du système binaire `_lang == 'fr' ? X : Y` vers une map `_t({'fr':..., 'en':..., 'es':..., 'de':..., 'ar':..., 'pt':..., 'zh':..., 'sw':...})` avec repli sur FR. Ajout de la constante exportée `kSupportedLocales` (code ISO → libellé avec drapeau) et nouvelles clés `langSpanish`/`langGerman`/`langArabic`/`langPortuguese`/`langChinese`/`langSwahili`. `_AppLocalizationsDelegate.isSupported` utilise désormais `kSupportedLocales`.
- `lib/providers/locale_provider.dart` : `setLocale`/`_loadLocale` valident via `kSupportedLocales` (8 langues au lieu de 2) ; nouvelle méthode `cycleLocale()` pour le sélecteur rapide de la barre du haut.
- `lib/main.dart` (ligne ~359) : `supportedLocales` généré dynamiquement depuis `kSupportedLocales`.
- `lib/pages/home/homeScreen.dart` : 
  - Sélecteur de langue du menu latéral (~ligne 497-534) : remplace le toggle FR/EN par un bottom sheet `_showLanguagePicker()` listant les 8 langues avec coche sur la langue active.
  - Petit sélecteur "drapeau" de la barre du haut (~ligne 1653-1666) : tap ouvre le même bottom sheet, appui long fait défiler les langues via `cycleLocale()`.
  - Nouvelle méthode privée `_showLanguagePicker()` (~ligne 2049) ajoutée juste avant `_onTopBarRefreshTap()`.

**Note importante** : la traduction des descriptions de posts (Session 19) utilise déjà `Provider.of<LocaleProvider>(context).locale.languageCode` comme `targetLang` envoyé à `translatePostDescription` — Google Translate supportant ~130 langues, **aucune modification de la Cloud Function n'était nécessaire** pour que la traduction des posts fonctionne dans ces 6 nouvelles langues.

**Vérification** : `flutter analyze` sur les 4 fichiers modifiés → **0 nouvelle erreur** (164 issues, toutes pré-existantes : `unused_field`, `avoid_print`, `prefer_const_constructors`, etc., + 1 warning pré-existant `depend_on_referenced_packages` sur `shared_preferences` déjà présent avant cette session).

---

## Session 21 — Ajout du bouton de traduction dans les pages de détails de post

Complète l'intégration de `TranslatableDescription` (Session 19) dans les pages de détails restantes.

- `lib/pages/postDetails.dart` :
  - Imports ajoutés (après `import '../theme/app_colors.dart';`) : `providers/locale_provider.dart` et `userPosts/postWidgets/translatable_description.dart`.
  - Nouvel état `String? _translatedDescription` (déclaré juste après `bool _isExpanded = false;`).
  - Les usages de `post.description` aux lignes ~292 et ~711 (miniatures de posts suggérés) et ~1409-1411 (en-tête lecteur audio) sont des aperçus/miniatures distincts du post — **non modifiés**, conformément à la consigne (éviter les doublons).
  - L'affichage principal/complet de la description se fait dans `_buildPostContent()` / `_buildTextContent()` (texte récupéré via `final text = _translatedDescription ?? post.description ?? "";`). Un `TranslatableDescription` est ajouté juste après le `_buildTextContent(text)` dans la branche "contenu déverrouillé", avec `onToggle: (t) => setState(() => _translatedDescription = t)` et `targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode`.

- `lib/pages/postDetailsVideo.dart` :
  - Imports ajoutés (après `import '../theme/app_colors.dart';`) : `providers/locale_provider.dart` et `userPosts/postWidgets/translatable_description.dart`.
  - Nouvel état `final Map<String, String> _translatedDescriptions = {}` (déclaré juste après `bool _isDescriptionExpanded = false;`), indexé par `_currentPost.id` car la page affiche un feed de vidéos avec suggestions/swipe (même pattern que `post_video_format_tel_details.dart`).
  - Dans `_buildExpandableDescription()` (~ligne 645-700), un `TranslatableDescription` est ajouté en fin de `Column`, avec `postId: _currentPost.id!`, `text: _currentPost.description!`, et `onToggle` qui met à jour/supprime l'entrée de `_translatedDescriptions` pour `_currentPost.id`.
  - L'appel à `_buildExpandableDescription(_currentPost.description!)` (~ligne 1728-1731) est modifié pour passer `_translatedDescriptions[_currentPost.id] ?? _currentPost.description!`.
  - Ligne ~1335 (`post.description` dans la liste des vidéos suggérées, miniatures) — **non modifiée**, c'est un aperçu distinct.

**Vérification** : `flutter analyze lib/pages/postDetails.dart lib/pages/postDetailsVideo.dart` → **0 nouvelle erreur** (713 issues au total, toutes pré-existantes : `prefer_const_constructors`, `deprecated_member_use` (`withOpacity`), `avoid_print`, `use_build_context_synchronously`, `unused_element` (`_handleSupportAd`), `sized_box_for_whitespace`, `prefer_const_literals_to_create_immutables`, etc.).

---

## Session 21 (partie 1) — Thème dynamique + traduction des écrans d'accueil / inscription

Application du thème dynamique (`AppColors.of(context)`) et de la traduction (`AppLocalizations.of(context)`) aux écrans Welcome et Signup (étape 1) qui utilisaient des couleurs codées en dur (noir, blanc, gris) et du texte français en dur.

- `lib/pages/auth/authTest/Screens/Welcome/welcome_screen.dart` :
  - Imports ajoutés : `../../../../../theme/app_colors.dart` et `../../../../../l10n/app_localizations.dart`.
  - Suppression des constantes `darkBackground` et `textColor` (remplacées par `AppColors.of(context)`).
  - Fond du `Scaffold` (gradient) → `colors.background` / `colors.surface`.
  - Bouton "Se connecter" → texte `l10n.authSignIn` ; bouton "Créer un compte" → `l10n.authSignUp`, fond `colors.surface.withOpacity(0.4)`.
  - Bloc revenus : titre → `l10n.welcomeIncomeTitle`, description → `l10n.welcomeIncomeDesc`, fond `colors.surface.withOpacity(0.4)`, texte → `colors.textPrimary`.
  - Message de soutien : `l10n.welcomeSupportTitle` / `l10n.welcomeSupportDesc`, couleur secondaire → `colors.textSecondary`.
  - Texte d'accroche du bas → `l10n.welcomeTagline`, couleur → `colors.textSecondary`.
  - Suppression de l'import inutilisé `signup_screen.dart`.

- `lib/pages/auth/authTest/Screens/Welcome/components/welcome_image.dart` :
  - Imports ajoutés (`../../../../../../theme/app_colors.dart`, `../../../../../../l10n/app_localizations.dart`), suppression de l'import inutilisé `flutter_svg`.
  - `Colors.black54` → `colors.surface.withOpacity(0.6)`.
  - Texte "Bienvenue chez Afrolook" → `l10n.welcomeBienvenue`.

- `lib/pages/auth/authTest/Screens/Signup/components/signup_form.dart` :
  - Imports ajoutés (`../../../../../../theme/app_colors.dart`, `../../../../../../l10n/app_localizations.dart`), suppression des constantes `darkBackground`, `lightBackground`, `textColor`.
  - `backgroundColor` du `Scaffold` → `colors.background`.
  - Titre "Créer un compte" → `l10n.signupCreateAccountTitle`, sous-titre "Rejoignez la communauté Afrolook" → `l10n.signupJoinCommunity`, couleurs → `colors.textPrimary` / `colors.textSecondary`.
  - Champ téléphone (`IntlPhoneField`) : fond → `colors.surface`, hint/texte → `l10n.signupPhoneHint` / `colors.textSecondary` / `colors.textPrimary`, message de validation → `l10n.signupPhoneRequired`.
  - `_buildTextField` et `_buildPasswordField` : ajout du paramètre `context`, couleurs (`fillColor`, `hintStyle`, `style`) basées sur `AppColors.of(context)`.
  - Champs code parrainage / email / pseudo / mot de passe / confirmation : hints et messages de validation remplacés par `l10n.signupReferralCodeOptional`, `l10n.authEmail`, `l10n.signupEmailRequired`, `l10n.signupEmailInvalidShort`, `l10n.signupPseudoUnique`, `l10n.signupPseudoRequired`, `l10n.signupPseudoTooShort`, `l10n.signupPasswordHint`, `l10n.signupConfirmPasswordHint`, `l10n.signupPasswordRequired`, `l10n.signupPasswordTooShort`, `l10n.signupConfirmPasswordRequired`, `l10n.signupPasswordsDontMatch`.
  - Sélecteur de genre : fond/texte via `colors.surface`/`colors.textPrimary`/`colors.textSecondary`, libellés "Homme"/"Femme" affichés via `l10n.signupGenreMale`/`l10n.signupGenreFemale` (valeurs internes `genres` inchangées), validation → `l10n.signupGenreRequired`.
  - SnackBar "Le pseudo existe déjà" → `l10n.signupPseudoExists`.
  - Bouton "Suivant" → `l10n.signupNext`.
  - Lien "Vous avez déjà un compte? / Connectez-vous" → `l10n.signupAlreadyHaveAccount` / `l10n.signupLoginLink`, couleur secondaire → `colors.textSecondary`.

- `lib/pages/auth/authTest/Screens/Signup/components/sign_up_top_image.dart` :
  - Imports ajoutés (`../../../../../../theme/app_colors.dart`, `../../../../../../l10n/app_localizations.dart`).
  - Texte "S'inscrire" → `l10n.signupRegister.toUpperCase()`, couleur → `colors.textPrimary`.

- `lib/pages/auth/authTest/Screens/Signup/components/socal_sign_up.dart` : fichier entièrement commenté, **aucune modification** (rien à thématiser/traduire dans du code mort).

- `lib/pages/auth/authTest/Screens/Signup/components/or_divider.dart` :
  - Imports ajoutés (`../../../../../../theme/app_colors.dart`, `../../../../../../l10n/app_localizations.dart`).
  - Texte "OR" → `l10n.commonOr.toUpperCase()`.
  - Couleur du `Divider` (`Color(0xFFD9D9D9)`) → `colors.divider`.

- `lib/pages/auth/authTest/Screens/Signup/verificationOtps.dart` :
  - Imports ajoutés (`../../../../../theme/app_colors.dart`, `../../../../../l10n/app_localizations.dart`).
  - `backgroundColor: Colors.white` → `colors.background`.
  - "Verification de Code" → `l10n.otpVerificationTitle`, couleur → `colors.textPrimary`.
  - Texte d'instruction (avec numéro de téléphone) → `"${l10n.otpVerificationDesc} ${widget.phoneNumber}"`, couleur → `colors.textSecondary`.
  - "resend code" → `l10n.otpResendCode`, "Vérifier" → `l10n.otpVerify`, couleurs (`Colors.blue`) → `colors.primary`/`colors.onPrimary`.
  - Dialogues : "Ce compte existe déjà" → `l10n.otpAccountExists`, "Vérification réussie" → `l10n.otpVerificationSuccess`, "Erreur de verification" → `l10n.otpVerificationError`.

- `lib/l10n/app_localizations.dart` : nouvelles clés ajoutées après `signupAlreadyAccount` (section "Welcome / Signup étendu (Session 21)"), traduites en fr/en/es/de/ar/pt/zh/sw :
  `welcomeTagline`, `welcomeIncomeTitle`, `welcomeIncomeDesc`, `welcomeSupportTitle`, `welcomeSupportDesc`, `welcomeBienvenue`, `signupCreateAccountTitle`, `signupJoinCommunity`, `signupPhoneHint`, `signupPhoneRequired`, `signupReferralCodeOptional`, `signupEmailRequired`, `signupEmailInvalidShort`, `signupPseudoUnique`, `signupPseudoRequired`, `signupPseudoTooShort`, `signupPseudoExists`, `signupGenreLabel`, `signupGenreMale`, `signupGenreFemale`, `signupGenreRequired`, `signupPasswordHint`, `signupConfirmPasswordHint`, `signupPasswordRequired`, `signupPasswordTooShort`, `signupConfirmPasswordRequired`, `signupPasswordsDontMatch`, `signupNext`, `signupAlreadyHaveAccount`, `signupLoginLink`, `otpVerificationTitle`, `otpVerificationDesc`, `otpResendCode`, `otpVerify`, `otpAccountExists`, `otpVerificationSuccess`, `otpVerificationError`, `otpWrongCode`.

**Vérification** : `flutter analyze` sur les 7 fichiers modifiés (+ `app_localizations.dart`) → **0 nouvelle erreur**. Seuls subsistent des warnings/infos pré-existants (`unused_catch_clause` dans `signup_form.dart` ligne 61, `prefer_const_constructors`, `deprecated_member_use` (`withOpacity`, `WillPopScope`), `use_build_context_synchronously`, `non_constant_identifier_names`, `unused_local_variable`, `unnecessary_non_null_assertion`).

---

## Session 21 (partie 2) — Thème dynamique et traduction de l'inscription étape 2

Application du thème adaptatif (`AppColors.of(context)`) et de la traduction (`AppLocalizations.of(context)`) à `lib/pages/auth/authTest/Screens/Signup/signup_up_form_step_2.dart` (formulaire de finalisation de profil après l'inscription : photo de profil, adresse, "à propos", validation et création du compte).

- Imports ajoutés : `import '../../../../../theme/app_colors.dart';` et `import '../../../../../l10n/app_localizations.dart';` (même profondeur relative que `Login/loginPageUser.dart`).
- Ajout des champs d'état `late AppColors _colors;` et `late AppLocalizations l10n;`, initialisés en tête de `build()`.
- Suppression des constantes couleur codées en dur devenues inutiles (`darkBackground`, `lightBackground`, `textColor`) ; `primaryGreen` conservé (utilisé pour les accents de la photo de profil et liens).
- Remplacements de couleurs :
  - `Scaffold.backgroundColor` et fond du modal de vérification email → `_colors.background`.
  - Titres et textes principaux (AppBar, "Votre photo de profil", "À propos de vous") → `_colors.textPrimary`.
  - Champs de formulaire (`_buildTextField`, `_buildAboutSection`) : `fillColor`/`color` du conteneur → `_colors.surface`, `hintStyle` → `_colors.textSecondary`.
  - Bouton "S'inscrire" et bouton "J'ai compris" du modal → `_colors.primary`, texte/icônes correspondants → `_colors.onPrimary`.
  - Bordure du bouton caméra (photo de profil) → `_colors.background` (anciennement `darkBackground`).
  - Icônes/textes de statut : succès → `_colors.success`, avertissement (email à vérifier) → `_colors.warning`, erreurs (SnackBars) → `_colors.danger`.
  - Textes secondaires (mentions légales, "Vous avez déjà un compte ?", placeholders) → `_colors.textSecondary`.
- Traduction (FR par défaut, 8 langues) : tous les textes affichés (titre AppBar, libellés de champs, placeholders, messages de validation, SnackBars de succès/erreur, contenu du modal de vérification email, messages d'erreur Firebase Auth) remplacés par `l10n.xxx`.

**Nouvelles clés l10n ajoutées** (section `// ── Inscription (étape 2) ──` à la fin de `lib/l10n/app_localizations.dart`, avant `_AppLocalizationsDelegate`) : `signupStep2Title`, `signupProfilePhoto`, `signupImageSelected`, `signupImageSelectedSuccess`, `signupImageSelectError`, `signupAddress`, `signupAddressRequired`, `signupAboutYou`, `signupAboutYouHint`, `signupTermsAcceptance`, `signupSelectProfilePhoto`, `signupImageTooLarge`, `signupCodeParrainInvalid`, `signupAccountCreatedSuccess`, `signupOneStepLeft`, `signupVerificationEmailSentTo`, `signupCheckSpamFolder`, `signupUnderstood`, `signupNoImageSelected`, `signupImageUploadFailed`, `signupVerificationEmailSendError`, `signupErrorInvalidEmail`, `signupErrorWrongPassword`, `signupErrorEmailInUse`, `signupErrorUserNotFound`, `signupErrorUserDisabled`, `signupErrorTooManyRequests`, `signupErrorOperationNotAllowed`, `signupErrorWeakPassword`, `signupErrorUndefined`, `signupErrorFirebase`, `signupErrorUnexpected`. Réutilisation des clés existantes `signupRegister` ("S'inscrire"), `signupAlreadyHaveAccount` et `signupLoginNow` (ajoutées en partie 1, déjà disponibles ; une définition en double ajoutée par erreur a été automatiquement commentée pour éviter `duplicate_definition`).

**Logique métier** : inchangée (validation de formulaire, navigation, appels Firebase Auth/Firestore/Storage, `setState`, `Provider`).

**Vérification** : `flutter analyze lib/pages/auth/authTest/Screens/Signup/signup_up_form_step_2.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur** (45 issues, toutes pré-existantes : `avoid_print`, `prefer_const_constructors`, `use_build_context_synchronously`, `unused_field` (`_currentAddress`, `_currentPosition`), `unused_local_variable` (`notif`), `unnecessary_non_null_assertion`, `depend_on_referenced_packages`/`library_prefixes` sur l'import `path`, `sized_box_for_whitespace`).

---

## Session 22 — Optimisation requêtes amis/conversations + présence + thème/traduction

### `lib/pages/user/amis/mesAmis.dart`
- **Optimisation majeure de `getFriendsData()`** : remplacement de l'ancienne implémentation N+1 (une requête Firestore `Users` par ami, dans une boucle `await for`, ce qui rendait le chargement très lent avec beaucoup d'amis) par :
  - Une seule écoute du flux `Friends` (current_user_id OU friend_id == utilisateur courant).
  - Récupération groupée des profils `Users` via des requêtes `whereIn` par lots de 10, exécutées **en parallèle** (`Future.wait`), comme dans `_loadRecentFriends()` de `listUserConv.dart`.
  - Déduplication par pseudo conservée. Résultat : chargement de la liste d'amis en quelques secondes au lieu de potentiellement plusieurs dizaines de secondes.
- **Widget `Monami(Friends amigo)` réécrit** :
  - Remplacement de l'ancien indicateur de présence (StreamBuilder + cercle coloré custom) par `UserPresenceWidget(userId: friendId, size: 14.0, showTextStatus: false)` — même composant que `listUserConv.dart`, pour une présence cohérente dans toute l'app.
  - Couleurs codées en dur (`Colors.white`, `Colors.grey.shade600`, `Colors.green`) → `AppColors.of(context)` (`textPrimary`, `textSecondary`, `primary`).
  - Texte "abonné(s)" → `l10n.amiSubscribers`.
- **`searchListDialogue()`** : `AlertDialog` themé (`colors.surface`), titre "Liste d'amis" → `l10n.amiListTitle`, "vide" → `l10n.amiListEmpty`, label de recherche "Amis" → `l10n.amiSearchLabel`, bordures `Colors.blue`/`fillColor: Colors.white` → `colors.primary`/`colors.surfaceVariant`, "Fermer" → `l10n.amiClose`.

### `lib/pages/user/conversation/listUserConv.dart`
- Ajout de l'import `AppLocalizations` et du champ `late AppLocalizations _l10n;` (initialisé dans `build()` des deux State : `_ListUserChatsOptimizedState` et `_ConversationListState`).
- Toutes les chaînes françaises codées en dur traduites en 8 langues (fr/en/es/de/ar/pt/zh/sw) : messages d'erreur/retry, placeholder de recherche, titre "Conversations", section "RÉCEMMENT ACTIFS"/"Voir plus d'amis", statut "En ligne"/temps relatifs (réutilisation de `notifMinutesAgo`/`notifHoursAgo`/`notifDaysAgo`), "MESSAGES", pseudo de repli "Utilisateur", placeholders de recherche, "Aucun message"/"🎤 Message audio", états vides ("Aucune conversation", "Aucun résultat trouvé", etc.), "Vous: "/"écrit...", formats de temps courts (`Xj`/`Xh`/`Xmin`/"À l'instant").
- Couleurs codées en dur (`Colors.white`, `Colors.red`, `Colors.grey[900]`/`[800]`) → `AppColors.of(context)` (`textPrimary`, `danger`, `surfaceVariant`, `border`).

### `lib/l10n/app_localizations.dart`
Nouvelles sections de clés ajoutées (toutes traduites fr/en/es/de/ar/pt/zh/sw) :
- **Page Amis** : `amiSubscribers`, `amiListTitle`, `amiListEmpty`, `amiSearchLabel`, `amiClose`.
- **Page liste des conversations** : `convErrorLoading`, `convRetry`, `convErrorOpeningChat`, `convSearchHint`, `convTitle`, `convRecentlyActive`, `convSeeMoreFriends`, `convOnline`, `convJustNow`, `convJustNowCap`, `convMessagesTitle`, `convDefaultUser`, `convTypeToSearch`, `convStartConversation`, `convNoMessage`, `convVoiceMessage`, `convEmptyTitle`, `convEmptySubtitle`, `convSeeMyFriends`, `convNoResults`, `convTryOtherTerms`, `convDaysShort`, `convHoursShort`, `convMinutesShort`, `convYouPrefix`, `convTyping`.

**Vérification** : `flutter analyze lib/pages/user/amis/mesAmis.dart lib/pages/user/conversation/listUserConv.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur** (uniquement warnings/infos pré-existants : imports inutilisés, `prefer_const_constructors`, `unnecessary_non_null_assertion`).

**Reste à faire (hors scope de cette session)** : `lib/pages/user/amis/addListAmis.dart` est une page "Découvrir" avec un thème sombre/doré codé en dur (pas de `AppColors`, pas de `UserPresenceWidget`) — son intégration au thème/traduction/présence représenterait une réécriture séparée plus conséquente.

---

## Session 23 — Chat (myChat.dart) : Phase 1 performance/fluidité (cache local, pagination, lecture en batch)

Objectif : page de chat plus fluide façon WhatsApp, en évitant de retélécharger tout l'historique de la conversation à chaque ouverture/écriture.

### Nouveau service `lib/services/chat_cache_service.dart`
- `ChatCacheService` (SharedPreferences, même approche que `FeedCacheService`) : sauvegarde/charge les ~60 derniers messages d'une conversation en JSON local (`chat_messages_{chatId}`).
- Sérialisation "cache-safe" : retire les champs `Duration` non sérialisables (`voice_message_duration`, `reply_message.voiceMessageDuration`) avant `jsonEncode` ; ils sont de toute façon rafraîchis par le flux Firestore.

### `lib/pages/chat/myChat.dart`
- **Affichage instantané depuis le cache** (`_loadCachedMessages()`) : à l'ouverture du chat, les derniers messages connus sont affichés immédiatement (depuis SharedPreferences) pendant que le flux Firestore se (re)connecte — plus d'écran vide/spinner à chaque ouverture.
- **Requête Firestore fenêtrée** : `_loadMessages()` utilise désormais `.limitToLast(_pageSize)` (30) au lieu de récupérer tout l'historique. Le flux ne renvoie donc que la fenêtre récente, quel que soit le nombre total de messages de la conversation.
- **Pagination des messages plus anciens** (`_loadMoreMessages()`) : déclenchée quand l'utilisateur remonte en haut de la liste (`_onScroll`, seuil 200px). Requête ponctuelle (`.get()`, pas de listener) `where('createdAt', isLessThan: <plus ancien message affiché>).limitToLast(_pageSize)`. Position de scroll préservée (calcul du delta de `maxScrollExtent` avant/après insertion) pour éviter le "saut" visuel.
- **Fusion des sources** (`_mergeMessages()`) : combine les messages paginés (`_olderMessages`) et la fenêtre récente du flux (`_streamMessages`), dédupliqués par `id`, triés par `create_at_time_spam`.
- **Marquage "lu" en batch** (`_scheduleReadReceipts()`) : suppression de l'écriture Firestore par message *dans `itemBuilder`* (qui pouvait déclencher une écriture à chaque frame/rebuild). Remplacé par une détection des messages non lus après réception du snapshot, puis une seule écriture groupée (`WriteBatch`) après un debounce de 500 ms.
- **Cache mis à jour automatiquement** : à chaque nouvelle donnée du flux, `ChatCacheService.saveMessages()` est appelé (fire-and-forget) pour garder le cache local synchronisé.
- Indicateur de chargement discret en haut de la liste pendant la pagination (`_isLoadingMore`).
- "Erreur de chargement" / "Aucun message" → réutilisation des clés `l10n.convErrorLoading` / `l10n.convNoMessage` (déjà ajoutées en Session 22), couleurs codées en dur (`Colors.white`/`Colors.grey`/`Colors.green`) → `AppColors`.

**Note Firestore** : aucune nouvelle règle d'index requise — `limitToLast` et le filtre `createdAt <` réutilisent l'index composite déjà nécessaire à la requête `orderBy('createdAt')` existante.

**Logique métier inchangée** : envoi de texte/image/audio, réactions, réponses, lecteur audio, notifications — non modifiés. Firestore applique déjà la "latency compensation" (les messages envoyés apparaissent immédiatement via le cache local du SDK avant confirmation serveur), donc pas de gestion manuelle d'état "optimiste" ajoutée pour cette phase.

**Vérification** : `flutter analyze lib/pages/chat/myChat.dart lib/services/chat_cache_service.dart` → **0 nouvelle erreur** (78 issues, toutes pré-existantes ou identiques au pattern de `feed_cache_service.dart` : `depend_on_referenced_packages` (shared_preferences), `avoid_print`, `prefer_const_constructors`, `use_build_context_synchronously`, `deprecated_member_use`).

**Phase 3 (à venir)** : chiffrement des messages "au repos" — Option A retenue (clé AES-256 symétrique par conversation, chiffrée par participant avec sa clé publique, stockage de la clé privée via `flutter_secure_storage`). À traiter dans une session dédiée, après validation de cette base de cache/pagination.

---

## Session 24 — Chat (myChat.dart) : Phase 2 UI façon WhatsApp (séparateurs de date, regroupement, coches de lecture)

### `lib/l10n/app_localizations.dart`
- Nouvelles clés : `chatToday` ("Aujourd'hui"), `chatYesterday` ("Hier") — pour les séparateurs de date, traduites dans les 8 langues.

### `lib/pages/chat/myChat.dart`
- **Séparateurs de date** : `_buildDateSeparator()` + `_formatDateSeparator()` insèrent un badge centré ("Aujourd'hui" / "Hier" / `dd/MM/yyyy`) entre les groupes de messages de jours différents.
- **Regroupement visuel des messages** (`_buildMessageList`) : construit une liste plate `_ChatListItem` (séparateur de date ou message + flags `isFirstInGroup`/`isLastInGroup`). Deux messages consécutifs du même expéditeur, le même jour, à moins de 2 min d'écart (`_groupingThresholdMs`) sont regroupés : marge réduite entre eux, avatar affiché une seule fois (sur le dernier message du groupe) au lieu d'être répété sur chaque message.
- **Heure des messages** : `_formatMessageTime()` affiche désormais `HH:mm` sous chaque message (au lieu de "il y a X min"), comme WhatsApp. L'ancienne fonction `_formatDateTime` (temps relatif) est supprimée — elle n'était utilisée que pour cet affichage.
- **Coches de lecture** (`_buildMessageStatus`) : pour les messages envoyés par l'utilisateur, une coche simple (gris) = envoyé/non lu (`NONLU`), coches doubles colorées (`_colors.primary`) = lu (`LU`). Pour les messages reçus, pas de coche (uniquement l'heure), comme sur WhatsApp.

**Logique métier inchangée** : pagination/cache (Phase 1), envoi de messages, réactions, réponses, audio — non modifiés.

**Vérification** : `flutter analyze lib/pages/chat/myChat.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur** (75 issues, toutes info/warning pré-existantes : `prefer_const_constructors`, `use_build_context_synchronously`, etc.).

**Phase 3 (à venir)** : chiffrement des messages au repos (Option A — clé AES-256 par conversation).

---

## Session 25 — Chat (myChat.dart) : Phase 3 chiffrement des messages texte au repos (Option A simplifiée)

Objectif : que le contenu des messages texte ne soit plus stocké en clair dans Firestore, façon messagerie sécurisée.

### Nouvelles dépendances (`pubspec.yaml`)
- `cryptography: ^2.7.0` (X25519, AES-256-GCM, HKDF)
- `flutter_secure_storage: ^9.2.2` (stockage de la clé privée sur l'appareil)

### Nouveau service `lib/services/encryption_service.dart`
- **Paire de clés par utilisateur** : à la première utilisation, génère une paire X25519 ; la clé privée est stockée dans `flutter_secure_storage` (jamais transmise), la clé publique est publiée dans `UserKeys/{userId}.public_key`.
- **Clé de conversation dérivée** (`getChatKey`) : pour un chat entre A et B, calcule le secret partagé Diffie-Hellman `ECDH(privA, pubB) == ECDH(privB, pubA)`, puis dérive (HKDF-SHA256, salé par `chatId`) une clé AES-256 propre à cette conversation. Mise en cache mémoire par `chatId`. Retourne `null` si l'autre participant n'a pas encore de clé publique publiée (1ère connexion sur l'app côté destinataire) — dans ce cas les messages restent en clair jusqu'à ce que sa clé soit disponible.
- **`encryptText`/`decryptText`** : AES-256-GCM, sortie encodée en base64 préfixée `enc:v1:`. Les anciens messages (non préfixés) sont retournés tels quels par `decryptText` — compatibilité rétroactive automatique.

### `lib/models/chatmodels/message.dart`
- Ajout du champ `is_encrypted` (bool, défaut `false`) à `Message`, lu/écrit dans `toJson`/`fromJson`.

### `lib/pages/chat/myChat.dart`
- Nouveau champ `_chatKey` (clé de chiffrement de la conversation, calculée une fois via `_initEncryptionAndLoad()` avant de démarrer le flux de messages).
- **Envoi** (`_sendTextMessage`) : si `_chatKey` est disponible, le texte est chiffré (`EncryptionService.encryptText`) avant l'écriture Firestore, et `is_encrypted: true` est ajouté au document.
- **Réception** (`_loadMessages`/`_loadMoreMessages`) : `_decryptMessages()` déchiffre en place le champ `message` de tout message marqué `is_encrypted`, avant affichage/mise en cache.
- **Portée** : seul le **texte des messages** (`messageType == text`) est chiffré dans cette phase. Les URLs d'images/audio (Firebase Storage, déjà protégées par les règles d'accès) et les aperçus de réponse ne sont pas chiffrés — amélioration possible ultérieure si besoin.

**Action de déploiement requise** : ajouter une règle Firestore pour la collection `UserKeys` (lecture authentifiée de n'importe quel document — nécessaire pour résoudre la clé publique de l'autre participant —, écriture limitée à `request.auth.uid == userId`).

**Vérification** : `flutter analyze lib/pages/chat/myChat.dart lib/services/encryption_service.dart lib/models/chatmodels/message.dart` → **0 nouvelle erreur** (96 issues, toutes `prefer_const_constructors`/`use_build_context_synchronously`/`avoid_print`, cohérentes avec le reste du projet). `flutter pub get` exécuté avec succès (nouvelles dépendances résolues).

**Phases 1-2-3 terminées.** Chat désormais : paginé/caché (Phase 1), façon WhatsApp (séparateurs de date, regroupement, coches) (Phase 2), messages texte chiffrés au repos (Phase 3).

---

## Session 26 — Corrections : sélecteur de langue (overflow) + amis "Récemment actifs"

### `lib/pages/home/homeScreen.dart`
- `_showLanguagePicker` : la liste des 8 langues débordait en bas de l'écran (erreur "bottom overflowed by X pixels"). La feuille modale est maintenant bornée à 70% de la hauteur d'écran (`ConstrainedBox`) avec la liste des langues dans un `Flexible` + `ListView` scrollable.

### `lib/pages/user/conversation/listUserConv.dart`
- Section "Récemment actifs" (page des conversations) : elle prenait simplement les 7 amis triés par `last_time_active` décroissant, même si ceux-ci n'étaient plus connectés depuis des mois (faute d'amis réellement actifs récemment).
- Ajout d'un filtre `_recentActiveThresholdMs` (7 jours) : seuls les amis connectés au cours des 7 derniers jours sont éligibles avant le tri/`take(7)`. La section reste masquée si aucun ami n'est récemment actif (`_recentFriends.isEmpty`, comportement déjà existant).

**Vérification** : `flutter analyze` sur les 2 fichiers → 0 nouvelle erreur.

---

## Session 27 — Thème clair/sombre sur la page des commentaires (PostComments)

### `lib/pages/postComments.dart`
- La page des commentaires d'un post (`PostComments`) utilisait encore de nombreuses couleurs codées en dur (`Colors.white`, `Colors.grey.shade*`, `Colors.blue.shade*`, `Colors.black87`, `Colors.red`...), non adaptées au mode sombre.
- Remplacement par `AppColors.of(context)` (`_colors`) :
  - **Champ de saisie** (`_buildCommentInput`) : fond `_colors.surface`, bordure `_colors.divider`, zone de texte `_colors.surfaceVariant` avec texte/placeholder via `_colors.textPrimary`/`_colors.textSecondary`, bandeau "Réponse à ..." et icône d'envoi en `_colors.primary`.
  - **Affichage des commentaires et réponses** (`_buildCommentItem`, `_buildCommentContent`, `_buildReplyContent`) : fonds (`_colors.surface` / `_colors.surfaceVariant`), avatars de secours, pseudos et dates (`_colors.textPrimary`/`_colors.textSecondary`), liens "Lire tout"/"Voir réponses" en `_colors.primary`, icônes like/répondre en `_colors.textSecondary`, cœur actif et suppression en `_colors.danger`.
  - **Suggestions de mentions** (`_buildUserSuggestions`) : fond `_colors.surface`, texte `_colors.textPrimary`, lien "Charger plus" en `_colors.primary`.

**Vérification** : `flutter analyze lib/pages/postComments.dart` → **0 nouvelle erreur** (90 issues, toutes pré-existantes : `prefer_const_constructors`/`avoid_print`/`use_build_context_synchronously`/`unnecessary_non_null_assertion`).

---

## Session 28 — En-tête du chat : thème clair + badge de certification

### `lib/pages/chat/myChat.dart`
- En-tête de conversation (`_buildChatHeader`) : le pseudo était affiché en `Colors.white`, illisible en mode clair. Remplacé par `_colors.textPrimary`.
- Ajout du badge de certification/abonnement à côté du pseudo via le widget existant `AbonnementUtils.getUserBadge` (réutilisé tel quel, déjà utilisé sur les autres pages).

### `lib/pages/home/user_presence_widget.dart`
- Mode `isChatHeader` : le texte de statut "Hors ligne / En ligne il y a..." utilisait `Colors.grey[400]`, peu visible en mode clair. Remplacé par `AppColors.of(context).textSecondary` (le statut "En ligne" reste en vert).

**Vérification** : `flutter analyze lib/pages/chat/myChat.dart lib/pages/home/user_presence_widget.dart` → **0 nouvelle erreur** (78 issues, toutes pré-existantes : `prefer_const_constructors`/`deprecated_member_use` (`withOpacity`)).

---

## Session 29 — Défilement vidéo plus sensible (façon TikTok)

### `lib/pages/post_video_format_tel_details.dart`
- Le `PageView` vertical des vidéos nécessitait un glissement d'environ 50% de l'écran (comportement par défaut de `PageView`) pour passer à la vidéo suivante — trop lourd comparé à TikTok.
- Ajout d'une physique de défilement personnalisée `_TikTokPageScrollPhysics` (remplace `BouncingScrollPhysics`) :
  - un **flick** (geste rapide), même très court, fait toujours avancer/reculer d'une vidéo ;
  - un **glissement lent** valide le changement dès que ~12% de la hauteur d'écran est parcouru (`_commitThreshold = 0.12`), au lieu de 50%.

**Vérification** : `flutter analyze lib/pages/post_video_format_tel_details.dart` → **0 nouvelle erreur** (106 issues, toutes pré-existantes : `prefer_const_constructors`/`deprecated_member_use`/`use_build_context_synchronously`/variables non utilisées).

---

## Session 30 — Page de profil utilisateur (UserProfil) : thème clair/sombre + traductions

### `lib/pages/user/profile/profile.dart`
- Ajout des imports `AppLocalizations` et `AppColors`, et initialisation de `_colors`/`l10n` dans `build()`.
- Remplacement des constantes de couleurs codées en dur par leurs équivalents `AppColors.of(context)` : fond principal (`_colors.background`), cartes/boutons de menu (`_colors.surfaceVariant`), bordures (`_colors.border`), séparateurs (`_colors.divider`), texte principal/secondaire (`_colors.textPrimary`/`_colors.textSecondary`).
- Libellé des boutons de menu (`_buildMenuButton`) : texte passé de `Color(0xFFF5F5F5)` (blanc fixe) à `_colors.textPrimary`.
- Écran de chargement temporaire affiché lors de la navigation vers "Entreprise" : fond `Colors.white` → `_colors.background`.
- Traduction de tous les libellés (titre de page, "Abonnés", "Likes", "Mes Looks", boutons de menu : Mes Infos, Entreprise, Monétisations, Abonnement, Favoris, Canaux, Publicité, ainsi que les entrées admin AppData/Challenge/Contacts/Pub/Emailing/Pronostique/Afrolove) et de la boîte de dialogue de création d'entreprise (titre, description, bouton, message d'erreur).

### `lib/l10n/app_localizations.dart`
- Ajout d'environ 20 nouvelles clés de traduction (fr/en/es/de/ar/pt/zh/sw) : `profileLikesShort`, `profileMyLooks`, `profileMenuMyInfos`, `profileMenuEnterprise`, `profileMenuMonetization`, `profileMenuSubscription`, `profileMenuFavorites`, `profileMenuChannels`, `profileMenuAds`, `profileMenuAppData`, `profileMenuChallenge`, `profileMenuContacts`, `profileMenuPub`, `profileMenuEmailing`, `profileMenuPronostic`, `profileMenuAfrolove`, `profileEnterpriseCreateTitle`, `profileEnterpriseCreateDesc`, `profileEnterpriseCreateBtn`, `profileEnterpriseLoadError`.

**Vérification** : `flutter analyze lib/pages/user/profile/profile.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur** (69 issues, toutes pré-existantes : `prefer_const_constructors`/`deprecated_member_use`/`use_build_context_synchronously`/`unnecessary_non_null_assertion`/etc.).

---

## Session 31 — Refonte de l'espace rémunération (RemunerationHomePage)

### `lib/pages/user/remuneration_home_page.dart`
- Ancien design : fond en dégradé fixe noir/rouge/or, textes et icônes en couleurs codées en dur, non adapté aux modes clair/sombre et non traduit.
- Refonte complète de l'UI pour reprendre la charte graphique de l'application (`AppColors` : fonds `_colors.background`/`_colors.surface`/`_colors.surfaceVariant`, bordures `_colors.border`, textes `_colors.textPrimary`/`_colors.textSecondary`, accent vert `_colors.primary`) :
  - `AppBar` avec titre et chip de solde adaptés au thème.
  - Cartes de rémunération (`_buildRemunerationCard`) : design unifié en cartes `_colors.surface` avec icône colorée (vert pour le compte principal, jaune/accent pour les posts, bleu info pour les pubs), remplaçant les anciens dégradés rouge/or/bleu.
  - Carte "Prochainement" (`_buildFutureCard`) et pied de page (`_buildFooter`) adaptés au thème.
- Traduction complète des textes (titre, sous-titre, libellés et descriptions des 3 cartes, section "Prochainement", pied de page).

### `lib/l10n/app_localizations.dart`
- Ajout de 13 nouvelles clés (fr/en/es/de/ar/pt/zh/sw) : `remunerationTitle`, `remunerationSubtitle`, `remunerationBalance`, `remunerationMainAccount`, `remunerationMainAccountDesc`, `remunerationPosts`, `remunerationPostsDesc`, `remunerationAds`, `remunerationAdsDesc`, `remunerationComingSoon`, `remunerationComingSoonDesc`, `remunerationFooter`, `remunerationFooterSub`.

**Vérification** : `flutter analyze lib/pages/user/remuneration_home_page.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur**.

---

## Session 32 — Annulation de la physique de défilement TikTok (Session 29)

### `lib/pages/post_video_format_tel_details.dart`
- La physique personnalisée `_TikTokPageScrollPhysics` (Session 29) provoquait une instabilité : les pages se déplaçaient seules / oscillaient sans interaction utilisateur.
- Retour à la physique d'origine `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` pour le `PageView` vertical des vidéos, et suppression de la classe `_TikTokPageScrollPhysics`.

**Vérification** : `flutter analyze lib/pages/post_video_format_tel_details.dart` → **0 nouvelle erreur**.

---

## Session 33 — CDN : passage systématique des médias par `convertToCdnUrl` (espace VIP, priorité)

Vérification de toutes les pages de `lib/pages/contenuPayant/` (espace VIP) : toute URL de média (image, vidéo, avatar) affichée directement (sans passer par `convertToCdnUrl`) a été corrigée pour utiliser le CDN, via une méthode utilitaire `_cdnUrl(url)` ajoutée dans chaque écran (basée sur `UserAuthProvider.convertToCdnUrl` + `appDefaultData`).

- `TableauDeBord.dart` : ajout de `_optimizeUrl` (état) et `_cdnUrl` (fonction de haut niveau, pour `CategoryContentScreen` et `ContentSearchDelegate`). Appliqué aux miniatures (`_buildContentImage`, `_buildThumbnail`, résultats de recherche de contenu) et à l'avatar des créateurs dans la recherche.
- `contentDetails.dart` : la bannière (`thumbnailUrl`) et les contrôleurs vidéo des capsules (début/milieu/fin) utilisaient l'URL brute — passés par `convertToCdnUrl`.
- `contentDetailsEbook.dart` : bannière de l'ebook/série passée par `convertToCdnUrl`.
- `contentForm.dart` : avatar utilisateur et aperçu de la miniature uploadée passés par `_cdnUrl`.
- `contentSerie.dart` : miniatures des épisodes et bannière de série passées par `_cdnUrl`.
- `profileScreenContent.dart` : avatar du profil, miniatures de contenus et de séries passés par `_cdnUrl`.
- `recent_vip_content_widget.dart` : miniatures des contenus récents passées par `_cdnUrl`.
- `seriesDetailScreenContenu.dart` : bannière de série et miniatures d'épisodes passées par `_cdnUrl`.
- `userAbonnerInfos.dart` : avatar du propriétaire du contenu passé par `_cdnUrl`.

**Vérification** : `flutter analyze lib/pages/contenuPayant/` → **0 nouvelle erreur**.

**Reste à faire (hors VIP, scope plus large)** : un audit similaire est nécessaire sur le reste de l'application (home, chat, profils, stories, chroniques, canaux, dating, afroshop, etc.) où `Image.network`/`CachedNetworkImage`/`NetworkImage`/`VideoPlayerController.network` sont utilisés sans `convertToCdnUrl`. À traiter dans une session dédiée tant le périmètre est large.

---

## Session 34 — Module Dating, étape 1/5 : géolocalisation et tri par proximité

Audit complet du module `lib/pages/dating/` réalisé (15+ pages, service `dating_service.dart`, modèles `dating_data.dart`). Plan de refonte en 5 étapes validé avec l'utilisateur :
1. Géolocalisation & tri par proximité (cette session)
2. Requêtes Firestore & logique de matching
3. Animations de swipe façon Tinder
4. Abonnements (quotas, gating premium)
5. Theme (`AppColors`) + traductions (`AppLocalizations`) + CDN

**Réalisé pour l'étape 1** :
- `lib/models/dating_data.dart` : ajout d'une fonction utilitaire `calculateDistanceKm(lat1, lon1, lat2, lon2)` (formule de Haversine) et ajout des champs `latitude`/`longitude` (nullable) au modèle `DatingProfile` (constructeur, `fromJson`, `toJson`, `copyWith`), avec une méthode `distanceFrom(otherLat, otherLng)` qui retourne la distance en km ou `null` si une position est inconnue.
- `lib/pages/dating/dating_profile_setup_page.dart` : la détection GPS (`Geolocator.getCurrentPosition`) stockait déjà les coordonnées en mémoire mais ne les sauvegardait jamais. Désormais `_detectedLatitude`/`_detectedLongitude` sont capturées et envoyées dans `DatingProfile` lors de la sauvegarde (en conservant les anciennes valeurs si la détection échoue). Au passage, fix : le `popularityScore` et le `countryCode` existants n'étaient pas préservés lors de la modification d'un profil (remis à 0 / null) — corrigé pour conserver les valeurs précédentes si non redétectées.
- `lib/pages/dating/dating_entry_page.dart` (`_loadProfiles`) : le tri des profils par groupes de popularité (40% haut / 30% moyen / 30% bas) utilisait un `shuffle()` aléatoire dans chaque groupe. Si la position de l'utilisateur courant est connue, chaque groupe est désormais trié par distance croissante (profil le plus proche en premier) via `distanceFrom`. Sans position connue, le comportement aléatoire d'origine est conservé.
- Suppression de la méthode morte `_loadProfilesOld` (dupliquait l'ancienne logique de chargement, jamais appelée, ~120 lignes).

**Vérification** : `flutter analyze lib/pages/dating/ lib/models/dating_data.dart` → **0 nouvelle erreur**.

**Limite connue** : seuls les nouveaux profils (ou ceux réenregistrés via la page de configuration) auront des coordonnées GPS. Les profils existants en base n'ont pas de `latitude`/`longitude` et seront donc triés en fin de groupe (via le `da == null` → retourne après les profils géolocalisés). Une régénération ponctuelle des positions pourra être envisagée plus tard si nécessaire.

---

## Session 35 — Module Dating, étape 2/5 : filtres de recherche et logique de matching

**Réalisé** :
- `lib/pages/dating/dating_entry_page.dart` (`_loadProfiles`) : la requête Firestore ne filtrait que sur `isActive` et `sexe` — l'âge (`rechercheAgeMin`/`rechercheAgeMax`) et le pays (`recherchePays`) de l'utilisateur courant n'étaient jamais appliqués (les filtres existants en base `dating_service.dart` n'étaient pas utilisés par cette page). Ajout d'un filtrage côté client juste après l'exclusion de soi-même : profils dont l'âge n'est pas dans la tranche recherchée, ou dont le pays ne correspond pas à `recherchePays` (sauf valeur "tous"), sont désormais exclus avant le tri par popularité/proximité.
- Anti-boucle infinie : `_loadProfiles` se rappelait lui-même sans condition d'arrêt si Firestore renvoyait un lot vide ou entièrement filtré (risque de boucle infinie sur une base vide ou avec des filtres très restrictifs). Ajout d'un compteur `_reloadAttempts` (max `_maxReloadAttempts = 3`) : au-delà, on arrête le chargement (`_hasMore = false`) au lieu de relancer indéfiniment. Le compteur est remis à zéro dès qu'un lot de profils valides est obtenu.
- `_isMatching(user, target)` : ne vérifiait que la compatibilité de genre (`rechercheSexe` vs `sexe`). Ajout de la vérification de la tranche d'âge recherchée (`rechercheAgeMin`/`rechercheAgeMax` de `user` vs `age` de `target`), dans les deux sens lors de la détection d'un match mutuel.
- `_checkMatchCompatibility` (utilisé pour les super likes) dupliquait une logique de compatibilité de genre incomplète (sans âge) — remplacé par un appel à `_isMatching` dans les deux sens, pour une cohérence totale avec la logique de match des likes simples.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart` → **0 nouvelle erreur**.

**Note** : un filtrage serveur (Firestore `where` sur `age`/`pays`) nécessiterait des index composites supplémentaires (et un `orderBy` cohérent avec la pagination par curseur) — non fait dans cette session pour éviter de casser la pagination en production sans coordination sur les index Firestore. Le filtrage côté client reste correct fonctionnellement, juste un peu moins efficace réseau (lots de 50 documents pouvant être réduits après filtrage).

---

## Session 36 — Module Dating, étape 3/5 : animations de swipe façon Tinder + carte des profils

**Réalisé** :
- `lib/pages/dating/dating_entry_page.dart` : refonte du geste de swipe (`_onPanUpdate`/`_onPanEnd`) pour se rapprocher de Tinder :
  - Ajout du geste **glisser vers le haut = Super Like** (en plus du like/pass horizontal existant), avec seuil dédié `_superLikeThreshold = 120.0`.
  - Ajout de retours haptiques (`HapticFeedback.selectionClick()` quand le seuil de décision est atteint pendant le drag, `HapticFeedback.mediumImpact()` au moment où le swipe est validé).
  - Ajout d'un overlay **"SUPER LIKE"** (badge bleu, façon tampon Tinder) qui apparaît lors du drag vertical vers le haut, en plus des overlays existants **LIKE**/**PASS** pour le drag horizontal.
  - La carte suivante (sous la carte en cours de swipe) s'agrandit légèrement (`Transform.scale` de 0.92 à 1.0) au fur et à mesure du glissement, pour reproduire l'effet de "pile de cartes" de Tinder.
- **Nouvelle page carte** `lib/pages/dating/dating_map_page.dart` (`flutter_map` + `latlong2`, ajoutés au `pubspec.yaml` : `flutter_map: ^6.1.0`, `latlong2: ^0.9.1`) :
  - Carte basée sur OpenStreetMap (pas de clé API requise), centrée sur la position de l'utilisateur courant si connue, sinon sur le premier profil géolocalisé, sinon sur Lomé (Togo) par défaut.
  - Affiche un marqueur stylé (avatar circulaire avec photo de profil + petite pointe façon épingle) pour chaque profil possédant `latitude`/`longitude` (champs ajoutés à la Session 34).
  - Marqueur bleu distinct pour la position de l'utilisateur courant.
  - Au tap sur un marqueur, une carte récapitulative du profil apparaît en bas (photo, pseudo, âge, ville, distance en km calculée via `distanceFrom`), avec un bouton "Voir" qui navigue vers `DatingProfileDetailPage`.
  - Boutons de zoom +/- superposés sur la carte.
  - Message d'information si aucun profil n'a de coordonnées GPS.
  - Navigation ajoutée depuis `dating_entry_page.dart` : nouvelle icône carte (`Icons.map_outlined`) dans l'`AppBar`, ouvre `DatingMapPage` avec la liste de profils déjà chargés et la position de l'utilisateur courant.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_map_page.dart` → **0 nouvelle erreur** (uniquement des infos/warnings préexistants de style, type `prefer_const_constructors`, `withOpacity` déprécié, etc., non liés à cette session).

**Note** : les profils sans `latitude`/`longitude` (créés avant la Session 34) n'apparaissent simplement pas sur la carte — comportement attendu, cohérent avec le repli déjà en place pour le tri par proximité.

---

## Session 37 — Module Dating, étape 4/5 : abonnements (quotas, contrôle, gating premium)

**Réalisé** :
- `lib/pages/dating/dating_entry_page.dart` (`_processLike` / `_sendSuperLike`) : le décompte des likes/super likes restants écrivait la valeur absolue locale (`remainingLikes`/`remainingSuperLikes`) via `_saveRemainingLikes()`, ce qui pouvait écraser une valeur plus récente écrite par une autre session (perte ou duplication de quota en cas d'usage multi-appareils ou de fermeture brutale de l'app entre le `setState` et l'écriture). Ajout de `_decrementRemaining(field)` qui utilise `FieldValue.increment(-1)` pour un décompte atomique côté Firestore ; `_processLike` et `_sendSuperLike` (cas gratuit) l'utilisent désormais à la place de `_saveRemainingLikes()`.
- `_loadUserSubscription` : en cas d'abonnement payant expiré, le code désactivait l'ancien document (`isActive: false`) et recalculait les quotas gratuits en mémoire, mais ne créait **aucun nouveau document actif** — les décréments suivants (`_decrementRemaining`/`_saveRemainingLikes`) auraient donc continué à écrire sur l'ancien document désactivé. Correction : un nouveau document `user_dating_subscriptions` `gratuit`/actif est créé immédiatement (comme pour un nouvel utilisateur), avec `lastResetDate` et quotas corrects, et `_userSubscriptionDocId`/`_subscriptionPlan` pointent vers ce nouveau document.
- `lib/pages/dating/dating_likes_list_page.dart` : l'onglet "Reçus" (personnes ayant liké l'utilisateur) affichait la liste complète des profils à **tous les utilisateurs**, alors que "Voir qui vous a liké" est annoncé comme une fonctionnalité réservée aux abonnements Plus/Gold (cf. `features` des plans dans `_initializeSubscriptionPlansIfNeeded`). Ajout de `_loadSubscriptionPlan()` (lecture de `user_dating_subscriptions` actif) et, pour les utilisateurs gratuits, remplacement de la liste par une vignette verrouillée `_buildLockedLikesTeaser` (icône floutée + cadenas, nombre de likes reçus, bouton vers `DatingSubscriptionPage`). L'onglet "Envoyés" reste inchangé et accessible à tous.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_likes_list_page.dart` → **0 nouvelle erreur**.

**Note** : la logique de pub (`_checkAndShowSwipeAd`, seuils par plan), le coût en pièces des super likes (`_sendSuperLike`, achat avec pièces) et l'initialisation des plans (`subscription_plans`) étaient déjà correctement implémentés et n'ont pas été modifiés.

---

## Session 38 — Module Dating, étape 5/5 : thème (clair/sombre) + traductions + CDN — `dating_entry_page.dart`

**Contexte** : `lib/l10n/app_localizations.dart` contient déjà ~112 clés `dating*` (section "Dating (Batch 1)") préparées mais inutilisées dans les pages du module dating. Cette session "câble" ces clés existantes dans `dating_entry_page.dart`, applique `AppColors.of(context)` pour le thème clair/sombre, et utilise `convertToCdnUrl` pour les images de profils.

**Réalisé** :
- `lib/pages/dating/dating_entry_page.dart` :
  - Ajout des imports `AppColors` et `AppLocalizations`, et d'un helper `_cdnUrl()` (identique au pattern utilisé ailleurs dans l'app) appliqué aux photos de profils affichées dans `_buildProfileCard`.
  - `Scaffold.backgroundColor` et `Dialog.backgroundColor` (match, likes premium) basés sur `AppColors.of(context).background` / `.surface` au lieu de `Colors.white`.
  - États vides (chargement, plus de profils, aucun profil) : icônes/textes utilisent `AppColors.of(context).textPrimary` / `.textSecondary` et les clés `t.datingLoadingProfiles`, `t.datingPleaseWait`, `t.datingNoMoreProfilesNow`, `t.datingComeBackLater`, `t.datingRefresh`, `t.datingNoProfilesYet`.
  - `_showUpgradeDialog` (limite de likes/super likes atteinte) et `_showInsufficientCoinsDialog` (solde de pièces insuffisant pour un super like payant) : tous les textes (titres, messages, boutons "Regarder la pub", "Voir les offres", "Acheter des pièces", etc.) remplacés par les clés `AppLocalizations` correspondantes, avec substitution `{bonus}`/`{price}`/`{balance}` via `replaceAll`.
  - `_showMatchDialog` ("C'est un match !"), `_showPremiumChatDialog` (messagerie réservée Gold) et `_showLikedProfilesPremiumDialog` (likes envoyés réservés Plus/Gold) : titres, messages et boutons traduits (`datingItsAMatch`, `datingMutualLikeWith`, `datingChatPrivately`, `datingContinue`, `datingPrivateMessagingGoldOnly`, `datingUpgradeGoldForChat`, `datingLikedProfilesCount`, `datingDiscoverLikedProfiles`, `datingViewMyLikes`, `datingContinueSwiping`, `datingUnlockPremium`, etc.) ; fond de dialogue basé sur `AppColors.of(context).surface`.
  - Messages de feedback (snackbars `_showSuccessMessage`) lors d'un like/super like : "déjà en contact", "ne correspond pas à vos critères", "vous avez liké X", "super like envoyé à X", "erreur d'envoi", incompatibilité de genre — tous traduits via `datingAlreadyInContactWith`, `datingDoesNotMatchCriteria`, `datingYouLiked`, `datingSuperLikeSentTo`, `datingErrorSending`, `datingNotSearchingThisGender`, `datingOtherNotSearchingYourGender`.
  - Dialogue "Coup de cœur payant" (`_processSuperLike`) : titre, message, coût et solde traduits via `datingPaidCrushTitle`, `datingNoMoreFreeCoupsToday`, `datingSendCoupCost`, `datingYourBalance`, `datingBuyAndSend`, `datingCancel`.
  - Bandeau incitatif "Afrolove Gold" (`_showGoldIncentiveMessage`) : titre, message et bouton "VOIR L'OFFRE" traduits via `datingGoldTitle`, `datingGoldRemoveAdsMessage`, `datingViewOffer`.
  - Panneau de filtres (genre, popularité, âge min/max, boutons Annuler/Appliquer) entièrement traduit via `datingFilters`, `datingGender`, `datingAll`, `datingWomen`, `datingMen`, `datingPopularity`, `datingMostPopular`, `datingLeastPopular`, `datingAgeMin`, `datingAgeMax`, `datingApply`, `datingCancel`.
  - Overlays de swipe LIKE/PASS traduits via `datingLike`/`datingPass` (le badge "SUPER LIKE" reste en majuscules non traduit, terme universel façon Tinder).
  - Badge "Profil incomplet" sur la carte traduit via `datingIncompleteProfile`.
  - Barre de navigation basse : labels "Rencontres"/"Explorer"/"Profil" traduits via `datingMeetings`, `datingExplore`, `datingProfile`.
- `lib/pages/dating/dating_map_page.dart` : ajout d'un helper `_cdnUrl()` appliqué aux avatars des marqueurs et à la carte de profil sélectionné (`Image.network`) ; fond de page et fond de la carte de profil sélectionné basés sur `AppColors.of(context).background`/`.surface` ; texte du pseudo/âge utilise `AppColors.of(context).textPrimary`.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_map_page.dart` → **0 nouvelle erreur** (uniquement des infos de style préexistantes : `prefer_const_constructors`, `withOpacity` déprécié, etc.).

**Restant pour l'étape 5/5** : appliquer le même travail (thème + traductions + CDN) aux autres pages du module dating (`dating_profile_detail_page.dart`, `dating_chat_page.dart`, `dating_profile_setup_page.dart`, `dating_subscription_page.dart`, `dating_explore_page.dart`, `dating_likes_list_page.dart`, pages `creator_*`, etc.) — sessions suivantes.

## Session 39 — Module Dating : polish UI façon Tinder, modal "découvrir la carte" et quota de profils parcourus

**Contexte** : suite de la demande "revoir le ui pour être digne d'un réseau comme Tinder, éviter les erreurs UI, attirer les utilisateurs (modal vers la carte) et appliquer les contrôles d'abonnement sur les profils à parcourir".

**Réalisé** :
- `lib/l10n/app_localizations.dart` : ajout de 5 nouvelles clés (8 langues) : `datingDiscoverMapTitle`, `datingDiscoverMapMessage`, `datingViewMap`, `datingMaybeLater`, `datingNoMoreSwipes`.
- `lib/pages/dating/dating_entry_page.dart` :
  - **Polish visuel** : `AppBar` passe d'un fond uni `Colors.red.shade600` à un dégradé rouge→rose (`flexibleSpace` + `LinearGradient`) pour un rendu plus "dating app". `bottomNavigationBar` et `_buildBottomNavItem` utilisent désormais `AppColors.of(context).surface`/`.textSecondary` pour supporter le mode sombre (au lieu de `Colors.white`/`Colors.grey` codés en dur). Le panneau de filtres (`Card`) a maintenant une couleur de fond explicite `AppColors.of(context).surface`.
  - **Correction UI** : le texte "Chargement de nouveaux profils..." codé en dur est remplacé par `t.datingLoadingMoreProfiles`.
  - **Quota de profils parcourus (`_remainingSwipes`)** : nouveau champ `remainingSwipes` sur `user_dating_subscriptions`, avec reset quotidien identique aux likes/super likes. Quotas par défaut via `_defaultSwipesForPlan()` : gratuit = 30/jour, plus = 150/jour, gold = illimité (-1). `_canSwipe()` vérifie le quota avant chaque swipe (gauche/droite/super like) et affiche `_showUpgradeDialog(type: 'swipe')` (nouveau cas géré, message `t.datingNoMoreSwipes`) si épuisé ; `_consumeSwipe()` décrémente atomiquement via `_decrementRemaining('remainingSwipes')`.
  - **Modal "Découvrir la carte"** : toutes les 15 actions de swipe (`_mapPromoCounter`/`_mapPromoThreshold`), `_showMapDiscoveryDialog()` propose à l'utilisateur de visualiser les profils proches sur `DatingMapPage` (boutons `t.datingViewMap` / `t.datingMaybeLater`).

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur**.

**Complément — animations de swipe (boutons + relâchement de carte)** :
- Ajout d'un `AnimationController` (`_cardAnimController`, 250 ms, `Curves.easeOut`) qui pilote `_dragOffset`/`_rotationAngle`/`_opacity` via `_onCardAnimTick`.
- `_animateCardOff(target, rotation)` : envoie la carte courante hors de l'écran (gauche/droite/haut selon l'action), puis appelle `_nextProfile()` à la fin.
- `_animateCardBack()` : ramène la carte en douceur au centre si le swipe relâché n'a pas atteint le seuil (au lieu d'un reset instantané).
- `_handleSwipeLeft` / `_handleSwipeRight` / `_handleSuperLike` retournent désormais un `bool` (succès/échec selon les quotas) sans appeler `_nextProfile()` directement — c'est l'appelant (`_onPanEnd` ou les 3 boutons d'action close/star/favorite) qui déclenche l'animation de sortie correspondante (gauche/droite/haut) seulement si l'action a été acceptée.
- Résultat : les 3 boutons d'action en bas de l'écran déclenchent maintenant la même animation "carte qui s'envole" façon Tinder que le swipe au doigt, et un swipe relâché trop court revient élastiquement à sa place.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart` → **0 nouvelle erreur**.

---

## Session 40 — Module Dating : algorithme de recommandation, modal de nouvelle activité, badges de profil

**Contexte** : suite de la demande "change notre algorithme à un algorithme de suggestion/recommandation de profils au profil courant, applique-le aussi sur Explorer, réduis le nom 'AfroLove' qui se superpose à la carte, ajoute un modal de bienvenue annonçant les nouveaux matchs/likes sur la page de swipe, ajoute des badges de compteur sur les boutons Matchs/Mes likes du profil, et améliore l'UI dating en général".

**Réalisé** :
- `lib/models/dating_data.dart` : nouvelle méthode `recommendationScore(DatingProfile other)` sur `DatingProfile` — score de compatibilité pondéré (intérêts communs ×20, tranche d'âge recherchée +10, profil vérifié +5, popularité/10 plafonnée à 50, bonus de proximité jusqu'à 50).
- `lib/pages/dating/dating_entry_page.dart` :
  - `_loadProfiles()` : le tri high/mid/low (puis mélange 5/3/2) se base désormais sur `recommendationScore` du profil courant plutôt que sur la seule popularité.
  - **AppBar "AfroLove"** réduite (icône 24→20, texte 22→17px, `mainAxisSize: MainAxisSize.min`, `titleSpacing: 12`) pour ne plus se superposer aux boutons carte/likes/filtre.
  - **Nouveau modal d'activité** : `_checkNewActivity()` (appelé à l'arrivée sur la page si le profil est complet) interroge `Notifications` pour compter les `DATING_MATCH` et `DATING_LIKE`/`DATING_SUPER_LIKE` non lus (`is_open == false`). Si au moins un est trouvé, `_showNewActivityDialog()` affiche un modal façon "découvrir la carte" (icône cœur en dégradé rouge→rose) annonçant les compteurs, avec un bouton d'action vers `DatingConnectionsPage` (matchs) ou `DatingLikesListPage` (likes).
  - Ajout de l'import `dating_connections_page.dart`.
- `lib/pages/dating/dating_explore_page.dart` :
  - `_mixProfiles()` : tri par `recommendationScore` du profil courant (au lieu de la popularité seule) avant la répartition high/mid/low et le mélange.
  - **Polish UI** : AppBar passe d'un fond uni `Colors.pink.shade400` à un dégradé rouge→rose (`flexibleSpace`, cohérent avec `dating_entry_page.dart`), titre réduit (icône `travel_explore` 20px, texte 17px). `Scaffold.backgroundColor` et les textes de l'état vide utilisent désormais `AppColors.of(context)` pour le support du mode sombre.
- `lib/pages/dating/dating_profile_detail_page.dart` :
  - Nouveaux champs `_unreadMatchesCount`/`_unreadLikesCount` + méthode `_loadUnreadMatchesAndLikesCount()` (même requête `Notifications` que `_loadUnreadNotificationsCount`, filtrée par type `DATING_MATCH` et `DATING_LIKE`/`DATING_SUPER_LIKE`).
  - Les boutons "Matchs" et "Mes likes" du profil personnel affichent désormais un badge (`badgeCount:`) avec le nombre de matchs/likes non encore consultés, comme pour "Notif".
- `lib/l10n/app_localizations.dart` : 5 nouvelles clés (8 langues) : `datingNewActivityTitle`, `datingNewActivityMatches(count)`, `datingNewActivityLikes(count)`, `datingViewMatches`, `datingViewLikes`.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_explore_page.dart lib/pages/dating/dating_profile_detail_page.dart lib/models/dating_data.dart lib/l10n/app_localizations.dart` → **0 nouvelle erreur**.

**Complément — priorité aux profils non explorés et cycle sans fin** :
- `lib/pages/dating/dating_entry_page.dart` et `lib/pages/dating/dating_explore_page.dart` : nouvelle méthode `_loadExcludedUserIds()` qui récupère les `userId` déjà likés (`dating_likes` où `fromUserId == currentUserId`) ou déjà matchés (`dating_connections`, `userId1`/`userId2 == currentUserId`).
- Dans `_loadProfiles()` des deux pages, ces profils sont écartés en priorité (champ `_excludeInteracted`, vrai par défaut) afin que les profils non encore explorés remontent toujours en premier.
- Si plus aucun profil inexploré n'est disponible alors que la liste complète a été récupérée (`snapshot.docs.length < _batchSize`), `_excludeInteracted` passe à `false` : le filtre est désactivé et les profils déjà likés/matchés réapparaissent, garantissant qu'il reste toujours des profils à swiper/explorer (recommence le cycle).
- Combiné au tri par `recommendationScore` + mélange par groupes (high/mid/low), l'ordre d'affichage varie d'une visite à l'autre tout en priorisant la nouveauté.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_explore_page.dart` → **0 nouvelle erreur**.

**Complément — swipe infini avec chargement en arrière-plan** :
- `lib/pages/dating/dating_entry_page.dart` : `_checkAndLoadMore()` (appelé après chaque swipe) déclenche désormais `_loadMoreProfiles()` dès qu'il reste ≤5 profils dans la pile, **même si `_hasMore` est `false`**.
- `_loadMoreProfiles()` : si plus aucun nouveau profil n'est disponible côté serveur (`_hasMore == false`), désactive `_excludeInteracted` (réintègre les profils déjà likés/matchés) et réinitialise `_lastDocument`/`_hasMore`/`_reloadAttempts` pour relancer le cycle de pagination depuis le début — l'utilisateur a donc toujours de nouveaux profils chargés en arrière-plan, sans jamais arriver à une pile vide.
- Correction d'un bug associé : quand un lot vide était reçu pendant un `_loadProfiles(isLoadMore: true)`, le code remettait `_isLoading` au lieu de `_isLoadingMore` à `false`, ce qui bloquait définitivement `_loadMoreProfiles()` (`_isLoadingMore` restait `true`).
- `lib/pages/dating/dating_explore_page.dart` : même logique de recyclage quand la fin de la collection `dating_profiles` est atteinte alors que `_excludeInteracted` est encore actif.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_explore_page.dart` → **0 nouvelle erreur**.

**Correctif — écran vide quand tous les profils chargés sont déjà explorés** :
- Bug : avec un lot complet (`snapshot.docs.length == _batchSize`, ex. "50 profils avant" → "0 profils après exclusion"), la condition de recyclage exigeait un lot incomplet, donc `_excludeInteracted` restait actif et `allProfiles` repartait à 0 → `_loadProfiles()` se relançait en boucle (jusqu'à `_maxReloadAttempts`) sur la même requête et finissait avec **aucun profil affiché**.
- Correctif : dès que le filtre "non explorés" donne une liste vide alors que des profils ont bien été chargés (peu importe la taille du lot), `_excludeInteracted` passe immédiatement à `false` et on **réutilise les profils déjà récupérés** (déjà likés/matchés) au lieu de relancer une requête réseau supplémentaire.
- `_loadExcludedUserIds()` (les deux pages) : les 3 requêtes Firestore (`dating_likes`, `dating_connections` × 2) sont désormais lancées en parallèle via `Future.wait` au lieu d'être séquentielles, pour accélérer le chargement initial.

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/pages/dating/dating_explore_page.dart` → **0 nouvelle erreur**.

## Session 41 — Module Dating : suppression des publicités récompensées, anti-doublon de likes, photos aléatoires, plus de profils et nouveau bouton "Découvrir"

**Contexte** : suite de la Session 40. Demandes : (1) afficher une photo aléatoire pour les profils ayant plusieurs photos, (2) ne plus enregistrer de like en double pour un même profil et bien gérer le statut "déjà liké"/match sur la page de détail, (3) supprimer toute la logique "regarder une pub pour un bonus" (publicités récompensées/interstitielles), (4) charger davantage de profils par requête, (5) transformer le bouton "Explorer" du bas de la page swipe en un choix Carte/Liste.

**Réalisé** :
- **Suppression des publicités récompensées/interstitielles** (`lib/pages/dating/dating_entry_page.dart`) :
  - Retrait des imports `rewarded_ad_widget.dart` / `rewarded_interstitial_ad_widget.dart`, des champs `_isLoadingAd`, `_rewardedAdKey`, `_showRewardedAd`, `_pendingRewardType`, `_adKey`, `_swipeCounter`, et des méthodes `_addBonusLikes`, `_addBonusSuperLikes`, `_checkAndShowSwipeAd` (et ses 2 appels dans `_handleSwipeLeft`/`_handleSwipeRight`), `_showGoldIncentiveMessage`.
  - `_showUpgradeDialog()` : suppression du bouton "regarder la pub" et du spinner de chargement de pub ; ne reste que le message d'incitation à l'upgrade Gold et le bouton "Voir les offres".
  - `_openChat()` était cassé (appel de pub + navigation commentée) : corrigé pour naviguer directement vers `DatingChatPage` avec les bons paramètres (`connectionId`, `otherUserId`, `otherUserName`, `otherUserImage`).
  - Retrait du widget `RewardedAdWidget`/`InterstitialAdWidget` de l'arbre de build.
  - Même nettoyage sur `lib/pages/dating/dating_profile_detail_page.dart` : retrait des imports `banner_ad_widget.dart`/`rewarded_ad_widget.dart`, des champs `_rewardedAdKey`/`_showRewardedAd`/`_pendingRewardType`, des méthodes `_addBonusLikes`/`_addBonusSuperLikes`, du bloc `RewardedAdWidget` dans le `CustomScrollView`, du bouton "Regarder la pub" et du texte associé dans `_showUpgradeDialog()`. La méthode `_handleLike2()` (doublon mort de `_handleLike()`, jamais appelé) a été supprimée.
- **Anti-doublon de likes** :
  - `dating_entry_page.dart` → `_processLike()` : vérifie désormais l'existence d'un document `dating_likes` (`fromUserId`/`toUserId`) avant d'en créer un nouveau ; si déjà liké, on saute l'insertion, le décompte de quota, l'incrément `likesCount` et le recalcul du score de popularité, mais on continue de vérifier le like mutuel/match.
  - `dating_profile_detail_page.dart` → `_handleLike()` : retour anticipé avec un message "Vous avez déjà liké ce profil ❤️" si `_isLiked` est déjà vrai (calculé par `_checkLikeStatus()` à l'ouverture de la page) ; vérification supplémentaire juste avant l'insertion (re-requête `dating_likes`) pour couvrir les cas de concurrence, avec mise à jour de `_isLiked` sans nouvelle écriture si un like existe déjà.
- **Photos aléatoires pour profils multi-photos** :
  - `dating_explore_page.dart` → `_buildProfileCard()` : l'image affichée est désormais choisie via `profile.photosUrls[profile.userId.hashCode.abs() % profile.photosUrls.length]` (au lieu de toujours la première photo), stable par profil grâce au hash de `userId`.
  - `dating_entry_page.dart` → `_buildProfileCard()` (page swipe) : correction du calcul existant pour éviter une `IntegerDivisionByZeroException`/index négatif (`.abs()` ajouté avant le modulo).
- **Plus de profils par requête** : `_batchSize` passé de 50 à 100 dans `dating_entry_page.dart`, et de 20 à 50 dans `dating_explore_page.dart`.
- **Nouveau bouton "Découvrir"** (remplace "Explorer" dans la barre de navigation basse de la page swipe) :
  - `_showDiscoverChoiceDialog()` (nouveau, `dating_entry_page.dart`) : ouvre un `showModalBottomSheet` avec 2 choix — **"Carte"** (ouvre `DatingMapPage` avec les profils chargés et la position de l'utilisateur) et **"Liste"** (ouvre `DatingExplorePage`).
  - `lib/l10n/app_localizations.dart` : nouvelles clés (8 langues) `datingDiscoverNav` ("Découvrir"/"Discover"...), `datingDiscoverChoiceTitle`, `datingDiscoverChoiceMap`, `datingDiscoverChoiceMapSubtitle`, `datingDiscoverChoiceList`, `datingDiscoverChoiceListSubtitle`.

**Vérification** : `flutter analyze lib/pages/dating/` → **0 erreur** (uniquement des warnings/infos préexistants, type `deprecated_member_use`/`prefer_const_constructors`).

## Session 42 — Module Dating : refonte du système d'abonnement (flux post-souscription, 3 paliers carte/explorer, anti-doublons, badge profil consulté, refonte design `dating_subscription_page.dart`)

**Contexte** : refonte complète de la gestion des abonnements `gratuit`/`plus`/`gold` : flux de retour après souscription, application des 3 paliers sur la carte, fiabilisation des données `subscription_plans`/`user_dating_subscriptions`, et alignement de `dating_subscription_page.dart` sur le thème clair/sombre + i18n (8 langues), ce qui complète la tâche #8 du backlog (theme+i18n+CDN `dating_subscription_page.dart`).

### Algorithme d'engagement (rétention sur la page swipe)
- **Implémenté** : dans `dating_entry_page.dart`, lorsque `_remainingSwipes` atteint 0 (palier gratuit), `_showUpgradeDialog(type: 'swipe')` affiche désormais un compte à rebours (`_formatTimeUntilNextReset()`, basé sur le nouveau champ `_lastResetDate` + 24h) via la clé i18n `datingNextSwipeIn` ("Prochains swipes dans {time}"), pour donner une raison de revenir le lendemain.
- **Implémenté** : dans `dating_explore_page.dart` et `dating_map_page.dart`, quand la limite `_maxVisibleProfiles` (10/200/illimité selon le plan) est atteinte, un bandeau "Passez à Plus ou Gold pour voir plus de profils..." (`datingMoreProfilesWithPlan`) s'affiche en plus du bouton d'upgrade existant, au lieu de simplement arrêter le chargement silencieusement.
- **Documenté seulement** (non codé, à planifier séparément si validé) :
  - Streaks de connexion quotidienne (récompense de bonus de swipes/likes pour les connexions consécutives).
  - Teaser "X personnes vous ont liké" flouté pour le plan gratuit (incite à l'abonnement Plus/Gold pour révéler).
  - Boost de visibilité temporaire (quelques heures) juste après un achat d'abonnement, pour donner un effet immédiat perceptible.
  - Notifications intelligentes basées sur l'heure d'activité habituelle de l'utilisateur (au lieu d'horaires fixes).

### Flux post-souscription (`dating_subscription_page.dart`)
- `_subscribe()` : après succès, `Navigator.of(context).popUntil((route) => route.isFirst)` ramène systématiquement à `DatingEntryPage` (racine de la pile Dating), quelle que soit la page d'origine (détail profil, explorer...). `dating_entry_page.dart` rafraîchit déjà automatiquement (`didChangeDependencies` → `_refreshData()` → `_loadUserSubscription()`) au retour, donc `_remainingSwipes`/`_remainingLikes`/`_remainingSuperLikes` sont recalculés immédiatement depuis le nouveau document `user_dating_subscriptions` sans attendre le reset du lendemain.
- Suppression des méthodes mortes `_updateLocalLimits()` (SharedPreferences) et `_updateProviderLimits()` (no-op) ; seul `authProvider.refreshUserData()` est conservé (pour `coinsBalance`).

### Doublons `subscription_plans` et garde anti-resouscription (§5/§8)
- `_checkAndCreatePlans()` utilise désormais des doc IDs déterministes (`doc('gratuit'|'plus'|'gold').set({...}, SetOptions(merge: true))`) au lieu de `.add()`, garantissant l'unicité par `code`.
- `_loadPlans()` déduplique les documents existants par `code` (garde celui avec `updatedAt` le plus récent, désactive les autres via `update({isActive: false})`) — nettoyage silencieux et progressif des doublons historiques.
- `_subscribe()` : la garde anti-resouscription couvre désormais tous les plans y compris `gratuit` (`if (_currentSubscriptionPlan == plan.code) { ... return; }`), message `datingAlreadySubscribedToPlan`. Le bouton "Abonnement actif" (désactivé) s'applique donc aussi au plan gratuit déjà actif.

### Badge d'abonnement du profil consulté (`dating_profile_detail_page.dart`)
- Nouveau `_loadProfileOwnerSubscription()` : requête `user_dating_subscriptions where userId == profile.userId && isActive == true limit 1`, stockée dans `_profileOwnerSubscriptionPlan`.
- Nouveau badge "Abonnement : Gratuit/Plus/Gold" affiché uniquement si `_canViewProfileOwnerSubscription()` (= propriétaire du profil ou `role == UserRole.ADM.name`), basé sur `_profileOwnerSubscriptionPlan` (et non plus sur l'abonnement du visiteur). L'ancien badge "Abonnement Gold actif" (qui affichait à tort le plan du visiteur à tout le monde) a été retiré/remplacé par celui-ci.
- Nouvelles clés i18n (8 langues) : `datingSubscriptionLabel`, `datingPlanFree`, `datingPlanPlus`, `datingPlanGold`.

### 3 paliers sur la carte (`dating_map_page.dart`) et bandeau Explorer
- `DatingMapPage` reçoit désormais `subscriptionPlan` (depuis `_subscriptionPlan` de `dating_entry_page.dart`, passé sur les 3 points d'ouverture de la carte) et applique `_maxVisibleProfiles` (gratuit=10, plus=200, gold=illimité) sur `_locatedProfiles` (`.take(_maxVisibleProfiles)`).
- Si la limite est atteinte, un bandeau `datingMoreProfilesWithPlan` s'affiche en haut de la carte.
- Passage thème/i18n : titre `Carte des profils` → `datingMapPageTitle`, message "Aucun profil géolocalisé..." → `datingNoLocatedProfiles`, bouton "Voir" → `datingViewProfileButton`. `Colors.red.shade600` (AppBar/boutons de zoom) conservé comme accent de marque, conformément à la convention du module.

### Refonte design `dating_subscription_page.dart` (§7, tâche #8 du backlog)
- Toutes les couleurs en dur remplacées par `AppColors.of(context)` (`.background`, `.surface`, `.surfaceVariant`, `.border`, `.textPrimary`, `.textSecondary`), en conservant `Colors.red`/`Colors.amber`/`Colors.green` pour les accents de marque/statut (gold, succès, erreurs).
- ~25 nouvelles clés `AppLocalizations` (8 langues) pour tous les textes en dur (titre, solde, confirmation, limites, messages de succès/erreur, etc.).
- Nouvelle clé `datingBalanceLabel` ("Votre solde") distincte de `datingYourBalance` (préexistante, avec placeholder `{balance}`) pour éviter un conflit de nom.

### Fiabilisation/centralisation (§5 — documentation)
- Lecture de l'abonnement actif (`user_dating_subscriptions where userId==X && isActive==true limit 1`) reste dupliquée dans `dating_entry_page.dart`, `dating_explore_page.dart` et `dating_profile_detail_page.dart`. Une factorisation dans un service partagé est envisageable mais a été volontairement reportée à une session dédiée pour limiter le risque de régression sur cette refonte.

**Vérification** : `flutter analyze lib/pages/dating/ lib/l10n/app_localizations.dart` → **0 erreur**.

## Session 43 — Module Dating : algo de découverte, boost long, page Explorer, modal "Comment ça marche", fix transaction abonnement, proposition paiement

### 1. Anti-boucle "6 profils" + reprise de session (`dating_entry_page.dart`)
- Ajout d'un cache statique de session sur `_DatingSwipePageState` (`_cachedUserId`, `_cachedProfiles`, `_cachedCurrentIndex`, `_cachedLoadedProfileIds`, `_cachedExcludedUserIds`, `_cachedExcludeInteracted`, `_cachedFiltersRelaxed`, `_cachedHasMore`, `_cachedLastDocument`) + `_saveDeckCache()`/`_restoreDeckCache()` : en quittant puis revenant sur la page swipe, l'utilisateur reprend exactement où il s'était arrêté (au lieu de repartir du profil 1).
- Nouveau champ `_filtersRelaxed` + `_restartDiscoveryCycle()` : si après un cycle complet (`_excludeInteracted = false`) il reste ≤ 6 profils correspondant aux critères (tranche d'âge / pays), ces filtres sont automatiquement ignorés pour élargir la recherche, avec un `SnackBar` (`datingExpandedSearchCriteria`) informant l'utilisateur.

### 2. Boost de profil longue durée (1j / 1 sem / 3 sem / 1 mois / 3 mois / 6 mois)
- Nouvelle map `_longBoostPricesCoins` (`{1:300, 7:1500, 21:3500, 30:4500, 90:11000, 180:19000}`) et méthode `_activateLongBoost()` (transaction Firestore : débit `coinsBalance`, écriture `boostUntil = now + days*24h`, log `user_coin_transactions` type `spend_long_boost`).
- `_showBoostDialog()` refondu : section boost rapide (30 min, existant) + nouvelle section "🚀 Boost longue durée" avec un bouton par durée (`_longBoostLabel()`).
- Badge "Boosté" (`datingBoostedBadge`) ajouté sur la carte swipe (`dating_entry_page.dart`) **et** sur les cartes de `dating_explore_page.dart`, basé sur `profile.isBoosted` (`boostUntil > now`).
- Nouvelles clés i18n (8 langues) : `datingBoost1Day`, `datingBoost1Week`, `datingBoost3Weeks`, `datingBoost1Month`, `datingBoost3Months`, `datingBoost6Months`.

### 3. Modal "Comment ça marche" (remplace les messages périodiques de la page swipe)
- Suppression de l'overlay rotatif (`_motivationalMessages`, `_currentMessageIndex`, `_messageTimer`, `_showMessage`, `_startMessageTimer()`) qui apparaissait/disparaissait en boucle.
- Ajout de `_maybeShowHowItWorksModal()` (utilise `shared_preferences`, clé `dating_how_it_works_last_shown`) : affiche `_showHowItWorksDialog()` à la première visite, puis au maximum une fois par mois (30 jours).
- Le modal présente 5 sections (Swipe, Like & Coup de cœur, Carte, Abonnements, Boost) avec icône/titre/description, et un bouton "Compris, c'est parti !" (`datingHowItWorksGotIt`).
- Nouvelles clés i18n (8 langues) : `datingHowItWorksTitle`, `datingHowItWorksSwipeTitle/Desc`, `datingHowItWorksLikeTitle/Desc`, `datingHowItWorksMapTitle/Desc`, `datingHowItWorksSubscriptionsTitle/Desc`, `datingHowItWorksBoostTitle/Desc`, `datingHowItWorksGotIt`.

### 4. Page Explorer (`dating_explore_page.dart`) : CDN + badges + AppBar
- `_buildProfileCard()` : `Image.network` remplacé par `CachedNetworkImage` (placeholder/erreur stylisés) avec URL passée par `_cdnUrl()` (conversion CDN via `UserAuthProvider.convertToCdnUrl`), comme sur les autres pages dating.
- Ajout du badge "Boosté" (gradient ambre/orange, haut-gauche) en complément du badge popularité existant (haut-droite).
- AppBar redessinée : titre dans un `Flexible` (évite la superposition), le `Switch` + texte "Filtre recherche genre" remplacé par un `IconButton` compact (icône `tune`/`tune_outlined`, ambre si actif) avec tooltip `datingGenderSearchFilter`.
- Nouvelle clé i18n `datingGenderSearchFilter` (8 langues).

### 5. Page détail profil (`dating_profile_detail_page.dart`) : badge abonnement cliquable + CTA plan gratuit
- Réorganisation de `_buildProfileInfo()` : badge d'abonnement, bouton de vérification, bouton créateur et CTA plan gratuit s'affichent désormais **avant** la rangée de statistiques (likes/coups de cœur/matches/visites), qui est maintenant dans sa propre carte en bas.
- `_buildOwnerSubscriptionBadge()` : sur son propre profil, le badge de plan (Gratuit/Plus/Gold) est cliquable (`Tooltip` + `chevron_right`) et ouvre `DatingSubscriptionPage`, quel que soit le plan actuel.
- `_buildFreePlanCta()` : si le plan du propriétaire est `gratuit`/`null`, affiche une carte d'incitation (titre + description listant les avantages Plus/Gold : messages directs sans match, voir qui a liké, swipes/likes illimités, boost...) avec bouton "Voir les offres" → `DatingSubscriptionPage`.
- Nouvelles clés i18n (8 langues) : `datingTapToViewPlans`, `datingFreePlanCtaTitle`, `datingFreePlanCtaDesc`, `datingUpgradeNow`.

### 6. Modal "recharger les pièces" pour le boost (`dating_entry_page.dart`)
- Nouvelle méthode `_showInsufficientCoinsForBoostDialog(int requiredCoins)` : si le solde est insuffisant lors de l'activation d'un boost (rapide ou longue durée), affiche un `AlertDialog` "Solde insuffisant" indiquant le nombre de pièces requis (`datingBoostCoinsNeeded`, placeholder `{coins}`) avec un bouton "Recharger" → `BuyCoinsPage`.
- Remplace l'ancien comportement (simple `SnackBar` `datingInsufficientCoinsForBoost`) dans `_activateBoost()` et `_activateLongBoost()`.
- Nouvelle clé i18n `datingBoostCoinsNeeded` (8 langues).

### 7. Fix bug souscription : "Transactions require all reads to be executed before all writes"
- `dating_subscription_page.dart` → `_subscribe()` : la transaction faisait `transaction.get(userRef)` (lecture) → `transaction.update(userRef, ...)` (écriture) → puis `transaction.get(doc.reference)` pour chaque ancien abonnement (lecture après écriture = erreur Firestore).
- Corrigé : toutes les lectures (solde utilisateur si plan payant) sont faites en premier, puis toutes les écritures (débit pièces, désactivation des anciens abonnements via les références déjà récupérées par la requête pré-transaction, création du nouvel abonnement, log de transaction de pièces).

**Vérification (session 43)** : `flutter analyze` sur tous les fichiers modifiés → **0 erreur** (uniquement warnings/infos préexistants).

### 8. Proposition : recharge de compte par carte bancaire (Google Pay vs alternatives) — NON IMPLÉMENTÉ
**Demande** : permettre à n'importe quel utilisateur muni d'une carte bancaire de recharger son solde de pièces (FCFA), idéalement avec un prestataire qui prend en charge les frais de transaction.

**Analyse** :
- **Google Pay** : n'est qu'un wallet/UI de paiement, nécessite un processeur de paiement (Stripe, Adyen, Braintree...) en arrière-plan pour effectuer l'encaissement réel. Ces processeurs ont un support marchand très limité/inexistant pour la zone FCFA (Côte d'Ivoire, Sénégal, Cameroun, etc.), ce qui le rend difficilement exploitable directement.
- **Google Play Billing (achat intégré)** : obligatoire sur Android pour de la "monnaie virtuelle" selon la politique du Play Store, mais commission de 15-30% et paiements non disponibles en FCFA — solution la plus coûteuse et la moins adaptée ici.
- **CinetPay / FeexPay / PayGate** (déjà présents, partiellement commentés dans `lib/pages/paiement/newDepot.dart`) : couvrent à la fois le Mobile Money (Orange Money, MTN, Wave, Moov) **et** les cartes bancaires Visa/Mastercard internationales, facturation native en FCFA, frais de transaction carte gérés par le prestataire (CinetPay/FeexPay) plutôt que par l'application.

**Recommandation** : ne pas intégrer Google Pay/Play Billing pour cette fonctionnalité (incompatibilité FCFA + coût). Finaliser/activer l'intégration CinetPay (ou FeexPay) déjà présente dans `newDepot.dart` pour la recharge de pièces — couvre déjà le besoin "carte bancaire pour tous" en FCFA avec frais pris en charge par le prestataire.

**Prochaines étapes (si validées)** :
1. Décommenter et finaliser `_processCinetPayPayment()` dans `newDepot.dart`, en vérifiant la config API CinetPay (clé API, site ID) dans `lib/models/payment_config.dart`.
2. Vérifier le webhook/callback de confirmation de paiement côté backend (Cloud Functions) pour créditer `coinsBalance` après paiement carte validé.
3. Ajouter un test de bout en bout : recharge par carte bancaire (CinetPay) → crédit du solde → vérification dans `user_coin_transactions`.

## Session 44 — Sécurité carte : floutage de la position GPS des autres profils (anti-triangulation, façon Tinder)

**Contexte** : `dating_map_page.dart` affichait la position GPS exacte (`latitude`/`longitude`) de chaque profil, ce qui permettrait à une personne malveillante de retrouver le lieu de vie réel d'un autre utilisateur en recoupant plusieurs observations. Tinder résout ce problème en n'affichant jamais de point exact : un décalage aléatoire est appliqué à la position affichée, et la distance montrée est arrondie.

**Implémenté** (`lib/models/dating_data.dart`) :
- Nouveau getter `DatingProfile.fuzzedLocation` : applique un décalage aléatoire d'environ 300 m, **stable par profil et recalculé une fois par jour** (seed = `userId` + index du jour, via `Random`), avant d'exposer la position d'un autre utilisateur. La position réelle (`latitude`/`longitude`) reste utilisée en interne pour le tri par proximité/`recommendationScore` (jamais affichée telle quelle).
- Nouvelle fonction `formatDistanceKm(double)` : arrondit la distance affichée (`< 1 km`, `3 km`, etc.) au lieu d'une décimale précise (`3.2 km`).

**Implémenté** (`lib/pages/dating/dating_map_page.dart`) :
- Les marqueurs de la carte utilisent désormais `profile.fuzzedLocation` (au lieu de `profile.latitude!`/`profile.longitude!`) pour les autres utilisateurs ; le marqueur "moi" reste sur la position exacte de l'utilisateur courant (`widget.myLatitude`/`myLongitude`, sa propre position).
- Le centrage initial de la carte (cas où la position de l'utilisateur courant est inconnue) utilise aussi `fuzzedLocation` du premier profil affiché.
- La distance affichée dans la carte de profil sélectionné utilise `formatDistanceKm()` au lieu de `toStringAsFixed(1)`.

**Vérification** : `flutter analyze lib/models/dating_data.dart lib/pages/dating/dating_map_page.dart` → **0 erreur**.

**Limites / suite possible** : le floutage est appliqué uniquement côté client (les coordonnées exactes restent dans Firestore et transitent via les requêtes de profils). Pour une protection complète, envisager côté backend (Cloud Function) de ne renvoyer qu'une position déjà floutée/un `geohash` tronqué aux clients autres que le propriétaire — non fait dans cette session pour limiter le risque de régression sur les requêtes de proximité existantes.

### Information utilisateur sur le floutage (1 fois/mois)
- `dating_map_page.dart` : nouveau `_maybeShowPrivacyNotice()` (même pattern que la modal "Comment ça marche" — `shared_preferences`, clé `dating_map_privacy_notice_last_shown`) : à la première ouverture de la carte, puis au maximum une fois par mois, affiche une `AlertDialog` (`datingMapPrivacyTitle` / `datingMapPrivacyDesc` / bouton `datingMapPrivacyGotIt`) expliquant que la position affichée des autres profils est volontairement floutée pour leur sécurité.
- Nouvelles clés i18n (8 langues) : `datingMapPrivacyTitle`, `datingMapPrivacyDesc`, `datingMapPrivacyGotIt`.

**Vérification** : `flutter analyze lib/pages/dating/dating_map_page.dart lib/l10n/app_localizations.dart` → **0 erreur**.

**Backlog** : tâche #8 ("Dating: theme+i18n+CDN `dating_subscription_page.dart`") marquée comme **complétée**.

## Session 45 — Explication de la demande de position + redirection vers les paramètres si refusée

**Contexte** : sur la page de création de profil (`dating_profile_setup_page.dart`), la position GPS est demandée silencieusement, sans expliquer son utilité, et si l'utilisateur refuse, rien ne l'invite à l'activer plus tard.

**Implémenté** (`lib/pages/dating/dating_profile_setup_page.dart`) :
- Nouveau champ d'état `_locationPermissionDenied`, mis à jour dans `_detectLocationInBackground()` selon le résultat de `Permission.location.request()`.
- Dans `_buildLocationSection()` :
  - Ajout d'un bandeau d'information toujours visible (mobile) expliquant pourquoi la position est demandée : trouver des profils à proximité et afficher une distance approximative (jamais exacte aux autres utilisateurs) — clé `datingLocationWhyDesc`.
  - Ajout d'un bandeau conditionnel (`if (_locationPermissionDenied)`) expliquant que sans position, aucun profil à proximité ne pourra être proposé, avec un bouton "Ouvrir les paramètres" (`openAppSettings()` de `permission_handler`) — clés `datingLocationPermissionDeniedTitle`, `datingLocationPermissionDeniedDesc`, `datingOpenSettings`.

**Nouvelles clés i18n (8 langues)** dans `lib/l10n/app_localizations.dart` : `datingLocationWhyTitle`, `datingLocationWhyDesc`, `datingLocationPermissionDeniedTitle`, `datingLocationPermissionDeniedDesc`, `datingOpenSettings`.

**Vérification** : `flutter analyze lib/pages/dating/dating_profile_setup_page.dart lib/l10n/app_localizations.dart` → **0 erreur** (uniquement des infos préexistantes, sans rapport avec ce changement).

---

## Session 46 — Feed home doublons, rémunération vues, marketing affiliation, dating swipe fixes

### 1. Fix doublons feed Home (`HomeConstPost.dart`) ✅ FAIT

**Cause** : race condition entre `_startOldPostsLoading()` (lancé avec `_loadedPostIds` vide) et `_loadInitialPosts()`.

**3 corrections appliquées** :
- **Fix A (déduplication au rendu)** : `oldBuffer` filtré contre `_loadedPostIds` dans `_buildContent()`.
- **Fix B (ordre d'exécution)** : `_startOldPostsLoading()` déplacé APRÈS `_loadInitialPosts()` dans les deux branches (avec et sans cache), en utilisant `await` sur `_loadInitialPosts()` dans la branche sans cache.
- **Fix C (borne supérieure date)** : dans `_fetchOldPostsForWindow()`, la borne supérieure est plafonnée à `now - 2 jours` pour éviter que les anciens posts chevauchent les nouveaux posts chargés ce jour.

### 2. Système de rémunération des vues de posts ✅ FAIT

**Nouveau fichier** `lib/services/postService/post_view_service.dart` :
- `recordAuthorView(post, viewerUserId)` : incrémente `totalPostUniqueViews`, `postViewsAvailable (+2 FCFA)`, `postViewsMonthly.$month` dans Firestore — uniquement pour `type == POST` et `auteur ≠ viewer`.
- `migrateUserPostViews(userId)` : migration one-time (flag `postViewsMigrationDone`) qui agrège les vues des 3 derniers mois.
- `fixMonthlyData(userId)` : recalcule uniquement `postViewsMonthly` sans toucher au solde/total (pour corriger les dates corrompues).
- `_parseCreatedAt()` : auto-détection µs (> 10¹³) vs ms → `DateTime.fromMicrosecondsSinceEpoch`/`fromMillisecondsSinceEpoch`.

**Correction dates corrompues ("Avril 57708", "Février 577737")** :
- Cause : `created_at` stocké en µs mais ancienne migration utilisait `fromMillisecondsSinceEpoch` → années ~57 000.
- Fix : `_parseCreatedAt()` auto-détecte l'unité ; filtrage côté client (pas de filtre date Firestore car valeurs µs/ms incomparables).

**Refonte `lib/pages/user/mes_gains_post_page.dart`** (réécriture complète) :
- AppColors + AppLocalizations (8 langues), taux `1 vue = 2 FCFA`, seuil encaissement 1 000 FCFA.
- Section historique mensuel : filtre **strictement les 3 derniers mois valides** (`.take(3)` + filtre par date réelle), ignore les clés avec année > `currentYear + 1`.
- `_hasCorruptMonthly()` : détecte les données corrompues et appelle `fixMonthlyData` si besoin.
- Boutons rapides 25%/50%/100% pour montant à encaisser.

### 3. Modal rémunération + homeScreen ✅ FAIT

**`lib/pages/home/listTopModal.dart`** — `showRemunerationAnnounceModal` réécrit :
- Badge "NOUVEAU" rouge, icône dorée `monetization_on_rounded`.
- Taux affiché via clé i18n `remuModalRate` ("1 vue = 2 FCFA").
- 3 points explicatifs (`remuModalPoint1/2/3`), bouton CTA → `MesGainsPage`.

**`lib/pages/home/homeScreen.dart`** :
- `'remuneration'` ajouté dans la liste prioritaire des modals : `['affiliation_marketing', 'remuneration', 'invite_amis']`.
- Bug corrigé : `if (modalToShow == 'remuneration')` → `else if` (logique de dispatch cassée sans `else`).

### 4. Pages Marketing affiliation ✅ FAIT

- `lib/pages/Marketing/affiliationMarketing.dart` : refonte UI avec AppColors + AppLocalizations.
- `lib/pages/Marketing/pageExplicationMarketing.dart` : refonte UI avec AppColors + AppLocalizations.
- **Nouveau fichier** `lib/pages/Marketing/affiliation_announce_modal.dart` : modal d'annonce programme affiliation.
- Commission split : **75% parrain affiché dans l'UI** — les 25% de revenus app ne sont JAMAIS mentionnés nulle part (modals, textes, traductions, notifications).

### 5. Dating swipe — fixes boucle infinie + persistance position ✅ FAIT

**Fix A — Passes persistés dans Firestore** (`dating_entry_page.dart`) :
- Nouveau set `_passedUserIds` (séparé de `_excludedUserIds` qui contient likes/matchs).
- `_passProfile(userId)` : écrit dans la collection `dating_passes` + ajoute immédiatement à `_passedUserIds`.
- `_handleSwipeLeft()` : appelle `_passProfile(profile.userId)` à chaque swipe gauche.
- `_loadExcludedUserIds()` : charge aussi `dating_passes` au démarrage (4e requête dans `Future.wait`).
- `_loadProfiles()` : filtre `_passedUserIds` **en premier**, avant tout filtre, et ce filtre ne peut jamais être désactivé.
- Résultat : les profils passés **ne reviennent jamais**, même après un restart de cycle.

**Fix B — Cache statique étendu** :
- `_cachedPassedUserIds` : cache statique ajouté pour `_passedUserIds`.
- `_saveDeckCache()` / `_restoreDeckCache()` : sauvegardes/restaurations incluent les passes.
- `_passProfile()` met à jour `_cachedPassedUserIds` immédiatement (sans attendre la navigation).

**Fix C — Écran "Tu as tout vu !" quand deck épuisé** :
- `bool _deckExhausted` : flag activé quand aucun profil n'est trouvable.
- `_restartDiscoveryCycle()` refondé en 4 étapes ordonnées :
  1. Profils frais (excluant likes + passes) → si trouvé, on continue
  2. Réinclure les likés/matchés (mais jamais les passes) → si trouvé, on continue
  3. Élargir les filtres âge/pays → dernière tentative
  4. Deck vraiment épuisé → `_deckExhausted = true`
- Nouvel écran "Tu as tout vu ! 🎉" (icône trophée, texte explicatif, bouton "Actualiser").
- Nouvelles clés i18n : `datingDeckExhaustedTitle`, `datingDeckExhaustedSubtitle` (8 langues).

**Vérification** : `flutter analyze lib/pages/dating/dating_entry_page.dart lib/l10n/app_localizations.dart` → **0 erreur** (91 infos/warnings pré-existants).

---

## Session 47 — OtherUserPage : refonte complète (thème, i18n, onglet Publicités, audio fallback)

### Fichiers modifiés
- `lib/pages/user/otherUser/otherUser.dart`
- `lib/l10n/app_localizations.dart` (22 nouvelles clés)
- `lib/pages/Marketing/affiliationMarketing.dart`
- `lib/pages/user/mes_gains_post_page.dart`
- `lib/services/postService/post_view_service.dart`

### Réalisé

**Suppression du stream Firestore** :
- `_listenToUserChanges()` / `_userSubscription` remplacés par une lecture unique de `widget.otherUser.userlikes` dans `initState`.
- Imports nettoyés : supprimé `dart:async`, `video_thumbnail`, `constColors`, `sizeText`, `textCustom`.

**Onglet Publicités** :
- Nouvel onglet "Publicités" dans le toggle de filtre (Posts / Publicités).
- `_loadInitialAds()` / `_loadMoreAds()` : chargement paginé des posts `isAdvertisement == true`.
- `_fetchAdvertisements(List<Post>)` : batch-fetch des objets `Advertisement` via Firestore `whereIn` (max 30 par requête), avec cache `_adsData: Map<String, Advertisement>` pour éviter les re-chargements.
- `_buildAdCard(Post, double)` : card pub avec stats (Vues / Clics / CTR), badge statut coloré, bouton d'action (`getActionButtonText()` / `getActionIcon()`).
- Grille ads avec `childAspectRatio: 0.65` (plus de hauteur pour les stats).

**Thème AppColors + i18n AppLocalizations** :
- Toutes les couleurs hardcodées remplacées par `AppColors.of(context)`.
- 22 nouvelles clés i18n ajoutées (8 langues) dans `app_localizations.dart` :
  - Navigation : `otherUserSubscribe`, `otherUserUnsubscribe`, `otherUserAbout`, `otherUserNoDescription`
  - Filtres : `otherUserFilterTitle`, `otherUserTabPosts`, `otherUserTabAds`, `otherUserFilterAll/Images/Videos/Texts/Audios`
  - États vides : `otherUserNoPosts`, `otherUserNoAds`, `otherUserNoFilterPosts(String type)`
  - Profil : `otherUserReferralCode`, `otherUserSponsorships`, `otherUserLikesReceived`, `otherUserCodeCopied`, `otherUserVerified`, `otherUserShareProfile`, `otherUserSendReminder`

**Affichage des posts** :
- Vidéo : `post.thumbnail` stocké → image + play icon ; sinon container gris + play (suppression de `VideoThumbnail.thumbnailData()` async).
- Types corrigés en MAJUSCULES dans `_getPostTypeIcon` / `_getPostTypeLabel` (correspondance Firestore : `VIDEO`, `IMAGE`, `TEXT`, `AUDIO`).
- Pagination : `_postsPerPage = 12` (était 5), `startAfterDocument`.

**Audio — fallback `post.images`** :
- Ordre de priorité pour la couverture d'un post audio :
  1. `post.thumbnail` (non vide) → image + badge headphones bas-gauche
  2. `post.images` (non vide) → `images.first` + badge headphones bas-gauche
  3. Aucune image → dégradé violet + headphones centré

**Commit** : `6404d95`

**Vérification** : `dart analyze` → 0 erreur (warnings/infos pré-existants uniquement).

---

## Session 48 — Gestion des publicités : refonte UI tableau de bord (admin)

### Fichier modifié
- `lib/pages/user/userPubs/user_my_advertisements_page.dart` (réécriture complète)

### Réalisé

**Thème clair/sombre (AppColors)** :
- Suppression de toutes les constantes de couleur hardcodées (`_primaryColor`, `_cardColor`, `_backgroundColor`, etc.)
- `late AppColors _colors` initialisé dans `build()`, utilisé dans toutes les méthodes

**Tableau de bord KPI** :
- Ligne 1 : 4 cartes cliquables — En attente / Actives / Expirées / Rejetées (chacune filtre la liste au tap)
- Ligne 2 : Annulées + Toutes (filtre global)
- Animation `AnimatedContainer` au sélection
- CTA "Créer une publicité" intégré dans le tableau de bord

**Chips de filtre horizontaux** : Toutes / Actives / En attente / Expirées / Rejetées / Annulées — couleur sémantique par statut, animation de sélection

**Fix dates expirées** :
- `_loadCounters()` : pour chaque annonce `status='active'` dont `endDate <= now` → corrige automatiquement le statut à `'expired'` dans Firestore + mémorise l'ID dans `_autoFixedIds`
- `_effectiveStatus()` : helper client-side pour rattraper les cas non encore propagés dans le stream
- Filtre client-side dans le `StreamBuilder` pour la cohérence immédiate
- Bannière d'alerte orange sur les cartes auto-corrigées

**Onglet Annulées** :
- Statut `'cancelled'` désormais comptabilisé et filtrable
- `_statusLabel`, `_statusColor`, `_statusIcon` couvrent les 5 statuts

**Aperçu du post selon son type** (`_buildPostPreview`) :
- `IMAGE` → première image via `CachedNetworkImage`
- `VIDEO` → thumbnail/première image + icône play centré + badge "Vidéo"
- `AUDIO` → thumbnail ou `images.first` + badge headphones ; sinon dégradé violet
- `TEXT` → fond surfaceVariant + icône + description (4 lignes max)
- `EBOOK` / autre → première image si disponible, sinon icône menu_book

**Chargement post indépendant** : `_buildAdCardWithPost(doc)` utilise un `FutureBuilder<DocumentSnapshot>` par carte → les cards apparaissent avec un placeholder immédiatement, le post se charge indépendamment sans bloquer la liste

**Cartes publicité redessinées** :
- Aperçu post 130px pleine largeur
- Badge statut + ID court + date de création
- Barre `LinearProgressIndicator` (rouge si ≤3j, gris si expiré/annulé)
- Dates début/fin + prix payé
- Bloc stats (Vues / Clics / CTR) bordé
- Motif de rejet si présent
- Boutons : Détails / Renouveler (uniquement si active ou expirée) / Supprimer

**Commit** : `e42ba4f`

### Session 49 (18 juin 2026 — agent actuel)

**Page admin publicités — refonte UI complète ✅ FAIT**

- `lib/pages/admin/AfrolookPub/afrolookAdminPubPage.dart` (`AdvertisementManagementPage`) — réécriture complète :

**AppColors dark/light** :
- Suppression de toutes les constantes hardcodées (`_primaryColor = Color(0xFFE21221)`, `_secondaryColor`, `_backgroundColor = Color(0xFF121212)`, `_cardColor`, `_textColor`)
- Pattern `late AppColors _colors` initialisé dans `build()` via `AppColors.of(context)`

**Auto-fix dates expirées** :
- `_loadGlobalStats()` : détecte les annonces `status='active'` avec `endDate <= now`
- Correction automatique Firestore (`status: 'expired'`) en `Future.wait` groupé
- IDs mémorisés dans `_autoFixedIds: Set<String>`
- `_effectiveStatus(data)` helper client-side utilisé dans le `StreamBuilder` pour cohérence immédiate
- Bannière alerte orange sur les cartes auto-corrigées

**6 onglets TabBar** (ajout de l'onglet Annulées) :
- Stats / En attente (badge rouge si > 0) / Actives / Expirées / Rejetées / Annulées
- `TabController(length: 6, ...)`
- `_cancelledAds` comptabilisé dans `_loadGlobalStats()`

**Aperçu du post selon son type** (`_buildPostPreview`) :
- `IMAGE` → première image via `CachedNetworkImage`
- `VIDEO` → thumbnail/images.first + play centré + badge "Vidéo"
- `AUDIO` → thumbnail/images.first + badge headphones ; sinon `_buildAudioGradient()` (dégradé violet)
- `TEXT` → fond surfaceVariant + icône + description 4 lignes max
- `EBOOK` / autre → images.first ou icône menu_book

**Chargement post indépendant** : `_buildAdCardWithPost(doc)` avec `FutureBuilder<DocumentSnapshot>` par carte

**Cartes publicité redessinées** :
- Aperçu 130px pleine largeur (type-aware)
- Badge statut + ID court + date création + prix payé
- Bannière alerte auto-fix (si applicable)
- Description post (2 lignes max)
- Lien + bouton d'action (si présent)
- Barre `LinearProgressIndicator` (orange si ≤3j restants, gris si expiré/annulé)
- Dates début/fin avec indication dépassement
- Bloc stats : Vues / Clics / CTR / Vues uniques
- Motif rejet (si applicable)
- Boutons d'action admin selon statut :
  - Pending : **Accepter** (vert) / **Rejeter** (rouge, ouvre dialog motif + remboursement) / Supprimer
  - Active : **Annuler** / **Prolonger** (dialog durée, gratuit admin) / Supprimer
  - Expired : **Prolonger** / Supprimer
  - Rejected / Cancelled : Supprimer uniquement

**Actions admin préservées** :
- `_refundUser(ad)` : crédite `Users.votre_solde_principal` + log `TransactionSolde` GAIN
- `_updateAdStatus(ad, status, {reason})` : appelle `_refundUser` si rejet de pending
- `_renewAd(ad, days)` : prolonge sans débit (admin), choix 7/14/30/60/90 jours
- `_deleteAd(ad)` : supprime annonce + post associé (avec confirmation)
- Dialog rejet : motif obligatoire + message remboursement affiché

**Onglet Stats redessiné** :
- Grille 3 colonnes : Total / En attente / Actives / Expirées / Rejetées / Annulées
- Grille 2 colonnes : Vues totales / Clics / Vues uniques / CTR global
- Carte revenus totaux (pubs actives + expirées)
- Top 5 par vues et Top 5 par clics (barres avec rang coloré)
- Activité 7 derniers jours (barres de progression horizontales)
- `RefreshIndicator` pour rechargement manuel

**`dart analyze`** → 0 erreur, 0 warning (18 `info` : `withOpacity` dépréciés pré-existants dans tout le projet, non bloquants)

### Session 50 (18 juin 2026 — agent actuel)

**Système publicitaire — améliorations complètes ✅ FAIT**

**Commit** : `da8f91a`

**1. Config tarifaire centralisée — `lib/services/ad_config_service.dart`** (nouveau fichier) :
- Classe `AdDuration` : `{weeks, price, label}`
- Classe `AdConfigService` : lecture Firestore `AdConfig/pricing` avec cache 30 min + fallback sur les 5 durées par défaut (2/4/12/24/52 semaines)
- Méthodes : `getDurations()`, `toMap()`, `labelFor()`, `update()`, `invalidateCache()`
- Tarifs par défaut : 2 sem. 2 500 FCFA · 1 mois 4 500 FCFA · 3 mois 10 000 FCFA · 6 mois 18 000 FCFA · 12 mois 30 000 FCFA

**2. Éditeur de tarifs admin — `afrolookAdminPubPage.dart`** :
- Bouton `Icons.price_change_outlined` dans l'AppBar
- Dialog avec champs de prix éditables par durée (clavier numérique)
- Sauvegarde dans `AdConfig/pricing` via `AdConfigService.update()` + invalidation du cache

**3. Boost post depuis `postDetails.dart`** :
- Variables : `_ownerAdForPost`, `_isLoadingOwnerAd`, `_ownerAdLoaded`
- `_loadOwnerAd()` : requête `Advertisements.where('postId', isEqualTo: post.id).limit(1)` — appelée si `userId == post.user_id`
- `_buildBoostSection()` : section visible uniquement pour le propriétaire du post
  - **Aucune pub** → bouton "Créer une publicité" → `UserCreateAdvertisementPage(existingPost: post)`
  - **Pending** → badge "En attente de validation"
  - **Active/Expirée** → stats (Vues/Clics/CTR) + dates + bouton "Renouveler" avec dialog durée/prix
  - **Annulée/Rejetée** → message "Contacter l'administrateur"
- `_renewBoostAd()` : débit solde + log `TransactionSolde` DEPENSE + mise à jour Firestore (status: `pending`, nouveaux dates, `pricePaid` incrémenté)
- Section insérée dans l'arbre build après `_buildAdvertisementHeader()`

**4. "Booster un post existant" — `user_create_advertisement_page.dart`** :
- `Post? existingPost` ajouté au constructeur
- Tarifs chargés depuis `AdConfigService` (plus de `Map` hardcodé)
- Mode **boost** : affichage aperçu du post existant + skip section upload médias + skip création de nouveau Post (lien direct sur le `postId` existant)
- `initState` : pré-remplit `_descriptionController` depuis `existingPost.description`
- `_publishAdvertisement()` : branche `isBoost` → update le post existant (`isAdvertisement: true`, `availableCountries`, `description`) puis crée uniquement l'`Advertisement`
- Nettoyage des imports dupliqués + ajout `foundation.dart` et `flutter_vector_icons`

**5. `user_my_advertisements_page.dart`** :
- Tarifs lus depuis `AdConfigService` au lieu du `Map` hardcodé
- `_getDurationLabel()` délégué à `AdConfigService.labelFor()`

**6. Comptage aléatoire 1–3 dans tous les widgets pub** :
- `advertisementPostImageWidget.dart` : vues et clics → `FieldValue.increment(Random().nextInt(3) + 1)`
- `advertisement_video_widget.dart` : idem
- `ad_post_page_video_widget.dart` : idem
- `postDetails.dart` (`_recordAdClick`) : idem
- Note : les compteurs `uniqueViews` / `uniqueClicks` restent à `increment(1)` (vue/clic unique par utilisateur, non amplifié)

**7. Règle pub annulée/rejetée = admin uniquement** :
- `postDetails.dart` : section boost affiche message "Contacter l'administrateur" sans bouton pour ces statuts
- `user_my_advertisements_page.dart` : déjà enforced (pas de bouton Renouveler pour cancelled/rejected — session 48)

**`dart analyze`** → 0 erreur, 0 warning (infos pré-existants, non bloquants)

---

## Session 51 — Affichage pub dans pages détail vidéo + injection pubs dans chroniques + préchargement

**Date :** 2026-06-18  
**Fichiers modifiés :**
- `lib/services/ad_preload_service.dart` *(nouveau)*
- `lib/pages/postDetailsVideo.dart`
- `lib/pages/post_video_format_tel_details.dart`
- `lib/pages/chronique/chroniquedetails.dart`

---

**1. Nouveau service — `AdPreloadService` (`lib/services/ad_preload_service.dart`)** :
- Singleton qui pré-initialise les `VideoPlayerController` des pubs vidéo actives au démarrage
- `preload()` : charge les pubs actives depuis Firestore (limit 10), initialise les contrôleurs vidéo (muted + looping), stocke dans `_controllers[adId]`
- `getController(adId)` : retourne le contrôleur pré-initialisé ou null
- `getRandomActiveAd()` : pub active aléatoire parmi celles chargées
- `invalidate()` : vide le cache (dispose les contrôleurs)
- Pubs sans `postId` ou expirées → ignorées ; pubs sans `url_media` → ignorées (images uniquement)

**2. `postDetailsVideo.dart` (VideoYoutubePageDetails)** :
- Random 1–3 sur `_recordAdClick` : `FieldValue.increment(Random().nextInt(3) + 1)`
- Nouvelle méthode `_recordAdView(ad)` : random 1–3 pour vues + `uniqueViews` fixe à 1 + `dailyStats.$today.views`
- `_loadAdvertisement()` : appelle `_recordAdView(ad)` après succès
- Header pub (`_buildAdvertisementHeader`) réécrit avec `AppColors.of(context)` + ligne stats (Vues / Clics / CTR)
- `_loadOwnerAd()` : requête `Advertisements.where('postId')` — charge si utilisateur = propriétaire
- `_buildBoostSection()` : section Boost propriétaire (identique à `postDetails.dart` — bouton Booster / stats / renouveler)

**3. `post_video_format_tel_details.dart` (PostDetailsVideoFormatTel)** :
- Cache d'ads : `Map<String, Advertisement?> _adCache` + `Set<String> _loadingAdIds`
- `_ensureAdLoaded(post)` : charge l'`Advertisement` depuis Firestore, enregistre vue (random 1–3), stocke dans `_adCache`
- `_recordAdViewForPost(ad)` : random 1–3 vues + uniqueViews fixe
- `_buildVideoAdOverlay(post)` : overlay positionné sur la vidéo — badge **SPONSORISÉ**, stats (vues/clics/CTR), bouton d'action (random 1–3 clics)
- `_buildVideoPage(post)` : branche `isAdvertisement` → `_buildVideoAdOverlay` au lieu de `_buildActionButtons`

**4. `chroniquedetails.dart` (ChroniqueDetailPage) — injection pubs entre chroniques** :
- `_activeAds`, `_adImageUrls` : liste de pubs + map URL images pré-chargées
- `_loadActiveAds()` : charge pubs Firestore + URLs images des posts en parallèle (`Future.wait`) → plus de FutureBuilder lent
- Getter `_displayItems` : liste mixte `Chronique | Advertisement` — 1 pub après la 1ère chronique (i=0), puis 1 pub toutes les 3 chroniques (i=3, 6, 9…)
- Helpers : `_virtualToChronique(int)`, `_isVirtualAd(int)`, `_chroniqueToVirtual(int)` — maintient `_currentPage` en index chronique même si le PageView inclut des slots pub
- `_recordAdView(ad)` / `_recordAdClick(ad)` : random 1–3 pour vues et clics
- `_buildAdSlide(ad)` :
  - Fond `BoxFit.cover` assombri (opacité 55 %) → image pré-chargée depuis `_adImageUrls`
  - Image principale `Positioned.fill` + `BoxFit.contain` → affichage correct images paysage/portrait
  - Dégradés haut + bas pour lisibilité
  - Badge **SPONSORISÉ** positionné en haut
  - Bouton d'action : `bottom: _showMessages ? 280.0 : 120.0` → jamais caché par le bottom bar de saisie

**Fixes bugs** :
- Images pubs dans chroniques ne s'affichaient pas en grand → réglé avec `BoxFit.contain` + fond `BoxFit.cover`
- Bouton d'action caché par le champ de saisie → offset dynamique selon `_showMessages`
- Chargement lent des images → pré-chargement URLs dans `_loadActiveAds()` via `Future.wait`
- Champ `_virtualPage` inutilisé → supprimé

**`dart analyze`** → 0 erreur sur tous les fichiers modifiés

---

## Session 52 — Refonte système de messagerie niveau WhatsApp + UI chat

**Date :** 2026-06-19  
**Fichiers modifiés :**
- `pubspec.yaml`
- `lib/widgets/chat/chat_bubble_widget.dart` *(nouveau)*
- `lib/pages/chat/myChat.dart`
- `lib/pages/user/conversation/listUserConv.dart`
- `lib/pages/user/userAbonnementPage.dart`

---

**1. Nouveaux packages (`pubspec.yaml`)** :
- `emoji_picker_flutter: ^3.1.0` (remplace `^2.2.0` commenté qui conflictait avec `pdfx`)
- `lottie: ^3.1.2` (stickers animés / gifts futurs)
- `flutter_slidable: ^3.1.1` (swipe actions sur liste conversations)

---

**2. Nouveau widget `lib/widgets/chat/chat_bubble_widget.dart`** :

Ensemble de widgets exportés utilisés dans `myChat.dart` :
- `ChatDateSeparator` — pill de date (fond vert transparent)
- `TypingIndicator` — 3 dots animés via `flutter_animate`
- `ReadReceiptIcon` — check / check_all coloré selon état
- `TextBubble` — bulle texte avec dégradé vert (envoyé) / fond sombre (reçu), shadow
- `_EmojiOnlyBubble` — emoji seul 44px avec animation scale
- `ImageBubble` / `MultiImageBubble` — image(s) avec coins arrondis, layout 1/2/3 photos
- `AudioBubble` — waveform animée (20 barres, seed `message.id.hashCode` = cohérent) + bouton play circulaire
- `MessageMeta` — heure + `ReadReceiptIcon`
- `_ReplyPreview` — citation avec bordure gauche colorée
- `_ReactionChip` — pill emoji flottant

---

**3. Refonte `myChat.dart`** (refonte majeure de l'UI) :

**Imports** : `emoji_picker_flutter`, `flutter_animate`, retrait de `chat_bubbles`  
**Fond** : `RadialGradient` subtil (4% opacité `primary`) sur tout le `Scaffold`

**Header (`_buildAppBar`)** :
- Gradient top transparent → teinte primaire 6%
- Avatar avec ring gradient pulsant (2px border, shadow verte)
- `TypingIndicator` animé à la place du texte statique

**Bulles** : `TextBubble` / `AudioBubble` / `ImageBubble` / `MultiImageBubble` / `ChatDateSeparator`

**Input bar (`_buildMessageInput`)** :
- Bouton + gradient → `_showAttachMenu()` (Photo / Multi-photos 👑 / Vocal)
- `EmojiPicker` toggle (280px, onglets personnalisés)
- Bouton envoi animé (scale spring) avec gradient vert
- Preview multi-images (strip horizontal)

**Fonctionnalités Premium (gate `_showPremiumGate`)** :
- Envoi jusqu'à 3 images simultanément (`_getMultipleImages()`, limit: 3)
- URLs supplémentaires stockées dans `message.imageText` séparées par `|`
- `MultiImageBubble` détecte `|` dans `imageText` → layouts 1/2/3 photos

**Méthodes nouvelles** :
- `_sendMultipleImagesMessage()` — upload parallèle, stockage multi-URL
- `_showPremiumGate(msg)` — bottom sheet paywall gold/dark avec route `/abonnement`
- `_getMultipleImages()` — vérification Premium avant sélection

---

**4. Refonte `listUserConv.dart`** :

**`ConversationList`** — widget entièrement redessiné :
- Paramètres ajoutés : `isPinned`, `isPro`, `messageType`
- Avatar 52px avec ring gradient (vert + glow si en ligne, gris si hors ligne)
- Badge **PRO** (dégradé or) si `UserData.hasEntreprise == true`
- Épingle (icône + fond teinté) si conversation épinglée
- Badge non-lus : fond vert, texte noir (meilleure lisibilité)
- Preview message enrichi : `📷 Photo` / `📷 3 photos` / `🎙️ Message vocal`

**Swipe actions `flutter_slidable`** :
- Glisser gauche → **Archiver** (avec undo snackbar)
- Glisser droite → **Épingler / Désépingler**
- Épinglés remontés en tête de liste (tri local)
- Conversations archivées masquées de la liste (avec undo)

**Section amis récents** — `_StoryRingAvatar` :
- Ring gradient animé (pulsation `ScaleTransition 1.0 → 1.08`) si ami en ligne
- Ring gris statique si hors ligne

---

**5. Page abonnement Premium (`userAbonnementPage.dart`)** :

Nouveaux avantages ajoutés dans la grille `_buildWhyPremiumSection` :
- 👻 **Mode fantôme** — présence en ligne masquable (`Colors.deepPurple`)
- 🖼️ **3 images** simultanément dans le chat (`Colors.cyan`)
- ✨ **Emojis 3D animés** exclusifs (`Colors.pink`)
- 🎭 **Stickers Afrolook** exclusifs (`Color(0xFFFF6B35)`)

Nouveaux détails dans la section expandable :
- Section "💬 Chat & Messagerie" avec 7 avantages listés
- Gifts animés (bientôt), thèmes personnalisés (bientôt), galerie média par conversation

---

**`dart analyze`** → 0 erreur sur tous les fichiers modifiés  
(warnings mineurs pré-existants : `unused_field`, `unused_element`, `print` — non liés)

---

## Session 53 — Sécurité Afrolook Messenger : chiffrement E2E, blocage, signalement, présence Premium

**Date :** 2026-06-19  
**Fichiers modifiés / créés :**
- `firestore.rules` *(nouveau)*
- `firebase.json`
- `lib/services/encryption_service.dart`
- `lib/pages/chat/myChat.dart`
- `lib/pages/home/user_presence_widget.dart`
- `lib/pages/user/privacy_settings_page.dart` *(nouveau)*

---

### Task 1 — Firestore Security Rules ✅

**Nouveau fichier `firestore.rules`** à la racine (versionné, déployable via `firebase deploy --only firestore:rules`).

Règles définies pour chaque collection :

| Collection | Lecture | Création | Mise à jour | Suppression |
|---|---|---|---|---|
| `Messages` | Participants uniquement (`send_by` ou `receiverBy == uid`) | Expéditeur + `is_valide: true` | Expéditeur: `is_valide/deleted_*` · Destinataire: `message_state` · Les deux: `reaction` | ❌ (logique via `is_valide`) |
| `Chats` | Participants uniquement | L'un des deux | L'un des deux | ❌ |
| `Users` | Tout utilisateur auth | — | Son propre document | — |
| `UserKeys` | Tout utilisateur auth | — | Sa propre clé | — |
| `Reports` | ❌ côté client | `reportedBy == uid` + champs obligatoires | ❌ | ❌ |
| `BlockedUsers` | Les deux parties | Bloqueur uniquement + champs obligatoires | ❌ | Bloqueur uniquement |
| `Friends` | Les deux parties | Les deux parties | Les deux parties | Les deux parties |
| `/*` (autres) | Auth uniquement | Auth uniquement | — | — |

`firebase.json` : ajout de `"firestore": { "rules": "firestore.rules" }`.

---

### Task 2 — Chiffrement E2E : plus jamais d'envoi en clair ✅

**`lib/services/encryption_service.dart`** — `getChatKey()` :
- Signature étendue : `maxRetries = 3`, `retryDelayMs = 1500 ms`
- Si la clé publique de l'autre utilisateur est absente → réessaie jusqu'à 3× (1,5 s entre chaque) avant de retourner `null`
- Méthode `invalidateChatKey(chatId)` ajoutée (rotation de clés future)

**`lib/pages/chat/myChat.dart`** — `_sendTextMessage()` :
- Si `_chatKey == null` au moment d'envoyer → relance `getChatKey()` (qui retente 3×)
- Si toujours `null` → SnackBar orange "Chiffrement en cours d'initialisation" + **`return`** (message non envoyé)
- `is_encrypted: true` toujours positionné quand la clé est disponible — **jamais d'envoi en clair silencieux**

---

### Task 3 — Suppression de message (traçabilité complète) ✅

**`lib/pages/chat/myChat.dart`** :

`_showMessageOptions(message)` redessiné :
- Aperçu tronqué du message en haut du sheet
- Options : Répondre · Copier (texte) · Signaler (reçus) · Supprimer pour tous (envoyés)

`_confirmDeleteMessage(message)` : dialog de confirmation avant suppression.

`_deleteMessage(message)` : écriture Firestore directe (sans passer par le modèle) :
```dart
_firestore.collection('Messages').doc(msgId).update({
  'is_valide': false,
  'deleted_at': DateTime.now().millisecondsSinceEpoch,  // int ms — cohérent avec le projet
  'deleted_by': myId,
  'delete_scope': 'all',
});
```

---

### Task 4 — Signalement de message ✅

**`lib/pages/chat/myChat.dart`** :

`_showReportSheet(message)` : bottom sheet avec 4 motifs :
- `spam` · `harassment` (Harcèlement ou menaces) · `inappropriate` (Contenu inapproprié) · `other` (Autre)

`_reportMessage(message, reason)` : écriture collection `Reports` :
```dart
_firestore.collection('Reports').doc('${msgId}_$myId').set({
  'reportedBy': myId,
  'messageId': msgId,
  'chatId': chatId,
  'reason': reason,
  'reportedUserId': message.sendBy,
  'createdAt': DateTime.now().millisecondsSinceEpoch,  // int ms
});
```
- ID = `${messageId}_${myId}` → un seul signalement par utilisateur par message
- Collection inaccessible côté client (Firestore Rules : lecture/update/delete = `false`)

---

### Task 5 — Blocage utilisateur ✅

**`lib/pages/chat/myChat.dart`** :

Nouvelles variables d'état : `_otherId`, `_isBlockedByMe`, `_isBlockedByOther`

`_loadBlockStatus()` : vérifie les deux directions (`${myId}_${otherId}` et `${otherId}_${myId}`) via `Future.wait` à l'init du chat.

`_blockUser()` : création de `BlockedUsers/${myId}_${otherId}` avec `createdAt: DateTime.now().millisecondsSinceEpoch`

`_unblockUser()` : suppression du même document

`_showChatMenu()` : bouton ⋮ dans l'AppBar → bottom sheet avec "Ma confidentialité" + "Bloquer/Débloquer @pseudo"

`_confirmBlockUser(pseudo)` : dialog de confirmation avant blocage

`_buildBlockBanner()` : bannière contextuelle :
- Si `_isBlockedByMe` → "Vous avez bloqué @pseudo" + bouton Débloquer
- Si `_isBlockedByOther` → "Vous ne pouvez pas envoyer de message à cette personne"

`_buildBlockedInputBar()` : input verrouillé (remplace `_buildMessageInput()` si bloqué dans l'un ou l'autre sens)

---

### Task 6 — Présence Premium (ghostMode, hideLastSeen) ✅

**`lib/pages/home/user_presence_widget.dart`** :
- Lit `data['privacySettings']` depuis le document Firestore de l'utilisateur affiché
- `ghostMode: true` → `effectiveOnline = false` (point vert masqué, texte "hors ligne")
- `hideLastSeen: true` → affiche `"—"` au lieu de "Il y a X min"
- Rétrocompatible : si `privacySettings` absent → comportement inchangé

**`lib/pages/user/privacy_settings_page.dart`** *(nouveau)* :
- Page accessible via le menu ⋮ du chat ("Ma confidentialité")
- Toggles avec Premium gate (🔑 → `/abonnement`) :
  - **Mode fantôme** (`ghostMode`) — apparaître hors ligne pour tous
  - **Masquer la dernière connexion** (`hideLastSeen`) — afficher "—"
  - **Masquer les accusés de lecture** — marqué "Bientôt"
- Écriture via notation pointée Firestore : `update({'privacySettings.ghostMode': value})` (sans modifier le modèle `UserData`)
- Bannière Premium cliquable si non Premium → `/abonnement`

---

**Convention dates** : toutes les nouvelles collections (`Reports`, `BlockedUsers`) et champs de traçabilité (`deleted_at`) utilisent **`DateTime.now().millisecondsSinceEpoch`** (int, millisecondes) — cohérent avec `create_at_time_spam`, `dating_data.dart`, `coin_pack.dart`, etc.

---

**À faire (sessions suivantes)** :
- [ ] Déployer `firestore.rules` via Firebase Console ou `firebase deploy --only firestore:rules`
- [ ] Typing indicator côté Firestore (champ `isTyping` en temps réel)
- [ ] Stickers Afrolook (picker + assets Lottie Premium)
- [ ] Gifts virtuels (animations Lottie + crédits Afrolook)
- [ ] Invitation externe (contact sans compte → `share_plus`)

---

## Session 54 — Messenger UX : annulation audio, cache liste, typing, réponse scrollable, page Premium

**Date :** 2026-06-19  
**Fichiers modifiés :**
- `lib/pages/chat/myChat.dart`
- `lib/widgets/chat/chat_bubble_widget.dart`
- `lib/pages/user/conversation/listUserConv.dart`
- `lib/pages/user/userAbonnementPage.dart`
- `lib/main.dart`

---

### Task 1 — Annulation enregistrement audio ✅

**`lib/pages/chat/myChat.dart`** :
- Ajout de `String? _highlightedMessageId` (pour le scroll)
- `_buildMessageInput()` : quand `_isRecording == true`, affiche `_buildRecordingBar()` au lieu du champ texte
- `_buildRecordingBar()` (nouvelle méthode) :
  - Bouton ❌ "Annuler" → `_stopRecording(cancel: true)` (efface le fichier temp)
  - Indicateur rouge 🔴 + chrono `MM:SS` (utilise `_recordingDuration` existant)
  - Bouton ▶ Envoyer → `_stopRecording()` (envoie)
- La méthode `_stopRecording({bool cancel = false})` existait déjà et gère les deux cas

---

### Task 2 — Suppression du double reply indicator ✅

**`lib/pages/chat/myChat.dart`** :
- Supprimé l'appel à `_buildReplyIndicator(message)` dans `_buildMessageBubble` (lignes 1016-1020)
- Supprimé la méthode `_buildReplyIndicator()` entière (51 lignes)
- `_ReplyPreview` dans `TextBubble` (`chat_bubble_widget.dart:356`) était déjà là depuis session 52 — il n'y avait plus de raison de doublon

---

### Task 3 — Scroll vers le message répondu ✅

**`lib/widgets/chat/chat_bubble_widget.dart`** :
- Ajout de `VoidCallback? onTapReply` à `TextBubble`
- `_ReplyPreview` enveloppé dans `GestureDetector(onTap: onTapReply)`

**`lib/pages/chat/myChat.dart`** :
- `_buildTextMessage()` : passe `onTapReply: () => _scrollToMessage(message.replyMessage.messageId)` si `messageId` non vide
- `_scrollToMessage(String messageId)` (nouvelle méthode) :
  - Utilise `GlobalObjectKey(messageId).currentContext` pour trouver le widget dans le tree
  - `Scrollable.ensureVisible()` avec `duration: 400ms, curve: easeInOut, alignment: 0.3`
  - Highlight 1 200 ms via `_highlightedMessageId` + `AnimatedContainer` gradient primary
- `_buildMessageList()` : chaque message wrapé dans `KeyedSubtree(key: GlobalObjectKey(message.id!))` + `AnimatedContainer` de highlight conditionnel

---

### Task 4 — Liste conversations : cache + typing + preview ✅

**`lib/pages/user/conversation/listUserConv.dart`** :

**Cache local (affichage instantané style WhatsApp) :**
- `_convCacheKey` : clé SharedPreferences `conv_list_{userId}`
- `_saveConvCache(chats)` : sérialise les 30 premières conversations (champs Chat + friend minimal + lastMsg JSON) après chaque mise à jour stream
- `_loadConvCache()` : lu dans `initState` — reconstruit des `ChatWithLastMessage` avec `Chat.fromJson` + `UserData` inline + `Message.fromJson` → `setState` immédiat, plus de spinner visible
- Stream Firestore démarre après le cache (`_loadConvCache().then((_) => _initChatsStream())`)
- `.limit(50)` ajouté sur la requête Firestore (plafond raisonnable)

**Typing indicator :**
- `_isOtherUserTyping(Chat chat)` : lit `chat.receiver_sending` si je suis sender, sinon `chat.send_sending` — non vide = autre personne en train d'écrire
- Remplace `isTyping: false` dans les deux endroits où `ConversationList` est instancié

**Preview déchiffré :**
- `_getMessagePreview()` : si `lastMessage.message.startsWith('enc:v1:')` → retourne `'🔒 Message chiffré'` au lieu du code base64

---

### Task 5 — Page abonnement : route + hideLastSeen ✅

**`lib/main.dart`** :
- Import `userAbonnementPage.dart` ajouté
- Route `'/abonnement'` enregistrée dans `onGenerateRoute` → `AbonnementScreen()`
- Corrige `Navigator.pushNamed(context, '/abonnement')` utilisé dans `myChat.dart` et `privacy_settings_page.dart`

**`lib/pages/user/userAbonnementPage.dart`** :
- Nouvelle carte avantage : **"Connexion cachée"** (`Icons.access_time_rounded`, indigo) — masquer la dernière connexion (`hideLastSeen`)
- Nouveau détail dans la section expandable : `'🕐 Masquer ta dernière connexion aux autres'`

---

**À faire (sessions suivantes)** :
- [ ] Déployer `firestore.rules` via Firebase Console ou `firebase deploy --only firestore:rules`
- [ ] Typing indicator côté Firestore (écrire `send_sending`/`receiver_sending` dans `myChat.dart` quand l'utilisateur tape)
- [ ] Stickers Afrolook (picker + assets Lottie Premium)
- [ ] Gifts virtuels (animations Lottie + crédits Afrolook)
- [ ] Invitation externe (contact sans compte → `share_plus`)

---

## Session 55 — 4 bugs critiques Messenger

**Date :** 2026-06-19
**Fichiers modifiés :**
- `lib/widgets/chat/post_share_sheet.dart`
- `lib/pages/chat/myChat.dart`
- `lib/widgets/chat/chat_bubble_widget.dart`
- `lib/pages/user/conversation/listUserConv.dart`
- `lib/pages/chat/group/group_chat_page.dart`

---

### B1 — Posts partagés non affichés dans le chat simple ✅

**Cause racine :** `PostShareSheet._sendToChat` sauvegardait les champs Firestore en camelCase (`'messageType'`, `'sendBy'`, `'replyMessage'`) mais `Message.fromJson` lit en snake_case (`json["message_type"]`, `json["send_by"]`, `json["reply_message"]`) → `message.messageType` était `null` → branche `default` du switch → texte brut affiché.

**Fix `lib/widgets/chat/post_share_sheet.dart`** :
- `'sendBy': myId` → `'send_by': myId`
- `'messageType': 'post'` → `'message_type': 'post'`
- `'post_thumbnail': thumbnail` → `'imageText': thumbnail` (PostBubble lit `message.imageText`)
- `'replyMessage': {...}` → `'reply_message': {'message': '', 'message_type': 'text', ...}`
- Ajout de `'receiverBy'` pour la cohérence avec le modèle

**Fix `lib/pages/chat/myChat.dart`** :
- `PostBubble.onTap` : remplacé `Navigator.pushNamed('/post/${message.imageText}')` (mauvais — imageText = thumbnail, pas post_id) par `_openSharedPost(message.id)`
- Nouvelle méthode `_openSharedPost(messageId)` : charge `post_id` + `post_data_type` depuis Firestore via message.id, charge le Post, navigue vers `PostDetailsVideoFormatTel` (VIDEO) ou `DetailsPost` (autres)
- Imports ajoutés : `postDetails.dart`, `post_video_format_tel_details.dart`

---

### B2 — Icône de lecture toujours verte en mode clair ✅

**Cause racine :** `ReadReceiptIcon` utilisait `colors.primary` (vert) pour l'état lu, même quand `isMe=true` (bulle sur fond vert) → icône verte sur fond vert = invisible en mode clair.

**Fix `lib/widgets/chat/chat_bubble_widget.dart`** (`ReadReceiptIcon.build`) :
```dart
// Avant
color: isRead ? AppColors.of(context).primary : AppColors.of(context).textSecondary,

// Après
color: isMe
    ? (isRead ? Colors.white : Colors.white54)
    : (isRead ? colors.primary : colors.textSecondary),
```

---

### B3 — Liste discussions : "Message chiffré" au lieu du vrai message ✅

**Cause racine :** `_getLastMessageForChat` retournait le message brut sans déchiffrement. `_getMessagePreview` détectait `'enc:v1:'` et affichait `'🔒 Message chiffré'`.

**Fix `lib/pages/user/conversation/listUserConv.dart`** :
- Import `encryption_service.dart` ajouté
- `_processChatDocument` passe `otherUserId` à `_getLastMessageForChat`
- `_getLastMessageForChat({String? otherUserId})` : après avoir chargé le message, si `msg.is_encrypted && msg.message.startsWith('enc:v1:')`, appelle `EncryptionService.getChatKey(chatId, myId, otherUserId)` puis `EncryptionService.decryptText(key, msg.message)` — le message est déchiffré in-place avant d'être retourné
- `_getMessagePreview` : suppression du retour `'🔒 Message chiffré'` (remplacé par `'🔒 Message'` si déchiffrement impossible), ajout du cas `'post'` → `'📎 Post partage'`

---

### B4 — Groupe : post partagé navigue toujours vers DetailsPost ✅

**Cause racine :** `_openSharedPost(postId)` dans `group_chat_page.dart` naviguait toujours vers `DetailsPost` sans tenir compte du type du post.

**Fix `lib/pages/chat/group/group_chat_page.dart`** :
- Import `post_video_format_tel_details.dart` ajouté
- `_openSharedPost(postId, {dataType})` : charge le post, lit `post.dataType`, navigue vers `PostDetailsVideoFormatTel` si VIDEO, `DetailsPost` sinon
- `_buildSharedPostCard` : passe `dataType: dataType` à `_openSharedPost`

---

### Backlog session 55 (prochaines sessions)

**Session 56 :** U1 ✅, U2 ✅, G1 ✅
**Session 57 :** U3 ✅, G2 ✅, G3 ✅, G4 ✅
**Session 58 :** P1 ✅, P2 ✅

---

## Session 60 — Fix bouton partage live + analyse UI

**Date :** 2026-06-19
**Fichiers modifiés :**
- `lib/pages/LiveAgora/livePage.dart`

---

### L7 — Bouton partage live : bottom sheet avec 2 options ✅

**Problème :** `_shareLive()` appelait directement `AppLinkService.shareContent()` sans proposer l'option "Envoyer dans un chat".

**Correction :**
- `_shareLive()` → affiche un `ModalBottomSheet` avec 2 tuiles :
  - **Envoyer dans un chat** → `_shareLiveToChat()` → ouvre `GenericShareSheet(itemType: 'live', ...)`
  - **Partager le lien** → `_shareLiveExternally()` → appelle `AppLinkService` (lien externe)
- Import `generic_share_sheet.dart` ajouté dans `livePage.dart`
- `_incrementShareCount()` appelé dans les 2 cas

**Session 60 :** L7 ✅

---

## Session 63 — Messenger groupe : badges, droits, non-lu + transactions live

**Date :** 2026-06-20
**Fichiers modifiés :**
- `lib/pages/chat/group/group_chat_page.dart`
- `lib/pages/chat/group/group_info_page.dart`
- `lib/pages/user/conversation/listUserConv.dart`
- `lib/widgets/chat/generic_share_sheet.dart`

**Ce qui a été fait :**

### Badges utilisateurs dans le chat groupe
- `_senderBadgeCache` : Map en mémoire par userId pour stocker badge/type/premium
- `_loadBadgesFor(Set<String>)` : chargement en lots de 10 via `whereIn`, stocké dans cache
- `_subscribeMessages` : appel `_loadBadgesFor` après chaque mise à jour des messages
- `_buildUserBadge(userId)` : retourne le widget badge selon le type :
  - Orange cercle → comptes personnels (`influencer`, `artist`, `publicFigure`, `entrepreneur`)
  - Bleu carré → comptes institutionnels (`company`, `stateInstitution`, `media`, `journalist`, `ngo`, `association`, `other`)
  - Or cercle → utilisateur premium (sans badge officiel)
- `_badgeDot({color, icon, isRound})` : container 14×14 avec bordure blanche 1.5px

### Profil au clic sur avatar
- `_showSenderProfile(userId)` : fetch Firestore Users + `showUserDetailsModalDialog(UserData, w, h, ctx)`
- Avatar dans `_buildMessageBubble` : `GestureDetector` → `_showSenderProfile` + `Stack` avec badge en `Positioned(bottom: -2, right: -2)`

### Droits et permissions dans les groupes
- `_hasPermission(right)` : si admin/owner → true, sinon vérifie `_myPermissions[right] == true`
- Utilisé dans `_showMessageOptions` : `canDelete = isMe || _hasPermission('can_delete_others')`
- `_loadGroup` : lit `permissions` depuis `GroupChats/{id}/members/{myId}` → stocke dans `_myPermissions`
- `group_info_page.dart` — `_showMemberOptions` : nouveau tile "Gérer les droits"
- `_showPermissionsDialog(userId, pseudo)` : bottom sheet `StatefulBuilder` avec `SwitchListTile` pour 4 droits :
  - `can_share` — Partager des contenus
  - `can_delete_others` — Supprimer les messages des autres
  - `can_pin` — Épingler des messages
  - `can_invite` — Inviter des membres
  - Chaque toggle met à jour `GroupChats/{id}/members/{userId}.permissions.{key}` en temps réel

### Restriction de partage dans les groupes
- `generic_share_sheet.dart` — `_sendToGroup` : avant envoi, lit le doc membre, vérifie `role` + `permissions.can_share`
- Si non autorisé → SnackBar "Vous n'avez pas le droit de partager dans ce groupe."

### Compteur de messages non-lus (groupes)
- `_sendTextMessage` + `_sendImageMessage` : incrémentent `unread_counts.{memberId}` pour tous les autres membres via `FieldValue.increment(1)`
- `_markMessagesRead` : reset `unread_counts.{myId}` à 0 en parallel avec mise à jour `reads`
- `listUserConv.dart` — `_buildGroupTile` : lit `group['unread_counts'][myId]`, affiche badge nombre (même style que 1-1), met le texte + heure en gras/primary si non-lu > 0

---

## Session 61 — Refonte UI complète livePage.dart

**Date :** 2026-06-19
**Fichiers modifiés :**
- `lib/pages/LiveAgora/livePage.dart`

**Ce qui a été fait :**
- `_buildCommentsSection()` : suppression header "Commentaires", bulles glassmorphism premium (`black.withOpacity(0.45)`, `borderRadius: 16`), gift comments or (left border `Color(0xFFF9A825)`, fond doré, username doré)
- `_buildToggleCommentsButton()` : déplacé en haut à droite (`right: 16, bottom: 90`), cercle 34px cohérent avec le reste
- `_buildTypingIndicator()` : style minimal (`black.withOpacity(0.4)`, texte blanc60 taille 10.5), animation 3 points via `_TypingDots` widget
- `_buildParticipantControls()` : cercles 44px par bouton via `_buildCtrlBtn()` helper, fond glassmorphism, style actif/inactif (rouge si désactivé)
- `_buildPausedOverlay()` : fond dégradé sombre `0xFF0D0D1A → 0xFF1A1430`, icône dans cercle or semi-transparent, spinner or fin
- `_TypingDots` : nouveau widget `StatefulWidget` avec animation répétitive, 3 points de taille 4px
- Correction `Colors.white50` → `Colors.white54` (getter non défini)

**Résultat :** Refonte UI livePage.dart ✅ complète (L8)

**Session 61 :** L8 ✅

---

## Session 58 — Partage produits, contenu VIP et lives dans les chats

**Date :** 2026-06-19
**Fichiers créés :**
- `lib/widgets/chat/generic_share_sheet.dart`

**Fichiers modifiés :**
- `lib/pages/afroshop/marketPlace/acceuil/produit_details.dart`
- `lib/pages/contenuPayant/contentDetails.dart`
- `lib/pages/LiveAgora/live_list_page.dart`
- `lib/pages/chat/group/group_chat_page.dart`
- `lib/pages/chat/myChat.dart`

---

### P1 — Partager produits Afroshop et contenu VIP dans les chats ✅

**`lib/widgets/chat/generic_share_sheet.dart`** (nouveau fichier) :
- Widget `GenericShareSheet` — prend `itemId`, `itemType`, `title`, `subtitle`, `thumbnail`, `icon`
- Même structure que `PostShareSheet` : deux onglets Conversations + Groupes
- Écrit `message_type: 'link_share'` en Firestore avec tous les champs `item_*`
- `message` = titre (utilisé par `message.message`), `imageText` = thumbnail (pour affichage sans fetch)
- Après envoi dans un groupe → navigate vers `GroupChatPage` (même comportement U1)

**`produit_details.dart`** :
- Import `generic_share_sheet.dart` ajouté
- `_shareProduct()` modifiée : affiche d'abord un bottom sheet avec 2 options : "Partager (lien externe)" et "Envoyer dans un chat"
- "Envoyer dans un chat" → `_shareProductToChat()` → ouvre `GenericShareSheet(itemType: 'product', ...)`

**`contentDetails.dart`** :
- Import `generic_share_sheet.dart` ajouté
- `_handleShare()` modifiée : même pattern — bottom sheet 2 options
- "Envoyer dans un chat" → `_shareContentToChat()` → ouvre `GenericShareSheet(itemType: 'vip', ...)`

---

### P2 — Partager les lives dans les chats ✅

**`live_list_page.dart`** :
- Import `generic_share_sheet.dart` ajouté
- Nouvelle méthode `_shareLiveToChat(PostLive live)` → ouvre `GenericShareSheet(itemType: 'live', ...)`
- Icône `ios_share_rounded` ajoutée dans la ligne statistiques de chaque `_buildLiveGridItem`

---

### Affichage des `link_share` dans les chats

**`group_chat_page.dart`** :
- Imports `produit_details.dart` + `contentDetails.dart` ajoutés
- `_buildMessageBubble` : nouveau cas `link_share` → `_buildLinkShareCard(msg, isMe)`
- `_buildLinkShareCard` : card avec miniature + label type + titre + "Voir"
- `_openSharedItem(msg)` : navigation selon `item_type` — product → `ProduitDetail`, vip → charge `ContentPaie` depuis Firestore → `ContentDetailScreen`, live → snackbar

**`myChat.dart`** :
- Imports `produit_details.dart` + `contentDetails.dart` ajoutés
- Switch `message.messageType` : nouveau cas `link_share` → `_buildLinkShareBubble(message, isMe)`
- `_buildLinkShareBubble` : bulle avec miniature + titre + "Appuyer pour voir"
- `_openSharedItem(messageId)` : fetch Firestore → navigation identique au groupe
**Sessions 59-60 :** R1 (refonte pages vente contenu), R2 (refonte lives + cadeaux directs)

---

## Session 59 — Refonte système live : pièces, stats, UI premium

**Date :** 2026-06-19

**Fichiers créés :**
- `lib/pages/LiveAgora/live_ended_page.dart`

**Fichiers modifiés :**
- `lib/pages/LiveAgora/livePage.dart`
- `lib/pages/LiveAgora/live_widgets.dart`
- `lib/pages/LiveAgora/mesLives.dart`
- `lib/pages/LiveAgora/livesAgora.dart`
- `lib/pages/chat/myChat.dart`
- `lib/pages/chat/group/group_chat_page.dart`

---

### L1 — Système cadeaux : passage FCFA → pièces ✅

**`livePage.dart` — `_sendGift`** remplacée intégralement :
- Lit `giftCoinsBalance` Firestore du sender pour vérifier solde
- Firestore transaction : -100% sender, +70% host (`giftCoinsBalance`), +30% app (`solde_gain_pieces`)
- Parrainage sender : -2.5% de `solde_gain_pieces` → `giftCoinsBalance` du parrain (via `code_parrain`)
- Parrainage host : idem
- Incrémente `giftCoinsTotal` + `giftCount` + `giftLeaderboard.${userId}` + `giftLeaderboardMeta.${userId}` sur le live
- Méthode `_payCommission()` ajoutée (fire-and-forget pour parrainage)
- Méthode `_showInsufficientCoinsDialog()` ajoutée

**`live_widgets.dart` — `GiftPanelWidget`** :
- Prix affiché : `${gift.price.toInt()} pcs` au lieu de `FCFA`

---

### L2 — Affichage stats pièces ✅

**`livePage.dart` — `_buildViewerInfo`** :
- Chip cadeaux : `$_giftCoinsTotal pcs` (icône `Icons.stars_rounded`) au lieu de FCFA

**`livePage.dart` — `_showLiveEndStats`** :
- Dialogue redesigné (fond dégradé sombre, coins dorés, bordure or)
- Affiche `$_giftCoinsTotal pcs` au lieu de FCFA
- Section top donateurs avec médailles 🥇🥈🥉 si `_topDonors` non vide

---

### L3 — Leaderboard top donateurs ✅

**`livesAgora.dart` — `PostLive`** :
- Champ `giftCoinsTotal` ajouté (field + constructeur + `toMap` + `fromMap` + `copyWith`)

**`livePage.dart` — `_setupFirestoreListeners`** :
- Lit `giftLeaderboard` + `giftLeaderboardMeta`, trie par total décroissant, construit `_topDonors` (top 3)

**`livePage.dart` — `_buildLeaderboard()`** (nouveau widget) :
- Positionné en haut à droite (sous les chips stats)
- Affiche jusqu'à 3 donateurs avec médaille, avatar, pseudo, total pcs

---

### L4 — UI footer améliorée ✅

**`livePage.dart` — `_buildFooter()`** :
- Ligne de raccourcis cadeaux rapides (3 premiers cadeaux de la liste) avec solde pièces affiché
- Barre principale redesignée : fond semi-transparent avec bordure, icônes uniformisées (rounded)
- Méthode helper `_buildFooterAction()` extraite

---

### L5 — Suppression encaissement dans mesLives ✅

**`mesLives.dart`** :
- Supprimés : `_withdrawEarnings`, `_showWithdrawalConfirmation`, `_processingWithdrawal`
- Section gains → remplacée : affiche `X pcs` (cadeaux reçus) + FCFA entrées payantes séparés
- Dialog `_showLiveDetailsDialog` : section revenus → `X pcs` au lieu de FCFA

---

### L6 — Page live terminé depuis les chats ✅

**`lib/pages/LiveAgora/live_ended_page.dart`** (nouveau) :
- Page stats pour un live terminé : hôte, titre, date, durée, grid 6 stats (spectateurs, likes, pièces, partages, durée, participants)
- Bannière rouge "Ce live est terminé"
- Section entrées payantes séparée (FCFA)

**`myChat.dart` + `group_chat_page.dart`** :
- `case 'live'` dans `_openSharedItem` : fetch live depuis Firestore
  - `isLive == true` → push `LivePage` (spectateur)
  - `isLive == false` → push `LiveEndedPage`
- Imports `livesAgora.dart`, `livePage.dart`, `live_ended_page.dart` ajoutés dans les 2 fichiers

---

**Session 59 :** L1 ✅, L2 ✅, L3 ✅, L4 ✅, L5 ✅, L6 ✅

---

## Session 57 — Groupe : vues messages, ajout membre, notif départ, lecture seule

**Date :** 2026-06-19
**Fichiers modifiés :**
- `lib/pages/chat/group/group_chat_page.dart`
- `lib/pages/chat/group/group_info_page.dart`

---

### U3 — Vues des messages dans les groupes (qui a lu, sauf incognito) ✅

**`group_chat_page.dart`** :
- Champ état `String _myRole = 'member'` — chargé depuis `GroupChats/{id}/members/{myId}.role`
- `_markMessagesRead()` : écrit `GroupChats/{groupId}/reads/{myId}` avec `last_read_at: now` (1 seule écriture à chaque ouverture/nouveau message, pas une écriture par message)
- Appelé dans `_subscribeMessages()` à chaque snapshot
- Message bubble : icône `done_all` + GestureDetector sur l'heure (messages envoyés par moi uniquement)
- `_showMessageReaders(msg)` : charge `reads` subcollection, compare `last_read_at >= msg.create_at_time_spam`, exclude `myId` et users avec `incognitoMode == true` → bottom sheet avec liste des lecteurs

---

### G2 — Ajouter un membre au groupe + notification ✅

**`group_info_page.dart`** :
- Import `userProvider.dart` ajouté
- Bouton `Icons.person_add_alt_1_rounded` dans AppBar (owner/admin uniquement)
- `_showAddMemberSheet()` : bottom sheet avec champ de recherche, appelle `userProvider.searchUsersByPseudo(q)`, filtre les membres déjà présents
- `_addMember(userId, pseudo, imageUrl, oneSignalId)` : écrit dans `members` subcollection + `FieldValue.arrayUnion` sur `member_ids` + `FieldValue.increment(1)` sur `member_count`, envoie notification OneSignal "Vous avez été ajouté au groupe [nom]"

---

### G3 — Notification au propriétaire quand quelqu'un quitte ✅

**`group_info_page.dart`** :
- `_leaveGroup()` : après suppression Firestore, appelle `_notifyOwnerMemberLeft(myId, myPseudo)`
- `_notifyOwnerMemberLeft()` : récupère `owner_id` de `_groupData`, charge `oneIgnalUserid`, envoie notification "@pseudo a quitté le groupe [nom]"

---

### G4 — Mode lecture seule (admin peut désactiver l'envoi des messages) ✅

**`group_info_page.dart`** :
- Section "PARAMÈTRES ADMIN" avec `SwitchListTile` pour `is_read_only` (owner/admin uniquement)
- `_toggleReadOnly(bool)` : met à jour `GroupChats/{groupId}.is_read_only` Firestore

**`group_chat_page.dart`** :
- `_isReadOnly` chargé depuis `is_read_only` dans `_loadGroup()`
- Getter `_isAdminOrOwner` : `_myRole == 'owner' || _myRole == 'admin'`
- `_sendTextMessage()` / `_sendImageMessage()` : bloqués si `_isReadOnly && !_isAdminOrOwner`
- Bannière `_buildReadOnlyBanner()` + placeholder `_buildReadOnlyInputPlaceholder()` pour les membres en lecture seule

---

## Session 56 — UX Messenger : redirection groupe, archives AppBar, mute notifications

**Date :** 2026-06-19
**Fichiers modifiés :**
- `lib/widgets/chat/post_share_sheet.dart`
- `lib/pages/user/conversation/listUserConv.dart`
- `lib/pages/chat/group/group_chat_page.dart`

---

### U1 — Redirection vers le groupe après partage d'un post ✅

**Comportement avant :** après envoi d'un post dans un groupe via `PostShareSheet`, la bottom sheet se fermait mais l'utilisateur restait sur la page courante.

**Fix `lib/widgets/chat/post_share_sheet.dart`** :
- Import `group_chat_page.dart` ajouté
- `_sendToGroup(Map group)` extrait maintenant `groupName` et `groupImage` du map
- Appel `_done()` remplacé par `_doneAndOpenGroup(groupId, groupName, groupImage)`
- Nouvelle méthode `_doneAndOpenGroup` : capture `Navigator` + `ScaffoldMessenger` + couleur avant `pop`, ferme la sheet, affiche le snackbar, puis pousse `GroupChatPage` directement

---

### U2 — Menu 3 points dans AppBar conversations → accès aux archives ✅

**Comportement avant :** les conversations archivées étaient accessibles uniquement via une tile en bas de la liste (visible uniquement si on scrollait jusqu'en bas).

**Fix `lib/pages/user/conversation/listUserConv.dart`** :
- `_buildAppBar()` : ajout d'un `PopupMenuButton` (icône `more_vert`) dans la `Row` des actions, après l'icône `people`
- MenuItem "Archives" avec icône `archive_outlined` → appelle `_showArchivedChats()`

---

### G1 — Mute/unmute notifications d'un groupe en 1 clic ✅

**Comportement avant :** aucun moyen de couper les notifications d'un groupe sans désactiver toutes les notifications.

**Fix `lib/pages/chat/group/group_chat_page.dart`** :
- État `bool _isMuted = false` ajouté
- `_loadGroup()` lit `Users/{myId}.muted_groups` (array) et vérifie si `widget.groupId` est dedans → initialise `_isMuted`
- Nouvelle méthode `_toggleMute()` : met à jour Firestore via `FieldValue.arrayUnion/arrayRemove` sur `muted_groups`, affiche un snackbar de confirmation
- AppBar : nouvelle icône cloche (`notifications_none_rounded` si actif, `notifications_off_outlined` si muted, couleur `textSecondary`) avant l'icône info
- `_sendGroupNotification()` : pour chaque membre, si `data['muted_groups']` contient `widget.groupId` → `continue` (skip la notification OneSignal)

---

## Session 57 — 4 corrections Messenger critiques + système Influenceur

**Date :** 2026-06-19
**Fichiers modifiés :**
- `lib/pages/chat/group/group_info_page.dart`
- `lib/widgets/chat/post_share_sheet.dart`
- `lib/widgets/chat/generic_share_sheet.dart`
- `lib/pages/chat/myChat.dart`
- `lib/pages/admin/influencer_requests_page.dart` *(nouveau fichier)*
- `lib/pages/user/profile/profile.dart`

**Analyse :** `flutter analyze` → 0 erreur (166 info/warnings, tous pré-existants)

---

### M1 — Mode lecture seule : gate Premium ✅

**Problème :** n'importe quel owner/admin pouvait activer le mode lecture seule, même sans abonnement Premium.

**Fix `lib/pages/chat/group/group_info_page.dart`** :
- `_toggleReadOnly(bool value)` : vérifie `_auth.loginUserData.abonnement?.estPremium == true` avant d'écrire Firestore
- Si non-Premium → appel `_showPremiumGate()` (return immédiat, pas d'écriture)
- `_showPremiumGate()` : bottom sheet avec icône gradient or, texte explicatif, bouton "Devenir Premium" → navigation `/abonnement`

---

### M2 — Notifications partage groupe ✅

**Problème :** partager un post/live/article/contenu payant dans un groupe n'envoyait aucune notification aux membres.

**Fix `lib/widgets/chat/post_share_sheet.dart`** :
- Ajout méthode `_notifyGroupMembers({group, now, notifTitre, notifDesc, postId})`
- Itère `member_ids` du groupe, chunks de 10 (limite `whereIn` Firestore)
- Pour chaque membre : enregistre un document `NotificationData` dans `Notifications/` + collecte `oneIgnalUserid`
- Après les chunks : envoie une notification OneSignal groupée via `_auth.sendNotification(...)`
- `_sendToGroup()` appelle `_notifyGroupMembers()` après l'écriture du message

**Fix `lib/widgets/chat/generic_share_sheet.dart`** (même pattern) :
- Même méthode `_notifyGroupMembers` adaptée (paramètre `itemId` au lieu de `postId`, `post_type: widget.itemType`)
- Titre notif : `'${me.pseudo ?? ''} a partagé ${widget.subtitle}'`

---

### M3 — Messages chiffrés affichés en brut ✅

**Problème :** quand `_chatKey == null` (clé de déchiffrement absente), les messages avec `is_encrypted: true` s'affichaient tels quels : `enc:v1:AAAA...` (base64 brut).

**Fix `lib/pages/chat/myChat.dart`** — méthode `_buildTextMessage(message, isMe)` :
- Détection en tête de méthode : `message.is_encrypted == true && message.message.startsWith('enc:v1:')`
- Si vrai → retourne une bulle visuelle avec `Icons.lock_outline_rounded` + texte `'Message chiffré'` en italique
- Couleurs adaptées : fond `_colors.primary.withOpacity(0.85)` (moi) ou `_colors.surfaceVariant` (autre)
- Texte couleur `Colors.white70` (moi) ou `_colors.textSecondary` (autre)
- Si la condition n'est pas vraie → `TextBubble` habituel

---

### I1 — Système Influenceur : page admin + demande profil ✅

**Problème :** pas de distinction entre profil standard et profil influenceur. Pas de workflow de demande.

**Nouveau fichier `lib/pages/admin/influencer_requests_page.dart`** :
- Page admin avec 3 onglets (`TabController`) : En attente / Approuvées / Refusées
- `_streamRequests(status)` : Stream Firestore sur `InfluenceurRequests where status == X, orderBy createdAt desc`
- `_buildRequestCard(doc)` : carte avec avatar, @pseudo, nombre d'abonnés, badge statut coloré, note admin, bouton "Traiter" (pending seulement)
- `_showActionDialog(data, docId)` : AlertDialog avec champ note + boutons Refuser (rouge) / Approuver (vert)
- `_processRequest(data, docId, approve, note)` : met à jour `InfluenceurRequests/{id}` (status, adminNote, processedAt, processedBy) + si approuvé → `Users/{userId}.update({'is_influencer': true})`
- Snackbar de confirmation vert/rouge selon le résultat

**Fix `lib/pages/user/profile/profile.dart`** :
- Import ajouté : `influencer_requests_page.dart`
- État `String? _influencerStatus` (null = chargement, 'none' = aucune demande, 'pending' | 'approved' | 'rejected')
- `initState` ajouté avec `WidgetsBinding.instance.addPostFrameCallback(() => _loadInfluencerStatus())`
- `_loadInfluencerStatus()` : query `InfluenceurRequests where userId == myId, limit 1`
- `_submitInfluencerRequest()` : crée document dans `InfluenceurRequests` (id, userId, pseudo, imageUrl, followerCount, status: 'pending', createdAt)
- `_buildInfluencerButton(status)` : bouton gradient "Devenir Influenceur" (si 'none' ou 'rejected'), texte "En attente" (si 'pending')
- `_showInfluencerRequestDialog()` : bottom sheet confirmation avec gradient or, nombre d'abonnés affiché
- Condition d'affichage : `followers >= 10 && _influencerStatus != null && _influencerStatus != 'approved'`
- Section admin : ajout bouton "Influenceurs" (amber, `Icons.star_rounded`) → `InfluencerRequestsPage`

**Collection Firestore `InfluenceurRequests`** (créée à la volée) :
```
{
  id: String,
  userId: String,
  pseudo: String,
  imageUrl: String,
  followerCount: int,
  status: 'pending' | 'approved' | 'rejected',
  adminNote: String?,
  createdAt: int (ms),
  processedAt: int? (ms),
  processedBy: String? (admin userId),
}
```


---

## SESSION 62 — Système "Compte officiel" (refonte complète du système influenceur)

### I2 — Refonte complète : Influenceur → Compte Officiel ✅

**Objectif :** remplacer le système minimal "Devenir Influenceur" par un système générique, évolutif et administrable de Comptes Officiels.

---

#### Nouveaux fichiers créés

**`lib/models/official_account/official_account_enums.dart`**
- `OfficialAccountCategory` (11 valeurs) : `influencer` (requiresIdVerification: true, canMonetize: true), `media`, `journalist`, `stateInstitution`, `company`, `ngo`, `association`, `artist`, `publicFigure`, `entrepreneur`, `other`
- `OfficialAccountStatus` (6 valeurs) : `pending`, `underReview`, `moreInfoNeeded`, `approved`, `rejected`, `suspended` — chacun avec label + couleur ARGB
- `SocialNetworkType` (11 valeurs) : Facebook, Instagram, TikTok, LinkedIn, Threads, X, YouTube, Snapchat, Telegram, WhatsApp Channel, Autre
- `BroadcastDomain` (23 valeurs) : Actualités, Politique, Économie, Business, Entrepreneuriat, Sport, Culture, Musique, Cinéma, Humour, Éducation, Santé, Agriculture, Technologie, IA, Environnement, Religion, Mode, Lifestyle, Jeux vidéo, Cuisine, Science, Autres
- `IdDocumentType` (4 valeurs) : CNI, Passeport, Permis de conduire, Titre de séjour

**`lib/models/official_account/official_account_request.dart`**
- `OfficialAccountAction` : historique des actions admin (action, note, adminId, timestamp)
- `SocialNetworkEntry` : entrée réseau social (type, handle, url, followerCount)
- `OfficialAccountRequest` : modèle complet avec `toMap()`, `fromMap(docId)`, `copyWith()`

**`lib/services/official_account/official_account_service.dart`**
- Singleton `OfficialAccountService.instance`
- Collection Firestore : `OfficialAccountRequests`
- `submitRequest()` : soumet une demande
- `getMyRequest(userId)` : demande la plus récente d'un utilisateur
- `watchMyRequest(userId)` : stream temps-réel
- `watchByStatus(status)` / `watchFiltered({status, category})` : streams admin
- `updateStatus()` : change le statut + historise + met à jour le profil `Users/{id}` atomiquement
  - `approved` → pose `officialBadge: true`, `officialAccountType`, `officialName`, `broadcastDomains`, `canMonetize`, `canReceiveGiftCommission`, `canDoParrainage` (uniquement `influencer`)
  - `suspended` → `officialBadge: false`
  - `rejected` → `officialAccountStatus: 'rejected'` (badge préservé si déjà approuvé)

**`lib/pages/user/official_account/request_official_account_page.dart`**
- Formulaire multi-étapes `PageController` (5 ou 6 étapes selon catégorie)
- Étape 1 — `_StepCategory` : grille de 11 catégories (icône + label)
- Étape 2 — `_StepInfo` : nom officiel, description, pays, ville, téléphone, email, site web
- Étape 3 — `_StepDomains` : chips filtrables (23 domaines), sélection multiple
- Étape 4 — `_StepSocialNetworks` : liste dynamique de réseaux avec type, handle, url, followers
- Étape 5 — `_StepIdentity` (influenceur seulement) : date de naissance (vérification ≥ 18 ans), type pièce, numéro pièce
- Étape 6 — `_StepTerms` : conditions d'utilisation + checkbox acceptation ; bouton "Contacter le service" pour catégories non-influenceur
- `_StepIndicator` : indicateur de progression horizontal scrollable (pills animés)
- Validation par étape via `_canProceed()`

**`lib/pages/admin/official_accounts_page.dart`**
- `OfficialAccountsPage` : 6 onglets (un par statut `OfficialAccountStatus`)
- Filtre par catégorie via bottom sheet
- `_RequestList` : StreamBuilder + `watchFiltered()`
- `_RequestCard` : carte avec badge statut, catégorie, domaines en chips
- `_RequestDetailPage` : vue détail complète (demandeur, informations, domaines, réseaux sociaux, identité si influenceur, avertissement monétisation, historique des actions)
- `_AdminActions` : boutons contextuels selon statut (approuver, refuser, demander infos, suspendre, reprendre l'analyse)
- `_promptNote()` : AlertDialog saisie de note (obligatoire pour refus/suspension/infos)

---

#### Fichiers modifiés

**`lib/models/model_data.dart`** — `UserData` :
Ajout des champs après `postViewsMigrationDone` :
```dart
String? officialAccountType;
String? officialAccountStatus;
bool? officialBadge = false;
String? officialAccountRequestId;
String? officialName;
String? officialDescription;
String? officialCountry;
String? officialCity;
String? officialWebsite;
List<String>? broadcastDomains = [];
List<Map<String, dynamic>>? officialSocialLinks = [];
bool? canMonetize = false;
bool? canReceiveGiftCommission = false;
bool? canDoParrainage = false;
bool get isOfficialAccount => officialBadge == true && officialAccountStatus == 'approved';
```

**`lib/pages/user/profile/profile.dart`** :
- Anciens imports `influencer_requests_page.dart` + état `_influencerStatus` supprimés
- Nouveaux imports : `official_accounts_page.dart`, `request_official_account_page.dart`, `official_account_enums.dart`, `official_account_request.dart`, `official_account_service.dart`
- État remplacé : `OfficialAccountRequest? _officialRequest` + `bool _officialRequestLoaded`
- `_loadOfficialRequest()` remplace `_loadInfluencerStatus()` + `_submitInfluencerRequest()`
- `_buildOfficialAccountButton(req)` remplace `_buildInfluencerButton(status)` : 5 états (null=créer, pending, underReview, moreInfoNeeded, rejected, suspended)
- `_buildOfficialBadge(me)` : bandeau gradient violet affiché si `me.isOfficialAccount`
- Menu admin : "Influenceurs" (`InfluencerRequestsPage`) → "Comptes officiels" (`OfficialAccountsPage`, `Icons.verified_rounded`)

**`lib/models/chatmodels/message.dart`** :
- Ajout `itemType` et `itemSubtitle` pour les messages `link_share`

**`lib/pages/chat/myChat.dart`** + **`lib/pages/chat/group/group_chat_page.dart`** :
- `_buildLinkShareBubble()` différencie par `itemType` : `live` (badge ● LIVE rouge + "Visiter le live"), `product`, `vip`, défaut

---

#### Règles de monétisation
- Seul `OfficialAccountCategory.influencer` a `canMonetize: true`
- Toutes les autres catégories → cadeaux 100% plateforme (`canMonetize: false`, `canReceiveGiftCommission: false`, `canDoParrainage: false`)
- **RÈGLE SÉCURITÉ** : les 25% de commission plateforme ne s'affichent jamais dans l'UI

---

#### Collection Firestore `OfficialAccountRequests`
```
{
  id: String,
  userId: String,
  pseudo: String,
  profilePhotoUrl: String,
  coverPhotoUrl: String,
  category: String (OfficialAccountCategory.id),
  officialName: String,
  description: String,
  country: String,
  city: String,
  phone: String,
  email: String,
  website: String?,
  broadcastDomains: List<String>,
  socialNetworks: List<Map>,
  birthDate: String? (yyyy-MM-dd, influenceur seulement),
  idDocumentType: String? (influenceur seulement),
  idNumber: String? (influenceur seulement),
  status: String (OfficialAccountStatus.id),
  adminNote: String?,
  actionHistory: List<Map>,
  createdAt: int (ms),
  updatedAt: int (ms),
  processedAt: int? (ms),
  processedBy: String? (admin userId),
}
```

---

#### À faire (optionnel/futur)
- Bouton "Contacter le service" dans `_StepTerms` → naviguer vers la vraie page Contact
- Badge officiel sur les profils `OtherUser` et résultats de recherche
- `broadcastDomains` intégré dans l'algorithme de recommandation

---

## Session 65 — Comptes officiels : abonnement mensuel + refonte formulaire

**Date :** 2026-06-20

**Fichiers modifiés :**
- `lib/models/model_data.dart` — `OfficialSubscription` class, `isMonetized` getter, `officialSubscription` field, `ABONNEMENT_OFFICIEL` dans `TypeTransaction`
- `lib/models/official_account/official_account_enums.dart` — `canMonetize` (influencer, artist, entrepreneur), `isPersonal` getter
- `lib/pages/user/official_account/request_official_account_page.dart` — `_StepCategory` groupé (personnels/institutionnels + tags), `_StepInfo` avec pays africains + IntlPhoneField, `_StepTerms` avec bloc frais, état parent adapté
- `lib/services/official_account/official_account_service.dart` — `paySubscription()`, `getSubscription()`

**Fichiers créés :**
- `lib/pages/user/official_account/official_subscription_page.dart` — page statut abonnement + bouton paiement + modal solde insuffisant

**Ce qui a été fait :**

### Modèles
- `OfficialSubscription` : `active`, `lastPaidAt`, `nextDueAt`, `autoPayEnabled`, `daysLate`, `isLate`, `isSuspendable`, `fromJson/toJson/copyWith`
- `isMonetized` getter sur `UserData` : `true` si non officiel OU si type parmi `{influencer, artist, entrepreneur}`
- `ABONNEMENT_OFFICIEL` ajouté à `TypeTransaction`

### Formulaire de demande
- `_StepCategory` : 2 groupes "Comptes personnels" et "Comptes institutionnels" avec tags (Monétisable, Vérif. identité), bandeau info frais 5 000 FCFA
- `_StepInfo` : dropdown 54 pays africains + `IntlPhoneField` (indicatif auto)
- `_StepTerms` : bloc jaune "Frais d'abonnement mensuel 5 000 FCFA/mois"

### Service
- `paySubscription(userId)` : Firestore transaction — vérifie solde ≥ 5 000, débite `votre_solde_principal`, crée `TransactionSolde` type `ABONNEMENT_OFFICIEL`, met à jour `officialSubscription`
- `getSubscription(userId)` : lecture du champ `officialSubscription`

### Page abonnement
- Carte statut (actif / en retard / suspendable) avec date dernier paiement et prochain renouvellement
- Affichage du solde actuel
- Bouton paiement avec feedback loading
- Modal solde insuffisant avec bouton "Recharger"
- Bloc info (auto-pay, notification, suspension 30j)

**Prochaines sessions planifiées :**
- **Session 66** : ✅ fait (voir ci-dessous)
- **Session 64** : `MonetizationService`, page monétisation verrouillée pour comptes non monétisés
- **Session 67** : Dashboard admin complet (5 onglets)

---

## Session 66 — Badge officiel : fix isVerify, widget unifié + bouton AppData admin

**Date :** 2026-06-20

**Fichiers modifiés :**
- `lib/services/official_account/official_account_service.dart`
- `lib/pages/admin/admin_dashboard_page.dart`
- `lib/services/utils/abonnement_utils.dart`
- `lib/widgets/user_badge_widget.dart` *(nouveau)*
- `lib/pages/postComments.dart`
- `lib/pages/vibe/vibesPage.dart`
- `lib/pages/post_video_format_tel_details.dart`
- `lib/pages/postDetails.dart`
- `lib/pages/chat/myChat.dart`
- `lib/pages/chat/group/group_chat_page.dart`
- `lib/pages/home/homeScreen.dart`
- `lib/pages/userPosts/youTube_video_card.dart`
- `lib/pages/user/detailsOtherUser.dart`
- `lib/pages/userPosts/postWidgets/postWidgetPage.dart`
- `lib/pages/home/HomeConstPost.dart`
- `lib/pages/postDetailsVideo.dart`

---

### Bug 1 — Badge officiel invisible partout sauf sur le profil ✅

**Cause racine :** `OfficialAccountService.updateStatus()` écrivait `officialBadge: true` lors de l'approbation, mais **pas** `isVerify: true`. Or tous les widgets d'affichage de badge dans l'app (cartes posts, commentaires, etc.) lisent `user.isVerify`. Le profil affichait le badge via `officialBadge`, mais les autres widgets ne le voyaient pas.

**Fix `lib/services/official_account/official_account_service.dart`** :
- Bloc `isApproved` : ajout `'isVerify': true` dans `userUpdate`
- Bloc `isSuspended` : ajout `'isVerify': false` dans `userUpdate`
- Méthode `paySubscription()` : ajout `'isVerify': true` dans la transaction

**Note :** les comptes approuvés **avant** ce correctif ont `officialBadge: true` mais `isVerify: false`. Ils nécessitent une mise à jour manuelle Firestore ou une ré-approbation admin pour afficher le badge partout.

---

### Bug 2 — Bouton AppData absent du tableau de bord admin ✅

**Cause :** la session 62 avait regroupé les boutons admin éparpillés dans une page tableau de bord (`AdminDashboardPage`), mais la page `AdminHubPage` (statistiques globales de l'application) n'avait pas été incluse comme module.

**Fix `lib/pages/admin/admin_dashboard_page.dart`** :
- Import `'../user/profile/adminprofil.dart'` ajouté
- Nouveau widget `_AppDataButton` (full-width, dégradé bleu foncé, icône `bar_chart_rounded`) inséré entre le header et les stats
- Navigation : `Navigator.push → AdminHubPage()`

---

### Unification du widget badge (UserBadgeWidget) ✅

**Contexte :** les call sites utilisaient `AbonnementUtils.getUserBadge(abonnement: ..., isVerified: ...)` sans passer `officialBadge` ni `officialAccountType`, donc même si `isVerify` était true, le badge officiel (orange/bleu carré) ne s'affichait jamais correctement.

**`lib/services/utils/abonnement_utils.dart`** :
- Ajout du paramètre `bool withBackground = false` à `getUserBadge()`
- Refactoring interne : passage du pattern early-return à une variable `Widget? badge` nullable
- Quand `withBackground: true` : le badge est enveloppé dans un `Container` cercle blanc avec ombre (`boxShadow`, `withOpacity(0.12)`)

**Nouveau fichier `lib/widgets/user_badge_widget.dart`** :
- `UserBadgeWidget extends StatelessWidget` — widget unique pour toute l'app
- Accepte `UserData? user` (lit automatiquement `isVerify`, `officialBadge`, `officialAccountType`, `abonnement`)
- OU paramètres individuels (pour les contextes cache comme le chat groupe)
- `withBackground: true` par défaut (fond blanc circulaire derrière le badge)
- Paramètre `size` pour ajuster la taille selon le contexte

**Remplacement de tous les call sites (12 fichiers) :**

| Fichier | Ancienne syntaxe | Nouvelle syntaxe |
|---|---|---|
| `postComments.dart` | `getUserBadge(abonnement: ..., isVerified: ...)` × 2 | `UserBadgeWidget(user: ..., size: 14)` |
| `vibesPage.dart` | `getUserBadge(abonnement: ..., isVerified: ...)` × 2 | `UserBadgeWidget(user: user, size: 14)` |
| `post_video_format_tel_details.dart` | `getUserBadge(...)` × 2 | `UserBadgeWidget(user: user, size: 14)` |
| `postDetails.dart` | `getUserBadge(abonnement: ..., isVerified: user.isVerify!)` | `UserBadgeWidget(user: user, size: 15)` |
| `myChat.dart` | `getUserBadge(abonnement: ..., isVerified: ..., size: 14)` | `UserBadgeWidget(user: user, size: 14)` |
| `group_chat_page.dart` | méthode `_buildUserBadge()` avec `_badgeDot()` | `UserBadgeWidget(isVerified: ..., officialBadge: ..., officialAccountType: ..., size: 12)` |
| `homeScreen.dart` | `getUserBadge(abonnement: ..., isVerified: ..!)` | `UserBadgeWidget(user: loginUserData, size: 15)` |
| `youTube_video_card.dart` | `if (_creatorUser?.abonnement != null) getUserBadge(...)` | `if (_creatorUser != null) UserBadgeWidget(user: _creatorUser, size: 14)` |
| `detailsOtherUser.dart` | `getUserBadge(abonnement: ..., isVerified: ..!)` | `UserBadgeWidget(user: widget.user, size: 18)` |
| `postWidgetPage.dart` | `getUserBadge(...)` × 2 | `UserBadgeWidget(user: widget.post.user, size: 14)` |
| `HomeConstPost.dart` | `if (user.isVerify ?? false) Icon(Icons.verified, ...)` | `UserBadgeWidget(user: user, size: 12)` |
| `postDetailsVideo.dart` | `if (canal?.isVerify == true \|\| user?.isVerify == true) Icon(...)` | `if (user != null) UserBadgeWidget(user: user, size: 15)` |

**Résultat :** un seul widget centralise l'affichage des badges dans toute l'application. Toute évolution future (nouveau type de badge, changement visuel) se fait en un seul endroit.

### Session 67 (20 juin 2026 — refonte UI thème clair/sombre : contenu payant + lives)

**Demande :** Refaire l'UI de la page home du contenu payant, de la liste des lives et de la page mes lives pour utiliser `AppColors` (support mode clair/sombre).

**3 fichiers refactorisés :**

#### `lib/pages/contenuPayant/profileScreenContent.dart` ✅ RÉÉCRITURE COMPLÈTE
- Fichier avait 3 blocs d'imports dupliqués et ~1400 lignes avec du code commenté en fin — réécriture propre
- Import inutile `contentSerie.dart` supprimé
- Couleur marque `Color(0xFFC62828)` (rouge) remplacée par `colors.primary` (vert thème) sur tous les éléments
- Gradient header : `[Color(0xFFC62828), Color(0xFFFFD600)]` → `[colors.primary, colors.accent]`
- `Colors.grey.shade50` background → `colors.background`
- `Colors.white` cartes → `colors.surface`
- `Colors.grey.*` textes → `colors.textSecondary`
- Badge officiel : `if (user.isVerify ?? false) Positioned(...)` → `UserBadgeWidget(user: user, size: 18, withBackground: true)`
- `UserBadgeWidget` utilisé en `Positioned` sur l'avatar
- `shimmerBase` d'AppColors utilisé pour les placeholders de chargement d'images
- Code commenté legacy (lignes 1356+) supprimé — code mort non pertinent
- `flutter analyze` : 0 erreur, 1 warning (import inutile corrigé), infos pré-existants

#### `lib/pages/LiveAgora/live_list_page.dart` ✅ REFACTORISÉ
- Champs `static const _bg`, `_surface`, `_gold` supprimés
- `final colors = AppColors.of(context)` dans `build()`, passé en paramètre à toutes les méthodes
- `backgroundColor: colors.background`, FAB `colors.accent`, `WaterDropHeader` `colors.accent`
- Tabs : fond `colors.surface`, bordure `colors.border`, indicateur `colors.accent`, label `colors.onAccent`/`colors.textSecondary`
- Cartes lives : `colors.surface`, `colors.border`, textes `colors.textPrimary`/`colors.textSecondary`
- Badge LIVE (rouge) conservé comme `Color(0xFFFF3B30)` — couleur sémantique intentionnelle
- Icône cœur `Color(0xFFFF6B6B)` conservée — couleur sémantique

#### `lib/pages/LiveAgora/mesLives.dart` ✅ RÉÉCRITURE COMPLÈTE
- Imports dupliqués (2 blocs identiques) supprimés — bloc unique propre
- Extension morte `PostLiveExtension` supprimée
- Toutes les couleurs hardcodées remplacées : `Colors.black` → `colors.background`, `Colors.grey[900]` → `colors.surface`, `Colors.grey[800]` → `colors.surfaceVariant`, `Color(0xFFF9A825)` → `colors.accent`, textes blancs → `colors.textPrimary`, gris → `colors.textSecondary`, rouge LIVE → `colors.danger`
- Toutes les méthodes acceptent `AppColors colors` en paramètre
- Dialogs utilisent `AppColors.of(context)` directement

**Commit :** à pusher sur `refonte_claude`

---

## SYSTÈME D'ABONNEMENTS UTILISATEUR — REFONTE COMPLÈTE (Session 79+)

_Ajouté : 22 juin 2026_

### Vue d'ensemble

L'abonnement est **individuel par compte utilisateur** (un seul plan actif par personne). Changer de plan affecte toutes les fonctionnalités de l'app. Le **point de contrôle unique** est `AbonnementUtils` dans `lib/services/utils/abonnement_utils.dart` — toutes les pages passent par ce service pour décider ce qu'un utilisateur peut faire.

### Plans

| Plan | Prix base | Type Firestore |
|---|---|---|
| Gratuit | 0 FCFA | `'gratuit'` |
| Premium | 200 FCFA/mois | `'premium'` |
| Gold | 500 FCFA/mois | `'gold'` |

**Règle d'héritage :** Gold ⊃ Premium. `estPremium` retourne `true` pour Premium ET Gold.

### Réductions multi-mois

**Premium (base 200 FCFA/mois) :**

| Durée | Prix total | Réduction |
|---|---|---|
| 1 mois | 200 F | — |
| 2 mois | 400 F | — |
| 3 mois | 500 F | -100 F |
| 6 mois | 1 000 F | -200 F |
| 12 mois | 1 900 F | -500 F |

**Gold (base 500 FCFA/mois) :**

| Durée | Prix total | Réduction |
|---|---|---|
| 1 mois | 500 F | — |
| 2 mois | 950 F | -50 F |
| 3 mois | 1 350 F | -150 F |
| 6 mois | 2 500 F | -500 F |
| 12 mois | 4 500 F | -1 500 F |

### Avantages par plan

| Fonctionnalité | Gratuit | Premium | Gold |
|---|---|---|---|
| Messagerie privée | ✅ | ✅ | ✅ |
| Rejoindre groupes publics | ✅ | ✅ | ✅ |
| Posts visibles dans son pays | ✅ | ✅ | ✅ |
| 1 photo par look | ✅ | ✅ | ✅ |
| Créer & gérer des groupes chat | ❌ | ✅ | ✅ |
| Posts visibles partout en Afrique | ❌ | ✅ | ✅ |
| 3 photos par look | ❌ | ✅ | ✅ |
| Live HD · latence 500ms | ❌ | ✅ | ✅ |
| Mode fantôme · connexion cachée | ❌ | ✅ | ✅ |
| Emojis 3D · Stickers exclusifs | ❌ | ✅ | ✅ |
| Badge Premium ⭐ | ❌ | ✅ | ✅ |
| **Groupes privés payants** (70%/30%) | ❌ | ❌ | ✅ |
| **Code unique — rejoindre par code** | ❌ | ❌ | ✅ |
| **Carousel pub dans page Groupes** | ❌ | ❌ | ✅ |
| **Badge Gold 👑** | ❌ | ❌ | ✅ |

### Logique abonnement groupe privé

- À l'expiration Gold du propriétaire : groupe passe en **lecture seule** (`is_frozen: true`)
- À l'expiration de l'abonnement d'un membre à un groupe privé : **pas d'expulsion automatique**
- Au moment où le membre tente de ré-entrer : vérification → si expiré → dialog de renouvellement
- Le suivi des abonnements individuels aux groupes se fait dans `GroupChats.paid_subscribers` : `{ userId: expiry_ms }`

---

### Fichiers à modifier

#### 1. `lib/models/model_data.dart` — Modèle central

**Champs `AfrolookAbonnement` à ajouter/modifier :**
- `type` : `'gratuit'` | `'premium'` | `'gold'` (ajout de `'gold'`)
- Nouveau getter `bool get estGold` : `type == 'gold' && estActif && !dateFin.isBefore(DateTime.now())`
- Modifier `bool get estPremium` : `(type == 'premium' || type == 'gold') && estActif && !dateFin.isBefore(...)`
- Nouvelle factory `AfrolookAbonnement.gold({int dureeMois = 1})`
- Nouvelle méthode statique `calculerPrixGold(int dureeMois)` — table de prix Gold
- Nouvelle constante `prixGoldBase = 500.0`
- Map `reductionsGold` séparé de `reductions` (Premium)
- Nouvelle méthode statique `getAvantagesGold()` — liste des avantages Gold
- Mise à jour `fromJson` : gère `type == 'gold'`, expiration Gold → retour gratuit
- Mise à jour `toJson` : si gold expiré → retour gratuit
- Mise à jour `getLiveRestrictions` : Gold = même que Premium

**Nouveaux champs Firestore `GroupChats` (pas dans model_data — direct Map<String,dynamic>) :**
- `join_code` : String 8 chars (généré à la création si propriétaire Gold)
- `is_private` : bool
- `subscription_price` : double (FCFA/mois pour rejoindre le groupe)
- `paid_subscribers` : Map<userId, expiry_ms>

#### 2. `lib/services/utils/abonnement_utils.dart` — Point de contrôle unique

**Nouvelles méthodes statiques à ajouter :**
```dart
static bool isGold(AfrolookAbonnement? abonnement) => abonnement?.estGold == true;
static bool canCreatePrivateGroup(AfrolookAbonnement? abonnement) => abonnement?.estGold == true;
static bool canUseGroupJoinCode(AfrolookAbonnement? abonnement) => abonnement?.estGold == true;
static bool canAppearInGoldCarousel(AfrolookAbonnement? abonnement) => abonnement?.estGold == true;
static bool canCreateGroup(AfrolookAbonnement? abonnement) => abonnement?.estPremium == true;
```

**Mise à jour `getUserBadge()` :**
- Ajouter priorité Gold (avant Premium, après officiel) :
  - `else if (isGold(abonnement))` → badge 👑 doré (gradient `FFD700` → `FF8C00`)

**Mise à jour `calculerPrix` → renommer `calculerPrixPremium`, ajouter `calculerPrixGold`**

#### 3. `lib/services/abonnement_service.dart` — Service d'abonnement

**Modifications :**
- Renommer `souscrirePremium` → conserver tel quel (compatibilité pages existantes)
- Ajouter `souscrireGold({required int dureeMois, required UserData user, required BuildContext context})`
  - Même logique que `souscrirePremium` mais avec `AfrolookAbonnement.gold()`
  - Transaction type `ABONNEMENT_GOLD`
  - Bloque si Gold déjà actif (comme Premium bloque si Premium actif)
- Ajouter `souscrireGenerique({required String planType, ...})` — appelé par la nouvelle page

#### 4. `lib/pages/user/userAbonnementPage.dart` — Page abonnement

**Réécriture complète :**
- 3 onglets : Gratuit / Premium / Gold
- Pour chaque plan payant : sélecteur de durée (chips horizontaux) + résumé prix + bouton paiement
- Section renouvellement si abonnement actif (Premium ou Gold)
- Badge et couleur par plan : ⭐ orange/jaune pour Premium, 👑 or pour Gold
- Info renouvellement groupes privés : "pas d'expulsion automatique, demandé à la prochaine entrée"
- Appelle `_abonnementService.souscrireGenerique(planType: 'premium'|'gold', dureeMois: ...)`

#### 5. `lib/pages/user/conversation/listUserConv.dart` — Page groupes/conversations

**Ajouts dans l'onglet 'groups' :**
- Barre "Rejoindre par code" (visible uniquement dans le filtre 'groups')
  - Input champ code → bouton Chercher
  - Recherche Firestore : `GroupChats.where('join_code', isEqualTo: code)`
  - Vérification : charger le propriétaire → `estGold` doit être `true`
  - Si Gold OK → modal de confirmation → `addUserToGroup(groupId, userId)`
  - Si propriétaire plus Gold → message "Ce groupe n'accepte plus de nouveaux membres par code"
- Carousel Gold groups (visible uniquement dans le filtre 'groups')
  - Requête : `GroupChats.where('is_private', isEqualTo: false).limit(20)` filtrés par propriétaire Gold
  - Ordre **aléatoire** à chaque affichage (`..shuffle()`)
  - Cards horizontaux scrollables : image groupe + nom + nb membres + badge 👑 GOLD
  - Tap → ouvrir page du groupe (si déjà membre) ou modal "Rejoindre"

#### 6. `lib/pages/chat/group/create_group_page.dart` — Création groupe

**Ajouts :**
- Si propriétaire Gold : option "Groupe privé" (switch) + champ "Prix abonnement (FCFA/mois)"
- Génération automatique `join_code` si Gold : `_generateJoinCode()` → 8 chars alphanumériques uniques
- Sauvegarder `join_code`, `is_private`, `subscription_price` dans `GroupChats`

#### 7. `lib/pages/chat/group/group_chat_page.dart` — Chat groupe

**Ajouts :**
- À l'ouverture du groupe : si `is_private == true`, vérifier `paid_subscribers[userId]`
  - Si absent ou expiré → dialog "Renouveler votre abonnement au groupe"
  - Dialog : prix + bouton payer sur solde principal + annuler
  - Si solde insuffisant → bouton Recharger
  - Paiement : 70% au propriétaire (`_creditCreator`), 30% app
  - Mise à jour `paid_subscribers[userId] = DateTime.now().add(30 jours).ms`

#### 8. `lib/pages/chat/group/group_info_page.dart` — Info groupe

**Afficher :**
- Badge "Privé" si `is_private == true`
- Code unique si Gold et propriétaire : `join_code` avec bouton copier + partager

---

### Pages qui N'ont PAS besoin d'être modifiées

Les 75 pages qui vérifient `estPremium` restent inchangées car Gold satisfait `estPremium == true`. Seules les fonctions **exclusivement Gold** nécessitent un nouveau check `estGold`.

### Statut d'implémentation

| Étape | Statut |
|---|---|
| Modèle `AfrolookAbonnement` (Gold type + getters) | ✅ Session 79 |
| `AbonnementUtils` (nouvelles méthodes + badge Gold) | ✅ Session 79 |
| `AbonnementService.souscrireGold()` | ✅ Session 79 |
| Page abonnement — réécriture 3 plans | ✅ Session 79 |
| `listUserConv.dart` — search-by-code + carousel Gold | ✅ Session 80 |
| `create_group_page.dart` — join_code + is_private | ✅ Session 80 |
| `group_chat_page.dart` — vérif abonnement privé à l'entrée | ✅ Session 80 |
| `group_info_page.dart` — affichage code + badge privé | ✅ Session 80 |

---

## SESSION 82 — Flutter Web vidéo + Group chat permissions + HomeConstPage performance

### 1. Flutter Web — Lecture vidéo (sessions 81→82)

**Problème :** Les vidéos ne se lisaient pas du tout sur Flutter Web (`Cannot read properties of undefined (reading 'isSupported')` — bug dans `video_player_web`).

**Solution : `SmartVideoPlayer` — bypass complet de `video_player_web` sur web**

Nouveaux fichiers :
- `lib/widgets/smart_video_player.dart` — export conditionnel selon la plateforme
- `lib/widgets/smart_video_player_web.dart` — implémentation web avec `<video>` HTML natif via `dart:ui_web` + `HtmlElementView`
- `lib/widgets/smart_video_player_native.dart` — implémentation mobile avec Chewie
- `lib/widgets/smart_video_player_stub.dart` — fallback non supporté

**Fichiers modifiés :**
- `lib/pages/postDetailsVideo.dart` — `kIsWeb` guard + `SmartVideoPlayer` sur web
- `lib/pages/post_video_format_tel_details.dart` — idem
- `lib/pages/userPosts/youTube_video_card.dart` — idem + `XFile.readAsBytes()` pour upload cross-platform
- `lib/pages/userPosts/video_preload_manager.dart` — `kIsWeb` guard
- `lib/pages/chat/group/group_chat_page.dart` — `XFile` au lieu de `dart:io File` pour upload
- `lib/pages/chat/group/group_info_page.dart` — idem
- `lib/pages/chat/group/create_group_page.dart` — idem

**CORS Firebase Storage :** `cors.json` appliqué sur `gs://afrolooki.appspot.com` avec headers `Accept-Ranges`, `Content-Range`, `Range` pour le streaming vidéo.

---

### 2. Group Chat — Flash de permissions (session 82)

**Problème :** À l'ouverture d'un groupe, les banners (frozen/read-only/no-write) et la barre d'input s'affichaient avec `_myRole = 'member'` (défaut) avant la fin du chargement des vraies permissions → flash visible.

**Solution :** Ajout du flag `bool _permissionsLoaded = false` dans `group_chat_page.dart`.
- `_loadGroup()` → set `_permissionsLoaded = true` dans le même `setState` que le rôle
- Dans `build()` : banners et barre d'input enveloppés dans `if (_permissionsLoaded)` → invisibles jusqu'à ce que les permissions soient connues

**Fichier modifié :** `lib/pages/chat/group/group_chat_page.dart`

---

### 3. HomeConstPage — Layout jump + performance (session 82)

**Problème :** En arrivant sur la page home, le premier post s'affichait depuis le cache, puis les sections (chroniques, profils) apparaissaient et décalaient tout le contenu vers le bas.

**Cause racine 1 :** `Post.toJson()` mettait des objets `Timestamp` Firestore bruts → `jsonEncode` explosait silencieusement → **aucun post n'était jamais sauvegardé en cache**.

**Cause racine 2 :** Les sections (chroniques, profils) étaient chargées depuis le cache dans `_loadFromCacheAndDisplay()` avec leurs données, mais leurs flags `_isLoadingX` restaient `true` → les sections se cachaient quand même malgré le cache.

**Solution architecture `HomeBootCache` :**

Nouveau fichier : `lib/pages/home/home_boot_cache.dart`
- Singleton `HomeBootCache` avec clé stable `home_boot_<userId>` (sans dépendance pays/filtre)
- Stocke 5 posts max + chroniques + profils suggérés
- `preload(userId)` appelé dans `_navigateToHomeWithDestination()` du splash **avant** navigation (< 10ms depuis SharedPreferences)
- `save(...)` appelé dans `_loadSuggestedUsersInBackground()` après chaque refresh réseau

**Fichiers modifiés :**

`lib/models/model_data.dart` — `Post` :
- Ajout méthode statique `_tsToMs(dynamic v)` → convertit `Timestamp` Firestore en `int` (ms)
- `Post.toJson()` : `created_at`, `updated_at`, `lastScoreUpdate`, `recentEngagement`, `eventDate` → tous passent par `_tsToMs()`
- `Post.fromJson()` : idem pour normaliser les Timestamps venant de Firestore

`lib/pages/home/HomeConstPost.dart` :
- `_loadFromCacheAndDisplay()` : ajout de `_isLoadingChroniques = false`, `_isLoadingSuggestedUsers = false`, `_isLoadingCanaux = false`, `_isLoadingArticles = false` quand le cache a de la donnée → sections visibles immédiatement depuis le cache
- Loaders réseau : `setState(() => _isLoadingX = true)` conditionnel sur `_dataList.isEmpty` → pas de flash si le cache a déjà fourni les données
- `initState()` : lecture synchrone de `HomeBootCache.instance` **avant le premier build** — premier frame déjà peuplé
- 1ère visite (sans cache) : sections lancées **en parallèle** avec les posts au lieu d'attendre la fin du chargement posts

`lib/pages/splashChargement.dart` :
- `_navigateToHomeWithDestination()` → `async` + `await HomeBootCache.preload(userId)` avant navigation
- Refactoring `_prepareDestination()` : `.then()` → `await` direct pour supporter l'`await` de navigation

**Sections feed :**
- `lib/widgets/feed/sections/feed_profiles_section.dart` — `if (isLoading || users.isEmpty) return SizedBox.shrink()` → rien affiché pendant le chargement (comportement voulu)
- `lib/widgets/feed/sections/feed_articles_section.dart` — idem
- `lib/widgets/feed/sections/feed_canaux_section.dart` — idem

**Comportement final :**
- **2ème session+** : posts + chroniques + profils s'affichent sur le **premier frame** sans shimmer, sans jump
- **1ère session** : posts et sections chargent en parallèle depuis le réseau, boot cache sauvegardé pour la prochaine ouverture
- Refresh réseau silencieux en arrière-plan sans faire disparaître les sections déjà affichées


---

## Session 86 — Cadeaux accès rapide (QuickGiftBar) + Fix admin groupe

### 1. QuickGiftBar — Raccourcis cadeaux (3 slots)

**Objectif :** Remplacer le bouton "Soutenir le créateur" par 3 bulles de cadeaux à accès rapide + bouton "+" sur les posts et pages détail.

**Nouveaux fichiers :**

- `lib/services/quick_gift_service.dart` — Gestion SharedPreferences pour l'historique récent (max 10) et les cadeaux épinglés (max 3). Clés : `quick_gift_recent_v1`, `quick_gift_pinned_v1`. Méthodes : `recordRecentGift`, `getRecentGifts`, `pinGift`, `unpinGift`, `getPinnedGifts`, `getShortcuts` (défauts 🔥💎👑).
- `lib/widgets/gifts/quick_gift_bar.dart` — Widget StatefulWidget avec :
  - 3 bulles cliquables (icône emoji, bordure dorée si épinglé, badge doré)
  - Bouton "+" → ouvre `CoinGiftDialog`
  - Compteur total pièces cadeaux affiché sous les bulles
  - Envoi optimiste : toast immédiat, Firestore fire-and-forget en arrière-plan
  - Debounce 1,5s anti double-envoi
  - Long press → bottom sheet (épingler/désépingler/ouvrir modal)
  - Toast animé slide-from-top avec dégradé doré (auto-dismiss 1,4s)

**Fichiers modifiés :**

`lib/pages/coins/coin_gift_dialog.dart` :
- Ajout `int _quantity = 1` — tap sur la même case → incrémente la quantité, tap autre case → reset à 1
- Badge `x$_quantity` sur la case sélectionnée
- Bouton envoi affiche `3x 💎  🪙 300` (coût total)
- `_sendGift()` utilise `totalCost = pack.coins * _quantity`
- Enregistrement dans `QuickGiftService.recordRecentGift` après envoi réussi

`pubspec.yaml` : ajout `shared_preferences: ^2.3.3` (déclaration explicite)

**Widgets de carte post modifiés :**

`lib/pages/userPosts/postWidgets/postWidgetPage.dart` (HomePostUsersWidget) :
- `_buildSupportButton(hasAccess)` → `QuickGiftBar` si non-propriétaire, sinon `SizedBox.shrink()`
- `_buildPostActions()` → cadeau remplacé par `QuickGiftBar` si non-propriétaire et accès ok

`lib/pages/userPosts/youTube_video_card.dart` (YouTubeVideoCard) :
- `_buildPostActions()` → cadeau remplacé par `QuickGiftBar` si non-propriétaire et accès ok

`lib/pages/post_video_format_tel_details.dart` (PostDetailsVideoFormatTel) :
- Bouton "Soutenir le créateur" (container) remplacé par `QuickGiftBar` si non-propriétaire

**Pages détail modifiées :**

`lib/pages/postDetails.dart` (DetailsPost) :
- Import `quick_gift_bar.dart` ajouté
- `_buildSupportButton()` réécrit → `QuickGiftBar` si non-propriétaire et accès ok, sinon `SizedBox.shrink()`
- `_buildStatsRow()` → section cadeau remplacée par `QuickGiftBar` via `Builder` (lecture seule si propriétaire ou accès verrouillé)
- Appel `_buildActionButtons(updatedPost)` + Divider supprimés (doublon de `_buildStatsRow`)
- Méthode `_buildActionButtons()` supprimée

`lib/pages/postDetailsVideo.dart` (VideoYoutubePageDetails) :
- Import `quick_gift_bar.dart` ajouté
- `_buildActionButtons()` réécrit : chaque bouton affiche icône + compteur + label (style `_buildStatItem`) et est cliquable — cadeau remplacé par `QuickGiftBar`
- `_buildStatsRow()` supprimée (doublon unifié dans `_buildActionButtons`)
- `_buildSupportButton()` supprimée (doublon)
- Appels `_buildStatsRow()` et `_buildSupportButton(_currentPost)` retirés du build

---

### 2. Fix — Admin app (role == 'ADM') bloqué en read-only dans les groupes

**Problème :** L'admin app entrant dans un groupe restait en mode lecture seule (pas de champ de saisie).

**Cause :** `_userCanWrite` contenait `!_isAppAdmin && ...` → toujours `false` pour ADM.

**Solution dans `lib/pages/chat/group/group_chat_page.dart` :**

```dart
// Avant (buggy)
bool get _userCanWrite => !_isAppAdmin && !_isBlocked && GroupPermissionUtils.canWrite(...)

// Après (corrigé)
bool get _userCanWrite => _isAppAdmin || (!_isBlocked && GroupPermissionUtils.canWrite(...))
bool get _userCanShare => _isAppAdmin || (!_isBlocked && GroupPermissionUtils.canShare(...))
```

- 4 méthodes d'envoi (texte, image, vidéo, document) : `if (!_isMember(myId)) return;` → `if (!_isAppAdmin && !_isMember(myId)) return;`
- ADM a toujours tous les droits d'écriture dans n'importe quel groupe, quel que soit son statut de membre

---

---

## Session 87 — Fix navigation après partage + fix temps réel groupes

### 1. Fix navigation après partage de post vers un groupe (CRITIQUE)

**Problème :** Après partage d'un post depuis une page détail (post_share_sheet / generic_share_sheet), le bottom sheet restait ouvert et il n'y avait aucune navigation vers le groupe.

**Cause racine :** `_doneAndOpenGroup` appelait `Navigator.of(context)`, `ScaffoldMessenger.of(context)` et `AppColors.of(context)` après des `await` — le BuildContext est invalidé après une gap async, ce qui causait une exception silencieuse.

**Solution dans `lib/widgets/chat/post_share_sheet.dart` et `lib/widgets/chat/generic_share_sheet.dart` :**
- Capture de `nav = Navigator.of(context)`, `scaffoldMsg = ScaffoldMessenger.of(context)`, `primaryColor = AppColors.of(context).primary` AVANT le premier `await` dans `_sendToGroup`
- Navigation inline après le try-catch en utilisant les références capturées
- Méthode `_doneAndOpenGroup` supprimée (code mort)

### 2. Fix groupes officiels — temps réel + badge non-lus + date à jour

**Problème :** La liste des chats de groupe n'était pas mise à jour en temps réel quand des messages/posts étaient partagés depuis d'autres pages.

**Cause :** Les groupes officiels utilisaient un `get()` (lecture unique) alors que les chats directs utilisaient `snapshots()` (stream temps réel).

**Solution dans `lib/pages/user/conversation/listUserConv.dart` :**
- Ajout d'un `StreamSubscription` (`_groupsStreamSub`) alimenté par `.snapshots()` sur la collection `GroupChats`
- `_initGroupsStream()` : écoute Firestore en temps réel, met à jour la liste à chaque changement
- `initState` : appelle `_loadGroupCache().then((_) => _initGroupsStream())`
- `dispose()` : `_groupsStreamSub?.cancel()`
- `_buildGoldGroupCard` : badge unread_counts affiché (Positioned top:-4/right:-4), `fontWeight` w700 si non-lus
- Retour depuis GroupChatPage : `load(force: true)` sur `GoldGroupsProvider` pour forcer le rechargement

### 3. Fix `updated_at` manquant lors du partage vers un groupe

**Problème :** Partager un post dans un groupe ne mettait pas à jour `updated_at`, donc le groupe ne remontait pas en tête de la liste.

**Solution :** Ajout de `'updated_at': now` dans `groupUpdate` dans les deux share sheets (`post_share_sheet.dart` et `generic_share_sheet.dart`).

### 4. Fix navigation PostComments → page détail correcte

**Problème :** Le bouton "voir le post" dans PostComments naviguait toujours vers `DetailsPost`, quel que soit le type.

**Solution dans `lib/pages/postComments.dart` :**
- Routage 3 voies : `VIDEO + isPortrait=true` → `PostDetailsVideoFormatTel`, `VIDEO + isPortrait=false` → `VideoYoutubePageDetails`, sinon → `DetailsPost`

---

---

## Session 88 — Fix groupes officiels (badge bleu) : temps réel + ADM + navigation

### Problèmes résolus

**1. Navigation après partage toujours bloquée pour ADM**
- **Cause** : `_sendToGroup` faisait 2 `await` pour vérifier les permissions depuis `members` subcollection. Pour un ADM non dans `member_ids`, le `role` revenait à 'member'. De plus, `catch (_) {}` avalait les erreurs Firestore silencieusement → `sent = false` → pas de navigation.
- **Solution** dans `lib/widgets/chat/post_share_sheet.dart` et `lib/widgets/chat/generic_share_sheet.dart` :
  - Vérification `isAppAdmin = _auth.loginUserData.role == 'ADM'` AVANT tout `await`
  - Si ADM : skip complet du bloc de permission (comme dans `group_chat_page.dart`)
  - `catch` maintenant loggue l'erreur : `catch (e, st) { debugPrint(...); }`

**2. Carousel GoldGroupsProvider jamais mis à jour en temps réel**
- **Cause** : `GoldGroupsProvider` utilisait `get()` avec cache 10 min — aucune mise à jour quand des messages arrivaient.
- **Solution** dans `lib/providers/gold_groups_provider.dart` :
  - Ajout d'un `StreamSubscription` (`_officialSub`) sur les groupes officiels (`is_official == true`)
  - `startStream()` lancé automatiquement depuis `load()` — stream alimenté par Firestore `snapshots()`
  - `_rebuildGroups()` : fusionne official groups (stream) + gold user groups (one-time), trié par `last_message_at` desc
  - `dispose()` ajouté pour `_officialSub?.cancel()`
  - Les gold user groups (groupes des utilisateurs Gold) gardent le `get()` one-time

**3. Groupes pas triés dans le carousel**
- Avant : les groupes officiels n'étaient pas triés (shuffle aléatoire)
- Maintenant : `_rebuildGroups()` trie par `last_message_at` desc → les groupes avec messages récents remontent

**4. Groupes dont l'ADM est propriétaire absents de `_groups`**
- **Cause** : `_initGroupsStream` ne queryait que `member_ids arrayContains myId`. Pour ADM qui entre dans ses groupes sans être ajouté à `member_ids`, ces groupes n'apparaissaient pas dans la liste.
- **Solution** dans `lib/pages/user/conversation/listUserConv.dart` :
  - Ajout d'un second `StreamSubscription` (`_ownedGroupsStreamSub`) : `owner_id == myId`
  - `_mergeAndSetGroups()` : fusionne les 2 streams, déduplique par `id`, trie par `last_message_at`
  - `dispose()` : `_ownedGroupsStreamSub?.cancel()`

---

### Règle de sécurité (rappel)
- Commission split : 75% parrain affiché dans l'UI, 25% revenus app — **ne jamais afficher les 25% dans l'UI**
- ADM est Gold permanent

---

## Session 89 — Fix gains vues + suppression définitive chat groupe (multi-sélection)

### 1. Fix page détails utilisateur admin — dates et rôle « non disponible »

**Fichiers :** `lib/models/model_data.dart`, `lib/pages/auth/authTest/Screens/Signup/signup_up_form_step_2.dart`

- `UserData.fromJson` : lecture `createdAt` (camelCase Firestore), `updatedAt`, `last_time_active` via `parseTimestamp()`
- `parseTimestamp()` : détection automatique microsecondes (`> 9999999999999 → value ~/ 1000`) vs millisecondes vs `Timestamp` Firestore → corrige l'affichage aberrant « 58222 »
- `toJson()` : inclusion `createdAt`, `updatedAt`, `role` pour l'écriture Firestore
- Création de compte (`signup_up_form_step_2.dart`) : passage de `microsecondsSinceEpoch` → `millisecondsSinceEpoch`
- Affichage rôle : fallback `'Utilisateur'` si champ vide

### 2. Fix page gains par vues — affichage et calcul

**Fichiers :** `lib/pages/user/mes_gains_post_page.dart`, `lib/services/postService/post_view_service.dart`, `lib/l10n/app_localizations.dart`

**Taux :** 1 FCFA/vue (100 vues = 100 FCFA). Constante `_fcfaPerView = 1.0`.

**Calcul dynamique du disponible :**
- Avant : `postViewsAvailable` stocké en FCFA fixe → incohérent au changement de taux
- Maintenant : `available = (totalPostUniqueViews × _fcfaPerView) − postViewsTotalCashed` (jamais stocké)
- Transaction d'encaissement revalidée en Firestore (race-condition safe)

**Vues uniques par post :**
- `recordAuthorView` incrémente `postViewsMonthly.$month`, `postViewsMonthlyPostIds.$month` (arrayUnion), `postViewsPerPost.$postId`, `uniqueViewsCount` sur le post
- Migration one-time (`postViewsMigrationDone`) recalcule depuis `uniqueViewsCount ?? vues` des posts

**Bottom sheet mois — posts s'affichaient mais vues = 0 :**
- Cause : `postViewsMonthly` pouvait être 0 après reset de `fixMonthlyData` (si `uniqueViewsCount` était nul sur les posts)
- Fix : `_monthlyPostIds` (Map<String, List<String>>) lu directement depuis Firestore au chargement de la page
- `_monthlyCard` fusionne `postViewsMonthly` + `postViewsMonthlyPostIds` : affiche `postViewsMonthly[mois]` si > 0, sinon `postViewsMonthlyPostIds[mois].length` (nombre de posts distincts vus ce mois)
- Mois visibles proviennent de l'union des deux maps (plus aucun mois orphelin invisible)

**Sous-titre stats :** affiche `totalViews vues` (non `postViewsAvailable / rate` → évite la confusion)

### 3. Fix chat groupe — scroll initial + bouton bas + suppression définitive

**Fichier :** `lib/pages/chat/group/group_chat_page.dart`

**Scroll initial fiable :**
- `_initialScrollDone` flag → premier chargement : `_scrollToBottomInitial()` (double `addPostFrameCallback`)
- Messages suivants : `_scrollToBottomIfNearEnd()` (scroll auto seulement si `< 150px` du bas)
- Bouton AppBar `keyboard_double_arrow_down` pour descendre manuellement

**Suppression définitive (admin) :**
- `_permanentDeleteMessage` : suppression physique Firestore (`doc.delete()`), aucune trace
- Appui long sur messages déjà supprimés (`is_deleted: true`) autorisé pour l'admin
- Modal options rendu scrollable (`isScrollControlled: true` + `ConstrainedBox 75%` + `SingleChildScrollView`)

### 4. Sélection multiple pour suppression définitive (admin uniquement)

**Fichier :** `lib/pages/chat/group/group_chat_page.dart`

**Fonctionnement :**
- Appui long (admin) → entre en mode sélection, sélectionne le message visé
- `_isSelectionMode` + `Set<String> _selectedMsgIds` comme état
- Tap en mode sélection → toggle sélection (checkbox circulaire à gauche de chaque bulle)
- Fond animé (`AnimatedContainer`) teinté sur les messages sélectionnés
- Avatar expéditeur masqué en mode sélection pour laisser la place aux checkboxes
- `AbsorbPointer` implicite via `GestureDetector.behavior = HitTestBehavior.opaque` : neutralise les taps imbriqués (images, liens)
- `_deleteSelectedMessages()` : `WriteBatch` Firestore par paquets de 400, suppression physique de tous les messages sélectionnés
- `PopScope` : bouton retour Android quitte le mode sélection sans fermer la page

**AppBar mode sélection :**
- Fond teinté primaire
- `✕` annule la sélection
- Titre dynamique `"N message(s) sélectionné(s)"`
- Bouton `🗑` rouge affiché dès qu'au moins 1 message est coché → confirme avant suppression

---

### Règle de sécurité (rappel)
- Commission split : 75% parrain affiché dans l'UI, 25% revenus app — **ne jamais afficher les 25% dans l'UI**
- ADM est Gold permanent
