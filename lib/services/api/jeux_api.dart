import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Aides communes aux modules « jeux, médias et conversations » (Quiz, Étude, Contes, Journal, lives, groupes, notifications).
/// Aucun retour à Firebase : une erreur de l'API est remontée telle quelle à l'écran (message en français + « Réessayer »).
class JeuxApi {
  JeuxApi._();

  static ApiClient get client => ApiGateway.instance.client;

  /// `snake_case` -> `camelCase`.
  static String camel(String k) {
    if (!k.contains('_')) return k;
    final parts = k.split('_');
    return parts.first + parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }

  /// Convertit les clés du premier niveau (et des sous-tableaux listés dans [deep]) en camelCase ; les valeurs de [keep] (ex. inventaire,
  /// dont les clés sont des identifiants d'objets) restent intactes.
  static Map<String, dynamic> camelKeys(Map m, {Set<String> deep = const {}, Set<String> keep = const {}}) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      final key = camel('$k');
      if (keep.contains(key) || keep.contains('$k')) {
        out[key] = v;
      } else if (deep.contains(key) && v is Map) {
        out[key] = camelKeys(v, deep: deep, keep: keep);
      } else if (deep.contains(key) && v is List) {
        out[key] = v.map((e) => e is Map ? camelKeys(e, deep: deep, keep: keep) : e).toList();
      } else {
        out[key] = v;
      }
    });
    return out;
  }

  /// Extrait le champ `data` d'une réponse.
  static dynamic data(dynamic r) => r is Map ? r['data'] : r;

  static Map<String, dynamic> map(dynamic r) {
    final d = data(r);
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> list(dynamic r) {
    final d = data(r);
    return d is List ? d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
  }

  static int asInt(dynamic v, [int def = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? def : def);

  /// Date ISO -> millisecondes depuis 1970 (0 si absente).
  static int ms(dynamic iso) {
    if (iso is num) return iso.toInt();
    return DateTime.tryParse('$iso')?.millisecondsSinceEpoch ?? 0;
  }
}
