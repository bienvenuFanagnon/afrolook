// Pubs de la page « Travaille et gagne de l'argent » : pub plein écran avant l'ouverture du mur de tâches.
// Voir docs/OFFERWALL_TACHES.md §19.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_data.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_service.dart';
import 'appodeal_service.dart';

class TaskAds {
  TaskAds._();

  /// À appeler à l'ouverture de la page : prépare la pub plein écran pour qu'elle soit prête au toucher de « Voir les tâches ».
  static void warmUp(UserData? user) {
    try {
      if (AdConfig.current.tasksInterstitial) {
        AdmobService.warmUpInterstitial(user);
        AppodealService.warmUpInterstitial();
      }
    } catch (_) {}
  }

  /// Galerie de tâches : avant CHAQUE offre ouverte, une pub plein écran, Appodeal d'abord puis AdMob en renfort (décision du propriétaire, 01/11/2026).
  /// Plafond par jour et par appareil, comptes sans pub exclus ; ne bloque jamais l'accès à l'offre (toute erreur est ignorée, attente limitée).
  /// Retourne `true` si une pub a été montrée.
  static Future<bool> beforeOffer(UserData? user) async {
    try {
      final c = AdConfig.current;
      if (!c.tasksInterstitial || !AdGate.canShowType(user, 'interstitial')) return false;
      final sp = await SharedPreferences.getInstance();
      final n = DateTime.now();
      final key = 'ad_offer_${n.year}${n.month}${n.day}';
      if ((sp.getInt(key) ?? 0) >= c.tasksOfferInterstitialMaxPerDay) return false;
      final closed = Completer<bool>();
      var shown = await AppodealService.showInterstitial(onDismissed: () {
        if (!closed.isCompleted) closed.complete(true);
      });
      if (shown) {
        await closed.future.timeout(const Duration(seconds: 60), onTimeout: () => true);
      } else {
        // Appodeal n'a rien à montrer : AdMob prend le relais (sans les écarts du fil : l'action est volontaire)
        shown = await AdmobService.showInterstitialAndWait(user, maxPerDay: c.tasksOfferInterstitialMaxPerDay, capKey: 'ad_inter_offer', warmup: false)
            .timeout(const Duration(seconds: 60), onTimeout: () => false);
      }
      if (shown) await sp.setInt(key, (sp.getInt(key) ?? 0) + 1);
      return shown;
    } catch (_) {
      return false;
    }
  }

  static const _kMissionLast = 'ad_mission_last_ms';

  /// Une pub plein écran peut-elle passer avant l'ouverture d'une mission ? Oui seulement si : pub activée, compte non exempté, temps d'attente écoulé depuis la
  /// dernière pub plein écran des missions (mémorisé sur l'appareil, même après fermeture de l'application) et plafond du jour non atteint. Les bannières ne sont pas concernées.
  static Future<bool> canShowMissionAd(UserData? user) async {
    try {
      final c = AdConfig.current;
      if (!c.missionInterstitial || !c.interstitialEnabled || !AdGate.canShowType(user, 'interstitial')) return false;
      final sp = await SharedPreferences.getInstance();
      final last = sp.getInt(_kMissionLast) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - last < c.missionInterstitialMinGapMinutes * 60000) return false;
      final n = DateTime.now();
      return (sp.getInt('ad_mission_${n.year}${n.month}${n.day}') ?? 0) < c.missionInterstitialMaxPerDay;
    } catch (_) {
      return false;
    }
  }

  /// Montre la pub plein écran des missions (Appodeal d'abord, puis AdMob) et mémorise l'heure : le temps d'attente repart. Ne bloque jamais l'accès (toute erreur est ignorée).
  /// Retourne `true` si une pub a été montrée ; sinon rien n'est mémorisé (la prochaine mission pourra réessayer).
  static Future<bool> beforeMission(UserData? user) async {
    try {
      if (!await canShowMissionAd(user)) return false;
      final closed = Completer<bool>();
      var shown = await AppodealService.showInterstitial(onDismissed: () {
        if (!closed.isCompleted) closed.complete(true);
      });
      if (shown) {
        await closed.future.timeout(const Duration(seconds: 60), onTimeout: () => true);
      } else {
        shown = await AdmobService.showInterstitialNow(onDismissed: () {
          if (!closed.isCompleted) closed.complete(true);
        }, onFailed: () {
          if (!closed.isCompleted) closed.complete(false);
        });
        if (shown) await closed.future.timeout(const Duration(seconds: 60), onTimeout: () => true);
      }
      if (shown) {
        final sp = await SharedPreferences.getInstance();
        final n = DateTime.now();
        final key = 'ad_mission_${n.year}${n.month}${n.day}';
        await sp.setInt(_kMissionLast, n.millisecondsSinceEpoch);
        await sp.setInt(key, (sp.getInt(key) ?? 0) + 1);
      }
      return shown;
    } catch (_) {
      return false;
    }
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
