import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:afrotok/services/api/api_gateway.dart';

/// Utilisations d'un modèle prêt à poster : au total et sur les 7 derniers jours.
class TemplateUse {
  const TemplateUse(this.code, this.uses, this.week);
  final String code;
  final int uses;
  final int week;
}

/// Compteur des modèles prêts à poster (09/11/2026). Un modèle se désigne par son code, celui du post (`m:{id}` Studio, `c:{style}` carte).
/// « Une utilisation = une publication faite avec le modèle » ; la liste vient classée du serveur (la semaine d'abord, puis le total) et reste 3 minutes en mémoire.
class TemplateStatsApi {
  TemplateStatsApi._();

  static ApiClient get _c => ApiGateway.instance.client;
  static List<TemplateUse> _cache = const [];
  static DateTime? _at;

  /// Pour les tests : impose la liste du serveur.
  @visibleForTesting
  static void setForTest(List<TemplateUse> rows) {
    _cache = rows;
    _at = DateTime.now();
  }

  /// Dernière liste connue (vide tant qu'elle n'est pas chargée ou si le réseau échoue : les écrans restent corrects sans compteur).
  static List<TemplateUse> get current => _cache;

  static Future<List<TemplateUse>> load({bool force = false}) async {
    final at = _at;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 3)) return _cache;
    try {
      final d = ApiClient.data(await _c.get('/studio/templates/stats'));
      final rows = d is List ? d : const [];
      _cache = [
        for (final r in rows.whereType<Map>()) TemplateUse('${r['code']}', (r['uses'] as num?)?.toInt() ?? 0, (r['week'] as num?)?.toInt() ?? 0),
      ];
      _at = DateTime.now();
    } catch (_) {
      // réseau ou serveur indisponible : on garde ce qu'on avait
    }
    return _cache;
  }

  /// Nombre total d'utilisations du modèle [code] (0 si inconnu).
  static int usesOf(String code) {
    for (final u in _cache) {
      if (u.code == code) return u.uses;
    }
    return 0;
  }

  /// Rang d'un modèle dans le classement du serveur (plus petit = plus utilisé) ; `null` s'il n'a encore aucune utilisation.
  static int? rankOf(String code) {
    for (var i = 0; i < _cache.length; i++) {
      if (_cache[i].code == code) return i;
    }
    return null;
  }

  /// « 18,2 k » pour 18 200 ; le nombre tel quel en dessous de 1 000.
  static String format(int n) => n < 1000 ? '$n' : '${(n / 1000).toStringAsFixed(1).replaceAll('.', ',')} k';
}
