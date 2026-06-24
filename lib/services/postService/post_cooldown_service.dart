import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestion du cooldown de publication.
///
/// Architecture :
///   1. Cache local (SharedPreferences) — lecture synchrone après init, 0 réseau.
///      Partagé entre tous les onglets. Mis à jour par [markPosted()] après chaque
///      publication réussie.
///   2. Vérification serveur (Cloud Function) — appelée uniquement si le cache local
///      ne détecte pas de cooldown actif.
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

    // 2. Vérification serveur
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('checkPostCooldownServer');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      final canPost = data['canPost'] as bool? ?? true;
      final remaining = data['remainingSeconds'] as int? ?? 0;

      // Serveur dit non → synchroniser le cache local pour les autres onglets
      if (!canPost && remaining > 0) {
        final prefs = await SharedPreferences.getInstance();
        final simulatedLast =
            DateTime.now().millisecondsSinceEpoch - (_cooldownMs - remaining * 1000);
        await prefs.setInt(_kKey, simulatedLast);
      }

      return (canPost: canPost, remainingSeconds: remaining);
    } catch (_) {
      // Erreur réseau : on laisse passer pour ne pas bloquer l'UX
      return (canPost: true, remainingSeconds: 0);
    }
  }

  static String formatRemaining(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
