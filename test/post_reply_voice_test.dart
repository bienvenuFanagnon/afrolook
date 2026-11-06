import 'package:afrotok/services/api/post_mapper.dart';
import 'package:afrotok/widgets/original_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: Scaffold(body: Center(child: child)),
    );

Map<String, dynamic> _json(Map<String, dynamic> extra) => {
      'id': 'p1',
      'author': {'id': 'u1', 'username': 'awa', 'display_name': 'Awa', 'avatar_url': null},
      'type': 'post',
      'media_kind': 'audio',
      'description': 'Ma voix',
      'counts': {'likes': 0, 'comments': 0, 'shares': 0, 'views': 0},
      'created_at': '2026-11-05T10:00:00Z',
      ...extra,
    };

void main() {
  test('le mapper lit l\'effet de voix et la réponse en vidéo (« En réponse à »)', () {
    final p = postFromApi(_json({
      'voice_effect': 'deep',
      'reply_to': {'id': 'orig1', 'author': {'id': 'u2', 'username': 'kofi'}, 'excerpt': 'Le match d\'hier'},
    }));
    expect(p.voiceEffect, 'deep');
    expect(p.replyToPostId, 'orig1');
    expect(p.replyToUsername, 'kofi');
    expect(p.replyToExcerpt, 'Le match d\'hier');
    // sans ces champs : rien d'affiché
    final q = postFromApi(_json({}));
    expect(q.voiceEffect, isNull);
    expect(q.replyToPostId, isNull);
    expect(VoiceChangedBadge.has(q.voiceEffect), isFalse);
    expect(VoiceChangedBadge.has(''), isFalse);
    expect(VoiceChangedBadge.has('echo'), isTrue);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('étiquettes (${b.name}) : « Voix modifiée » et « En réponse à @pseudo », la ligne est touchable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        Column(mainAxisSize: MainAxisSize.min, children: [
          const VoiceChangedBadge(),
          ReplyToLine(username: 'kofi', onTap: () => taps++),
          const ReplyToLine(username: null),
        ]),
        b: b,
      ));
      expect(find.text('Voix modifiée'), findsOneWidget);
      expect(find.text('En réponse à @kofi'), findsOneWidget);
      expect(find.text('En réponse à un post'), findsOneWidget);
      await tester.tap(find.text('En réponse à @kofi'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
