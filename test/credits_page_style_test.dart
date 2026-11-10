import 'package:afrotok/pages/studio/montage/credits_page.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le choix du style réécrit le texte du sujet', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = kMontageTemplates.firstWhere((x) => x.id == 'gen_voyage');
    await tester.pumpWidget(MaterialApp(home: CreditsTemplatePage(template: t)));
    await tester.pump(const Duration(milliseconds: 300));
    String text() => tester.widget<TextField>(find.byKey(const ValueKey('credits_text'))).controller!.text;
    expect(text(), startsWith('# MON VOYAGE\n'));

    await tester.ensureVisible(find.byKey(const ValueKey('credits_style_chapitres')));
    await tester.tap(find.byKey(const ValueKey('credits_style_chapitres')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(text(), startsWith('# MON VOYAGE EN 4 ÉTAPES'));
    expect(text(), contains('Départ · Valises prêtes'));

    // texte modifié par la personne : on demande avant de le remplacer
    await tester.enterText(find.byKey(const ValueKey('credits_text')), 'Mon propre texte');
    await tester.ensureVisible(find.byKey(const ValueKey('credits_style_classique')));
    await tester.tap(find.byKey(const ValueKey('credits_style_classique')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('credits_style_keep')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(text(), 'Mon propre texte');
  });
}
