import 'package:afrotok/models/model_data.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Convertit une publication de la nouvelle API en modèle `Post` de l'application (les écrans existants ne changent pas).
Post postFromApi(Map<String, dynamic> j) {
  final media = (j['media'] as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  final imageUrls = media.where((m) => m['kind'] == 'image').map((m) => '${m['url']}').toList();
  final first = media.isEmpty ? null : media.first;
  final dataType = switch (j['media_kind']) {
    'image' => 'IMAGE',
    'video' => 'VIDEO',
    'audio' => 'AUDIO',
    _ => 'TEXT',
  };
  final counts = Map<String, dynamic>.from(j['counts'] as Map? ?? const {});
  final created = DateTime.tryParse('${j['created_at']}')?.millisecondsSinceEpoch ?? 0;
  final author = Map<String, dynamic>.from(j['author'] as Map? ?? const {});
  final post = Post(
    id: j['id'] as String?,
    user_id: author['id'] as String?,
    type: 'POST',
    status: 'VALIDE',
    dataType: dataType,
    description: j['description'] as String?,
    urlLink: j['link_url'] as String?,
    createdAt: created,
    updatedAt: created,
  );
  post
    ..canal_id = j['channel_id'] as String?
    ..images = imageUrls
    ..url_media = dataType == 'IMAGE' ? (imageUrls.isEmpty ? null : imageUrls.first) : first?['url'] as String?
    ..thumbnail = first?['thumbnail_url'] as String?
    ..loves = (counts['likes'] as num?)?.toInt() ?? 0
    ..likes = 0
    ..comments = (counts['comments'] as num?)?.toInt() ?? 0
    ..partage = (counts['shares'] as num?)?.toInt() ?? 0
    ..vues = (counts['views'] as num?)?.toInt() ?? 0
    ..uniqueViewsCount = (counts['views'] as num?)?.toInt() ?? 0
    ..monetized = j['is_monetized'] == true
    ..availableCountries = (j['countries'] as List? ?? const []).map((e) => '$e').toList()
    ..postInterests = (j['interests'] as List? ?? const []).map((e) => '$e').toList()
    ..categorie = j['category'] as String?;
  // Situation de la personne connectée (champs souhaités côté API : voir lacunes_api_publications.md)
  final me = FirebaseAuth.instance.currentUser?.uid;
  if (me != null) {
    post.users_love_id = j['liked_by_me'] == true ? [me] : [];
    post.users_favorite_id = j['favorited_by_me'] == true ? [me] : [];
  }
  final sound = j['sound'];
  if (sound is Map) {
    post.artistSoundId = sound['id'] as String?;
    post.artistSoundTitle = sound['title'] as String?;
  }
  final u = UserData()
    ..id = author['id'] as String?
    ..pseudo = (author['username'] as String?) ?? ''
    ..imageUrl = (author['avatar_url'] as String?) ?? '';
  post.user = u;
  return post;
}
