import 'dart:convert';
import 'dart:io';

import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/pages/create/create_editor_page.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_look.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:afrotok/services/post_source_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG transparent de 1 pixel : suffit à l'aperçu d'une photo
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: child,
    );

void main() {
  late File photo;

  setUpAll(() async {
    photo = File('${Directory.systemTemp.path}/editor_test_${DateTime.now().microsecondsSinceEpoch}.png');
    await photo.writeAsBytes(_png);
  });

  tearDownAll(() async {
    if (await photo.exists()) await photo.delete();
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('éditeur d\'une photo (${b.name}) : bandeau « Avec musique », outils Modèles/Musique/Texte/Effets, pas de Couper, Refaire et Suivant', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(CreateEditorPage(path: photo.path, isVideo: false, source: PostSourceLink.imported), b: b));
      await tester.pump();
      expect(find.byKey(const ValueKey('photo_banner')), findsOneWidget);
      for (final k in ['tool_models', 'tool_music', 'tool_text', 'tool_stickers', 'tool_looks', 'editor_next', 'editor_redo', 'editor_back']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey('tool_trim')), findsNothing);
      expect(find.byKey(const ValueKey('tool_trim_top')), findsNothing);
      expect(find.text('Texte'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('le texte libre du montage : vide au départ, 6 couleurs dont le blanc en premier, trois positions', () {
    final s = MontageState(kPlainTemplate);
    expect(s.freeText, '');
    expect(s.freeColor, 0);
    expect(s.freePos, 1);
    expect(kFreeTextColors.length, 6);
    expect(kFreeTextColors.first, const Color(0xFFFFFFFF));
    s
      ..freeText = '  Bonne année !  '
      ..freePos = 2
      ..freeColor = 1;
    expect(s.freeText.trim(), 'Bonne année !');
    expect(kFreeTextColors[s.freeColor], const Color(0xFFFFD60A));
  });
}
