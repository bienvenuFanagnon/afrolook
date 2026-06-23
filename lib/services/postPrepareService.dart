// Service de préparation des posts - VERSION CORRIGÉE

import 'package:afrotok/pages/component/consoleWidget.dart';
import 'dart:math' as Math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/model_data.dart';

class PostPreparationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<String>> preparePostsForUser(String? userId, {int maxPosts = 50}) async {
    try {
      printVm('🚀 ========= PRÉPARATION POSTS =========');
      printVm('👤 Utilisateur: ${userId ?? "Anonyme"}');

      if (userId == null) {
        return await _preparePostsForAnonymousUser(maxPosts);
      }

      return await _preparePostsForLoggedInUser(userId, maxPosts);

    } catch (e) {
      printVm('❌ Erreur préparation posts: $e');
      return await _getFallbackPosts(maxPosts);
    }
  }

  static Future<List<String>> _preparePostsForLoggedInUser(String userId, int maxPosts) async {
    final stopwatch = Stopwatch()..start();

    // 1. Récupérer les données utilisateur
    final userData = await _getUserData(userId);
    final followingIds = userData.userAbonnesIds ?? [];
    final viewedPostIds = userData.viewedPostIds ?? [];

    printVm('📋 DONNÉES UTILISATEUR:');
    printVm('   - Abonnements: ${followingIds.length}');
    printVm('   - Posts déjà vus: ${viewedPostIds.length}');

    // 2. Récupérer les posts récents
    final recentPosts = await _getRecentPostsOnly(200);
    printVm('📝 POSTS RÉCENTS: ${recentPosts.length}');

    // 3. Appliquer l'algorithme de priorité
    final preparedPosts = await _applyPriorityAlgorithm(
        recentPosts,
        followingIds,
        viewedPostIds,
        maxPosts
    );

    printVm('✅ PRÉPARATION TERMINÉE: ${preparedPosts.length} posts');
    stopwatch.stop();

    return preparedPosts;
  }

  static Future<List<String>> _applyPriorityAlgorithm(
      List<Post> posts,
      List<String> followingIds,
      List<String> viewedPostIds,
      int maxPosts
      ) async {

    // Catégoriser les posts
    final Map<String, List<Post>> postsByUser = {};
    final List<Post> followingUnseen = [];
    final List<Post> followingSeen = [];
    final List<Post> otherUnseen = [];
    final List<Post> otherSeen = [];

    for (final post in posts) {
      if (post.user_id == null || post.id == null) continue;

      // Grouper par utilisateur
      postsByUser.putIfAbsent(post.user_id!, () => []);
      postsByUser[post.user_id]!.add(post);

      final isUnseen = !viewedPostIds.contains(post.id);
      final isFollowing = followingIds.contains(post.user_id);

      if (isFollowing) {
        if (isUnseen) {
          followingUnseen.add(post);
        } else {
          followingSeen.add(post);
        }
      } else {
        if (isUnseen) {
          otherUnseen.add(post);
        } else {
          otherSeen.add(post);
        }
      }
    }

    printVm('📊 CATÉGORISATION:');
    printVm('   - Abonnements non vus: ${followingUnseen.length}');
    printVm('   - Abonnements vus: ${followingSeen.length}');
    printVm('   - Autres non vus: ${otherUnseen.length}');
    printVm('   - Autres vus: ${otherSeen.length}');

    // Préparer les posts selon la priorité
    final preparedPosts = <String>[];
    final usedUsers = <String>{};

    // Fonction pour prendre le post le plus récent d'un utilisateur
    String? takeLatestPostFromUser(String userId) {
      if (usedUsers.contains(userId)) return null;

      final userPosts = postsByUser[userId];
      if (userPosts == null || userPosts.isEmpty) return null;

      // Prendre le post le plus récent
      userPosts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      final latestPost = userPosts.first;

      usedUsers.add(userId);
      return latestPost.id;
    }

    // PHASE 1: Posts non vus des abonnements (priorité maximale)
    printVm('\n🎯 PHASE 1: Posts non vus abonnements');
    for (final post in followingUnseen) {
      if (preparedPosts.length >= maxPosts) break;

      final postId = takeLatestPostFromUser(post.user_id!);
      if (postId != null) {
        preparedPosts.add(postId);
        printVm('   ✅ Ajouté: ${post.id} (abonnement non vu)');
      }
    }

    // PHASE 2: Posts non vus des autres utilisateurs
    printVm('\n🎯 PHASE 2: Posts non vus autres');
    for (final post in otherUnseen) {
      if (preparedPosts.length >= maxPosts) break;

      final postId = takeLatestPostFromUser(post.user_id!);
      if (postId != null) {
        preparedPosts.add(postId);
        printVm('   ✅ Ajouté: ${post.id} (autre non vu)');
      }
    }

    // PHASE 3: Posts vus des abonnements (si besoin)
    if (preparedPosts.length < maxPosts) {
      printVm('\n🎯 PHASE 3: Posts vus abonnements');
      for (final post in followingSeen) {
        if (preparedPosts.length >= maxPosts) break;

        final postId = takeLatestPostFromUser(post.user_id!);
        if (postId != null) {
          preparedPosts.add(postId);
          printVm('   🔄 Ajouté: ${post.id} (abonnement vu)');
        }
      }
    }

    // PHASE 4: Posts vus des autres (si besoin)
    if (preparedPosts.length < maxPosts) {
      printVm('\n🎯 PHASE 4: Posts vus autres');
      for (final post in otherSeen) {
        if (preparedPosts.length >= maxPosts) break;

        final postId = takeLatestPostFromUser(post.user_id!);
        if (postId != null) {
          preparedPosts.add(postId);
          printVm('   🔄 Ajouté: ${post.id} (autre vu)');
        }
      }
    }

    printVm('\n📦 RÉSULTAT FINAL: ${preparedPosts.length} posts');
    printVm('   - Priorité: Non vus abonnements > Non vus autres > Vus abonnements > Vus autres');

    return preparedPosts.take(maxPosts).toList();
  }

  static Future<UserData> _getUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      return userDoc.exists
          ? UserData.fromJson(userDoc.data() as Map<String, dynamic>)
          : UserData(viewedPostIds: [], userAbonnesIds: []);
    } catch (e) {
      printVm('⚠️ Erreur récupération user data: $e');
      return UserData(viewedPostIds: [], userAbonnesIds: []);
    }
  }

  static Future<List<Post>> _getRecentPostsOnly(int limit) async {
    try {
      final oneMonthAgo = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;

      final postsSnapshot = await _firestore
          .collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name)
          .where("created_at", isGreaterThan: oneMonthAgo)
          .orderBy("created_at", descending: true)
          .limit(limit)
          .get();

      return postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data());
        post.id = doc.id;
        return post;
      }).toList();
    } catch (e) {
      printVm('⚠️ Fallback: récupération tous posts récents');
      final postsSnapshot = await _firestore
          .collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name)
          .orderBy("created_at", descending: true)
          .limit(limit)
          .get();

      return postsSnapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data());
        post.id = doc.id;
        return post;
      }).toList();
    }
  }

  static Future<List<String>> _preparePostsForAnonymousUser(int maxPosts) async {
    printVm('🔓 Mode utilisateur anonyme');
    final posts = await _firestore
        .collection('Posts')
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("type", isEqualTo: PostType.POST.name)
        .orderBy("created_at", descending: true)
        .limit(maxPosts)
        .get();

    return posts.docs.map((doc) => doc.id).toList();
  }

  static Future<List<String>> _getFallbackPosts(int maxPosts) async {
    printVm('🔄 Fallback rapide');
    final posts = await _firestore
        .collection('Posts')
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("type", isEqualTo: PostType.POST.name)
        .orderBy("created_at", descending: true)
        .limit(maxPosts)
        .get();

    return posts.docs.map((doc) => doc.id).toList();
  }
}

// AppInitializer avec rafraîchissement
class AppInitializer {
  static List<String> preparedPostIds = [];
  static List<String> backgroundPostIds = [];
  static bool isPostsPrepared = false;
  static bool isBackgroundPreparationDone = false;
  static DateTime? lastPreparationTime;

  static Future<void> initializeApp({String? userId, bool isRefresh = false}) async {
    if (isRefresh) {
      printVm('\n🔄 ========= RAFRAÎCHISSEMENT =========');
      preparedPostIds = [];
      isPostsPrepared = false;
      isBackgroundPreparationDone = false;
    } else {
      printVm('\n🎪 ========= INITIALISATION =========');
    }

    printVm('👤 ID: ${userId ?? "Anonyme"}');

    final stopwatch = Stopwatch()..start();

    try {
      // Préparation initiale (16 posts)
      preparedPostIds = await PostPreparationService.preparePostsForUser(
          userId,
          maxPosts: 16
      );

      isPostsPrepared = true;
      lastPreparationTime = DateTime.now();

      printVm('✅ ${preparedPostIds.length} posts préparés en ${stopwatch.elapsedMilliseconds}ms');

      // Lancer la préparation en arrière-plan pour les 50 posts
      _startBackgroundPreparation(userId);

    } catch (e) {
      printVm('❌ Erreur: $e');
      preparedPostIds = await _getUltraFastFallback();
      isPostsPrepared = true;
      _startBackgroundPreparation(userId);
    }

    stopwatch.stop();
  }

  static void _startBackgroundPreparation(String? userId) {
    Future.microtask(() async {
      try {
        printVm('🔄 Début préparation arrière-plan...');
        backgroundPostIds = await PostPreparationService.preparePostsForUser(
            userId,
            maxPosts: 50
        );
        isBackgroundPreparationDone = true;
        printVm('✅ Préparation arrière-plan terminée: ${backgroundPostIds.length} posts');

      } catch (e) {
        printVm('❌ Erreur préparation arrière-plan: $e');
      }
    });
  }

  static Future<List<String>> _getUltraFastFallback() async {
    final posts = await FirebaseFirestore.instance
        .collection('Posts')
        .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
        .where("type", isEqualTo: PostType.POST.name)
        .orderBy("created_at", descending: true)
        .limit(16)
        .get();

    return posts.docs.map((doc) => doc.id).toList();
  }

  static List<String> getPreparedPostIds() {
    if (!isPostsPrepared) return [];
    return List.from(preparedPostIds);
  }

  static bool hasMorePosts() {
    return isBackgroundPreparationDone && backgroundPostIds.length > preparedPostIds.length;
  }

  static List<String> getMorePosts() {
    if (!hasMorePosts()) return [];

    final newPosts = backgroundPostIds.skip(preparedPostIds.length).take(8).toList();
    preparedPostIds.addAll(newPosts);

    printVm('📥 Chargement posts supplémentaires: ${newPosts.length}');
    return newPosts;
  }

  // Nouvelle méthode pour le rafraîchissement
  static Future<void> refreshPosts({String? userId}) async {
    await initializeApp(userId: userId, isRefresh: true);
  }
}