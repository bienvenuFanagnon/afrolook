import 'dart:async';

import 'package:flutter/material.dart';

import '../../ads/ad_slot.dart';
import '../../ads/appodeal_service.dart';

/// Résultat d'une pub du cinéma : pub regardée, aucune pub disponible, ou pub fermée avant la fin.
enum CinemaAdResult { network, none, dismissed }

extension CinemaAdResultX on CinemaAdResult {
  /// Une pub a bien été montrée (elle compte pour débloquer l'épisode).
  bool get counted => this == CinemaAdResult.network;
}

/// Pubs de Cartoon Cinéma : Appodeal seulement (décision du 22/11/2026), ni AdMob en direct ni annonce Afrolook Ads ; quand Appodeal n'a
/// rien, aucune pub et on ne bloque jamais la personne.
///  - Pour débloquer un épisode : pub récompensée Appodeal.
///  - Au milieu de l'épisode : pub plein écran Appodeal.
///  - Dans les pages : bannières et grands formats Appodeal ([CinemaAdSlot]).
class CinemaAds {
  CinemaAds._();

  /// Prépare les pubs dès l'ouverture du lecteur, pour qu'elles soient prêtes au moment voulu.
  static void warmUp() {
    AppodealService.warmUpRewarded();
    AppodealService.warmUpInterstitial();
  }

  /// Une pub récompensée pour débloquer l'épisode.
  static Future<CinemaAdResult> rewarded(BuildContext context) async {
    switch (await AppodealService.watchRewardedOutcome()) {
      case 'earned':
        return CinemaAdResult.network;
      case 'dismissed':
        return CinemaAdResult.dismissed;   // fermée avant la fin : jamais une seconde pub d'office
      default:
        return CinemaAdResult.none;
    }
  }

  /// Une pub plein écran au milieu de l'épisode.
  static Future<CinemaAdResult> interstitial(BuildContext context) async {
    try {
      final closed = Completer<void>();
      final shown = await AppodealService.showInterstitial(onDismissed: () {
        if (!closed.isCompleted) closed.complete();
      });
      if (shown) {
        await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
        return CinemaAdResult.network;
      }
    } catch (_) {}
    return CinemaAdResult.none;
  }
}

/// Emplacement de pub des pages du Cinéma : Appodeal seulement (bannière, grand format pour [AdSlotKind.detailMrec]), rien sinon.
class CinemaAdSlot extends StatelessWidget {
  const CinemaAdSlot({super.key, required this.kind});

  final AdSlotKind kind;

  static Widget _nothing() => const SizedBox.shrink();

  @override
  Widget build(BuildContext context) => AdSlot(kind: kind, appodealOnly: true, allowOwn: false, own: _nothing);
}
