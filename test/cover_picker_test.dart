import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/pages/create/cover_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Choix de la couverture d'une vidéo avant publication (08/11/2026) : image de la bande, instant précis avec le curseur, image de la galerie.
// PNG 1 x 1 : de vrais fichiers image pour que l'affichage fonctionne
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
  0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _app(Widget sheet, {Brightness b = Brightness.light}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: sheet)),
    );

void main() {
  late Directory dir;
  setUpAll(() => dir = Directory.systemTemp.createTempSync('cover_test'));
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<File?> frame(int ms) async => File('${dir.path}/f_$ms.png')..writeAsBytesSync(_png);

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('la bande montre 8 images de la vidéo (${b.name}) ; en choisir une la met en grand', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(_app(CoverPickerSheet(video: File('${dir.path}/v.mp4'), duration: const Duration(seconds: 16), frameLoader: frame), b: b));
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      for (var i = 0; i < 8; i++) {
        expect(find.byKey(ValueKey('cover_frame_$i')), findsOneWidget);
      }
      // rien n'est choisi : « Utiliser cette image » est désactivé
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('cover_ok'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('cover_frame_3')));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('cover_ok'))).onPressed, isNotNull);
      expect(find.descendant(of: find.byKey(const ValueKey('cover_selected')), matching: find.byType(Image)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('une image de la galerie devient la couverture, et « Utiliser cette image » la renvoie', (tester) async {
    final gallery = File('${dir.path}/galerie.png')..writeAsBytesSync(_png);
    File? result;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 2400);   // écran assez haut pour voir tous les boutons de la fenêtre
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push<File>(MaterialPageRoute(builder: (_) => Scaffold(body: CoverPickerSheet(video: File('${dir.path}/v.mp4'), duration: const Duration(seconds: 8), frameLoader: (_) async => null, galleryPicker: () async => gallery)))),
          child: const Text('ouvrir'),
        ),
      )));
      await tester.tap(find.text('ouvrir'));
      await tester.pump(const Duration(milliseconds: 500));   // la fenêtre finit de monter
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(const ValueKey('cover_gallery')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('cover_gallery')));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      await tester.ensureVisible(find.byKey(const ValueKey('cover_ok')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('cover_ok')));
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    expect(result?.path, gallery.path);
  });

  testWidgets('le curseur choisit un instant précis ; une extraction qui échoue ne plante pas', (tester) async {
    final asked = <int>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(CoverPickerSheet(
        video: File('${dir.path}/v.mp4'),
        duration: const Duration(seconds: 10),
        frameLoader: (ms) async {
          asked.add(ms);
          return ms == 5000 ? (File('${dir.path}/s_5000.png')..writeAsBytesSync(_png)) : null;   // les images de la bande échouent, l'instant 5 s réussit
        },
      )));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
      final slider = tester.widget<Slider>(find.byKey(const ValueKey('cover_slider')));
      slider.onChanged!(5000);
      await tester.pump();
      slider.onChangeEnd!(5000);
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    expect(asked, contains(5000));
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('cover_ok'))).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
