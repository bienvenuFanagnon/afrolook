import 'package:flutter/foundation.dart';

/// Repères de temps du démarrage (écran de lancement → premier post affiché). Sert à MESURER avant d'optimiser :
/// chaque repère affiche le temps écoulé depuis le début du processus et depuis le repère précédent.
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _sw = Stopwatch()..start();
  static int _last = 0;

  static void mark(String name) {
    final now = _sw.elapsedMilliseconds;
    debugPrint('⏱️ [DÉMARRAGE] $name : $now ms depuis le lancement (+${now - _last} ms)');
    _last = now;
  }

  /// Chronomètre une opération asynchrone et affiche sa durée.
  static Future<T> time<T>(String name, Future<T> Function() op) async {
    final s = Stopwatch()..start();
    try {
      return await op();
    } finally {
      debugPrint('⏱️ [TEMPS] $name : ${s.elapsedMilliseconds} ms');
    }
  }
}
