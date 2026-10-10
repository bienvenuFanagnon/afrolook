import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:afrotok/pages/cards/card_canvas.dart';
import 'package:afrotok/pages/cards/card_export.dart';
import 'package:afrotok/pages/cards/card_models.dart';
import 'package:afrotok/pages/cards/card_studio_page.dart';
import 'package:afrotok/pages/cards/card_tutorial_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Images du site vitrine (cartes réelles et capture du studio) : `CARD_OUT=/dossier FLUTTER_FONTS=/polices flutter test test/card_site_assets_test.dart`.
/// Sans CARD_OUT, le test ne fait rien.
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
  final dir = Platform.environment['FLUTTER_FONTS'];
  if (dir != null) {
    final r = FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(File('$dir/Roboto-Bold.ttf').readAsBytesSync())));
    await r.load();
    // la bande « passeport » est écrite en police à chasse fixe, que le banc de test n'a pas : Roboto la remplace pour l'image
    final mono = FontLoader('monospace')..addFont(Future.value(ByteData.sublistView(File('$dir/RobotoCondensed-Regular.ttf').readAsBytesSync())));
    await mono.load();
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

CardSource demo({required String text, List<String> images = const ['intro1'], String pseudo = 'aminata_k', String country = 'TG', int likes = 2400, int comments = 186, int followers = 12800}) => CardSource(
      pseudo: pseudo,
      avatar: const AssetImage('assets/images/intro3.jpg'),
      verified: true,
      text: text,
      images: [for (final f in images) AssetImage('assets/images/$f.jpg')],
      postId: 'demo',
      profileId: 'demo',
      date: DateTime(2026, 10, 10),
      likes: likes,
      comments: comments,
      followers: followers,
      country: country,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['CARD_OUT'];
  if (out == null) return;

  setUpAll(loadFonts);

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
    await tester.pump(const Duration(milliseconds: 150));
    late Uint8List png;
    await tester.runAsync(() async => png = await CardExport.toPng(key, format: spec.format));
    return png;
  }

  final jobs = <String, (CardSource, CardSpec)>{
    'neon': (demo(text: 'Chaque soir, la corniche de Dakar se met en or.', images: ['intro1']), CardSpec(style: CardStyleId.neon)),
    'manga': (demo(text: 'Nouvelle série, nouvelle énergie : on ne lâche rien !', images: ['intro5']), CardSpec(style: CardStyleId.manga)),
    'collector': (demo(text: 'Ma plus belle prise de la saison, merci à tous.', images: ['intro6']), CardSpec(style: CardStyleId.collector, showFollowers: true)),
    'passport': (demo(text: 'Citoyenne du monde, Togolaise de cœur.', images: ['intro1'], country: 'TG'), CardSpec(style: CardStyleId.passport, showFollowers: true)),
    'stamp': (demo(text: 'Souvenir du marché de Lomé.', images: ['intro6'], country: 'TG'), CardSpec(style: CardStyleId.stamp)),
    'film': (demo(text: 'Le jour où tout a changé', images: ['intro1']), CardSpec(style: CardStyleId.film)),
    'magazine': (demo(text: 'La mode de rue prend le pouvoir', images: ['intro6']), CardSpec(style: CardStyleId.magazine)),
    'sport': (demo(text: 'Champion du quartier, champion dans la vie.', images: ['intro2']), CardSpec(style: CardStyleId.sport)),
    'pride': (demo(text: 'Fière de mes racines, fière de mon pays.', images: ['intro5'], country: 'CI', pseudo: 'koffi_a'), CardSpec(style: CardStyleId.pride)),
    'tarot': (demo(text: 'Une nouvelle étoile se lève sur ta journée.', images: ['intro6']), CardSpec(style: CardStyleId.tarot)),
    'boarding': (demo(text: 'Direction Abidjan, la valise est prête !', images: ['intro3'], country: 'SN'), CardSpec(style: CardStyleId.boarding)),
    'quote': (demo(text: 'On ne devient pas grand en attendant la permission.', images: []), CardSpec(style: CardStyleId.quote)),
    'glass': (demo(text: 'Soirée entre amis, la musique et les rires.', images: ['intro3']), CardSpec(style: CardStyleId.glass)),
    'gamer': (demo(text: 'Niveau 72 débloqué, on monte encore !', images: ['intro5']), CardSpec(style: CardStyleId.gamer)),
    'flag': (demo(text: 'Joyeuse fête nationale, Sénégal !', images: [], country: 'SN'), CardSpec(style: CardStyleId.flag)),
    'duo': (demo(text: 'Deux pays, une même fierté.', images: ['intro6'], country: 'CI'), CardSpec(style: CardStyleId.duo, country2: 'FR')),
    'supporter': (demo(text: 'Allez les Éperviers, on y croit !', images: ['intro2'], country: 'TG'), CardSpec(style: CardStyleId.supporter)),
    'newspaper': (demo(text: 'Le quartier fête son champion', images: ['intro2']), CardSpec(style: CardStyleId.newspaper)),
    'music': (demo(text: 'La playlist de mon dimanche', images: ['intro1']), CardSpec(style: CardStyleId.music)),
    'kente': (demo(text: 'Fier de notre héritage.', images: ['intro2']), CardSpec(style: CardStyleId.kente)),
    'wax': (demo(text: 'Wax du jour, sourire du jour.', images: ['intro3']), CardSpec(style: CardStyleId.wax)),
    'anime': (demo(text: 'Épisode 1 : le début d\'une belle aventure.', images: ['intro1']), CardSpec(style: CardStyleId.anime)),
    'y2k': (demo(text: 'Retour en 2005 avec mes amis.', images: ['intro3']), CardSpec(style: CardStyleId.y2k)),
    'street': (demo(text: 'Nouvelle collection, nouveau style.', images: ['intro2']), CardSpec(style: CardStyleId.street)),
    'bogolan': (demo(text: 'Les motifs de chez nous.', images: ['intro2']), CardSpec(style: CardStyleId.bogolan)),
    'pro': (demo(text: 'Ravi de rejoindre l\'équipe, merci pour la confiance.', images: ['intro3']), CardSpec(style: CardStyleId.pro)),
    'story_neon': (demo(text: 'Ma journée à Abidjan en une carte.', images: ['intro1']), CardSpec(style: CardStyleId.neon, format: CardFormat.story)),
    'square_pro': (demo(text: 'Rendez-vous demain à 9 h, pensez à vos badges.', images: []), CardSpec(style: CardStyleId.pro, format: CardFormat.square)),
  };

  for (final e in jobs.entries) {
    testWidgets('site : ${e.key}', (tester) async {
      final png = await render(tester, e.value.$1, e.value.$2);
      File('$out/site_${e.key}.png').writeAsBytesSync(png);
    });
  }

  testWidgets('site : capture du studio (onglet Style)', (tester) async {
    SharedPreferences.setMockInitialValues({'cards_tuto_seen': true});
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: CardStudioPage(source: demo(text: 'Chaque soir, la corniche de Dakar se met en or.', images: ['intro1'])),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final ctx = tester.element(find.byType(CardStudioPage));
    await tester.runAsync(() async {
      for (final f in ['intro1', 'intro3']) {
        await precacheImage(AssetImage('assets/images/$f.jpg'), ctx);
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Style'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.drag(find.text('Moderne'), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Moderne'));
    await tester.pump(const Duration(milliseconds: 800));
    late Uint8List png;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    });
    File('$out/site_studio.png').writeAsBytesSync(png);
  });
}
