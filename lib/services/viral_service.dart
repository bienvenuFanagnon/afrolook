import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api/viral_api.dart';

/// Nombre de posts viraux que la personne n'a pas encore vus : le « +N » de l'onglet Viral et du bandeau du fil « Pour toi ».
/// Relu toutes les 3 minutes tant que l'accueil est ouvert, au retour dans l'application et à la sortie de la page Viral. Jamais bloquant.
class ViralService {
  ViralService._();

  static final ValueNotifier<int> unseen = ValueNotifier(0);
  static Timer? _timer;
  static DateTime? _at;

  static Future<void> refresh({bool force = false}) async {
    final at = _at;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(seconds: 90)) return;
    _at = DateTime.now();
    try {
      unseen.value = (await ViralApi.unseen()).clamp(0, 99);
    } catch (_) {/* garde le dernier nombre connu */}
  }

  /// À lancer à l'ouverture de l'accueil ; [stop] à sa fermeture.
  static void start() {
    refresh(force: true);
    _timer ??= Timer.periodic(const Duration(minutes: 3), (_) => refresh(force: true));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Texte du « +N » (« +99 » au plus) ; vide quand il n'y en a pas.
  static String badge(int n) => n <= 0 ? '' : '+${n > 99 ? 99 : n}';
}
