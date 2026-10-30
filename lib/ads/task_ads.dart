// Pubs de la page « Travaille et gagne de l'argent » : pub plein écran avant l'ouverture du mur de tâches.
// Voir docs/OFFERWALL_TACHES.md §19.

import 'dart:async';

import '../models/model_data.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_service.dart';

class TaskAds {
  TaskAds._();

  /// À appeler à l'ouverture de la page : prépare la pub plein écran pour qu'elle soit prête au toucher de « Voir les tâches ».
  static void warmUp(UserData? user) {
    try {
      if (AdConfig.current.tasksInterstitial) AdmobService.warmUpInterstitial(user);
    } catch (_) {}
  }

  /// Juste avant d'ouvrir le mur de tâches : une pub plein écran passe d'abord si elle est prête et si les garde-fous le permettent
  /// (comptes sans pub exclus, écart minimum entre deux pubs, plafond par jour). Ne bloque jamais l'accès aux tâches : toute erreur est ignorée
  /// et l'attente est limitée. Retourne `true` si une pub a été montrée.
  static Future<bool> beforeTasks(UserData? user) async {
    try {
      final c = AdConfig.current;
      if (!c.tasksInterstitial || !AdGate.canShowType(user, 'interstitial')) return false;
      return await AdmobService
          .showInterstitialAndWait(user, maxPerDay: c.tasksInterstitialMaxPerDay, capKey: 'ad_inter_tasks', warmup: false)
          .timeout(const Duration(seconds: 45), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }
}
