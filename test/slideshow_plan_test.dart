import 'dart:convert';
import 'dart:io';

import 'package:afrotok/pages/create/multi_images_page.dart';
import 'package:afrotok/services/slideshow_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Durée du diaporama (08/11/2026) : total 7, 15, 30 ou 60 s réparti à parts égales, ou une durée par image ; minimum 1 s par image ; maximum du film. Mêmes calculs que le serveur.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: child,
    );

void main() {
  group('calculs (identiques au serveur)', () {
    test('le total voulu se répartit à parts égales, chevauchements des transitions compris', () {
      expect(SlideshowPlan.even(5, 15, 'fade'), List<double>.filled(5, 3.4));
      expect(SlideshowPlan.total(SlideshowPlan.even(5, 15, 'fade'), 'fade'), 15.0);
      expect(SlideshowPlan.even(5, 15, 'none'), List<double>.filled(5, 3.0));
      expect(SlideshowPlan.even(5, 7, 'fade').first, 1.8);
      expect(SlideshowPlan.total([1, 2, 3], 'fade'), 5.0);
      expect(SlideshowPlan.total([1, 2, 3], 'none'), 6.0);
    });

    test('la transition est toujours plus courte que chaque image ; rien pour une coupe franche', () {
      expect(SlideshowPlan.transitionSeconds('fade', 3), 0.5);
      expect(SlideshowPlan.transitionSeconds('fade', 0.6), 0.3);
      expect(SlideshowPlan.transitionSeconds('none', 3), 0);
    });

    test('7, 15, 30 et 60 s tiennent toujours pour 2 à 5 images (1 s au moins par image)', () {
      for (final t in SlideshowPlan.totals) {
        for (var n = 2; n <= 5; n++) {
          for (final tr in ['fade', 'none', 'zoom', 'slide']) {
            expect(SlideshowPlan.problem(SlideshowPlan.even(n, t.toDouble(), tr), tr), isNull, reason: '$n images, $t s, $tr');
          }
        }
      }
    });

    test('trop court, trop long, et le plus court possible', () {
      expect(SlideshowPlan.problem(SlideshowPlan.even(5, 3, 'none'), 'none'), 'short');   // 0,6 s par image
      expect(SlideshowPlan.problem(const [0.5, 3, 3], 'fade'), 'short');
      expect(SlideshowPlan.problem(const [10, 10, 10, 10, 10], 'none', max: 30), 'long');   // 50 s, maximum 30 s (chronique)
      expect(SlideshowPlan.problem(const [10, 10, 10, 10, 10], 'none'), isNull);
      expect(SlideshowPlan.minTotal(5, 'fade'), 3.0);
      expect(SlideshowPlan.minTotal(5, 'none'), 5.0);
      expect(SlideshowPlan.fmt(3.4), '3,4');
      expect(SlideshowPlan.fmt(15), '15');
    });
  });

  group('écran « Mes images » : la durée', () {
    late List<String> paths;
    setUpAll(() async {
      paths = [];
      for (var i = 0; i < 5; i++) {
        final f = File('${Directory.systemTemp.path}/slide_plan_${DateTime.now().microsecondsSinceEpoch}_$i.png');
        await f.writeAsBytes(_png);
        paths.add(f.path);
      }
    });
    tearDownAll(() async {
      for (final p in paths) {
        try {
          await File(p).delete();
        } catch (_) {}
      }
    });

    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('(${b.name}) la durée totale se choisit, le temps par image et le total sont toujours visibles, le réglage image par image apparaît', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(MultiImagesPage(paths: paths), b: b));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('mode_slideshow')));
        await tester.pump();
        // 5 images, 15 s, fondu : 3,4 s chacune
        expect(find.text('5 images · 3,4 s chacune · total 15 s'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('total_7')));
        await tester.pump();
        expect(find.text('5 images · 1,8 s chacune · total 7 s'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('total_60')));
        await tester.pump();
        expect(find.text('5 images · 12,4 s chacune · total 60 s'), findsOneWidget);
        expect(find.byKey(const ValueKey('slide_problem')), findsNothing);
        // coupe franche : 7 s font 1,4 s par image, c'est permis
        await tester.tap(find.byKey(const ValueKey('trans_none')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('total_7')));
        await tester.pump();
        expect(find.text('5 images · 1,4 s chacune · total 7 s'), findsOneWidget);
        expect(find.byKey(const ValueKey('slide_dur')), findsNothing);
        // réglage image par image : le curseur de l'image choisie
        await tester.tap(find.byKey(const ValueKey('slide_manual')));
        await tester.pump();
        expect(find.byKey(const ValueKey('slide_dur')), findsOneWidget);
        // l'image choisie passe à 1 s, les autres restent à 1,4 s : le total suit (4 x 1,4 + 1 = 6,6 s)
        tester.widget<Slider>(find.byKey(const ValueKey('slide_dur'))).onChanged!(1.0);
        await tester.pump();
        expect(find.textContaining('de 1 à 1,4 s'), findsOneWidget);
        expect(find.textContaining('total 6,6 s'), findsOneWidget);
        expect(find.byKey(const ValueKey('slide_problem')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
