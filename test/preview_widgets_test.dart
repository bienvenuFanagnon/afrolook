import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:afrotok/models/post_widget.dart';
import 'package:afrotok/pages/studio/montage/montage_preview_page.dart';
import 'package:afrotok/widgets/draft_widgets_layer.dart';
import 'package:afrotok/widgets/post_widget_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );

/// Une vraie image PNG de 90 × 160 pixels (9:16), dessinée ici : l'aperçu en décode le format pour poser les widgets.
Future<Uint8List> _png(WidgetTester tester) async => (await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 90, 160), ui.Paint()..color = const ui.Color(0xFF336699));
      final img = await rec.endRecording().toImage(90, 160);
      return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    }))!;

/// Demande du propriétaire (09/11/2026) : dans l'aperçu final, avant de poster, les widgets sont toujours visibles (ils ne l'étaient qu'après la publication).
void main() {
  tearDown(PostWidgetsLink.clear);

  testWidgets('le calque d\'aperçu montre chaque widget à sa place, sans « ⋮ » ni commande, et sans réagir aux touchers', (tester) async {
    PostWidgetsLink.add(PostWidget(kind: WidgetKind.question, config: {'question': 'Pose-moi une question'}, x: .3, y: .8));
    await tester.pumpWidget(_app(const Scaffold(body: Center(child: SizedBox(width: 300, height: 500, child: DraftWidgetsPreview(mediaAspect: 9 / 16))))));
    expect(find.byKey(const ValueKey('preview_widget_0')), findsOneWidget);
    expect(find.textContaining('Pose-moi une question'), findsOneWidget);
    expect(find.byKey(const ValueKey('wm_dots_0')), findsNothing);   // le ⋮ n'existe que dans l'éditeur
    final w = tester.getCenter(find.byKey(const ValueKey('preview_widget_0')));
    final box = tester.getRect(find.byType(DraftWidgetsPreview));
    expect(w.dy, greaterThan(box.top + box.height * .6));   // en bas du cadre (y = .8)
    expect(w.dx, lessThan(box.center.dx));                  // à gauche (x = .3)
  });

  testWidgets('sans widget : le calque d\'aperçu ne dessine rien', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: SizedBox(width: 300, height: 500, child: DraftWidgetsPreview()))));
    expect(find.byType(PostWidgetView), findsNothing);
  });

  testWidgets('l\'aperçu final du montage (image) affiche les widgets posés ; « Poursuivre » et « Modifier » restent là', (tester) async {
    PostWidgetsLink.add(PostWidget(kind: WidgetKind.question, config: {'question': 'Ton plat préféré ?'}));
    await tester.pumpWidget(_app(MontagePreviewPage(bytes: await _png(tester), video: false)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));   // décodage du format de l'image
    await tester.pump();
    expect(find.byKey(const ValueKey('preview_widgets')), findsOneWidget);
    expect(find.textContaining('Ton plat préféré ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview_continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview_edit')), findsOneWidget);
  });

  testWidgets('aperçu simple depuis le formulaire : le post tel qu\'il sera vu, widgets compris, un seul bouton « Fermer »', (tester) async {
    PostWidgetsLink.add(PostWidget(kind: WidgetKind.question, config: {'question': 'Dernière question ?'}));
    await tester.pumpWidget(_app(MontagePreviewPage(bytes: await _png(tester), video: false, plain: true)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('Voici ton post tel qu\'il sera vu, avec tes widgets.'), findsOneWidget);
    expect(find.textContaining('Dernière question ?'), findsOneWidget);
    expect(find.byKey(const ValueKey('preview_close')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview_continue')), findsNothing);
  });
}
