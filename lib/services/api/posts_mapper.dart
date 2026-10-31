import 'package:afrotok/models/model_data.dart';
import 'package:firebase_auth/firebase_auth.dart';

int _micros(dynamic iso) => (DateTime.tryParse('$iso')?.microsecondsSinceEpoch) ?? 0;

UserData _author(Map<String, dynamic> a) => UserData()
  ..id = a['id'] as String?
  ..pseudo = (a['username'] as String?) ?? (a['display_name'] as String?) ?? ''
  ..imageUrl = (a['avatar_url'] as String?) ?? '';

/// Sticker de l'API → format `media` de l'application ({type, stickerId, url, thumbUrl, ...}).
Map<String, dynamic>? _media(dynamic m) => m is Map ? Map<String, dynamic>.from(m) : null;

/// Commentaire de l'API → `PostComment` (les écrans existants ne changent pas). Dates en microsecondes, comme l'application.
PostComment commentFromApi(Map<String, dynamic> j) {
  final author = Map<String, dynamic>.from(j['author'] as Map? ?? const {});
  final created = _micros(j['created_at']);
  final c = PostComment(
    id: j['id'] as String?,
    post_id: j['post_id'] as String?,
    user_id: author['id'] as String?,
    status: 'VALIDE',
    message: (j['body'] as String?) ?? '',
    createdAt: created,
    updatedAt: created,
    loves: 0,
    likes: (j['likes_count'] as num?)?.toInt() ?? 0,
    comments: (j['replies_count'] as num?)?.toInt() ?? 0,
    users_like_id: j['liked_by_me'] == true ? _me() : [],
    responseComments: [],
    media: _media(j['media']),
  );
  c.user = _author(author);
  return c;
}

/// Réponse de l'API → `ResponsePostComment`.
ResponsePostComment replyFromApi(Map<String, dynamic> j) {
  final author = Map<String, dynamic>.from(j['author'] as Map? ?? const {});
  final created = _micros(j['created_at']);
  final r = ResponsePostComment(
    id: j['id'] as String?,
    post_comment_id: j['parent_id'] as String?,
    user_id: author['id'] as String?,
    user_logo_url: (author['avatar_url'] as String?) ?? '',
    user_pseudo: (author['username'] as String?) ?? '',
    message: (j['body'] as String?) ?? '',
    status: 'VALIDE',
    likes: (j['likes_count'] as num?)?.toInt() ?? 0,
    users_like_id: j['liked_by_me'] == true ? _me() : [],
    createdAt: created,
    updatedAt: created,
    media: _media(j['media']),
  );
  r.user = _author(author);
  return r;
}

/// Identifiant de la personne connectée (le j'aime d'un commentaire est reporté dans `users_like_id`, comme avant).
List<String> _me() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  return uid == null ? [] : [uid];
}
