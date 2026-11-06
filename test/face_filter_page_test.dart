import 'dart:convert';
import 'dart:io';

import 'package:afrotok/pages/create/face_filter_page.dart';
import 'package:afrotok/services/face_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

void main() {
  late File photo;
  setUpAll(() async {
    photo = File('${Directory.systemTemp.path}/ff_${DateTime.now().microsecondsSinceEpoch}.png');
    await photo.writeAsBytes(_png);
  });
  tearDownAll(() async {
    if (await photo.exists()) await photo.delete();
  });

  Widget host(Widget child, Brightness b) => MaterialApp(theme: ThemeData(brightness: b), locale: const Locale('fr'), localizationsDelegates: GlobalMaterialLocalizations.delegates, supportedLocales: const [Locale('fr')], home: child);

  for (final b in [Brightness.light, Brightness.dark]) {
    testWidgets('aperçu des filtres (${b.name}) : choix instantané, Reprendre rend null', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      Object? got = 'rien';
      await tester.pumpWidget(host(
        Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () async => got = await Navigator.of(c).push<String>(MaterialPageRoute(builder: (_) => FaceFilterPage(path: photo.path, size: const Size(600, 800), faces: const [FaceBox(rect: Rect.fromLTWH(200, 200, 200, 260))]))), child: const Text('go')))),
        b,
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('face_overlay')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('filter_glasses')));
      await tester.pump();
      expect(find.text('Utiliser cette photo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('filter_retake')));
      await tester.pumpAndSettle();
      expect(got, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sans visage : pas de filtres proposés, la photo peut être gardée', (tester) async {
    await tester.pumpWidget(host(FaceFilterPage(path: photo.path, size: const Size(600, 800), faces: const []), Brightness.light));
    await tester.pump();
    expect(find.textContaining('Aucun visage trouvé'), findsOneWidget);
    expect(find.byKey(const ValueKey('filter_glasses')), findsNothing);
    expect(find.byKey(const ValueKey('filter_use')), findsOneWidget);
  });
}
