import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const int _maxShields = 3;
  static const int _shieldEarnIntervalDays = 7;

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Appelé après chaque commentaire envoyé avec succès.
  /// Retourne un [StreakResult] pour piloter le toast de célébration.
  static Future<StreakResult> onCommentSent({
    required String userId,
    required String postId,
  }) async {
    final today = _todayStr();

    // ── Déduplication locale : 1 commentaire comptant par post par jour ──────
    final prefs = await SharedPreferences.getInstance();
    final dedupKey = 'streak_comment_${postId}_${userId}_$today';
    if (prefs.getBool(dedupKey) == true) {
      final streak = prefs.getInt('streak_current_$userId') ?? 0;
      final count = prefs.getInt('streak_today_count_$userId') ?? 0;
      final shields = prefs.getInt('streak_shields_$userId') ?? 0;
      return StreakResult(
        quotaReached: false,
        streakSaved: false,
        shieldUsed: false,
        alreadyCounted: true,
        currentStreak: streak,
        todayCount: count,
        shields: shields,
      );
    }

    // ── Lire l'état courant depuis Firestore ──────────────────────────────────
    final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
    final doc = await userRef.get();
    final data = doc.data() ?? {};

    int currentStreak = (data['commentStreak'] as num?)?.toInt() ?? 0;
    int bestStreak = (data['bestCommentStreak'] as num?)?.toInt() ?? 0;
    int shields = (data['streakShields'] as num?)?.toInt() ?? 0;
    int todayCount = (data['todayCommentCount'] as num?)?.toInt() ?? 0;
    String? lastDate = data['todayCommentDate'] as String?;

    // ── Nouveau jour : calculer si la série continue ───────────────────────────
    bool streakSaved = false;
    if (lastDate != null && lastDate != today) {
      final last = DateTime.tryParse(lastDate);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final lastDay = last != null ? DateTime(last.year, last.month, last.day) : null;

      if (lastDay != null && lastDay.isAtSameMomentAs(yesterday)) {
        // Hier → série continue
        if (todayCount >= _dailyQuota) streakSaved = true;
      } else {
        // Plus d'un jour de gap → série cassée
        currentStreak = 0;
      }

      todayCount = 0;
    }

    // ── Incrémenter le compteur du jour ───────────────────────────────────────
    todayCount++;
    await prefs.setBool(dedupKey, true);
    await prefs.setInt('streak_today_count_$userId', todayCount);

    // ── Quota du jour atteint → valider la série ──────────────────────────────
    // On utilise == et non >= pour n'incrémenter la série qu'une seule fois,
    // exactement au moment où le quota est atteint (pas pour chaque commentaire suivant).
    bool quotaReached = false;
    if (todayCount == _dailyQuota) {
      quotaReached = true;
      currentStreak++;
      if (currentStreak > bestStreak) bestStreak = currentStreak;

      // Gagner un bouclier tous les N jours de série
      if (currentStreak % _shieldEarnIntervalDays == 0 && shields < _maxShields) {
        shields++;
      }

      await prefs.setInt('streak_current_$userId', currentStreak);
      await prefs.setInt('streak_shields_$userId', shields);
    }

    // ── Écriture Firestore atomique ────────────────────────────────────────────
    try {
      await userRef.update({
        'commentStreak': currentStreak,
        'bestCommentStreak': bestStreak,
        'streakShields': shields,
        'todayCommentCount': todayCount,
        'todayCommentDate': today,
      });
    } catch (e) {
      // Rollback de la clé de dédup pour permettre une nouvelle tentative
      await prefs.remove(dedupKey);
      await prefs.setInt('streak_today_count_$userId', todayCount - 1);
      rethrow;
    }

    return StreakResult(
      quotaReached: quotaReached,
      streakSaved: streakSaved,
      shieldUsed: false,
      alreadyCounted: false,
      currentStreak: currentStreak,
      todayCount: todayCount,
      shields: shields,
    );
  }

  /// Appelé au démarrage de l'app. Vérifie si la série est en danger
  /// et consomme un bouclier si nécessaire.
  static Future<void> checkAndResetDaily(String userId) async {
    final today = _todayStr();
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString('streak_last_checked_$userId');
    if (lastChecked == today) return; // déjà vérifié aujourd'hui

    final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
    final doc = await userRef.get();
    final data = doc.data();
    if (data == null) return;

    final lastDate = data['todayCommentDate'] as String?;
    if (lastDate == null || lastDate == today) {
      await prefs.setString('streak_last_checked_$userId', today);
      return;
    }

    final last = DateTime.tryParse(lastDate);
    if (last == null) return;

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final lastDay = DateTime(last.year, last.month, last.day);
    final todayCount = (data['todayCommentCount'] as num?)?.toInt() ?? 0;
    int shields = (data['streakShields'] as num?)?.toInt() ?? 0;

    // Quota d'hier non atteint → la série est en danger
    if (!lastDay.isAtSameMomentAs(yesterday) || todayCount < _dailyQuota) {
      if (shields > 0) {
        // Bouclier absorbe la coupure
        shields--;
        await userRef.update({
          'streakShields': shields,
          'todayCommentDate': today,
          'todayCommentCount': 0,
        });
        await prefs.setInt('streak_shields_$userId', shields);
      } else {
        // Série cassée
        await userRef.update({
          'commentStreak': 0,
          'todayCommentDate': today,
          'todayCommentCount': 0,
        });
        await prefs.setInt('streak_current_$userId', 0);
      }
    } else {
      // Hier OK (quota atteint), mais on est un nouveau jour : remettre le compteur à 0.
      // Sans ce else, todayCommentCount reste à 3 en Firestore et le provider croit
      // que l'utilisateur a déjà commenté aujourd'hui alors qu'il vient juste de se connecter.
      await userRef.update({
        'todayCommentDate': today,
        'todayCommentCount': 0,
      });
    }
    await prefs.setInt('streak_today_count_$userId', 0);
    await prefs.setString('streak_last_checked_$userId', today);
  }

  /// Migration douce : crée les champs streak si absents en Firestore.
  static Future<void> initIfNeeded(String userId) async {
    final userRef = FirebaseFirestore.instance.collection('Users').doc(userId);
    final doc = await userRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    if (data.containsKey('commentStreak')) return; // déjà initialisé

    await userRef.update({
      'commentStreak': 0,
      'bestCommentStreak': 0,
      'streakShields': 0,
      'todayCommentCount': 0,
      'todayCommentDate': null,
    });
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
