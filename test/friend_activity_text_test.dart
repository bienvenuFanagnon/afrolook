import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/notification_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activité des amis : la phrase suit l\'action et nomme l\'auteur de la publication', () {
    expect(NotificationText.sentence('FRIEND_ACTIVITY', body: 'like|kofi'), 'a aimé la publication de @kofi');
    expect(NotificationText.sentence('FRIEND_ACTIVITY', body: 'comment|kofi'), 'a commenté la publication de @kofi');
    expect(NotificationText.sentence('FRIEND_ACTIVITY', body: 'repost|kofi'), 'a republié la publication de @kofi');
    expect(NotificationText.sentence('FRIEND_ACTIVITY', body: 'like|'), 'a aimé la publication de un ami');
    expect(NotificationText.groupTypes['Publications & Lives'], contains('FRIEND_ACTIVITY'));
  });

  test('les trois phrases sont traduites dans les sept langues, avec le pseudo', () {
    for (final lang in ['en', 'es', 'pt', 'de', 'ar', 'zh', 'sw']) {
      for (final k in ['a aimé la publication de {who}', 'a commenté la publication de {who}', 'a republié la publication de {who}']) {
        final t = trFor(lang, k, {'who': '@kofi'});
        expect(t, isNot(k.replaceAll('{who}', '@kofi')), reason: '$lang : $k');
        expect(t, contains('@kofi'), reason: '$lang : $k');
      }
    }
  });
}
