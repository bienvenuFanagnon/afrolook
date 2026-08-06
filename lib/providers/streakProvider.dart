import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/streak_service.dart';

class StreakProvider extends ChangeNotifier {
  int commentStreak = 0;
  int bestStreak = 0;
  int todayCount = 0;
  int shields = 0;
  int level = 0;
  String levelLabel = 'Froid';

  StreamSubscription<DocumentSnapshot>? _subscription;

  /// Écoute le document Firestore de l'utilisateur pour rester à jour en temps réel.
  void listenToUser(String userId) {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data()!;
      commentStreak = (data['commentStreak'] as num?)?.toInt() ?? 0;
      bestStreak = (data['bestCommentStreak'] as num?)?.toInt() ?? 0;
      shields = (data['streakShields'] as num?)?.toInt() ?? 0;

      // Sécurité : si todayCommentDate != aujourd'hui (Firestore pas encore mis à jour
      // par checkAndResetDaily), afficher 0 pour ne pas montrer le count d'hier.
      final todayStr = _todayStr();
      final firestoreDate = data['todayCommentDate'] as String?;
      todayCount = (firestoreDate == todayStr)
          ? (data['todayCommentCount'] as num?)?.toInt() ?? 0
          : 0;

      level = StreakService.streakLevel(commentStreak);
      levelLabel = StreakService.streakLevelLabel(level);
      notifyListeners();
    });
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Mise à jour immédiate depuis un [StreakResult] (avant que le stream revienne).
  void updateFromResult(StreakResult result) {
    commentStreak = result.currentStreak;
    todayCount = result.todayCount;
    shields = result.shields;
    level = StreakService.streakLevel(commentStreak);
    levelLabel = StreakService.streakLevelLabel(level);
    if (commentStreak > bestStreak) bestStreak = commentStreak;
    notifyListeners();
  }

  /// Nombre de posts encore nécessaires pour valider le quota du jour (max 3).
  int get remainingToday => (3 - todayCount).clamp(0, 3);

  /// Le quota du jour est atteint.
  bool get quotaReachedToday => todayCount >= 3;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
