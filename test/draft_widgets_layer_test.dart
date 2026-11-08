import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/widgets/draft_widgets_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget layer) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: Center(child: SizedBox(width: 300, height: 500, child: layer))),
    );

/// Le calque des widgets est le même dans l'éditeur de création et dans le Studio : déplaçable, redimensionnable, supprimable (08/11).
void main() {
  tearDown(PostWidgetsLink.clear);

  testWidgets('on touche un widget : les commandes apparaissent ; supprimer le retire ; le fond ne bloque rien sans sélection', (tester) async {
    PostWidgetsLink.add(PostWidget(kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}));
    await tester.pumpWidget(_app(const DraftWidgetsLayer()));
    expect(find.byKey(const ValueKey('wm_delete')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('draft_widget_0')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wm_delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_range')), findsNothing);   // pas de vidéo : pas de « Visible de… à… »
    await tester.tap(find.byKey(const ValueKey('wm_delete')));
    await tester.pump();
    expect(PostWidgetsLink.drafts.value, isEmpty);
  });

  testWidgets('glisser déplace le widget dans le cadre, la vidéo ajoute le réglage « Visible de… à… »', (tester) async {
    final w = PostWidget(kind: WidgetKind.question, config: {'question': 'Pose-moi une question'}, x: .5, y: .5);
    PostWidgetsLink.add(w);
    await tester.pumpWidget(_app(DraftWidgetsLayer(videoSeconds: () => 20)));
    await tester.drag(find.byKey(const ValueKey('draft_widget_0')), const Offset(60, 100));
    await tester.pump();
    expect(w.x, greaterThan(.5));
    expect(w.y, greaterThan(.5));
    // glisser sélectionne le widget : ses commandes (dont la durée, car c'est une vidéo) sont là
    expect(find.byKey(const ValueKey('wm_range')), findsOneWidget);
  });
}
