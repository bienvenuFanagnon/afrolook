import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('« Ma vidéo avec ce son » : hors galerie, sans musique d\'office, son d\'origine coupé par défaut', () {
    expect(kMontageTemplates.any((t) => t.id == kPlainTemplateId), isFalse);
    final s = MontageState(kPlainTemplate)..hidden.addAll(MontageLayer.values);
    expect(s.music, isNull);
    expect(s.keepVideoAudio, isFalse);
    for (final l in MontageLayer.values) {
      expect(s.shows(l), isFalse);
    }
  });

  testWidgets('modèle sans habillage se dessine sans erreur', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final s = MontageState(kPlainTemplate)
      ..post = false
      ..hidden.addAll(MontageLayer.values);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: MontageCanvas(state: s, t: .5, keys: MontageKeys(), pseudo: 'ama', media: const ColoredBox(color: Colors.blueGrey)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
