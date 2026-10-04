import '../ads/admob_service.dart';

/// Façade conservée pour l'ancien code : toute la publicité passe maintenant par AdMob
/// (voir lib/ads/). Appodeal n'est plus utilisé.
class AdService {
  AdService._();

  static Future<void> init() => AdmobService.init();

  /// Outil de diagnostic AdMob (admin).
  static void showTestScreen() => AdmobService.openInspector();
}
