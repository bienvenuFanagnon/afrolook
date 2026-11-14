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
  testWidgets('la pub du réseau prête s\'affiche avec « Fermer dans 5 s », puis un bouton « Fermer » : la page ne passe JAMAIS toute seule', (tester) async {
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
    expect(find.text('Fermer dans 5 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Fermer dans 3 s'), findsOneWidget);
    expect(find.byKey(const ValueKey('ad_close')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byKey(const ValueKey('ad_close')), findsOneWidget);   // le bouton est là
    expect(next, 0);
    await tester.pump(const Duration(minutes: 5));   // même longtemps après : aucune fermeture automatique
    expect(next, 0);
    await tester.tap(find.byKey(const ValueKey('ad_close')));
    await tester.pump();
    await tester.pump();
    expect(next, 1);
  });

  testWidgets('réseau pas prêt au bout de 3 s : la pub Afrolook Ads prend la place, même attente de 5 s, la fin de sa vidéo ne ferme rien, seul le bouton ferme', (tester) async {
    var next = 0;
    var shown = 0;
    VoidCallback? adDone;
    await tester.pumpWidget(_host(FullScreenAdPage(
      active: true,
      onShown: (s) => shown = s,
      onNext: () => next++,
      networkBuilder: (l, f) => const SizedBox(key: ValueKey('net'), width: 300, height: 250),
      ownBuilder: (done) {
        adDone = done;
        return const ColoredBox(key: ValueKey('own'), color: Colors.green);
      },
    )));
    expect(find.byKey(const ValueKey('own')), findsNothing);
    await tester.pump(const Duration(milliseconds: 3100));
    expect(find.byKey(const ValueKey('own')), findsOneWidget);
    expect(shown, 5);
    expect(find.text('Fermer dans 5 s'), findsOneWidget);
    adDone!();   // la vidéo de la pub se termine : rien ne se ferme
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(next, 0);
    expect(find.byKey(const ValueKey('ad_close')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ad_close')));
    await tester.pump();
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
