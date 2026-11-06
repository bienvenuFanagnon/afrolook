import 'package:afrotok/pages/create/create_menu_sheet.dart';
import 'package:afrotok/pages/create/create_result.dart';
import 'package:afrotok/services/post_source_link.dart';
import 'package:afrotok/widgets/feed/sections/post_call_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(theme: ThemeData(brightness: b), locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: child));

void main() {
  testWidgets('menu du « + » : deux choix, créer un post et passer en live, avec le pseudo dans le titre', (tester) async {
    var created = 0, live = 0;
    await tester.pumpWidget(_host(CreateMenuSheet(pseudo: 'Ama', onCreate: () => created++, onLive: () => live++)));
    expect(find.textContaining('Ama'), findsOneWidget);
    expect(find.text('Créer un post'), findsOneWidget);
    expect(find.text('Passer en live'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu_create')));
    await tester.tap(find.byKey(const ValueKey('menu_live')));
    expect(created, 1);
    expect(live, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu du « + » en thème sombre, sans pseudo : aucun débordement', (tester) async {
    await tester.pumpWidget(_host(CreateMenuSheet(onCreate: () {}, onLive: () {}), b: Brightness.dark));
    expect(find.text('Que veux-tu faire ?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('l\'origine du média est consommée une seule fois et effacée à la fermeture ; une valeur inconnue est ignorée', () {
    PostSourceLink.set('captured');
    expect(PostSourceLink.pending, 'captured');
    expect(PostSourceLink.take(), 'captured');
    expect(PostSourceLink.take(), isNull);
    PostSourceLink.set('imported');
    PostSourceLink.clear();
    expect(PostSourceLink.pending, isNull);
    PostSourceLink.set('inconnu');
    expect(PostSourceLink.pending, isNull);
  });

  test('les types de post suivent l\'ordre des onglets du formulaire (audio, texte, image, vidéo)', () {
    expect([for (final k in CreatePostKind.values) k.tab], [0, 1, 2, 3]);
    expect(kCreateBack, isNot(kCreateDone));
  });

  test('appels à poster : phrases variées, une par jour et par emplacement, le prénom est inséré, jamais de phrase vide', () {
    expect(PostCallPhrases.all.length, greaterThanOrEqualTo(10));
    expect({for (final p in PostCallPhrases.all) p.title}.length, PostCallPhrases.all.length);
    final d = DateTime(2026, 11, 5);
    expect(PostCallPhrases.indexFor(d, 1), PostCallPhrases.indexFor(d, 1));
    expect({for (var s = 1; s <= 6; s++) PostCallPhrases.indexFor(d, s)}.length, greaterThan(3));   // les emplacements d'un même fil changent de phrase
    expect(PostCallPhrases.indexFor(d, 1), isNot(PostCallPhrases.indexFor(DateTime(2026, 11, 6), 1)));
    expect(PostCallPhrases.fill('{a}, c\'est ton moment.', 'Ama'), 'Ama, c\'est ton moment.');
    expect(PostCallPhrases.fill('{a}, c\'est ton moment.', ''), 'C\'est ton moment.');
    for (final p in PostCallPhrases.all) {
      expect(PostCallPhrases.fill(p.title, 'Ama'), isNotEmpty);
      expect(p.sub, isNotEmpty);
    }
  });
}
