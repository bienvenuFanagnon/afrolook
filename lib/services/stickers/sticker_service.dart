import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'sticker_models.dart';

/// Accès aux stickers : catalogue (cache mémoire), récents, quotas serveur.
/// Le serveur applique les règles ; l'app pré-vérifie et affiche.
class StickerService {
  StickerService._();
  static final StickerService instance = StickerService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<StickerItem>? _officialCache;
  Future<List<StickerItem>>? _officialLoading;

  /// Stickers actifs du pack officiel, triés par `order` (cache mémoire).
  Future<List<StickerItem>> loadOfficialStickers({bool force = false}) {
    if (!force && _officialCache != null) return Future.value(_officialCache!);
    if (!force && _officialLoading != null) return _officialLoading!;
    final f = _fetchOfficial().whenComplete(() => _officialLoading = null);
    _officialLoading = f;
    return f;
  }

  Future<List<StickerItem>> _fetchOfficial() async {
    // Seulement des égalités : pas d'index composite requis, tri fait ici.
    final snap = await _db
        .collection('Stickers')
        .where('packId', isEqualTo: kOfficialStickerPackId)
        .where('status', isEqualTo: 'active')
        .get();
    final items = snap.docs.map(StickerItem.fromFirestore).where((s) => s.url.isNotEmpty).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    _officialCache = items;
    return items;
  }

  /// Le pack officiel lui-même (pour son nom localisé), null si absent.
  Future<StickerPack?> loadOfficialPack() async {
    try {
      final doc = await _db.collection('StickerPacks').doc(kOfficialStickerPackId).get();
      return doc.exists ? StickerPack.fromFirestore(doc) : null;
    } catch (_) {
      return null;
    }
  }

  /// Légende dans la langue de l'app : repli en puis fr, sinon null.
  String? captionFor(StickerItem s, String lang) {
    for (final l in [lang, 'en', 'fr']) {
      final c = s.captions[l];
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  /// Minuscules et sans accents.
  static String normalize(String input) {
    const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    final b = StringBuffer();
    for (final ch in input.toLowerCase().trim().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  /// Recherche locale sur mots-clés et légendes (toutes langues).
  List<StickerItem> search(List<StickerItem> all, String query) {
    final terms = normalize(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return all;
    return all.where((s) {
      final hay = <String>[
        ...s.keywords.map(normalize),
        ...s.captions.values.map(normalize),
      ];
      return terms.every((t) => hay.any((h) => h.contains(t)));
    }).toList();
  }

  /// Appel du callable `stickerAccess` ; null en cas d'échec (mode dégradé).
  Future<StickerAccess?> fetchAccess({String? postId}) async {
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('stickerAccess')
          .call<dynamic>({if (postId != null) 'postId': postId})
          .timeout(const Duration(seconds: 12));
      final data = res.data;
      if (data is Map) return StickerAccess.fromMap(data);
    } catch (e) {
      debugPrint('[Stickers] stickerAccess indisponible: $e');
    }
    return null;
  }

  /// Récents de l'utilisateur (12 max), résolus depuis `Stickers/{id}`.
  Future<List<StickerItem>> loadRecents(String uid) async {
    try {
      final snap = await _db
          .collection('Users')
          .doc(uid)
          .collection('StickerRecents')
          .orderBy('lastUsedAt', descending: true)
          .limit(12)
          .get();
      final ids = <String>[
        for (final d in snap.docs)
          if ((d.data()['source'] ?? 'pack') == 'pack') d.id,
      ];
      final docs = await Future.wait(ids.map((id) => _db.collection('Stickers').doc(id).get()));
      return [
        for (final d in docs)
          if (d.exists) StickerItem.fromFirestore(d),
      ].where((s) => s.url.isNotEmpty).toList();
    } catch (e) {
      debugPrint('[Stickers] récents indisponibles: $e');
      return const [];
    }
  }
}
