import 'package:afrotok/services/nav_cache_service.dart';
import 'package:afrotok/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Toucher une notification liée à un post doit ouvrir ce post (16/11/2026 : « nouveau post » ouvrait l'accueil, faute de `post_id`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Map<String, dynamic>?> tap(Map<String, dynamic> data) async {
    await storeNavigationFromPush(data);
    return NavigationCacheService().getAndClearPendingNavigation();
  }

  test('nouveau post avec post_id : ouvre le post', () async {
    final nav = await tap({'type_notif': 'NEWPOST', 'subject_type': 'post', 'subject_id': 'p1', 'post_id': 'p1'});
    expect(nav?['type'], 'post');
    expect(nav?['postId'], 'p1');
  });

  test('ancienne annonce sans post_id (nouveau post, republication, défi) : le post est retrouvé dans subject_id', () async {
    for (final type in ['NEWPOST', 'REPOST', 'DEFI_LAUNCH']) {
      final nav = await tap({'type_notif': type, 'subject_type': 'post', 'subject_id': 'p2', 'actor_id': 'u1'});
      expect(nav?['type'], 'post', reason: type);
      expect(nav?['postId'], 'p2', reason: type);
    }
  });

  test('subject_id d\'un autre sujet (groupe) : pas pris pour un post', () async {
    final nav = await tap({'type_notif': 'GROUP_MESSAGE', 'subject_type': 'group', 'subject_id': 'g1'});
    expect(nav, isNull);
  });
}
