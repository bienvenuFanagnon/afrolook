import 'package:afrotok/pages/cards/card_studio_page.dart';
import 'package:afrotok/pages/cards/card_tutorial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // la visite guidée du premier usage est déjà vue : on teste le studio lui-même
    SharedPreferences.setMockInitialValues({'cards_tuto_seen': true});
  });

  Future<void> bigScreen(WidgetTester t) async {
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
  }

  testWidgets('le studio affiche la carte, 4 onglets et les 3 actions avec leurs prix', (t) async {
    await bigScreen(t);
    final source = CardDemo.post(images: const [AssetImage('assets/images/intro1.jpg')]);
    await t.pumpWidget(app(CardStudioPage(source: source)));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Médias'), findsOneWidget);
    expect(find.text('Style'), findsOneWidget);
    expect(find.text('Texte'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.text('Publier'), findsOneWidget);
    // devis de secours (serveur injoignable en test) : captures 25 pièces, publication 10 pièces
    expect(find.text('25 🪙'), findsNWidgets(2));
    expect(find.text('10 🪙'), findsWidgets);
  });

  testWidgets('choisir un style Pro affiche le supplément ; le format se change dans l\'onglet Format', (t) async {
    await bigScreen(t);
    await t.pumpWidget(app(CardStudioPage(source: CardDemo.post())));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Style'));
    await t.pump();
    expect(find.text('INCLUS'), findsNWidgets(3));
    expect(find.text('+20 🪙'), findsOneWidget);
    await t.tap(find.text('Bogolan'));
    await t.pump();
    await t.tap(find.text('Format'));
    await t.pump();
    expect(find.text('Story 9:16'), findsOneWidget);
    await t.tap(find.text('Story 9:16'));
    await t.pump();
    expect(find.textContaining('Format Story'), findsNothing); // aucun plantage au changement de format
  });

  testWidgets("l'onglet Texte signale une coupe propre quand le texte est trop long", (t) async {
    await bigScreen(t);
    final long = CardDemo.post(text: List.filled(12, 'Une phrase assez longue pour remplir la carte.').join(' '));
    await t.pumpWidget(app(CardStudioPage(source: long)));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Texte'));
    await t.pump();
    expect(find.textContaining('Texte coupé proprement'), findsOneWidget);
    expect(find.text('Choisir les phrases'), findsOneWidget);
  });

  testWidgets('mode brouillon : un seul bouton « Utiliser cette carte »', (t) async {
    await bigScreen(t);
    await t.pumpWidget(app(CardStudioPage(source: CardDemo.textOnly(), compose: true)));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Utiliser cette carte'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('le tutoriel se parcourt jusqu\'au bout', (t) async {
    await bigScreen(t);
    await t.pumpWidget(app(const CardTutorialPage(fromStudio: true)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Un post devient une carte'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('Suivant'));
      await t.pumpAndSettle();
    }
    expect(find.text('Publie ou partage partout'), findsOneWidget);
    expect(find.text('C\'est parti'), findsOneWidget);
    expect(find.textContaining('5 captures + 20 publications'), findsOneWidget);
  });
}
