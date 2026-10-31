import 'package:afrotok/pages/LiveAgora/livesAgora.dart';
import 'package:afrotok/services/api/jeux_api.dart';

/// Live de l'API -> [PostLive]. Le nom et la photo de l'hôte sont fournis par l'API (`host: {username, display_name, avatar_url}`) ; [hostName] et
/// [hostImage] ne servent que de secours quand elle ne les envoie pas (profil déjà connu de l'appelant).
PostLive postLiveFromApi(Map<String, dynamic> j, {String hostName = '', String hostImage = ''}) {
  final host = j['host'] is Map ? Map<String, dynamic>.from(j['host'] as Map) : const <String, dynamic>{};
  final apiName = '${host['username'] ?? ''}'.trim().isNotEmpty ? '${host['username']}'.trim() : '${host['display_name'] ?? ''}'.trim();
  final apiImage = '${host['avatar_url'] ?? ''}'.trim();
  hostName = apiName.isNotEmpty ? apiName : hostName;
  hostImage = apiImage.isNotEmpty ? apiImage : hostImage;
  final started = DateTime.tryParse('${j['started_at']}') ?? DateTime.now();
  final ended = j['ended_at'] == null ? null : DateTime.tryParse('${j['ended_at']}');
  final opts = j['options'] is Map ? Map<String, dynamic>.from(j['options'] as Map) : <String, dynamic>{};
  final fee = JeuxApi.asInt(j['participation_fee_coins']);
  return PostLive(
    liveId: '${j['id']}',
    hostId: '${j['host_id']}',
    hostName: hostName,
    hostImage: hostImage,
    title: '${j['title'] ?? ''}',
    coverImage: j['cover_url'] as String?,
    viewerCount: JeuxApi.asInt(j['viewer_count']),
    giftCount: JeuxApi.asInt(j['gift_count']),
    likeCount: JeuxApi.asInt(j['likes_count']),
    startTime: started,
    endTime: ended,
    isLive: j['is_live'] == true,
    giftTotal: JeuxApi.asInt(j['gift_coins_total']).toDouble(),
    isPaidLive: j['is_paid'] == true,
    participationFee: fee / 2.5,
    participationFeeCoinsRaw: fee,
    freeTrialMinutes: JeuxApi.asInt(j['free_trial_minutes']),
    audioBehaviorAfterTrial: '${opts['audioBehaviorAfterTrial'] ?? 'reduce'}',
    audioReductionPercent: JeuxApi.asInt(opts['audioReductionPercent'], 50),
    blurVideoAfterTrial: opts['blurVideoAfterTrial'] != false,
    showPaymentModalAfterTrial: opts['showPaymentModalAfterTrial'] != false,
    pinnedText: j['pinned_text'] as String?,
    shareCount: JeuxApi.asInt(j['shares_count']),
    liveDurationMinutes: JeuxApi.asInt(j['duration_minutes'], 30),
    isPaused: j['is_paused'] == true,
    pauseMessage: j['pause_message'] as String?,
    giftCoinsTotal: JeuxApi.asInt(j['gift_coins_total']),
  );
}
