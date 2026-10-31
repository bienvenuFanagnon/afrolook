import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/wallet_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Un document d'administration des stickers (pack, sticker ou signalement) avec les noms de champs déjà utilisés par les écrans.
class StickerDoc {
  StickerDoc(this.id, this._data);
  final String id;
  final Map<String, dynamic> _data;
  bool get exists => true;
  Map<String, dynamic> data() => _data;
}

/// Accès à l'API : modération des stickers (équipe).
/// Seule l'action de modération (`POST /admin/stickers/actions`) et le détail d'un pack (`GET /stickers/packs/{id}`) existent aujourd'hui.
/// Les listes d'administration (packs en attente, signalements, catalogue complet) sont des points d'accès PRÉVUS : tant qu'ils sont absents,
/// les écrans affichent l'erreur et « Réessayer » (voir lacunes_api_argent_creations.md).
class StickersAdminApi {
  StickersAdminApi._();

  static dynamic get _c => ApiGateway.instance.client;

  static int _ms(dynamic iso) => DateTime.tryParse('$iso')?.millisecondsSinceEpoch ?? 0;

  /// Pack de l'API → champs de l'écran.
  static StickerDoc pack(Map<String, dynamic> m) => StickerDoc('${m['id']}', {
        'name': m['name'],
        'status': m['status'],
        'kind': m['kind'],
        'region': m['region'],
        'creatorId': m['creator_id'] ?? '',
        'priceCoins': m['price_coins'],
        'stickerCount': m['sticker_count'],
        'salesCount': m['sales_count'],
        'rejectReason': m['reject_reason'],
        'coverUrl': m['cover_url'],
        'needsReview': m['needs_review'] == true,
        'createdAt': _ms(m['created_at']),
      });

  /// Sticker de l'API → champs de l'écran.
  static StickerDoc sticker(Map<String, dynamic> m) => StickerDoc('${m['id']}', {
        'packId': m['pack_id'],
        'order': m['sort'],
        'category': m['category'],
        'captions': m['captions'],
        'url': m['url'],
        'thumbUrl': m['thumb_url'] ?? m['url'],
        'status': m['status'] ?? 'active',
        'giftPriceCoins': m['gift_price_coins'],
        'creatorId': m['creator_id'] ?? '',
        'copyOf': m['copy_of'] ?? '',
        'copyOfCreator': m['copy_of_creator'],
        'animated': m['animated'],
        'createdAt': _ms(m['created_at']),
        'sizeBytes': m['size_bytes'],
        'w': m['width'],
        'h': m['height'],
      });

  /// [mode] : pending | active | all. Point d'accès prévu : GET /admin/stickers/packs?status=
  static Future<List<StickerDoc>> packs(String mode) async =>
      WalletApi.list(await _c.get('/admin/stickers/packs', query: {'status': mode})).map(pack).toList();

  /// Un pack (visible par l'équipe quel que soit son statut).
  static Future<StickerDoc?> packById(String id) async {
    try {
      return pack(WalletApi.map(await _c.get('/stickers/packs/$id')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  static Future<List<StickerDoc>> stickersOfPack(String id) async {
    final d = WalletApi.map(await _c.get('/stickers/packs/$id'));
    return [for (final m in (d['stickers'] as List? ?? const [])) if (m is Map) sticker({...Map<String, dynamic>.from(m), 'creator_id': d['creator_id']})];
  }

  /// Signalements ouverts. Point d'accès prévu : GET /admin/stickers/reports
  static Future<List<StickerDoc>> reports() async => [
        for (final m in WalletApi.list(await _c.get('/admin/stickers/reports', query: {'status': 'open'})))
          StickerDoc('${m['id']}', {
            'stickerId': m['sticker_id'],
            'packId': m['pack_id'],
            'creatorId': m['creator_id'],
            'reporterId': m['reporter_id'],
            'note': m['note'],
            'createdAt': _ms(m['created_at']),
          }),
      ];

  /// Classe un signalement. Point d'accès prévu : POST /admin/stickers/reports/{id}/close
  static Future<void> closeReport(String id, String resolution) => _c.post('/admin/stickers/reports/$id/close', body: {'resolution': resolution});

  /// Un sticker (fiche). Point d'accès prévu : GET /admin/stickers/stickers/{id}
  static Future<StickerDoc?> stickerById(String id) async {
    try {
      return sticker(WalletApi.map(await _c.get('/admin/stickers/stickers/$id')));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Catalogue : [filter] = all | active | pending | removed | copies | official ; [q] = recherche. Point d'accès prévu : GET /admin/stickers/stickers
  static Future<({List<StickerDoc> items, bool more})> catalog({required String filter, String q = '', int page = 1}) async {
    final r = await _c.get('/admin/stickers/stickers', query: {'filter': filter, if (q.isNotEmpty) 'q': q, 'page': page});
    return (items: WalletApi.list(r).map(sticker).toList(), more: r is Map && r['has_more'] == true);
  }

  /// Signalements et actions d'administration d'un sticker. Point d'accès prévu : GET /admin/stickers/stickers/{id}/history
  static Future<({int reports, List<Map<String, dynamic>> actions})> history(String id) async {
    final d = WalletApi.map(await _c.get('/admin/stickers/stickers/$id/history'));
    return (
      reports: (d['reports'] as num?)?.toInt() ?? 0,
      actions: [for (final a in (d['actions'] as List? ?? const [])) if (a is Map) Map<String, dynamic>.from(a)],
    );
  }

  /// Modération : [action] = approve | reject | remove | restore (motif obligatoire pour refuser).
  static Future<void> action({String? packId, String? stickerId, required String action, String? reason}) =>
      _c.post('/admin/stickers/actions', body: {
        if (packId != null) 'pack_id': packId,
        if (stickerId != null) 'sticker_id': stickerId,
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
}
