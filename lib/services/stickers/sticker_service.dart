import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../models/model_data.dart';
import 'sticker_models.dart';

/// Régions des packs (valeur du champ `region`) dans l'ordre d'affichage des puces.
const List<String> kStickerRegions = ['africa', 'caribbean', 'europe', 'asia', 'latam', 'mena'];

const Set<String> _africaCodes = {
  'AO', 'BF', 'BI', 'BJ', 'BW', 'CD', 'CF', 'CG', 'CI', 'CM', 'CV', 'DJ', 'ER', 'ET', 'GA', 'GH', 'GM', 'GN', 'GQ',
  'GW', 'KE', 'KM', 'LR', 'LS', 'MG', 'ML', 'MR', 'MU', 'MW', 'MZ', 'NA', 'NE', 'NG', 'RE', 'RW', 'SC', 'SD', 'SL',
  'SN', 'SO', 'SS', 'ST', 'SZ', 'TD', 'TG', 'TZ', 'UG', 'ZA', 'ZM', 'ZW',
};
const Set<String> _caribbeanCodes = {
  'AG', 'AI', 'AW', 'BB', 'BL', 'BQ', 'BS', 'CU', 'CW', 'DM', 'DO', 'GD', 'GP', 'HT', 'JM', 'KN', 'KY', 'LC', 'MF',
  'MQ', 'MS', 'PR', 'SX', 'TC', 'TT', 'VC', 'VG', 'VI',
};
const Set<String> _europeCodes = {
  'AD', 'AL', 'AT', 'BA', 'BE', 'BG', 'BY', 'CH', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'GR', 'HR',
  'HU', 'IE', 'IS', 'IT', 'LI', 'LT', 'LU', 'LV', 'MC', 'MD', 'ME', 'MK', 'MT', 'NL', 'NO', 'PL', 'PT', 'RO', 'RS',
  'RU', 'SE', 'SI', 'SK', 'SM', 'UA', 'VA', 'XK',
};
const Set<String> _asiaCodes = {
  'AF', 'AM', 'AU', 'AZ', 'BD', 'BN', 'BT', 'CN', 'GE', 'HK', 'ID', 'IN', 'JP', 'KG', 'KH', 'KP', 'KR', 'KZ', 'LA',
  'LK', 'MM', 'MN', 'MO', 'MV', 'MY', 'NP', 'NZ', 'PH', 'PK', 'SG', 'TH', 'TJ', 'TL', 'TM', 'TW', 'UZ', 'VN',
};
const Set<String> _latamCodes = {
  'AR', 'BO', 'BR', 'BZ', 'CL', 'CO', 'CR', 'EC', 'GF', 'GT', 'GY', 'HN', 'MX', 'NI', 'PA', 'PE', 'PY', 'SR', 'SV',
  'UY', 'VE',
};
const Set<String> _menaCodes = {
  'AE', 'BH', 'DZ', 'EG', 'IL', 'IQ', 'IR', 'JO', 'KW', 'LB', 'LY', 'MA', 'OM', 'PS', 'QA', 'SA', 'SY', 'TN', 'TR', 'YE',
};

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

  /// Récents de l'utilisateur (12 max) : stickers de packs (`Stickers`) et personnels (`UserStickers`),
  /// dans l'ordre du plus récent au plus ancien.
  Future<List<StickerItem>> loadRecents(String uid) async {
    try {
      final snap = await _db
          .collection('Users')
          .doc(uid)
          .collection('StickerRecents')
          .orderBy('lastUsedAt', descending: true)
          .limit(12)
          .get();
      final docs = await Future.wait(snap.docs.map((r) async {
        final mine = (r.data()['source'] ?? 'pack') == 'mine';
        final d = await _db.collection(mine ? 'UserStickers' : 'Stickers').doc(r.id).get();
        if (!d.exists) return null;
        return mine ? StickerItem.fromUserSticker(d) : StickerItem.fromFirestore(d);
      }));
      return [
        for (final s in docs)
          if (s != null && s.url.isNotEmpty) s,
      ];
    } catch (e) {
      debugPrint('[Stickers] récents indisponibles: $e');
      return const [];
    }
  }

  // ── Régions ────────────────────────────────────────────────────────────────

  /// Région de packs correspondant au pays de l'utilisateur (code ISO `countryData['countryCode']`), null si inconnue.
  static String? regionForUser(UserData? user) {
    final code = (user?.countryData?['countryCode'] ?? '').toString().trim().toUpperCase();
    if (code.isEmpty) return null;
    if (_africaCodes.contains(code)) return 'africa';
    if (_caribbeanCodes.contains(code)) return 'caribbean';
    if (_europeCodes.contains(code)) return 'europe';
    if (_asiaCodes.contains(code)) return 'asia';
    if (_latamCodes.contains(code)) return 'latam';
    if (_menaCodes.contains(code)) return 'mena';
    return null;
  }

  // ── Packs ──────────────────────────────────────────────────────────────────

  /// Packs actifs de créateurs et du monde (égalités / `in` seulement : pas d'index composite ; tri côté app).
  Future<List<StickerPack>> loadWorldPacks({int limit = 150}) async {
    final snap = await _db
        .collection('StickerPacks')
        .where('status', isEqualTo: 'active')
        .where('kind', whereIn: const ['creator', 'world'])
        .limit(limit)
        .get();
    final packs = snap.docs.map(StickerPack.fromFirestore).toList()
      ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : b.salesCount.compareTo(a.salesCount));
    return packs;
  }

  /// Packs de créateurs (`kind == 'creator'`) triés par ventes décroissantes.
  Future<List<StickerPack>> loadCreatorPacks({int limit = 100}) async {
    final snap = await _db
        .collection('StickerPacks')
        .where('status', isEqualTo: 'active')
        .where('kind', isEqualTo: 'creator')
        .limit(limit)
        .get();
    return snap.docs.map(StickerPack.fromFirestore).toList()..sort((a, b) => b.salesCount.compareTo(a.salesCount));
  }

  /// Identifiants des packs achetés par l'utilisateur (`StickerOwnership`).
  Future<Set<String>> loadOwnedPackIds(String uid) async {
    try {
      final snap = await _db.collection('StickerOwnership').where('userId', isEqualTo: uid).limit(200).get();
      return {
        for (final d in snap.docs)
          if ((d.data()['packId'] ?? '').toString().isNotEmpty) d.data()['packId'].toString(),
      };
    } catch (e) {
      debugPrint('[Stickers] achats indisponibles: $e');
      return {};
    }
  }

  /// Packs (actifs) correspondant à ces identifiants.
  Future<List<StickerPack>> loadPacksByIds(Iterable<String> ids) async {
    final docs = await Future.wait(ids.toSet().map((id) => _db.collection('StickerPacks').doc(id).get()));
    return [
      for (final d in docs)
        if (d.exists) StickerPack.fromFirestore(d),
    ].where((p) => p.status == 'active').toList();
  }

  /// Stickers actifs d'un pack, triés par `order`.
  Future<List<StickerItem>> loadPackStickers(String packId) async {
    final snap = await _db
        .collection('Stickers')
        .where('packId', isEqualTo: packId)
        .where('status', isEqualTo: 'active')
        .get();
    return snap.docs.map(StickerItem.fromFirestore).where((s) => s.url.isNotEmpty).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Aperçu (4 miniatures) d'un pack : cache mémoire pour ne pas relire à chaque affichage.
  final Map<String, Future<List<StickerItem>>> _previewCache = {};
  Future<List<StickerItem>> packPreview(String packId) {
    return _previewCache.putIfAbsent(packId, () async {
      try {
        final snap = await _db
            .collection('Stickers')
            .where('packId', isEqualTo: packId)
            .where('status', isEqualTo: 'active')
            .limit(12)
            .get();
        final list = snap.docs.map(StickerItem.fromFirestore).where((s) => s.thumbUrl.isNotEmpty).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        return list.take(4).toList();
      } catch (_) {
        return const <StickerItem>[];
      }
    });
  }

  // ── Créateurs ──────────────────────────────────────────────────────────────

  final Map<String, StickerCreatorInfo> _creatorCache = {};

  /// Pseudo et badge vérifié des créateurs (cache mémoire). 'afrolook' = compte officiel.
  Future<Map<String, StickerCreatorInfo>> resolveCreators(Iterable<String> ids) async {
    final wanted = ids.where((id) => id.isNotEmpty).toSet();
    final missing = wanted.where((id) => !_creatorCache.containsKey(id) && id != 'afrolook').toList();
    await Future.wait(missing.map((id) async {
      try {
        final d = await _db.collection('Users').doc(id).get();
        final m = d.data() ?? const <String, dynamic>{};
        _creatorCache[id] = StickerCreatorInfo(
          id: id,
          pseudo: (m['pseudo'] ?? '').toString(),
          verified: m['isVerify'] == true,
        );
      } catch (_) {
        _creatorCache[id] = StickerCreatorInfo(id: id);
      }
    }));
    _creatorCache['afrolook'] = const StickerCreatorInfo(id: 'afrolook', pseudo: 'Afrolook', verified: true);
    return {
      for (final id in wanted)
        if (_creatorCache[id] != null) id: _creatorCache[id]!,
    };
  }

  // ── Cadeaux ────────────────────────────────────────────────────────────────

  /// Stickers-cadeaux : `giftPriceCoins > 0`, statut actif, pack actif. Un seul filtre d'inégalité (pas d'index composite).
  Future<List<StickerItem>> loadGiftStickers({int limit = 200}) async {
    final snap = await _db.collection('Stickers').where('giftPriceCoins', isGreaterThan: 0).limit(limit).get();
    final items = snap.docs
        .map(StickerItem.fromFirestore)
        .where((s) => s.status == 'active' && s.url.isNotEmpty)
        .toList();
    final packs = await loadPacksByIds(items.map((s) => s.packId).where((id) => id.isNotEmpty));
    final active = packs.map((p) => p.id).toSet();
    return items.where((s) => active.contains(s.packId)).toList()
      ..sort((a, b) => a.giftPriceCoins.compareTo(b.giftPriceCoins));
  }

  /// Offre un sticker-cadeau. Lève `FirebaseFunctionsException` (`resource-exhausted` = solde insuffisant).
  Future<void> sendGift({required StickerGiftTarget target, required String stickerId}) async {
    await FirebaseFunctions.instance.httpsCallable('stickerGiftSend').call<dynamic>({
      'commentId': target.commentId,
      if (target.replyId != null) 'replyId': target.replyId,
      'stickerId': stickerId,
    });
  }

  /// Signale un sticker copié.
  Future<void> reportCopy({required String stickerId, String? note}) async {
    await FirebaseFunctions.instance.httpsCallable('reportStickerCopy').call<dynamic>({
      'stickerId': stickerId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  // ── Mes stickers (UserStickers) ────────────────────────────────────────────

  /// Nombre de stickers personnels autorisés : Premium 10, Gold 50, admin 50, sinon 0.
  static int personalQuota(UserData user) {
    if (user.role == UserRole.ADM.name) return 50;
    final a = user.abonnement;
    if (a?.estGold == true) return 50;
    if (a?.estPremium == true) return 10;
    return 0;
  }

  /// Stickers personnels actifs, du plus récent au plus ancien.
  Future<List<StickerItem>> loadUserStickers(String uid) async {
    final snap = await _db
        .collection('UserStickers')
        .where('ownerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(60)
        .get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final x = (a.data()['createdAt'] is num) ? (a.data()['createdAt'] as num) : 0;
        final y = (b.data()['createdAt'] is num) ? (b.data()['createdAt'] as num) : 0;
        return y.compareTo(x);
      });
    return docs.map(StickerItem.fromUserSticker).where((s) => s.url.isNotEmpty).toList();
  }

  /// Supprime un sticker personnel : document, puis fichier Storage.
  Future<void> deleteUserSticker(StickerItem s) async {
    await _db.collection('UserStickers').doc(s.id).delete();
    final path = s.storagePath;
    if (path != null && path.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (e) {
        debugPrint('[Stickers] fichier déjà supprimé ou inaccessible: $e');
      }
    }
  }
}
