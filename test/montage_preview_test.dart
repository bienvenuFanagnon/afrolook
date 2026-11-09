import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/pages/studio/montage/montage_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: home);

void main() {
  exactPreviewTests();
  testWidgets('aperçu du montage : « Modifier » rend faux, « Poursuivre » rend vrai (image)', (tester) async {
    final f = File('${Directory.systemTemp.path}/montage_preview_test.png')..writeAsBytesSync(Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]));
    bool? result;
    await tester.pumpWidget(_app(Builder(builder: (ctx) => TextButton(onPressed: () async => result = await Navigator.of(ctx).push<bool>(MaterialPageRoute(builder: (_) => MontagePreviewPage(file: f, video: false))), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Voici ton montage. Vérifie-le avant de continuer.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preview_edit')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview_continue')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

/// « Voir le rendu exact » (09/11/2026) : l'aperçu du serveur en basse définition n'a qu'un bouton « Fermer » (rien à poursuivre), en clair comme en sombre.
void exactPreviewTests() {
  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('aperçu du rendu exact : bandeau « basse définition » et un seul bouton « Fermer » (${b.name})', (tester) async {
      final f = File('${Directory.systemTemp.path}/montage_exact_test_${b.name}.png')..writeAsBytesSync(Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]));
      bool? result;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: b),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(builder: (ctx) => TextButton(onPressed: () async => result = await Navigator.of(ctx).push<bool>(MaterialPageRoute(builder: (_) => MontagePreviewPage(file: f, video: false, exact: true))), child: const Text('go'))),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Rendu exact en basse définition (6 s au plus). La vidéo finale sera plus nette.'), findsOneWidget);
      expect(find.byKey(const ValueKey('preview_continue')), findsNothing);
      expect(find.byKey(const ValueKey('preview_edit')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('preview_close')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  }
}
