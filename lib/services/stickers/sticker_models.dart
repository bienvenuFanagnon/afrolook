import 'package:cloud_firestore/cloud_firestore.dart';

/// Identifiant du pack officiel Afrolook (voir docs/STICKERS_SPEC.md).
const String kOfficialStickerPackId = 'official_universel';

int _asInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

/// Un sticker (document `Stickers/{id}`).
class StickerItem {
  final String id;
  final String packId;
  final int order;
  final String category;
  final Map<String, String> captions;
  final List<String> keywords;
  final String url;
  final String thumbUrl;
  final String? storagePath;
  final int sizeBytes;
  final int durationMs;
  final bool animated;
  final int giftPriceCoins;
  final String status;
  final String? creatorId;
  final int w;
  final int h;

  /// 'pack' (Stickers) ou 'mine' (UserStickers, phase 3).
  final String source;

  const StickerItem({
    required this.id,
    this.packId = '',
    this.order = 0,
    this.category = '',
    this.captions = const {},
    this.keywords = const [],
    this.url = '',
    this.thumbUrl = '',
    this.storagePath,
    this.sizeBytes = 0,
    this.durationMs = 0,
    this.animated = true,
    this.giftPriceCoins = 0,
    this.status = 'active',
    this.creatorId,
    this.w = 512,
    this.h = 512,
    this.source = 'pack',
  });

  factory StickerItem.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    final rawCaptions = d['captions'];
    final rawKeywords = d['keywords'];
    final url = (d['url'] ?? '').toString();
    return StickerItem(
      id: doc.id,
      packId: (d['packId'] ?? '').toString(),
      order: _asInt(d['order']),
      category: (d['category'] ?? '').toString(),
      captions: rawCaptions is Map
          ? {
              for (final e in rawCaptions.entries)
                if (e.value != null && e.value.toString().trim().isNotEmpty)
                  e.key.toString(): e.value.toString(),
            }
          : const {},
      keywords: rawKeywords is List ? rawKeywords.map((e) => e.toString()).toList() : const [],
      url: url,
      thumbUrl: (d['thumbUrl'] ?? '').toString().isNotEmpty ? d['thumbUrl'].toString() : url,
      storagePath: d['storagePath']?.toString(),
      sizeBytes: _asInt(d['sizeBytes']),
      durationMs: _asInt(d['durationMs']),
      animated: d['animated'] != false,
      giftPriceCoins: _asInt(d['giftPriceCoins']),
      status: (d['status'] ?? 'active').toString(),
      creatorId: d['creatorId']?.toString(),
      w: _asInt(d['w'], 512),
      h: _asInt(d['h'], 512),
    );
  }

  /// Sticker personnel (`UserStickers/{id}`, source 'mine').
  factory StickerItem.fromUserSticker(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    final url = (d['url'] ?? '').toString();
    final thumb = (d['thumbUrl'] ?? '').toString();
    final rawCaptions = d['captions'];
    return StickerItem(
      id: doc.id,
      url: url,
      thumbUrl: thumb.isNotEmpty ? thumb : url,
      storagePath: d['storagePath']?.toString(),
      sizeBytes: _asInt(d['sizeBytes']),
      durationMs: _asInt(d['durationMs']),
      animated: d['animated'] != false,
      status: (d['status'] ?? 'pending').toString(),
      creatorId: d['ownerId']?.toString(),
      captions: rawCaptions is Map
          ? {
              for (final e in rawCaptions.entries)
                if (e.value != null && e.value.toString().trim().isNotEmpty) e.key.toString(): e.value.toString(),
            }
          : const {},
      w: _asInt(d['w'], 512),
      h: _asInt(d['h'], 512),
      source: 'mine',
    );
  }

  bool get isGift => giftPriceCoins > 0;

  /// Champ `media` écrit dans `PostComments/{id}`.
  Map<String, dynamic> toMedia() => {
        'type': source == 'mine' ? 'user_sticker' : 'sticker',
        'stickerId': id,
        'url': url,
        'thumbUrl': thumbUrl,
        'w': w,
        'h': h,
        'sizeBytes': sizeBytes,
        'animated': animated,
      };
}

/// Un pack (document `StickerPacks/{id}`).
class StickerPack {
  final String id;
  final String name;
  final Map<String, String> names;
  final String kind;
  final String region;
  final String creatorId;
  final int priceCoins;
  final String status;
  final int stickerCount;
  final int order;
  final String coverUrl;
  final int salesCount;

  const StickerPack({
    required this.id,
    this.name = '',
    this.names = const {},
    this.kind = 'official',
    this.region = 'universal',
    this.creatorId = '',
    this.priceCoins = 0,
    this.status = 'active',
    this.stickerCount = 0,
    this.order = 0,
    this.coverUrl = '',
    this.salesCount = 0,
  });

  factory StickerPack.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? const {};
    final rawNames = d['names'];
    return StickerPack(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      names: rawNames is Map
          ? {for (final e in rawNames.entries) e.key.toString(): e.value.toString()}
          : const {},
      kind: (d['kind'] ?? 'official').toString(),
      region: (d['region'] ?? 'universal').toString(),
      creatorId: (d['creatorId'] ?? '').toString(),
      priceCoins: _asInt(d['priceCoins']),
      status: (d['status'] ?? 'active').toString(),
      stickerCount: _asInt(d['stickerCount']),
      order: _asInt(d['order']),
      coverUrl: (d['coverUrl'] ?? '').toString(),
      salesCount: _asInt(d['salesCount']),
    );
  }

  String localizedName(String lang) => names[lang] ?? names['en'] ?? name;

  bool get isFree => priceCoins <= 0;
}

/// Créateur d'un pack : pseudo et badge « vérifié » (résolus depuis `Users`).
class StickerCreatorInfo {
  final String id;
  final String pseudo;
  final bool verified;
  const StickerCreatorInfo({required this.id, this.pseudo = '', this.verified = false});
}

/// Cible d'un sticker-cadeau : le commentaire (ou la réponse) à qui on l'offre.
class StickerGiftTarget {
  final String commentId;
  final String? replyId;
  const StickerGiftTarget({required this.commentId, this.replyId});
}

/// Statut d'un sticker récent renvoyé par `stickerAccess`.
class StickerRecentStatus {
  final String stickerId;
  final String source;
  final bool usable;
  final String? reason;

  const StickerRecentStatus({
    required this.stickerId,
    this.source = 'pack',
    this.usable = true,
    this.reason,
  });
}

/// Réponse du callable `stickerAccess`.
class StickerAccess {
  final String tier;
  final bool canSend;
  final String? reason;
  final int perPostMax;
  final int perDayMax;
  final int dayUsed;
  final int postUsed;
  /// Stickers offerts restants aujourd'hui (récompense « pubs »).
  final int bonusRemaining;
  final List<StickerRecentStatus> recents;

  const StickerAccess({
    this.tier = 'gratuit',
    this.canSend = true,
    this.reason,
    this.perPostMax = 0,
    this.perDayMax = 0,
    this.dayUsed = 0,
    this.postUsed = 0,
    this.bonusRemaining = 0,
    this.recents = const [],
  });

  factory StickerAccess.fromMap(Map<dynamic, dynamic> m) {
    final rawRecents = m['recents'];
    return StickerAccess(
      tier: (m['tier'] ?? 'gratuit').toString(),
      canSend: m['canSend'] != false,
      reason: m['reason']?.toString(),
      perPostMax: _asInt(m['perPostMax']),
      perDayMax: _asInt(m['perDayMax']),
      dayUsed: _asInt(m['dayUsed']),
      postUsed: _asInt(m['postUsed']),
      bonusRemaining: _asInt(m['bonusRemaining']),
      recents: rawRecents is List
          ? rawRecents.whereType<Map>().map((r) {
              return StickerRecentStatus(
                stickerId: (r['stickerId'] ?? '').toString(),
                source: (r['source'] ?? 'pack').toString(),
                usable: r['usable'] != false,
                reason: r['reason']?.toString(),
              );
            }).toList()
          : const [],
    );
  }

  /// Vrai quand les quotas sont connus (sinon mode dégradé : le serveur tranchera).
  bool get hasLimits => perPostMax > 0 || perDayMax > 0;

  /// Raison pour laquelle CE sticker n'est pas utilisable (null = utilisable).
  String? blockedReasonFor(StickerItem s, {bool isRecent = false}) {
    if (!canSend) return reason ?? 'not_subscribed';
    if (isRecent) {
      for (final r in recents) {
        if (r.stickerId == s.id) return r.usable ? null : (r.reason ?? 'inactive');
      }
    }
    return null;
  }
}
