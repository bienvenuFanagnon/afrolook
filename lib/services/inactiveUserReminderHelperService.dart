import 'package:flutter/foundation.dart';

/// Rappels aux personnes inactives : désormais programmés et envoyés par le serveur de l'API (budget de 3 notifications par jour, heures calmes,
/// fuseau horaire et langue de l'appareil enregistrés via `PUT /v1/me/devices`). L'application ne déclenche plus aucun traitement.
class InactiveUserReminderService {
  static const int DAYS_INACTIVE_THRESHOLD = 3;
  static const int MAX_EMAILS_PER_MONTH = 2;

  // Constantes pour les conversions
  static const int ONE_DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000; // 86,400,000 ms
  static const int ONE_DAY_IN_MICROSECONDS = ONE_DAY_IN_MILLISECONDS * 1000; // 86,400,000,000 μs
  static const int MAX_REASONABLE_DAYS = 500; // Si >500 jours, c'est probablement en microsecondes

  /// Conservé pour compatibilité : ne fait rien (le serveur s'en charge).
  static Future<void> checkAndNotifyInactiveUsers() async {
    if (kDebugMode) debugPrint('📧 Rappels d\'inactivité : gérés par le serveur, rien à faire dans l\'application');
  }

  /// Détecte automatiquement si le timestamp est en millisecondes ou microsecondes
  /// et retourne le nombre de jours d'inactivité
  static int calculateDaysInactive(int lastTimeActive) {
    if (lastTimeActive == 0) return 0;

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final isMicroseconds = lastTimeActive > 1000000000000000;
    final lastMs = isMicroseconds ? lastTimeActive ~/ 1000 : lastTimeActive;
    final days = (nowMs - lastMs) ~/ ONE_DAY_IN_MILLISECONDS;
    return days < 0 || days > MAX_REASONABLE_DAYS * 10 ? 0 : days;
  }
}
