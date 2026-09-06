import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_data.dart';

/// Cache local (SharedPreferences) des posts de découverte (T2/T3).
///
/// Principe :
/// - Pool de [maxPoolSize] posts stockés en JSON par utilisateur
/// - À chaque chargement de feed : on pioche dans le pool (pas de requête Firestore)
/// - Quand le pool passe sous [lowWatermark] OU dépasse [ttlHours] heures :
///   rechargement en arrière-plan (sans bloquer l'affichage)
/// - Les posts pris du pool sont marqués dans [SeenDiscoveryCache] pour
///   ne pas revenir dans le prochain rechargement Firestore
class DiscoveryPostsCache {
  DiscoveryPostsCache._();
  static final DiscoveryPostsCache instance = DiscoveryPostsCache._();

  static const int maxPoolSize  = 60;
  static const int lowWatermark = 12;
  static const int ttlHours     = 48;

  static const String _keyPosts = 'discovery_pool_posts_v1_';
  static const String _keyTs    = 'discovery_pool_ts_v1_';

  final List<Post> _pool = [];
  String? _userId;
  DateTime? _poolTs;

  bool get isEmpty   => _pool.isEmpty;
  int  get available => _pool.length;

  /// [needsRefetch] : true si pool presque vide ou trop vieux
  bool get needsRefetch {
    if (_pool.length < lowWatermark) return true;
    if (_poolTs == null) return true;
    return DateTime.now().difference(_poolTs!).inHours >= ttlHours;
  }

  /// Charge le pool depuis SharedPreferences pour [userId].
  /// Appeler dans initState ou _initSharedPreferences.
  static Future<void> load(String userId) async {
    final c = instance;
    if (c._userId == userId && c._pool.isNotEmpty) return;
    c._userId = userId;
    c._pool.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('$_keyPosts$userId');
      final tsMs  = prefs.getInt('$_keyTs$userId');
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          try {
            final p = Post.fromJson(Map<String, dynamic>.from(item as Map));
            if (p.id != null) c._pool.add(p);
          } catch (_) {}
        }
      }
      if (tsMs != null) {
        c._poolTs = DateTime.fromMillisecondsSinceEpoch(tsMs);
      }
    } catch (_) {}
  }

  /// Prend [n] posts du pool (mélangés), les retire et sauvegarde.
  /// Retourne une liste vide si le pool est vide.
  List<Post> take(int n) {
    if (_pool.isEmpty) return [];
    _pool.shuffle(Random());
    final taken = _pool.take(n).toList();
    _pool.removeWhere((p) => taken.any((t) => t.id == p.id));
    _saveAsync();
    return taken;
  }

  /// Ajoute des posts au pool (dédupliqués) et sauvegarde.
  /// Appelé après un fetch Firestore pour remplir/réapprovisionner.
  void replenish(List<Post> posts) {
    final existingIds = _pool.map((p) => p.id).toSet();
    for (final p in posts) {
      if (p.id != null && !existingIds.contains(p.id)) {
        _pool.add(p);
        existingIds.add(p.id);
      }
    }
    // Garder seulement les maxPoolSize plus récents
    if (_pool.length > maxPoolSize) {
      _pool.removeRange(0, _pool.length - maxPoolSize);
    }
    _poolTs = DateTime.now();
    _saveAsync();
  }

  Future<void> _saveAsync() async {
    if (_userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = _pool.map((p) => _postToMap(p)).toList();
      await prefs.setString('$_keyPosts$_userId', jsonEncode(encoded));
      if (_poolTs != null) {
        await prefs.setInt('$_keyTs$_userId', _poolTs!.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  Map<String, dynamic> _postToMap(Post p) {
    final map = p.toJson();
    // S'assurer que l'ID est bien présent
    map['id'] ??= p.id;
    return map;
  }

  /// IDs des posts actuellement dans le pool — utilisés comme exclusion
  /// lors des refetch Firestore pour ne pas repeupler avec les mêmes.
  Set<String> get poolIds =>
      _pool.where((p) => p.id != null).map((p) => p.id!).toSet();
}
