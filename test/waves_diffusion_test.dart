import 'package:afrotok/services/api/post_diffusion.dart';
import 'package:afrotok/services/watch_tracker.dart';
import 'package:afrotok/widgets/post_diffusion_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vagues de diffusion (08/11/2026) : tranche de visionnage anonyme, carte « Diffusion » visible par tous (clair et sombre).
Widget _app(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
    );

PostDiffusion _card({String state = 'testing', int level = 3, bool mine = false}) => PostDiffusion.fromJson({
      'state': state,
      'level': level,
      'levels': 5,
      'shown_total': 1600,
      'shown_outside': 1480,
      'finished_pct': 52,
      'loops_pct': 11,
      'shares': 37,
      'is_video': true,
      'mine': mine,
    });

void main() {
  group('tranche de visionnage anonyme', () {
    test('trop court pour compter : rien n\'est envoyé', () {
      expect(WatchTracker.bucketFor(300, 20000), isNull);
      expect(WatchTracker.bucketFor(5000, 0), isNull);
    });
    test('moins de la moitié, la moitié, presque la fin, en boucle', () {
      expect(WatchTracker.bucketFor(3000, 20000), 'q');
      expect(WatchTracker.bucketFor(10000, 20000), 'h');
      expect(WatchTracker.bucketFor(19000, 20000), 'f');
      expect(WatchTracker.bucketFor(30000, 20000), 'l');
    });
  });

  test('la carte reçue de l\'API est lue, avec des valeurs de départ sûres', () {
    final d = PostDiffusion.fromJson({'state': 'promising', 'level': 2, 'shown_total': 120});
    expect(d.state, 'promising');
    expect(d.levels, 5);
    expect(d.finishedPct, isNull);
    expect(d.mine, isFalse);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('carte Diffusion en cours de test (${b.name}) : vague, personnes touchées, part regardée, partages', (tester) async {
      await tester.pumpWidget(_app(PostDiffusionSheet(postId: 'p1', loader: (_) async => _card()), b: b));
      await tester.pumpAndSettle();
      expect(find.text('Diffusion de cette publication'), findsOneWidget);
      expect(find.text('Vague 3 / 5'), findsOneWidget);
      expect(find.text('1 600 personnes'), findsOneWidget);
      expect(find.text('1 480'), findsOneWidget);
      expect(find.text('52 %'), findsOneWidget);
      expect(find.text('11 %'), findsOneWidget);
      expect(find.text('37'), findsOneWidget);
      expect(find.text('En cours de test'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la même carte pour l\'auteur et pour les autres ; le mot du bas suit l\'état', (tester) async {
    for (final mine in [false, true]) {
      await tester.pumpWidget(_app(PostDiffusionSheet(key: UniqueKey(), postId: 'p1', loader: (_) async => _card(state: 'promising', mine: mine))));
      await tester.pumpAndSettle();
      expect(find.text('Elle plaît : prochaine vague bientôt'), findsOneWidget);
    }
    await tester.pumpWidget(_app(PostDiffusionSheet(key: UniqueKey(), postId: 'p1', loader: (_) async => _card(state: 'stopped', level: 1))));
    await tester.pumpAndSettle();
    expect(find.text('Restée discrète : ses abonnés la voient toujours'), findsOneWidget);
    await tester.pumpWidget(_app(PostDiffusionSheet(key: UniqueKey(), postId: 'p1', loader: (_) async => _card(state: 'top', level: 5))));
    await tester.pumpAndSettle();
    expect(find.text("Au sommet : elle est dans l'onglet Viral"), findsOneWidget);
    expect(find.text('Vague 5 / 5'), findsOneWidget);
  });

  testWidgets('publication hors des vagues : un message clair, pas de chiffres', (tester) async {
    await tester.pumpWidget(_app(PostDiffusionSheet(postId: 'p1', loader: (_) async => null)));
    await tester.pumpAndSettle();
    expect(find.text('Pas encore dans les vagues de diffusion.'), findsOneWidget);
    expect(find.text('Partages'), findsNothing);
  });

  testWidgets('erreur réseau : message, jamais de plantage', (tester) async {
    await tester.pumpWidget(_app(PostDiffusionSheet(postId: 'p1', loader: (_) async => throw Exception('hors ligne'))));
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger la diffusion. Réessaie plus tard.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
