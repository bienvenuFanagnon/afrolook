import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_pin.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Régression (08/11) : l'aperçu des deux médias était dessiné DANS le calque capturé à l'export (`top.png`) : il se retrouvait collé, opaque et figé, par-dessus tout le film.
void main() {
  MontagePin pin() => MontagePin(id: 'p', source: const MontagePinSource(postId: '', thumbUrl: '', authorPseudo: 'ama', durationSec: 5));

  Widget app(MontageState s) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 360, child: MontageCanvas(state: s, media: const ColoredBox(color: Colors.red), onMove: (_, __) {}))),
        ),
      );

  testWidgets('disposition à deux médias : l\'aperçu est dans l\'éditeur, jamais dans la capture d\'export', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final s = MontageState(kPlainTemplate)
      ..layout = 'tb'
      ..pins.add(pin());
    await tester.pumpWidget(app(s));
    expect(find.byType(MontageLayoutPreview), findsOneWidget);

    s.exportCapture = true;
    await tester.pumpWidget(app(MontageState(kPlainTemplate)..layout = 'tb'..pins.add(pin())..exportCapture = true));
    expect(find.byType(MontageLayoutPreview), findsNothing);
  });

  testWidgets('mode coin : la miniature n\'entre pas non plus dans la capture', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final s = MontageState(kPlainTemplate)..pins.add(pin());
    await tester.pumpWidget(app(s));
    expect(find.byType(MontagePinView), findsOneWidget);

    await tester.pumpWidget(app(MontageState(kPlainTemplate)..pins.add(pin())..exportCapture = true));
    expect(find.byType(MontagePinView), findsNothing);
  });

  test('ta voix est gardée par défaut sans musique ; le son d\'origine reboucle par défaut', () {
    final s = MontageState(kPlainTemplate);
    expect(s.keepVideoAudio, isTrue);
    expect(s.originLoop, isTrue);
  });
}
