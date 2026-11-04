import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/afrolook_ads_pool.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le stock du serveur (`GET /ads/app/pool`) est converti dans la forme que le widget d'annonce relit depuis toujours :
/// `{ad: <Advertisement>, post: <Post>|null, isEntityBoost: bool}`. Chaque forme doit se relire avec `fromJson`, comme le fait le widget.
Map<String, dynamic> _web({String? ends}) => {
      'id': 'ad-web-1', 'source': 'web', 'target_type': null, 'target_id': null, 'post_id': null, 'owner': null, 'post': null,
      'title': 'Boutique Awa', 'text': 'Des pagnes magnifiques', 'cta': 'Visiter', 'action_url': 'https://awa.example.com', 'paid': false,
      'media': {'type': 'image', 'url': 'https://cdn.test/a.jpg', 'thumb': 'https://cdn.test/t.jpg', 'duration': 0, 'images': ['https://cdn.test/a.jpg']},
      'ends_at': ends ?? DateTime.now().add(const Duration(days: 5)).toUtc().toIso8601String(),
    };

void main() {
  test('annonce d\'Afrolook Ads : une carte « publication » faite avec son visuel, bouton vers le lien de l\'annonceur', () {
    final m = AfrolookAdsPool.toLegacy(_web())!;
    expect(m['isEntityBoost'], false);
    final ad = Advertisement.fromJson(Map<String, dynamic>.from(m['ad'] as Map));
    final post = Post.fromJson(Map<String, dynamic>.from(m['post'] as Map));
    expect(ad.id, 'ad-web-1');
    expect(ad.status, 'active');
    expect(ad.actionUrl, 'https://awa.example.com');
    expect(ad.actionButtonText, 'Visiter');
    expect(ad.description, 'Des pagnes magnifiques');
    expect(post.id, 'ad_ad-web-1');   // le widget reconnaît ce préfixe : il ouvre le lien au lieu d'une page de publication
    expect(post.dataType, 'IMAGE');
    expect(post.url_media, 'https://cdn.test/a.jpg');
    expect(post.thumbnail, 'https://cdn.test/t.jpg');
    expect(post.images, ['https://cdn.test/a.jpg']);
  });

  test('annonce vidéo : la publication est de type vidéo', () {
    final it = _web()..['media'] = {'type': 'video', 'url': 'https://cdn.test/v.mp4', 'thumb': 'https://cdn.test/t.jpg', 'duration': 12, 'images': <String>[]};
    final post = Post.fromJson(Map<String, dynamic>.from(AfrolookAdsPool.toLegacy(it)!['post'] as Map));
    expect(post.dataType, 'VIDEO');
    expect(post.url_media, 'https://cdn.test/v.mp4');
  });

  test('boost de profil : carte « entité » sans publication, avec nom, avatar et type', () {
    final m = AfrolookAdsPool.toLegacy({
      ..._web(), 'id': 'b1', 'target_type': 'profile', 'target_id': 'user-9', 'title': 'Awa Boutique', 'text': 'Mode africaine', 'source': null, 'paid': true,
      'owner': {'id': 'user-9', 'name': 'Awa Boutique', 'avatar': 'https://cdn.test/av.jpg'},
    })!;
    expect(m['isEntityBoost'], true);
    expect(m['post'], isNull);
    final ad = Advertisement.fromJson(Map<String, dynamic>.from(m['ad'] as Map));
    expect(ad.ownerType, 'user');
    expect(ad.ownerId, 'user-9');
    expect(ad.ownerName, 'Awa Boutique');
    expect(ad.ownerAvatar, 'https://cdn.test/t.jpg');
    expect(ad.ownerDescription, 'Mode africaine');
  });

  test('boost de canal et de groupe : types propres à l\'application', () {
    String typeOf(String t) => Advertisement.fromJson(Map<String, dynamic>.from(AfrolookAdsPool.toLegacy({..._web(), 'target_type': t, 'target_id': 'x1'})!['ad'] as Map)).ownerType!;
    expect(typeOf('canal'), 'canal');
    expect(typeOf('group'), 'group');
  });

  test('boost de publication : la publication jointe par le serveur est reprise, avec son auteur', () {
    final m = AfrolookAdsPool.toLegacy({
      ..._web(), 'id': 'b2', 'target_type': 'post', 'target_id': 'p1', 'post_id': 'p1', 'source': null, 'paid': true,
      'owner': {'id': 'u1', 'name': 'Koffi', 'avatar': 'https://cdn.test/k.jpg'},
      'post': {'id': 'p1', 'media_kind': 'text', 'description': 'Ma publication', 'author': {'id': 'u1'}, 'created_at': '2026-11-01T10:00:00+00:00', 'counts': {}, 'media': []},
    })!;
    expect(m['isEntityBoost'], false);
    final post = Post.fromJson(Map<String, dynamic>.from(m['post'] as Map));
    final ad = Advertisement.fromJson(Map<String, dynamic>.from(m['ad'] as Map));
    expect(post.id, 'p1');
    expect(post.description, 'Ma publication');
    expect(ad.postId, 'p1');
    expect(ad.ownerName, 'Koffi');
    expect(ad.ownerType, 'user');
  });

  test('élément à écarter : terminé, boost de publication sans publication, sans identifiant', () {
    expect(AfrolookAdsPool.toLegacy(_web(ends: DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String())), isNull);
    expect(AfrolookAdsPool.toLegacy({..._web(), 'target_type': 'post', 'post_id': 'p9', 'post': null}), isNull);
    expect(AfrolookAdsPool.toLegacy({..._web(), 'id': ''}), isNull);
    // un élément illisible n'empêche pas les autres
    final list = AfrolookAdsPool.convert([_web(), {'id': 'bad', 'media': 'pas une liste'}, {..._web(), 'id': 'ad-web-2'}]);
    expect(list.map((e) => (e['ad'] as Map)['id']).toList(), ['ad-web-1', 'ad-web-2']);
  });

  test('sans lien d\'annonceur : pas de bouton d\'action', () {
    final ad = Advertisement.fromJson(Map<String, dynamic>.from(AfrolookAdsPool.toLegacy({..._web(), 'action_url': '', 'cta': ''})!['ad'] as Map));
    expect(ad.actionUrl, isNull);
    expect(ad.actionButtonText, isNull);
  });
}
