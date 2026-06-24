import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GoldGroupsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = false;
  bool _loaded = false;
  DateTime? _lastFetch;

  List<Map<String, dynamic>> get groups => _groups;
  bool get loading => _loading;
  bool get isLoaded => _loaded;

  /// Charge les groupes Gold + officiels. Si déjà chargés depuis moins de 10 min,
  /// ne refait pas la requête (sauf [force] = true).
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (!force && _loaded && _lastFetch != null) {
      final age = DateTime.now().difference(_lastFetch!);
      if (age.inMinutes < 10) return;
    }

    _loading = true;
    notifyListeners();

    try {
      final officialFuture = FirebaseFirestore.instance
          .collection('GroupChats')
          .where('is_official', isEqualTo: true)
          .where('is_frozen', isEqualTo: false)
          .limit(20)
          .get();

      final usersFuture = FirebaseFirestore.instance
          .collection('Users')
          .where('abonnement.type', isEqualTo: 'gold')
          .limit(50)
          .get();

      final results = await Future.wait([officialFuture, usersFuture]);
      final officialSnap = results[0];
      final usersSnap = results[1];

      final now = DateTime.now();
      final goldUserIds = usersSnap.docs.where((d) {
        final ab = d.data()['abonnement'] as Map<String, dynamic>?;
        if (ab == null) return false;
        final dateFinStr = ab['dateFin'] as String?;
        if (dateFinStr == null) return false;
        final dateFin = DateTime.tryParse(dateFinStr);
        return dateFin != null && dateFin.isAfter(now);
      }).map((d) => d.id).toList();

      final officialGroups = officialSnap.docs.map((d) => d.data()).toList();
      final officialIds = officialSnap.docs.map((d) => d.id).toSet();

      final goldGroups = <Map<String, dynamic>>[];
      if (goldUserIds.isNotEmpty) {
        final groupsSnap = await FirebaseFirestore.instance
            .collection('GroupChats')
            .where('owner_id', whereIn: goldUserIds.take(10).toList())
            .where('is_frozen', isEqualTo: false)
            .limit(20)
            .get();
        for (final doc in groupsSnap.docs) {
          if (!officialIds.contains(doc.id)) goldGroups.add(doc.data());
        }
      }

      goldGroups.shuffle(Random());
      _groups = [...officialGroups, ...goldGroups];
      _loaded = true;
      _lastFetch = DateTime.now();
    } catch (e) {
      debugPrint('GoldGroupsProvider error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
