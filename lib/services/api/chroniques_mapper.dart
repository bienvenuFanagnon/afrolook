import 'package:afrotok/pages/chronique/chroniqueform.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

String chroniqueTypeToApi(ChroniqueType t) => switch (t) {
      ChroniqueType.TEXT => 'text',
      ChroniqueType.IMAGE => 'image',
      ChroniqueType.VIDEO => 'video',
      ChroniqueType.AUDIO => 'audio',
    };

ChroniqueType chroniqueTypeFromApi(String? t) => switch (t) {
      'image' => ChroniqueType.IMAGE,
      'video' => ChroniqueType.VIDEO,
      'audio' => ChroniqueType.AUDIO,
      _ => ChroniqueType.TEXT,
    };

/// Chronique de l'API -> modèle `Chronique` de l'application (les écrans existants ne changent pas).
/// MA situation (j'aime / j'adore) est reportée dans `likers` / `lovers` ; les listes complètes n'existent plus.
/// Le nombre de commentaires et le dernier commentaire (sur Firebase) sont complétés par l'écran qui les affiche.
Chronique chroniqueFromApi(Map<String, dynamic> j, {String? myId}) {
  final author = j['author'] is Map ? Map<String, dynamic>.from(j['author'] as Map) : <String, dynamic>{};
  final music = j['music'] is Map ? Map<String, dynamic>.from(j['music'] as Map) : null;
  final created = DateTime.tryParse('${j['created_at']}') ?? DateTime.now();
  final expires = DateTime.tryParse('${j['expires_at']}') ?? created.add(const Duration(hours: 24));
  final me = myId ?? '';
  return Chronique(
    id: j['id'] as String?,
    commerce: j['commerce'] is Map ? Map<String, dynamic>.from(j['commerce'] as Map) : null,
    userId: '${author['id'] ?? ''}',
    userPseudo: '${author['username'] ?? ''}',
    userImageUrl: '${author['avatar_url'] ?? ''}',
    type: chroniqueTypeFromApi(j['type'] as String?),
    textContent: j['text'] as String?,
    mediaUrl: j['media_url'] as String?,
    coverImageUrl: j['cover_url'] as String?,
    posterUrl: j['poster_url'] as String?,
    backgroundColor: j['background_color'] as String?,
    templateId: j['template_id'] as String?,
    duration: (j['duration_sec'] as num?)?.toInt() ?? 0,
    viewCount: (j['views_count'] as num?)?.toInt() ?? 0,
    likeCount: (j['likes_count'] as num?)?.toInt() ?? 0,
    loveCount: (j['loves_count'] as num?)?.toInt() ?? 0,
    viewers: [if (j['is_mine'] == true && me.isNotEmpty) me],
    likers: [if (j['liked_by_me'] == true && me.isNotEmpty) me],
    lovers: [if (j['loved_by_me'] == true && me.isNotEmpty) me],
    createdAt: Timestamp.fromDate(created),
    expiresAt: Timestamp.fromDate(expires),
    audioStartMs: (j['audio_start_ms'] as num?)?.toInt(),
    audioEndMs: (j['audio_end_ms'] as num?)?.toInt(),
    musicKind: music?['kind'] as String?,
    musicId: music?['sound_id'] as String?,
    musicTitle: music?['title'] as String?,
    musicArtist: music == null ? null : (music['kind'] == 'artist' && (music['artist'] as String?)?.isNotEmpty == true ? '@${music['artist']}' : music['artist'] as String?),
    musicUrl: music?['url'] as String?,
    musicStartMs: (music?['start_ms'] as num?)?.toInt(),
    musicEndMs: (music?['end_ms'] as num?)?.toInt(),
    musicVolume: (music?['volume'] as num?)?.toDouble() ?? 0.7,
    videoSoundKept: music?['keep_video_sound'] == true,
    textX: (j['text_x'] as num?)?.toDouble(),
    textY: (j['text_y'] as num?)?.toDouble(),
  );
}

/// Son d'artiste de l'API -> table au format des anciens documents `artist_sounds/{id}` (lue par `ArtistSound.fromMap`).
Map<String, dynamic> artistSoundMapFromApi(Map<String, dynamic> j) {
  final artist = j['artist'] is Map ? Map<String, dynamic>.from(j['artist'] as Map) : <String, dynamic>{};
  final use = (j['use_coins'] as num?)?.toInt() ?? 0;
  final sale = (j['sale_coins'] as num?)?.toInt() ?? 0;
  final countries = j['countries'] is List ? (j['countries'] as List).map((e) => '$e').toList() : <String>[];
  final created = DateTime.tryParse('${j['created_at']}') ?? DateTime.now();
  return {
    'userId': '${j['artist_id'] ?? artist['id'] ?? ''}',
    'userPseudo': '${artist['username'] ?? ''}',
    'userImageUrl': artist['avatar_url'],
    'title': j['title'] ?? '',
    'genre': j['genre'],
    'description': j['description'],
    'previewUrl': j['preview_url'],
    'pricing': use == 0 && sale == 0 ? 'free' : 'paid',
    'coverImageUrl': j['cover_url'],
    'durationMs': (j['duration_ms'] as num?)?.toInt() ?? 0,
    'status': j['status'] ?? 'validated',
    'usageCount': (j['usage_count'] as num?)?.toInt() ?? 0,
    'totalEarningsCoins': 0,
    'postCount': (j['post_count'] as num?)?.toInt() ?? 0,
    'useCoins': use,
    'saleCoins': sale,
    'previewSec': (j['preview_sec'] as num?)?.toInt() ?? 30,
    'streamCount': (j['stream_count'] as num?)?.toInt() ?? 0,
    'likeCount': (j['like_count'] as num?)?.toInt() ?? 0,
    'availableCountries': countries,
    'createdAt': Timestamp.fromDate(created),
  };
}
