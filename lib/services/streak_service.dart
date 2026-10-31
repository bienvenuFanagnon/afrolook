import 'package:afrotok/services/api/users_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StreakResult {
  final bool quotaReached;
  final bool streakSaved;
  final bool shieldUsed;
  final bool alreadyCounted;
  final int currentStreak;
  final int todayCount;
  final int shields;

  const StreakResult({
    required this.quotaReached,
    required this.streakSaved,
    required this.shieldUsed,
    required this.alreadyCounted,
    required this.currentStreak,
    required this.todayCount,
    required this.shields,
  });
}

class StreakService {
  static const int _dailyQuota = 3;

  static StreakResult _fromApi(Map<String, dynamic> st, {required int previousToday, required int previousStreak, bool alreadyCounted = false}) {
    final today = (st['today_count'] as num?)?.toInt() ?? 0;
    final streak = (st['streak'] as num?)?.toInt() ?? 0;
    final quota = (st['quota'] as num?)?.toInt() ?? _dailyQuota;
    return StreakResult(
      quotaReached: !alreadyCounted && today >= quota && previousToday < quota,
      streakSaved: false,
      shieldUsed: false,
      alreadyCounted: alreadyCounted,
      currentStreak: streak,
      todayCount: today,
      shields: (st['shields'] as num?)?.toInt() ?? 0,
    );
  }

  /// Appelé après chaque commentaire envoyé avec succès. La série est calculée par le SERVEUR (au moment du commentaire) :
  /// ici on relit seulement l'état (`GET /v1/streak`) pour piloter le toast de célébration.
  static Future<StreakResult> onCommentSent({
    required String userId,
    required String postId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final previousToday = prefs.getInt('streak_today_count_$userId') ?? 0;
    final previousStreak = prefs.getInt('streak_current_$userId') ?? 0;
    final st = await UsersApi.streak();
    final r = _fromApi(st, previousToday: previousToday, previousStreak: previousStreak, alreadyCounted: ((st['today_count'] as num?)?.toInt() ?? 0) == previousToday);
    await prefs.setInt('streak_today_count_$userId', r.todayCount);
    await prefs.setInt('streak_current_$userId', r.currentStreak);
    await prefs.setInt('streak_shields_$userId', r.shields);
    return r;
  }

  /// Plus rien à faire au démarrage : le serveur remet la série à jour (boucliers compris) à chaque lecture.
  static Future<void> checkAndResetDaily(String userId) async {}

  /// Plus rien à initialiser : la série est créée par le serveur.
  static Future<void> initIfNeeded(String userId) async {}

  /// État actuel de la série (API), ou null en cas d'erreur.
  static Future<StreakResult?> fetch() async {
    try {
      final st = await UsersApi.streak();
      return _fromApi(st, previousToday: 0, previousStreak: 0, alreadyCounted: true);
    } catch (_) {
      return null;
    }
  }

  /// Retourne le niveau de flamme (0-5) selon la série.
  static int streakLevel(int streak) {
    if (streak == 0) return 0;
    if (streak < 3) return 1;
    if (streak < 7) return 2;
    if (streak < 14) return 3;
    if (streak < 30) return 4;
    return 5;
  }

  /// Label du niveau.
  static String streakLevelLabel(int level) {
    const labels = ['Froid', 'Tiède', 'Chaud', 'Enflammé', 'Brûlant', 'Légendaire'];
    return labels[level.clamp(0, 5)];
  }
}
