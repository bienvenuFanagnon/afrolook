import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'dart:math';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/home/unitePostPage/chronique_section.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../../services/utils/abonnement_utils.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../chronique/chroniqueform.dart';
import '../component/showUserDetails.dart';
import '../../providers/authProvider.dart';
import 'package:shimmer/shimmer.dart';
import '../listeUserLikepage.dart';
import '../postDetailsVideo.dart';
import '../pronostics/pronostics_carousel_widget.dart';

import '../user/userAbonnementPage.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../providers/mixed_feed_service_provider.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import '../userPosts/youTube_video_card.dart';
import '../userPosts/video_preload_manager.dart';
import '../../providers/sound_provider.dart';
import 'feed_cache_service.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../services/postService/post_view_service.dart';
import '../../widgets/feed/sections/feed_articles_section.dart';
import '../../widgets/feed/sections/shop_promo_feed_widget.dart';
import '../../widgets/feed/sections/feed_canaux_section.dart';
import '../../widgets/feed/sections/active_creators_section_widget.dart';
import '../contenuPayant/recent_vip_content_widget.dart';
import '../contenuPayant/widgets/boosted_content_strip.dart';
import '../../widgets/feed/sections/feed_profiles_section.dart';
import '../../widgets/feed/sections/feed_state_widgets.dart';
import '../../widgets/feed/sections/feed_filter_bar.dart';
import '../../widgets/feed/sections/feed_ad_widgets.dart';
import '../../services/feed/feed_repository.dart';
import '../../widgets/feed/weekly_top_creators_widget.dart';
import '../../widgets/feed/sections/weekly_top_commentators_widget.dart';
import '../../widgets/feed/sections/weekly_top_posts_section_widget.dart';

import '../dating/widgets/top_dating_profiles_widget.dart';


// Constantes de couleur
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Colors.black;
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
const Color accentYellow = Color(0xFFFFD700);

// Types disponibles basés sur votre enum TabBarType
const List<String> availablePostTypes = [
  'ACTUALITES',
  'LOOKS',
  'SPORT',
  'EVENEMENT',
  'OFFRES',
  'GAMER'
];

class HomeSportPostPage extends StatefulWidget {
  final String type;
  final String? sortType;

  HomeSportPostPage({super.key, required this.type, this.sortType});

  @override
  State<HomeSportPostPage> createState() => _HomeSportPostPageState();
}

class _HomeSportPostPageState extends State<HomeSportPostPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Providers
  late UserAuthProvider authProvider;
  late UserShopAuthProvider authProviderShop;
  late CategorieProduitProvider categorieProduitProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  late MixedFeedServiceProvider mixedFeedProvider;

  // Contrôleurs
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  // Variables d'état pour les posts
  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  bool _hasErrorPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  bool _isLoadingBackground = false;

  // Système hybride de chargement
  Set<String> _loadedPostIds = Set();
  int _totalPostsLoaded = 0;
  int _backgroundPostsLoaded = 0;
  final int _initialLimit = 3;
  final int _backgroundLoadLimit = 8;
  final int _manualLoadLimit = 8;

  // === Pool de widgets rotatifs (1 widget par slot, intervalle 4 posts) ===
  static const List<String> _kPoolOrder = [
    'BoostedContent', 'WeeklyTopCreators', 'Canaux', 'VIPContent', 'Articles',
  ];
  final int _maxBackgroundPosts = 20;
  final int _maxTotalPosts = 1000;
  Timer? _backgroundLoadTimer;
  bool _useBackgroundLoading = true;

  // Filtrage par pays
  String? _selectedCountryCode;
  // String _currentFilter = 'MIXED';
  String _currentFilter = 'ALL';
  bool _isFirstLoad = true;

  // Filtrage par type (le paramètre principal de cette page)
  String _selectedPostType = 'ACTUALITES';

  // Données supplémentaires
  List<ArticleData> _articles = [];
  bool _isLoadingArticles = false;

  List<Canal> _canaux = [];
  bool _isLoadingCanaux = false;


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

  Timer? _stayTimer;
  bool _isPageVisible = true;
  bool _isSupportDialogShowing = false;
  String? _lastPopupDateKey = 'last_support_ad_popup_date';

  List<Post> _oldPostsCache = [];
  bool _isLoadingOldPosts = false;

  // Cache des fenêtres mensuelles déjà testées et trouvées vides (Session 9/14)
  final Set<DateTime> _emptyOldPostsWindows = {};

  // Liste des posts rendus (mix posts + anciens) pour le préchargement vidéo (Session 14)
  List<Post> _renderedFeedPosts = [];

  late SoundProvider _soundProvider;

  Timer? _oldPostsLoadTimer;

  // Animation
  late AnimationController _starController;
  late AnimationController _unlikeController;

  // Utilitaires
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTitleIndex = 0;
  Timer? _titleTimer;

  void _startTitleAnimation() {
    _titleTimer?.cancel();
    _titleTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (mounted && _selectedPostType == 'SPORT') {
        setState(() {
          _currentTitleIndex = (_currentTitleIndex + 1) % _sportTitles.length;
        });
      }
    });
  }
  late SharedPreferences _prefs;
  final String _lastViewDatePrefix = 'last_view_date_';

  // 🔥 NOUVELLE MÉTHODE
  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }


  @override
  void initState() {
    super.initState();
    // 🔥 Initialisation du MediaPlaybackManager avec l'instance globale
    // (même instance que l'AppBar / YouTubeVideoCard / AudioPostCard, Session 8)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _soundProvider = Provider.of<SoundProvider>(context, listen: false);
      MediaPlaybackManager.init(_soundProvider);
    });
    _initSharedPreferences();

    _startTitleAnimation();
    _sportTitles.shuffle();

    // Initialiser le type de post
    _selectedPostType = widget.type.toUpperCase();

    // Initialisation des providers
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
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
// Ajoutez cette méthode pour les titres sportifs dynamiques
  String _getSportTitle() {
    if (_selectedPostType != 'SPORT') return _selectedPostType;

    List<String> sportTitles = [
      '⚽ Actualité du football',
      '🏆 Ligue des Champions',
      '⚡ Transferts et rumeurs',
      '⭐ Mbappé, Messi, Ronaldo...',
      '🌍 CAN 2024',
      '🇫🇷 Équipe de France',
      '🏟️ Résultats en direct',
      '🎯 Tops buteurs',
    ];
    return sportTitles[_random.nextInt(sportTitles.length)];
  }

// Ajoutez cette méthode pour les sous-titres
  String _getSportSubtitle() {
    if (_selectedPostType != 'SPORT') return _getFilterDescription();

    List<String> sportSubtitles = [
      'Toute l\'actu foot en direct',
      'Analyses et débats sportifs',
      'Les stars du ballon rond',
      'Matchs et compétitions',
      'Mercato et transferts',
      'Exclu interviews',
    ];
    return sportSubtitles[_random.nextInt(sportSubtitles.length)];
  }

// Ajoutez cette méthode pour les hashtags
  Widget _buildSportTags() {
    List<String> tags = [
      '#Football', '#LDC', '#Ligue1', '#PremierLeague',
      '#Liga', '#Basketball', '#NBA', '#Handball',
      '#LigueAfricaine', '#LigueEuropa', '#ChampionsLeague',
    ];

    // Mélanger pour variété
    tags.shuffle();
    tags = tags.take(6).toList(); // Garder 6 tags

    return Container(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Text(
              tags[index],
              style: TextStyle(color: Colors.green, fontSize: 11),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _backgroundLoadTimer?.cancel();
    _oldPostsLoadTimer?.cancel();
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

    _stopStayTimer();
    _stayTimer = Timer(const Duration(seconds: 5), () {
      printVm('⏱️ [Timer] Timer déclenché après 5 secondes');
      _checkAndShowSupportPopup();
    });
    printVm('⏱️ [Timer] Timer démarré (10s)');
  }
  void _stopStayTimer() {
    if (_stayTimer != null && _stayTimer!.isActive) {
      _stayTimer!.cancel();
      printVm('⏱️ [Timer] Timer annulé');
    }
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

    printVm('🔔 [Popup] Affichage du popup...');
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
            Icon(Icons.volunteer_activism, color: primaryGreen, size: 24),
            const SizedBox(width: 8),
            Text(l10n.supportTitle, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.supportMessage,
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
                          l10n.supportBecomePremium,
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          l10n.supportPremiumPrice,
                          style: TextStyle(color: accentYellow, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.supportPremiumDesc,
                          style: TextStyle(color: colors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                MaterialPageRoute(builder: (context) =>  AbonnementScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentYellow,
              foregroundColor: colors.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(l10n.profileSubscribe, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isSupportDialogShowing = false;
              _showInterstitialAd();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(l10n.supportWatchAd, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _showInterstitialAd() {
    // interstitiel supprimé du feed
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
    // Précharger les top créateurs et top commentateurs en parallèle
    WeeklyTopCreatorsWidget.preload();
    WeeklyTopCommentatorsWidget.preload();

    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    printVm('Pays utilisateur détecté: ${_selectedCountryCode}');
    printVm('Type de post sélectionné: $_selectedPostType');

    // 2. Par défaut: filtre sur le pays de l'utilisateur (Session 11/14),
    // fallback sur "Tous" si pays inconnu.
    if (_selectedCountryCode != null) {
      _currentFilter = 'COUNTRY';
    } else {
      _currentFilter = 'ALL';
    }
    _isFirstLoad = true;
    _useBackgroundLoading = true;
    _backgroundPostsLoaded = 0;

    // 0. 🔥 Affichage instantané depuis le cache local (Facebook-style)
    final bool hasCachedPosts = await _loadFromCacheAndDisplay();

    // 3. Réinitialiser la pagination sans effacer les posts déjà affichés
    // depuis le cache (Session 12 fix).
    _resetPagination(clearPosts: !hasCachedPosts);
    _startOldPostsLoading();

    if (hasCachedPosts) {
      // Affichage déjà assuré par le cache : réseau en arrière-plan sans
      // bloquer le premier paint.
      _loadInitialPosts();
      _startBackgroundLoading();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllAdditionalDataInParallel();
      });
    } else {
      await _loadInitialPosts();
      _startBackgroundLoading();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllAdditionalDataInParallel();
      });
    }
  }

  void _resetPagination({bool clearPosts = true}) {
    if (clearPosts) {
      _posts.clear();
      _loadedPostIds.clear();
    }
    _totalPostsLoaded = 0;
    _backgroundPostsLoaded = 0;
    _hasMorePosts = true;
    _isLoadingMorePosts = false;
    _isLoadingBackground = false;
  }

  // ===========================================================================
  // CACHE LOCAL DU FEED (affichage instantané "Facebook-style") - Session 14
  // ===========================================================================

  /// Clé de cache unique pour le feed Sport : type + sortType + filtre +
  /// code pays, pour éviter toute collision avec HomeConstPost.dart.
  String get _feedCacheKey => FeedCacheService.buildKey(
      widget.type, '${widget.sortType ?? 'default'}_${_currentFilter}_${_selectedCountryCode ?? 'none'}');

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

      // --- Produits boostés / articles ---
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

      if (!mounted) return cachedPosts.isNotEmpty;

      setState(() {
        if (cachedPosts.isNotEmpty) {
          _posts = cachedPosts;
          _loadedPostIds.addAll(cachedPosts.map((p) => p.id ?? '').where((id) => id.isNotEmpty));
          _totalPostsLoaded = cachedPosts.length;
          _isFirstLoad = false;
          _isLoadingPosts = false;
        }
        if (cachedChroniques.isNotEmpty) {
          _chroniques = cachedChroniques;
        }
        if (cachedCanaux.isNotEmpty) {
          _canaux = cachedCanaux;
        }
        if (cachedArticles.isNotEmpty) {
          _articles = cachedArticles;
        }
      });

      printVm('⚡ Feed Sport affiché instantanément depuis le cache local ($_feedCacheKey)');
      return cachedPosts.isNotEmpty;
    } catch (e) {
      printVm('⚠️ Erreur _loadFromCacheAndDisplay (Sport): $e');
      return false;
    }
  }

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
          if (map['createdAt'] is Timestamp) {
            map['createdAt'] = (map['createdAt'] as Timestamp).toDate().toIso8601String();
          }
          if (map['expiresAt'] is Timestamp) {
            map['expiresAt'] = (map['expiresAt'] as Timestamp).toDate().toIso8601String();
          }
          return map;
        }).toList();

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


      if (_canaux.isNotEmpty) {
        data['canaux'] = _canaux.map((c) => c.toJson()).toList();
      }

      if (_articles.isNotEmpty) {
        data['articles'] = _articles.map((a) => a.toJson()).toList();
      }

      if (data.isEmpty) return;

      await FeedCacheService.saveFeedData(_feedCacheKey, data);
    } catch (e) {
      printVm('⚠️ Erreur _saveFeedToCache (Sport): $e');
    }
  }

  // ===========================================================================
  // SYSTÈME HYBRIDE DE CHARGEMENT
  // ===========================================================================

  void _startBackgroundLoading() {
    if (!_useBackgroundLoading) return;

    _backgroundLoadTimer?.cancel();

    printVm('🚀 Démarrage du chargement background pour $_selectedPostType');

    _backgroundLoadTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (_useBackgroundLoading &&
          !_isLoadingBackground &&
          !_isLoadingMorePosts &&
          _hasMorePosts &&
          _backgroundPostsLoaded < _maxBackgroundPosts &&
          _totalPostsLoaded < _maxTotalPosts &&
          !_isUserScrolling()) {
        await _loadBackgroundPosts();
      }

      if (_backgroundPostsLoaded >= _maxBackgroundPosts ||
          !_hasMorePosts ||
          !_useBackgroundLoading) {
        printVm('⏹️ Arrêt du chargement background');
        timer.cancel();
        _useBackgroundLoading = false;
      }
    });
  }

  bool _isUserScrolling() {
    // Vérifier si le controller est attaché avant d'accéder à position
    if (!_scrollController.hasClients) {
      return false; // Pas encore attaché, donc l'utilisateur ne scroll pas
    }

    try {
      return _scrollController.position.isScrollingNotifier.value;
    } catch (e) {
      printVm('Erreur isUserScrolling: $e');
      return false;
    }
  }

  Future<void> _loadBackgroundPosts() async {
    if (_isLoadingBackground ||
        !_hasMorePosts ||
        _backgroundPostsLoaded >= _maxBackgroundPosts ||
        _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    printVm('🔄 Chargement background...');

    setState(() {
      _isLoadingBackground = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _backgroundLoadLimit);

      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
          _backgroundPostsLoaded += newPosts.length;
        });

        printVm('✅ ${newPosts.length} posts chargés en background');
      }

      _hasMorePosts = newPosts.length >= (_backgroundLoadLimit ~/ 2);

      if (_backgroundPostsLoaded >= _maxBackgroundPosts) {
        _useBackgroundLoading = false;
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
  // FILTRES PAR PAYS
  // ===========================================================================

  void _showCountryFilterModal() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            List<AfricanCountry> filteredCountries = AfricanCountry.allCountries
                .where((country) {
              if (searchQuery.isEmpty) return true;
              return country.name.toLowerCase().contains(searchQuery) ||
                  country.code.toLowerCase().contains(searchQuery) ||
                  country.name?.toLowerCase().contains(searchQuery) == true;
            }).toList();

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

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickFilterOption(
                            icon: Icons.public,
                            label: l10n.feedAllFilter,
                            isSelected: _currentFilter == 'ALL',
                            color: primaryGreen,
                            onTap: () async {
                              Navigator.pop(context);
                              await _applyFilter(filterType: 'ALL', countryCode: null);
                            },
                          ),
                          SizedBox(width: 8),

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

                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: Icons.blender,
                              label: l10n.feedMixFilter,
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

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: colors.border, thickness: 1),
                  ),

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

                  Expanded(
                    child: _buildCountryList(filteredCountries, searchQuery),
                  ),

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
                color: isSelected ? colors.onPrimary : colors.textPrimary,
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
                  l10n.feedTryAnotherSearch,
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
                        color: colors.surface.withOpacity(0.5),
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
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.feedYourCountry,
                                    style: TextStyle(
                                      color: Colors.green,
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
    _backgroundLoadTimer?.cancel();

    setState(() {
      _currentFilter = filterType;
      if (countryCode != null) {
        _selectedCountryCode = countryCode.toUpperCase();
      }
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true;
      _backgroundPostsLoaded = 0;
    });

    _resetPagination();
    await _loadInitialPosts();

    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });

    printVm('✅ Filtre appliqué: $_currentFilter - Pays: $_selectedCountryCode - Type: $_selectedPostType');
  }
  void _showTypeFilterModal() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final TextEditingController searchController = TextEditingController();
            String searchQuery = '';

            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            // Filtrer les types selon la recherche
            List<String> filteredTypes = availablePostTypes
                .where((type) => searchQuery.isEmpty ||
                type.toLowerCase().contains(searchQuery))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
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
                            l10n.feedChooseType,
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

                  // Barre de recherche
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
                                hintText: l10n.feedSearchType,
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

                  // Titre liste
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          l10n.feedAvailableTypes,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${filteredTypes.length} ${l10n.feedTypesSuffix}',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // Liste des types
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: filteredTypes.length,
                      itemBuilder: (context, index) {
                        final type = filteredTypes[index];
                        final isSelected = _selectedPostType == type;

                        return _buildTypeOption(
                          type: type,
                          isSelected: isSelected,
                          onTap: () => _applyTypeFilter(type),
                        );
                      },
                    ),
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
  Future<void> _applyTypeFilter(String newType) async {
    // Arrêter le chargement background pendant le changement de filtre
    _backgroundLoadTimer?.cancel();

    printVm('🔄 Changement de type: $_selectedPostType -> $newType');

    setState(() {
      _selectedPostType = newType;
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true;
      _backgroundPostsLoaded = 0;
    });

    // Réinitialiser la pagination
    _resetPagination();

    // Charger les posts initiaux avec le nouveau type
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });

    printVm('✅ Type changé: $newType');
  }
  Widget _buildTypeOption({
    required String type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // Fermer le modal
            onTap(); // Appliquer le filtre
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple.withOpacity(0.2) : colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _getTypeIcon(type),
                      color: isSelected ? Colors.purple : colors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getTypeDescription(type),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.purple, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeDescription(String type) {
    switch (type.toUpperCase()) {
      case 'ACTUALITES':
        return 'Actualités et informations';
      case 'LOOKS':
        return 'Mode, style et looks';
      case 'SPORT':
        return 'Sports et compétitions';
      case 'EVENEMENT':
        return 'Événements et manifestations';
      case 'OFFRES':
        return 'Offres et promotions';
      case 'GAMER':
        return 'Jeux vidéo et e-sport';
      default:
        return 'Contenu de type $type';
    }
  }
  // ===========================================================================
  // CHARGEMENT DES POSTS AVEC FILTRES TYPE + PAYS
  // ===========================================================================

  Future<void> _loadInitialPosts() async {
    try {
      // Session 12 fix : ne remettre _isLoadingPosts à true que si on n'a
      // encore aucun post affiché (cache ou précédent) - sinon le skeleton
      // ne doit pas réapparaître pendant le rafraîchissement réseau.
      if (_posts.isEmpty) {
        setState(() {
          _isLoadingPosts = true;
          _hasErrorPosts = false;
        });
      } else {
        setState(() {
          _hasErrorPosts = false;
        });
      }

      Set<String> loadedIds = Set();
      List<Post> newPosts = [];

      int limit = _initialLimit;

      switch (_currentFilter) {
        case 'ALL':
          await _loadPostsWithTypeAndCountry(
            loadedIds,
            newPosts,
            postType: _selectedPostType,
            countryCode: null, // Tous les pays
            isInitialLoad: true,
            limit: limit,
          );
          break;

        case 'COUNTRY':
          if (_selectedCountryCode != null) {
            await _loadPostsWithTypeAndCountry(
              loadedIds,
              newPosts,
              postType: _selectedPostType,
              countryCode: _selectedCountryCode,
              isInitialLoad: true,
              limit: limit,
            );
            // Compléter avec les autres pays si pas assez de posts (Session 11)
            if (newPosts.length < limit) {
              await _loadPostsWithTypeAndCountry(
                loadedIds,
                newPosts,
                postType: _selectedPostType,
                countryCode: null,
                isInitialLoad: true,
                limit: limit - newPosts.length,
              );
            }
          }
          break;

        case 'MIXED':
          if (_selectedCountryCode != null) {
            await _loadMixedPostsWithType(loadedIds, newPosts, limit);
          }
          break;

        case 'CUSTOM':
          if (_selectedCountryCode != null) {
            await _loadPostsWithTypeAndCountry(
              loadedIds,
              newPosts,
              postType: _selectedPostType,
              countryCode: _selectedCountryCode,
              isInitialLoad: true,
              limit: limit,
            );
          }
          break;
      }

      setState(() {
        _posts = newPosts;
        _loadedPostIds.addAll(loadedIds);
        _totalPostsLoaded = newPosts.length;
        _isFirstLoad = false;
      });

      if (newPosts.isNotEmpty) {
        _saveFeedToCache();
      }

      printVm('✅ ${newPosts.length} posts chargés avec filtre: $_currentFilter - Type: $_selectedPostType');

    } catch (e) {
      printVm('❌ Erreur chargement posts: $e');
      setState(() {
        _hasErrorPosts = true;
      });
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  // Méthode principale pour charger les posts avec type et pays
  Future<void> _loadPostsWithTypeAndCountry(
      Set<String> loadedIds,
      List<Post> newPosts, {
        required String postType,
        String? countryCode,
        bool isInitialLoad = false,
        int limit = 5,
      }) async {
    if (limit <= 0) return;
    try {
      final excluded = {...loadedIds, ..._loadedPostIds};
      List<Post> posts;
      if (countryCode != null && countryCode.isNotEmpty) {
        posts = await FeedRepository().fetchCountryPosts(
          countryCode,
          excluded,
          limit: limit,
          tabbarType: postType,
        );
      } else {
        posts = await FeedRepository().fetchRecentPosts(
          excluded,
          limit: limit,
          tabbarType: postType,
        );
      }
      _addFetchedToList(posts, loadedIds, newPosts, limit);
    } catch (e) {
      printVm('❌ Erreur chargement posts: $e');
    }
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
    if (newPosts.length > 1) newPosts.shuffle();
  }

  Widget _buildAdAdvertisement({required String key}) => FeedAdCarousel(adKey: key);
  Widget _buildAdBanner({required String key}) => FeedAdBanner(adKey: key);
  Widget _buildAdNative({required String key}) => FeedAdMrec(adKey: key);
  // Méthode pour les posts MIXED (mélange intelligent)
  Future<void> _loadMixedPostsWithType(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    printVm('🔄 Chargement mode "Mix" avec type: $_selectedPostType');
    printVm('🔄 Chargement mode "Mix" avec type et pays: $_selectedCountryCode');

    if (_selectedCountryCode == null) return;

    // 1. Posts du pays utilisateur (60%)
    int countryPostsNeeded = (limit * 0.6).ceil();
    await _loadPostsWithTypeAndCountry(
      loadedIds,
      newPosts,
      postType: _selectedPostType,
      countryCode: _selectedCountryCode,
      isInitialLoad: true,
      limit: countryPostsNeeded,
    );

    // 2. Posts ALL (40%)
    int allPostsNeeded = limit - newPosts.length;
    if (allPostsNeeded > 0) {
      await _loadPostsWithTypeAndCountry(
        loadedIds,
        newPosts,
        postType: _selectedPostType,
        countryCode: null, // Tous les pays
        isInitialLoad: true,
        limit: allPostsNeeded,
      );
    }
  }

  // ===========================================================================
  // PAGINATION - CHARGEMENT MANUEL
  // ===========================================================================

  void _scrollListener() {
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

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _manualLoadLimit);

      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
          // Fenêtre mémoire : max 40 posts
          if (_posts.length > 40) {
            _posts.removeRange(0, 8);
          }
        });

        printVm('📱 ${newPosts.length} posts chargés manuellement');
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

  Future<void> _loadMorePostsByFilter(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    switch (_currentFilter) {
      case 'ALL':
        await _loadPostsWithTypeAndCountry(
          loadedIds,
          newPosts,
          postType: _selectedPostType,
          countryCode: null,
          isInitialLoad: false,
          limit: limit,
        );
        break;

      case 'COUNTRY':
        if (_selectedCountryCode != null) {
          await _loadPostsWithTypeAndCountry(
            loadedIds,
            newPosts,
            postType: _selectedPostType,
            countryCode: _selectedCountryCode,
            isInitialLoad: false,
            limit: limit,
          );
        }
        break;

      case 'MIXED':
        await _loadMixedPostsWithType(loadedIds, newPosts, limit);
        break;

      case 'CUSTOM':
        if (_selectedCountryCode != null) {
          await _loadPostsWithTypeAndCountry(
            loadedIds,
            newPosts,
            postType: _selectedPostType,
            countryCode: _selectedCountryCode,
            isInitialLoad: false,
            limit: limit,
          );
        }
        break;
    }
  }

  // ===========================================================================
  // CHARGEMENT DES DONNÉES SUPPLÉMENTAIRES
  // ===========================================================================

  Future<void> _loadAllAdditionalDataInParallel() async {
    _loadArticlesInBackground();
    _loadCanauxInBackground();
    _loadChroniquesInBackground();
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
      printVm('Error loading articles: $e');
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
      printVm('Error loading canaux: $e');
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
      printVm('❌ Erreur chargement chroniques: $e');
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
                    builder: (context) => VideoYoutubePageDetails(initialPost: post),
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
  // SECTIONS SUPPLÉMENTAIRES
  // ===========================================================================

  Widget _buildChroniquesSection() {
    if (_isLoadingChroniques) {
      return _buildLoadingSection('📝 Chroniques récentes');
    }

    if (_chroniques.isEmpty) {
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

  Widget _buildCreatorsSection() => const ActiveCreatorsSectionWidget();

  void _showUserDetails(UserData user) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    showUserDetailsModalDialog(user, w, h, context);
  }

  Widget _buildArticlesSection() {
    return FeedArticlesSection(
      articles: _articles,
      isLoading: _isLoadingArticles,
      title: '🔥 Produits Boostés',
      seeMoreLabel: 'Boutiques',
    );
  }

  Widget _buildCanauxSection() {
    return FeedCanauxSection(
      canaux: _canaux,
      isLoading: _isLoadingCanaux,
      title: '📺 Afrolook Canal',
      seeMoreLabel: 'Voir plus',
    );
  }

  Widget _buildLoadingSection(String title) => FeedSectionLoader(title: title);

  // ===========================================================================
  // CONTENU PRINCIPAL
  // ===========================================================================

  /// Choisit une fenêtre mensuelle aléatoire (pondérée) en évitant si possible
  /// les fenêtres déjà connues comme vides (Session 9/14).
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

    return candidate!;
  }

  /// Exécute la requête Firestore pour une fenêtre mensuelle donnée et
  /// retourne les posts valides trouvés (sans les ajouter au cache).
  Future<List<Post>> _fetchOldPostsForWindow(DateTime startDate) async {
    final DateTime endDate = DateTime(startDate.year, startDate.month + 1, 1);

    final int startMicros = startDate.microsecondsSinceEpoch;
    final int endMicros = endDate.microsecondsSinceEpoch;

    printVm("📜 Chargement anciens posts entre $startDate et $endDate");

    Query query = _firestore.collection('Posts');

    query = query
        .where("typeTabbar", isEqualTo: _selectedPostType)
        .where("created_at", isGreaterThanOrEqualTo: startMicros)
        .where("created_at", isLessThan: endMicros)
        .orderBy("created_at")
        .limit(30); // on prend large pour filtrer ensuite

    final snapshot = await query.get();

    if (snapshot.docs.isEmpty) {
      printVm("⚠️ Aucun post trouvé dans cette période");
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

        printVm("↩️ Fenêtre vide, tentative de repli (${attempt + 1}/${maxFallbacks + 1})");
      }

      if (validOldPosts.isNotEmpty) {
        validOldPosts.shuffle();

        _oldPostsCache.addAll(validOldPosts);

        printVm(
          "✅ ${validOldPosts.length} anciens posts ajoutés (cache: ${_oldPostsCache.length})",
        );
      } else {
        printVm("⚠️ Aucun post valide après filtrage (toutes les tentatives vides)");
      }
    } catch (e) {
      printVm("❌ Erreur chargement anciens posts: $e");
    } finally {
      _isLoadingOldPosts = false;
    }
  }

  void _startOldPostsLoading() {
    _oldPostsLoadTimer?.cancel();
    _oldPostsLoadTimer = Timer.periodic(Duration(seconds: 22), (timer) {
      if (_oldPostsCache.length < 4 && !_isLoadingOldPosts) {
        _loadOldPostsInBackground();
      }
    });
    // Premier chargement immédiat
    _loadOldPostsInBackground();
  }

  /// 🔥 Préchargement Facebook-style (Session 6/14) : appelé par
  /// `YouTubeVideoCard` quand elle devient visible. Précharge les vidéos
  /// voisines et nettoie les contrôleurs hors-champ.
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
    List<Post> oldBuffer = List.from(_oldPostsCache);

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

    // 🔥 Mise à jour de la liste rendue pour le préchargement vidéo (Session 6/14)
    _renderedFeedPosts = finalPosts;

    // ------------------------------------------------------------
    // 2. Construction des widgets (filtrés, sections, posts, pub...)
    // ------------------------------------------------------------
    List<Widget> contentWidgets = [];

    contentWidgets.add(_buildFilterChips());
    contentWidgets.add(const SizedBox(height: 8));

    final chroniquesSection = _buildChroniquesSection();
    if (chroniquesSection is! SizedBox) contentWidgets.add(chroniquesSection);

    if (finalPosts.isNotEmpty) {
      contentWidgets.add(const PronosticsCarouselWidget());
    }

    // AfroShop promo — lundi (1) et jeudi (4)
    final _sportWeekday = DateTime.now().weekday;
    if ((_sportWeekday == DateTime.monday || _sportWeekday == DateTime.thursday) &&
        _articles.isNotEmpty) {
      contentWidgets.add(
        ShopPromoFeedWidget(articles: _articles, isFirstPosition: true),
      );
    }

    for (int i = 0; i < finalPosts.length; i++) {
      final post = finalPosts[i];

      contentWidgets.add(
        RepaintBoundary(
          child: GestureDetector(
            onTap: () => _navigateToPostDetails(post),
            child: _buildPostWidget(post, width, height, i),
          ),
        ),
      );

      // Après le 2ème post : classement hebdo commentateurs (visible toute la semaine)
      if (i == 1) {
        contentWidgets.add(const WeeklyTopCommentatorsWidget());
      }

      // Pub toutes les 4 posts — toujours affichée
      final postNumber = i + 1;
      if (postNumber % 4 == 0) {
        final slotN = postNumber ~/ 4 - 1;
        contentWidgets.add(_buildUnifiedAdSlot(key: 'ad_slot_$slotN'));
      }
      // Slot découverte toutes les 6 posts — fallback pub si le widget est vide
      if (postNumber % 6 == 0) {
        final poolCount = postNumber ~/ 6 - 1;
        final poolIdx = poolCount % _kPoolOrder.length;
        contentWidgets.add(_buildPoolOrAd(_kPoolOrder[poolIdx], 'pool_slot_$poolCount'));
      }
    }

    if (_isLoadingMorePosts) {
      contentWidgets.add(_buildShimmerPost());
      contentWidgets.add(_buildShimmerPost());
      contentWidgets.add(_buildShimmerPost());
    } else if (!_hasMorePosts) {
      contentWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.flag, color: Colors.green, size: 36),
                const SizedBox(height: 10),
                Text(
                  _getEndMessage(),
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Revenez plus tard pour de nouveaux contenus',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
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
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          SizedBox(height: 12),
          Text(l10n.commonLoadingError, style: TextStyle(color: colors.textPrimary, fontSize: 14)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text(l10n.commonRetry, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final l10n = AppLocalizations.of(context);
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
            child: Text(l10n.commonRefresh, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    String typeMsg = ' de type $_selectedPostType';

    switch (_currentFilter) {
      case 'ALL':
        return 'Aucun contenu disponible pour tous les pays$typeMsg';
      case 'COUNTRY':
        return 'Aucun contenu disponible en ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      case 'MIXED':
        return 'Aucun contenu disponible pour le moment$typeMsg';
      case 'CUSTOM':
        return 'Aucun contenu disponible pour ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      default:
        return 'Aucun contenu disponible$typeMsg';
    }
  }

  String _getEndMessage() {
    String typeMsg = ' de type $_selectedPostType';

    switch (_currentFilter) {
      case 'ALL':
        return 'Vous avez vu tous les contenus disponibles$typeMsg';
      case 'COUNTRY':
        return 'Fin des contenus en ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      case 'MIXED':
        return 'Fin des contenus pour le mix actuel$typeMsg';
      case 'CUSTOM':
        return 'Fin des contenus pour ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      default:
        return 'Fin des contenus$typeMsg';
    }
  }

  String _getFilterDescription() {
    String countryDesc = '';
    String typeDesc = 'Type: $_selectedPostType';

    switch (_currentFilter) {
      case 'ALL':
        countryDesc = '🌍 Tous les pays';
        break;
      case 'COUNTRY':
        countryDesc = '📍 ${_selectedCountryCode ?? "Mon pays"}';
        break;
      case 'MIXED':
        countryDesc = '🔄 Mix intelligent';
        break;
      case 'CUSTOM':
        countryDesc = '⚙️ ${_selectedCountryCode ?? "Pays spécifique"}';
        break;
      default:
        countryDesc = 'Filtrer par pays';
    }

    return '$countryDesc • $typeDesc';
  }
  Widget _getFilterIcon() {
    switch (_currentFilter) {
      case 'ALL':
        return Icon(Icons.public, color: Colors.white, size: 18);
      case 'COUNTRY':
      case 'CUSTOM':
        return Text(
          _getCountryFlag(_selectedCountryCode ?? ''),
          style: TextStyle(fontSize: 16),
        );
      case 'MIXED':
        return Icon(Icons.blender, color: Colors.white, size: 18);
      default:
        return Icon(Icons.filter_alt, color: Colors.white, size: 18);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'SPORT':
        return Icons.sports_soccer;
      case 'MUSIC':
        return Icons.music_note;
      case 'ACTUALITES':
        return Icons.newspaper;
      case 'LOOKS':
        return Icons.style;
      case 'EVENEMENT':
        return Icons.event;
      case 'OFFRES':
        return Icons.local_offer;
      case 'GAMER':
        return Icons.videogame_asset;
      default:
        return Icons.category;
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

      // ❌ Si moins de 2 jours -> ne PAS compter la vue
      if (difference < 2) {
        printVm(
            '⏭️ Post ${post.id} déjà vu il y a $difference jour(s) par $currentUserId - Vue NON comptée');

        if (!post.users_vue_id!.contains(currentUserId)) {
          setState(() {
            post.users_vue_id!.add(currentUserId);
            post.hasBeenSeenByCurrentUser = true;
          });
        }

        // ✅ Même si la vue n'est pas comptée, on vérifie l'interaction par session
        await _checkAndIncrementInteraction(post);
        return;
      }
    }

    try {
      // 🔥 Sauvegarder la date pour les vues
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
      }

      PostViewService.recordAuthorView(post, currentUserId);
      printVm('✅ Vue comptée pour post ${post.id} par $currentUserId');

      // ✅ 2. GESTION DE L'INTERACTION (par session)
      await _checkAndIncrementInteraction(post);

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
    _backgroundLoadTimer?.cancel();

    setState(() {
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true;
      _backgroundPostsLoaded = 0;
    });

    _resetPagination();
    await _loadInitialPosts();

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
// Dans votre classe, ajoutez ces listes
  final List<String> _sportTitles = [
    '⚽ LIGUE DES CHAMPIONS',
    '⚽ LIGUE EUROPA',

    '🏆 LIGA - REAL MADRID',
    '🏆 LIGA - BARÇA',
    '🏆 LIGA - ATLETICO MADRID',

    '⚽ LIGUE 1 - PSG',
    '⚽ LIGUE 1 - MARSEILLE',

    '⚽ PREMIER LEAGUE',
    '⚽ PREMIER LEAGUE - MANCHESTER CITY',
    '⚽ PREMIER LEAGUE - LIVERPOOL',

    '⚽ LDC - CAN',
    '⚽ LIGUE AFRICAINE',
    '⚽ CAF - AL AHLY',
    '⚽ CAF - ZAMALEK',
    '⚽ CAF - TP MAZEMBE',
    '⚽ CAF - WYDAD CASABLANCA',

    '🏀 BASKETBALL - NBA',
    '🤾 HANDBALL',
  ];

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
  String _getFilterLabel() {
    final l10n = AppLocalizations.of(context);
    switch (_currentFilter) {
      case 'ALL':
        return l10n.feedAllFilter;
      case 'COUNTRY':
        return l10n.feedMyCountry;
      case 'MIXED':
        return l10n.feedMixFilter;
      case 'CUSTOM':
        return _selectedCountryCode ?? l10n.feedCountryLabel;
      default:
        return l10n.feedFilterLabel;
    }
  }
  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ============================================================
              // LIGNE 1: Titre animé + bouton retour (compact)
              // ============================================================
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: colors.surface,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bouton retour
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back, color: colors.textPrimary, size: 18),
                      ),
                    ),
                    SizedBox(width: 10,),


                    // Titre animé (expand)
                    Expanded(
                      child: _selectedPostType == 'SPORT'
                          ? _buildCompactSportTitle()
                          : Text(
                        _selectedPostType,
                        style: TextStyle(
                          fontSize: 18,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // LIGNE 2: Boutons d'action + hashtags (scroll horizontal)
              // ============================================================
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: colors.surface,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Bouton Poster compact
                      _buildCompactButton(
                        label: AppLocalizations.of(context).feedPostButton,
                        icon: Icons.add,
                        color: Colors.green,
                        onTap: () => Navigator.pushNamed(context, '/user_posts_form'),
                      ),

                      SizedBox(width: 6),

                      // Bouton Type compact
                      _buildCompactButton(
                        label: _selectedPostType,
                        icon: _getTypeIcon(_selectedPostType),
                        color: Colors.purple,
                        onTap: _showTypeFilterModal,
                      ),

                      SizedBox(width: 6),

                      // Bouton Filtre compact
                      _buildCompactButton(
                        label: _getFilterLabel(),
                        iconDataWidget: _getFilterIcon(),
                        color: _getFilterBorderColor(),
                        onTap: _showCountryFilterModal,
                      ),

                      SizedBox(width: 6),

                      // Bouton Rafraîchir
                      InkWell(
                        onTap: _refreshData,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.refresh, color: colors.textPrimary, size: 14),
                        ),
                      ),

                      // Hashtags sport (sur la même ligne que les boutons)
                      if (_selectedPostType == 'SPORT') ...[
                        SizedBox(width: 8),
                        _buildCompactSportTags(),
                      ],
                    ],
                  ),
                ),
              ),

              // ============================================================
              // CONTENU PRINCIPAL
              // ============================================================
              Expanded(
                child: AppLayout.isWide(context)
                    ? CenteredContent(child: _buildContent())
                    : _buildContent(),
              ),

            ],
          ),
        ),
      ),
    );
  }

// Titre sport compact animé
// Titre sport compact animé (version corrigée)
  Widget _buildCompactSportTitle() {
    if (_selectedPostType != 'SPORT') {
      return Text(
        _selectedPostType,
        style: TextStyle(fontSize: 18, color: AppColors.of(context).textPrimary, fontWeight: FontWeight.bold),
      );
    }

    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.2, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        _sportTitles[_currentTitleIndex],
        key: ValueKey(_currentTitleIndex),
        style: TextStyle(
          fontSize: 16,
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
// Bouton compact
  Widget _buildCompactButton({
    required String label,
    IconData? icon,
    Widget? iconDataWidget,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: colors.textPrimary, size: 12)
            else if (iconDataWidget != null)
              Container(width: 16, height: 16, child: Center(child: iconDataWidget)),

            if (label.isNotEmpty) ...[
              SizedBox(width: 4),
              Text(
                label.length > 6 ? '${label.substring(0, 4)}..' : label,
                style: TextStyle(color: colors.textPrimary, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

// Hashtags sport compacts (une seule ligne avec les boutons)
  Widget _buildCompactSportTags() {
    List<String> tags = ['#Football', '#LDC', '#Ligue1', '#NBA', '#Handball', '#Liga'];
    tags.shuffle();
    tags = tags.take(3).toList(); // Seulement 3 tags pour garder compact

    return Row(
      children: tags.map((tag) => Container(
        margin: EdgeInsets.only(right: 4),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Text(
          tag,
          style: TextStyle(color: Colors.green, fontSize: 9),
        ),
      )).toList(),
    );
  }
}