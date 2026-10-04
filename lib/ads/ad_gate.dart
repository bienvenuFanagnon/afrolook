import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_data.dart';
import '../services/utils/abonnement_utils.dart';
import 'ad_config.dart';
import 'admob_service.dart';

/// Qui voit des pubs AdMob, et quand. Toutes les règles passent par ici.
class AdGate {
  AdGate._();

  static int _sessions = 0;
  static final DateTime sessionStart = DateTime.now();

  /// À appeler une fois au démarrage : compte les sessions (les nouveaux comptes n'ont pas de pub au début).
  static Future<void> init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _sessions = (sp.getInt('ad_sessions') ?? 0) + 1;
      await sp.setInt('ad_sessions', _sessions);
    } catch (_) {}
  }

  /// Règle d'abonnement : admin toujours, Gold jamais, Premium oui (voir [AbonnementUtils.showsAds]).
  static bool userSeesAds(UserData? u) =>
      u != null && AbonnementUtils.showsAds(u.abonnement, u.role, adFreeUntil: u.adFreeUntil);

  static bool _isAdmin(UserData u) => AbonnementUtils.isAdmin(u.role);

  /// Appartient-il au pourcentage d'utilisateurs concernés ? (stable pour un même compte)
  static bool inRollout(UserData u) {
    if (_isAdmin(u)) return true;
    final id = u.id ?? '';
    if (id.isEmpty) return false;
    final h = id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
    return h % 100 < AdConfig.current.rolloutPercent;
  }

  /// Peut-on afficher une pub AdMob à cet utilisateur maintenant ?
  static bool canShowAdmob(UserData? u) {
    if (u == null || !AdConfig.isMobile) return false;
    final c = AdConfig.current;
    if (!c.enabled || !AdmobService.ready.value) return false;
    if (!userSeesAds(u) || !inRollout(u)) return false;
    if (!_isAdmin(u) && _sessions <= c.freeSessions) return false;
    return true;
  }

  static bool canShowType(UserData? u, String type) => canShowAdmob(u) && AdConfig.current.unit(type).isNotEmpty;

  // ── Alternance pubs Afrolook / AdMob sur un même emplacement ──────────────
  static int _slotCounter = 0;

  /// Vrai si CET emplacement doit être confié à AdMob (1 sur [AdConfig.admobEvery]).
  static bool nextSlotIsAdmob() {
    final n = AdConfig.current.admobEvery;
    final isAdmob = _slotCounter % n == n - 1;
    _slotCounter++;
    return isAdmob;
  }
}
