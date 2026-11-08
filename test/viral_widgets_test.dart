import 'package:afrotok/services/api/viral_api.dart';
import 'package:afrotok/services/viral_service.dart';
import 'package:afrotok/widgets/viral_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page « 🔥 Viral » (08/11/2026) : « +N » de l'onglet et du bandeau, lecture de la réponse de l'API.
Widget _app(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUp(() => ViralService.unseen.value = 0);

  test('le « +N » : rien à 0, le nombre sinon, « +99 » au plus', () {
    expect(ViralService.badge(0), '');
    expect(ViralService.badge(-2), '');
    expect(ViralService.badge(3), '+3');
    expect(ViralService.badge(250), '+99');
  });

  test('la réponse de l\'API devient des posts avec leur vitesse, l\'épinglage et le curseur suivant', () {
    final page = ViralApi.parse({
      'data': [
        {'id': 'p1', 'author': {'id': 'a1', 'username': 'ama'}, 'description': 'un post', 'viral': {'window': '2h', 'interactions': 320, 'pinned': true}},
        {'id': 'p2', 'author': {'id': 'a2', 'username': 'kofi'}, 'description': 'un autre', 'viral': {'window': '2h', 'interactions': 45}},
        {'description': 'sans identifiant : ignoré'},
      ],
      'next_cursor': '20',
    });
    expect(page.items.map((e) => e.post.id), ['p1', 'p2']);
    expect(page.items.map((e) => e.interactions), [320, 45]);
    expect(page.items.map((e) => e.pinned), [true, false]);
    expect(page.next, '20');
    expect(ViralApi.parse({'data': [], 'next_cursor': null}).next, isNull);
  });

  testWidgets('l\'onglet montre « 🔥 Viral » et le « +N » rouge quand il y a des posts pas vus', (tester) async {
    await tester.pumpWidget(_app(const ViralTabLabel()));
    expect(find.text('🔥 Viral'), findsOneWidget);
    expect(find.byKey(const ValueKey('viral_count_pill')), findsNothing);

    ViralService.unseen.value = 3;
    await tester.pump();
    expect(find.text('+3'), findsOneWidget);

    ViralService.unseen.value = 120;
    await tester.pump();
    expect(find.text('+99'), findsOneWidget);
  });

  testWidgets('le bandeau du fil « Pour toi » n\'apparaît que s\'il y a du nouveau, avec le même « +N »', (tester) async {
    await tester.pumpWidget(_app(const ViralBanner()));
    expect(find.byKey(const ValueKey('viral_banner')), findsNothing);

    ViralService.unseen.value = 2;
    await tester.pump();
    expect(find.byKey(const ValueKey('viral_banner')), findsOneWidget);
    expect(find.text('Posts qui décollent'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);

    ViralService.unseen.value = 0;
    await tester.pump();
    expect(find.byKey(const ValueKey('viral_banner')), findsNothing);
  });
}
