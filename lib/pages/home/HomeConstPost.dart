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
import '../../widgets/feed/sections/feed_profiles_section.dart';
import '../../widgets/feed/sections/feed_state_widgets.dart';
import '../../widgets/feed/sections/feed_filter_bar.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../../services/feed/feed_repository.dart';


// Constantes de couleur
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
const Color accentYellow = Color(0xFFFFD700);
final Color _primaryColor = Color(0xFFE21221); // Rouge
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

  // 🔥 Liste des posts effectivement rendus dans le feed (avec anciens posts
  // mélangés), utilisée par le préchargement vidéo Facebook-style pour
  // retrouver les voisins d'un index donné.
  List<Post> _renderedFeedPosts = [];
  bool _isLoadingPosts = true;
  bool _hasErrorPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  bool _isLoadingBackground = false;

  // Système hybride de chargement
  Set<String> _loadedPostIds = Set();
  int _totalPostsLoaded = 0;
  int _backgroundPostsLoaded = 0; // Compteur des posts chargés en background
  final int _initialLimit = 4; // Premier chargement: 4 posts
  final int _backgroundLoadLimit = 5; // Chargement background: 5 posts
  final int _manualLoadLimit = 5; // Chargement manuel: 5 posts
  final int _maxBackgroundPosts = 20; // MAX posts en background
  final int _maxTotalPosts = 1000; // Limite totale
  Timer? _backgroundLoadTimer;
  bool _useBackgroundLoading = true; // Active/désactive le chargement background

  // Filtrage par pays
  String? _selectedCountryCode;
  String _currentFilter = 'MIXED'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  // String _currentFilter = 'ALL'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  bool _isFirstLoad = true;


  // Données supplémentaires - chargement séparé
  List<ArticleData> _articles = [];
  bool _isLoadingArticles = false;

  List<Canal> _canaux = [];
  bool _isLoadingCanaux = false;

  List<UserData> _suggestedUsers = [];
  bool _isLoadingSuggestedUsers = false;
  Timer? _stayTimer;
  bool _isPageVisible = true;
  bool _isSupportDialogShowing = false;
  String? _lastPopupDateKey = 'last_support_ad_popup_date';
  // Chroniques
  List<Chronique> _chroniques = [];
  bool _isLoadingChroniques = false;
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

// 🔥 NOUVELLE MÉTHODE
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }


  // Dans _HomeConstPostPageState
  List<Post> _oldPostsCache = [];
  bool _isLoadingOldPosts = false;

  // Cache des fenêtres mensuelles déjà testées et trouvées vides (clé = startDate du mois)
  final Set<DateTime> _emptyOldPostsWindows = {};

  Timer? _oldPostsLoadTimer;
  DocumentSnapshot? _lastOldPostDocument;

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
    _oldPostsLoadTimer?.cancel();
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _backgroundLoadTimer?.cancel();
    _starController.dispose();
    _unlikeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    MediaPlaybackManager.dispose();
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

  /// Choisit une fenêtre mensuelle aléatoire (pondérée) en évitant si possible
  /// les fenêtres déjà connues comme vides.
  DateTime _pickRandomOldPostsWindowStart(Random random) {
    DateTime? candidate;

    for (int attempt = 0; attempt < 5; attempt++) {
      int monthsBack;
      int chance = random.nextInt(100);

      if (chance < 50) {
        // 50% → 1 à 6 mois
        monthsBack = random.nextInt(6) + 1;
      } else if (chance < 80) {
        // 30% → 6 à 18 mois
        monthsBack = random.nextInt(12) + 6;
      } else {
        // 20% → 18 à 30 mois
        monthsBack = random.nextInt(12) + 18;
      }

      final now = DateTime.now();
      final DateTime endDate = DateTime(now.year, now.month - monthsBack, 1);
      final DateTime startDate = DateTime(endDate.year, endDate.month - 1, 1);

      if (!_emptyOldPostsWindows.contains(startDate)) {
        return startDate;
      }
      candidate = startDate;
    }

    // Toutes les tentatives sont tombées sur des fenêtres déjà vides :
    // on retente quand même avec la dernière, le cache pourra avoir été
    // rafraîchi entre-temps (nouveaux posts publiés).
    return candidate!;
  }

  /// Exécute la requête Firestore pour une fenêtre mensuelle donnée et
  /// retourne les posts valides trouvés (sans les ajouter au cache).
  Future<List<Post>> _fetchOldPostsForWindow(DateTime startDate) async {
    final DateTime endDate = DateTime(startDate.year, startDate.month + 1, 1);

    final int startMicros = startDate.microsecondsSinceEpoch;

    // Borne supérieure : jamais les 2 derniers jours (évite tout chevauchement
    // avec le feed principal qui charge les posts les plus récents).
    final int twoDaysAgoMicros = DateTime.now()
        .subtract(const Duration(days: 2))
        .microsecondsSinceEpoch;
    final int safeEndMicros =
        endDate.microsecondsSinceEpoch < twoDaysAgoMicros
            ? endDate.microsecondsSinceEpoch
            : twoDaysAgoMicros;

    if (safeEndMicros <= startMicros) return [];

    print("📜 Chargement anciens posts entre $startDate et $endDate");

    Query query = _firestore.collection('Posts');

    if (widget.isVideoPage) {
      query = query.where(
        "dataType",
        isEqualTo: PostDataType.VIDEO.name,
      );
    }

    query = query
        .where("created_at", isGreaterThanOrEqualTo: startMicros)
        .where("created_at", isLessThan: safeEndMicros)
        .orderBy("created_at")
        .limit(30); // on prend large pour filtrer ensuite

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      print("⚠️ Aucun post trouvé dans cette période");
      return [];
    }

    List<Post> validOldPosts = [];

    for (final doc in snapshot.docs) {
      final post = Post.fromJson(doc.data() as Map<String, dynamic>);
      post.id = doc.id;

      if (_loadedPostIds.contains(post.id)) continue;
      if (_oldPostsCache.any((p) => p.id == post.id)) continue;
      if (post.isAdvertisement == true) continue;

      post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);

      validOldPosts.add(post);

      if (validOldPosts.length >= 12) break;
    }

    return validOldPosts;
  }

  Future<void> _loadOldPostsInBackground() async {
    if (_isLoadingOldPosts) return;
    _isLoadingOldPosts = true;

    try {
      final random = Random();

      // Jusqu'à 3 fenêtres tentées dans cette même passe : la fenêtre
      // initiale + jusqu'à 2 fallbacks si vide/quasi-vide (<3 posts).
      const int maxFallbacks = 2;
      List<Post> validOldPosts = [];

      for (int attempt = 0; attempt <= maxFallbacks; attempt++) {
        final startDate = _pickRandomOldPostsWindowStart(random);

        final found = await _fetchOldPostsForWindow(startDate);

        if (found.length < 3) {
          _emptyOldPostsWindows.add(startDate);
        }

        if (found.isNotEmpty) {
          validOldPosts = found;
          break;
        }

        print("↩️ Fenêtre vide, tentative de repli (${attempt + 1}/${maxFallbacks + 1})");
      }

      if (validOldPosts.isNotEmpty) {
        validOldPosts.shuffle();

        _oldPostsCache.addAll(validOldPosts);

        print(
          "✅ ${validOldPosts.length} anciens posts ajoutés (cache: ${_oldPostsCache.length})",
        );
      } else {
        print("⚠️ Aucun post valide après filtrage (toutes les tentatives vides)");
      }
    } catch (e) {
      print("❌ Erreur chargement anciens posts: $e");
    } finally {
      _isLoadingOldPosts = false;
    }
  }


  // Injecte les anciens posts dans le feed quand le feed récent est épuisé.
  // Relance le background loading pour continuer à alimenter le cache.
  void _injectOldPostsAndResume() {
    final available = _oldPostsCache
        .where((p) => p.id != null && !_loadedPostIds.contains(p.id))
        .take(12)
        .toList()..shuffle();

    if (available.isEmpty) return;

    setState(() {
      _posts.addAll(available);
      _loadedPostIds.addAll(available.map((p) => p.id!));
      _totalPostsLoaded += available.length;
      _hasMorePosts = true;
      _backgroundPostsLoaded = 0;
      _useBackgroundLoading = true;
    });

    _oldPostsCache.removeWhere((p) => available.any((a) => a.id == p.id));
    _startBackgroundLoading();
  }

  void _startOldPostsLoading() {
    _oldPostsLoadTimer?.cancel();
    // Intervalle augmenté de 15s à 22s : réduit le nombre de round trips
    // Firestore tout en restant suffisamment réactif pour réalimenter le
    // cache d'anciens posts (cf. SUIVI_REFONTE.md - Session 9).
    _oldPostsLoadTimer = Timer.periodic(Duration(seconds: 22), (timer) {
      if (_oldPostsCache.length < 4 && !_isLoadingOldPosts) {
        _loadOldPostsInBackground();
      }
    });
    // Premier chargement immédiat
    _loadOldPostsInBackground();
  }

// Appeler _startOldPostsLoading() dans _initializeData() après _loadInitialPosts
  Future<bool> _shouldStartTimer() async {
    if (_isUserPremium()) {
      print('⏱️ [Timer] Utilisateur premium → timer non démarré');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPopupDateStr = prefs.getString(_lastPopupDateKey!);
    if (lastPopupDateStr != null) {
      final lastDate = DateTime.parse(lastPopupDateStr);
      final diffDays = DateTime.now().difference(lastDate).inDays;
      print('⏱️ [Timer] Dernière popup: $lastPopupDateStr, différence jours: $diffDays');
      if (diffDays < 2) {
        print('⏱️ [Timer] Délai de 2 jours non écoulé → timer non démarré');
        return false;
      }
    }

    print('⏱️ [Timer] Conditions OK : non premium et cooldown passé');
    return true;
  }
  void _startStayTimer() async {
    print('⏱️ [Timer] Démarrage demandé...');

    bool shouldStart = await _shouldStartTimer();
    if (!shouldStart) return;
    _checkAndShowSupportPopup();

  }
  void _stopStayTimer() {
    // if (_stayTimer != null && _stayTimer!.isActive) {
    //   _stayTimer!.cancel();
    //   print('⏱️ [Timer] Timer annulé');
    // }
  }

  bool _isUserPremium() {
    final user = authProvider.loginUserData;
    if (user == null) {
      print('🔍 [Premium] Utilisateur null');
      return false;
    }
    final isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
    print('🔍 [Premium] Abonnement utilisateur: ${user.abonnement} => isPremium = $isPremium');
    return isPremium;
  }

  Future<void> _checkAndShowSupportPopup() async {
    print('🔔 [Popup] Vérification des conditions...');
    if (!_isPageVisible) {
      print('🔔 [Popup] Page non visible → annulé');
      return;
    }
    if (_isSupportDialogShowing) {
      print('🔔 [Popup] Popup déjà en cours d\'affichage → annulé');
      return;
    }
    if (_isUserPremium()) {
      print('🔔 [Popup] Utilisateur premium → pas de popup');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastPopupDateStr = prefs.getString(_lastPopupDateKey!);
    print('🔔 [Popup] Dernière date enregistrée: $lastPopupDateStr');

    if (lastPopupDateStr != null) {
      final lastDate = DateTime.parse(lastPopupDateStr);
      final diffDays = DateTime.now().difference(lastDate).inDays;
      print('🔔 [Popup] Différence en jours: $diffDays');
      if (diffDays < 2) {
        print('🔔 [Popup] Cooldown actif (moins de 2 jours) → popup ignoré');
        return;
      }
    }

    // Enregistrer la date actuelle
    final nowStr = DateTime.now().toIso8601String();
    await prefs.setString(_lastPopupDateKey!, nowStr);
    print('🔔 [Popup] Date enregistrée: $nowStr');

    print('🔔 [Popup] Affichage du popup...');
    _showSupportDialog();
  }
  void _showSupportDialog() {
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
  void _setupScrollController() {
    _scrollController.addListener(_scrollListener);
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
    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    print('Pays utilisateur détecté: ${_selectedCountryCode}');

    // 🔥 MODIFICATION: Pour EVENEMENT, forcer le mode COUNTRY (pas de mix)
    if (widget.type == TabBarType.EVENEMENT.name) {
      _currentFilter = 'COUNTRY';  // Forcer le pays de l'utilisateur seulement
      print('🎯 Mode EVENEMENT activé - Filtre: COUNTRY (${_selectedCountryCode})');
    } else if (_selectedCountryCode != null) {
      // 🔥 Par défaut: filtre sur le pays de l'utilisateur (au lieu de "Tous")
      // L'utilisateur peut toujours changer via la modale de filtre (_showCountryFilterModal).
      _currentFilter = 'COUNTRY';
      print('🌍 Filtre par défaut: COUNTRY (pays utilisateur: ${_selectedCountryCode})');
    } else {
      _currentFilter = 'MIXED';     // Fallback si pays utilisateur inconnu
    }

    _isFirstLoad = true;
    _useBackgroundLoading = true;
    _backgroundPostsLoaded = 0;

    // 0. 🔥 Affichage instantané depuis le cache local (Facebook-style) avant
    // même que le réseau ait répondu - skip si rien en cache.
    final bool hasCachedPosts = await _loadFromCacheAndDisplay();

    // 3. Réinitialiser la pagination. Si le cache a déjà rempli `_posts`,
    // on NE LES EFFACE PAS (sinon le skeleton revient le temps du réseau) :
    // `_loadInitialPosts()` remplacera/complètera ces posts dès que la
    // réponse réseau arrive, sans repasser par un état "vide".
    _resetPagination(clearPosts: !hasCachedPosts);

    if (hasCachedPosts) {
      // Cache présent : réseau en arrière-plan, pas de skeleton.
      // _startOldPostsLoading démarre après pour que _loadedPostIds
      // soit peuplé par le cache avant la première requête old posts.
      _loadInitialPosts();
      _startOldPostsLoading();
      _startBackgroundLoading();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllAdditionalDataInParallel();
      });
    } else {
      // Pas de cache : on attend les premiers posts avant tout le reste,
      // garantissant que _loadedPostIds est peuplé avant _startOldPostsLoading.
      await _loadInitialPosts();
      _startOldPostsLoading();
      _startBackgroundLoading();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllAdditionalDataInParallel();
      });
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
    try {
      final cached = await FeedCacheService.loadFeedData(_feedCacheKey);
      if (cached == null) return false;

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
            print('⚠️ Cache: erreur parsing post: $e');
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
            print('⚠️ Cache: erreur parsing chronique: $e');
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
            print('⚠️ Cache: erreur parsing auteur chronique: $e');
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
            print('⚠️ Cache: erreur parsing profil suggéré: $e');
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
            print('⚠️ Cache: erreur parsing canal: $e');
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
            print('⚠️ Cache: erreur parsing article boosté: $e');
          }
        }
      }

      if (!mounted) return cachedPosts.isNotEmpty;

      setState(() {
        if (cachedPosts.isNotEmpty) {
          _posts = cachedPosts;
          _loadedPostIds.addAll(cachedPosts.map((p) => p.id ?? '').where((id) => id.isNotEmpty));
          _totalPostsLoaded = cachedPosts.length;
          _isFirstLoad = false;
          _isLoadingPosts = false; // skip le skeleton, affichage instantané
        }
        if (cachedChroniques.isNotEmpty) {
          _chroniques = cachedChroniques;
        }
        if (cachedSuggestedUsers.isNotEmpty) {
          _suggestedUsers = cachedSuggestedUsers;
        }
        if (cachedCanaux.isNotEmpty) {
          _canaux = cachedCanaux;
        }
        if (cachedArticles.isNotEmpty) {
          _articles = cachedArticles;
        }
      });

      print('⚡ Feed affiché instantanément depuis le cache local ($_feedCacheKey)');
      return cachedPosts.isNotEmpty;
    } catch (e) {
      print('⚠️ Erreur _loadFromCacheAndDisplay: $e');
      return false;
    }
  }

  /// Sauvegarde l'état courant du feed dans le cache local pour le prochain
  /// affichage instantané. Appelé après chaque chargement réseau réussi
  /// (posts initiaux, chroniques, profils suggérés, canaux, articles boostés).
  Future<void> _saveFeedToCache() async {
    try {
      final data = <String, dynamic>{};

      if (_posts.isNotEmpty) {
        data['posts'] = _posts.map((p) {
          final json = p.toJson();
          json['id'] = p.id;
          return json;
        }).toList();
      }

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
      print('⚠️ Erreur _saveFeedToCache: $e');
    }
  }

  void _initializeData2() async {
    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    print('Pays utilisateur détecté: ${_selectedCountryCode}');

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

    // 5. Charger les autres données EN PARALLÈLE (non bloquant)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllAdditionalDataInParallel();
    });
  }

  void _resetPagination({bool clearPosts = true}) {
    if (clearPosts) {
      _posts.clear();
      _loadedPostIds.clear();
      _isLoadingPosts = true; // évite l'écran vide pendant le rechargement
    }
    _totalPostsLoaded = 0;
    _backgroundPostsLoaded = 0;
    _hasMorePosts = true;
    _isLoadingMorePosts = false;
    _isLoadingBackground = false;
  }

  // ===========================================================================
  // SYSTÈME HYBRIDE DE CHARGEMENT (Background + Manuel)
  // ===========================================================================

  void _startBackgroundLoading() {
    if (!_useBackgroundLoading) return;

    // Arrêter tout timer existant
    _backgroundLoadTimer?.cancel();

    print('🚀 Démarrage du chargement background (max: $_maxBackgroundPosts posts)');

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
        print('⏹️ Arrêt du chargement background (posts background: $_backgroundPostsLoaded)');
        timer.cancel();
        _useBackgroundLoading = false; // Passer en mode manuel
      }
    });
  }

  bool _isUserScrolling() {
    return _scrollController.position.isScrollingNotifier.value;
  }

  Future<void> _loadBackgroundPosts() async {
    if (_isLoadingBackground ||
        !_hasMorePosts ||
        _backgroundPostsLoaded >= _maxBackgroundPosts ||
        _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    print('🔄 Chargement background... ($_backgroundPostsLoaded/$_maxBackgroundPosts)');

    setState(() {
      _isLoadingBackground = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _backgroundLoadLimit);

      // Ajouter les nouveaux posts à la liste
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
          _backgroundPostsLoaded += newPosts.length;
        });

        print('✅ ${newPosts.length} posts chargés en background (total: $_totalPostsLoaded, background: $_backgroundPostsLoaded)');
      }

      // Vérifier s'il reste des posts à charger
      _hasMorePosts = newPosts.length >= (_backgroundLoadLimit ~/ 2);

      // Feed récent épuisé → injecter les anciens posts si disponibles
      if (!_hasMorePosts && _oldPostsCache.isNotEmpty) {
        _injectOldPostsAndResume();
      }

      // Si on atteint la limite de background, désactiver
      if (_backgroundPostsLoaded >= _maxBackgroundPosts) {
        _useBackgroundLoading = false;
        print('📊 Passage en mode chargement manuel (limite background atteinte)');
      }

    } catch (e) {
      print('❌ Erreur chargement background: $e');
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
    showModalBottomSheet(
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
    _oldPostsCache.clear();
    _lastOldPostDocument = null;
    _loadOldPostsInBackground(); // recharger immédiatement
    setState(() {
      _isLoadingPosts = false;
    });

    print('✅ Filtre appliqué: $_currentFilter - Pays: $_selectedCountryCode');
  }

  // ===========================================================================
  // CHARGEMENT DES POSTS
  // ===========================================================================
  Future<void> _loadInitialPosts() async {
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

      switch (_currentFilter) {
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

      if (_posts.isEmpty) {
        // Aucun cache : afficher directement les posts réseau
        setState(() {
          _posts = newPosts;
          _loadedPostIds.addAll(loadedIds);
          _totalPostsLoaded = newPosts.length;
          _isFirstLoad = false;
        });
      } else {
        // Cache déjà affiché : ne pas remplacer les posts (évite le flash visible).
        // Prépendre uniquement les posts vraiment nouveaux (absents du cache).
        final alreadyShown = Set<String>.from(_loadedPostIds);
        final trulyNew = newPosts.where((p) => p.id != null && !alreadyShown.contains(p.id)).toList();
        setState(() {
          if (trulyNew.isNotEmpty) {
            _posts = [...trulyNew, ..._posts];
          }
          _loadedPostIds.addAll(loadedIds);
          _totalPostsLoaded = _posts.length;
          _isFirstLoad = false;
        });
      }

      print('✅ ${newPosts.length} posts chargés avec filtre: $_currentFilter');

      // Sauvegarder en cache pour le prochain lancement (contenu à jour)
      if (newPosts.isNotEmpty) {
        _saveFeedToCache();
      }

    } catch (e) {
      print('❌ Erreur chargement posts: $e');
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
    print('🌍 Chargement mode "Tous les pays" - limite: $limit');

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

    // Mélanger pour variété
    if (newPosts.length > 1) {
      newPosts.shuffle();
    }
  }

  Future<void> _loadMixedPostsSmart(Set<String> loadedIds, List<Post> newPosts, String userCountryCode, int limit) async {
    print('🔄 Chargement mode "Mix intelligent" - limite: $limit');

    // 1. Posts du pays utilisateur (40%)
    int countryPostsNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      userCountryCode,
      isInitialLoad: true,
      limit: countryPostsNeeded,
    );

    // 2. Posts ALL (40%)
    // int allPostsNeeded = (limit * 0.4).ceil();
    // await _loadAllCountriesPosts(
    //   loadedIds,
    //   newPosts,
    //   isInitialLoad: true,
    //   limit: allPostsNeeded,
    // );

    // 3. Posts autres pays (60%)
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
      print('❌ Erreur chargement pays $countryCode: $e');
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
      print('❌ Erreur chargement événements: $e');
    }
  }

  /// Ajoute les posts récupérés à [newPosts] avec dédup et mélange final.
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
    if (newPosts.length > 1) newPosts.shuffle();
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
      print('❌ Erreur chargement posts ALL: $e');
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
      print('❌ Erreur chargement autres pays: $e');
    }
  }

  // ===========================================================================
  // PAGINATION - CHARGEMENT MANUEL (Après les 20 posts background)
  // ===========================================================================

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMorePosts &&
        !_isLoadingBackground &&
        _hasMorePosts &&
        _totalPostsLoaded < _maxTotalPosts &&
        !_useBackgroundLoading) { // Seulement en mode manuel
      _loadMorePostsManually();
    }
  }

  Future<void> _loadMorePostsManually() async {
    if (_isLoadingMorePosts || _isLoadingBackground || !_hasMorePosts || _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _manualLoadLimit);

      // Ajouter les nouveaux posts
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
        });

        print('📱 ${newPosts.length} posts chargés manuellement (total: $_totalPostsLoaded)');
      }

      _hasMorePosts = newPosts.length >= (_manualLoadLimit ~/ 2);

      // Feed épuisé → injecter les anciens posts si disponibles
      if (!_hasMorePosts && _oldPostsCache.isNotEmpty) {
        _injectOldPostsAndResume();
      }

    } catch (e) {
      print('❌ Erreur chargement manuel: $e');
      _hasMorePosts = false;
      if (_oldPostsCache.isNotEmpty) _injectOldPostsAndResume();
    } finally {
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  Future<void> _loadMorePostsByFilter(Set<String> loadedIds, List<Post> newPosts, int limit) async {
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
  // CHARGEMENT DES DONNÉES SUPPLÉMENTAIRES (SÉPARÉ)
  // ===========================================================================

  Future<void> _loadAllAdditionalDataInParallel() async {
    // Charger tout en parallèle sans bloquer
    _loadSuggestedUsersInBackground();
    _loadArticlesInBackground();
    _loadCanauxInBackground();
    _loadChroniquesInBackground();
  }

  Future<void> _loadSuggestedUsersInBackground() async {
    if (_isLoadingSuggestedUsers) return;

    setState(() {
      _isLoadingSuggestedUsers = true;
    });

    try {
      final users = await userProvider.getProfileUsers(
        authProvider.loginUserData.id!,
        context,
        8, // Limité à 8 pour la performance
      );

      setState(() {
        _suggestedUsers = users..shuffle();
      });
      _saveFeedToCache();
    } catch (e) {
      print('Error loading suggested users: $e');
    } finally {
      setState(() {
        _isLoadingSuggestedUsers = false;
      });
    }
  }

  Future<void> _loadArticlesInBackground() async {
    if (_isLoadingArticles) return;

    setState(() {
      _isLoadingArticles = true;
    });

    try {
      final articleResults = await categorieProduitProvider.getArticleBooster(
          _selectedCountryCode?.toUpperCase() ?? 'TG'
      );

      setState(() {
        _articles = articleResults;
      });
      _saveFeedToCache();
    } catch (e) {
      print('Error loading articles: $e');
    } finally {
      setState(() {
        _isLoadingArticles = false;
      });
    }
  }

  Future<void> _loadCanauxInBackground() async {
    if (_isLoadingCanaux) return;

    setState(() {
      _isLoadingCanaux = true;
    });

    try {
      final canalResults = await postProvider.getCanauxHome();

      setState(() {
        _canaux = canalResults..shuffle();
      });
      _saveFeedToCache();
    } catch (e) {
      print('Error loading canaux: $e');
    } finally {
      setState(() {
        _isLoadingCanaux = false;
      });
    }
  }

  Future<void> _loadChroniquesInBackground() async {
    if (_isLoadingChroniques) return;
    setState(() => _isLoadingChroniques = true);
    try {
      final validChroniques = await FeedRepository().fetchChroniques(limit: 6);
      setState(() => _chroniques = validChroniques);
      if (validChroniques.isNotEmpty) {
        await _loadChroniqueUserDataInBackground(validChroniques);
      }
      _saveFeedToCache();
    } catch (e) {
      print('❌ Erreur chargement chroniques: $e');
    } finally {
      setState(() => _isLoadingChroniques = false);
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
      print('❌ Erreur chargement données chroniques: $e');
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
  Widget _buildPostWidget(Post post, double width, double height, int index) {
    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Container(
        child: Stack(
          children: [
            // Badge de disponibilité/pays (existant)
            // _buildAvailabilityBadge(post),

            // Contenu du post
            post.type == PostType.PRONOSTIC.name
                ? SizedBox.shrink()
                : post.type == PostType.CHALLENGEPARTICIPATION.name
                ? LookChallengePostWidget(post: post, height: height, width: width)
                : (post.type == PostType.POST.name && post.dataType == PostDataType.VIDEO.name)
                ? YouTubeVideoCard(
              post: post,
              index: index,
              onNeighborhoodPreload: _preloadVideoNeighborhood,
              currentFilterCountry: _currentFilter == 'ALL' || _currentFilter == 'MIXED' ? null : _selectedCountryCode,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoYoutubePageDetails(initialPost: post),
                  ),
                );
              },
            )
                : HomePostUsersWidget(
              index: index,
              post: post,
              color: _getRandomColor(),
              height: height * 0.6,
              width: width,
              isDegrade: true,
              currentFilterCountry: _currentFilter == 'ALL' || _currentFilter == 'MIXED' ? null : _selectedCountryCode,
            ),

          ],
        ),
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
    if (_isLoadingChroniques || _chroniques.isEmpty) {
      return SizedBox.shrink();
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
    final l10n = AppLocalizations.of(context);
    return FeedProfilesSection(
      users: _suggestedUsers,
      isLoading: _isLoadingSuggestedUsers,
      title: l10n.sectionDiscoverProfiles,
      seeAllLabel: l10n.commonSeeAll,
      onShowProfile: _showUserDetails,
    );
  }

  void _showUserDetails(UserData user) async {
    final users = await authProvider.getUserById(user.id!);
    if (users.isNotEmpty && mounted) {
      final w = MediaQuery.of(context).size.width;
      final h = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(users.first, w, h, context);
    }
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

  Widget _buildContent2() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    if (_isLoadingPosts && _posts.isEmpty) {
      return _buildLoadingShimmer(width, height);
    }

    if (_hasErrorPosts && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty) {
      return _buildEmptyWidget();
    }

    List<Widget> contentWidgets = [];

    // 1. Filtres
    contentWidgets.add(_buildFilterChips());
    contentWidgets.add(SizedBox(height: 8));

    // 2. Chroniques (si chargées)
    final chroniquesSection = _buildChroniquesSection();
    if (chroniquesSection is! SizedBox) {
      contentWidgets.add(chroniquesSection);
    }

    // 3. Profils utilisateurs (si chargés)
    final profilesSection = _buildProfilesSection();
    if (profilesSection is! SizedBox) {
      contentWidgets.add(profilesSection);
      contentWidgets.add(_buildAdMrec(key: 'ad_native_user'));

      contentWidgets.add(SizedBox(height: 8));
    }

    // 4. Posts avec bannières
    int postIndex = 0;
    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];
      if (postIndex == 0) {
        contentWidgets.add( const PronosticsCarouselWidget(),);
        // contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
      }
      // Ajouter le post
      contentWidgets.add(
        GestureDetector(
          onTap: () => _navigateToPostDetails(post),
          child: _buildPostWidget(post, width, height,i),
        ),
      );

      postIndex++;

      // 🔴 AJOUT DES BANNIÈRES ADMOB
      // Après le PREMIER post (postIndex == 1)
      if (postIndex == 2) {
        contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
        contentWidgets.add(TopDatingProfilesWidget());
        contentWidgets.add(RecentVIPContentWidget(),);


        // contentWidgets.add(_buildAdBanner(key: 'ad_list_post$postIndex'));
        // contentWidgets.add(_buildAdMrec(key: 'ad_native_post$postIndex'));
      }
// Top dating : après le premier post, puis tous les 5 posts
      //AJOUT DES BANNIÈRES ADMOB
      // if (postIndex == 2) {
      //   // contentWidgets.add(_buildAdBanner(key: 'ad_$postIndex'));
      //
      //   // contentWidgets.add(TopDatingProfilesWidget());
      // } else if (postIndex > 1 && (postIndex - 1) % 5 == 0) {
      //   contentWidgets.add(TopDatingProfilesWidget());
      // }
      // AdMOb Ensuite, tous les 3 posts (après le 4ème, 7ème, 10ème...)
      // if (postIndex > 1 && (postIndex - 1) % 3 == 0) {
      //   // contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
      //
      //   contentWidgets.add(TopDatingProfilesWidget());
      //   // contentWidgets.add(_buildAdBanner(key: 'ad_${postIndex}'));
      // }

      // Garder vos sections spéciales existantes
      if (postIndex % 3 == 0) {
        if (postIndex % 6 == 3) {
          final articlesSection = _buildArticlesSection();
          if (articlesSection is! SizedBox) {
            contentWidgets.add(articlesSection);

          }
        } else if (postIndex % 6 == 0) {
          final canauxSection = _buildCanauxSection();
          if (canauxSection is! SizedBox) {
            contentWidgets.add(canauxSection);
            contentWidgets.add(RecentVIPContentWidget(),);
            // contentWidgets.add(_buildAdBanner(key: 'ad_list_post$postIndex'));
            contentWidgets.add(_buildAdAdvertisement(key: 'ad_vert$postIndex'));

            // contentWidgets.add(_buildAdMrec(key: 'ad_native_post$postIndex'));

          }
        }
      }
    }
    // 5. Indicateurs de chargement/fin
    final colors = AppColors.of(context);
    if (_isLoadingMorePosts) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: colors.primary),
                SizedBox(height: 10),
                Text('Chargement de plus de posts...', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    } else if (_isLoadingBackground && _useBackgroundLoading) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Préparation de plus de contenu... ($_backgroundPostsLoaded/$_maxBackgroundPosts)',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_hasMorePosts && _oldPostsCache.isEmpty) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.flag, color: colors.primary, size: 36),
                SizedBox(height: 10),
                Text(
                  _getEndMessage(),
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'Revenez plus tard pour de nouveaux contenus',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_useBackgroundLoading) {
      // Bouton "Charger plus" quand le background est désactivé
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                Text(
                  'Chargement automatique terminé',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loadMorePostsManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: Text(
                    'Charger 5 posts de plus',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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



  Widget _buildContent() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    if (_isLoadingPosts && _posts.isEmpty) return _buildLoadingShimmer(width, height);
    if (_hasErrorPosts && _posts.isEmpty) return _buildErrorWidget();
    if (_posts.isEmpty) return _buildEmptyWidget();

    // ------------------------------------------------------------
    // 1. Construction du flux alterné (3 normaux → 2 anciens)
    // ------------------------------------------------------------
    List<Post> normalPosts = List.from(_posts);
    // Filet de sécurité : exclure tout post déjà présent dans le feed principal,
    // même si la race condition entre _startOldPostsLoading et _loadInitialPosts
    // a permis un chevauchement.
    List<Post> oldBuffer = _oldPostsCache
        .where((p) => p.id != null && !_loadedPostIds.contains(p.id))
        .toList();

    List<Post> finalPosts = [];

    const int normalBatchSize = 3;
    const int oldPerBatch = 2;

    int normalIndex = 0;

    while (normalIndex < normalPosts.length) {
      int end = normalIndex + normalBatchSize;

      if (end > normalPosts.length) {
        end = normalPosts.length;
      }

      finalPosts.addAll(
        normalPosts.sublist(normalIndex, end),
      );

      normalIndex = end;

      if (oldBuffer.isNotEmpty) {
        int take = oldPerBatch;

        if (take > oldBuffer.length) {
          take = oldBuffer.length;
        }

        finalPosts.addAll(
          oldBuffer.sublist(0, take),
        );

        oldBuffer.removeRange(0, take);
      }
    }

    if (oldBuffer.isNotEmpty) {
      finalPosts.addAll(oldBuffer);
    }

    // 🔥 Mémoriser la liste rendue pour le préchargement vidéo (index -> post)
    _renderedFeedPosts = finalPosts;

    // ------------------------------------------------------------
    // 2. Construction des widgets (filtrés, sections, posts, pub...)
    // ------------------------------------------------------------
    List<Widget> contentWidgets = [];

    contentWidgets.add(_buildFilterChips());
    contentWidgets.add(const SizedBox(height: 8));

    final chroniquesSection = _buildChroniquesSection();
    if (chroniquesSection is! SizedBox) contentWidgets.add(chroniquesSection);

    final profilesSection = _buildProfilesSection();
    if (profilesSection is! SizedBox) {
      contentWidgets.add(profilesSection);
      contentWidgets.add(_buildAdMrec(key: 'ad_native_user'));
      contentWidgets.add(const SizedBox(height: 8));
    }

    int postIndex = 0;
    for (int i = 0; i < finalPosts.length; i++) {
      final post = finalPosts[i];

      if (postIndex == 0) {
        contentWidgets.add(const PronosticsCarouselWidget());
      }

      contentWidgets.add(
        GestureDetector(
          onTap: () => _navigateToPostDetails(post),
          child: _buildPostWidget(post, width, height, i),
        ),
      );
      postIndex++;

      if (postIndex == 2) {
        contentWidgets.add(_buildAdAdvertisement(key: 'ad_after_first'));
        contentWidgets.add(const TopDatingProfilesWidget());
        // contentWidgets.add(const RecentVIPContentWidget());
      }

      if (postIndex % 3 == 0) {
        if (postIndex % 6 == 3) {
          final articlesSection = _buildArticlesSection();
          if (articlesSection is! SizedBox) contentWidgets.add(articlesSection);
        } else if (postIndex % 6 == 0) {
          final canauxSection = _buildCanauxSection();
          if (canauxSection is! SizedBox) {
            contentWidgets.add(const RecentVIPContentWidget());
            contentWidgets.add(canauxSection);
            // contentWidgets.add(_buildAdAdvertisement(key: 'ad_vert$postIndex'));
          }
        }
      }
    }

    // Indicateurs de fin / chargement
    if (_isLoadingMorePosts) {
      contentWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: primaryGreen),
                SizedBox(height: 10),
                Text('Chargement de plus de posts...', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    } else if (_isLoadingBackground && _useBackgroundLoading) {
      contentWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Préparation de plus de contenu... ($_backgroundPostsLoaded/$_maxBackgroundPosts)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_hasMorePosts && _oldPostsCache.isEmpty) {
      final colors2 = AppColors.of(context);
      contentWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.flag, color: colors2.primary, size: 36),
                const SizedBox(height: 10),
                Text(
                  _getEndMessage(),
                  style: TextStyle(color: colors2.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Text(
                  'Revenez plus tard pour de nouveaux contenus',
                  style: TextStyle(color: colors2.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_useBackgroundLoading) {
      contentWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                const Text(
                  'Chargement automatique terminé',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loadMorePostsManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: const Text('Charger 5 posts de plus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      );
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
  }
  // 🔥 NOUVELLE MÉTHODE UTILITAIRE
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
  Future<void> _recordPostView3(Post post) async {

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
        print(
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

      PostViewService.recordAuthorView(post, currentUserId);
      print('✅ Vue comptée pour post ${post.id} par $currentUserId');



    } catch (e) {
      print('Error recording post view: $e');
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
      print('✅ Total interactions +1 pour le post ${post.id} (première vue de la session)');
    } else {
      print('⏭️ Interaction déjà comptée dans cette session pour le post ${post.id}');
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
      print('⏭️ Post ${post.id} déjà vu aujourd\'hui par $currentUserId - Vue NON comptée');

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

      print('✅ Vue comptée pour post ${post.id} par $currentUserId le $todayDate');

    } catch (e) {
      print('Error recording post view: $e');
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
      print('Error recording post view: $e');
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
    } else {
      _setUserOffline();
    }
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
                _buildContent(),
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

