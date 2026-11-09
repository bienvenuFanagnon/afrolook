import 'dart:convert';
import 'dart:io';

import 'package:afrotok/pages/create/multi_images_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

// PNG transparent de 1 pixel : suffit pour les vignettes et l'aperçu
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: child,
    );

void main() {
  late List<String> paths;

  setUpAll(() async {
    paths = [];
    for (var i = 0; i < 3; i++) {
      final f = File('${Directory.systemTemp.path}/multi_test_${DateTime.now().microsecondsSinceEpoch}_$i.png');
      await f.writeAsBytes(_png);
      paths.add(f.path);
    }
  });

  tearDownAll(() async {
    for (final p in paths) {
      try {
        await File(p).delete();
      } catch (_) {}   // Windows : fichier encore lu par un aperçu
    }
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('« Mes images » (${b.name}) : 3 vignettes, les trois modes, Refaire et Suivant', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(MultiImagesPage(paths: paths), b: b));
      await tester.pump();
      expect(find.text('Mes images · 3 / 5'), findsOneWidget);
      for (final k in ['multi_back', 'multi_strip', 'multi_add', 'multi_redo', 'multi_next', 'mode_carousel', 'mode_collage', 'mode_slideshow', 'multi_retouch']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey('remove_0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('le mode Collage propose les mises en page de 3 images et l\'espace ; le mode Diaporama la durée, les transitions et le format', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(MultiImagesPage(paths: paths)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mode_collage')));
    await tester.pump();
    for (final k in ['layout_left1', 'layout_top1', 'layout_rows3', 'collage_gap']) {
      expect(find.byKey(ValueKey(k), skipOffstage: false), findsOneWidget, reason: k);   // la rangée de choix défile : certains restent hors de l'écran
    }
    expect(find.byKey(const ValueKey('layout_grid')), findsNothing);   // la grille 2x2 est pour 4 images
    expect(find.byType(CollagePreview), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mode_slideshow')));
    await tester.pump();
    for (final k in ['total_7', 'total_15', 'total_30', 'total_60', 'slide_summary', 'slide_manual', 'trans_fade', 'trans_slide', 'trans_zoom', 'trans_none', 'fmt_story', 'fmt_post', 'fmt_landscape']) {
      expect(find.byKey(ValueKey(k), skipOffstage: false), findsOneWidget, reason: k);
    }
    expect(find.byType(CollagePreview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on retire une image jusqu\'à 2, jamais moins ; les mises en page suivent le nombre d\'images', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(MultiImagesPage(paths: paths)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('remove_0')));
    await tester.pump();
    expect(find.text('Mes images · 2 / 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove_0')));
    await tester.pump();
    expect(find.text('Mes images · 2 / 5'), findsOneWidget);   // 2 images au moins
    await tester.tap(find.byKey(const ValueKey('mode_collage')));
    await tester.pump();
    expect(find.byKey(const ValueKey('layout_tb')), findsOneWidget);
    expect(find.byKey(const ValueKey('layout_sbs')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
