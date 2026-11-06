import 'package:afrotok/pages/create/prepare_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: Scaffold(body: child),
    );

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('écran Préparation (${b.name}) : anneau, message, barre qui avance sans dépasser 92 %, étape en cours', (tester) async {
      final step = ValueNotifier<String>('Envoi…');
      addTearDown(step.dispose);
      await tester.pumpWidget(_host(PrepareScreen(step: step), b: b));
      expect(find.text('Préparation de ta vidéo'), findsOneWidget);
      expect(find.textContaining('environ 15 secondes'), findsOneWidget);
      expect(find.byKey(const ValueKey('prepare_ring')), findsOneWidget);
      expect(find.text('Envoi…'), findsOneWidget);
      double value() => tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('prepare_bar'))).value!;
      final v0 = value();
      await tester.pump(const Duration(seconds: 5));
      final v1 = value();
      await tester.pump(const Duration(seconds: 30));
      final vEnd = value();
      expect(v1, greaterThan(v0));
      expect(vEnd, lessThanOrEqualTo(.92));
      step.value = 'Montage de la vidéo…';
      await tester.pump();
      expect(find.text('Montage de la vidéo…'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('version image : message adapté', (tester) async {
    final step = ValueNotifier<String>('Montage…');
    addTearDown(step.dispose);
    await tester.pumpWidget(_host(PrepareScreen(step: step, video: false)));
    expect(find.text('Préparation de ton image'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
  });
}
