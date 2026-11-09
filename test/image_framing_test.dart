import 'dart:io';
import 'dart:ui' as ui;

import 'package:afrotok/pages/create/image_framing_page.dart';
import 'package:afrotok/pages/create/multi_images_page.dart';
import 'package:afrotok/services/collage_layouts.dart';
import 'package:afrotok/services/image_framing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cadrage par image (08/11/2026) : zoom, déplacement, double toucher pour remettre ; les images cadrées sont celles qui sont publiées (carrousel, collage, diaporama).
Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: child,
    );

/// Image de [w] x [h] : moitié gauche rouge, moitié droite bleue.
Future<File> _twoColors(Directory dir, String name, {int w = 200, int h = 100}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, w / 2, h.toDouble()), Paint()..color = const Color(0xFFFF0000));
  c.drawRect(Rect.fromLTWH(w / 2, 0, w / 2, h.toDouble()), Paint()..color = const Color(0xFF0000FF));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return File('${dir.path}/$name').writeAsBytes(data!.buffer.asUint8List());
}

Future<List<int>> _pixel(File f, int x, int y) async {
  final codec = await ui.instantiateImageCodec(await f.readAsBytes());
  final img = (await codec.getNextFrame()).image;
  final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * img.width + x) * 4;
  return [d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2)];
}

void main() {
  group('calcul du cadrage', () {
    test('sans cadrage : la partie centrale qui remplit le cadre, comme avant (jamais déformée)', () {
      for (final a in [9 / 16, 4 / 5, 16 / 9, 1.0]) {
        final r = FramingMath.sourceRect(1600, 1200, a, const ImageFraming());
        final old = CollageLayouts.coverSource(1600, 1200, a * 100, 100);
        expect(r.left, closeTo(old.left, 1e-6));
        expect(r.top, closeTo(old.top, 1e-6));
        expect(r.width, closeTo(old.width, 1e-6));
        expect(r.height, closeTo(old.height, 1e-6));
        expect(r.width / r.height, closeTo(a, 1e-6));
      }
    });

    test('le zoom réduit la partie visible, sans jamais sortir de l\'image ; le centre est ramené dedans', () {
      final full = FramingMath.sourceRect(1000, 1000, 1, const ImageFraming());
      final z2 = FramingMath.sourceRect(1000, 1000, 1, const ImageFraming(zoom: 2));
      expect(z2.width, closeTo(full.width / 2, 1e-6));
      final edge = FramingMath.sourceRect(1000, 1000, 1, const ImageFraming(zoom: 4, cx: 0, cy: 1));
      expect(edge.left, closeTo(0, 1e-6));
      expect(edge.bottom, closeTo(1000, 1e-6));
      // zoom au-delà du maximum : borné
      expect(FramingMath.sourceRect(1000, 1000, 1, const ImageFraming(zoom: 99)).width, closeTo(250, 1e-6));
    });

    test('le glissement suit le doigt : l\'image va dans le sens du geste, et reste dans l\'image', () {
      const f = ImageFraming(zoom: 2);
      final moved = FramingMath.pan(f, const Offset(50, 0), 1000, 1000, 1, 300);   // doigt vers la droite : on voit plus à gauche
      expect(moved.cx, lessThan(.5));
      final far = FramingMath.pan(f, const Offset(100000, 0), 1000, 1000, 1, 300);
      expect(FramingMath.sourceRect(1000, 1000, 1, far).left, closeTo(0, 1e-6));
      expect(const ImageFraming().isDefault, isTrue);
      expect(const ImageFraming(zoom: 1.5).isDefault, isFalse);
    });
  });

  group('images cadrées réellement produites', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('cadrage_'));
    tearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renderCrop : le zoom sur la partie gauche donne une image toute rouge, au bon format', (tester) async {
      await tester.runAsync(() async {
        final src = await _twoColors(dir, 'src.png');
        // sans cadrage, carré central : 50 px de rouge puis 50 px de bleu
        final def = (await FramingMath.renderCrop(src.path, const ImageFraming(), 1, outW: 100, into: dir))!;
        expect((await _pixel(def, 10, 50))[0], greaterThan(200));   // gauche : rouge
        expect((await _pixel(def, 90, 50))[2], greaterThan(200));   // droite : bleu
        // zoom 2 sur la gauche (centre à 25 % de la largeur) : tout est rouge
        final z = (await FramingMath.renderCrop(src.path, const ImageFraming(zoom: 2, cx: .25), 1, outW: 100, into: dir))!;
        expect((await _pixel(z, 5, 50))[0], greaterThan(200));
        expect((await _pixel(z, 95, 50))[0], greaterThan(200));
        expect((await _pixel(z, 95, 50))[2], lessThan(60));
        // le format demandé : 9:16
        final story = (await FramingMath.renderCrop(src.path, const ImageFraming(), 9 / 16, outW: 90, into: dir))!;
        final codec = await ui.instantiateImageCodec(await story.readAsBytes());
        final im = (await codec.getNextFrame()).image;
        expect([im.width, im.height], [90, 160]);
      });
    });

    testWidgets('le collage utilise le cadrage choisi pour chaque image', (tester) async {
      await tester.runAsync(() async {
        final a = await _twoColors(dir, 'a.png');
        final b = await _twoColors(dir, 'b.png');
        // 2 images côte à côte ; la 1re cadrée sur sa partie gauche (rouge), la 2e laissée au centre
        final out = await CollageLayouts.render([a.path, b.path], 'sbs', width: 200, framings: {a.path: const ImageFraming(zoom: 3, cx: .1)}, into: dir);
        // case de gauche (x de 0 à 100) : toute rouge ; case de droite : moitié rouge, moitié bleue (centre de l'image)
        expect((await _pixel(out, 10, 100))[0], greaterThan(200));
        expect((await _pixel(out, 90, 100))[0], greaterThan(200));
        expect((await _pixel(out, 90, 100))[2], lessThan(60));
        expect((await _pixel(out, 110, 100))[0], greaterThan(200));   // 2e image, côté rouge de son centre
        expect((await _pixel(out, 190, 100))[2], greaterThan(200));   // 2e image, côté bleu de son centre
      });
    });

    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('écran de cadrage (${b.name}) : le double toucher remet, le curseur zoome, « Valider » rend le cadrage', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        late File src;
        await tester.runAsync(() async => src = await _twoColors(dir, 'p.png'));
        ImageFraming? result;
        await tester.pumpWidget(_host(
          Builder(builder: (ctx) => TextButton(onPressed: () async => result = await Navigator.of(ctx).push<ImageFraming>(MaterialPageRoute(builder: (_) => ImageFramingPage(path: src.path, aspect: 1))), child: const Text('go'))),
          b: b,
        ));
        await tester.tap(find.text('go'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
        expect(find.byKey(const ValueKey('framing_frame')), findsOneWidget);
        // « Remettre » est désactivé tant que rien n'a bougé
        expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('framing_reset'))).onPressed, isNull);
        // le curseur de zoom
        await tester.drag(find.byKey(const ValueKey('framing_zoom')), const Offset(120, 0));
        await tester.pump();
        expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('framing_reset'))).onPressed, isNotNull);
        // le double toucher remet
        await tester.tap(find.byKey(const ValueKey('framing_frame')));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(find.byKey(const ValueKey('framing_frame')));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('framing_reset'))).onPressed, isNull);
        // un nouveau zoom puis « Valider »
        await tester.drag(find.byKey(const ValueKey('framing_zoom')), const Offset(80, 0));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('framing_ok')));
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.zoom, greaterThan(1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('« Mes images » : le bouton Cadrer existe dans les trois modes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late List<String> paths;
      await tester.runAsync(() async => paths = [(await _twoColors(dir, '1.png')).path, (await _twoColors(dir, '2.png')).path, (await _twoColors(dir, '3.png')).path]);
      await tester.pumpWidget(_host(MultiImagesPage(paths: paths)));
      await tester.pump();
      for (final mode in ['mode_carousel', 'mode_collage', 'mode_slideshow']) {
        await tester.tap(find.byKey(ValueKey(mode)));
        await tester.pump();
        expect(find.byKey(const ValueKey('multi_frame'), skipOffstage: false), findsOneWidget, reason: mode);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
