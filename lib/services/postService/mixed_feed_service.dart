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
import 'package:afrotok/providers/postProvider.dart';

class MixedFeedService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final UserAuthProvider authProvider;
  final CategorieProduitProvider categorieProvider;
  final PostProvider postProvider;
  final ChroniqueProvider chroniqueProvider;
  final ContentProvider contentProvider;

  // Service de notification pour les abonnés
  final MassNotificationService _notificationService = MassNotificationService();

  // 🔥 NOUVEAU: Cache des IDs préparés
  List<String> _preparedPostIds = [];
  int _currentIndex = 0;
  static const int _preloadBatchSize = 100;

  // 🔥 CONTENU GLOBAL
  List<ArticleData> _globalArticles = [];
  List<Canal> _globalCanaux = [];
  List<Chronique> _globalChroniques = [];
  bool _hasLoadedGlobalContent = false;

  MixedFeedService({
    required this.authProvider,
    required this.categorieProvider,
    required this.postProvider,
    required this.chroniqueProvider,
    required this.contentProvider,
  });

  // 🔥 INITIALISATION DU CONTENU GLOBAL
  Future<void> loadGlobalContent() async {
    if (_hasLoadedGlobalContent) return;

    try {
      print('🌍 Chargement du contenu global...');

      // Charger en parallèle
      await Future.wait([
        _loadChroniques(),
        _loadArticles(),
        _loadCanaux(),
      ]);

      _hasLoadedGlobalContent = true;
      print('✅ Contenu global chargé: ${_globalChroniques.length} chroniques, ${_globalArticles.length} articles, ${_globalCanaux.length} canaux');

    } catch (e) {
      print('❌ Erreur chargement contenu global: $e');
    }
  }

  Future<void> _loadChroniques() async {
    try {
      final snapshot = await firestore
          .collection('Chroniques')
          // .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      _globalChroniques = snapshot.docs.map((doc) {
        return Chronique.fromMap(doc.data(),doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur chroniques: $e');
    }
  }

  Future<void> _loadArticles() async {
    try {
      final snapshot = await firestore
          .collection('Articles')
          .where('isBoosted', isEqualTo: true)
          // .orderBy('boostedUntil', descending: true)
          .limit(4)
          .get();

      _globalArticles = snapshot.docs.map((doc) {
        return ArticleData.fromJson({'id': doc.id, ...doc.data()});
      }).toList();
    } catch (e) {
      print('❌ Erreur articles: $e');
    }
  }

  Future<void> _loadCanaux() async {
    try {
      final snapshot = await firestore
          .collection('Canaux')
          // .where('isActive', isEqualTo: true)
          // .orderBy('subscribersCount', descending: true)
          .limit(6)
          .get();

      _globalCanaux = snapshot.docs.map((doc) {
        return Canal.fromJson({'id': doc.id, ...doc.data()});
      }).toList();
    } catch (e) {
      print('❌ Erreur canaux: $e');
    }
  }

  // 🔥 ALGORITHME INTELLIGENT AVEC PRÉ-CHARGEMENT
  Future<List<Post>> loadSmartFeed({bool loadMore = false}) async {
    try {
      print('🧠 Chargement feed intelligent - LoadMore: $loadMore');

      // Charger le contenu global en background
      if (!_hasLoadedGlobalContent) {
        WidgetsBinding.instance?.addPostFrameCallback((_) {
          loadGlobalContent();
        });
      }

      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) {
        print('❌ Utilisateur non connecté');
        return [];
      }

      // 🔥 STRATÉGIE: Préparer les IDs une fois, puis les utiliser par lots
      if (!loadMore || _preparedPostIds.isEmpty || _currentIndex >= _preparedPostIds.length - 10) {
        await _prepareInitialPostIds(currentUserId);
      }

      if (_preparedPostIds.isEmpty) {
        print('📭 Aucun post à charger');
        return [];
      }

      // 🔥 CHARGER LE LOT ACTUEL
      final posts = await _loadCurrentBatch();

      print('✅ Feed chargé: ${posts.length} posts (index: $_currentIndex/total: ${_preparedPostIds.length})');
      return posts;

    } catch (e) {
      print('❌ Erreur chargement feed: $e');
      return [];
    }
  }

  // 🔥 PRÉPARATION DES IDs INITIAUX (100+ posts)
  Future<void> _prepareInitialPostIds(String currentUserId) async {
    try {
      print('🎯 Préparation des IDs de posts...');

      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final newPostsFromSubscriptions = List<String>.from(userData['newPostsFromSubscriptions'] ?? []);
      final viewedPostIds = List<String>.from(userData['viewedPostIds'] ?? []);

      // 🔥 ALGORITHME AMÉLIORÉ POUR 100+ POSTS
      final List<String> allPostIds = [];

      // 1. Posts d'abonnements non vus (30%)
      final subscriptionPosts = await _getSubscriptionPosts(newPostsFromSubscriptions, viewedPostIds, limit: 30);
      allPostIds.addAll(subscriptionPosts);

      // 2. Posts récents (30%)
      final recentPosts = await _getRecentPostIds(30, excludeIds: viewedPostIds);
      allPostIds.addAll(recentPosts);

      // 3. Posts par score (40% - mélangés)
      final highScorePosts = await _getPostsByScore(15, 0.7, 1.0, excludeIds: viewedPostIds);
      final mediumScorePosts = await _getPostsByScore(15, 0.4, 0.7, excludeIds: viewedPostIds);
      final lowScorePosts = await _getPostsByScore(10, 0.0, 0.4, excludeIds: viewedPostIds);

      allPostIds.addAll(highScorePosts);
      allPostIds.addAll(mediumScorePosts);
      allPostIds.addAll(lowScorePosts);

      // 🔥 MÉLANGER ET LIMITER
      allPostIds.shuffle(Random());
      _preparedPostIds = allPostIds.take(_preloadBatchSize).toList();
      _currentIndex = 0;

      print('📦 IDs préparés: ${_preparedPostIds.length} posts');
      print('📊 Composition: ${subscriptionPosts.length} abonnements, ${recentPosts.length} récents, ${highScorePosts.length}F ${mediumScorePosts.length}M ${lowScorePosts.length}L');

    } catch (e) {
      print('❌ Erreur préparation IDs: $e');
      _preparedPostIds = [];
    }
  }

  // 🔥 CHARGEMENT DU LOT ACTUEL (8-12 posts)
  Future<List<Post>> _loadCurrentBatch() async {
    final batchSize = 8; // Taille optimisée
    final endIndex = min(_currentIndex + batchSize, _preparedPostIds.length);

    if (_currentIndex >= _preparedPostIds.length) {
      return [];
    }

    final batchIds = _preparedPostIds.sublist(_currentIndex, endIndex);
    _currentIndex = endIndex;

    final posts = await _loadPostsByIds(batchIds);

    // 🔥 MARQUER COMME VUS AU FUR ET À MESURE
    for (final post in posts) {
      if (post.id != null) {
        await markPostAsSeen(post.id!);
      }
    }

    return posts;
  }

  // 🔥 MÉTHODES OPTIMISÉES POUR LA RÉCUPÉRATION
  Future<List<String>> _getSubscriptionPosts(List<String> subscriptionPosts, List<String> viewedPostIds, {required int limit}) async {
    final unseenPosts = subscriptionPosts.where((id) => !viewedPostIds.contains(id)).toList();

    if (unseenPosts.length >= limit) {
      return unseenPosts.take(limit).toList();
    }

    // Compléter avec d'autres posts si nécessaire
    final needed = limit - unseenPosts.length;
    if (needed > 0) {
      final additionalPosts = await _getRecentPostIds(needed, excludeIds: viewedPostIds);
      unseenPosts.addAll(additionalPosts);
    }

    return unseenPosts.take(limit).toList();
  }

  Future<List<String>> _getRecentPostIds(int limit, {List<String> excludeIds = const []}) async {
    try {
      final whereNotIn = excludeIds.isEmpty ? [''] : excludeIds.take(10).toList();

      final snapshot = await firestore
          .collection('Posts')
          .where('id', whereNotIn: whereNotIn)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Erreur posts récents: $e');
      return [];
    }
  }

  Future<List<String>> _getPostsByScore(int limit, double minScore, double maxScore, {List<String> excludeIds = const []}) async {
    try {
      final whereNotIn = excludeIds.isEmpty ? [''] : excludeIds.take(10).toList();

      final snapshot = await firestore
          .collection('Posts')
          .where('feedScore', isGreaterThanOrEqualTo: minScore)
          .where('feedScore', isLessThan: maxScore)
          .where('id', whereNotIn: whereNotIn)
          .orderBy('feedScore', descending: minScore > 0.5)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Erreur posts par score: $e');
      return [];
    }
  }

  Future<List<Post>> _loadPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    final List<Post> posts = [];

    try {
      // Charger par lots de 10 pour éviter les limites Firebase
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

  // 🔥 RÉINITIALISATION
  Future<void> reset() async {
    _preparedPostIds.clear();
    _currentIndex = 0;
    _hasLoadedGlobalContent = false;
    print('🔄 Service réinitialisé');
  }

  // 🔥 GETTERS POUR LE CONTENU GLOBAL
  List<ArticleData> get articles => _globalArticles;
  List<Canal> get canaux => _globalCanaux;
  List<Chronique> get chroniques => _globalChroniques;
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