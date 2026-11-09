import 'dart:io';

import 'package:afrotok/data/country_list.dart';
import 'package:afrotok/widgets/location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sélecteur de pays léger (09/11/2026) : il remplace `csc_picker_plus` (liste mondiale de 25,7 Mo) sans changer les noms de pays déjà enregistrés.
Widget _app(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(brightness: b),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: child))),
    );

void main() {
  test('la liste garde les noms exacts de l\'ancien paquet (compatibilité des profils déjà enregistrés)', () {
    final names = kCountryList.map((c) => c.$1).toSet();
    expect(kCountryList.length, 250);
    for (final n in ['Togo', 'Gambia The', 'Netherlands The', 'Burkina Faso', "Cote D'Ivoire (Ivory Coast)", 'Congo', 'South Africa', 'United States']) {
      expect(names, contains(n));
    }
    expect(countryFlag('Togo'), isNotEmpty);
    expect(countryFlag('Pays inconnu'), '');
  });

  test('la liste pèse quelques Ko, pas des dizaines de Mo', () {
    expect(File('lib/data/country_list.dart').lengthSync(), lessThan(20 * 1024));
    expect(File('pubspec.yaml').readAsStringSync().contains('csc_picker_plus'), isFalse);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('choisir un pays prévient l\'écran, région et ville se saisissent après (${b.name})', (tester) async {
      var country = '';
      var state = '';
      var city = '';
      await tester.pumpWidget(_app(LocationPicker(onCountryChanged: (v) => country = v, onStateChanged: (v) => state = v, onCityChanged: (v) => city = v), b: b));
      expect(find.text('Sélectionnez un pays'), findsOneWidget);
      // la région et la ville attendent le pays
      expect(tester.widget<TextField>(find.byKey(const ValueKey('location_state'))).enabled, isFalse);

      await tester.tap(find.byKey(const ValueKey('location_country')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('country_search')), 'tog');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('country_Togo')), findsOneWidget);
      expect(find.byKey(const ValueKey('country_France')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('country_Togo')));
      await tester.pumpAndSettle();
      expect(country, 'Togo');

      expect(tester.widget<TextField>(find.byKey(const ValueKey('location_state'))).enabled, isTrue);
      await tester.enterText(find.byKey(const ValueKey('location_state')), '  Maritime ');
      await tester.enterText(find.byKey(const ValueKey('location_city')), 'Lomé');
      expect(state, 'Maritime');
      expect(city, 'Lomé');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pays de départ annoncé tout de suite, liste limitée par le filtre, recherche sans résultat', (tester) async {
    final got = <String>[];
    await tester.pumpWidget(_app(LocationPicker(initialCountry: 'Togo', countryFilter: const ['Togo', 'Benin', 'Ghana'], onCountryChanged: got.add)));
    await tester.pump();
    expect(got, ['Togo']);
    expect(find.text('Togo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('location_country')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('country_Benin')), findsOneWidget);
    expect(find.byKey(const ValueKey('country_Ghana')), findsOneWidget);
    expect(find.byKey(const ValueKey('country_France')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('country_search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Aucun pays trouvé.'), findsOneWidget);
  });

  testWidgets('sans région ni ville (showStateCity faux) seul le pays est proposé', (tester) async {
    await tester.pumpWidget(_app(LocationPicker(showStateCity: false, onCountryChanged: (_) {})));
    expect(find.byKey(const ValueKey('location_state')), findsNothing);
    expect(find.byKey(const ValueKey('location_city')), findsNothing);
  });
}
