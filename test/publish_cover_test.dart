import 'dart:io';
import 'dart:typed_data';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/create/create_publish_page.dart';
import 'package:afrotok/pages/create/create_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Page « Nouveau post » : la ligne « Couverture » (08/11/2026) est proposée pour une vidéo, et seulement pour une vidéo ; la couverture choisie remplace la vidéo dans l'aperçu.
Widget _host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
      theme: ThemeData(brightness: b),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );

UserData _user() => UserData()..countryData = {'countryCode': 'TG'};

final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
  0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('une vidéo propose la ligne Couverture (automatique au départ) ; choisir une couverture la met dans l\'aperçu', (tester) async {
    tall(tester);
    final dir = Directory.systemTemp.createTempSync('publish_cover');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cover = File('${dir.path}/c.png')..writeAsBytesSync(_png);
    var asked = 0;
    await tester.pumpWidget(_host(CreatePublishPage(
      kind: CreatePostKind.video,
      video: File('${dir.path}/v.mp4'),
      me: _user(),
      publish: (d, t, c) async {},
      pickCover: (video, duration, current) async {
        asked++;
        return cover;
      },
    )));
    expect(find.byKey(const ValueKey('field_cover')), findsOneWidget);
    expect(find.text('Couverture'), findsOneWidget);
    expect(find.text('Automatique'), findsOneWidget);
    expect(find.byKey(const ValueKey('publish_cover_preview')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('field_cover')));
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(find.text('Choisie'), findsOneWidget);
    expect(find.byKey(const ValueKey('publish_cover_preview')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('annuler le choix garde la couverture automatique', (tester) async {
    tall(tester);
    await tester.pumpWidget(_host(CreatePublishPage(kind: CreatePostKind.video, video: File('v.mp4'), me: _user(), publish: (d, t, c) async {}, pickCover: (v, d, c) async => null)));
    await tester.tap(find.byKey(const ValueKey('field_cover')));
    await tester.pumpAndSettle();
    expect(find.text('Automatique'), findsOneWidget);
    expect(find.byKey(const ValueKey('publish_cover_preview')), findsNothing);
  });

  testWidgets('image, audio et texte n\'ont pas de ligne Couverture', (tester) async {
    tall(tester);
    for (final k in [CreatePostKind.image, CreatePostKind.audio, CreatePostKind.text]) {
      await tester.pumpWidget(_host(CreatePublishPage(key: UniqueKey(), kind: k, me: _user(), publish: (d, t, c) async {})));
      expect(find.byKey(const ValueKey('field_cover')), findsNothing, reason: '$k');
    }
  });
}
