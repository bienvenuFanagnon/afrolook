import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:afrotok/pages/studio/montage/montage_stickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

Widget _canvas(MontageState s, {MontageKeys? keys, void Function(String, Offset)? onMove, void Function(String, double)? onScale, String pseudo = 'awa'}) =>
    MontageCanvas(state: s, media: const ColoredBox(color: Color(0xFF334455)), pseudo: pseudo, keys: keys, onMove: onMove, onScale: onScale, selectedSticker: null);

bool _inside(Rect inner, Rect frame) => inner.left >= frame.left - .5 && inner.top >= frame.top - .5 && inner.right <= frame.right + .5 && inner.bottom <= frame.bottom + .5;

void main() {
  test('le pack : des thèmes avec leurs éléments, des pastilles de texte et le logo Afrolook', () {
    expect(kStickerPack.length, greaterThanOrEqualTo(8));
    expect(kStickerPack.map((c) => c.id).toSet().length, kStickerPack.length);
    expect(kStickerPack.where((c) => c.kind == 'badge').single.items, contains('NOUVEAU'));
    expect(kStickerPack.where((c) => c.kind == 'logo').single.items, ['afrolook']);
    for (final c in kStickerPack) {
      expect(c.items, isNotEmpty, reason: c.id);
      expect(c.items.toSet().length, c.items.length, reason: 'doublon dans ${c.id}');
    }
    // une pastille garde toujours la même couleur
    expect(badgeColorsFor('PROMO'), badgeColorsFor('PROMO'));
  });

  testWidgets('un élément posé hors du cadre (pseudo, chiffres, texte, autocollant) est ramené À L\'INTÉRIEUR : il ne se perd jamais', (tester) async {
    final s = MontageState(kPlainTemplate)
      ..freeText = 'Bonjour Lomé'
      ..moved['pseudo'] = const Offset(-3, 9)
      ..moved['text'] = const Offset(7, -5)
      ..stickers.add(MontageSticker(id: 'a', kind: 'emoji', value: '🎉', center: const Offset(12, -12)))
      ..stickers.add(MontageSticker(id: 'b', kind: 'badge', value: 'NOUVEAU', center: const Offset(-9, 9), scale: 3));
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    final frame = tester.getRect(find.byType(MontageCanvas));
    for (final f in [find.textContaining('awa'), find.text('Bonjour Lomé'), find.text('🎉'), find.text('NOUVEAU')]) {
      expect(f, findsOneWidget);
      expect(_inside(tester.getRect(f), frame), isTrue, reason: '${f.description} sort du cadre : ${tester.getRect(f)} hors de $frame');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans déplacement, le pseudo et le texte libre restent à leur place d\'origine, dans le cadre', (tester) async {
    final s = MontageState(kPlainTemplate)..freeText = 'Salut';
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    final frame = tester.getRect(find.byType(MontageCanvas));
    final pseudo = tester.getRect(find.textContaining('awa'));
    expect(pseudo.center.dy, greaterThan(frame.center.dy), reason: 'le pseudo est en bas à gauche par défaut');
    expect(pseudo.center.dx, lessThan(frame.center.dx));
    expect(_inside(pseudo, frame), isTrue);
    expect((tester.getRect(find.text('Salut')).center.dx - frame.center.dx).abs(), lessThan(2), reason: 'texte centré');
  });

  testWidgets('glisser un élément envoie son nouveau centre (0 à 1) ; l\'aperçu sans geste (export) ne réagit pas', (tester) async {
    final s = MontageState(kPlainTemplate)..stickers.add(MontageSticker(id: 'x', kind: 'emoji', value: '🔥', center: const Offset(.5, .5)));
    final moves = <String, Offset>{};
    await tester.pumpWidget(_host(_canvas(s, keys: MontageKeys(), onMove: (id, c) => moves[id] = c)));
    await tester.pump();
    await tester.drag(find.text('🔥'), const Offset(60, 40));
    await tester.pump();
    final c = moves['st:x']!;
    expect(c.dx, greaterThan(.5));
    expect(c.dy, greaterThan(.5));
    expect(c.dx, lessThanOrEqualTo(1));
    expect(c.dy, lessThanOrEqualTo(1));
    // sans onMove : aucun geste (c'est le cas de l'export)
    moves.clear();
    await tester.pumpWidget(_host(_canvas(s, keys: MontageKeys())));
    await tester.pump();
    await tester.drag(find.text('🔥'), const Offset(60, 40));
    expect(moves, isEmpty);
  });

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('feuille du pack (${b.name}) : thèmes, grille, et le choix rend le type et la valeur', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      ({String kind, String value})? picked;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: b),
        locale: const Locale('fr'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fr')],
        home: Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(key: const ValueKey('open'), onPressed: () async => picked = await showStickerPicker(ctx), child: const Text('ouvrir'))))),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.text('Ajouter un autocollant'), findsOneWidget);
      expect(find.byKey(const ValueKey('sticker_tab_faces')), findsOneWidget);
      expect(find.byKey(const ValueKey('sticker_tab_love')), findsOneWidget);
      // les autres onglets (liste horizontale) s'atteignent en faisant défiler
      await tester.scrollUntilVisible(find.byKey(const ValueKey('sticker_tab_badges')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('sticker_tab_badges')));
      await tester.pumpAndSettle();
      expect(find.text('NOUVEAU'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sticker_badges_0')));
      await tester.pumpAndSettle();
      expect(picked, (kind: 'badge', value: 'NOUVEAU'));
      expect(tester.takeException(), isNull);
    });
  }
}
