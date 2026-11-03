import 'package:afrotok/services/post_orientation.dart';
import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/services/ads_engine_service.dart';
import '../services/comments_prefetch.dart';
import 'package:afrotok/widgets/studio/post_template_try.dart';
import '../widgets/music/music_overlay.dart';
import 'defi/defi_boost.dart';
import 'pub/ad_actions.dart';
import 'package:afrotok/ads/admob_service.dart';
import 'package:afrotok/ads/ad_gate.dart';
import 'package:afrotok/utils/post_time_ago.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'package:afrotok/pages/stickers/sticker_quick_button.dart';
import 'package:afrotok/services/stickers/sticker_models.dart';
import 'package:afrotok/widgets/safe_network_avatar.dart';
import '../services/followers_count_service.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/defi/defi_details_section.dart';

import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:afrotok/pages/component/showUserDetails.dart';

import 'package:afrotok/pages/paiement/newDepot.dart';

import 'package:afrotok/pages/postDetails.dart';

import 'package:afrotok/widgets/chat/post_share_sheet.dart';

import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/user/userPubs/user_create_advertisement_page.dart';

import 'package:afrotok/pages/pub/conditional_ad_banner.dart';
import 'package:afrotok/pages/pub/afrolook_inline_ad.dart';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/post_social_api.dart';
import 'package:afrotok/widgets/post_social_actions.dart';
import 'package:afrotok/pages/pub/midroll_ad_card.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_mapper.dart';

import 'package:afrotok/pages/widgetGlobal.dart';

import 'package:flutter/gestures.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'cards/card_entry.dart';
import 'defi/defi_convert.dart';
import 'package:afrotok/services/block_service.dart';
import 'package:afrotok/widgets/smart_video_player.dart';
import '../services/media_cache_service.dart';

import 'package:video_player/video_player.dart';

import 'package:chewie/chewie.dart';


import 'package:afrotok/services/api/publications_api.dart';
import 'package:afrotok/services/api/pub_videos_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:provider/provider.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/follow_service.dart';

import 'package:afrotok/providers/authProvider.dart';

import 'package:afrotok/providers/postProvider.dart';

import 'package:afrotok/pages/postComments.dart';

import 'package:afrotok/services/linkService.dart';

import 'package:video_thumbnail/video_thumbnail.dart';

import '../providers/coin_gift_provider.dart';

import '../services/utils/abonnement_utils.dart';

import '../widgets/user_badge_widget.dart';

import 'UserServices/deviceService.dart';

import 'admin/AfrolookPub/ad_post_page_video_widget.dart';

import 'canaux/detailsCanal.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'coins/coin_gift_dialog.dart';

import 'coins/coin_recharge_screen.dart';
import '../widgets/like_coins_helper.dart';
import '../models/coin_pack.dart';
import '../widgets/gifts/gift_sent_overlay.dart';
import '../widgets/gifts/quick_gift_bar.dart';

import 'coins/post_gifts_list.dart';

import '../theme/app_colors.dart';

import '../services/feed/feed_repository.dart';
import '../services/feed/country_priority.dart';
import '../widgets/feed/sections/feed_end_discovery_section.dart';
import '../services/postService/feed_interaction_service.dart';
import '../services/streak_service.dart';
import '../providers/streakProvider.dart';

import 'userPosts/postWidgets/translatable_description.dart';

import '../providers/locale_provider.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../services/postService/post_view_service.dart';
import '../widgets/feed/sections/shop_promo_feed_widget.dart';
import 'package:afrotok/services/comment_coins.dart';
import 'package:afrotok/widgets/post_coins_earned.dart';
import 'intro/monetization_tutorial.dart';
import '../utils/platform_guard.dart';

const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroDarkGrey = Color(0xFF16181C);
const _afroLightGrey = Color(0xFF71767B);
const _twitterCardBg = Color(0xFF16181C);
const _twitterTextPrimary = Color(0xFFFFFFFF);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterGreen = Color(0xFF1D9BF0);
const _twitterRed = Color(0xFFF91880);


class PostDetailsVideoFormatTel extends StatefulWidget {
  final Post? initialPost;
  final bool isIn;
  final String? feedTier;

  const PostDetailsVideoFormatTel({Key? key, this.initialPost, this.isIn = false, this.feedTier}) : super(key: key);

  @override
  _PostDetailsVideoFormatTelState createState() => _PostDetailsVideoFormatTelState();
}

class _PostDetailsVideoFormatTelState extends State<PostDetailsVideoFormatTel> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver, MusicSuspendMixin {
  @override
  bool get wantKeepAlive => true;

  final Map<String, String> _translatedDescriptions = {};
  late PageController _pageController;
  final FocusNode _focusNode = FocusNode();
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;
  static const String _kLastSessionTsKey = 'last_session_timestamp';
  bool _sessionTimestampSaved = false;
  int _itemsSinceLastLoad = 0;
  // Feed mixte : contient Post, Map<String,dynamic> (pub), ou _ShopPromoSentinel
  List<dynamic> _feedItems = [];
  List<ArticleData> _promoArticles = [];
  List<Post> _videoPosts = [];
  final Set<String> _loadedPostIds = {};
  final Set<String> _loadingRelations = {};
  final Set<String> _relationsResolved = {};
  int _currentPage = 0;
  bool _isLoadingFeed = true;
  bool _isLoadingMore = false;
  final int _batchSize = 10;
  bool _t1Exhausted = false;
  bool _hasSubscribedFromEndFeed = false;
  bool _hasLoadedDiscovery = false;
  bool _isReloadingAfterSubscribe = false;
  final int _preloadThreshold = 2;
  String? _videosCursor; // curseur de l'API pour le fil de vidéos
  bool _videosExhausted = false;
  String? _oldVideosCursor;
  bool _oldVideosExhausted = false;

  // Video controllers
  VideoPlayerController? _currentVideoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _showScrollHint = false;
  Timer? _scrollHintTimer;
  bool _maxVideosReached = false;
  final int _maxVideosLimit = 50; // seuil de 50 vidéos

  // Nouveaux membres pour le préchargement
  // Clé = identifiant du POST (pas la position) : l'insertion d'une pub ou d'une page entre deux vidéos ne décale plus jamais un lecteur préchargé
  final Map<String, VideoPlayerController> _preloadedControllers = {};
  // Préchargement « façon TikTok » : 3 vidéos d'avance et 1 en arrière, prêtes à lire (lecteur initialisé, premières images en mémoire)
  final int _preloadAhead = 3;
  final int _preloadBehind = 1;
  final Set<String> _preloadingIndices = {};

  // Cache des données pub pour les posts qui sont des publicités
  final Map<String, Advertisement?> _adCache = {};
  final Set<String> _loadingAdIds = {};

  // Interactions state
  bool _isSharing = false;
  bool _isSupporting = false;
  bool? _hasSeenSupportModal;
  int _selectedGiftIndex = 0;
  final List<double> giftPrices = [10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000, 2500, 5000, 7000, 10000, 15000, 20000, 30000, 50000, 75000, 100000];
  final List<String> giftIcons = ['🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕','🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'];

  final Set<String> _postRefreshed = {};
  Timer? _suggestionModalTimer;
  bool _hasSeenSuggestionsModal = false;

  // Pub midroll — affichée 5s avant la fin (vidéo initiale + toutes les 3 vidéos)
  bool _showMidrollAd = false;
  Timer? _midrollTimer;
  int _videoPlayCount = 0;
  bool _midrollShownForCurrentVideo = false;
  Map<String, dynamic>? _midrollAdData;
  VideoPlayerController? _midrollVideoController;
  bool _midrollVideoInitialized = false;
  VoidCallback? _videoPositionListener;


  // Pour l'animation de like au double clic
  bool _showLikeAnimation = false;
  double _likeAnimationTop = 0;
  double _likeAnimationLeft = 0;
  Timer? _likeAnimationTimer;

  // Pour le scroll plus sensible
  double _dragStartY = 0;
  double _dragDistance = 0;

  // Pour l'animation des 5 coeurs qui se dispersent
  final List<FlyingHeart> _flyingHearts = [];
  final Random _random = Random();

  bool _isFavorite = false;
  int _favoritesCount = 0;
  bool _isFavoriteProcessing = false;

  // Nouveau système de like + commentaire rapide
  bool _isLiking = false;
  // Posts dont le like Firestore est encore en vol (optimistic update en cours)
  final Set<String> _pendingLikePostIds = {};
  // État local du like par post — résistant aux rebuilds et replacements de _videoPosts par les snapshots
  final Map<String, bool> _likedPosts = {};
  final Map<String, int> _lovesCount = {};
  List<PostComment> _preloadedComments = [];
  final TextEditingController _quickCommentController = TextEditingController();
  bool _isSendingQuickComment = false;

  // Overlay toggle + live comments (style TikTok Live)
  bool _showOverlay = true;
  Timer? _liveCommentTimer;
  final GlobalKey<AnimatedListState> _liveListKey = GlobalKey<AnimatedListState>();
  final List<PostComment> _visibleComments = [];
  int _commentCycleIdx = 0;

// Cache et gestion des anciennes vidéos
  List<Post> _oldVideosCache = [];
  bool _isLoadingOldVideos = false;
  Timer? _oldVideosLoadTimer;   // chargement par lot
  Set<String> _usedOldVideoIds = {};

  // Rappel animé « chaque like paie le créateur » (de temps en temps)
  bool _showTutoReminder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AdmobService.warmUpInterstitial(authProvider.loginUserData);
    });
    MonetizationReminder.due('video').then((v) {
      if (mounted && v) setState(() => _showTutoReminder = true);
    });
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
    );

    _initSharedPreferences();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    // 🔥 Vérifier si initialPost existe avant de l'utiliser
    if (widget.initialPost != null) {
      _checkFavoriteStatus();
      _incrementViews(); // gère totalInteractions + vue unique via SharedPrefs
      _loadSupportModalSeen();
    }

    // 🚀 Affichage instantané : on place immédiatement le post initial dans
    // le feed pour que le premier frame puisse l'afficher (sans attendre
    // la requête réseau de la liste complète).
    if (widget.initialPost != null && !_loadedPostIds.contains(widget.initialPost!.id)) {
      _loadedPostIds.add(widget.initialPost!.id!);
      _videoPosts.add(widget.initialPost!);
      _rebuildFeedItems();
      _isLoadingFeed = false;
      _subscribeToPostUpdates(widget.initialPost!);
      // Charger les relations (user/canal) en arrière-plan sans bloquer l'affichage
      _lazyLoadPostRelations(widget.initialPost!);
    }

    _initializeFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstScrollModalIfNeeded();
      // Démarrer la vidéo initiale dès le premier frame, sans attendre le
      // chargement de la liste complète.
      if (_feedItems.isNotEmpty && _feedItems[0] is Post && !_isVideoInitialized) {
        _preloadNeighborhood(0);
        _initializeVideo(_feedItems[0] as Post, index: 0);
      }
    });
  }
  Future<void> _lazyLoadPostRelations(Post post) async {
    if (post.id == null) return;
    if (_loadingRelations.contains(post.id)) return;
    if (_relationsResolved.contains(post.id)) return;
    _loadingRelations.add(post.id!);

    try {
      await _loadPostRelations(post); // utilise la méthode existante
      if (mounted) setState(() {});
    } finally {
      _loadingRelations.remove(post.id);
      // Évite de relancer une requête Firestore à chaque rebuild si la relation reste introuvable
      _relationsResolved.add(post.id!);
    }
  }
  Future<void> _loadOldVideosInBackground() async {
    if (_isLoadingOldVideos) return;
    _isLoadingOldVideos = true;

    try {
      final random = Random();

      // Anciennes vidéos : pages suivantes du fil de l'API (le serveur renvoie des publications non vues)
      if (_oldVideosExhausted) {
        _isLoadingOldVideos = false;
        return;
      }
      final r = await PubVideosApi.videos(
        cursor: _oldVideosCursor,
        limit: 12,
        exclude: {..._loadedPostIds, ..._oldVideosCache.map((p) => p.id!)},
      );
      _oldVideosCursor = r.next;
      if (r.next == null) _oldVideosExhausted = true;
      final validOldVideos = r.posts.where((p) => p.isAdvertisement != true).toList();

      if (validOldVideos.isNotEmpty) {
        validOldVideos.shuffle();
        _oldVideosCache.addAll(validOldVideos);
        printVm("✅ ${validOldVideos.length} anciennes vidéos ajoutées (cache: ${_oldVideosCache.length})");
      } else {
        printVm("⚠️ Aucune vidéo valide après filtrage");
      }
    } catch (e) {
      printVm("❌ Erreur chargement anciennes vidéos: $e");
    } finally {
      _isLoadingOldVideos = false;
    }
  }
  // Vérifier si le post est en favori
  void _checkFavoriteStatus() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    try {
      final fresh = await PubApi.fresh(widget.initialPost!.id!);
      if (!mounted || fresh == null) return;
      setState(() {
        _isFavorite = fresh.users_favorite_id?.contains(userId) ?? false;
        _favoritesCount = fresh.favoritesCount ?? _favoritesCount;
      });
    } catch (e) {
      printVm('Erreur lecture favori: $e');
    }
  }

// Ajouter/retirer des favoris
  Future<void> _toggleFavorite() async {
    if (_isFavoriteProcessing) return;
    _isFavoriteProcessing = true;

    final userId = authProvider.loginUserData.id;
    if (userId == null) {
      _isFavoriteProcessing = false;
      return;
    }

    try {
      if (_isFavorite) {
        // Retirer des favoris
        await PubApi.setFavorite(widget.initialPost!.id!, false);
        setState(() {
          _isFavorite = false;
          _favoritesCount--;
        });
      } else {
        // Ajouter aux favoris
        await PubApi.setFavorite(widget.initialPost!.id!, true);
        setState(() {
          _isFavorite = true;
          _favoritesCount++;
        });

        // la notification de favori est envoyée par le serveur
      }
    } catch (e) {
      printVm("Erreur favori: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PubApi.message(e))));
    } finally {
      _isFavoriteProcessing = false;
    }
  }

// Formater le nombre
  String _formatNumber(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  void dispose() {
    // Plus de pub plein écran déclenchée par la fermeture de la page (décision du 01/11/2026) : elle pouvait s'afficher par-dessus la
    // page suivante, avant même que la vidéo soit regardée.
    WidgetsBinding.instance.removeObserver(this);
    _likeAnimationTimer?.cancel();
    _liveCommentTimer?.cancel();
    _quickCommentController.dispose();

    // Nettoyer tous les
    // contrôleurs préchargés
    for (var controller in _preloadedControllers.values) {
      controller.dispose();
    }
    _preloadedControllers.clear();
    _suggestionModalTimer?.cancel();
    _scrollHintTimer?.cancel();
    _midrollTimer?.cancel();
    _midrollVideoController?.dispose();
    _midrollVideoController = null;
    _removeMidrollListener();
    _pageController.dispose();
    _disposeCurrentVideo();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause automatique quand l'app passe en arrière-plan ou est inactive
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _currentVideoController?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Reprend seulement si la vidéo était en lecture avant
      if (_currentVideoController != null &&
          _currentVideoController!.value.isInitialized) {
        _currentVideoController!.play();
      }
    }
  }

  Widget _wrapWithControls(Widget child) {
    return KeyboardListener(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
        }
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          if (event.scrollDelta.dy > 0) {
            _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          } else if (event.scrollDelta.dy < 0) {
            _pageController.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          }
        },
        child: child,
      ),
    );
  }

  // ── Midroll ad ──────────────────────────────────────────────────────────────

  /// Vrai si l'utilisateur ne doit pas voir de pub (Gold ; l'admin en voit toujours) — nom conservé.
  bool _isUserPremium() => !AdGate.userSeesAds(authProvider.loginUserData);

  void _attachMidrollListener() {
    if (_currentVideoController == null) return;
    _removeMidrollListener();
    _midrollShownForCurrentVideo = false;
    // Pré-charger la pub dès le début de la vidéo — elle sera prête au moment du trigger
    _prepareMidrollAd();
    final listener = () {
      if (_midrollShownForCurrentVideo || !mounted) return;
      final vpc = _currentVideoController;
      if (vpc == null) return;
      final value = vpc.value;
      if (!value.isPlaying) return;
      final duration = value.duration;
      final position = value.position;
      if (duration.inSeconds < 20) return;
      final remaining = duration - position;
      if (remaining.inSeconds <= 15 && remaining.inSeconds > 0 && position.inSeconds > 5) {
        _midrollShownForCurrentVideo = true;
        _showMidrollOverlay();
      }
    };
    _videoPositionListener = listener;
    _currentVideoController!.addListener(listener);
  }

  void _removeMidrollListener() {
    if (_videoPositionListener != null && _currentVideoController != null) {
      _currentVideoController!.removeListener(_videoPositionListener!);
    }
    _videoPositionListener = null;
    // Libérer la pub pré-chargée si elle n'est pas en cours d'affichage
    if (!_showMidrollAd) {
      _midrollVideoController?.dispose();
      _midrollVideoController = null;
      _midrollVideoInitialized = false;
      _midrollAdData = null;
    }
  }

  /// Pré-charge la pub midroll dès que la vidéo démarre.
  /// Quand le trigger se déclenche (15s avant fin), la pub est déjà prête.
  Future<void> _prepareMidrollAd() async {
    if (!mounted) return;
    // Inclure les entity boosts (pas de post mais gérés par _buildMidrollCard)
    // et les pubs post normales — exclure uniquement celles sans post ET sans entity boost
    final ads = authProvider.advertisements
        .where((a) => a['isEntityBoost'] == true || a['post'] != null)
        .toList();
    if (ads.isEmpty) return;
    final picked = ads[Random().nextInt(ads.length)];
    _midrollAdData = picked;

    // Pré-initialiser le contrôleur vidéo de la pub (sans le jouer)
    final isEntityBoost = picked['isEntityBoost'] == true;
    if (!isEntityBoost) {
      try {
        final post = Post.fromJson(picked['post'] as Map<String, dynamic>);
        final isVideo = post.dataType == PostDataType.VIDEO.name ||
            (post.url_media?.contains('.mp4') ?? false) ||
            (post.url_media?.contains('.mov') ?? false);
        if (isVideo && post.url_media?.isNotEmpty == true) {
          final cdnUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
          _midrollVideoController?.dispose();
          final ctrl = VideoPlayerController.networkUrl(Uri.parse(cdnUrl));
          _midrollVideoController = ctrl;
          await ctrl.initialize();
          await ctrl.setVolume(0);
          ctrl.setLooping(true);
          // Pas de play() ici — on attend le moment du trigger
          if (mounted) setState(() => _midrollVideoInitialized = true);
        }
      } catch (_) {
        _midrollVideoController?.dispose();
        _midrollVideoController = null;
        _midrollVideoInitialized = false;
      }
    }
  }

  /// Déclenché par le listener quand la vidéo approche de la fin.
  /// La pub est déjà prête grâce à [_prepareMidrollAd].
  Future<void> _showMidrollOverlay() async {
    if (!mounted) return;
    if (_midrollAdData == null) return; // Pas de pub pré-chargée, on ne coupe pas la vidéo
    _currentVideoController?.pause();
    // Lancer la lecture de la pub vidéo pré-chargée
    _midrollVideoController?.play();
    // Compte à rebours et bouton « Fermer » gérés par MidrollAdCard
    setState(() { _showMidrollAd = true; });
  }

  void _closeMidrollOverlay() {
    if (!mounted) return;
    _midrollTimer?.cancel();
    _midrollVideoController?.dispose();
    _midrollVideoController = null;
    setState(() {
      _showMidrollAd = false;
      _midrollVideoInitialized = false;
    });
    _midrollAdData = null;
    _currentVideoController?.play();
  }

  // ────────────────────────────────────────────────────────────────────────────

  void _disposeCurrentVideo() {
    _removeMidrollListener();
    _chewieController?.dispose();
    _currentVideoController?.dispose();
    if (mounted) setState(() => _isVideoInitialized = false);
  }
  // ==================== MÉTHODES DE PRÉCHARGEMENT ====================

  Future<void> _preloadVideoAtIndex(int index) async {
    // Sur web, video_player_web échoue avec 'isSupported' — pas de préchargement
    if (kIsWeb) return;
    if (index < 0 || index >= _feedItems.length) return;
    final item = _feedItems[index];
    if (item is! Post) return;
    final post = item;

    final key = post.id;
    if (key == null || post.url_media == null) return;
    if (_preloadedControllers.containsKey(key)) return;
    if (_preloadingIndices.contains(key)) return;

    _preloadingIndices.add(key);

    try {
      final optimizedUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
      final controller = await MediaCacheService.videoController(optimizedUrl);
      await controller.initialize();
      // NE PAS jouer, NE PAS mettre en pause, NE PAS seek
      // L'initialisation seule suffit à remplir le buffer
      _preloadedControllers[key] = controller;
      printVm("✅ Vidéo préchargée à l'index $index");
    } catch (e) {
      printVm("❌ Erreur préchargement index $index : $e");
    } finally {
      _preloadingIndices.remove(key);
    }
  }

  void _preloadNeighborhood(int currentIndex) {
    final start = max(0, currentIndex - _preloadBehind);
    final end = min(_feedItems.length - 1, currentIndex + _preloadAhead);

    // Les plus proches d'abord : la suivante est prête avant celle d'après
    for (int i = max(currentIndex, start); i <= end; i++) {
      if (_feedItems[i] is Post) {
        _preloadVideoAtIndex(i);
      }
    }
    for (int i = currentIndex - 1; i >= start; i--) {
      if (_feedItems[i] is Post) {
        _preloadVideoAtIndex(i);
      }
    }
  }

  void _cleanupOutOfRangeControllers(int currentIndex) {
    final keep = <String>{};
    for (int i = max(0, currentIndex - _preloadBehind); i <= min(_feedItems.length - 1, currentIndex + _preloadAhead); i++) {
      final item = _feedItems[i];
      if (item is Post && item.id != null) keep.add(item.id!);
    }
    final toRemove = <String>[];

    _preloadedControllers.forEach((key, controller) {
      // Le lecteur en cours de lecture n'est jamais libéré ici
      if (!keep.contains(key) && controller != _currentVideoController) {
        controller.dispose();
        toRemove.add(key);
      }
    });

    for (var key in toRemove) {
      _preloadedControllers.remove(key);
    }
  }

  // ==================== VIDEO INIT & PLAYBACK (MODIFIÉE) ====================

  Future<void> _initializeVideo(Post post, {int? index}) async {
    // Sur web, SmartVideoPlayer gère l'affichage nativement via <video> HTML
    if (kIsWeb) return;
    // Si un index est fourni et qu'un contrôleur préchargé existe, on l'utilise
    if (post.id != null && _preloadedControllers.containsKey(post.id)) {
      final preloadedController = _preloadedControllers[post.id]!;

      // Nettoyer l'ancien ChewieController sans disposer le contrôleur vidéo
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }

      // Retirer le listener midroll de l'ancien contrôleur avant tout dispose
      _removeMidrollListener();

      // Si l'ancien contrôleur vidéo n'était pas géré par le cache de préchargement
      // (ex: chargement de secours), il faut le disposer pour éviter une fuite mémoire/réseau.
      if (_currentVideoController != null &&
          _currentVideoController != preloadedController &&
          !_preloadedControllers.values.contains(_currentVideoController)) {
        _currentVideoController!.dispose();
      }

      _currentVideoController = preloadedController;

      // Créer le nouveau ChewieController avec autoPlay true
      _chewieController = ChewieController(
        videoPlayerController: _currentVideoController!,
        autoPlay: true,
        looping: true,
        showControls: false,
        allowFullScreen: false,
        allowMuting: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: _afroGreen,
          handleColor: _afroGreen,
          backgroundColor: _afroLightGrey.withOpacity(0.3),
          bufferedColor: _afroLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(
          color: _afroBlack,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(color: _afroGreen), SizedBox(height: 16), Text('Chargement...', style: TextStyle(color: Colors.white))],
            ),
          ),
        ),
        autoInitialize: true,
      );

      setState(() => _isVideoInitialized = true);
      if (_learnOrientation(post)) return;
      _videoPlayCount++;
      if ((_videoPlayCount - 1) % 3 == 0 && !_isUserPremium() && post.isAdvertisement != true) _attachMidrollListener();
      await _recordPostView(post);
      _startSuggestionModalTimer();
      return;
    }

    // Fallback : comportement normal si pas de préchargement
    _disposeCurrentVideo();
    if (post.url_media == null || post.url_media!.isEmpty) return;

    try {
      final String optimizedUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
      _currentVideoController = await MediaCacheService.videoController(optimizedUrl);
      await _currentVideoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _currentVideoController!,
        autoPlay: true,
        looping: true,
        showControls: false,
        allowFullScreen: false,
        allowMuting: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: _afroGreen,
          handleColor: _afroGreen,
          backgroundColor: _afroLightGrey.withOpacity(0.3),
          bufferedColor: _afroLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(
          color: _afroBlack,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(color: _afroGreen), SizedBox(height: 16), Text('Chargement...', style: TextStyle(color: Colors.white))],
            ),
          ),
        ),
        autoInitialize: true,
      );

      setState(() => _isVideoInitialized = true);
      if (_learnOrientation(post)) return;
      _videoPlayCount++;
      if ((_videoPlayCount - 1) % 3 == 0 && !_isUserPremium() && post.isAdvertisement != true) _attachMidrollListener();
      await _recordPostView(post);
      _startSuggestionModalTimer();
    } catch (e) {
      printVm('❌ Erreur init vidéo: $e');
      setState(() => _isVideoInitialized = false);
    }
  }
  // ==================== FEED LOADING (MODIFIÉ) ====================
  /// 🚀 Le post initial est déjà affiché (placé dans `_feedItems` dès
  /// `initState`). Cette méthode ne fait que compléter le feed EN
  /// ARRIÈRE-PLAN : chargement des vidéos suggérées + anciennes vidéos,
  /// puis ajout au feed sans perturber la lecture en cours (pas de reset
  /// du `PageController`, pas de remise à `_isLoadingFeed = true`).
  Future<void> _initializeFeed() async {
    _itemsSinceLastLoad = 0;
    _maxVideosReached = false;
    _videosCursor = null;
    _videosExhausted = false;
    _usedOldVideoIds.clear();

    // Si le post initial n'a pas encore été ajouté (cas où widget.initialPost
    // est null lors du initState), on le garde géré ici en fallback.
    if (widget.initialPost != null && !_loadedPostIds.contains(widget.initialPost!.id)) {
      _loadedPostIds.add(widget.initialPost!.id!);
      _videoPosts.add(widget.initialPost!);
      await _loadPostRelations(widget.initialPost!);
      _subscribeToPostUpdates(widget.initialPost!);
      _rebuildFeedItems();
      if (mounted) setState(() {});
    }

    // T1 uniquement au lancement : vidéos non vues des abonnements.
    // T3 (suggestions/découverte) uniquement via "À découvrir & Tendances".
    await _loadTier1Videos();

    if (mounted) {
      setState(() {
        _rebuildFeedItems();
      });
    }

    // Précharger immédiatement les voisins (posts #2/#3).
    _preloadNeighborhood(0);

    // Reconstruire le feed avec les nouvelles vidéos ajoutées, sans toucher
    // à la position de lecture courante (_rebuildFeedItems reconstruit la
    // liste mais le PageController garde son index courant).
    if (mounted) {
      setState(() {
        _rebuildFeedItems();
        _isLoadingFeed = false;
      });
    }

    // Précharger les voisins du post actuellement affiché si pas déjà fait
    if (_feedItems.isNotEmpty && _feedItems[0] is Post && !_isVideoInitialized) {
      _preloadNeighborhood(0);
      _initializeVideo(_feedItems[0] as Post, index: 0);
    } else {
      _preloadNeighborhood(_currentPage);
    }
  }
  Future<void> _initializeFeed2() async {
    setState(() => _isLoadingFeed = true);

    _itemsSinceLastLoad = 0;
    _maxVideosReached = false;
    _videosCursor = null;
    _videosExhausted = false;

    // RESET sécurité anti doublon old videos
    _usedOldVideoIds.clear();

    // 1. Charger vidéo initiale
    if (!_loadedPostIds.contains(widget.initialPost!.id)) {
      _loadedPostIds.add(widget.initialPost!.id!);
      _videoPosts.add(widget.initialPost!);

      await _loadPostRelations(widget.initialPost!);
      _subscribeToPostUpdates(widget.initialPost!);
    }

    // 2. Charger vidéos récentes
    await _loadMoreVideos(isInitial: true);

    // 3. Charger les anciennes vidéos AVANT rebuild
    await _loadOldVideosInBackground();

    // 4. Construire feed final
    _rebuildFeedItems();

    setState(() => _isLoadingFeed = false);

    // 5. Init player
    if (_feedItems.isNotEmpty && _feedItems[0] is Post) {
      _preloadNeighborhood(0);
      _initializeVideo(_feedItems[0] as Post, index: 0);
    }
  }
  // ==================== FEED LOADING ====================

  Future<void> _incrementViews() async {
    try {
      if (authProvider.loginUserData == null ||
          widget.initialPost == null ||
          widget.initialPost!.id == null) return;
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      // Garde permanente par appareil — une seule vue par utilisateur par post
      final prefKey = 'view_${widget.initialPost!.id}_$currentUserId';
      if (_prefs.getBool(prefKey) ?? false) {
        printVm('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }
      await _prefs.setBool(prefKey, true);

      authProvider.incrementPostTotalInteractions(
        postId: widget.initialPost!.id!,
        userId: currentUserId,
        interactionType: 'view',
      );

      setState(() {
        widget.initialPost!.vues = (widget.initialPost!.vues ?? 0) + 1;
        widget.initialPost!.users_vue_id ??= [];
        widget.initialPost!.users_vue_id!.add(currentUserId);
      });
      await PubApi.view(widget.initialPost!.id!);
      PostViewService.recordAuthorView(widget.initialPost!, currentUserId);
      printVm('✅ Vue unique enregistrée pour ${widget.initialPost!.id}');
    } catch (e) {
      printVm("Erreur incrémentation vues: $e");
    }
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _rebuildFeedItems() {
    // Première construction : vidéos du pays de l'utilisateur en premier
    // (la vidéo ouverte reste en tête ; tri local, sans index Firestore).
    if (_feedItems.isEmpty && _videoPosts.length > 2) {
      final rest = prioritizeUserCountry(
          _videoPosts.sublist(1), authProvider.loginUserData.countryData?['countryCode']);
      _videoPosts.replaceRange(1, _videoPosts.length, rest);
    }
    final List<Post> normalPosts = List.from(_videoPosts);
    final List<Post> oldBuffer = List.from(_oldVideosCache);
    final List<Post> mixedPosts = [];

    const int normalBatchSize = 3;
    const int oldPerBatch = 2;

    int normalIndex = 0;

    while (normalIndex < normalPosts.length) {
      // normales
      int end = normalIndex + normalBatchSize;
      if (end > normalPosts.length) end = normalPosts.length;

      mixedPosts.addAll(normalPosts.sublist(normalIndex, end));
      normalIndex = end;

      // anciennes
      int added = 0;

      while (oldBuffer.isNotEmpty && added < oldPerBatch) {
        final oldPost = oldBuffer.removeAt(0);

        if (_usedOldVideoIds.contains(oldPost.id)) {
          continue;
        }

        _usedOldVideoIds.add(oldPost.id!);
        mixedPosts.add(oldPost);
        added++;
      }
    }

    // reste des anciennes
    while (oldBuffer.isNotEmpty) {
      final oldPost = oldBuffer.removeAt(0);

      if (_usedOldVideoIds.contains(oldPost.id)) continue;

      _usedOldVideoIds.add(oldPost.id!);
      mixedPosts.add(oldPost);
    }

    // insertion ads + promo AfroShop (toutes les 7 vidéos)
    // Les pubs (AdPostWidget) sont masquées pour les utilisateurs Premium/Gold/Admin
    // Entity boosts exclus : AdPostWidget.initState() appelle Post.fromJson(post) qui crashe si post==null
    final ads = authProvider.advertisements
        .where((a) => a['isEntityBoost'] != true && a['post'] != null)
        .toList();
    final skipAds = _isUserPremium();
    _feedItems.clear();

    int adIdx = 0;
    int postCount = 0; // compte uniquement les Post (pas les pubs)

    for (int i = 0; i < mixedPosts.length; i++) {
      _feedItems.add(mixedPosts[i]);
      postCount++;
      if (postCount == 1 && _showTutoReminder) _feedItems.add(const _TutoReminderSentinel());

      // Pub toutes les 3 vidéos (gratuit uniquement)
      if (!skipAds &&
          postCount % 3 == 0 &&
          i != mixedPosts.length - 1 &&
          adIdx < ads.length) {
        _feedItems.add(ads[adIdx]);
        adIdx++;
      }

      // Promo AfroShop toutes les 7 vidéos
      if (postCount % 7 == 0 && _promoArticles.isNotEmpty && !kIsAppleStore) {
        _feedItems.add(const _ShopPromoSentinel());
      }

      // Créateurs et canaux à suivre : une page entière toutes les 10 vidéos (défilement infini : plus de section réservée à la fin)
      if (postCount % 10 == 0 && i != mixedPosts.length - 1) {
        _feedItems.add(const _CreatorsChannelsSentinel());
      }
    }

    // Fin de feed T1 : widget de découverte (uniquement si T3 pas encore chargé)
    if (_t1Exhausted && !_hasLoadedDiscovery) {
      _feedItems.add(const _EndOfFeedSentinel());
    }

    // Charger les articles promo si pas encore fait
    if (_promoArticles.isEmpty) _loadPromoArticles();
  }

  Future<void> _loadPromoArticles() async {
    // Les articles promotionnels (ancienne collection « Articles ») n'ont pas de route dans l'API : voir lacunes. Aucune carte promo pour l'instant.
  }
  void _rebuildFeedItems2() {
    _feedItems.clear();
    final ads = authProvider.advertisements
        .where((a) => a['isEntityBoost'] != true && a['post'] != null)
        .toList();
    final skipAds = _isUserPremium();
    if (_videoPosts.isEmpty) return;

    int videoIdx = 0;
    int adIdx = 0;

    while (videoIdx < _videoPosts.length) {
      _feedItems.add(_videoPosts[videoIdx]);
      videoIdx++;
      if (videoIdx == 1 && _showTutoReminder) _feedItems.add(const _TutoReminderSentinel());

      // Toutes les 3 vidéos (gratuit uniquement)
      if (!skipAds && videoIdx % 3 == 0 && videoIdx < _videoPosts.length && adIdx < ads.length) {
        _feedItems.add(ads[adIdx]);
        adIdx++;
      }
    }
  }
  int _getCurrentVideoIndex() {
    int videoCount = 0;
    for (int i = 0; i <= _currentPage && i < _feedItems.length; i++) {
      if (_feedItems[i] is Post) videoCount++;
    }
    return videoCount - 1; // retourne l'index dans _videoPosts (0-based)
  }
  Future<void> _loadPostRelations(Post post) async {
    final _sw = Stopwatch()..start();
    final postId = post.id ?? '?';
    final isCanalPost = post.canal_id != null && post.canal_id!.isNotEmpty;

    // ── Phase 1 : snapshot → affichage immédiat ──────────────────────────────
    bool usedSnapshot = false;
    if (post.user == null && post.creatorSnapshot != null) {
      final snap = post.creatorSnapshot!;
      post.user = UserData()
        ..pseudo = snap['pseudo'] as String?
        ..imageUrl = snap['imageUrl'] as String?
        ..abonnes = snap['abonnes'] as int? ?? 0;
      usedSnapshot = true;
    }
    if (post.canal == null && post.canalSnapshot != null && isCanalPost) {
      final snap = post.canalSnapshot!;
      post.canal = Canal()
        ..titre = snap['titre'] as String?
        ..urlImage = snap['urlImage'] as String?
        ..suivi = snap['suivi'] as int? ?? 0;
      usedSnapshot = true;
    }
    printVm('⏱️ [DETAILS-CARD] id=$postId canal=$isCanalPost — snapshot=${usedSnapshot ? "✅ ${_sw.elapsedMilliseconds}ms" : "❌ pas de snapshot"}');
    if (mounted) setState(() {});

    // ── Phase 2 : profil complet en arrière-plan ─────────────────────────────
    final needUserFetch = post.user_id != null && (post.user == null || post.user!.isVerify == null);
    final needCanalFetch = isCanalPost && (post.canal == null || post.canal!.usersSuiviId == null);

    if (!needUserFetch && !needCanalFetch) {
      printVm('⏱️ [DETAILS-CARD] id=$postId — cache hit, pas de fetch réseau — ${_sw.elapsedMilliseconds}ms');
      return;
    }

    if (needUserFetch) {
      try {
        final u = await PubApi.user(post.user_id!);
        if (u != null) {
          post.user = u;
          printVm('⏱️ [DETAILS-CARD] id=$postId — user fetch complet — ${_sw.elapsedMilliseconds}ms');
        }
      } catch (e) { printVm('Erreur chargement user: $e'); }
    }

    if (needCanalFetch) {
      try {
        final c = await PubApi.canal(post.canal_id!, myId: authProvider.loginUserData.id);
        if (c != null) {
          post.canal = c;
          printVm('⏱️ [DETAILS-CARD] id=$postId — canal fetch complet — ${_sw.elapsedMilliseconds}ms');
        }
      } catch (e) { printVm('Erreur chargement canal: $e'); }
    }
    if (mounted) setState(() {});
    printVm('⏱️ [DETAILS-CARD] id=$postId — total=${_sw.elapsedMilliseconds}ms');
  }

  // ── T1 : vidéos non vues des abonnements ──────────────────────────────────
  Future<void> _loadTier1Videos() async {
    // Flux infini de vidéos, même algorithme que l'accueil : les vidéos non vues des ABONNEMENTS d'abord, puis celles qui correspondent aux goûts,
    // les nouveaux créateurs et canaux ; toujours des vidéos non vues. Les premières sont déjà prêtes (stock du téléphone).
    final List<Post> t1Posts = [];
    try {
      t1Posts.addAll(await _fetchVideoStream(_batchSize, reset: true));
    } catch (e) {
      printVm('Erreur chargement des vidéos: ${PubApi.message(e)}');
    }

    for (final p in t1Posts) {
      if (p.id != null && !_loadedPostIds.contains(p.id)) {
        _loadedPostIds.add(p.id!);
        _videoPosts.add(p);
        _loadPostRelations(p).ignore();
        _subscribeToPostUpdates(p);
      }
    }

    // Flux infini : la suite se charge au défilement (plus de page « tu as tout vu » au milieu)
    if (mounted) setState(() => _hasLoadedDiscovery = true);
  }

  /// Vidéos du flux infini (API, `media=video`) : jamais déjà chargées dans cette page.
  Future<List<Post>> _fetchVideoStream(int limit, {bool reset = false}) async {
    final rows = await ApiGateway.instance.forYouVideos(limit: limit, reset: reset);
    return rows
        .map(postFromApi)
        .where((p) => p.id != null && p.dataType == PostDataType.VIDEO.name && p.url_media != null && !_loadedPostIds.contains(p.id))
        .toList();
  }

  // ── T3 : découverte et tendances (sur demande explicite) ──────────────────
  Future<void> _loadDiscoveryVideos() async {
    if (!mounted || _isLoadingMore) return;
    setState(() => _hasLoadedDiscovery = true);
    // Note : _loadMoreVideos gère lui-même _isLoadingMore.
    await _loadMoreVideos();
    await _loadOldVideosInBackground();
    if (!mounted) return;
    setState(() => _rebuildFeedItems());
    // Auto-scroll vers le premier post T3 (juste après la page sentinel)
    final sentinelIndex = _feedItems.indexWhere((e) => e is _EndOfFeedSentinel);
    if (sentinelIndex >= 0 && _pageController.hasClients) {
      final nextIndex = sentinelIndex + 1;
      if (nextIndex < _feedItems.length) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // ── Page « créateurs et canaux à suivre » intercalée dans le fil vidéo ─────
  Widget _buildCreatorsChannelsPage() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                'Créateurs et canaux à suivre',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Abonne-toi pour voir plus de leurs vidéos. Glisse vers le haut pour continuer.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FeedEndDiscoverySection(
                pageType: 'VIDEO',
                onSubscribed: () {
                  if (!mounted) return;
                  setState(() => _hasSubscribedFromEndFeed = true);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Page de fin de feed T1 ─────────────────────────────────────────────────
  Widget _buildEndOfFeedPage() {
    return Builder(builder: (ctx) {
      final colors = AppColors.of(ctx);
      return Container(
        color: Colors.black,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                Icon(Icons.check_circle_outline, color: colors.primary, size: 40),
                const SizedBox(height: 10),
                const Text(
                  'Tu as tout vu !',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Abonne-toi à de nouveaux créateurs pour voir plus de vidéos',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FeedEndDiscoverySection(
                  pageType: 'VIDEO',
                  onSubscribed: () {
                    if (!mounted) return;
                    setState(() => _hasSubscribedFromEndFeed = true);
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _isReloadingAfterSubscribe
                            ? Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
                            : ElevatedButton.icon(
                                onPressed: _hasSubscribedFromEndFeed
                                    ? () async {
                                        setState(() => _isReloadingAfterSubscribe = true);
                                        // Réinitialiser et recharger T1
                                        _videoPosts.clear();
                                        _loadedPostIds.clear();
                                        if (widget.initialPost?.id != null) {
                                          _loadedPostIds.add(widget.initialPost!.id!);
                                          _videoPosts.add(widget.initialPost!);
                                        }
                                        setState(() {
                                          _t1Exhausted = false;
                                          _hasSubscribedFromEndFeed = false;
                                          _hasLoadedDiscovery = false;
                                        });
                                        await _loadTier1Videos();
                                        if (mounted) {
                                          setState(() {
                                            _rebuildFeedItems();
                                            _isReloadingAfterSubscribe = false;
                                          });
                                          _pageController.jumpToPage(0);
                                        }
                                      }
                                    : null,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Voir de nouveaux posts'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasSubscribedFromEndFeed
                                      ? colors.primary
                                      : colors.primary.withOpacity(0.3),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                      ),
                      if (!_hasSubscribedFromEndFeed)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Abonne-toi à un créateur ou canal ci-dessus pour activer ce bouton',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingMore ? null : _loadDiscoveryVideos,
                          icon: _isLoadingMore
                              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
                              : const Icon(Icons.explore_outlined, size: 18),
                          label: const Text('À découvrir & Tendances'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(color: colors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _loadMoreVideos({bool isInitial = false, int? limit}) async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      List<Post> newPosts = await _fetchSuggestedVideosBatch(
        limit: limit ?? _batchSize,
        excludeIds: _loadedPostIds,
      );

      if (newPosts.isNotEmpty) {
        // ── Posts non vus en priorité au premier chargement ─────────────────
        if (isInitial) {
          final prefs = await SharedPreferences.getInstance();
          final lastSessionMs = prefs.getInt(_kLastSessionTsKey) ?? 0;
          if (lastSessionMs > 0) {
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

        for (var post in newPosts) {
          if (post.id != null) {
            _loadedPostIds.add(post.id!);
            _videoPosts.add(post);
            await _loadPostRelations(post);
            _subscribeToPostUpdates(post);
          }
        }
        _rebuildFeedItems();
      }
      // Ne pas bloquer définitivement — prochain scroll réessaiera
    } catch (e) {
      printVm('Erreur chargement vidéos: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }
  Future<List<Post>> _fetchSuggestedVideosBatch({required int limit, required Set<String> excludeIds}) async {
    // Suite du flux infini (le serveur applique déjà « jamais plus de 2 de suite du même créateur ou canal » ; le stock du téléphone aussi)
    final more = await _fetchVideoStream(limit * 2);
    return more.where((p) => !excludeIds.contains(p.id)).take(limit).toList();
  }

  void _initPostLikeState(Post post) {
    if (post.id == null) return;
    if (_likedPosts.containsKey(post.id)) return;
    final userId = authProvider.loginUserData.id;
    _likedPosts[post.id!] = post.users_love_id?.contains(userId) ?? false;
    _lovesCount[post.id!] = post.loves ?? 0;
  }

  /// Prépare l'état du j'aime puis relit une fois la publication à l'API (pièces reçues, compteurs).
  /// Plus de flux en direct : l'écran est rafraîchi après chaque action.
  void _subscribeToPostUpdates(Post post) {
    if (post.id == null || !_postRefreshed.add(post.id!)) return;
    _initPostLikeState(post);
    PubApi.fresh(post.id!).then((updatedPost) {
      if (updatedPost == null || !mounted) return;
      setState(() {
        final index = _videoPosts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          updatedPost.user = _videoPosts[index].user;
          updatedPost.canal = _videoPosts[index].canal;
          _videoPosts[index] = updatedPost;
        }
        final feedIndex = _feedItems.indexWhere((e) => e is Post && e.id == post.id);
        if (feedIndex != -1) {
          final old = _feedItems[feedIndex] as Post;
          updatedPost.user ??= old.user;
          updatedPost.canal ??= old.canal;
          _feedItems[feedIndex] = updatedPost;
        }
        final userId = authProvider.loginUserData.id;
        if (userId != null && post.id != null && !_pendingLikePostIds.contains(post.id)) {
          _likedPosts[post.id!] = updatedPost.users_love_id?.contains(userId) ?? _likedPosts[post.id!] ?? false;
          _lovesCount[post.id!] = updatedPost.loves ?? 0;
        }
      });
    }).catchError((e) {
      _postRefreshed.remove(post.id);
      printVm('Erreur lecture publication: $e');
    });
  }

  // ==================== VIDEO INIT & PLAYBACK ====================

  /// Orientation réelle de la vidéo : retenue pour la suite ; si la vidéo ouverte est en PAYSAGE alors que l'API ne le savait pas, on passe à la page paysage.
  bool _learnOrientation(Post post) {
    final c = _currentVideoController;
    if (c == null || !c.value.isInitialized) return false;
    final unknown = PostOrientation.isUnknown(post);
    PostOrientation.learn(post, c.value.size.width, c.value.size.height);
    if (unknown && post.isPortrait == false && mounted && widget.initialPost?.id == post.id) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VideoYoutubePageDetails(initialPost: post, isIn: true, feedTier: widget.feedTier)));
      return true;
    }
    return false;
  }

  Future<void> _recordPostView(Post post) async {
    if (post.id == null) return;
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;
    try {
      await _markPostAsSeen(post);
      if (post.users_vue_id != null && post.users_vue_id!.contains(currentUserId)) return;
      await PubApi.view(post.id!);
      ApiGateway.instance.noteSeen(post.id!);   // quitte le stock des vidéos du téléphone
      setState(() {
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id = [...?post.users_vue_id, currentUserId];
      });
      PostViewService.recordAuthorView(post, currentUserId);
    } catch (e) { printVm('Erreur enregistrement vue: $e'); }
  }

  Future<void> _markPostAsSeen(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;
    final key = 'viewed_${post.id}_$currentUserId';
    final hasSeen = _prefs.getBool(key) ?? false;
    if (!hasSeen) {
      await _prefs.setBool(key, true); // la liste des vidéos vues est tenue par le serveur (PubApi.view)
    }
  }

  // ==================== SCROLL HINT & FIRST MODAL ====================

  Future<void> _loadSuggestionsModalPreference() async {
    final userId = authProvider.loginUserData.id;
    final key = 'has_seen_suggestions_modal_video_$userId';
    _hasSeenSuggestionsModal = _prefs.getBool(key) ?? false;
  }

  void _startSuggestionModalTimer() {
    // Vérifier si le modal doit être affiché
    _shouldShowSuggestionsModal().then((shouldShow) {
      if (!shouldShow) return;

      _suggestionModalTimer?.cancel();
      _suggestionModalTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _showFirstScrollModal();
        }
      });
    });
  }

  Future<bool> _shouldShowSuggestionsModal() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return false;

    final lastShowKey = 'suggestions_modal_last_show_$userId';
    final lastShowTimestamp = _prefs.getInt(lastShowKey);

    // Une seule fois par compte : affiché seulement s'il ne l'a jamais été
    return lastShowTimestamp == null;
  }

  Future<void> _markSuggestionsModalSeen() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    final lastShowKey = 'suggestions_modal_last_show_$userId';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Sauvegarder la date et l'heure actuelles
    await _prefs.setInt(lastShowKey, now);

    // Optionnel : garder aussi le booléen pour d'autres usages
    await _prefs.setBool('has_seen_suggestions_modal_video_$userId', true);

    if (mounted) {
      setState(() => _hasSeenSuggestionsModal = true);
    }
  }

  void _showFirstScrollModal() {
    _markSuggestionsModalSeen();   // noté dès l'ouverture : il ne revient plus
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [Icon(Icons.swipe_vertical, color: colors.accentText), const SizedBox(width: 8), Text('Astuces Vidéo', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Astuce 1 : Scroll
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.swipe_vertical, color: colors.accentText, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Glisser pour découvrir', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Défiler vers le haut ou le bas pour voir d\'autres vidéos tendance.', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
            const SizedBox(height: 12),

            // Astuce 2 : Double tap pour liker
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.danger.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.favorite, color: colors.danger, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Double tap pour aimer', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Tapez deux fois rapidement sur la vidéo pour envoyer un like ❤️', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms).slideX(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
            const SizedBox(height: 12),

            // Astuce 3 : Pièces et cadeaux (optionnel)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.card_giftcard, color: colors.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cadeaux et soutien', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Envoyez des cadeaux ou soutenez les créateurs avec les boutons à droite.', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms, delay: 160.ms).slideX(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _markSuggestionsModalSeen();
            },
            child: Text('Compris !', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }
  void _showFirstScrollModalIfNeeded() async {
    final userId = authProvider.loginUserData.id;
    final key = 'first_scroll_modal_shown_$userId';
    final shown = _prefs.getBool(key) ?? false;
    if (!shown && mounted) {
      await _prefs.setBool(key, true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showFirstScrollModal();
      });
    }
  }

  void _showFlyingHearts(double tapX, double tapY) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Couleurs de cœurs (rouge, rose, orange, jaune)
    final List<Color> heartColors = [
      Colors.red,
      Colors.pink,
      Colors.deepOrange,
      Colors.orange,
      Colors.pinkAccent,
    ];

    // Créer entre 8 et 12 cœurs à chaque double tap
    // final heartCount = 8 + _random.nextInt(5);
    final heartCount = 15;

    for (int i = 0; i < heartCount; i++) {
      // Position X de départ légèrement aléatoire autour du point de tap
      final startX = tapX + (_random.nextDouble() - 0.5) * 40;
      final startY = tapY + (_random.nextDouble() - 0.5) * 30;

      // Direction : plutôt vers le haut avec un peu de côté
      final angle = (-pi / 2) + (_random.nextDouble() - 0.5) * (pi / 1.5);
      final distance = 150 + _random.nextDouble() * 150;

      final endX = startX + (cos(angle) * distance);
      final endY = startY - (80 + _random.nextDouble() * 120); // Monter vers le haut

      // Taille variée
      final size = 25 + _random.nextDouble() * 35;

      // Rotation aléatoire
      final rotation = (_random.nextDouble() - 0.5) * pi / 2;

      // Durée de l'animation (entre 0.6 et 1.2 secondes)
      final duration = Duration(milliseconds: (600 + _random.nextInt(600)).toInt());

      // Couleur aléatoire
      final color = heartColors[_random.nextInt(heartColors.length)];

      _flyingHearts.add(FlyingHeart(
        startX: startX.clamp(20, screenWidth - 20),
        startY: startY,
        endX: endX.clamp(20, screenWidth - 20),
        endY: endY,
        size: size,
        startTime: DateTime.now(),
        duration: duration,
        rotation: rotation,
        color: color,
      ));
    }

    setState(() {});

    // Nettoyage après 1.5 secondes
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _flyingHearts.clear();
        });
      }
    });
  }
  List<Widget> _buildFlyingHearts() {
    final widgets = <Widget>[];

    for (int i = 0; i < _flyingHearts.length; i++) {
      final heart = _flyingHearts[i];

      widgets.add(
        _AnimatedHeart(
          key: ValueKey('heart_$i'),
          heart: heart,
        ),
      );
    }

    return widgets;
  }
  Future<void> _handleLike(Post post) async {
    if (_isLiking) return;
    if (post.id == null) return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    // Source de vérité : Maps locales (résistantes aux replacements de _videoPosts)
    final alreadyLiked = _likedPosts[post.id] ?? (post.users_love_id?.contains(userId) ?? false);
    final previousCount = _lovesCount[post.id] ?? post.loves ?? 0;

    // Marquer comme "en vol" pour protéger l'update optimiste contre le snapshot Firestore
    _pendingLikePostIds.add(post.id!);

    setState(() {
      _isLiking = true;
      _likedPosts[post.id!] = !alreadyLiked;
      _lovesCount[post.id!] = alreadyLiked
          ? (previousCount - 1).clamp(0, 999999)
          : previousCount + 1;
      if (!alreadyLiked) {
        final screenSize = MediaQuery.of(context).size;
        _showFlyingHearts(screenSize.width / 2, screenSize.height / 2);
      }
    });

    void _finalizeLike() {
      _pendingLikePostIds.remove(post.id);
      if (mounted) setState(() => _isLiking = false);
    }

    if (alreadyLiked) {
      PubApi.setLike(post.id!, false).catchError((e) {
        if (mounted) {
          setState(() {
            _likedPosts[post.id!] = true;
            _lovesCount[post.id!] = previousCount;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PubApi.message(e))));
        }
      }).whenComplete(_finalizeLike);
    } else {
      _processLikeBackground(post, userId, alreadyLiked, previousCount);
    }
  }

  void _processLikeBackground(Post post, String userId, bool alreadyLiked, int previousCount) {
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    coinProvider.sendLikeWithCoins(
      senderId: userId,
      receiverId: post.user_id!,
      post: post,
      context: context,
      onReadyToAnimate: () {
        if (!mounted) return;
        showLikeOverlay(context, creatorName: post.user?.pseudo ?? '');
      },
    ).then((success) {
      if (!mounted) return;
      if (!success) {
        // Pas de pièces : le serveur refuse le j'aime ; on annule l'affichage et on propose de recharger
        setState(() {
          _likedPosts[post.id!] = false;
          _lovesCount[post.id!] = previousCount;
        });
        if (mounted) _showInsufficientCoinsForLikeDialog();
        return;
      }
      if (!alreadyLiked) {
        postProvider.interactWithPostAndIncrementSolde(post.id!, userId, "like", post.user_id!);
        authProvider.incrementPostTotalInteractions(postId: post.id!);
        _sendLikeNotification(post);
      }
    }).catchError((e) {
      // Erreur : on annule l'affichage et on affiche le message
      if (mounted) {
        setState(() {
          _likedPosts[post.id!] = false;
          _lovesCount[post.id!] = previousCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PubApi.message(e))));
      }
    }).whenComplete(() {
      _pendingLikePostIds.remove(post.id);
      if (mounted) setState(() => _isLiking = false);
    });
  }

  void _triggerSupportMessage() {
    if (!mounted) return;
    showLikeOverlay(context);
  }

  void _showInsufficientCoinsForLikeDialog() {
    showInsufficientCoinsForLikeDialog(
      context: context,
      user: authProvider.loginUserData,
      coinProvider: Provider.of<CoinGiftUserProvider>(context, listen: false),
      authProvider: authProvider,
    );
  }
  Future<void> _handleLike3(Post post) async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    final isLiked = post.users_love_id?.contains(userId) ?? false;
    if (isLiked) return;
    try {
      await PubApi.setLike(post.id!, true);
      setState(() {
        post.loves = (post.loves ?? 0) + 1;
        post.users_love_id = [...?post.users_love_id, userId];
      });
      postProvider.interactWithPostAndIncrementSolde(post.id!, userId, "like", post.user_id!);
      authProvider.incrementPostTotalInteractions(postId: post.id!);
      _sendLikeNotification(post);
    } catch (e) { printVm('Erreur like: $e'); }
  }

  Future<void> _sendLikeNotification(Post post) async {
    final currentUser = authProvider.loginUserData;
    final postOwnerId = post.user_id;
    if (postOwnerId == currentUser.id) return;
    await authProvider.sendNotification(
      userIds: [post.user?.oneIgnalUserid ?? ''],
      smallImage: currentUser.imageUrl ?? '',
      send_user_id: currentUser.id!,
      recever_user_id: postOwnerId!,
      message: "@${currentUser.pseudo} a aimé votre vidéo",
      type_notif: NotificationType.POST.name,
      post_id: post.id!,
      post_type: PostDataType.VIDEO.name,
      chat_id: '',
    );
  }

  void _showCommentsModal(Post post) {
    authProvider.incrementPostTotalInteractions(postId: post.id!);
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Commentaires', style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: Icon(Icons.close, color: colors.textPrimary), onPressed: () => Navigator.pop(context))])),
            Expanded(child: PostComments(post: post)),
          ],
        ),
      ).animate().slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOut).fadeIn(duration: 250.ms),
    );
  }
  void _showInsufficientBalanceDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Solde insuffisant', style: TextStyle(color: colors.accentText)),
        content: Text('Rechargez votre compte pour envoyer un cadeau.', style: TextStyle(color: colors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: colors.textPrimary))),
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const CoinRechargeScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: colors.primary), child: Text('Recharger', style: TextStyle(color: colors.onPrimary))),
        ],
      ),
    );
  }


  Future<void> _handleRepost(Post post) async {
    await PostSocialActions.repost(context, post, myId: authProvider.loginUserData.id, onDone: () {
      if (mounted) setState(() {});
    });
  }

  void _sharePost(Post post) async {
    setState(() => _isSharing = true);
    try {
      final shareUrl = post.dataType == PostDataType.VIDEO.name
          ? (post.thumbnail ?? '')
          : (post.images?.isNotEmpty == true ? post.images!.first : '');
      final linkService = AppLinkService();
      await linkService.shareContent(type: AppLinkType.post, id: post.id!, message: post.description ?? '', mediaUrl: shareUrl);
      final shared = await PubApi.share(post.id!);
      setState(() {
        post.partage = shared.count ?? ((post.partage ?? 0) + (shared.counted ? 1 : 0));
        post.users_partage_id ??= [];
        post.users_partage_id!.add(authProvider.loginUserData.id!);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Partagé !'), backgroundColor: AppColors.of(context).primary));
    } catch (e) { printVm('Erreur partage: $e'); } finally { setState(() => _isSharing = false); }
  }

  void _showPostMenu(Post post) {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (CardEntry.canMake(post, authProvider.loginUserData))
              CardMenuTile(
                onTap: () {
                  Navigator.pop(context);
                  CardEntry.openFromPost(this.context, post);
                },
              ),
            if (DefiConvert.canConvert(post, authProvider.loginUserData))
              DefiMenuTile(
                onTap: () {
                  Navigator.pop(context);
                  DefiConvert.openFromPost(this.context, post);
                },
              ),
            // Bouton Partager (externe)
            ListTile(
              leading: Icon(Icons.share, color: colors.info),
              title: Text('Partager', style: TextStyle(color: colors.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                 _sharePost(post);
              },
            ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            if (post.user_id != authProvider.loginUserData.id)
              ListTile(
                leading: Icon(Icons.repeat, color: colors.success),
                title: Text(tr('Republier'), style: TextStyle(color: colors.textPrimary)),
                onTap: () { Navigator.pop(context); _handleRepost(post); },
              ).animate().fadeIn(duration: 200.ms, delay: 20.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            // Bouton Envoyer dans le chat
            ListTile(
              leading: Icon(Icons.send_rounded, color: colors.primary),
              title: Text('Envoyer dans un chat', style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                showResponsiveBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PostShareSheet(post: post),
                );
              },
            ).animate().fadeIn(duration: 200.ms, delay: 40.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            if (post.user_id != authProvider.loginUserData.id) ...[
              if (authProvider.loginUserData.role == UserRole.ADM.name) ...[
                ListTile(
                  leading: Icon(Icons.gavel, color: Colors.orange.shade700),
                  title: Text('Modérer ce post', style: TextStyle(color: Colors.orange.shade700)),
                  onTap: () => _reportPostWithScore(post, isAdmin: true, reportType: 'standard'),
                ).animate().fadeIn(duration: 200.ms, delay: 40.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),
                ListTile(
                  leading: Icon(Icons.category_outlined, color: Colors.deepOrange.shade700),
                  title: Text('Hors catégorie (admin)', style: TextStyle(color: Colors.deepOrange.shade700)),
                  onTap: () => _reportPostWithScore(post, isAdmin: true, reportType: 'wrong_category'),
                ).animate().fadeIn(duration: 200.ms, delay: 60.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),
              ] else ...[
                if (!(post.reporterIds?.contains(authProvider.loginUserData.id) ?? false))
                  ListTile(
                    leading: Icon(Icons.flag_outlined, color: colors.textPrimary),
                    title: Text('Signaler', style: TextStyle(color: colors.textPrimary)),
                    onTap: () => _reportPostWithScore(post, isAdmin: false, reportType: 'standard'),
                  ).animate().fadeIn(duration: 200.ms, delay: 40.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),
                if (!(post.wrongCategoryReporterIds?.contains(authProvider.loginUserData.id) ?? false))
                  ListTile(
                    leading: Icon(Icons.category_outlined, color: colors.textSecondary),
                    title: Text('Contenu hors catégorie', style: TextStyle(color: colors.textSecondary)),
                    onTap: () => _reportPostWithScore(post, isAdmin: false, reportType: 'wrong_category'),
                  ).animate().fadeIn(duration: 200.ms, delay: 60.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),
              ],
              if (post.user_id != null)
                ListTile(
                  leading: Icon(Icons.block, color: colors.danger),
                  title: Text('Bloquer cet utilisateur', style: TextStyle(color: colors.danger)),
                  onTap: () async {
                    Navigator.pop(context);
                    final blocked = await confirmAndBlockUser(
                      this.context,
                      userId: post.user_id!,
                      pseudo: post.user?.pseudo,
                      postId: post.id,
                    );
                    if (blocked && mounted) Navigator.pop(this.context);
                  },
                ).animate().fadeIn(duration: 200.ms, delay: 80.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),
            ],

            if (post.user_id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(
                leading: Icon(Icons.delete, color: colors.danger),
                title: Text('Supprimer', style: TextStyle(color: colors.danger)),
                onTap: () {
                  Navigator.pop(context);
                  // Utilise le contexte de la page, pas celui du sheet (déjà fermé)
                  _confirmAndDeletePost(post);
                },
              ).animate().fadeIn(duration: 200.ms, delay: 80.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            // Option "Booster ce post" — créateur + admin uniquement
            if (post.user_id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(
                leading: Icon(Icons.rocket_launch, color: colors.accentText),
                title: Text('Booster ce post', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Transformer en publicité', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => boostPageFor(post),
                    ),
                  );
                },
              ).animate().fadeIn(duration: 200.ms, delay: 100.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            Divider(color: colors.divider),

            ListTile(
              leading: Icon(Icons.cancel, color: colors.textPrimary),
              title: Text('Annuler', style: TextStyle(color: colors.textPrimary)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _reportPostWithScore(Post post, {required bool isAdmin, required String reportType}) async {
    Navigator.pop(context);
    try {
      await PubApi.report(post.id!, type: reportType == 'wrong_category' ? 'wrong_category' : 'standard');
      if (mounted) {
        final msg = reportType == 'wrong_category' ? 'Signalé comme hors catégorie.' : 'Post signalé.';
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg, style: TextStyle(color: c.success)),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        final msg = e.status == 409 ? 'Tu as déjà signalé ce post.' : PubApi.message(e, fallback: 'Erreur.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PubApi.message(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmAndDeletePost(Post post) async {
    if (!mounted) return;
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.delete_forever_rounded, color: colors.danger, size: 24),
          const SizedBox(width: 10),
          Text('Supprimer la vidéo', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text(
          'Cette vidéo sera supprimée définitivement. Cette action est irréversible.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: colors.primary)),
    );

    try {
      await PubApi.delete(post.id!);
      if (!mounted) return;
      Navigator.pop(context); // ferme le loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text('Vidéo supprimée avec succès'),
        ]),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
      if (_videoPosts.length <= 1) Navigator.pop(context);
    } catch (e) {
      printVm('Erreur suppression: $e');
      if (!mounted) return;
      Navigator.pop(context); // ferme le loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.error_outline, color: Colors.white),
          SizedBox(width: 10),
          Text('Échec de la suppression. Réessaie.'),
        ]),
        backgroundColor: colors.danger,
        duration: const Duration(seconds: 4),
      ));
    }
  }







  void _showError(String msg) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colors.danger));
  }
  void _showSuccess(String msg) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colors.success));
  }

  // ==================== SUPPORT AD ====================
  Future<void> _loadSupportModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;
    _hasSeenSupportModal = prefs.getBool('has_seen_support_modal_$userId') ?? false;
  }

  Future<void> _handleSupportAd(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == post.user_id) { _showError(tr('Tu ne peux pas soutenir ta propre publication.')); return; }
    final hasSupported = await PostSocialApi.supportedToday(post.id!);
    if (hasSupported) { _showError(tr('Tu as déjà soutenu cette publication aujourd\'hui. Reviens demain !')); return; }
    if (_hasSeenSupportModal == false) {
      _showSupportModal(post);
    } else {
      _startSupportAd(post);
    }
  }

  void _showSupportModal(Post post) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.surface,
        title: Row(children: [Icon(Icons.volunteer_activism, color: colors.accentText), const SizedBox(width: 8), Text('Soutenir le créateur', style: TextStyle(color: colors.textPrimary))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Regarde cette publicité jusqu\'au bout pour offrir 1 pièce au créateur.'), style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.monetization_on, color: colors.accentText), const SizedBox(width: 8), Expanded(child: Text('Les pièces peuvent être converties en argent réel.', style: TextStyle(color: colors.textPrimary)))])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Plus tard', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await _markSupportModalSeen(); _startSupportAd(post); }, style: ElevatedButton.styleFrom(backgroundColor: colors.accent), child: Text('Regarder la pub', style: TextStyle(color: colors.onAccent))),
        ],
      ),
    );
  }

  Future<void> _markSupportModalSeen() async {
    final userId = authProvider.loginUserData.id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_support_modal_$userId', true);
    _hasSeenSupportModal = true;
  }

  /// Pub récompensée regardée en entier, déclarée au serveur puis consommée par `POST /posts/{id}/support-ad` (messages et « Réessayer » inclus).
  Future<void> _startSupportAd(Post post) async {
    if (_isSupporting) return;
    setState(() => _isSupporting = true);
    await PostSocialActions.supportWithAd(context, post, myId: authProvider.loginUserData.id, onSupported: (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _isSupporting = false);
  }

  // ==================== UI BUILD ====================

  Widget _buildVideoPlayer(Post post) {
    // Sur Flutter Web : lecteur HTML natif (contourne video_player_web)
    if (kIsWeb) {
      final url = post.url_media;
      if (url == null || url.isEmpty) {
        return Container(
          color: _afroBlack,
          child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 48)),
        );
      }
      return SmartVideoPlayer(url: url, autoPlay: true, looping: true, progressColor: _afroGreen);
    }
    if (!_isVideoInitialized) {
      return Container(
        color: _afroBlack,
        child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _afroGreen), SizedBox(height: 16), Text('Chargement...', style: TextStyle(color: Colors.white))])),
      );
    }
    return Chewie(controller: _chewieController!);
  }

  Widget _buildUserInfo(Post post) {
    // Lance le chargement si nécessaire (sans await)
    if ((post.user == null && post.user_id != null) ||
        (post.canal == null && post.canal_id != null)) {
      _lazyLoadPostRelations(post);
    }

    final isOwner = authProvider.loginUserData.id == post.user_id;

    return Positioned(
      bottom: 165,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.isRepost == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  if (post.reposterImageUrl != null && post.reposterImageUrl!.isNotEmpty)
                    ClipOval(
                      child: Image.network(post.reposterImageUrl!, width: 14, height: 14, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.repeat, size: 12, color: Colors.white70)),
                    )
                  else
                    const Icon(Icons.repeat, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    tr('@{p} a republié', {'p': post.reposterPseudo ?? post.reposterUserId ?? tr('quelqu\'un')}),
                    style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          if (postTimeAgo(post.createdAt).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(postTimeAgo(post.createdAt), style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 4),
          if (post.description != null)
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _translatedDescriptions[post.id] ?? post.description!,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.id != null)
                    TranslatableDescription(
                      postId: post.id!,
                      text: post.description!,
                      targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
                      style: const TextStyle(color: Colors.white),
                      onToggle: (translated) => setState(() {
                        if (translated == null) {
                          _translatedDescriptions.remove(post.id);
                        } else {
                          _translatedDescriptions[post.id!] = translated;
                        }
                      }),
                    ),
                ],
              ),
            ),
          PostGiftsList(postId: post.id!, compactLevel: CompactLevel.light, maxDisplayItems: 10),
          // Musique et template du post : « Utiliser · 🪙 5 », « Essayer ce template »
          PostCtaRow(post: post, dark: true),
          _buildPostScoreBadge(post),
          // Pièces reçues (likes + commentaires + cadeaux), tout petit sous le score
          if (post.isAdvertisement != true)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: PostCoinsChip(post: post, mini: true),
            ),

          // ── Section DÉFI — card info ──────────────────────────────
          if (post.type == PostType.DEFI.name)
            DefiDetailsSection(
              defiPost: post,
              currentUserId: Provider.of<UserAuthProvider>(context, listen: false).loginUserData?.id ?? '',
            ),
          if (post.defiResponseToPostId != null)
            DefiResponseBanner(
              responsePost: post,
              currentUserId: Provider.of<UserAuthProvider>(context, listen: false).loginUserData?.id ?? '',
              onTap: (defiPost) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailsPost(post: defiPost)),
              ),
            ),

          // ── Participations DÉFI ───────────────────────────────────
          if (post.type == PostType.DEFI.name)
            DefiResponsesFeed(
              defiPostId: post.id!,
              currentUserId: Provider.of<UserAuthProvider>(context, listen: false).loginUserData?.id ?? '',
              isDefiOver: (post.defiConfig?.isTermine ?? false) ||
                  ((post.defiConfig?.endDate ?? 0) > 0 &&
                      DateTime.fromMillisecondsSinceEpoch(post.defiConfig!.endDate).isBefore(DateTime.now())),
            ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.08, end: 0, duration: 400.ms, curve: Curves.easeOut),
    );
  }

  Widget _buildPostScoreBadge(Post post) {
    final score = post.postScore ?? 0.0;
    if (score <= 0 || score.isNaN || score.isInfinite) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final color = score >= 50
        ? const Color(0xFF4CAF50)
        : score >= 20
            ? const Color(0xFFFFD700)
            : colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(children: [
        Icon(Icons.trending_up_rounded, size: 13, color: color),
        const SizedBox(width: 4),
        Text('Score : ${score >= 10 ? score.round() : score.toStringAsFixed(1)}',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // Widget _buildActionButtons(Post post) {
  //   final isLiked = post.users_love_id?.contains(authProvider.loginUserData.id) ?? false;
  //   return Positioned(
  //     right: 16,
  //     bottom: 90,
  //     child: Column(
  //       children: [
  //         GestureDetector(
  //           behavior: HitTestBehavior.opaque,
  //           onTap: () {
  //             final user = post.user;
  //             final canal = post.canal;
  //
  //             if (canal != null) {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(
  //                   builder: (context) => CanalDetails(canal: canal),
  //                 ),
  //               );
  //             } else if (user != null) {
  //               showUserDetailsModalDialog(
  //                 user,
  //                 MediaQuery.of(context).size.width,
  //                 MediaQuery.of(context).size.height,
  //                 context,
  //               );
  //             }
  //           },
  //           child: Stack(
  //             clipBehavior: Clip.none,
  //             children: [
  //               Container(
  //                 decoration: BoxDecoration(
  //                   border: Border.all(color: _afroGreen, width: 2),
  //                   shape: BoxShape.circle,
  //                 ),
  //                 child: CircleAvatar(
  //                   radius: 25,
  //                   backgroundImage: NetworkImage(
  //                     post.canal?.urlImage ??
  //                         post.user?.imageUrl ??
  //                         '',
  //                   ),
  //                 ),
  //               ),
  //               _buildSubscribeIcon(post),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(height: 20),
  //         if (_isLookChallenge)
  //           Column(
  //             children: [
  //               GestureDetector(
  //                 behavior: HitTestBehavior.opaque,
  //                 onTap: _voteForLook,
  //                 child: Icon(
  //                   _hasVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined,
  //                   color: _hasVoted ? _afroGreen : Colors.white,
  //                   size: 35,
  //                 ),
  //               ),
  //               Text('${post.votesChallenge ?? 0}', style: const TextStyle(color: Colors.white))
  //             ],
  //           ),
  //         Column(
  //           children: [
  //             GestureDetector(
  //               behavior: HitTestBehavior.opaque,
  //               onTap: () => _handleLike(post),
  //               child: const Icon(
  //                 Icons.favorite_border,
  //                 color: _afroRed,
  //                 size: 30,
  //               ),
  //             ),
  //             Text('${post.loves ?? 0}', style: const TextStyle(color: Colors.white))
  //           ],
  //         ),
  //         Column(
  //           children: [
  //             GestureDetector(
  //               behavior: HitTestBehavior.opaque,
  //               onTap: () => _showCommentsModal(post),
  //               child: const Icon(
  //                 Icons.chat_bubble_outline,
  //                 color: Colors.white,
  //                 size: 33,
  //               ),
  //             ),
  //             Text('${post.comments ?? 0}', style: const TextStyle(color: Colors.white))
  //           ],
  //         ),
  //         if (post.type != PostType.CHALLENGEPARTICIPATION.name)
  //           Column(
  //             children: [
  //               GestureDetector(
  //                 behavior: HitTestBehavior.opaque,
  //                 onTap: () => _showGiftDialog(post),
  //                 child: const Icon(
  //                   Icons.card_giftcard,
  //                   color: _afroYellow,
  //                   size: 30,
  //                 ),
  //               ),
  //               Text('${post.totalGiftCoinsSentOnThisPost ?? 0}', style: const TextStyle(color: Colors.white))
  //             ],
  //           ),
  //         Column(
  //           children: [
  //             GestureDetector(
  //               behavior: HitTestBehavior.opaque,
  //               onTap: () {},
  //               child: const Icon(
  //                 Icons.bar_chart,
  //                 color: Colors.blue,
  //                 size: 35,
  //               ),
  //             ),
  //             Text('${post.totalInteractions ?? 0}', style: const TextStyle(color: Colors.white))
  //           ],
  //         ),
  //         // Au lieu du bouton partage, on met le bouton favoris
  //         Column(
  //         children: [
  //         GestureDetector(
  //         behavior: HitTestBehavior.opaque,
  //   onTap: _toggleFavorite,
  //   child: Icon(
  //   _isFavorite ? Icons.bookmark : Icons.bookmark_border,
  //   color: _isFavorite ? _afroYellow : Colors.white,
  //   size: 30,
  //   ),
  //   ),
  //   Text(
  //   _formatNumber(_favoritesCount),
  //   style: const TextStyle(color: Colors.white)
  //   ),
  //   ],
  //   ),
  //         GestureDetector(
  //           behavior: HitTestBehavior.opaque,
  //           onTap: () => _showPostMenu(post),
  //           child: const Icon(
  //             Icons.more_vert,
  //             color: Colors.white,
  //             size: 30,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _loadLastCommentForPost(Post post) async {
    final postId = post.id;
    if (postId == null) return;
    try {
      // Cache partagé : une seule lecture (5 commentaires, auteurs des 3 premiers) pour tous les écrans, prête avant l'ouverture des commentaires
      final page = await CommentsPrefetch.instance.first(postId);
      if (page.comments.isNotEmpty && mounted) {
        setState(() {
          _preloadedComments = List.of(page.comments);
        });
      }
    } catch (_) {}
  }

  void _autoLikeIfNeeded(String userId, Post post) {
    final postId = post.id;
    if (postId == null) return;
    final alreadyLiked = _likedPosts[postId] ?? (post.users_love_id?.contains(userId) ?? false);
    if (alreadyLiked) return;
    PubApi.setLike(postId, true).catchError((_) {});
    if (mounted) setState(() {
      _likedPosts[postId] = true;
      post.users_love_id = [...?post.users_love_id, userId];
      post.loves = (post.loves ?? 0) + 1;
    });
  }

  Future<void> _sendQuickComment(String text, Post post, {StickerItem? sticker}) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && sticker == null) || _isSendingQuickComment) return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    setState(() {
      _isSendingQuickComment = true;
      _quickCommentController.clear();
    });

    try {
      final comment = PostComment(
        media: sticker?.toMedia(),
        id: 'tmp_${DateTime.now().microsecondsSinceEpoch}',
        user_id: userId,
        user: authProvider.loginUserData,
        post_id: post.id,
        users_like_id: [],
        responseComments: [],
        message: trimmed,
        loves: 0,
        likes: 0,
        comments: 0,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
      );

      final success = await postProvider.newComment(comment);
      // 2 pièces (1 au créateur) — publié même sans solde
      if (success && mounted) CommentCoins.charge(context, post);

      if (success && mounted) {
        setState(() {
          _preloadedComments.insert(0, comment);
            CommentsPrefetch.instance.addLocal(comment.post_id ?? '', comment);
          post.comments = (post.comments ?? 0) + 1;
        });
        _addLiveComment();
        authProvider.incrementPostTotalInteractions(postId: post.id!);
        authProvider.notifySubscribersOfInteraction(
          actionUserId: userId,
          postOwnerId: post.user_id!,
          postId: post.id!,
          actionType: 'comment',
          commentaireMessage: trimmed,
          isSticker: sticker != null,
          excludeUserIds: [post.user_id!],
          postDescription: post.description,
          postImageUrl: post.thumbnail ?? post.user?.imageUrl ?? '',
          postDataType: post.dataType,
        );
        _autoLikeIfNeeded(userId, post);
        FeedInteractionService.onPostCommented(post, userId);
        try {
          final result = await StreakService.onCommentSent(
            userId: userId,
            postId: post.id!,
          );
          if (mounted) context.read<StreakProvider>().updateFromResult(result);
        } catch (e) {
          debugPrint('[Streak] erreur quickComment audio: $e');
        }

        if (post.user != null && post.user!.id != userId) {
          try {
            final msg = sticker != null
                ? "@${authProvider.loginUserData.pseudo!} a envoyé un sticker sur votre vidéo"
                : "@${authProvider.loginUserData.pseudo!} a commenté votre vidéo";
            // la notification enregistrée est créée par le serveur à l'envoi du commentaire
            final receiverUser = await authProvider.getUserById(post.user!.id!);
            if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
              await authProvider.sendNotification(
                userIds: [receiverUser.first.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl!,
                send_user_id: userId,
                recever_user_id: post.user!.id!,
                message: msg,
                type_notif: NotificationType.POST.name,
                post_id: post.id!,
                post_type: PostDataType.COMMENT.name,
                chat_id: '',
              );
            }
          } catch (_) {}
        }
      }

      if (success && mounted) {
        _showCommentsModal(post);
      }
    } finally {
      if (mounted) setState(() => _isSendingQuickComment = false);
    }
  }

  Widget _buildQuickCommentOverlay(Post post) {
    final colors = AppColors.of(context);
    final rawMsg = _preloadedComments.isNotEmpty ? _preloadedComments.first.message : null;
    final msg = rawMsg != null && rawMsg.trim().isNotEmpty ? rawMsg.trim() : null;

    return Positioned(
      left: 12,
      right: 72,
      bottom: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg != null)
            GestureDetector(
              onTap: () => _showCommentsModal(post),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over_outlined, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 5),
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickCommentController,
                    enabled: !_isSendingQuickComment,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) => _sendQuickComment(v, post),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un commentaire…',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                StickerQuickButton(
                  postId: post.id,
                  onPicked: (s) => _sendQuickComment(_quickCommentController.text, post, sticker: s),
                ),
                GestureDetector(
                  onTap: () => _sendQuickComment(_quickCommentController.text, post),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _isSendingQuickComment
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 14, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Post post) {
    if ((post.user == null && post.user_id != null) ||
        (post.canal == null && post.canal_id != null)) {
      _lazyLoadPostRelations(post);
    }

    final user = post.user;
    final canal = post.canal;
    // post de canal dont le canal n'est pas encore chargé : gabarit statique, jamais le créateur à la place du canal
    final bool canalPending = canal == null && post.canal_id != null && post.canal_id!.isNotEmpty;
    final String displayName = canal != null
        ? '#${canal.titre ?? ''}'
        : '@${user?.pseudo ?? ''}';
    final int subscriberCount = canal != null
        ? (canal.membersCount)
        : ((user?.followersCount ?? 0));

    return Positioned(
      right: 16,
      bottom: 90,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (canal != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal)));
              } else if (user != null) {
                showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(border: (canal != null || canalPending) ? null : Border.all(color: _afroGreen, width: 2), shape: BoxShape.circle),
                  child: canalPending
                      ? Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle))
                      : (canal == null && user == null)
                      ? const CircleAvatar(radius: 25, child: CircularProgressIndicator(strokeWidth: 2))
                      : SafeNetworkAvatar(url: canal?.urlImage ?? user?.imageUrl, radius: 25),
                ),
                if (!canalPending) _buildSubscribeIcon(post),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 62,
            child: canalPending
                ? Column(children: [
                    Container(width: 44, height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Container(width: 28, height: 8, decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(4))),
                  ])
                : Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: NameTag(
                        label: displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(width: 2),
                      UserBadgeWidget(user: user, size: 9),
                    ],
                  ],
                ),
                canal != null
                    ? Text(_formatNumber(subscriberCount), style: const TextStyle(color: Colors.white70, fontSize: 9))
                    : FollowersCountBuilder(
                        userId: user?.id ?? post.user_id,
                        fallback: subscriberCount,
                        builder: (_, c) => Text(_formatNumber(c), style: const TextStyle(color: Colors.white70, fontSize: 9)),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isLiking ? null : () => _handleLike(post),
            child: Column(
              children: [
                LikeCoinHeart(
                  icon: (_likedPosts[post.id] ?? (post.users_love_id?.contains(authProvider.loginUserData.id) ?? false))
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _afroRed,
                  size: 30,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.6),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Text(
                    '${_lovesCount[post.id] ?? post.loves ?? 0}',
                    key: ValueKey(_lovesCount[post.id] ?? post.loves ?? 0),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showCommentsModal(post),
            child: Column(children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 33),
              Text('${post.comments ?? 0}', style: const TextStyle(color: Colors.white)),
            ]),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Column(children: [
              const Icon(Icons.bar_chart, color: Colors.blue, size: 35),
              Text('${post.totalInteractions ?? 0}', style: const TextStyle(color: Colors.white)),
            ]),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleFavorite,
            child: Column(children: [
              Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border, color: _isFavorite ? _afroYellow : Colors.white, size: 30),
              Text(_formatNumber(_favoritesCount), style: const TextStyle(color: Colors.white)),
            ]),
          ),
          GestureDetector(
            onTap: () => _showPostMenu(post),
            child: const Icon(Icons.more_vert, color: Colors.white, size: 30),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut),
    );
  }

  // Fonction pour vérifier l'état d'abonnement et retourner l'icône appropriée
  Widget _buildSubscribeIcon(Post post) {
    final currentUserId = authProvider.loginUserData.id;

    // Si l'utilisateur n'est pas connecté, afficher l'icône d'abonnement
    if (currentUserId == null) {
      return Positioned(
        bottom: -2,
        right: -2,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 12,
          ),
        ),
      );
    }

    // Vérifier si c'est un post de canal
    if (post.canal_id != null && post.canal_id!.isNotEmpty) {
      // C'est un post de canal - vérifier si l'utilisateur est abonné au canal
      final isSubscribed = post.canal?.usersSuiviId?.contains(currentUserId) ?? false;

      // Si l'utilisateur n'est PAS abonné, afficher l'icône
      if (!isSubscribed) {
        return Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 12,
            ),
          ),
        );
      }
    }
    else if (post.user_id != null) {
      // C'est un post d'utilisateur - vérifier si l'utilisateur courant suit ce créateur
      final isFollowing = FollowService.isFollowing(authProvider.loginUserData, post.user);

      // Si l'utilisateur ne suit PAS le créateur, afficher l'icône
      if (!isFollowing) {
        return Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 12,
            ),
          ),
        );
      }
    }

    // Si l'utilisateur est déjà abonné ou suit déjà le créateur, ne rien afficher
    return const SizedBox.shrink();
  }

  Widget _buildScrollHint() {
    if (!_showScrollHint) return const SizedBox.shrink();
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showScrollHint ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: const Column(
          children: [
            Icon(Icons.swipe_vertical, color: _afroYellow, size: 36),
            SizedBox(height: 4),
            Text('Glisser pour vidéo suivante', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AD OVERLAY — affiché quand le post courant est une publicité
  // ============================================================

  Future<void> _ensureAdLoaded(Post post) async {
    if (post.id == null) return;
    if (_adCache.containsKey(post.id) || _loadingAdIds.contains(post.id)) return;
    _loadingAdIds.add(post.id!);
    try {
      // La fiche de la publicité n'est plus lue dans l'application (route à créer côté API : voir lacunes).
      Advertisement? ad;
      if (mounted) setState(() => _adCache[post.id!] = ad);
    } catch (_) {
      if (mounted) setState(() => _adCache[post.id!] = null);
    } finally {
      _loadingAdIds.remove(post.id!);
    }
  }

  Future<void> _recordAdViewForPost(Advertisement ad) async {
    if (ad.id == null) return;
    AdsEngineService.instance.view(ad.id!, format: 'video', slot: 'video');
  }

  Widget _adStatChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 11),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildVideoAdOverlay(Post post) {
    if (!_adCache.containsKey(post.id)) {
      _ensureAdLoaded(post);
    }
    final ad = post.id != null ? _adCache[post.id!] : null;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 12,
      right: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge SPONSORISÉ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.black, size: 12),
                SizedBox(width: 4),
                Text('SPONSORISÉ', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (ad != null) ...[
            const SizedBox(height: 8),
            // Stats
            Row(
              children: [
                _adStatChip(Icons.visibility, '${ad.views}'),
                const SizedBox(width: 6),
                _adStatChip(Icons.touch_app, '${ad.clicks}'),
                const SizedBox(width: 6),
                _adStatChip(Icons.percent, '${ad.ctr.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            // Bouton d'action
            GestureDetector(
              onTap: () async {
                if (ad.id != null) AdsEngineService.instance.click(ad.id!, format: 'video', slot: 'video');
                await AdActions.open(ad);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE21221), Color(0xFFFF5252)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ad.actionType == 'download' ? Icons.download
                          : ad.actionType == 'visit' ? Icons.language
                          : Icons.info,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(ad.getActionButtonText().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Live comments (style TikTok Live) ───────────────────────────────────

  void _addCommentToLiveFeed(PostComment comment) {
    if (!mounted) return;
    _visibleComments.insert(0, comment);
    _liveListKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 1200));
    // Limite à 5 commentaires visibles max — retire le plus ancien silencieusement
    if (_visibleComments.length > 5) {
      final lastIdx = _visibleComments.length - 1;
      final removed = _visibleComments.removeAt(lastIdx);
      _liveListKey.currentState?.removeItem(
        lastIdx,
        (ctx, anim) => _buildCommentBubble(removed, anim),
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  // Appelé quand l'utilisateur envoie un commentaire (déjà inséré dans _preloadedComments[0])
  void _addLiveComment() {
    if (!mounted || _preloadedComments.isEmpty) return;
    _addCommentToLiveFeed(_preloadedComments.first);
  }

  Future<void> _initLiveComments(Post post) async {
    _liveCommentTimer?.cancel();
    _visibleComments.clear();
    _commentCycleIdx = 0;
    if (mounted) setState(() { _preloadedComments = []; });

    await _loadLastCommentForPost(post);
    if (!mounted || _preloadedComments.isEmpty) return;

    if (mounted) setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _preloadedComments.isEmpty) return;
      // Premier commentaire immédiatement
      _addCommentToLiveFeed(
        _preloadedComments[_commentCycleIdx % _preloadedComments.length],
      );
      _commentCycleIdx++;

      // Puis un nouveau toutes les 8 secondes (cycle infini — montée lente)
      _liveCommentTimer = Timer.periodic(const Duration(milliseconds: 8000), (_) {
        if (!mounted || _preloadedComments.isEmpty) return;
        _addCommentToLiveFeed(
          _preloadedComments[_commentCycleIdx % _preloadedComments.length],
        );
        _commentCycleIdx++;
      });
    });
  }

  Widget _buildCommentBubble(PostComment c, Animation<double> animation) {
    // La bulle s'adapte à la longueur du texte (jusqu'à 70% de l'écran),
    // toujours sur une seule ligne avec ellipsis si trop long.
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.70;
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          // Align libère la contrainte de largeur → la bulle wrap son contenu
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '@${c.user?.pseudo ?? 'Anonyme'} ',
                        style: const TextStyle(
                          color: _afroGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: c.message ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCommentsOverlay() {
    final halfScreen = MediaQuery.of(context).size.height / 2;
    return Positioned(
      left: 12,
      right: 80,
      bottom: 215,
      // Purement visuel : sans IgnorePointer, cette grande zone bloquait les taps sur la
      // pastille de pièces et les infos du créateur qui passent dessous.
      child: IgnorePointer(
       child: SizedBox(
        height: halfScreen,
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Fondu doux : transparent en haut, opaque dès 40% vers le bas
            colors: [Colors.transparent, Colors.transparent, Colors.white],
            stops: [0.0, 0.38, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: AnimatedList(
            key: _liveListKey,
            reverse: true,      // index 0 = bas (nouveau commentaire)
            shrinkWrap: true,   // se réduit à sa hauteur réelle
            physics: const NeverScrollableScrollPhysics(),
            initialItemCount: _visibleComments.length,
            itemBuilder: (ctx, i, animation) {
              if (i >= _visibleComments.length) return const SizedBox.shrink();
              return _buildCommentBubble(_visibleComments[i], animation);
            },
          ),
        ),
       ),
      ),
    );
  }

  Widget _buildOverlayToggle() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 12,
      child: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _showOverlay ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPage(Post post, int index) {
    return Stack(
      children: [
        // Vidéo avec son propre détecteur de double tap
        Positioned.fill(
          child: GestureDetector(
            // translucent : les swipes atteignent le PageView même si le child (Chewie)
            // aurait normalement absorbé tous les événements tactiles.
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () {
              _handleLike(post);
            },
            child: IgnorePointer(
              // Chewie ajoute ses propres GestureDetectors (opaque) qui bloquent le
              // VerticalDragRecognizer du PageView sur toute la surface vidéo.
              // IgnorePointer désactive complètement leur hit-testing ; tous les gestes
              // sont gérés ici ou par le PageView parent.
              child: _buildVideoPlayer(post),
            ),
          ),
        ),

        // Overlay pub spécifique (badge + stats + bouton d'action) — toujours visible pour les pubs
        if (post.isAdvertisement == true) ...[
          _buildVideoAdOverlay(post),
          // Bouton 3-points toujours visible (remplace le toggle pour les pubs)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 12,
            child: GestureDetector(
              onTap: () => _showPostMenu(post),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.more_vert, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],

        // Overlay interactions (like / commentaire / partage / favoris)
        // Identique pour tous les posts, y compris les pubs.
        // Pour les pubs : toujours visible (opacity 1.0, non masquable).
        // Pour les posts normaux : contrôlé par _showOverlay.
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: post.isAdvertisement == true ? 1.0 : (_showOverlay ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 250),
            child: IgnorePointer(
              ignoring: post.isAdvertisement == true ? false : !_showOverlay,
              child: Stack(
                children: [
                  _buildActionButtons(post),
                  _buildQuickCommentOverlay(post),
                  _buildUserInfo(post),
                  // Hint de scroll uniquement pour les posts normaux
                  if (post.isAdvertisement != true) _buildScrollHint(),
                ],
              ),
            ),
          ),
        ),

        // Animation des cœurs (toujours visible même sans overlay)
        ..._buildFlyingHearts(),

        // Bouton toggle overlay — uniquement pour les posts normaux
        // (les pubs ont le bouton 3-points toujours visible à la place)
        if (post.isAdvertisement != true) _buildOverlayToggle(),

        if (widget.isIn)
          Positioned(
            top: 12,
            left: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.yellow)),
                    if (post.type == PostType.DEFI.name) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF9500),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events, color: Color(0xFFFF9500), size: 13),
                            SizedBox(width: 4),
                            Text('DÉFI', style: TextStyle(color: Color(0xFFFF9500), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Text('Vibe vidéos', style: TextStyle(color: _afroGreen, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        if (_isLoadingMore && _videoPosts.length - _currentPage <= _preloadThreshold)
          const Positioned(bottom: 100, child: Center(child: CircularProgressIndicator(color: _afroGreen))),

        // Badges Tier + Pays — uniquement pour le post initial (tier connu depuis le feed)
        if (_currentPage == 0 && (widget.feedTier != null || !(post.availableCountries.contains('ALL') || post.availableCountries.isEmpty)))
          Positioned(
            top: MediaQuery.of(context).padding.top + (widget.isIn ? 60 : 12),
            left: 12,
            child: _VideoPageBadges(post: post, feedTier: _currentPage == 0 ? widget.feedTier : null),
          ),
        // Cadeau rapide + badge — à droite, visible pour les non-propriétaires
        if (_currentPage == 0 && post.isAdvertisement != true && post.user_id != null && post.user_id != authProvider.loginUserData.id)
          Positioned(
            // Sous le bouton œil (top + 10, ~40 px) pour ne jamais le chevaucher
            top: MediaQuery.of(context).padding.top + 60,
            right: 12,
            child: CadeauBadge(
              receiverId: post.user_id!,
              receiverName: post.user?.pseudo ?? 'Créateur',
              receiverAvatar: post.user?.imageUrl ?? '',
              post: post,
              giftCount: post.totalGiftCoinsSentOnThisPost ?? 0,
              showCount: false,
              onGiftSuccess: () {
                setState(() {
                  post.users_cadeau_id ??= [];
                  if (!post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
                    post.users_cadeau_id!.add(authProvider.loginUserData.id!);
                  }
                });
                Provider.of<CoinGiftUserProvider>(context, listen: false)
                    .refreshBalance(authProvider.loginUserData.id!);
              },
            ),
          ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final bool _isWide = AppLayout.isWide(context);
    final Widget _videoStack = Stack(
      children: [
        Scaffold(
          backgroundColor: _afroBlack,
          body: _isLoadingFeed
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: colors.primary),
                const SizedBox(height: 20),
                Text(
                  'Chargement des vibes en cours...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: 8),
                Text(
                  'Préparez-vous pour le meilleur contenu 🔥',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 100.ms),
              ],
            ),
          )
              : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _feedItems.length,
            physics: const BouncingScrollPhysics(  // Ajoute cette ligne
              parent: AlwaysScrollableScrollPhysics(),
            ),
            onPageChanged: (index) async {
              if (!mounted) return;
              // Fermer le midroll si l'utilisateur swipe pendant qu'une pub est affichée
              if (_showMidrollAd) _closeMidrollOverlay();
              setState(() {
                _currentPage = index;
                _showOverlay = true; // rétablir les overlays à chaque changement de vidéo
              });
              _itemsSinceLastLoad++;
              // Auto-load uniquement si T3 (découverte) a été activé par l'utilisateur.
              if (_itemsSinceLastLoad >= 3 && !_isLoadingMore && _hasLoadedDiscovery) {
                _itemsSinceLastLoad = 0;
                await _loadMoreVideos();
                if (!mounted) return;
              }

              // Nettoyer les contrôleurs hors de la zone visible
              _cleanupOutOfRangeControllers(index);
              // Précharger les vidéos autour de l'index courant
              _preloadNeighborhood(index);

              if (index < _feedItems.length && _feedItems[index] is Post) {
                final post = _feedItems[index] as Post;
                _initializeVideo(post, index: index);
                _initLiveComments(post);
              }
            },
            itemBuilder: (context, index) {
              final item = _feedItems[index];
              if (item is Post) {
                return _buildVideoPage(item, index);
              } else if (item is _EndOfFeedSentinel) {
                return _buildEndOfFeedPage();
              } else if (item is _CreatorsChannelsSentinel) {
                return _buildCreatorsChannelsPage();
              } else if (item is _ShopPromoSentinel) {
                return ShopPromoVideoItem(articles: _promoArticles);
              } else if (item is _TutoReminderSentinel) {
                return const FeedMonetizationReminder(feed: 'video', fullScreen: true);
              } else if (item is Map<String, dynamic>) {
                return AdPostWidget(
                  adData: item,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  onComplete: () {
                    if (_pageController.hasClients && _pageController.page?.toInt() == index) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        // Live comments — toujours dans une position fixe du Stack (évite doublon GlobalKey)
        if (!_isLoadingFeed) _buildLiveCommentsOverlay(),
        // Pas de bannière fixe dans la page portrait — la pub passe en midroll modal
        // Pub midroll — grand format centré, vidéo en pause (gratuit uniquement)
        if (_showMidrollAd && !_isUserPremium())
          MidrollAdCard(
            key: ValueKey(_midrollAdData.hashCode),
            adData: _midrollAdData,
            videoController: _midrollVideoController,
            videoInitialized: _midrollVideoInitialized,
            onClose: _closeMidrollOverlay,
          ),
      ],
    );
    if (_isWide) {
      final Widget scaffold = Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(width: 480, child: _videoStack),
        ),
      );
      return _wrapWithControls(scaffold);
    }
    return _videoStack;
  }
}

/// Sentinel du rappel animé de monétisation (feed vidéo).
class _TutoReminderSentinel {
  const _TutoReminderSentinel();
}

/// Sentinel inséré dans _feedItems pour déclencher l'affichage de la promo AfroShop.
class _ShopPromoSentinel {
  const _ShopPromoSentinel();
}

/// Sentinel inséré toutes les 10 vidéos : page « créateurs et canaux à suivre ».
class _CreatorsChannelsSentinel {
  const _CreatorsChannelsSentinel();
}

/// Sentinel inséré en fin de T1 pour afficher la page de découverte.
class _EndOfFeedSentinel {
  const _EndOfFeedSentinel();
}

// Remplacer la classe FlyingHeart par celle-ci
class FlyingHeart {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final DateTime startTime;
  final Duration duration;
  final double rotation; // Nouveau : rotation aléatoire
  final Color color;     // Nouveau : couleur aléatoire

  FlyingHeart({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.startTime,
    required this.duration,
    required this.rotation,
    required this.color,
  });
}

class _AnimatedHeart extends StatefulWidget {
  final FlyingHeart heart;

  const _AnimatedHeart({Key? key, required this.heart}) : super(key: key);

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.heart.duration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // Laisser le parent nettoyer
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final progress = _progress.value;

        // Position
        final currentX = widget.heart.startX + (widget.heart.endX - widget.heart.startX) * progress;
        final currentY = widget.heart.startY + (widget.heart.endY - widget.heart.startY) * progress;

        // Opacité
        double opacity;
        if (progress < 0.7) {
          opacity = 1.0;
        } else {
          opacity = 1.0 - ((progress - 0.7) / 0.3);
        }
        opacity = opacity.clamp(0.0, 1.0);

        // Scale
        double scale;
        if (progress < 0.3) {
          scale = 0.5 + (progress / 0.3) * 0.8;
        } else if (progress < 0.7) {
          scale = 1.3;
        } else {
          scale = 1.3 - ((progress - 0.7) / 0.3) * 0.8;
        }
        scale = scale.clamp(0.3, 1.5);

        // Rotation
        final rotation = widget.heart.rotation * (progress < 0.5 ? progress * 2 : (1 - progress) * 2);

        return Positioned(
          left: currentX - widget.heart.size / 2,
          top: currentY - widget.heart.size / 2,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Icon(
                  Icons.favorite,
                  color: widget.heart.color,
                  size: widget.heart.size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Badges Tier + Pays pour la page vidéo format téléphone ───────────────────
class _VideoPageBadges extends StatelessWidget {
  final Post post;
  final String? feedTier;
  const _VideoPageBadges({required this.post, this.feedTier});

  @override
  Widget build(BuildContext context) {
    final tierLabel = switch (feedTier) {
      'tier1' => ('Nouveau · Abonnement', const Color(0xFF25D366)),
      'tier2' => ('Découverte · Intérêts', const Color(0xFF6C63FF)),
      'tier3' => ('Tendance', const Color(0xFF9E9E9E)),
      _ => null,
    };

    final countries = post.availableCountries;
    final isAll = countries.contains('ALL') || countries.isEmpty;

    String flagText = '';
    String countryLabel = '';
    if (!isAll) {
      final code = countries.first.toUpperCase();
      final found = AfricanCountry.everyCountry.where((c) => c.code.toUpperCase() == code).toList();
      flagText = found.isNotEmpty ? found.first.flag : '🏳️';
      countryLabel = countries.length == 1 ? code : '+${countries.length - 1}';
    }

    if (tierLabel == null && isAll) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tierLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tierLabel.$2.withOpacity(0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle, color: tierLabel.$2, size: 6),
              const SizedBox(width: 5),
              Text(tierLabel.$1, style: TextStyle(color: tierLabel.$2, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 4),
        ],
        if (!isAll)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(flagText, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 5),
              Text(countryLabel, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }
}