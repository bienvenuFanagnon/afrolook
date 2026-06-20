import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/pub/banner_ad_widget.dart';
import 'package:afrotok/pages/pub/native_ad_widget.dart';
import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';
import 'package:afrotok/pages/widgetGlobal.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../providers/coin_gift_provider.dart';
import '../../services/utils/abonnement_utils.dart';
import '../../widgets/user_badge_widget.dart';
import '../admin/AfrolookPub/ad_post_page_video_widget.dart';
import '../canaux/detailsCanal.dart';
import '../coins/coin_gift_dialog.dart';
import '../coins/coin_recharge_screen.dart';
import '../coins/post_gifts_list.dart';

import 'package:shared_preferences/shared_preferences.dart';

const _vibeBlack = Color(0xFF000000);
const _vibeGreen = Color(0xFF2ECC71);
const _vibeYellow = Color(0xFFF1C40F);
const _vibeRed = Color(0xFFE74C3C);
const _vibeDarkGrey = Color(0xFF16181C);
const _vibeLightGrey = Color(0xFF71767B);

// Catégories de vibes
final Map<String, Map<String, dynamic>> vibeCategories = {
  'COMEDIE': {'label': '🎭 Comédie', 'icon': Icons.theater_comedy, 'color': Colors.orange, 'emoji': '😂'},
  'DANSE': {'label': '💃 Danse', 'icon': Icons.music_note, 'color': Colors.pink, 'emoji': '💃'},
  'MUSIQUE': {'label': '🎵 Musique', 'icon': Icons.music_video, 'color': Colors.purple, 'emoji': '🎤'},
  'CHALLENGE': {'label': '🏆 Challenge', 'icon': Icons.emoji_events, 'color': Colors.yellow, 'emoji': '🔥'},
  'TUTO': {'label': '📱 Tutoriel', 'icon': Icons.school, 'color': Colors.blue, 'emoji': '📚'},
  'ASTUCE': {'label': '💡 Astuce', 'icon': Icons.lightbulb, 'color': Colors.green, 'emoji': '✨'},
  'INSPIRATION': {'label': '✨ Inspiration', 'icon': Icons.psychology, 'color': Colors.teal, 'emoji': '💫'},
  'LOL': {'label': '😂 LOL', 'icon': Icons.face, 'color': Colors.red, 'emoji': '🤣'},
  'FOOT': {'label': '⚽ Foot', 'icon': Icons.sports_soccer, 'color': Colors.green, 'emoji': '⚽'},
  'BASKET': {'label': '🏀 Basket', 'icon': Icons.sports_basketball, 'color': Colors.orange, 'emoji': '🏀'},
};

class VibesVideoPage extends StatefulWidget {
  final Post? initialVibe;
  final bool isIn;

  const VibesVideoPage({Key? key, this.initialVibe, this.isIn = false}) : super(key: key);

  @override
  State<VibesVideoPage> createState() => _VibesVideoPageState();
}

class _VibesVideoPageState extends State<VibesVideoPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late PageController _pageController;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;
  int _itemsSinceLastLoad = 0;
  List<dynamic> _feedItems = [];
  List<Post> _vibePosts = [];
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
  final int _maxVideosLimit = 100;

  // Préchargement
  final Map<int, VideoPlayerController> _preloadedControllers = {};
  final int _preloadRadius = 2;
  final Set<int> _preloadingIndices = {};

  // Interactions
  bool _isSharing = false;
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

  // Animations
  final List<FlyingHeart> _flyingHearts = [];
  final Random _random = Random();
  bool _isFavorite = false;
  int _favoritesCount = 0;
  bool _isFavoriteProcessing = false;

  // Cache anciennes vibes
  List<Post> _oldVibesCache = [];
  bool _isLoadingOldVibes = false;
  Timer? _oldVibesLoadTimer;

  // Cache des fenêtres mensuelles déjà testées et trouvées vides (clé = startDate du mois)
  final Set<DateTime> _emptyOldVibesWindows = {};
  Set<String> _usedOldVibeIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0, viewportFraction: 1.0);
    _initSharedPreferences();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    if (widget.initialVibe != null) {
      authProvider.incrementPostTotalInteractions(postId: widget.initialVibe!.id!);
      _checkFavoriteStatus();
      _incrementViews();
      _loadSupportModalSeen();
    }

    _initializeFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstScrollModalIfNeeded();
    });
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void _checkFavoriteStatus() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null || widget.initialVibe == null) return;

    final postDoc = await _firestore.collection('Posts').doc(widget.initialVibe!.id).get();
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

  Future<void> _toggleFavorite() async {
    if (_isFavoriteProcessing || widget.initialVibe == null) return;
    _isFavoriteProcessing = true;

    final userId = authProvider.loginUserData.id;
    if (userId == null) {
      _isFavoriteProcessing = false;
      return;
    }

    try {
      if (_isFavorite) {
        await _firestore.collection('Posts').doc(widget.initialVibe!.id).update({
          'users_favorite_id': FieldValue.arrayRemove([userId]),
          'favorites_count': FieldValue.increment(-1),
        });
        setState(() {
          _isFavorite = false;
          _favoritesCount--;
        });
      } else {
        await _firestore.collection('Posts').doc(widget.initialVibe!.id).update({
          'users_favorite_id': FieldValue.arrayUnion([userId]),
          'favorites_count': FieldValue.increment(1),
        });
        setState(() {
          _isFavorite = true;
          _favoritesCount++;
        });
        if (widget.initialVibe!.user_id != userId) {
          await authProvider.sendNotification(
            userIds: [widget.initialVibe!.user?.oneIgnalUserid ?? ''],
            smallImage: authProvider.loginUserData.imageUrl ?? '',
            send_user_id: userId,
            recever_user_id: widget.initialVibe!.user_id!,
            message: "📌 @${authProvider.loginUserData.pseudo} a ajouté votre vibe aux favoris",
            type_notif: NotificationType.FAVORITE.name,
            post_id: widget.initialVibe!.id!,
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

  String _formatNumber(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  void dispose() {
    for (var controller in _preloadedControllers.values) {
      controller.dispose();
    }
    _preloadedControllers.clear();
    _suggestionModalTimer?.cancel();
    _scrollHintTimer?.cancel();
    _oldVibesLoadTimer?.cancel();
    _pageController.dispose();
    _disposeCurrentVideo();
    _postSubscriptions.forEach((key, subscription) => subscription.cancel());
    super.dispose();
  }

  void _disposeCurrentVideo() {
    _chewieController?.dispose();
    _currentVideoController?.dispose();
    setState(() => _isVideoInitialized = false);
  }

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
      _preloadedControllers[index] = controller;
    } catch (e) {
      print("❌ Erreur préchargement: $e");
    } finally {
      _preloadingIndices.remove(index);
    }
  }

  void _preloadNeighborhood(int currentIndex) {
    final start = max(0, currentIndex - _preloadRadius);
    final end = min(_feedItems.length - 1, currentIndex + _preloadRadius);
    for (int i = start; i <= end; i++) {
      if (_feedItems[i] is Post) _preloadVideoAtIndex(i);
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
    for (var idx in toRemove) _preloadedControllers.remove(idx);

    // Limite le nombre de listeners Firestore actifs au voisinage affiché
    final keepIds = <String>{};
    for (int i = max(0, minKeep); i <= min(_feedItems.length - 1, maxKeep); i++) {
      final item = _feedItems[i];
      if (item is Post && item.id != null) keepIds.add(item.id!);
    }
    final subsToRemove = _postSubscriptions.keys.where((id) => !keepIds.contains(id)).toList();
    for (final id in subsToRemove) {
      _postSubscriptions[id]?.cancel();
      _postSubscriptions.remove(id);
    }
  }

  Future<void> _initializeVideo(Post post, {int? index}) async {
    if (index != null && _preloadedControllers.containsKey(index)) {
      final preloadedController = _preloadedControllers[index]!;
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }
      _currentVideoController = preloadedController;
      _chewieController = ChewieController(
        videoPlayerController: _currentVideoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _vibeGreen,
          handleColor: _vibeGreen,
          backgroundColor: _vibeLightGrey.withOpacity(0.3),
          bufferedColor: _vibeLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(
          color: _vibeBlack,
          child: const Center(child: CircularProgressIndicator(color: _vibeGreen)),
        ),
        autoInitialize: true,
      );
      setState(() => _isVideoInitialized = true);
      await _recordPostView(post);
      _startSuggestionModalTimer();
      return;
    }

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
          playedColor: _vibeGreen,
          handleColor: _vibeGreen,
          backgroundColor: _vibeLightGrey.withOpacity(0.3),
          bufferedColor: _vibeLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(color: _vibeBlack, child: const Center(child: CircularProgressIndicator(color: _vibeGreen))),
        autoInitialize: true,
      );
      setState(() => _isVideoInitialized = true);
      await _recordPostView(post);
      _startSuggestionModalTimer();
    } catch (e) {
      print('❌ Erreur init vibe: $e');
      setState(() => _isVideoInitialized = false);
    }
  }

  Future<void> _initializeFeed() async {
    setState(() => _isLoadingFeed = true);
    _itemsSinceLastLoad = 0;
    _maxVideosReached = false;
    _lastDocument = null;
    _usedOldVibeIds.clear();

    if (widget.initialVibe != null && !_loadedPostIds.contains(widget.initialVibe!.id)) {
      _loadedPostIds.add(widget.initialVibe!.id!);
      _vibePosts.add(widget.initialVibe!);
      await _loadPostRelations(widget.initialVibe!);
      _subscribeToPostUpdates(widget.initialVibe!);
    }

    await _loadMoreVibes(isInitial: true);
    await _loadOldVibesInBackground();
    _startOldVibesLoading();
    _rebuildFeedItems();
    setState(() => _isLoadingFeed = false);

    if (_feedItems.isNotEmpty && _feedItems[0] is Post) {
      _preloadNeighborhood(0);
      _initializeVideo(_feedItems[0] as Post, index: 0);
    }
  }

  /// Choisit une fenêtre mensuelle aléatoire (1-6 mois) en évitant si possible
  /// les fenêtres déjà connues comme vides.
  DateTime _pickRandomOldVibesWindowStart(Random random) {
    DateTime? candidate;

    for (int attempt = 0; attempt < 5; attempt++) {
      int monthsBack = random.nextInt(6) + 1;
      final now = DateTime.now();
      final DateTime endDate = DateTime(now.year, now.month - monthsBack, 1);
      final DateTime startDate = DateTime(endDate.year, endDate.month - 1, 1);

      if (!_emptyOldVibesWindows.contains(startDate)) {
        return startDate;
      }
      candidate = startDate;
    }

    return candidate!;
  }

  Future<List<Post>> _fetchOldVibesForWindow(DateTime startDate) async {
    final DateTime endDate = DateTime(startDate.year, startDate.month + 1, 1);
    final int startMicros = startDate.microsecondsSinceEpoch;
    final int endMicros = endDate.microsecondsSinceEpoch;

    Query query = _firestore.collection('Posts')
        .where("dataType", isEqualTo: PostDataType.VIDEO.name)
        .where("typeTabbar", isEqualTo: "VIBE")
        .where("created_at", isGreaterThanOrEqualTo: startMicros)
        .where("created_at", isLessThan: endMicros)
        .orderBy("created_at")
        .limit(30);

    final snapshot = await query.get();
    if (snapshot.docs.isEmpty) return [];

    List<Post> validOldVibes = [];
    for (final doc in snapshot.docs) {
      final post = Post.fromJson(doc.data() as Map<String, dynamic>);
      post.id = doc.id;
      if (_loadedPostIds.contains(post.id)) continue;
      if (_oldVibesCache.any((p) => p.id == post.id)) continue;
      if (post.isAdvertisement == true) continue;
      validOldVibes.add(post);
      if (validOldVibes.length >= 12) break;
    }
    return validOldVibes;
  }

  Future<void> _loadOldVibesInBackground() async {
    if (_isLoadingOldVibes) return;
    _isLoadingOldVibes = true;
    try {
      final random = Random();

      // Jusqu'à 3 fenêtres tentées dans cette même passe : la fenêtre
      // initiale + jusqu'à 2 fallbacks si vide/quasi-vide (<3 posts).
      const int maxFallbacks = 2;
      List<Post> validOldVibes = [];

      for (int attempt = 0; attempt <= maxFallbacks; attempt++) {
        final startDate = _pickRandomOldVibesWindowStart(random);
        final found = await _fetchOldVibesForWindow(startDate);

        if (found.length < 3) {
          _emptyOldVibesWindows.add(startDate);
        }

        if (found.isNotEmpty) {
          validOldVibes = found;
          break;
        }
      }

      if (validOldVibes.isNotEmpty) {
        validOldVibes.shuffle();
        setState(() => _oldVibesCache.addAll(validOldVibes));
      }
    } catch (e) {
      print("❌ Erreur chargement anciennes vibes: $e");
    } finally {
      _isLoadingOldVibes = false;
    }
  }

  void _startOldVibesLoading() {
    _oldVibesLoadTimer?.cancel();
    // Recharge périodiquement le cache d'anciennes vibes si nécessaire,
    // intervalle aligné sur HomeConstPost (22s) - cf. SUIVI_REFONTE.md Session 9.
    _oldVibesLoadTimer = Timer.periodic(Duration(seconds: 22), (timer) {
      if (_oldVibesCache.length < 4 && !_isLoadingOldVibes) {
        _loadOldVibesInBackground();
      }
    });
  }

  void _rebuildFeedItems() {
    final List<Post> normalPosts = List.from(_vibePosts);
    final List<Post> oldBuffer = List.from(_oldVibesCache);
    final List<Post> mixedPosts = [];

    const int normalBatchSize = 3;
    const int oldPerBatch = 2;
    int normalIndex = 0;

    while (normalIndex < normalPosts.length) {
      int end = normalIndex + normalBatchSize;
      if (end > normalPosts.length) end = normalPosts.length;
      mixedPosts.addAll(normalPosts.sublist(normalIndex, end));
      normalIndex = end;

      int added = 0;
      while (oldBuffer.isNotEmpty && added < oldPerBatch) {
        final oldPost = oldBuffer.removeAt(0);
        if (_usedOldVibeIds.contains(oldPost.id)) continue;
        _usedOldVibeIds.add(oldPost.id!);
        mixedPosts.add(oldPost);
        added++;
      }
    }

    while (oldBuffer.isNotEmpty) {
      final oldPost = oldBuffer.removeAt(0);
      if (_usedOldVibeIds.contains(oldPost.id)) continue;
      _usedOldVibeIds.add(oldPost.id!);
      mixedPosts.add(oldPost);
    }

    final ads = authProvider.advertisements;
    _feedItems.clear();
    int adIdx = 0;
    for (int i = 0; i < mixedPosts.length; i++) {
      _feedItems.add(mixedPosts[i]);
      if ((i + 1) % 3 == 0 && i != mixedPosts.length - 1 && adIdx < ads.length) {
        _feedItems.add(ads[adIdx]);
        adIdx++;
      }
    }
  }

  Future<void> _loadPostRelations(Post post) async {
    if (post.user_id != null && post.user == null) {
      try {
        final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
        if (userDoc.exists) post.user = UserData.fromJson(userDoc.data()!);
      } catch (e) { print('Erreur chargement user: $e'); }
    }
    if (post.canal_id != null && post.canal_id!.isNotEmpty && post.canal == null) {
      try {
        final canalDoc = await _firestore.collection('Canaux').doc(post.canal_id).get();
        if (canalDoc.exists) post.canal = Canal.fromJson(canalDoc.data()!);
      } catch (e) { print('Erreur chargement canal: $e'); }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMoreVibes({bool isInitial = false}) async {
    if (_isLoadingMore || _maxVideosReached) return;
    setState(() => _isLoadingMore = true);
    try {
      final newPosts = await _fetchSuggestedVibesBatch(limit: _batchSize, excludeIds: _loadedPostIds);
      if (newPosts.isEmpty) {
        _maxVideosReached = true;
      } else {
        for (var post in newPosts) {
          if (post.id != null && !_loadedPostIds.contains(post.id)) {
            _loadedPostIds.add(post.id!);
            _vibePosts.add(post);
            await _loadPostRelations(post);
            _subscribeToPostUpdates(post);
          }
        }
        if (_vibePosts.length >= _maxVideosLimit) _maxVideosReached = true;
        _rebuildFeedItems();
      }
    } catch (e) {
      print('Erreur chargement vibes: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<Post>> _fetchSuggestedVibesBatch({required int limit, required Set<String> excludeIds}) async {
    List<Post> results = [];
    Set<String> ids = Set.from(excludeIds);
    int attempts = 0;
    const maxAttempts = 5;

    while (results.length < limit && attempts < maxAttempts) {
      attempts++;
      final random = Random();
      int strategy = random.nextInt(3);

      Future<List<Post>> fetchOrdered(String field, bool descending, int fetchLimit) async {
        final snap = await _firestore
            .collection('Posts')
            .where('dataType', isEqualTo: PostDataType.VIDEO.name)
            .where('typeTabbar', isEqualTo: "VIBE")
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
            .where('typeTabbar', isEqualTo: "VIBE")
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
        candidates = await fetchRandom(limit * 2);
      } else {
        candidates = await fetchOrdered('popularity', true, limit * 3);
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
          final index = _vibePosts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            updatedPost.user = _vibePosts[index].user;
            updatedPost.canal = _vibePosts[index].canal;
            _vibePosts[index] = updatedPost;
          }
        });
      }
    });
    _postSubscriptions[post.id!] = subscription;
  }

  Future<void> _incrementViews() async {
    if (widget.initialVibe == null || widget.initialVibe!.id == null) return;
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;
    try {
      widget.initialVibe!.users_vue_id ??= [];
      if (widget.initialVibe!.users_vue_id!.contains(currentUserId)) return;
      authProvider.incrementPostTotalInteractions(postId: widget.initialVibe!.id!);
      setState(() {
        widget.initialVibe!.vues = (widget.initialVibe!.vues ?? 0) + 1;
        widget.initialVibe!.users_vue_id!.add(currentUserId);
      });
      await _firestore.collection('Posts').doc(widget.initialVibe!.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });
    } catch (e) { print("Erreur vues: $e"); }
  }

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
    } catch (e) { print('Erreur vue: $e'); }
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

  void _startSuggestionModalTimer() {
    _shouldShowSuggestionsModal().then((shouldShow) {
      if (!shouldShow) return;
      _suggestionModalTimer?.cancel();
      _suggestionModalTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) _showFirstScrollModal();
      });
    });
  }

  Future<bool> _shouldShowSuggestionsModal() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return false;
    final lastShowKey = 'vibes_modal_last_show_$userId';
    final lastShowTimestamp = _prefs.getInt(lastShowKey);
    if (lastShowTimestamp == null) return true;
    final lastShowDate = DateTime.fromMillisecondsSinceEpoch(lastShowTimestamp);
    final difference = DateTime.now().difference(lastShowDate).inDays;
    return difference >= 3;
  }

  Future<void> _markSuggestionsModalSeen() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    final lastShowKey = 'vibes_modal_last_show_$userId';
    await _prefs.setInt(lastShowKey, DateTime.now().millisecondsSinceEpoch);
    if (mounted) setState(() => _hasSeenSuggestionsModal = true);
  }

  void _showFirstScrollModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: _vibeDarkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.music_video, color: _vibeYellow), SizedBox(width: 8), Text('Bienvenue dans les Vibes !', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _vibeYellow.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.swipe_vertical, color: _vibeYellow, size: 28)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Glissez vers le haut/bas pour découvrir des vibes', style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _vibeRed.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.favorite, color: _vibeRed, size: 28)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Double tap pour aimer et soutenir le créateur ❤️', style: TextStyle(color: Colors.white))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _markSuggestionsModalSeen(); }, child: const Text('Compris !', style: TextStyle(color: _vibeGreen))),
        ],
      ),
    );
  }

  void _showFirstScrollModalIfNeeded() async {
    final userId = authProvider.loginUserData.id;
    final key = 'first_vibes_modal_shown_$userId';
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
    final List<Color> heartColors = [Colors.red, Colors.pink, Colors.deepOrange, Colors.orange, Colors.pinkAccent];
    final heartCount = 15;

    for (int i = 0; i < heartCount; i++) {
      final startX = tapX + (_random.nextDouble() - 0.5) * 40;
      final startY = tapY + (_random.nextDouble() - 0.5) * 30;
      final angle = (-pi / 2) + (_random.nextDouble() - 0.5) * (pi / 1.5);
      final distance = 150 + _random.nextDouble() * 150;
      final endX = startX + (cos(angle) * distance);
      final endY = startY - (80 + _random.nextDouble() * 120);
      final size = 25 + _random.nextDouble() * 35;
      final rotation = (_random.nextDouble() - 0.5) * pi / 2;
      final duration = Duration(milliseconds: (600 + _random.nextInt(600)).toInt());
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
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flyingHearts.clear());
    });
  }

  List<Widget> _buildFlyingHearts() {
    List<Widget> widgets = [];
    for (int i = 0; i < _flyingHearts.length; i++) {
      widgets.add(_AnimatedHeart(key: ValueKey('heart_$i'), heart: _flyingHearts[i]));
    }
    return widgets;
  }

  Future<void> _handleLike(Post post) async {
    final screenSize = MediaQuery.of(context).size;
    _showFlyingHearts(screenSize.width / 2, screenSize.height / 2);
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final hasEnoughCoins = coinProvider.giftCoinsBalance >= 2;

    if (!hasEnoughCoins) {
      _showInsufficientCoinsForLikeDialog();
      return;
    }

    try {
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
      setState(() {
        post.loves = (post.loves ?? 0) + 1;
        post.users_love_id = [...?post.users_love_id, userId];
      });
      postProvider.interactWithPostAndIncrementSolde(post.id!, userId, "like", post.user_id!);
      authProvider.incrementPostTotalInteractions(postId: post.id!);
      _sendLikeNotification(post);
    } catch (e) { print('Erreur like: $e'); }
  }

  void _showInsufficientCoinsForLikeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💡 Soutenez le créateur !', style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chaque like que vous envoyez offre 1 pièce au créateur !', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3))),
              child: const Row(children: [Text('🪙', style: TextStyle(fontSize: 20)), SizedBox(width: 8), Expanded(child: Text('Le like coûte 2 pièces pour soutenir le créateur', style: TextStyle(color: Colors.white70, fontSize: 12)))]),
            ),
            const SizedBox(height: 16),
            const Text('Rechargez votre compte pour continuer à soutenir vos créateurs préférés !', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (context) => const CoinRechargeScreen())); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
            child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLikeNotification(Post post) async {
    final currentUser = authProvider.loginUserData;
    if (post.user_id == currentUser.id) return;
    await authProvider.sendNotification(
      userIds: [post.user?.oneIgnalUserid ?? ''],
      smallImage: currentUser.imageUrl ?? '',
      send_user_id: currentUser.id!,
      recever_user_id: post.user_id!,
      message: "❤️ @${currentUser.pseudo} a aimé votre vibe",
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
        decoration: const BoxDecoration(color: _vibeBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Commentaires', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))])),
            Expanded(child: PostComments(post: post)),
          ],
        ),
      ),
    );
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
          setState(() {
            post.users_cadeau_id ??= [];
            if (!post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
              post.users_cadeau_id!.add(authProvider.loginUserData.id!);
            }
          });
          final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
          await coinProvider.refreshBalance(authProvider.loginUserData.id!);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎁 Cadeau envoyé avec succès !'), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        },
      ),
    );
  }

  void _sharePost(Post post) async {
    setState(() => _isSharing = true);
    try {
      final shareUrl = post.thumbnail ?? '';
      final linkService = AppLinkService();
      await linkService.shareContent(type: AppLinkType.post, id: post.id!, message: post.description ?? '', mediaUrl: shareUrl);
      await _firestore.collection('Posts').doc(post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
      });
      setState(() => post.partage = (post.partage ?? 0) + 1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vibe partagée !'), backgroundColor: Colors.green));
    } catch (e) { print('Erreur partage: $e'); } finally { setState(() => _isSharing = false); }
  }

  void _showPostMenu(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _vibeDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.share, color: Colors.white), title: const Text('Partager', style: TextStyle(color: Colors.white)), onTap: () async { Navigator.pop(context); _sharePost(post); }),
            if (post.user_id != authProvider.loginUserData.id)
              ListTile(leading: const Icon(Icons.flag, color: Colors.white), title: const Text('Signaler', style: TextStyle(color: Colors.white)), onTap: () async { Navigator.pop(context); await postProvider.updateVuePost(post, context); }),
            if (post.user_id == authProvider.loginUserData.id || authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Supprimer', style: TextStyle(color: Colors.red)), onTap: () async { Navigator.pop(context); await _deletePost(post); }),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.cancel, color: Colors.white), title: const Text('Annuler', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePost(Post post) async {
    try {
      await _firestore.collection('Posts').doc(post.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vibe supprimée')));
      if (_vibePosts.length == 1) Navigator.pop(context);
    } catch (e) { print('Erreur suppression: $e'); }
  }

  Future<void> _loadSupportModalSeen() async {
    final userId = authProvider.loginUserData.id;
    _hasSeenSupportModal = _prefs.getBool('has_seen_support_modal_$userId') ?? false;
  }

  void _startSupportAd(Post post) {
    setState(() { _isSupporting = true; _showRewardedAd = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _rewardedAdKey.currentState?.showAd());
  }

  Future<void> _onSupportAdRewarded(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    final creatorId = post.user_id!;
    await _firestore.collection('Posts').doc(post.id).update({'adSupportCount': FieldValue.increment(1)});
    await _firestore.collection('Users').doc(creatorId).update({'totalCoinsEarnedFromAdSupport': FieldValue.increment(1)});
    await _firestore.collection('Users').doc(currentUserId).update({'totalAdViewsSupported': FieldValue.increment(1)});
    await _firestore.collection('post_supports').add({'postId': post.id, 'userId': currentUserId, 'supportedAt': DateTime.now().millisecondsSinceEpoch});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci ! Le créateur a reçu 10 pièces.'), backgroundColor: Colors.green));
    setState(() { _isSupporting = false; _showRewardedAd = false; });
  }

  Widget _buildVideoPlayer(Post post) {
    if (!_isVideoInitialized) {
      return Container(
        color: _vibeBlack,
        child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: _vibeGreen), SizedBox(height: 16), Text('Chargement de la vibe...', style: TextStyle(color: Colors.white))])),
      );
    }
    return Chewie(controller: _chewieController!);
  }

  Widget _buildUserInfo(Post post) {
    if ((post.user == null && post.user_id != null) || (post.canal == null && post.canal_id != null)) {
      _lazyLoadPostRelations(post);
    }

    final user = post.user;
    final canal = post.canal;
    final vibeCategory = vibeCategories[post.categorie];
    final categoryEmoji = vibeCategory?['emoji'] ?? '🎬';
    final categoryColor = vibeCategory?['color'] ?? _vibeYellow;

    if (canal == null && user == null && (post.user_id != null || post.canal_id != null)) {
      return Positioned(bottom: 120, left: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Chargement...', style: TextStyle(color: Colors.white70)), if (post.description != null) Container(constraints: const BoxConstraints(maxWidth: 250), child: Text(post.description!, style: const TextStyle(color: Colors.white), maxLines: 2))]));
    }

    return Positioned(
      bottom: 120,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Catégorie de la vibe
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: categoryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: categoryColor)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(categoryEmoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(vibeCategory?['label'] ?? 'Vibe', style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Info créateur
          if (canal != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal))),
              child: Row(children: [Text('#${canal.titre ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), if (user != null) ...[const SizedBox(width: 4), UserBadgeWidget(user: user, size: 14)]]),
            )
          else if (user != null)
            GestureDetector(
              onTap: () => showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context),
              child: Row(children: [Text('@${user.pseudo ?? ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 4), UserBadgeWidget(user: user, size: 14)]),
            ),
          if (canal != null)
            Text('${canal.usersSuiviId?.length ?? 0} abonnés', style: const TextStyle(color: Colors.white70))
          else if (user != null)
            Text('${user.userAbonnesIds?.length ?? 0} abonnés', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          if (post.description != null)
            Container(constraints: const BoxConstraints(maxWidth: 250), child: Text(post.description!, style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (authProvider.loginUserData.id != post.user_id)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: () => _handleGift(post),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _vibeDarkGrey.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: _vibeYellow.withOpacity(0.5))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [_isSupporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _vibeYellow)) : const Icon(Icons.volunteer_activism, color: _vibeYellow, size: 16), const SizedBox(width: 6), const Text('Soutenir', style: TextStyle(color: Colors.white, fontSize: 12))]),
                ),
              ),
            ),
          PostGiftsList(postId: post.id!, compactLevel: CompactLevel.light, maxDisplayItems: 5),
        ],
      ),
    );
  }

  void _lazyLoadPostRelations(Post post) async {
    if (_loadingRelations.contains(post.id)) return;
    _loadingRelations.add(post.id!);
    try {
      await _loadPostRelations(post);
      if (mounted) setState(() {});
    } finally {
      _loadingRelations.remove(post.id);
    }
  }

  Widget _buildActionButtons(Post post) {
    if ((post.user == null && post.user_id != null) || (post.canal == null && post.canal_id != null)) {
      _lazyLoadPostRelations(post);
    }

    return Positioned(
      right: 16,
      bottom: 90,
      child: Column(
        children: [
          GestureDetector(
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
                  decoration: BoxDecoration(border: Border.all(color: _vibeGreen, width: 2), shape: BoxShape.circle),
                  child: CircleAvatar(radius: 25, backgroundImage: (post.canal?.urlImage != null || post.user?.imageUrl != null) ? NetworkImage(post.canal?.urlImage ?? post.user?.imageUrl ?? '') : null, child: (post.canal == null && post.user == null) ? const CircularProgressIndicator(strokeWidth: 2) : null),
                ),
                _buildSubscribeIcon(post),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Column(children: [GestureDetector(onTap: () => _handleLike(post), child: const Icon(Icons.favorite_border, color: _vibeRed, size: 30)), Text('${post.loves ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [GestureDetector(onTap: () => _showCommentsModal(post), child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 33)), Text('${post.comments ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [GestureDetector(onTap: () => _handleGift(post), child: const Icon(Icons.card_giftcard, color: _vibeYellow, size: 30)), Text('${post.totalGiftCoinsSentOnThisPost ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [GestureDetector(onTap: () {}, child: const Icon(Icons.bar_chart, color: Colors.blue, size: 35)), Text('${post.totalInteractions ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [GestureDetector(onTap: _toggleFavorite, child: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border, color: _isFavorite ? _vibeYellow : Colors.white, size: 30)), Text(_formatNumber(_favoritesCount), style: const TextStyle(color: Colors.white))]),
          GestureDetector(onTap: () => _showPostMenu(post), child: const Icon(Icons.more_vert, color: Colors.white, size: 30)),
        ],
      ),
    );
  }

  Widget _buildSubscribeIcon(Post post) {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) {
      return Positioned(
        bottom: -2, right: -2,
        child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add, color: Colors.white, size: 12)),
      );
    }
    if (post.canal_id != null && post.canal_id!.isNotEmpty) {
      final isSubscribed = post.canal?.usersSuiviId?.contains(currentUserId) ?? false;
      if (!isSubscribed) {
        return Positioned(
          bottom: -2, right: -2,
          child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add, color: Colors.white, size: 12)),
        );
      }
    } else if (post.user_id != null) {
      final isFollowing = post.user?.userAbonnesIds?.contains(currentUserId) ?? false;
      if (!isFollowing) {
        return Positioned(
          bottom: -2, right: -2,
          child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.add, color: Colors.white, size: 12)),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildScrollHint() {
    if (!_showScrollHint) return const SizedBox.shrink();
    return Positioned(
      bottom: 40, left: 0, right: 0,
      child: AnimatedOpacity(
        opacity: _showScrollHint ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: const Column(children: [Icon(Icons.swipe_vertical, color: _vibeYellow, size: 36), SizedBox(height: 4), Text('Glisser pour vibe suivante', style: TextStyle(color: Colors.white70, fontSize: 12))]),
      ),
    );
  }

  Widget _buildVideoPage(Post post) {
    return Stack(
      children: [
        Positioned.fill(child: GestureDetector(onDoubleTap: () => _handleLike(post), child: _buildVideoPlayer(post))),
        _buildUserInfo(post),
        _buildActionButtons(post),
        _buildScrollHint(),
        ..._buildFlyingHearts(),
        if (widget.isIn)
          Positioned(
            top: 12, left: 10,
            child: Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.yellow)), const Text('Vibes Vidéos', style: TextStyle(color: _vibeGreen, fontSize: 20, fontWeight: FontWeight.bold))]),
          ),
        if (_isLoadingMore && _vibePosts.length - _currentPage <= _preloadThreshold)
          const Positioned(bottom: 100, child: Center(child: CircularProgressIndicator(color: _vibeGreen))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: _vibeBlack,
          body: _isLoadingFeed
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: _vibeGreen),
                const SizedBox(height: 20),
                Text('Chargement des vibes en cours...', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('Préparez-vous pour des moments de divertissement 🔥', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          )
              : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _feedItems.length,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            onPageChanged: (index) async {
              setState(() => _currentPage = index);
              _itemsSinceLastLoad++;
              if (_itemsSinceLastLoad >= 3 && !_maxVideosReached && !_isLoadingMore) {
                _itemsSinceLastLoad = 0;
                await _loadMoreVibes();
              }
              _cleanupOutOfRangeControllers(index);
              _preloadNeighborhood(index);
              if (index < _feedItems.length && _feedItems[index] is Post) {
                final post = _feedItems[index] as Post;
                _initializeVideo(post, index: index);
              }
            },
            itemBuilder: (context, index) {
              final item = _feedItems[index];
              if (item is Post) return _buildVideoPage(item);
              if (item is Map<String, dynamic>) {
                return AdPostWidget(adData: item, width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.height, onComplete: () {
                  if (_pageController.hasClients && _pageController.page?.toInt() == index) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
                  }
                });
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: const MrecAdWidget(showLessAdsButton: true)),
        if (_showRewardedAd)
          RewardedAdWidget(
            key: _rewardedAdKey,
            onUserEarnedReward: (amount, name) async => await _onSupportAdRewarded(_vibePosts[_currentPage]),
            onAdDismissed: () => setState(() { _showRewardedAd = false; _isSupporting = false; }),
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class FlyingHeart {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final DateTime startTime;
  final Duration duration;
  final double rotation;
  final Color color;
  FlyingHeart({required this.startX, required this.startY, required this.endX, required this.endY, required this.size, required this.startTime, required this.duration, required this.rotation, required this.color});
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
    _controller = AnimationController(vsync: this, duration: widget.heart.duration);
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final progress = _progress.value;
        final currentX = widget.heart.startX + (widget.heart.endX - widget.heart.startX) * progress;
        final currentY = widget.heart.startY + (widget.heart.endY - widget.heart.startY) * progress;
        double opacity = progress < 0.7 ? 1.0 : 1.0 - ((progress - 0.7) / 0.3);
        opacity = opacity.clamp(0.0, 1.0);
        double scale = progress < 0.3 ? 0.5 + (progress / 0.3) * 0.8 : (progress < 0.7 ? 1.3 : 1.3 - ((progress - 0.7) / 0.3) * 0.8);
        scale = scale.clamp(0.3, 1.5);
        final rotation = widget.heart.rotation * (progress < 0.5 ? progress * 2 : (1 - progress) * 2);
        return Positioned(
          left: currentX - widget.heart.size / 2,
          top: currentY - widget.heart.size / 2,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: Icon(Icons.favorite, color: widget.heart.color, size: widget.heart.size)),
            ),
          ),
        );
      },
    );
  }
}