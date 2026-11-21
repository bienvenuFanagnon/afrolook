import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/admob_service.dart';
import '../../ads/appodeal_service.dart';
import '../../ads/fullscreen_ad_page.dart';
import '../../ads/rewarded_ads.dart';
import '../../providers/authProvider.dart';
import '../../services/ad_rotation_service.dart';
import '../../services/api/api_identity.dart';
import '../admin/AfrolookPub/ad_post_page_video_widget.dart';

/// Résultat d'une pub du cinéma : pub du réseau regardée, annonce Afrolook Ads montrée, aucune pub disponible, ou pub fermée avant la fin.
enum CinemaAdResult { network, house, none, dismissed }

extension CinemaAdResultX on CinemaAdResult {
  /// Une pub a bien été montrée (elle compte pour débloquer l'épisode).
  bool get counted => this == CinemaAdResult.network || this == CinemaAdResult.house;
}

/// Pubs de Cartoon Cinéma (décision du 21/11/2026) : seules les pubs du réseau (AdMob / Appodeal) rapportent ; quand le réseau n'a rien,
/// une annonce d'Afrolook Ads prend la place ; sans rien du tout, on ne bloque jamais la personne.
///  - Pour débloquer un épisode : pubs récompensées (AdMob, puis Appodeal), sinon annonce Afrolook Ads.
///  - Au milieu de l'épisode : pub plein écran (AdMob, puis Appodeal), sinon annonce Afrolook Ads.
class CinemaAds {
  CinemaAds._();

  /// Prépare les pubs dès l'ouverture du lecteur, pour qu'elles soient prêtes au moment voulu.
  static void warmUp() {
    try {
      AdmobService.loadRewarded();
      AdmobService.preloadInterstitial();
    } catch (_) {}
  }

  /// Une pub récompensée pour débloquer l'épisode.
  static Future<CinemaAdResult> rewarded(BuildContext context) async {
    try {
      final o = await AdmobService.watchRewardedOutcome(userId: ApiIdentity.myId);
      if (o == RewardedOutcome.earned) return CinemaAdResult.network;
      if (o == RewardedOutcome.dismissed) return CinemaAdResult.dismissed;   // fermée avant la fin : jamais une seconde pub d'office
      if (await AppodealService.watchRewarded()) return CinemaAdResult.network;
    } catch (_) {}
    if (!context.mounted) return CinemaAdResult.none;
    return house(context);
  }

  /// Une pub plein écran au milieu de l'épisode.
  static Future<CinemaAdResult> interstitial(BuildContext context) async {
    try {
      final closed = Completer<void>();
      void done() {
        if (!closed.isCompleted) closed.complete();
      }
      final shown = await AdmobService.showInterstitialNow(onDismissed: done, onFailed: done);
      if (shown) {
        await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
        return CinemaAdResult.network;
      }
    } catch (_) {}
    if (!context.mounted) return CinemaAdResult.none;
    return house(context);
  }

  /// Annonce Afrolook Ads en plein écran (bouton « Fermer » après 5 s, comme partout dans l'application). `none` s'il n'y a aucune annonce.
  static Future<CinemaAdResult> house(BuildContext context) async {
    final ads = context.read<UserAuthProvider>().advertisements.where((a) => a['isEntityBoost'] != true && a['post'] != null).toList();
    if (ads.isEmpty) return CinemaAdResult.none;
    final ad = ads[AdRotationService.instance.claimNext(ads.length)];
    final shown = await Navigator.of(context).push<bool>(PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _CinemaHouseAdPage(adData: ad),
    ));
    return shown == true ? CinemaAdResult.house : CinemaAdResult.none;
  }
}

class _CinemaHouseAdPage extends StatefulWidget {
  const _CinemaHouseAdPage({required this.adData});

  final Map<String, dynamic> adData;

  @override
  State<_CinemaHouseAdPage> createState() => _CinemaHouseAdPageState();
}

class _CinemaHouseAdPageState extends State<_CinemaHouseAdPage> {
  bool _shown = false;
  bool _closed = false;

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(_shown);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return PopScope(
      canPop: false,   // on ne quitte l'annonce que par son bouton « Fermer »
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FullScreenAdPage(
          active: true,
          waitMs: 0,   // le réseau a déjà été essayé : l'annonce Afrolook Ads s'affiche tout de suite
          networkBuilder: (_, __) => const SizedBox.shrink(),
          onShown: (_) => _shown = true,
          onNext: _close,
          ownBuilder: (done) => AdPostWidget(adData: widget.adData, width: size.width, height: size.height, onComplete: done),
        ),
      ),
    );
  }
}
