import 'package:cloud_functions/cloud_functions.dart';

/// Vérifie côté serveur si l'utilisateur peut poster (cooldown 5 minutes).
/// Cette vérification est autoritaire et ne peut pas être contournée côté client.
class PostCooldownService {
  static Future<({bool canPost, int remainingSeconds})> check() async {
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('checkPostCooldownServer');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return (
        canPost: data['canPost'] as bool? ?? true,
        remainingSeconds: data['remainingSeconds'] as int? ?? 0,
      );
    } catch (_) {
      // En cas d'erreur réseau, on laisse passer pour ne pas bloquer l'UX
      return (canPost: true, remainingSeconds: 0);
    }
  }

  static String formatRemaining(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
