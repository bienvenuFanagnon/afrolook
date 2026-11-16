import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/pub/ad_actions.dart';
import 'package:afrotok/pages/pub/brand_ad_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Annonce d'application avec un lien Google Play et un lien App Store (16/11/2026) : le bon lien selon le téléphone et le logo de la boutique sur « Installer ».
void main() {
  const play = 'https://play.google.com/store/apps/details?id=com.awa.app';
  const apple = 'https://apps.apple.com/app/awa/id123456789';

  test('deux liens : App Store sur iPhone, Google Play sur Android ; logo de la boutique qui va s\'ouvrir', () {
    final ad = Advertisement(adType: 'app', actionType: 'download', actionUrl: play, actionUrlIos: apple);
    expect(AdActions.urlFor(ad, platform: TargetPlatform.iOS), apple);
    expect(AdActions.urlFor(ad, platform: TargetPlatform.android), play);
    expect(AdActions.storeIcon(ad, platform: TargetPlatform.iOS), Icons.apple_rounded);
    expect(AdActions.storeIcon(ad, platform: TargetPlatform.android), Icons.shop_rounded);
  });

  test('un seul lien : ouvert partout (l\'annonce est montrée à tous) ; un site n\'a pas de logo de boutique', () {
    final androidOnly = Advertisement(adType: 'app', actionUrl: play);
    expect(AdActions.urlFor(androidOnly, platform: TargetPlatform.iOS), play);
    expect(AdActions.storeIcon(androidOnly, platform: TargetPlatform.iOS), Icons.shop_rounded);
    final iosOnly = Advertisement(adType: 'app', actionUrl: apple);
    expect(AdActions.urlFor(iosOnly, platform: TargetPlatform.android), apple);
    final site = Advertisement(adType: 'site', actionUrl: 'https://awa.example.com');
    expect(AdActions.storeIcon(site), isNull);
  });

  test('le lien App Store est lu depuis l\'API et gardé dans le modèle', () {
    final ad = Advertisement.fromJson({'actionUrl': play, 'actionUrlIos': apple});
    expect(ad.actionUrlIos, apple);
    expect(ad.toJson()['actionUrlIos'], apple);
  });

  testWidgets('bouton jaune « Installer » : le logo s\'affiche à gauche du texte', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: AdYellowButton(label: 'Installer', onTap: () {}, icon: Icons.shop_rounded)))));
    expect(find.text('Installer'), findsOneWidget);
    expect(find.byIcon(Icons.shop_rounded), findsOneWidget);
    expect(t.getTopLeft(find.byIcon(Icons.shop_rounded)).dx, lessThan(t.getTopLeft(find.text('Installer')).dx));
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: AdYellowButton(label: 'Visiter le site', onTap: () {})))));
    expect(find.byType(Icon), findsNothing);
  });
}
