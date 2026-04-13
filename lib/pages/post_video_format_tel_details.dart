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

import 'UserServices/deviceService.dart';
import 'admin/AfrolookPub/ad_post_page_video_widget.dart';
import 'canaux/detailsCanal.dart';
import 'package:shared_preferences/shared_preferences.dart';


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
  final Post initialPost;
  final bool isIn;

  const PostDetailsVideoFormatTel({Key? key, required this.initialPost, this.isIn = false}) : super(key: key);

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

  bool get _isLookChallenge => widget.initialPost.type == 'CHALLENGEPARTICIPATION';

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    authProvider.incrementPostTotalInteractions(postId: widget.initialPost.id!);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _pageController = PageController();
    _incrementViews();
    _loadSupportModalSeen();
    if (_isLookChallenge && widget.initialPost.challenge_id != null) {
      _loadChallengeData();
      _checkIfUserHasVoted();
    }
    _initializeFeed();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstScrollModalIfNeeded();
    });
  }
  Future<void> _incrementViews() async {
    try {
      if (authProvider.loginUserData == null ||
          widget.initialPost == null ||
          widget.initialPost.id == null) return;
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;
      widget.initialPost.users_vue_id ??= [];
      if (widget.initialPost.users_vue_id!.contains(currentUserId)) {
        print('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }
      authProvider. incrementPostTotalInteractions(postId: widget.initialPost.id!);

      setState(() {
        widget.initialPost.vues = (widget.initialPost.vues ?? 0) + 1;
        widget.initialPost.users_vue_id!.add(currentUserId);
      });
      await _firestore.collection('Posts').doc(widget.initialPost.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });
      print('✅ Vue unique enregistrée pour ${widget.initialPost.id}');
    } catch (e) {
      print("Erreur incrémentation vues: $e");
    }
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  void dispose() {
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

  // ==================== FEED LOADING ====================

  Future<void> _initializeFeed() async {
    setState(() => _isLoadingFeed = true);
    _itemsSinceLastLoad = 0;
    _maxVideosReached = false;
    _lastDocument = null;
    // 1. Charger les publicités depuis le provider

    // 2. Ajouter la vidéo initiale
    if (!_loadedPostIds.contains(widget.initialPost.id)) {
      _loadedPostIds.add(widget.initialPost.id!);
      _videoPosts.add(widget.initialPost);
      await _loadPostRelations(widget.initialPost);
      _subscribeToPostUpdates(widget.initialPost);
    }

    // 3. Charger plus de vidéos
    await _loadMoreVideos(isInitial: true);

    // 4. Construire le feed mixte (vidéos + pubs)
    _rebuildFeedItems();

    setState(() => _isLoadingFeed = false);
    if (_feedItems.isNotEmpty && _feedItems[0] is Post) {
      _initializeVideo(_feedItems[0] as Post);
    }
  }

  void _rebuildFeedItems() {
    _feedItems.clear();
    final ads = authProvider.advertisements;
    if (_videoPosts.isEmpty) return;

    int videoIdx = 0;
    int adIdx = 0;
    bool firstAdInserted = false;

    while (videoIdx < _videoPosts.length) {
      // Première vidéo toujours en premier
      if (videoIdx == 0) {
        _feedItems.add(_videoPosts[videoIdx]);
        videoIdx++;
        continue;
      }

      // Après la première vidéo, insérer une pub (si disponible)
      if (!firstAdInserted && adIdx < ads.length) {
        _feedItems.add(ads[adIdx]);
        adIdx++;
        firstAdInserted = true;
        continue;
      }

      // Ensuite, toutes les 3 vidéos, insérer une pub
      // Compter combien de vidéos on a ajoutées depuis la dernière pub (ou depuis le début)
      int videosSinceLastAd = 0;
      // On va parcourir et ajouter jusqu'à 3 vidéos puis une pub
      for (int i = 0; i < 3 && videoIdx < _videoPosts.length; i++) {
        _feedItems.add(_videoPosts[videoIdx]);
        videoIdx++;
        videosSinceLastAd++;
      }
      // Si on a ajouté des vidéos et qu'il reste des pubs, ajouter une pub
      if (videosSinceLastAd > 0 && adIdx < ads.length && videoIdx < _videoPosts.length) {
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

  Future<void> _initializeVideo(Post post) async {
    _disposeCurrentVideo();
    if (post.url_media == null || post.url_media!.isEmpty) {
      return;
    }
    try {
      _currentVideoController = VideoPlayerController.network(post.url_media!);
      await _currentVideoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _currentVideoController!,
        autoPlay: true,
        looping: false,
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

      _currentVideoController!.addListener(() {
        if (_currentVideoController!.value.isCompleted && !_showScrollHint) {
          setState(() => _showScrollHint = true);
          _scrollHintTimer?.cancel();
          _scrollHintTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _showScrollHint = false);
          });
        }
      });

      setState(() => _isVideoInitialized = true);
      await _recordPostView(post);
      _startSuggestionModalTimer();
    } catch (e) {
      print('❌ Erreur init vidéo: $e');
      setState(() => _isVideoInitialized = false);
    }
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

  Future<void> _markSuggestionsModalSeen() async {
    final userId = authProvider.loginUserData.id;
    await _prefs.setBool('has_seen_suggestions_modal_video_$userId', true);
    setState(() => _hasSeenSuggestionsModal = true);
  }

  void _startSuggestionModalTimer() {
    if (_hasSeenSuggestionsModal) return;
    _suggestionModalTimer?.cancel();
    _suggestionModalTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_hasSeenSuggestionsModal) {
        _showFirstScrollModal();
      }
    });
  }

  void _showFirstScrollModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: _afroDarkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [Icon(Icons.swipe_vertical, color: _afroYellow), SizedBox(width: 8), Text('Glissez pour découvrir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vous pouvez faire défiler vers le haut ou le bas pour voir d’autres vidéos tendance.', style: TextStyle(color: _twitterTextSecondary)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.arrow_upward, color: _afroYellow),
              const SizedBox(width: 8),
              Icon(Icons.arrow_downward, color: _afroYellow),
            ]),
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

  // ==================== INTERACTIONS ====================
  // (Les méthodes _handleLike, _showCommentsModal, _showGiftDialog, _sendGift,
  // _sharePost, _showPostMenu, _deletePost, etc. sont identiques à celles
  // fournies précédemment. Je les inclus intégralement pour que le code soit complet.
  // Pour gagner de la place, je les ai reprises du code fonctionnel original.
  // Vous pouvez les copier depuis la version précédente, elles n'ont pas changé.)

  // Je vais les écrire succinctement mais complètes :

  Future<void> _handleLike(Post post) async {
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

  void _sharePost() async {
    setState(() => _isSharing = true);
    try {
      final shareUrl = widget.initialPost.dataType == PostDataType.VIDEO.name
          ? (widget.initialPost.thumbnail ?? '')
          : (widget.initialPost.images?.isNotEmpty == true ? widget.initialPost.images!.first : '');
      final linkService = AppLinkService();
      await linkService.shareContent(type: AppLinkType.post, id: widget.initialPost.id!, message: widget.initialPost.description ?? '', mediaUrl: shareUrl);
      await _firestore.collection('Posts').doc(widget.initialPost.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
      });
      setState(() {
        widget.initialPost.partage = (widget.initialPost.partage ?? 0) + 1;
        widget.initialPost.users_partage_id!.add(authProvider.loginUserData.id!);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partagé !'), backgroundColor: Colors.green));
    } catch (e) { print('Erreur partage: $e'); } finally { setState(() => _isSharing = false); }
  }

  void _showPostMenu(Post post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _afroDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.user_id != authProvider.loginUserData.id)
              ListTile(leading: const Icon(Icons.flag, color: Colors.white), title: const Text('Signaler', style: TextStyle(color: Colors.white)), onTap: () async { Navigator.pop(context); await postProvider.updateVuePost(post, context); }),
            if (post.user_id == authProvider.loginUserData.id || authProvider.loginUserData.role == UserRole.ADM.name)
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Supprimer', style: TextStyle(color: Colors.red)), onTap: () async { await _deletePost(post, context); Navigator.pop(context); }),
            const Divider(color: Colors.grey),
            ListTile(leading: const Icon(Icons.cancel, color: Colors.white), title: const Text('Annuler', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context)),
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
    if (widget.initialPost.challenge_id == null) return;
    setState(() => _loadingChallenge = true);
    try {
      final doc = await _firestore.collection('Challenges').doc(widget.initialPost.challenge_id).get();
      if (doc.exists) setState(() => _challenge = Challenge.fromJson(doc.data()!)..id = doc.id);
    } catch (e) { print('Erreur chargement challenge: $e'); } finally { setState(() => _loadingChallenge = false); }
  }

  Future<void> _checkIfUserHasVoted() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    final doc = await _firestore.collection('Posts').doc(widget.initialPost.id).get();
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
        transaction.update(_firestore.collection('Posts').doc(widget.initialPost.id), {
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
    final user = post.user;
    final canal = post.canal;
    final isOwner = authProvider.loginUserData.id == post.user_id;
    return Positioned(
      bottom: 120,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canal != null) ...[
            GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal))), child: Text('#${canal.titre}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            Text('${canal.usersSuiviId?.length ?? 0} abonnés', style: const TextStyle(color: Colors.white70)),
          ] else if (user != null) ...[
            GestureDetector(onTap: () => showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context), child: Text('@${user.pseudo}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            Text('${user.userAbonnesIds?.length ?? 0} abonnés', style: const TextStyle(color: Colors.white70)),
          ],
          const SizedBox(height: 4),
          if (post.description != null) Container(constraints: const BoxConstraints(maxWidth: 250), child: Text(post.description!, style: const TextStyle(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
          if (!isOwner) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: _isSupporting ? null : () => _handleSupportAd(post),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _afroDarkGrey.withOpacity(0.8), borderRadius: BorderRadius.circular(20), border: Border.all(color: _afroYellow.withOpacity(0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _isSupporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _afroYellow)) : const Icon(Icons.volunteer_activism, color: _afroYellow, size: 16),
                  const SizedBox(width: 6),
                  const Text('Soutenir le créateur', style: TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Post post) {
    final isLiked = post.users_love_id?.contains(authProvider.loginUserData.id) ?? false;
    return Positioned(
      right: 16,
      bottom: 90,
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              final user = post.user;
              final canal = post.canal;
              if (canal != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal)));
              else if (user != null) showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
            },
            child: Container(decoration: BoxDecoration(border: Border.all(color: _afroGreen, width: 2), shape: BoxShape.circle), child: CircleAvatar(radius: 25, backgroundImage: NetworkImage(post.canal?.urlImage ?? post.user?.imageUrl ?? ''))),
          ),
          const SizedBox(height: 20),
          if (_isLookChallenge) Column(children: [IconButton(icon: Icon(_hasVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined, color: _hasVoted ? _afroGreen : Colors.white, size: 35), onPressed: _voteForLook), Text('${post.votesChallenge ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [IconButton(icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? _afroRed : Colors.white, size: 30), onPressed: () => _handleLike(post)), Text('${post.loves ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 33), onPressed: () => _showCommentsModal(post)), Text('${post.comments ?? 0}', style: const TextStyle(color: Colors.white))]),
          if (post.type != PostType.CHALLENGEPARTICIPATION.name) Column(children: [IconButton(icon: const Icon(Icons.card_giftcard, color: _afroYellow, size: 30), onPressed: () => _showGiftDialog(post)), Text('${post.users_cadeau_id?.length ?? 0}', style: const TextStyle(color: Colors.white))]),
          // Column(children: [IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.white, size: 35), onPressed: () {}), Text('${post.vues ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [IconButton(icon: const Icon(Icons.bar_chart, color: Colors.blue, size: 35), onPressed: () {}), Text('${post.totalInteractions ?? 0}', style: const TextStyle(color: Colors.white))]),
          Column(children: [_isSharing ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: const Icon(Icons.share, color: Colors.white, size: 30), onPressed: _sharePost), Text('${post.partage ?? 0}', style: const TextStyle(color: Colors.white))]),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white, size: 30), onPressed: () => _showPostMenu(post)),
        ],
      ),
    );
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
        _buildVideoPlayer(post),
        _buildUserInfo(post),
        _buildActionButtons(post),
        _buildScrollHint(),
        if (widget.isIn)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.yellow)), const Text('Afrolook', style: TextStyle(color: _afroGreen, fontSize: 24, fontWeight: FontWeight.bold))]),
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
              ? const Center(child: CircularProgressIndicator(color: _afroGreen))
              : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _feedItems.length,
            onPageChanged: (index) async {
              setState(() => _currentPage = index);
              _itemsSinceLastLoad++;
              if (_itemsSinceLastLoad >= 3 && !_maxVideosReached && !_isLoadingMore) {
                _itemsSinceLastLoad = 0;
                await _loadMoreVideos();
              }
              if (index < _feedItems.length && _feedItems[index] is Post) {
                final post = _feedItems[index] as Post;
                _initializeVideo(post);
              }
            },            itemBuilder: (context, index) {
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

