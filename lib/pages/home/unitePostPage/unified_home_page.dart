import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/postService/local_viewed_posts_service.dart';
import '../../../services/postService/mixed_feed_service.dart';
import '../../chronique/chroniqueform.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';
import 'chronique_section.dart';
import 'home_components/loading_components.dart';
import 'home_components/special_sections_component.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/mixed_feed_service_provider.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/postService/local_viewed_posts_service.dart';
import '../../../services/postService/mixed_feed_service.dart';
import '../../chronique/chroniqueform.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';
import 'chronique_section.dart';
import 'home_components/loading_components.dart';
import 'home_components/special_sections_component.dart';

class UnifiedHomeOptimized extends StatefulWidget {
  const UnifiedHomeOptimized({super.key});

  @override
  State<UnifiedHomeOptimized> createState() => _UnifiedHomeOptimizedState();
}

class _UnifiedHomeOptimizedState extends State<UnifiedHomeOptimized> {
  final ScrollController _scrollController = ScrollController();

  // 🔥 VARIABLES SIMPLIFIÉES
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  int _currentIndex = 0;
  int _userLastVisitTime = 0;
  bool _isRefreshing = false;

  // 🔥 GESTION VISIBILITÉ
  final Map<String, Timer> _visibilityTimers = {};

  // 🔥 VARIABLES POUR LES CHRONIQUES
  final Map<String, String> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};
  bool _isLoadingChroniques = false;
  Map<String, List<Chronique>> _groupedChroniques = {};

  @override
  void initState() {
    super.initState();
    _initializePage();
    _scrollController.addListener(_scrollListener);
  }

  // 🔥 INITIALISATION SIMPLIFIÉE AVEC LE PROVIDER
  Future<void> _initializePage() async {
    final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

    try {
      print('🎯 UnifiedHomeOptimized - Initialisation avec le provider...');

      // 🔥 CHARGER LE TEMPS DE DERNIÈRE VISITE
      await _loadUserLastVisitTime();

      if (mixedFeedProvider.isPrepared) {
        print('✅ Service déjà préparé avec ${mixedFeedProvider.preparedPostsCount} posts');
        // Charger directement le contenu global
        await mixedFeedProvider.loadGlobalContent();
        await _loadInitialContent();
      } else {
        print('🔄 Service non préparé - préparation rapide...');
        await mixedFeedProvider.preparePosts();
        await mixedFeedProvider.loadGlobalContent();
        await _loadInitialContent();
      }

    } catch (e) {
      print('❌ Erreur initialisation page: $e');
      setState(() => _hasError = true);
    }
  }

  // 🔥 CHARGEMENT DU TEMPS DE DERNIÈRE VISITE
  Future<void> _loadUserLastVisitTime() async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUser = authProvider.loginUserData;

      if (currentUser.lastFeedVisitTime != null) {
        _userLastVisitTime = currentUser.lastFeedVisitTime!;
      } else {
        _userLastVisitTime = DateTime.now().microsecondsSinceEpoch - Duration(hours: 1).inMicroseconds;
      }

      print('👤 Dernière visite: ${DateTime.fromMicrosecondsSinceEpoch(_userLastVisitTime)}');

    } catch (e) {
      print('❌ Erreur chargement dernière visite: $e');
      _userLastVisitTime = DateTime.now().microsecondsSinceEpoch - Duration(hours: 1).inMicroseconds;
    }
  }

  // 🔥 METTRE À JOUR LE TEMPS DE DERNIÈRE VISITE
  Future<void> _updateLastVisitTime() async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final currentUserId = authProvider.loginUserData.id;

      if (currentUserId != null) {
        final now = DateTime.now().microsecondsSinceEpoch;
        await FirebaseFirestore.instance.collection('Users').doc(currentUserId).update({
          'lastFeedVisitTime': now,
        });

        authProvider.loginUserData.lastFeedVisitTime = now;
        _userLastVisitTime = now;

        print('🕐 Temps de visite mis à jour');
      }
    } catch (e) {
      print('❌ Erreur mise à jour temps visite: $e');
    }
  }

  // 🔥 CHARGEMENT INITIAL ULTRA RAPIDE
  Future<void> _loadInitialContent() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

      print('🚀 Chargement rapide depuis le provider...');

      // 🔥 AFFICHER LE DERNIER POST VU AU DÉMARRAGE
      final lastSeenPost = await LocalViewedPostsService.getLastSeenPost();
      final viewedPosts = await LocalViewedPostsService.getViewedPosts();
      print('''
🚀 DÉMARRAGE APPLICATION:
   - Dernier post vu: $lastSeenPost
   - Posts déjà vus: ${viewedPosts.length}
   - Provider prêt: ${mixedFeedProvider.isPrepared}
   - Posts préparés: ${mixedFeedProvider.preparedPostsCount}
''');

      // 🔥 CHARGEMENT DIRECT
      await mixedFeedProvider.loadMixedContent(loadMore: false);

      print('✅ Contenu chargé: ${mixedFeedProvider.mixedContent.length} éléments');

      await _updateLastVisitTime();

    } catch (e) {
      print('❌ Erreur chargement initial: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 CHARGEMENT SUPPLÉMENTAIRE SIMPLIFIÉ
  Future<void> _loadMoreContent() async {
    if (_isLoadingMore) return;

    final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);
    if (!mixedFeedProvider.hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      await mixedFeedProvider.loadMixedContent(loadMore: true);
      print('📥 Chargement supplémentaire terminé');
    } catch (e) {
      print('❌ Erreur chargement supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // 🔥 REFRESH COMPLET
  Future<void> _refreshData() async {
    print('🔄 Refresh manuel...');

    if (_isLoading || _isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _hasError = false;
    });

    try {
      final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

      await mixedFeedProvider.reset();
      await mixedFeedProvider.preparePosts();
      await mixedFeedProvider.loadGlobalContent();
      await _loadInitialContent();

      print('🆕 Refresh terminé');

    } catch (e) {
      print('❌ Erreur refresh: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMoreContent();
    }
  }

  // 🔥 CONSTRUCTION DES SECTIONS DE CONTENU
  Widget _buildContentSection(ContentSection section) {
    print('🎨 Construction section: ${section.type}');

    switch (section.type) {
      case ContentMixtType.POST:
        final post = section.data as Post;
        print('   📝 Post: ${post.id} - ${post.type}');
        return _buildPostItem(post);

      case ContentMixtType.CHRONIQUES:
        final chroniques = section.data as List<Chronique>;
        print('   📺 Chroniques: ${chroniques.length} éléments');
        return _buildChroniquesSection(chroniques);

      case ContentMixtType.ARTICLES:
        final articles = section.data as List<ArticleData>;
        print('   📰 Articles: ${articles.length} éléments');
        return _buildArticlesSection(articles);

      case ContentMixtType.CANAUX:
        final canaux = section.data as List<Canal>;
        print('   🎙️ Canaux: ${canaux.length} éléments');
        return _buildCanauxSection(canaux);

      default:
        print('   ❌ Type inconnu: ${section.type}');
        return SizedBox.shrink();
    }
  }

  // 🔥 SECTION CHRONIQUES
  Widget _buildChroniquesSection(List<Chronique> chroniques) {
    // Charger les données si nécessaire
    if (!_isLoadingChroniques && _groupedChroniques.isEmpty && chroniques.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChroniqueData(chroniques);
      });
    }

    return ChroniqueSectionComponent(
      videoThumbnails: _videoThumbnails,
      userVerificationStatus: _userVerificationStatus,
      userDataCache: _userDataCache,
      isLoadingChroniques: _isLoadingChroniques,
      groupedChroniques: _groupedChroniques,
    );
  }

  // 🔥 SECTION ARTICLES
  Widget _buildArticlesSection(List<ArticleData> articles) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SpecialSectionsComponent.buildBoosterSection(
      articles: articles,
      context: context,
      width: width,
      height: height,
    );
  }

  // 🔥 SECTION CANAUX
  Widget _buildCanauxSection(List<Canal> canaux) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return SpecialSectionsComponent.buildCanalSection(
      canaux: canaux,
      context: context,
      width: width,
      height: height,
    );
  }

  // 🔥 WIDGET POST INDIVIDUEL
  Widget _buildPostItem(Post post) {
    final screenHeight = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    final isNewForUser = post.createdAt != null &&
        post.createdAt! > _userLastVisitTime;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (info) => _handlePostVisibility(post, info),
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
          border: isNewForUser ? Border.all(color: Colors.green, width: 2) : null,
        ),
        child: Stack(
          children: [
            post.type == PostType.CHALLENGEPARTICIPATION.name
                ? LookChallengePostWidget(
              post: post,
              height: screenHeight,
              width: width,
              onLiked: () => _onPostLiked(post),
              onCommented: () => _onPostCommented(post),
              onShared: () => _onPostShared(post),
              onLoved: () => _onPostLoved(post),
            )
                : HomePostUsersWidget(
              post: post,
              color: Colors.blue,
              height: screenHeight * 0.6,
              width: width,
              isDegrade: true,
              onLiked: () => _onPostLiked(post),
              onCommented: () => _onPostCommented(post),
              onShared: () => _onPostShared(post),
              onLoved: () => _onPostLoved(post),
            ),

            if (isNewForUser)
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

            if (post.createdAt != null)
              Positioned(
                bottom: 5,
                left: 5,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_formatPostDate(post.createdAt!)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 🔥 MARQUER UN POST COMME VU
  void _handlePostVisibility(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.8) {
      _visibilityTimers[postId] = Timer(Duration(seconds: 2), () {
        if (mounted && info.visibleFraction > 0.7) {
          print('✅ Post VU: $postId (regardé pendant 2 secondes)');
          _markPostAsSeen(post);
        } else {
          print('❌ Marquage annulé: $postId pas regardé assez longtemps');
        }
      });
    } else if (info.visibleFraction < 0.3) {
      _visibilityTimers.remove(postId);
    }
  }

  Future<void> _markPostAsSeen(Post post) async {
    final currentUserId = _getUserId();
    if (currentUserId.isEmpty || post.id == null) return;

    try {
      print('👁️ Marquage post comme vu: ${post.id}');

      // 🔥 SAUVEGARDE LOCALE
      await LocalViewedPostsService.markPostAsViewedAndUpdateLast(post.id!);

      // 🔥 MARQUAGE DANS FIRESTORE VIA LE SERVICE DU PROVIDER
      final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);
      if (mixedFeedProvider.mixedFeedService != null) {
        await mixedFeedProvider.mixedFeedService!.markPostAsSeen(post.id!);
      }

      if (mounted) {
        setState(() {
          post.vues = (post.vues ?? 0) + 1;
          post.users_vue_id ??= [];
          if (!post.users_vue_id!.contains(currentUserId)) {
            post.users_vue_id!.add(currentUserId);
          }
        });
      }

      // 🔥 DEBUG
      final lastSeen = await LocalViewedPostsService.getLastSeenPost();
      final viewedCount = await LocalViewedPostsService.getViewedPosts();
      print('''
📍 STATUT POSTS VUS:
   - Dernier post vu: $lastSeen
   - Total posts vus: ${viewedCount.length}
   - Post actuel: ${post.id}
''');

    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  // 🔥 MÉTHODES POUR LES CHRONIQUES
  Future<void> _loadChroniqueData(List<Chronique> chroniques) async {
    if (_isLoadingChroniques) return;

    setState(() => _isLoadingChroniques = true);

    try {
      _groupedChroniques = _groupChroniquesByUser(chroniques);
      await _loadUserVerificationStatus(chroniques);
      await _loadUserData(chroniques);
      await _generateVideoThumbnails(chroniques);

      print('✅ Données chroniques chargées: ${chroniques.length} éléments');

    } catch (e) {
      print('❌ Erreur chargement données chroniques: $e');
    } finally {
      setState(() => _isLoadingChroniques = false);
    }
  }

  Future<void> _loadUserVerificationStatus(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques.map((c) => c.userId).toSet();

      for (final userId in userIds) {
        if (!_userVerificationStatus.containsKey(userId)) {
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
          final isVerified = userDoc.data()?['isVerify'] ?? false;
          _userVerificationStatus[userId] = isVerified;
        }
      }
    } catch (e) {
      print('❌ Erreur chargement statut vérification: $e');
    }
  }

  Future<void> _loadUserData(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques.map((c) => c.userId).toSet();

      for (final userId in userIds) {
        if (!_userDataCache.containsKey(userId)) {
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final userData = UserData.fromJson(userDoc.data()!);
            _userDataCache[userId] = userData;
          }
        }
      }
    } catch (e) {
      print('❌ Erreur chargement données utilisateurs: $e');
    }
  }

  Future<void> _generateVideoThumbnails(List<Chronique> chroniques) async {
    try {
      final videoChroniques = chroniques.where((c) => c.type == ChroniqueType.VIDEO);

      for (final chronique in videoChroniques) {
        if (chronique.mediaUrl != null && !_videoThumbnails.containsKey(chronique.id)) {
          _videoThumbnails[chronique.id!] = chronique.mediaUrl!;

          // Tu pourras ajouter video_thumbnail plus tard si nécessaire

          final thumbnailPath = await VideoThumbnail.thumbnailFile(
            video: chronique.mediaUrl!,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            quality: 50,
            timeMs: 2000,
          );
          if (thumbnailPath != null) {
            _videoThumbnails[chronique.id!] = thumbnailPath;
          }

        }
      }
    } catch (e) {
      print('❌ Erreur génération thumbnails: $e');
    }
  }

  Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
    final grouped = <String, List<Chronique>>{};
    for (final chronique in chroniques) {
      grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
    }
    return grouped;
  }

  // 🔥 BODY SIMPLIFIÉ AVEC CONSUMER
  Widget _buildBody(double width, double height) {
    return Consumer<MixedFeedServiceProvider>(
      builder: (context, provider, child) {
        final content = provider.mixedContent;

        print('🎯 Build avec ${content.length} éléments (préparés: ${provider.preparedPostsCount})');

        if (_isLoading && content.isEmpty) {
          return LoadingComponents.buildShimmerEffect();
        }

        if (_hasError && content.isEmpty) {
          return _buildErrorWidget();
        }

        if (content.isEmpty && !_isLoading) {
          return _buildEmptyState();
        }

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshData,
              backgroundColor: Colors.black,
              color: Colors.white,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        if (index == content.length) {
                          return _buildLoadingMore();
                        }
                        final section = content[index] as ContentSection;
                        return _buildContentSection(section);
                      },
                      childCount: content.length + (provider.hasMore ? 1 : 0),
                    ),
                  ),

                  if (!provider.hasMore && content.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildEndOfFeed(),
                    ),
                ],
              ),
            ),

            if (_isRefreshing)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  color: Colors.black.withOpacity(0.8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Actualisation...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // 🔥 WIDGETS D'ÉTAT
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          SizedBox(height: 20),
          Text(
            'Erreur de chargement',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 10),
          Text(
            'Impossible de charger le contenu',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadInitialContent,
            icon: Icon(Icons.refresh),
            label: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, color: Colors.grey, size: 64),
          SizedBox(height: 20),
          Text(
            'Aucun contenu disponible',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 10),
          Text(
            'Le chargement semble avoir échoué',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Recommencer'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    if (!_isLoadingMore) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text(
              'Chargement de plus de contenu...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfFeed() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.flag, color: Colors.green, size: 40),
            SizedBox(height: 10),
            Text(
              'Vous avez vu tous les contenus pour le moment',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              'Revenez plus tard pour découvrir de nouveaux posts',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 MÉTHODES UTILITAIRES
  String _formatPostDate(int microSinceEpoch) {
    try {
      final date = DateTime.fromMicrosecondsSinceEpoch(microSinceEpoch);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'À l\'instant';
      if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes}min';
      if (difference.inHours < 24) return 'Il y a ${difference.inHours}h';
      if (difference.inDays < 7) return 'Il y a ${difference.inDays}j';

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  String _getUserId() {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.loginUserData.id ?? '';
  }

  void _onPostLiked(Post post) {
    FeedInteractionService.onPostLiked(post, _getUserId());
  }

  void _onPostCommented(Post post) {
    FeedInteractionService.onPostCommented(post, _getUserId());
  }

  void _onPostShared(Post post) {
    FeedInteractionService.onPostShared(post, _getUserId());
  }

  void _onPostLoved(Post post) {
    FeedInteractionService.onPostLoved(post, _getUserId());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _visibilityTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Text(
          'Découvrir 🚀',
          style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _isRefreshing ? null : _refreshData,
                tooltip: 'Rafraîchir',
              ),
              if (_isRefreshing)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'reset') {
                Provider.of<MixedFeedServiceProvider>(context, listen: false).reset();
                _refreshData();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'reset',
                child: Text('Réinitialiser le feed'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(width, height),
    );
  }
}
// 🔥 ENUM POUR LES TYPES DE CONTENU
