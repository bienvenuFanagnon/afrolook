import 'ad_config.dart';
import 'admob_service.dart';
import 'appodeal_service.dart';

/// Résultat d'une pub récompensée AdMob : regardée en entier, fermée avant la fin, ou aucune pub disponible.
enum RewardedOutcome { earned, dismissed, noAd }

/// Pub récompensée avec renfort : AdMob d'abord ; s'il n'a AUCUNE pub à montrer, Appodeal prend le relais (un autre jeu de réseaux, donc plus de chances
/// de remplissage) pour que la page Récompenses ne reste pas bloquée.
///
/// Le renfort n'est utilisé que si la vérification serveur AdMob (SSV) est coupée : avec elle, le serveur ne compte que les pubs AdMob vérifiées,
/// donc une pub Appodeal ne pourrait pas être créditée. Une pub fermée avant la fin ne déclenche jamais une seconde pub.
class RewardedAds {
  RewardedAds._();

  /// Retourne `true` si une pub a été regardée en entier (et peut être comptée).
  static Future<bool> watch({String? userId}) async {
    final admob = await AdmobService.watchRewardedOutcome(userId: userId);
    if (admob == RewardedOutcome.earned) return true;
    if (admob == RewardedOutcome.dismissed) return false;
    if (AdConfig.current.ssvEnabled) return false;
    return AppodealService.watchRewarded();
  }
}
