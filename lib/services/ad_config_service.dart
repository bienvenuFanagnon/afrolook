// ad_config_service.dart — config tarifaire centralisée (réglages publics de l'API : GET /config, clé `ad_durations`)
import 'package:afrotok/services/api/regie_api.dart';

class AdDuration {
  final int weeks;
  final int price;
  final String label;

  const AdDuration({required this.weeks, required this.price, required this.label});

  Map<String, dynamic> toJson() => {'weeks': weeks, 'price': price, 'label': label};

  factory AdDuration.fromJson(Map<String, dynamic> json) => AdDuration(
        weeks: json['weeks'] as int,
        price: json['price'] as int,
        label: json['label'] as String,
      );
}

class AdConfigService {
  static const List<AdDuration> _defaults = [
    AdDuration(weeks: 1,  price: 1500,  label: '1 semaine'),
    AdDuration(weeks: 2,  price: 2500,  label: '2 semaines'),
    AdDuration(weeks: 4,  price: 4500,  label: '1 mois'),
    AdDuration(weeks: 12, price: 10000, label: '3 mois'),
    AdDuration(weeks: 24, price: 18000, label: '6 mois'),
    AdDuration(weeks: 52, price: 30000, label: '12 mois'),
  ];

  // Cache en mémoire (30 min)
  static List<AdDuration>? _cached;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 30);

  static List<AdDuration> get defaults => _defaults;

  static Future<List<AdDuration>> getDurations() async {
    if (_cached != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheTtl) {
      return _cached!;
    }
    try {
      final cfg = await RegieApi.config();
      final raw = cfg['ad_durations'];
      if (raw is List && raw.isNotEmpty) {
        final list = raw.whereType<Map>().map((e) => AdDuration.fromJson(Map<String, dynamic>.from(e))).toList();
        _cached = list;
        _cacheTime = DateTime.now();
        return list;
      }
    } catch (_) {/* tarifs par défaut (affichage seul : le serveur reste juge du prix à l'achat) */}
    return _defaults;
  }

  static Map<int, int> toMap(List<AdDuration> durations) =>
      {for (final d in durations) d.weeks: d.price};

  static String labelFor(int weeks, [List<AdDuration>? durations]) {
    final list = durations ?? _cached ?? _defaults;
    final match = list.where((d) => d.weeks == weeks).firstOrNull;
    if (match != null) return match.label;
    if (weeks < 4) return '$weeks semaines';
    if (weeks < 52) return '${weeks ~/ 4} mois';
    return '${weeks ~/ 52} an(s)';
  }

  /// Enregistre les tarifs (administrateur). Passe par le serveur : réglage `ad_durations`.
  static Future<void> update(List<AdDuration> durations, String adminId) async {
    await RegieApi.put('/admin/settings/ad_durations', body: {'value': durations.map((d) => d.toJson()).toList()});
    _cached = durations;
    _cacheTime = DateTime.now();
  }

  static void invalidateCache() {
    _cached = null;
    _cacheTime = null;
  }
}
