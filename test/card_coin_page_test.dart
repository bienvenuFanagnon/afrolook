import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/coins/card_coin_page.dart';
import 'package:afrotok/services/card_coins.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const quote = CardQuote(
    enabled: true, termsVersion: 'v1', feePct: 9.9, xofPerUsd: 600,
    packs: [
      CardPack(coins: 1000, total: 0.89, xof: 480),
      CardPack(coins: 2500, total: 2.13, xof: 1150),
      CardPack(coins: 5000, total: 4.07, xof: 2200),
    ],
  );

  Widget app() => MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: CardCoinPage(prefill: UserData()..prenom = 'Awa'..nom = 'Koné'),
      );

  testWidgets('affiche les packs en dollars avec équivalent FCFA et le bouton de paiement', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CardCoins.quoteOverride = () async => quote;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('0,89 \$'), findsOneWidget);
    expect(find.text('2,13 \$'), findsOneWidget);
    expect(find.textContaining('≈'), findsNWidgets(3));
    // pack du milieu présélectionné
    expect(find.text('Payer 4,07 \$'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').replaceAll(RegExp(r'\s'), ' ') == '1 000 pièces'));
    await tester.pump();
    expect(find.text('Payer 0,89 \$'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refuse de payer sans accepter les conditions', (tester) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CardCoins.quoteOverride = () async => quote;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Téléphone (avec indicatif)'), '33612345678');
    await tester.enterText(find.widgetWithText(TextField, 'Ville'), 'Paris');
    await tester.enterText(find.widgetWithText(TextField, 'Code postal'), '75001');
    await tester.tap(find.textContaining('Payer 4,07'));
    await tester.pump();
    expect(find.text('Accepte les conditions pour continuer.'), findsOneWidget);
  });

  testWidgets('message clair quand la carte est désactivée', (tester) async {
    CardCoins.quoteOverride = () async => const CardQuote(enabled: false, termsVersion: 'v1', feePct: 9.9, xofPerUsd: 600, packs: []);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('momentanément indisponible'), findsOneWidget);
  });
}
