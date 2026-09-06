import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache local (SharedPreferences) des IDs de posts de découverte déjà vus.
/// Fenêtre glissante de [maxSize] entrées par utilisateur — les plus anciens
/// sortent quand la limite est dépassée.
/// Usage :
///   await SeenDiscoveryCache.load(userId);
///   final excluded = SeenDiscoveryCache.instance.seenIds;
///   SeenDiscoveryCache.instance.add(newlyShownIds);
class SeenDiscoveryCache {
  SeenDiscoveryCache._();
  static SeenDiscoveryCache? _instance;
  static SeenDiscoveryCache get instance {
    _instance ??= SeenDiscoveryCache._();
    return _instance!;
  }

  static const int maxSize = 200;
  static const String _keyPrefix = 'discovery_seen_';

  final List<String> _ids = [];
  String? _userId;

  Set<String> get seenIds => _ids.toSet();

  static Future<void> load(String userId) async {
    final cache = SeenDiscoveryCache.instance;
    if (cache._userId == userId) return; // déjà chargé pour cet user
    cache._userId = userId;
    cache._ids.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$userId');
      if (raw != null) {
        final list = List<String>.from(jsonDecode(raw) as List);
        cache._ids.addAll(list);
      }
    } catch (_) {}
  }

  void add(Iterable<String> ids) {
    for (final id in ids) {
      if (!_ids.contains(id)) _ids.add(id);
    }
    // Fenêtre glissante : garder uniquement les maxSize plus récents
    if (_ids.length > maxSize) {
      _ids.removeRange(0, _ids.length - maxSize);
    }
  }

  Future<void> save() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPrefix$_userId', jsonEncode(_ids));
    } catch (_) {}
  }

  void clear() => _ids.clear();
}
