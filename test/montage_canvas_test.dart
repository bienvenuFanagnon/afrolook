import 'dart:io';
import 'dart:ui' as ui;

import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _font(String family, String asset) async {
  final loader = FontLoader(family)..addFont(rootBundle.load(asset));
  await loader.load();
}

void main() {
  final out = Platform.environment['MONTAGE_OUT'];

  setUpAll(() async {
    await _font('Nunito', 'assets/fonts/Nunito-Regular.ttf');
    await _font('NunitoBold', 'assets/fonts/Nunito-ExtraBold.ttf');
    await _font('Anton', 'assets/fonts/cartes/Anton-Regular.ttf');
    await _font('PermanentMarker', 'assets/fonts/cartes/PermanentMarker-Regular.ttf');
  });

  for (final t in kMontageTemplates) {
    for (final post in [false, true]) {
      testWidgets('${t.id} ${post ? 'post' : 'story'} se dessine sans erreur', (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        final s = MontageState(t)..post = post;
        final keys = MontageKeys();
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: MontageCanvas(
                  state: s,
                  t: .5,
                  keys: keys,
                  pseudo: 'ama.kouassi',
                  media: Image.asset(t.sampleIsVideo ? 'assets/images/intro4.jpg' : t.sample, fit: BoxFit.cover),
                  secondMedia: t.dualSample != null ? Image.asset(t.dualSample!, fit: BoxFit.cover) : null,
                ),
              ),
            ),
          ),
        ));
        await tester.runAsync(() async {
          for (final p in [t.sample, t.dualSample, 'assets/images/intro4.jpg', 'assets/logo/afrolook_logo.png']) {
            if (p == null || p.endsWith('.mp4')) continue;
            await precacheImage(AssetImage(p), tester.element(find.byType(MontageCanvas)));
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        if (out != null && !post) {
          await tester.runAsync(() async {
            final b = keys.all.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final img = await b.toImage(pixelRatio: 1);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            await File('$out/${t.id}.png').writeAsBytes(data!.buffer.asUint8List());
          });
        }
      });
    }
  }
}
