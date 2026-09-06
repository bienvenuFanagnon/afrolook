import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Historique local des IDs de posts de découverte déjà montrés à l'utilisateur.
/// Utilisé pour exclure ces posts lors du rechargement du pool (fetchInterestPosts).
/// Fenêtre glissante de [maxSize] entrées — les plus anciens sortent en premier.
class SeenDiscoveryCache {
  SeenDiscoveryCache._();
  static final SeenDiscoveryCache instance = SeenDiscoveryCache._();

  static const int maxSize = 300;
  static const String _prefix = 'discovery_seen_v2_';

  final List<String> _ids = [];
  String? _userId;

  Set<String> get seenIds => _ids.toSet();

  static Future<void> load(String userId) async {
    final c = instance;
    if (c._userId == userId) return;
    c._userId = userId;
    c._ids.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$userId');
      if (raw != null) {
        c._ids.addAll(List<String>.from(jsonDecode(raw) as List));
      }
    } catch (_) {}
  }

  void add(Iterable<String> ids) {
    for (final id in ids) {
      if (!_ids.contains(id)) _ids.add(id);
    }
    if (_ids.length > maxSize) _ids.removeRange(0, _ids.length - maxSize);
  }

  Future<void> save() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$_userId', jsonEncode(_ids));
    } catch (_) {}
  }
}
