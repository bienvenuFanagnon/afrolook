import 'package:afrotok/pages/create/subtitles_sheet.dart';
import 'package:afrotok/services/api/studio_subtitles_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('relecture des sous-titres (${b.name}) : corriger, retirer, valider', (tester) async {
      List<SubtitleSegment>? out;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: b),
        locale: const Locale('fr'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fr')],
        home: Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () async => out = await showSubtitlesSheet(c, [SubtitleSegment(startMs: 0, endMs: 1500, text: 'Bonjour'), SubtitleSegment(startMs: 2000, endMs: 3500, text: 'a tous')]), child: const Text('ouvrir')))),
      ));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Relis tes sous-titres'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('subtitle_1')), 'à tous');
      await tester.tap(find.byKey(const ValueKey('subtitle_del_0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('subtitles_ok')));
      await tester.pumpAndSettle();
      expect(out!.length, 1);
      expect(out!.first.text, 'à tous');
      expect(out!.first.startMs, 2000);
    });
  }
}
