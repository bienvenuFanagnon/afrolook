import 'dart:convert';

import 'package:afrotok/ads/afrolook_ads_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:visibility_detector/visibility_detector.dart';

Map<String, dynamic> _ad({String? banner}) => {
      'id': 'AD1', 'title': 'Boutique Kofi : mode africaine', 'text': 'Vêtements modernes, livraison à Lomé.', 'cta': 'Visiter',
      'media': {'type': 'image', 'url': 'https://example.com/a.jpg', 'thumb': 'https://example.com/a.jpg'},
      if (banner != null) 'banner': {'url': banner, 'w': 320, 'h': 50},
      'click': 'https://example.com/go?t=TOK', 'token': 'TOK', 'event': 'https://example.com/event', 'viewMs': 1000,
    };

Future<void> _pump(WidgetTester tester, Widget child, http.Client client) async {
  await http.runWithClient(() async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await tester.pump();
  }, () => client);
}

void main() {
  const vid = 'visiteur-test-0001';
  VisibilityDetectorController.instance.updateInterval = Duration.zero; // pas de minuteur de visibilité en attente à la fin d'un test

  test('tailles standard comme AdMob', () {
    expect([AdsBannerSize.mini.width, AdsBannerSize.mini.height, AdsBannerSize.mini.code], [320, 50, '320x50']);
    expect([AdsBannerSize.large.width, AdsBannerSize.large.height, AdsBannerSize.large.code], [320, 100, '320x100']);
    expect([AdsBannerSize.medium.width, AdsBannerSize.medium.height, AdsBannerSize.medium.code], [300, 250, '300x250']);
    expect([AdsBannerSize.leaderboard.width, AdsBannerSize.leaderboard.height, AdsBannerSize.leaderboard.code], [728, 90, '728x90']);
  });

  testWidgets('la bannière demande la bonne taille au moteur et affiche la mention Annonce', (tester) async {
    Uri? asked;
    final client = MockClient((req) async {
      asked = req.url;
      return http.Response(jsonEncode({'ok': true, 'ad': _ad()}), 200);
    });
    await _pump(tester, const AfrolookAdsBanner(pubId: 'ap_aaaaaaaaaa', visitorId: vid, size: AdsBannerSize.large), client);
    expect(asked?.path, '/adsServe');
    expect(asked?.queryParameters['size'], '320x100');
    expect(asked?.queryParameters['fmt'], 'banner');
    expect(asked?.queryParameters['pub'], 'ap_aaaaaaaaaa');
    expect(find.text('Annonce'), findsOneWidget);
    expect(find.text('Boutique Kofi : mode africaine'), findsOneWidget);
    expect(find.text('Visiter'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // arrête les minuteurs
  });

  testWidgets('mini bannière du bas : format collant 320×50, fermable', (tester) async {
    Uri? asked;
    final client = MockClient((req) async {
      asked = req.url;
      return http.Response(jsonEncode({'ok': true, 'ad': _ad()}), 200);
    });
    await _pump(tester, const AfrolookAdsBanner.bottom(pubId: 'ap_aaaaaaaaaa', visitorId: vid), client);
    expect(asked?.queryParameters['fmt'], 'sticky');
    expect(asked?.queryParameters['size'], '320x50');
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.text('Annonce'), findsNothing); // fermée
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('aucune annonce : rien n\'est affiché', (tester) async {
    final client = MockClient((req) async => http.Response(jsonEncode({'ok': true, 'ad': null}), 200));
    await _pump(tester, const AfrolookAdsBanner(pubId: 'ap_aaaaaaaaaa', visitorId: vid), client);
    expect(find.text('Annonce'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('erreur réseau : rien n\'est affiché, aucune exception', (tester) async {
    final client = MockClient((req) async => http.Response('erreur', 500));
    await _pump(tester, const AfrolookAdsBanner(pubId: 'ap_aaaaaaaaaa', visitorId: vid), client);
    expect(find.text('Annonce'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('en-têtes ajoutés (attestation de l\'application)', (tester) async {
    Map<String, String>? seen;
    final client = MockClient((req) async {
      seen = req.headers;
      return http.Response(jsonEncode({'ok': true, 'ad': null}), 200);
    });
    await _pump(tester, AfrolookAdsBanner(pubId: 'ap_aaaaaaaaaa', visitorId: vid, headers: () async => {'X-Firebase-AppCheck': 'jeton'}), client);
    expect(seen?['X-Firebase-AppCheck'], 'jeton');
    await tester.pumpWidget(const SizedBox());
  });
}
