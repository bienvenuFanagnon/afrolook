import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/models/model_data.dart';
import 'feed_scoring_service.dart';

class FeedInteractionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 📈 Mettre à jour le score quand un utilisateur like un post
  static Future<void> onPostLiked(Post post, String userId) async {
    try {
      // 1. Mettre à jour les données du post
      await _firestore.collection('Posts').doc(post.id).update({
        'likes': FieldValue.increment(1),
        'users_like_id': FieldValue.arrayUnion([userId]),
        'recentEngagement': FieldValue.increment(1),
      });

      // 2. Recalculer et mettre à jour le score
      await _updatePostScore(post.id!);

      printVm('✅ Like enregistré et score mis à jour pour le post ${post.id}');

    } catch (e) {
      printVm('❌ Erreur lors du like: $e');
    }
  }

  // 📈 Mettre à jour le score quand un utilisateur commente
  static Future<void> onPostCommented(Post post, String userId) async {
    try {
      // recentEngagement compte une seule interaction par user par post.
      final isFirstComment = !(post.users_comments_id?.contains(userId) ?? false);
      await _firestore.collection('Posts').doc(post.id).update({
        'comments': FieldValue.increment(1),
        'users_comments_id': FieldValue.arrayUnion([userId]),
        if (isFirstComment) 'recentEngagement': FieldValue.increment(1),
      });

      await _updatePostScore(post.id!);
      printVm('✅ Commentaire enregistré et score mis à jour');

    } catch (e) {
      printVm('❌ Erreur lors du commentaire: $e');
    }
  }

  // 📈 Mettre à jour le score quand un utilisateur partage
  static Future<void> onPostShared(Post post, String userId) async {
    try {
      await _firestore.collection('Posts').doc(post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([userId]),
        'recentEngagement': FieldValue.increment(1),
      });

      await _updatePostScore(post.id!);
      printVm('✅ Partage enregistré et score mis à jour');

    } catch (e) {
      printVm('❌ Erreur lors du partage: $e');
    }
  }

  // 📈 Mettre à jour le score quand un utilisateur aime (love)
  static Future<void> onPostLoved(Post post, String userId) async {
    try {
      // await _firestore.collection('Posts').doc(post.id).update({
      //   // 'loves': FieldValue.increment(1),
      //   // 'users_love_id': FieldValue.arrayUnion([userId]),
      //   'recentEngagement': FieldValue.increment(1),
      // });

      await _updatePostScore(post.id!);
      printVm('✅ Love enregistré et score mis à jour');

    } catch (e) {
      printVm('❌ Erreur lors du love: $e');
    }
  }

  // 🔄 Mettre à jour le score d'un post
  static Future<void> _updatePostScore(String postId) async {
    try {
      final doc = await _firestore.collection('Posts').doc(postId).get();
      if (doc.exists) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = postId;

        // Calculer le nouveau score (sans contexte utilisateur pour le score de base)
        final newScore = FeedScoringService.calculateFeedScore(post, 0);

        // Mettre à jour le score dans Firestore
        await _firestore.collection('Posts').doc(postId).update({
          'feedScore': newScore,
          'lastScoreUpdate': DateTime.now().millisecondsSinceEpoch,
        });

        printVm('📊 Score mis à jour pour $postId: $newScore');
      }
    } catch (e) {
      printVm('❌ Erreur mise à jour score: $e');
    }
  }

  // 📊 Mettre à jour les vues uniques
  static Future<void> updateUniqueViews(Post post, String userId) async {
    try {
      await _firestore.collection('Posts').doc(post.id).update({
        'uniqueViewsCount': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([userId]),
      });

      // Les vues ont un poids moindre dans le score, on peut mettre à jour moins fréquemment
      if ((post.uniqueViewsCount ?? 0) % 10 == 0) { // Toutes les 10 vues
        await _updatePostScore(post.id!);
      }

    } catch (e) {
      printVm('❌ Erreur mise à jour vues: $e');
    }
  }
}