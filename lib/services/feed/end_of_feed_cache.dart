import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/model_data.dart';

/// Cache SharedPreferences des créateurs et canaux suggérés en fin de feed.
/// TTL de 1 heure. Préchargé au démarrage ; lu instantanément à l'affichage.
class EndOfFeedCache {
  EndOfFeedCache._();
  static final EndOfFeedCache instance = EndOfFeedCache._();

  static const _keyCreators = 'eofc_creators_v1';
  static const _keyCanaux = 'eofc_canaux_v1';
  static const _keyTs = 'eofc_ts_v1';
  static const _ttl = Duration(hours: 1);

  // In-memory layer pour éviter les lectures SP répétées dans la même session
  List<UserData>? _creators;
  List<Canal>? _canaux;
  DateTime? _loadedAt;

  // ── Lecture ──────────────────────────────────────────────────────────────

  Future<(List<UserData>, List<Canal>)> get() async {
    if (_isMemoryFresh()) return (_creators!, _canaux!);

    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keyTs);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (ts != null && (now - ts) < _ttl.inMilliseconds) {
      final creatorJson = prefs.getString(_keyCreators);
      final canauxJson = prefs.getString(_keyCanaux);
      if (creatorJson != null && canauxJson != null) {
        try {
          final creators = (jsonDecode(creatorJson) as List)
              .map((e) => UserData.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          final canaux = (jsonDecode(canauxJson) as List)
              .map((e) => Canal.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _creators = creators;
          _canaux = canaux;
          _loadedAt = DateTime.now();
          return (creators, canaux);
        } catch (_) {}
      }
    }
    return (<UserData>[], <Canal>[]);
  }

  // ── Préchargement Firestore ──────────────────────────────────────────────

  /// À appeler dans [_loadAllAdditionalDataInParallel] sans await.
  Future<void> prefetch({
    required String myId,
    required Set<String> alreadyFollowing,
    Set<String>? alreadySubscribedCanalIds,
    String? pageType,
  }) async {
    // Ne précharger que si le cache est expiré
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_keyTs);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (ts != null && (now - ts) < _ttl.inMilliseconds) return;

    try {
      final exclude = {...alreadyFollowing, myId};

      // Créateurs (pas de filtre status — les créateurs ordinaires n'ont pas ce champ)
      QuerySnapshot<Map<String, dynamic>> userSnap;
      if (pageType != null && pageType.isNotEmpty) {
        userSnap = await FirebaseFirestore.instance
            .collection('Users')
            .where('mainCategory', isEqualTo: pageType)
            .limit(60)
            .get();
      } else {
        userSnap = await FirebaseFirestore.instance
            .collection('Users')
            .limit(60)
            .get();
      }
      final creators = userSnap.docs
          .map((d) {
            try { return UserData.fromJson(d.data())..id = d.id; } catch (_) { return null; }
          })
          .whereType<UserData>()
          .where((u) => u.id != null && !exclude.contains(u.id))
          .where((u) => (u.creatorScore ?? 0) > 0 || (u.abonnes ?? 0) > 0)
          .toList()
        ..sort((a, b) => (b.creatorScore ?? 0).compareTo(a.creatorScore ?? 0));

      // Canaux
      final canalSnap = await FirebaseFirestore.instance
          .collection('Canaux')
          .limit(40)
          .get();
      final canaux = canalSnap.docs
          .map((d) {
            try { return Canal.fromJson(d.data())..id = d.id; } catch (_) { return null; }
          })
          .whereType<Canal>()
          .where((c) => c.id != null && !(alreadySubscribedCanalIds?.contains(c.id) ?? false))
          .where((c) {
            if (pageType == null || pageType.isEmpty) return true;
            return c.mainCategory == pageType || (c.categories?.contains(pageType) ?? false);
          })
          .toList()
        ..sort((a, b) => (b.canalScore ?? 0).compareTo(a.canalScore ?? 0));

      // Sérialisation
      final creatorsJson = jsonEncode(creators.take(20).map((u) => u.toJson()).toList());
      final canauxJson = jsonEncode(canaux.take(10).map((c) => c.toJson()).toList());

      await prefs.setString(_keyCreators, creatorsJson);
      await prefs.setString(_keyCanaux, canauxJson);
      await prefs.setInt(_keyTs, DateTime.now().millisecondsSinceEpoch);

      _creators = creators.take(20).toList();
      _canaux = canaux.take(10).toList();
      _loadedAt = DateTime.now();
    } catch (_) {}
  }

  /// Sauvegarde les listes déjà récupérées par le widget (évite un double fetch).
  Future<void> saveFromWidget({
    required List<UserData> users,
    required List<Canal> canaux,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final creatorsJson = jsonEncode(users.take(20).map((u) => u.toJson()).toList());
      final canauxJson = jsonEncode(canaux.take(10).map((c) => c.toJson()).toList());
      await prefs.setString(_keyCreators, creatorsJson);
      await prefs.setString(_keyCanaux, canauxJson);
      await prefs.setInt(_keyTs, DateTime.now().millisecondsSinceEpoch);
      _creators = users.take(20).toList();
      _canaux = canaux.take(10).toList();
      _loadedAt = DateTime.now();
    } catch (_) {}
  }

  /// Force la réinitialisation (ex : après follow/subscribe)
  Future<void> invalidate() async {
    _creators = null;
    _canaux = null;
    _loadedAt = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTs);
  }

  bool _isMemoryFresh() {
    if (_creators == null || _canaux == null || _loadedAt == null) return false;
    return DateTime.now().difference(_loadedAt!) < _ttl;
  }
}
