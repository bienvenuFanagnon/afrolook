# SUIVI REFONTE UI — AFROLOOK V2
_Dernière mise à jour : 13 juin 2026 (session 13)_

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

---

## WIDGET TOGGLE THÈME

Le bouton de basculement clair/sombre est à exposer clairement dans l'UI.  
`ThemeProvider.toggleTheme()` existe déjà.

**À faire :** Proposer une position cohérente (drawer, settings, AppBar) et un design du bouton toggle.

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

**Backlog** : tâche #8 ("Dating: theme+i18n+CDN `dating_subscription_page.dart`") marquée comme **complétée**.
