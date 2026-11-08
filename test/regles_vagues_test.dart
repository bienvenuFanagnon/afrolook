import 'package:afrotok/pages/regles_confidentialite_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page Règles et confidentialité (08/11/2026) : règles des vagues de diffusion et du visionnage anonyme ajoutées, règles périmées retirées.
Widget _app(Brightness b) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: const ReglesConfidentialitePage(),
    );

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('la page s\'affiche (${b.name}) avec les vagues et le visionnage anonyme', (tester) async {
      await tester.pumpWidget(_app(b));
      final list = find.byType(Scrollable).first;

      Future<void> see(String text) async {
        await tester.scrollUntilVisible(find.text(text), 400, scrollable: list);
        expect(find.text(text), findsOneWidget, reason: text);
      }

      await see('Mise en avant des publications (vagues)');
      await see('Seulement les contenus authentiques');
      await see('La carte « Diffusion »');
      await see('Visionnage anonyme');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('les règles qui n\'existent plus ne sont plus affichées', (tester) async {
    await tester.pumpWidget(_app(Brightness.light));
    final list = find.byType(Scrollable).first;
    // on parcourt toute la page
    await tester.drag(list, const Offset(0, -200000));
    await tester.pumpAndSettle();
    expect(find.text('Récompenses commentaires'), findsNothing);
    expect(find.textContaining('top 5 hebdomadaire'), findsNothing);
    expect(find.textContaining('priorité dans les algorithmes'), findsNothing);
  });
}
