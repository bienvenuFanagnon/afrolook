// Vérifie que le tutoriel des tâches ne déborde pas (bottom overflow) sur des écrans de téléphone de tailles courantes.
import 'dart:io';

import 'package:afrotok/l10n/app_localizations.dart';
import 'package:afrotok/pages/offerwall/offerwall_tutorial_page.dart';
import 'package:flutter/material.dart';
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
  final fonts = Platform.environment['TUTO_SDK_FONTS'];
  for (final size in const [Size(360, 640), Size(384, 855), Size(320, 568)]) {
    for (final scale in const [1.0, 1.3, 1.6]) {
      const lang = 'fr';
      testWidgets('tutoriel des tâches sans débordement ${size.width.toInt()}x${size.height.toInt()} texte x$scale', (tester) async {
        SharedPreferences.setMockInitialValues({});
        if (fonts != null) {
          await _font('Roboto', ['$fonts/roboto-regular.ttf', '$fonts/roboto-medium.ttf', '$fonts/roboto-bold.ttf', '$fonts/roboto-black.ttf']);
          await _font('MaterialIcons', ['$fonts/materialicons-regular.otf']);
        }
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
          locale: const Locale(lang),
          supportedLocales: kSupportedLocales.keys.map((c) => Locale(c)).toList(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          theme: ThemeData(fontFamily: fonts == null ? null : 'Roboto'),
          home: const OfferwallTutorialPage(),
        ));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 800)); // une boucle complète de 9 s
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
