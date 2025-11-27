import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:provider/provider.dart';
import '../../pages/chronique/chroniqueform.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import 'feed_scoring_service.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:provider/provider.dart';
import '../../pages/chronique/chroniqueform.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import 'feed_scoring_service.dart';
import 'package:afrotok/providers/authProvider.dart';

import 'local_viewed_posts_service.dart';

class MixedFeedService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final UserAuthProvider authProvider;
  final CategorieProduitProvider categorieProvider;
  final PostProvider postProvider;
  final ChroniqueProvider chroniqueProvider;
  final ContentProvider contentProvider;

  // 🔥 CACHE AMÉLIORÉ AVEC GESTION DES DOUBLONS
  List<String> _preparedPostIds = [];
  int _currentIndex = 0;
  static const int _preloadBatchSize = 100;
  static const int _displayBatchSize = 5;

  // 🔥 CONTENU GLOBAL
  List<ArticleData> _globalArticles = [];
  List<Canal> _globalCanaux = [];
  List<Chronique> _globalChroniques = [];
  bool _hasLoadedGlobalContent = false;
  bool _isPreparingPosts = false;

  // 🔥 MÉMOIRE DES POSTS DÉJÀ CHARGÉS (pour éviter les doublons)
  Set<String> _alreadyLoadedPostIds = Set();

  // 🔥 ÉTAT DE CHARGEMENT
  bool _isLoading = false;
  bool _hasMore = true;

  // 🔥 CONTENU MIXTE ACTUEL
  List<dynamic> _mixedContent = [];

  MixedFeedService({
    required this.authProvider,
    required this.categorieProvider,
    required this.postProvider,
    required this.chroniqueProvider,
    required this.contentProvider,
  });

  // 🔥 GETTERS
  List<dynamic> get mixedContent => _mixedContent;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isGlobalContentLoaded => _hasLoadedGlobalContent;
  bool get isReady => _preparedPostIds.isNotEmpty;
  int get preparedPostsCount => _preparedPostIds.length;
  int get currentIndex => _currentIndex;
  List<ArticleData> get articles => _globalArticles;
  List<Canal> get canaux => _globalCanaux;
  List<Chronique> get chroniques => _globalChroniques;

  // 🔥 INITIALISATION RAPIDE POUR LE SPLASH (POSTS SEULEMENT)
  Future<void> preparePostsOnly() async {
    if (_isPreparingPosts) return;

    _isPreparingPosts = true;

    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      print('🎯 Préparation des posts seulement depuis le splash...');

      await _prepareInitialPostIds(currentUserId);

      print('✅ Posts préparés: ${_preparedPostIds.length} IDs uniques prêts');

    } catch (e) {
      print('❌ Erreur préparation posts: $e');
    } finally {
      _isPreparingPosts = false;
    }
  }

  // 🔥 CHARGEMENT DU CONTENU GLOBAL DEPUIS LA PAGE
  Future<void> loadGlobalContentFromPage() async {
    if (_hasLoadedGlobalContent) {
      print('✅ Contenu global déjà chargé');
      return;
    }

    try {
      print('🌍 Chargement du contenu global depuis la page...');

      await Future.wait([
        _loadChroniques(),
        _loadArticles(),
        _loadCanaux(),
      ]);

      _hasLoadedGlobalContent = true;

      print('''
✅ Contenu global chargé depuis la page:
   - ${_globalChroniques.length} chroniques
   - ${_globalArticles.length} articles  
   - ${_globalCanaux.length} canaux
''');

    } catch (e) {
      print('❌ Erreur chargement contenu global depuis page: $e');
    }
  }

  // 🔥 ALGORITHME INTELLIGENT DE CHARGEMENT AVEC MÉLANGE
  Future<List<dynamic>> loadMixedContent({bool loadMore = false}) async {
    if (_isLoading) return _mixedContent;

    _isLoading = true;

    try {
      print('🧠 Chargement contenu mixte - LoadMore: $loadMore');

      if (!loadMore) {
        // 🔥 RÉINITIALISER POUR LE PREMIER CHARGEMENT
        _mixedContent.clear();
        _currentIndex = 0;
        _alreadyLoadedPostIds.clear();
      }

      // 🔥 PRÉPARER LES IDs SI NÉCESSAIRE
      if (!loadMore || _preparedPostIds.isEmpty || _currentIndex >= _preparedPostIds.length - 10) {
        final currentUserId = authProvider.loginUserData.id;
        if (currentUserId != null) {
          await _prepareInitialPostIds(currentUserId);
        }
      }

      if (_preparedPostIds.isEmpty) {
        print('📭 Aucun post à charger');
        _hasMore = false;
        return _mixedContent;
      }

      // 🔥 CHARGER LE LOT DE POSTS ACTUEL
      final posts = await _loadCurrentBatch();

      // 🔥 CONSTRUIRE LE CONTENU MIXTE
      final newContent = _buildMixedContent(posts, loadMore: loadMore);

      if (loadMore) {
        _mixedContent.addAll(newContent);
      } else {
        _mixedContent = newContent;
      }

      // 🔥 METTRE À JOUR L'ÉTAT "HAS MORE"
      _hasMore = _currentIndex < _preparedPostIds.length;

      print('✅ Contenu mixte chargé: ${_mixedContent.length} éléments (hasMore: $_hasMore)');
      return _mixedContent;

    } catch (e) {
      print('❌ Erreur chargement contenu mixte: $e');
      _hasMore = false;
      return _mixedContent;
    } finally {
      _isLoading = false;
    }
  }

  // 🔥 PRÉPARATION DES IDs INITIAUX - VERSION RÉCURSIVE CORRIGÉE
  Future<void> _prepareInitialPostIds(String currentUserId) async {
    try {
      print('🎯 Préparation des IDs de posts - Recherche étendue...');

      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final newPostsFromSubscriptions = List<String>.from(userData['newPostsFromSubscriptions'] ?? []);
      final viewedPostIds = List<String>.from(userData['viewedPostIds'] ?? []);

      // 🔥 NETTOYER LES DONNÉES FIRESTORE SI TROP ANCIENNES
      await _cleanupOldViewedPosts(currentUserId, viewedPostIds);

      // Récupérer les posts vus localement
      final localViewedPosts = await LocalViewedPostsService.getViewedPosts();
      print('📱 Posts vus: ${viewedPostIds.length} Firestore + ${localViewedPosts.length} local');

      // Combiner et limiter les posts vus
      final allViewedPosts = {...viewedPostIds, ...localViewedPosts}.toList();
      final cleanedViewedPosts = allViewedPosts.length > 500
          ? allViewedPosts.sublist(allViewedPosts.length - 500)
          : allViewedPosts;

      print('👀 Total posts vus: ${cleanedViewedPosts.length}');

      // 🔥 ALGORITHME RÉCURSIF POUR GARANTIR 100+ POSTS UNIQUES
      final Set<String> allPostIds = Set();
      int attempts = 0;
      const int maxAttempts = 5;

      while (allPostIds.length < _preloadBatchSize && attempts < maxAttempts) {
        attempts++;
        print('🔄 Tentative $attempts - Posts trouvés: ${allPostIds.length}');

        // 1. Posts d'abonnements non vus
        if (allPostIds.length < _preloadBatchSize * 0.3) {
          final subscriptionPosts = await _getSubscriptionPostsRecursive(
              newPostsFromSubscriptions,
              cleanedViewedPosts,
              limit: 30,
              excludedIds: allPostIds.toList()
          );
          allPostIds.addAll(subscriptionPosts);
          print('   📨 Abonnements: +${subscriptionPosts.length}');
        }

        // 2. Posts récents non vus (avec pagination)
        if (allPostIds.length < _preloadBatchSize * 0.4) {
          final recentPosts = await _getRecentPostIdsRecursive(
              limit: 40,
              excludeIds: cleanedViewedPosts,
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );
          allPostIds.addAll(recentPosts);
          print('   🆕 Récents: +${recentPosts.length}');
        }

        // 3. Posts par score (avec pagination)
        if (allPostIds.length < _preloadBatchSize) {
          final highScorePosts = await _getPostsByScoreRecursive(
              limit: 20,
              minScore: 0.7,
              maxScore: 1.0,
              excludeIds: cleanedViewedPosts,
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );
          final mediumScorePosts = await _getPostsByScoreRecursive(
              limit: 20,
              minScore: 0.4,
              maxScore: 0.7,
              excludeIds: cleanedViewedPosts,
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );
          final lowScorePosts = await _getPostsByScoreRecursive(
              limit: 15,
              minScore: 0.0,
              maxScore: 0.4,
              excludeIds: cleanedViewedPosts,
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );

          allPostIds.addAll(highScorePosts);
          allPostIds.addAll(mediumScorePosts);
          allPostIds.addAll(lowScorePosts);

          print('   📊 Scores: ${highScorePosts.length}F ${mediumScorePosts.length}M ${lowScorePosts.length}L');
        }

        // 4. 🔥 FORÇAGE : Si toujours pas assez, chercher SANS exclusion
        if (allPostIds.length < 20 && attempts >= 3) {
          print('🚨 FORÇAGE - Recherche sans exclusion...');
          final forcedPosts = await _getForcedPosts(30, excludedIds: allPostIds.toList());
          allPostIds.addAll(forcedPosts);
          print('   💥 Forcés: +${forcedPosts.length}');
        }

        // Petit délai entre les tentatives
        if (allPostIds.length < _preloadBatchSize && attempts < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 200));
        }
      }

      print('🎯 Recherche terminée: ${allPostIds.length} posts uniques après $attempts tentatives');

      // 🔥 FILTRAGE FINAL (normalement déjà fait, mais sécurité)
      final finalPosts = allPostIds.where((id) => !cleanedViewedPosts.contains(id)).toList();

      print('''
📦 RÉSULTAT FINAL:
   - Posts bruts: ${allPostIds.length}
   - Après filtrage: ${finalPosts.length}
   - Posts exclus: ${allPostIds.length - finalPosts.length}
''');

      // 🔥 ORDRE CYCLIQUE
      final orderedPosts = _createCyclicOrderFromSet(finalPosts);

      _preparedPostIds = orderedPosts.take(_preloadBatchSize).toList();
      _currentIndex = 0;
      _alreadyLoadedPostIds.clear();
      _hasMore = _preparedPostIds.isNotEmpty;

      print('✅ Préparation terminée: ${_preparedPostIds.length} posts prêts');

    } catch (e) {
      print('❌ Erreur préparation IDs: $e');
      _preparedPostIds = [];
      _hasMore = false;
    }
  }

  // 🔥 MÉTHODE RÉCURSIVE POUR LES ABONNEMENTS
  Future<List<String>> _getSubscriptionPostsRecursive(
      List<String> subscriptionPosts,
      List<String> viewedPostIds, {
        required int limit,
        List<String> excludedIds = const []
      }) async {
    try {
      final unseenPosts = subscriptionPosts.where((id) =>
      !viewedPostIds.contains(id) && !excludedIds.contains(id)
      ).toList();

      return unseenPosts.take(limit).toList();
    } catch (e) {
      print('❌ Erreur abonnements récursifs: $e');
      return [];
    }
  }

  // 🔥 RÉCUPÉRATION RÉCURSIVE DES POSTS RÉCENTS
  Future<List<String>> _getRecentPostIdsRecursive({
    required int limit,
    List<String> excludeIds = const [],
    List<String> excludedIds = const [],
    int attempt = 1
  }) async {
    try {
      final multiplier = attempt * 2;
      final effectiveLimit = limit * multiplier;

      Query query = firestore
          .collection('Posts')
          .orderBy('created_at', descending: true)
          .limit(effectiveLimit);

      final snapshot = await query.get();

      // Filtrage manuel
      final allPosts = snapshot.docs.map((doc) => doc.id).toList();
      final filteredPosts = allPosts.where((id) =>
      !excludeIds.contains(id) && !excludedIds.contains(id)
      ).toList();

      return filteredPosts.take(limit).toList();

    } catch (e) {
      print('❌ Erreur posts récents récursifs: $e');
      return [];
    }
  }

  // 🔥 RÉCUPÉRATION RÉCURSIVE PAR SCORE
  Future<List<String>> _getPostsByScoreRecursive({
    required int limit,
    required double minScore,
    required double maxScore,
    List<String> excludeIds = const [],
    List<String> excludedIds = const [],
    int attempt = 1
  }) async {
    try {
      final multiplier = attempt * 2;
      final effectiveLimit = limit * multiplier;

      Query query = firestore
          .collection('Posts')
          .where('feedScore', isGreaterThanOrEqualTo: minScore)
          .where('feedScore', isLessThan: maxScore)
          .orderBy('feedScore', descending: minScore > 0.5)
          .limit(effectiveLimit);

      final snapshot = await query.get();

      // Filtrage manuel
      final allPosts = snapshot.docs.map((doc) => doc.id).toList();
      final filteredPosts = allPosts.where((id) =>
      !excludeIds.contains(id) && !excludedIds.contains(id)
      ).toList();

      return filteredPosts.take(limit).toList();

    } catch (e) {
      print('❌ Erreur posts score récursifs: $e');
      return [];
    }
  }

  // 🔥 RÉCUPÉRATION FORCÉE (sans exclusion)
  Future<List<String>> _getForcedPosts(int limit, {List<String> excludedIds = const []}) async {
    try {
      final snapshot = await firestore
          .collection('Posts')
          .orderBy('created_at', descending: true)
          .limit(limit * 3)
          .get();

      final allPosts = snapshot.docs.map((doc) => doc.id).toList();
      final filteredPosts = allPosts.where((id) => !excludedIds.contains(id)).toList();

      return filteredPosts.take(limit).toList();

    } catch (e) {
      print('❌ Erreur posts forcés: $e');
      return [];
    }
  }

  // 🔥 ORDRE CYCLIQUE ADAPTÉ
  List<String> _createCyclicOrderFromSet(List<String> posts) {
    if (posts.isEmpty) return [];

    final shuffled = List<String>.from(posts)..shuffle();

    // Mélanger pour varier l'expérience
    return shuffled.take(_preloadBatchSize).toList();
  }

  // 🔥 NETTOYER LES POSTS VUS ANCIENS DANS FIRESTORE
  Future<void> _cleanupOldViewedPosts(String userId, List<String> viewedPostIds) async {
    try {
      if (viewedPostIds.length > 1000) {
        print('🧹 Nettoyage Firestore: ${viewedPostIds.length} posts vus → 1000');

        // Garder seulement les 1000 derniers posts
        final cleanedPosts = viewedPostIds.length > 1000
            ? viewedPostIds.sublist(viewedPostIds.length - 1000)
            : viewedPostIds;

        await firestore.collection('Users').doc(userId).update({
          'viewedPostIds': cleanedPosts,
        });

        print('✅ Firestore nettoyé: ${cleanedPosts.length} posts conservés');
      }
    } catch (e) {
      print('❌ Erreur nettoyage Firestore: $e');
    }
  }

  // 🔥 VIDER COMPLÈTEMENT L'HISTORIQUE DES POSTS VUS
  Future<void> clearUserViewedPosts() async {
    try {
      print('🧹 Début du nettoyage complet des posts vus...');

      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      // 1. VIDER FIRESTORE
      await firestore.collection('Users').doc(currentUserId).update({
        'viewedPostIds': [],
        'newPostsFromSubscriptions': FieldValue.delete(),
      });

      // 2. VIDER LE STOCKAGE LOCAL
      await LocalViewedPostsService.clearViewedPosts();

      // 3. VIDER LE CACHE LOCAL DU SERVICE
      _preparedPostIds.clear();
      _mixedContent.clear();
      _alreadyLoadedPostIds.clear();
      _currentIndex = 0;

      print('''
✅ NETTOYAGE COMPLET RÉUSSI:
   - Firestore: viewedPostIds vidé
   - Stockage local: posts vus effacés
   - Cache service: réinitialisé
''');

      // 4. RELANCER LA PRÉPARATION
      await _prepareInitialPostIds(currentUserId);

    } catch (e) {
      print('❌ Erreur nettoyage posts vus: $e');
    }
  }

  // 🔥 VERSION SIMPLIFIÉE POUR LA COMPATIBILITÉ
  List<String> _createCyclicOrder({
    required List<String> subscriptionPosts,
    required List<String> recentPosts,
    required List<String> highScorePosts,
    required List<String> mediumScorePosts,
    required List<String> lowScorePosts,
  }) {
    return _createCyclicOrderFromSet([
      ...subscriptionPosts,
      ...recentPosts,
      ...highScorePosts,
      ...mediumScorePosts,
      ...lowScorePosts,
    ]);
  }

  String? _getAnyAvailablePost(List<List<String>> pools) {
    for (final pool in pools) {
      if (pool.isNotEmpty) {
        return pool.removeAt(0);
      }
    }
    return null;
  }

  // 🔥 CHARGEMENT DU LOT ACTUEL AVEC GESTION DES DOUBLONS
  Future<List<Post>> _loadCurrentBatch() async {
    final batchSize = _displayBatchSize;
    final endIndex = min(_currentIndex + batchSize, _preparedPostIds.length);

    if (_currentIndex >= _preparedPostIds.length) {
      return [];
    }

    // 🔥 FILTRER LES IDs DÉJÀ CHARGÉS
    final availableIds = _preparedPostIds.sublist(_currentIndex, endIndex)
        .where((id) => !_alreadyLoadedPostIds.contains(id))
        .toList();

    if (availableIds.isEmpty) {
      print('⚠️ Tous les posts de ce lot sont déjà chargés, passage au suivant');
      _currentIndex = endIndex;
      return await _loadCurrentBatch();
    }

    final posts = await _loadPostsByIds(availableIds);

    // 🔥 METTRE À JOUR LA MÉMOIRE ET L'INDEX
    for (final post in posts) {
      if (post.id != null) {
        _alreadyLoadedPostIds.add(post.id!);
      }
    }

    _currentIndex = endIndex;

    // 🔥 MARQUER COMME VUS EN ARRIÈRE-PLAN
    _markPostsAsSeenInBackground(posts);

    return posts;
  }

  // 🔥 CONSTRUCTION DU CONTENU MIXTE (POSTS + AUTRES CONTENUS)
  List<dynamic> _buildMixedContent(List<Post> posts, {bool loadMore = false}) {
    final mixedContent = <dynamic>[];

    if (!loadMore) {
      print('🎯 Construction contenu mixte INITIAL:');
      print('   - ${posts.length} posts');
      print('   - ${_globalChroniques.length} chroniques');
      print('   - ${_globalArticles.length} articles');
      print('   - ${_globalCanaux.length} canaux');

      // 1. Chroniques en premier
      if (_globalChroniques.isNotEmpty) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.CHRONIQUES,
          data: _globalChroniques,
        ));
        print('   ✅ Chroniques ajoutées');
      }

      // 2. Posts initiaux (2-3 premiers)
      final initialPosts = posts.take(3).toList();
      for (final post in initialPosts) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.POST,
          data: post,
        ));
      }
      print('   ✅ ${initialPosts.length} posts initiaux ajoutés');

      // 3. Canaux (avant les articles)
      if (_globalCanaux.isNotEmpty) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.CANAUX,
          data: _globalCanaux,
        ));
        print('   ✅ Canaux ajoutés');
      }

      // 4. 🔥 ARTICLES UNIQUEMENT EN INITIAL
      if (_globalArticles.isNotEmpty) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.ARTICLES,
          data: _globalArticles,
        ));
        print('   ✅ Articles ajoutés (initial seulement)');
      }

      // 5. Posts restants
      if (posts.length > 3) {
        final remainingPosts = posts.skip(3).toList();
        for (final post in remainingPosts) {
          mixedContent.add(ContentSection(
            type: ContentMixtType.POST,
            data: post,
          ));
        }
        print('   ✅ ${remainingPosts.length} posts restants ajoutés');
      }

    } else {
      // 🔥 CHARGEMENT SUPPLÉMENTAIRE : PAS D'ARTICLES
      print('🎯 Construction contenu mixte LOADMORE:');
      print('   - ${posts.length} posts');
      print('   - ${_globalChroniques.length} chroniques');
      print('   - ${_globalCanaux.length} canaux');
      print('   - ❌ Articles exclus en loadMore');

      // 1. Chroniques (si disponibles)
      if (_globalChroniques.isNotEmpty) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.CHRONIQUES,
          data: _globalChroniques,
        ));
        print('   ✅ Chroniques ajoutées en loadMore');
      }

      // 2. Posts (la majorité du contenu)
      for (final post in posts) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.POST,
          data: post,
        ));
      }
      print('   ✅ ${posts.length} posts ajoutés en loadMore');

      // 3. 🔥 CANAUX EN LOADMORE
      if (_globalCanaux.isNotEmpty) {
        mixedContent.add(ContentSection(
          type: ContentMixtType.CANAUX,
          data: _globalCanaux,
        ));
        print('   ✅ Canaux ajoutés en loadMore');
      }
    }

    print('🎯 Contenu mixte final: ${mixedContent.length} sections');
    return mixedContent;
  }

  // 🔥 MARQUAGE EN ARRIÈRE-PLAN
  void _markPostsAsSeenInBackground(List<Post> posts) {
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      for (final post in posts) {
        if (post.id != null) {
          await markPostAsSeen(post.id!);
        }
      }
    });
  }

  // 🔥 MÉTHODES DE CHARGEMENT COMPATIBILITÉ
  Future<List<String>> _getSubscriptionPosts(List<String> subscriptionPosts, List<String> viewedPostIds, {required int limit}) async {
    return _getSubscriptionPostsRecursive(subscriptionPosts, viewedPostIds, limit: limit);
  }

  Future<List<String>> _getRecentPostIds(int limit, {List<String> excludeIds = const []}) async {
    return _getRecentPostIdsRecursive(limit: limit, excludeIds: excludeIds);
  }

  Future<List<String>> _getPostsByScore(int limit, double minScore, double maxScore, {List<String> excludeIds = const []}) async {
    return _getPostsByScoreRecursive(limit: limit, minScore: minScore, maxScore: maxScore, excludeIds: excludeIds);
  }

  Future<List<Post>> _loadPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    final List<Post> posts = [];

    try {
      for (int i = 0; i < postIds.length; i += 10) {
        final batchIds = postIds.sublist(i, min(i + 10, postIds.length));

        final snapshot = await firestore
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        final batchPosts = snapshot.docs.map((doc) {
          try {
            final post = Post.fromJson({'id': doc.id, ...doc.data()});
            return post;
          } catch (e) {
            print('❌ Erreur parsing post ${doc.id}: $e');
            return null;
          }
        }).where((post) => post != null).cast<Post>().toList();

        posts.addAll(batchPosts);
      }
    } catch (e) {
      print('❌ Erreur chargement posts par IDs: $e');
    }

    return posts;
  }

  Future<void> _loadChroniques() async {
    try {
      final snapshot = await firestore
          .collection('chroniques')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      _globalChroniques = snapshot.docs.map((doc) {
        return Chronique.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur chroniques: $e');
      _globalChroniques = [];
    }
  }

  Future<void> _loadArticles() async {
    try {
      final snapshot = await firestore
          .collection('Articles')
          .where('isBoosted', isEqualTo: true)
          .limit(3)
          .get();

      _globalArticles = snapshot.docs.map((doc) {
        return ArticleData.fromJson({'id': doc.id, ...doc.data()});
      }).toList();
    } catch (e) {
      print('❌ Erreur articles: $e');
      _globalArticles = [];
    }
  }

  Future<void> _loadCanaux() async {
    try {
      final snapshot = await firestore
          .collection('Canaux')
          .limit(6)
          .get();

      _globalCanaux = snapshot.docs.map((doc) {
        return Canal.fromJson(doc.data());
      }).toList();
      _globalCanaux.shuffle();
    } catch (e) {
      print('❌ Erreur canaux: $e');
      _globalCanaux = [];
    }
  }

  // 🔥 MARQUER UN POST COMME VU
  Future<void> markPostAsSeen(String postId) async {
    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      await firestore.collection('Users').doc(currentUserId).update({
        'viewedPostIds': FieldValue.arrayUnion([postId]),
        'newPostsFromSubscriptions': FieldValue.arrayRemove([postId]),
      });

      print('👁️ Post $postId marqué comme vu');
    } catch (e) {
      print('❌ Erreur marquage post vu: $e');
    }
  }

  // 🔥 NETTOYAGE
  Future<void> cleanupUserLists() async {
    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final newPosts = List<String>.from(data['newPostsFromSubscriptions'] ?? []);
      final seenPosts = List<String>.from(data['viewedPostIds'] ?? []);

      final updates = <String, dynamic>{};

      if (newPosts.length > 1000) {
        updates['newPostsFromSubscriptions'] = newPosts.take(1000).toList();
      }
      if (seenPosts.length > 1000) {
        updates['viewedPostIds'] = seenPosts.take(1000).toList();
      }

      if (updates.isNotEmpty) {
        await firestore.collection('Users').doc(currentUserId).update(updates);
        print('🧹 Listes utilisateur nettoyées');
      }

    } catch (e) {
      print('❌ Erreur nettoyage listes: $e');
    }
  }

  // 🔥 RÉINITIALISATION COMPLÈTE
  Future<void> reset() async {
    _preparedPostIds.clear();
    _currentIndex = 0;
    _hasLoadedGlobalContent = false;
    _isPreparingPosts = false;
    _alreadyLoadedPostIds.clear();
    _mixedContent.clear();
    _isLoading = false;
    _hasMore = true;
    print('🔄 Service réinitialisé');
  }
}

// 🔥 ENUM POUR LES TYPES DE CONTENU
enum ContentMixtType {
  POST,
  CHRONIQUES,
  ARTICLES,
  CANAUX
}

// 🔥 CLASSE POUR REPRÉSENTER UNE SECTION DE CONTENU
class ContentSection {
  final ContentMixtType type;
  final dynamic data;

  ContentSection({required this.type, required this.data});
}

enum _PostType { SUBSCRIPTION, RECENT, HIGH, MEDIUM, LOW }

// 🔥 SERVICE DE NOTIFICATION DES ABONNÉS
class MassNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> notifySubscribersAboutNewPost({
    required String postId,
    required String authorId,
  }) async {
    try {
      print('🚀 Notification pour le post $postId aux abonnés de $authorId');

      int totalProcessed = 0;
      int batchCount = 0;

      await _processSubscribersInBatches(authorId, (subscriberIds) async {
        if (subscriberIds.isEmpty) return;

        batchCount++;
        totalProcessed += subscriberIds.length;

        await _updateSubscribersBatch(subscriberIds, postId);

        print('📦 Batch $batchCount: ${subscriberIds.length} abonnés');
      });

      print('✅ Notification terminée: $totalProcessed abonnés notifiés');

    } catch (e) {
      print('❌ Erreur notification abonnés: $e');
      rethrow;
    }
  }

  Future<void> _processSubscribersInBatches(
      String authorId,
      Function(List<String>) processBatch,
      ) async {
    const int batchSize = 400;
    DocumentSnapshot? lastDoc;
    bool hasMore = true;

    while (hasMore) {
      Query query = _firestore
          .collection('Users')
          .where('userAbonnesIds', arrayContains: authorId)
          .limit(batchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      final subscriberIds = snapshot.docs.map((doc) => doc.id).toList();

      if (subscriberIds.isNotEmpty) {
        await processBatch(subscriberIds);
        lastDoc = snapshot.docs.last;
      }

      hasMore = subscriberIds.length == batchSize;

      if (hasMore) {
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _updateSubscribersBatch(List<String> subscriberIds, String postId) async {
    final batch = _firestore.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final subscriberId in subscriberIds) {
      final userRef = _firestore.collection('Users').doc(subscriberId);

      batch.update(userRef, {
        'newPostsFromSubscriptions': FieldValue.arrayUnion([postId]),
        'lastFeedUpdate': now,
      });
    }

    await batch.commit();
  }
}