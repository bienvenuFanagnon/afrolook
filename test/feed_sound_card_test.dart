import 'dart:io';
import 'dart:ui' as ui;

import 'package:afrotok/pages/studio/artist_marketplace.dart';
import 'package:afrotok/pages/studio/feed_sound_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ArtistSound _s(String id, String title, {bool free = true, String? genre, int posts = 0}) => ArtistSound.fromMap({
      'userId': 'u1', 'userPseudo': 'x', 'title': title, 'genre': genre, 'previewUrl': 'https://example.com/$id.m4a', 'pricing': free ? 'free' : 'paid',
      'useCoins': 8, 'saleCoins': 120, 'durationMs': 187000, 'status': 'validated', 'usageCount': 0, 'totalEarningsCoins': 0, 'postCount': posts,
      'createdAt': Timestamp.now(),
    }, id);

void main() {
  final out = Platform.environment['FEED_OUT'];
  final sounds = [
    _s('a1', 'Soleil de Lomé', genre: 'Afrobeat', posts: 12),
    _s('b2', 'Nuit à Cotonou', free: false, genre: 'Amapiano'),
    _s('c3', 'Mon pays, ma fierté', genre: 'Rumba', posts: 3),
    _s('d4', 'Matin de marché', free: false, genre: 'Highlife'),
    _s('e5', 'Sur la route de Kara'),
  ];

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('com.ryanheise.just_audio.methods'), (c) async => null);
  });

  for (final dark in [false, true]) {
    for (final kind in ['affiche', 'rangée', 'liste']) {
      testWidgets('$kind se dessine sans erreur (${dark ? 'sombre' : 'clair'}, téléphone étroit)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(380, 900));
        final key = GlobalKey();
        final w = kind == 'affiche'
            ? FeedSoundCard(slot: 0, preset: sounds[0])
            : kind == 'rangée'
                ? FeedSoundCarousel(slot: 0, presets: sounds)
                : FeedSoundList(slot: 0, presets: sounds.take(4).toList());
        await tester.pumpWidget(MaterialApp(
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(body: SingleChildScrollView(child: RepaintBoundary(key: key, child: w))),
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        if (out != null) {
          await tester.runAsync(() async {
            final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final img = await b.toImage(pixelRatio: 1.5);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            await File('$out/${kind}_${dark ? 'sombre' : 'clair'}.png').writeAsBytes(data!.buffer.asUint8List());
          });
        }
      });
    }
  }
}
