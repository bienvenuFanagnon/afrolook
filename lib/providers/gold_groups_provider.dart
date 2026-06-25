import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GoldGroupsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = false;
  bool _loaded = false;

  // Stream for official groups (real-time)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _officialSub;
  List<Map<String, dynamic>> _officialGroups = [];
  List<Map<String, dynamic>> _goldUserGroups = [];

  List<Map<String, dynamic>> get groups => _groups;
  bool get loading => _loading;
  bool get isLoaded => _loaded;

  /// Lance l'écoute temps réel des groupes officiels.
  /// Appeler une fois au démarrage (depuis initState ou un Consumer haut-niveau).
  void startStream() {
    if (_officialSub != null) return;
    _officialSub = FirebaseFirestore.instance
        .collection('GroupChats')
        .where('is_official', isEqualTo: true)
        .where('is_frozen', isEqualTo: false)
        .limit(20)
        .snapshots()
        .listen((snap) {
      _officialGroups = snap.docs.map((d) => d.data()).toList();
      _rebuildGroups();
    }, onError: (e) {
      debugPrint('GoldGroupsProvider official stream error: $e');
    });
  }

  void _rebuildGroups() {
    final officialIds = _officialGroups.map((g) => g['id'] as String?).toSet();
    final combined = [
      ..._officialGroups,
      ..._goldUserGroups.where((g) => !officialIds.contains(g['id'] as String?)),
    ];
    combined.sort((a, b) {
      final aAt = (a['last_message_at'] as int?) ?? 0;
      final bAt = (b['last_message_at'] as int?) ?? 0;
      return bAt.compareTo(aAt);
    });
    _groups = combined;
    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  /// Charge les groupes Gold des utilisateurs (one-time).
  /// [force] ignore le cache et recharge depuis Firestore.
  Future<void> load({bool force = false}) async {
    // Lance le stream si pas encore démarré
    startStream();

    if (_loading) return;
    if (!force && _loaded) return;

    _loading = true;
    notifyListeners();

    try {
      final usersSnap = await FirebaseFirestore.instance
          .collection('Users')
          .where('abonnement.type', isEqualTo: 'gold')
          .limit(50)
          .get();

      final now = DateTime.now();
      final goldUserIds = usersSnap.docs.where((d) {
        final ab = d.data()['abonnement'] as Map<String, dynamic>?;
        if (ab == null) return false;
        final dateFinStr = ab['dateFin'] as String?;
        if (dateFinStr == null) return false;
        final dateFin = DateTime.tryParse(dateFinStr);
        return dateFin != null && dateFin.isAfter(now);
      }).map((d) => d.id).toList();

      _goldUserGroups = [];
      if (goldUserIds.isNotEmpty) {
        final officialIds = _officialGroups.map((g) => g['id'] as String?).toSet();
        final groupsSnap = await FirebaseFirestore.instance
            .collection('GroupChats')
            .where('owner_id', whereIn: goldUserIds.take(10).toList())
            .where('is_frozen', isEqualTo: false)
            .limit(20)
            .get();
        for (final doc in groupsSnap.docs) {
          if (!officialIds.contains(doc.id)) _goldUserGroups.add(doc.data());
        }
        _goldUserGroups.shuffle(Random());
      }
    } catch (e) {
      debugPrint('GoldGroupsProvider.load error: $e');
    }

    _rebuildGroups();
  }

  @override
  void dispose() {
    _officialSub?.cancel();
    super.dispose();
  }
}
