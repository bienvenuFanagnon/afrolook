// Outil temporaire : rend le tutoriel de monétisation image par image (60 i/s)
// et l'envoie à ffmpeg. Lancer avec :
//   flutter test test/tuto_render_test.dart --dart-define=TUTO_VIDEO=true
// Variables : TUTO_OUT (dossier de sortie), TUTO_LANG (fr, en, …).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:afrotok/l10n/app_localizations.dart';
import 'package:afrotok/pages/intro/monetization_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await l.load();
}

void main() {
  testWidgets('rendu vidéo du tutoriel', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final out = Platform.environment['TUTO_OUT']!;
    final lang = Platform.environment['TUTO_LANG'] ?? 'fr';
    final seconds = double.parse(Platform.environment['TUTO_SECONDS'] ?? '33');
    final sdkFonts = Platform.environment['TUTO_SDK_FONTS']!;
    final pubCache = Platform.environment['TUTO_PUB']!;

    await _font('Roboto', [
      '$sdkFonts/roboto-regular.ttf',
      '$sdkFonts/roboto-medium.ttf',
      '$sdkFonts/roboto-bold.ttf',
      '$sdkFonts/roboto-black.ttf',
    ]);
    await _font('MaterialIcons', ['$sdkFonts/materialicons-regular.otf']);
    await _font('packages/flutter_vector_icons/FontAwesome', ['$pubCache/flutter_vector_icons-2.0.0/fonts/FontAwesome.ttf']);
    await _font('Segoe UI Emoji', ['C:/Windows/Fonts/seguiemj.ttf']);

    const w = 1080.0, h = 1920.0, dpr = 2.5;
    tester.view.physicalSize = const Size(w, h);
    tester.view.devicePixelRatio = dpr;

    const fps = 60;
    var frame = 0;
    final sounds = <Map<String, Object>>[];
    setMonetizationTutorialSfxHook((name, vol) => sounds.add({'t': frame / fps, 'name': name, 'vol': vol}));

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(lang),
        supportedLocales: kSupportedLocales.keys.map((c) => Locale(c)).toList(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(fontFamily: 'Roboto', fontFamilyFallback: const ['Segoe UI Emoji']),
        home: const MonetizationTutorialPage(),
      ),
    ));

    // Décodage des images avant de lancer l'horloge
    final ctx = key.currentContext!;
    await tester.runAsync(() async {
      for (final p in ['intro3', 'intro2', 'intro5']) {
        await precacheImage(AssetImage('assets/images/$p.jpg'), ctx);
      }
    });

    final ff = await tester.runAsync(() => Process.start('ffmpeg', [
          '-y', '-loglevel', 'error',
          '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${w.toInt()}x${h.toInt()}', '-r', '$fps',
          '-i', '-',
          '-c:v', 'libx264', '-preset', 'medium', '-crf', '16', '-pix_fmt', 'yuv420p',
          '$out/video_$lang.mp4',
        ]));

    final total = (seconds * fps).round();
    for (frame = 0; frame < total; frame++) {
      await tester.pump(const Duration(microseconds: 1000000 ~/ fps));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: dpr);
        final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        img.dispose();
        ff!.stdin.add(bd!.buffer.asUint8List());
        await ff.stdin.flush();
      });
    }
    await tester.runAsync(() async {
      await ff!.stdin.close();
      await ff.exitCode;
      File('$out/sounds_$lang.json').writeAsStringSync(jsonEncode(sounds));
    });
    setMonetizationTutorialSfxHook(null);
  }, timeout: const Timeout(Duration(minutes: 40)));
}
