import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/pub/banner_ad_widget.dart';
import 'package:afrotok/pages/pub/native_ad_widget.dart';
import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';
import 'package:afrotok/pages/widgetGlobal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
import 'UserServices/deviceService.dart';
import 'admin/AfrolookPub/ad_post_page_video_widget.dart';
import 'canaux/detailsCanal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coins/coin_gift_dialog.dart';
import 'coins/coin_recharge_screen.dart';
import 'coins/post_gifts_list.dart';


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

class _PostDetailsVideoFormatTelState extends State<PostDetailsVideoFormatTel> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late PageController _pageController;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;
  int _itemsSinceLastLoad = 0;
  // Feed mixte : contient soit Post soit Map<String,dynamic> (pub)
  List<dynamic> _feedItems = [];
  List<Post> _videoPosts = [];
  final Set<String> _loadedPostIds = {};
  final Set<String> _loadingRelations = {};
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
  final int _preloadRadius = 2; // nombre de vidéos avant/après à précharger
  final Set<int> _preloadingIndices = {};

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

// Cache et gestion des anciennes vidéos
  List<Post> _oldVideosCache = [];
  bool _isLoadingOldVideos = false;
  Timer? _oldVideosLoadTimer;   // chargement par lot
  Set<String> _usedOldVideoIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 1.0,
    );

    _initSharedPreferences();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    // 🔥 Vérifier si initialPost existe avant de l'utiliser
    if (widget.initialPost != null) {
      authProvider.incrementPostTotalInteractions(postId: widget.initialPost!.id!);
      _checkFavoriteStatus();
      _incrementViews();
      _loadSupportModalSeen();
      if (_isLookChallenge && widget.initialPost!.challenge_id != null) {
        _loadChallengeData();
        _checkIfUserHasVoted();
      }
    }

    _initializeFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstScrollModalIfNeeded();
    });
  }
  Future<void> _lazyLoadPostRelations(Post post) async {
    if (_loadingRelations.contains(post.id)) return;
    _loadingRelations.add(post.id!);

    try {
      await _loadPostRelations(post); // utilise la méthode existante
      if (mounted) setState(() {});
    } finally {
      _loadingRelations.remove(post.id);
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


      print("📜 Chargement anciennes vidéos entre $startDate et $endDate");

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
        print("⚠️ Aucune vidéo trouvée dans cette période");
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
        print("✅ ${validOldVideos.length} anciennes vidéos ajoutées (cache: ${_oldVideosCache.length})");
      } else {
        print("⚠️ Aucune vidéo valide après filtrage");
      }
    } catch (e) {
      print("❌ Erreur chargement anciennes vidéos: $e");
    } finally {
      _isLoadingOldVideos = false;
    }
  }
  // Vérifier si le post est en favori
  void _checkFavoriteStatus() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    final postDoc = await _firestore.collection('Posts').doc(widget.initialPost!.id).get();
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
      print("Erreur favori: $e");
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
    _likeAnimationTimer?.cancel();

    // Nettoyer tous les
    // contrôleurs préchargés
    for (var controller in _preloadedControllers.values) {
      controller.dispose();
    }
    _preloadedControllers.clear();
    _suggestionModalTimer?.cancel();
    _scrollHintTimer?.cancel();
    _pageController.dispose();
    _disposeCurrentVideo();
    _postSubscriptions.forEach((key, subscription) => subscription.cancel());
    super.dispose();
  }
  void _disposeCurrentVideo() {
    _chewieController?.dispose();
    _currentVideoController?.dispose();
    setState(() {
      _isVideoInitialized = false;
    });
  }
  // ==================== MÉTHODES DE PRÉCHARGEMENT ====================

  Future<void> _preloadVideoAtIndex(int index) async {
    if (index < 0 || index >= _feedItems.length) return;
    final item = _feedItems[index];
    if (item is! Post) return;
    final post = item;

    if (_preloadedControllers.containsKey(index)) return;
    if (_preloadingIndices.contains(index)) return;

    _preloadingIndices.add(index);

    try {
      final optimizedUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
      final controller = VideoPlayerController.network(optimizedUrl);
      await controller.initialize();
      // NE PAS jouer, NE PAS mettre en pause, NE PAS seek
      // L'initialisation seule suffit à remplir le buffer
      _preloadedControllers[index] = controller;
      print("✅ Vidéo préchargée à l'index $index");
    } catch (e) {
      print("❌ Erreur préchargement index $index : $e");
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
    // Si un index est fourni et qu'un contrôleur préchargé existe, on l'utilise
    if (index != null && _preloadedControllers.containsKey(index)) {
      final preloadedController = _preloadedControllers[index]!;

      // Nettoyer l'ancien ChewieController sans disposer le contrôleur vidéo
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
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
      await _recordPostView(post);
      _startSuggestionModalTimer();
      return;
    }

    // Fallback : comportement normal si pas de préchargement
    _disposeCurrentVideo();
    if (post.url_media == null || post.url_media!.isEmpty) return;

    try {
      final String optimizedUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
      _currentVideoController = VideoPlayerController.network(optimizedUrl);
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
      await _recordPostView(post);
      _startSuggestionModalTimer();
    } catch (e) {
      print('❌ Erreur init vidéo: $e');
      setState(() => _isVideoInitialized = false);
    }
  }
  // ==================== FEED LOADING (MODIFIÉ) ====================
  Future<void> _initializeFeed() async {
    setState(() => _isLoadingFeed = true);

    _itemsSinceLastLoad = 0;
    _maxVideosReached = false;
    _lastDocument = null;
    _usedOldVideoIds.clear();

    // 🔥 Charger vidéo initiale SEULEMENT si elle existe
    if (widget.initialPost != null && !_loadedPostIds.contains(widget.initialPost!.id)) {
      _loadedPostIds.add(widget.initialPost!.id!);
      _videoPosts.add(widget.initialPost!);
      await _loadPostRelations(widget.initialPost!);
      _subscribeToPostUpdates(widget.initialPost!);
    }

    // Charger vidéos récentes
    await _loadMoreVideos(isInitial: true);

    // Charger les anciennes vidéos
    await _loadOldVideosInBackground();

    // Construire feed final
    _rebuildFeedItems();

    setState(() => _isLoadingFeed = false);

    // Init player seulement si le feed n'est pas vide
    if (_feedItems.isNotEmpty && _feedItems[0] is Post) {
      _preloadNeighborhood(0);
      _initializeVideo(_feedItems[0] as Post, index: 0);
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
      widget.initialPost!.users_vue_id ??= [];
      if (widget.initialPost!.users_vue_id!.contains(currentUserId)) {
        print('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }
      authProvider. incrementPostTotalInteractions(postId: widget.initialPost!.id!);

      setState(() {
        widget.initialPost!.vues = (widget.initialPost!.vues ?? 0) + 1;
        widget.initialPost!.users_vue_id!.add(currentUserId);
      });
      await _firestore.collection('Posts').doc(widget.initialPost!.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });
      print('✅ Vue unique enregistrée pour ${widget.initialPost!.id}');
    } catch (e) {
      print("Erreur incrémentation vues: $e");
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

    // insertion ads
    final ads = authProvider.advertisements;
    _feedItems.clear();

    int adIdx = 0;

    for (int i = 0; i < mixedPosts.length; i++) {
      _feedItems.add(mixedPosts[i]);

      if ((i + 1) % 3 == 0 &&
          i != mixedPosts.length - 1 &&
          adIdx < ads.length) {
        _feedItems.add(ads[adIdx]);
        adIdx++;
      }
    }
  }
  void _rebuildFeedItems2() {
    _feedItems.clear();
    final ads = authProvider.advertisements;
    if (_videoPosts.isEmpty) return;

    int videoIdx = 0;
    int adIdx = 0;

    while (videoIdx < _videoPosts.length) {
      // Ajouter la vidéo courante
      _feedItems.add(_videoPosts[videoIdx]);
      videoIdx++;

      // Toutes les 3 vidéos (sauf si c'est la dernière), insérer une pub
      if (videoIdx % 3 == 0 && videoIdx < _videoPosts.length && adIdx < ads.length) {
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
      } catch (e) { print('Erreur chargement user: $e'); }
    }

    if (post.canal_id != null && post.canal_id!.isNotEmpty && post.canal == null) {
      try {
        final canalDoc = await _firestore.collection('Canaux').doc(post.canal_id).get();
        if (canalDoc.exists) {
          post.canal = Canal.fromJson(canalDoc.data()!);
        }
      } catch (e) { print('Erreur chargement canal: $e'); }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMoreVideos({bool isInitial = false}) async {
    if (_isLoadingMore) return;
    if (_maxVideosReached) return; // déjà atteint 50 vidéos

    setState(() => _isLoadingMore = true);
    try {
      final newPosts = await _fetchSuggestedVideosBatch(limit: _batchSize, excludeIds: _loadedPostIds);
      if (newPosts.isEmpty) {
        // Aucune nouvelle vidéo trouvée, on s'arrête
        _maxVideosReached = true;
      } else {
        for (var post in newPosts) {
          if (post.id != null && !_loadedPostIds.contains(post.id)) {
            _loadedPostIds.add(post.id!);
            _videoPosts.add(post);
            await _loadPostRelations(post);
            _subscribeToPostUpdates(post);
          }
        }
        // Vérifier si on a dépassé ou atteint la limite de 50 vidéos
        if (_videoPosts.length >= _maxVideosLimit) {
          _maxVideosReached = true;
        }
        _rebuildFeedItems();
      }
    } catch (e) {
      print('Erreur chargement vidéos: $e');
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
        candidates = await fetchOrdered('created_at', true, limit * 2);
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


  void _subscribeToPostUpdates(Post post) {
    if (post.id == null || _postSubscriptions.containsKey(post.id)) return;
    final subscription = _firestore.collection('Posts').doc(post.id).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final updatedPost = Post.fromJson(snapshot.data() as Map<String, dynamic>);
        setState(() {
          final index = _videoPosts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            updatedPost.user = _videoPosts[index].user;
            updatedPost.canal = _videoPosts[index].canal;
            _videoPosts[index] = updatedPost;
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
    } catch (e) { print('Erreur enregistrement vue: $e'); }
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: _afroDarkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.swipe_vertical, color: _afroYellow), SizedBox(width: 8), Text('Astuces Vidéo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Astuce 1 : Scroll
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _afroYellow.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swipe_vertical, color: _afroYellow, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Glisser pour découvrir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Défiler vers le haut ou le bas pour voir d\'autres vidéos tendance.', style: TextStyle(color: _twitterTextSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Astuce 2 : Double tap pour liker
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _afroRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite, color: _afroRed, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Double tap pour aimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Tapez deux fois rapidement sur la vidéo pour envoyer un like ❤️', style: TextStyle(color: _twitterTextSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Astuce 3 : Pièces et cadeaux (optionnel)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _afroGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.card_giftcard, color: _afroGreen, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cadeaux et soutien', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Envoyez des cadeaux ou soutenez les créateurs avec les boutons à droite.', style: TextStyle(color: _twitterTextSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _markSuggestionsModalSeen();
            },
            child: const Text('Compris !', style: TextStyle(color: _afroGreen)),
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
  // Je vais les écrire succinctement mais complètes :
  Future<void> _handleLike(Post post) async {
    final userId = authProvider.loginUserData.id;
    final screenSize = MediaQuery.of(context).size;
    _showFlyingHearts(screenSize.width / 2, screenSize.height / 2);
    // _handleLike(post);
    if (userId == null) return;

    // final isLiked = post.users_love_id?.contains(userId) ?? false;
    // if (isLiked) return;

    // 🔥 VÉRIFICATION DU SOLDE DE PIÈCES (2 pièces minimum)
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final hasEnoughCoins = coinProvider.giftCoinsBalance >= 2;

    if (!hasEnoughCoins) {
      _showInsufficientCoinsForLikeDialog();
      return;
    }

    try {
      // 🔥 ENVOI DU LIKE AVEC PIÈCES
      final success = await coinProvider.sendLikeWithCoins(
        senderId: userId,
        receiverId: post.user_id!,
        post: post,
        context: context,
      );

      if (!success) {
        _showInsufficientCoinsForLikeDialog();
        return;
      }

      // Mise à jour locale uniquement (Firestore déjà mis à jour par sendLikeWithCoins)
      setState(() {
        post.loves = (post.loves ?? 0) + 1;
        post.users_love_id = [...?post.users_love_id, userId];
      });

      final isLiked = post.users_love_id?.contains(userId) ?? false;
      if (!isLiked) {
        // Interactions supplémentaires (si nécessaire)
        postProvider.interactWithPostAndIncrementSolde(post.id!, userId, "like", post.user_id!);
        authProvider.incrementPostTotalInteractions(postId: post.id!);

        // Envoi de la notification
        _sendLikeNotification(post);
      }


      // Feedback utilisateur
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('❤️ Like envoyé ! 1 pièce offerte au créateur.'),
      //     backgroundColor: Colors.green,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      // print('Erreur like: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Erreur: $e'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    }
  }

// Dialog pour solde insuffisant (à ajouter dans la classe)
  void _showInsufficientCoinsForLikeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '💡 Soutenez le créateur !',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chaque like que vous envoyez offre 1 pièce au créateur du post !',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('🪙', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le like coûte 2 pièces :\n• Pour soutenir le créateur',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rechargez votre compte pour continuer à soutenir vos créateurs préférés !',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
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
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
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
    } catch (e) { print('Erreur like: $e'); }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: _afroBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Commentaires', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))])),
            Expanded(child: PostComments(post: post)),
          ],
        ),
      ),
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
            const SnackBar(
              content: Text('🎁 Cadeau envoyé avec succès !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // 🔥 Appeler le callback parent si existant
          // widget.onGiftSuccess?.call();
        },
      ),
    );
  }
  void _showGiftDialog2(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => Dialog(
            backgroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.yellow, width: 2)),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Envoyer un Cadeau', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 12),
                  const Text('Choisissez le montant en FCFA', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
                      itemCount: giftPrices.length,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () => setStateDialog(() => _selectedGiftIndex = index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedGiftIndex == index ? Colors.green : Colors.grey[800],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _selectedGiftIndex == index ? Colors.yellow : Colors.transparent),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(giftIcons[index], style: const TextStyle(fontSize: 24)), const SizedBox(height: 5), Text('${giftPrices[index].toInt()} FCFA', style: const TextStyle(color: Colors.white))]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA', style: const TextStyle(color: Colors.yellow)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.white))),
                    ElevatedButton(onPressed: () { Navigator.pop(context); _sendGift(giftPrices[_selectedGiftIndex], post); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Envoyer', style: TextStyle(color: Colors.black))),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text('🎁 Cadeau envoyé!')));
    } catch (e) { print('Erreur envoi cadeau: $e'); }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Solde insuffisant', style: TextStyle(color: Colors.yellow)),
        content: const Text('Rechargez votre compte pour envoyer un cadeau.', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.white))),
          ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Recharger')),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partagé !'), backgroundColor: Colors.green));
    } catch (e) { print('Erreur partage: $e'); } finally { setState(() => _isSharing = false); }
  }

  void _showPostMenu(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _afroDarkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton Partager (comme sur TikTok)
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Partager', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                 _sharePost(post);
              },
            ),

            if (post.user_id != authProvider.loginUserData.id)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.white),
                title: const Text('Signaler', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  await postProvider.updateVuePost(post, context);
                },
              ),

            if (post.user_id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _deletePost(post, context);
                },
              ),

            const Divider(color: Colors.grey),

            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.white),
              title: const Text('Annuler', style: TextStyle(color: Colors.white)),
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
    } catch (e) { print('Erreur suppression: $e'); }
  }

  // ==================== CHALLENGE & VOTE ====================
  Future<void> _loadChallengeData() async {
    if (widget.initialPost!.challenge_id == null) return;
    setState(() => _loadingChallenge = true);
    try {
      final doc = await _firestore.collection('Challenges').doc(widget.initialPost!.challenge_id).get();
      if (doc.exists) setState(() => _challenge = Challenge.fromJson(doc.data()!)..id = doc.id);
    } catch (e) { print('Erreur chargement challenge: $e'); } finally { setState(() => _loadingChallenge = false); }
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _afroDarkGrey,
        title: const Text('Confirmer votre vote', style: TextStyle(color: Colors.white)),
        content: Text(!_challenge!.voteGratuit! ? 'Ce vote coûtera ${_challenge!.prixVote} FCFA.' : 'Votre vote est gratuit et définitif.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await _processVoteWithChallenge(user.uid); }, style: ElevatedButton.styleFrom(backgroundColor: _afroGreen), child: const Text('Voter')),
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

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  void _showSoldeInsuffisant(int manquant) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _afroDarkGrey,
      title: const Text('Solde insuffisant', style: TextStyle(color: Colors.yellow)),
      content: Text('Il manque $manquant FCFA pour voter. Rechargez votre compte.', style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard')),
        ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen())); }, child: const Text('Recharger')),
      ],
    ),
  );

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _afroDarkGrey,
        title: const Row(children: [Icon(Icons.volunteer_activism, color: _afroYellow), SizedBox(width: 8), Text('Soutenir le créateur', style: TextStyle(color: Colors.white))]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Regardez cette publicité pour offrir 10 pièces au créateur.', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.monetization_on, color: _afroYellow), SizedBox(width: 8), Expanded(child: Text('Les pièces peuvent être converties en argent réel.', style: TextStyle(color: Colors.white)))])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Plus tard', style: TextStyle(color: Colors.white70))),
          ElevatedButton(onPressed: () async { Navigator.pop(context); await _markSupportModalSeen(); _startSupportAd(post); }, style: ElevatedButton.styleFrom(backgroundColor: _afroYellow), child: const Text('Regarder la pub', style: TextStyle(color: Colors.black))),
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

    final user = post.user;
    final canal = post.canal;

    final String displayName = canal != null
        ? '#${canal.titre ?? ''}'
        : '@${user?.pseudo ?? ''}';
    final String shortName = displayName.length > 10
        ? '${displayName.substring(0, 10)}...'
        : displayName;
    final isOwner = authProvider.loginUserData.id == post.user_id;

    // Affichage temporaire si toujours null
    if (canal == null && user == null && (post.user_id != null || post.canal_id != null)) {
      return Positioned(
        bottom: 120,
        left: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chargement...', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            if (post.description != null)
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(post.description!, style: const TextStyle(color: Colors.white), maxLines: 2),
              ),
          ],
        ),
      );
    }

    // Affichage normal (identique à l’original)
    return Positioned(
      bottom: 120,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canal != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (user != null) ...[
                    const SizedBox(width: 4),
                    AbonnementUtils.getUserBadge(abonnement: user.abonnement, isVerified: user.isVerify ?? false),
                  ],
                ],
              ),
            )
          else if (user != null)
            GestureDetector(
              onTap: () => showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(width: 4),
                  AbonnementUtils.getUserBadge(abonnement: user.abonnement, isVerified: user.isVerify ?? false),
                ],
              ),
            ),
          if (canal != null)
            Text('${canal.usersSuiviId?.length ?? 0} abonnés', style: const TextStyle(color: Colors.white70))
          else if (user != null)
            Text('${user.userAbonnesIds?.length ?? 0} abonnés', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          if (post.description != null)
            Container(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(post.description!, style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => _handleGift(post),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _afroDarkGrey.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: _afroYellow.withOpacity(0.5))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isSupporting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _afroYellow))
                          : const Icon(Icons.volunteer_activism, color: _afroYellow, size: 16),
                      const SizedBox(width: 6),
                      const Text('Soutenir le créateur', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          PostGiftsList(postId: post.id!, compactLevel: CompactLevel.light, maxDisplayItems: 10),
        ],
      ),
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

  Widget _buildActionButtons(Post post) {
    // Lance le chargement si nécessaire
    if ((post.user == null && post.user_id != null) ||
        (post.canal == null && post.canal_id != null)) {
      _lazyLoadPostRelations(post);
    }

    final isLiked = post.users_love_id?.contains(authProvider.loginUserData.id) ?? false;

    return Positioned(
      right: 16,
      bottom: 90,
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final user = post.user;
              final canal = post.canal;
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
                    backgroundImage: (post.canal?.urlImage != null || post.user?.imageUrl != null)
                        ? NetworkImage(post.canal?.urlImage ?? post.user?.imageUrl ?? '')
                        : null,
                    child: (post.canal == null && post.user == null) ? const CircularProgressIndicator(strokeWidth: 2) : null,
                  ),
                ),
                _buildSubscribeIcon(post),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
              GestureDetector(onTap: () => _handleLike(post), child: const Icon(Icons.favorite_border, color: _afroRed, size: 30)),
              Text('${post.loves ?? 0}', style: const TextStyle(color: Colors.white)),
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
      ),
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

  Widget _buildVideoPage(Post post) {
    return Stack(
      children: [
        // Vidéo avec son propre détecteur de double tap
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: () {
              // final screenSize = MediaQuery.of(context).size;
              // _showFlyingHearts(screenSize.width / 2, screenSize.height / 2);
              _handleLike(post);
            },
            child: _buildVideoPlayer(post),
          ),
        ),

        // Contenu interactif (boutons, infos) - au-dessus de la vidéo
        _buildUserInfo(post),
        _buildActionButtons(post),
        _buildScrollHint(),

        // Animation des cœurs
        ..._buildFlyingHearts(),

        if (widget.isIn)
          Positioned(
            top:12,
            left: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.yellow)), const Text('Vibe vidéos', style: TextStyle(color: _afroGreen, fontSize: 20, fontWeight: FontWeight.bold))]),
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
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _afroBlack,
          body: _isLoadingFeed
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: _afroGreen),
                const SizedBox(height: 20),
                Text(
                  'Chargement des vibes en cours...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Préparez-vous pour le meilleur contenu 🔥',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
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
              setState(() => _currentPage = index);
              _itemsSinceLastLoad++;
              if (_itemsSinceLastLoad >= 3 && !_maxVideosReached && !_isLoadingMore) {
                _itemsSinceLastLoad = 0;
                await _loadMoreVideos();
              }

              // Nettoyer les contrôleurs hors de la zone visible
              _cleanupOutOfRangeControllers(index);
              // Précharger les vidéos autour de l'index courant
              _preloadNeighborhood(index);

              if (index < _feedItems.length && _feedItems[index] is Post) {
                final post = _feedItems[index] as Post;
                _initializeVideo(post, index: index);
              }
            },
            itemBuilder: (context, index) {
              final item = _feedItems[index];
              if (item is Post) {
                return _buildVideoPage(item);
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
        // Bannière publicitaire en bas
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: const MrecAdWidget(showLessAdsButton: true),
        ),
        if (_showRewardedAd)
          RewardedAdWidget(
            key: _rewardedAdKey,
            onUserEarnedReward: (amount, name) async => await _onSupportAdRewarded(_videoPosts[_currentPage]),
            onAdDismissed: () => setState(() { _showRewardedAd = false; _isSupporting = false; }),
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
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