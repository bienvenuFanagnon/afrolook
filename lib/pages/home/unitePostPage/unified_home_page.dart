import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/postService/mixed_feed_service.dart';
import '../../chronique/chroniqueform.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';
import 'chronique_section.dart';
import 'home_components/content_grid_component.dart';
import 'home_components/loading_components.dart';
import 'home_components/special_sections_component.dart';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/chroniqueProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';

import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/postService/mixed_feed_service.dart';
import 'chronique_section.dart';
import 'home_components/loading_components.dart';
import 'home_components/special_sections_component.dart';

class UnifiedHomeOptimized extends StatefulWidget {
  const UnifiedHomeOptimized({super.key});

  @override
  State<UnifiedHomeOptimized> createState() => _UnifiedHomeOptimizedState();
}

class _UnifiedHomeOptimizedState extends State<UnifiedHomeOptimized> {
  late MixedFeedService _feedService;
  final ScrollController _scrollController = ScrollController();

  // 🔥 ÉTAT AMÉLIORÉ
  List<Post> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  int _userLastVisitTime = 0;
  bool _isRefreshing = false;

  // 🔥 GESTION VISIBILITÉ
  final Map<String, Timer> _visibilityTimers = {};

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _scrollController.addListener(_scrollListener);
  }

  // 🔥 INITIALISATION OPTIMISÉE
  Future<void> _initializeServices() async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final categorieProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);

      _feedService = MixedFeedService(
        authProvider: authProvider,
        categorieProvider: categorieProvider,
        postProvider: postProvider,
        chroniqueProvider: chroniqueProvider,
        contentProvider: contentProvider,
      );

      // Charger le temps de dernière visite
      await _loadUserLastVisitTime();

      // Nettoyer les listes au login
      await _feedService.cleanupUserLists();

      // Charger le feed initial
      await _loadInitialPosts();

    } catch (e) {
      print('❌ Erreur initialisation: $e');
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
        await _feedService.firestore.collection('Users').doc(currentUserId).update({
          'lastFeedVisitTime': now,
        });

        // Mettre à jour localement
        authProvider.loginUserData.lastFeedVisitTime = now;
        _userLastVisitTime = now;

        print('🕐 Temps de visite mis à jour');
      }
    } catch (e) {
      print('❌ Erreur mise à jour temps visite: $e');
    }
  }

  // 🔥 CHARGEMENT INITIAL AVEC TIMEOUT
  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _posts = []; // Vider les posts pendant le chargement
    });

    try {
      final newPosts = await _feedService.loadSmartFeed(loadMore: false)
          .timeout(Duration(seconds: 30), onTimeout: () {
        print('⏰ Timeout chargement initial');
        return [];
      });

      setState(() {
        _posts = newPosts;
        _hasMore = newPosts.isNotEmpty;
      });

      print('✅ Feed initial: ${newPosts.length} posts');

      // METTRE À JOUR LE TEMPS DE VISITE
      await _updateLastVisitTime();

    } catch (e) {
      print('❌ Erreur chargement initial: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 CHARGEMENT SUPPLÉMENTAIRE AVEC TIMEOUT
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _isLoading || _isRefreshing) return;

    setState(() => _isLoadingMore = true);

    try {
      final newPosts = await _feedService.loadSmartFeed(loadMore: true)
          .timeout(Duration(seconds: 15), onTimeout: () {
        print('⏰ Timeout chargement supplémentaire');
        return [];
      });

      setState(() {
        if (newPosts.isNotEmpty) {
          _posts.addAll(newPosts);
          print('📥 Ajout: ${newPosts.length} posts (total: ${_posts.length})');
        } else {
          _hasMore = false;
          print('🏁 Fin des posts disponibles');
        }
      });

    } catch (e) {
      print('❌ Erreur chargement supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // 🔥 REFRESH COMPLET AVEC INDICATEUR
  Future<void> _refreshData() async {
    print('🔄 Refresh manuel...');

    if (_isLoading || _isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _hasError = false;
    });

    try {
      // RÉINITIALISER COMPLÈTEMENT LE SERVICE
      await _feedService.reset();

      final newPosts = await _feedService.loadSmartFeed(loadMore: false)
          .timeout(Duration(seconds: 20), onTimeout: () {
        print('⏰ Timeout refresh');
        return [];
      });

      setState(() {
        _posts = newPosts;
        _hasMore = newPosts.isNotEmpty;
      });

      // METTRE À JOUR LE TEMPS DE VISITE
      await _updateLastVisitTime();

      print('🆕 Nouveaux posts après refresh: ${newPosts.length}');

    } catch (e) {
      print('❌ Erreur refresh: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  // 🔥 RÉINITIALISATION COMPLÈTE
  Future<void> _resetEverything() async {
    print('🔄 Réinitialisation complète...');

    setState(() {
      _isLoading = true;
      _posts = [];
      _hasMore = true;
      _hasError = false;
    });

    try {
      // RÉINITIALISER LE SERVICE
      await _feedService.reset();

      // RECOMMENCER LE CHARGEMENT
      await _loadInitialPosts();

      print('✅ Réinitialisation terminée');

    } catch (e) {
      print('❌ Erreur réinitialisation: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMorePosts();
    }
  }

  // 🔥 MARQUER UN POST COMME VU QUAND IL EST VISIBLE
  void _handlePostVisibility(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.6) {
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 800), () {
        if (mounted && info.visibleFraction > 0.6) {
          _markPostAsSeen(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }

  Future<void> _markPostAsSeen(Post post) async {
    final currentUserId = _getUserId();
    if (currentUserId.isEmpty || post.id == null) return;

    try {
      // Marquer dans Firebase
      await _feedService.markPostAsSeen(post.id!);

      // Mettre à jour localement
      if (mounted) {
        setState(() {
          post.vues = (post.vues ?? 0) + 1;
          post.users_vue_id ??= [];
          if (!post.users_vue_id!.contains(currentUserId)) {
            post.users_vue_id!.add(currentUserId);
          }
        });
      }
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  // 🔥 GESTION DES ERREURS
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
            onPressed: _loadInitialPosts,
            icon: Icon(Icons.refresh),
            label: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // 🔥 CONSTRUCTION DU BODY AMÉLIORÉE
  Widget _buildBody(double width, double height) {
    // AFFICHER LE CHARGEMENT INITIAL
    if (_isLoading && _posts.isEmpty) {
      return LoadingComponents.buildShimmerEffect();
    }

    // AFFICHER L'ERREUR
    if (_hasError && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    // AUCUN CONTENU
    if (_posts.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey, size: 64),
            SizedBox(height: 20),
            Text(
              'Aucun contenu disponible',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Revenez plus tard ou rafraîchissez',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: Icon(Icons.refresh),
              label: Text('Rafraîchir'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // CONTENU PRINCIPAL
        RefreshIndicator(
          onRefresh: _refreshData,
          backgroundColor: Colors.black,
          color: Colors.white,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // SECTION CHRONIQUES
              if (_feedService.chroniques.isNotEmpty)
                SliverToBoxAdapter(
                  child: ChroniqueSectionComponent(
                    videoThumbnails: {},
                    userVerificationStatus: {},
                    userDataCache: {},
                    isLoadingChroniques: false,
                    groupedChroniques: _groupChroniquesByUser(_feedService.chroniques),
                  ),
                ),

              // SECTION POSTS PRINCIPALE
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    if (index == _posts.length) {
                      return _buildLoadingMore();
                    }
                    return _buildPostItem(_posts[index]);
                  },
                  childCount: _posts.length + (_hasMore ? 1 : 0),
                ),
              ),

              // SECTIONS SPÉCIALES
              if (_feedService.articles.isNotEmpty)
                SliverToBoxAdapter(
                  child: SpecialSectionsComponent.buildBoosterSection(
                    articles: _feedService.articles,
                    context: context,
                    width: width,
                    height: height,
                  ),
                ),

              if (_feedService.canaux.isNotEmpty)
                SliverToBoxAdapter(
                  child: SpecialSectionsComponent.buildCanalSection(
                    canaux: _feedService.canaux,
                    context: context,
                    width: width,
                    height: height,
                  ),
                ),

              // MESSAGE DE FIN
              if (!_hasMore && _posts.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildEndOfFeed(),
                ),
            ],
          ),
        ),

        // INDICATEUR DE REFRESH EN HAUT
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
            // CONTENU POST
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

            // BADGE "NOUVEAU" POUR LES POSTS RÉCENTS
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

            // INDICATEUR DE DATE DE CRÉATION
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

  // 🔥 FORMATAGE DE LA DATE POUR AFFICHAGE
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

  // 🔥 LOADING MORE
  Widget _buildLoadingMore() {
    if (!_hasMore) return SizedBox.shrink();

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

  // 🔥 FIN DU FEED
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

  // 🔥 GROUPEMENT DES CHRONIQUES PAR UTILISATEUR
  Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
    final grouped = <String, List<Chronique>>{};
    for (final chronique in chroniques) {
      grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
    }
    return grouped;
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
          // 🔥 ICÔNE REFRESH AVEC INDICATEUR
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
              if (value == 'reset') _resetEverything();
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