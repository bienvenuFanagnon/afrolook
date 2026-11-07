import 'package:afrotok/models/coin_pack.dart';
import 'package:afrotok/pages/create/chronique_flow.dart';
import 'package:afrotok/pages/videos/video_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(locale: const Locale('fr'), supportedLocales: const [Locale('fr')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Scaffold(body: child));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('invitation à offrir un cadeau : un toucher sur l\'un des 3 cadeaux l\'envoie tout de suite', (tester) async {
    CoinPack? sent;
    var opened = 0;
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(onPressed: () => VideoGiftNudge.show(ctx, creatorName: 'Ama', avatarUrl: '', onGift: () => opened++, onQuick: (p) => sent = p), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nudge_gift_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('nudge_gift_2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nudge_gift_1')));
    await tester.pumpAndSettle();
    expect(sent, isNotNull);
    expect(sent!.coins, greaterThan(0));
    expect(opened, 0);
    expect(find.byKey(const ValueKey('nudge_gift_0')), findsNothing);   // la fenêtre s'est refermée
  });

  testWidgets('invitation : « Voir tous les cadeaux » ouvre la fenêtre complète', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(onPressed: () => VideoGiftNudge.show(ctx, creatorName: 'Ama', avatarUrl: '', onGift: () => opened++, onQuick: (_) {}), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir tous les cadeaux'));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });

  testWidgets('créer une chronique depuis les listes : le choix propose « Chronique (24 h) » et « Chronique business »', (tester) async {
    await tester.pumpWidget(_host(Builder(builder: (ctx) => TextButton(onPressed: () => showChroniqueChoice(ctx), child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('choice_chronique')), findsOneWidget);
    expect(find.byKey(const ValueKey('choice_business')), findsOneWidget);
    expect(find.text('Chronique business'), findsOneWidget);
  });
}
