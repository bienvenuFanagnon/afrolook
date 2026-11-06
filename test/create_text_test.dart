import 'package:afrotok/pages/create/create_result.dart';
import 'package:afrotok/pages/create/create_text_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: child,
    );

void main() {
  test('5 papiers de couleur et 4 façons d\'écrire, comme la proposition', () {
    expect(kTextPapers.length, 5);
    expect(kTextStyles.map((s) => s.label).toList(), ['Citation', 'Annonce', 'Humeur', 'Pensée']);
    for (final p in kTextPapers) {
      expect(p.length, 2);
    }
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('écran Texte (${b.name}) : papier, pastilles, façons d\'écrire ; un texte vide ne passe pas, un texte écrit part vers le formulaire', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      var opened = 0;
      await tester.pumpWidget(_host(CreateTextPage(openForm: (file, text) async {
        opened++;
        return kCreateBack;
      }), b: b));
      expect(find.byKey(const ValueKey('text_field')), findsOneWidget);
      for (var i = 0; i < kTextPapers.length; i++) {
        expect(find.byKey(ValueKey('text_paper_$i')), findsOneWidget);
      }
      for (final s in kTextStyles) {
        expect(find.byKey(ValueKey('text_style_${s.id}')), findsOneWidget);
      }
      // texte vide : message, formulaire non ouvert
      await tester.tap(find.byKey(const ValueKey('text_next')));
      await tester.pump();
      expect(find.text('Écris ton texte avant de continuer.'), findsOneWidget);
      expect(opened, 0);
      // changer de papier et de façon d'écrire sans erreur
      await tester.tap(find.byKey(const ValueKey('text_paper_2')));
      await tester.tap(find.byKey(const ValueKey('text_style_announce')));
      await tester.enterText(find.byKey(const ValueKey('text_field')), 'Aujourd\'hui, j\'ai enfin lancé ma boutique à Lomé.');
      await tester.pump();
      expect(find.text('Aujourd\'hui, j\'ai enfin lancé ma boutique à Lomé.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
