import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:afrotok/services/conversation_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groupToLegacy lit me.muted, me.unread et les champs de découverte', () {
    final g = groupToLegacy({
      'id': 'g1',
      'name': 'Groupe',
      'me': {'role': 'member', 'is_member': false, 'muted': true, 'unread': 4},
      'is_member': true,
      'owner_is_gold': true,
      'featured': true,
    });
    expect(g['muted'], true);
    expect(g['me_unread'], 4);
    expect(g['me_is_member'], true);
    expect(g['owner_is_gold'], true);
    expect(g['featured'], true);
  });

  test('memberToLegacy garde joined_at', () {
    final m = memberToLegacy({'user_id': 'u1', 'joined_at': '2026-10-31T10:00:00Z'});
    expect(m['joined_at'], DateTime.utc(2026, 10, 31, 10).millisecondsSinceEpoch);
    expect(memberToLegacy({'user_id': 'u2'})['joined_at'], 0);
  });

  test('conversation bloquée : qui a bloqué', () {
    final mine = chatFromConversation({'id': 'c1', 'other': {'id': 'u2', 'username': 'awa'}, 'blocked': true, 'blocked_by_me': true}, 'u1');
    expect(ConversationOpener.blockedNotice(mine), contains('Tu as bloqué @awa'));
    final theirs = chatFromConversation({'id': 'c1', 'other': {'id': 'u2', 'username': 'awa'}, 'blocked': true, 'blocked_by_me': false}, 'u1');
    expect(ConversationOpener.blockedNotice(theirs), contains('@awa t\'a bloqué'));
    final free = chatFromConversation({'id': 'c1', 'other': {'id': 'u2', 'username': 'awa'}}, 'u1');
    expect(ConversationOpener.blockedNotice(free), isNull);
  });

  test('notificationFromApi lit post_data_type et post_thumbnail', () {
    final n = notificationFromApi({
      'id': 'n1',
      'type': 'FAVORITE',
      'subject_type': 'post',
      'subject_id': 'p1',
      'post_data_type': 'VIDEO',
      'post_thumbnail': 'https://x/y.jpg',
      'media_url': 'https://x/avatar.jpg',
      'created_at': '2026-10-31T10:00:00Z',
    });
    expect(n.post_data_type, 'VIDEO');
    expect(n.post_thumbnail, 'https://x/y.jpg');
    expect(n.post_id, 'p1');
  });
}
