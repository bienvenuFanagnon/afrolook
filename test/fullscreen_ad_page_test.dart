import 'package:afrotok/ads/fullscreen_ad_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('la pub du réseau prête s\'affiche avec son décompte, puis la page passe toute seule après 5 s', (tester) async {
    var next = 0;
    late VoidCallback loaded;
    await tester.pumpWidget(_host(FullScreenAdPage(
      active: true,
      onNext: () => next++,
      networkBuilder: (l, f) {
        loaded = l;
        return const SizedBox(key: ValueKey('net'), width: 300, height: 250);
      },
    )));
    expect(find.byKey(const ValueKey('ad_countdown')), findsNothing);   // pas encore prête : un chargement, pas de page noire vide
    loaded();
    await tester.pump();
    expect(find.byKey(const ValueKey('ad_countdown')), findsOneWidget);
    expect(find.text('Suivant dans 5 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Suivant dans 3 s'), findsOneWidget);
    expect(next, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(next, 1);
  });

  testWidgets('réseau pas prêt au bout de 3 s : la pub Afrolook Ads prend la place et dure 3 s ; fin de pub : on passe', (tester) async {
    var next = 0;
    var shown = 0;
    await tester.pumpWidget(_host(FullScreenAdPage(
      active: true,
      ownSeconds: 3,
      onShown: (s) => shown = s,
      onNext: () => next++,
      networkBuilder: (l, f) => const SizedBox(key: ValueKey('net'), width: 300, height: 250),
      ownBuilder: (done) => const ColoredBox(key: ValueKey('own'), color: Colors.green),
    )));
    expect(find.byKey(const ValueKey('own')), findsNothing);
    await tester.pump(const Duration(milliseconds: 3100));
    expect(find.byKey(const ValueKey('own')), findsOneWidget);
    expect(shown, 3);
    expect(find.text('Suivant dans 3 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(next, 1);
  });

  testWidgets('échec du réseau : repli immédiat sur Afrolook Ads, sans attendre les 3 s', (tester) async {
    late VoidCallback failed;
    await tester.pumpWidget(_host(FullScreenAdPage(
      active: true,
      onNext: () {},
      networkBuilder: (l, f) {
        failed = f;
        return const SizedBox(width: 300, height: 250);
      },
      ownBuilder: (done) => const ColoredBox(key: ValueKey('own'), color: Colors.green),
    )));
    failed();
    await tester.pump();
    expect(find.byKey(const ValueKey('own')), findsOneWidget);
  });

  testWidgets('ni réseau ni pub Afrolook : la page se passe toute seule, une seule fois', (tester) async {
    var next = 0;
    await tester.pumpWidget(_host(FullScreenAdPage(
      active: true,
      onNext: () => next++,
      networkBuilder: (l, f) => const SizedBox(width: 300, height: 250),
    )));
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(next, 1);
  });

  testWidgets('sans pub et avec « retryNext » : si le premier passage n\'a pas eu d\'effet, la page redemande (jamais un cercle qui tourne sans fin) puis s\'arrête après 6 essais', (tester) async {
    var next = 0;
    await tester.pumpWidget(_host(FullScreenAdPage(
      active: true,
      retryNext: true,
      onNext: () => next++,   // ne fait jamais défiler : la page reste regardée
      networkBuilder: (l, f) => const SizedBox(width: 300, height: 250),
    )));
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);   // plus de cercle une fois « sans pub »
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 800));
    }
    expect(next, 7);   // 1 appel + 6 réessais
  });

  testWidgets('une page pas encore regardée ne lance aucun décompte ; elle montre la pub déjà prête dès qu\'on y arrive', (tester) async {
    var next = 0;
    late VoidCallback loaded;
    Widget build(bool active) => _host(FullScreenAdPage(
          active: active,
          onNext: () => next++,
          networkBuilder: (l, f) {
            loaded = l;
            return const SizedBox(width: 300, height: 250);
          },
        ));
    await tester.pumpWidget(build(false));
    loaded();   // la pub se charge pendant qu'on regarde autre chose
    await tester.pump(const Duration(seconds: 10));
    expect(next, 0);
    expect(find.byKey(const ValueKey('ad_countdown')), findsNothing);
    await tester.pumpWidget(build(true));
    await tester.pump();
    expect(find.byKey(const ValueKey('ad_countdown')), findsOneWidget);   // déjà prête : affichée tout de suite
  });
}
