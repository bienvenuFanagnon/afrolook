import 'package:afrotok/services/api/notification_text.dart';
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

  // 16/11/2026 : nouvelles notifications (republication vers les abonnés, regroupement, post du moment, jeu en direct, activité)
  test('republication, post du moment : ouvrent la publication ; jeu en direct : le live ; activité : la liste ; regroupement : le fil', () async {
    expect((await tap({'type_notif': 'REPOST_FEED', 'post_id': 'p1'}))?['postId'], 'p1');
    expect((await tap({'type_notif': 'RAPPEL_TRENDING', 'post_id': 'p2'}))?['postId'], 'p2');
    expect(await tap({'type_notif': 'LIVE', 'post_id': 'lv1'}), {'type': 'live', 'liveId': 'lv1'});
    expect(await tap({'type_notif': 'RAPPEL_ACTIVITE', 'post_id': ''}), {'type': 'screen', 'screen': 'notifications'});
    expect(await tap({'type_notif': 'NEWPOST_GROUP', 'post_id': ''}), isNull);   // l'accueil (le fil) est la bonne page
  });

  test('liste : les nouvelles notifications sont rangées (publications, rappels) et leur phrase vient du serveur', () {
    for (final t in ['REPOST_FEED', 'NEWPOST_GROUP', 'RAPPEL_TRENDING']) {
      expect(NotificationText.groupTypes['Publications & Lives'], contains(t));
    }
    for (final t in ['RAPPEL_ACTIVITE', 'RAPPEL_QUIZ', 'RAPPEL_PARTAGE', 'NEWS']) {
      expect(NotificationText.groupTypes['Rappels'], contains(t));
    }
    expect(NotificationText.composedByServer('NEWPOST'), isTrue);
    expect(NotificationText.composedByServer('RAPPEL_QUIZ'), isTrue);
    expect(NotificationText.composedByServer('LIKE'), isFalse);
    expect(NotificationText.look('REPOST_FEED'), isNotNull);
  });
}
