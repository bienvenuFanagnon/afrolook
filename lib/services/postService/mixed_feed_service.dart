import 'dart:async';
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
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:provider/provider.dart';
import '../../pages/chronique/chroniqueform.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/chroniqueProvider.dart';

// 🔥 CLASSE DE CONFIGURATION CENTRALISÉE COMPLÈTE
class FeedConfig {
  // ================= POSTS IMMÉDIATS (SPLASH) =================
  static const int immediatePostsCount = 2;

  // ================= PRÉPARATION DES IDs =================
  static const int preloadBatchSize = 25;
  static const int displayBatchSize = 5;

  // ================= ALGORITHMES DE RECHERCHE =================
  static const int maxPreparationAttempts = 3;
  static const int preparationDelayMs = 200;

  // Répartition pour la préparation des posts
  static const double subscriptionPercentage = 0.3;  // 30%
  static const double recentPercentage = 0.4;        // 40%
  static const double scorePercentage = 0.3;         // 30%

  // Limites par catégorie (calculées dynamiquement)
  static int get subscriptionLimit => (preloadBatchSize * subscriptionPercentage).round();
  static int get recentLimit => (preloadBatchSize * recentPercentage).round();
  static int get scoreLimit => (preloadBatchSize * scorePercentage).round();

  // ================= FILTRES =================
  static const int filteredPostsLimit = 5;
  static const int filteredPostsMultiplier = 2; // Pour avoir plus de choix

  // ================= NETTOYAGE =================
  static const int maxViewedPosts = 1000;
  static const int cleanupBatchSize = 500;
  static const int cleanupDelayMs = 100;

  // ================= CHRONIQUES =================
  static const int chroniquesLoadLimit = 20;
  static const int chroniquesDisplayLimit = 8;

  // ================= ARTICLES =================
  static const int articlesLoadLimit = 3;

  // ================= CANAUX =================
  static const int canauxLoadLimit = 6;

  // ================= CHARGEMENT PAR BATCH =================
  static const int postsBatchSize = 10; // Pour _loadPostsByIds

  // ================= FORÇAGE =================
  static const int minPostsForForce = 5;
  static const int forceAttemptThreshold = 2;
  static const int forceMultiplier = 2;

  // ================= VISIBILITÉ =================
  static const double visibilityThreshold = 0.8;
  static const double visibilityCancelThreshold = 0.3;
  static const int visibilityTimerSeconds = 2;

  // ================= DÉLAIS =================
  static const int backgroundLoadDelayMs = 500;
  static const int batchCommitDelayMs = 100;
}


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

  // 🔥 UTILISATION DE LA CONFIGURATION
  int get _preloadBatchSize => FeedConfig.preloadBatchSize;
  int get _displayBatchSize => FeedConfig.displayBatchSize;
  // 🔥 INITIALISATION RAPIDE POUR LE SPLASH (POSTS SEULEMENT)
  bool _isPreparingPosts = false;
  List<String> _availablePostIds = []; // Posts déjà trouvés
  Completer<void>? _preparationCompleter;
// 🔥 MODIFIER LE GETTER preparedPostIds
  List<String> get preparedPostIds => _availablePostIds;

// 🔥 MODIFIER preparedPostsCount
  int get preparedPostsCount => _availablePostIds.length;

// 🔥 MODIFIER isReady pour retourner true dès qu'on a des posts
  bool get isReady => _availablePostIds.isNotEmpty;
  // 🔥 CONTENU GLOBAL
  List<ArticleData> _globalArticles = [];
  List<Canal> _globalCanaux = [];
  List<Chronique> _globalChroniques = [];
  bool _hasLoadedGlobalContent = false;

  // 🔥 MÉMOIRE DES POSTS DÉJÀ CHARGÉS (pour éviter les doublons)
  Set<String> _alreadyLoadedPostIds = Set();

  // 🔥 ÉTAT DE CHARGEMENT
  bool _isLoading = false;
  bool _hasMore = true;

  // 🔥 CONTENU MIXTE ACTUEL
  List<dynamic> _mixedContent = [];

  // 🔥 NOUVEAU: Posts immédiats pour le splash
  List<Post> _immediatePosts = [];
  bool _areImmediatePostsLoaded = false;

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
  // bool get isReady => _preparedPostIds.isNotEmpty;
  // int get preparedPostsCount => _preparedPostIds.length;
  int get currentIndex => _currentIndex;
  List<ArticleData> get articles => _globalArticles;
  List<Canal> get canaux => _globalCanaux;
  List<Chronique> get chroniques => _globalChroniques;

  // 🔥 GETTERS POUR POSTS IMMÉDIATS
  List<Post> get immediatePosts => _immediatePosts;
  bool get areImmediatePostsLoaded => _areImmediatePostsLoaded;

  // 🔥 CHARGEMENT DES POSTS IMMÉDIATS
  Future<void> loadImmediatePosts() async {
    if (_areImmediatePostsLoaded) return;

    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) {
        _areImmediatePostsLoaded = true;
        return;
      }

      print('🚀 Chargement des ${FeedConfig.immediatePostsCount} posts immédiats...');

      List<String> immediatePostIds = [];

      // 🔥 ÉTAPE 1: ESSAYER LES ABONNEMENTS
      try {
        final userDoc = await firestore.collection('Users').doc(currentUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final newPostsFromSubscriptions = List<String>.from(userData['newPostsFromSubscriptions'] ?? []);
          final viewedPostIds = List<String>.from(userData['viewedPostIds'] ?? []);
          final localViewedPosts = await LocalViewedPostsService.getViewedPosts();
          final allViewedPosts = {...viewedPostIds, ...localViewedPosts}.toList();

          if (newPostsFromSubscriptions.isNotEmpty) {
            final subscriptionPosts = newPostsFromSubscriptions
                .where((id) => !allViewedPosts.contains(id))
                .take(FeedConfig.immediatePostsCount) // 🔥 CONFIGURABLE
                .toList();

            immediatePostIds.addAll(subscriptionPosts);
            print('📨 ${subscriptionPosts.length} post(s) d\'abonnement(s)');
          }
        }
      } catch (e) {
        print('⚠️ Erreur abonnements, continuation: $e');
      }

      // 🔥 ÉTAPE 2: COMPLÉTER AVEC DES POSTS RÉCENTS
      if (immediatePostIds.length < FeedConfig.immediatePostsCount) {
        final needed = FeedConfig.immediatePostsCount - immediatePostIds.length;
        try {
          final recentPosts = await _getRecentPostIdsForImmediate(limit: needed * 2);
          final postsToAdd = recentPosts.take(needed).toList();
          immediatePostIds.addAll(postsToAdd);
          print('🔄 ${postsToAdd.length} post(s) récents ajoutés');
        } catch (e) {
          print('⚠️ Erreur posts récents: $e');
        }
      }

      // 🔥 ÉTAPE 3: FORCER SI NÉCESSAIRE
      if (immediatePostIds.isEmpty) {
        try {
          final forcedPosts = await _getForcedPosts(FeedConfig.immediatePostsCount);
          immediatePostIds.addAll(forcedPosts);
          print('💥 ${forcedPosts.length} post(s) forcés');
        } catch (e) {
          print('❌ Erreur forçage: $e');
        }
      }

      // 🔥 CHARGER LES POSTS
      if (immediatePostIds.isNotEmpty) {
        _immediatePosts = await _loadPostsByIds(immediatePostIds);

        for (final post in _immediatePosts) {
          if (post.id != null) {
            _alreadyLoadedPostIds.add(post.id!);
          }
        }
      }

      _areImmediatePostsLoaded = true;
      print('🎯 FINAL: ${_immediatePosts.length} post(s) immédiat(s) chargé(s)');

    } catch (e) {
      print('❌ Erreur critique posts immédiats: $e');
      _immediatePosts = [];
      _areImmediatePostsLoaded = true;
    }
  }

  // 🔥 VERSION SPÉCIALISÉE POUR LES POSTS IMMÉDIATS
  Future<List<String>> _getRecentPostIdsForImmediate({
    required int limit,
    List<String> excludeIds = const [],
  }) async {
    try {
      final snapshot = await firestore
          .collection('Posts')
          .orderBy('created_at', descending: true)
          .limit(limit * 2)
          .get();

      final allPosts = snapshot.docs.map((doc) => doc.id).toList();
      final filteredPosts = allPosts.where((id) => !excludeIds.contains(id)).toList();

      return filteredPosts.take(limit).toList();

    } catch (e) {
      print('❌ Erreur posts récents immédiats: $e');
      return [];
    }
  }



// 🔥 NOUVELLE MÉTHODE : PRÉPARATION PROGRESSIVE
  Future<void> preparePostsOnly() async {
    if (_isPreparingPosts) return;

    _isPreparingPosts = true;
    _availablePostIds.clear(); // Réinitialiser

    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      print('🎯 Début de la préparation progressive des posts...');

      // 🔥 LANCER EN BACKGROUND SANS ATTENDRE
      _startProgressivePreparation(currentUserId);

      print('✅ Préparation lancée en background');

    } catch (e) {
      print('❌ Erreur préparation posts: $e');
      _isPreparingPosts = false;
    }
  }

// 🔥 PRÉPARATION PROGRESSIVE EN BACKGROUND
  void _startProgressivePreparation(String currentUserId) async {
    try {
      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) {
        _isPreparingPosts = false;
        return;
      }

      final userData = userDoc.data()!;
      final newPostsFromSubscriptions = List<String>.from(userData['newPostsFromSubscriptions'] ?? []);
      final viewedPostIds = List<String>.from(userData['viewedPostIds'] ?? []);

      await _cleanupOldViewedPosts(currentUserId, viewedPostIds);

      final localViewedPosts = await LocalViewedPostsService.getViewedPosts();
      final allViewedPosts = {...viewedPostIds, ...localViewedPosts}.toList();
      final immediatePostIds = _immediatePosts.map((post) => post.id!).where((id) => id != null).toList();
      final excludedPosts = {...allViewedPosts, ...immediatePostIds}.toList();

      print('🎯 Préparation progressive - Cible: $_preloadBatchSize posts');

      // 🔥 PHASE 1 : POSTS RAPIDES (abonnements + récents)
      await _loadQuickPosts(newPostsFromSubscriptions, excludedPosts);

      // 🔥 PHASE 2 : POSTS SCORE (en background)
      _loadScorePostsInBackground(excludedPosts);

      // 🔥 PHASE 3 : FORÇAGE SI NÉCESSAIRE (en background)
      _loadForcedPostsInBackground(excludedPosts);

    } catch (e) {
      print('❌ Erreur préparation progressive: $e');
      _isPreparingPosts = false;
    }
  }

// 🔥 PHASE 1 : POSTS RAPIDES (abonnements + récents)
  Future<void> _loadQuickPosts(List<String> subscriptionPosts, List<String> excludedPosts) async {
    try {
      final Set<String> quickPosts = Set();

      // 1. ABONNEMENTS (très rapide)
      final subscriptionIds = await _getSubscriptionPostsRecursive(
          subscriptionPosts,
          excludedPosts,
          limit: FeedConfig.subscriptionLimit,
          excludedIds: []
      );
      quickPosts.addAll(subscriptionIds);
      print('📨 Phase rapide - Abonnements: ${subscriptionIds.length}');

      // 2. POSTS RÉCENTS (rapide)
      if (quickPosts.length < _preloadBatchSize) {
        final needed = _preloadBatchSize - quickPosts.length;
        final recentIds = await _getRecentPostIdsRecursive(
            limit: min(needed, 10),
            excludeIds: excludedPosts,
            excludedIds: quickPosts.toList(),
            attempt: 1
        );
        quickPosts.addAll(recentIds);
        print('🆕 Phase rapide - Récents: ${recentIds.length}');
      }

      // 🔥 METTRE À JOUR IMMÉDIATEMENT LES POSTS DISPONIBLES
      if (quickPosts.isNotEmpty) {
        final newPosts = quickPosts.where((id) => !_availablePostIds.contains(id)).toList();
        _availablePostIds.addAll(newPosts);

        // Mélanger pour variété
        _availablePostIds.shuffle();

        print('🚀 Posts rapides disponibles: ${_availablePostIds.length}');

        // Notifier que de nouveaux posts sont prêts
        _notifyNewPostsAvailable();
      }

    } catch (e) {
      print('❌ Erreur phase rapide: $e');
    }
  }

// 🔥 PHASE 2 : POSTS PAR SCORE (background)
  void _loadScorePostsInBackground(List<String> excludedPosts) async {
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      try {
        if (_availablePostIds.length >= _preloadBatchSize) return;

        final needed = _preloadBatchSize - _availablePostIds.length;
        final scoreLimit = min(needed, FeedConfig.scoreLimit);

        print('📊 Début phase score - Besoin: $needed posts');

        final highScorePosts = await _getPostsByScoreRecursive(
            limit: scoreLimit ~/ 3,
            minScore: 0.7,
            maxScore: 1.0,
            excludeIds: excludedPosts,
            excludedIds: _availablePostIds.toList(),
            attempt: 1
        );

        final mediumScorePosts = await _getPostsByScoreRecursive(
            limit: scoreLimit ~/ 3,
            minScore: 0.4,
            maxScore: 0.7,
            excludeIds: excludedPosts,
            excludedIds: _availablePostIds.toList(),
            attempt: 1
        );

        final lowScorePosts = await _getPostsByScoreRecursive(
            limit: scoreLimit ~/ 3,
            minScore: 0.0,
            maxScore: 0.4,
            excludeIds: excludedPosts,
            excludedIds: _availablePostIds.toList(),
            attempt: 1
        );

        final allScorePosts = [...highScorePosts, ...mediumScorePosts, ...lowScorePosts];

        if (allScorePosts.isNotEmpty) {
          _availablePostIds.addAll(allScorePosts);
          _availablePostIds.shuffle();

          print('📊 Phase score terminée: +${allScorePosts.length} posts (Total: ${_availablePostIds.length})');
          _notifyNewPostsAvailable();
        }

        // 🔥 LANÇER LA PHASE 3 SI TOUJOURS BESOIN
        if (_availablePostIds.length < FeedConfig.minPostsForForce) {
          _loadForcedPostsInBackground(excludedPosts);
        }

      } catch (e) {
        print('❌ Erreur phase score: $e');
      }
    });
  }

// 🔥 PHASE 3 : FORÇAGE (background)
  void _loadForcedPostsInBackground(List<String> excludedPosts) async {
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      try {
        if (_availablePostIds.length >= _preloadBatchSize) return;

        final needed = _preloadBatchSize - _availablePostIds.length;
        print('💥 Début phase forçage - Besoin: $needed posts');

        final forcedPosts = await _getForcedPosts(
            needed * FeedConfig.forceMultiplier,
            excludedIds: [...excludedPosts, ..._availablePostIds]
        );

        if (forcedPosts.isNotEmpty) {
          _availablePostIds.addAll(forcedPosts);
          _availablePostIds.shuffle();

          print('💥 Phase forçage terminée: +${forcedPosts.length} posts (Total: ${_availablePostIds.length})');
          _notifyNewPostsAvailable();
        }

        // 🔥 MARQUER LA FIN DE LA PRÉPARATION
        _isPreparingPosts = false;
        print('🎯 Préparation progressive terminée: ${_availablePostIds.length} posts disponibles');

      } catch (e) {
        print('❌ Erreur phase forçage: $e');
        _isPreparingPosts = false;
      }
    });
  }

// 🔥 NOTIFIER QUE DE NOUVEAUX POSTS SONT DISPONIBLES
  void _notifyNewPostsAvailable() {
    // Cette méthode peut être utilisée pour notifier les listeners si besoin
    print('🆕 Nouveaux posts disponibles: ${_availablePostIds.length}');
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

  // 🔥 PRÉPARATION DES IDs INITIAUX - VERSION OPTIMISÉE POUR 25 POSTS
// Dans MixedFeedService - Modifier _prepareInitialPostIds
  Future<void> _prepareInitialPostIds(String currentUserId) async {
    try {
      print('🎯 Préparation des IDs de posts - Cible: $_preloadBatchSize posts...');

      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final newPostsFromSubscriptions = List<String>.from(userData['newPostsFromSubscriptions'] ?? []);
      final viewedPostIds = List<String>.from(userData['viewedPostIds'] ?? []);

      // 🔥 RÉDUIRE LES EXCLUSIONS : Garder seulement les 100 derniers posts vus
      final recentViewedPosts = viewedPostIds.length > 100
          ? viewedPostIds.sublist(viewedPostIds.length - 100)
          : viewedPostIds;

      final localViewedPosts = await LocalViewedPostsService.getViewedPosts();

      // 🔥 LIMITER AUSSI LES POSTS LOCAUX VUS
      final recentLocalViewed = localViewedPosts.length > 50
          ? localViewedPosts.sublist(localViewedPosts.length - 50)
          : localViewedPosts;

      // 🔥 EXCLUSIONS MINIMALES : Posts immédiats + vus récents
      final immediatePostIds = _immediatePosts.map((post) => post.id!).where((id) => id != null).toList();
      final excludedPosts = {...recentViewedPosts, ...recentLocalViewed, ...immediatePostIds}.toList();

      print('👀 Posts exclus réduits: ${excludedPosts.length} (dont ${immediatePostIds.length} immédiats)');

      // 🔥 ALGORITHME AMÉLIORÉ AVEC FALLBACK
      final Set<String> allPostIds = Set();
      int attempts = 0;
      final int maxAttempts = FeedConfig.maxPreparationAttempts;

      while (allPostIds.length < _preloadBatchSize && attempts < maxAttempts) {
        attempts++;
        print('🔄 Tentative $attempts - Posts trouvés: ${allPostIds.length}');

        final remaining = _preloadBatchSize - allPostIds.length;

        // 1. Posts d'abonnements (priorité haute)
        if (allPostIds.length < _preloadBatchSize * 0.3) {
          final subscriptionLimit = min(8, remaining);
          final subscriptionPosts = await _getSubscriptionPostsRecursive(
              newPostsFromSubscriptions,
              excludedPosts, // Utiliser les exclusions réduites
              limit: subscriptionLimit,
              excludedIds: allPostIds.toList()
          );
          allPostIds.addAll(subscriptionPosts);
          print('   📨 Abonnements: +${subscriptionPosts.length}');
        }

        // 2. Posts récents avec fallback progressif
        if (allPostIds.length < _preloadBatchSize * 0.7) {
          final recentLimit = min(10, remaining);

          // 🔥 RÉDUIRE LES EXCLUSIONS POUR LES POSTS RÉCENTS
          final recentExclusions = excludedPosts.length > 200
              ? excludedPosts.sublist(0, 200) // Limiter à 200 exclusions
              : excludedPosts;

          final recentPosts = await _getRecentPostIdsRecursive(
              limit: recentLimit,
              excludeIds: recentExclusions, // Exclusions réduites
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );
          allPostIds.addAll(recentPosts);
          print('   🆕 Récents: +${recentPosts.length}');
        }

        // 3. Posts par score
        if (allPostIds.length < _preloadBatchSize) {
          final scoreLimit = min(7, remaining);

          // 🔥 RÉDUIRE LES EXCLUSIONS POUR LES SCORES
          final scoreExclusions = excludedPosts.length > 150
              ? excludedPosts.sublist(0, 150)
              : excludedPosts;

          final highScorePosts = await _getPostsByScoreRecursive(
              limit: scoreLimit ~/ 3,
              minScore: 0.7,
              maxScore: 1.0,
              excludeIds: scoreExclusions, // Exclusions réduites
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );
          final mediumScorePosts = await _getPostsByScoreRecursive(
              limit: scoreLimit ~/ 3,
              minScore: 0.4,
              maxScore: 0.7,
              excludeIds: scoreExclusions,
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );
          final lowScorePosts = await _getPostsByScoreRecursive(
              limit: scoreLimit ~/ 3,
              minScore: 0.0,
              maxScore: 0.4,
              excludeIds: scoreExclusions,
              excludedIds: allPostIds.toList(),
              attempt: attempts
          );

          allPostIds.addAll(highScorePosts);
          allPostIds.addAll(mediumScorePosts);
          allPostIds.addAll(lowScorePosts);

          print('   📊 Scores: ${highScorePosts.length}F ${mediumScorePosts.length}M ${lowScorePosts.length}L');
        }

        // 4. 🔥 FORÇAGE INTELLIGENT : Si pas assez de posts
        if (allPostIds.length < 5 && attempts >= 1) { // Réduit à 1 tentative
          print('🚨 FORÇAGE - Recherche avec exclusions réduites...');
          final forcedLimit = min(15, _preloadBatchSize - allPostIds.length);

          // 🔥 FORÇAGE AVEC EXCLUSIONS MINIMALES
          final minimalExclusions = [...immediatePostIds]; // Uniquement les posts immédiats

          final forcedPosts = await _getForcedPosts(forcedLimit, excludedIds: minimalExclusions);
          allPostIds.addAll(forcedPosts);
          print('   💥 Forcés: +${forcedPosts.length}');
        }

        // Petit délai entre les tentatives
        if (allPostIds.length < _preloadBatchSize && attempts < maxAttempts) {
          await Future.delayed(Duration(milliseconds: FeedConfig.preparationDelayMs));
        }
      }

      print('🎯 Recherche terminée: ${allPostIds.length} posts uniques après $attempts tentatives');

      // 🔥 FILTRAGE FINAL AVEC EXCLUSIONS RÉDUITES
      final minimalExclusions = [...immediatePostIds, ...recentViewedPosts.take(50)]; // Seulement 50 derniers vus
      final finalPosts = allPostIds.where((id) => !minimalExclusions.contains(id)).toList();

      print('''
📦 RÉSULTAT FINAL:
   - Posts bruts: ${allPostIds.length}
   - Après filtrage: ${finalPosts.length}
   - Posts exclus: ${allPostIds.length - finalPosts.length}
   - Cible: $_preloadBatchSize posts
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
          .limit(limit * 2)
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
    return shuffled.take(_preloadBatchSize).toList();
  }

  // 🔥 NETTOYER LES POSTS VUS ANCIENS DANS FIRESTORE
  Future<void> _cleanupOldViewedPosts(String userId, List<String> viewedPostIds) async {
    try {
      if (viewedPostIds.length > FeedConfig.maxViewedPosts) {
        print('🧹 Nettoyage Firestore: ${viewedPostIds.length} posts vus → ${FeedConfig.maxViewedPosts}');

        // Garder seulement les posts les plus récents
        final cleanedPosts = viewedPostIds.length > FeedConfig.maxViewedPosts
            ? viewedPostIds.sublist(viewedPostIds.length - FeedConfig.maxViewedPosts)
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
      _immediatePosts.clear();
      _areImmediatePostsLoaded = false;

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

  // 🔥 CHARGEMENT DES CHRONIQUES AVEC VÉRIFICATION EXPIRATION
  Future<void> _loadChroniques() async {
    try {
      final snapshot = await firestore
          .collection('chroniques')
          .orderBy('createdAt', descending: true)
          .limit(FeedConfig.chroniquesLoadLimit)
          .get();

      final now = DateTime.now();
      final List<Chronique> validChroniques = [];
      final List<String> expiredChroniqueIds = [];

      // 🔥 PARCOURIR ET FILTRER LES CHRONIQUES
      for (final doc in snapshot.docs) {
        try {
          final chronique = Chronique.fromMap(doc.data(), doc.id);

          // Vérifier si la chronique est expirée
          if (chronique.isExpired) {
            print('🗑️ Chronique expirée détectée: ${chronique.id} - Expirée depuis: ${chronique.expiresAt.toDate()}');
            expiredChroniqueIds.add(chronique.id!);
          } else {
            // Calculer le temps restant pour debug
            final timeLeft = chronique.expiresAt.toDate().difference(now);
            print('✅ Chronique valide: ${chronique.id} - Expire dans: ${timeLeft.inHours}h ${timeLeft.inMinutes.remainder(60)}min');
            validChroniques.add(chronique);
          }
        } catch (e) {
          print('❌ Erreur parsing chronique ${doc.id}: $e');
        }
      }

      // 🔥 SUPPRESSION EFFICACE DES CHRONIQUES EXPIRÉES
      if (expiredChroniqueIds.isNotEmpty) {
        await _deleteExpiredChroniques(expiredChroniqueIds);
      }

      // 🔥 LIMITER AUX PREMIÈRES CHRONIQUES VALIDES
      _globalChroniques = validChroniques.take(FeedConfig.chroniquesDisplayLimit).toList();

      print('''
📊 CHRONIQUES CHARGÉES:
   - Total trouvées: ${snapshot.docs.length}
   - Expirées supprimées: ${expiredChroniqueIds.length}
   - Valides conservées: ${validChroniques.length}
   - Final affichées: ${_globalChroniques.length}
''');

    } catch (e) {
      print('❌ Erreur chargement chroniques: $e');
      _globalChroniques = [];
    }
  }

  // 🔥 SUPPRESSION EFFICACE PAR LOTS DES CHRONIQUES EXPIRÉES
  Future<void> _deleteExpiredChroniques(List<String> chroniqueIds) async {
    try {
      print('🧹 Suppression de ${chroniqueIds.length} chroniques expirées...');

      // Supprimer par lots
      for (int i = 0; i < chroniqueIds.length; i += FeedConfig.cleanupBatchSize) {
        final batch = firestore.batch();
        final batchIds = chroniqueIds.sublist(i, min(i + FeedConfig.cleanupBatchSize, chroniqueIds.length));

        for (final id in batchIds) {
          batch.delete(firestore.collection('chroniques').doc(id));
        }

        await batch.commit();
        print('✅ Lot ${i ~/ FeedConfig.cleanupBatchSize + 1} supprimé: ${batchIds.length} chroniques');

        // Petit délai entre les batches pour éviter les limites
        if (i + FeedConfig.cleanupBatchSize < chroniqueIds.length) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      print('🎯 Suppression terminée: ${chroniqueIds.length} chroniques expirées supprimées');

    } catch (e) {
      print('❌ Erreur suppression chroniques expirées: $e');
    }
  }

  Future<void> _loadArticles() async {
    try {
      final snapshot = await firestore
          .collection('Articles')
          .where('isBoosted', isEqualTo: true)
          .limit(FeedConfig.articlesLoadLimit)
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
          .limit(FeedConfig.canauxLoadLimit)
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

      if (newPosts.length > FeedConfig.maxViewedPosts) {
        updates['newPostsFromSubscriptions'] = newPosts.take(FeedConfig.maxViewedPosts).toList();
      }
      if (seenPosts.length > FeedConfig.maxViewedPosts) {
        updates['viewedPostIds'] = seenPosts.take(FeedConfig.maxViewedPosts).toList();
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
    _immediatePosts.clear();
    _areImmediatePostsLoaded = false;
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