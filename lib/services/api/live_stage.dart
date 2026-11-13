/// Scène d'un live à plusieurs : personnes sur scène, demandes (le spectateur lève la main), invitations de l'hôte, places selon l'abonnement.
/// Lu depuis `GET /lives/{id}/stage` (interrogé toutes les quelques secondes pendant le live).
class StageUser {
  const StageUser({required this.id, required this.username, this.avatarUrl});

  final String id;
  final String username;
  final String? avatarUrl;

  static StageUser? fromJson(Object? j) {
    if (j is! Map) return null;
    final name = (j['username'] ?? j['display_name'] ?? '') as Object;
    return StageUser(id: '${j['id']}', username: '$name', avatarUrl: j['avatar_url'] as String?);
  }

  String get initials {
    final t = username.replaceAll('@', '').trim();
    return t.isEmpty ? '?' : t.substring(0, t.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class StageSpeaker {
  const StageSpeaker({required this.user, required this.media, this.agoraUid});

  final StageUser user;

  /// `video` (caméra et micro) ou `audio` (micro seul).
  final String media;
  final int? agoraUid;

  bool get isVideo => media == 'video';
}

class StageRequest {
  const StageRequest({required this.id, required this.source, required this.media, required this.coins, required this.status, this.user, this.expiresAt});

  final String id;

  /// `request` (le spectateur lève la main) ou `invite` (l'hôte invite).
  final String source;
  final String media;

  /// Prix de la place, débité seulement quand l'hôte accepte (0 : place gratuite).
  final int coins;
  final String status;
  final StageUser? user;
  final DateTime? expiresAt;

  bool get isInvite => source == 'invite';

  static StageRequest? fromJson(Object? j) {
    if (j is! Map) return null;
    final e = j['expires_at'];
    return StageRequest(
      id: '${j['id']}',
      source: '${j['source']}',
      media: '${j['media']}',
      coins: j['coins'] is num ? (j['coins'] as num).toInt() : 0,
      status: '${j['status']}',
      user: StageUser.fromJson(j['user']),
      expiresAt: e is String ? DateTime.tryParse(e)?.toLocal() : null,
    );
  }
}

class LiveStageState {
  const LiveStageState({
    this.enabled = true,
    this.maxVideo = 0,
    this.maxAudio = 0,
    this.usedVideo = 0,
    this.usedAudio = 0,
    this.placeCoins = 0,
    this.speakers = const [],
    this.requests = const [],
    this.invited = const [],
    this.mine,
    this.onStage = false,
    this.hostAgoraUid,
  });

  /// L'hôte a ouvert la scène (« Inviter sur scène » activé).
  final bool enabled;
  final int maxVideo;
  final int maxAudio;
  final int usedVideo;
  final int usedAudio;

  /// Prix d'une place demandée par un spectateur ; 0 si elle est gratuite pour lui.
  final int placeCoins;
  final List<StageSpeaker> speakers;

  /// Hôte : demandes en attente.
  final List<StageRequest> requests;

  /// Hôte : personnes déjà invitées (invitation en attente).
  final List<String> invited;

  /// Spectateur : sa demande ou son invitation en attente.
  final StageRequest? mine;
  final bool onStage;
  final int? hostAgoraUid;

  bool get videoFull => usedVideo >= maxVideo;
  bool get audioFull => usedAudio >= maxAudio;

  /// Texte « 3 vidéo sur 4 · 2 audio sur 5 » (même ligne que la maquette).
  String get placesLabel => '$usedVideo vidéo sur $maxVideo · $usedAudio audio sur $maxAudio';

  List<StageSpeaker> get videoSpeakers => speakers.where((s) => s.isVideo).toList();
  List<StageSpeaker> get audioSpeakers => speakers.where((s) => !s.isVideo).toList();

  static LiveStageState fromJson(Map<String, dynamic> j) {
    int i(Object? v) => v is num ? v.toInt() : 0;
    final lim = j['limits'] is Map ? j['limits'] as Map : const {};
    final used = j['used'] is Map ? j['used'] as Map : const {};
    return LiveStageState(
      enabled: j['enabled'] != false,
      maxVideo: i(lim['video']),
      maxAudio: i(lim['audio']),
      usedVideo: i(used['video']),
      usedAudio: i(used['audio']),
      placeCoins: i(j['place_coins']),
      speakers: [
        for (final s in (j['speakers'] as List? ?? const []))
          if (s is Map && StageUser.fromJson(s['user']) != null)
            StageSpeaker(user: StageUser.fromJson(s['user'])!, media: '${s['media']}', agoraUid: s['agora_uid'] is num ? (s['agora_uid'] as num).toInt() : null),
      ],
      requests: [for (final r in (j['requests'] as List? ?? const [])) if (StageRequest.fromJson(r) != null) StageRequest.fromJson(r)!],
      invited: [for (final u in (j['invited'] as List? ?? const [])) '$u'],
      mine: StageRequest.fromJson(j['mine']),
      onStage: j['on_stage'] == true,
      hostAgoraUid: j['host_agora_uid'] is num ? (j['host_agora_uid'] as num).toInt() : null,
    );
  }
}
