import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Revenus publicitaires estimés par emplacement (événements « paid » d'AdMob et d'Appodeal). Les montants s'additionnent en mémoire puis partent au
/// serveur toutes les 5 minutes (fonction recordAdRevenue, qui garde un total par jour) : l'écran admin « Revenus » les affiche emplacement par
/// emplacement. Jamais bloquant : un échec réessaie plus tard, sans effet pour la personne.
class AdRevenueTracker {
  AdRevenueTracker._();

  static final Map<String, _Acc> _acc = {};
  static Timer? _timer;

  /// [placement] : `admob_banner`, `admob_native`, `admob_interstitial`, `admob_rewarded`, `appodeal_banner`… ; [micros] : valeur en millionièmes d'unité.
  static void record(String placement, double micros, String currency) {
    if (micros <= 0 || micros.isNaN || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) return;
    final key = '${_clean(placement)}|$currency';
    final a = _acc.putIfAbsent(key, () => _Acc());
    a.micros += micros;
    a.n += 1;
    _timer ??= Timer.periodic(const Duration(minutes: 5), (_) => flush());
  }

  static String _clean(String p) => p.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_:\-]'), '_');

  /// Envoie les totaux accumulés (appelée par le minuteur ; peut aussi l'être à la mise en arrière-plan).
  static Future<void> flush() async {
    if (_acc.isEmpty) return;
    final snapshot = Map<String, _Acc>.of(_acc);
    _acc.clear();
    final items = snapshot.entries.map((e) {
      final parts = e.key.split('|');
      return {'p': parts[0], 'c': parts[1], 'm': e.value.micros.round(), 'n': e.value.n};
    }).toList();
    try {
      await FirebaseFunctions.instance.httpsCallable('recordAdRevenue').call({'items': items});
    } catch (e) {
      // pas de perte : on remet les montants pour le prochain envoi
      for (final en in snapshot.entries) {
        final a = _acc.putIfAbsent(en.key, () => _Acc());
        a.micros += en.value.micros;
        a.n += en.value.n;
      }
      if (kDebugMode) debugPrint('AdRevenueTracker : envoi différé ($e)');
    }
  }
}

class _Acc {
  double micros = 0;
  int n = 0;
}
