import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Bloque les captures d'écran et l'enregistrement d'écran tant qu'une page du Studio Cartes est ouverte.
///
/// - Android : FLAG_SECURE (la capture est noire, l'aperçu des applis récentes aussi).
/// - iOS : la protection native du plugin.
/// - Web : un navigateur ne peut pas bloquer une capture ; le studio y est donc réservé à l'application.
///
/// L'export (enregistrer / partager) lit les pixels du widget, pas l'écran : il n'est pas touché.
class CardGuard {
  CardGuard._();

  static int _holders = 0;

  /// Le studio n'est proposé que là où les captures peuvent être bloquées.
  static bool get supported => !kIsWeb;

  static Future<void> enter() async {
    if (kIsWeb) return;
    _holders++;
    if (_holders != 1) return;
    try {
      await ScreenProtector.preventScreenshotOn();
      await ScreenProtector.protectDataLeakageOn();
    } catch (_) {}
  }

  static Future<void> leave() async {
    if (kIsWeb || _holders == 0) return;
    _holders--;
    if (_holders != 0) return;
    try {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
    } catch (_) {}
  }
}
