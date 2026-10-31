import 'package:afrotok/services/api/users_api.dart';
import 'package:flutter/foundation.dart';
import '../services/streak_service.dart';

class StreakProvider extends ChangeNotifier {
  int commentStreak = 0;
  int bestStreak = 0;
  int todayCount = 0;
  int shields = 0;
  int level = 0;
  String levelLabel = 'Froid';

  /// Charge l'état de la série depuis l'API (le serveur la tient à jour et applique les boucliers).
  Future<void> listenToUser(String userId) async {
    try {
      final st = await UsersApi.streak();
      commentStreak = (st['streak'] as num?)?.toInt() ?? 0;
      bestStreak = (st['best'] as num?)?.toInt() ?? 0;
      shields = (st['shields'] as num?)?.toInt() ?? 0;
      todayCount = (st['today_count'] as num?)?.toInt() ?? 0;
      level = StreakService.streakLevel(commentStreak);
      levelLabel = StreakService.streakLevelLabel(level);
      notifyListeners();
    } catch (_) {/* l'état précédent est conservé */}
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Pré-remplit le provider depuis les données déjà chargées dans UserData
  /// (cache local). Évite l'affichage à 0 lors de l'ouverture du modal avant
  /// que le stream Firestore n'ait répondu.
  void seedFromUserData({
    required int commentStreak,
    required int bestCommentStreak,
    required int streakShields,
    required int todayCommentCount,
    String? todayCommentDate,
  }) {
    this.commentStreak = commentStreak;
    bestStreak = bestCommentStreak;
    shields = streakShields;
    final todayStr = _todayStr();
    todayCount = (todayCommentDate == todayStr) ? todayCommentCount : 0;
    level = StreakService.streakLevel(this.commentStreak);
    levelLabel = StreakService.streakLevelLabel(level);
    notifyListeners();
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

}
