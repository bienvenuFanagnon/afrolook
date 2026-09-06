import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/home/unitePostPage/chronique_section.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../../providers/sound_provider.dart';
import '../../services/utils/abonnement_utils.dart';
import '../auth/authTest/Screens/updateUserData.dart';
import '../chronique/chroniqueform.dart';
import '../component/showUserDetails.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import 'package:shimmer/shimmer.dart';
import '../contenuPayant/recent_vip_content_widget.dart';
import '../contenuPayant/widgets/boosted_content_strip.dart';
import '../dating/widgets/top_dating_profiles_widget.dart';
import '../postDetailsVideo.dart';
import '../pronostics/pronostics_carousel_widget.dart';
import '../pub/rewarded_interstitial_ad_widget.dart';
import '../user/userAbonnementPage.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../providers/mixed_feed_service_provider.dart';
import 'dart:typed_data';

import '../userPosts/youTube_video_card.dart';
import '../userPosts/video_preload_manager.dart';
import 'feed_cache_service.dart';
import '../../services/postService/post_view_service.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/feed/sections/feed_articles_section.dart';
import '../../widgets/feed/sections/feed_canaux_section.dart';
import '../../widgets/feed/sections/shop_promo_feed_widget.dart';
import '../../widgets/feed/sections/feed_profiles_section.dart';
import '../../widgets/feed/sections/feed_state_widgets.dart';
import '../../widgets/feed/sections/feed_filter_bar.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../../services/feed/feed_repository.dart';
import '../../services/feed/feed_preload_service.dart';
import '../../constants/user_interests.dart';
import '../../widgets/feed/sections/feed_category_section.dart';
import '../../widgets/feed/sections/feed_end_discovery_section.dart';
import '../../services/feed/discovery_boost_service.dart';
import '../../services/active_creators_service.dart';
import '../user/active_creators_list_page.dart';
import '../../layout/responsive_layout.dart';
import '../../layout/centered_content.dart';
import '../user/creator_unseen_posts_page.dart';
import '../user/following_unseen_feed_page.dart';
import 'home_boot_cache.dart';
import '../../widgets/feed/weekly_top_creators_widget.dart';
import '../../widgets/feed/sections/weekly_top_posts_section_widget.dart';
import '../../widgets/feed/sections/weekly_top_commentators_widget.dart';
import '../../widgets/feed/sections/comment_level_widget.dart';
import '../../widgets/flame_streak_banner.dart';


// Constantes de couleur
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
const Color accentYellow = Color(0xFFFFD700);
final Color _primaryColor = Color(0xFFE21221); // Rouge

// ── Helpers top-level pour la gestion des posts vus (Tier 1) ─────────────────
const _kSeenPostsPrefKey = 'seen_tier1_posts_pending';

Future<void> _persistSeenLocally(Set<String> ids) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kSeenPostsPrefKey) ?? [];
    final merged = {...existing, ...ids}.toList();
    if (merged.length > 1000) merged.removeRange(0, merged.length - 1000);
    await prefs.setStringList(_kSeenPostsPrefKey, merged);
  } catch (_) {}
}

/// Flush les posts vus de la session précédente vers Firestore ET nettoie
/// la mémoire. Appelé avant le chargement du feed pour que Tier 1 soit propre.
Future<void> flushSeenPostsAndCleanMemory(
  String userId,
  UserData userData,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_kSeenPostsPrefKey) ?? [];
    if (pending.isEmpty) return;
    final toFlush = pending.take(500).toList();
    final updates = <String, dynamic>{};
    for (final id in toFlush) {
      updates['unreadPosts.$id'] = FieldValue.delete();
    }
    await FirebaseFirestore.instance.collection('Users').doc(userId).update(updates);
    for (final id in toFlush) {
      userData.unreadPosts?.remove(id);
    }
    final remaining = pending.length > 500 ? pending.sublist(500) : <String>[];
    await prefs.setStringList(_kSeenPostsPrefKey, remaining);
  } catch (_) {}
}

class HomeConstPostPage extends StatefulWidget {
  final String type;
  final String? sortType;
  final bool isVideoPage; // Nouvelle variable avec défaut false


  HomeConstPostPage({super.key, required this.type, this.sortType,    this.isVideoPage = false, // valeur par défaut
  });

  @override
  State<HomeConstPostPage> createState() => _HomeConstPostPageState();
}

class _HomeConstPostPageState extends State<HomeConstPostPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Providers
  late UserAuthProvider authProvider;
  late UserShopAuthProvider authProviderShop;
  late ContentProvider contentProvider;
  late CategorieProduitProvider categorieProduitProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  late MixedFeedServiceProvider mixedFeedProvider;
   String HAS_SEEN_VIDEO_PAGE_KEY = 'has_seen_video_quality_page';

  // Contrôleurs
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  // Variables d'état pour les posts
  List<Post> _posts = [];

  // Liste des posts effectivement rendus dans le feed, utilisée par le
  // préchargement vidéo Facebook-style pour retrouver les voisins d'un index donné.
  List<Post> _renderedFeedPosts = [];
  bool _isLoadingPosts = true;
  bool _hasErrorPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  bool _isLoadingBackground = false;

  // Curseur DocumentSnapshot pour le mode récent (startAfterDocument — unit-agnostic)
  QueryDocumentSnapshot? _recentLastDoc;

  // Système hybride de chargement
  Set<String> _loadedPostIds = Set();
  int _totalPostsLoaded = 0;
  int _backgroundPostsLoaded = 0; // Compteur des posts chargés en background
  final int _initialLimit = 4; // Premier chargement: 4 posts
  final int _backgroundLoadLimit = 8;
  final int _manualLoadLimit = 8;
  final int _maxBackgroundPosts = 20;
  final int _maxTotalPosts = 1000;
  Timer? _backgroundLoadTimer;
  bool _useBackgroundLoading = true;

  // === Pool de widgets rotatifs (1 widget par slot, intervalle 4 posts) ===
  static const List<String> _kPoolOrder = [
    'BoostedContent', 'WeeklyTopCreators', 'Canaux', 'VIPContent', 'Articles',
  ];

  // Filtrage par pays
  String? _selectedCountryCode;
  String _currentFilter = 'MIXED'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  // String _currentFilter = 'ALL'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  bool _isFirstLoad = true;


  // Données supplémentaires - chargement séparé
  // Initialisés à true → skeleton visible dès le premier build,
  // avant même que le cache des posts s'affiche. Évite le saut de layout
  // quand les sections s'insèrent après coup au-dessus des posts.
  List<ArticleData> _articles = [];
  bool _isLoadingArticles = true;
  bool _hasStartedLoadArticles = false;

  List<Canal> _canaux = [];
  bool _isLoadingCanaux = true;
  bool _hasStartedLoadCanaux = false;

  List<UserData> _suggestedUsers = [];
  List<ActiveCreator> _activeCreators = [];
  bool _isLoadingSuggestedUsers = true;
  bool _hasStartedLoadSuggestedUsers = false;
  Map<String, int> _unseenCounts = {};
  Map<String, int> _creatorLastActivityUs = {};
  List<String> _followedCanalIds = [];
  List<String> _followingIds = []; // créateurs que l'utilisateur SUIT (abonnements)
  List<ActiveCanal> _recentCanaux = [];
  final _activeCreatorsService = ActiveCreatorsService();
  // Posts déjà décrémentés dans cette session (évite double-décrément au scroll)
  final _decrementedPostIds = <String>{};
  // IDs des posts Tier 1 CHARGÉS comme Tier 1 → utilisés uniquement pour le badge badge "Nouveau".
  // NE JAMAIS ajouter ici des posts vus au scroll : uniquement _loadTier1Posts().
  final _seenTier1PostIds = <String>{};
  // IDs des posts unreadPosts vus au scroll → pour flush Firestore (séparé du badge).
  final _viewedUnreadIds = <String>{};
  // Tier 2 : posts chargés par intérêts (pour badge "Découverte")
  final _tier2PostIds = <String>{};
  // Découverte créateur : posts injectés depuis créateurs non suivis (badge "Découverte · Créateur")
  final _localDiscoveryIds = <String>{};
  // Pool de posts réguliers de créateurs non suivis (rempli en arrière-plan)
  List<Post> _regularDiscoveryPool = [];
  // Lead découverte : 1 fois sur 3 exactement (compteur déterministe)
  bool _leadDiscoveryWithT1 = false;
  static int _leadDiscoveryCounter = 0;
  Timer? _stayTimer;
  bool _isPageVisible = true;
  bool _isSupportDialogShowing = false;
  String? _lastPopupDateKey = 'last_support_ad_popup_date';
  // Chroniques
  List<Chronique> _chroniques = [];
  bool _isLoadingChroniques = true;
  bool _hasStartedLoadChroniques = false;
  Map<String, List<Chronique>> _groupedChroniques = {};
  final Map<String, Uint8List> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};

  // Gestion de visibilité
  final Map<String, Timer> _visibilityTimers = {};
  final Map<String, bool> _postsViewedInSession = {};

  // Animation
  late AnimationController _starController;
  late AnimationController _unlikeController;

  // Utilitaires
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late SharedPreferences _prefs;
  final String _lastViewDatePrefix = 'last_view_date_';
  static const String _kLastSessionTsKey = 'last_session_timestamp';
  bool _sessionTimestampSaved = false;

// 🔥 NOUVELLE MÉTHODE
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }


  late SoundProvider _soundProvider;
  @override
  void initState() {
    super.initState();
    // 🔥 Initialisation du MediaPlaybackManager avec l'instance globale
    // (celle fournie par le ChangeNotifierProvider dans main.dart, la même
    // utilisée par l'icône son de l'AppBar, AudioPostCard et YouTubeVideoCard)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _soundProvider = Provider.of<SoundProvider>(context, listen: false);
      MediaPlaybackManager.init(_soundProvider);
    });
    _initSharedPreferences();
    // checkAndRedirectToVideoPage(context);
    // Initialisation des providers
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    contentProvider = Provider.of<ContentProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

    // Boot cache désactivé — le système Tier charge toujours du réseau au démarrage.
    final boot = HomeBootCache.instance;
    if (false && boot.isReady) {
      _posts = List.from(boot.posts);
      _loadedPostIds.addAll(boot.posts.map((p) => p.id ?? '').where((id) => id.isNotEmpty));
      _totalPostsLoaded = boot.posts.length;
      _isLoadingPosts = false;
      _isFirstLoad = false;
      if (boot.chroniques.isNotEmpty) {
        _chroniques = List.from(boot.chroniques);
        _isLoadingChroniques = false;
      }
      if (boot.suggestedUsers.isNotEmpty) {
        _suggestedUsers = List.from(boot.suggestedUsers);
        _isLoadingSuggestedUsers = false;
      }
    }
    // Pré-peupler les counts depuis newPostsByCreator (déjà en mémoire, 0 requête).
    // Garantit que les boot users affichent leurs badges immédiatement, sans
    // attendre que resolve() termine son fetch Firestore.
    final cfCounts = Map<String, int>.from(
        authProvider.loginUserData.newPostsByCreator ?? {});
    cfCounts.removeWhere((_, v) => v <= 0);
    if (cfCounts.isNotEmpty) _unseenCounts = cfCounts;

    // Configuration initiale
    _initializeAnimations();
    _setupScrollController();
    _setupLifecycleObservers();
    _initializeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStayTimer();
    });
  }

  @override
  void dispose() {
    _scrollCooldownTimer?.cancel();
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _seenTimers.forEach((_, t) => t.cancel());
    _backgroundLoadTimer?.cancel();
    _starController.dispose();
    _unlikeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    MediaPlaybackManager.dispose();
    _markSeenPostsInFirestore();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (_isPageVisible != isCurrent) {
      _isPageVisible = isCurrent;
      if (_isPageVisible) {
        _startStayTimer();
      } else {
        _stopStayTimer();
      }
    }
  }

  Future<bool> _shouldStartTimer() async {
    if (_isUserPremium()) {
      printVm('⏱️ [Timer] Utilisateur premium → timer non démarré');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPopupDateStr = prefs.getString(_lastPopupDateKey!);
    if (lastPopupDateStr != null) {
      final lastDate = DateTime.parse(lastPopupDateStr);
      final diffDays = DateTime.now().difference(lastDate).inDays;
      printVm('⏱️ [Timer] Dernière popup: $lastPopupDateStr, différence jours: $diffDays');
      if (diffDays < 2) {
        printVm('⏱️ [Timer] Délai de 2 jours non écoulé → timer non démarré');
        return false;
      }
    }

    printVm('⏱️ [Timer] Conditions OK : non premium et cooldown passé');
    return true;
  }
  void _startStayTimer() async {
    printVm('⏱️ [Timer] Démarrage demandé...');

    bool shouldStart = await _shouldStartTimer();
    if (!shouldStart) return;
    _checkAndShowSupportPopup();

  }
  void _stopStayTimer() {
    // if (_stayTimer != null && _stayTimer!.isActive) {
    //   _stayTimer!.cancel();
    //   printVm('⏱️ [Timer] Timer annulé');
    // }
  }

  bool _isUserPremium() {
    final user = authProvider.loginUserData;
    if (user == null) {
      printVm('🔍 [Premium] Utilisateur null');
      return false;
    }
    final isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
    printVm('🔍 [Premium] Abonnement utilisateur: ${user.abonnement} => isPremium = $isPremium');
    return isPremium;
  }

  Future<void> _checkAndShowSupportPopup() async {
    printVm('🔔 [Popup] Vérification des conditions...');
    if (!_isPageVisible) {
      printVm('🔔 [Popup] Page non visible → annulé');
      return;
    }
    if (_isSupportDialogShowing) {
      printVm('🔔 [Popup] Popup déjà en cours d\'affichage → annulé');
      return;
    }
    if (_isScrollActive) {
      printVm('🔔 [Popup] Scroll actif → annulé');
      return;
    }
    if (_isUserPremium()) {
      printVm('🔔 [Popup] Utilisateur premium → pas de popup');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPopupDateStr = prefs.getString(_lastPopupDateKey!);
    printVm('🔔 [Popup] Dernière date enregistrée: $lastPopupDateStr');

    if (lastPopupDateStr != null) {
      final lastDate = DateTime.parse(lastPopupDateStr);
      final diffDays = DateTime.now().difference(lastDate).inDays;
      printVm('🔔 [Popup] Différence en jours: $diffDays');
      if (diffDays < 2) {
        printVm('🔔 [Popup] Cooldown actif (moins de 2 jours) → popup ignoré');
        return;
      }
    }

    // Enregistrer la date actuelle
    final nowStr = DateTime.now().toIso8601String();
    await prefs.setString(_lastPopupDateKey!, nowStr);
    printVm('🔔 [Popup] Date enregistrée: $nowStr');

    // Vérifier que le widget est toujours monté après les await (navigation possible pendant l'async)
    if (!mounted) return;

    printVm('🔔 [Popup] Affichage du popup...');
    // Différer au prochain frame pour éviter le crash "hit test on unlaid-out box"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSupportDialog();
    });
  }
  void _showSupportDialog() {
    if (!mounted) return;
    _isSupportDialogShowing = true;
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: Row(
          children: [
            Icon(AntDesign.appstore1, color: primaryGreen, size: 24),
            const SizedBox(width: 8),
            Text(l10n.homeConstBusinessTitle, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeConstBusinessIntro,
                style: TextStyle(color: colors.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentYellow),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium, color: accentYellow, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.homeConstUpgradeTitle,
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            l10n.homeConstPremiumSubtitle,
                            style: TextStyle(color: accentYellow, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l10n.homeConstPremiumDesc,
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.homeConstUpgradeCta,
                  style: TextStyle(color: accentYellow, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isSupportDialogShowing = false;
            },
            child: Text(l10n.commonClose, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isSupportDialogShowing = false;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AbonnementScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentYellow,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(l10n.homeConstSubscribe, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _showInterstitialAd() {
    _interstitialAdKey.currentState?.showAd();
    // Optional: show a thank‑you snackbar after ad dismisses
    // We'll do that inside the widget's callback in the build method.
  }
  // Cooldown anti-crash : empêche les actions d'overlay (dialog, navigation)
  // pendant un scroll actif — la race condition Overlay↔hitTest est debug-only
  // mais on la prévient en bloquant les déclencheurs.
  bool _isScrollActive = false;
  Timer? _scrollCooldownTimer;

  void _setupScrollController() {
    _scrollController.addListener(_scrollListener);
  }

  void scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  /// Retourne true si le scroll est actif. Utiliser comme garde avant
  /// tout showDialog / Navigator.push déclenché depuis le feed.
  bool _canShowOverlay() {
    return !_isScrollActive;
  }

  void _setupLifecycleObservers() {
    WidgetsBinding.instance.addObserver(this);
    SystemChannels.lifecycle.setMessageHandler((message) {
      _handleAppLifecycle(message);
      return Future.value(message);
    });
  }

  void _initializeAnimations() {
    _starController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _unlikeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }
  void _initializeData() async {
    final userId = authProvider.loginUserData.id;
    if (userId != null && userId.isNotEmpty) {
      // 0. Rafraîchir unreadPosts depuis Firestore AVANT le flush :
      //    loginUserData est chargé une seule fois à la connexion, mais de nouveaux
      //    posts d'abonnements peuvent être arrivés depuis. Sans ce refresh, Tier 1
      //    serait toujours vide entre deux sessions.
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .get();
        final fresh = ((userDoc.data()?['unreadPosts'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt()));
        authProvider.loginUserData.unreadPosts = fresh;
        printVm('🔄 Tier 1 — unreadPosts rafraîchi : ${fresh.length} posts non vus');
      } catch (e) {
        printVm('⚠️ Impossible de rafraîchir unreadPosts : $e');
      }

      // Flush les posts vus lors de la session précédente → une seule écriture Firestore
      await flushSeenPostsAndCleanMemory(
        userId,
        authProvider.loginUserData,
      );
    }

    // Diagnostic Tier 2 — intérêts
    final interests = authProvider.loginUserData.interests ?? [];
    printVm('🎯 Tier 2 — interests utilisateur : $interests (${interests.length} configurés)');

    // Précharger les top créateurs, top posts et top commentateurs en parallèle
    WeeklyTopCreatorsWidget.preload();
    WeeklyTopPostsSectionWidget.preload();
    WeeklyTopCommentatorsWidget.preload();

    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    printVm('Pays utilisateur détecté: ${_selectedCountryCode}');

    // 🔥 MODIFICATION: Pour EVENEMENT, forcer le mode COUNTRY (pas de mix)
    if (widget.type == TabBarType.EVENEMENT.name) {
      _currentFilter = 'COUNTRY';  // Forcer le pays de l'utilisateur seulement
      printVm('🎯 Mode EVENEMENT activé - Filtre: COUNTRY (${_selectedCountryCode})');
    } else if (_selectedCountryCode != null) {
      // 🔥 Par défaut: filtre sur le pays de l'utilisateur (au lieu de "Tous")
      // L'utilisateur peut toujours changer via la modale de filtre (_showCountryFilterModal).
      _currentFilter = 'COUNTRY';
      printVm('🌍 Filtre par défaut: COUNTRY (pays utilisateur: ${_selectedCountryCode})');
    } else {
      _currentFilter = 'MIXED';     // Fallback si pays utilisateur inconnu
    }

    _isFirstLoad = true;
    _useBackgroundLoading = true;
    _backgroundPostsLoaded = 0;

    // 0a. Pré-chargement des posts non vus en arrière-plan (startup)
    _startFeedPreload();

    // Charge les données auxiliaires (chroniques, canaux, etc.) depuis le cache.
    // Les posts eux-mêmes ignorent le cache et viennent toujours du réseau (système Tier).
    final bool hasCachedPosts = await _loadFromCacheAndDisplay();

    // 3. Réinitialiser la pagination. Si le cache a déjà rempli `_posts`,
    // on NE LES EFFACE PAS (sinon le skeleton revient le temps du réseau) :
    // `_loadInitialPosts()` remplacera/complètera ces posts dès que la
    // réponse réseau arrive, sans repasser par un état "vide".
    _resetPagination(clearPosts: !hasCachedPosts);

    if (hasCachedPosts) {
      // Cache présent : réseau en arrière-plan, pas de skeleton.
      _loadInitialPosts();
      _startBackgroundLoading();
      // Décalé pour laisser T1+T2 s'exécuter sans contention Firestore
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _loadAllAdditionalDataInParallel();
        });
      });
    } else {
      // Pas de cache : décaler les sections pour éviter la contention avec T1+T2.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _loadAllAdditionalDataInParallel();
        });
      });
      await _loadInitialPosts();
      _startBackgroundLoading();
    }
  }

  // ===========================================================================
  // CACHE LOCAL DU FEED (affichage instantané "Facebook-style")
  // ===========================================================================

  /// Clé de cache unique par type de feed + tri (Home récents/populaires,
  /// Sport, etc.) pour éviter toute collision entre onglets.
  /// La clé de cache intègre le filtre pays courant (COUNTRY/MIXED/ALL +
  /// code pays) pour éviter qu'un changement de filtre via la modale
  /// n'écrase le cache du filtre par défaut (pays utilisateur) avec un
  /// contenu provenant d'un autre filtre.
  String get _feedCacheKey => FeedCacheService.buildKey(
      widget.type, '${widget.sortType ?? 'default'}_${_currentFilter}_${_selectedCountryCode ?? 'none'}');

  static const Duration _adsCacheMaxAge = Duration(hours: 1);
  static const Duration _vipCacheMaxAge = Duration(hours: 6);

  /// Charge les données mises en cache (posts, chroniques, profils suggérés,
  /// canaux, produits boostés) et les affiche immédiatement, sans attendre
  /// le réseau. Le chargement réseau classique se poursuit normalement après
  /// cet appel et remplacera/complètera ces données.
  Future<bool> _loadFromCacheAndDisplay() async {
    final _swCache = Stopwatch()..start();
    try {
      printVm('⏱️ [CACHE] lecture disque...');
      // Cache valide uniquement pour le jour en cours (minuit → minuit).
      // Le lendemain le cache est ignoré et un chargement réseau repart.
      final cached = await FeedCacheService.loadFeedData(_feedCacheKey, dailyCacheOnly: true);
      if (cached == null) {
        printVm('⏱️ [CACHE] aucun cache valide — ${_swCache.elapsedMilliseconds}ms');
        return false;
      }
      printVm('⏱️ [CACHE] lecture disque terminée — ${_swCache.elapsedMilliseconds}ms');

      final data = cached['data'] as Map<String, dynamic>;

      // --- Posts initiaux ---
      final cachedPostsJson = data['posts'] as List<dynamic>?;
      List<Post> cachedPosts = [];
      if (cachedPostsJson != null) {
        for (final p in cachedPostsJson) {
          try {
            final json = Map<String, dynamic>.from(p as Map);
            final post = Post.fromJson(json);
            post.id = json['id'] as String?;
            post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
            cachedPosts.add(post);
          } catch (e) {
            printVm('⚠️ Cache: erreur parsing post: $e');
          }
        }
      }

      // --- Chroniques ---
      final cachedChroniquesJson = data['chroniques'] as List<dynamic>?;
      List<Chronique> cachedChroniques = [];
      if (cachedChroniquesJson != null) {
        for (final c in cachedChroniquesJson) {
          try {
            final json = Map<String, dynamic>.from(c as Map);
            final id = json['id'] as String?;
            // Reconvertir les dates ISO -> Timestamp pour Chronique.fromMap
            final map = Map<String, dynamic>.from(json);
            if (map['createdAt'] is String) {
              map['createdAt'] = Timestamp.fromDate(DateTime.parse(map['createdAt'] as String));
            }
            if (map['expiresAt'] is String) {
              map['expiresAt'] = Timestamp.fromDate(DateTime.parse(map['expiresAt'] as String));
            }
            final chronique = Chronique.fromMap(map, id ?? '');
            if (!chronique.isExpired) {
              cachedChroniques.add(chronique);
            }
          } catch (e) {
            printVm('⚠️ Cache: erreur parsing chronique: $e');
          }
        }
      }

      // --- Auteurs des chroniques (profils résolus) ---
      final cachedChroniqueAuthors = data['chroniqueAuthors'] as Map<String, dynamic>?;
      if (cachedChroniqueAuthors != null) {
        cachedChroniqueAuthors.forEach((userId, userJson) {
          try {
            final userData = UserData.fromJson(Map<String, dynamic>.from(userJson as Map));
            _userDataCache[userId] = userData;
            _userVerificationStatus[userId] = userData.isVerify ?? false;
          } catch (e) {
            printVm('⚠️ Cache: erreur parsing auteur chronique: $e');
          }
        });
      }

      // --- Profils suggérés ---
      final cachedSuggestedJson = data['suggestedUsers'] as List<dynamic>?;
      List<UserData> cachedSuggestedUsers = [];
      if (cachedSuggestedJson != null) {
        for (final u in cachedSuggestedJson) {
          try {
            cachedSuggestedUsers.add(UserData.fromJson(Map<String, dynamic>.from(u as Map)));
          } catch (e) {
            printVm('⚠️ Cache: erreur parsing profil suggéré: $e');
          }
        }
      }

      // --- Canaux ---
      final cachedCanauxJson = data['canaux'] as List<dynamic>?;
      List<Canal> cachedCanaux = [];
      if (cachedCanauxJson != null) {
        for (final c in cachedCanauxJson) {
          try {
            cachedCanaux.add(Canal.fromJson(Map<String, dynamic>.from(c as Map)));
          } catch (e) {
            printVm('⚠️ Cache: erreur parsing canal: $e');
          }
        }
      }

      // --- Produits boostés / articles (Zone VIP) ---
      final cachedArticlesJson = data['articles'] as List<dynamic>?;
      List<ArticleData> cachedArticles = [];
      if (cachedArticlesJson != null) {
        for (final a in cachedArticlesJson) {
          try {
            cachedArticles.add(ArticleData.fromJson(Map<String, dynamic>.from(a as Map)));
          } catch (e) {
            printVm('⚠️ Cache: erreur parsing article boosté: $e');
          }
        }
      }

      if (!mounted) return false;

      final parseMs = _swCache.elapsedMilliseconds;
      printVm('⏱️ [CACHE] parsing JSON — ${cachedChroniques.length} chroniques, ${cachedSuggestedUsers.length} profils, ${cachedCanaux.length} canaux, ${cachedArticles.length} articles — ${parseMs}ms');

      // Posts ignorés du cache — le système Tier charge toujours depuis le réseau.
      setState(() {
        if (cachedChroniques.isNotEmpty) {
          _chroniques = cachedChroniques;
          _isLoadingChroniques = false; // données dispo depuis le cache → pas de jump
        }
        if (cachedSuggestedUsers.isNotEmpty) {
          _suggestedUsers = cachedSuggestedUsers;
          _isLoadingSuggestedUsers = false; // données dispo depuis le cache → pas de jump
        }
        if (cachedCanaux.isNotEmpty) {
          _canaux = cachedCanaux;
          _isLoadingCanaux = false;
        }
        if (cachedArticles.isNotEmpty) {
          _articles = cachedArticles;
          _isLoadingArticles = false;
        }
      });

      printVm('⏱️ [CACHE] total: ${_swCache.elapsedMilliseconds}ms — données auxiliaires affichées depuis le cache');
      return false; // Posts toujours depuis le réseau
    } catch (e) {
      printVm('⚠️ Erreur _loadFromCacheAndDisplay: $e [${_swCache.elapsedMilliseconds}ms]');
      return false;
    }
  }

  /// Sauvegarde l'état courant du feed dans le cache local pour le prochain
  /// affichage instantané. Appelé après chaque chargement réseau réussi
  /// (posts initiaux, chroniques, profils suggérés, canaux, articles boostés).
  Future<void> _saveFeedToCache() async {
    try {
      final data = <String, dynamic>{};

      // Posts exclus du cache — toujours rechargés depuis le réseau (système Tier).
      if (_chroniques.isNotEmpty) {
        data['chroniques'] = _chroniques.map((c) {
          final map = Map<String, dynamic>.from(c.toMap());
          map['id'] = c.id;
          // Timestamp -> ISO string pour sérialisation JSON
          if (map['createdAt'] is Timestamp) {
            map['createdAt'] = (map['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (map['expiresAt'] is Timestamp) {
            map['expiresAt'] = (map['expiresAt'] as Timestamp).toDate().toIso8601String();
          }
          return map;
        }).toList();

        // Auteurs résolus des chroniques affichées
        final authors = <String, dynamic>{};
        for (final c in _chroniques) {
          final userData = _userDataCache[c.userId];
          if (userData != null) {
            final json = userData.toJson();
            json['isVerify'] = userData.isVerify ?? false;
            authors[c.userId] = json;
          }
        }
        if (authors.isNotEmpty) {
          data['chroniqueAuthors'] = authors;
        }
      }

      if (_suggestedUsers.isNotEmpty) {
        data['suggestedUsers'] = _suggestedUsers.map((u) {
          final json = u.toJson();
          json['isVerify'] = u.isVerify ?? false;
          return json;
        }).toList();
      }

      if (_canaux.isNotEmpty) {
        data['canaux'] = _canaux.map((c) => c.toJson()).toList();
      }

      if (_articles.isNotEmpty) {
        data['articles'] = _articles.map((a) => a.toJson()).toList();
      }

      if (data.isEmpty) return;

      await FeedCacheService.saveFeedData(_feedCacheKey, data);
    } catch (e) {
      printVm('⚠️ Erreur _saveFeedToCache: $e');
    }
  }

  void _initializeData2() async {
    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    printVm('Pays utilisateur détecté: ${_selectedCountryCode}');

    // 2. Par défaut: mode "Tous les pays"
    _currentFilter = 'MIXED';
    // _currentFilter = 'ALL';
    _isFirstLoad = true;
    _useBackgroundLoading = true; // Activer le chargement background initial
    _backgroundPostsLoaded = 0; // Réinitialiser le compteur

    // 3. Réinitialiser et charger les posts initiaux (3 posts)
    _resetPagination();
    await _loadInitialPosts();

    // 4. Démarrer le chargement background (si activé)
    _startBackgroundLoading();

    // 5. Charger les autres données EN PARALLÈLE (décalé pour éviter contention)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _loadAllAdditionalDataInParallel();
      });
    });
  }

  void _resetPagination({bool clearPosts = true}) {
    if (clearPosts) {
      printVm('🧹 [RESET] _resetPagination clearPosts=true → seenTier1=${_seenTier1PostIds.length} IDs vidés, tier2=${_tier2PostIds.length} IDs vidés');
      _posts.clear();
      _loadedPostIds.clear();
      _isLoadingPosts = true; // évite l'écran vide pendant le rechargement
      _seenTier1PostIds.clear();
      _tier2PostIds.clear();
      _localDiscoveryIds.clear();
      _regularDiscoveryPool = [];
      _leadDiscoveryWithT1 = (_leadDiscoveryCounter % 3 == 0);
      _leadDiscoveryCounter++;
    }
    _totalPostsLoaded = 0;
    _backgroundPostsLoaded = 0;
    _hasMorePosts = true;
    _isLoadingMorePosts = false;
    _isLoadingBackground = false;
    _recentLastDoc = null;
  }

  // ===========================================================================
  // SYSTÈME HYBRIDE DE CHARGEMENT (Background + Manuel)
  // ===========================================================================

  void _startBackgroundLoading() {
    if (!_useBackgroundLoading) return;

    // Arrêter tout timer existant
    _backgroundLoadTimer?.cancel();

    printVm('🚀 Démarrage du chargement background (max: $_maxBackgroundPosts posts)');

    // Démarrer un nouveau timer pour le chargement background
    _backgroundLoadTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      // Conditions pour charger en background :
      // 1. Background activé
      // 2. Pas déjà en cours de chargement background
      // 3. Pas de chargement manuel en cours
      // 4. Il reste des posts à charger
      // 5. On n'a pas dépassé la limite de background
      // 6. L'utilisateur ne scroll pas activement
      if (_useBackgroundLoading &&
          !_isLoadingBackground &&
          !_isLoadingMorePosts &&
          _hasMorePosts &&
          _backgroundPostsLoaded < _maxBackgroundPosts &&
          _totalPostsLoaded < _maxTotalPosts &&
          !_isUserScrolling()) {

        await _loadBackgroundPosts();
      }

      // Arrêter le timer si :
      // 1. On a atteint la limite de background
      // 2. Il n'y a plus de posts à charger
      // 3. Le background est désactivé
      if (_backgroundPostsLoaded >= _maxBackgroundPosts ||
          !_hasMorePosts ||
          !_useBackgroundLoading) {
        printVm('⏹️ Arrêt du chargement background (posts background: $_backgroundPostsLoaded)');
        timer.cancel();
        _useBackgroundLoading = false; // Passer en mode manuel
      }
    });
  }

  bool _isUserScrolling() {
    if (!_scrollController.hasClients) return false;
    return _scrollController.position.isScrollingNotifier.value;
  }

  Future<void> _loadBackgroundPosts() async {
    if (_isLoadingBackground ||
        !_hasMorePosts ||
        _backgroundPostsLoaded >= _maxBackgroundPosts ||
        _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    printVm('🔄 Chargement background... ($_backgroundPostsLoaded/$_maxBackgroundPosts)');

    setState(() {
      _isLoadingBackground = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _backgroundLoadLimit);

      // Ajouter les nouveaux posts à la liste (spread pour éviter les rafales)
      if (newPosts.isNotEmpty) {
        final spread = _spreadCreatorsWithContext(newPosts, _posts);
        setState(() {
          _posts.addAll(spread);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += spread.length;
          _backgroundPostsLoaded += spread.length;
        });

        printVm('✅ ${spread.length} posts chargés en background (total: $_totalPostsLoaded, background: $_backgroundPostsLoaded)');
      }

      // Vérifier s'il reste des posts à charger
      _hasMorePosts = newPosts.length >= (_backgroundLoadLimit ~/ 2);

      // Si on atteint la limite de background, désactiver
      if (_backgroundPostsLoaded >= _maxBackgroundPosts) {
        _useBackgroundLoading = false;
        printVm('📊 Passage en mode chargement manuel (limite background atteinte)');
      }

    } catch (e) {
      printVm('❌ Erreur chargement background: $e');
    } finally {
      setState(() {
        _isLoadingBackground = false;
      });
    }
  }

  // ===========================================================================
  // MODAL DE FILTRE PAR PAYS - VERSION AMÉLIORÉE
  // ===========================================================================

  void _showCountryFilterModal() {
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Fonction pour mettre à jour la recherche
            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            // Filtrer les pays
            List<AfricanCountry> filteredCountries = AfricanCountry.allCountries
                .where((country) {
              if (searchQuery.isEmpty) return true;
              return country.name.toLowerCase().contains(searchQuery) ||
                  country.code.toLowerCase().contains(searchQuery) ||
                  country.name?.toLowerCase().contains(searchQuery) == true;
            }).toList();

            final colors = AppColors.of(context);
            final l10n = AppLocalizations.of(context);
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Poignée
                  Container(
                    height: 4,
                    width: 40,
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Titre et bouton fermer
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.feedFilterByCountry,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: colors.textSecondary, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Barre de recherche AMÉLIORÉE
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.search, color: colors.textSecondary, size: 20),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: updateSearch,
                              style: TextStyle(color: colors.textPrimary, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: l10n.feedSearchCountry,
                                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: colors.textSecondary),
                              onPressed: () {
                                searchController.clear();
                                updateSearch('');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Options rapides sur UNE SEULE LIGNE
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Option "Tous les pays"
                          _buildQuickFilterOption(
                            icon: Icons.public,
                            label: l10n.homeConstAllShort,
                            isSelected: _currentFilter == 'ALL',
                            color: primaryGreen,
                            onTap: () async {
                              Navigator.pop(context);
                              await _applyFilter(filterType: 'ALL', countryCode: null);
                            },
                          ),
                          SizedBox(width: 8),

                          // Option "Mon pays"
                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: null,
                              label: l10n.feedMyCountry,
                              flag: _getCountryFlag(_selectedCountryCode!),
                              isSelected: _currentFilter == 'COUNTRY',
                              color: Colors.blue,
                              onTap: () async {
                                Navigator.pop(context);
                                await _applyFilter(filterType: 'COUNTRY', countryCode: _selectedCountryCode);
                              },
                            ),

                          if (_selectedCountryCode != null) SizedBox(width: 8),

                          // Option "Mix"
                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: Icons.blender,
                              label: l10n.homeConstMix,
                              isSelected: _currentFilter == 'MIXED',
                              color: Colors.purple,
                              onTap: () async {
                                Navigator.pop(context);
                                await _applyFilter(filterType: 'MIXED', countryCode: _selectedCountryCode);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Séparateur
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: colors.divider, thickness: 1),
                  ),

                  // Titre liste pays
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          l10n.feedChooseCountry,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${filteredCountries.length} ${l10n.feedCountriesSuffix}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // Liste des pays avec recherche fonctionnelle
                  Expanded(
                    child: _buildCountryList(filteredCountries, searchQuery),
                  ),

                  // Bouton fermer
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.surfaceVariant,
                          foregroundColor: colors.textPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.commonClose,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickFilterOption({
    IconData? icon,
    required String label,
    String? flag,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.onPrimary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null)
              Text(flag, style: TextStyle(fontSize: 16))
            else if (icon != null)
              Icon(icon, size: 16, color: isSelected ? colors.onPrimary : colors.textSecondary),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.onPrimary : colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) SizedBox(width: 4),
            if (isSelected)
              Icon(Icons.check, size: 14, color: colors.onPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryList(List<AfricanCountry> countries, String searchQuery) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    if (countries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: colors.textSecondary, size: 48),
            SizedBox(height: 12),
            Text(
              searchQuery.isEmpty ? l10n.commonLoading : l10n.feedNoCountryFound,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 16,
              ),
            ),
            if (searchQuery.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  l10n.homeConstTryOtherSearch,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        final isCurrentCountry = _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();
        final isSelected = _currentFilter == 'CUSTOM' &&
            _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(context);
                await _applyFilter(
                  filterType: 'CUSTOM',
                  countryCode: country.code.toUpperCase(),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withOpacity(0.2) : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          country.flag,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentCountry)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.success.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.homeConstYourCountry,
                                    style: TextStyle(
                                      color: colors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            country.code.toUpperCase(),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.orange, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCountryFlag(String countryCode) {
    try {
      final country = AfricanCountry.allCountries.firstWhere(
            (c) => c.code.toUpperCase() == countryCode.toUpperCase(),
        orElse: () => AfricanCountry(
          code: countryCode,
          name: countryCode,
          flag: '🏳️',
        ),
      );
      return country.flag;
    } catch (e) {
      return '🏳️';
    }
  }

  Future<void> _applyFilter({
    required String filterType,
    String? countryCode,
  }) async
  {
    // Arrêter le chargement background pendant le changement de filtre
    _backgroundLoadTimer?.cancel();

    setState(() {
      _currentFilter = filterType;
      if (countryCode != null) {
        _selectedCountryCode = countryCode.toUpperCase();
      }
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true; // Réactiver le background pour le nouveau filtre
      _backgroundPostsLoaded = 0; // Réinitialiser le compteur
    });

    // Réinitialiser la pagination
    _resetPagination();

    // Charger les posts initiaux (3 posts)
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();
    setState(() {
      _isLoadingPosts = false;
    });

    printVm('✅ Filtre appliqué: $_currentFilter - Pays: $_selectedCountryCode');
  }

  // ===========================================================================
  // CHARGEMENT DES POSTS
  // ===========================================================================
  Future<void> _loadInitialPosts() async {
    final _sw = Stopwatch()..start();
    printVm('⏱️ [PERF] _loadInitialPosts démarré');
    try {
      if (authProvider.loginUserData.countryData?["countryCode"] == null &&
          authProvider.loginUserData.countryData?["country"] == null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UpdateUserData(title: "Mise à jour d'adresse"),
          ),
        );
      }

      setState(() {
        // 🔥 Ne réafficher le skeleton que si on n'a rien à montrer (pas de
        // posts issus du cache local) : sinon le contenu déjà affiché reste
        // visible pendant le rafraîchissement réseau (Facebook-style).
        if (_posts.isEmpty) {
          _isLoadingPosts = true;
        }
        _hasErrorPosts = false;
      });

      Set<String> loadedIds = Set();
      List<Post> newPosts = [];

      int limit = _initialLimit;
      printVm("_currentFilter data: ${_currentFilter}");

      // Mode récent : chargement direct par curseur Firestore (unit-agnostic)
      if (widget.sortType == 'recent') {
        await _loadInitialRecentPosts(loadedIds, newPosts, limit);
      } else {
        // ── T1 + T2 en PARALLÈLE ────────────────────────────────────────────
        // Prépare les données nécessaires aux deux requêtes
        var unread = authProvider.loginUserData.unreadPosts ?? {};
        // Plafond anti-accumulation (identique à _loadTier1Posts)
        const int _kMaxUnread = 200;
        if (unread.length > _kMaxUnread) {
          final sorted = unread.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final toKeep = sorted.take(_kMaxUnread).map((e) => e.key).toSet();
          final toDelete = unread.keys.where((id) => !toKeep.contains(id)).toList();
          for (final id in toDelete) { unread.remove(id); }
          authProvider.loginUserData.unreadPosts = unread;
          final userId = authProvider.loginUserData.id;
          if (userId != null) {
            for (int i = 0; i < toDelete.length; i += 500) {
              final batch = toDelete.sublist(i, min(i + 500, toDelete.length));
              final updates = <String, dynamic>{};
              for (final id in batch) { updates['unreadPosts.$id'] = FieldValue.delete(); }
              FirebaseFirestore.instance.collection('Users').doc(userId).update(updates).catchError((_) {});
            }
          }
        }
        final userInterests = authProvider.loginUserData.interests ?? [];
        // T2 seulement si l'utilisateur a configuré ses propres intérêts.
        // Avec les defaults (userInterests vide), la query retourne souvent 0 résultats
        // et coûte inutilement ~3-4s de Firestore cold start.
        final hasRealInterests = userInterests.isNotEmpty;
        final interests = hasRealInterests ? userInterests : UserInterests.defaults;
        final countryCode = authProvider.loginUserData.countryData?['countryCode'] as String? ?? '';
        // Snapshot des IDs exclus avant le lancement (évite les mutations concurrentes)
        final excludedSnapshot = Set<String>.from(_loadedPostIds);

        printVm('⏱️ [PERF] lancement T1+T2 en parallèle — unread=${unread.length}, interests=${userInterests.length} (réels=${hasRealInterests})');

        final t1Future = unread.isEmpty
            ? Future.value(<Post>[])
            : FeedRepository().fetchUnreadSubscriptionPosts(unread, excludedSnapshot, limit: 5);
        // T2 skippé si l'utilisateur n'a pas configuré ses intérêts (évite 3-4s pour 0 résultats)
        final t2Future = hasRealInterests
            ? FeedRepository().fetchInterestPosts(interests, excludedSnapshot, countryCode: countryCode, limit: 25)
            : Future.value(<Post>[]);

        final parallelResults = await Future.wait([t1Future, t2Future]);
        final t1Posts = parallelResults[0];
        final t2Posts = parallelResults[1];
        printVm('⏱️ [PERF] T1+T2 parallèle terminé: ${_sw.elapsedMilliseconds}ms — T1=${t1Posts.length}, T2=${t2Posts.length}');

        // Update tracking (T1 seen IDs, T2 seen IDs)
        for (final p in t1Posts) { if (p.id != null) _seenTier1PostIds.add(p.id!); }

        // Merge sans doublons : T1 prioritaire, T2 complète
        final mergedSeen = <String>{};
        final allMerged = <Post>[];
        for (final p in [...t1Posts, ...t2Posts]) {
          if (p.id != null && mergedSeen.add(p.id!)) allMerged.add(p);
        }
        for (final p in allMerged) { if (p.id != null) _tier2PostIds.add(p.id!); }
        printVm('⏱️ [PERF] merge: ${allMerged.length} posts uniques (T1+T2)');

        // ── Phase 1 : 2 posts → 1er affichage immédiat ──────────────────────
        if (allMerged.isNotEmpty && mounted) {
          _addFetchedToList(allMerged.take(2).toList(), loadedIds, newPosts, 2);
          setState(() {
            _posts = _buildTieredFeed(List.from(newPosts));
            _loadedPostIds.addAll(loadedIds);
            _totalPostsLoaded = newPosts.length;
            _isLoadingPosts = false;
            _isFirstLoad = false;
          });
          printVm('⏱️ [PERF] 1er affichage (${newPosts.length} posts): ${_sw.elapsedMilliseconds}ms');
          _logBadgeSummary();
        }

        // ── Phase 2 : 3 posts suivants → quasi-instantané (mémoire) ────────
        if (allMerged.length > 2 && mounted) {
          _addFetchedToList(allMerged.skip(2).take(3).toList(), loadedIds, newPosts, 3);
          setState(() {
            _posts = _buildTieredFeed(List.from(newPosts));
            _loadedPostIds.addAll(loadedIds);
            _totalPostsLoaded = newPosts.length;
          });
          printVm('⏱️ [PERF] 2ème affichage (${newPosts.length} posts): ${_sw.elapsedMilliseconds}ms');
        }

        // ── Phase 3 : tous les autres → quasi-instantané (mémoire) ─────────
        if (allMerged.length > 5) {
          _addFetchedToList(allMerged.skip(5).toList(), loadedIds, newPosts, allMerged.length);
          _loadedPostIds.addAll(loadedIds);
          printVm('⏱️ [PERF] phase3 (${newPosts.length} posts total): ${_sw.elapsedMilliseconds}ms');
        }
      }
      if (widget.sortType != 'recent') switch (_currentFilter) {
        case 'ALL':
          await _loadAllCountriesMixed(loadedIds, newPosts, limit);
          break;

        case 'COUNTRY':
          if (_selectedCountryCode != null) {
            await _loadCountrySpecificPosts(
              loadedIds,
              newPosts,
              _selectedCountryCode!,
              isInitialLoad: true,
              limit: limit,
            );

            // 🔥 Pour EVENEMENT: ne pas compléter avec d'autres posts
            if (widget.type != TabBarType.EVENEMENT.name) {
              // Compléter avec posts ALL si pas assez (comportement normal)
              if (newPosts.length < limit) {
                await _loadAllCountriesPosts(
                  loadedIds,
                  newPosts,
                  isInitialLoad: true,
                  limit: limit - newPosts.length,
                );
              }
            }
          }
          break;

        case 'MIXED':
          if (_selectedCountryCode != null) {
            await _loadMixedPostsSmart(loadedIds, newPosts, _selectedCountryCode!, limit);
          }
          break;

        case 'CUSTOM':
          if (_selectedCountryCode != null) {
            await _loadCountrySpecificPosts(
              loadedIds,
              newPosts,
              _selectedCountryCode!,
              isInitialLoad: true,
              limit: limit,
            );
          }
          break;
      }

      // En mode "Récent" : aucun algorithme, l'ordre created_at desc de Firestore est conservé tel quel.
      if (widget.sortType != 'recent') {
        // ── Injecter les posts non vus des following en tête de feed ────────────
        final preload = FeedPreloadService.instance;
        if (preload.isReady && preload.unseenFollowingPosts.isNotEmpty) {
          final preloadedIds = <String>{};
          for (final p in preload.unseenFollowingPosts) {
            if (p.id != null && !loadedIds.contains(p.id)) {
              preloadedIds.add(p.id!);
            }
          }
          final unseenToPin = preload.unseenFollowingPosts
              .where((p) => p.id != null && preloadedIds.contains(p.id))
              .toList();

          if (unseenToPin.isNotEmpty) {
            final regularPosts = newPosts
                .where((p) => p.id != null && !preloadedIds.contains(p.id))
                .toList();
            newPosts = [...unseenToPin, ...regularPosts];
            loadedIds.addAll(preloadedIds);
          }
        }

        // ── Pré-charger le boost découverte (injection dans _buildTieredFeed) ──
        _loadDiscoveryBoostInBackground();

        // ── Posts non vus en priorité (cursor de session) ──────────────────────
        {
          final prefs = await SharedPreferences.getInstance();
          final lastSessionMs = prefs.getInt(_kLastSessionTsKey) ?? 0;
          if (lastSessionMs > 0 && newPosts.isNotEmpty) {
            final unseen = newPosts.where((p) => p.isNewForUser(lastSessionMs)).toList();
            if (unseen.isNotEmpty && unseen.length < newPosts.length) {
              final seen = newPosts.where((p) => !p.isNewForUser(lastSessionMs)).toList();
              newPosts = [...unseen, ...seen];
            }
          }
          if (!_sessionTimestampSaved) {
            _sessionTimestampSaved = true;
            prefs.setInt(_kLastSessionTsKey, DateTime.now().millisecondsSinceEpoch);
          }
        }
      } else {
        // Mode récent : on sauvegarde quand même le timestamp de session
        final prefs = await SharedPreferences.getInstance();
        if (!_sessionTimestampSaved) {
          _sessionTimestampSaved = true;
          prefs.setInt(_kLastSessionTsKey, DateTime.now().millisecondsSinceEpoch);
        }
      }

      // Toujours remplacer par la liste finale Tier 1→2→3 ordonnée.
      // (Plus de cache post : pas de merge avec d'anciens posts persistés.)
      printVm('🏁 [FINAL] Avant setState final: newPosts=${newPosts.length}, seenT1=${_seenTier1PostIds.length}, tier2=${_tier2PostIds.length}, _isFirstLoad=$_isFirstLoad, filtre=$_currentFilter');
      printVm('⏱️ [PERF] avant setState final: ${_sw.elapsedMilliseconds}ms');
      setState(() {
        _posts = _buildTieredFeed(newPosts);
        _loadedPostIds.addAll(loadedIds);
        _totalPostsLoaded = _posts.length;
        _isFirstLoad = false;
      });
      _logBadgeSummary();
      printVm('✅ [FINAL] ${_posts.length} posts affichés, filtre=$_currentFilter');
      printVm('⏱️ [PERF] _loadInitialPosts terminé: ${_sw.elapsedMilliseconds}ms TOTAL');

    } catch (e) {
      printVm('❌ Erreur chargement posts: $e [${_sw.elapsedMilliseconds}ms]');
      setState(() {
        _hasErrorPosts = true;
      });
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }


  // ===========================================================================
  // ALGORITHMES DE CHARGEMENT SPÉCIFIQUES
  // ===========================================================================

  Future<void> _loadAllCountriesMixed(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    printVm('🌍 Chargement mode "Tous les pays" - limite: $limit');

    int attempts = 0;
    int maxAttempts = 3;

    while (newPosts.length < limit && attempts < maxAttempts) {
      // 1. Posts ALL (60%)
      if (newPosts.length < limit) {
        int needed = (limit * 0.6).ceil();
        await _loadAllCountriesPosts(
          loadedIds,
          newPosts,
          isInitialLoad: attempts == 0,
          limit: needed,
        );
      }

      // 2. Autres pays (40%)
      if (_selectedCountryCode != null && newPosts.length < limit) {
        int needed = limit - newPosts.length;
        await _loadOtherCountriesPosts(
          loadedIds,
          newPosts,
          excludeCountry: _selectedCountryCode!,
          isInitialLoad: attempts == 0,
          limit: needed,
        );
      }

      attempts++;
    }

  }

  // ── TIER 1 : posts non vus des abonnements ───────────────────────────────
  Future<void> _loadTier1Posts(
    Set<String> loadedIds,
    List<Post> newPosts,
    int limit,
  ) async {
    var unread = authProvider.loginUserData.unreadPosts ?? {};
    printVm('📌 [TIER1] unreadPosts dans loginUserData: ${unread.length} entrées');

    // Plafond de sécurité : si trop de posts non vus s'accumulent (ex. 1000+),
    // supprimer les plus anciens de Firestore pour éviter une liste infinie.
    const int _kMaxUnread = 200;
    if (unread.length > _kMaxUnread) {
      final sorted = unread.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final toKeep = sorted.take(_kMaxUnread).map((e) => e.key).toSet();
      final toDelete = unread.keys.where((id) => !toKeep.contains(id)).toList();
      printVm('📌 [TIER1] ⚠️ ${unread.length} posts non vus → plafond $_kMaxUnread dépassé, suppression de ${toDelete.length} anciens');
      // Nettoyer en mémoire immédiatement
      for (final id in toDelete) { unread.remove(id); }
      authProvider.loginUserData.unreadPosts = unread;
      // Supprimer de Firestore en arrière-plan (batches de 500)
      final userId = authProvider.loginUserData.id;
      if (userId != null) {
        for (int i = 0; i < toDelete.length; i += 500) {
          final batch = toDelete.sublist(i, min(i + 500, toDelete.length));
          final updates = <String, dynamic>{};
          for (final id in batch) { updates['unreadPosts.$id'] = FieldValue.delete(); }
          FirebaseFirestore.instance.collection('Users').doc(userId).update(updates).catchError((_) {});
        }
      }
    }

    if (unread.isEmpty) {
      printVm('📌 [TIER1] → toujours vide, aucun post Tier1 chargé');
      return;
    }
    try {
      final posts = await FeedRepository().fetchUnreadSubscriptionPosts(
        unread,
        {...loadedIds, ..._loadedPostIds},
        limit: limit,
      );
      printVm('📌 [TIER1] fetchUnreadSubscriptionPosts retourné: ${posts.length} posts (limit=$limit)');
      _addFetchedToList(posts, loadedIds, newPosts, limit);
      for (final p in posts) {
        if (p.id != null) _seenTier1PostIds.add(p.id!);
      }
      printVm('📌 [TIER1] _seenTier1PostIds: ${_seenTier1PostIds.length} IDs → ${_seenTier1PostIds.take(5).join(', ')}${_seenTier1PostIds.length > 5 ? '...' : ''}');
    } catch (e) {
      printVm('⚠️ [TIER1] erreur : $e');
    }
  }

  // ── TIER 2 : découverte par intérêts ─────────────────────────────────────
  Future<void> _loadTier2InterestPosts(
    Set<String> loadedIds,
    List<Post> newPosts,
    int limit,
  ) async {
    final userInterests = authProvider.loginUserData.interests ?? [];
    // Nouveau utilisateur sans intérêts configurés → intérêts par défaut (1 par catégorie)
    final interests = userInterests.isEmpty ? UserInterests.defaults : userInterests;
    final isDefault = userInterests.isEmpty;
    printVm('🎯 [TIER2] interests: ${interests.length} (défaut=$isDefault) → $interests');
    final countryCode = authProvider.loginUserData.countryData?['countryCode'] as String? ?? '';
    try {
      final posts = await FeedRepository().fetchInterestPosts(
        interests,
        {...loadedIds, ..._loadedPostIds},
        countryCode: countryCode,
        limit: limit,
      );
      printVm('🎯 [TIER2] fetchInterestPosts retourné: ${posts.length} posts (limit=$limit, pays=$countryCode)');
      _addFetchedToList(posts, loadedIds, newPosts, limit);
      for (final p in posts) {
        if (p.id != null) _tier2PostIds.add(p.id!);
      }
      printVm('🎯 [TIER2] _tier2PostIds: ${_tier2PostIds.length} IDs → ${_tier2PostIds.take(5).join(', ')}${_tier2PostIds.length > 5 ? '...' : ''}');
    } catch (e) {
      printVm('⚠️ Tier 2 erreur : $e');
    }
  }

  // Appelé au dispose : s'assure que les posts vus sont bien en SharedPreferences
  // (backup pour les cas où l'écriture Firestore en temps réel aurait échoué).
  void _markSeenPostsInFirestore() {
    final toFlush = {..._seenTier1PostIds, ..._viewedUnreadIds};
    if (toFlush.isEmpty) return;
    _persistSeenLocally(toFlush);
  }

  // ── Flush des posts vus + refresh Firestore avant tout rechargement ──────────
  // À appeler avant chaque rechargement (pull-to-refresh, load-more, etc.)
  // pour que unreadPosts soit propre et à jour avant de reconstruire le feed.
  Future<void> _flushAndRefreshUnread() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null || userId.isEmpty) return;

    // 1. Flush immédiat des posts vus en session (backup SharedPreferences → Firestore)
    //    Couvre les cas où l'écriture temps-réel de _markPostAsSeenNow a échoué.
    await flushSeenPostsAndCleanMemory(userId, authProvider.loginUserData);

    // 2. Relire unreadPosts depuis Firestore pour être à jour
    //    (nouveaux posts d'abonnements arrivés depuis la dernière lecture)
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      final fresh = ((userDoc.data()?['unreadPosts'] as Map<String, dynamic>?) ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt()));
      authProvider.loginUserData.unreadPosts = fresh;
      printVm('🔄 [UNREAD] unreadPosts mis à jour : ${fresh.length} posts non vus');
    } catch (e) {
      printVm('⚠️ [UNREAD] Impossible de rafraîchir unreadPosts : $e');
    }
  }

  // ── Un post est considéré "vu" après 1 seconde d'affichage continu ──────
  // Ajuster _kSeenDelayMs pour tester 500ms vs 1000ms.
  static const int _kSeenDelayMs = 700;

  final Map<String, Timer> _seenTimers = {};
  // Timestamps d'entrée dans le viewport (pour mesurer le temps réel de vue)
  final Map<String, int> _visibleSince = {};
  // IDs déjà en cours de flush pour éviter les doublons
  final _flushingIds = <String>{};

  void _onPostBecameVisible(String postId, double fraction) {
    // _seenTier1PostIds = badge display only. Ne PAS l'utiliser pour bloquer le marquage vu.
    // Seul _flushingIds empêche le double traitement.
    if (_flushingIds.contains(postId)) return;
    final inUnread = (authProvider.loginUserData.unreadPosts ?? {}).containsKey(postId);
    if (!inUnread) return;

    if (fraction >= 0.5) {
      // Enregistrer le moment d'entrée dans le viewport si pas déjà fait
      _visibleSince.putIfAbsent(postId, () => DateTime.now().millisecondsSinceEpoch);

      _seenTimers.putIfAbsent(postId, () => Timer(Duration(milliseconds: _kSeenDelayMs), () {
        _seenTimers.remove(postId);
        final enteredAt = _visibleSince.remove(postId);
        final elapsed = enteredAt != null
            ? DateTime.now().millisecondsSinceEpoch - enteredAt
            : _kSeenDelayMs;
        printVm('👁️ [VUE] post=${postId.substring(0, postId.length.clamp(0, 8))}... vu pendant ${elapsed}ms (seuil=${_kSeenDelayMs}ms, fraction=${fraction.toStringAsFixed(2)}) → marqué vu');
        _markPostAsSeenNow(postId);
      }));
    } else {
      // Post sorti du viewport avant le seuil → annuler
      final timer = _seenTimers.remove(postId);
      if (timer != null) {
        timer.cancel();
        final enteredAt = _visibleSince.remove(postId);
        final elapsed = enteredAt != null
            ? DateTime.now().millisecondsSinceEpoch - enteredAt
            : 0;
        printVm('👁️ [VUE] post=${postId.substring(0, postId.length.clamp(0, 8))}... quitté après ${elapsed}ms (fraction=${fraction.toStringAsFixed(2)}) → PAS marqué vu');
      }
    }
  }

  // Supprime immédiatement le post de unreadPosts en mémoire ET sur Firestore.
  // Fire-and-forget : l'UI ne bloque pas sur l'écriture réseau.
  void _markPostAsSeenNow(String postId) {
    if (_flushingIds.contains(postId)) return;
    _flushingIds.add(postId);
    _viewedUnreadIds.add(postId);

    // Retrait en mémoire immédiat → le prochain rechargement ne verra plus ce post en Tier 1
    authProvider.loginUserData.unreadPosts?.remove(postId);

    // Sauvegarde locale en backup (au cas où l'écriture réseau échoue)
    _persistSeenLocally({postId});

    // Écriture Firestore asynchrone (fire-and-forget)
    final userId = authProvider.loginUserData.id;
    if (userId != null && userId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .update({'unreadPosts.$postId': FieldValue.delete()})
          .catchError((e) {
            printVm('⚠️ [SEEN] Firestore delete échoué pour $postId : $e');
          });
    }
  }

  Future<void> _loadMixedPostsSmart(Set<String> loadedIds, List<Post> newPosts, String userCountryCode, int limit) async {
    printVm('🔄 Chargement mode "Mix intelligent" - limite: $limit');

    // 0. Garantir ≥10 posts récents des abonnements (7 derniers jours)
    //    Fallback indépendant du FeedPreloadService (qui peut ne pas être prêt)
    if (_followingIds.isNotEmpty) {
      final followingPosts = await FeedRepository().fetchFollowingRecentPosts(
        _followingIds,
        {...loadedIds, ..._loadedPostIds},
        limit: 10,
        withinDays: 7,
      );
      _addFetchedToList(followingPosts, loadedIds, newPosts, 10);
      printVm('📌 ${followingPosts.length} posts abonnements récents chargés');
    }

    // 0b. Injecter jusqu'à 5 nouveaux posts (< 48h, peu vus) pour les encourager
    final boostPosts = await FeedRepository().fetchNewPostsToBoost(
      {...loadedIds, ..._loadedPostIds},
      limit: 5,
    );
    if (boostPosts.isNotEmpty) {
      _addFetchedToList(boostPosts, loadedIds, newPosts, 5);
      printVm('🚀 ${boostPosts.length} nouveaux posts boostés injectés');
    }

    // 1. Posts du pays utilisateur (40% du limit restant)
    int countryPostsNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      userCountryCode,
      isInitialLoad: true,
      limit: countryPostsNeeded,
    );

    // 2. Posts autres pays (complète jusqu'à limit)
    int otherPostsNeeded = limit - newPosts.length;
    if (otherPostsNeeded > 0) {
      await _loadOtherCountriesPosts(
        loadedIds,
        newPosts,
        excludeCountry: userCountryCode,
        isInitialLoad: true,
        limit: otherPostsNeeded,
      );
    }
  }

  Future<void> _loadCountrySpecificPosts(
      Set<String> loadedIds,
      List<Post> newPosts,
      String countryCode, {
        bool isInitialLoad = false,
        int limit = 5,
      }) async {
    if (limit <= 0) return;

    // EVENEMENT : tri spécial par eventDate — query directe conservée
    if (widget.type == TabBarType.EVENEMENT.name) {
      await _loadEventsByDate(loadedIds, newPosts, countryCode, limit: limit);
      return;
    }

    try {
      final excluded = {...loadedIds, ..._loadedPostIds};
      final posts = await FeedRepository().fetchCountryPosts(
        countryCode,
        excluded,
        limit: limit,
        mediaType: widget.isVideoPage ? PostDataType.VIDEO.name : null,
        tabbarType: widget.type.isNotEmpty ? widget.type : null,
      );
      _addFetchedToList(posts, loadedIds, newPosts, limit);
    } catch (e) {
      printVm('❌ Erreur chargement pays $countryCode: $e');
    }
  }

  /// Query directe Firestore pour les événements (tri par eventDate requis).
  Future<void> _loadEventsByDate(
      Set<String> loadedIds,
      List<Post> newPosts,
      String countryCode, {
        int limit = 5,
      }) async {
    try {
      Query query = _firestore
          .collection('Posts')
          .where("typeTabbar", isEqualTo: "EVENEMENT")
          .orderBy("eventDate", descending: false);
      if (countryCode.isNotEmpty) {
        query = query.where("available_countries", arrayContains: countryCode);
      }
      query = query.limit((limit * 1.5).ceil());
      final snapshot = await query.get();
      final tempEvents = <Post>[];
      for (final doc in snapshot.docs) {
        if (tempEvents.length >= limit) break;
        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;
          if (post.isAdvertisement == true) continue;
          if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) continue;
          post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
          loadedIds.add(post.id!);
          tempEvents.add(post);
        } catch (_) {}
      }
      tempEvents.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
      newPosts.addAll(tempEvents);
    } catch (e) {
      printVm('❌ Erreur chargement événements: $e');
    }
  }

  /// Ajoute les posts récupérés à [newPosts] avec dédup et mélange final.
  /// Répartit les posts pour qu'un même créateur n'apparaisse jamais
  /// deux fois dans moins de 3 posts d'écart (gap minimum = 3).
  /// Préserve la priorité Tier 1 → Tier 2 → Tier 3 en prenant toujours
  /// le premier post en attente dont le créateur respecte le gap.
  List<Post> _spreadCreators(List<Post> posts) {
    if (posts.length <= 3) return posts;
    const int minGap = 3;
    final result = <Post>[];
    final pending = List<Post>.from(posts);
    final lastSeen = <String, int>{}; // creatorId → dernier index dans result

    while (pending.isNotEmpty) {
      final currentPos = result.length;
      bool placed = false;
      for (int i = 0; i < pending.length; i++) {
        final creatorId = pending[i].user_id ?? '';
        final last = lastSeen[creatorId];
        if (last == null || currentPos - last > minGap) {
          result.add(pending.removeAt(i));
          if (creatorId.isNotEmpty) lastSeen[creatorId] = currentPos;
          placed = true;
          break;
        }
      }
      // Si aucun post ne respecte le gap, on place le premier en attente (force)
      if (!placed) {
        final post = pending.removeAt(0);
        result.add(post);
        final creatorId = post.user_id ?? '';
        if (creatorId.isNotEmpty) lastSeen[creatorId] = currentPos;
      }
    }
    return result;
  }

  /// Spread des créateurs dans [newPosts] en respectant le gap par rapport à la
  /// fin de [existingPosts] déjà affichés (évite les rafales lors de la pagination).
  List<Post> _spreadCreatorsWithContext(List<Post> newPosts, List<Post> existingPosts) {
    if (newPosts.isEmpty) return newPosts;
    const int minGap = 3;
    final result = <Post>[];
    final pending = List<Post>.from(newPosts);

    // Initialiser lastSeen depuis les derniers minGap posts déjà à l'écran
    final lastSeen = <String, int>{};
    final tail = existingPosts.length > minGap
        ? existingPosts.sublist(existingPosts.length - minGap)
        : existingPosts;
    for (int i = 0; i < tail.length; i++) {
      final creatorId = tail[i].user_id ?? '';
      if (creatorId.isNotEmpty) {
        // Positions négatives = avant result[0]
        lastSeen[creatorId] = -(tail.length - i);
      }
    }

    while (pending.isNotEmpty) {
      final currentPos = result.length;
      bool placed = false;
      for (int i = 0; i < pending.length; i++) {
        final creatorId = pending[i].user_id ?? '';
        final last = lastSeen[creatorId];
        if (last == null || currentPos - last > minGap) {
          result.add(pending.removeAt(i));
          if (creatorId.isNotEmpty) lastSeen[creatorId] = currentPos;
          placed = true;
          break;
        }
      }
      if (!placed) {
        final post = pending.removeAt(0);
        result.add(post);
        final creatorId = post.user_id ?? '';
        if (creatorId.isNotEmpty) lastSeen[creatorId] = result.length - 1;
      }
    }
    return result;
  }

  /// Répartit les posts en maintenant l'ordre Tier 1 → Tier 2 → Tier 3.
  /// Spread créateurs appliqué en tenant compte des frontières inter-tiers
  /// (jamais 3 posts consécutifs du même créateur/canal).
  /// Injecte 3 posts découverte toutes les 10 posts T1.
  List<Post> _buildTieredFeed(List<Post> posts) {
    final t1 = <Post>[];
    final t2 = <Post>[];
    final t3 = <Post>[];
    for (final p in posts) {
      final pid = p.id;
      if (pid == null) { t3.add(p); continue; }
      if (_seenTier1PostIds.contains(pid)) { t1.add(p); continue; }
      if (_tier2PostIds.contains(pid)) { t2.add(p); continue; }
      t3.add(p);
    }

    // Spread par tier avec contexte cross-tier pour éviter 3+ consécutifs
    final s1 = _spreadCreators(t1);
    final s2 = _spreadCreatorsWithContext(t2, s1);
    final s3 = _spreadCreatorsWithContext(t3, [...s1, ...s2]);
    final ordered = [...s1, ...s2, ...s3];

    printVm('🏗️ [FEED] _buildTieredFeed → T1=${t1.length} | T2=${t2.length} | T3=${t3.length} | total=${ordered.length}');

    // ── Injection découverte : 3 posts toutes les 10 posts T1 ───────────────
    final me = authProvider.loginUserData;
    final followedSet = _followingIds.isNotEmpty
        ? Set<String>.from(_followingIds)
        : Set<String>.from(me.followingIds ?? []);
    followedSet.add(me.id ?? '');

    final alreadyInjected = DiscoveryBoostService.instance.discoveryPostIds;
    final boostPool = DiscoveryBoostService.instance.getBoostPosts(
      followedSet: followedSet,
      currentUserId: me.id ?? '',
      userCountry: me.countryData?['countryCode']?.toString().toUpperCase(),
    ).where((p) => p.id != null
        && !_loadedPostIds.contains(p.id)
        && !alreadyInjected.contains(p.id)).toList();

    final regularPool = _regularDiscoveryPool
        .where((p) => p.id != null
            && !_loadedPostIds.contains(p.id)
            && !_localDiscoveryIds.contains(p.id))
        .toList();

    if (boostPool.isEmpty && regularPool.isEmpty) return ordered;
    return _injectDiscoveryPosts(ordered, boostPool, regularPool,
        leadWithDiscovery: _leadDiscoveryWithT1);
  }

  /// Injecte 3 posts découverte toutes les 10 posts T1.
  /// Chaque batch = [1 boost (nouveau créateur) + 2 réguliers (créateur non suivi)].
  /// Si [leadWithDiscovery], ajoute le premier batch avant tous les posts T1.
  List<Post> _injectDiscoveryPosts(
    List<Post> ordered,
    List<Post> boostPool,
    List<Post> regularPool, {
    required bool leadWithDiscovery,
  }) {
    // Construire les batches : toujours [1 boost (nouveau créateur) + 2 réguliers]
    // Un batch incomplet (< 3 posts) n'est pas créé pour éviter les déséquilibres.
    final batches = <List<Post>>[];
    int bi = 0, ri = 0;
    while (bi < boostPool.length && ri + 1 < regularPool.length) {
      final batch = <Post>[
        boostPool[bi++],       // slot 0 : nouveau créateur
        regularPool[ri++],     // slot 1 : découverte régulière
        regularPool[ri++],     // slot 2 : découverte régulière
      ];
      batches.add(batch);
    }
    if (batches.isEmpty) return ordered;

    final result = <Post>[];
    int batchIdx = 0;
    int postCount = 0;
    // Si pas de T1, compter tous les posts (T2+T3) pour déclencher l'injection
    final bool noT1 = _seenTier1PostIds.isEmpty;

    // Optionnellement : commencer par le premier batch avant les posts
    if (leadWithDiscovery && batchIdx < batches.length) {
      _registerBatch(batches[batchIdx]);
      result.addAll(batches[batchIdx++]);
    }

    for (final post in ordered) {
      result.add(post);
      final pid = post.id;
      if (pid != null) {
        final isT1 = _seenTier1PostIds.contains(pid);
        if (isT1 || noT1) {
          postCount++;
          if (postCount % 10 == 0 && batchIdx < batches.length) {
            _registerBatch(batches[batchIdx]);
            result.addAll(batches[batchIdx++]);
          }
        }
      }
    }

    printVm('🔍 [DISCOVERY] injecté ${batchIdx} batch(es) de 3 posts (comptés=$postCount noT1=$noT1 lead=$leadWithDiscovery)');
    return result;
  }

  void _registerBatch(List<Post> batch) {
    for (int i = 0; i < batch.length; i++) {
      final id = batch[i].id;
      if (id == null) continue;
      if (i == 0) {
        DiscoveryBoostService.instance.addDiscoveryIds([id]); // badge "Nouveau créateur"
      } else {
        _localDiscoveryIds.add(id); // badge "Découverte · Créateur"
      }
    }
  }

  void _logBadgeSummary() {
    if (_posts.isEmpty) {
      printVm('🏷️ [BADGES] _posts vide — aucun badge à afficher');
      return;
    }
    final lines = <String>[];
    for (int i = 0; i < _posts.length && i < 15; i++) {
      final p = _posts[i];
      final pid = p.id ?? 'null';
      final isTier1 = pid != 'null' && _seenTier1PostIds.contains(pid);
      final isTier2 = pid != 'null' && _tier2PostIds.contains(pid) && !isTier1;
      final isTier3 = !_isFirstLoad && pid != 'null' && !isTier1 && !isTier2;
      final badge = isTier1 ? 'NOUVEAU' : isTier2 ? 'DECOUVERTE' : isTier3 ? 'TENDANCE' : 'AUCUN(_isFirstLoad=$_isFirstLoad)';
      lines.add('  [$i] ${pid.substring(0, pid.length.clamp(0, 8))}... → $badge');
    }
    printVm('🏷️ [BADGES] Résumé des ${_posts.length.clamp(0, 15)} premiers posts:\n${lines.join('\n')}');
  }

  void _addFetchedToList(
      List<Post> fetched, Set<String> loadedIds, List<Post> newPosts, int limit) {
    int added = 0;
    for (final post in fetched) {
      if (added >= limit) break;
      if (post.id == null) continue;
      if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) continue;
      if (post.isAdvertisement == true) continue;
      post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
      loadedIds.add(post.id!);
      newPosts.add(post);
      added++;
    }
    // Pas de shuffle global : l'ordre Tier 1 → Tier 2 → Tier 3 est préservé.
    // _spreadCreators() s'occupe de varier les créateurs dans la liste finale.
  }
  Future<void> _loadAllCountriesPosts(
      Set<String> loadedIds,
      List<Post> newPosts, {
        bool isInitialLoad = false,
        int limit = 5,
      }) async {
    if (limit <= 0) return;
    try {
      final excluded = {...loadedIds, ..._loadedPostIds};
      final posts = await FeedRepository().fetchRecentPosts(
        excluded,
        limit: limit,
        mediaType: widget.isVideoPage ? PostDataType.VIDEO.name : null,
        tabbarType: widget.type.isNotEmpty ? widget.type : null,
      );
      _addFetchedToList(posts, loadedIds, newPosts, limit);
    } catch (e) {
      printVm('❌ Erreur chargement posts ALL: $e');
    }
  }
  Future<void> _loadOtherCountriesPosts(
      Set<String> loadedIds,
      List<Post> newPosts, {
        required String excludeCountry,
        bool isInitialLoad = false,
        int limit = 5,
      }) async {
    if (limit <= 0) return;
    try {
      final excluded = {...loadedIds, ..._loadedPostIds};
      final posts = await FeedRepository().fetchOtherCountriesPosts(
        excludeCountry,
        excluded,
        limit: limit,
        mediaType: widget.isVideoPage ? PostDataType.VIDEO.name : null,
        tabbarType: widget.type.isNotEmpty ? widget.type : null,
      );
      _addFetchedToList(posts, loadedIds, newPosts, limit);
    } catch (e) {
      printVm('❌ Erreur chargement autres pays: $e');
    }
  }

  // ===========================================================================
  // PAGINATION - CHARGEMENT MANUEL (Après les 20 posts background)
  // ===========================================================================

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    // Marquer le scroll comme actif + reset du cooldown
    _isScrollActive = true;
    _scrollCooldownTimer?.cancel();
    _scrollCooldownTimer = Timer(const Duration(milliseconds: 300), () {
      _isScrollActive = false;
    });

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 1500 &&
        !_isLoadingMorePosts &&
        !_isLoadingBackground &&
        _hasMorePosts &&
        _totalPostsLoaded < _maxTotalPosts) {
      _loadMorePostsManually();
    }
  }

  Future<void> _loadMorePostsManually() async {
    if (_isLoadingMorePosts || _isLoadingBackground || !_hasMorePosts || _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    // Lever le flag AVANT tout await pour bloquer les appels concurrents du scroll listener
    _isLoadingMorePosts = true;
    if (mounted) setState(() {});

    // Flush les posts déjà vus + relit unreadPosts avant de charger la suite
    await _flushAndRefreshUnread();

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _manualLoadLimit);

      // Ajouter les nouveaux posts (spread pour éviter les rafales)
      if (newPosts.isNotEmpty) {
        final spread = _spreadCreatorsWithContext(newPosts, _posts);
        setState(() {
          _posts.addAll(spread);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += spread.length;
        });

        printVm('📱 ${spread.length} posts chargés manuellement (total: $_totalPostsLoaded)');
      }

      _hasMorePosts = newPosts.length >= (_manualLoadLimit ~/ 2);

    } catch (e) {
      printVm('❌ Erreur chargement manuel: $e');
      _hasMorePosts = false;
    } finally {
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  /// Chargement initial pour le mode "Récent" — query directe Firestore avec DocumentSnapshot curseur.
  Future<void> _loadInitialRecentPosts(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    try {
      final snap = await _firestore
          .collection('Posts')
          .orderBy('created_at', descending: true)
          .limit(limit * 4)
          .get();

      for (final doc in snap.docs) {
        try {
          final post = Post.fromJson(doc.data());
          post.id = doc.id;
          if (post.id == null || post.isAdvertisement == true) continue;
          if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) continue;
          post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
          loadedIds.add(post.id!);
          newPosts.add(post);
        } catch (_) {}
      }

      // Tri client-side par createdAt normalisé (ms) pour corriger le mélange µs/ms en base
      newPosts.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      if (newPosts.length > limit) newPosts.removeRange(limit, newPosts.length);

      // Sauvegarder le dernier doc Firestore comme curseur (unit-agnostic)
      if (snap.docs.isNotEmpty) _recentLastDoc = snap.docs.last;
    } catch (e) {
      printVm('❌ Erreur chargement initial récent: $e');
    }
  }

  /// Pagination curseur pour le mode "Récent" — startAfterDocument (unit-agnostic).
  Future<void> _loadMoreRecentCursor(List<Post> newPosts, int limit) async {
    if (_recentLastDoc == null) return;
    try {
      final snap = await _firestore
          .collection('Posts')
          .orderBy('created_at', descending: true)
          .startAfterDocument(_recentLastDoc!)
          .limit(limit * 3)
          .get();

      for (final doc in snap.docs) {
        try {
          final post = Post.fromJson(doc.data());
          post.id = doc.id;
          if (post.id == null || _loadedPostIds.contains(post.id) || post.isAdvertisement == true) continue;
          post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
          newPosts.add(post);
        } catch (_) {}
        _recentLastDoc = doc; // avancer le curseur sur chaque doc traité
        if (newPosts.length >= limit) break;
      }

      // Tri client-side pour corriger le mélange µs/ms restant en base
      newPosts.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    } catch (e) {
      printVm('❌ Erreur pagination récente (curseur): $e');
    }
  }

  Future<void> _loadMorePostsByFilter(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    // Mode récent : pagination curseur strictement chronologique
    if (widget.sortType == 'recent') {
      await _loadMoreRecentCursor(newPosts, limit);
      return;
    }

    switch (_currentFilter) {
      case 'ALL':
        await _loadMoreAllCountriesMixed(loadedIds, newPosts, limit);
        break;

      case 'COUNTRY':
        if (_selectedCountryCode != null) {
          await _loadMoreCountrySpecific(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;

      case 'MIXED':
        if (_selectedCountryCode != null) {
          await _loadMoreMixed(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;

      case 'CUSTOM':
        if (_selectedCountryCode != null) {
          await _loadMoreCountrySpecific(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;
    }
  }

  Future<int> _loadMoreAllCountriesMixed(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    int added = 0;
    int attempts = 0;

    while (added < limit && attempts < 2) {
      int needed = limit - added;
      await _loadAllCountriesPosts(
        loadedIds,
        newPosts,
        isInitialLoad: false,
        limit: needed,
      );

      if (_selectedCountryCode != null && added < limit) {
        needed = limit - added;
        await _loadOtherCountriesPosts(
          loadedIds,
          newPosts,
          excludeCountry: _selectedCountryCode!,
          isInitialLoad: false,
          limit: needed,
        );
      }

      added = newPosts.length;
      attempts++;
    }

    return added;
  }

  Future<int> _loadMoreCountrySpecific(Set<String> loadedIds, List<Post> newPosts, String countryCode, int limit) async {
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      countryCode,
      isInitialLoad: false,
      limit: limit,
    );

    int added = newPosts.length;

    if (added < limit) {
      int needed = limit - added;
      await _loadAllCountriesPosts(
        loadedIds,
        newPosts,
        isInitialLoad: false,
        limit: needed,
      );
      added = newPosts.length;
    }

    return added;
  }

  Future<int> _loadMoreMixed(Set<String> loadedIds, List<Post> newPosts, String countryCode, int limit) async {
    int countryNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      countryCode,
      isInitialLoad: false,
      limit: countryNeeded,
    );

    int allNeeded = (limit * 0.4).ceil();
    await _loadAllCountriesPosts(
      loadedIds,
      newPosts,
      isInitialLoad: false,
      limit: allNeeded,
    );

    int otherNeeded = limit - newPosts.length;
    if (otherNeeded > 0) {
      await _loadOtherCountriesPosts(
        loadedIds,
        newPosts,
        excludeCountry: countryCode,
        isInitialLoad: false,
        limit: otherNeeded,
      );
    }

    return newPosts.length;
  }

  // ===========================================================================
  // PRÉ-CHARGEMENT DES POSTS NON VUS (STARTUP)
  // ===========================================================================

  /// Lance le préchargement des posts non vus en arrière-plan.
  /// Résultat disponible via FeedPreloadService.instance.unseenFollowingPosts.
  void _startFeedPreload() {
    final me = authProvider.loginUserData;
    if (me.id == null) return;
    // Fire-and-forget : ne bloque pas l'initialisation
    FeedPreloadService.instance.preload(
      me,
      canalIds: _followedCanalIds,
      followingIds: _followingIds,
    );
  }

  Future<void> _loadDiscoveryBoostInBackground() async {
    final me = authProvider.loginUserData;
    if (me.id == null) return;
    final followedSet = _followingIds.isNotEmpty
        ? Set<String>.from(_followingIds)
        : Set<String>.from(me.followingIds ?? []);
    followedSet.add(me.id!);
    final userCountry = me.countryData?['countryCode']?.toString().toUpperCase();
    await DiscoveryBoostService.instance.preload(
      followedSet: followedSet,
      currentUserId: me.id!,
      userCountry: userCountry,
    );
  }

  Future<void> _loadRegularDiscoveryPool() async {
    final me = authProvider.loginUserData;
    if (me.id == null) return;
    final followedSet = _followingIds.isNotEmpty
        ? Set<String>.from(_followingIds)
        : Set<String>.from(me.followingIds ?? []);
    followedSet.add(me.id!);
    final userCountry = me.countryData?['countryCode']?.toString().toUpperCase();
    final pool = await DiscoveryBoostService.instance.fetchRegularDiscovery(
      followedSet: followedSet,
      currentUserId: me.id!,
      userCountry: userCountry,
    );
    if (!mounted) return;
    setState(() {
      _regularDiscoveryPool = pool;
    });
  }

  // ===========================================================================
  // CHARGEMENT DES DONNÉES SUPPLÉMENTAIRES (SÉPARÉ)
  // ===========================================================================

  Future<void> _loadAllAdditionalDataInParallel() async {
    // Charger tout en parallèle sans bloquer
    _loadSuggestedUsersInBackground();
    _loadFollowedCanalIdsInBackground();
    _loadArticlesInBackground();
    _loadCanauxInBackground();
    _loadChroniquesInBackground();
    _loadDiscoveryBoostInBackground();
    _loadRegularDiscoveryPool();
  }

  Future<void> _loadFollowedCanalIdsInBackground() async {
    final me = authProvider.loginUserData;
    final userId = me.id ?? '';
    if (userId.isEmpty) return;
    try {
      // Si followingIds est déjà dans le modèle (chargé depuis Firestore) → l'utiliser
      // Sinon : migration one-time depuis la collection Abonnements
      List<String> followingIds = me.followingIds ?? [];

      final results = await Future.wait([
        _activeCreatorsService.fetchFollowedCanalIds(userId),
        // Migration : seulement si followingIds vide dans le document utilisateur
        if (followingIds.isEmpty)
          _activeCreatorsService.fetchFollowingIds(userId)
        else
          Future.value(<String>[]),
      ]);
      final canalIds = results[0];
      final migratedIds = results[1];

      // Migration : sauvegarder en Firestore pour ne plus faire cette requête
      if (followingIds.isEmpty && migratedIds.isNotEmpty) {
        followingIds = migratedIds;
        me.followingIds = followingIds;
        FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .update({'followingIds': followingIds}).catchError((_) {});
      }

      if (!mounted) return;
      setState(() {
        if (canalIds.isNotEmpty) _followedCanalIds = canalIds;
        if (followingIds.isNotEmpty) _followingIds = followingIds;
      });
      // Relancer le preload maintenant qu'on a les vrais following IDs
      if (followingIds.isNotEmpty) _startFeedPreload();
      final ids = _followedCanalIds;
      if (ids.isEmpty) return;

      // Essayer d'abord les canaux avec des posts récents (30j)
      var canaux = await _activeCreatorsService
          .fetchFollowedRecentCanaux(ids, limit: 5);

      // Fallback : si aucun canal actif récemment, charger les canaux directement
      // (l'utilisateur les a suivis → ils doivent s'afficher quoi qu'il arrive)
      if (canaux.isEmpty) {
        canaux = await _activeCreatorsService
            .fetchFollowedCanauxDirect(ids, limit: 5);
      }

      if (mounted && canaux.isNotEmpty) {
        setState(() => _recentCanaux = canaux);
        // Relancer le preload maintenant qu'on a les IDs de canaux
        _startFeedPreload();
      }
    } catch (_) {}
  }

  Future<void> _loadSuggestedUsersInBackground() async {
    if (_hasStartedLoadSuggestedUsers) return;
    _hasStartedLoadSuggestedUsers = true;
    if (mounted && _suggestedUsers.isEmpty) {
      setState(() => _isLoadingSuggestedUsers = true);
    }

    try {
      final me = authProvider.loginUserData;
      final userId = me.id ?? '';

      // Fetch newPostsByCreator frais depuis Firestore pour éviter les valeurs
      // stale du cache local (le listener auth peut ne pas avoir encore reçu la
      // réponse serveur quand ce code s'exécute).
      Map<String, int>? freshCounts;
      if (userId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(userId)
              .get();
          final raw = doc.data()?['newPostsByCreator'] as Map<String, dynamic>? ?? {};
          freshCounts = Map<String, int>.fromEntries(
            raw.entries
                .where((e) => (e.value as num? ?? 0).toInt() > 0)
                .map((e) => MapEntry(e.key, (e.value as num).toInt())),
          );
          // Mise à jour immédiate des badges avant que resolve() finisse
          if (mounted && freshCounts.isNotEmpty) {
            setState(() => _unseenCounts = Map.from(freshCounts!));
          }
        } catch (_) {}
      }

      // limit=20 : affiche jusqu'à 20 créateurs, dont TOUS ceux avec posts non vus
      final creators = await _activeCreatorsService.resolve(
        me,
        limit: 20,
        followingIds: _followingIds.isNotEmpty ? _followingIds : null,
        freshCounts: freshCounts,
      );

      // Recalibration de TOUS les créateurs affichés contre viewedPostIds
      // (source de vérité = posts Firestore réels, pas le compteur CF)
      final allCreatorIds = creators
          .where((c) => c.user.id != null)
          .map((c) => c.user.id!)
          .toList();

      Map<String, int> calibratedCounts = {};

      if (allCreatorIds.isNotEmpty) {
        final viewedSet = Set<String>.from(me.viewedPostIds ?? []);
        calibratedCounts = await _activeCreatorsService.recalibrateUnseenCounts(
          creatorIds: allCreatorIds,
          viewedPostIds: viewedSet,
          userCreatedAtMs: me.createdAt ?? 0,
        );
        // Resync newPostsByCreator dans Firestore pour aligner CF et réalité
        _syncNewPostsByCreatorToFirestore(userId, allCreatorIds, calibratedCounts);
      }

      // Si aucun post non vu, mélanger pour varier l'ordre à chaque chargement
      final hasUnseen = calibratedCounts.values.any((c) => c > 0);
      final ordered = hasUnseen ? creators : (List.of(creators)..shuffle());

      if (!mounted) return;
      setState(() {
        _activeCreators = ordered;
        _suggestedUsers = ordered.map((c) => c.user).toList();
        _unseenCounts = calibratedCounts;
        _creatorLastActivityUs = {
          for (final c in ordered)
            if (c.user.id != null) c.user.id!: c.lastActivityUs,
        };
      });

      _saveFeedToCache();
    } catch (e) {
      printVm('Error loading active creators: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSuggestedUsers = false);
    }
  }

  Future<void> _loadArticlesInBackground() async {
    if (_hasStartedLoadArticles) return;
    _hasStartedLoadArticles = true;
    if (mounted && _articles.isEmpty) setState(() => _isLoadingArticles = true);

    try {
      final articleResults = await categorieProduitProvider.getArticleBooster(
          _selectedCountryCode?.toUpperCase() ?? 'TG'
      );

      setState(() {
        _articles = articleResults;
      });
      _saveFeedToCache();
    } catch (e) {
      printVm('Error loading articles: $e');
    } finally {
      setState(() {
        _isLoadingArticles = false;
      });
    }
  }

  Future<void> _loadCanauxInBackground() async {
    if (_hasStartedLoadCanaux) return;
    _hasStartedLoadCanaux = true;
    if (mounted && _canaux.isEmpty) setState(() => _isLoadingCanaux = true);

    try {
      final canalResults = await postProvider.getCanauxHome();

      setState(() {
        _canaux = canalResults..shuffle();
      });
      _saveFeedToCache();
    } catch (e) {
      printVm('Error loading canaux: $e');
    } finally {
      setState(() {
        _isLoadingCanaux = false;
      });
    }
  }

  Future<void> _loadChroniquesInBackground() async {
    if (_hasStartedLoadChroniques) return;
    _hasStartedLoadChroniques = true;
    if (mounted && _chroniques.isEmpty) setState(() => _isLoadingChroniques = true);
    try {
      // Timeout 15s — si dépassé on garde le cache (pas d'écrasement par [])
      List<Chronique>? validChroniques;
      try {
        validChroniques = await FeedRepository()
            .fetchChroniques(limit: 6)
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        printVm('⏱ fetchChroniques timeout – cache conservé');
      }
      if (!mounted) return;
      if (validChroniques != null) {
        // Résultat réel reçu : mettre à jour (même si vide = toutes expirées)
        setState(() => _chroniques = validChroniques!);
        if (validChroniques.isNotEmpty) {
          await _loadChroniqueUserDataInBackground(validChroniques);
        }
        _saveFeedToCache();
      }
      // Si null (timeout) : on garde _chroniques tel quel
    } catch (e) {
      printVm('❌ Erreur chargement chroniques: $e');
    } finally {
      if (mounted) setState(() => _isLoadingChroniques = false);
    }
  }

  Future<void> _loadChroniqueUserDataInBackground(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques
          .map((c) => c.userId)
          .toSet()
          .where((id) => !_userDataCache.containsKey(id))
          .toList();

      if (userIds.isEmpty) return;

      // Firestore whereIn supporte au maximum 30 ids par requête -> on chunk
      const chunkSize = 30;
      for (var i = 0; i < userIds.length; i += chunkSize) {
        final chunk = userIds.sublist(
          i,
          (i + chunkSize > userIds.length) ? userIds.length : i + chunkSize,
        );

        final snapshot = await _firestore
            .collection('Users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snapshot.docs) {
          final userData = UserData.fromJson(doc.data());
          _userDataCache[doc.id] = userData;
          _userVerificationStatus[doc.id] = userData.isVerify ?? false;
        }
      }

      // Mettre à jour l'UI si nécessaire
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      printVm('❌ Erreur chargement données chroniques: $e');
    }
  }

  // ===========================================================================
  // WIDGETS PRINCIPAUX
  // ===========================================================================

// Clé pour stocker dans SharedPreferences

// Fonction pour vérifier et rediriger
  Future<void> checkAndRedirectToVideoPage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeen = prefs.getBool(HAS_SEEN_VIDEO_PAGE_KEY) ?? false;

    if (!hasSeen) {
      // Marquer comme vu immédiatement
      await prefs.setBool(HAS_SEEN_VIDEO_PAGE_KEY, true);

      // Rediriger vers la page des vidéos
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomeConstPostPage(isVideoPage: true, type: '',)),
      );
    }
  }

  Widget _buildShimmerPost() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[850]!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        height: 280,
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Construit un slot de découverte : affiche le widget pool [name] s'il a du
  /// contenu, sinon bascule sur [FeedUnifiedAdSlot] (pub) en fallback.
  /// Articles et Canaux : vérification synchrone via l'état local.
  /// Autres widgets async : vérification post-frame via FeedPoolOrAd.
  Widget _buildPoolOrAd(String name, String adKey) {
    switch (name) {
      case 'Articles':
        if (_articles.isEmpty) return _buildUnifiedAdSlot(key: adKey);
        return FeedPoolOrAd(
          key: ValueKey('pool_$adKey'),
          adKey: adKey,
          poolChild: _buildArticlesSection(),
        );
      case 'Canaux':
        if (_canaux.isEmpty) return _buildUnifiedAdSlot(key: adKey);
        return FeedPoolOrAd(
          key: ValueKey('pool_$adKey'),
          adKey: adKey,
          poolChild: _buildCanauxSection(),
        );
      case 'WeeklyTopCreators':
        return FeedPoolOrAd(
          key: ValueKey('pool_$adKey'),
          adKey: adKey,
          poolChild: const WeeklyTopCreatorsWidget(),
        );
      case 'BoostedContent':
        return FeedPoolOrAd(
          key: ValueKey('pool_$adKey'),
          adKey: adKey,
          poolChild: const BoostedContentStripWidget(),
        );
      case 'VIPContent':
        return FeedPoolOrAd(
          key: ValueKey('pool_$adKey'),
          adKey: adKey,
          poolChild: const RecentVIPContentWidget(),
        );
      default:
        return _buildUnifiedAdSlot(key: adKey);
    }
  }

  Widget _buildUnifiedAdSlot({required String key}) =>
      FeedUnifiedAdSlot(adKey: key);

  Widget _buildPostWidget(Post post, double width, double height, int index) {
    final pid = post.id;
    final isDiscovery = pid != null &&
        DiscoveryBoostService.instance.discoveryPostIds.contains(pid);
    final isLocalDiscovery = pid != null && !isDiscovery && _localDiscoveryIds.contains(pid);
    final isTier1 = pid != null && _seenTier1PostIds.contains(pid);
    final isTier2 = pid != null && _tier2PostIds.contains(pid) && !isTier1;
    // Tendance uniquement affiché après la fin du chargement initial.
    // Pendant _isFirstLoad le tier est inconnu → on n'affiche rien.
    final isTier3 = !_isFirstLoad && pid != null && !isTier1 && !isTier2 && !isDiscovery && !isLocalDiscovery;

    if (index < 5) {
      final badge = isTier1 ? 'NOUVEAU' : isTier2 ? 'DECOUVERTE' : isTier3 ? 'TENDANCE' : 'AUCUN(_isFirstLoad=$_isFirstLoad)';
      printVm('🏷️ [POST $index] pid=${pid?.substring(0, pid.length.clamp(0, 8))}... badge=$badge (T1=${_seenTier1PostIds.contains(pid)} T2=${_tier2PostIds.contains(pid)})');
    }

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Badges Tier ──────────────────────────────────────────────────────
          if (isTier1)
            _FeedTierBadge(label: 'Nouveau · Abonnement', color: const Color(0xFF25D366))
          else if (isTier2)
            _FeedTierBadge(label: 'Découverte · Intérêts', color: const Color(0xFF6C63FF))
          else if (isDiscovery)
            _NewCreatorBadge(postId: pid!, userId: post.user_id ?? '')
          else if (isLocalDiscovery)
            _FeedTierBadge(label: 'Découverte · Créateur', color: const Color(0xFFFF8C00))
          else if (isTier3)
            _FeedTierBadge(label: 'Tendance', color: const Color(0xFF9E9E9E)),

          // ── Contenu du post ──────────────────────────────────────────────────
          Container(
            child: Stack(
              children: [
                post.type == PostType.PRONOSTIC.name
                    ? SizedBox.shrink()
                    : post.type == PostType.CHALLENGEPARTICIPATION.name
                    ? LookChallengePostWidget(post: post, height: height, width: width)
                    : (post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name)
                    ? YouTubeVideoCard(
                  key: ValueKey('ytcard_${post.id}'),
                  post: post,
                  index: index,
                  suppressInlineAd: true,
                  onNeighborhoodPreload: _preloadVideoNeighborhood,
                  currentFilterCountry: _currentFilter == 'ALL' || _currentFilter == 'MIXED' ? null : _selectedCountryCode,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoYoutubePageDetails(
                          initialPost: post,
                          feedTier: isTier1 ? 'tier1' : isTier2 ? 'tier2' : 'tier3',
                        ),
                      ),
                    );
                  },
                )
                    : HomePostUsersWidget(
                  key: ValueKey('hwp-${post.id}'),
                  index: index,
                  post: post,
                  color: _getRandomColor(),
                  height: height * 0.6,
                  width: width,
                  isDegrade: true,
                  suppressInlineAd: true,
                  currentFilterCountry: _currentFilter == 'ALL' || _currentFilter == 'MIXED' ? null : _selectedCountryCode,
                  feedTier: isTier1 ? 'tier1' : isTier2 ? 'tier2' : 'tier3',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAvailabilityBadge(Post post) {
    String badgeText = '';
    Color badgeColor = Colors.grey;

    if (post.availableCountries.contains('ALL')) {
      badgeText = '🌍 ALL';
      badgeColor = Colors.green;
    } else if (_selectedCountryCode != null &&
        post.availableCountries.contains(_selectedCountryCode!)) {
      badgeText = '📍 ${_selectedCountryCode}';
      badgeColor = Colors.blue;
    } else {
      badgeText = '🌐 MULTI';
      badgeColor = Colors.orange;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRandomColor() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  // ===========================================================================
  // FILTRES CHIPS (Pour le contenu principal)
  // ===========================================================================

  Widget _buildFilterChips() {
    return FeedFilterBar(
      currentFilter: _currentFilter,
      selectedCountryCode: _selectedCountryCode,
      onApplyFilter: ({required String filterType, String? countryCode}) =>
          _applyFilter(filterType: filterType, countryCode: countryCode),
      onShowCountryModal: _showCountryFilterModal,
    );
  }

  // ===========================================================================
  // SECTION CHRONIQUES
  // ===========================================================================

  Widget _buildChroniquesSection() {
    if (_isLoadingChroniques) {
      // Skeleton stories — même hauteur que ChroniqueSectionComponent
      return SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 50,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_chroniques.isEmpty) {
      // Bouton "Nouvelle chronique" quand aucune chronique n'existe encore
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddChroniquePage()),
          ).then((_) {
            // Relancer le chargement des chroniques au retour
            if (!mounted) return;
            setState(() { _hasStartedLoadChroniques = false; });
            _loadChroniquesInBackground();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.of(context).primary.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(30),
              color: AppColors.of(context).primary.withOpacity(0.07),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 18, color: AppColors.of(context).primary),
                const SizedBox(width: 8),
                Text(
                  'Nouvelle chronique',
                  style: TextStyle(
                    color: AppColors.of(context).primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ChroniqueSectionComponent(
      videoThumbnails: _videoThumbnails,
      userVerificationStatus: _userVerificationStatus,
      userDataCache: _userDataCache,
      isLoadingChroniques: _isLoadingChroniques,
      groupedChroniques: _groupChroniquesByUser(_chroniques),
    );
  }

  Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
    final grouped = <String, List<Chronique>>{};
    for (final chronique in chroniques) {
      grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
    }
    return grouped;
  }

  // ===========================================================================
  // SECTION PROFILS UTILISATEURS
  // ===========================================================================

  Widget _buildProfilesSection() {
    final currentUser = authProvider.loginUserData;
    final hasUnseen = _unseenCounts.values.any((c) => c > 0);
    final hasFollowed = currentUser.userAbonnesIds?.isNotEmpty ?? false;
    final hasCanaux = _recentCanaux.isNotEmpty;
    final hasCreators = _suggestedUsers.isNotEmpty;
    final hasFollowings = _followingIds.isNotEmpty ||
        (currentUser.followingIds?.isNotEmpty ?? false);
    final String title;
    if (hasUnseen) {
      title = 'Vos Créateurs actifs';
    } else if (hasFollowings || hasCreators) {
      title = hasCanaux && !hasCreators
          ? 'Vos Canaux suivis'
          : 'Créateurs & Canaux';
    } else if (hasCanaux) {
      title = 'Vos Canaux suivis';
    } else {
      title = 'Créateurs à découvrir';
    }
    return FeedProfilesSection(
      users: _suggestedUsers,
      isLoading: _isLoadingSuggestedUsers,
      title: title,
      onShowProfile: _showUserDetails,
      unseenCounts: _unseenCounts,
      recentCanaux: _recentCanaux,
      creatorLastActivityUs: _creatorLastActivityUs,
      roundCards: true,
      // "Voir plus" → toujours la liste (ActiveCreatorsListPage)
      // Cette page a déjà un bouton "Voir tous les posts non vus" pour le feed
      onSeeAllOverride: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveCreatorsListPage(
              abonnesIds: _followingIds.isNotEmpty
                  ? _followingIds
                  : (currentUser.followingIds ?? currentUser.userAbonnesIds ?? []),
              viewedPostIds: currentUser.viewedPostIds ?? [],
              currentUserId: currentUser.id ?? '',
              userCreatedAtMs: currentUser.createdAt ?? 0,
              unseenCounts: _unseenCounts,
              followedCanalIds: _followedCanalIds,
              recentCanaux: _recentCanaux,
              preloadedCreators: _activeCreators,
            ),
          ),
        );
      },
      // Tap sur une carte → toujours la page du créateur
      onTapCard: (user) {
        final unseen = _unseenCounts[user.id] ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorUnseenPostsPage(
              creator: user,
              unseenCount: unseen,
              viewedPostIds: currentUser.viewedPostIds ?? [],
              currentUserId: currentUser.id ?? '',
              userCreatedAtMs: currentUser.createdAt ?? 0,
            ),
          ),
        ).then((_) {
          // Retirer le count en mémoire pour ce créateur uniquement
          if (mounted && user.id != null) {
            setState(() {
              _unseenCounts.remove(user.id);
              _activeCreators = _activeCreators
                  .map((c) => c.user.id == user.id
                      ? ActiveCreator(
                          user: c.user,
                          unseenCount: 0,
                          lastActivityUs: c.lastActivityUs,
                        )
                      : c)
                  .toList();
              authProvider.loginUserData.newPostsByCreator?.remove(user.id);
            });
          }
        });
      },
    );
  }

  void _showUserDetails(UserData user) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    showUserDetailsModalDialog(user, w, h, context);
  }

  // ===========================================================================
  // SECTION ARTICLES
  // ===========================================================================

  Widget _buildArticlesSection() {
    final l10n = AppLocalizations.of(context);
    return FeedArticlesSection(
      articles: _articles,
      isLoading: _isLoadingArticles,
      title: l10n.sectionBoostedProducts,
      seeMoreLabel: l10n.sectionBoutiques,
    );
  }

  // ===========================================================================
  // SECTION CANAUX
  // ===========================================================================

  Widget _buildCanauxSection() {
    final l10n = AppLocalizations.of(context);
    return FeedCanauxSection(
      canaux: _canaux,
      isLoading: _isLoadingCanaux,
      title: l10n.sectionAfrolookCanal,
      seeMoreLabel: l10n.vipSeeMore,
    );
  }

  Widget _buildLoadingSection(String title) => FeedSectionLoader(title: title);

  // ===========================================================================
  // CONTENU PRINCIPAL
  // ===========================================================================



  Widget _buildContent() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    if (_isLoadingPosts && _posts.isEmpty) return _buildLoadingShimmer(width, height);
    if (_hasErrorPosts && _posts.isEmpty) return _buildErrorWidget();
    if (_posts.isEmpty) {
      // Sur une page typée (sport, evenement...) sans posts, afficher la section
      // découverte de fin de feed au lieu du widget vide centré.
      if (widget.type.isNotEmpty) {
        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                FeedEndDiscoverySection(pageType: widget.type.isNotEmpty ? widget.type : null),
                _buildT3RefreshWidget(),
              ]),
            ),
          ],
        );
      }
      return _buildEmptyWidget();
    }

    // L'ordre Tier 1 → Tier 2 → Tier 3 est déjà assuré par _buildTieredFeed.
    // Pas d'interleaving manuel : on affiche _posts tel quel.
    List<Post> finalPosts = List.from(_posts);

    // 🔥 Mémoriser la liste rendue pour le préchargement vidéo (index -> post)
    _renderedFeedPosts = finalPosts;

    // ------------------------------------------------------------
    // 2. Construction des widgets (filtrés, sections, posts, pub...)
    // ------------------------------------------------------------
    List<Widget> contentWidgets = [];

    contentWidgets.add(_buildFilterChips());
    contentWidgets.add(const SizedBox(height: 8));

    contentWidgets.add(_buildChroniquesSection());

    // Pas de posts : créateurs en haut
    if (finalPosts.isEmpty) {
      contentWidgets.add(_buildProfilesSection());
    }

    final bool _showShopPromo = _articles.isNotEmpty;

    // Catégories de l'utilisateur calculées avant la boucle pour l'injection inline
    final _inlineUserInterests = authProvider.loginUserData.interests ?? [];
    final _inlineAllCategories = _inlineUserInterests.map((id) {
      if (UserInterests.isCategoryId(id)) return id;
      try {
        return UserInterests.all.firstWhere((i) => i.code == id).category;
      } catch (_) {
        return null;
      }
    }).whereType<String>().toSet().toList();
    // SPORT toujours présent (garanti en cat1 de chaque slot)
    final _inlineCategoriesOther =
        _inlineAllCategories.where((c) => c != 'SPORT').toList();
    // Fallback si l'utilisateur n'a pas d'intérêts configurés
    const _fallbackCategories = ['EVENEMENT', 'LOOKS', 'ACTUALITES', 'GAMER'];
    final _cat2Pool = _inlineCategoriesOther.isNotEmpty
        ? _inlineCategoriesOther
        : _fallbackCategories;
    final _inlineExcludedIds = Set<String>.from(_loadedPostIds);
    // Index rotatif pour la 2ème catégorie (hors SPORT)
    int _inlineCatIdx = 0;

    // Nombre de posts T3 (Tendance) affichés avant de proposer le rafraîchissement
    const int _t3CutoffCount = 3;
    int _t3Shown = 0;
    bool _t3CutoffReached = false;

    for (int i = 0; i < finalPosts.length; i++) {
      final post = finalPosts[i];
      final pid = post.id ?? '';

      // Détecter les posts T3 (ni T1 ni T2)
      final isT1 = _seenTier1PostIds.contains(pid);
      final isT2 = _tier2PostIds.contains(pid) && !isT1;
      final isT3 = !isT1 && !isT2 && pid.isNotEmpty && !_isFirstLoad;

      if (isT3) {
        _t3Shown++;
        if (_t3Shown > _t3CutoffCount) {
          // Couper ici et injecter le bouton de rafraîchissement
          _t3CutoffReached = true;
          break;
        }
      }

      final _isVideoPost = post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name;
      contentWidgets.add(
        RepaintBoundary(
          child: _isVideoPost
              ? _buildPostWidget(post, width, height, i)
              : GestureDetector(
                  onTap: () => _navigateToPostDetails(post),
                  child: _buildPostWidget(post, width, height, i),
                ),
        ),
      );

      // Après le 1er post : section créateurs actifs
      if (i == 0) {
        contentWidgets.add(_buildProfilesSection());
      }

      // Après le 2ème post : niveau de commentaire — toujours visible
      if (i == 1) {
        contentWidgets.add(const CommentLevelWidget());
      }

      // Après le 3ème post : classement hebdo commentateurs + articles
      if (i == 2) {
        contentWidgets.add(const WeeklyTopCommentatorsWidget());
        if (_showShopPromo) {
          contentWidgets.add(ShopPromoFeedWidget(articles: _articles, isFirstPosition: false));
        }
      }

      // Pub toutes les 3 posts, première après le 2ème post (i=1, 4, 7, 10...)
      // Pattern : i >= 1 && (i - 1) % 3 == 0
      final postNumber = i + 1;
      if (i >= 1 && (i - 1) % 3 == 0) {
        final slotN = (i - 1) ~/ 3;
        contentWidgets.add(_buildUnifiedAdSlot(key: 'ad_slot_$slotN'));
      }
      // Slot découverte toutes les 9 posts
      if (postNumber % 9 == 0) {
        final poolCount = postNumber ~/ 9 - 1;
        final poolIdx = poolCount % _kPoolOrder.length;
        contentWidgets.add(_buildPoolOrAd(_kPoolOrder[poolIdx], 'pool_slot_$poolCount'));
      }

      // ── 2 sections catégorie inline toutes les 8 posts ──
      // Cat1 = SPORT (toujours), Cat2 = rotation dans les intérêts de l'utilisateur.
      // Ne pas injecter une catégorie si la page affiche déjà ce type de contenu.
      if ((i + 1) % 8 == 0) {
        final slotNum = i ~/ 8;
        if (widget.type != 'SPORT') {
          contentWidgets.add(FeedCategorySectionWidget(
            key: ValueKey('inline_cat_SPORT_$slotNum'),
            categoryId: 'SPORT',
            excludedIds: _inlineExcludedIds,
          ));
        }
        final cat2 = _cat2Pool[_inlineCatIdx % _cat2Pool.length];
        _inlineCatIdx++;
        if (widget.type != cat2) {
          contentWidgets.add(FeedCategorySectionWidget(
            key: ValueKey('inline_cat_${cat2}_${slotNum}_b'),
            categoryId: cat2,
            excludedIds: _inlineExcludedIds,
          ));
        }
      }
    }

    // ── Section "À suivre pour plus de posts" en fin de feed ────────────────
    // Affichée avant le bouton refresh T3 et avant "Fin du feed".
    // Encourage l'utilisateur à suivre des créateurs/canaux pour enrichir son T1.
    final bool _showEndDiscovery = _t3CutoffReached ||
        (!_isLoadingMorePosts && !_hasMorePosts);
    if (_showEndDiscovery) {
      contentWidgets.add(FeedEndDiscoverySection(pageType: widget.type.isNotEmpty ? widget.type : null));
    }

    // Bouton de rafraîchissement après le seuil de posts Tendance
    if (_t3CutoffReached) {
      contentWidgets.add(_buildT3RefreshWidget());
    }

    // Indicateurs de chargement / fin de feed
    if (!_t3CutoffReached) {
      if (_isLoadingMorePosts) {
        contentWidgets.add(_buildShimmerPost());
        contentWidgets.add(_buildShimmerPost());
        contentWidgets.add(_buildShimmerPost());
      } else if (!_hasMorePosts) {
        contentWidgets.add(_buildEndOfFeedWidget());
      }
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => contentWidgets[index],
            childCount: contentWidgets.length,
          ),
        ),
      ],
    );
  }

  // 🎯 Widget pour afficher une bannière AdMob
  Widget _buildAdBanner({required String key}) => FeedAdBanner(adKey: key);
  Widget _buildAdMrec({required String key}) => FeedAdMrec(adKey: key);
  Widget _buildAdAdvertisement({required String key}) => FeedAdCarousel(adKey: key);
  String _getEndMessage() {
    switch (_currentFilter) {
      case 'ALL':
        return 'Vous avez vu tous les contenus disponibles';
      case 'COUNTRY':
        return 'Fin des contenus en ${_selectedCountryCode ?? "ce pays"}';
      case 'MIXED':
        return 'Fin des contenus pour le mix actuel';
      case 'CUSTOM':
        return 'Fin des contenus pour ${_selectedCountryCode ?? "ce pays"}';
      default:
        return 'Fin des contenus';
    }
  }

  Widget _buildT3RefreshWidget() {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: colors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'Vous avez vu les Tendances',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rechargez pour voir de nouveaux posts et des créateurs à découvrir',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Voir les nouveautés'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndOfFeedWidget() {
    final colors2 = AppColors.of(context);
    // Détermine le prochain filtre à proposer
    final String? nextFilter = _currentFilter == 'COUNTRY'
        ? 'MIXED'
        : _currentFilter == 'MIXED'
            ? 'ALL'
            : null;
    final String? nextLabel = _currentFilter == 'COUNTRY'
        ? 'Voir des créateurs d\'autres pays'
        : _currentFilter == 'MIXED'
            ? 'Voir tous les contenus'
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.flag, color: colors2.primary, size: 36),
          const SizedBox(height: 10),
          Text(
            _getEndMessage(),
            style: TextStyle(color: colors2.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (nextFilter != null && nextLabel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _applyFilter(filterType: nextFilter, countryCode: _selectedCountryCode),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: Text(nextLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors2.primary,
                  side: BorderSide(color: colors2.primary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 5),
            Text(
              'Revenez plus tard pour de nouveaux contenus',
              style: TextStyle(color: colors2.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGETS D'ÉTAT
  // ===========================================================================

  Widget _buildLoadingShimmer(double width, double height) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 100,
            margin: EdgeInsets.all(8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.2,
                  margin: EdgeInsets.all(4),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[800]!,
                    highlightColor: Colors.grey[700]!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return Container(
                margin: EdgeInsets.all(8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
            childCount: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          SizedBox(height: 12),
          Text('Erreur de chargement', style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Réessayer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed, color: Colors.grey, size: 40),
          SizedBox(height: 12),
          Text(
            _getEmptyMessage(),
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Actualiser', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case 'ALL':
        return 'Aucun contenu disponible pour tous les pays';
      case 'COUNTRY':
        return 'Aucun contenu disponible en ${_selectedCountryCode ?? "ce pays"}';
      case 'MIXED':
        return 'Aucun contenu disponible pour le moment';
      case 'CUSTOM':
        return 'Aucun contenu disponible pour ${_selectedCountryCode ?? "ce pays"}';
      default:
        return 'Aucun contenu disponible';
    }
  }

  String _getFilterDescription() {
    switch (_currentFilter) {
      case 'ALL':
        return '🌍 Tous les pays';
      case 'COUNTRY':
        return '📍 ${_selectedCountryCode ?? "Mon pays"}';
      case 'MIXED':
        return '🔄 Mix intelligent';
      case 'CUSTOM':
        return '⚙️ ${_selectedCountryCode ?? "Pays spécifique"}';
      default:
        return 'Filtrer par pays';
    }
  }

  Widget _getFilterIcon(AppColors colors) {
    switch (_currentFilter) {
      case 'ALL':
        return Icon(Icons.public, color: colors.textPrimary, size: 18);
      case 'COUNTRY':
      case 'CUSTOM':
        return Text(
          _getCountryFlag(_selectedCountryCode ?? ''),
          style: TextStyle(fontSize: 16),
        );
      case 'MIXED':
        return Icon(Icons.blender, color: colors.textPrimary, size: 18);
      default:
        return Icon(Icons.filter_alt, color: colors.textPrimary, size: 18);
    }
  }

  // ===========================================================================
  // MÉTHODES UTILITAIRES
  // ===========================================================================

  bool _checkIfPostSeen(Post post) {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return false;

    if (_postsViewedInSession.containsKey(post.id)) {
      return _postsViewedInSession[post.id]!;
    }

    if (authProvider.loginUserData.viewedPostIds?.contains(post.id!) ?? false) {
      return true;
    }

    if (post.users_vue_id?.contains(currentUserId) ?? false) {
      return true;
    }

    return false;
  }

  /// 🔥 Préchargement Facebook-style : appelé par `YouTubeVideoCard` quand
  /// elle devient visible. Précharge (initialise sans jouer) les vidéos
  /// voisines (±[VideoPreloadManager.preloadRadius]) et nettoie les
  /// contrôleurs préchargés devenus hors-champ.
  void _preloadVideoNeighborhood(int index) {
    if (_renderedFeedPosts.isEmpty) return;
    final length = _renderedFeedPosts.length;

    String? idAt(int i) {
      if (i < 0 || i >= length) return null;
      final p = _renderedFeedPosts[i];
      if (p.dataType != PostDataType.VIDEO.name) return null;
      return p.id;
    }

    String? urlAt(int i) {
      if (i < 0 || i >= length) return null;
      final p = _renderedFeedPosts[i];
      if (p.dataType != PostDataType.VIDEO.name) return null;
      return p.url_media;
    }

    VideoPreloadManager.preloadNeighborhood(index, length, idAt, urlAt);
    VideoPreloadManager.cleanupOutOfRange(index, length, idAt);
  }

  void _handleVisibilityChanged(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordPostView(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
    // Tier 1 : marquer vu après 2 secondes à ≥50% de visibilité
    _onPostBecameVisible(postId, info.visibleFraction);
  }
  // 🔥 NOUVELLE MÉTHODE UTILITAIRE
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
  Future<void> _recordPostView3(Post post) async {

  }

  /// Décrémente directement _unseenCounts quand un post est vu dans le feed.
  /// Chaque post n'est décrémenté qu'une seule fois par session.
  void _decrementCreatorUnseenCount(Post post) {
    final postId = post.id;
    final creatorId = post.user_id;
    if (postId == null || creatorId == null) return;
    if (_decrementedPostIds.contains(postId)) return;
    _decrementedPostIds.add(postId);

    // Source de vérité : _unseenCounts (issu de recalibrateUnseenCounts)
    final current = _unseenCounts[creatorId] ?? 0;
    if (current <= 0) return;

    final newCount = current - 1;

    // Mise à jour UI des badges
    if (mounted) {
      setState(() {
        if (newCount <= 0) {
          _unseenCounts.remove(creatorId);
        } else {
          _unseenCounts[creatorId] = newCount;
        }
        _activeCreators = _activeCreators.map((c) {
          if (c.user.id != creatorId) return c;
          return ActiveCreator(
            user: c.user,
            unseenCount: newCount,
            lastActivityUs: c.lastActivityUs,
          );
        }).toList();
      });
    }

    // Garde newPostsByCreator en sync pour la prochaine session
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    if (newCount <= 0) {
      _activeCreatorsService.resetCreatorCounter(userId, creatorId);
    } else {
      FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .update({'newPostsByCreator.$creatorId': FieldValue.increment(-1)})
          .catchError((_) {});
    }
  }
  // Resynchronise newPostsByCreator dans Firestore avec les valeurs recalibrées
  // pour corriger les décalages accumulés par les échecs de CF.
  void _syncNewPostsByCreatorToFirestore(
      String userId, List<String> creatorIds, Map<String, int> calibrated) {
    if (userId.isEmpty) return;
    final Map<String, dynamic> updates = {};
    for (final id in creatorIds) {
      updates['newPostsByCreator.$id'] = calibrated[id] ?? 0;
    }
    if (updates.isEmpty) return;
    FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .update(updates)
        .catchError((_) {});
  }

  Future<void> _recordPostView(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    String viewKey = '${_lastViewDatePrefix}${currentUserId}_${post.id}';

    String? lastViewDateStr = _prefs.getString(viewKey);

    // ✅ 1. GESTION DES VUES (inchangée)
    if (lastViewDateStr != null) {
      DateTime lastViewDate = DateTime.parse(lastViewDateStr);
      DateTime now = DateTime.now();

      int difference = now.difference(lastViewDate).inDays;

      // ❌ Si moins de 2 jours -> ne pas compter la vue
      if (difference < 2) {
        printVm(
            '⏭️ Post ${post.id} déjà vu il y a $difference jour(s) par $currentUserId - Vue NON comptée');

        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          setState(() {
            post.users_vue_id!.add(currentUserId);
            post.hasBeenSeenByCurrentUser = true;
          });
          // ✅ 2. GESTION DE L'INTERACTION (par session)
          await _checkAndIncrementInteraction(post);
        }


        return;
      }
    }

    try {
      // 🔥 Sauvegarder la date actuelle pour les vues
      await _prefs.setString(viewKey, DateTime.now().toIso8601String());

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      final batch = _firestore.batch();

      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
        // ✅ 2. GESTION DE L'INTERACTION (par session)
        await _checkAndIncrementInteraction(post);
      }

      // Décrémenter newPostsByCreator pour ce créateur
      _decrementCreatorUnseenCount(post);

      PostViewService.recordAuthorView(post, currentUserId);
      printVm('✅ Vue comptée pour post ${post.id} par $currentUserId');



    } catch (e) {
      printVm('Error recording post view: $e');
    }
  }

// ✅ Nouvelle fonction dédiée à l'interaction (session uniquement)
  Future<void> _checkAndIncrementInteraction(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    // Clé de session pour l'interaction
    String interactionKey = 'session_interaction_${currentUserId}_${post.id}';

    // Vérifier si déjà interagi dans cette session
    bool alreadyInteracted = _prefs.getBool(interactionKey) ?? false;

    if (!alreadyInteracted) {
      // Incrémenter l'interaction UNE SEULE FOIS par session
      await authProvider.incrementPostTotalInteractions(postId: post.id!);
      await _prefs.setBool(interactionKey, true);
      printVm('✅ Total interactions +1 pour le post ${post.id} (première vue de la session)');
    } else {
      printVm('⏭️ Interaction déjà comptée dans cette session pour le post ${post.id}');
    }
  }

  Future<void> _recordPostView4(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    // 🔥 Vérification avec SharedPreferences (une fois par jour)
    String todayDate = _getTodayDateString();
    String viewKey = '${_lastViewDatePrefix}${currentUserId}_${post.id}';

    // Récupérer la dernière date de vue pour ce post par cet utilisateur
    String? lastViewDate = _prefs.getString(viewKey);

    // Si déjà vu aujourd'hui, NE PAS COMPTER la vue
    if (lastViewDate == todayDate) {
      printVm('⏭️ Post ${post.id} déjà vu aujourd\'hui par $currentUserId - Vue NON comptée');

      // ✅ On met quand même à jour l'UI locale pour montrer que le post est vu
      if (!post.users_vue_id!.contains(currentUserId)) {
        setState(() {
          post.users_vue_id!.add(currentUserId);
          post.hasBeenSeenByCurrentUser = true;
        });
      }
      return; // On ne compte pas la vue
    }


    // ✅ SUPPRIMER la vérification _postsViewedInSession qui empêcherait
    // de compter la vue si l'utilisateur a déjà vu le post dans une session précédente
    // On garde seulement la vérification SharedPreferences (une fois par jour)

    try {
      // 🔥 Sauvegarder la date dans SharedPreferences
      await _prefs.setString(viewKey, todayDate);

      // Mise à jour locale de l'UI
      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      // Mise à jour Firestore avec batch pour atomicité
      final batch = _firestore.batch();

      // 1. Incrémenter les vues du post
      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      // 2. Ajouter l'ID du post à l'historique de l'utilisateur
      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      // Mettre à jour le provider local
      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

      printVm('✅ Vue comptée pour post ${post.id} par $currentUserId le $todayDate');

    } catch (e) {
      printVm('Error recording post view: $e');
    }
  }
  Future<void> _recordPostView2(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    if (_postsViewedInSession.containsKey(post.id!)) {
      return;
    }

    try {
      _postsViewedInSession[post.id!] = true;

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      final batch = _firestore.batch();
      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

    } catch (e) {
      printVm('Error recording post view: $e');
      _postsViewedInSession.remove(post.id!);
    }
  }

  void _navigateToPostDetails(Post post) {
    _recordPostView(post);
    // Naviguer vers la page de détails du post
  }

  Future<void> _refreshData() async {
    // Arrêter le chargement background pendant le refresh
    _backgroundLoadTimer?.cancel();

    setState(() {
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true; // Réactiver le background
      _backgroundPostsLoaded = 0; // Réinitialiser le compteur
    });

    // Flush les posts déjà vus + relit unreadPosts depuis Firestore
    // pour que Tier 1 soit propre avant de reconstruire le feed.
    await _flushAndRefreshUnread();

    _resetPagination();
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  void _handleAppLifecycle(String? message) {
    if (message?.contains('resume') == true) {
      _setUserOnline();
      _recalibrateUnseenOnFocus();
    } else {
      _setUserOffline();
    }
  }

  // Re-calibre les badges après retour sur la page (viewedPostIds peut avoir évolué)
  Future<void> _recalibrateUnseenOnFocus() async {
    if (!mounted) return;
    final me = authProvider.loginUserData;
    final creatorIds = _activeCreators
        .where((c) => c.user.id != null)
        .map((c) => c.user.id!)
        .toList();
    if (creatorIds.isEmpty) return;
    try {
      final viewedSet = Set<String>.from(me.viewedPostIds ?? []);
      final calibrated = await _activeCreatorsService.recalibrateUnseenCounts(
        creatorIds: creatorIds,
        viewedPostIds: viewedSet,
        userCreatedAtMs: me.createdAt ?? 0,
      );
      if (!mounted) return;
      setState(() => _unseenCounts = calibrated);
    } catch (_) {}
  }

  void _setUserOnline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = true;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.ONLINE.name
      );
    }
  }

  void _setUserOffline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.OFFLINE.name
      );
    }
  }

  Color _getFilterBorderColor() {
    switch (_currentFilter) {
      case 'ALL':
        return primaryGreen;
      case 'COUNTRY':
        return Colors.blue;
      case 'MIXED':
        return Colors.purple;
      case 'CUSTOM':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  final GlobalKey<InterstitialAdWidgetState> _interstitialAdKey = GlobalKey();

  // ── Méthodes publiques exposées pour la barre supérieure de homeScreen ──
  // Permettent de déclencher le filtre pays et le rafraîchissement depuis
  // l'AppBar combiné de la page d'accueil (l'AppBar "Découvrir" propre à
  // cette page a été supprimée pour libérer de la place).
  void showCountryFilter() => _showCountryFilterModal();
  Future<void> refreshFeed() => _refreshData();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.background,
        appBar: widget.isVideoPage
            ? AppBar(
                automaticallyImplyLeading: true,
                iconTheme: IconThemeData(color: colors.accent),
                backgroundColor: colors.surface,
                title: Text(
                  'Afrolook vidéos',
                  style: TextStyle(
                    fontSize: 18,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                elevation: 0,
                actions: [
                  Consumer<SoundProvider>(
                    builder: (context, soundProvider, child) {
                      return IconButton(
                        icon: Icon(
                          soundProvider.isMuted ? Icons.volume_off : Icons.volume_up,
                          color: soundProvider.isMuted ? colors.textSecondary : colors.primary,
                        ),
                        onPressed: () {
                          soundProvider.toggleSound();
                        },
                        tooltip: soundProvider.isMuted ? 'Activer le son' : 'Couper le son',
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: colors.textPrimary, size: 22),
                    onPressed: _refreshData,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                  IconButton(
                    icon: Icon(
                      colors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: colors.textPrimary,
                    ),
                    tooltip: 'Changer de thème',
                    onPressed: () {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                    },
                  ),
                  SizedBox(width: 8),
                ],
              )
            : null,
        body: SafeArea(
          child: Container(
            color: colors.background,
            child: Stack(
              children: [
                AppLayout.isWide(context)
                    ? CenteredContent(child: _buildContent())
                    : _buildContent(),
                InterstitialAdWidget(
                  key: _interstitialAdKey,
                  onAdDismissed: () {
                    // Show a thank‑you message after the ad is dismissed
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Merci d\'avoir regardé la publicité ! Votre soutien est précieux.',
                          style: TextStyle(color: colors.success),
                        ),
                        backgroundColor: colors.surface,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),      ),
    );
  }
}

// ── Badge générique Tier (Nouveau·Abonnement / Découverte·Intérêts) ──────────

class _FeedTierBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _FeedTierBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 6),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge "Nouveau créateur" affiché au-dessus d'un post boosté ──────────────

class _NewCreatorBadge extends StatelessWidget {
  final String postId;
  final String userId;

  const _NewCreatorBadge({required this.postId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B2FF7), Color(0xFFFF6B35)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
          SizedBox(width: 5),
          Text(
            'Nouveau créateur',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

