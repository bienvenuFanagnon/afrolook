import 'dart:async';
import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentSerie.dart';
import 'package:afrotok/pages/home/storyCustom/StoryCustom.dart';
import 'package:afrotok/pages/story/afroStory/storie/storyFormChoise.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../userPosts/postWidgets/postWidgetPage.dart';

class UnifiedHomePage extends StatefulWidget {
  const UnifiedHomePage({super.key});

  @override
  State<UnifiedHomePage> createState() => _UnifiedHomePageState();
}

class _UnifiedHomePageState extends State<UnifiedHomePage> {
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;

  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;
  late ContentProvider _contentProvider;

  List<Post> _posts = [];
  List<ContentPaie> _contents = [];
  List<dynamic> _mixedItems = [];

  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasMoreContent = true;

  // Pour stocker le nombre total de documents
  int _totalPostsCount = 1000;
  int _totalContentCount = 0;

  DocumentSnapshot? _lastPostDocument;
  DocumentSnapshot? _lastContentDocument;

  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  Color _color = Colors.blue;

  // Map pour suivre quels posts ont été vus pendant cette session
  final Map<String, bool> _postsViewedInSession = {};
  // Map pour suivre les timers de visibilité
  final Map<String, Timer> _visibilityTimers = {};

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _contentProvider = Provider.of<ContentProvider>(context, listen: false);

    _loadInitialData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Annuler tous les timers en cours
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _visibilityTimers.clear();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        (_hasMorePosts || _hasMoreContent)) {
      _loadMoreData();
    }
  }

  void _changeColor() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.brown,
      Colors.blueAccent,
      Colors.red,
      Colors.yellow,
    ];
    _color = colors[_random.nextInt(colors.length)];
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _postsViewedInSession.clear();
      });

      _lastPostDocument = null;
      _lastContentDocument = null;

      // Charger les comptes totaux et les données initiales
      await Future.wait([
        // migrateSeenByUsersField(),
        // _getTotalPostsCount(),
        // updateAllPostIdsInAppData(),
        _getTotalContentCount(),
        _loadPostsWithStream(isInitialLoad: true),
        _loadContentWithStream(isInitialLoad: true),
      ]);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading initial data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // Obtenir le nombre total de posts
  Future<void> _getTotalPostsCount() async {
    try {
      final query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name);

      final snapshot = await query.count().get();
      _totalPostsCount = snapshot.count!;
      print('_totalPostsCount content count: $_totalPostsCount');

    } catch (e) {
      print('Error getting total posts count: $e');
      _totalPostsCount = 0;
    }
  }

  // Obtenir le nombre total de contenus
  Future<void> _getTotalContentCount() async {
    try {
      final query = FirebaseFirestore.instance.collection('ContentPaies');
      final snapshot = await query.count().get();
      _totalContentCount = snapshot.count!;
      print('_totalContentCount content count: $_totalContentCount');

    } catch (e) {
      print('Error getting total content count: $e');
      _totalContentCount = 0;
    }
  }

  Future<void> _loadPostsWithStream({bool isInitialLoad = false}) async {
    try {
      final currentUserId = _authProvider.loginUserData.id;

      if (isInitialLoad) {
        await _loadUnseenPostsFirst(currentUserId);
      } else {
        await _loadMorePostsByDate(currentUserId);
      }

      _hasMorePosts = _posts.length < _totalPostsCount;
      _createMixedList();

    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _hasMorePosts = false;
      });
    }
  }

  Future<void> _loadUnseenPostsFirst(String? currentUserId) async {
    if (currentUserId == null) {
      await _loadMorePostsByDate(currentUserId);
      return;
    }

    try {
      // 🔹 Étape 1: Récupérer les données nécessaires
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = appData.allPostIds ?? [];
      final viewedPostIds = userData.viewedPostIds ?? [];

      print('🔹 Total posts dans AppData: ${allPostIds.length}');
      print('🔹 Posts vus par l\'utilisateur: ${viewedPostIds.length}');

      // 🔹 Étape 2: Identifier les posts non vus
      final unseenPostIds = allPostIds.where((postId) => !viewedPostIds.contains(postId)).toList();
      print('🔹 Posts non vus identifiés: ${unseenPostIds.length}');

      // 🔹 Étape 3: Charger les posts non vus (équivalent à seen_by_users_map.$currentUserId = null)
      final unseenPosts = await _loadPostsByIds(unseenPostIds, limit: _initialLimit, isSeen: false);
      print('🔹 Posts non vus chargés: ${unseenPosts.length}');

      // 🔹 Étape 4: Compléter avec des posts vus si nécessaire (équivalent à seen_by_users_map.$currentUserId = true)
      if (unseenPosts.length < _initialLimit) {
        final remainingLimit = _initialLimit - unseenPosts.length;
        print('🔹 Complétion avec $remainingLimit posts vus');

        // Les posts vus sont ceux qui sont dans viewedPostIds
        final seenPostsToLoad = viewedPostIds.take(remainingLimit).toList();
        final seenPosts = await _loadPostsByIds(seenPostsToLoad, limit: remainingLimit, isSeen: true);

        _posts = [...unseenPosts, ...seenPosts];
      } else {
        _posts = unseenPosts;
      }

      // 🔹 Étape 5: Mettre à jour le dernier document pour la pagination
      if (_posts.isNotEmpty) {
        // Pour la pagination, nous utilisons le dernier post chargé
        // Nous devons récupérer son document reference depuis Firestore
        final lastPostId = _posts.last.id;
        if (lastPostId != null) {
          final lastDoc = await FirebaseFirestore.instance.collection('Posts').doc(lastPostId).get();
          _lastPostDocument = lastDoc;
        }
      }

      print('✅ Chargement initial terminé. Total posts: ${_posts.length}');
      print('📊 Stats: ${_posts.where((p) => !p.hasBeenSeenByCurrentUser!).length} non vus');

    } catch (e, stack) {
      print('❌ Erreur lors du chargement des posts non vus: $e');
      print(stack);
    }
  }

  Future<void> _loadMorePostsByDate(String? currentUserId) async {
    try {
      if (currentUserId == null) {
        // Pour les utilisateurs non connectés, charger normalement par date
        await _loadMorePostsChronologically();
        return;
      }

      // 🔹 Récupérer les données nécessaires
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = appData.allPostIds ?? [];
      final viewedPostIds = userData.viewedPostIds ?? [];

      // 🔹 Identifier les posts non vus non encore chargés
      final alreadyLoadedPostIds = _posts.map((p) => p.id).toSet();
      final unseenPostIds = allPostIds.where((postId) =>
      !viewedPostIds.contains(postId) && !alreadyLoadedPostIds.contains(postId)).toList();

      print('🔹 Posts non vus restants: ${unseenPostIds.length}');

      // 🔹 Charger les posts non vus suivants
      final unseenPosts = await _loadPostsByIds(unseenPostIds, limit: _loadMoreLimit, isSeen: false);
      print('🔹 Posts non vus supplémentaires chargés: ${unseenPosts.length}');

      // 🔹 Compléter avec des posts vus si nécessaire
      if (unseenPosts.length < _loadMoreLimit) {
        final remainingLimit = _loadMoreLimit - unseenPosts.length;

        // Charger des posts vus non encore chargés
        final seenPostIdsToLoad = viewedPostIds
            .where((postId) => !alreadyLoadedPostIds.contains(postId))
            .take(remainingLimit)
            .toList();

        final seenPosts = await _loadPostsByIds(seenPostIdsToLoad, limit: remainingLimit, isSeen: true);

        _posts.addAll([...unseenPosts, ...seenPosts]);
      } else {
        _posts.addAll(unseenPosts);
      }

      // 🔹 Mettre à jour le dernier document pour la pagination
      if (_posts.isNotEmpty) {
        final lastPostId = _posts.last.id;
        if (lastPostId != null) {
          final lastDoc = await FirebaseFirestore.instance.collection('Posts').doc(lastPostId).get();
          _lastPostDocument = lastDoc;
        }
      }

      print('✅ Chargement supplémentaire terminé. Nouveaux posts: ${unseenPosts.length}');

    } catch (e, stack) {
      print('❌ Erreur chargement supplémentaire des posts: $e');
      print(stack);
    }
  }

// 🔹 Méthode utilitaire pour charger des posts par leurs IDs
  Future<List<Post>> _loadPostsByIds(List<String> postIds, {required int limit, required bool isSeen}) async {
    if (postIds.isEmpty) return [];

    final posts = <Post>[];
    final idsToLoad = postIds.take(limit).toList();

    print('🔹 Chargement de ${idsToLoad.length} posts par ID (isSeen: $isSeen)');

    // Charger par batches de 10 (limite Firebase)
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
            final post = Post.fromJson(doc.data() as Map<String, dynamic>);
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

    return posts;
  }

// 🔹 Méthode de fallback pour le chargement chronologique (utilisateurs non connectés)
  Future<void> _loadMorePostsChronologically() async {
    try {
      Query query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name)
          .orderBy("created_at", descending: true);

      if (_lastPostDocument != null) {
        query = query.startAfterDocument(_lastPostDocument!);
      }

      query = query.limit(_loadMoreLimit);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastPostDocument = snapshot.docs.last;
      }

      final newPosts = <Post>[];

      for (var doc in snapshot.docs) {
        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.hasBeenSeenByCurrentUser = false; // Non connecté = non vu par défaut
          newPosts.add(post);
        } catch (e) {
          print('⚠️ Erreur parsing post (chargement supplémentaire): ${doc.id} -> $e');
        }
      }

      final existingIds = _posts.map((p) => p.id).toSet();
      final uniqueNewPosts = newPosts.where((post) =>
      post.id != null && !existingIds.contains(post.id)).toList();

      _posts.addAll(uniqueNewPosts);

      print('✅ Chargement chronologique terminé: ${uniqueNewPosts.length} nouveaux posts');

    } catch (e, stack) {
      print('❌ Erreur chargement chronologique: $e');
      print(stack);
    }
  }

// 🔹 Méthodes pour récupérer AppData et UserData
  Future<AppDefaultData> _getAppData() async {
    try {
      final appDataRef = FirebaseFirestore.instance.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      final appDataSnapshot = await appDataRef.get();

      if (appDataSnapshot.exists) {
        return AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
      }

      return AppDefaultData(allPostIds: []);
    } catch (e) {
      print('❌ Erreur récupération AppData: $e');
      return AppDefaultData(allPostIds: []);
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
  Future<void> _recordPostView(Post post) async {
    final currentUserId = _authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    try {
      // ✅ Vérifier si déjà vu localement
      if (post.hasBeenSeenByCurrentUser == true ||
          (post.users_vue_id?.contains(currentUserId) ?? false) ||
          (_authProvider.loginUserData.viewedPostIds?.contains(post.id) ?? false)) {
        print("⚠️ Vue déjà comptée pour le post ${post.id}");
        return;
      }

      // 🔹 Mettre à jour UserData.viewedPostIds
      final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);
      await userRef.update({
        'viewedPostIds': FieldValue.arrayUnion([post.id]),
      });

      // 🔹 Mettre à jour le compteur de vues du post (atomic increment)
      final postRef = FirebaseFirestore.instance.collection('Posts').doc(post.id);
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      // 🔹 Mettre à jour localement
      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;

        if (post.users_vue_id == null) {
          post.users_vue_id = [];
        }
        post.users_vue_id!.add(currentUserId);

        if (!_authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
          _authProvider.loginUserData.viewedPostIds!.add(post.id!);
        }
      });

      print('✅ Vue enregistrée pour le post ${post.id}');
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

// 🔹 Méthode pour enregistrer une vue (à utiliser avec VisibilityDetector)
  Future<void> _recordPostView2(Post post) async {
    final currentUserId = _authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    try {
      // 🔹 Mettre à jour UserData.viewedPostIds
      final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);
      await userRef.update({
        'viewedPostIds': FieldValue.arrayUnion([post.id]),
      });

      // 🔹 Mettre à jour le compteur de vues du post
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      // 🔹 Mettre à jour localement
      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id!.add(currentUserId);


        // Mettre à jour l'utilisateur local
        if (!_authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
          _authProvider.loginUserData.viewedPostIds!.add(post.id!);
        }
      });

      print('✅ Vue enregistrée pour le post ${post.id}');

    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }




  Future<void> _loadContentWithStream({bool isInitialLoad = false}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('ContentPaies')
          .orderBy('createdAt', descending: true);

      if (_lastContentDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastContentDocument!);
      }

      query = query.limit(isInitialLoad ? _initialLimit : _loadMoreLimit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastContentDocument = snapshot.docs.last;
      }

      final newContents = snapshot.docs
          .map((doc) => ContentPaie.fromJson({
        ...?doc.data() as Map<String, dynamic>?,
        'id': doc.id,
      }))
          .toList();

      if (isInitialLoad) {
        _contents = newContents;
      } else {
        final existingIds = _contents.map((c) => c.id).toSet();
        final uniqueNewContents = newContents.where((content) => !existingIds.contains(content.id)).toList();
        _contents.addAll(uniqueNewContents);
      }

      // Vérifier s'il reste des contenus à charger basé sur le compte total
      _hasMoreContent = _contents.length < _totalContentCount;
      _createMixedList();

    } catch (e) {
      print('Error loading content: $e');
      setState(() {
        _hasMoreContent = false;
      });
    }
  }

  void _createMixedList() {
    _mixedItems = [];
    int postIndex = 0;
    int contentIndex = 0;
    int cycle = 0;

    while (postIndex < _posts.length && contentIndex < _contents.length) {
      if (cycle % 2 == 0) {
        if (postIndex < _posts.length) {
          _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: _posts[postIndex]));
          postIndex++;
        }

        if (contentIndex < _contents.length) {
          final contentsToAdd = [];
          for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
            contentsToAdd.add(_contents[contentIndex]);
            contentIndex++;
          }
          _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
        }
      } else {
        for (int i = 0; i < 2 && postIndex < _posts.length; i++) {
          _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: _posts[postIndex]));
          postIndex++;
        }

        if (contentIndex < _contents.length) {
          final contentsToAdd = [];
          for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
            contentsToAdd.add(_contents[contentIndex]);
            contentIndex++;
          }
          _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
        }
      }
      cycle++;
    }

    while (postIndex < _posts.length) {
      _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: _posts[postIndex]));
      postIndex++;
    }

    while (contentIndex < _contents.length) {
      final contentsToAdd = [];
      for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
        contentsToAdd.add(_contents[contentIndex]);
        contentIndex++;
      }
      _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
    }

    setState(() {});
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    final shouldLoadMore = _hasMorePosts || _hasMoreContent;
    if (!shouldLoadMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await Future.wait([
        if (_hasMorePosts) _loadPostsWithStream(isInitialLoad: false),
        if (_hasMoreContent) _loadContentWithStream(isInitialLoad: false),
      ]);
    } catch (e) {
      print('Error loading more data: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _posts = [];
      _contents = [];
      _mixedItems = [];
      _isLoading = true;
      _isLoadingMore = false;
      _hasMorePosts = true;
      _hasMoreContent = true;
      _lastPostDocument = null;
      _lastContentDocument = null;
      _totalPostsCount = 1000;
      _totalContentCount = 0;
      _postsViewedInSession.clear();
      _visibilityTimers.forEach((key, timer) => timer.cancel());
      _visibilityTimers.clear();
    });

    await _loadInitialData();
  }

  // Méthode pour enregistrer qu'un post a été vu

  // Gestionnaire de changement de visibilité
  void _handleVisibilityChanged(Post post, VisibilityInfo info) {
    final postId = post.id!;

    // Annuler le timer existant pour ce post
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      // Le post est visible à plus de 50%, démarrer un timer de 500ms
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordPostView(post);
        }
      });
    } else {
      // Le post n'est plus suffisamment visible
      _visibilityTimers.remove(postId);
    }
  }

  // Widget qui encapsule chaque post avec le détecteur de visibilité
  Widget _buildPostWithVisibilityDetection(Post post, double width) {
    final currentUserId = _authProvider.loginUserData.id;
    // final hasUserSeenPost = post.seenByUsersMap?[currentUserId] ?? false;
    final hasUserSeenPost = post.hasBeenSeenByCurrentUser;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: !hasUserSeenPost!
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            HomePostUsersWidget(
              post: post,
              color: _color,
              height: MediaQuery.of(context).size.height * 0.6,
              width: width,
              isDegrade: true,
            ),

            // Badge "Nouveau" pour les posts non vus
            if (!hasUserSeenPost)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_new, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Nouveau',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(dynamic item, _MixedItemType type) {
    if (type == _MixedItemType.post) {
      // S'assurer que la vue est enregistrée avant la navigation
      if (item is Post) {
        _recordPostView(item);
      }
      print('Navigate to post details: ${item.id}');
      // Ici vous pouvez naviguer vers les détails du post
      // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsPage(post: item)));
    } else {
      if (item.isSeries) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(series: item)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContentDetailScreen(content: item)),
        );
      }
    }
  }

  Widget _buildContentGrid(List<ContentPaie> contents, double width) {
    return Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Text(
                "Vidéos virales 🔥",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: contents.length,
              itemBuilder: (context, index) {
                final content = contents[index];
                return _buildContentItem(content, width / 2 - 12);
              },
            ),
          ],)
    );
  }

  Widget _buildContentItem(ContentPaie content, double itemWidth) {
    return GestureDetector(
      onTap: () => _navigateToDetails(content, _MixedItemType.content),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: content.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(child: CircularProgressIndicator(color: Colors.green)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    )
                        : Center(child: Icon(Icons.videocam, color: Colors.grey[600], size: 30)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.red, size: 40),
                        SizedBox(height: 4),
                        Text(
                          "Voir",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        if (!content.isFree)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${content.price} F',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        SizedBox(width: 4),
                        if (content.isSeries)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.playlist_play, color: Colors.blue, size: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        content.isSeries ? 'Série' : 'Film',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      if (content.views != null && content.views! > 0)
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              content.views!.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    _changeColor();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Text(
          'Découvrir',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerEffect()
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text('Réessayer'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = _mixedItems[index];
                  if (item.type == _MixedItemType.post) {
                    return GestureDetector(
                      onTap: () => _navigateToDetails(item.data, _MixedItemType.post),
                      child: _buildPostWithVisibilityDetection(item.data, width),
                    );
                  } else if (item.type == _MixedItemType.contentGrid) {
                    return _buildContentGrid(
                      (item.data as List<dynamic>).map((e) => e as ContentPaie).toList(),
                      width,
                    );
                  }
                  return SizedBox.shrink();
                },
                childCount: _mixedItems.length,
              ),
            ),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                ),
              ),
            if (!_hasMorePosts && !_hasMoreContent && _mixedItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Vous avez vu tous les contenus',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MixedItemType { post, content, contentGrid }

class _MixedItem {
  final _MixedItemType type;
  final dynamic data;

  _MixedItem({required this.type, required this.data});
}