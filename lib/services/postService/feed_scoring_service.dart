import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/model_data.dart';

class FeedScoringService {
  static double calculateFeedScore(Post post, int userLastVisitTime) {
    final double engagementWeight = 0.6;
    final double freshnessWeight = 0.3;
    final double viralityWeight = 0.1;

    return engagementWeight * _calculateEngagementScore(post) +
        freshnessWeight * _calculateFreshnessScore(post, userLastVisitTime) +
        viralityWeight * _calculateViralityScore(post);
  }

  static double _calculateEngagementScore(Post post) {
    // Normalisation logarithmique
    final double likeScore = _logNormalize(post.likes ?? 0, base: 100);
    final double commentScore = _logNormalize(post.comments ?? 0, base: 50);
    final double shareScore = _logNormalize(post.partage ?? 0, base: 25);
    final double viewScore = _logNormalize(post.vues ?? 0, base: 1000);

    return (likeScore * 0.4 + commentScore * 0.3 + shareScore * 0.2 + viewScore * 0.1);
  }

  static double _calculateFreshnessScore(Post post, int userLastVisitTime) {
    // Posts créés après la dernière visite = maximum score
    if ((post.createdAt ?? 0) > userLastVisitTime) {
      return 1.0;
    }

    // Décroissance exponentielle
    final int postAge = DateTime.now().millisecondsSinceEpoch - (post.createdAt ?? 0);
    final double ageInHours = postAge / (1000 * 3600);
    return _exponentialDecay(ageInHours, halfLife: 168); // Demi-vie de 1 semaine
  }

  static double _calculateViralityScore(Post post) {
    if (post.vues == null || post.vues! <= 10) return 0.0;

    final double engagementRate = ((post.likes ?? 0) + (post.comments ?? 0) + (post.partage ?? 0)) / post.vues!;
    final double virality = engagementRate * _logNormalize(post.vues!, base: 1000);

    return virality.clamp(0.0, 1.0);
  }

  static double _logNormalize(int value, {required double base}) {
    if (value <= 0) return 0.0;
    return log(value + 1) / log(base + 1);
  }

  static double _exponentialDecay(double ageInHours, {required double halfLife}) {
    return exp(-ageInHours / halfLife);
  }

  // Méthode pour mettre à jour le score d'un post
  static Future<void> updatePostScore(Post post) async {
    final newScore = calculateFeedScore(post, 0); // Score de base

    // Mettre à jour dans Firestore
    await FirebaseFirestore.instance
        .collection('Posts')
        .doc(post.id)
        .update({
      'feedScore': newScore,
      'lastScoreUpdate': DateTime.now().millisecondsSinceEpoch,
      'recentEngagement': (post.likes ?? 0) + (post.comments ?? 0) + (post.partage ?? 0)
    });
  }
}