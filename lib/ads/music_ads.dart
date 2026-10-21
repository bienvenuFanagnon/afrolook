// Pubs de la page Musique : pub plein écran rare entre deux écoutes, titre payant écouté en entier contre une pub récompensée,
// et suivi du revenu estimé des emplacements dédiés (bannière et natif de la page Musique).

import 'dart:async';
import 'rewarded_ads.dart';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/model_data.dart';
import '../pages/studio/artist_sound_common.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_service.dart';
import 'rewards_service.dart';

enum MusicAdOutcome { ok, noAd, limit, unavailable, failed }

class MusicAdListen {
  const MusicAdListen(this.outcome, [this.url]);
  final MusicAdOutcome outcome;
  final String? url;
}

class MusicAds {
  MusicAds._();

  // ── Pub plein écran : seulement entre deux titres, jamais pendant l'écoute ──
  static int _starts = 0;

  /// À appeler juste avant de lancer un titre choisi par la personne. Tous les N titres (réglage), si les garde-fous le permettent,
  /// une pub plein écran passe puis la lecture démarre. Les comptes sans pub (Gold, nouveaux comptes…) ne voient rien.
  static Future<void> beforeTrack(UserData? user) async {
    // Une pub ne doit JAMAIS empêcher ni retarder la musique : toute erreur est ignorée et l'attente est limitée.
    try {
      final c = AdConfig.current;
      if (!c.musicInterstitial || !AdGate.canShowType(user, 'interstitial')) return;
      _starts++;
      AdmobService.warmUpInterstitial(user);
      if (_starts % c.musicInterstitialEvery != 0) return;
      await AdmobService.showInterstitialAndWait(user, maxPerDay: c.musicInterstitialMaxPerDay).timeout(const Duration(seconds: 45), onTimeout: () => false);
    } catch (_) {}
  }

  // ── Titre payant écouté en entier contre une pub récompensée ──
  static bool canOfferRewarded(UserData? user) => AdConfig.current.musicRewarded && AdGate.canShowType(user, 'rewarded');

  /// Regarde une pub récompensée, puis demande au serveur d'ouvrir UNE écoute complète de ce titre (5 par jour au plus).
  static Future<MusicAdListen> listenWithAd(String soundId, {required String userId}) async {
    final earned = await RewardedAds.watch(userId: userId);
    if (!earned) return const MusicAdListen(MusicAdOutcome.noAd);
    try {
      await RewardsService.recordView();
    } catch (_) {
      // la pub est vérifiée par AdMob côté serveur, parfois avec un petit délai
    }
    for (var i = 0; i < 4; i++) {
      try {
        await FirebaseFunctions.instance.httpsCallable('musicAdListen').call({'soundId': soundId});
        final url = await fetchFullListenUrl(soundId);
        return url == null ? const MusicAdListen(MusicAdOutcome.failed) : MusicAdListen(MusicAdOutcome.ok, url);
      } on FirebaseFunctionsException catch (e) {
        final m = '${e.message}';
        if (m.contains('NO_ADS') && i < 3) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        if (m.contains('LIMITE_JOUR')) return const MusicAdListen(MusicAdOutcome.limit);
        if (m.contains('RETIRE')) return const MusicAdListen(MusicAdOutcome.unavailable);
        return const MusicAdListen(MusicAdOutcome.failed);
      } catch (_) {
        return const MusicAdListen(MusicAdOutcome.failed);
      }
    }
    return const MusicAdListen(MusicAdOutcome.failed);
  }

  static String message(MusicAdOutcome o) => switch (o) {
        MusicAdOutcome.ok => '',
        MusicAdOutcome.noAd => 'Aucune pub disponible pour le moment. Réessaie dans un instant.',
        MusicAdOutcome.limit => 'Tu as utilisé tes 5 écoutes avec pub d’aujourd’hui. Reviens demain ou achète le titre.',
        MusicAdOutcome.unavailable => 'Ce titre n’est plus disponible.',
        MusicAdOutcome.failed => 'La pub n’a pas pu être comptée. Réessaie.',
      };

  // ── Revenu estimé des emplacements de la page Musique (lu dans l'admin ; le chiffre officiel est dans la console AdMob) ──
  static final List<Map<String, Object>> _buf = [];
  static Timer? _timer;

  static void Function(double, String) paid(String placement) => (micros, currency) {
        _buf.add({'p': placement, 'v': micros, 'c': currency});
        if (_buf.length >= 20) {
          flush();
        } else {
          _timer ??= Timer(const Duration(minutes: 1), flush);
        }
      };

  static Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_buf.isEmpty) return;
    final events = List<Map<String, Object>>.from(_buf);
    _buf.clear();
    try {
      await FirebaseFunctions.instance.httpsCallable('musicAdPaid').call({'events': events});
    } catch (_) {/* indicatif : on abandonne sans bruit */}
  }
}
