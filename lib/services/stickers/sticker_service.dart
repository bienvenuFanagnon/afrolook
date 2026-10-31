import 'dart:async';

import '../api/api_gateway.dart';
import '../api/users_api.dart';
import '../api/wallet_api.dart';
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

  dynamic get _c => ApiGateway.instance.client;

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
    final items = await loadPackStickers(kOfficialStickerPackId);
    _officialCache = items;
    return items;
  }

  /// Le pack officiel lui-même (pour son nom localisé), null si absent.
  Future<StickerPack?> loadOfficialPack() async {
    try {
      final d = WalletApi.map(await _c.get('/stickers/packs/$kOfficialStickerPackId'));
      return d.isEmpty ? null : StickerPack.fromApi(d);
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

  /// Quotas et droits (`GET /stickers/access`) ; null en cas d'échec (mode dégradé : l'API tranchera).
  Future<StickerAccess?> fetchAccess({String? postId}) async {
    try {
      final r = await _c.get('/stickers/access', query: {if (postId != null) 'post_id': postId}) as dynamic;
      final d = WalletApi.map(r);
      if (d.isNotEmpty) return StickerAccess.fromMap(d);
    } catch (e) {
      debugPrint('[Stickers] accès indisponible: $e');
    }
    return null;
  }

  /// Récents de l'utilisateur (12 max), du plus récent au plus ancien. L'API donne les identifiants ; le détail est retrouvé dans
  /// le pack officiel, les cadeaux et mes stickers (voir lacunes_api_argent_creations.md : il manque `GET /stickers/{id}`).
  Future<List<StickerItem>> loadRecents(String uid) async {
    try {
      final access = await fetchAccess();
      if (access == null || access.recents.isEmpty) return const [];
      final known = <String, StickerItem>{};
      for (final s in await loadOfficialStickers()) {
        known[s.id] = s;
      }
      for (final s in _giftCache ?? const <StickerItem>[]) {
        known[s.id] = s;
      }
      final mine = access.recents.any((r) => r.source == 'mine') ? await loadUserStickers(uid) : const <StickerItem>[];
      for (final s in mine) {
        known[s.id] = s;
      }
      return [
        for (final r in access.recents)
          if (known[r.stickerId] != null) known[r.stickerId]!,
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

  Future<List<StickerPack>> _packs() async => WalletApi.list(await _c.get('/stickers/packs')).map(StickerPack.fromApi).toList();

  /// Packs actifs de créateurs et du monde (tri côté application).
  Future<List<StickerPack>> loadWorldPacks({int limit = 150}) async {
    final packs = (await _packs()).where((p) => p.kind == 'creator' || p.kind == 'world').take(limit).toList()
      ..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : b.salesCount.compareTo(a.salesCount));
    return packs;
  }

  /// Packs de créateurs (`kind == 'creator'`) triés par ventes décroissantes.
  Future<List<StickerPack>> loadCreatorPacks({int limit = 100}) async =>
      (await _packs()).where((p) => p.kind == 'creator').take(limit).toList()..sort((a, b) => b.salesCount.compareTo(a.salesCount));

  /// Identifiants des packs utilisables par la personne (gratuits, à elle ou achetés) — calculé par l'API.
  Future<Set<String>> loadOwnedPackIds(String uid) async {
    try {
      return {for (final p in await _packs()) if (p.owned) p.id};
    } catch (e) {
      debugPrint('[Stickers] achats indisponibles: $e');
      return {};
    }
  }

  /// Packs (actifs) correspondant à ces identifiants.
  Future<List<StickerPack>> loadPacksByIds(Iterable<String> ids) async {
    final wanted = ids.toSet();
    return (await _packs()).where((p) => wanted.contains(p.id) && p.status == 'active').toList();
  }

  final Map<String, Future<List<StickerItem>>> _packCache = {};

  /// Stickers actifs d'un pack, triés par `order` (un appel par pack et par session).
  Future<List<StickerItem>> loadPackStickers(String packId) {
    return _packCache[packId] ??= () async {
      final d = WalletApi.map(await _c.get('/stickers/packs/$packId'));
      final list = [for (final m in (d['stickers'] as List? ?? const [])) if (m is Map) StickerItem.fromApi(Map<String, dynamic>.from(m))]
          .where((s) => s.url.isNotEmpty)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return list;
    }()
        .catchError((Object e) {
      _packCache.remove(packId);
      throw e;
    });
  }

  /// Aperçu (4 miniatures) d'un pack.
  Future<List<StickerItem>> packPreview(String packId) async {
    try {
      final list = (await loadPackStickers(packId)).where((s) => s.thumbUrl.isNotEmpty).toList();
      return list.take(4).toList();
    } catch (_) {
      return const <StickerItem>[];
    }
  }

  // ── Créateurs ──────────────────────────────────────────────────────────────

  final Map<String, StickerCreatorInfo> _creatorCache = {};

  /// Pseudo et badge vérifié des créateurs (cache mémoire). 'afrolook' = compte officiel.
  Future<Map<String, StickerCreatorInfo>> resolveCreators(Iterable<String> ids) async {
    final wanted = ids.where((id) => id.isNotEmpty).toSet();
    final missing = wanted.where((id) => !_creatorCache.containsKey(id) && id != 'afrolook').toList();
    await Future.wait(missing.map((id) async {
      try {
        final m = await UsersApi.publicProfile(id);
        final u = m['user'] is Map ? Map<String, dynamic>.from(m['user'] as Map) : m;
        _creatorCache[id] = StickerCreatorInfo(
          id: id,
          pseudo: (u['username'] ?? u['display_name'] ?? '').toString(),
          verified: u['is_verified'] == true || u['verified'] == true,
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

  /// Cache mémoire des stickers-cadeaux : l'onglet « Cadeaux » s'affiche aussitôt, puis se rafraîchit en douce.
  List<StickerItem>? _giftCache;
  List<StickerItem>? get cachedGiftStickers => _giftCache;

  /// À appeler dès l'ouverture des commentaires : la liste est prête quand l'utilisateur touche « Offrir un sticker ».
  void prefetchGiftStickers() {
    if (_giftCache != null) return;
    loadGiftStickers().catchError((_) => <StickerItem>[]);
  }

  /// Stickers-cadeaux (prix de cadeau > 0) des packs actifs. Il n'existe pas encore de liste dédiée dans l'API
  /// (voir lacunes_api_argent_creations.md : `GET /stickers/gifts`) : on parcourt les packs.
  Future<List<StickerItem>> loadGiftStickers({int limit = 200}) async {
    final packs = (await _packs()).where((p) => p.status == 'active').take(25).toList();
    final lists = await Future.wait(packs.map((p) => loadPackStickers(p.id).catchError((_) => <StickerItem>[])));
    final list = [for (final l in lists) ...l.where((s) => s.giftPriceCoins > 0)].take(limit).toList()
      ..sort((a, b) => a.giftPriceCoins.compareTo(b.giftPriceCoins));
    _giftCache = list;
    return list;
  }

  /// Offre un sticker-cadeau (clé d'idempotence conservée). Lève une `ApiException` (402 = solde insuffisant).
  Future<void> sendGift({required StickerGiftTarget target, required String stickerId}) async {
    await WalletApi.instance.pay('stickergift:${target.replyId ?? target.commentId}:$stickerId', '/stickers/gifts',
        body: {'comment_id': target.replyId ?? target.commentId, 'sticker_id': stickerId});
  }

  /// Signale un sticker copié.
  Future<void> reportCopy({required String stickerId, String? note}) async {
    await _c.post('/stickers/$stickerId/report', body: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
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
    final r = await _c.get('/stickers/mine');
    return WalletApi.list(r).map((m) => StickerItem.fromApi({...m, 'owner_id': uid}, source: 'mine')).where((s) => s.url.isNotEmpty).toList();
  }

  /// Supprime un sticker personnel.
  Future<void> deleteUserSticker(StickerItem s) async {
    await _c.delete('/stickers/mine/${s.id}');
  }
}
