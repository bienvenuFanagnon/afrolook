import 'package:flutter/services.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

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
import 'package:afrotok/pages/user/userAbonnementPage.dart';

import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';

import 'package:afrotok/pages/widgetGlobal.dart';

import 'package:flutter/gestures.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:afrotok/widgets/smart_video_player.dart';
import '../services/media_cache_service.dart';

import 'package:video_player/video_player.dart';

import 'package:chewie/chewie.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:provider/provider.dart';

import 'package:afrotok/models/model_data.dart';

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
import 'user/otherUser/otherUser.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'coins/coin_gift_dialog.dart';

import 'coins/coin_recharge_screen.dart';
import '../widgets/gifts/quick_gift_bar.dart';

import 'coins/post_gifts_list.dart';

import '../theme/app_colors.dart';

import '../services/feed/feed_repository.dart';
import '../services/postService/feed_interaction_service.dart';
import '../services/streak_service.dart';
import '../providers/streakProvider.dart';

import 'userPosts/postWidgets/translatable_description.dart';

import '../providers/locale_provider.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../services/postService/post_view_service.dart';
import '../widgets/feed/sections/shop_promo_feed_widget.dart';

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

  const PostDetailsVideoFormatTel({Key? key, this.initialPost, this.isIn = false}) : super(key: key);

  @override
  _PostDetailsVideoFormatTelState createState() => _PostDetailsVideoFormatTelState();
}

class _PostDetailsVideoFormatTelState extends State<PostDetailsVideoFormatTel>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  bool get wantKeepAlive => true;

  final Map<String, String> _translatedDescriptions = {};
  late PageController _pageController;
  final FocusNode _focusNode = FocusNode();
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;
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
  final int _preloadThreshold = 2;
  DocumentSnapshot? _lastDocument;

  // Video controllers
  VideoPlayerController? _currentVideoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _showScrollHint = false;
  Timer? _scrollHintTimer;
  bool _maxVideosReached = false;
  final int _maxVideosLimit = 50; // seuil de 50 vidéos

  // Nouveaux membres pour le préchargement
  final Map<int, VideoPlayerController> _preloadedControllers = {};
  final int _preloadRadius = 2;
  final Set<int> _preloadingIndices = {};

  // Cache des données pub pour les posts qui sont des publicités
  final Map<String, Advertisement?> _adCache = {};
  final Set<String> _loadingAdIds = {};

  // Interactions state
  bool _isSharing = false;
  bool _isVoting = false;
  bool _hasVoted = false;
  Challenge? _challenge;
  bool _loadingChallenge = false;
  bool _isSupporting = false;
  bool? _hasSeenSupportModal;
  int _selectedGiftIndex = 0;
  final List<double> giftPrices = [10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000, 2500, 5000, 7000, 10000, 15000, 20000, 30000, 50000, 75000, 100000];
  final List<String> giftIcons = ['🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕','🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'];

  final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;
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
  int _midrollCountdown = 5;
  VoidCallback? _videoPositionListener;
  bool _isMidrollCtaLoading = false;

  // bool get _isLookChallenge => widget.initialPost!.type == 'CHALLENGEPARTICIPATION';
  bool get _isLookChallenge => widget.initialPost != null && widget.initialPost!.type == 'CHALLENGEPARTICIPATION';

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

  @override
  void initState() {
    super.initState();
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
      if (_isLookChallenge && widget.initialPost!.challenge_id != null) {
        _loadChallengeData();
        _checkIfUserHasVoted();
      }
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

      // ------------------------------------------------------------
      // 1. Choix de la tranche de mois (pondération)
      // ------------------------------------------------------------
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
      final DateTime endDate = DateTime(
        now.year,
        now.month - monthsBack,
        1,
      );
      final DateTime startDate = DateTime(
        endDate.year,
        endDate.month - 1,
        1,
      );

      final int startMicros = startDate.microsecondsSinceEpoch;
      final int endMicros = endDate.microsecondsSinceEpoch;

      printVm("📜 Chargement anciennes vidéos entre $startDate et $endDate");

      // ------------------------------------------------------------
      // 2. Query Firestore (intervalle de temps)
      // ------------------------------------------------------------
      Query query = _firestore.collection('Posts');

      // 🔥 Adaptation : on filtre uniquement les vidéos
      query = query.where("dataType", isEqualTo: PostDataType.VIDEO.name);

      query = query
          .where("created_at", isGreaterThanOrEqualTo: startMicros)
          .where("created_at", isLessThan: endMicros)
          .orderBy("created_at")
          .limit(30); // on prend large pour filtrer ensuite

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        printVm("⚠️ Aucune vidéo trouvée dans cette période");
        _isLoadingOldVideos = false;
        return;
      }

      // ------------------------------------------------------------
      // 3. Transformation + filtrage
      // ------------------------------------------------------------
      List<Post> validOldVideos = [];

      for (final doc in snapshot.docs) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = doc.id;

        if (_loadedPostIds.contains(post.id)) continue;
        if (_oldVideosCache.any((p) => p.id == post.id)) continue;
        if (post.isAdvertisement == true) continue;
        // 🔥 Adaptation : `_checkIfPostSeen` n'existe pas dans cette classe
        // On peut soit l'ignorer, soit l'implémenter sommairement.
        // Ici on garde l'appel mais on le commente car la méthode n'est pas définie.
        // post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);

        validOldVideos.add(post);

        if (validOldVideos.length >= 12) break;
      }

      // ------------------------------------------------------------
      // 4. Ajout au cache
      // ------------------------------------------------------------
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

    final postDoc = await _firestore.collection('Posts').doc(widget.initialPost!.id).get();
    if (!mounted) return;
    if (postDoc.exists) {
      final data = postDoc.data();
      final usersFavorite = List<String>.from(data?['users_favorite_id'] ?? []);
      final favoritesCount = data?['favorites_count'] ?? 0;

      setState(() {
        _isFavorite = usersFavorite.contains(userId);
        _favoritesCount = favoritesCount;
      });
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
        await _firestore.collection('Posts').doc(widget.initialPost!.id).update({
          'users_favorite_id': FieldValue.arrayRemove([userId]),
          'favorites_count': FieldValue.increment(-1),
        });
        setState(() {
          _isFavorite = false;
          _favoritesCount--;
        });
      } else {
        // Ajouter aux favoris
        await _firestore.collection('Posts').doc(widget.initialPost!.id).update({
          'users_favorite_id': FieldValue.arrayUnion([userId]),
          'favorites_count': FieldValue.increment(1),
        });
        setState(() {
          _isFavorite = true;
          _favoritesCount++;
        });

        // Notification
        if (widget.initialPost!.user_id != userId) {
          await authProvider.sendNotification(
            userIds: [widget.initialPost!.user?.oneIgnalUserid ?? ''],
            smallImage: authProvider.loginUserData.imageUrl ?? '',
            send_user_id: userId,
            recever_user_id: widget.initialPost!.user_id!,
            message: "📌 @${authProvider.loginUserData.pseudo} a ajouté votre vidéo aux favoris",
            type_notif: NotificationType.FAVORITE.name,
            post_id: widget.initialPost!.id!,
            post_type: PostDataType.VIDEO.name,
            chat_id: '',
          );
        }
      }
    } catch (e) {
      printVm("Erreur favori: $e");
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
    _postSubscriptions.forEach((key, subscription) => subscription.cancel());
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

  bool _isUserPremium() => false;

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
    _midrollCountdown = 5;
    setState(() { _showMidrollAd = true; });
    _midrollTimer?.cancel();
    _midrollTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_midrollCountdown > 0) _midrollCountdown--;
      });
      if (_midrollCountdown <= 0) t.cancel();
    });
  }

  void _closeMidrollOverlay() {
    if (!mounted) return;
    _midrollTimer?.cancel();
    _midrollVideoController?.dispose();
    _midrollVideoController = null;
    setState(() {
      _showMidrollAd = false;
      _midrollVideoInitialized = false;
      _midrollCountdown = 5;
      _isMidrollCtaLoading = false;
    });
    _midrollAdData = null;
    _currentVideoController?.play();
  }

  String _ownerCtaLabel(String? type) {
    switch (type) {
      case 'canal':     return "S'abonner";
      case 'group':     return 'Rejoindre';
      case 'event':     return 'Participer';
      case 'challenge': return 'Participer';
      case 'product':   return 'Commander';
      case 'service':   return 'Contacter';
      case 'content':   return 'Voir';
      case 'user':      return 'Suivre';
      default:          return 'Voir';
    }
  }

  Future<void> _navigateToAdOwner(BuildContext ctx, String ownerId, String? ownerType) async {
    try {
      final fs = FirebaseFirestore.instance;
      switch (ownerType) {
        case 'canal':
          final doc = await fs.collection('Canaux').doc(ownerId).get();
          if (!doc.exists || !ctx.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => CanalDetails(canal: Canal.fromJson(data)),
          ));
          break;
        case 'user':
        default:
          final doc = await fs.collection('Users').doc(ownerId).get();
          if (!doc.exists || !ctx.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: UserData.fromJson(data)),
          ));
      }
    } catch (e) {
      debugPrint('_navigateToAdOwner error: $e');
    }
  }


  Widget _buildMidrollCard() {
    final screenH = MediaQuery.of(context).size.height;
    final adData = _midrollAdData;

    Post? post;
    Advertisement? ad;
    String? thumb;
    String caption = '';
    String btnText = 'En savoir plus';

    if (adData != null) {
      // Parse l'annonce en premier (toujours disponible)
      try {
        ad = Advertisement.fromJson(adData['ad'] as Map<String, dynamic>);
      } catch (_) {}

      final isEntityBoost = adData['isEntityBoost'] == true;
      if (isEntityBoost && ad != null) {
        // Boost entité : description de la pub (saisie par l'annonceur)
        thumb = ad!.ownerAvatar?.isNotEmpty == true ? ad!.ownerAvatar : null;
        caption = ad!.description ?? '';
        btnText = _ownerCtaLabel(ad!.ownerType);
      } else if (!isEntityBoost) {
        // Boost post standard
        try {
          post = Post.fromJson(adData['post'] as Map<String, dynamic>);
          if (post!.thumbnail?.isNotEmpty == true) thumb = post!.thumbnail;
          else if (post!.images?.isNotEmpty == true && post!.images!.first.isNotEmpty) thumb = post!.images!.first;
          // Description de la pub en priorité, fallback sur le post
          caption = ad?.description?.isNotEmpty == true ? ad!.description! : post!.description ?? '';
          btnText = ad?.actionButtonText ?? 'En savoir plus';
        } catch (_) {}
      }
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.93),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenH * 0.72, maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Barre de header : badge + close ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('SPONSORISÉ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _midrollCountdown <= 0 ? _closeMidrollOverlay : null,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _midrollCountdown > 0 ? Colors.white12 : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: _midrollCountdown > 0
                                ? Text(
                                    '$_midrollCountdown',
                                    style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                                  )
                                : const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Carte principale ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: const Color(0xFF1A1A1A),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zone média : vidéo auto-play muet ou image
                            GestureDetector(
                              onTap: () {
                                if (post != null && ad != null) {
                                  _closeMidrollOverlay();
                                  if (post.dataType == PostDataType.VIDEO.name ||
                                      (post.url_media?.contains('.mp4') ?? false)) {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => PostDetailsVideoFormatTel(initialPost: post!, isIn: false),
                                    ));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => DetailsPost(post: post!),
                                    ));
                                  }
                                }
                              },
                              child: Builder(builder: (ctx) {
                                final isVideo = _midrollVideoInitialized && _midrollVideoController != null;
                                final videoSize = isVideo ? _midrollVideoController!.value.size : Size.zero;
                                final videoRatio = (isVideo && videoSize.height > 0)
                                    ? videoSize.width / videoSize.height
                                    : 16 / 9;
                                return Container(
                                  color: Colors.black,
                                  constraints: BoxConstraints(
                                    maxHeight: MediaQuery.of(ctx).size.height * 0.42,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: isVideo ? videoRatio : 4 / 3,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(color: Colors.black),
                                        // Vidéo en contain : pas de déformation ni de crop
                                        if (isVideo)
                                          FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: videoSize.width,
                                              height: videoSize.height,
                                              child: VideoPlayer(_midrollVideoController!),
                                            ),
                                          )
                                        else if (thumb != null)
                                          CachedNetworkImage(
                                            imageUrl: thumb,
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => const Center(
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)),
                                            ),
                                            errorWidget: (_, __, ___) => const Icon(Icons.image, color: Colors.white38, size: 48),
                                          )
                                        else
                                          const Icon(Icons.image, color: Colors.white38, size: 48),
                                        // Badge VIDÉO
                                        if (post != null && (post.dataType == PostDataType.VIDEO.name ||
                                            (post.url_media?.contains('.mp4') ?? false)))
                                          Positioned(
                                            bottom: 8, right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.videocam, color: Colors.white, size: 12),
                                                  SizedBox(width: 3),
                                                  Text('VIDÉO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        // Icône son coupé
                                        if (_midrollVideoInitialized)
                                          Positioned(
                                            top: 8, left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.volume_off, color: Colors.white, size: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),

                            // ── Infos pub ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (caption.isNotEmpty)
                                    Text(
                                      caption,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  if (caption.isNotEmpty) const SizedBox(height: 10),

                                  // ── Profil / entité boostée ──
                                  if (ad != null && ad!.ownerName?.isNotEmpty == true) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 14),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          ClipOval(
                                            child: SizedBox(
                                              width: 42, height: 42,
                                              child: ad!.ownerAvatar?.isNotEmpty == true
                                                  ? CachedNetworkImage(
                                                      imageUrl: ad!.ownerAvatar!,
                                                      fit: BoxFit.cover,
                                                      placeholder: (_, __) => Container(color: const Color(0xFFFFD700).withOpacity(0.3)),
                                                      errorWidget: (_, __, ___) => Container(
                                                        color: const Color(0xFFFFD700).withOpacity(0.3),
                                                        child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: const Color(0xFFFFD700).withOpacity(0.3),
                                                      child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Infos
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ad!.ownerName!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    decoration: TextDecoration.none,
                                                  ),
                                                ),
                                                if (ad!.ownerDescription?.isNotEmpty == true)
                                                  Text(
                                                    ad!.ownerDescription!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 11,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  )
                                                else if (ad!.ownerFollowers != null && ad!.ownerFollowers! > 0)
                                                  Text(
                                                    '${ad!.ownerFollowers} abonnés',
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 11,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Bouton suivre / rejoindre
                                          GestureDetector(
                                            onTap: _isMidrollCtaLoading ? null : () async {
                                              final ownerId = ad!.ownerId;
                                              final ownerType = ad!.ownerType;
                                              if (ownerId == null) return;
                                              setState(() => _isMidrollCtaLoading = true);
                                              _closeMidrollOverlay();
                                              await _navigateToAdOwner(context, ownerId, ownerType);
                                              if (mounted) setState(() => _isMidrollCtaLoading = false);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFD700),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: _isMidrollCtaLoading
                                                  ? const SizedBox(
                                                      height: 14, width: 14,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation(Colors.black),
                                                      ))
                                                  : Text(
                                                      _ownerCtaLabel(ad!.ownerType),
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        decoration: TextDecoration.none,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ── Mini-feed 3 derniers posts ──
                                    if (ad!.ownerRecentPosts?.isNotEmpty == true)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: ad!.ownerRecentPosts!.take(3).map((p) {
                                                final thumb = p['thumb'] as String? ?? '';
                                                final isVideo = p['isVideo'] as bool? ?? false;
                                                return Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.only(right: 6),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(10),
                                                      child: AspectRatio(
                                                        aspectRatio: 1,
                                                        child: Stack(
                                                          fit: StackFit.expand,
                                                          children: [
                                                            if (thumb.isNotEmpty)
                                                              CachedNetworkImage(
                                                                imageUrl: thumb,
                                                                fit: BoxFit.cover,
                                                                placeholder: (_, __) => Container(color: Colors.white10),
                                                                errorWidget: (_, __, ___) => Container(color: Colors.white10),
                                                              )
                                                            else
                                                              Container(color: Colors.white10),
                                                            // Overlay sombre
                                                            Container(color: Colors.black.withOpacity(0.40)),
                                                            // Icône vidéo
                                                            if (isVideo)
                                                              const Center(
                                                                child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 22),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 12),
                                            // CTA pleine largeur "Suivre ce créateur"
                                            GestureDetector(
                                              onTap: _isMidrollCtaLoading ? null : () async {
                                                final ownerId = ad!.ownerId;
                                                final ownerType = ad!.ownerType;
                                                if (ownerId == null) return;
                                                setState(() => _isMidrollCtaLoading = true);
                                                _closeMidrollOverlay();
                                                await _navigateToAdOwner(context, ownerId, ownerType);
                                                if (mounted) setState(() => _isMidrollCtaLoading = false);
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFD700),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: _isMidrollCtaLoading
                                                    ? const Center(
                                                        child: SizedBox(
                                                          height: 18, width: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            valueColor: AlwaysStoppedAnimation(Colors.black),
                                                          )))
                                                    : Text(
                                                        _ownerCtaLabel(ad!.ownerType) == 'Suivre'
                                                            ? 'Suivre ce créateur'
                                                            : _ownerCtaLabel(ad!.ownerType) == "S'abonner"
                                                                ? 'S\'abonner à ce canal'
                                                                : 'Rejoindre ${ad!.ownerName ?? ''}',
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w800,
                                                          decoration: TextDecoration.none,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],

                                  // Stats pub (vues toujours, clics uniquement admin/propriétaire)
                                  if (ad != null && (ad!.views ?? 0) > 0) ...[
                                    Builder(builder: (ctx) {
                                      final uid = authProvider.loginUserData?.id;
                                      final showClicks = uid != null &&
                                          (uid == ad!.ownerId ||
                                              AbonnementUtils.isAdmin(authProvider.loginUserData?.role));
                                      return Column(mainAxisSize: MainAxisSize.min, children: [
                                        const SizedBox(height: 10),
                                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          const Icon(Icons.remove_red_eye_outlined, size: 13, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text('${ad!.views} vues',
                                            style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                          if (showClicks && (ad!.clicks ?? 0) > 0) ...[
                                            const SizedBox(width: 12),
                                            const Icon(Icons.touch_app_outlined, size: 13, color: Colors.white54),
                                            const SizedBox(width: 4),
                                            Text('${ad!.clicks} clics',
                                              style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                          ],
                                        ]),
                                      ]);
                                    }),
                                  ],
                                  const SizedBox(height: 12),

                                  // Bouton CTA
                                  SizedBox(
                                    width: double.infinity,
                                    child: GestureDetector(
                                      onTap: _isMidrollCtaLoading ? null : () async {
                                        if (ad == null) return;
                                        _closeMidrollOverlay();
                                        if (post != null) {
                                          if (post!.dataType == PostDataType.VIDEO.name ||
                                              (post!.url_media?.contains('.mp4') ?? false)) {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => PostDetailsVideoFormatTel(initialPost: post!, isIn: false),
                                            ));
                                          } else {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => DetailsPost(post: post!),
                                            ));
                                          }
                                        } else if (ad!.ownerId != null) {
                                          setState(() => _isMidrollCtaLoading = true);
                                          await _navigateToAdOwner(context, ad!.ownerId!, ad!.ownerType);
                                          if (mounted) setState(() => _isMidrollCtaLoading = false);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                          ),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: _isMidrollCtaLoading
                                            ? const Center(
                                                child: SizedBox(
                                                  height: 20, width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                                  )))
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    btnText,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      decoration: TextDecoration.none,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Countdown / bouton Fermer ──
                    if (_midrollCountdown > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _midrollCountdown / 5.0,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fermer disponible dans ${_midrollCountdown}s',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ] else
                      GestureDetector(
                        onTap: _closeMidrollOverlay,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white38),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'Fermer',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ── Lien "Ne plus voir" ──
                    GestureDetector(
                      onTap: () {
                        _closeMidrollOverlay();
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AbonnementScreen(initialTab: 1)));
                      },
                      child: const Text(
                        'Ne plus voir de pubs → Premium',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

    if (_preloadedControllers.containsKey(index)) return;
    if (_preloadingIndices.contains(index)) return;

    _preloadingIndices.add(index);

    try {
      final optimizedUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
      final controller = await MediaCacheService.videoController(optimizedUrl);
      await controller.initialize();
      // NE PAS jouer, NE PAS mettre en pause, NE PAS seek
      // L'initialisation seule suffit à remplir le buffer
      _preloadedControllers[index] = controller;
      printVm("✅ Vidéo préchargée à l'index $index");
    } catch (e) {
      printVm("❌ Erreur préchargement index $index : $e");
    } finally {
      _preloadingIndices.remove(index);
    }
  }

  void _preloadNeighborhood(int currentIndex) {
    final start = max(0, currentIndex - _preloadRadius);
    final end = min(_feedItems.length - 1, currentIndex + _preloadRadius);

    for (int i = start; i <= end; i++) {
      if (_feedItems[i] is Post) {
        _preloadVideoAtIndex(i);
      }
    }
  }

  void _cleanupOutOfRangeControllers(int currentIndex) {
    final minKeep = currentIndex - _preloadRadius;
    final maxKeep = currentIndex + _preloadRadius;
    final toRemove = <int>[];

    _preloadedControllers.forEach((index, controller) {
      if (index < minKeep || index > maxKeep) {
        controller.dispose();
        toRemove.add(index);
      }
    });

    for (var idx in toRemove) {
      _preloadedControllers.remove(idx);
    }
  }

  // ==================== VIDEO INIT & PLAYBACK (MODIFIÉE) ====================

  Future<void> _initializeVideo(Post post, {int? index}) async {
    // Sur web, SmartVideoPlayer gère l'affichage nativement via <video> HTML
    if (kIsWeb) return;
    // Si un index est fourni et qu'un contrôleur préchargé existe, on l'utilise
    if (index != null && _preloadedControllers.containsKey(index)) {
      final preloadedController = _preloadedControllers[index]!;

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
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
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
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
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
    _lastDocument = null;
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

    // 🚀 Priorité haute : charger un petit lot (3 posts) en premier pour
    // garantir que les posts #2 et #3 soient disponibles très rapidement,
    // avant le post #1 ne soit même terminé de s'afficher/jouer.
    await _loadMoreVideos(isInitial: true, limit: 3);

    if (mounted) {
      setState(() {
        _rebuildFeedItems();
      });
    }

    // Précharger immédiatement les voisins (posts #2/#3) pour que leurs
    // VideoPlayerController soient prêts pendant la lecture du post #1.
    _preloadNeighborhood(0);

    // Charger le reste du lot suggéré + les anciennes vidéos en arrière-plan,
    // sans bloquer/retarder l'affichage déjà effectué ci-dessus.
    await _loadMoreVideos(isInitial: true, limit: _batchSize - 3);

    // Charger les anciennes vidéos
    await _loadOldVideosInBackground();

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
    _lastDocument = null;

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
      await _firestore.collection('Posts').doc(widget.initialPost!.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });
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

      // Pub toutes les 3 vidéos (gratuit uniquement)
      if (!skipAds &&
          postCount % 3 == 0 &&
          i != mixedPosts.length - 1 &&
          adIdx < ads.length) {
        _feedItems.add(ads[adIdx]);
        adIdx++;
      }

      // Promo AfroShop toutes les 7 vidéos
      if (postCount % 7 == 0 && _promoArticles.isNotEmpty) {
        _feedItems.add(const _ShopPromoSentinel());
      }
    }

    // Charger les articles promo si pas encore fait
    if (_promoArticles.isEmpty) _loadPromoArticles();
  }

  Future<void> _loadPromoArticles() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Articles')
          .where('status', isEqualTo: 'ACTIF')
          .limit(20)
          .get();
      if (!mounted) return;
      setState(() {
        _promoArticles = snap.docs
            .map((d) => ArticleData.fromJson(d.data()))
            .toList();
      });
    } catch (_) {}
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
    if (post.user_id != null && post.user == null) {
      try {
        final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
        if (userDoc.exists) {
          post.user = UserData.fromJson(userDoc.data()!);
        }
      } catch (e) { printVm('Erreur chargement user: $e'); }
    }

    if (post.canal_id != null && post.canal_id!.isNotEmpty && post.canal == null) {
      try {
        final canalDoc = await _firestore.collection('Canaux').doc(post.canal_id).get();
        if (canalDoc.exists) {
          post.canal = Canal.fromJson(canalDoc.data()!);
        }
      } catch (e) { printVm('Erreur chargement canal: $e'); }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMoreVideos({bool isInitial = false, int? limit}) async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      List<Post> newPosts = await _fetchSuggestedVideosBatch(
        limit: limit ?? _batchSize,
        excludeIds: _loadedPostIds,
      );

      if (newPosts.isEmpty && !isInitial) {
        // Pool épuisé — recycler en ne gardant que les 5 derniers vus
        // pour éviter les répétitions immédiates
        final recent = _videoPosts.length > 5
            ? _videoPosts.sublist(_videoPosts.length - 5).map((p) => p.id!).toSet()
            : <String>{};
        _loadedPostIds
          ..clear()
          ..addAll(recent);
        newPosts = await _fetchSuggestedVideosBatch(
          limit: limit ?? _batchSize,
          excludeIds: _loadedPostIds,
        );
      }

      if (newPosts.isNotEmpty) {
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
    List<Post> results = [];
    Set<String> ids = Set.from(excludeIds);
    int attempts = 0;
    const maxAttempts = 5; // Augmenté pour plus de chances

    // Récupérer l'ID du dernier créateur/canal affiché
    String? lastCreatorId;
    String? lastCanalId;

    if (_videoPosts.isNotEmpty) {
      final lastPost = _videoPosts.last;
      lastCreatorId = lastPost.user_id;
      lastCanalId = lastPost.canal_id;
    }

    while (results.length < limit && attempts < maxAttempts) {
      attempts++;
      final random = Random();
      int strategy = random.nextInt(3);

      Future<List<Post>> fetchOrdered(String field, bool descending, int fetchLimit) async {
        final snap = await _firestore
            .collection('Posts')
            .where('dataType', isEqualTo: PostDataType.VIDEO.name)
            .where('status', isEqualTo: PostStatus.VALIDE.name)
            .orderBy(field, descending: descending)
            .limit(fetchLimit)
            .get();
        return snap.docs.map((doc) {
          final p = Post.fromJson(doc.data());
          p.id = doc.id;
          return p;
        }).toList();
      }

      Future<List<Post>> fetchRandom(int fetchLimit) async {
        final snap = await _firestore
            .collection('Posts')
            .where('dataType', isEqualTo: PostDataType.VIDEO.name)
            .where('status', isEqualTo: PostStatus.VALIDE.name)
            .limit(50)
            .get();
        List<Post> posts = snap.docs.map((doc) {
          final p = Post.fromJson(doc.data());
          p.id = doc.id;
          return p;
        }).toList();
        posts.shuffle();
        return posts.take(fetchLimit).toList();
      }

      List<Post> candidates = [];
      if (attempts == 1) {
        // Stratégie principale via FeedRepository (centralisé)
        candidates = await FeedRepository().fetchByMediaType(
          PostDataType.VIDEO.name, '', ids, limit: limit * 2,
        );
        if (candidates.isEmpty) {
          candidates = await fetchOrdered('created_at', true, limit * 2);
        }
      } else if (attempts == 2) {
        if (strategy == 0) candidates = await fetchOrdered('popularity', true, limit * 2);
        else if (strategy == 1) candidates = await fetchOrdered('popularity', false, limit * 2);
        else candidates = await fetchRandom(limit * 2);
      } else {
        candidates = await fetchOrdered('created_at', true, limit * 3);
      }

      // Filtrer pour éviter 3 mêmes créateurs/canaux à la suite
      for (var p in candidates) {
        if (p.id != null && !ids.contains(p.id)) {
          // Vérifier la répétition du créateur
          bool sameCreator = (lastCreatorId != null && p.user_id == lastCreatorId);
          bool sameCanal = (lastCanalId != null && p.canal_id == lastCanalId && p.canal_id != null && p.canal_id!.isNotEmpty);

          // Compter combien de fois ce créateur apparaît dans les 2 dernières vidéos
          int creatorCount = 0;
          int canalCount = 0;

          for (int i = _videoPosts.length - 1; i >= max(0, _videoPosts.length - 2); i--) {
            if (_videoPosts[i].user_id == p.user_id) creatorCount++;
            if (_videoPosts[i].canal_id != null && _videoPosts[i].canal_id == p.canal_id) canalCount++;
          }

          // Autoriser si pas déjà 2 fois de suite le même créateur ou canal
          if (creatorCount < 2 && canalCount < 2) {
            ids.add(p.id!);
            results.add(p);
            lastCreatorId = p.user_id;
            lastCanalId = p.canal_id;
            if (results.length >= limit) break;
          }
        }
      }
    }

    results.shuffle();
    return results;
  }
  Future<List<Post>> _fetchSuggestedVideosBatch2({required int limit, required Set<String> excludeIds}) async {
    List<Post> results = [];
    Set<String> ids = Set.from(excludeIds);
    int attempts = 0;
    const maxAttempts = 3;

    while (results.length < limit && attempts < maxAttempts) {
      attempts++;
      final random = Random();
      int strategy = random.nextInt(3);

      Future<List<Post>> fetchOrdered(String field, bool descending, int fetchLimit) async {
        final snap = await _firestore
            .collection('Posts')
            .where('dataType', isEqualTo: PostDataType.VIDEO.name)
            .where('status', isEqualTo: PostStatus.VALIDE.name)
            .orderBy(field, descending: descending)
            .limit(fetchLimit)
            .get();
        return snap.docs.map((doc) {
          final p = Post.fromJson(doc.data());
          p.id = doc.id;
          return p;
        }).toList();
      }

      Future<List<Post>> fetchRandom(int fetchLimit) async {
        final snap = await _firestore
            .collection('Posts')
            .where('dataType', isEqualTo: PostDataType.VIDEO.name)
            .where('status', isEqualTo: PostStatus.VALIDE.name)
            .limit(50)
            .get();
        List<Post> posts = snap.docs.map((doc) {
          final p = Post.fromJson(doc.data());
          p.id = doc.id;
          return p;
        }).toList();
        posts.shuffle();
        return posts.take(fetchLimit).toList();
      }

      List<Post> candidates = [];
      if (attempts == 1) {
        candidates = await fetchOrdered('created_at', true, limit * 2);
      } else if (attempts == 2) {
        if (strategy == 0) candidates = await fetchOrdered('popularity', true, limit * 2);
        else if (strategy == 1) candidates = await fetchOrdered('popularity', false, limit * 2);
        else candidates = await fetchRandom(limit * 2);
      } else {
        candidates = await fetchOrdered('created_at', true, limit * 3);
      }

      for (var p in candidates) {
        if (p.id != null && !ids.contains(p.id)) {
          ids.add(p.id!);
          results.add(p);
          if (results.length >= limit) break;
        }
      }

    }

    results.shuffle();
    return results;
  }

  void _initPostLikeState(Post post) {
    if (post.id == null) return;
    if (_likedPosts.containsKey(post.id)) return;
    final userId = authProvider.loginUserData.id;
    _likedPosts[post.id!] = post.users_love_id?.contains(userId) ?? false;
    _lovesCount[post.id!] = post.loves ?? 0;
  }

  void _subscribeToPostUpdates(Post post) {
    if (post.id == null || _postSubscriptions.containsKey(post.id)) return;
    _initPostLikeState(post);
    final subscription = _firestore.collection('Posts').doc(post.id).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        // Inclure snapshot.id pour que updatedPost.id ne soit jamais null
        final updatedPost = Post.fromJson({'id': snapshot.id, ...snapshot.data() as Map<String, dynamic>});
        setState(() {
          final index = _videoPosts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            updatedPost.user = _videoPosts[index].user;
            updatedPost.canal = _videoPosts[index].canal;
            _videoPosts[index] = updatedPost;
          }

          // Mise à jour des Maps depuis Firestore
          // Ignorer seulement si un like est en vol pour ce post (update optimiste)
          final userId = authProvider.loginUserData.id;
          if (userId != null && post.id != null) {
            final likedInSnapshot = updatedPost.users_love_id?.contains(userId) ?? false;
            final hasPending = _pendingLikePostIds.contains(post.id);
            if (!hasPending) {
              // Pas d'opération en cours → toujours accepter Firestore
              _likedPosts[post.id!] = likedInSnapshot;
              _lovesCount[post.id!] = updatedPost.loves ?? 0;
            }
            // Sinon : update optimiste en vol → conserver l'état local
          }
        });
      }
    });
    _postSubscriptions[post.id!] = subscription;
  }

  // ==================== VIDEO INIT & PLAYBACK ====================

  Future<void> _recordPostView(Post post) async {
    if (post.id == null) return;
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;
    try {
      await _markPostAsSeen(post);
      if (post.users_vue_id != null && post.users_vue_id!.contains(currentUserId)) return;
      await _firestore.collection('Posts').doc(post.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });
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
      await _prefs.setBool(key, true);
      await _firestore.collection('Users').doc(currentUserId).update({
        'viewedPostIds': FieldValue.arrayUnion([post.id]),
      });
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

    // Si jamais affiché avant, on affiche
    if (lastShowTimestamp == null) return true;

    // Récupérer la date du dernier affichage
    final lastShowDate = DateTime.fromMillisecondsSinceEpoch(lastShowTimestamp);
    final now = DateTime.now();

    // Calculer la différence en jours
    final difference = now.difference(lastShowDate).inDays;

    // Afficher seulement si 3 jours ou plus sont passés
    return difference >= 3;
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
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [Icon(Icons.swipe_vertical, color: colors.accent), const SizedBox(width: 8), Text('Astuces Vidéo', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold))],
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
                    child: Icon(Icons.swipe_vertical, color: colors.accent, size: 28),
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
      _firestore.collection('Posts').doc(post.id).update({
        'loves': FieldValue.increment(-1),
        'users_love_id': FieldValue.arrayRemove([userId]),
        'popularity': FieldValue.increment(-1),
      }).catchError((_) {
        if (mounted) setState(() {
          _likedPosts[post.id!] = true;
          _lovesCount[post.id!] = previousCount;
        });
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
    ).then((success) {
      if (!mounted) return;
      if (!success) {
        // Pas de pièces → like quand même enregistré, modal informatif seulement
        _firestore.collection('Posts').doc(post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(1),
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
      // Erreur réseau → enregistrer quand même le like sans les coins
      _firestore.collection('Posts').doc(post.id).update({
        'loves': FieldValue.increment(1),
        'users_love_id': FieldValue.arrayUnion([userId]),
        'popularity': FieldValue.increment(1),
      }).catchError((_) {});
    }).whenComplete(() {
      _pendingLikePostIds.remove(post.id);
      if (mounted) setState(() => _isLiking = false);
    });
  }

// Dialog pour solde insuffisant (à ajouter dans la classe)
  void _showInsufficientCoinsForLikeDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '💡 Soutenez le créateur !',
          style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chaque like que vous envoyez offre 1 pièce au créateur du post !',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le like coûte 2 pièces :\n• Pour soutenir le créateur',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rechargez votre compte pour continuer à soutenir vos créateurs préférés !',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CoinRechargeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
            ),
            child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  Future<void> _handleLike3(Post post) async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    final isLiked = post.users_love_id?.contains(userId) ?? false;
    if (isLiked) return;
    try {
      await _firestore.collection('Posts').doc(post.id).update({
        'loves': FieldValue.increment(1),
        'users_love_id': FieldValue.arrayUnion([userId]),
      });
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
        height: MediaQuery.of(context).size.height * 0.85,
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
  void _showGiftDialog(Post post) {
    _handleGift(post);
  }
  void _handleGift(Post post) {
    showDialog(
      context: context,
      builder: (context) => CoinGiftDialog(
        receiverId: post.user_id!,
        receiverName: post.user?.pseudo ?? 'Créateur',
        receiverAvatar: post.user?.imageUrl ?? '',
        post: post,
        onGiftSuccess: () async {
          // Mettre à jour l'affichage local du compteur de cadeaux
          setState(() {
            post.users_cadeau_id ??= [];
            if (!post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
              post.users_cadeau_id!.add(authProvider.loginUserData.id!);
            }
          });

          // Rafraîchir le provider pour mettre à jour le solde
          final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
          await coinProvider.refreshBalance(authProvider.loginUserData.id!);

          // Afficher un snackbar de confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎁 Cadeau envoyé avec succès !'),
              backgroundColor: AppColors.of(context).primary,
              duration: const Duration(seconds: 2),
            ),
          );

          // 🔥 Appeler le callback parent si existant
          // widget.onGiftSuccess?.call();
        },
      ),
    );
  }
  void _showGiftDialog2(Post post) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: colors.accent, width: 2)),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Envoyer un Cadeau', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 12),
                  Text('Choisissez le montant en FCFA', style: TextStyle(color: colors.textPrimary)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
                      itemCount: giftPrices.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => setStateDialog(() => _selectedGiftIndex = index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedGiftIndex == index ? colors.primary : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _selectedGiftIndex == index ? colors.accent : Colors.transparent),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(giftIcons[index], style: const TextStyle(fontSize: 24)), const SizedBox(height: 5), Text('${giftPrices[index].toInt()} FCFA', style: TextStyle(color: colors.textPrimary))]),
                        ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 250.ms, curve: Curves.easeOut),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA', style: TextStyle(color: colors.accent)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: colors.textPrimary))),
                    ElevatedButton(onPressed: () { Navigator.pop(context); _sendGift(giftPrices[_selectedGiftIndex], post); }, style: ElevatedButton.styleFrom(backgroundColor: colors.primary), child: Text('Envoyer', style: TextStyle(color: colors.onPrimary))),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendGift(double amount, Post post) async {
    try {
      final senderBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
      if (senderBalance < amount) {
        _showInsufficientBalanceDialog();
        return;
      }
      final gainDestinataire = amount * 0.7;
      final gainApp = amount * 0.3;
      await _firestore.runTransaction((transaction) async {
        final senderRef = _firestore.collection('Users').doc(authProvider.loginUserData.id);
        final receiverRef = _firestore.collection('Users').doc(post.user_id);
        final appDataRef = _firestore.collection('AppData').doc(appId);
        transaction.update(senderRef, {'votre_solde_principal': FieldValue.increment(-amount)});
        transaction.update(receiverRef, {'votre_solde_principal': FieldValue.increment(gainDestinataire)});
        transaction.update(appDataRef, {'solde_gain': FieldValue.increment(gainApp)});
        transaction.update(_firestore.collection('Posts').doc(post.id), {
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5),
        });
      });
      await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${post.user!.pseudo}", authProvider.loginUserData.id!);
      await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}", post.user_id!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppColors.of(context).primary, content: const Text('🎁 Cadeau envoyé!')));
    } catch (e) { printVm('Erreur envoi cadeau: $e'); }
  }

  void _showInsufficientBalanceDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Solde insuffisant', style: TextStyle(color: colors.accent)),
        content: Text('Rechargez votre compte pour envoyer un cadeau.', style: TextStyle(color: colors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: colors.textPrimary))),
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: colors.primary), child: Text('Recharger', style: TextStyle(color: colors.onPrimary))),
        ],
      ),
    );
  }

  Future<void> _createTransaction(String type, double montant, String description, String userid) async {
    final transaction = TransactionSolde()
      ..id = _firestore.collection('TransactionSoldes').doc().id
      ..user_id = userid
      ..type = type
      ..statut = StatutTransaction.VALIDER.name
      ..description = description
      ..montant = montant
      ..methode_paiement = "cadeau"
      ..createdAt = DateTime.now().millisecondsSinceEpoch
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
  }

  void _sharePost(Post post) async {
    setState(() => _isSharing = true);
    try {
      final shareUrl = post.dataType == PostDataType.VIDEO.name
          ? (post.thumbnail ?? '')
          : (post.images?.isNotEmpty == true ? post.images!.first : '');
      final linkService = AppLinkService();
      await linkService.shareContent(type: AppLinkType.post, id: post.id!, message: post.description ?? '', mediaUrl: shareUrl);
      await _firestore.collection('Posts').doc(post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
      });
      setState(() {
        post.partage = (widget.initialPost!.partage ?? 0) + 1;
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
            // Bouton Partager (externe)
            ListTile(
              leading: Icon(Icons.share, color: colors.info),
              title: Text('Partager', style: TextStyle(color: colors.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                 _sharePost(post);
              },
            ).animate().fadeIn(duration: 200.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

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
            ).animate().fadeIn(duration: 200.ms, delay: 20.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            if (post.user_id != authProvider.loginUserData.id)
              ListTile(
                leading: Icon(Icons.flag, color: colors.textPrimary),
                title: Text('Signaler', style: TextStyle(color: colors.textPrimary)),
                onTap: () async {
                  Navigator.pop(context);
                  await postProvider.updateVuePost(post, context);
                },
              ).animate().fadeIn(duration: 200.ms, delay: 40.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            if (post.user_id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(
                leading: Icon(Icons.delete, color: colors.danger),
                title: Text('Supprimer', style: TextStyle(color: colors.danger)),
                onTap: () async {
                  Navigator.pop(context);
                  await _deletePost(post, context);
                },
              ).animate().fadeIn(duration: 200.ms, delay: 80.ms).slideX(begin: -0.05, end: 0, duration: 200.ms, curve: Curves.easeOut),

            // Option "Booster ce post" — créateur + admin uniquement
            if (post.user_id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(
                leading: Icon(Icons.rocket_launch, color: colors.accent),
                title: Text('Booster ce post', style: TextStyle(color: colors.textPrimary)),
                subtitle: Text('Transformer en publicité', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserCreateAdvertisementPage(existingPost: post),
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
  Future<void> _deletePost(Post post, BuildContext context) async {
    try {
      await _firestore.collection('Posts').doc(post.id).delete();
      await _firestore.collection('AppData').doc(appId).update({'allPostIds': FieldValue.arrayRemove([post.id])});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post supprimé')));
      if (_videoPosts.length == 1) Navigator.pop(context);
    } catch (e) { printVm('Erreur suppression: $e'); }
  }

  // ==================== CHALLENGE & VOTE ====================
  Future<void> _loadChallengeData() async {
    if (widget.initialPost!.challenge_id == null) return;
    setState(() => _loadingChallenge = true);
    try {
      final doc = await _firestore.collection('Challenges').doc(widget.initialPost!.challenge_id).get();
      if (doc.exists) setState(() => _challenge = Challenge.fromJson(doc.data()!)..id = doc.id);
    } catch (e) { printVm('Erreur chargement challenge: $e'); } finally { setState(() => _loadingChallenge = false); }
  }

  Future<void> _checkIfUserHasVoted() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    final doc = await _firestore.collection('Posts').doc(widget.initialPost!.id).get();
    if (doc.exists) {
      final voters = List<String>.from(doc.data()?['users_votes_ids'] ?? []);
      setState(() => _hasVoted = voters.contains(userId));
    }
  }

  Future<void> _voteForLook() async {
    if (_hasVoted || _isVoting || _challenge == null) return;
    final user = _auth.currentUser;
    if (user == null) { _showError('Connectez-vous pour voter'); return; }
    if (_challenge!.isTermine) { _showError('Challenge terminé'); return; }
    if (_challenge!.aVote(user.uid)) { _showError('Vous avez déjà voté'); return; }
    if (!_challenge!.voteGratuit!) {
      final solde = await _getSoldeUtilisateur(user.uid);
      if (solde < _challenge!.prixVote!) { _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt()); return; }
    }
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Confirmer votre vote', style: TextStyle(color: colors.textPrimary)),
        content: Text(!_challenge!.voteGratuit! ? 'Ce vote coûtera ${_challenge!.prixVote} FCFA.' : 'Votre vote est gratuit et définitif.', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await _processVoteWithChallenge(user.uid); }, style: ElevatedButton.styleFrom(backgroundColor: colors.primary), child: Text('Voter', style: TextStyle(color: colors.onPrimary))),
        ],
      ),
    );
  }

  Future<void> _processVoteWithChallenge(String userId) async {
    setState(() => _isVoting = true);
    try {
      await _firestore.runTransaction((transaction) async {
        final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id);
        final challengeDoc = await transaction.get(challengeRef);
        if (!challengeDoc.exists) throw Exception('Challenge introuvable');
        final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
        if (!currentChallenge.isEnCours) throw Exception('Challenge non actif');
        if (currentChallenge.aVote(userId)) throw Exception('Déjà voté');
        if (!_challenge!.voteGratuit!) {
          await _debiterUtilisateur(userId, _challenge!.prixVote!, 'Vote challenge ${_challenge!.titre}');
        }
        transaction.update(_firestore.collection('Posts').doc(widget.initialPost!.id), {
          'votes_challenge': FieldValue.increment(1),
          'users_votes_ids': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(3),
        });
        transaction.update(challengeRef, {
          'users_votants_ids': FieldValue.arrayUnion([userId]),
          'total_votes': FieldValue.increment(1),
        });
      });
      setState(() => _hasVoted = true);
      _showSuccess('Vote enregistré !');
    } catch (e) { _showError('Erreur: $e'); } finally { setState(() => _isVoting = false); }
  }

  Future<double> _getSoldeUtilisateur(String userId) async {
    final doc = await _firestore.collection('Users').doc(userId).get();
    return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
  }

  Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
    await _firestore.collection('Users').doc(userId).update({'votre_solde_principal': FieldValue.increment(-montant)});
    await _firestore.collection('AppData').doc(appId).set({'solde_gain': FieldValue.increment(montant)}, SetOptions(merge: true));
    await _createTransaction(TypeTransaction.DEPENSE.name, montant.toDouble(), raison, userId);
  }

  void _showError(String msg) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colors.danger));
  }
  void _showSuccess(String msg) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: colors.success));
  }
  void _showSoldeInsuffisant(int manquant) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Solde insuffisant', style: TextStyle(color: colors.accent)),
        content: Text('Il manque $manquant FCFA pour voter. Rechargez votre compte.', style: TextStyle(color: colors.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Plus tard', style: TextStyle(color: colors.textSecondary))),
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: colors.primary), child: Text('Recharger', style: TextStyle(color: colors.onPrimary))),
        ],
      ),
    );
  }

  // ==================== SUPPORT AD ====================
  Future<void> _loadSupportModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;
    _hasSeenSupportModal = prefs.getBool('has_seen_support_modal_$userId') ?? false;
  }

  Future<void> _handleSupportAd(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == post.user_id) { _showError('Vous ne pouvez pas soutenir votre propre post'); return; }
    final hasSupported = await _hasSupportedToday(post.id!, currentUserId!);
    if (hasSupported) { _showError('Vous avez déjà soutenu ce post aujourd\'hui'); return; }
    if (_hasSeenSupportModal == false) {
      _showSupportModal(post);
    } else {
      _startSupportAd(post);
    }
  }

  Future<bool> _hasSupportedToday(String postId, String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + const Duration(days: 1).inMilliseconds;
    final query = await _firestore.collection('post_supports').where('postId', isEqualTo: postId).where('userId', isEqualTo: userId).where('supportedAt', isGreaterThanOrEqualTo: startOfDay).where('supportedAt', isLessThan: endOfDay).limit(1).get();
    return query.docs.isNotEmpty;
  }

  void _showSupportModal(Post post) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.surface,
        title: Row(children: [Icon(Icons.volunteer_activism, color: colors.accent), const SizedBox(width: 8), Text('Soutenir le créateur', style: TextStyle(color: colors.textPrimary))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Regardez cette publicité pour offrir 10 pièces au créateur.', style: TextStyle(color: colors.textSecondary)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.monetization_on, color: colors.accent), const SizedBox(width: 8), Expanded(child: Text('Les pièces peuvent être converties en argent réel.', style: TextStyle(color: colors.textPrimary)))])),
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

  void _startSupportAd(Post post) {
    setState(() { _isSupporting = true; _showRewardedAd = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rewardedAdKey.currentState?.showAd();
    });
  }

  Future<void> _onSupportAdRewarded(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    final creatorId = post.user_id!;
    await _firestore.collection('Posts').doc(post.id).update({'adSupportCount': FieldValue.increment(1)});
    await _firestore.collection('Users').doc(creatorId).update({'totalCoinsEarnedFromAdSupport': FieldValue.increment(1)});
    await _firestore.collection('Users').doc(currentUserId).update({'totalAdViewsSupported': FieldValue.increment(1)});
    await _firestore.collection('post_supports').add({'postId': post.id, 'userId': currentUserId, 'supportedAt': DateTime.now().millisecondsSinceEpoch});
    _showSuccess('Merci ! Le créateur a reçu 10 pièces.');
    setState(() { _isSupporting = false; _showRewardedAd = false; });
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
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: QuickGiftBar(
                receiverId: post.user_id!,
                receiverName: post.user?.pseudo ?? 'Créateur',
                receiverAvatar: post.user?.imageUrl ?? '',
                post: post,
                giftCount: post.totalGiftCoinsSentOnThisPost ?? 0,
                onGiftSuccess: () async {
                  setState(() {
                    post.users_cadeau_id ??= [];
                    if (!post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
                      post.users_cadeau_id!.add(authProvider.loginUserData.id!);
                    }
                  });
                  final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
                  await coinProvider.refreshBalance(authProvider.loginUserData.id!);
                },
              ),
            ),
          PostGiftsList(postId: post.id!, compactLevel: CompactLevel.light, maxDisplayItems: 10),
        ],
      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.08, end: 0, duration: 400.ms, curve: Curves.easeOut),
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
      final snap = await _firestore
          .collection('PostComments')
          .where('post_id', isEqualTo: postId)
          .orderBy('created_at', descending: true)
          .limit(5)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        setState(() {
          _preloadedComments = snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return PostComment.fromJson(data);
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _sendQuickComment(String text, Post post) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSendingQuickComment) return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    setState(() {
      _isSendingQuickComment = true;
      _quickCommentController.clear();
    });

    try {
      final comment = PostComment(
        id: FirebaseFirestore.instance.collection('PostComments').doc().id,
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

      if (success && mounted) {
        setState(() {
          _preloadedComments.insert(0, comment);
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
          postDescription: post.description,
          postImageUrl: post.thumbnail ?? post.user?.imageUrl ?? '',
          postDataType: post.dataType,
        );
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
            final msg = "@${authProvider.loginUserData.pseudo!} a commenté votre vidéo";
            final notif = NotificationData(
              id: FirebaseFirestore.instance.collection('Notifications').doc().id,
              titre: "Nouvelle interaction",
              media_url: authProvider.loginUserData.imageUrl,
              type: NotificationType.POST.name,
              description: msg,
              user_id: userId,
              receiver_id: post.user!.id!,
              post_id: post.id!,
              post_data_type: PostDataType.COMMENT.name,
              createdAt: DateTime.now().microsecondsSinceEpoch,
              updatedAt: DateTime.now().microsecondsSinceEpoch,
              status: PostStatus.VALIDE.name,
            );
            await FirebaseFirestore.instance.collection('Notifications').doc(notif.id).set(notif.toJson());
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
    final String displayName = canal != null
        ? '#${canal.titre ?? ''}'
        : '@${user?.pseudo ?? ''}';
    final int subscriberCount = canal != null
        ? (canal.usersSuiviId?.length ?? 0)
        : (user?.userAbonnesIds?.length ?? 0);

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
                  decoration: BoxDecoration(border: Border.all(color: _afroGreen, width: 2), shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundImage: (canal?.urlImage != null || user?.imageUrl != null)
                        ? NetworkImage(canal?.urlImage ?? user?.imageUrl ?? '')
                        : null,
                    child: (canal == null && user == null) ? const CircularProgressIndicator(strokeWidth: 2) : null,
                  ),
                ),
                _buildSubscribeIcon(post),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 62,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
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
                Text(
                  _formatNumber(subscriberCount),
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_isLookChallenge)
            Column(
              children: [
                GestureDetector(
                  onTap: _voteForLook,
                  child: Icon(_hasVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined, color: _hasVoted ? _afroGreen : Colors.white, size: 35),
                ),
                Text('${post.votesChallenge ?? 0}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          Column(
            children: [
              GestureDetector(
                onTap: _isLiking ? null : () => _handleLike(post),
                child: Icon(
                  (_likedPosts[post.id] ?? (post.users_love_id?.contains(authProvider.loginUserData.id) ?? false))
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _afroRed,
                  size: 30,
                ),
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
          Column(
            children: [
              GestureDetector(onTap: () => _showCommentsModal(post), child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 33)),
              Text('${post.comments ?? 0}', style: const TextStyle(color: Colors.white)),
            ],
          ),
          if (post.type != PostType.CHALLENGEPARTICIPATION.name)
            Column(
              children: [
                GestureDetector(onTap: () => _showGiftDialog(post), child: const Icon(Icons.card_giftcard, color: _afroYellow, size: 30)),
                Text('${post.totalGiftCoinsSentOnThisPost ?? 0}', style: const TextStyle(color: Colors.white)),
              ],
            ),
          Column(
            children: [
              GestureDetector(onTap: () {}, child: const Icon(Icons.bar_chart, color: Colors.blue, size: 35)),
              Text('${post.totalInteractions ?? 0}', style: const TextStyle(color: Colors.white)),
            ],
          ),
          Column(
            children: [
              GestureDetector(
                onTap: _toggleFavorite,
                child: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border, color: _isFavorite ? _afroYellow : Colors.white, size: 30),
              ),
              Text(_formatNumber(_favoritesCount), style: const TextStyle(color: Colors.white)),
            ],
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
      final isFollowing = post.user?.userAbonnesIds?.contains(currentUserId) ?? false;

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
      final snap = await _firestore
          .collection('Advertisements')
          .where('postId', isEqualTo: post.id)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      Advertisement? ad;
      if (snap.docs.isNotEmpty) {
        ad = Advertisement.fromJson(snap.docs.first.data());
        ad.id = snap.docs.first.id;
        _recordAdViewForPost(ad);
      }
      if (mounted) setState(() => _adCache[post.id!] = ad);
    } catch (_) {
      if (mounted) setState(() => _adCache[post.id!] = null);
    } finally {
      _loadingAdIds.remove(post.id!);
    }
  }

  Future<void> _recordAdViewForPost(Advertisement ad) async {
    if (ad.id == null) return;
    final viewIncr = Random().nextInt(3) + 1;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _firestore.collection('Advertisements').doc(ad.id).update({
        'views': FieldValue.increment(viewIncr),
        'uniqueViews': FieldValue.increment(1),
        'dailyStats.$today.views': FieldValue.increment(viewIncr),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
    } catch (_) {}
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
                final clickIncr = Random().nextInt(3) + 1;
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                _firestore.collection('Advertisements').doc(ad.id).update({
                  'clicks': FieldValue.increment(clickIncr),
                  'uniqueClicks': FieldValue.increment(1),
                  'dailyStats.$today.clicks': FieldValue.increment(clickIncr),
                });
                if (ad.actionUrl != null && ad.actionUrl!.isNotEmpty) {
                  final url = Uri.parse(ad.actionUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                }
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
            onDoubleTap: () {
              _handleLike(post);
            },
            child: _buildVideoPlayer(post),
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
                Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.yellow)),
                  const Text('Vibe vidéos', style: TextStyle(color: _afroGreen, fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
              ],
            ),
          ),
        if (_isLoadingMore && _videoPosts.length - _currentPage <= _preloadThreshold)
          const Positioned(bottom: 100, child: Center(child: CircularProgressIndicator(color: _afroGreen))),
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
              if (_itemsSinceLastLoad >= 3 && !_isLoadingMore) {
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
              } else if (item is _ShopPromoSentinel) {
                return ShopPromoVideoItem(articles: _promoArticles);
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
        if (_showRewardedAd)
          RewardedAdWidget(
            key: _rewardedAdKey,
            onUserEarnedReward: (amount, name) async => await _onSupportAdRewarded(_videoPosts[_currentPage]),
            onAdDismissed: () => setState(() { _showRewardedAd = false; _isSupporting = false; }),
            child: const SizedBox.shrink(),
          ),

        // Pub midroll — grand format centré, vidéo en pause (gratuit uniquement)
        if (_showMidrollAd && !_isUserPremium())
          _buildMidrollCard(),
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

/// Sentinel inséré dans _feedItems pour déclencher l'affichage de la promo AfroShop.
class _ShopPromoSentinel {
  const _ShopPromoSentinel();
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