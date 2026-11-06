import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:afrotok/pages/studio/montage/montage_pin.dart';
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

  testWidgets('messages temporisés : le calque principal les exclut, chaque message a son calque, et un autocollant normal reste partout', (tester) async {
    final timed = MontageSticker(id: 't', kind: 'badge', value: 'PROMO', center: const Offset(.5, .2))
      ..startSec = 2
      ..endSec = 4;
    final normal = MontageSticker(id: 'n', kind: 'emoji', value: '🎉', center: const Offset(.5, .6));
    expect(timed.timed, isTrue);
    expect(normal.timed, isFalse);
    final s = MontageState(kPlainTemplate)..stickers.addAll([timed, normal]);
    // aperçu normal : les deux
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    expect(find.byType(StickerView), findsNWidgets(2));
    // calque principal : sans le message temporisé
    s.exportExcludeTimed = true;
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    expect(find.byType(StickerView), findsOneWidget);
    expect(tester.widget<StickerView>(find.byType(StickerView)).sticker.id, 'n');
    // calque du message temporisé : lui seul
    s
      ..exportExcludeTimed = false
      ..exportOnlySticker = 't';
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    expect(find.byType(StickerView), findsOneWidget);
    expect(tester.widget<StickerView>(find.byType(StickerView)).sticker.id, 't');
  });

  testWidgets('vidéo épinglée : aperçu seulement dans l éditeur (jamais dans l export), réglages envoyés au serveur avec taille bornée', (tester) async {
    const src = MontagePinSource(postId: 'post-1', thumbUrl: '', authorPseudo: 'awa', durationSec: 30);
    final pin = MontagePin(id: 'p1', source: src, scale: 5, circle: true, clipStartSec: 4, clipEndSec: 12)
      ..startSec = 1.5
      ..endSec = 7;
    final s = MontageState(kPlainTemplate)..pins.add(pin);
    // export / galerie (sans geste) : rien dessiné
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    expect(find.byType(MontagePinView), findsNothing);
    // éditeur (avec geste) : l'aperçu apparaît
    await tester.pumpWidget(_host(_canvas(s, onMove: (_, __) {})));
    await tester.pump();
    expect(find.byType(MontagePinView), findsOneWidget);
    // réglages pour le serveur : taille bornée à 60 % de la largeur, extrait et créneau en millisecondes / secondes
    final api = pin.toApi();
    expect(api['post_id'], 'post-1');
    expect(api['w'], .6);
    expect(api['shape'], 'circle');
    expect(api['clip_start_ms'], 4000);
    expect(api['clip_end_ms'], 12000);
    expect(api['start'], 1.5);
    expect(api['end'], 7);
    expect(MontagePin(id: 'p2', source: src, scale: .1).widthFrac, .15);
    // sans durée connue : extrait de 6 s au plus depuis le début
    expect(MontagePin(id: 'p3', source: const MontagePinSource(postId: 'x', thumbUrl: '', authorPseudo: 'a', durationSec: 0)).clipSeconds, 6);
  });
}
