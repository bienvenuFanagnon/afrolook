// ad_config_service.dart — config tarifaire centralisée (Firestore)
import 'package:cloud_firestore/cloud_firestore.dart';

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
  static const _collection = 'AdConfig';
  static const _docId = 'pricing';

  static const List<AdDuration> _defaults = [
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
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(_docId)
          .get();
      if (doc.exists && doc.data()?['durations'] != null) {
        final list = (doc.data()!['durations'] as List)
            .map((e) => AdDuration.fromJson(e as Map<String, dynamic>))
            .toList();
        _cached = list;
        _cacheTime = DateTime.now();
        return list;
      }
    } catch (_) {}
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

  static Future<void> update(List<AdDuration> durations, String adminId) async {
    await FirebaseFirestore.instance
        .collection(_collection)
        .doc(_docId)
        .set({
      'durations': durations.map((d) => d.toJson()).toList(),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'updatedBy': adminId,
    }, SetOptions(merge: true));
    _cached = durations;
    _cacheTime = DateTime.now();
  }

  static void invalidateCache() {
    _cached = null;
    _cacheTime = null;
  }
}
