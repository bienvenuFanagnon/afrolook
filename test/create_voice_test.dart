import 'package:afrotok/pages/create/create_voice_page.dart';
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
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('écran Audio (${b.name}) : onde, minuteur « 0:00 / 3:00 », micro rouge et « Importer un fichier »', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(const CreateVoicePage(), b: b));
      await tester.pump();
      expect(find.text('Audio'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_timer')), findsOneWidget);
      expect(find.textContaining('0:00'), findsOneWidget);
      expect(find.textContaining('3:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_rec')), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_pick')), findsOneWidget);
      expect(find.text('Importer un fichier'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_close')), findsOneWidget);
      // pas de boutons de l'écran « Ton audio » tant que rien n'est enregistré
      expect(find.byKey(const ValueKey('voice_next')), findsNothing);
      expect(find.byKey(const ValueKey('voice_trim')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la limite de galerie atteinte masque « Importer un fichier » (enregistrer reste possible)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const CreateVoicePage(allowPick: false)));
    await tester.pump();
    expect(find.byKey(const ValueKey('voice_pick')), findsNothing);
    expect(find.byKey(const ValueKey('voice_rec')), findsOneWidget);
  });
}
