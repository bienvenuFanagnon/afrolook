import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/pub/brand_ad_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Advertisement _ad({String? url = 'https://www.boutique-awa.com/pagnes', String? label = 'Visiter le site', String type = 'visit', String? ownerType, String name = 'Boutique Awa'}) => Advertisement(
      id: 'a1',
      description: 'Paiement Mobile Money accepté. Commandez en 2 minutes.',
      actionType: type,
      actionUrl: url,
      actionButtonText: label,
      status: 'active',
      ownerName: name,
      ownerType: ownerType,
      adTitle: 'Livraison en Afrique de l\'Ouest',
      brandCity: 'Lomé',
      brandSector: 'Boutique et commerce',
    );

Post _post({String id = 'ad_a1', String dataType = 'IMAGE'}) => Post(id: id, user_id: '', type: 'POST', status: 'VALIDE', dataType: dataType, description: 'Paiement Mobile Money accepté. Commandez en 2 minutes.');

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('A · carte du fil : marque, Sponsorisé, ville, domaine, titre, bouton choisi par l\'annonceur ; ni profil ni « Suivre »', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var action = 0, details = 0;
    await tester.pumpWidget(_host(BrandAdCard(ad: _ad(), post: _post(), onAction: () => action++, onOpenDetails: () => details++)));
    expect(find.text('Boutique Awa'), findsWidgets);
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.text('· Lomé'), findsOneWidget);
    expect(find.text('boutique-awa.com'), findsOneWidget);            // « www. » retiré
    expect(find.text('Livraison en Afrique de l\'Ouest'), findsOneWidget);
    expect(find.text('Visiter le site'), findsOneWidget);
    expect(find.text('Suivre'), findsNothing);
    await tester.tap(find.text('Visiter le site'));
    expect(action, 1);
    // aucun faux compteur
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.remove_red_eye), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B · annonce vidéo : durée, bouton de son, bouton « Installer » et boutique d\'applications nommée', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ad = _ad(url: 'https://play.google.com/store/apps/details?id=com.kekepay', label: 'Installer', type: 'download', name: 'Kéké Pay')..videoSeconds = 12;
    await tester.pumpWidget(_host(BrandAdCard(ad: ad, post: _post(dataType: 'VIDEO'), onAction: () {}, onOpenDetails: () {})));
    expect(find.text('0:12'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.text('Installer'), findsOneWidget);
    expect(find.text('Google Play'), findsOneWidget);
    expect(find.text('· Application'), findsOneWidget);               // « Sponsorisé · Application »
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans lien, pas de bouton vide ; le texte du bouton retombe sur le type d\'action', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(BrandAdCard(ad: _ad(url: null), post: _post(), onAction: () {}, onOpenDetails: () {})));
    expect(find.text('Visiter le site'), findsNothing);
    expect(adButtonLabel(_ad(label: null, type: 'download')), 'Télécharger');
    expect(tester.takeException(), isNull);
  });

  testWidgets('E · petite annonce : marque, Sponsorisé, secteur, petit bouton', (tester) async {
    await tester.pumpWidget(_host(BrandAdCompact(ad: _ad(label: 'Appeler', type: 'call'), post: _post(), onAction: () {}, onOpenDetails: () {})));
    expect(find.text('Boutique Awa'), findsOneWidget);
    expect(find.text('Sponsorisé'), findsOneWidget);
    expect(find.text('Boutique et commerce'), findsOneWidget);
    expect(find.text('Appeler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F · bannière : étiquette Annonce, nom de la marque, titre et bouton', (tester) async {
    await tester.pumpWidget(_host(BrandBanner(ad: _ad(), post: _post(), onAction: () {}, onOpenDetails: () {})));
    expect(find.text('Annonce'), findsOneWidget);
    expect(find.text('Boutique Awa'), findsOneWidget);
    expect(find.text('Livraison en Afrique de l\'Ouest'), findsOneWidget);
    expect(find.text('Visiter le site'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('C · page de détails : titre, texte, « Pourquoi cette annonce ? », « Signaler », bouton d\'action toujours en bas', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AdDetailPage(ad: _ad(), post: _post())));
    await tester.pump();
    expect(find.text('Annonce'), findsOneWidget);
    expect(find.text('Boutique Awa'), findsWidgets);
    expect(find.text('Livraison en Afrique de l\'Ouest'), findsOneWidget);
    expect(find.textContaining('Pourquoi cette annonce'), findsOneWidget);
    expect(find.textContaining('Signaler'), findsOneWidget);
    expect(find.text('Visiter le site'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D · boost d\'un membre : pseudo, abonnés, « Suivre », « Voir la publication » ; H · boost de canal : bouton vert « Rejoindre le canal »', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final member = _ad(ownerType: 'user', name: 'bienvenu')..ownerFollowers = 2345;
    var followed = 0;
    await tester.pumpWidget(_host(MemberBoostCard(ad: member, post: _post(id: 'p1'), onOpenPost: () {}, onFollow: () => followed++)));
    expect(find.text('@bienvenu'), findsOneWidget);
    expect(find.text('· 2345 abonnés'), findsOneWidget);
    expect(find.text('Voir la publication'), findsOneWidget);
    await tester.tap(find.text('Suivre'));
    expect(followed, 1);
    final canal = _ad(ownerType: 'canal', name: 'Afro Mode');
    await tester.pumpWidget(_host(EntityBoostCard(ad: canal, followers: 12480, onOpen: () {})));
    expect(find.text('Canal · 12480 abonnés'), findsOneWidget);
    expect(find.text('Rejoindre le canal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('annonce « Produit » : prix affiché dans la carte, la petite annonce et la page de détails, bouton Acheter ; sans prix connu, aucun prix inventé', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ad = _ad(label: 'Acheter', type: 'buy')..adType = 'product'..productPrice = 12500;
    expect(adPriceLabel(ad), '12 500 F CFA');
    await tester.pumpWidget(_host(BrandAdCard(ad: ad, post: _post(), onAction: () {}, onOpenDetails: () {})));
    expect(find.text('12 500 F CFA'), findsOneWidget);
    expect(find.text('Acheter'), findsOneWidget);
    await tester.pumpWidget(_host(BrandAdCompact(ad: ad, post: _post(), onAction: () {}, onOpenDetails: () {})));
    expect(find.text('12 500 F CFA'), findsOneWidget);
    // un produit sans prix, ou un autre type avec un prix : aucun prix affiché
    expect(adPriceLabel(_ad()..adType = 'product'), isNull);
    expect(adPriceLabel(_ad()..adType = 'site'..productPrice = 500), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('annonce « Produit » : le prix est aussi dans la page de détails', (tester) async {
    final ad = _ad(label: 'Acheter', type: 'buy')..adType = 'product'..productPrice = 12500;
    await tester.pumpWidget(MaterialApp(home: AdDetailPage(ad: ad, post: _post())));
    await tester.pump();
    expect(find.text('12 500 F CFA'), findsOneWidget);
    expect(find.text('Acheter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('chaque type annoncé a son bouton par défaut', () {
    String label(String type, String action) => _ad(label: null, type: action).getActionButtonText();
    expect((_ad(label: null, type: 'buy')..adType = 'product').getActionButtonText(), 'Acheter');
    expect((_ad(label: null, type: 'download')..adType = 'app').getActionButtonText(), 'Installer');
    expect((_ad(label: null, type: 'visit')..adType = 'site').getActionButtonText(), 'Visiter le site');
    expect(_ad(label: null, type: 'follow').getActionButtonText(), 'Suivre la page');
    expect(_ad(label: null, type: 'book').getActionButtonText(), 'Réserver');
    expect(_ad(label: null, type: 'whatsapp').getActionButtonText(), 'Écrire sur WhatsApp');
    expect(_ad(label: null, type: 'call').getActionButtonText(), 'Appeler');
    expect(label('x', 'call'), 'Appeler');
  });

  test('une annonce du site est reconnue à sa publication synthétique, jamais une vraie publication', () {
    expect(isBrandPost(_post()), isTrue);
    expect(isBrandPost(_post(id: '01j9realpost')), isFalse);
    expect(isBrandPost(null), isFalse);
    expect(brandNameOf(_ad(name: '')), 'Afrolook Ads');
  });
}
