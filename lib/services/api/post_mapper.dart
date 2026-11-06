import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/post_social_models.dart';

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
  // Fichier principal : pour un son ou une vidéo, le premier média DE CE TYPE (une jaquette ou une image d'illustration ne doit jamais être lue comme un son)
  final wanted = dataType == 'AUDIO' ? 'audio' : (dataType == 'VIDEO' ? 'video' : null);
  Map<String, dynamic>? main = first;
  if (wanted != null) {
    for (final m in media) {
      if (m['kind'] == wanted) {
        main = m;
        break;
      }
    }
  }
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
    ..hasCommerce = j['has_commerce'] == true
    ..images = imageUrls
    ..url_media = dataType == 'IMAGE' ? (imageUrls.isEmpty ? null : imageUrls.first) : main?['url'] as String?
    ..thumbnail = (main?['thumbnail_url'] ?? first?['thumbnail_url']) as String?
    ..loves = (counts['likes'] as num?)?.toInt() ?? 0
    ..likes = 0
    ..comments = (counts['comments'] as num?)?.toInt() ?? 0
    ..partage = (counts['shares'] as num?)?.toInt() ?? 0
    ..adSupportCount = (counts['ad_support'] as num?)?.toInt() ?? 0
    // L'API ne donne que le NOMBRE de republications (`counts.reposts`) : le modèle n'a qu'une liste d'identifiants (`users_republier_id`), dont les
    // écrans affichent la longueur. On la remplit d'autant d'entrées vides ; l'appartenance de la personne connectée y est ajoutée après sa republication.
    ..users_republier_id = List<String>.filled((counts['reposts'] as num?)?.toInt() ?? 0, '', growable: true)
    ..vues = (counts['views'] as num?)?.toInt() ?? 0
    ..uniqueViewsCount = (counts['views'] as num?)?.toInt() ?? 0
    ..monetized = j['is_monetized'] == true
    ..availableCountries = (j['countries'] as List? ?? const []).map((e) => '$e').toList()
    ..postInterests = (j['interests'] as List? ?? const []).map((e) => '$e').toList()
    ..categorie = j['category'] as String?
    ..isPortrait = j['is_portrait'] as bool?
    ..captureSource = j['capture_source'] as String?
    ..voiceEffect = j['voice_effect'] as String?
    ..replyToPostId = (j['reply_to'] is Map ? (j['reply_to'] as Map)['id'] : null) as String?
    ..replyToUsername = (j['reply_to'] is Map && (j['reply_to'] as Map)['author'] is Map ? ((j['reply_to'] as Map)['author'] as Map)['username'] : null) as String?
    ..replyToExcerpt = (j['reply_to'] is Map ? (j['reply_to'] as Map)['excerpt'] : null) as String?
    ..feedReason = j['reason'] as String?;
  // Situation de la personne connectée (champs souhaités côté API : voir lacunes_api_publications.md)
  final me = ApiIdentity.myId; // identifiant API (celui de loginUserData.id), pas l'uid Firebase
  if (me != null) {
    post.users_love_id = j['liked_by_me'] == true ? [me] : [];
    post.users_favorite_id = j['favorited_by_me'] == true ? [me] : [];
  }
  _applyDefi(post, j, me);
  // Fil des abonnements : publication republiée par un compte suivi (bloc `reposted_by`, absent ailleurs). Le bandeau « a republié » des écrans lit ces champs.
  final by = RepostedBy.fromJson(j['reposted_by']);
  if (by != null) {
    post
      ..isRepost = true
      ..reposterUserId = by.id
      ..reposterPseudo = by.username
      ..reposterImageUrl = by.avatarUrl.isEmpty ? null : by.avatarUrl;
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

/// Données d'un défi (bloc `defi`) ou d'une participation (bloc `defi_response`) : reconstruit ce que les écrans lisaient avant dans le document Firestore.
void _applyDefi(Post post, Map<String, dynamic> j, String? me) {
  final d = j['defi'];
  if (d is Map) {
    final over = d['status'] == 'ended';
    final endMs = DateTime.tryParse('${d['ends_at']}')?.millisecondsSinceEpoch ?? 0;
    post.type = 'DEFI';
    post.defiConfigMap = {
      'cagnotte_pieces': d['jackpot_coins'],
      'participation_fee': d['participation_fee'],
      'vote_fee': d['vote_fee'],
      'winners_count': d['winners_count'],
      'reward_split': d['reward_split'],
      'end_date': endMs,
      'status': over ? 'termine' : 'en_cours',
      if (over) 'payout_status': 'paye',
    };
    post.defiParticipantCount = (d['participants_count'] as num?)?.toInt() ?? 0;
    post.defiParticipantIds = d['participated_by_me'] == true && me != null ? [me] : [];
    post.defiVoterIds = d['voted_by_me'] == true && me != null ? [me] : [];
    post.defiWinners = (d['winners'] as List? ?? const []).whereType<Map>().map((w) {
      final m = Map<String, dynamic>.from(w);
      return DefiWinner(
        userId: '${m['user_id']}',
        postId: '${m['post_id']}',
        rank: (m['rank'] as num?)?.toInt() ?? 0,
        coins: (m['coins'] as num?)?.toInt() ?? 0,
        votes: (m['votes'] as num?)?.toInt() ?? 0,
        pseudo: '${m['username'] ?? ''}',
        imageUrl: '${m['avatar_url'] ?? ''}',
      );
    }).toList();
  }
  final r = j['defi_response'];
  if (r is Map) {
    post.defiResponseToPostId = '${r['defi_id']}';
    post.defiVotes = (r['votes_count'] as num?)?.toInt() ?? 0;
    post.defiVoterIds = r['voted_by_me'] == true && me != null ? [me] : [];
  }
}
