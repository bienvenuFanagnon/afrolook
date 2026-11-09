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
/// Depuis le 09/11 : un bouton « ⋮ » sur chaque widget (et le toucher du widget) ouvre ses options dans une feuille du bas ; le « ⋮ » n'existe que dans ce calque d'édition.
void main() {
  tearDown(PostWidgetsLink.clear);

  testWidgets('le ⋮ est sur chaque widget ; toucher le widget ouvre ses options (taille, modifier, supprimer) ; supprimer le retire', (tester) async {
    PostWidgetsLink.add(PostWidget(kind: WidgetKind.poll, config: {'question': 'Ton plat ?', 'options': ['Riz', 'Attiéké']}));
    await tester.pumpWidget(_app(const DraftWidgetsLayer()));
    expect(find.byKey(const ValueKey('wm_delete')), findsNothing);
    expect(find.byKey(const ValueKey('wm_dots_0')), findsOneWidget);   // visible dans l'éditeur, sans rien sélectionner
    await tester.tap(find.byKey(const ValueKey('draft_widget_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wm_delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_smaller')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_bigger')), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_range')), findsNothing);   // pas de vidéo : pas de « Visible de… à… »
    await tester.tap(find.byKey(const ValueKey('wm_delete')));
    await tester.pumpAndSettle();
    expect(PostWidgetsLink.drafts.value, isEmpty);
  });

  testWidgets('glisser déplace le widget dans le cadre ; le ⋮ ouvre les options, avec « Visible de… à… » pour une vidéo, et + agrandit sans fermer la feuille', (tester) async {
    final w = PostWidget(kind: WidgetKind.question, config: {'question': 'Pose-moi une question'}, x: .5, y: .5);
    PostWidgetsLink.add(w);
    await tester.pumpWidget(_app(DraftWidgetsLayer(videoSeconds: () => 20)));
    await tester.drag(find.byKey(const ValueKey('draft_widget_0')), const Offset(60, 100));
    await tester.pump();
    expect(w.x, greaterThan(.5));
    expect(w.y, greaterThan(.5));
    await tester.tap(find.byKey(const ValueKey('wm_dots_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wm_range')), findsOneWidget);   // c'est une vidéo : la durée est proposée
    await tester.tap(find.byKey(const ValueKey('wm_bigger')));
    await tester.pumpAndSettle();
    expect(w.scale, greaterThan(1.1));
    expect(find.byKey(const ValueKey('wm_delete')), findsOneWidget);   // la feuille reste ouverte
  });
}
