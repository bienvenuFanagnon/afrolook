import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/model_data.dart';
import 'feed_scoring_service.dart';

class IntelligentFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Post>> getFeed({
    required String userId,
    required int userLastVisitTime,
    int limit = 20,
    bool useIntelligentAlgorithm = true,
  }) async {
    try {
      if (useIntelligentAlgorithm) {
        return await _getIntelligentFeed(userId, userLastVisitTime, limit);
      } else {
        // Fallback: ancien système chronologique
        return await _getChronologicalFeed(limit);
      }
    } catch (e) {
      print('Error loading feed: $e');
      return await _getChronologicalFeed(limit);
    }
  }

  Future<List<Post>> _getIntelligentFeed(
      String userId,
      int userLastVisitTime,
      int limit
      ) async {
    // Récupérer les posts avec pagination
    final snapshot = await _firestore
        .collection('Posts')
        .where('status', isNotEqualTo: 'SUPPRIMER')
        .orderBy('feedScore', descending: true)
        .limit(limit)
        .get();

    final posts = snapshot.docs.map((doc) {
      final post = Post.fromJson(doc.data());
      post.id = doc.id;
      return post;
    }).toList();

    // Calcul des scores en temps réel avec contexte utilisateur
    for (final post in posts) {
      final realTimeScore = FeedScoringService.calculateFeedScore(post, userLastVisitTime);
      post.feedScore = realTimeScore;
    }

    // Tri final par score temps réel
    posts.sort((a, b) => b.feedScore!.compareTo(a.feedScore!));

    return posts;
  }

  Future<List<Post>> _getChronologicalFeed(int limit) async {
    final snapshot = await _firestore
        .collection('Posts')
        .where('status', isNotEqualTo: 'SUPPRIMER')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final post = Post.fromJson(doc.data() as Map<String, dynamic>);
      post.id = doc.id;
      return post;
    }).toList();
  }

  // Mettre à jour le timestamp de visite utilisateur
  Future<void> updateUserLastVisit(String userId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _firestore
        .collection('Users')
        .doc(userId)
        .update({
      'lastFeedVisitTime': now
    });
  }
}