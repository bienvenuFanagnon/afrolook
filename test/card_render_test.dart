import 'dart:io';
import 'dart:ui' as ui;

import 'package:afrotok/pages/cards/card_canvas.dart';
import 'package:afrotok/pages/cards/card_export.dart';
import 'package:afrotok/pages/cards/card_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Charge les polices de l'application dans le test (sinon Flutter utilise une police de secours).
Future<void> loadFonts() async {
  const fams = {
    'CrimsonText': ['assets/fonts/contes/CrimsonText-SemiBold.ttf'],
    'Righteous': ['assets/fonts/cartes/Righteous-Regular.ttf'],
    'Audiowide': ['assets/fonts/cartes/Audiowide-Regular.ttf'],
    'Arvo': ['assets/fonts/cartes/Arvo-Regular.ttf', 'assets/fonts/cartes/Arvo-Bold.ttf'],
    'Anton': ['assets/fonts/cartes/Anton-Regular.ttf'],
    'Bangers': ['assets/fonts/cartes/Bangers-Regular.ttf'],
    'PermanentMarker': ['assets/fonts/cartes/PermanentMarker-Regular.ttf'],
    'PressStart2P': ['assets/fonts/cartes/PressStart2P-Regular.ttf'],
    'Rajdhani': ['assets/fonts/cartes/Rajdhani-SemiBold.ttf', 'assets/fonts/cartes/Rajdhani-Bold.ttf'],
    'AbrilFatface': ['assets/fonts/cartes/AbrilFatface-Regular.ttf'],
    'CinzelDecorative': ['assets/fonts/contes/CinzelDecorative-Bold.ttf'],
  };
  // Roboto et les icônes Material : fournies avec le SDK Flutter (FLUTTER_FONTS = dossier material_fonts)
  final dir = Platform.environment['FLUTTER_FONTS'];
  if (dir != null) {
    final r = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(File('$dir/Roboto-Bold.ttf').readAsBytesSync())));
    await r.load();
    final m = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
    await m.load();
  }
  for (final e in fams.entries) {
    final loader = FontLoader(e.key);
    for (final p in e.value) {
      loader.addFont(rootBundle.load(p));
    }
    await loader.load();
  }
}

const _longText =
    'Hier, j’ai pris le car de cinq heures pour rejoindre ma tante à Bouaké. Le chauffeur a mis une musique que je n’entendais plus depuis mon enfance, et tout le monde s’est mis à chanter. Une dame près de moi a sorti des beignets qu’elle a partagés avec tout le car. À l’arrivée, personne ne voulait descendre. #voyage #cotedivoire';

CardSource source({String text = 'Coucher de soleil sur la corniche de Dakar 🌅', int images = 1, bool video = false}) => CardSource(
      pseudo: 'aminata_k',
      avatar: const AssetImage('assets/images/intro3.jpg'),
      verified: true,
      text: text,
      images: [for (final f in ['intro1', 'intro3', 'intro7', 'intro2'].take(images)) AssetImage('assets/images/$f.jpg')],
      isVideo: video,
      postId: 'abc123',
      date: DateTime(2026, 10, 10),
      likes: 1200,
      comments: 214,
      followers: 3400,
      profileId: 'u1',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['CARD_OUT'];

  Future<Uint8List> render(WidgetTester tester, CardSource src, CardSpec spec) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: Colors.grey.shade800, body: Center(child: RepaintBoundary(key: key, child: CardCanvas(source: src, spec: spec)))),
    ));
    final ctx = tester.element(find.byType(CardCanvas));
    await tester.runAsync(() => CardExport.precache(ctx, src, spec));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    late Uint8List png;
    await tester.runAsync(() async {
      png = await CardExport.toPng(key, format: spec.format);
    });
    return png;
  }

  setUpAll(loadFonts);

  for (final style in CardStyleId.values) {
    testWidgets('style ${style.name} : portrait image, texte seul, story, carré, 3 images, abonnés', (tester) async {
      final cases = <String, (CardSource, CardSpec)>{
        'p_img': (source(images: 1), CardSpec(style: style, showFollowers: true)),
        'p_txt': (source(images: 0), CardSpec(style: style)),
        'p_long': (source(text: _longText, images: 1), CardSpec(style: style)),
        's_img': (source(images: 1), CardSpec(style: style, format: CardFormat.story, showFollowers: true)),
        'q_img': (source(images: 1), CardSpec(style: style, format: CardFormat.square)),
        'p_3img': (source(images: 3), CardSpec(style: style, layout: CardLayout.mosaic, imageOrder: [0, 1, 2])),
      };
      for (final e in cases.entries) {
        final png = await render(tester, e.value.$1, e.value.$2);
        expect(png.length > 15000, true, reason: '${style.name} ${e.key}');
        if (out != null) File('$out/st_${style.name}_${e.key}.png').writeAsBytesSync(png);
      }
    });
  }

  for (final style in CardStyleId.values.take(4)) {
    testWidgets('carte ${style.name} : texte + image, portrait', (tester) async {
      final png = await render(tester, source(images: 1), CardSpec(style: style));
      expect(png.length > 20000, true);
      expect(png.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      if (out != null) File('$out/${style.name}_portrait_image.png').writeAsBytesSync(png);
    });
  }

  testWidgets('stats avec abonnés + texte long (les stats restent visibles)', (tester) async {
    for (final long in [false, true]) {
      final png = await render(tester, source(text: long ? _longText : 'Coucher de soleil sur la corniche de Dakar 🌅'), CardSpec(style: CardStyleId.neon, showFollowers: true));
      expect(png.length > 20000, true);
      if (out != null) File('$out/stats_${long ? 'long' : 'court'}.png').writeAsBytesSync(png);
    }
  });

  test('chiffres personnalisés : vide ou espaces = vrai chiffre', () {
    expect(CardSpec(style: CardStyleId.neon).likesOverride, isNull);
    expect(CardSpec(style: CardStyleId.neon, likesText: '  ').likesOverride, isNull);
    expect(CardSpec(style: CardStyleId.neon, likesText: ' 12k ').likesOverride, '12k');
  });

  testWidgets('chiffres personnalisés : tous les styles se dessinent', (tester) async {
    for (final st in CardStyleId.values) {
      final png = await render(tester, source(), CardSpec(style: st, showFollowers: true, likesText: '12,4k', commentsText: '350', followersText: '1,2M', country: 'SN'));
      expect(png.length > 10000, true, reason: st.name);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('cadrage d\'image : limites et valeurs par défaut', () {
    expect(const ImageAdjust().isDefault, true);
    final big = const ImageAdjust(zoom: 20, dx: 9, dy: -9).clamped();
    expect(big.zoom, ImageAdjust.maxZoom);
    expect(big.dx <= 3, true);
    expect(big.dy >= -3, true);
    expect(const ImageAdjust(zoom: 0.1).clamped().zoom, ImageAdjust.minZoom);
  });

  testWidgets('cadrage d\'image : zoom et décalage dessinés sur tous les styles, 1 à 4 images', (tester) async {
    for (final st in CardStyleId.values) {
      for (final n in [1, 2, 4]) {
        final spec = CardSpec(style: st, imageOrder: List<int>.generate(n, (i) => i));
        for (var i = 0; i < n; i++) {
          spec.adjusts[i] = ImageAdjust(zoom: 2.2, dx: 0.2, dy: -0.1 * i);
        }
        final png = await render(tester, source(images: n), spec);
        expect(png.length > 10000, true, reason: '${st.name} x$n');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('cadrage d\'image : glisser et pincer sur l\'aperçu recadre l\'image, l\'export reste sans geste', (tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final spec = CardSpec(style: CardStyleId.neon);
    final got = <int, ImageAdjust>{};
    late StateSetter set;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(builder: (c, s) {
            set = s;
            return CardCanvas(source: source(), spec: spec, onAdjust: (i, a) => set(() { spec.adjusts[i] = a; got[i] = a; }));
          }),
        ),
      ),
    ));
    await tester.pump();
    final img = find.byType(FitImage).first;
    await tester.drag(img, const Offset(60, 0));
    await tester.pump();
    expect(got[0]!.dx > 0, true, reason: 'le glisser décale l\'image');
    // pincement à deux doigts
    final c = tester.getCenter(img);
    final g1 = await tester.startGesture(c - const Offset(20, 0));
    final g2 = await tester.startGesture(c + const Offset(20, 0));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await g1.moveBy(const Offset(-15, 0));
      await g2.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    expect(got[0]!.zoom > 1.2, true, reason: 'le pincement zoome');
    // double-tape : recentre
    await tester.tap(img);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(img);
    await tester.pump(const Duration(milliseconds: 400));
    expect(got[0]!.isDefault, true);
  });

  test('carte lien : le QR et le partage mènent à la vidéo d\'origine', () {
    final base = source();
    expect(base.externalLink, isNull);
    final link = base.copyWith(externalLink: 'https://www.youtube.com/watch?v=abc', credit: 'YouTube · Une chaîne', isVideo: true);
    expect(link.link, 'https://www.youtube.com/watch?v=abc');
    expect(link.isVideo, true);
    expect(link.copyWith(text: 'Autre titre').externalLink, 'https://www.youtube.com/watch?v=abc');
    expect(link.copyWith(text: 'Autre titre').credit, 'YouTube · Une chaîne');
  });

  testWidgets('carte lien : se dessine sur tous les styles', (tester) async {
    final link = source(images: 1).copyWith(text: 'Rick Astley - Never Gonna Give You Up (Official Video)', externalLink: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', credit: 'YouTube · Rick Astley', isVideo: true);
    for (final st in CardStyleId.values) {
      final png = await render(tester, link, CardSpec(style: st, layout: CardLayout.single, imageOrder: [0]));
      expect(png.length > 10000, true, reason: st.name);
      if (out != null) File('$out/lien_${st.name}.png').writeAsBytesSync(png);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('le lien du QR : post, sinon profil, sinon accueil', () {
    expect(source().link, 'https://afrolookmedia.com/share/post/abc123');
    expect(CardSource.draft(pseudo: 'a', profileId: 'u1').link, 'https://afrolookmedia.com/share/creator/u1');
    expect(CardSource.draft(pseudo: 'a').link, 'https://afrolookmedia.com');
  });

  testWidgets('formats story et carré, texte seul, vidéo, texte long', (tester) async {
    final cases = <String, (CardSource, CardSpec)>{
      'neon_story_image': (source(), CardSpec(style: CardStyleId.neon, format: CardFormat.story)),
      'wax_square_image': (source(), CardSpec(style: CardStyleId.wax, format: CardFormat.square)),
      'kente_portrait_texte': (source(text: 'On dit que l’argent ne fait pas le bonheur. Mais il paie le transport pour aller le chercher. 😂', images: 0), CardSpec(style: CardStyleId.kente)),
      'bogolan_portrait_video': (source(video: true), CardSpec(style: CardStyleId.bogolan)),
      'kente_portrait_long': (source(text: _longText, images: 0), CardSpec(style: CardStyleId.kente)),
      'neon_portrait_long_media': (source(text: _longText), CardSpec(style: CardStyleId.neon)),
    };
    for (final e in cases.entries) {
      final png = await render(tester, e.value.$1, e.value.$2);
      expect(png.length > 10000, true, reason: e.key);
      if (out != null) File('$out/${e.key}.png').writeAsBytesSync(png);
    }
  });

  testWidgets('plusieurs images : mosaïque 2, 3, 4, polaroïds, bande', (tester) async {
    final cases = <String, (int, CardLayout, CardStyleId)>{
      'mos2': (2, CardLayout.mosaic, CardStyleId.wax),
      'mos3': (3, CardLayout.mosaic, CardStyleId.wax),
      'mos4': (4, CardLayout.mosaic, CardStyleId.wax),
      'pola3': (3, CardLayout.polaroid, CardStyleId.wax),
      'film3': (3, CardLayout.film, CardStyleId.neon),
      'single': (3, CardLayout.single, CardStyleId.kente),
    };
    for (final e in cases.entries) {
      final png = await render(tester, source(images: e.value.$1), CardSpec(style: e.value.$3, layout: e.value.$2, imageOrder: List.generate(e.value.$1, (i) => i)));
      expect(png.length > 10000, true, reason: e.key);
      if (out != null) File('$out/multi_${e.key}.png').writeAsBytesSync(png);
    }
  });

  testWidgets("la taille d'export est 1080 px de large", (tester) async {
    final png = await render(tester, source(), CardSpec(format: CardFormat.story));
    final codec = await tester.runAsync(() => decodeImage(png));
    expect(codec!.$1, 1080);
    expect(codec.$2, 1920);
  });
}

Future<(int, int)> decodeImage(Uint8List bytes) async {
  final c = await ui.instantiateImageCodec(bytes);
  final f = await c.getNextFrame();
  return (f.image.width, f.image.height);
}
