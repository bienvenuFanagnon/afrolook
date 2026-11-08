import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/services/widget_raster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un widget affiché devient une image PNG transparente (avec sa place et sa largeur relative) pour être incrusté dans la vidéo téléchargée (08/11).
void main() {
  testWidgets('un sondage est dessiné en PNG, avec sa place, sa largeur relative et sa plage de temps', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      })),
    ));
    final w = PostWidget(kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}, x: .3, y: .7, scale: 1.2, start: 1, end: 4, counts: {'0': 1, '1': 3}, myValue: '1', responsesCount: 4);
    WidgetLayer? layer;
    final done = tester.runAsync(() async => layer = await WidgetRaster.render(ctx, w));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await done;
    expect(layer, isNotNull);
    expect(layer!.png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);   // en-tête PNG
    expect((layer!.x, layer!.y, layer!.start, layer!.end), (.3, .7, 1.0, 4.0));
    expect(layer!.width, inInclusiveRange(.1, 1.0));
  });
}
