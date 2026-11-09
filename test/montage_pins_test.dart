import 'package:afrotok/pages/studio/montage/montage_canvas.dart';
import 'package:afrotok/pages/studio/montage/montage_catalog.dart';
import 'package:afrotok/pages/studio/montage/montage_pin.dart';
import 'package:afrotok/pages/studio/montage/montage_state.dart';
import 'package:afrotok/pages/studio/montage/montage_stickers.dart';
import 'package:afrotok/services/montage_signature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Montage (08/11/2026) : jusqu'à 5 médias épinglés (images posées librement), pas de pseudo sur un média de la galerie, signature « #canal » pour un post de canal.
Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('fr')],
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

Widget _canvas(MontageState s, {String pseudo = 'awa'}) =>
    MontageCanvas(state: s, media: const ColoredBox(color: Color(0xFF334455)), pseudo: pseudo, onMove: (_, __) {}, onScale: (_, __) {}, selectedSticker: null);

MontagePin _image(String id, {Offset? center}) => MontagePin(
      id: id,
      source: MontagePinSource(postId: '', thumbUrl: '/inconnu/$id.jpg', authorPseudo: 'moi', durationSec: 2, localImagePath: '/inconnu/$id.jpg'),
      center: center ?? const Offset(.78, .22),
    );

void main() {
  tearDown(MontageSignature.clear);

  test('5 médias épinglés au plus, aux places toutes différentes et dans le cadre', () {
    expect(kMaxPins, 5);
    expect(kPinSpots.length, 5);
    expect(kPinSpots.map((e) => e.$2).toSet().length, 5);
    for (final e in kPinSpots) {
      expect(e.$2.dx, inInclusiveRange(0, 1));
      expect(e.$2.dy, inInclusiveRange(0, 1));
    }
    final s = MontageState(kPlainTemplate);
    for (var i = 0; i < kMaxPins; i++) {
      expect(s.canAddPin, isTrue, reason: 'image $i');
      s.pins.add(_image('i$i'));
    }
    expect(s.canAddPin, isFalse);
  });

  test('retirer UN média ne retire que lui ; retirer le 1er arrête la disposition, les autres images restent libres', () {
    final s = MontageState(kPlainTemplate)
      ..pins.addAll([_image('a'), _image('b'), _image('c')])
      ..layout = 'tb';
    s.removePin(s.pins[1]);
    expect(s.pins.map((e) => e.id), ['a', 'c']);
    expect(s.layout, 'tb');
    s.removePin(s.pins.first);
    expect(s.pins.map((e) => e.id), ['c']);
    expect(s.layout, isNull);
    s.removePin(s.pins.single);
    expect(s.pins, isEmpty);
  });

  test('le crédit « avec @nom » d\'une vidéo d\'un autre suit son média, et seulement lui', () {
    final s = MontageState(kPlainTemplate);
    final other = MontagePin(id: 'o', source: const MontagePinSource(postId: 'p1', thumbUrl: '', authorPseudo: 'awa', durationSec: 8));
    s.pins.addAll([other, _image('b')]);
    s.stickers.add(MontageSticker(id: 'credit_o', kind: 'badge', value: 'avec @awa', center: const Offset(.5, .94)));
    s.removePin(s.pins[1]);
    expect(s.stickers.any((e) => e.id == 'credit_o'), isTrue);
    s.clearPins();
    expect(s.stickers.any((e) => e.id == 'credit_o'), isFalse);
    expect(s.pins, isEmpty);
  });

  testWidgets('un média épinglé de la galerie ne porte JAMAIS de pseudo ; la vidéo d\'un autre créateur garde son nom', (tester) async {
    final local = _image('a');
    await tester.pumpWidget(_host(MontagePinView(pin: local, cq: 3.6)));
    await tester.pump();
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('moi'), findsNothing);

    final other = MontagePin(id: 'o', source: const MontagePinSource(postId: 'p1', thumbUrl: '', authorPseudo: 'awa', durationSec: 8));
    await tester.pumpWidget(_host(MontagePinView(pin: other, cq: 3.6)));
    await tester.pump();
    expect(find.text('@awa'), findsOneWidget);
  });

  testWidgets('plusieurs médias épinglés : tous visibles en coin ; en disposition, le 1er tient sa place et les autres restent posés par-dessus', (tester) async {
    final s = MontageState(kPlainTemplate)..pins.addAll([_image('a'), _image('b', center: kPinSpots[1].$2), _image('c', center: kPinSpots[2].$2)]);
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    expect(find.byType(MontagePinView), findsNWidgets(3));

    s.layout = 'tb';
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    expect(find.byType(MontagePinView), findsNWidgets(2));
    expect(find.byType(MontageLayoutPreview), findsOneWidget);

    // jamais dans l'export (sans geste) : le serveur pose les vrais médias
    await tester.pumpWidget(_host(MontageCanvas(state: s, media: const ColoredBox(color: Color(0xFF334455)), pseudo: 'awa')));
    await tester.pump();
    expect(find.byType(MontagePinView), findsNothing);
  });

  test('la signature : « #titre » pour un post de canal, le pseudo sinon', () {
    expect(MontageSignature.isCanal, isFalse);
    expect(MontageSignature.label('awa'), 'awa');
    expect(MontageSignature.outroLabel('awa'), '@awa');
    expect(MontageSignature.avatar('http://moi.jpg'), 'http://moi.jpg');
    expect(MontageSignature.followers(12), 12);

    MontageSignature.canalTitle = 'mode.afro';
    MontageSignature.canalImage = '';
    MontageSignature.canalMembers = 340;
    expect(MontageSignature.isCanal, isTrue);
    expect(MontageSignature.label('awa'), '#mode.afro');
    expect(MontageSignature.outroLabel('awa'), '#mode.afro');
    expect(MontageSignature.avatar('http://moi.jpg'), isNull);   // jamais la photo de la personne à la place de celle du canal
    expect(MontageSignature.followers(12), 340);

    MontageSignature.clear();
    expect(MontageSignature.label('awa'), 'awa');
  });

  testWidgets('la pastille de signature écrit « #titre » (jamais « @pseudo ») pour un canal, et « @pseudo » pour une personne', (tester) async {
    final s = MontageState(kPlainTemplate)..hidden.clear();
    await tester.pumpWidget(_host(_canvas(s, pseudo: '#mode.afro')));
    await tester.pump();
    expect(find.textContaining('#mode.afro'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);

    await tester.pumpWidget(_host(_canvas(s, pseudo: 'awa')));
    await tester.pump();
    expect(find.textContaining('@awa'), findsOneWidget);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('ordre des calques : les épingles sont SOUS le texte, le pseudo et les autocollants (comme le rendu du serveur)', (tester) async {
    final s = MontageState(kPlainTemplate)
      ..hidden.clear()
      ..freeText = 'Bonjour Lomé'
      ..pins.addAll([_image('a'), _image('b', center: kPinSpots[1].$2)]);
    await tester.pumpWidget(_host(_canvas(s)));
    await tester.pump();
    // ordre de dessin = ordre du parcours de l'arbre : ce qui vient plus tard est dessiné par-dessus
    var i = 0;
    final order = <String, int>{};
    void visit(Element e) {
      final w = e.widget;
      if (w is MontagePinView) order.putIfAbsent('pin', () => i);
      if (w is Text && (w.data == 'Bonjour Lomé' || (w.textSpan?.toPlainText() ?? '').contains('Bonjour'))) order.putIfAbsent('texte', () => i);
      if (w is Text && (w.textSpan?.toPlainText() ?? '').contains('awa')) order.putIfAbsent('pseudo', () => i);
      i++;
      e.visitChildren(visit);
    }

    tester.element(find.byType(MontageCanvas)).visitChildren(visit);
    expect(order.keys, containsAll(['pin', 'texte', 'pseudo']));
    expect(order['pin']!, lessThan(order['texte']!));
    expect(order['pin']!, lessThan(order['pseudo']!));
  });
}
