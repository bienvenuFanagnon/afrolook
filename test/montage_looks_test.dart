import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_look.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mélange de filtres (08/11/2026) : plusieurs looks cumulables, effet animé utilisable sans modèle, un seul rendu.
MontageLook _look(String id) => kMontageLooks.firstWhere((l) => l.id == id);

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

void main() {
  test('les looks se cumulent : saturations multipliées, luminosités additionnées, 3 au plus', () {
    final s = MontageState(kPlainTemplate);
    expect(s.looks, isEmpty);
    expect(s.saturation, s.template.saturation);   // sans look : l'ambiance du modèle
    expect(s.toggleLook(_look('vivid')), isTrue);
    expect(s.toggleLook(_look('matte')), isTrue);
    expect(s.saturation, closeTo(_look('vivid').saturation * _look('matte').saturation, 1e-9));
    expect(s.brightness, closeTo(_look('vivid').brightness + _look('matte').brightness, 1e-9));
    expect(s.toggleLook(_look('night')), isTrue);
    expect(s.looks.length, MontageState.maxLooks);
    expect(s.toggleLook(_look('gold')), isFalse);   // la limite est atteinte : rien ne change
    expect(s.looks.length, 3);
    // toucher un look déjà choisi le retire
    expect(s.toggleLook(_look('matte')), isTrue);
    expect(s.looks.map((e) => e.id), ['vivid', 'night']);
    // l'ancien réglage « un seul look » marche toujours
    s.look = _look('mono');
    expect(s.looks.map((e) => e.id), ['mono']);
    expect(s.look?.id, 'mono');
    s.look = null;
    expect(s.looks, isEmpty);
  });

  test('un effet animé se choisit sans modèle ; « Aucun » le coupe ; sans choix, celui du modèle', () {
    final s = MontageState(kPlainTemplate);
    expect(s.fxActive, isFalse);
    expect(s.exportsVideo, isFalse);   // une photo sans effet ni musique reste une image fixe
    s.fxChoice = MontageFx.hearts;
    s.animated = true;
    expect(s.fx, MontageFx.hearts);
    expect(s.fxActive, isTrue);
    expect(s.exportsVideo, isTrue);    // l'effet bouge : vidéo
    s.fxChoice = MontageFx.none;
    expect(s.fxActive, isFalse);
    // un modèle avec son effet : visible quand l'effet n'est pas masqué, coupé par « Aucun »
    final tpl = kMontageTemplates.firstWhere((t) => t.fx != MontageFx.none);
    final m = MontageState(tpl)..hidden.remove(MontageLayer.fx);
    expect(m.fx, tpl.fx);
    expect(m.fxActive, isTrue);
    m.fxChoice = MontageFx.none;
    expect(m.fxActive, isFalse);
    expect(kMontageFxLabels.keys.toSet(), MontageFx.values.toSet()..remove(MontageFx.none));   // chaque effet a son nom
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('looks cumulés et effet animé sans modèle se dessinent ensemble sans erreur (${b.name})', (tester) async {
      final s = MontageState(kPlainTemplate)
        ..hidden.addAll(MontageLayer.values)
        ..toggleLook(_look('gold'))
        ..toggleLook(_look('night'))
        ..fxChoice = MontageFx.sparkle
        ..animated = true
        ..freeText = 'Bonjour';
      await tester.pumpWidget(_host(MontageCanvas(state: s, t: .4, keys: MontageKeys(), media: const ColoredBox(color: Colors.blueGrey)), b: b));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Bonjour'), findsOneWidget);
      // les deux teintes sont posées l'une sur l'autre
      final gradients = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((d) => d.decoration is BoxDecoration && (d.decoration as BoxDecoration).gradient is LinearGradient).length;
      expect(gradients, greaterThanOrEqualTo(2));
    });
  }
}
