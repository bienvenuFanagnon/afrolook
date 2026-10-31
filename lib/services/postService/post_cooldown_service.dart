import 'package:shared_preferences/shared_preferences.dart';

/// Gestion du cooldown de publication.
///
/// Architecture :
///   1. Cache local (SharedPreferences) — lecture synchrone après init, 0 réseau.
///      Partagé entre tous les onglets. Mis à jour par [markPosted()] après chaque
///      publication réussie.
///   2. Vérification serveur : faite par l'API à la création de la publication.
///
/// Cooldown : 5 minutes pour tous les utilisateurs non-premium.
class PostCooldownService {
  static const String _kKey = 'last_post_timestamp_ms';
  static const int _cooldownMs = 5 * 60 * 1000; // 5 minutes en ms

  // ── API publique ─────────────────────────────────────────────────────────────

  /// À appeler immédiatement après une publication Firestore réussie.
  /// Met à jour le cache local pour que tous les onglets voient le cooldown.
  static Future<void> markPosted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Retourne les secondes restantes depuis le cache local uniquement (0 = peut poster).
  /// Rapide — pas de réseau. Utilisé pour restaurer le timer au démarrage de chaque onglet.
  static Future<int> localRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kKey) ?? 0;
    if (last == 0) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    if (elapsed >= _cooldownMs) return 0;
    return ((_cooldownMs - elapsed) / 1000).ceil();
  }

  /// Vérification complète : cache local d'abord, puis Cloud Function si nécessaire.
  /// Retourne (canPost, remainingSeconds).
  static Future<({bool canPost, int remainingSeconds})> check() async {
    // 1. Cache local — bloquant instantané, aucun réseau
    final localRemaining = await localRemainingSeconds();
    if (localRemaining > 0) {
      return (canPost: false, remainingSeconds: localRemaining);
    }

    // Le serveur applique ses propres limites à la création (erreur 429 affichée par l'écran de publication).
    return (canPost: true, remainingSeconds: 0);
  }

  static String formatRemaining(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
