import 'package:afrotok/pages/cards/card_studio_page.dart';
import 'package:afrotok/pages/cards/card_tutorial_page.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(Widget child, Brightness b) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'cards_tuto_seen': true}));

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('composer la carte (${b.name}) : titre, pastilles et bouton principal jaune avec texte lisible', (t) async {
      t.view.physicalSize = const Size(900, 1800);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(CardStudioPage(source: CardDemo.post(), compose: true), b));
      await t.pump(const Duration(milliseconds: 400));
      final c = AppColors.of(t.element(find.byType(Scaffold).first));

      expect(find.text('Ma carte'), findsOneWidget);
      expect(find.text('Style'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Utiliser cette carte'), findsOneWidget);

      // pastille choisie (onglet Médias) : fond jaune, texte onAccent
      final tabText = t.widget<Text>(find.descendant(of: find.byType(Material), matching: find.text('Médias')).first);
      expect(tabText.style!.color, c.onAccent);
      // pastille non choisie : texte du thème, pas de jaune
      final other = t.widget<Text>(find.descendant(of: find.byType(Material), matching: find.text('Style')).first);
      expect(other.style!.color, c.textPrimary);

      // bouton principal : jaune en fond, onAccent en texte
      final btn = t.widget<FilledButton>(find.ancestor(of: find.text('Utiliser cette carte'), matching: find.byType(FilledButton)));
      expect(btn.style!.backgroundColor!.resolve({}), c.accent);
      expect(btn.style!.foregroundColor!.resolve({}), c.onAccent);

      await t.tap(find.text('Format'));
      await t.pump();
      expect(find.textContaining('Portrait'), findsWidgets);
      expect(find.text('Story 9:16'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
