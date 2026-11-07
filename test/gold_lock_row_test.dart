import 'package:afrotok/widgets/gold_lock_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Brightness b = Brightness.light}) => MaterialApp(theme: ThemeData(brightness: b), locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('ligne réservée à Gold (${b.name}) : titre, pastille GOLD, explication, bouton ; le bouton fait ce qu\'on lui demande', (tester) async {
      var acted = 0;
      await tester.pumpWidget(_app(GoldLockRow(title: 'Fin Afrolook incluse', subtitle: 'Seul le plan Gold peut la retirer.', actionLabel: 'Débloquer', onAction: () => acted++), b: b));
      expect(find.text('Fin Afrolook incluse'), findsOneWidget);
      expect(find.byKey(const ValueKey('gold_chip')), findsOneWidget);
      expect(find.text('Seul le plan Gold peut la retirer.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gold_lock_action')));
      expect(acted, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
