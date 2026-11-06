import 'package:afrotok/pages/studio/montage/montage_look.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_text_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chaque style d\'écriture, arrière-plan et cadre se dessine sans erreur, texte compris', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (var f = 0; f < kFreeTextFonts.length; f++) {
      for (var bg = 0; bg < kFreeBgModes.length; bg++) {
        for (var fr = 0; fr < kFreeFrames.length; fr++) {
          await tester.pumpWidget(MaterialApp(home: Scaffold(backgroundColor: const Color(0xFF445566), body: Center(child: SizedBox(width: 360, child: FreeTextView(text: 'Bonne année !', cq: 3.6, font: f, color: 1, bg: bg, bgColor: 2, frame: fr))))));
          expect(find.textContaining(kFreeTextFonts[f].upper ? 'BONNE' : 'Bonne', findRichText: true), findsWidgets, reason: '$f/$bg/$fr');
          expect(tester.takeException(), isNull, reason: '$f/$bg/$fr');
        }
      }
    }
  });

  test('le montage garde par défaut le style classique, sans fond ni cadre ; huit styles et cinq cadres', () {
    final s = MontageState(kPlainTemplate);
    expect([s.freeFont, s.freeBg, s.freeFrame, s.freeBgColor], [0, 0, 0, 2]);
    expect(kFreeTextFonts.length, 8);
    expect(kFreeFrames.length, 5);
    expect(kFreeBgModes.length, 4);
    expect(kFreeTextColors.length, 6);
    expect(kFreeTextFonts.map((f) => f.id).toSet().length, 8);
  });
}
