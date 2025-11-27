import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../chronique/chroniqueform.dart';

class HomeDataService {
  // Providers
  final UserAuthProvider authProvider;
  final PostProvider postProvider;
  final ContentProvider contentProvider;
  final CategorieProduitProvider categorieProvider;
  final ChroniqueProvider chroniqueProvider;

  // Données
  List<Post> _posts = [];
  List<ContentPaie> _contents = [];
  List<MixedItem> _mixedItems = [];
  List<Chronique> _activeChroniques = [];
  Map<String, List<Chronique>> _groupedChroniques = {};
  List<ArticleData> _articles = [];
  List<Canal> _canaux = [];

  // État
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasMoreContent = true;
  bool _isLoadingChroniques = false;

  // Cache et utilitaires
  final Map<String, String> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};
  final Map<String, Timer> _visibilityTimers = {};
  final Map<String, bool> _postsViewedInSession = {};

  // Pagination
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;
  DocumentSnapshot? _lastContentDocument;
  int _totalContentCount = 0;

  HomeDataService({
    required this.authProvider,
    required this.postProvider,
    required this.contentProvider,
    required this.categorieProvider,
    required this.chroniqueProvider,
  });

  // Getters pour l'état
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _hasMorePosts || _hasMoreContent;
  bool get isLoadingChroniques => _isLoadingChroniques;
  bool get shouldShowChroniques => _groupedChroniques.isNotEmpty || _isLoadingChroniques;
  bool get showNoMoreContent => !_hasMorePosts && !_hasMoreContent && _mixedItems.isNotEmpty;

  // Getters pour les données
  List<MixedItem> get mixedItems => _mixedItems;
  List<ArticleData> get articles => _articles;
  List<Canal> get canaux => _canaux;
  Map<String, String> get videoThumbnails => _videoThumbnails;
  Map<String, bool> get userVerificationStatus => _userVerificationStatus;
  Map<String, UserData> get userDataCache => _userDataCache;
  Map<String, List<Chronique>> get groupedChroniques => _groupedChroniques;

  // Setters pour l'état
  void setLoading(bool loading) => _isLoading = loading;
  void setError(bool error) => _hasError = error;
  void setLoadingMore(bool loadingMore) => _isLoadingMore = loadingMore;

  Future<void> loadInitialData() async {
    await Future.wait([
      _loadAdditionalData(),
      _loadPostsWithStream(isInitialLoad: true),
      _loadActiveChroniques(),
    ]);
    _createMixedList();
  }

  Future<void> refreshData() async {
    resetState();
    await loadInitialData();
  }

  Future<void> loadMoreData() async {
    await _loadPostsWithStream(isInitialLoad: false);
    _createMixedList();
  }

  void resetState() {
    _posts = [];
    _contents = [];
    _mixedItems = [];
    _isLoading = true;
    _isLoadingMore = false;
    _hasMorePosts = true;
    _hasMoreContent = true;
    _lastContentDocument = null;
    _totalContentCount = 0;
    _postsViewedInSession.clear();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _visibilityTimers.clear();
  }

  Future<void> _loadAdditionalData() async {
    try {
      final articleResults = await categorieProvider.getArticleBooster(
          authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');
      final canalResults = await postProvider.getCanauxHome();

      _articles = articleResults;
      _canaux = canalResults;
      _articles.shuffle();
      _canaux.shuffle();
    } catch (e) {
      print('Error loading additional data: $e');
    }
  }

  Future<void> _loadActiveChroniques() async {
    if (_isLoadingChroniques) return;

    _isLoadingChroniques = true;

    try {
      final chroniques = await chroniqueProvider.getActiveChroniques().first;

      final Map<String, List<Chronique>> grouped = {};
      for (var chronique in chroniques) {
        if (!grouped.containsKey(chronique.userId)) {
          grouped[chronique.userId] = [];
        }
        grouped[chronique.userId]!.add(chronique);
      }

      grouped.forEach((userId, userChroniques) {
        userChroniques.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

      await _loadVideoThumbnails(chroniques);
      await _loadUserVerificationStatus(grouped.keys.toList());

      _groupedChroniques = grouped;
      _activeChroniques = chroniques;
      _isLoadingChroniques = false;
    } catch (e) {
      print('Erreur chargement chroniques: $e');
      _isLoadingChroniques = false;
    }
  }

  Future<void> _loadVideoThumbnails(List<Chronique> chroniques) async {
    for (var chronique in chroniques) {
      if (chronique.type == ChroniqueType.VIDEO && chronique.mediaUrl != null) {
        try {
          final thumbnail = await VideoThumbnail.thumbnailFile(
            video: chronique.mediaUrl!,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200,
            quality: 50,
            timeMs: 2000,
          );
          if (thumbnail != null) {
            _videoThumbnails[chronique.id!] = thumbnail;
          }
        } catch (e) {
          print('Erreur génération thumbnail: $e');
        }
      }
    }
  }

  Future<void> _loadUserVerificationStatus(List<String> userIds) async {
    for (var userId in userIds) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          _userDataCache[userId] = userData;
          _userVerificationStatus[userId] = userData.isVerify ?? false;
        }
      } catch (e) {
        print('Erreur chargement statut vérification: $e');
      }
    }
  }

  Future<void> _loadPostsWithStream({bool isInitialLoad = false}) async {
    try {
      final currentUserId = authProvider.loginUserData.id;

      if (isInitialLoad) {
        await _loadUnseenPostsFirst(currentUserId);
      } else {
        await _loadMoreUnseenPosts(currentUserId);
      }
    } catch (e) {
      print('Error loading posts: $e');
      _hasMorePosts = false;
    }
  }

  Future<void> _loadUnseenPostsFirst(String? currentUserId) async {
    if (currentUserId == null) {
      await _loadMorePostsChronologically();
      return;
    }

    try {
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = (appData.allPostIds ?? []).reversed.toList();
      final viewedPostIds = userData.viewedPostIds ?? [];

      final unseenPostIds = allPostIds
          .where((postId) => !viewedPostIds.contains(postId))
          .toList();

      if (unseenPostIds.isEmpty) {
        _hasMorePosts = false;
        return;
      }

      final orderedUnseenIds = List<String>.from(unseenPostIds);
      final idsToLoad = orderedUnseenIds.take(_initialLimit).toList();

      final unseenPosts = await _loadPostsByIds(
          idsToLoad,
          limit: _initialLimit,
          isSeen: false
      );

      unseenPosts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      _posts = unseenPosts;
      _hasMorePosts = true;

    } catch (e, stack) {
      print('❌ Erreur lors du chargement des posts non vus: $e');
      print(stack);
      await _loadMorePostsChronologically();
    }
  }

  Future<void> _loadMoreUnseenPosts(String? currentUserId) async {
    try {
      if (currentUserId == null) {
        await _loadMorePostsChronologically();
        return;
      }

      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = (appData.allPostIds ?? []).reversed.toList();
      final viewedPostIds = userData.viewedPostIds ?? [];

      final alreadyLoadedPostIds = _posts.map((p) => p.id).where((id) => id != null).cast<String>().toSet();
      final unseenPostIds = allPostIds.where((postId) =>
      !viewedPostIds.contains(postId) &&
          !alreadyLoadedPostIds.contains(postId)
      ).toList();

      List<Post> newPosts = [];

      if (unseenPostIds.isNotEmpty) {
        final idsToLoad = unseenPostIds.take(_loadMoreLimit).toList();
        newPosts = await _loadPostsByIds(idsToLoad, limit: _loadMoreLimit, isSeen: false);
        _posts.addAll(newPosts);
        _hasMorePosts = true;
      } else {
        _hasMorePosts = false;
      }

    } catch (e, stack) {
      print('❌ Erreur chargement supplémentaire des posts: $e');
      print(stack);
    }
  }

  Future<List<Post>> _loadPostsByIds(List<String> postIds, {required int limit, required bool isSeen}) async {
    if (postIds.isEmpty) return [];

    final posts = <Post>[];
    final idsToLoad = postIds.take(limit).toList();

    for (var i = 0; i < idsToLoad.length; i += 10) {
      final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();

      if (batchIds.isEmpty) continue;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromJson(doc.data());
            post.id = doc.id;
            post.hasBeenSeenByCurrentUser = isSeen;
            posts.add(post);
          } catch (e) {
            print('⚠️ Erreur parsing post ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('❌ Erreur batch chargement posts: $e');
      }
    }

    posts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return posts;
  }

  Future<void> _loadMorePostsChronologically() async {
    try {
      Query query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name)
          .orderBy("created_at", descending: true)
          .limit(_loadMoreLimit);

      final snapshot = await query.get();

      final newPosts = <Post>[];

      for (var doc in snapshot.docs) {
        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.hasBeenSeenByCurrentUser = false;
          newPosts.add(post);
        } catch (e) {
          print('⚠️ Erreur parsing post (chargement supplémentaire): ${doc.id} -> $e');
        }
      }

      final existingIds = _posts.map((p) => p.id).toSet();
      final uniqueNewPosts = newPosts.where((post) =>
      post.id != null && !existingIds.contains(post.id)).toList();

      _posts.addAll(uniqueNewPosts);

    } catch (e, stack) {
      print('❌ Erreur chargement chronologique: $e');
      print(stack);
    }
  }

  void _createMixedList() {
    _mixedItems = [];

    int postIndex = 0;
    int contentIndex = 0;
    int boosterIndex = 0;
    int canalIndex = 0;

    final random = Random();
    int postsSinceLastInsertion = 0;
    bool nextInsertionIsBooster = true;
    bool lastWasContentGrid = false;

    String? lastUserId;
    List<Post> availablePosts = List.from(_posts);
    List<Post> usedPosts = [];

    int maxIterations = (_posts.length + _contents.length) * 2;
    int currentIteration = 0;

    while ((availablePosts.isNotEmpty || contentIndex < _contents.length) &&
        currentIteration < maxIterations) {

      currentIteration++;

      if (postsSinceLastInsertion >= 2 + random.nextInt(3) && !lastWasContentGrid) {
        if (nextInsertionIsBooster && boosterIndex < _articles.length) {
          final nextBoosters = _getNextBoosters(refIndex: boosterIndex);
          if (nextBoosters.isNotEmpty) {
            _mixedItems.add(MixedItem(
                type: MixedItemType.booster,
                data: nextBoosters
            ));
            boosterIndex += nextBoosters.length;
            nextInsertionIsBooster = false;
            lastWasContentGrid = false;
            postsSinceLastInsertion = 0;
            continue;
          }
        } else if (!nextInsertionIsBooster && canalIndex < _canaux.length) {
          final nextCanaux = _getNextCanaux(refIndex: canalIndex);
          if (nextCanaux.isNotEmpty) {
            _mixedItems.add(MixedItem(
                type: MixedItemType.canal,
                data: nextCanaux
            ));
            canalIndex += nextCanaux.length;
            nextInsertionIsBooster = true;
            lastWasContentGrid = false;
            postsSinceLastInsertion = 0;
            continue;
          }
        }
      }

      if (availablePosts.isNotEmpty) {
        Post? nextPost;
        int foundIndex = -1;

        for (int i = 0; i < availablePosts.length; i++) {
          if (availablePosts[i].user_id != lastUserId) {
            nextPost = availablePosts[i];
            foundIndex = i;
            break;
          }
        }

        if (nextPost == null && availablePosts.isNotEmpty) {
          nextPost = availablePosts.first;
          foundIndex = 0;
        }

        if (nextPost != null && foundIndex != -1) {
          _mixedItems.add(MixedItem(type: MixedItemType.post, data: nextPost));
          usedPosts.add(nextPost);
          availablePosts.removeAt(foundIndex);
          lastUserId = nextPost.user_id;
          postsSinceLastInsertion++;
          lastWasContentGrid = false;
        }
      }
      else if (contentIndex < _contents.length && !lastWasContentGrid) {
        final contentsToAdd = [];
        for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
          contentsToAdd.add(_contents[contentIndex]);
          contentIndex++;
        }
        if (contentsToAdd.isNotEmpty) {
          _mixedItems.add(MixedItem(type: MixedItemType.contentGrid, data: contentsToAdd));
          lastWasContentGrid = true;
          postsSinceLastInsertion = 0;
          lastUserId = null;
        }
      }
      else {
        break;
      }
    }

    if (boosterIndex < _articles.length) {
      final remainingBoosters = _getRemainingBoosters(refIndex: boosterIndex);
      if (remainingBoosters.isNotEmpty) {
        _mixedItems.add(MixedItem(
            type: MixedItemType.booster,
            data: remainingBoosters
        ));
      }
    }

    if (canalIndex < _canaux.length) {
      final remainingCanaux = _getRemainingCanaux(refIndex: canalIndex);
      if (remainingCanaux.isNotEmpty) {
        _mixedItems.add(MixedItem(
            type: MixedItemType.canal,
            data: remainingCanaux
        ));
      }
    }
  }

  List<ArticleData> _getNextBoosters({required int refIndex}) {
    if (_articles.isEmpty || refIndex >= _articles.length) return [];
    final endIndex = refIndex + 3 <= _articles.length ? refIndex + 3 : _articles.length;
    return _articles.sublist(refIndex, endIndex);
  }

  List<Canal> _getNextCanaux({required int refIndex}) {
    if (_canaux.isEmpty || refIndex >= _canaux.length) return [];
    final endIndex = refIndex + 3 <= _canaux.length ? refIndex + 3 : _canaux.length;
    return _canaux.sublist(refIndex, endIndex);
  }

  List<ArticleData> _getRemainingBoosters({required int refIndex}) {
    if (_articles.isEmpty || refIndex >= _articles.length) return [];
    return _articles.sublist(refIndex);
  }

  List<Canal> _getRemainingCanaux({required int refIndex}) {
    if (_canaux.isEmpty || refIndex >= _canaux.length) return [];
    return _canaux.sublist(refIndex);
  }

  Future<AppDefaultData> _getAppData() async {
    try {
      final appDataRef = FirebaseFirestore.instance.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      final appDataSnapshot = await appDataRef.get();

      if (appDataSnapshot.exists) {
        return AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
      }

      return AppDefaultData();
    } catch (e) {
      print('❌ Erreur récupération AppData: $e');
      return AppDefaultData();
    }
  }

  Future<UserData> _getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        return UserData.fromJson(userDoc.data() as Map<String, dynamic>);
      }

      return UserData(viewedPostIds: []);
    } catch (e) {
      print('❌ Erreur récupération UserData: $e');
      return UserData(viewedPostIds: []);
    }
  }

  Future<void> recordPostView(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    try {
      if ((authProvider.loginUserData.viewedPostIds?.contains(post.id) ?? false)) {
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);

      final currentViewedIds = authProvider.loginUserData.viewedPostIds ?? [];
      final willReachLimit = currentViewedIds.length >= 999;

      if (willReachLimit) {
        await userRef.update({
          'viewedPostIds': [post.id],
        });
        authProvider.loginUserData.viewedPostIds = [post.id!];
      } else {
        await userRef.update({
          'viewedPostIds': FieldValue.arrayUnion([post.id]),
        });

        if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
          authProvider.loginUserData.viewedPostIds!.add(post.id!);
        }
      }

      final postRef = FirebaseFirestore.instance.collection('Posts').doc(post.id);
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      post.hasBeenSeenByCurrentUser = true;
      post.vues = (post.vues ?? 0) + 1;

      if (post.users_vue_id == null) {
        post.users_vue_id = [];
      }
      post.users_vue_id!.add(currentUserId);

    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  void handlePostVisibility(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
        if (info.visibleFraction > 0.5) {
          recordPostView(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }

  void dispose() {
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _visibilityTimers.clear();
  }
}

enum MixedItemType { post, content, contentGrid, booster, canal }

class MixedItem {
  final MixedItemType type;
  final dynamic data;

  MixedItem({required this.type, required this.data});
}